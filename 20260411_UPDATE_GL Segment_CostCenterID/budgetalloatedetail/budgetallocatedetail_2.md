# รายละเอียดการทำงานของปุ่ม "ยืนยัน" (btn-Confirm)

สรุปขั้นตอนการทำงานเมื่อผู้ใช้งานกดปุ่ม **"ยืนยัน"** (`id="btn-Confirm"`) ในหน้า **BudgetAllocateDetail.cshtml** ของระบบ OAG Budget

---

## 1. การทำงานในส่วน jQuery (Frontend)

เมื่อมีการคลิกปุ่ม `#btn-Confirm` ระบบจะดำเนินการตามลำดับดังนี้:

1.  **การยืนยันเบื้องต้น**: แสดง Dialog สอบถาม "ยืนยันที่จะบันทึกข้อมูล ?"
2.  **การรวบรวมข้อมูล (Data Collection)**:
    -   วนลูปอ่านข้อมูลจากทุกตารางในทุกแท็บ (`tbltab_...`)
    -   เก็บข้อมูลเข้าสู่ `dataList` ซึ่งประกอบด้วย:
        -   `budgetAllocateNew`: รายการ Category ใหม่ที่ถูกเพิ่ม
        -   `budgetGovernmentType`: ยอดเงินแยกตามประเภท (Type 5: แปรญัตติ, Type 6: เสนอจัดสรร, Type 8: คำขอแปรญัตติตาม พ.ร.บ.)
        -   `budgetCodeYear`: รหัสงบประมาณที่เลือกสำหรับแต่ละรายการ
3.  **การตรวจสอบความถูกต้อง (Validation)**:
    -   **รหัสงบประมาณ**: ต้องเลือกให้ครบถ้วนทุกแถว (หากไม่ครบจะแสดง Error และหยุดการทำงาน)
    -   **การตรวจสอบยอดเงิน**:
        -   เช็คว่ายอด "แปรญัตติ" เกินกว่า "คำขอแปรญัตติ" หรือไม่
        -   เช็คว่ายอด "เสนอจัดสรร" เกินกว่า "รวมคำขอ" หรือไม่
        -   หากเกิน ระบบจะแสดง Warning List รายการที่ผิดปกติ แต่ยังอนุญาตให้ "ยืนยันซ้ำ" เพื่อบันทึกได้
4.  **การส่งข้อมูล (AJAX Call)**: 
    ระบบจะเรียกฟังก์ชัน `SaveAndConfirmBudgetAllocateDetail` ซึ่งมีการยิง AJAX 2 รอบต่อเนื่องกัน:
    -   **รอบที่ 1 (Save)**: ส่งไปที่ `/Budget/SaveBudgetAllocateDetail` เพื่อบันทึกข้อมูลงฐานข้อมูล OAG
    -   **รอบที่ 2 (Confirm)**: ส่งไปที่ `/Budget/ConfirmBudgetAllocatePlan` เพื่อเปลี่ยนสถานะเป็น 'C' และส่งข้อมูลเข้าฐานข้อมูลบัญชี (Oracle EBS)

---

## 2. การทำงานในส่วน Web Controller (C#)

### BudgetController (ฝั่ง Web)
ทำหน้าที่รับข้อมูลจาก UI และเรียกใช้ Interface `_budgetService`:
-   `SaveBudgetAllocateDetail`: บันทึกข้อมูลตั้งต้น (Draft)
-   `ConfirmBudgetAllocatePlan`: สั่งยืนยันแผนงบประมาณทั้งปี

---

## 3. การทำงานในส่วน Backend API และ Business Logic

### ขั้นตอนที่ 1: การบันทึกข้อมูล (SaveBudgetAllocateDetail)
-   **Internal DB Update**: 
    -   บันทึกข้อมูลลงตาราง `OagwbgBudgetgovernments` (สถานะเริ่มต้นเป็น 'B' หรือ 'U')
    -   หากเป็นรายการใหม่ ระบบจะสร้างรายการใน `OagwbgBudgetdisbursementplanitems` ให้ครบทั้ง 12 เดือนโดยอัตโนมัติ
    -   บันทึกความสัมพันธ์ของรหัสงบประมาณใน `OagwbgBudgetcodeYears`

### ขั้นตอนที่ 2: การยืนยันแผน (ConfirmBudgetAllocatePlan)
ทำงานใน `Services/Repository/BudgetService.cs` (Line 4596) ดังนี้:
1.  **เปลี่ยนสถานะ**: ค้นหารายการทั้งหมดในปีและประเภทฟอร์มนั้นที่มีสถานะเป็น 'B' (Draft) และเปลี่ยนเป็น 'C' (Confirmed)
2.  **การเชื่อมต่อระบบบัญชี (Oracle EBS Interface)**:
    หาก `isConnection` เป็นจริง ระบบจะเรียก `SaveBudgetAllocate` (Line 8843) เพื่อส่งข้อมูลเข้า **Oracle EBS**:
    -   ดึงข้อมูลยอดเงิน (Allocate + Adjusted)
    -   คำนวณ **GL Segments ทั้ง 13 ตัว** ตามรหัสบัญชีและประเภทรายจ่าย
    -   สร้างรายการบันทึกประวัติใน `OagwbgLogInterface`
    -   เรียก `SaveInterface` เพื่อส่งข้อมูลเข้าตาราง Interface ใน Oracle
3.  **อัปเดตแผนการเบิกจ่าย**: ตรวจสอบและเชื่อมโยงรายการเบิกจ่ายรายเดือนเข้ากับแผนงบประมาณประจำปี

---

## 4. การส่งและการใช้งาน Interface

-   **IBudgetService**: ใช้สื่อสารระหว่าง UI Controller และ API Logic
-   **IAuthService**: ใช้เพื่อดึงข้อมูล User สำหรับบันทึกประวัติการสร้าง (`Createby`) และแก้ไข (`Updateby`)
-   **IEbsContext**: ใช้เพื่อขอ Connection String และจัดการการเชื่อมต่อกับระบบ Oracle EBS
-   **OagwbgContext (Entity Framework)**: ใช้สำหรับจัดการ Transaction ภายในฐานข้อมูล Oracle ของ OAG เช่น การเพิ่มรายการแผนงาน (Product/Activity) และรายการใช้จ่าย (Category)

---
*หมายเหตุ: ข้อมูลอ้างอิงจากรหัสต้นฉบับในโปรเจกต์ OAG Budget และ OAGBudget.API ณ วันที่ 10/04/2026*
