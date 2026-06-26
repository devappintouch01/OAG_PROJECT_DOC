# Roadmap 131 — แสดงสถานะการจัดสรรเงิน บนหน้าคำของบประมาณประจำปี (แบบโครงการ)

วันที่วิเคราะห์: 2026-06-05

---

## 1. สรุปความต้องการ

หลัง Step **พรบ** (Confirm Budget Allocate Project) เจ้าหน้าที่ส่วนกลางได้ยืนยันสถานะการจัดสรรเงินให้แต่ละโครงการแล้ว  
ต้องการ **นำสถานะการจัดสรรนั้นไปแสดงบนหน้าคำขอ** (`BudgetRequestProjectList`) ของหน่วยงาน  
เพื่อให้หน่วยงานเจ้าของโครงการทราบว่าโครงการตนเองได้รับ/ไม่ได้รับงบประมาณ

---

## 2. ไฟล์ที่เกี่ยวข้อง

| Layer | ไฟล์ | หมายเหตุ |
|-------|------|----------|
| View | `OAGBudget\Views\Budget\BudgetRequestProjectList.cshtml` | **ต้องแก้ไข** — เพิ่มคอลัมน์สถานะการจัดสรร |
| Controller (MVC) | `OAGBudget\Controllers\BudgetController.cs:971` | `BudgetRequestProjectList()` — ไม่ต้องแก้ |
| Service (MVC) | `OAGBudget\Services\Repository\BudgetService.cs` | ไม่ต้องแก้ |
| API Controller | `OAGBudget.API\Controllers\BudgetController.cs:168` | `GetBudgetRequestProjectList()` — ไม่ต้องแก้ |
| API Service | `OAGBudget.API\Services\Repository\BudgetService.cs:1611` | `GetBudgetRequestProjectList()` — ไม่ต้องแก้ |
| Model (ViewModel) | `OAGBudget.Models\ViewModel\BudgetRequestProjectListViewModel.cs` | ไม่ต้องแก้ |
| DAL Model | `OAGBudget.DAL\Models\OagwbgVProject.cs` | มีฟิลด์พร้อมใช้แล้ว |

---

## 3. Oracle Tables / Views ที่เกี่ยวข้อง

| ชื่อ Table/View | ฟิลด์สำคัญ | ความสัมพันธ์ |
|-----------------|-----------|-------------|
| `OAGWBG_PROJECT` | `STATUS` — "1"=ได้รับจัดสรร, "0"=ไม่ได้รับ, null=รอ | ตารางหลักโครงการ |
| `OAGWBG_PROJECT` | `PROJECTSTATUS` — "C"=ยืนยันการจัดสรรแล้ว | ตารางหลักโครงการ |
| `OAGWBG_V_PROJECT` | `Status`, `Projectstatus`, `Projectstatusname` | View ที่ใช้ query ใน Service |
| `OAGWBG_BUDGETGOVERNMENT` | `BUDGETSTATUS` — "C"=ยืนยัน | เงินงบประมาณแผ่นดินของโครงการ |
| `OAGWBG_BUDGETREQUEST` | `STATUSID` — 20102=อนุมัติ (หลังพรบ) | คำของบประมาณ |

**ไม่มี Stored Procedure** — ระบบใช้ EF Core ดึงข้อมูลโดยตรงจาก View `OAGWBG_V_PROJECT`

---

## 4. การทำงาน Flow ปัจจุบัน

```
[หน่วยงาน] เปิดหน้าคำขอโครงการ
    ↓
BudgetRequestProjectList (GET) — BudgetController.cs:971
    ↓
_budgetService.GetBudgetRequestProjectList(Id)   ← MVC BudgetService (proxy)
    ↓ HTTP call ไปยัง OAGBudget.API
API: BudgetController.cs:168 → GetBudgetRequestProjectList()
    ↓
BudgetService.cs:1611 → GetBudgetRequestProjectList()
    ↓ EF Core Query
SELECT จาก OAGWBG_V_BUDGETREQUEST (header)
     + OAGWBG_V_PROJECT WHERE Budgetrequestid = ? AND Temp IS NULL
    ↓ Return BudgetRequestProjectListViewModel
        .Projects = List<OagwbgVProject>
    ↓
View: BudgetRequestProjectList.cshtml
    แสดง DataTable columns:
    [ลำดับที่] | [actions] | [ชื่อโครงการ] | [รวมเงินงบประมาณ]
```

### Step พรบ (ConfirmBudgetAllocateProject)

```
ส่วนกลาง กด "ยืนยันการจัดสรร"
    ↓
BudgetController.cs:2798 → ConfirmBudgetAllocateProject()
    ↓
BudgetService.cs:4751 → ConfirmBudgetAllocateProject()
    ↓ EF Core Update
    OAGWBG_PROJECT.PROJECTSTATUS = 'C'
    OAGWBG_BUDGETGOVERNMENT.BUDGETSTATUS = 'C'
```

### สถานะการจัดสรร (STATUS) ถูกกำหนดโดย

