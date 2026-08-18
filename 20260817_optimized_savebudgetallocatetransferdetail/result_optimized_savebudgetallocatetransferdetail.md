# ผลวิเคราะห์ประสิทธิภาพ — SaveBudgetAllocateTransferDetail

**วันที่วิเคราะห์:** 2026-08-17
**ขอบเขต:** view `Budget/BudgetAllocateTransferDetail` → MVC `BudgetController` → API `Budget/SaveBudgetAllocateTransferDetail` → DAL → Oracle PREPROD
**สถานะ:** วิเคราะห์อย่างเดียว — **ไม่มีการแก้ไข code ใดๆ**

> **หมายเหตุการเก็บข้อมูล:** ตัวเลขเวลาทั้งหมดในเอกสารนี้วัดจริงบน Oracle PREPROD (172.16.11.19 / ebs_PRE) ผ่าน VPN
> ด้วยคำสั่ง **SELECT อ่านอย่างเดียว** ไม่มีการ INSERT/UPDATE/DELETE/DDL ใดๆ ทั้งสิ้น

---

## 1. บทสรุปผู้บริหาร (TL;DR)

> **ปัญหาไม่ได้อยู่ที่ code C# และไม่ได้อยู่ที่จำนวนรายการในใบโอน**
> **~95% ของเวลาที่รอ มาจาก Oracle pipelined function ตัวเดียว ที่ถูกเรียก 2 รอบต่อการกดบันทึก 1 ครั้ง**

| ประเด็น | ตัวเลขที่วัดได้ |
|---|---|
| `OAGWBG_FN_GETBUDGET_ALLOCATE_TRANSFER_CATEGORY(2569, 1)` | **33.5 วินาที** คืน 477 แถว |
| จำนวนครั้งที่ถูกเรียกต่อการกดบันทึก 1 ครั้ง | **2 ครั้ง** (ตอน save + ตอน auto-update หลัง reload) |
| เวลาที่ใช้จริงในการเขียนข้อมูลลงตาราง (EF SaveChanges + query ลูก) | **< 1 วินาที** |
| จำนวนรายการสูงสุดต่อใบโอนในระบบจริง | **84 แถว** (เฉลี่ย 3.3 แถว/ใบ) |

**ผลลัพธ์:** ผู้ใช้กดบันทึก → รอ ~33 วิ → หน้า reload → รออีก ~33 วิ (auto-update ทำงาน background พร้อมล็อกปุ่มไว้) ≈ **รวม 70+ วินาทีต่อการบันทึก 1 ครั้ง**

**สาเหตุที่ "ผู้ใช้เยอะแล้วยิ่งช้า":** query 27 วินาทีนี้กิน CPU/IO ของ Oracle เต็มๆ เมื่อ 5 คนกดพร้อมกันคือ 10 queries หนักพร้อมกัน (save 5 + auto-update 5) + ฝั่ง MVC สร้าง `new HttpClient()` ใหม่ทุก request (126 จุดใน `BudgetService.cs`) ทำให้ socket ค้างสถานะ TIME_WAIT

**ข้อสังเกตสำคัญ:** ความช้า **ไม่ขึ้นกับจำนวนรายการในใบโอน** เลย เพราะ function ตัวนี้ query ข้อมูล**ทั้งปีงบประมาณ** ไม่ได้กรองตามใบโอน — ใบที่มี 3 รายการกับใบที่มี 84 รายการ ช้าเท่ากัน

---

## 2. ไฟล์ทั้งหมดที่เกี่ยวข้อง (แยกตาม Layer)

### 2.1 Frontend / View

| ไฟล์ | บรรทัด | บทบาท |
|---|---|---|
| `OAGBudget\Views\Budget\BudgetAllocateTransferDetail.cshtml` | 1206–1377 | `SaveBudgetAllocateTransferDetail()` — ประกอบ payload 3 ก้อน + ยิง AJAX |
| " | 1334–1338 | `$.ajax` POST ไป `/Budget/SaveBudgetAllocateTransferDetail` |
| " | 1339–1350 | **success handler → `markAutoUpdateAfterSave()` + `location.reload()`** ⚠ จุดสำคัญ |
| " | 683–730 | state `isAutoUpdateInProgress` + flag ผ่าน `sessionStorage` |
| " | 857–858 | ตอนโหลดหน้า: ถ้าเจอ flag → `runAutoUpdateBudgetTransfer()` |
| " | 3528–3610 | `updateBudgetTransfer()` — ยิง `/Budget/AutoUpdateBudgetTransfer` |
| " | 1506 | `getChildrenOverAllocatedParents()` — validate ยอดลูก vs แม่ (ฝั่ง client) |

### 2.2 MVC (Frontend Server)

| ไฟล์ | บรรทัด | บทบาท |
|---|---|---|
| `OAGBudget\Controllers\BudgetController.cs` | 3911–3919 | `SaveBudgetAllocateTransferDetail` — bind model แล้วส่งต่อ (ไม่มี logic) |
| " | 3871–3899 | `AutoUpdateBudgetTransfer` — เรียก `UpdateBudgetTransfer` + `GetBudgetAllocateTransferDetail` |
| " | 3818–3841 | `BudgetAllocateTransferDetail(int? id)` — **await dropdown 12 ตัวเรียงกัน** ⚠ |
| " | 3847–3863 | `SetBudgetAllocateTransferCostCenterViewBag()` — +2 API call |
| `OAGBudget\Services\Repository\BudgetService.cs` | 4414–4448 | proxy ไป API — `new HttpClient()` + Timeout 10 นาที ⚠ |

### 2.3 API (Backend)

