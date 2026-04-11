# รายละเอียดการทำงานของปุ่ม "ยืนยัน" (btn-Confirm) - งบประมาณเพิ่มเติม/งบกลาง

สรุปขั้นตอนการทำงานเมื่อผู้ใช้งานกดปุ่ม **"ยืนยัน"** (`id="btn-Confirm"`) ในหน้า **BudgetPaymentGfMoreDetail.cshtml** สำหรับการสรุปยอดและส่งข้อมูลเข้าสู่ระบบบัญชีกลาง

---

## 1. การทำงานในส่วน jQuery (Frontend)

เมื่อมีการคลิกปุ่ม `#btn-Confirm` ระบบจะดำเนินการเป็น 2 ขั้นตอนอัตโนมัติ:

1.  **Step 1: บันทึกข้อมูลปัจจุบัน (Save First)**: 
    -   เรียกใช้ฟังก์ชัน `saveData(false)` เพื่อทำการรวบรวมข้อมูลในตาราง (แหล่งเงิน, แผนงาน, รอบ, วันที่ และยอดเงิน) ส่งไปบันทึกที่ `/Budget/SaveBudgetPaymentGfMoreDetail` ก่อน เพื่อให้มั่นใจว่าข้อมูลล่าสุดถูกบันทึกลงฐานข้อมูลแล้ว
2.  **Step 2: การยืนยัน (Confirm Request)**:
    -   หากบันทึกข้อมูลสำเร็จ ระบบจะส่ง AJAX Request ไปยัง **`/Budget/ConfirmBudgetPaymentGfMore`** พร้อมส่ง `BudgetGovernmentId` ไปด้วย
    -   **URL**: `${baseURL}/Budget/ConfirmBudgetPaymentGfMore?BudgetGovernmentId=${budgetgoverment}`
    -   **Method**: `POST`

---

## 2. การทำงานในส่วน Controller (C#)

### BudgetController (ฝั่ง Web)
-   **Method**: `ConfirmBudgetPaymentGfMore`
-   **บรรทัด**: **2709** (ในไฟล์ `BudgetController.cs`)
-   **หน้าที่**: รับ `budgetGovernmentId` และส่งต่อคำสั่งไปยัง Backend API

### BudgetController (ฝั่ง API)
-   **Method**: `ConfirmBudgetPaymentGfMore`
-   **บรรทัด**: **1166** (ในไฟล์ `OAGBudget.API/Controllers/BudgetController.cs`)
-   **หน้าที่**: เรียกใช้ `_service.ConfirmBudgetPaymentGfMore(budgetGovernmentId)`

---

## 3. การทำงานในส่วน Backend API และ GL Segments

ฟังก์ชันหลักที่ควบคุมการยืนยันจะอยู่ใน `BudgetService.cs` มีรายละเอียดดังนี้:

### ฟังก์ชัน ConfirmBudgetPaymentGfMore
-   **ตำแหน่ง**: บรรทัด **7461** ในไฟล์ `OAGBudget.API/Services/Repository/BudgetService.cs`
-   **ลำดับการทำงาน**:
    1.  ตรวจสอบความมีอยู่ของข้อมูลในตาราง `OagwbgBudgetgovernments`
    2.  เรียกฟังก์ชัน **`SaveBudgetPaymentGf(budgetGovernmentId)`** ที่บรรทัด **7498** เพื่อทำการประมวลผล Interface
    3.  หากประมวลผล Interface สำเร็จ ระบบจะอัปเดตสถานะงบประมาณเป็น **"C" (Confirmed)** ที่บรรทัด **7516** และบันทึกลงฐานข้อมูล Oracle

### การคำนวณ GL Segments ทั้ง 13 ตัว
การคำนวณถูกจัดการในฟังก์ชัน `SaveBudgetPaymentGf` (บรรทัด **9192**) ซึ่งจะวนลูปตามรายการหมวดรายจ่ายรายงวดที่บันทึกไว้ และกำหนด Segments ดังนี้:

| Segment | ชื่อ Segment | แหล่งข้อมูล / วิธีการคำนวณ |
| :---: | :--- | :--- |
| **1** | Department | ค่าคงที่ `"2900600000"` |
| **2** | Cost Center | ค่าคงที่ `"2906999999"` (รหัสหน่วยงานภาพรวม) |
| **3** | Year | ปีงบประมาณ 2 หลักท้าย (เช่น 2568 -> `"68"`) |
| **4** | Source | รหัสแหล่งเงิน (`Budgetsourceid`) ที่เลือกในตาราง |
| **5** | Account | ค้นหาจาก `ExpenseAccountRule` โดยใช้ `CategoryId` (SegmentNum: 5) |
| **6** | Product | รหัสผลผลิต (`ProductId`) จากรายการที่เลือก |
| **7** | Activity | รหัสกิจกรรม (`ActivityId`) จากรายการที่เลือก |
| **8** | Sub Category | ค้นหาจาก `ExpenseAccountRule` โดยใช้ `CategoryId` (SegmentNum: 8) |
| **9** | Budget Code | รหัสงบประมาณที่ตรงกับ `Product`, `Activity`, `Category` และ `Source` |
| **10** | Intermediate | ค้นหาจาก `ExpenseAccountRule` โดยใช้ `CategoryId` (SegmentNum: 10) |
| **11** | Product Detail | ค้นหาจาก `ExpenseAccountRule` โดยใช้ `CategoryId` (SegmentNum: 11) |
| **12** | Reserved | ค่าคงที่ `"00"` |
| **13** | Spare | ค่าคงที่ `"000"` |

### สถานที่บันทึกข้อมูล
ระบบจะบันทึกข้อมูลผลลัพธ์ลงใน:
1.  **Oracle EBS (Table: `oagwbg.oaggl_journal_interface`)**: เพื่อรอการนำเข้าสู่ระบบบัญชีใหญ่
2.  **Local Oracle (Table: `OAGWBG_LOG_INTERFACE`)**: เพื่อเก็บประวัติในระบบ OAG

---
*หมายเหตุ: ข้อมูลอ้างอิงจากรหัสต้นฉบับในโปรเจกต์ OAG Budget และ OAGBudget.API ณ วันที่ 10/04/2026*