```
SaveBudgetAllocateGovernmentProject()
    ↓
    OAGWBG_PROJECT.STATUS = data.Status
    (ส่วนกลางเลือกว่าโครงการไหนได้/ไม่ได้รับ → "1" หรือ "0")
```

---

## 5. ค่าสถานะที่ใช้

### OagwbgVProject.Status (สถานะการจัดสรรเงิน)

| ค่า | ความหมาย | Badge แนะนำ |
|-----|----------|------------|
| `"1"` | ได้รับจัดสรรงบประมาณ | สีเขียว (success) |
| `"0"` | ไม่ได้รับจัดสรรงบประมาณ | สีแดง (danger) |
| `null` | รอการจัดสรรงบประมาณ | สีเทา (secondary) |

### OagwbgVProject.Projectstatus (สถานะคำขอโครงการ)

| ค่า | ความหมาย |
|-----|----------|
| `"C"` | ยืนยันการจัดสรรแล้ว (หลัง Confirm พรบ) |
| `"A"` | อนุมัติ/จัดทำคำขอ |
| `"U"` | อยู่ระหว่างพิจารณา |
| `"N"` | ไม่อนุมัติโครงการ |

---

## 6. สิ่งที่ต้องเปลี่ยนในแต่ละ Layer

### Layer ที่ 1: View — `BudgetRequestProjectList.cshtml` ✅ ต้องแก้ไข

**ปัญหาปัจจุบัน:** ตาราง `#tblProjectBudget` มีเพียง 4 คอลัมน์ ไม่มีคอลัมน์สถานะการจัดสรร

**สิ่งที่ต้องแก้:**

1. **เพิ่ม `<th>` ใน `<thead>`** (บรรทัดประมาณ 109–115):
   ```html
   <th>สถานะการจัดสรร</th>
   ```

2. **เพิ่ม `columnDefs`** สำหรับคอลัมน์ใหม่ (index 4):
   ```js
   { targets: 4, orderable: false },
   ```

3. **เพิ่ม column render** ใน `columns` array หลัง `totalrequestamount`:
   ```js
   {
       data: 'status',
       className: 'text-center',
       render: function (data, type, row) {
           if (data === '1') return '<span class="badge badge-light-success">ได้รับจัดสรร</span>';
           if (data === '0') return '<span class="badge badge-light-danger">ไม่ได้รับจัดสรร</span>';
           return '<span class="badge badge-light-secondary">รอการจัดสรร</span>';
       }
   }
   ```

4. **เงื่อนไขการแสดง:** ควรแสดงคอลัมน์นี้เมื่อ `statusId == 20102` (อนุมัติ/หลังพรบ) เพื่อไม่ให้หน่วยงานเห็นก่อนกำหนด

---

### Layer ที่ 2–5: ไม่ต้องแก้ไข

| Layer | เหตุผล |
|-------|--------|
| MVC Controller | `BudgetRequestProjectList()` ส่ง model ครบแล้ว |
| MVC Service | เป็นแค่ proxy เรียก API |
| API Controller | `GetBudgetRequestProjectList()` ไม่ต้องเพิ่ม parameter |
| API Service | query `OagwbgVProject` อยู่แล้ว และ View มีฟิลด์ `Status` พร้อม |
| Models/DTOs | `BudgetRequestProjectListViewModel.Projects` เป็น `List<OagwbgVProject>` ซึ่งมี `.Status` อยู่แล้ว |
| DAL | `OagwbgVProject.Status` มีอยู่แล้ว (string?) |

**ข้อมูลพร้อมใช้งาน:** JavaScript variable `projects` ใน View มีฟิลด์ `status` อยู่แล้วจาก JSON serialization ของ `OagwbgVProject`

---

## 7. สรุปไฟล์ที่ต้องแก้ไข

```
✅ ต้องแก้ (1 ไฟล์เท่านั้น):
   OAGBudget\Views\Budget\BudgetRequestProjectList.cshtml
   — เพิ่มคอลัมน์ "สถานะการจัดสรร" ใน DataTable

❌ ไม่ต้องแก้:
   BudgetController.cs (MVC + API)
   BudgetService.cs (MVC + API)
   BudgetRequestProjectListViewModel.cs
   OagwbgVProject.cs
   OAGBudget.DAL (ทั้งหมด)
   Oracle SP / Table
```

---

## 8. ข้อควรระวัง

- ฟิลด์ `status` ใน JavaScript (`data.status`) จะเป็น lowercase เนื่องจาก JSON serialization
- ตรวจสอบว่าเงื่อนไขการแสดงผลถูกต้อง: ควรแสดงเฉพาะเมื่อ `statusId >= 20102` หรือ `Projectstatus == "C"` เพื่อไม่ให้หน่วยงานเห็นสถานะก่อนที่ส่วนกลางจะยืนยัน
- ปัจจุบันใน `BudgetAllocateProjectList.cshtml` (หน้าของส่วนกลาง) แปลค่า Status ในฝั่ง C# แล้ว แต่ในหน้า `BudgetRequestProjectList.cshtml` ต้องแปลใน JavaScript render function