| ไฟล์ | บรรทัด | บทบาท |
|---|---|---|
| `OAGBudget.API\Controllers\BudgetController.cs` | 1367–1379 | endpoint `POST SaveBudgetAllocateTransferDetail` |
| `OAGBudget.API\Services\Repository\BudgetService.cs` | 10588–10676 | **`SaveBudgetAllocateTransferDetail`** — ฟังก์ชันหลัก |
| " | 10678–10841 | **`SaveBudgetAllocateTransferCategory`** ← 🔥 **จุดคอขวดหลัก (บรรทัด 10689)** |
| " | 10843–10911 | `SaveBudgetAllocateTransferCostCenter` |
| " | 10420–10585 | **`UpdateBudgetTransfer`** ← 🔥 **จุดคอขวดที่สอง (บรรทัด 10484)** |
| " | 19806–19860 | `ResolveRoundNoAsync` — MERGE + SELECT บน `OAGWBG_TRANSFER_RUNNING` |
| " | 10059–10100 | `GetBudgetAllocateTransferDetail` — มี query ซ้ำที่ไม่ได้ใช้ (บรรทัด 10064) |
| " | 10195–10258 | `GetBulkTotalBudget` — เรียก `APPS.oaggl_process.find_budget` แบบ UNION ALL |
| " | 7097–7129 | `GetBudgetYear()` |
| `OAGBudget.API\Services\Repository\AuthenService.cs` | 283–365 | `ValidateTokenAndGetUserInfo()` — **5 DB queries ต่อการเรียก 1 ครั้ง** |

### 2.4 Global / Models / DAL

| ไฟล์ | บทบาท |
|---|---|
| `OAGBudget.Global\CollectionHelper.cs` (บรรทัด 19–71) | `SaveCollectionAsync` — diff add/update/remove แบบ O(N×M) |
| `OAGBudget.Models\Data\BudgetAllocateTransferDetailModel.cs` | DTO 3 ก้อน (header / categoryList / costCenterList) |
| `OAGBudget.DAL\Models\OagwbgBudgetallocatetransfer.cs` | entity header |
| `OAGBudget.DAL\Models\OagwbgBudgetallocatetransferCategory.cs` | entity รายการงบประมาณ |
| `OAGBudget.DAL\Models\OagwbgBudgetallocatetransferCostcenter.cs` | entity ศูนย์ต้นทุน |
| `OAGBudget.DAL\Models\OAGDBContextBase.cs` (บรรทัด 1881+) | mapping — `Id` ไม่ได้ประกาศ `ValueGeneratedNever` |
| `OAGBudget.API\Program.cs` (บรรทัด 40–43) | `AddDbContext(...UseOracle(...))` — ไม่ได้ tune `MaxBatchSize` / `AutoDetectChanges` |

---

## 3. Oracle Objects ที่เกี่ยวข้อง

### 3.1 ตารางในเส้นทาง Save

| Table | บทบาท | จำนวนแถวปัจจุบัน |
|---|---|---|
| `OAGWBG_BUDGETALLOCATETRANSFER` | header ใบโอน | 2,366 |
| `OAGWBG_BUDGETALLOCATETRANSFER_CATEGORY` | รายการงบประมาณ (ลูกของ header) | 4,434 |
| `OAGWBG_BUDGETALLOCATETRANSFER_COSTCENTER` | ศูนย์ต้นทุน + บัญชีผู้โอน/ผู้รับ | 4,188 |
| `OAGWBG_BUDGETRECEIVE` | ยอดรับงบ (ถูกลบตอนลบ category) | 51,811 |
| `OAGWBG_TRANSFER_RUNNING` | ตัวนับ running เลขโอน (MERGE atomically) | — |
| `OAGWBG_BUDGETALLOCATETRANSFER_COSTCENTER_NOTE` | หมายเหตุระดับ line | — |

### 3.2 Function / Package ที่ถูกเรียก

| Object | เรียกจาก | เวลา (วัดจริง) |
|---|---|---|
| **`OAGWBG.OAGWBG_FN_GETBUDGET_ALLOCATE_TRANSFER_CATEGORY`** (PIPELINED) | `BudgetService.cs:10689` (save)<br>`:10484` (auto-update)<br>`:10118` (modal เลือกรายการ) | **33.2–33.5 วินาที** 🔥 |
| `OAGWBG.OAGWBG_FN_GETBUDGETYEAR` | `GetBudgetYear()` | < 50 ms |
| `APPS.oaggl_process.find_budget` | `GetBulkTotalBudget` | ~170 ms/call |
| `APPS.OAGGL_JOURNAL_INF_PKG.MAIN` | `GetBatchStatus` (ยืนยัน/ยกเลิก) | — |

### 3.3 View ที่ function ใช้

| View | จำนวนแถว | เวลา count(*) |
|---|---|---|
| `OAGWBG_V_EXT_OAGPO_EXPENSE_ACCOUNT_RULE_V` | 843 | 549 ms ← **ตัวปัญหา** |
| `OAGWBG_V_EXT_OAGGL_ACCOUNT_HIERACHIES_V` | 15,894 | 30 ms |
| `OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V` | 808 | 210 ms |
| `APPS.OAGGL_BUDGET_PRODUCT_V` | 26 | 27 ms |
| `APPS.OAGGL_BUDGET_ACTIVITY_V` | 22 | 22 ms |
| `OAGWBG_V_EXT_OAGGL_BUDGET_CATEGORY_PLAN` | 7 | 19 ms |

### 3.4 Interface / Staging table (ฝั่งยืนยัน–ยกเลิก, ไม่อยู่บนเส้นทาง Save)

