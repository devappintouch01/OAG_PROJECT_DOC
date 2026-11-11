# แผนงาน: ผูกรายการครุภัณฑ์ทดแทนเข้ากับรายการค่าใช้จ่าย

> วันที่วิเคราะห์: 2026-08-27 · ตรวจโครงสร้าง DB จริงบน PREPROD (172.16.11.19:1541/ebs_PRE)

## สถานะการทำงาน (2026-08-27)

| Phase | สถานะ |
|---|---|
| 1 · Database | 🟡 **บางส่วน** — `ALTER TABLE ADD COLUMN` + `COMMENT` รันแล้ว · **ยังเหลือ index, view, backfill** |
| 2 · DAL | ✅ เสร็จ |
| 3 · API Service | ✅ เสร็จ |
| 4 · Frontend (ตาราง + modal ต่อบรรทัด) | ✅ เสร็จ ทั้ง 4 หน้า |
| 5 · แท็บ Tree อ่านอย่างเดียว | ✅ เสร็จ ทั้ง 2 partial |
| 6 · รายงาน | ⏸ เลื่อนตามที่ตัดสินใจ |
| 7 · ทดสอบ | ⬜ ยังไม่ได้ทำ |

> ### 🔴 ต้องรัน SQL ก่อนเปิดใช้งาน
> `sql/03_view_v_budgetgovernmentassetitem.sql` — **บังคับ**
> EF ผูก `OagwbgVBudgetgovernmentassetitem.Budgetgovernmentitemid` กับ view แล้ว
> ถ้ายังไม่รัน ทุกหน้าที่โหลดรายการครุภัณฑ์จะพังด้วย `ORA-00904: invalid identifier`
>
> `sql/01` STEP 2 (index) และ `sql/02` STEP 1 (backfill) ยังไม่รัน — ไม่ทำให้พัง แต่ควรรันให้ครบ

### ไฟล์ที่แก้ไปแล้ว

```
OAGBudget.DAL/Models/OagwbgBudgetgovernmentassetitem.cs      + Budgetgovernmentitemid, [NotMapped] ItemRowKey
OAGBudget.DAL/Models/OagwbgBudgetgovernmentitem.cs           + [NotMapped] RowKey
OAGBudget.DAL/Models/OagwbgVBudgetgovernmentassetitem.cs     + Budgetgovernmentitemid
OAGBudget.DAL/Models/OAGDBContextBase.cs                     mapping ทั้ง table และ view
OAGBudget.API/Services/Repository/BudgetService.cs           SaveBudgetGovernmentItem / SaveBudgetMoreCostcenterGovernmentItem
                                                             คืน Dictionary<string,int> + cascade ลบครุภัณฑ์
                                                             SaveBudgetGovernmentAssetItem รับ itemIdMap
                                                             DuplicatePlanData remap link
OAGBudget/Views/Budget/_partialView/_assetItemLinkCore.cshtml               [ใหม่] core ทั้งหมด
OAGBudget/Views/Budget/_partialView/_tabBudgetRequestInvestmentProjectAsset.cshtml            → Tree อ่านอย่างเดียว
OAGBudget/Views/Budget/_partialView/_tabBudgetRequestMoreCostcenterInvestmentProjectAsset.cshtml → Tree อ่านอย่างเดียว
OAGBudget/Views/Budget/_partialView/_modalProjectAssetReplace.cshtml        เพดาน/การผูก เปลี่ยนเป็นรายบรรทัด
OAGBudget/Views/Budget/BudgetRequestExpensesDetail.cshtml                   คอลัมน์ใหม่ + validation + payload
OAGBudget/Views/Budget/BudgetRequestMoreExpensesDetail.cshtml               เหมือนกัน
OAGBudget/Views/Budget/BudgetRequestMoreCostcenterExpensesDetail.cshtml     เหมือนกัน
OAGBudget/Views/Budget/BudgetRequestMoreCostcenterExpensesNew.cshtml        เหมือนกัน
```

`dotnet build OAGBudget.sln` → **0 Error**

### ข้อจำกัดที่ยอมรับไว้

1. ครุภัณฑ์ที่ `BUDGETGOVERNMENTITEMID IS NULL` **ลบผ่านหน้าจอไม่ได้** — `removeFunc` ใน
   `SaveBudgetGovernmentAssetItem` ข้ามแถวเหล่านี้เสมอ เพื่อกันไม่ให้ข้อมูลเดิมหายตอนผู้ใช้
   เปิดคำขอเก่ามากดบันทึก · ย้ายเข้ารายการได้ (update) แต่ลบไม่ได้
2. แท็บครุภัณฑ์ render สูงสุด **2,000 แถว** (คำขอ 45600 มี 121,710 แถว) แถวที่เกินจะไม่ถูกส่งกลับ
   ตอนบันทึก — ปลอดภัยเพราะแถวเหล่านั้นเป็น NULL ทั้งหมดจึงติดกฎข้อ 1
   ⚠️ ถ้าอนาคต backfill กลุ่มกำกวมจนมีค่า ต้องทบทวนข้อนี้ก่อน
