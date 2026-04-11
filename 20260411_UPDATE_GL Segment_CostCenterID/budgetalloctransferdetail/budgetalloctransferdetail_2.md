# ขั้นตอนการทำงานเมื่อกดปุ่ม "ยืนยัน" (id="btn-Confirm") ใน BudgetAllocateTransferDetail.cshtml

เอกสารฉบับนี้อธิบายลำดับการทำงานทางเทคนิค (Technical Workflow) ของกระบวนการกดยืนยันรายการโอนจัดสรรงบประมาณ เพื่อส่งข้อมูลเข้าสู่ Oracle EBS

## 1. ฝั่งหน้าจอ (UI - jQuery)
เมื่อผู้ใช้งานกดปุ่ม **"ยืนยัน"** (`#btn-Confirm`) ระบบจะตรวจสอบดังนี้:

1.  **ตรวจสอบความพร้อมของข้อมูล:**
    *   ตรวจสอบว่ามีการเปลี่ยนแปลงในตารางหรือแท็บศูนย์ต้นทุนที่ยังไม่ได้บันทึกหรือไม่ (`hasUnsavedTableChanges`, `hasUnsavedCostCenterChanges`) หากมีจะแจ้งเตือนให้บันทึกก่อน
    *   ตรวจสอบความครบถ้วนของ **วันที่โอน**
2.  **ตรวจสอบแท็บ "รายชื่อศูนย์ต้นทุนที่โอนจัดสรร":**
    *   ตรวจสอบว่าทุกแถวในตาราง `tbCostCenter` ได้เลือก **บัญชีผู้โอน** และ **บัญชีผู้รับโอน** ครบถ้วนแล้วหรือไม่
3.  **แจ้งเตือนยืนยัน:**
    *   แสดง SweetAlert2 เพื่อยืนยันการดำเนินการ
4.  **เรียกฟังก์ชัน AJAX:**
    *   ส่ง Request ไปที่ MVC Controller: `/Budget/ConfirmBudgetAllocateTransfer/{id}`

---

## 2. ลำดับการเรียกฟังก์ชัน (Call Stack)
ลำดับการทำงานข้าม Layer มีดังนี้:

1.  **MVC Controller:** `BudgetController.ConfirmBudgetAllocateTransfer` (บรรทัดที่ 3525)
2.  **MVC Service:** `BudgetService.ConfirmBudgetAllocateTransfer` (บรรทัดที่ 4020) สั่งยิง API พร้อม Token
3.  **API Controller:** `BudgetController.ConfirmBudgetAllocateTransfer` (บรรทัดที่ 1308)
4.  **API Service:** `BudgetService.ConfirmBudgetAllocateTransfer` (บรรทัดที่ 14564)
    *   เรียกใช้ `SaveBudgetAllocateTransfer` เพื่อสร้าง Interface ไปยัง Oracle EBS

---

## 3. การคำนวณ 13 GL Segments
ใน API Service เมธอด `SaveBudgetAllocateTransfer` (บรรทัดที่ 9305) มีการดึงข้อมูลจาก `ExpenseAccountRule` เพื่อสร้าง Segments ทั้ง 13 ตัว ดังนี้:

| Segment | คำอธิบาย | ข้อมูลที่ใช้ |
| :--- | :--- | :--- |
| **Segment 1** | กรม (Department) | "2900600000" |
| **Segment 2** | หน่วยงาน (Cost Center) | "2900600000" |
| **Segment 3** | ปีงบประมาณ (Year) | ปีงบประมาณ 2 หลักท้าย (เช่น '68') |
| **Segment 4** | แหล่งเงิน (Source) | `BudgetSourceId` ของรายการนั้นๆ |
| **Segment 5** | แผนงาน (Plan) | `BudgetPlanId` หรือจาก Expense Rule |
| **Segment 6** | ผลผลิต (Product) | `ProductId` ของรายการนั้นๆ |
| **Segment 7** | กิจกรรมหลัก (Activity) | `ActivityId` ของรายการนั้นๆ |
| **Segment 8** | ประเภทงบประมาณ (Budget Type) | ดึงจาก `ExpenseAccountRule.BudgetTypeId` |
| **Segment 9** | รายการงบประมาณ (Budget Code) | `BudgetCodeId` (เช่น 5101020199) |
| **Segment 10** | บัญชีแยกประเภท (Account) | ดึงจาก `ExpenseAccountRule.AccountNo` |
| **Segment 11** | บัญชีย่อย (Sub Account) | ดึงจาก `ExpenseAccountRule.SubAccountNo` |
| **Segment 12** | รหัสสำรอง 1 | "00" |
| **Segment 13** | รหัสสำรอง 2 | "000" |

**หมายเหตุ:**
*   **EnteredDr (Debit):** บันทึกยอดตามจำนวนเงินที่โอนจัดสรร (`Totalreceiveamount`)
*   **Actual Flag:** ตั้งค่าเป็น **"E"** (Encumbrance - การกันเงินแบบจองงบ)
*   **User JE Category:** "Budget - โอนจัดสรร"

---

## 4. การทำงานหลังการ Interface สำเร็จ
เมื่อได้รับสถานะความสำเร็จจาก Oracle EBS ระบบใน API Service จะดำเนินการต่อดังนี้:

1.  **อัปเดตสถานะ (Status Update):**
    *   ตาราง `OAGWBG_BUDGETALLOCATETRANSFER` จะเปลี่ยนสถานะเป็น `80201`
2.  **อัปเดตยอดคงเหลือ (Balance Deduction):**
    *   ระบบวนลูปรายการในตาราง `OAGWBG_BUDGETRECEIVE` เพื่อเพิ่มยอด `Totaltransferamount` (ยอดที่ถูกโอนไป)
    *   คำนวณยอดคงเหลือใหม่ (`Totalbalanceamount = Totalallocate - Totaltransferamount`)
3.  **บันทึก Log:**
    *   บันทึกประวัติการส่งข้อมูลลงใน `OAGWBG_LOG_INTERFACE` เพื่อตรวจสอบย้อนกลับ (Traceability)
