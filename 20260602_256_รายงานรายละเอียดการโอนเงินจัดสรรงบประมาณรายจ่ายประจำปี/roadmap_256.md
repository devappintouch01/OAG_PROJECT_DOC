# Roadmap #256 — เพิ่มช่อง "รายจ่ายย่อย" ในรายงานรายละเอียดการโอนเงินจัดสรรงบประมาณรายจ่ายประจำปี

## สาเหตุของปัญหา

ข้อมูล "รายจ่ายย่อย" (`Expensetypename`) มีอยู่ในฐานข้อมูลแล้ว (ใน View `OagwbgRBudgetallocatetransfer`) แต่ยังไม่ได้นำมาแสดงในรายงาน เนื่องจาก:

1. **`TransferDetailReportItem`** (internal class ใน `ReportService.cs` บรรทัด 5901–5927) ยังไม่มี property `ExpenseTypeName`
2. **`GetTransferDetailTypeAllocateTransfer()`** (บรรทัด 5762–5824) ใช้ `Expensetypeid` เฉพาะเป็น filter แต่ไม่ได้ select `Expensetypename` มาเก็บในผลลัพธ์
3. **Header array** ในฟังก์ชัน `ReportBudgetAllocateTransferDetail()` (บรรทัด 5659) มี 9 คอลัมน์ ไม่มีคอลัมน์ "รายจ่ายย่อย"
4. **`OagwbgRBudgetTransfer`** (TransferType = 2 "ใบโอนกลับ") ไม่มี field `Expensetypeid`/`Expensetypename` ใน model — ต้องตรวจสอบว่า View ฐานข้อมูลรองรับหรือไม่

---

## ขอบเขตการแก้ไข

รายงานที่ได้รับผลกระทบ:
- **TransferType = 1** (ใบโอนจัดสรร) — ไฟล์ `รายละเอียดการโอนเงินจัดสรรงบประมาณรายจ่ายประจำปี.xlsx`
- **TransferType = 2** (ใบโอนกลับ) — อาจต้องตรวจสอบ View ฐานข้อมูลก่อน

ไฟล์ที่ต้องแก้ไข:
- `OAGBudget.API\Services\Repository\ReportService.cs`

---

## แผนการแก้ไข

### ขั้นตอนที่ 1 — เพิ่ม property ใน `TransferDetailReportItem`
ไฟล์: `ReportService.cs` บรรทัด ~5901

เพิ่ม property:
```csharp
public string? ExpenseTypeName { get; set; }
```

---

### ขั้นตอนที่ 2 — Map ข้อมูลใน `GetTransferDetailTypeAllocateTransfer()`
ไฟล์: `ReportService.cs` บรรทัด ~5796–5822

เพิ่มการ map ใน `.Select(x => new TransferDetailReportItem { ... })`:
```csharp
ExpenseTypeName = x.Expensetypename,
```

---

### ขั้นตอนที่ 3 — Map ข้อมูลใน `GetTransferDetailTypeReserveTransfer()` (TransferType = 2)
ไฟล์: `ReportService.cs` บรรทัด ~5872–5898

- ตรวจสอบว่า View `OAGWBG_R_BUDGET_TRANSFER` ในฐานข้อมูลมี column `EXPENSETYPENAME` หรือไม่
- ถ้ามี → เพิ่มใน `OagwbgRBudgetTransfer.cs` และ map ใน Select
- ถ้าไม่มี → ใส่ค่าว่าง `ExpenseTypeName = null`

---

### ขั้นตอนที่ 4 — เพิ่มคอลัมน์ "รายจ่ายย่อย" ในรายงาน Excel (TransferType = 1)
ไฟล์: `ReportService.cs` ฟังก์ชัน `ReportBudgetAllocateTransferDetail()` บรรทัด ~5619–5744

**4.1** แก้ไข header merge จาก 9 คอลัมน์ → 10 คอลัมน์ (บรรทัดที่ใช้ `Merge()` ทั้งหมดในส่วน header):
```csharp
// เปลี่ยน ...9).Merge() → ...10).Merge()
```

**4.2** แก้ไข headers array (บรรทัด 5659):
```csharp
string[] headers = { "ลำดับ", "สำนักงาน", "รายการ", "รายจ่ายย่อย", "ประเภทงบประมาณ", "รหัสงบประมาณ", "จำนวนเงิน", "ชื่อบัญชี", "เลขที่บัญชี", "หมายเหตุ" };
```

**4.3** แก้ไข tableData projection (บรรทัด ~5674–5686) เพิ่ม field:
```csharp
ExpenseType = x.ExpenseTypeName,
```

**4.4** แก้ไข data row writing เลื่อน column index และเพิ่ม column ใหม่ (บรรทัด ~5696–5719):
```
Col 1 = ลำดับ (ไม่เปลี่ยน)
Col 2 = สำนักงาน (ไม่เปลี่ยน)
Col 3 = รายการ (ไม่เปลี่ยน)
Col 4 = รายจ่ายย่อย (ใหม่)
Col 5 = ประเภทงบประมาณ (เดิม col 4)
Col 6 = รหัสงบประมาณ (เดิม col 5)
Col 7 = จำนวนเงิน (เดิม col 6)
Col 8 = ชื่อบัญชี (เดิม col 7)
Col 9 = เลขที่บัญชี (เดิม col 8)
Col 10 = หมายเหตุ (เดิม col 9)
```

**4.5** แก้ไข "รวมทั้งสิ้น" row (บรรทัด ~5724–5732) เลื่อน column จาก 5,6 → 6,7

**4.6** แก้ไข column widths (บรรทัด ~5734–5742) เพิ่ม column 4 และปรับ index ที่เหลือ:
```csharp
ws.Column(1).Width = 8;
ws.Column(2).Width = 25;
ws.Column(3).Width = 40;
ws.Column(4).Width = 20;  // รายจ่ายย่อย (ใหม่)
ws.Column(5).Width = 25;
ws.Column(6).Width = 30;
ws.Column(7).Width = 15;
ws.Column(8).Width = 40;
ws.Column(9).Width = 20;
ws.Column(10).Width = 40;
```

**4.7** แก้ไข border style ใน data row จาก `..., 9)` → `..., 10)`

---

## ข้อควรระวัง

- ตรวจสอบ **merge ranges** ทุกตำแหน่งในส่วน header ของรายงาน (มีหลายบรรทัดที่ merge ถึงคอลัมน์ 9) ต้องแก้เป็น 10 ทั้งหมด
- รายงาน **TransferType = 2** (ใบโอนกลับ) ใช้ฟังก์ชัน `ReportBudgetAllocateTransferReciveDetail()` แยกต่างหาก ต้องแก้ไขแยกถ้าต้องการเพิ่มคอลัมน์นั้นด้วย
- ควรทดสอบกับข้อมูลจริงใน EBS database เพื่อยืนยันว่า `Expensetypename` มีค่าและแสดงผลถูกต้อง

---

## สรุป

| ขั้นตอน | ไฟล์ | รายละเอียด |
|---|---|---|
| 1 | `ReportService.cs` | เพิ่ม `ExpenseTypeName` ใน `TransferDetailReportItem` |
| 2 | `ReportService.cs` | Map `Expensetypename` ใน `GetTransferDetailTypeAllocateTransfer()` |
| 3 | `ReportService.cs`, `OagwbgRBudgetTransfer.cs` | ตรวจสอบ/เพิ่ม ExpenseType สำหรับ TransferType=2 |
| 4 | `ReportService.cs` | เพิ่มคอลัมน์ "รายจ่ายย่อย" ในรายงาน Excel (headers, data, widths, merges) |
