-- =====================================================================
-- หน้าจัดสรรงบประมาณ (BudgetAllocateDetail) — เก็บยอดรายคำขอ + ทศนิยมยอดแปรญัตติ
-- ตาราง: OAGWBG.OAGWBG_BUDGETGOVERNMENT
--
-- (1) เพิ่มคอลัมน์ REQ_* (ใช้เฉพาะ record ระดับคำขอ: BUDGETGOVERNMENTTYPE IS NULL/'7' และ BUDGETREQUESTID <> 0)
--     ยอดคำขอแปรญัตติ/เสนอจัดสรร/แปรญัตติ เก็บเป็นยอดรวมระดับรายการใน record type 8/6/5
--     หน้าจอให้กรอกรายคำขอแล้วรวมเป็นยอดรายการ จึงต้องมีที่เก็บยอดรายคำขอไว้แสดงตอนเปิดใหม่
--     ไม่ใช้คอลัมน์ TOTALALLOCATEAMOUNT เดิมของ record คำขอ เพราะ OAGWBG_V_BUDGETREMAINLIST
--     SUM(TOTALALLOCATEAMOUNT) ทุกแถวโดยไม่กรอง type — ยอดจะนับซ้ำ
--     คอลัมน์ REQ_* ไม่ถูก map ใน EF entity (อ่าน/เขียนผ่าน raw SQL) — deploy โค้ดก่อนหรือหลัง DDL ก็ได้
--
-- (2) ขยาย TOTALADJUSTEDAMOUNT / TOTALREQUESTADJUSTAMOUNT จาก NUMBER(12,0) เป็น NUMBER(14,2)
--     ให้เก็บทศนิยมได้ (เดิมยอดแปรญัตติที่มีทศนิยมถูกปัดทิ้ง) โดยจำนวนเต็มยังได้ 12 หลักเท่าเดิม
--     (ข้อมูลจริง ณ 2026-09-29: TOTALREQUESTADJUSTAMOUNT สูงสุด 114,262,600 — NUMBER(10,2) เก็บไม่พอ)
--     ⚠️ ต้อง deploy (2) ก่อนโค้ดชุดนี้ — EF map สองคอลัมน์นี้เป็น decimal(14,2) แล้ว
--        ถ้าบันทึกทศนิยมลง NUMBER(12,0) Oracle จะปัดทิ้งเหมือนเดิม (ไม่ error) แต่ตั้งใจให้ได้ทศนิยม
--     ถ้า MODIFY ถูกปฏิเสธด้วย ORA-01440 ให้ใช้วิธีสำรองท้ายไฟล์
-- =====================================================================

-- (1) ยอดรายคำขอ
ALTER TABLE OAGWBG.OAGWBG_BUDGETGOVERNMENT ADD (
    REQ_TOTALREQUESTADJUSTAMOUNT NUMBER(14,2),
    REQ_TOTALALLOCATEAMOUNT      NUMBER(14,2),
    REQ_TOTALADJUSTEDAMOUNT      NUMBER(14,2)
);

COMMENT ON COLUMN OAGWBG.OAGWBG_BUDGETGOVERNMENT.REQ_TOTALREQUESTADJUSTAMOUNT IS 'คำขอแปรญัตติ รายคำขอ (หน้าจัดสรร) — ยอดรวมระดับรายการอยู่ที่ record type 8';
COMMENT ON COLUMN OAGWBG.OAGWBG_BUDGETGOVERNMENT.REQ_TOTALALLOCATEAMOUNT IS 'เสนอจัดสรร รายคำขอ (หน้าจัดสรร) — ยอดรวมระดับรายการอยู่ที่ record type 6';
COMMENT ON COLUMN OAGWBG.OAGWBG_BUDGETGOVERNMENT.REQ_TOTALADJUSTEDAMOUNT IS 'แปรญัตติ รายคำขอ (หน้าจัดสรร) — ยอดรวมระดับรายการอยู่ที่ record type 5';

-- (2) ทศนิยมยอดแปรญัตติ
ALTER TABLE OAGWBG.OAGWBG_BUDGETGOVERNMENT MODIFY (
    TOTALADJUSTEDAMOUNT      NUMBER(14,2),
    TOTALREQUESTADJUSTAMOUNT NUMBER(14,2)
);

-- ตรวจหลัง deploy
-- SELECT COLUMN_NAME, DATA_TYPE, DATA_PRECISION, DATA_SCALE FROM ALL_TAB_COLUMNS
--  WHERE OWNER = 'OAGWBG' AND TABLE_NAME = 'OAGWBG_BUDGETGOVERNMENT'
--    AND (COLUMN_NAME LIKE 'REQ\_%' ESCAPE '\' OR COLUMN_NAME IN ('TOTALADJUSTEDAMOUNT', 'TOTALREQUESTADJUSTAMOUNT'));

-- Rollback (1)
-- ALTER TABLE OAGWBG.OAGWBG_BUDGETGOVERNMENT DROP (REQ_TOTALREQUESTADJUSTAMOUNT, REQ_TOTALALLOCATEAMOUNT, REQ_TOTALADJUSTEDAMOUNT);
-- Rollback (2): ย้อนเป็น NUMBER(12,0) ไม่ได้ถ้ามีข้อมูลแล้ว (ลด scale ต้องให้คอลัมน์ว่าง) — ต้องใช้วิธีสำรองกลับทาง

-- วิธีสำรองของ (2) กรณี ORA-01440 (ทำทีละคอลัมน์ ช่วงไม่มีคนใช้งาน):
-- ALTER TABLE OAGWBG.OAGWBG_BUDGETGOVERNMENT ADD (TOTALADJUSTEDAMOUNT_NEW NUMBER(14,2));
-- UPDATE OAGWBG.OAGWBG_BUDGETGOVERNMENT SET TOTALADJUSTEDAMOUNT_NEW = TOTALADJUSTEDAMOUNT;
-- ALTER TABLE OAGWBG.OAGWBG_BUDGETGOVERNMENT DROP COLUMN TOTALADJUSTEDAMOUNT;   -- ⚠️ view ที่อ้างคอลัมน์จะ INVALID ชั่วคราว
-- ALTER TABLE OAGWBG.OAGWBG_BUDGETGOVERNMENT RENAME COLUMN TOTALADJUSTEDAMOUNT_NEW TO TOTALADJUSTEDAMOUNT;
-- (ทำซ้ำกับ TOTALREQUESTADJUSTAMOUNT แล้ว recompile view ที่ INVALID)