3. ยังไม่มีทางย้ายครุภัณฑ์จากถัง "ยังไม่ระบุ" เข้ารายการผ่าน UI (แท็บเป็น read-only)
   ต้องทำในรอบถัดไปถ้าต้องการ

---

## 1. โจทย์

ปัจจุบันกรณีครุภัณฑ์ **"ขอทดแทน" (EQUIPMENTCASE = 'R')** ระบบบังคับให้ผู้ใช้ไปกรอกที่แท็บ **รายการครุภัณฑ์** (tab3) ของหน้า `BudgetRequestExpensesDetail`

ที่ต้องการเปลี่ยนเป็น:

1. ย้ายการบันทึกออกจากแท็บ → เปิดจาก **แถวในตารางรายการค่าใช้จ่าย** ของแท็บข้อมูลทั่วไป (tab1)
2. หน้าใหม่ทำได้ทุกอย่างเหมือนแท็บเดิม (ค้นหา / เลือกหลายรายการ / กรอกเอง / ลบ)
3. **เพิ่มใหม่:** บันทึกว่าครุภัณฑ์แต่ละเครื่องมาจาก *รายการค่าใช้จ่ายบรรทัดไหน* → ต้องเพิ่มคอลัมน์ในตาราง

---

## 2. โครงสร้างปัจจุบัน (ตรวจสอบแล้ว)

### 2.1 Flow การบันทึก

```
Browser  BudgetRequestExpensesDetail.cshtml
   │       budgetItemList[]        (รายการค่าใช้จ่าย — tab1, อยู่ใน JS ล้วน)
   │       assetReplaceItemList[]  (รายการครุภัณฑ์  — tab3, อยู่ใน JS ล้วน)
   │  กดปุ่ม "บันทึก" ครั้งเดียว ส่งทั้งก้อน
   ▼
MVC      BudgetController.SaveBudgetRequestExpensesDetail          (:789)
   ▼
API      BudgetController.SaveBudgetRequestExpensesDetail          (:168)
   ▼
Service  BudgetService.SaveBudgetRequestExpensesDetail             (:1432)
            ├─ SaveBudgetGovernmentItem(data)                      (:1525)
            ├─ SaveBudgetDisbursementPlanItem(...)                 (:1633)
            └─ SaveBudgetGovernmentAssetItem(id, list, user)       (:1693)
   ▼
Oracle   OAGWBG_BUDGETGOVERNMENTITEM / OAGWBG_BUDGETGOVERNMENTASSETITEM
```

### 2.2 ไฟล์ที่เกี่ยวข้อง

| ไฟล์ | บทบาท |
|---|---|
| `OAGBudget/Views/Budget/BudgetRequestExpensesDetail.cshtml` | หน้าหลัก, ตาราง `#tblMain`, modal เพิ่มรายการค่าใช้จ่าย, validation ก่อน submit |
| `OAGBudget/Views/Budget/_partialView/_tabBudgetRequestInvestmentProjectAsset.cshtml` | แท็บ tab3 + ตาราง `#tableProjectAssetReplace` + `getAssetItemLimit()` |
| `OAGBudget/Views/Budget/_partialView/_modalProjectAssetReplace.cshtml` | modal ค้นหา/เลือกครุภัณฑ์ (Select2 AJAX + DataTables server-side) |
| `OAGBudget/Controllers/BudgetController.cs` | `:664 BudgetRequestExpensesDetail`, `:940 OpenAssetReplace`, `:958 SearchAssetReplace`, `:789 Save...` |
| `OAGBudget.API/Services/Repository/BudgetService.cs` | `:1432 Save...`, `:1525 SaveBudgetGovernmentItem`, `:1693 SaveBudgetGovernmentAssetItem`, `:8283 GetAssetList`, `:31859 DuplicatePlanData` |
| `OAGBudget.DAL/Models/OagwbgBudgetgovernmentassetitem.cs` | entity ของตาราง |
| `OAGBudget.DAL/Models/OagwbgVBudgetgovernmentassetitem.cs` | entity ของ view |
| `OAGBudget.DAL/Models/OAGDBContextBase.cs` | mapping `:3451` (table), `:14572` (view) |
| `OAGBudget.Models/Data/BudgetRequestExpenseDetailModel.cs` | DTO ที่ส่งจาก browser |

### 2.3 ตารางฝั่ง DB

