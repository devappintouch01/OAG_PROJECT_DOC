-- =============================================================================
-- 01_alter_table_add_column.sql
-- เพิ่มคอลัมน์ผูก "รายการครุภัณฑ์ทดแทน" -> "รายการค่าใช้จ่าย" (แท็บข้อมูลทั่วไป)
--
-- Target   : OAGWBG (PREPROD 172.16.11.19:1541/ebs_PRE)
-- Verified : 2026-08-27 — คอลัมน์นี้ยังไม่มีทั้งใน PREPROD และ TEST
-- Rollback : ดู 99_rollback.sql
-- =============================================================================

-- ---------------------------------------------------------------------------
-- STEP 1: เพิ่มคอลัมน์ (NULL ได้ เพื่อไม่กระทบข้อมูลเดิม 124,053 แถว)
-- ---------------------------------------------------------------------------
ALTER TABLE OAGWBG.OAGWBG_BUDGETGOVERNMENTASSETITEM
    ADD (BUDGETGOVERNMENTITEMID NUMBER(10));

COMMENT ON COLUMN OAGWBG.OAGWBG_BUDGETGOVERNMENTASSETITEM.BUDGETGOVERNMENTITEMID
    IS 'FK -> OAGWBG_BUDGETGOVERNMENTITEM.ID : รายการค่าใช้จ่ายในแท็บข้อมูลทั่วไปที่ครุภัณฑ์ทดแทนแถวนี้สังกัด (NULL = ข้อมูลเดิมก่อน 2569 ที่ยังไม่ได้ระบุ)';


-- ---------------------------------------------------------------------------
-- STEP 2: Index
--   IX_BGASSETITEM_BGITEMID : รองรับ query ใหม่ (ดึงครุภัณฑ์ของรายการค่าใช้จ่าย)
--   IX_BGASSETITEM_BGID     : ตารางนี้ "ไม่มี index บน BUDGETGOVERNMENTID เลย"
--                             (ตรวจสอบ 2026-08-27 มีแค่ PK บน ID) ทุก query ที่
--                             filter ด้วย BUDGETGOVERNMENTID จึง full scan 124K แถว
--                             — รวมถึง GetBudgetRequestExpensesDetail และ view รายงาน
-- ---------------------------------------------------------------------------
CREATE INDEX OAGWBG.IX_BGASSETITEM_BGITEMID
    ON OAGWBG.OAGWBG_BUDGETGOVERNMENTASSETITEM (BUDGETGOVERNMENTITEMID);

CREATE INDEX OAGWBG.IX_BGASSETITEM_BGID
    ON OAGWBG.OAGWBG_BUDGETGOVERNMENTASSETITEM (BUDGETGOVERNMENTID);


-- ---------------------------------------------------------------------------
-- STEP 3: Foreign Key — ❌ ตัดสินใจแล้วว่า "ไม่ทำ" (2026-08-27)
--
--   เหตุผล: อิงตาม convention ของ schema เดิม — OAGWBG มี FK แค่ 3 ตัว
--           จาก 66 ตาราง (ตรวจ user_constraints 2026-08-27:
--           P=66, C=293, U=1, R=3)
--
--   ผลที่ตามมา: ความถูกต้องของ link ขึ้นกับโค้ด 100% ต้องมั่นใจว่า
--     - SaveBudgetGovernmentItem ลบครุภัณฑ์ของรายการที่ถูกลบ ในทรานแซกชันเดียวกัน
--     - DuplicatePlanData remap BUDGETGOVERNMENTITEMID ให้ครบ
--     - รัน query ตรวจ integrity ท้าย 02_backfill.sql เป็นระยะหลัง deploy
-- ---------------------------------------------------------------------------


-- ---------------------------------------------------------------------------
-- VERIFY
-- ---------------------------------------------------------------------------
SELECT column_id, column_name, data_type, data_precision, nullable
FROM   user_tab_columns
WHERE  table_name = 'OAGWBG_BUDGETGOVERNMENTASSETITEM'
ORDER  BY column_id;

SELECT index_name, uniqueness FROM user_indexes
WHERE  table_name = 'OAGWBG_BUDGETGOVERNMENTASSETITEM';
