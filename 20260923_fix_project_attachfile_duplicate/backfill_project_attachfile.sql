-- =====================================================================
-- Backfill : ไฟล์แนบระดับ Project ที่หายไปตอนระบบ duplicate โครงการ
-- Target   : PROD (schema OAGWBG)
-- Date     : 2026-09-23   (rev.2 — ขยาย scope ครอบเส้น "อนุมัติ" ด้วย)
--
-- Root cause: DuplicateProjectChildren ไม่ได้ copy OAGWBG_ATTACHFILE
--             ที่ REFERENCETABLE = 'Project'  (ของ BudgetGovernment copy อยู่แล้ว)
--
-- มี 2 ปุ่มที่ทำให้เกิด ทั้งคู่อยู่ในหน้า "พิจารณาคำของบประมาณ" และเป็น
-- เฉพาะคำขอประเภทโครงการ (BUDGETFORMTYPEID = 2) เท่านั้น:
--
--   [แก้ไข]  statusId 20102 -> DuplicateBudgetRequest -> DuplicateProjectData
--            สร้างคำขอ version 2 ทั้งใบ + project ชุดใหม่  (TEMP ของลูก = ค่าเดิมที่ copy มา)
--            มี guard "duplicate first time only" (PARENTID ต้องเป็น NULL) กดซ้ำไม่งอกเพิ่ม
--
--   [อนุมัติ] statusId 20201 -> DuplicateProjectsInRequest
--            สร้าง project ชุดใหม่ "ในคำขอใบเดิม" และ stamp TEMP = id ของ project ต้นฉบับ
--            *** ไม่มี guard *** กดกี่ครั้ง duplicate กี่รอบ
--
-- !! รัน STEP 0 ให้ครบก่อนเสมอ ถ้าผลไม่ตรงกับที่คาดไว้ให้หยุด !!
-- !! STEP 2 ไม่มี COMMIT ในตัว — ตรวจ STEP 3 ก่อนแล้วค่อย COMMIT เอง !!
-- =====================================================================


-- =====================================================================
-- STEP 0 — PRE-CHECK  (read-only ทั้งหมด)
-- =====================================================================

-- 0.1 sequence ที่ trigger ใช้ ต้องไม่ต่ำกว่า MAX(ID) ไม่งั้น insert จะชน PK_OAGWBG_ATTACHFILE
--
--     ตารางนี้มี trigger BEFORE INSERT 2 ตัวที่ใช้คนละ sequence และเป็น
--     IF :NEW.ID IS NULL เหมือนกัน -> ตัวที่ fire ก่อนเป็นตัวที่ได้ใช้จริง
--        OAGWBG_ATTACHFILE_BI       -> SEQ_ATTACHFILE_ID
--        TRG_OAGWBG_ATTACHFILE_ID   -> SEQ_OAGWBG_ATTACHFILE_ID
--
--     วัดบน PREPROD 2026-09-23 ได้: SEQ_ATTACHFILE_ID = 1 (ค้าง ไม่ได้ถูกใช้)
--     ส่วน SEQ_OAGWBG_ATTACHFILE_ID = 2533 กับ MAX(ID) = 2532 -> ตัวนี้คือตัวที่ทำงานจริง
--
--     คาดหวังบน PROD: มี sequence อย่างน้อย 1 ตัวที่ LAST_NUMBER > MAX_ID
--     ถ้าทั้งสองตัวต่ำกว่า MAX_ID -> หยุด แจ้ง DBA ให้ปรับ sequence ก่อน
SELECT SEQUENCE_NAME, LAST_NUMBER, INCREMENT_BY, CACHE_SIZE
FROM   ALL_SEQUENCES
WHERE  SEQUENCE_NAME IN ('SEQ_ATTACHFILE_ID', 'SEQ_OAGWBG_ATTACHFILE_ID');

SELECT MAX(ID) AS MAX_ID, COUNT(*) AS N_ROWS FROM OAGWBG_ATTACHFILE;


