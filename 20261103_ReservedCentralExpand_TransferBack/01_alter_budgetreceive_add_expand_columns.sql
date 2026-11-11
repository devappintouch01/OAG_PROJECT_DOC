-- OAGWBG_BUDGETRECEIVE: คอลัมน์สำหรับแถวรับตัดยอดของ PO/PR ที่ขยายจากเงินกันส่วนกลาง (BUDGETRECEIVETYPE = 'E')
--
-- ที่มา: ยอด EXPAND_PO / EXPAND_PR ของใบเงินกันส่วนกลาง (region C) อยู่ใน OAGWBG_BUDGETRESERVEDITEM อย่างเดียว
--   ไม่มีแถวใน BUDGETRECEIVE หน้าโอนกลับจึงค้นไม่เจอ (เช่น 681203: ยอดใบ 25,874,940 = ถัง O 25,837,440 + PO/PR 37,500)
--   view OAGWBG_V_BUDGETRECEIVESUMMARY_REFUND (ไฟล์ 03) จะ UNION ยอดขยายรอบล่าสุดเข้ามา และเมื่อบันทึกใบโอนกลับ
--   ระบบจะสร้างแถว 'E' (ยอดรับ 0) ไว้รับการตัดยอด
--
-- ทำไมต้องมีคอลัมน์ใหม่:
--   OVERLAPYEAR/OVERLAPROUND — ยอดขยายรอบใหม่ถูกกรอกโดยหักยอดที่โอนกลับไปแล้ว (ผู้ใช้ยืนยัน 2026-11-03)
--     view จึงต้องหักเฉพาะแถว 'E' ของรอบล่าสุด แถวรอบก่อนต้องไม่ถูกนับซ้ำ
--   BUDGETCODEID — รหัสงบใน ACCOUNTCODE ของรายการไม่จำเป็นต้องตรงกับ BUDGETRESERVED_CATEGORY.BUDGETCODEID
--     (PREPROD ใบ 68030001: รายการ ...004100281 / category ...004100000)
--   ห้ามใช้ RESERVE1/RESERVE2 แทน: OAGWBG_V_BUDGET_TRANSFER_DETAIL_INTERFACE อ่านเป็น GL SEGMENT12/13
--
-- ⚠️ ลำดับ deploy: ไฟล์นี้ → 03 (view) → โค้ด API
--   โค้ดที่ map คอลัมน์ใหม่ขึ้นก่อน ALTER = ทุก query ที่แตะ OAGWBG_BUDGETRECEIVE พัง ORA-00904
--   โค้ดเดิมไม่กระทบ (EF ไม่อ่านคอลัมน์ที่ไม่ได้ map)
-- ถอยกลับ: 99_rollback.sql

ALTER TABLE OAGWBG.OAGWBG_BUDGETRECEIVE ADD (
  OVERLAPYEAR   NUMBER,
  OVERLAPROUND  NUMBER,
  BUDGETCODEID  VARCHAR2(50)
);

COMMENT ON COLUMN OAGWBG.OAGWBG_BUDGETRECEIVE.OVERLAPYEAR  IS 'แถว E: ปีของรอบขยายเงินกันส่วนกลาง (OAGWBG_BUDGETRESERVEDITEM.OVERLAPYEAR)';
COMMENT ON COLUMN OAGWBG.OAGWBG_BUDGETRECEIVE.OVERLAPROUND IS 'แถว E: รอบขยายเงินกันส่วนกลาง (OAGWBG_BUDGETRESERVEDITEM.OVERLAPROUND)';
COMMENT ON COLUMN OAGWBG.OAGWBG_BUDGETRECEIVE.BUDGETCODEID IS 'แถว E: รหัสงบ (segment 9) จาก ACCOUNTCODE ของรายการขยาย';

-- ตรวจ: ต้องได้ 3 แถว
SELECT COLUMN_NAME, DATA_TYPE, DATA_LENGTH, NULLABLE
  FROM ALL_TAB_COLUMNS
 WHERE OWNER = 'OAGWBG' AND TABLE_NAME = 'OAGWBG_BUDGETRECEIVE'
   AND COLUMN_NAME IN ('OVERLAPYEAR', 'OVERLAPROUND', 'BUDGETCODEID');