หน้านี้**ไม่มี temp table บนเส้นทางบันทึก** — บันทึกลงตารางจริงโดยตรง
temp/staging table จะถูกใช้เฉพาะตอน **ยืนยัน / ยกเลิก** เท่านั้น:

| Object | บทบาท | เรียกจาก |
|---|---|---|
| `oagwbg.oaggl_journal_interface` | **staging table** — เขียน journal line ก่อน post เข้า GL | `SaveInterface()` `BudgetService.cs:14772` |
| `OAGWBG_LOG_INTERFACE` | log ผลการ interface (ใช้ตรวจเมื่อ post ไม่สำเร็จ) | `SaveInterface` / `GetBatchStatus` |
| `OAGWBG_RECEIVE_BATCH_NO` | เก็บเลข batch ที่ post สำเร็จ (`InterfaceType = "A"`) | `GetBatchStatus` `:21305` |
| `APPS.OAGGL_JOURNAL_INF_PKG.MAIN` | **Stored Procedure** ที่ push จาก staging เข้า GL จริง | `GetBatchStatus` |

Endpoint ที่เกี่ยวข้อง (จาก view): `ConfirmBudgetAllocateTransfer`, `ReverseConfirmBudgetAllocateTransfer`, `ApproveBudgetAllocateTransfer`, `CancelReserveBudgetAllocateTransfer`, `CancelBudgetAllocateTransfer`

### 3.5 สถานะ Index (วัดจาก `all_ind_columns`)

| Table | Index ที่มี |
|---|---|
| `OAGWBG_BUDGETALLOCATETRANSFER_CATEGORY` | `SYS_C0012028 (ID)` — **PK เท่านั้น ไม่มี index บน `BUDGETALLOCATETRANSFERID`** |
| `OAGWBG_BUDGETALLOCATETRANSFER_COSTCENTER` | `SYS_C0012042 (ID)` — **PK เท่านั้น** |
| `OAGWBG_BUDGETRECEIVE` | `SYS_C0011972 (ID)`, `OAGWBG_BUDGETRECEIVE_N1 (BUDGETALLOCATETRANSFERID)` — **ไม่มี index บน `BUDGETALLOCATETRANSFERCATEGORYID`** |
| `OAGWBG_TRANSFER_RUNNING` | `PK_TRANSFER_RUNNING (BUDGET_YEAR, ORG_TYPE)` ✓ |

**Trigger (สำหรับออก ID):** `TRG_BI_OAGWBG_BUDGETTRANSFER_CATEGORY` (BEFORE INSERT, ENABLED) — คอลัมน์ `ID` มี `IDENTITY_COLUMN = NO` แปลว่าใช้ sequence ผ่าน trigger

> ⚠ Index ที่ขาดยัง**ไม่ใช่คอขวดในตอนนี้** เพราะตารางเล็กมาก (4.4k / 4.2k แถว) — วัดได้ 14–354 ms ต่อ query
> แต่ควรเพิ่มไว้ก่อนที่ข้อมูลจะโต (ดูข้อ 6.3)

---

## 4. Flow ปัจจุบัน + หลักฐานตัวเลข

### 4.1 ลำดับการทำงานพร้อมเวลาที่วัดได้

```
[Browser] คลิกบันทึก
    │
    ├─ blockedByAutoUpdate() → validate 3 ฟิลด์ → validate ยอดลูก vs แม่      (client, ~0 ms)
    ├─ ประกอบ payload: header + items + costCenterItems                       (client, ~0 ms)
    ├─ ConfirmSubmitDialog → showLoading() → isSaving = true
    │
    ▼ POST /Budget/SaveBudgetAllocateTransferDetail
[MVC Controller :3911] bind model → ส่งต่อ service ทันที                        (~0 ms)
[MVC Service :4414]  new HttpClient() ⚠ + Bearer token + PostAsJsonAsync
    │
    ▼ POST {BaseUrlApi}/Budget/SaveBudgetAllocateTransferDetail
[API Controller :1367] → [API Service :10588]
    │
    ├─ ValidateTokenAndGetUserInfo()                              5 queries   (~250 ms)
    ├─ validate 3 ฟิลด์ (ซ้ำกับฝั่ง client)
    ├─ UPDATE: SELECT header  /  INSERT: ResolveRoundNoAsync (MERGE+SELECT)   (~50 ms)
    ├─ SaveChangesAsync()                                                      (~20 ms)
    │
    ├─▶ SaveBudgetAllocateTransferCategory() :10678
    │     ├─ SELECT existing categories WHERE budgetallocatetransferid = :id  (~180 ms, full scan)
    │     ├─ SELECT header ซ้ำอีกรอบ ⚠ (มี entity อยู่ใน param แล้ว)          (~20 ms)
    │     ├─ 🔥 SELECT * FROM TABLE(OAGWBG_FN_GETBUDGET_ALLOCATE_TRANSFER_CATEGORY(year, orgtype))
    │     │                                                    ★★★ 33,470 ms ★★★
    │     ├─ prefetch catInfos / receivesByCategoryId / costCenterRows        (~250 ms)
    │     ├─ CollectionHelper.SaveCollectionAsync (add/update/remove)
    │     └─ SaveChangesAsync()                                               (~200 ms)
    │
    ├─▶ SaveBudgetAllocateTransferCostCenter() :10843
    │     ├─ SELECT validCostCenters (join BUDGETRECEIVE × CATEGORY_CODES_V)  (~100 ms)
    │     ├─ SELECT existing costcenters                                      (~15 ms)
    │     └─ SaveChangesAsync()                                               (~100 ms)
    │
    ▼ return id                                            รวมฝั่ง API ≈ 34.7 วินาที
[Browser] AlertSuccessDialog → markAutoUpdateAfterSave(id) → location.reload()
    │
    ▼ GET /Budget/BudgetAllocateTransferDetail/{id}
[MVC :3818] await dropdown 12 ตัว + GetBudgetAllocateTransferDetail + ViewBag 2 ตัว
             = ~15 HTTP round-trip เรียงกัน (แต่ละตัว new HttpClient()) ⚠     (~2–5 วินาที)
    │
    ▼ onload: เจอ flag → runAutoUpdateBudgetTransfer() (background, ล็อกปุ่มไว้)
[MVC :3871] → [API :10420] UpdateBudgetTransfer
    │     ├─ ValidateTokenAndGetUserInfo()                        5 queries   (~250 ms)
    │     ├─ SELECT transferStatus / categories                               (~200 ms)
    │     ├─ 🔥 SELECT * FROM TABLE(OAGWBG_FN_GETBUDGET_ALLOCATE_TRANSFER_CATEGORY(year, 1))
    │     │                                                    ★★★ 33,470 ms ★★★
    │     ├─ GetBulkTotalBudget → find_budget แบบ UNION ALL                   (~200 ms)
    │     └─ SaveChangesAsync()
    └─ แล้วยังเรียก GetBudgetAllocateTransferDetail อีกรอบ (:3886)            (~500 ms)

รวมเวลาตั้งแต่คลิกจนหน้าใช้งานได้เต็ม ≈ 70–75 วินาที
```