-- 0.2 constraint ของตาราง — คาดหวัง 2 แถว (ยืนยันแล้วบน PREPROD)
--       PK_OAGWBG_ATTACHFILE          P  ID
--       UQ_OAGWBG_ATTACHFILE_ROWGUID  U  ROWGUID
--     นี่คือเหตุผลที่ STEP 2 ไม่ใส่ค่า ID และ ROWGUID เอง
SELECT c.CONSTRAINT_NAME, c.CONSTRAINT_TYPE, cc.COLUMN_NAME
FROM   ALL_CONSTRAINTS c
JOIN   ALL_CONS_COLUMNS cc ON cc.CONSTRAINT_NAME = c.CONSTRAINT_NAME AND cc.OWNER = c.OWNER
WHERE  c.TABLE_NAME = 'OAGWBG_ATTACHFILE' AND c.CONSTRAINT_TYPE IN ('P', 'U')
ORDER  BY c.CONSTRAINT_NAME;


-- 0.3 ความลึกของสายพันธุ์คำขอ — คาดหวัง 0 (แม่ -> ลูก ชั้นเดียว ไม่มีหลาน)
SELECT COUNT(*) AS GRANDCHILD_REQ
FROM   OAGWBG_BUDGETREQUEST c
WHERE  c.PARENTID IN (SELECT ID FROM OAGWBG_BUDGETREQUEST WHERE PARENTID IS NOT NULL);


-- 0.4 สุขภาพของคอลัมน์ TEMP — คาดหวัง 0 ทั้งสองค่า
--     DANGLING  = TEMP ชี้ไป project ที่ไม่มีอยู่จริง (mapping ก) จะตกหล่น)
--     CHAINED   = TEMP ชี้ไป project ที่ตัวเองก็มี TEMP (ถ้าไม่ 0 แปลว่ามีสายโซ่ ต้องดูก่อน)
SELECT
  SUM(CASE WHEN NOT EXISTS (SELECT 1 FROM OAGWBG_PROJECT pp WHERE pp.ID = cp.TEMP) THEN 1 ELSE 0 END) AS DANGLING,
  SUM(CASE WHEN EXISTS (SELECT 1 FROM OAGWBG_PROJECT pp WHERE pp.ID = cp.TEMP AND pp.TEMP IS NOT NULL) THEN 1 ELSE 0 END) AS CHAINED
FROM OAGWBG_PROJECT cp WHERE cp.TEMP IS NOT NULL;


-- 0.5 mapping ต้องเป็น 1:1 ทั้งสองทางในฝั่งลูก
--     คาดหวัง: PAIRS = DISTINCT_CHILD  (ลูก 1 ตัวต้องมีแม่ได้แค่ตัวเดียว)
--     DISTINCT_PARENT อาจน้อยกว่าได้ เพราะแม่ 1 ตัวมีลูกได้หลายตัว
--     (เช่น project 182 มีลูกทั้ง 270 จากปุ่มอนุมัติ และ 289/302 จากปุ่มแก้ไข)
WITH child_map AS (
    -- ก) ลูกที่ระบบ stamp TEMP ไว้ (ปุ่ม "อนุมัติ" -> DuplicateProjectsInRequest)
    --    ลูกอาจอยู่ในคำขอใบเดียวกับแม่ หรือในคำขอ version ใหม่ก็ได้
    --    จึงต้องไม่ผูกเงื่อนไขกับ PARENTID ของคำขอ
    SELECT cp.ID AS CHILD_PROJ, pp.ID AS PARENT_PROJ, 'TEMP' AS VIA
    FROM   OAGWBG_PROJECT cp
    JOIN   OAGWBG_PROJECT pp ON pp.ID = cp.TEMP
    WHERE  cp.TEMP IS NOT NULL
    UNION ALL
    -- ข) ลูกที่ TEMP เป็น NULL (ปุ่ม "แก้ไข" -> DuplicateBudgetRequest)
    --    จับคู่ด้วยชื่อโครงการภายในคู่คำขอแม่-ลูก
    SELECT cp.ID, pp.ID, 'NAME'
    FROM   OAGWBG_BUDGETREQUEST r
    JOIN   OAGWBG_PROJECT cp ON cp.BUDGETREQUESTID = r.ID       AND cp.TEMP IS NULL
    JOIN   OAGWBG_PROJECT pp ON pp.BUDGETREQUESTID = r.PARENTID AND pp.TEMP IS NULL
                            AND pp.PROJECTNAME = cp.PROJECTNAME
    WHERE  r.PARENTID IS NOT NULL
)
SELECT VIA,
       COUNT(*)                    AS PAIRS,
       COUNT(DISTINCT CHILD_PROJ)  AS DISTINCT_CHILD,
       COUNT(DISTINCT PARENT_PROJ) AS DISTINCT_PARENT
