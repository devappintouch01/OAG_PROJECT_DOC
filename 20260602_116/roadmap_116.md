# Roadmap การแก้ไข #116 — ซ่อน ID ใน Dropdown รายการงบประมาณ (แผนงานอื่น ๆ)

## สรุปปัญหา

หน้า **คำของบประมาณเพิ่มเติม** แท็บ **แผนงานอื่น ๆ** ช่อง **รายการงบประมาณ**  
แสดงข้อความ Dropdown ในรูปแบบ `ID : ชื่อรายการ` เช่น `123 : งบดำเนินงาน`  
แต่ความต้องการคือควรแสดงเฉพาะ **ชื่อรายการ** เท่านั้น โดยไม่ต้องแสดง ID

---

## สาเหตุ (Root Cause)

ไฟล์ Partial View 2 ไฟล์ แสดง option ของ Dropdown ด้วย `@item.id : @item.text` แทนที่จะเป็น `@item.text`

| ไฟล์ | บรรทัด | โค้ดปัจจุบัน |
|------|--------|-------------|
| `OAGBudget\Views\Budget\_partialView\_tableBudgetMoreOtherPlan.cshtml` | 49 | `@item.id : @item.text` |
| `OAGBudget\Views\Budget\_partialView\_tableBudgetMoreCostcenterOtherPlan.cshtml` | 49 | `@item.id : @item.text` |

ทั้งสองไฟล์มี code เหมือนกันทุกประการ (copy กันมา)

---

## แผนการแก้ไข

แก้ไขโค้ดใน **2 ไฟล์** บรรทัดที่ 49 เปลี่ยน:

```cshtml
@item.id : @item.text
```

เป็น:

```cshtml
@item.text
```

ค่า `value="@item.id"` คงไว้ตามเดิม เพื่อให้ระบบยังส่ง ID ที่ถูกต้องเมื่อผู้ใช้เลือก

---

## ขั้นตอนการแก้ไข

1. **แก้ไขไฟล์ที่ 1**  
   `OAGBudget\Views\Budget\_partialView\_tableBudgetMoreOtherPlan.cshtml` บรรทัด 49

2. **แก้ไขไฟล์ที่ 2**  
   `OAGBudget\Views\Budget\_partialView\_tableBudgetMoreCostcenterOtherPlan.cshtml` บรรทัด 49

3. **ทดสอบ**  
   - เปิดหน้า คำของบประมาณเพิ่มเติม  
   - ไปที่แท็บ แผนงานอื่น ๆ  
   - ตรวจสอบ Dropdown รายการงบประมาณ ต้องแสดงเฉพาะชื่อ ไม่มี ID นำหน้า  
   - ตรวจสอบการบันทึกข้อมูลยังทำงานได้ปกติ (value ยังเป็น ID)

---

## ขอบเขตการแก้ไข

- แก้ไขเฉพาะ **display text** ใน option ของ Dropdown
- **ไม่มีการแก้ไข** Controller, Service, Model, หรือ Database
- **ไม่กระทบ** แท็บอื่น ๆ (บุคลากร, พื้นฐาน, ยุทธศาสตร์, บูรณาการ)

---

## TFS Changeset

| Changeset | วันที่ | รายละเอียด |
|---|---|---|
| 18953 | 2026-06-02 | fix #116: hide ID prefix in dropdowns on Other Work Plan tab |

On the Additional Budget Request page, Other Work Plan tab, both dropdowns
were displaying the ID prefix before the label (e.g. "16124 : Revenue Fund")
instead of showing only the label text.

Changed in 2 files:
- Views/Budget/_partialView/_tableBudgetMoreOtherPlan.cshtml
- Views/Budget/_partialView/_tableBudgetMoreCostcenterOtherPlan.cshtml

Changes:
1. Expense Type dropdown (line 23): changed label from "{Value} : {Text}" to "{Text}" only
2. Budget Item dropdown (line 49): changed display from "@item.id : @item.text" to "@item.text" only

Option value still holds the ID — no impact on save/submit behavior.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
