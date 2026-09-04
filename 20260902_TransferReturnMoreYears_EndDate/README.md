# PROD — หน้า "โอนกลับข้ามหลายปี" แสดงรายการงบประมาณที่ End date ไปแล้ว

**วันที่วิเคราะห์:** 2026-09-02
**หน้าจอ:** โอนกลับข้ามหลายปี — `BudgetTransferReturnMoreYearsDetail`
**สถานะ:** วิเคราะห์จาก source code เท่านั้น — **ยังไม่ได้ยืนยันกับ DB** (ต่อ VPN ไม่ได้ ดูข้อ 7)
**ความรุนแรง:** กลาง–สูง — ผู้ใช้เลือก master data ที่ตายแล้วได้ และระบบไม่มีด่านตรวจซ้ำตอนบันทึก/จอง/ยืนยัน

> ⚠️ **ข้อจำกัดของเอกสารนี้ (NO MAGIC)**
> ตอนวิเคราะห์ **เชื่อมต่อฐานข้อมูลไม่ได้** — `Test-NetConnection` ล้มเหลวทั้ง
> TEST `10.3.22.20:1561` และ PREPROD `172.16.11.19:1521` (ยังไม่ได้เปิด F5 BIG-IP Edge Client)
> และ **เรียก `tf` ไม่ได้** ในเครื่องนี้ (ไม่พบ `TF.exe` ตาม path ใน CLAUDE.md) จึงเทียบ history ของไฟล์ไม่ได้
> ⇒ ข้อ 3 คือข้อเท็จจริงจากโค้ด (ยืนยันได้ 100%) / ข้อ 5 คือสมมติฐานที่ **ต้องรัน SQL ในข้อ 7 เพื่อฟันธง**

---

## 1. อาการ

บน **PROD** หน้า *โอนกลับข้ามหลายปี* → ปุ่ม **เพิ่มรายการ** (modal `#modalAddItem`)
รายการงบประมาณ / master data ที่ **End date (วันหมดอายุ) ผ่านไปแล้ว** ยังโผล่ให้เลือกใน dropdown

---

## 2. เส้นทางข้อมูลของ dropdown บนหน้านี้