### 4.2 ผ่าตัด function หา root cause (วัดทีละชั้น)

รัน SQL แยกทีละส่วนของ function body บน PREPROD:

| การทดสอบ | เวลา | แถว |
|---|---|---|
| `TABLE(OAGWBG_FN_GETBUDGET_ALLOCATE_TRANSFER_CATEGORY(2569,1))` | 33,470 ms | 477 |
| รันซ้ำครั้งที่ 2 (ทดสอบ cache) | 33,214 ms | 477 | 
| เปลี่ยน orgtype เป็น 2 | 33,208 ms | 477 |
| cursor query ของ function แบบ standalone | 27,487 ms | 477 |
| subquery ชั้นใน `BRC_BASE` อย่างเดียว | **660 ms** | 495 |
| subquery `BATC` อย่างเดียว | **431 ms** | 359 |
| cursor query แต่**ตัด `LEFT JOIN ah`** ออก | 27,612 ms | 477 |
| cursor query แต่**ตัด `OUTER APPLY eoearv`** ออก | **5,197 ms** ✅ | 477 |

### 🎯 ต้นตอ: `OUTER APPLY` ทำลาย execution plan ของทั้ง query (ไม่ใช่ตัวมันเองแพง)

```sql
-- ในตัว function บรรทัด ~403–429
OUTER APPLY (
    SELECT *
    FROM OAGWBG_V_EXT_OAGPO_EXPENSE_ACCOUNT_RULE_V EAR
    WHERE EAR.CATEGORYID = BRC.CATEGORYID
    ORDER BY
        CASE WHEN EAR.BUDGETYEAR = MOD(BRC.BUDGETYEAR,100)
              AND EAR.PRODUCTID = BRC.PRODUCTID
              AND EAR.ACTIVITYCODEID = BRC.ACTIVITYID
             THEN 1 ELSE 2 END
    FETCH FIRST 1 ROW ONLY
) eoearv
```

**สมมติฐานแรกผิด** — ตอนแรกคิดว่า `OUTER APPLY` แพงเพราะรัน view ซ้ำทีละแถว แต่ทดสอบแล้วไม่ใช่:

| การทดสอบเพิ่มเติม | เวลา |
|---|---|
| `OUTER APPLY` แบบแยกเดี่ยว (383 แถว, ไม่มี cache) | **813 ms** |
| `OUTER APPLY` แบบแยกเดี่ยว (มี `MATERIALIZE` cache) | **122 ms** |
| ใส่ `MATERIALIZE` ให้ view ใน function จริง แต่ไม่แตะอย่างอื่น | **30,186 ms** (แทบไม่ช่วย) |

**ต้นตอที่แท้จริง:** `OUTER APPLY` เป็น **lateral join ที่ Oracle merge/unnest ไม่ได้** → มันไปบล็อกการจัดลำดับ join ทำให้ optimizer เลือก **nested-loop** แล้ว **ประเมิน inline view `BRC` และ `BATC` ซ้ำ** แทนที่จะ hash join ครั้งเดียว

- `BRC` เดี่ยวๆ = 660 ms, `BATC` เดี่ยวๆ = 431 ms → ถ้าคำนวณครั้งเดียวควรจบใน ~1–2 วินาที
- แต่พอมี lateral คั่นกลาง → 27.5 วินาที

**วิธีแก้:** ยก 3 บล็อกหนัก (`BRC`, `BATC`, view `EAR`) ขึ้นเป็น CTE พร้อม hint `/*+ MATERIALIZE */` เพื่อบังคับให้แต่ละบล็อกคำนวณ **ครั้งเดียว** ลง temp table — **ไม่แตะ logic / predicate / GROUP BY แม้แต่บรรทัดเดียว**

→ ดูผลการแก้ไขและหลักฐานการพิสูจน์ความถูกต้องที่ **หัวข้อ 9**

### 4.3 ปัญหาอื่นที่พบระหว่างทาง

