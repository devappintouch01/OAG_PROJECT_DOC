# Roadmap การแก้ไข: รายงานคำขอ ระดับภาพรวม — เพิ่มช่องรหัส E-Budgeting / รายจ่ายย่อย

## สรุปปัญหา

หน้า **รายงานคำขอ ระดับภาพรวม** (`BudgetRequestSummaryDetail`) ต้องเพิ่ม **2 คอลัมน์ใหม่** ในระดับที่ 5 (GrandChild):

| คอลัมน์ | ที่มา | Field |
|---------|-------|-------|
| รหัส E-Budgeting | `APPS.OAGINV_GL_SUBACCOUNT_EBUDGETING_V` | `EBUDGETING_CODE` |
| รหัสบัญชีย่อย/รายจ่ายย่อย | `APPS.OAGINV_GL_SUBACCOUNT_EBUDGETING_V` | `SEGMENT_11` |

**JOIN KEY:** `Code` (ใน `OagwbgVBudgetrequestsummary`) = `CATEGORY_CONCAT_SEGS` (ใน EBUDGETING View)

---

## สาเหตุที่ต้องแก้ไข

### ข้อมูลในฐานข้อมูล
- Database View `OAGWBG_V_BUDGETREQUESTSUMMARY` มีคอลัมน์ `CODE` → เป็น `CATEGORY_CONCAT_SEGS` ที่ใช้เป็น JOIN KEY
- View `APPS.OAGINV_GL_SUBACCOUNT_EBUDGETING_V` มี `EBUDGETING_CODE` และ `SEGMENT_11` ที่ต้องการ
- Model `SubAccountEbudgetingResult` มีอยู่แล้วใน `OAGBudget.Models\RawData\` พร้อม fields: `CategoryConcatSegs`, `EbudgetingCode`, `Segment11`
- Pattern การ Query และ Join แบบเดียวกันนี้ใช้อยู่แล้วใน `ReportService.cs` (line ~4969–4991)

### สาเหตุที่ยังไม่แสดง
1. **Model** `OagwbgVBudgetrequestsummary.cs` ไม่มี property `EbudgetingCode` และ `Segment11`
2. **Service** `GetGroupBudgetSummaryPlan()` ไม่ได้ Query EBUDGETING View และ JOIN ข้อมูล
3. **View** ไม่มีคอลัมน์แสดงผลทั้งสอง field

---

## แผนการแก้ไข (ลำดับ 1–5)

### ขั้นตอนที่ 1 — เพิ่ม Properties ใน DAL Model

**ไฟล์:** `OAGBudget.DAL\Models\OagwbgVBudgetrequestsummary.cs`

เพิ่ม non-mapped properties (ไม่ต้องเพิ่มใน `MOENDBContextBase.cs` เพราะ property ที่ไม่ถูก configure จะไม่ถูก map โดย EF Core):

```csharp
// Non-mapped — populated by service via JOIN with OAGINV_GL_SUBACCOUNT_EBUDGETING_V
public string? EbudgetingCode { get; set; }
public string? Segment11 { get; set; }
```

---

### ขั้นตอนที่ 2 — แก้ไข BudgetService: เพิ่ม Code ใน GrandChild Select

**ไฟล์:** `OAGBudget.API\Services\Repository\BudgetService.cs`  
**Method:** `GetGroupBudgetSummaryPlan()` (~line 6295–6320)

ตรวจสอบว่า `Code = x.Code` มีอยู่ใน Select ของ `budgetRequestSummaryGrandChildList` (ทำไปแล้วในรอบก่อน ✅)

---

### ขั้นตอนที่ 3 — แก้ไข BudgetService: Query EBUDGETING View และ JOIN

**ไฟล์:** `OAGBudget.API\Services\Repository\BudgetService.cs`  
**Method:** `GetGroupBudgetSummaryPlan()`  
**ตำแหน่ง:** หลัง `budgetRequestSummaryGrandChildList` ถูกสร้างเสร็จ (หลัง line ~6320)

```csharp
// Query OAGINV_GL_SUBACCOUNT_EBUDGETING_V
var subAccountSql = @"SELECT STRUCTURE_NAME AS StructureName,
                             CATEGORY_CONCAT_SEGS AS CategoryConcatSegs,
                             SEGMENT_11 AS Segment11,
                             EBUDGETING_CODE AS EbudgetingCode
                      FROM APPS.OAGINV_GL_SUBACCOUNT_EBUDGETING_V";

var subAccountList = await _context.Database
    .SqlQueryRaw<SubAccountEbudgetingResult>(subAccountSql)
    .ToListAsync();

var subAccountDict = subAccountList
    .GroupBy(x => x.CategoryConcatSegs)
    .ToDictionary(g => g.Key ?? "", g => g.First());

