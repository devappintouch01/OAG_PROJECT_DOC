# Roadmap #282 — ปรับชื่อช่อง "เลขที่โอน" ใน KTB Payment Text File

## สาเหตุของปัญหา

หน้ารายงาน KTB Payment Text File มี dropdown ชื่อ **TransferRound** ที่ใช้ข้อมูลคนละแหล่ง ขึ้นอยู่กับประเภทการโอนที่เลือก:

| ประเภทการโอน (TransferType) | แหล่งข้อมูล Dropdown | ชื่อที่ถูกต้อง |
|---|---|---|
| ประเภทอื่น (1, 3, 4) | `OagwbgBudgettransfers` → `DropdownRoundNo` | เลขที่โอน |
| เงินกัน (TransferType = 2) | `OagwbgBudgetreserveds` → `DropdownRoundNoReserved` | เลขที่เงินกัน |

แต่ label ที่แสดงในหน้าจอ **แสดงแค่ "เลขที่โอน" อย่างเดียวตลอด** ไม่ว่าจะเลือก TransferType อะไร ทำให้ผู้ใช้ที่เลือก TransferType = 2 (เงินกัน) อาจสับสน เพราะ dropdown นั้นจริง ๆ เป็น "เลขที่เงินกัน"

---

## แผนการแก้ไข

### ไฟล์ที่ต้องแก้ไข

**1. `OAGBudget\Views\Report\ReportBudgetTransferKTBPaymentTextFile.cshtml` (บรรทัด 87)**

เปลี่ยน label จาก:
```html
<label class="col-form-label">เลขที่โอน <span class="text-danger">*</span></label>
```
เป็น:
```html
<label class="col-form-label">เลขที่โอน / เลขที่เงินกัน <span class="text-danger">*</span></label>
```

**2. (ทางเลือก) `OAGBudget.DAL\Models\BudgetTransferKTB.cs` (บรรทัด 18)**

เปลี่ยน error message validation จาก:
```csharp
[Required(ErrorMessage = "กรุณาเลือกเลขที่โอน")]
```
เป็น:
```csharp
[Required(ErrorMessage = "กรุณาเลือกเลขที่โอน / เลขที่เงินกัน")]
```

---

## การ Verify หลังแก้ไข

1. เปิดหน้า รายงานโอนเงินงบประมาณ KTB Payment Text File
2. ตรวจสอบว่า label ของช่อง TransferRound แสดงเป็น **"เลขที่โอน / เลขที่เงินกัน *"** ถูกต้อง
3. ทดสอบ validation เมื่อไม่ได้เลือก TransferRound → ข้อความ error ต้องตรงกับที่แก้ไข

---

## สรุป Scope

| รายการ | ไฟล์ | บรรทัด | ประเภทการเปลี่ยนแปลง |
|---|---|---|---|
| แก้ label หน้าจอ | `ReportBudgetTransferKTBPaymentTextFile.cshtml` | 87 | **จำเป็น** |
| แก้ error message | `BudgetTransferKTB.cs` | 18 | ทางเลือก |

การแก้ไขนี้เป็น **UI label change เท่านั้น** ไม่กระทบ logic, database, หรือ API ใด ๆ

---

## TFS Changeset

| Changeset | วันที่ | รายละเอียด |
|---|---|---|
| 18955 | 2026-06-02 | fix #282: update label for transfer number field to include reserve fund case |

On the KTB Payment Text File report (รายงาน KTB Payment Text File), the
field label "เลขที่โอน" did not reflect that it also covers reserve fund
transfer numbers (เลขที่เงินกัน) when TransferType = 2.

Changed in 2 files:
- OAGBudget/Views/Report/ReportBudgetTransferKTBPaymentTextFile.cshtml
- OAGBudget.DAL/Models/BudgetTransferKTB.cs

Changes:
1. Field label (line 87): changed from "เลขที่โอน" to "เลขที่โอน / เลขที่เงินกัน"
   so the UI correctly describes both transfer types
2. Validation error message (line 18): changed from "กรุณาเลือกเลขที่โอน" to
   "กรุณาเลือกเลขที่โอน / เลขที่เงินกัน" to match the updated label

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