| Object | ชนิด | หมายเหตุ |
|---|---|---|
| `OAGWBG_BUDGETGOVERNMENTITEM` | ตาราง | รายการค่าใช้จ่าย (tab1) — **ปลายทางของ link ใหม่** |
| `OAGWBG_BUDGETGOVERNMENTASSETITEM` | ตาราง | รายการครุภัณฑ์ (tab3) — **ต้องเพิ่มคอลัมน์ที่นี่** |
| `OAGWBG_V_BUDGETGOVERNMENTASSETITEM` | view | ที่หน้าจออ่าน — ต้อง `CREATE OR REPLACE` |
| `OAGWBG_R_BUDGETREQUEST_ASSET` | view (รายงาน) | depend อยู่ |
| `OAGWBG_R_BUDGETREQUEST_ASSET_MORE` | view (รายงาน) | depend อยู่ |
| `TRG_..._ID` + `SEQ_..._ID` | trigger/sequence | สร้าง ID (ไม่ใช่ IDENTITY) — ไม่ต้องแก้ |

โครงสร้างตาราง `OAGWBG_BUDGETGOVERNMENTASSETITEM` ปัจจุบัน:

```
ID NUMBER(10) NOT NULL   ASSETID NUMBER(10)        BUDGETGOVERNMENTID NUMBER(10)
BUDGETYEAR NUMBER(10)    DEPARTMENTID VARCHAR2(150) COSTCENTERID VARCHAR2(150)
ASSETNUMBER VARCHAR2(255) ASSETNAME VARCHAR2(255)   ASSETDETAIL VARCHAR2(500)
```

**Index: มีแค่ PK บน `ID` เท่านั้น** — ไม่มี index บน `BUDGETGOVERNMENTID` ทั้งที่ตารางมี 124,053 แถว

---

## 3. ⚠️ ข้อค้นพบสำคัญก่อนตัดสินใจ

### 3.1 [BLOCKER] มีงานค้างของคนอื่นทับซ้อนกับงานนี้อยู่แล้ว

`OAGBudget.API/Services/Repository/ReportService.cs:9371` มีคอมเมนต์ว่า:

> *"ตอนนี้แก้ที่ต้นเหตุแล้ว: OAGWBG_BUDGETGOVERNMENTASSETITEM มีคอลัมน์ BUDGETGOVERNMENTITEMID และ view join แบบ 1 แถว = 1 รายการค่าใช้จ่าย ... (ดู `sql_asset_item_link/04_view_r_budgetrequest_asset_more.sql`)"*

แต่ตรวจจริงแล้ว:

- คอลัมน์ `BUDGETGOVERNMENTITEMID` **ยังไม่มี** ทั้งใน PREPROD และ TEST
- โฟลเดอร์ `sql_asset_item_link/` **ไม่มีอยู่ใน workspace นี้** และไม่มีใน git history ของ `_brain_OAGBUDGET`
- view `OAGWBG_R_BUDGETREQUEST_ASSET_MORE` บน PREPROD ยัง `LEFT JOIN` ทั้ง asset item และ gov item ด้วย `BUDGETGOVERNMENTID` → ยังได้ผลคูณไขว้ M×N อยู่
- แต่โค้ด `ReportService` (แก้ล่าสุด 2026-08-20) **ถอดตรรกะหารซ้ำออกไปแล้ว**

**ผลคือรายงาน "รายละเอียดรายการคำของบประมาณประจำปี_ครุภัณฑ์" ตอนนี้แถวเบิ้ล/ยอดเกินบน PREPROD**

> **ต้องเคลียร์ก่อนเริ่ม:** ใครทำงานชิ้นนั้นค้างไว้ / มี SQL script ชุดนั้นอยู่ที่ไหน / จะรวมงานกันอย่างไร
> ถ้าต่างคนต่างทำ จะได้คอลัมน์ชื่อเดียวกันแต่ความหมายไม่ตรงกัน

### 3.2 [BLOCKER ด้านออกแบบ] ID ของรายการค่าใช้จ่ายยังไม่มีตอนที่ผู้ใช้จะผูกครุภัณฑ์

`budgetItemList` ในเบราว์เซอร์เก็บรายการที่ **ยังไม่ถูกบันทึก** ด้วย `id: 0`
ID จริงเกิดตอน `SaveBudgetGovernmentItem` insert ลง Oracle เท่านั้น

ซ้ำร้าย `SaveBudgetGovernmentItem` ใช้วิธี **"ลบทิ้งแล้วสร้างใหม่"** สำหรับแถวที่หายไปจาก list
→ ถ้าไม่จัดการ ครุภัณฑ์จะชี้ไป ID ที่ถูกลบไปแล้ว

นี่คือข้อจำกัดที่กำหนดว่าหน้าใหม่จะเป็น "หน้าจริง" ได้หรือไม่ (ดู §4)

### 3.3 หน้าอื่นใช้ของร่วมกันอยู่