FROM   child_map
GROUP  BY VIA;


-- 0.6 จำนวนแถว/ขนาดที่จะ insert จริง (ตัวเลขนี้ต้องตรงกับที่ได้หลัง STEP 2)
WITH child_map AS (
    SELECT cp.ID AS CHILD_PROJ, pp.ID AS PARENT_PROJ
    FROM   OAGWBG_PROJECT cp
    JOIN   OAGWBG_PROJECT pp ON pp.ID = cp.TEMP
    WHERE  cp.TEMP IS NOT NULL
    UNION ALL
    SELECT cp.ID, pp.ID
    FROM   OAGWBG_BUDGETREQUEST r
    JOIN   OAGWBG_PROJECT cp ON cp.BUDGETREQUESTID = r.ID       AND cp.TEMP IS NULL
    JOIN   OAGWBG_PROJECT pp ON pp.BUDGETREQUESTID = r.PARENTID AND pp.TEMP IS NULL
                            AND pp.PROJECTNAME = cp.PROJECTNAME
    WHERE  r.PARENTID IS NOT NULL
)
SELECT COUNT(*)                            AS ROWS_TO_INSERT,
       COUNT(DISTINCT m.CHILD_PROJ)        AS CHILD_PROJECTS,
       ROUND(SUM(a.FILESIZE)/1024/1024, 1) AS MB
FROM   child_map m
JOIN   OAGWBG_ATTACHFILE a ON a.REFERENCETABLE = 'Project' AND a.REFERENCEID = m.PARENT_PROJ
WHERE  NOT EXISTS (SELECT 1 FROM OAGWBG_ATTACHFILE x
                   WHERE x.REFERENCETABLE = 'Project'
                     AND x.REFERENCEID = m.CHILD_PROJ
                     AND NVL(x.REFERENCEGROUP, '~') = NVL(a.REFERENCEGROUP, '~'));


-- 0.7 group ที่จะ "ข้าม" เพราะลูกมีไฟล์ในช่องนั้นอยู่แล้ว (คนอัปเองทีหลัง)
--     ดูให้ชัดว่ายอมรับได้ไหมที่ช่องนั้นจะไม่ได้ไฟล์ต้นฉบับกลับมา
SELECT m.CHILD_PROJ, m.PARENT_PROJ, a.REFERENCEGROUP,
       a.FILENAME AS PARENT_FILE,
       (SELECT MIN(x.FILENAME) FROM OAGWBG_ATTACHFILE x
        WHERE x.REFERENCETABLE = 'Project' AND x.REFERENCEID = m.CHILD_PROJ
          AND NVL(x.REFERENCEGROUP, '~') = NVL(a.REFERENCEGROUP, '~')) AS CHILD_FILE_ALREADY_THERE
FROM  (SELECT cp.ID AS CHILD_PROJ, pp.ID AS PARENT_PROJ
       FROM   OAGWBG_PROJECT cp
       JOIN   OAGWBG_PROJECT pp ON pp.ID = cp.TEMP
       WHERE  cp.TEMP IS NOT NULL
       UNION ALL
       SELECT cp.ID, pp.ID
       FROM   OAGWBG_BUDGETREQUEST r
       JOIN   OAGWBG_PROJECT cp ON cp.BUDGETREQUESTID = r.ID       AND cp.TEMP IS NULL
       JOIN   OAGWBG_PROJECT pp ON pp.BUDGETREQUESTID = r.PARENTID AND pp.TEMP IS NULL
                               AND pp.PROJECTNAME = cp.PROJECTNAME
       WHERE  r.PARENTID IS NOT NULL) m
