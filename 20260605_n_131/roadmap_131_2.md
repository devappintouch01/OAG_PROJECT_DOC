# Roadmap 131_2 — แสดงสถานะโครงการ (จาก BudgetAllocateProjectList) บนหน้าคำขอโครงการ

วันที่วิเคราะห์: 2026-06-26

---

## 1. สรุปความต้องการ

หน้า **BudgetAllocateProjectList** (รายละเอียดงบประมาณประจำปี - โครงการ) มีตาราง column **"สถานะโครงการ"**
ซึ่งแสดงว่าแต่ละโครงการ "ได้รับจัดสรร" หรือ "ไม่ได้รับจัดสรร"

หลังกด **"ยืนยัน"** บนหน้านั้น ต้องการนำค่าสถานะโครงการนั้นไปแสดงบนหน้า
**BudgetRequestProjectList** (คำของบประมาณรายจ่ายประจำปี - โครงการ)  
ในตารางรายการโครงการของคำขอ

---

## 2. ไฟล์ที่เกี่ยวข้อง

| Layer | ไฟล์ | ต้องแก้ |
|-------|------|---------|
| View (หน้าคำขอ) | `OAGBudget\Views\Budget\BudgetRequestProjectList.cshtml` | ✅ แก้ไปแล้วใน roadmap_131 |
| View (หน้าจัดสรร) | `OAGBudget\Views\Budget\BudgetAllocateProjectList.cshtml` | ❌ ไม่ต้องแก้ |
| MVC Controller | `OAGBudget\Controllers\BudgetController.cs` | ❌ ไม่ต้องแก้ |
| API Controller | `OAGBudget.API\Controllers\BudgetController.cs:631` | ❌ ไม่ต้องแก้ |
| **API Service** | **`OAGBudget.API\Services\Repository\BudgetService.cs`** | **✅ ต้องแก้ไข** |
| Models | `OAGBudget.Models\*` | ❌ ไม่ต้องแก้ |
| DAL | `OAGBudget.DAL\Models\OagwbgProject.cs` | ❌ ไม่ต้องแก้ (field มีอยู่แล้ว) |

---

## 3. Oracle Tables ที่เกี่ยวข้อง

| Table / View | ฟิลด์สำคัญ | บทบาท |
|-------------|-----------|-------|
| `OAGWBG_PROJECT` | `ID`, `TEMP`, `STATUS`, `PROJECTSTATUS` | ตารางโครงการหลัก |
| `OAGWBG_V_PROJECT` | `Id`, `Temp`, `Status`, `Projectstatus` | View ที่ใช้ query |
| `OAGWBG_BUDGETGOVERNMENT` | `BUDGETSTATUS` | งบประมาณแผ่นดินต่อโครงการ |

**ไม่มี Stored Procedure** — ใช้ EF Core ทั้งหมด  
**ไม่ต้องสร้างตารางใหม่** — field ที่ต้องการมีอยู่ครบแล้ว

---

## 4. กลไกสำคัญ: TEMP Project คืออะไร

ระบบสร้าง **โครงการสำเนา (TEMP project)** ขึ้นมาสำหรับขั้นตอนพิจารณาจัดสรร:

```
OAGWBG_PROJECT (ต้นฉบับ)       OAGWBG_PROJECT (สำเนา - TEMP)
┌─────────────────────┐          ┌─────────────────────┐
│ Id = 100            │◄────────│ Id = 200            │
│ Temp = NULL         │  Temp   │ Temp = 100          │ ← เก็บ Id ของต้นฉบับ
│ Status = NULL       │         │ Status = "1"/"0"    │ ← ถูก set โดยผู้พิจารณา
│ Projectstatus = "A" │         │ Projectstatus = "C" │ ← set เมื่อ Confirm
└─────────────────────┘         └─────────────────────┘
```

| ประเภท | เงื่อนไข | ใช้ใน |
|--------|----------|-------|
| ต้นฉบับ | `Temp IS NULL` | `BudgetRequestProjectList` (หน้าหน่วยงาน) |
| สำเนา-TEMP | `Temp IS NOT NULL` | `BudgetAllocateProjectList` (หน้าส่วนกลาง) |

---

## 5. Flow ปัจจุบัน (สาเหตุที่ Status ไม่แสดง)

```
[BudgetAllocateProjectList] แสดงโครงการ WHERE Temp != null
    ↓ admin คลิกแก้ไขโครงการ (pageType=4)
BudgetRequestProjectDetail (pageType=4)
    ↓ admin เลือก Status = "1" หรือ "0" แล้ว Save
SaveBudgetRequestProjectDetail → project.Status = data.Status
    ✅ อัปเดต TEMP project (Id=200) → Status="1"/"0"
    ❌ ต้นฉบับ (Id=100) → Status ยังคง NULL

    ↓ admin กด "ยืนยัน"
ConfirmBudgetAllocateProject()
    - validate: TEMP projects ทุกตัวต้องมี Status != null
    - set: TEMP project.Projectstatus = "C"
    - set: BudgetGovernment.Budgetstatus = "C"
    ❌ ไม่มีการ copy Status ไปยัง Original project

[BudgetRequestProjectList] แสดงโครงการ WHERE Temp IS NULL
    → ต้นฉบับ Status = NULL ตลอด
    → badge แสดง "รอการจัดสรร" แม้จะ Confirm แล้ว  ← ❌ BUG
```