| หน้า | partial ที่ใช้ | endpoint บันทึก |
|---|---|---|
| `BudgetRequestExpensesDetail` | `_tabBudgetRequestInvestmentProjectAsset` | `SaveBudgetRequestExpensesDetail` |
| `BudgetRequestMoreExpensesDetail` | **partial ตัวเดียวกัน** | **endpoint ตัวเดียวกัน** |
| `BudgetRequestMoreCostcenterExpensesDetail` | `_tabBudgetRequestMoreCostcenter...` | `SaveBudgetRequestMoreCostcenterExpensesDetail` |
| `BudgetRequestMoreCostcenterExpensesNew` | `_tabBudgetRequestMoreCostcenter...` | `SaveBudgetRequestMoreCostcenterExpensesNew` |

ทั้ง 4 หน้าเรียก `SaveBudgetGovernmentAssetItem` ตัวเดียวกัน (`:1511`, `:32917`, `:33714`)
→ **แก้ signature เมื่อไหร่ กระทบทั้ง 4 หน้า** ต้องตัดสินใจว่าจะทำครบทั้ง 4 หรือทำเฉพาะหน้าเดียวแล้วให้ที่เหลือส่ง `null`

### 3.4 กติกาเพดานจำนวนครุภัณฑ์จะเปลี่ยนความหมาย

ปัจจุบัน: `จำนวนครุภัณฑ์ทั้งใบ ≤ Σ(หน่วยนับ ของทุกบรรทัด)` และบังคับ "ต้องครบพอดี" เมื่อ EQUIPMENTCASE = 'R'
หลังเปลี่ยน: ควรเป็น `จำนวนครุภัณฑ์ของบรรทัด X ≤ หน่วยนับ ของบรรทัด X`

**เป็นการบีบให้แน่นขึ้น** ข้อมูลเดิมบางส่วนจะไม่ผ่านกฎใหม่ (ดู §6) → ต้องตัดสินใจว่าจะบังคับกับคำขอเก่าที่เปิดมาแก้ไขด้วยหรือไม่

### 3.5 การ duplicate คำขอจะทำ link พัง

`DuplicatePlanData` (`BudgetService.cs:31859`) คัดลอกทั้ง gov item และ asset item โดย set `Id = 0` ให้ Oracle แจก ID ใหม่
ถ้าไม่แก้ ครุภัณฑ์ของคำขอใหม่จะยังชี้ `BUDGETGOVERNMENTITEMID` ของ **คำขอเก่า**
→ ต้องทำ `Dictionary<int,int> itemIdMap` แล้ว remap
(`DuplicateProjectData` ไม่คัดลอก 2 ตารางนี้ — ไม่กระทบ)

### 3.6 ประสิทธิภาพ

ตารางมี 124K แถว แต่ไม่มี index บน `BUDGETGOVERNMENTID` → ทุกครั้งที่เปิดหน้ารายละเอียดค่าใช้จ่าย = full table scan
ควรใส่ index พร้อมกันในงานนี้ (อยู่ใน `sql/01`) — ได้ประโยชน์แม้ rollback ฟีเจอร์

---

## 4. ทางเลือกการออกแบบหน้าจอ — **ต้องเลือก 1 ข้อ**

### ตัวเลือก A — Modal เต็มจอในหน้าเดิม *(แนะนำ)*

คลิกไอคอนในแถว → เปิด Bootstrap `modal-fullscreen` หัวข้อ *"รายการครุภัณฑ์ทดแทน — <คำอธิบายรายการ>"* ข้างในคือของเดิมจาก tab3 ทั้งชุด

- ✅ ไม่ต้อง navigate → **แก้ปัญหา §3.2 ได้ทั้งหมด** ผูกกับ index ของแถวใน JS ก่อน แล้ว resolve เป็น ID จริงตอน save
- ✅ ไม่ต้องมี endpoint บันทึกใหม่ / ไม่มีปัญหาข้อมูลกำพร้าระหว่างทาง
- ✅ พฤติกรรม "กดบันทึกครั้งเดียวจบ" เหมือนเดิม ผู้ใช้ไม่ต้องเรียนรู้ใหม่
- ✅ งานน้อยที่สุด เสี่ยงน้อยที่สุด
- ⚠️ ไม่มี URL ของตัวเอง (bookmark / เปิดแท็บใหม่ไม่ได้)
- ⚠️ ทางเทคนิคไม่ใช่ "หน้าใหม่" ตามที่โจทย์เขียน แม้หน้าตาจะเต็มจอเหมือนหน้าใหม่

### ตัวเลือก B — หน้าใหม่จริง + บันทึกหน้าแม่ก่อน

คลิก → ถาม "ต้องบันทึกก่อน ยืนยันหรือไม่" → save ทั้งฟอร์ม → `redirect /Budget/BudgetGovernmentItemAsset/{itemId}` → หน้านั้นบันทึกครุภัณฑ์ลง DB โดยตรง → กดกลับ