| # | ปัญหา | หลักฐาน |
|---|---|---|
| **A** | **`p_BudgetFormType` (orgtype) ประกาศไว้แต่ไม่ถูกใช้เลยใน body ของ function** | รัน orgtype 1 และ 2 ได้ 477 แถวเท่ากันเป๊ะ + grep source ไม่เจอการอ้างถึงหลังบรรทัด declare |
| **B** | **`data` จาก function ถูกใช้เฉพาะใน `addFuncAsync` เท่านั้น** — save ที่ไม่ได้เพิ่มรายการใหม่ (แก้ยอด/แก้บัญชี) เสีย 33 วิ ฟรีๆ | `BudgetService.cs:10685–10690` เทียบกับ `:10734` |
| **C** | **auto-update ยิงหลัง save ทุกครั้งเสมอ** ไม่ว่าจะเปลี่ยนอะไร → เรียก function ตัวเดิมซ้ำอีก 33 วิ | view `:1345, :1348` + `:857–858` |
| **D** | `new HttpClient()` ทุก request — **126 จุดใน `OAGBudget\Services\Repository\BudgetService.cs`** ไม่มี `IHttpClientFactory` (มีแค่ `AddHttpClient<ITokenService>` ที่ `Program.cs:45`) | grep count |
| **E** | หน้า detail `await` dropdown 12 ตัวเรียงกัน + `DropdownProduct`/`DropdownActivity` ถูก assign ซ้ำ 2 รอบ (บรรทัด 3823–3824 ถูกทับด้วย 3826–3827) → **เสีย round-trip ฟรี 2 ครั้ง** | `BudgetController.cs:3818–3841` |
| **F** | `GetBudgetAllocateTransferDetail` query `OagwbgVBudgetallocatetransfers` **2 รอบ** ตัวแปร `t` ไม่ถูกใช้เลย | `BudgetService.cs:10064–10065` |
| **G** | `SaveBudgetAllocateTransferCategory` query header ซ้ำทั้งที่มี entity ใน parameter อยู่แล้ว | `BudgetService.cs:10686` |
| **H** | `ValidateTokenAndGetUserInfo()` = 5 DB queries ต่อครั้ง ไม่มี cache | `AuthenService.cs:326–361` |
| **I** | `CollectionHelper.SaveCollectionAsync` เป็น O(N×M) — **ยังไม่เป็นปัญหา** เพราะสูงสุด 84 แถว/ใบ | `CollectionHelper.cs:33–35` + วัดจาก DB |

---

## 5. สิ่งที่ต้องเปลี่ยนในแต่ละ Layer

### 🔴 Layer 1 — Oracle DB (ผลกระทบ ~95%, ต้องทำก่อนอย่างอื่น)

**เป้าหมาย: 33 วินาที → < 3 วินาที**

**1.1 ✅ แก้แล้ว — ยก `BRC` / `BATC` / view `EAR` เป็น CTE + `MATERIALIZE`**

**33.5 วินาที → 1.2 วินาที (เร็วขึ้น 28 เท่า)** พิสูจน์แล้วว่าผลลัพธ์เหมือนเดิมทุกแถวทุกคอลัมน์
ไฟล์ DDL พร้อมใช้: `OAGWBG_FN_GETBUDGET_ALLOCATE_TRANSFER_CATEGORY_optimized.sql`
ไฟล์กู้คืน: `OAGWBG_FN_GETBUDGET_ALLOCATE_TRANSFER_CATEGORY_rollback_original.sql`

รายละเอียดและหลักฐานทั้งหมดอยู่ที่ **หัวข้อ 9**

**1.2 เพิ่ม parameter กรองตามใบโอน**
`p_BudgetFormType` ไม่ได้ถูกใช้อยู่แล้ว — เพิ่ม `p_BudgetAllocateTransferId` เพื่อให้ query เฉพาะ category ของใบที่กำลังบันทึก แทนที่จะดึงทั้งปี (477 แถว → ~3–84 แถว)

**1.3 เพิ่ม index (เตรียมรับข้อมูลโต, R2)**
```sql
CREATE INDEX OAGWBG.IX_BATC_TRANSFERID   ON OAGWBG.OAGWBG_BUDGETALLOCATETRANSFER_CATEGORY (BUDGETALLOCATETRANSFERID);
CREATE INDEX OAGWBG.IX_BATCC_TRANSFERID  ON OAGWBG.OAGWBG_BUDGETALLOCATETRANSFER_COSTCENTER (BUDGETALLOCATETRANSFERID);
CREATE INDEX OAGWBG.IX_BR_BATCATID       ON OAGWBG.OAGWBG_BUDGETRECEIVE (BUDGETALLOCATETRANSFERCATEGORYID);
```
> ตอนนี้ยังไม่ให้ผลชัด (ตารางเล็ก) แต่ `OAGWBG_BUDGETRECEIVE` มี 51k แถวและถูก full-scan ทุกครั้งที่มีการลบ category

**1.4 เก็บสถิติ (`DBMS_STATS`)**
`all_tables.NUM_ROWS` เป็น NULL ทั้ง 5 ตาราง → **optimizer ไม่มีสถิติเลย** ต้องเดา cardinality ทำให้เลือก plan ผิดได้ง่าย

---

### 🟠 Layer 2 — API Service (ผลกระทบสูง, แก้ได้เองไม่ต้องรอ DBA)

**2.1 `SaveBudgetAllocateTransferCategory` — เรียก function เฉพาะเมื่อจำเป็น** (`BudgetService.cs:10685–10690`)

`data` ถูกใช้แค่ใน `addFuncAsync` → เช็คก่อนว่ามีรายการใหม่ (`s.Id == 0`) หรือไม่ ถ้าไม่มีก็ไม่ต้องเรียก function เลย
**ผล:** การบันทึกที่แก้เฉพาะยอด/บัญชี (น่าจะเป็นส่วนใหญ่) เร็วขึ้นจาก 34 วิ → < 1 วิ ทันที **โดยไม่ต้องแตะ DB เลย**