JOIN   OAGWBG_ATTACHFILE a ON a.REFERENCETABLE = 'Project' AND a.REFERENCEID = m.PARENT_PROJ
WHERE  EXISTS (SELECT 1 FROM OAGWBG_ATTACHFILE x
               WHERE x.REFERENCETABLE = 'Project'
                 AND x.REFERENCEID = m.CHILD_PROJ
                 AND NVL(x.REFERENCEGROUP, '~') = NVL(a.REFERENCEGROUP, '~'))
ORDER  BY m.CHILD_PROJ, a.REFERENCEGROUP;


-- =====================================================================
-- STEP 1 — DRY RUN : ดูรายการที่จะ insert (ไม่ดึง BLOB)
-- =====================================================================
WITH child_map AS (
    SELECT cp.ID AS CHILD_PROJ, pp.ID AS PARENT_PROJ, 'TEMP' AS VIA,
           cp.BUDGETREQUESTID AS CHILD_REQ, pp.BUDGETREQUESTID AS PARENT_REQ
    FROM   OAGWBG_PROJECT cp
    JOIN   OAGWBG_PROJECT pp ON pp.ID = cp.TEMP
    WHERE  cp.TEMP IS NOT NULL
    UNION ALL
    SELECT cp.ID, pp.ID, 'NAME', cp.BUDGETREQUESTID, pp.BUDGETREQUESTID
    FROM   OAGWBG_BUDGETREQUEST r
    JOIN   OAGWBG_PROJECT cp ON cp.BUDGETREQUESTID = r.ID       AND cp.TEMP IS NULL
    JOIN   OAGWBG_PROJECT pp ON pp.BUDGETREQUESTID = r.PARENTID AND pp.TEMP IS NULL
                            AND pp.PROJECTNAME = cp.PROJECTNAME
    WHERE  r.PARENTID IS NOT NULL
)
SELECT m.VIA, m.PARENT_REQ, m.CHILD_REQ, m.PARENT_PROJ, m.CHILD_PROJ,
       a.ID AS SRC_FILE_ID, a.REFERENCEGROUP, a.FILENAME, a.FILESIZE
FROM   child_map m
JOIN   OAGWBG_ATTACHFILE a ON a.REFERENCETABLE = 'Project' AND a.REFERENCEID = m.PARENT_PROJ
WHERE  NOT EXISTS (SELECT 1 FROM OAGWBG_ATTACHFILE x
                   WHERE x.REFERENCETABLE = 'Project'
                     AND x.REFERENCEID = m.CHILD_PROJ
                     AND NVL(x.REFERENCEGROUP, '~') = NVL(a.REFERENCEGROUP, '~'))
ORDER  BY m.CHILD_REQ, m.CHILD_PROJ, a.REFERENCEGROUP;


-- =====================================================================
-- STEP 2 — INSERT  (ยังไม่ COMMIT)
--
-- คอลัมน์ที่ "ไม่" ใส่ค่าโดยตั้งใจ:
--   ID       -> trigger BEFORE INSERT gen ให้ (IF :NEW.ID IS NULL)
--   ROWGUID  -> column default SYS_GUID()  (มี unique constraint ห้าม copy ค่าเดิม)
--   CREATEBY -> default -1           }  ให้เหมือนกับที่ EF insert ตอน duplicate
--   CREATEON -> default SYSTIMESTAMP }
--   SEQUENCE -> NULL   (โค้ด duplicate เดิมก็ไม่ copy และหน้าจอไม่ได้ใช้ค้นหา)
--
-- UPDATEBY = -777 คือ marker สำหรับ rollback / ตรวจย้อนหลัง
-- (ตรวจแล้วว่า _RenderAttachFileList.cshtml ไม่ได้แสดงคอลัมน์นี้)
--
-- ถ้าอยากทยอยทำทีละคำขอ (ลด undo/redo) ให้เติมใน WHERE:
--     AND m.CHILD_REQ = <budgetRequestId>
-- =====================================================================
INSERT INTO OAGWBG_ATTACHFILE
       (REFERENCETABLE, REFERENCEID, REFERENCEGROUP, FILENAME, EXTENSION, FILEDATA, FILESIZE, UPDATEBY)