- ✅ ตรงตามโจทย์ มี URL จริง
- ✅ ข้อมูลลง DB ทันที ไม่มีสถานะค้างใน JS
- ❌ **ผู้ใช้ต้องกรอกแผนการใช้จ่ายให้ยอดตรงก่อน** ถึงจะเพิ่มครุภัณฑ์ได้ (validation ปัจจุบันบังคับยอดตรงก่อน save) — ขัดกับลำดับการทำงานจริง
- ❌ ต้องทำ endpoint + service + view ใหม่ทั้งชุด (~2 เท่าของ A)
- ❌ ต้องออกแบบ "ยกเลิก" ใหม่ เพราะข้อมูลลง DB ไปแล้ว

### ตัวเลือก C — หน้าใหม่จริง + save เฉพาะรายการค่าใช้จ่าย

เหมือน B แต่เพิ่ม endpoint เบา ๆ ที่บันทึกเฉพาะ gov + gov item ก่อน navigate (ข้าม validation แผนการใช้จ่าย)

- ✅ ตรงตามโจทย์ + ไม่บังคับกรอกแผนก่อน
- ❌ ต้องเพิ่ม endpoint ใหม่ที่บันทึก "ครึ่งเดียว" → คำขอค้างสถานะไม่สมบูรณ์ใน DB
- ❌ การแก้ที่ tab2/tab4 ที่ยังไม่ได้บันทึก **จะหาย** ตอน navigate ต้องเตือนผู้ใช้
- ❌ เสี่ยงสูงสุดในสามตัวเลือก

> **ข้อเสนอ:** เริ่มด้วย **A** — ได้ทั้งความสามารถและการผูกข้อมูลตามโจทย์ โดยไม่ต้องรื้อ flow การบันทึก
> ถ้าจำเป็นต้องมี URL แยกจริง ๆ ค่อยแยกออกเป็นหน้าทีหลังได้ เพราะ DB schema เหมือนกัน

---

## 5. ขั้นตอนการทำงาน (ยึดตัวเลือก A)

### Phase 1 — Database *(R1 — ต้องให้ DBA รัน)*

| ลำดับ | Script | ผลลัพธ์ |
|---|---|---|
| 1 | `sql/01_alter_table_add_column.sql` | เพิ่ม `BUDGETGOVERNMENTITEMID NUMBER(10)` + index 2 ตัว |
| 2 | `sql/02_backfill.sql` STEP 1 | เติมค่าให้คำขอที่มีรายการเดียว (1,213 แถว) |
| 3 | `sql/03_view_v_budgetgovernmentassetitem.sql` | view คายคอลัมน์ใหม่ |
| 4 | ตรวจ `user_objects` ว่า view รายงาน 2 ตัวยัง VALID | |

### Phase 2 — DAL / Model

- `OagwbgBudgetgovernmentassetitem.cs` : `public int? Budgetgovernmentitemid { get; set; }`
- `OagwbgVBudgetgovernmentassetitem.cs` : เพิ่ม property เดียวกัน
- `OAGDBContextBase.cs:3451` : map `.HasColumnName("BUDGETGOVERNMENTITEMID").HasPrecision(10)`
- `OAGDBContextBase.cs:14572` : map ฝั่ง view
- เพิ่ม `public string? ItemRowKey { get; set; }` (`[NotMapped]`) สำหรับ key ชั่วคราวจาก JS

### Phase 3 — API Service

| เมธอด | สิ่งที่ต้องแก้ |
|---|---|
| `SaveBudgetGovernmentItem` (:1525) | คืน `Dictionary<string,int>` (rowKey → ID จริง) และลบครุภัณฑ์ที่ผูกกับรายการที่ถูกลบทิ้ง |
| `SaveBudgetRequestExpensesDetail` (:1432) | รับ map แล้วส่งต่อให้ `SaveBudgetGovernmentAssetItem` |
| `SaveBudgetGovernmentAssetItem` (:1693) | resolve `ItemRowKey` → `Budgetgovernmentitemid`, เขียนลงทั้งตอน add และ update, เปลี่ยน dup-check เป็น `(govId, itemId, assetId)` |
| `DuplicatePlanData` (:31859) | remap `Budgetgovernmentitemid` ด้วย `itemIdMap` |
| `SaveBudgetRequestMoreCostcenterExpensesNew` (:32835) / `...Detail` (:33635) | ปรับตาม signature ใหม่ |

### Phase 4 — Frontend

- `BudgetRequestExpensesDetail.cshtml`
  - เพิ่ม column ในตาราง `#tblMain`: ปุ่ม + badge *"ครุภัณฑ์ n/หน่วยนับ"*
  - แนบ `rowKey` (GUID ฝั่ง client) ให้ทุก item ใน `budgetItemList`
  - ย้าย validation จาก "รวมทั้งใบ" → ตรวจรายบรรทัด ชี้ปัญหาเป็นรายแถว
  - ซ่อน/ถอด tab3 ตามที่ตกลง (ดู §7 ข้อ 3)
  - ตอน submit map `assetItems` ของแต่ละบรรทัดกลับเป็น array เดียวพร้อม `ItemRowKey`
