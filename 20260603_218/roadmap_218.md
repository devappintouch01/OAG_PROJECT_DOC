# Roadmap 218 — เพิ่ม Column "รหัส E-Budgeting" ในรายงาน พรบ.

## 1. สาเหตุของปัญหา

- รายงาน **ReportBudgetAllocate** (รายงาน พรบ.) มี Column B ชื่อ **"รหัส E-Budgeting"** อยู่ใน header แล้ว แต่โค้ดที่ดึงข้อมูลมาใส่ใน cell จริงๆ ถูก **comment ออก** ทั้งหมด
- โค้ดที่ถูก comment ออกมีอยู่ใน **3 จุด** ของไฟล์ `OAGBudget.API\Services\Repository\ReportService.cs`:
  1. การ query `subAccountLookup` จาก View (บรรทัด 1304–1306) — ใช้ `_context.OaginvGlSubaccountEbudgetingVs` แบบ DbSet ซึ่ง **ไม่ได้ register** ใน EBSContext
  2. การใส่ค่า column B (E-Budgeting) และ column C (Segment11) ในเส้นทาง "เลือกแผนงาน" (บรรทัด 1592–1594)
  3. การใส่ค่า column B และ C ใน helper method `CreateSheet_BudgetYearStyle()` (บรรทัด 2010–2012)
- ผลลัพธ์คือ column B ในรายงาน Excel ว่างเปล่าทุกแถว

### ปัญหาเพิ่มเติมที่พบระหว่างแก้ไข

- `AdjustToContents()` ใน ClosedXML throw `SixLabors.Fonts.InvalidFontFileException` เมื่อใช้ font `TH Sarabun New` บน server — เกิดใน **4 จุด** ของ `ReportBudgetAllocate` / `CreateSheet_BudgetYearStyle` ทำให้รายงาน return 500 ทุกครั้ง

## 2. การแก้ไขที่ดำเนินการแล้ว ✅

ไฟล์ที่แก้ไข: **`OAGBudget.API\Services\Repository\ReportService.cs`**

### จุดที่ 1 — แทนที่ subAccountLookup query ด้วย Raw SQL + try/catch

เปลี่ยนจาก DbSet (ไม่ได้ register) เป็น `SqlQueryRaw<SubAccountEbudgetingResult>` พร้อมห่อ try/catch เพื่อให้รายงานยังออกได้แม้ Oracle view ไม่ตอบสนอง:

```csharp
Dictionary<string, SubAccountEbudgetingResult> subAccountLookup;
try
{
    var subAccountSql = @"SELECT STRUCTURE_NAME AS StructureName,
                                 CATEGORY_CONCAT_SEGS AS CategoryConcatSegs,
                                 SEGMENT_11 AS Segment11,
                                 EBUDGETING_CODE AS EbudgetingCode
                          FROM APPS.OAGINV_GL_SUBACCOUNT_EBUDGETING_V";
    var subAccountList = await _context.Database
        .SqlQueryRaw<SubAccountEbudgetingResult>(subAccountSql)
        .ToListAsync();
    subAccountLookup = subAccountList
        .GroupBy(x => x.CategoryConcatSegs)
        .ToDictionary(g => g.Key ?? "", g => g.First());
}
catch
{
    subAccountLookup = new Dictionary<string, SubAccountEbudgetingResult>();
}
```

### จุดที่ 2 — Restore parameter ใน `CreateSheet_BudgetYearStyle()`

```csharp
private void CreateSheet_BudgetYearStyle(
    XLWorkbook wb, int budgetYear, string planName,
    IEnumerable<OagwbgRBudgetallocate> planRows,
    Dictionary<string, SubAccountEbudgetingResult> subAccountLookup)
```

### จุดที่ 3 — ส่ง subAccountLookup เข้า CreateSheet_BudgetYearStyle

```csharp
CreateSheet_BudgetYearStyle(wb, model.BudgetYear.Value, planGroup.Key.Planname, planGroup.AsEnumerable(), subAccountLookup);
```

### จุดที่ 4 — Uncomment populate column B/C ในเส้นทาง PlanID

```csharp
subAccountLookup.TryGetValue(item.Code ?? "", out var subAccount);
ws.Cell(row, 2).Value = subAccount?.EbudgetingCode ?? "";
ws.Cell(row, 3).Value = subAccount?.Segment11 ?? "";
```

### จุดที่ 5 — Uncomment populate column B/C ใน `CreateSheet_BudgetYearStyle()`

```csharp
subAccountLookup.TryGetValue(item.Code ?? "", out var subAccount);
ws.Cell(row, 2).Value = subAccount?.EbudgetingCode ?? "";
ws.Cell(row, 3).Value = subAccount?.Segment11 ?? "";
```

### จุดที่ 6 — แก้ Font error จาก `AdjustToContents()` (4 จุด)

ห่อทุก `AdjustToContents()` ใน ReportBudgetAllocate region ด้วย `try/catch`:

| บรรทัด (หลังแก้ไข) | Path |
|---|---|
| ~1625 | เงื่อนไข 2 (PlanID) ชุดที่ 1 |
| ~1789 | เงื่อนไข 2 (PlanID) ชุดที่ 2 |
| ~1812 | เงื่อนไข "ไม่มีข้อมูล" (เปลี่ยนเป็น fixed width แทน) |
| ~2043 | `CreateSheet_BudgetYearStyle()` |

```csharp
try { ws.Columns(1, 7).AdjustToContents(); } catch { }
```

## 3. Logic การ Join ข้อมูล

- Join ด้วย: `item.Code` (จาก `OagwbgRBudgetallocate`) = `CategoryConcatSegs` (จาก View)
- Column B ← `EbudgetingCode`
- Column C ← `Segment11`

## 4. Verify

- [x] Build สำเร็จ — 0 Error
- [ ] Export รายงาน พรบ. เลือก BudgetYear เท่านั้น → ตรวจ column B มีค่า E-Budgeting code
- [ ] Export รายงาน พรบ. เลือก BudgetYear + PlanID → ตรวจ column B เช่นกัน
- [ ] เปรียบเทียบค่า column B กับ View `OAGINV_GL_SUBACCOUNT_EBUDGETING_V` ตรงกับ Code ของแถวนั้น