Controller: [`OAGBudget/Controllers/BudgetController.cs:5333-5372`](../../OAGBudget/Controllers/BudgetController.cs#L5333-L5372)
View: [`OAGBudget/Views/Budget/BudgetTransferReturnMoreYearsDetail.cshtml`](../../OAGBudget/Views/Budget/BudgetTransferReturnMoreYearsDetail.cshtml)

| ช่องบน modal | โหลดจาก | เมธอดปลายทาง | เงื่อนไขกรองจริง | กรองวันหมดอายุ? |
|---|---|---|---|---|
| แผนงาน | `ViewBag.DropdownBudgetPlan` | [`MasterService.GetBudgetPlanCode`](../../OAGBudget.API/Services/Repository/MasterService.cs#L2745) | `STATUS='Y' AND SUMMARYFLAG='N'` | — (view ไม่มีคอลัมน์วันที่) |
| ผลผลิต | AJAX `GetProductByPlanId` | [`MasterService.cs:3338`](../../OAGBudget.API/Services/Repository/MasterService.cs#L3338) | `SUMMARYFLAG='N'` เท่านั้น | ❌ **ไม่กรองแม้แต่ `STATUS='Y'`** |
| กิจกรรม | AJAX `GetActivityByPlanId` | [`MasterService.cs:3362`](../../OAGBudget.API/Services/Repository/MasterService.cs#L3362) | `SUMMARYFLAG='N' AND ENABLED_FLAG='Y'` | ✅ (ใช้ enabled flag) |
| **ประเภทค่าใช้จ่าย** | `ViewBag.DropdownBudgetType` ([BudgetController.cs:5361](../../OAGBudget/Controllers/BudgetController.cs#L5361)) | [`BudgetService.GetBudgetTypeFromCategory`](../../OAGBudget.API/Services/Repository/BudgetService.cs#L25373) | `STATUS='Y'` เท่านั้น | ❌ **ไม่กรอง `INACTIVE_DATE`** |
| **รายการงบประมาณ** | AJAX `GetCategorySegment1011` ([cshtml:641](../../OAGBudget/Views/Budget/BudgetTransferReturnMoreYearsDetail.cshtml#L641)) | [`BudgetService.cs:25507`](../../OAGBudget.API/Services/Repository/BudgetService.cs#L25507) → [`CategorySegment1011BaseQuery`](../../OAGBudget.API/Services/Repository/BudgetService.cs#L25493) | `INACTIVE_DATE IS NULL` | ⚠️ **มีกรอง แต่ใช้กฎคนละแบบกับที่อื่น** |
| **รหัสงบประมาณ** | `ViewBag.DropdownBudgetCode` ([BudgetController.cs:5363](../../OAGBudget/Controllers/BudgetController.cs#L5363)) | [`MasterService.GetBudgetCode`](../../OAGBudget.API/Services/Repository/MasterService.cs#L3512) | `SUMMARYFLAG='N'` เท่านั้น | ❌ **ไม่กรองแม้แต่ `STATUS='Y'`** |

---

## 3. สิ่งที่ยืนยันได้จากโค้ด (ข้อเท็จจริง)

### 3.1 `รหัสงบประมาณ` โหลด master ทั้งก้อน ไม่กรองสถานะเลย

[`OAGBudget.API/Services/Repository/MasterService.cs:3512-3521`](../../OAGBudget.API/Services/Repository/MasterService.cs#L3512-L3521)

```csharp
public async Task<List<SelectListItem>> GetBudgetCode()
{
    return await _context.OagwbgVExtOagglBudgetCodeVs
        .Where(s => s.Summaryflag == "N")            // ❌ ไม่มี s.Status == "Y"
        .Select(s => new SelectListItem { Text = s.Code + " : " + s.Name, Value = s.Id.ToString() })
        .OrderBy(x => x.Value).ToListAsync();
}
```

`OAGWBG_V_EXT_OAGGL_BUDGET_CODE_V` **มี** คอลัมน์ `STATUS` / `STATUSNAME`
([`OagwbgVExtOagglBudgetCodeV.cs`](../../OAGBudget.DAL/Models/OagwbgVExtOagglBudgetCodeV.cs)) แต่โค้ดไม่ได้ใช้
⇒ รหัสงบประมาณที่ปิดใช้งาน/หมดอายุแล้วในระบบ EBS **ยังแสดงครบทุกตัว**

หน้านี้เดิมเคยโหลดแบบ cascade (`GetBudgetCodeByCategoryid`) แล้วถูก**ยกเลิกไป**
— ดูคอมเมนต์ [BudgetController.cs:5362](../../OAGBudget/Controllers/BudgetController.cs#L5362)
และโค้ดเก่าที่ comment ทิ้งไว้ [cshtml:651-675](../../OAGBudget/Views/Budget/BudgetTransferReturnMoreYearsDetail.cshtml#L651-L675)
การเปลี่ยนมาเป็น "โหลดทั้งหมด" คือจุดที่ทำให้ตัวกรองหายไป

### 3.2 `ประเภทค่าใช้จ่าย` ไม่กรอง `INACTIVE_DATE`

[`OAGBudget.API/Services/Repository/BudgetService.cs:25373-25382`](../../OAGBudget.API/Services/Repository/BudgetService.cs#L25373-L25382)

```csharp
var categoryBudgets = await _context.OagwbgVExtOaginvCategoryCodesVs
    .Where(x => x.Status == "Y" && x.BudgetTypeId != null && x.BudgetTypeCode != null)
    // ❌ ไม่มีเงื่อนไข InactiveDate
    .Select(x => new { x.BudgetTypeId, x.BudgetTypeCode }).Distinct().ToListAsync();
```

### 3.3 `รายการงบประมาณ` ใช้กฎ `INACTIVE_DATE IS NULL` ซึ่ง**ไม่ตรงกับที่อื่นในระบบ**

[`OAGBudget.API/Services/Repository/BudgetService.cs:25493-25505`](../../OAGBudget.API/Services/Repository/BudgetService.cs#L25493-L25505)

```csharp
private IQueryable<OagwbgVExtOaginvCategoryCodesV> CategorySegment1011BaseQuery()
{
    return _context.OagwbgVExtOaginvCategoryCodesVs
        .Where(x => x.Status == "Y"
                 && x.BudgetPlanId != null
                 && x.BudgetTypeId != null
                 && x.BudgetPlanStatus != "Y"
                 && x.BudgetTypeStatus != "Y"
                 && x.InactiveDate == null          // ⚠️ เข้มกว่าที่อื่น
                 && (...))
        .OrderBy(x => x.Code);
}
```

**สำคัญ:** `INACTIVE_DATE IS NULL` **เข้มกว่า** `INACTIVE_DATE IS NULL OR INACTIVE_DATE > SYSDATE`
มันจะ**ซ่อน**รายการที่ยังไม่หมดอายุ (End date เป็นอนาคต) ทิ้งไปด้วย
⇒ **ตามโค้ดชุดนี้ ช่อง "รายการงบประมาณ" ไม่ควรแสดงรายการที่ End date ไปแล้วได้เลย**
นี่คือจุดที่ต้องไปยืนยันต่อในข้อ 5

### 3.4 ไม่มีการตรวจซ้ำตอนบันทึก / จอง / ยืนยัน

- `SaveBudgetTransferReturnMoreYearsDetail` — [BudgetService.cs](../../OAGBudget.API/Services/Repository/BudgetService.cs#L25507)
- `ReserveBudgetTransferReturnMoreYearsDetail` — เช็คแค่ status `80101` และ "มีรายการอย่างน้อย 1"
- `ConfirmBudgetTransferReturnMoreYearsDetail` — เช็คแค่ status `80401`

ไม่มีที่ใดตรวจว่า `Categoryid` / `Budgetcodeid` ที่ส่งมายัง active อยู่หรือไม่
⇒ ต่อให้ปิดรูที่ dropdown ใบเก่าที่บันทึกไว้แล้วก็ยัง**จอง/ยืนยันผ่านได้** และไปแตกทีหลังฝั่ง interface

### 3.5 ตัดประเด็น cache ออกได้

`MasterService` มี `GetOrCreateDropdownAsync` + `ReportDropdownCacheTtl` (10 นาที)
[`MasterService.cs:288-332`](../../OAGBudget.API/Services/Repository/MasterService.cs#L288-L332)
แต่ **ไม่มี call site เลย** — dropdown ทุกตัวยิง DB สด ⇒ ไม่ใช่ปัญหา cache ค้าง

---

## 4. หน้าจออื่นเคยเจอเรื่องเดียวกันและแก้ไปแล้ว (precedent)

หน้า **โอนเปลี่ยนแปลงงบประมาณ (BudgetAdjust TransferIn)** เคยมีอาการเดียวกัน แล้วแก้ด้วยการ
**แตกเมธอดใหม่** ไม่แก้ของเดิม (เพราะของเดิมถูกใช้ร่วมกับหน้ารายงาน)

[`OAGBudget.API/Services/Repository/BudgetService.cs:25333-25346`](../../OAGBudget.API/Services/Repository/BudgetService.cs#L25333-L25346)

```csharp
// ใช้เฉพาะหน้าโอนเปลี่ยนแปลงงบประมาณ (BudgetAdjust TransferIn) — เพิ่มกรอง InactiveDate
public async Task<List<SelectListItem>> GetCategoryByBudgetTypeAndPlanActive(...)
    ... && (x.InactiveDate == null || x.InactiveDate > DateTime.Now) ...
```

ใช้งานที่ [`BudgetAdjustDetail_TransferIn_Edit.cshtml:746`](../../OAGBudget/Views/Budget/_partialView/BudgetAdjustDetail_TransferIn_Edit.cshtml#L746)
**หน้าโอนกลับข้ามหลายปีไม่ได้รับการแก้รอบนั้น** — ยังใช้ `GetCategorySegment1011` และ `GetBudgetCode` ตัวเดิม

---

## 5. กฎ "ยังไม่หมดอายุ" ในระบบมี 4 แบบ ไม่ตรงกันเลย

| กฎ | ตัวอย่างจุดที่ใช้ | ผล |
|---|---|---|
| `INACTIVE_DATE IS NULL OR INACTIVE_DATE > SYSDATE` | [BudgetService.cs:25344](../../OAGBudget.API/Services/Repository/BudgetService.cs#L25344), [MasterService.cs:986](../../OAGBudget.API/Services/Repository/MasterService.cs#L986), [MasterService.cs:4848](../../OAGBudget.API/Services/Repository/MasterService.cs#L4848) | ✅ ถูกต้อง |
| `INACTIVE_DATE IS NULL` | [BudgetService.cs:25501](../../OAGBudget.API/Services/Repository/BudgetService.cs#L25501) (หน้านี้) | ⚠️ เข้มเกิน — ซ่อนของที่ End date เป็นอนาคต |
| `STATUS='Y'` อย่างเดียว | [BudgetService.cs:25379](../../OAGBudget.API/Services/Repository/BudgetService.cs#L25379) | ❌ ไม่ดูวันหมดอายุ |
| ไม่กรองอะไรเลย (แค่ `SUMMARYFLAG='N'`) | [MasterService.cs:3516](../../OAGBudget.API/Services/Repository/MasterService.cs#L3516), [MasterService.cs:3350](../../OAGBudget.API/Services/Repository/MasterService.cs#L3350) | ❌ ต้นเหตุหลัก |

**นี่คือ root cause เชิงระบบ:** ไม่มีจุดเดียวที่นิยามคำว่า "master data ที่ยังใช้ได้" แต่ละหน้าจึงเขียนกันเอง

---

## 6. สมมติฐานสำหรับ "รายการงบประมาณ" โดยเฉพาะ (ต้องฟันธงด้วยข้อ 7)

ถ้าผู้ใช้เห็นของหมดอายุที่ช่อง **รายการงบประมาณ** จริง ๆ (ไม่ใช่ช่องรหัสงบประมาณ)
เป็นไปได้ 3 ทางเท่านั้น เพราะโค้ดใน workspace นี้กรองไว้แล้ว:

| # | สมมติฐาน | วิธีพิสูจน์ |
|---|---|---|
| **H1** | build บน PROD **เก่ากว่า** source ชุดนี้ (ยังไม่มีบรรทัด `InactiveDate == null`) | เทียบ `FileVersion` ของ PROD กับ `0.3.149.0` ใน [OAGBudget.csproj:13](../../OAGBudget/OAGBudget.csproj#L13) |
| **H2** | คอลัมน์ `INACTIVE_DATE` ใน view เป็น `NULL` ทั้งที่ EBS โชว์ End Date (view ดึงคนละคอลัมน์กับที่ user เห็น) | รัน SQL Q1/Q2 ข้อ 7 |
| **H3** | ที่ผู้ใช้เห็นจริง ๆ คือคอลัมน์ **รหัสงบประมาณ** / **ประเภทค่าใช้จ่าย** (ข้อ 3.1 / 3.2) ซึ่งไม่กรองเลยแน่นอน | ขอ screenshot + ชื่อรายการที่เห็น แล้วรัน Q3 |

> **H3 คือทางที่เป็นไปได้มากที่สุด** เพราะเป็นเพียงทางเดียวที่อธิบายอาการได้โดยไม่ต้องสมมติอะไรเพิ่ม

---

## 7. SQL ที่ต้องรันเพื่อยืนยัน (ยังรันไม่ได้ — รอ VPN)

```sql
-- Q1: view มีคอลัมน์ INACTIVE_DATE และมีค่าจริงไหม
SELECT COUNT(*) AS total,
       COUNT(INACTIVE_DATE) AS has_inactive_date,
       COUNT(CASE WHEN INACTIVE_DATE <= SYSDATE THEN 1 END) AS already_expired
FROM   OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V;

-- Q2: DDL ของ view — ดูว่า INACTIVE_DATE map มาจากคอลัมน์ไหนของ EBS
SELECT TEXT FROM ALL_VIEWS
WHERE  VIEW_NAME = 'OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V';

-- Q3: รายการที่หมดอายุแล้วแต่ยังหลุด filter ของหน้าจอนี้
SELECT ID, CODE, NAME, STATUS, INACTIVE_DATE
FROM   OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V
WHERE  STATUS = 'Y'
AND    INACTIVE_DATE IS NOT NULL
AND    INACTIVE_DATE <= SYSDATE
ORDER  BY INACTIVE_DATE DESC;

-- Q4: รหัสงบประมาณที่ปิดใช้งานแล้วแต่ dropdown ยังโชว์ (ยืนยันข้อ 3.1)
SELECT STATUS, COUNT(*) FROM OAGWBG_V_EXT_OAGGL_BUDGET_CODE_V
WHERE  SUMMARYFLAG = 'N' GROUP BY STATUS;

-- Q5: ใบโอนกลับข้ามหลายปีที่บันทึกไว้แล้วและอ้าง category ที่หมดอายุ (ประเมิน blast radius)
SELECT r.BUDGETTRANSFERID, r.ID, r.CATEGORYID, c.NAME, c.INACTIVE_DATE
FROM   OAGWBG_BUDGETRECEIVE r
JOIN   OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V c ON c.ID = r.CATEGORYID
WHERE  r.BUDGETRECEIVETYPE = 'T'
AND    c.INACTIVE_DATE IS NOT NULL AND c.INACTIVE_DATE <= SYSDATE;
```

---

## 8. แนวทางแก้ที่เสนอ

### 8.1 กฎกลางหนึ่งเดียว

นิยาม "ยังใช้ได้" = `INACTIVE_DATE IS NULL OR INACTIVE_DATE > SYSDATE` (+ `STATUS='Y'`)
ทำเป็น extension method / predicate ตัวเดียวใน `BudgetService` แล้วให้ทุกที่เรียกใช้

### 8.2 แก้เฉพาะจุดของหน้านี้ (R2 — ย้อนกลับง่าย)

| ไฟล์ | แก้อะไร |
|---|---|
| [`MasterService.cs:3516`](../../OAGBudget.API/Services/Repository/MasterService.cs#L3516) | เพิ่ม `&& s.Status == "Y"` ใน `GetBudgetCode()` |
| [`BudgetService.cs:25379`](../../OAGBudget.API/Services/Repository/BudgetService.cs#L25379) | เพิ่ม `&& (x.InactiveDate == null \|\| x.InactiveDate > DateTime.Now)` |
| [`BudgetService.cs:25501`](../../OAGBudget.API/Services/Repository/BudgetService.cs#L25501) | เปลี่ยน `x.InactiveDate == null` → `(x.InactiveDate == null \|\| x.InactiveDate > DateTime.Now)` |
| [`MasterService.cs:3350`](../../OAGBudget.API/Services/Repository/MasterService.cs#L3350) | เพิ่ม `&& p.Status == "Y"` ใน `GetProductByPlanId()` |

### 8.3 ด่านที่สอง (server-side validation)

ใน `SaveBudgetTransferReturnMoreYearsDetail` / `Reserve...` ตรวจว่า `Categoryid` + `Budgetcodeid`
ยัง active ก่อนบันทึก/จอง — ถ้าไม่ผ่านให้ตอบ error ระบุชื่อรายการที่หมดอายุ

---

## 9. ⚠️ DISSENT / ความเสี่ยงก่อนลงมือแก้

| หัวข้อ | ประเมิน |
|---|---|
| **Blast radius** | `GetBudgetCode()` ถูกใช้ผ่าน `DropdownBudgetCode()` ใน **15 หน้าจอ** ([BudgetController.cs](../../OAGBudget/Controllers/BudgetController.cs) บรรทัด 1839, 1922, 1971, 1979, 2410, 2590, 2624, 2654, 2802, 3099, 3734, 3865, 4083, 4352, 5157, 5363) — แก้ที่เดียวกระทบทุกหน้า |
| **ผลข้างเคียงที่ต้องระวัง** | ใบเก่าที่อ้างรหัสที่ปิดไปแล้ว → dropdown จะไม่มี option ตรงกับค่าเดิม → หน้าจอ **แสดงว่าง** ต้องเติม option ของค่าที่บันทึกไว้กลับเข้าไปเสมอ (แบบเดียวกับที่ `GetCategoryByBudgetTypeAndPlan` เดิมถูกกันไว้ไม่ให้กระทบหน้ารายงาน) |
| **Reversibility** | **R2** — แก้ `.Where()` ล้วน ๆ ย้อนกลับได้ทันที |
| **Scope drift** | ที่ร้องมาคือ "หน้าโอนกลับข้ามหลายปี" — ถ้าจะทำ 8.1 (กฎกลางทั้งระบบ) ถือว่า **เกิน scope** ควรแยกเป็นงานที่สอง |
| **ยังไม่รู้** | ตัวเลข End date จริงบน PROD, เวอร์ชัน build บน PROD, DDL ของ view |

---

## 10. Next step

1. เปิด **F5 BIG-IP Edge Client** แล้ว connect → รัน Q1–Q5 ในข้อ 7
2. ขอ screenshot จากผู้ใช้ ระบุว่า "รายการที่หมดอายุ" ที่เห็นอยู่ใน dropdown **ช่องไหน** (ช่วยฟันธง H1/H2/H3)
3. เช็ค `FileVersion` ที่ deploy บน PROD เทียบกับ `0.3.149.0`
4. ได้ผลแล้วค่อยเลือกแก้ตาม 8.2 (+ 8.3) แล้ว build → `tf get` → `tf checkin`