**2.2 ตัด query ซ้ำ**
- `:10686` — ใช้ `budgetAllocateTranfer` ที่รับมาเป็น parameter แทนการ query ใหม่
- `:10064` — ลบตัวแปร `t` ที่ไม่ถูกใช้

**2.3 cache ผลของ function ระยะสั้น**
ผลของ `OAGWBG_FN_GETBUDGET_ALLOCATE_TRANSFER_CATEGORY(year, orgtype)` เหมือนกันทุกคนในปีเดียวกัน → `IMemoryCache` 30–60 วินาที จะตัดภาระของผู้ใช้พร้อมกันได้เกือบทั้งหมด
> ⚠ ต้องตกลงกับ business ก่อนว่ายอมรับข้อมูลเก่าได้กี่วินาที — เป็น trade-off ระหว่างความเร็วกับความสด

**2.4 cache `ValidateTokenAndGetUserInfo()` ต่อ request**
5 queries × ทุก method ที่เรียก — ใช้ `HttpContext.Items` เก็บผลไว้ต่อ request

**2.5 tune EF (`Program.cs:40`)**
```csharp
option.UseOracle(cs, o => o.MaxBatchSize(100))
```
ผลกระทบน้อย (สูงสุด 84 แถว) แต่ทำง่าย

---

### 🟡 Layer 3 — MVC Frontend Server

**3.1 เปลี่ยน `new HttpClient()` → `IHttpClientFactory`** — 126 จุดใน `BudgetService.cs`
นี่คือสาเหตุหลักของ "ผู้ใช้เยอะแล้วยิ่งช้า" ในฝั่ง app tier (socket TIME_WAIT exhaustion)
> R1 — เปลี่ยนหลายจุด ควรทำเป็น shared helper method แล้วค่อยแทนที่ทีละกลุ่ม

**3.2 ยิง dropdown แบบขนาน** (`BudgetController.cs:3818–3841`)
`await` 12 ตัวเรียงกัน → `Task.WhenAll` และ**ลบบรรทัด 3823–3824 ที่ถูกทับทิ้ง**
**ผล:** page reload หลัง save เร็วขึ้น ~60–70%

**3.3 พิจารณา cache dropdown**
Region / Plan / Product / Activity / Category / BudgetCode เปลี่ยนน้อยมาก → `IMemoryCache` ระดับนาที

---

### 🟢 Layer 4 — View / UX

**4.1 ไม่ต้อง `location.reload()` หลัง save** (`.cshtml:1349`)
ตอนนี้ save → reload หน้า (15 API calls) → auto-update (33 วิ) → patch DOM
ควรให้ API คืน state ที่อัพเดตแล้วกลับมาเลย แล้ว patch DOM ตรงๆ

**4.2 ยิง auto-update เฉพาะเมื่อจำเป็น** (`.cshtml:1344–1350`)
ตอนนี้ `markAutoUpdateAfterSave()` ถูกเรียกทุกครั้ง → ควรเรียกเฉพาะเมื่อมีการ**เพิ่ม/ลบรายการงบประมาณ** ไม่ใช่ตอนแก้ยอดหรือแก้บัญชีธนาคาร

**4.3 แสดง progress ที่มีความหมาย**
`showLoading()` แบบ spinner เปล่าๆ 33 วินาที ทำให้ผู้ใช้คิดว่าระบบค้าง

---

## 6. ลำดับความสำคัญที่แนะนำ

| ลำดับ | งาน | Layer | ผลที่คาด | ความเสี่ยง | หมายเหตุ |
|---|---|---|---|---|---|
| **1** | ข้าม function เมื่อไม่มีรายการใหม่ (2.1) | API | 34 วิ → **< 1 วิ** สำหรับ save ส่วนใหญ่ | **R2** ต่ำมาก | ⭐ ทำก่อนเลย คุ้มที่สุด |
| **2** | ไม่ยิง auto-update ถ้าไม่ได้เพิ่ม/ลบรายการ (4.2) | View | ตัด 33 วิ ที่สอง | **R2** | ⭐ ทำคู่กับข้อ 1 |
| **3** | ✅ **แก้ function แล้ว** (1.1 / หัวข้อ 9) | Oracle | 33 วิ → **1.2 วิ** ทุกกรณี | **R1** — diff ผ่านแล้ว 0/0 | รอ deploy (มีไฟล์ rollback) |
| **4** | `Task.WhenAll` dropdown + ลบบรรทัดซ้ำ (3.2) | MVC | reload เร็วขึ้น 60–70% | **R2** | |
| **5** | `IHttpClientFactory` (3.1) | MVC | แก้อาการ "คนเยอะยิ่งช้า" | **R1** | 126 จุด ทยอยทำ |
| **6** | cache ผล function + userInfo (2.3, 2.4) | API | ตัดภาระ concurrent | **R1** ต้องตกลง TTL | |
| **7** | เพิ่ม parameter กรองตามใบโอน (1.2) | Oracle | ลดข้อมูลที่ query | **R1** เปลี่ยน signature | |
| **8** | index + `DBMS_STATS` (1.3, 1.4) | Oracle | เตรียมรับข้อมูลโต | **R2** | |

---

## 7. ข้อควรระวัง (DISSENT)

