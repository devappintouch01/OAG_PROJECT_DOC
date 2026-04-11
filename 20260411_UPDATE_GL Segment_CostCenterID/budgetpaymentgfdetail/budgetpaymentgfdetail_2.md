# รายละเอียดการทำงานของปุ่ม "บันทึก" (btn-save) - บันทึกรับเงินจากสำนักการคลัง

สรุปขั้นตอนการทำงานเมื่อผู้ใช้งานกดปุ่ม **"บันทึก"** (`id="btn-save"`) ในหน้า **BudgetPaymentGfDetail.cshtml** ของระบบ OAG Budget

---

## 1. การทำงานในส่วน jQuery (Frontend)

เมื่อมีการคลิกปุ่ม `#btn-save` ระบบจะดำเนินการดังนี้:

1.  **การยืนยันผู้ใช้**: แสดง Dialog "ยืนยันที่จะบันทึกข้อมูล ?"
2.  **การตรวจสอบความถูกต้อง (Validation)**: ฟังก์ชัน `validateForm()` จะตรวจสอบว่ามีการระบุข้อมูลที่จำเป็นครบถ้วนหรือไม่ (เช่น วันที่ได้รับจัดสรร, แผนงาน, ไตรมาส)
3.  **การรวบรวมข้อมูล**: 
    -   วนลูปอ่านค่าจากตารางงวดเงิน (`#tbPeriod`) และเก็บไว้ใน `budgetReceivePeriodList`
    -   รวมยอดเงินทั้งหมด (`Totalallocateamount`) มาใส่ในข้อมูลส่วนหัว (Header)
4.  **การส่งข้อมูล (AJAX)**:
    -   **URL**: `/Budget/SaveBudgetPaymentGfDetail`
    -   **Method**: `POST`
    -   **Payload**: ส่งโมเดล `BudgetPaymentGfDetailModel` ที่ประกอบด้วยข้อมูลส่วนหัวและรายการงวดเงินในรูปแบบ JSON

---

## 2. การทำงานในส่วน Web Controller (C#)

### BudgetController (ฝั่ง Web)
-   รับข้อมูลผ่าน Method `SaveBudgetPaymentGfDetail([FromBody] BudgetPaymentGfDetailModel model)`
-   เรียกใช้ Interface `_budgetService.SaveBudgetPaymentGfDetail(model)` เพื่อส่งข้อมูลไปยัง Backend API

### BudgetService Implementation (Backend API)
ทำงานที่ `SaveBudgetPaymentGfDetail` (Line 6373) ดังนี้:
1.  **บันทึกข้อมูลส่วนหัว**: อััปเดตหรือเพิ่มข้อมูลลงในตาราง `OagwbgBudgetgovernments` (ประเภท "2" หมายถึง บันทึกรับเงินจากสำนักการคลัง)
2.  **จัดการรายการเงินงวด (Periods)**: เรียกฟังก์ชัน `SaveBudgetReceivePeriod` เพื่อทำการ Sync ข้อมูลในตาราง `OagwbgBudgetreceiveperiods`
3.  **Persistence**: เรียก `_context.SaveChangesAsync()` เพื่อบันทึกลงฐานข้อมูล Oracle

---

## 3. การคำนวณ GL Segments ระบบบัญชี (Interface)

แม้ปุ่มบันทึกจะยังไม่ส่งข้อมูลเข้า EBS ทันที (จะส่งเมื่อกด "ยืนยัน") แต่ข้อมูลที่ถูกบันึกไว้ในขั้นตอนนี้ คือต้นทางในการคำนวณ **GL Segments ทั้ง 13 ตัว** ซึ่งมีตรรกะการคำนวณในฟังก์ชัน `SaveBudgetPaymentGf` (Line 9192) ดังนี้:

| Segment | ชื่อเรียก | แหล่งข้อมูลและการคำนวณ (Withdrawal) |
| :--- | :--- | :--- |
| **Segment 1** | รหัสกรม | **"2900600000"** (ค่าคงที่) |
| **Segment 2** | หน่วยงาน | **"2900600000"** (ค่าคงที่) |
| **Segment 3** | ปีงบประมาณ | ใช้เลข 2 หลักท้ายของปี พ.ศ. (เช่น `2568 % 100 = 68`) |
| **Segment 4** | แหล่งเงิน | ดึงตาม `Budgetsourceid` (เช่น "100" สำหรับเงินงบประมาณ) |
| **Segment 5** | หมวดรายจ่าย | ดึงจาก Mapping ใน `allExpenseAccountRule` (Segment 5) ตามหมวด Category |
| **Segment 6** | ผลผลิต (Product) | ดึงรหัส Product ID 5 หลัก (เช่น "00001") |
| **Segment 7** | กิจกรรม (Activity) | ดึงรหัส Activity Code ID 5 หลัก |
| **Segment 8** | บัญชีย่อย | ดึงจาก Mapping ใน `allExpenseAccountRule` (Segment 8) ตามหมวด Category |
| **Segment 9** | รหัสงบประมาณ | หากเป็นงวดปกติ ใช้จาก `OagwbgBudgetcodeYears`, หากเป็นงบเพิ่มเติม ใช้จาก `OagwbgBudgetcodemoreYears` |
| **Segment 10** | โครงการ | ดึงจาก Mapping ใน `allExpenseAccountRule` (Segment 10) |
| **Segment 11** | ประเภทค่าใช้จ่าย | ดึงจาก Mapping ใน `allExpenseAccountRule` (Segment 11) |
| **Segment 12** | Future 1 | **"00"** (ค่าคงที่) |
| **Segment 13** | Future 2 | **"000"** (ค่าคงที่) |

---

## 4. สรุปการใช้ Interface และความสัมพันธ์

-   ข้อมูลที่บันทึกผ่านปุ่มนี้ จะถูกเก็บเป็นสถานะ **'R' (Receive/Draft)**
-   ระบบใช้ **allExpenseAccountRule** เป็น Interface หลักในการแปลงรหัสหมวดรายจ่ายในระบบ OAG ให้เป็นรหัสบัญชี GL (Segments ต่างๆ) 
-   การบันทึกนี้เป็นการเตรียม "Input" ที่ถูกต้องเพื่อให้เมื่อมีการยืนยันในลำดับถัดไป ระบบจะสามารถแตก Segments ทั้ง 13 ตัวได้อย่างแม่นยำเพื่อส่งเข้า Oracle EBS

---
*หมายเหตุ: ข้อมูลอ้างอิงจากรหัสต้นฉบับในโปรเจกต์ OAG Budget และ OAGBudget.API ณ วันที่ 10/04/2026*