WITH child_map AS (
    SELECT cp.ID AS CHILD_PROJ, pp.ID AS PARENT_PROJ, cp.BUDGETREQUESTID AS CHILD_REQ
    FROM   OAGWBG_PROJECT cp
    JOIN   OAGWBG_PROJECT pp ON pp.ID = cp.TEMP
    WHERE  cp.TEMP IS NOT NULL
    UNION ALL
    SELECT cp.ID, pp.ID, cp.BUDGETREQUESTID
    FROM   OAGWBG_BUDGETREQUEST r
    JOIN   OAGWBG_PROJECT cp ON cp.BUDGETREQUESTID = r.ID       AND cp.TEMP IS NULL
    JOIN   OAGWBG_PROJECT pp ON pp.BUDGETREQUESTID = r.PARENTID AND pp.TEMP IS NULL
                            AND pp.PROJECTNAME = cp.PROJECTNAME
    WHERE  r.PARENTID IS NOT NULL
)
SELECT a.REFERENCETABLE,
       m.CHILD_PROJ,
       a.REFERENCEGROUP,
       a.FILENAME,
       a.EXTENSION,
       a.FILEDATA,
       a.FILESIZE,
       -777
FROM   child_map m
JOIN   OAGWBG_ATTACHFILE a ON a.REFERENCETABLE = 'Project' AND a.REFERENCEID = m.PARENT_PROJ
WHERE  NOT EXISTS (SELECT 1 FROM OAGWBG_ATTACHFILE x
                   WHERE x.REFERENCETABLE = 'Project'
                     AND x.REFERENCEID = m.CHILD_PROJ
                     AND NVL(x.REFERENCEGROUP, '~') = NVL(a.REFERENCEGROUP, '~'));


-- =====================================================================
-- STEP 3 — VERIFY ก่อน COMMIT  (รันใน session เดียวกับ STEP 2)
-- =====================================================================

-- 3.1 จำนวนแถวที่ insert ต้องตรงกับ ROWS_TO_INSERT จาก STEP 0.6
SELECT COUNT(*) AS INSERTED, ROUND(SUM(FILESIZE)/1024/1024, 1) AS MB
FROM   OAGWBG_ATTACHFILE WHERE UPDATEBY = -777;

-- 3.2 ROWGUID ต้องไม่ซ้ำ — ต้องได้ 0 แถว
SELECT ROWGUID, COUNT(*) FROM OAGWBG_ATTACHFILE GROUP BY ROWGUID HAVING COUNT(*) > 1;

-- 3.3 ROWGUID ต้องไม่เป็น NULL ในแถวใหม่ — ต้องได้ 0
SELECT COUNT(*) AS NULL_ROWGUID FROM OAGWBG_ATTACHFILE WHERE UPDATEBY = -777 AND ROWGUID IS NULL;