### ข้อสรุปช่องโหว่

`ConfirmBudgetAllocateProject` ยืนยันสถานะบน **TEMP project** เท่านั้น  
แต่ `GetBudgetRequestProjectList` ดึงข้อมูลจาก **Original project (Temp IS NULL)**  
ซึ่ง Status ไม่เคยถูกอัปเดต → badge แสดงผลไม่ถูกต้อง

---

## 6. สิ่งที่ต้องเปลี่ยนในแต่ละ Layer

### Layer ที่ 1: API Service — `BudgetService.cs:ConfirmBudgetAllocateProject()` ✅ ต้องแก้ไข

**ตำแหน่ง:** บรรทัดประมาณ 4880 (method `ConfirmBudgetAllocateProject`)

**Logic ที่ต้องเพิ่ม** — หลังจาก set `Projectstatus = "C"` บน TEMP projects แล้ว  
ให้ propagate `Status` กลับไปยัง Original project โดยใช้ `Temp` field เป็น FK:

```csharp
// เพิ่มใน ConfirmBudgetAllocateProject() หลังจาก set Projectstatus = "C"
foreach (var tempProject in projects)
{
    if (tempProject.Temp.HasValue)
    {
        var originalProject = await _context.OagwbgProjects
            .FirstOrDefaultAsync(x => x.Id == tempProject.Temp);
        if (originalProject != null)
        {
            originalProject.Status = tempProject.Status; // propagate "1" หรือ "0"
            originalProject.Updateby = userId;
            originalProject.Updateon = now;
        }
    }
}
await _context.SaveChangesAsync(); // หรือรวมใน SaveChanges เดิม
```

**Build:** ต้อง build หลังแก้ไข

---

### Layer ที่ 2: View — `BudgetRequestProjectList.cshtml` ✅ แก้ไขแล้วใน roadmap_131

ไม่ต้องแก้เพิ่ม — badge แสดง `data.status` อยู่แล้ว  
เมื่อ Status ของ Original project ถูก propagate มาจาก Layer 1 badge จะแสดงถูกต้องโดยอัตโนมัติ:

| `data.status` | แสดงผล |
|--------------|--------|
| `"1"` | badge สีเขียว "ได้รับจัดสรร" |
| `"0"` | badge สีแดง "ไม่ได้รับจัดสรร" |
| `null` | badge สีเทา "รอการจัดสรร" |

---

### Layer ที่ 3–5: ไม่ต้องแก้ไข

| Layer | เหตุผล |
|-------|--------|
| MVC Controller | `BudgetRequestProjectList()` ส่ง model ถูกต้องแล้ว |
| API Controller | `ConfirmBudgetAllocateProject()` เรียก service ตรงๆ |
| GetBudgetRequestProjectList | query `Temp IS NULL` ถูกต้อง, `OagwbgVProject.Status` มีอยู่แล้ว |
| Models/DTOs | ไม่ต้องเพิ่ม field ใหม่ |
| Oracle Table | `STATUS` field ใน `OAGWBG_PROJECT` มีอยู่แล้ว |

---

## 7. สรุป Flow หลังแก้ไข

```
admin กด "ยืนยัน" บน BudgetAllocateProjectList
    ↓
ConfirmBudgetAllocateProject()
    ✅ set TEMP project.Projectstatus = "C"
    ✅ set BudgetGovernment.Budgetstatus = "C"
    ✅ [ใหม่] propagate Status → Original project (via Temp FK)
           TEMP project (Id=200, Temp=100, Status="1")
               → Original (Id=100).Status = "1"

หน่วยงานเปิดหน้า BudgetRequestProjectList
    → GetBudgetRequestProjectList query Temp IS NULL
    → Original project.Status = "1" (ถูก propagate แล้ว)
    → badge แสดง "ได้รับจัดสรร" ✅
```

---

## 8. สรุปไฟล์ที่ต้องแก้ไข

```
✅ ต้องแก้ (1 ไฟล์):
   OAGBudget.API\Services\Repository\BudgetService.cs
   — method: ConfirmBudgetAllocateProject()
   — เพิ่ม loop propagate Status จาก TEMP → Original project

✅ แก้ไขแล้ว (จาก roadmap_131):
   OAGBudget\Views\Budget\BudgetRequestProjectList.cshtml
   — badge แสดง data.status อยู่แล้ว

❌ ไม่ต้องแก้:
   Controllers (MVC + API)
   GetBudgetRequestProjectList (query logic)
   Models / DAL / Oracle Table / SP
```

---

## 9. ข้อควรระวัง

- **ลำดับ SaveChanges:** การ propagate ควรอยู่ใน `try` block เดียวกับ Projectstatus update  
  เพื่อให้ทั้ง TEMP update และ Original propagate เป็น atomic transaction
- **Null check:** ถ้า `tempProject.Temp` เป็น null (ไม่มี original) ให้ข้ามไป
- **ต้อง Build:** แก้ไข .cs file → ต้อง build เพื่อ verify ก่อน checkin เสมอ
- **ไม่กระทบ flow อื่น:** Original project's Status ถูกอ่านเฉพาะใน BudgetRequestProjectList  
  ไม่มี side effect กับ flow อื่นๆ
