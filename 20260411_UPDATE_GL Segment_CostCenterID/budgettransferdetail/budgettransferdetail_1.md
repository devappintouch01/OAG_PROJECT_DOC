# ขั้นตอนการทำงานเมื่อกดปุ่ม "ยืนยัน" (id="btn-Confirm") ใน BudgetTransferDetail.cshtml

เอกสารฉบับนี้อธิบายลำดับการทำงานทางเทคนิค (Technical Workflow) ของกระบวนการกดยืนยันรายการ **"โอนงบประมาณกลับ"** เพื่อส่งข้อมูลคืนงบประมาณเข้าสู่ Oracle EBS

## 1. ฝั่งหน้าจอ (UI - jQuery)
เมื่อผู้ใช้งานกดปุ่ม **"ยืนยัน"** (`#btn-Confirm`) ระบบจะทำงานดังนี้:

1.  **ตรวจสอบข้อมูล (Validation):**
    *   ตรวจสอบความครบถ้วนของฟิลด์ที่จำเป็น: วันที่โอน, หน่วยเบิกจ่าย, ศูนย์ต้นทุน, ปีงบประมาณ, แหล่งเงิน, หน่วยงานที่โอน และคำอธิบายรายการ
    *   แจ้งเตือนให้กด "บันทึก" ก่อนหากมีการเปลี่ยนแปลงข้อมูล
2.  **ยืนยันการทำรายการ:**
    *   แสดง SweetAlert2 เพื่อยืนยัน ("ยืนยันที่จะดำเนินการใช่หรือไม่?")
3.  **เรียกฟังก์ชัน `confirmOnlyId(id)`:**
    *   แสดง Loading Overlay พร้อมข้อความ "กำลังยืนยัน โปรดรอสักครู่"
    *   ส่ง AJAX POST ไปที่ MVC Controller: `/Budget/ConfirmBudgetTransferDetail?id={id}`

---

## 2. ลำดับการเรียกฟังก์ชัน (Call Stack)
1.  **MVC Controller:** `BudgetController.ConfirmBudgetTransferDetail` (บรรทัดที่ 2668)
2.  **MVC Service:** `BudgetService.ConfirmBudgetTransferDetail` (บรรทัดที่ 4556)
3.  **API Controller:** `BudgetController.ConfirmBudgetTransferDetail` (บรรทัดที่ 1619)
4.  **API Service:** `BudgetService.ConfirmBudgetTransferDetail` (บรรทัดที่ 14329)
    *   เรียกใช้ **`SaveBudgetTransfer(id)`** เพื่อทำ EBS Interface

---

## 3. การคำนวณ 13 GL Segments
ในเมธอด `SaveBudgetTransfer` (บรรทัดที่ 9631) จะทำการระบุ 13 Segments สำหรับรายการโอนกลับ (RETURN) ดังนี้:

| Segment | คำอธิบาย | แหล่งข้อมูล |
| :--- | :--- | :--- |
| **Segment 1** | กรม (Department) | `Departmentidgiver` (หน่วยงานที่ส่งเงินคืน) |
| **Segment 2** | หน่วยงาน (Cost Center) | `Costcenteridgiver` (ศูนย์ต้นทุนที่ส่งเงินคืน) |
| **Segment 3** | ปีงบประมาณ (Year) | ปีงบประมาณ 2 หลักท้าย (เช่น '68') |
| **Segment 4** | แหล่งเงิน (Source) | `Budgetsourceid` (Default: "100" หากไม่มี) |
| **Segment 5** | แผนงาน (Plan) | แมปจาก `ExpenseAccountRule` (Segment Num 5) |
| **Segment 6** | ผลผลิต (Product) | `Productid` (Default: "00000") |
| **Segment 7** | กิจกรรมหลัก (Activity) | `Activityid` (Default: "00000") |
| **Segment 8** | ประเภทงบประมาณ (Budget Type) | แมปจาก `ExpenseAccountRule` (Segment Num 8) |
| **Segment 9** | รายการงบประมาณ (Budget Code) | `Budgetcodeid` (รหัสบัญชีงบประมาณ) |
| **Segment 10** | บัญชีแยกประเภท (Account) | แมปจาก `ExpenseAccountRule` (Segment Num 10) |
| **Segment 11** | บัญชีย่อย (Sub Account) | แมปจาก `ExpenseAccountRule` (Segment Num 11) |
| **Segment 12** | รหัสจัดสรร 1 | "00" |
| **Segment 13** | รหัสจัดสรร 2 | "000" |

**รายละเอียดเพิ่มเติมของ Interface:**
*   **EnteredDr (Debit):** บันทึกยอดเงินโอนกลับ (`Totalrefundamount`)
*   **Actual Flag:** "E" (Encumbrance)
*   **JE Category:** "Budget - โอนเงินกลับ"
*   **Transfer Type:** "RETURN"

---

## 4. กระบวนการตรวจสอบและอัปเดตสถานะ
1.  **ตรวจสอบยอดเงิน (Budget Check):** ระบบจะเรียก `GetTotalBudget` เพื่อตรวจสอบว่ายอดเงินคงเหลือในงบประมาณก้อนนั้นเพียงพอสำหรับการโอนกลับหรือไม่
2.  **เรียก Stored Procedure:** เรียก `APPS.OAGGL_JOURNAL_INF_PKG.MAIN` เพื่อประมวลผล Interface ใน Oracle EBS
3.  **อัปเดตสถานะโครงการ:** หากสำเร็จ สถานะในตาราง `OAGWBG_BUDGETTRANSFER` จะถูกเปลี่ยนเป็น **`80201`** (ยืนยันรายการแล้ว)
