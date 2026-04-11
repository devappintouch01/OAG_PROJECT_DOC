# ขั้นตอนการทำงานเมื่อกดปุ่ม "บันทึก" (id="btn-save") ใน BudgetAllocateTransferDetail.cshtml

เอกสารฉบับนี้อธิบายลำดับเทคนิคการทำงาน (Technical Workflow) ตั้งแต่หน้าจอ UI (jQuery) จนถึงการบันทึกลงฐานข้อมูล Oracle และการอินเทอร์เฟซไปยัง Oracle EBS

## 1. ฝั่งหน้าจอ (UI - jQuery)
เมื่อผู้ใช้งานกดปุ่ม **"บันทึก"** (`#btn-save`) ระบบจะทำงานดังนี้:

1.  **การตรวจสอบข้อมูลเบื้องต้น (Validation):**
    *   ตรวจสอบว่าเลือก **ภาค (Region)**, **หน่วยงานที่โอน (TransferOrgType)** และ **วันที่โอน (Transferdate)** ครบถ้วนหรือไม่
2.  **เรียกฟังก์ชัน `SaveBudgetAllocateTransferDetail()`:**
    *   รวบรวมข้อมูลส่วนหัว (Header) เช่น เลขที่หนังสือ, วันที่โอน, แหล่งเงิน ฯลฯ
    *   รวบรวมรายการงบประมาณจากตารางหลัก (`periodData`) ลงใน `items[]`
    *   รวบรวมรายละเอียดศูนย์ต้นทุนจากแท็บ "รายชื่อศูนย์ต้นทุนที่โอนจัดสรร" ลงใน `costCenterItems[]`
    *   ส่งข้อมูลทั้งหมดแบบ JSON ไปยัง Controller ใน C# ด้วยวิธีการ **AJAX POST** ไปที่:
        `@Url.Action("SaveBudgetAllocateTransferDetail", "Budget")`

---

## 2. ฝั่ง Controller (C#)
1.  **MVC Controller (`BudgetController.cs`):** รับ Request และส่งต่อ (Proxy) ไปยัง API Layer
2.  **API Controller (`OAGBudget.API/Controllers/BudgetController.cs`):**
    *   เรียกใช้ Method `SaveBudgetAllocateTransferDetail` ใน `BudgetService.cs`

---

## 3. ฐานข้อมูลและ Business Logic (`BudgetService.cs`)
ฟังก์ชันหลัก: `SaveBudgetAllocateTransferDetail` (บรรทัดที่ ~8175)

1.  **บันทึกข้อมูลส่วนหัว (`OAGWBG_BUDGETALLOCATETRANSFER`):**
    *   **กรณีเพิ่มใหม่ (Insert):** ระบบจะคำนวณเลขที่โอน (`Roundno`) อัตโนมัติโดยใช้ `ResolveRoundNoAsync` (รูปแบบปี + รหัสหน่วยโอน + Running 4 หลัก)
    *   **กรณีแก้ไข (Update):** อัปเดตข้อมูลเดิมตาม `Id`
2.  **บันทึกรายการงบประมาณ (`OAGWBG_BUDGETALLOCATETRANSFER_CATEGORY`):**
    *   เรียกใช้ `CollectionHelper.SaveCollectionAsync` เพื่อทำ Synchronize ข้อมูล (Add/Update/Remove)
3.  **บันทึกศูนย์ต้นทุน (`OAGWBG_BUDGETALLOCATETRANSFER_COSTCENTER`):**
    *   บันทึกข้อมูลการจัดสรรแต่ละศูนย์ต้นทุนลงในตารางคู่ขนาน

---

## 4. การยืนยันรายการและการคำนวณ 13 GL Segments
เมื่อผู้ใช้งานกดปุ่ม **"ยืนยัน"** (`#btn-Confirm`) ระบบจะเรียก `ConfirmBudgetAllocateTransfer` ซึ่งทำงานดังนี้:

### การคำนวณ 13 GL Segments (ใน `SaveBudgetAllocateTransfer`)
ระบบจะทำการ Map ข้อมูลประเภทค่าใช้จ่ายและรายการงบประมาณเป็น Segment เพื่อส่งไป Oracle EBS ดังนี้:

| Segment | ชื่อที่ใช้ในระบบ | แหล่งที่มาของข้อมูล |
| :--- | :--- | :--- |
| **Segment 1** | กรม | "2900600000" (Default) |
| **Segment 2** | หน่วยงาน | "2900600000" (Default) |
| **Segment 3** | ปีงบประมาณ | ปีงบประมาณ (2 หลักท้าย เช่น '67') |
| **Segment 4** | แหล่งเงิน | `BudgetSourceId` จากรายการงบประมาณ |
| **Segment 5** | แผนงาน | `BudgetPlanId` หรือจาก `ExpenseAccountRule` |
| **Segment 6** | ผลผลิต | `ProductId` ของรายการนั้นๆ |
| **Segment 7** | กิจกรรมหลัก | `ActivityId` ของรายการนั้นๆ |
| **Segment 8** | รหัสงบประมาณ | `BudgetTypeId` จาก `ExpenseAccountRule` |
| **Segment 9** | รหัสรายการงบประมาณ | `BudgetCodeId` (เช่น 5101020199) |
| **Segment 10** | รหัสบัญชีแยกประเภท | `AccountNo` จาก `ExpenseAccountRule` |
| **Segment 11** | รหัสบัญชีย่อย | `SubAccountNo` จาก `ExpenseAccountRule` |
| **Segment 12** | รหัสจัดสรร 1 | "00" |
| **Segment 13** | รหัสจัดสรร 2 | "000" |

### ลำดับการ Interface ไป Oracle EBS:
1.  คำนวณ Segment ทั้ง 13 ตัว
2.  บันทึก Log ลงตาราง `OAGWBG_LOG_INTERFACE` (ในฝั่ง Oracle OAG)
3.  เรียกใช้ `SaveInterface` เพื่อ Insert ข้อมูลลงในอินเทอร์เฟซเทเบิลของ Oracle EBS โดยตรง:
    *   ตาราง: `oagwbg.oaggl_journal_interface`
4.  ตรวจสอบยอดเงินคงเหลือ (Budget Check) ผ่านฟังก์ชัน `GetTotalBudget` ก่อนส่ง

---

## 5. การปรับปรุงยอดคงเหลือ (Balance Update)
หลังจากการ Interface สำเร็จ ระบบจะอัปเดตสถานะเป็น `80201` และไปปรับปรุงยอดในตาราง **`OAGWBG_BUDGETRECEIVE`**:
*   ระบบจะทำการ **หักยอด (Deduct)** จาก `Totalbalanceamount` เดิม
*   ระบบจะบันทึก `Totaltransferamount` (ยอดที่โอนไปแล้ว) เพิ่มเติม เพื่อให้ทราบประวัติการโอนจัดสรรจากยอดรับงบประมาณก้อนนั้นๆ
