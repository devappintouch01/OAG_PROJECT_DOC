# Roadmap การแก้ไข Issue 86 และ 266

## สรุปปัญหา

### Issue 86 — Summary ไม่ต้องแสดงระดับรายการที่ไม่มีข้อมูล

**สาเหตุ:**  
ใน `_tableBudgetCheck.cshtml` วน loop แสดงแถวทุกรายการจาก `Model` (List<OagwbgOagglViewInquiryFund>) โดยไม่มีการกรองออก  
ข้อมูลที่คืนมาจาก API (`GetBudgetCheck`) มาจาก view `OagwbgOagglViewInquiryFundV` ซึ่งรวมทั้ง account ระดับ Summary (`SUMMARY_FLAG = 'Y'`) และระดับ Detail ไว้ด้วยกัน  
บางแถวเป็น parent-account node ในระบบ Oracle GL ที่ไม่มียอดงบประมาณผูกไว้โดยตรง ทำให้ฟิลด์ amount ทุกค่า (`BUDGET_AMOUNT`, `ENCUMBRANCE_AMOUNT`, `ACTUAL_AMOUNT`, `FUNDS_AVAILABLE_AMOUNT`, `PREPARE_BUDGET_AMOUNT`) เป็น null หรือ 0 ส่งผลให้แถวนั้นปรากฏบนหน้าจอโดยแสดงข้อมูลว่างเปล่า

**ไฟล์ที่เกี่ยวข้อง:**
- `OAGBudget\Views\Budget\_partialView\_tableBudgetCheck.cshtml` (ชั้น Presentation)

**แนวทางแก้ไข:**  
เพิ่มเงื่อนไขใน `@foreach` loop ใน `_tableBudgetCheck.cshtml` เพื่อข้ามแถวที่ไม่มีข้อมูลอยู่  
ตรวจสอบว่าแถวนั้น "มีข้อมูล" หรือไม่ โดยใช้เงื่อนไข:

```csharp
var hasData =
    (item.BUDGET_AMOUNT.HasValue && item.BUDGET_AMOUNT != 0) ||
    (item.ENCUMBRANCE_AMOUNT.HasValue && item.ENCUMBRANCE_AMOUNT != 0) ||
    (item.ACTUAL_AMOUNT.HasValue && item.ACTUAL_AMOUNT != 0) ||
    (item.FUNDS_AVAILABLE_AMOUNT.HasValue && item.FUNDS_AVAILABLE_AMOUNT != 0) ||
    (!string.IsNullOrEmpty(item.PREPARE_BUDGET_AMOUNT) &&
     item.PREPARE_BUDGET_AMOUNT != "0");
```

ถ้า `hasData == false` ให้ข้ามการ render `<tr>` สำหรับแถวนั้น

**จุดแก้ไข:**  
`_tableBudgetCheck.cshtml` บรรทัด 25–41 ภายใน `@foreach (var item in Model)`

---

### Issue 266 — เพิ่ม Sort by คำอธิบาย (Description)

**สาเหตุ:**  
ใน `_tableBudgetCheckPeriodCategory.cshtml` การตั้งค่า DataTable กำหนด column 4 (`คำอธิบาย` / `DESCRIPTION`) ว่า `orderable: false`  
ทำให้ผู้ใช้ไม่สามารถคลิกหัวคอลัมน์เพื่อ sort ได้ ทั้งที่ column 2 (ประเภท), 3 (ธุรกรรม), 5 (วันที่ผ่านรายการ) สามารถ sort ได้แล้ว

**ไฟล์ที่เกี่ยวข้อง:**
- `OAGBudget\Views\Budget\_partialView\_tableBudgetCheckPeriodCategory.cshtml` (ชั้น Presentation)

**แนวทางแก้ไข:**  
เปลี่ยน `orderable: false` เป็น `orderable: true` สำหรับ `targets: 4` ในส่วน `columnDefs` ของ DataTable

```javascript
// เดิม
{ targets: 4, orderable: false, className: 'text-start' },

// แก้ไขเป็น
{ targets: 4, orderable: true, className: 'text-start' },
```

**จุดแก้ไข:**  
`_tableBudgetCheckPeriodCategory.cshtml` บรรทัด 88

---

## แผนการแก้ไข (Step-by-step)

| ลำดับ | ไฟล์ | การเปลี่ยนแปลง | Issue |
|-------|------|----------------|-------|
| 1 | `_tableBudgetCheck.cshtml` บรรทัด ~25 | เพิ่มเงื่อนไข `hasData` ก่อน render `<tr>` เพื่อข้ามแถวที่ amount ทุกค่าเป็น null/0 | 86 |
| 2 | `_tableBudgetCheckPeriodCategory.cshtml` บรรทัด 88 | เปลี่ยน `targets: 4` จาก `orderable: false` เป็น `orderable: true` | 266 |

## การ Verify

1. **Issue 86** — ค้นหาด้วยงวด JUL-26 บัญชี `T290060000.T290060000.69.100.20000.21000.21100.210000.29006630001004100280.5999999999.T.T.T` แล้วตรวจสอบว่าในตาราง Summary ไม่มีแถวที่คอลัมน์ทุกค่าว่างเปล่า/เป็น 0 แสดงอยู่อีก
2. **Issue 266** — เปิดรายการธุรกรรมในงวดเดียวกัน แล้วคลิกหัวคอลัมน์ "คำอธิบาย" ตรวจสอบว่าสามารถ sort ขึ้น/ลงได้
