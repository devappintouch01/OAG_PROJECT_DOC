# รายละเอียดการทำงานของปุ่ม "บันทึก" (btn-save) - รายละเอียดงวดเงินรายหมวดรายจ่าย

สรุปขั้นตอนการทำงานเมื่อผู้ใช้งานกดปุ่ม **"บันทึก"** (`id="btn-save"`) ในหน้า **BudgetPaymentGfItemDetail.cshtml** ของระบบ OAG Budget

---

## 1. การทำงานในส่วน jQuery (Frontend)

เมื่อมีการคลิกปุ่ม `#btn-save` ในหน้ารายละเอียดงวดเงิน ระบบจะดำเนินการดังนี้:

1.  **การยืนยันผู้ใช้**: แสดง Dialog "ยืนยันที่จะบันทึกข้อมูล ?"
2.  **การรวบรวมข้อมูลรายการ (Items Management)**: 
    -   วนลูปอ่านแถวในตาราง `#tbPeriod` เฉพาะแถวที่เป็นระดับหมวดรายจ่าย (Category Level 6) โดยเช็คจากเงื่อนไข `data-category === nodeId`
    -   เก็บข้อมูลรหัสหมวดรายจ่าย (`CategoryId`), รหัสผลผลิต (`ProductId`), รหัสกิจกรรม (`ActivityId`), รหัสแผนงาน (`BudgetPlanId`) และ **ยอดเงินรับงวดนี้** (`TotalReceiveAmount`) เข้าสู่ตัวแปรอาร์เรย์ `items`
3.  **การส่งข้อมูล (AJAX)**:
    -   **URL**: `/Budget/SaveBudgetPaymentGfItemDetail`
    -   **Method**: `POST`
    -   **Payload**: ส่งโมเดล `BudgetPaymentGfItemDetail` ที่ระบุ `budgetReceivePeriodId` และรายการ `items` ทั้งหมด

---

## 2. การทำงานในส่วน Controller และ Service (C#)

### BudgetController (ฝั่ง Web)
-   **Method**: `SaveBudgetPaymentGfItemDetail`
-   **บรรทัด**: **2144** (ในไฟล์ `BudgetController.cs`)
-   **หน้าที่**: รับข้อมูล JSON และเรียกใช้ `_budgetService.SaveBudgetPaymentGfItemDetail(model)` เพื่อส่งต่อไปยัง API

### BudgetService Implementation (Backend API)
-   **Method**: `SaveBudgetPaymentGfItemDetail`
-   **บรรทัด**: **6696** (ในไฟล์ `OAGBudget.API/Services/Repository/BudgetService.cs`)
-   **Logic การทำงาน**:
    1.  **จัดการ Period Category**: ทำการบันทึกหรืออัปเดตข้อมูลลงตาราง `OagwbgBudgetreceiveperiodcategories` ซึ่งเป็นตารางที่เก็บยอดเงินรับจริงแยกตามหมวดรายจ่ายในงวดนั้นๆ
    2.  **จัดการ Budget Receive**: สำหรับรายการที่เป็นเงินงบประมาณประเภท "G" ระบบจะทำการคำนวณและบันทึกลงตาราง `OagwbgBudgetreceives` เพื่อใช้ในการควบคุมยอดคงเหลือ (Balance) ในระบบ
    3.  **การทำ Transaction**: มีการใช้ `BeginTransactionAsync` (บรรทัด 6698) เพื่อให้มั่นใจว่าการบันทึกข้อมูลทั้งส่วนงวดเงินและยอดสะสมถูกต้องครบถ้วน หรือทำ Rollback หากเกิดข้อผิดพลาด

---

## 3. การคำนวณ GL Segments ทั้ง 13 ตัว

การกดปุ่ม **"บันทึก"** ในหน้านี้ **ยังไม่มีการคำนวณหรือส่ง Segments ทันที** แต่เป็นการเตรียมข้อมูลต้นทางที่สำคัญที่สุด เพราะข้อมูลที่กรอกในหน้านี้ (รายหมวดรายจ่าย) จะถูกนำไปใช้ในขั้นตอน **"ยืนยัน" (Confirm)** เพื่อแตกรหัสบัญชีดังนี้:

