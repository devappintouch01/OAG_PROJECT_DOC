# Logic การตัดยอดเงินในตาราง OAGWBG_BUDGETRECEIVE

ตาราง **`OAGWBG_BUDGETRECEIVE`** เป็นตารางหลักที่ใช้เก็บยอดงบประมาณที่ได้รับ (Allocation) และยอดคงเหลือ (Balance) ของแต่ละรายการ โดย Logic การตัดยอดเงิน (Deduct Balance) มีการกระจายอยู่ในส่วนต่างๆ ของ `BudgetService.cs` ตามประเภทของธุรกรรมดังนี้:

## 1. การโอนจัดสรร (Allocate Transfer)
เมื่อมีการกดยืนยันการโอนจัดสรรงบประมาณจากส่วนกลางไปยังหน่วยงาน หรือระหว่างหน่วยงาน
*   **Method:** `ConfirmBudgetAllocateTransfer`
*   **ช่วงบรรทัด:** ~14750 - 14774
*   **Logic:** 
    *   ระบบจะเพิ่มยอดเงินในฟิลด์ `Totaltransferamount` (ยอดที่โอนออก)
    *   คำนวณยอดคงเหลือใหม่: `Totalbalanceamount = Totalallocateamount - Totaltransferamount`
    *   หากยอดเงินที่จะโอนมากกว่ายอดที่มีอยู่ ระบบจะยอมให้ `Totalbalanceamount` ติดลบในรายการสุดท้าย (เพื่อรองรับกรณี Over-allocation ตามเข็มขัดหรือนโยบาย)

## 2. การโอนเปลี่ยนแปลงงบประมาณ (Budget Adjust)
ใช้ในกรณีโอนเงินข้ามโครงการ หรือข้ามประเภทค่าใช้จ่าย
*   **Method:** `SaveBudgetAdjust`
*   **ช่วงบรรทัด:** ~13658
*   **Logic:**
    *   ทำการหักยอดออกจากรายการต้นทาง: `r.Totalbalanceamount = bal - cut;`
    *   และไปเพิ่มยอดให้กับรายการปลายทาง (Receiver)

## 3. การจ่ายชำระเงิน (Payment GF)
เมื่อมีการบันทึกรายละเอียดการจ่ายเงินผ่านระบบ
*   **Method:** `SaveBudgetPaymentGf` และ `SaveBudgetPaymentGfItemDetail`
*   **ช่วงบรรทัด:** ~6850, ~7436
*   **Logic:** อัปเดตยอดคงเหลือ (`Totalbalanceamount`) ตามจำนวนเงินที่เบิกจ่ายจริงในแต่ละงวด

## 4. การจองงบประมาณ / การกันเงิน (Encumbrance / Reservation)
ในส่วนของการทำ PR/PO (Purchase Request / Purchase Order)
*   **Method:** `SaveBudgetReserved` หรือฟังก์ชันที่เกี่ยวข้องกับการส่งข้อมูลคืนจาก EBS
*   **ช่วงบรรทัด:** ~18201, ~18536
*   **Logic:** 
    *   `Totalbalanceamount` จะถูกปรับปรุงให้สัมพันธ์กับยอด `Totalreservedamount` (ยอดเงินที่ถูกกันไว้)
    *   ยอดคงเหลือจะลดลงเมื่อมีการกันเงิน PR/PO และจะถูกปรับปรุงอีกครั้งเมื่อมีการจ่ายเงินจริง

## 5. การคืนยอดเงิน (Refund / Reversal)
ในกรณีที่มีการยกเลิกรายการโอนหรือการเบิกจ่าย
*   **ช่วงบรรทัด:** ~13508, ~18157
*   **Logic:** ระบบจะทำการ "บวกกลับ" ยอดเงินคืนเข้าสู่ `Totalbalanceamount` เพื่อให้งบประมาณก้อนนั้นกลับมาใช้งานได้อีกครั้ง

---
> [!NOTE]
> การจัดการยอดเงินส่วนใหญ่จะเน้นที่การคำนวณ `Totalbalanceamount` จากความสัมพันธ์ของ `Totalreceiveamount` (ยอดรับ) หักลบด้วย `Totaltransferamount` (ยอดโอนออก) และ `Totalreservedamount` (ยอดกันเงิน) เป็นหลัก