// Populate EbudgetingCode and Segment11 on each GrandChild item
foreach (var item in budgetRequestSummaryGrandChildList)
{
    if (!string.IsNullOrEmpty(item.Code) && subAccountDict.TryGetValue(item.Code, out var sa))
    {
        item.EbudgetingCode = sa.EbudgetingCode;
        item.Segment11 = sa.Segment11;
    }
}
```

**using ที่ต้องเพิ่ม:**
- `using OAGBudget.Models.RawData;` (ถ้ายังไม่มี)

---

### ขั้นตอนที่ 4 — แก้ไข View: Header และ GrandChild rows

**ไฟล์:** `OAGBudget\Views\Budget\_partialView\_tabBudgetRequestSummaryDetail.cshtml`

#### 4.1 Header — เปลี่ยนจาก 1 column รวม เป็น 2 columns แยก

เปลี่ยนจาก (ปัจจุบันหลังรอบก่อน):
```html
<th class="text-center" width="30%">รายการ</th>
<th class="text-center">รหัส E-Budgeting / รายจ่ายย่อย</th>
<th class="text-center">คำอธิบาย</th>
```
เป็น:
```html
<th class="text-center" width="30%">รายการ</th>
<th class="text-center">รหัส E-Budgeting</th>
<th class="text-center">รหัสบัญชีย่อย/รายจ่ายย่อย</th>
<th class="text-center">คำอธิบาย</th>
```

#### 4.2 Level 1 (Product), Level 2 (Activity), Level 3 (ExpenseType), Level 4 (Category)

ทุกระดับนี้มี `<td class="text-center"></td>` อยู่ 1 เซลล์ว่าง → เพิ่มเป็น 2 เซลล์ว่าง:
```html
<td class="text-center"></td>
<td class="text-center"></td>
```

#### 4.3 Level 5 (GrandChild) — แสดงข้อมูลจริง

เปลี่ยนจาก (ปัจจุบันหลังรอบก่อน):
```html
<td class="text-center">@detail?.Code</td>
```
เป็น:
```html
<td class="text-center">@detail?.EbudgetingCode</td>
<td class="text-center">@detail?.Segment11</td>
```

---

### ขั้นตอนที่ 5 — แก้ไข JavaScript: อัปเดต column index

การเพิ่ม column ทำให้ index ของ column ที่ใช้ใน JS เปลี่ยน:

**ก่อนแก้ไข (6 columns):**
- index 0: รายการ
- index 1: (เดิมว่าง)
- index 2: คำอธิบาย
- index 3: คำของบประมาณ ← `td:eq(3)`
- index 4: คำของบประมาณเพิ่มเติม ← `td:eq(4)`
- index 5: งบประมาณรวม ← `td:eq(5)`

**หลังแก้ไข (7 columns):**
- index 0: รายการ
- index 1: รหัส E-Budgeting
- index 2: รหัสบัญชีย่อย/รายจ่ายย่อย
- index 3: คำอธิบาย
- index 4: คำของบประมาณ ← `td:eq(4)` (เลื่อนจาก 3 → 4)
- index 5: คำของบประมาณเพิ่มเติม ← `td:eq(5)` (เลื่อนจาก 4 → 5)
- index 6: งบประมาณรวม ← `td:eq(6)` (เลื่อนจาก 5 → 6)

**ตำแหน่งใน JS ที่ต้องแก้ (ใน functions `updateActivityLevel` และ `updateProductLevel`):**

| เดิม | ใหม่ | ใช้สำหรับ |
|------|------|-----------|
| `td:eq(3) input` | `td:eq(4) input` | Totalrequestamount (Activity/Product) |
| `td:eq(4) input` | `td:eq(5) input` | Totalkeptcentral (Activity/Product) |
| `td:eq(5) input` | `td:eq(6) input` | Totalsummaryamount (Activity/Product) |

---

## ลำดับไฟล์ที่ต้องแก้ไขทั้งหมด

| ลำดับ | ไฟล์ | การเปลี่ยนแปลง | สถานะ |
|-------|------|----------------|-------|
| 1 | `OAGBudget.DAL\Models\OagwbgVBudgetrequestsummary.cs` | เพิ่ม `EbudgetingCode`, `Segment11` | ยังไม่ได้ทำ |
| 2 | `OAGBudget.API\Services\Repository\BudgetService.cs` | เพิ่ม `Code = x.Code` ใน GrandChild Select | ✅ ทำแล้ว |
| 3 | `OAGBudget.API\Services\Repository\BudgetService.cs` | Query EBUDGETING View + JOIN + Populate | ยังไม่ได้ทำ |
| 4 | `OAGBudget\Views\Budget\_partialView\_tabBudgetRequestSummaryDetail.cshtml` | แก้ Header + Level 1–4 cells + GrandChild cells + JS index | บางส่วนแล้ว (ต้องแก้เพิ่ม) |

---

## Verify แนวทาง

1. Build project — ตรวจสอบว่าไม่มี compile error
2. เปิดหน้า BudgetRequestSummaryDetail
3. ขยายแถวจนถึงระดับที่ 5 (GrandChild)
4. ตรวจสอบว่าคอลัมน์ "รหัส E-Budgeting" แสดงค่า `ebudgeting_code` จาก EBUDGETING View
5. ตรวจสอบว่าคอลัมน์ "รหัสบัญชีย่อย/รายจ่ายย่อย" แสดงค่า `segment_11`
6. ตรวจสอบว่าระดับ 1–4 ไม่มีข้อมูลในสองคอลัมน์นั้น (แสดงว่าง)
7. ตรวจสอบว่าการคำนวณ Totalkeptcentral / Totalsummaryamount ยังทำงานถูกต้อง (JS index)
