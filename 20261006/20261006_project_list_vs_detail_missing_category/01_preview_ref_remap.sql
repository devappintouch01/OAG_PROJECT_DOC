-- [01] PREVIEW — ดูก่อนว่าแถวไหนจะถูกแก้ REF_BUDGETGOVERNMENTID และจะชี้ไปแถวไหน (SELECT อย่างเดียว ไม่แก้ข้อมูล)
--
-- ปัญหา: คำขอแผนงานถูกสร้างเวอร์ชันใหม่ (สถานะ 20102 → DuplicateBudgetRequest → DuplicatePlanData)
--        แถวแผนงานถูก copy เป็น ID ใหม่ แต่ REF ของแถวโครงการยังชี้ ID เก่า
--        → dropdown "รายการ" หน้า BudgetRequestProjectDetail ไม่มีตัวที่ถูกเลือก
--        (ผลบน PROD 2026-10-06 ปี 2570: 41 โครงการในหน้า list)
--
-- แก้: ย้าย REF ไปแถวที่ copy ในคำขอใบล่าสุด จับคู่ด้วย RUNNING
--
-- ขอบเขตกว้างกว่า 41 แถวในหน้า list โดยตั้งใจ: รวมแถวโครงการต้นฉบับ / ชุดจัดสรร (TEMP) ที่ถือ REF เก่าตัวเดียวกัน
--   ถ้าแก้แค่แถวที่โชว์ ต้นฉบับยังถือ REF เก่า และตอนอนุมัติรอบหน้า DuplicateProjectsInRequest จะ copy REF เก่าไปอีก
--   ถ้าต้องการแก้แค่ 41 แถว ให้กรองด้วย PROJECTID ในขั้น 02
--
-- อ่านผล:
--   NEW_OK = 'Y'           → ขั้น 02 จะแก้แถวนี้
--   NEW_OK = 'N'           → ขั้น 02 ข้าม ดู BLOCK_REASON แล้วตัดสินใจเป็นรายตัว
--   CATEGORY_CHANGED = 'Y' → ใบใหม่เปลี่ยนรายการของแถวแผนงานไปแล้ว ถึงผ่านเงื่อนไขก็ควรดูด้วยตาอีกครั้ง
--
-- ใช้: แทน :BUDGETYEAR = 2570
-- ลำดับ: 01 → 02 → 03   (ย้อนกลับ: 99)

WITH
LEAF_BR AS (
  SELECT X.ID
  FROM OAGWBG_BUDGETREQUEST X
  WHERE NOT EXISTS (SELECT 1 FROM OAGWBG_BUDGETREQUEST G WHERE G.PARENTID = X.ID)
),

-- แถวโครงการ (ในคำขอใบล่าสุด) ที่ REF ชี้แถวแผนงานในคำขอใบเก่า
STALE AS (
  SELECT
    BG.ID                             AS BG_ID,
    BG.PROJECTID,
    PJ.PROJECTNAME,
    PJ.TEMP                           AS PROJECT_TEMP,
    NVL(PJ.BUDGETYEAR, BR.BUDGETYEAR) AS PROJECT_YEAR,
    BG.BUDGETREQUESTID                AS PJ_REQID,
    BG.REF_BUDGETGOVERNMENTID         AS OLD_REF_ID,
    BG.PRODUCTID,
    BG.ACTIVITYCODEID,
    BG.UPDATEON                       AS OLD_UPDATEON,
    O.BUDGETREQUESTID                 AS OLD_REQID,
    O.RUNNING,
    O.CATEGORYID                      AS OLD_CATEGORYID
  FROM OAGWBG_BUDGETGOVERNMENT BG
  JOIN OAGWBG_BUDGETREQUEST BR   ON BR.ID = BG.BUDGETREQUESTID
  JOIN LEAF_BR LP                ON LP.ID = BG.BUDGETREQUESTID
  JOIN OAGWBG_BUDGETGOVERNMENT O ON O.ID  = BG.REF_BUDGETGOVERNMENTID
  LEFT JOIN OAGWBG_PROJECT PJ    ON PJ.ID = BG.PROJECTID
  WHERE BR.BUDGETYEAR = :BUDGETYEAR
    AND BG.PROJECTID IS NOT NULL
    AND (BG.BUDGETGOVERNMENTTYPE IS NULL OR BG.BUDGETGOVERNMENTTYPE = '7')
    AND NOT EXISTS (SELECT 1 FROM LEAF_BR L WHERE L.ID = O.BUDGETREQUESTID)
),

-- คำขอใบล่าสุดของสายคำขอแผนงานเดิม (ไล่ลูกตาม PARENTID จนสุด)
REQ_LEAF AS (
  SELECT CONNECT_BY_ROOT ID AS OLD_REQID, ID AS LEAF_REQID
  FROM OAGWBG_BUDGETREQUEST
  WHERE CONNECT_BY_ISLEAF = 1
  START WITH ID IN (SELECT OLD_REQID FROM STALE)
  CONNECT BY PRIOR ID = PARENTID
),