เมื่อมีการยืนยันแผน ระบบจะเรียกฟังก์ชัน `SaveBudgetPaymentGf` (บรรทัด 9192) เพื่อนำข้อมูลที่บันทึกไว้จากหน้านี้มาคำนวณดังนี้:

-   **EnteredDr (ยอดเงินฝั่ง Debit)**: นำยอด `TotalReceiveAmount` ที่บันทึกไว้ในแต่ละบรรทัดของหน้านี้ไปเป็นยอดเงินใน GL Interface
-   **Segment 5, 8, 10, 11**: ระบบจะนำ `CategoryId` จากหน้านี้ไปวิ่งหาในตาราง **ExpenseAccountRule** เพื่อหาค่า Segment ที่จับคู่ไว้
-   **Segment 6-7**: นำ `ProductId` และ `Activityid` จากที่บันทึกไว้ในหน้านี้มา Pad ให้ครบ 5 หลัก
-   **Segment 9 (รหัสงบประมาณ)**: นำ `ProductId`, `ActivityId` และ `CategoryId` ไปค้นหารหัสงบทรัพย์สิน/งบทำการที่บันทึกไว้เพื่อมาเติม Segments

---

## 4. สรุปความแตกต่าง

-   **หน้า List (GfDetail)**: บันทึกข้อมูล "ภาพรวม" ของงวดเงิน (วันที่, รอบ, ยอดรวม)
-   **หน้านี้ (GfItemDetail)**: บันทึกข้อมูล "รายบรรทัดบัญชี" ว่ายอดรวมของงวดนั้น จะถูกเบิกจ่ายเข้าสู่หมวดรายจ่ายใดบ้าง ซึ่งมีความสำคัญสูงที่สุดในการแตก Segments เพื่อส่งเข้า Oracle EBS

---

## 5. รายละเอียดฟังก์ชัน SaveBudgetPaymentGf (Interface logic)

ฟังก์ชันนี้เป็นส่วนสำคัญที่สุดในการเชื่อมต่อกับระบบภายนอก โดยมีรายละเอียดดังนี้:

-   **ตำแหน่งในไฟล์**: อยู่ที่บรรทัด **9192** ในไฟล์ `BudgetService.cs` (ฝั่ง Backend API)
-   **การทำงาน**: 
    1.  รวบรวมข้อมูลหมวดรายจ่าย (Categories) ที่บันทึกไว้ในงวดนั้นๆ ทั้งหมด
    2.  สร้างพารามิเตอร์ Batch Name (เช่น `BUDGET_WD_2568_20260410...`)
    3.  **คำนวณ GL Segments (1-13)**: นำข้อมูล Product, Activity และ Category ไป Mapping กับตาราง `ExpenseAccountRule` เพื่อสร้างรหัสบัญชี 13 หลัก
    4.  **บันทึกข้อมูล (Save destinations)**: ฟังก์ชันนี้จะทำการบันทึกข้อมูลลง **2 แห่ง** พร้อมกัน (Dual Save):
        -   **Oracle EBS Database**: บันทึกลงตาราง `oagwbg.oaggl_journal_interface` ผ่าน SQL Interface เพื่อส่งข้อมูลเข้าสู่ระบบบัญชีกลาง
        -   **Local Oracle**: บันทึกลงตาราง `OAGWBG_LOG_INTERFACE` (ผ่าน `_context.OagwbgLogInterfaces`) เพื่อใช้เป็นประวัติการทำงาน (Audit Trail) ในระบบ OAG เอง
-   **Method ที่เรียกใช้**: จะถูกเรียกใช้โดยอัตโนมัติเมื่อมีการกดปุ่ม "ยืนยัน" (Confirm) ในขั้นตอนสุดท้าย

---
*หมายเหตุ: ข้อมูลอ้างอิงจากรหัสต้นฉบับในโปรเจกต์ OAG Budget และ OAGBudget.API ณ วันที่ 10/04/2026*
