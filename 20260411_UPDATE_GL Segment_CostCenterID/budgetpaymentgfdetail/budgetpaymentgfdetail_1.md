# รายละเอียดการทำงานของปุ่ม "ยืนยัน" (btn-Confirm) - บันทึกรับเงินจากสำนักการคลัง

สรุปขั้นตอนการทำงานเมื่อผู้ใช้งานกดปุ่ม **"ยืนยัน"** (`id="btn-Confirm"`) ในหน้า **BudgetPaymentGfDetail.cshtml** ของระบบ OAG Budget

---

## 1. การทำงานในส่วน jQuery (Frontend)

เมื่อมีการคลิกปุ่ม `#btn-Confirm` ระบบจะดำเนินการเป็นขั้นตอนดังนี้:

1.  **การยืนยันผู้ใช้**: แสดง Modal "ยืนยันที่จะบันทึกข้อมูล ?"
2.  **การบันทึกข้อมูลก่อนยืนยัน (Auto-Save)**: 
    เรียกใช้ฟังก์ชัน `saveData(false)` เพื่อทำการบันทึกข้อมูลปัจจุบันเข้าสู่ระบบก่อน:
    -   ตรวจสอบความถูกต้องของฟอร์ม (Validation) เช่น วันที่, แผนงาน และยอดเงิน
    -   รวบรวมรายการงวดที่ได้รับจัดสรร (`BudgetReceivePeriodList`)
    -   ส่งไปที่ Controller ผ่าน AJAX POST ที่ Method `SaveBudgetPaymentGfDetail`
3.  **การยืนยันรายการ (Confirm)**:
    หากการบันทึกสำเร็จ (Success) ระบบจะส่ง Request รอบที่ 2 ไปยัง Controller:
    -   **URL**: `/Budget/ConfirmBudgetPaymentGf`
    -   **Parameter**: `BudgetGovernmentId` (ID ของรายการหลัก)
    -   หากสำเร็จ จะแสดง Alert "ยืนยันข้อมูลสำเร็จ" และทำการ Reload หน้าจอ

---

## 2. การทำงานในส่วน Controller (C#)

### BudgetController (ทั้งฝั่ง Web และ API)
-   **SaveBudgetPaymentGfDetail**: รับ Model ข้อมูลทั้งหมด และส่งต่อไปยัง Service เพื่อบันทึกข้อมูลลงฐานข้อมูลเบื้องต้น
-   **ConfirmBudgetPaymentGf**: รับรหัส ID ของรายการ และเรียกใช้คำสั่งยืนยันแผนงานในระดับ Business Logic

---

## 3. การทำงานในส่วน Backend Logic (API Service)

ทำงานผ่าน `BudgetService.cs` ในโปรเจกต์ **OAGBudget.API** โดยมีขั้นตอนสำคัญดังนี้:

### การบันทึกรายละเอียด (SaveBudgetPaymentGfDetail)
-   อััปเดตข้อมูลในตาราง `OagwbgBudgetgovernments` (ประเภทรายการ = "2", สถานะเริ่มต้น = "R")
-   จัดการรายการงวดเงินในตาราง `OagwbgBudgetreceiveperiods` โดยใช้ `CollectionHelper` เพื่อเปรียบเทียบข้อมูลเก่าและใหม่ (Add/Update/Delete)

### การยืนยันและเชื่อมต่อระบบภายนอก (ConfirmBudgetPaymentGf)
1.  **ตรวจสอบสถานะ**: ดึงข้อมูลรายการและตรวจสอบความถูกต้อง
2.  **การเชื่อมต่อระบบบัญชี (Oracle EBS Integration)**:
    หากสถานะระบบเป็นการเชื่อมต่อ (`isConnection == true`) จะเรียกฟังก์ชัน `SaveBudgetPaymentGf`:
    -   สร้าง Batch Name ในรูปแบบ `BUDGET_WD_[ปี]_[Timestamp]` (WD = Withdrawal)
    -   วนลูปรายการงวดที่ได้รับจัดสรรเพื่อคำนวณ **GL Segments ทั้ง 13 ตัว**
    -   กำหนด `BudgetEncumbranceName` เป็น **"OAG_BG_FINAL"**
    -   บันทึกข้อมูลลงตาราง Log Interface และเรียกฟังก์ชัน `SaveInterface` เพื่อส่งข้อมูลเข้าสู่ระบบ **Oracle EBS (General Ledger)**
3.  **เปลี่ยนสถานะรายการ**: เมื่อส่งข้อมูลสำเร็จ จะเปลี่ยนสถานะ `Budgetstatus` เป็น **"C"** (Confirmed) เพื่อปิดการแก้ไข

---

## 4. การส่งและการใช้งาน Interface

-   **IBudgetService**: ใช้จัดการตรรกะการบันทึกและยืนยันระหว่างชั้น Web App และ API
-   **IEbsContext**: Interface สำคัญที่ใช้ดึง Connection String เพื่อเข้าถึงฐานข้อมูล Oracle ของระบบบัญชีกลาง
-   **IAuthService**: ใช้ตรวจสอบความถูกต้องของ Token และระบุตัวตนผู้ใช้ (`UserInfo`) เพื่อบันทึกในฟิลด์ `Updateby`
-   **OagwbgContext**: ใช้จัดการข้อมูลใน Oracle สำหรับตารางหลัก เช่น `OagwbgBudgetreceiveperiods` และ `OagwbgLogInterfaces`

---
*หมายเหตุ: ข้อมูลอ้างอิงจากรหัสต้นฉบับในโปรเจกต์ OAG Budget และ OAGBudget.API ณ วันที่ 10/04/2026*
