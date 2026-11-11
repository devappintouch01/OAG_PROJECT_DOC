-- =============================================================================
-- 02_backfill.sql
-- เติมค่า BUDGETGOVERNMENTITEMID ให้ข้อมูลเดิม
--
-- สำรวจข้อมูลจริง PREPROD 2026-08-27 (OAGWBG_BUDGETGOVERNMENTASSETITEM = 124,053 แถว / 783 คำขอ):
--   +---------------------------+---------+-------------+
--   | กลุ่ม                      | จำนวน gov | แถวครุภัณฑ์  |
--   +---------------------------+---------+-------------+
--   | มีรายการค่าใช้จ่าย 1 รายการ  |   711   |    1,213    |  <- map ได้แน่นอน
--   | มีรายการค่าใช้จ่าย > 1       |    68   |  122,836    |  <- กำกวม
--   | ไม่มีรายการค่าใช้จ่ายเลย     |     4   |        4    |  <- ขยะ
--   +---------------------------+---------+-------------+
--   * ในกลุ่มกำกวม BUDGETGOVERNMENTID = 45600 ตัวเดียวกิน 121,710 แถว
--     (เกิดจากการกด "เลือกรายการทั้งหมด" สมัยที่ยังไม่มีเพดานจำนวน)
--     เหลือของจริงที่กำกวมแค่ 67 คำขอ / 1,126 แถว
-- =============================================================================


-- ---------------------------------------------------------------------------
-- STEP 0: ตรวจสภาพก่อนแก้ (รันดูก่อนเสมอ)
-- ---------------------------------------------------------------------------
WITH x AS (
  SELECT g.ID govid,
         (SELECT COUNT(*) FROM OAGWBG.OAGWBG_BUDGETGOVERNMENTITEM      gi WHERE gi.BUDGETGOVERNMENTID = g.ID) item_cnt,
         (SELECT COUNT(*) FROM OAGWBG.OAGWBG_BUDGETGOVERNMENTASSETITEM ga WHERE ga.BUDGETGOVERNMENTID = g.ID) asset_cnt
  FROM   OAGWBG.OAGWBG_BUDGETGOVERNMENT g
  WHERE  EXISTS (SELECT 1 FROM OAGWBG.OAGWBG_BUDGETGOVERNMENTASSETITEM a WHERE a.BUDGETGOVERNMENTID = g.ID)
)
SELECT CASE WHEN item_cnt = 0 THEN '0 item (orphan)'
            WHEN item_cnt = 1 THEN '1 item (auto-map)'
            ELSE '>1 item (ambiguous)' END AS bucket,
       COUNT(*) gov_cnt, SUM(asset_cnt) asset_rows
FROM   x
GROUP  BY CASE WHEN item_cnt = 0 THEN '0 item (orphan)'
               WHEN item_cnt = 1 THEN '1 item (auto-map)'
               ELSE '>1 item (ambiguous)' END;


-- ---------------------------------------------------------------------------
-- STEP 1 [บังคับ]: คำขอที่มีรายการค่าใช้จ่ายเดียว -> ผูกตรง ๆ ไม่มีทางผิด
--                  (คาดว่ากระทบ 1,213 แถว)
-- ---------------------------------------------------------------------------
UPDATE OAGWBG.OAGWBG_BUDGETGOVERNMENTASSETITEM ga
SET    ga.BUDGETGOVERNMENTITEMID =
       (SELECT MIN(gi.ID) FROM OAGWBG.OAGWBG_BUDGETGOVERNMENTITEM gi
        WHERE  gi.BUDGETGOVERNMENTID = ga.BUDGETGOVERNMENTID)
WHERE  ga.BUDGETGOVERNMENTITEMID IS NULL
AND    (SELECT COUNT(*) FROM OAGWBG.OAGWBG_BUDGETGOVERNMENTITEM gi
        WHERE  gi.BUDGETGOVERNMENTID = ga.BUDGETGOVERNMENTID) = 1;

-- COMMIT;


-- ---------------------------------------------------------------------------
-- STEP 2 [ทางเลือก A — แนะนำ]: กลุ่มกำกวม ปล่อยเป็น NULL
--   หน้าจอจะแสดงครุภัณฑ์กลุ่มนี้ในถัง "ยังไม่ระบุรายการค่าใช้จ่าย"
--   ให้ผู้ใช้ลากเข้ารายการเองตอนแก้ไขคำขอครั้งถัดไป
--   => ไม่ต้องรัน SQL อะไรเพิ่ม แต่ต้องมี UI รองรับ (ดู implementation_plan.md §6)
-- ---------------------------------------------------------------------------