-- 3.4 เทียบไฟล์ของลูกกับแม่ — STILL_MISSING ควรเป็น 0 ทุกแถว
--     (ยกเว้น group ที่ตั้งใจข้ามตาม STEP 0.7)
WITH child_map AS (
    SELECT cp.ID AS CHILD_PROJ, pp.ID AS PARENT_PROJ
    FROM   OAGWBG_PROJECT cp
    JOIN   OAGWBG_PROJECT pp ON pp.ID = cp.TEMP
    WHERE  cp.TEMP IS NOT NULL
    UNION ALL
    SELECT cp.ID, pp.ID
    FROM   OAGWBG_BUDGETREQUEST r
    JOIN   OAGWBG_PROJECT cp ON cp.BUDGETREQUESTID = r.ID       AND cp.TEMP IS NULL
    JOIN   OAGWBG_PROJECT pp ON pp.BUDGETREQUESTID = r.PARENTID AND pp.TEMP IS NULL
                            AND pp.PROJECTNAME = cp.PROJECTNAME
    WHERE  r.PARENTID IS NOT NULL
)
SELECT m.PARENT_PROJ, m.CHILD_PROJ,
       (SELECT COUNT(*) FROM OAGWBG_ATTACHFILE
        WHERE REFERENCETABLE='Project' AND REFERENCEID = m.PARENT_PROJ) AS PARENT_FILES,
       (SELECT COUNT(*) FROM OAGWBG_ATTACHFILE
        WHERE REFERENCETABLE='Project' AND REFERENCEID = m.CHILD_PROJ)  AS CHILD_FILES,
       (SELECT COUNT(*) FROM OAGWBG_ATTACHFILE pa
        WHERE pa.REFERENCETABLE='Project' AND pa.REFERENCEID = m.PARENT_PROJ
          AND NOT EXISTS (SELECT 1 FROM OAGWBG_ATTACHFILE ca
                          WHERE ca.REFERENCETABLE='Project' AND ca.REFERENCEID = m.CHILD_PROJ
                            AND NVL(ca.REFERENCEGROUP,'~') = NVL(pa.REFERENCEGROUP,'~'))) AS STILL_MISSING
FROM   child_map m
ORDER  BY STILL_MISSING DESC, m.CHILD_PROJ;


-- =====================================================================
-- STEP 4 — ปิดงาน
-- =====================================================================
-- COMMIT;     -- ถ้า STEP 3 ผ่านหมด
-- ROLLBACK;   -- ถ้าไม่ผ่าน


-- =====================================================================
-- STEP 5 — ROLLBACK หลัง COMMIT ไปแล้ว
-- =====================================================================
-- SELECT COUNT(*) FROM OAGWBG_ATTACHFILE WHERE UPDATEBY = -777;
-- DELETE FROM OAGWBG_ATTACHFILE WHERE UPDATEBY = -777;
-- COMMIT;


-- =====================================================================
-- ทางเลือก: ถ้าอยากให้ช่องที่ลูกมีไฟล์อยู่แล้ว "เพิ่ม" ไฟล์ต้นฉบับเข้าไปด้วย
-- (ช่องนั้นจะมี 2 ไฟล์) ให้เติมเงื่อนไขนี้เข้าไปใน NOT EXISTS ของ STEP 2:
--     AND x.FILENAME = a.FILENAME
-- default ของ script นี้คือ "ไม่แตะช่องที่ลูกมีไฟล์อยู่แล้ว" (ปลอดภัยกว่า)
-- =====================================================================


-- =====================================================================
-- หมายเหตุ 1: script นี้ "ไม่" ไปแตะคอลัมน์ TEMP ของ OAGWBG_PROJECT
-- ถึงแม้การเซ็ต TEMP จะทำให้ mapping ในอนาคตง่ายขึ้น แต่ TEMP ถูกใช้เป็น
-- เงื่อนไขในฟีเจอร์อื่นด้วย (rollup สถานะโครงการลูก และรายงานที่ filter
-- Temp != null) การไปเซ็ตเพิ่มจะเปลี่ยนผลลัพธ์ของรายงานพวกนั้น
--
-- หมายเหตุ 2: ตารางลูกของ project ที่ DuplicateProjectChildren ยังไม่ copy
-- เหลือ OAGWBG_PROJECTASSETITEM ตัวเดียว (PREPROD ว่าง 0 แถว)
-- เช็ค PROD ก่อนว่ามีข้อมูลไหม ถ้ามีคือบั๊กอีกตัว คนละเรื่องกับไฟล์แนบ:
--     SELECT COUNT(*) N_ROWS, COUNT(DISTINCT PROJECTID) N_PROJ
--     FROM OAGWBG_PROJECTASSETITEM;
-- =====================================================================
