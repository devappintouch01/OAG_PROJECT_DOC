# Roadmap การแก้ไข: Validation กลุ่มเป้าหมาย / ผู้ที่ได้รับประโยชน์

## สรุปปัญหา

หน้า `/Budget/BudgetRequestProjectDetail/{id}?BudgetFormRequestType=1` มี Section "กลุ่มเป้าหมาย / ผู้ที่ได้รับประโยชน์" ใน Tab "กำหนดค่าค่าเป้าหมายความสำเร็จของโครงการ" ซึ่งปัจจุบัน **ยังไม่มีการ validate** ว่าช่อง "กลุ่มเป้าหมาย" จำเป็นต้องกรอก ผู้ใช้สามารถกดบันทึกโดยปล่อยช่องนี้ว่างได้

---

## ไฟล์ที่เกี่ยวข้อง

| ไฟล์ | บทบาท |
|------|-------|
| `OAGBudget\Views\Budget\_partialView\_tableProjectTargetGroup.cshtml` | Render ตาราง, ฟังก์ชัน `syncGroupInputsToList()`, ตัวแปร `projectTargetGroupList` |
| `OAGBudget\Views\Budget\BudgetRequestProjectDetail.cshtml` | Form submit handler, ฟังก์ชัน `validateRequiredFields()` (บรรทัด 952–1009), การดึงข้อมูล `formData.projectTargetGroup` (บรรทัด 1250–1307) |
| `OAGBudget.API\Services\Repository\BudgetService.cs` | `SaveProjectTargetGroup()` — บันทึกข้อมูลลง DB (ยังไม่มี server-side validation) |

---

## สาเหตุของปัญหา

1. **ฝั่ง Client (JavaScript):** ฟังก์ชัน `validateRequiredFields()` ใน `BudgetRequestProjectDetail.cshtml` ตรวจสอบเฉพาะ field ที่มี label ลงท้ายด้วย `*` หรือ attribute `required` เท่านั้น ช่อง `Targetgroup` ใน DataTable ไม่ได้ติด `required` และ label ก็ไม่มี `*` จึงถูกข้ามการ validate ไป

2. **ฝั่ง Server (C#):** เมธอด `SaveProjectTargetGroup()` ใน `BudgetService.cs` รับ List มาแล้ว insert/update โดยตรง ไม่มีการตรวจสอบว่า field `Targetgroup` ว่างหรือไม่

---

## แนวทางการแก้ไข

### ขั้นตอนที่ 1 — Client-side Validation (สำคัญที่สุด)

**ไฟล์:** `BudgetRequestProjectDetail.cshtml`  
**ตำแหน่ง:** ภายในฟังก์ชัน `validateRequiredFields()` (บรรทัดประมาณ 993–998) ต่อจาก block ตรวจสอบ `requestInformantList`

**Logic ที่ต้องเพิ่ม:**
```javascript
// Sync ค่า input ปัจจุบันในตารางกลับเข้า projectTargetGroupList ก่อน
if (typeof syncGroupInputsToList === 'function') {
    syncGroupInputsToList();
}
// ตรวจสอบว่ามีอย่างน้อย 1 รายการที่กรอก กลุ่มเป้าหมาย
if (typeof projectTargetGroupList !== 'undefined') {
    const hasTargetGroup = projectTargetGroupList.some(
        item => item.targetgroup && item.targetgroup.trim() !== ''
    );
    if (!hasTargetGroup) {
        errors.push('กลุ่มเป้าหมาย / ผู้ที่ได้รับประโยชน์ ต้องระบุข้อมูลในช่อง กลุ่มเป้าหมาย อย่างน้อย 1 รายการ');
    }
}
```

**เหตุผล:** `syncGroupInputsToList()` และ `projectTargetGroupList` ถูก declare ใน `_tableProjectTargetGroup.cshtml` และ scope อยู่ใน global ของ page เดียวกัน จึงเรียกใช้ได้จาก `BudgetRequestProjectDetail.cshtml` ได้เลย

---

### ขั้นตอนที่ 2 — Server-side Validation (Defense in Depth)

**ไฟล์:** `OAGBudget.API\Services\Repository\BudgetService.cs`  
**เมธอด:** `SaveProjectTargetGroup()` (บรรทัดประมาณ 501–585)  
**ตำแหน่ง:** เพิ่มก่อน loop insert/update

**Logic ที่ต้องเพิ่ม:**
```csharp
// ตรวจสอบว่ามีอย่างน้อย 1 รายการที่มี Targetgroup
bool hasTargetGroup = model.ProjectTargetGroup
    .Any(x => !string.IsNullOrWhiteSpace(x.Targetgroup));
if (!hasTargetGroup)
{
    return new ApiResultsModel
    {
        IsSuccess = false,
        Message = "กลุ่มเป้าหมาย / ผู้ที่ได้รับประโยชน์ ต้องระบุข้อมูลในช่อง กลุ่มเป้าหมาย อย่างน้อย 1 รายการ"
    };
}
```

---

## ลำดับการดำเนินงาน

1. **แก้ไข client-side** ใน `BudgetRequestProjectDetail.cshtml` → เพิ่ม validation ใน `validateRequiredFields()`
2. **แก้ไข server-side** ใน `BudgetService.cs` → เพิ่ม guard clause ใน `SaveProjectTargetGroup()`
3. **ทดสอบ** กรณีต่อไปนี้:
   - กด Save โดยที่ไม่กรอก กลุ่มเป้าหมาย ในแถวเดียวที่มีอยู่ → ต้องแสดง error
   - เพิ่มหลายแถว แต่ไม่กรอก กลุ่มเป้าหมาย เลย → ต้องแสดง error
   - เพิ่มหลายแถว กรอก กลุ่มเป้าหมาย อย่างน้อย 1 แถว → ต้องบันทึกได้
   - กรอก กลุ่มเป้าหมาย ครบทุกแถว → ต้องบันทึกได้

---

## หมายเหตุ

- ไม่จำเป็นต้องแก้ไข Model/DTO หรือ Database Schema ใด ๆ เพราะเป็นเพียงการเพิ่ม validation logic เท่านั้น
- ปัจจุบันระบบ default ให้มี 1 แถวเสมอ (บรรทัด 39–48 ใน `_tableProjectTargetGroup.cshtml`) ดังนั้น validation นี้จะบังคับให้ผู้ใช้กรอกแถวที่ default มาให้ด้วย