-- ---------------------------------------------------------------------------
-- STEP 2 [ทางเลือก B]: กลุ่มกำกวม เดาด้วยลำดับ + จำนวนหน่วยนับ
--   ใช้ตรรกะเดียวกับ view รายงาน OAGWBG_R_BUDGETREQUEST_ASSET เดิม
--   (ครุภัณฑ์ลำดับที่ k -> รายการค่าใช้จ่ายที่ช่วง QUANTITY สะสมครอบ k)
--   ครุภัณฑ์ที่เกินผลรวม QUANTITY จะยังเป็น NULL
--
--   ⚠ ควร EXCLUDE BUDGETGOVERNMENTID = 45600 (121,710 แถวขยะ) ออกก่อน
-- ---------------------------------------------------------------------------
-- MERGE INTO OAGWBG.OAGWBG_BUDGETGOVERNMENTASSETITEM t
-- USING (
--   WITH a AS (
--     SELECT ID, BUDGETGOVERNMENTID,
--            ROW_NUMBER() OVER (PARTITION BY BUDGETGOVERNMENTID ORDER BY ID) rn
--     FROM   OAGWBG.OAGWBG_BUDGETGOVERNMENTASSETITEM
--     WHERE  BUDGETGOVERNMENTITEMID IS NULL
--     AND    BUDGETGOVERNMENTID <> 45600
--   ), i AS (
--     SELECT ID, BUDGETGOVERNMENTID,
--            SUM(NVL(QUANTITY,0)) OVER (PARTITION BY BUDGETGOVERNMENTID ORDER BY ID) AS hi,
--            SUM(NVL(QUANTITY,0)) OVER (PARTITION BY BUDGETGOVERNMENTID ORDER BY ID)
--              - NVL(QUANTITY,0) + 1 AS lo
--     FROM   OAGWBG.OAGWBG_BUDGETGOVERNMENTITEM
--   )
--   SELECT a.ID AS asset_row_id, i.ID AS item_id
--   FROM   a JOIN i ON i.BUDGETGOVERNMENTID = a.BUDGETGOVERNMENTID
--                  AND a.rn BETWEEN i.lo AND i.hi
-- ) s ON (t.ID = s.asset_row_id)
-- WHEN MATCHED THEN UPDATE SET t.BUDGETGOVERNMENTITEMID = s.item_id;
--
-- COMMIT;


-- ---------------------------------------------------------------------------
-- STEP 3 [ทางเลือก — ต้องได้รับอนุมัติ R1]: ล้างข้อมูลขยะ
--   3.1 คำขอ 45600: 121,710 แถวจากการกดเลือกทั้งหมด (98% ของทั้งตาราง)
--   3.2 ครุภัณฑ์ที่ชี้ไปยัง BUDGETGOVERNMENT ที่ไม่มีรายการค่าใช้จ่ายเลย (4 แถว)
--   ** สำรอง CTAS ก่อนลบเสมอ **
-- ---------------------------------------------------------------------------
-- CREATE TABLE OAGWBG.BK_BGASSETITEM_20260827 AS
--   SELECT * FROM OAGWBG.OAGWBG_BUDGETGOVERNMENTASSETITEM;
--
-- DELETE FROM OAGWBG.OAGWBG_BUDGETGOVERNMENTASSETITEM WHERE BUDGETGOVERNMENTID = 45600;
--
-- DELETE FROM OAGWBG.OAGWBG_BUDGETGOVERNMENTASSETITEM ga
-- WHERE  NOT EXISTS (SELECT 1 FROM OAGWBG.OAGWBG_BUDGETGOVERNMENTITEM gi
--                    WHERE gi.BUDGETGOVERNMENTID = ga.BUDGETGOVERNMENTID);
-- COMMIT;


-- ---------------------------------------------------------------------------
-- VERIFY หลัง backfill
-- ---------------------------------------------------------------------------
SELECT COUNT(*) total,
       SUM(CASE WHEN BUDGETGOVERNMENTITEMID IS NULL THEN 1 ELSE 0 END) still_null,
       SUM(CASE WHEN BUDGETGOVERNMENTITEMID IS NOT NULL THEN 1 ELSE 0 END) linked
FROM   OAGWBG.OAGWBG_BUDGETGOVERNMENTASSETITEM;

-- ต้องได้ 0 แถว: link ข้ามคำขอ (ผิดแน่นอน)
SELECT ga.ID, ga.BUDGETGOVERNMENTID, ga.BUDGETGOVERNMENTITEMID, gi.BUDGETGOVERNMENTID AS item_gov
FROM   OAGWBG.OAGWBG_BUDGETGOVERNMENTASSETITEM ga
JOIN   OAGWBG.OAGWBG_BUDGETGOVERNMENTITEM      gi ON gi.ID = ga.BUDGETGOVERNMENTITEMID
WHERE  gi.BUDGETGOVERNMENTID <> ga.BUDGETGOVERNMENTID;

-- ต้องได้ 0 แถว: ชี้ไปยัง item ที่ไม่มีอยู่จริง
SELECT COUNT(*) dangling
FROM   OAGWBG.OAGWBG_BUDGETGOVERNMENTASSETITEM ga
WHERE  ga.BUDGETGOVERNMENTITEMID IS NOT NULL
AND    NOT EXISTS (SELECT 1 FROM OAGWBG.OAGWBG_BUDGETGOVERNMENTITEM gi
                   WHERE gi.ID = ga.BUDGETGOVERNMENTITEMID);