- `_partialView/_modalExpenseItemAsset.cshtml` (ใหม่) — เนื้อหาเดิมของ tab3 แต่ผูก context เป็นรายบรรทัด **นี่คือที่เดียวที่แก้ไขข้อมูลได้**
- `_modalProjectAssetReplace.cshtml` — `getModalAssetLimit()` เปลี่ยนเป็นอ่านหน่วยนับของบรรทัดที่กำลังทำอยู่
- `_tabBudgetRequestInvestmentProjectAsset.cshtml` — **แปลงเป็น Tree อ่านอย่างเดียว** (ดู §5.1) **อย่าลบไฟล์** เพราะ `BudgetRequestMoreExpensesDetail` ยังใช้อยู่
- `_tabBudgetRequestMoreCostcenterInvestmentProjectAsset.cshtml` — ทำแบบเดียวกัน

### Phase 5.1 — แท็บ "รายการครุภัณฑ์" แบบ Tree (อ่านอย่างเดียว)

ถอดปุ่ม *เพิ่มรายการ / ลบรายการ*, checkbox และ `openProjectAssetReplaceModal()` ออกทั้งหมด เหลือเป็นมุมมองสรุป 2 ระดับ:

```
▼ 1. เก้าอี้สำนักงาน                       3,500.00 × 4 หน่วย    [ครุภัณฑ์ 4/4] ✅
     ├─ GF110000035535   เก้าอี้ผู้บริหาร      ครุภัณฑ์สำนักงาน
     ├─ GF110000035536   เก้าอี้ผู้บริหาร      ครุภัณฑ์สำนักงาน
     ├─ GF110000035537   เก้าอี้ทำงาน         ครุภัณฑ์สำนักงาน
     └─ GF110000035538   เก้าอี้ทำงาน         ครุภัณฑ์สำนักงาน
▼ 2. โต๊ะทำงาน                             8,000.00 × 2 หน่วย    [ครุภัณฑ์ 0/2] ⚠ ขาด 2
     └─ (ยังไม่ได้ระบุรายการครุภัณฑ์)
▼ ยังไม่ระบุรายการค่าใช้จ่าย                                      [3 รายการ]
     ├─ GF110000012001   ตู้เอกสาร           ครุภัณฑ์สำนักงาน
     └─ …
```

- node ระดับบน = รายการค่าใช้จ่าย (จาก `budgetItemList`) แสดง `itemdetail`, ราคา × หน่วยนับ, badge จำนวนครุภัณฑ์ที่ผูกแล้ว
- node ระดับล่าง = ครุภัณฑ์ที่ `Budgetgovernmentitemid` ตรงกับ node นั้น
- node พิเศษท้ายสุด = ครุภัณฑ์ที่ `Budgetgovernmentitemid IS NULL` (ข้อมูลเดิมที่ backfill ไม่ได้)
- render จาก `budgetItemList` + `assetReplaceItemList` ที่มีอยู่แล้วในหน้า **ไม่ต้องยิง API เพิ่ม**
- คลิก node บนเพื่อกระโดดไป tab1 แล้วเปิด modal ของบรรทัดนั้น (ทางลัด ไม่ใช่การแก้ไขในแท็บ)

### Phase 6 — รายงาน *(เลื่อนออกไปรอบถัดไป ตามที่ตัดสินใจ)*

- แก้ `OAGWBG_R_BUDGETREQUEST_ASSET` ให้ join ผ่าน `BUDGETGOVERNMENTITEMID` แทน hack `ROW_NUMBER()` ปัจจุบัน
- แก้ `OAGWBG_R_BUDGETREQUEST_ASSET_MORE` ให้ 1 แถว = 1 รายการค่าใช้จ่าย + `LISTAGG` ชื่อครุภัณฑ์
- ตรวจว่า `ReportService.cs:9376` (ที่ถอดตรรกะหารซ้ำไปแล้ว) ให้ผลถูกต้อง
- **ต้องเคลียร์เจ้าของงาน §3.1 ก่อนเริ่มรอบนี้**

### Phase 7 — ทดสอบ