**7.1 อย่าเพิ่งไปแก้ Oracle function เป็นอย่างแรก**
ข้อ 1 + 2 (แก้ C#/JS ล้วน, R2) ให้ผลกับ **use case ส่วนใหญ่** ทันทีโดยไม่ต้องรอ DBA และไม่มีความเสี่ยงต่อความถูกต้องของตัวเลขงบประมาณ — ควรทำก่อนแล้ววัดผลจริงก่อนตัดสินใจแตะ function

**7.2 Blast radius ของการแก้ function** — ✅ ตรวจครบแล้ว (หัวข้อ 9.3)
`OAGWBG_FN_GETBUDGET_ALLOCATE_TRANSFER_CATEGORY` ถูกเรียกจาก **3 จุด** (`:10118` modal, `:10484` auto-update, `:10689` save) — แก้ผิดกระทบทั้ง 3 หน้า และกระทบ **ตัวเลขงบประมาณที่โชว์ให้ผู้ใช้เห็น**
- ✅ diff ทุกคอลัมน์ทุกแถวแล้ว ตรงกัน 0/0 ทั้ง 7 ชุดทดสอบ
- ✅ ทดสอบครบทุก `p_BudgetSource` (NULL / 100 / 200 / 300 / 400) และ 3 ปีงบ (2567/2568/2569)
- ⚠ `LAST_DDL_TIME` ของ function คือ 2026-08-14 (แก้ล่าสุด 3 วันก่อน) — **ยังต้องตรวจว่าไม่มีใครกำลังแก้อยู่คู่ขนาน ก่อน replace ทับ**

**7.3 การ cache มี trade-off ด้านความถูกต้อง**
ยอดงบคงเหลือเป็นตัวเลขที่ผู้ใช้ตัดสินใจโอนเงินจริง — การ cache 60 วิ อาจทำให้เห็นยอดเก่า ต้องให้ business ตัดสินใจ ไม่ใช่ทีมพัฒนาตัดสินเอง

**7.4 สิ่งที่ยังไม่ได้ตรวจ**
- ไม่ได้วัด end-to-end จริงผ่าน browser (วัดเฉพาะ SQL + อ่าน code) — ตัวเลข 70 วินาทีเป็นการประมาณจากผลรวม ควร**ยืนยันด้วย browser DevTools Network tab** ก่อนเริ่มแก้
- ไม่ได้ตรวจ execution plan ของ function (user `OAGWBG` ไม่มีสิทธิ์อ่าน `v$sql` — `ORA-00942`) → ควรให้ DBA ดึง plan มาประกอบ
- ไม่ได้ทดสอบ concurrency จริง (สมมติฐานเรื่อง "คนเยอะยิ่งช้า" มาจากการอ่าน code + ธรรมชาติของ query 27 วินาที)
- ไม่ได้อ่าน definition ของ `OAGWBG_V_EXT_OAGPO_EXPENSE_ACCOUNT_RULE_V` (คอลัมน์ `TEXT` เป็น LONG อ่านผ่าน tool ไม่ได้) — ควรตรวจว่า view นี้ทำไม materialize ช้า 550 ms

---

## 8. Scope check

**สิ่งที่ prompt ขอ:** วิเคราะห์อย่างเดียว ห้ามแก้ code → ✅ **ไม่มีไฟล์ C# / .cshtml ถูกแก้ไข**
**สิ่งที่ทำเพิ่มจาก prompt:** query PREPROD เพื่อวัดเวลาจริง (SELECT อย่างเดียว) — จำเป็นเพราะถ้าวิเคราะห์จาก code อย่างเดียวจะสรุปผิดว่าคอขวดคือ EF/N+1/index ซึ่ง**ไม่ใช่**
**สิ่งที่ทำตามที่ผู้ใช้สั่งเพิ่มภายหลัง:** เขียน DDL เวอร์ชัน optimized ของ Oracle function + พิสูจน์ความถูกต้อง (หัวข้อ 9)
**สิ่งที่ยังไม่ได้ทำ:** **ยังไม่ deploy DDL ลง PREPROD** — `CREATE OR REPLACE` บน DB ที่ใช้ร่วมกันเป็น R1 ต้องขออนุมัติก่อน

---

## 9. ผลการแก้ไข Oracle Function ✅

### 9.1 สิ่งที่แก้ (structural อย่างเดียว — ไม่แตะ logic)

| จุด | เดิม | ใหม่ |
|---|---|---|
| 1 | inline view `( ...133 บรรทัด... ) BRC` อยู่ใน `FROM` | ยกขึ้นเป็น `WITH BRC AS (SELECT /*+ MATERIALIZE */ * FROM (...))` |
| 2 | `LEFT JOIN ( ...116 บรรทัด... ) BATC ON ...` | ยกขึ้นเป็น `WITH BATC AS (SELECT /*+ MATERIALIZE */ * FROM (...))` แล้ว `LEFT JOIN BATC ON ...` (ON เดิมทุกบรรทัด) |
| 3 | `OUTER APPLY (SELECT * FROM OAGWBG_V_EXT_OAGPO_EXPENSE_ACCOUNT_RULE_V EAR ...)` | `OUTER APPLY (SELECT * FROM EAR_CACHE EAR ...)` โดย `EAR_CACHE` เป็น CTE ที่ materialize view นี้ครั้งเดียว |

> **ไม่มีการเปลี่ยน:** predicate ใน WHERE, เงื่อนไข ON, `ORDER BY CASE ... FETCH FIRST 1 ROW ONLY`,
> select list, GROUP BY, ORDER BY, PIPE ROW, signature ของ function — **เหมือนเดิมทุกตัวอักษร**

### 9.2 ผลด้านความเร็ว

| p_BudgetYear | p_BudgetSource | จำนวนแถว | **เดิม** | **ใหม่** | เร็วขึ้น |
|---|---|---|---|---|---|
| 2569 | NULL (ที่ save/auto-update ใช้) | 477 | **33,470 ms** | **1,186 ms** | **28×** |
| 2569 | 100 | 465 | ~33,000 ms | **1,176 ms** | ~28× |
| 2569 | 200 | 63 | ~5,000 ms | **812 ms** | ~6× |
| 2569 | 300 | 1 | ~1,000 ms | < 1,000 ms | — |
| 2569 | 400 | 8 | ~1,500 ms | < 1,000 ms | — |
| 2568 | NULL | 33 | — | ~1,000 ms | — |
| 2567 | NULL | 9 | — | ~1,000 ms | — |

### 9.3 การพิสูจน์ว่าผลลัพธ์เหมือนเดิม 100%

วิธี: เทียบแบบ **multiset ที่แน่นอน** — `GROUP BY` ทั้ง 25 คอลัมน์ + `COUNT(*)` แล้ว `MINUS` ทั้งสองทิศทาง
(จับได้ทั้งแถวที่หาย แถวที่เกิน ค่าที่เปลี่ยน และจำนวนแถวซ้ำที่ไม่ตรงกัน)

```sql
WITH ... NP AS (SELECT TO_CHAR(CODE) K1, ... TO_CHAR(DEPARTMENTID) K25 FROM <ใหม่>),
         OP AS (SELECT TO_CHAR(CODE) K1, ... TO_CHAR(DEPARTMENT)   K25 FROM TABLE(<function เดิม>))
SELECT (SELECT COUNT(*) FROM (SELECT K1..K25, COUNT(*) M FROM NP GROUP BY K1..K25
                              MINUS
                              SELECT K1..K25, COUNT(*) M FROM OP GROUP BY K1..K25)) NEW_MINUS_ORIG,
       (SELECT COUNT(*) FROM (... ทิศทางกลับกัน ...))                               ORIG_MINUS_NEW
FROM dual
```

**ผลการทดสอบทั้ง 7 ชุด:**

| ชุดทดสอบ | CNT_NEW | CNT_ORIG | NEW − ORIG | ORIG − NEW | ผล |
|---|---|---|---|---|---|
| year 2569, source NULL | 477 | 477 | **0** | **0** | ✅ |
| year 2569, source 100 | 465 | 465 | **0** | **0** | ✅ |
| year 2569, source 200 | 63 | 63 | **0** | **0** | ✅ |
| year 2569, source 300 | 1 | 1 | **0** | **0** | ✅ |
| year 2569, source 400 | 8 | 8 | **0** | **0** | ✅ |
| year 2568, source NULL | 33 | 33 | **0** | **0** | ✅ |
| year 2567, source NULL | 9 | 9 | **0** | **0** | ✅ |

### 9.4 ไฟล์ที่สร้าง

| ไฟล์ | ใช้ทำอะไร |
|---|---|
| `OAGWBG_FN_GETBUDGET_ALLOCATE_TRANSFER_CATEGORY_optimized.sql` | DDL เวอร์ชันใหม่ พร้อม deploy |
| `OAGWBG_FN_GETBUDGET_ALLOCATE_TRANSFER_CATEGORY_rollback_original.sql` | ต้นฉบับดึงจาก `all_source` ของ PREPROD ใช้กู้คืนถ้ามีปัญหา |

### 9.5 ข้อควรระวังก่อน deploy

1. **ยังไม่ได้ deploy** — `CREATE OR REPLACE` บน PREPROD กระทบผู้ใช้คนอื่นที่ใช้ DB เดียวกัน ต้องได้รับอนุมัติก่อน
2. **`LAST_DDL_TIME` = 2026-08-14** — เพิ่งมีคนแก้ function นี้ไป 3 วัน ต้องเช็คว่าไม่มีใครแก้คู่ขนานอยู่ ก่อน replace ทับ
3. function นี้ถูกเรียกจาก **3 จุดใน code** (`:10118` modal เลือกรายการ, `:10484` auto-update, `:10689` save) — หลัง deploy ควรทดสอบทั้ง 3 หน้า
4. `MATERIALIZE` เขียนลง **temp tablespace** — ปริมาณเล็กมาก (477 + 359 + 843 แถว) แต่เมื่อผู้ใช้พร้อมกันหลายคนจะมี temp segment หลายชุด ควรให้ DBA ดู temp usage หลัง deploy
5. ยังไม่ได้ทดสอบบน PROD data volume — PREPROD มี `OAGWBG_BUDGETRECEIVE` 51,811 แถว ถ้า PROD ใหญ่กว่ามากควรวัดซ้ำ
6. **ยังไม่ได้เก็บสถิติ (`DBMS_STATS`)** — ทุกตารางมี `NUM_ROWS` เป็น NULL ถ้าเก็บสถิติแล้ว plan อาจเปลี่ยน ควรวัดซ้ำหลังเก็บสถิติ

### 9.6 หมายเหตุ — สิ่งที่ยังคุ้มทำต่อแม้แก้ function แล้ว

แม้ function จะเหลือ 1.2 วินาที แต่ยังถูกเรียก **2 ครั้งต่อการกดบันทึก 1 ครั้ง** โดยไม่จำเป็น
ข้อ 1 และ 2 ในตารางลำดับความสำคัญ (หัวข้อ 6) **ยังคุ้มทำอยู่** เพราะตัดการเรียกที่ไม่จำเป็นทิ้งทั้งหมด
และเป็นการแก้ฝั่ง application ที่ไม่กระทบผู้ใช้คนอื่น

---

*วิเคราะห์และแก้ไขโดย Claude Opus 5 — 2026-08-17*