-- โครงการต้นฉบับในคำขอใบล่าสุดที่ถือ REF อยู่ (ตรรกะเดียวกับ chosenRefGovIdsList ใน GetProjectCategoryType)
TAKEN AS (
  SELECT BG2.REF_BUDGETGOVERNMENTID AS REF_ID, P2.ID AS TAKEN_BY_PROJECTID
  FROM OAGWBG_PROJECT P2
  JOIN OAGWBG_BUDGETGOVERNMENT BG2 ON BG2.ID = P2.BUDGETGOVERNMENTID
  WHERE BG2.REF_BUDGETGOVERNMENTID IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM OAGWBG_PROJECT X       WHERE X.ID       = P2.TEMP)
    AND NOT EXISTS (SELECT 1 FROM OAGWBG_BUDGETREQUEST R WHERE R.PARENTID = P2.BUDGETREQUESTID)
),

-- จับคู่แถวเก่า → แถวใหม่ด้วย RUNNING (DuplicatePlanData copy RUNNING ตรง ๆ)
SUCC AS (
  SELECT
    S.*,
    RL.LEAF_REQID,
    N.ID             AS NEW_REF_ID,
    N.CATEGORYID     AS NEW_CATEGORYID,
    N.PRODUCTID      AS NEW_PRODUCTID,
    N.ACTIVITYCODEID AS NEW_ACTIVITYCODEID,
    COUNT(N.ID) OVER (PARTITION BY S.BG_ID) AS CANDIDATES
  FROM STALE S
  LEFT JOIN REQ_LEAF RL ON RL.OLD_REQID = S.OLD_REQID
  LEFT JOIN OAGWBG_BUDGETGOVERNMENT N
         ON N.BUDGETREQUESTID = RL.LEAF_REQID
        AND N.RUNNING         = S.RUNNING
        AND N.CATEGORYTYPEID  = '2'
),

-- แถวใหม่ต้องผ่านเงื่อนไขของ dropdown หน้า detail ครบ
CHECKED AS (
  SELECT
    X.*,
    CASE
      WHEN X.CANDIDATES = 0 THEN 'ไม่เจอแถวใหม่ที่ RUNNING ตรงกัน (ใบใหม่อาจลบแถวนี้ไปแล้ว)'
      WHEN X.CANDIDATES > 1 THEN 'เจอแถวใหม่มากกว่า 1 แถว'
      WHEN NOT EXISTS (SELECT 1 FROM OAGWBG_V_BUDGETGOVERNMENT V
                        WHERE V.ID = X.NEW_REF_ID AND V.CATEGORYTYPEID = '2')
        THEN 'แถวใหม่ไม่อยู่ใน OAGWBG_V_BUDGETGOVERNMENT หรือ CATEGORYTYPEID ไม่ใช่ 2'
      WHEN NOT EXISTS (SELECT 1 FROM OAGWBG_V_BUDGETGOVERNMENT V
                        WHERE V.ID = X.NEW_REF_ID AND V.BUDGETYEAR = X.PROJECT_YEAR)
        THEN 'ปีของแถวใหม่ไม่ตรงกับปีโครงการ'
      WHEN X.PRODUCTID IS NOT NULL AND NVL(X.NEW_PRODUCTID, -1) <> X.PRODUCTID
        THEN 'PRODUCTID ของแถวใหม่ไม่ตรงกับแถวโครงการ (ใบใหม่ถูกแก้)'
      WHEN X.PRODUCTID IS NOT NULL AND X.ACTIVITYCODEID IS NOT NULL
       AND NVL(X.NEW_ACTIVITYCODEID, -1) <> X.ACTIVITYCODEID
        THEN 'ACTIVITYCODEID ของแถวใหม่ไม่ตรงกับแถวโครงการ (ใบใหม่ถูกแก้)'
      WHEN EXISTS (SELECT 1 FROM TAKEN T WHERE T.REF_ID = X.NEW_REF_ID)
        THEN 'แถวใหม่มีโครงการอื่นถืออยู่แล้ว'
    END AS BLOCK_REASON
  FROM SUCC X
),

FINAL AS (
  SELECT
    C.*,
    CASE WHEN C.BLOCK_REASON IS NULL THEN 'Y' ELSE 'N' END AS NEW_OK,
    CASE WHEN NVL(C.NEW_CATEGORYID, -1) <> NVL(C.OLD_CATEGORYID, -1) THEN 'Y' ELSE 'N' END AS CATEGORY_CHANGED
  FROM CHECKED C
)

SELECT
  NEW_OK, BLOCK_REASON, CATEGORY_CHANGED,
  PROJECTID, PROJECTNAME, PROJECT_TEMP, PROJECT_YEAR,
  BG_ID, PJ_REQID,
  OLD_REF_ID, OLD_REQID, RUNNING, LEAF_REQID, NEW_REF_ID, CANDIDATES,
  OLD_CATEGORYID, NEW_CATEGORYID,
  PRODUCTID      AS PROJECT_PRODUCTID,      NEW_PRODUCTID,
  ACTIVITYCODEID AS PROJECT_ACTIVITYCODEID, NEW_ACTIVITYCODEID
FROM FINAL
ORDER BY NEW_OK, PROJECTID, BG_ID;