1. สร้างคำขอใหม่ ครุภัณฑ์ 'R' 2 บรรทัด บรรทัดละ 2 หน่วย → ผูกครุภัณฑ์แยกกัน → บันทึก → เปิดใหม่ต้องแยกถูก
2. แก้คำขอเดิม เพิ่ม/ลบบรรทัด → ครุภัณฑ์ต้องตามไปถูก ไม่มีแถวกำพร้า
3. ลบบรรทัดที่มีครุภัณฑ์ → ครุภัณฑ์ต้องถูกลบตาม (**ไม่มี FK ช่วย — ต้องพิสูจน์ด้วยการ query จริง**)
4. duplicate คำขอ (`DuplicatePlanData`) → link ต้องชี้ item ของคำขอใหม่ ไม่ใช่ของเก่า
5. คำขอเก่าที่ backfill แล้ว เปิดมากดบันทึก → ครุภัณฑ์ต้องไม่ถูกล้าง
6. คำขอเก่าที่ `BUDGETGOVERNMENTITEMID IS NULL` → ต้องโผล่ในถัง "ยังไม่ระบุ" และ **ไม่ถูกลบทิ้งตอนบันทึก**
7. แท็บ Tree → นับจำนวนต่อบรรทัดถูก, badge ขาด/ครบถูก, node "ยังไม่ระบุ" แสดงเมื่อมีข้อมูลเท่านั้น
8. `BudgetRequestMoreExpensesDetail` + `MoreCostcenterExpensesDetail` + `MoreCostcenterExpensesNew` → ต้องไม่พัง
9. รัน query ตรวจ integrity ท้าย `02_backfill.sql` → ต้องได้ 0 แถวทั้งสองอัน
10. `dotnet build "D:\TFS\OAG Budget\OAGBudget.sln"` ต้อง 0 Error

---

## 6. ข้อมูลเดิม (สำรวจ PREPROD 2026-08-27)

`OAGWBG_BUDGETGOVERNMENTASSETITEM` = **124,053 แถว / 783 คำขอ**

| EQUIPMENTCASE | คำขอ | รายการค่าใช้จ่าย | แถวครุภัณฑ์ |
|---|---:|---:|---:|
| R (ขอทดแทน) | 760 | 978 | 124,023 |
| N (ขอเพิ่มเติม) | 18 | 23 | 23 |
| NULL | 5 | 7 | 7 |

ความเป็นไปได้ในการ backfill:

| กลุ่ม | คำขอ | แถวครุภัณฑ์ | ทำอย่างไร |
|---|---:|---:|---|
| มีรายการค่าใช้จ่าย 1 รายการ | 711 | 1,213 | ผูกอัตโนมัติ 100% |
| มี > 1 รายการ (กำกวม) | 68 | 122,836 | ต้องตัดสินใจ |
| ไม่มีรายการเลย (ขยะ) | 4 | 4 | ลบทิ้งได้ |

> **สำคัญ:** ในกลุ่มกำกวม `BUDGETGOVERNMENTID = 45600` ตัวเดียวกิน **121,710 แถว** (98% ของทั้งตาราง) เกิดจากการกด *"เลือกรายการทั้งหมด"* สมัยที่ยังไม่มีเพดาน
> ตัดตัวนี้ออก เหลือของจริงที่กำกวมแค่ **67 คำขอ / 1,126 แถว** — จัดการด้วยมือได้สบาย

---

## 7. การตัดสินใจ

### สรุปครบแล้ว (2026-08-27)

| # | ประเด็น | ✅ ที่เลือก |
|---|---|---|
| 1 | รูปแบบหน้าจอ | **A — Modal เต็มจอในหน้าเดิม** ไม่ navigate |
| 2 | ขอบเขตหน้าจอ | **ทั้ง 4 หน้าที่ใช้ของร่วมกัน** |
| 3 | ข้อมูลเดิมกลุ่มกำกวม 67 คำขอ | **ปล่อย NULL** ให้ผู้ใช้ระบุเองตอนแก้ไขครั้งถัดไป |
| 4 | ข้อมูลขยะคำขอ 45600 (121,710 แถว) | **เก็บไว้ ไม่แตะ** |
| 5 | งานค้าง §3.1 (รายงาน) | **ทำทีหลัง** — แก้หน้าจอให้จบก่อน แยกเป็นงานรอบถัดไป |
| 6 | แท็บ "รายการครุภัณฑ์" เดิม | **เก็บไว้ อ่านอย่างเดียว แสดงเป็น Tree** รายการค่าใช้จ่าย → รายการครุภัณฑ์ |
| 7 | FK constraint | **ไม่ใส่** — อิงตามตารางอื่นในระบบที่ไม่เชื่อม FK |

### ผลจากการตัดสินใจข้างต้น

**จาก #2 — ทำทั้ง 4 หน้า** ขอบเขตงานเพิ่มจากแผนเดิม:

