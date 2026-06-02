# Roadmap #256 — เพิ่มช่อง "รายจ่ายย่อย" ในรายงานรายละเอียดการโอนเงินจัดสรรงบประมาณรายจ่ายประจำปี

> **อัปเดต 2026-06-03**: เพิ่มข้อมูลจาก SA — แหล่งข้อมูลที่ถูกต้องคือ View `OAGINV_GL_SUBACCOUNT_EBUDGETING_V` field `SEGMENT_11` ไม่ใช่ `Expensetypename` ส่งผลให้ขั้นตอนที่ 2 และ 3 เปลี่ยนแปลงอย่างมีนัยสำคัญ

---

## แหล่งข้อมูลที่ถูกต้อง (จาก SA)

| ข้อมูล | แหล่งที่มา |
|---|---|
| รายจ่ายย่อย | View `APPS.OAGINV_GL_SUBACCOUNT_EBUDGETING_V` → field `SEGMENT_11` |
| Join key (TransferType=1) | `OagwbgRBudgetallocatetransfer.Code` = `OAGINV_GL_SUBACCOUNT_EBUDGETING_V.CATEGORY_CONCAT_SEGS` |
| Join key (TransferType=2) | ไม่ต้อง join — `OagwbgRBudgetTransfer.Segment11` มีอยู่โดยตรง |

---

## สาเหตุของปัญหา

คอลัมน์ "รายจ่ายย่อย" ยังไม่มีในรายงาน เนื่องจาก:

1. **`TransferDetailReportItem`** (internal class ใน `ReportService.cs`) ยังไม่มี property `ExpenseTypeName`
2. **`GetTransferDetailTypeAllocateTransfer()`** ไม่มีการ JOIN `OAGINV_GL_SUBACCOUNT_EBUDGETING_V` เพื่อดึง `Segment11`
3. **`GetTransferDetailTypeReserveTransfer()`** ไม่ได้ map `Segment11` ที่มีอยู่แล้วใน `OagwbgRBudgetTransfer`
4. **Header array** ในฟังก์ชัน `ReportBudgetAllocateTransferDetail()` มี 9 คอลัมน์ ไม่มีคอลัมน์ "รายจ่ายย่อย"

---

## สิ่งที่เปลี่ยนแปลงจากแผนเดิม (เทียบกับ roadmap v1)

| จุด | แผนเดิม (v1) | แผนใหม่ (v2 — ตาม SA) | สถานะ |
|---|---|---|---|
| แหล่งข้อมูล TransferType=1 | `x.Expensetypename` | `Segment11` จาก JOIN `OAGINV_GL_SUBACCOUNT_EBUDGETING_V` | **ต้องแก้ไขใหม่** |
| แหล่งข้อมูล TransferType=2 | `null` | `x.Segment11` (มีอยู่แล้วใน model) | **ต้องแก้ไขใหม่** |
| โครงสร้าง Excel (Step 4) | เพิ่ม col "รายจ่ายย่อย" | เหมือนเดิม | **ทำแล้ว — ไม่ต้องเปลี่ยน** |
| `TransferDetailReportItem.ExpenseTypeName` | เพิ่ม property | เหมือนเดิม | **ทำแล้ว — ไม่ต้องเปลี่ยน** |

> **หมายเหตุ**: Step 4 (โครงสร้าง Excel, header, column widths, merges) ที่ทำไปแล้วใช้ได้ ไม่ต้องเปลี่ยน
> Step 1 (`TransferDetailReportItem`) ที่ทำไปแล้วใช้ได้ ไม่ต้องเปลี่ยน
> **ต้องแก้ไขเฉพาะ Step 2 และ Step 3** ใน `ReportService.cs`

---

## ขอบเขตการแก้ไข

ไฟล์ที่ต้องแก้ไข (เฉพาะที่ยังไม่ได้ทำ หรือทำผิด):
- `OAGBudget.API\Services\Repository\ReportService.cs`

---

## แผนการแก้ไข (v2)

### ✅ ขั้นตอนที่ 1 — เพิ่ม property ใน `TransferDetailReportItem` (ทำแล้ว)

```csharp
public string? ExpenseTypeName { get; set; }
```

---

### ❌ ขั้นตอนที่ 2 — แก้ไข `GetTransferDetailTypeAllocateTransfer()` (TransferType = 1)

**ต้องแก้ไข** — โค้ดปัจจุบันใช้ `x.Expensetypename` ซึ่งผิด

**Pattern ที่ถูกต้อง** (เหมือนกับที่ใช้ใน `ReportBudgetAllocateTransferSummary` บรรทัด ~4969–4991):

