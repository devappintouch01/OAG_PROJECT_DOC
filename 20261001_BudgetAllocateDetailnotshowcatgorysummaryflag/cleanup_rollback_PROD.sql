-- rollback ของ cleanup_delete_PROD.sql: INSERT แถวที่ลบกลับจากตาราง backup
--   OAGWBG_BK1001_DUMMY_BG  → OAGWBG_BUDGETGOVERNMENT
--   OAGWBG_BK1001_DUMMY_DPI → OAGWBG_BUDGETDISBURSEMENTPLANITEM
-- PROD: 172.16.11.18:1531 / SERVICE_NAME=PROD / User=OAGWBG
-- ⚠️ ใช้ได้เมื่อยังไม่ได้ DROP ตาราง BK (STEP 6 ของ cleanup_delete_PROD.sql)
-- ⚠️ ใช้ SELECT * ได้เพราะตาราง BK สร้างด้วย CTAS จากตารางต้นทาง (คอลัมน์ลำดับเดียวกัน)
--    ถ้ามีการ ALTER เพิ่มคอลัมน์ในตารางต้นทางหลังลบ ให้ระบุชื่อคอลัมน์เองแทน *


-- ---------- STEP 1: ต้องได้ 0 ทั้งสองตัว (แถวยังไม่ถูกคืน — ถ้าไม่ใช่ 0 หยุด) ----------
SELECT COUNT(*) AS EXIST_BG  FROM OAGWBG.OAGWBG_BUDGETGOVERNMENT           WHERE ID IN (SELECT ID FROM OAGWBG.OAGWBG_BK1001_DUMMY_BG);
SELECT COUNT(*) AS EXIST_DPI FROM OAGWBG.OAGWBG_BUDGETDISBURSEMENTPLANITEM WHERE ID IN (SELECT ID FROM OAGWBG.OAGWBG_BK1001_DUMMY_DPI);


-- ---------- STEP 2: INSERT คืน (พ่อก่อนลูก) ----------
INSERT INTO OAGWBG.OAGWBG_BUDGETGOVERNMENT
SELECT * FROM OAGWBG.OAGWBG_BK1001_DUMMY_BG;

INSERT INTO OAGWBG.OAGWBG_BUDGETDISBURSEMENTPLANITEM
SELECT * FROM OAGWBG.OAGWBG_BK1001_DUMMY_DPI;


-- ---------- STEP 3: ตรวจ — ต้องเท่ากับจำนวนในตาราง BK ----------
SELECT (SELECT COUNT(*) FROM OAGWBG.OAGWBG_BUDGETGOVERNMENT           WHERE ID IN (SELECT ID FROM OAGWBG.OAGWBG_BK1001_DUMMY_BG))  AS RESTORED_BG,
       (SELECT COUNT(*) FROM OAGWBG.OAGWBG_BK1001_DUMMY_BG)                                                                    AS BK_BG,
       (SELECT COUNT(*) FROM OAGWBG.OAGWBG_BUDGETDISBURSEMENTPLANITEM WHERE ID IN (SELECT ID FROM OAGWBG.OAGWBG_BK1001_DUMMY_DPI)) AS RESTORED_DPI,
       (SELECT COUNT(*) FROM OAGWBG.OAGWBG_BK1001_DUMMY_DPI)                                                                   AS BK_DPI
FROM   DUAL;

-- ตรงกันครบ → COMMIT;
-- COMMIT;