- `_partialView/_tabBudgetRequestMoreCostcenterInvestmentProjectAsset.cshtml` ต้องแก้คู่ขนานกับตัวหลัก
- `BudgetRequestMoreExpensesDetail.cshtml` (ใช้ partial + endpoint ตัวเดียวกับหน้าหลัก) ได้ของใหม่ไปด้วยอัตโนมัติ — แต่ต้องทดสอบแยก
- `BudgetRequestMoreCostcenterExpensesDetail.cshtml` และ `...New.cshtml` ต้องแก้ตาราง `#tblMain` + ย้าย validation เหมือนหน้าหลัก
- `BudgetRequestMoreCostcenterExpensesDetailModel` ต้องรับ `ItemRowKey` ด้วย
- `SaveBudgetRequestMoreCostcenterExpensesNew` (:32835) และ `...Detail` (:33635) ต้องรับ id map จาก `SaveBudgetGovernmentItem` เหมือนกัน

**จาก #3 + #4 — ยังมีแถวที่ `BUDGETGOVERNMENTITEMID IS NULL` อยู่ในระบบถาวร** จึงต้องออกแบบเพิ่ม:

1. หน้าจอต้องมีถัง **"ยังไม่ระบุรายการค่าใช้จ่าย"** แสดงครุภัณฑ์ที่ยังไม่ได้ผูก พร้อมทางให้ย้ายเข้ารายการ
2. `SaveBudgetGovernmentAssetItem` **ห้ามลบแถวที่ยังเป็น NULL ทิ้ง** เพียงเพราะไม่พบใน list ที่ส่งมา — ต้องแยกให้ชัดระหว่าง "ผู้ใช้ลบ" กับ "ยังไม่เคยแตะ"
3. validation กฎใหม่ (ครุภัณฑ์ของบรรทัด X ≤ หน่วยนับของบรรทัด X) ควรบังคับ **เฉพาะบรรทัดที่ผู้ใช้แตะในรอบนั้น** ไม่งั้นคำขอเก่าจะบันทึกไม่ผ่านทั้งใบ
4. ⚠️ **คำขอ 45600 จะเปิดหน้าไม่ไหว** — `_tabBudgetRequestInvestmentProjectAsset.cshtml` ทำ `Json.Serialize` ของ asset list ทั้งก้อนลง HTML ถ้ามี 121,710 แถวหน้าจะค้าง (เป็นปัญหาที่มีอยู่แล้ววันนี้ ไม่ใช่ของใหม่) เมื่อเลือกเก็บข้อมูลไว้ ควรใส่ guard เช่นจำกัดจำนวนที่ render หรือโหลดแบบ lazy ต่อบรรทัด

**จาก #7 — ไม่มี FK** สอดคล้องกับ schema จริง (`OAGWBG` มี FK แค่ 3 ตัวจาก 66 ตาราง) แต่แปลว่า **ความถูกต้องของ link ขึ้นกับโค้ด 100%** จึงต้อง:

- `SaveBudgetGovernmentItem` ลบครุภัณฑ์ที่ผูกกับรายการที่ถูกลบ **ในทรานแซกชันเดียวกัน** — ไม่มี DB คอยกันให้
- `DuplicatePlanData` remap ให้ครบ ไม่งั้นได้ link ข้ามคำขอแบบเงียบ ๆ
- ใส่ query ตรวจ integrity ไว้ใน `02_backfill.sql` (link ข้ามคำขอ / ชี้ item ที่ไม่มีอยู่) แล้วรันเป็นระยะหลัง deploy

**จาก #5 — เลื่อนงานรายงาน** Phase 5 ถอดออกจากรอบนี้ ผลคือ:

- รายงาน "รายละเอียดรายการคำของบประมาณประจำปี_ครุภัณฑ์" **ยังยอดเบิ้ลอยู่เหมือนเดิม** ระหว่างรอบนี้ (สถานะไม่แย่ลง แต่ก็ไม่ดีขึ้น)
- view `OAGWBG_R_BUDGETREQUEST_ASSET` / `_MORE` ไม่ถูกแตะ → หลังรัน `03_view_...sql` ต้องเช็คว่ายัง VALID (เพิ่มคอลัมน์ต่อท้ายไม่กระทบ แต่ต้องยืนยัน)

---

## 8. ระดับความเสี่ยง

| งาน | ระดับ | เหตุผล |
|---|---|---|
| `ALTER TABLE ADD` + index | R2 | เพิ่มคอลัมน์ NULL ได้ ย้อนกลับด้วย `DROP COLUMN` |
| `CREATE OR REPLACE VIEW` | R2 | มี DDL เดิมเก็บไว้ใน `99_rollback.sql` |
| Backfill STEP 1 | R1 | แก้ข้อมูล ควร CTAS สำรองก่อน |
| Backfill STEP 2 (เดา) | R1 | เดาผิดได้ ต้องสุ่มตรวจ |
| ลบข้อมูลคำขอ 45600 | **R0** | ลบถาวร — ต้องขออนุมัติ + สำรองก่อน |
| แก้ `SaveBudgetGovernmentAssetItem` | R1 | กระทบ 4 หน้าพร้อมกัน |
| แก้ view รายงาน | R1 | ตัวเลขในรายงานเปลี่ยน ต้อง reconcile กับของเดิม |