```csharp
// 1. ดึงข้อมูลจาก OagwbgRBudgetallocatetransfer ก่อน (เหมือนเดิม)
var rawItems = await query
    .Where(x => x.Totaltransferamount > 0)
    .OrderBy(x => x.Departmentid)
    .ThenBy(x => x.Costcenterid)
    .ThenBy(x => x.NoteSeq)
    .ToListAsync();

// 2. Query OAGINV_GL_SUBACCOUNT_EBUDGETING_V ด้วย Raw SQL
var subAccountSql = @"SELECT STRUCTURE_NAME AS StructureName,
                             CATEGORY_CONCAT_SEGS AS CategoryConcatSegs,
                             SEGMENT_11 AS Segment11,
                             EBUDGETING_CODE AS EbudgetingCode
                      FROM APPS.OAGINV_GL_SUBACCOUNT_EBUDGETING_V";

var subAccountList = await _context.Database
    .SqlQueryRaw<SubAccountEbudgetingResult>(subAccountSql)
    .ToListAsync();

// 3. Build dictionary สำหรับ lookup โดยใช้ CategoryConcatSegs เป็น key
var subAccountDict = subAccountList
    .GroupBy(x => x.CategoryConcatSegs)
    .ToDictionary(g => g.Key ?? "", g => g.First());

// 4. Map ผลลัพธ์พร้อม Segment11
return rawItems.Select(x => new TransferDetailReportItem
{
    // ... fields เดิม ...
    ExpenseTypeName = subAccountDict.TryGetValue(x.Code ?? "", out var sa) ? sa.Segment11 : null
}).ToList();
```

> Join key: `OagwbgRBudgetallocatetransfer.Code` = `OAGINV_GL_SUBACCOUNT_EBUDGETING_V.CATEGORY_CONCAT_SEGS`

---

### ❌ ขั้นตอนที่ 3 — แก้ไข `GetTransferDetailTypeReserveTransfer()` (TransferType = 2)

**ต้องแก้ไข** — โค้ดปัจจุบัน `ExpenseTypeName = null` ซึ่งผิด

`OagwbgRBudgetTransfer` มี field `Segment11` อยู่แล้ว map โดยตรงได้เลย:

```csharp
// เปลี่ยนจาก:
ExpenseTypeName = null

// เป็น:
ExpenseTypeName = x.Segment11
```

---

### ✅ ขั้นตอนที่ 4 — โครงสร้าง Excel (ทำแล้ว ไม่ต้องเปลี่ยน)

| จุด | สถานะ |
|---|---|
| Header merges (9 → 10 คอลัมน์) | ✅ ทำแล้ว |
| Headers array เพิ่ม "รายจ่ายย่อย" | ✅ ทำแล้ว |
| tableData projection เพิ่ม `ExpenseType` | ✅ ทำแล้ว |
| Data row writing เลื่อน col 4→5, เพิ่ม col 4 | ✅ ทำแล้ว |
| "รวมทั้งสิ้น" row เลื่อน col 5,6 → 6,7 | ✅ ทำแล้ว |
| Column widths เพิ่ม col 4 | ✅ ทำแล้ว |
| Border style `...,9)` → `...,10)` | ✅ ทำแล้ว |

---

## ข้อควรระวัง

- `OAGINV_GL_SUBACCOUNT_EBUDGETING_V` query ดึงข้อมูลทั้งหมดก่อน แล้วค่อย join in-memory (เหมือน pattern เดิม) เพื่อหลีกเลี่ยง cross-context join
- `SubAccountEbudgetingResult` model มีอยู่แล้วที่ `OAGBudget.Models\RawData\SubAccountEbudgetingResult.cs` — ใช้ได้เลย ไม่ต้องสร้างใหม่
- ควรทดสอบกับข้อมูลจริงเพื่อยืนยันว่า `Code` ตรงกับ `CATEGORY_CONCAT_SEGS` และ `Segment11` มีค่า

---

## สรุป (v2)

| ขั้นตอน | ไฟล์ | สถานะ | รายละเอียด |
|---|---|---|---|
| 1 | `ReportService.cs` | ✅ ทำแล้ว | เพิ่ม `ExpenseTypeName` ใน `TransferDetailReportItem` |
| 2 | `ReportService.cs` | ❌ ต้องแก้ใหม่ | Join `OAGINV_GL_SUBACCOUNT_EBUDGETING_V` และ map `Segment11` แทน `Expensetypename` |
| 3 | `ReportService.cs` | ❌ ต้องแก้ใหม่ | Map `x.Segment11` แทน `null` สำหรับ TransferType=2 |
| 4 | `ReportService.cs` | ✅ ทำแล้ว | โครงสร้าง Excel 10 คอลัมน์ พร้อม "รายจ่ายย่อย" |
