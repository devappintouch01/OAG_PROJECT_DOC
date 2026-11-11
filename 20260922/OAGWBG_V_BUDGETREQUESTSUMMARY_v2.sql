--------------------------------------------------------------------------------
-- OAGWBG_V_BUDGETREQUESTSUMMARY  v2  (2026-09-22)
--
-- แก้ต่อจากเวอร์ชันที่ deploy ไปแล้ว (20260921_fix_keptcentral_orphan)
--
-- ปัญหาของ v1 : ทำ COALESCE(own, parent) ที่ "ระดับแถว"
--               แล้ว C# เอาไป g.Sum() ที่ "ระดับกลุ่ม" → ได้ own + parent
--               ทำให้ 5 กลุ่มที่มีก้อนของตัวเองอยู่แล้วถูกเติมก้อนที่สองเข้าไป
--
-- กฎธุรกิจ (user ยืนยัน 2026-09-22) :
--   "คำของบประมาณ"        = รวมทุกศูนย์ต้นทุน          → Sum ได้
--   "คำของบประมาณเพิ่มเติม" = เงินก้อนเดียวระดับกลุ่ม     → ห้าม Sum
--   ตัวอย่าง : ศูนย์ A 4,100 + ศูนย์ B 4,100 = 8,200
--              ส่วนกลางเติม 1,800 (ก้อนเดียว) → รวม 10,000
--
-- วิธีแก้ใน v2 : คืนก้อนเงิน "เฉพาะแถวเดียวต่อกลุ่ม" แถวอื่นเป็น NULL
--                → g.Sum() ฝั่ง C# จะได้ค่าถูกเอง
--                → ⭐ ไม่ต้องแก้ C# / DAL / DTO / .cshtml เลย
--
-- กติกาการเลือกก้อน (เรียงตามลำดับ) :
--   1. แถวไหนมีก้อนของตัวเอง (BG4) → ใช้ก้อนนั้น แถวอื่นในกลุ่มเป็น NULL
--   2. ถ้าทั้งกลุ่มไม่มีก้อนของตัวเองเลย → ดึงก้อนที่ค้างอยู่กับคำขอแม่ (BG4P)
--      และให้โผล่แค่ "แถวเดียว" (แถวแรกที่มี BG4P เรียงตาม BG.ID)
--
-- PARTITION BY ต้องตรงกับ grouping key ของ GetGroupBudgetSummaryPlan
-- (BudgetService.cs:8927) ครบทั้ง 9 ช่อง ห้ามขาด
--------------------------------------------------------------------------------

CREATE OR REPLACE FORCE EDITIONABLE VIEW "OAGWBG"."OAGWBG_V_BUDGETREQUESTSUMMARY"
    ("ID", "CREATEON", "PROJECTID", "CATEGORY_ID", "CATEGORY_NAME", "DUMMY_FLAG",
     "BUDGETYEAR", "TOTALREQUESTAMOUNT", "TOTALKEPTCENTRAL", "TOTALRECEIVEAMOUNT",
     "BUDGETPLANID", "EXPENSETYPEID", "BUDGETEXPENSETYPEID", "BUDGETFORMTYPEID",
     "BUDGETDETAIL", "PRODUCTID", "ACTIVITYCODEID", "PRODUCTNAME", "ACTIVITYNAME",
     "BUDGETFORMTYPENAME", "DESCRIPTION", "REF_GOVERNMENTID", "CODE") AS
SELECT
    ID,
    CREATEON,
    PROJECTID,
    CATEGORY_ID,
    CATEGORY_NAME,
    DUMMY_FLAG,
    BUDGETYEAR,
    TOTALREQUESTAMOUNT,
    ------------------------------------------------------------------ [2]
    KEPT_FINAL                                        AS TOTALKEPTCENTRAL,
    NVL(BR_TOTALREQUESTAMOUNT, 0) + NVL(KEPT_FINAL,0) AS TOTALRECEIVEAMOUNT,
    ------------------------------------------------------------------
    BUDGETPLANID,
    EXPENSETYPEID,
    BUDGETEXPENSETYPEID,
    BUDGETFORMTYPEID,
    BUDGETDETAIL,
    PRODUCTID,
    ACTIVITYCODEID,
    PRODUCTNAME,
    ACTIVITYNAME,
    BUDGETFORMTYPENAME,
    DESC_FINAL                                        AS DESCRIPTION,
    REF_GOVERNMENTID,
    CODE
FROM (
    SELECT
        BG4.ID,
        BG.CREATEON,
        PJ.ID AS PROJECTID,
        CASE
            WHEN NVL(BG.DUMMY_CATEGORY, 0) <> 0 THEN BG.DUMMY_CATEGORY
            ELSE BG.CATEGORYID
        END AS CATEGORY_ID,
        CASE
            WHEN BR.BUDGETFORMTYPEID = '1' THEN CC.NAME
            ELSE PJ.PROJECTNAME
        END AS CATEGORY_NAME,
        CC.DUMMY_FLAG,
        BR.BUDGETYEAR,
        CASE
            WHEN BG.BUDGETFORMTYPEID = 1 THEN BG.TOTALREQUESTAMOUNT
            WHEN BG.BUDGETFORMTYPEID = 2 THEN OPT.ALLOCATEDBUDGET
            ELSE BG.TOTALREQUESTAMOUNT
        END AS TOTALREQUESTAMOUNT,
        BR.TOTALREQUESTAMOUNT AS BR_TOTALREQUESTAMOUNT,
        BG.BUDGETPLANID,
        TO_NUMBER(CC.EXPENSE_TYPE_ID) AS EXPENSETYPEID,
        TO_NUMBER(CC.BUDGET_TYPE_ID)  AS BUDGETEXPENSETYPEID,
        BR.BUDGETFORMTYPEID,
        BG.BUDGETDETAIL,
        BG.PRODUCTID,
        BG.ACTIVITYCODEID,
        PV.NAME AS PRODUCTNAME,
        AC.ACTIVITY_NAME AS ACTIVITYNAME,
        CASE
            WHEN BR.BUDGETFORMTYPEID IN ('1','3') THEN 'แผนงาน'
            WHEN BR.BUDGETFORMTYPEID IN ('2','4') THEN 'โครงการ'
            ELSE 'โครงการ'
        END AS BUDGETFORMTYPENAME,
        BG.ID AS REF_GOVERNMENTID,
        CC.CODE,
        -------------------------------------------------------------- [1]
        -- ก้อนเงินของกลุ่ม : คืนค่าเฉพาะแถวเดียวต่อกลุ่ม แถวอื่นเป็น NULL
        CASE
            WHEN BG4.KEPTCENTRAL IS NOT NULL THEN BG4.KEPTCENTRAL
            WHEN COUNT(BG4.KEPTCENTRAL) OVER (
                     PARTITION BY BR.BUDGETYEAR, BR.BUDGETFORMTYPEID,
                                  CASE WHEN NVL(BG.DUMMY_CATEGORY,0) <> 0
                                       THEN BG.DUMMY_CATEGORY ELSE BG.CATEGORYID END,
                                  BG.PRODUCTID, BG.ACTIVITYCODEID, PJ.ID, BG.BUDGETPLANID,
                                  TO_NUMBER(CC.EXPENSE_TYPE_ID), TO_NUMBER(CC.BUDGET_TYPE_ID)
                 ) = 0
             AND ROW_NUMBER() OVER (
                     PARTITION BY BR.BUDGETYEAR, BR.BUDGETFORMTYPEID,
                                  CASE WHEN NVL(BG.DUMMY_CATEGORY,0) <> 0
                                       THEN BG.DUMMY_CATEGORY ELSE BG.CATEGORYID END,
                                  BG.PRODUCTID, BG.ACTIVITYCODEID, PJ.ID, BG.BUDGETPLANID,
                                  TO_NUMBER(CC.EXPENSE_TYPE_ID), TO_NUMBER(CC.BUDGET_TYPE_ID)
                     ORDER BY NVL2(BG4P.KEPTCENTRAL, 0, 1), BG.ID
                 ) = 1
            THEN BG4P.KEPTCENTRAL
        END AS KEPT_FINAL,
        CASE
            WHEN BG4.ID IS NOT NULL THEN BG4.BUDGETDETAIL
            WHEN COUNT(BG4.KEPTCENTRAL) OVER (
                     PARTITION BY BR.BUDGETYEAR, BR.BUDGETFORMTYPEID,
                                  CASE WHEN NVL(BG.DUMMY_CATEGORY,0) <> 0
                                       THEN BG.DUMMY_CATEGORY ELSE BG.CATEGORYID END,
                                  BG.PRODUCTID, BG.ACTIVITYCODEID, PJ.ID, BG.BUDGETPLANID,
                                  TO_NUMBER(CC.EXPENSE_TYPE_ID), TO_NUMBER(CC.BUDGET_TYPE_ID)
                 ) = 0
            THEN BG4P.BUDGETDETAIL
        END AS DESC_FINAL
        --------------------------------------------------------------
    FROM OAGWBG_BUDGETREQUEST BR
    JOIN OAGWBG_BUDGETGOVERNMENT BG
        ON BG.BUDGETREQUESTID = BR.ID
       AND BG.BUDGETFORMTYPEID IN (1,2)
       AND BG.ID IS NOT NULL
       AND ( BG.BUDGETGOVERNMENTTYPE IS NULL OR BG.BUDGETGOVERNMENTTYPE = '7' )
       AND BG.BUDGETSTATUS NOT IN ('A','X')
    LEFT JOIN (
        SELECT
            REF_BUDGETGOVERNMENTID,
            SUM(KEPTCENTRAL) AS KEPTCENTRAL,
            MAX(BUDGETDETAIL) AS BUDGETDETAIL,
            MAX(ID) KEEP (DENSE_RANK FIRST ORDER BY ID) AS ID
        FROM OAGWBG_BUDGETGOVERNMENT
        WHERE BUDGETGOVERNMENTTYPE = '4'
        GROUP BY REF_BUDGETGOVERNMENTID
    ) BG4 ON BG.ID = BG4.REF_BUDGETGOVERNMENTID
    LEFT JOIN (
        SELECT
            PBG.BUDGETREQUESTID   AS PARENT_REQID,
            PBG.RUNNING           AS RUNNING,
            SUM(B4P.KEPTCENTRAL)  AS KEPTCENTRAL,
            MAX(B4P.BUDGETDETAIL) AS BUDGETDETAIL
        FROM OAGWBG_BUDGETGOVERNMENT PBG
        JOIN OAGWBG_BUDGETGOVERNMENT B4P
             ON B4P.REF_BUDGETGOVERNMENTID = PBG.ID
            AND B4P.BUDGETGOVERNMENTTYPE   = '4'
        WHERE PBG.RUNNING IS NOT NULL
        GROUP BY PBG.BUDGETREQUESTID, PBG.RUNNING
        HAVING COUNT(*) = 1
    ) BG4P
        ON  BG4P.PARENT_REQID = BR.PARENTID
        AND BG4P.RUNNING      = BG.RUNNING
    LEFT JOIN OAGWBG_PROJECT PJ
        ON PJ.ID = BG.PROJECTID
    LEFT JOIN OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V CC
        ON CC.ID = CASE
            WHEN NVL(BG.DUMMY_CATEGORY, 0) <> 0 THEN BG.DUMMY_CATEGORY
            ELSE BG.CATEGORYID
        END
    LEFT JOIN OAGWBG_PROJECTTARGETS OPT ON OPT.PROJECTID = BG.PROJECTID
    LEFT JOIN OAGWBG_V_EXT_OAGGL_BUDGET_ACTIVITY_V AC
        ON AC.ACTIVITY_ID = CASE WHEN BG.ACTIVITYCODEID = 0 THEN '00000' ELSE TO_CHAR(BG.ACTIVITYCODEID) END
       AND AC.BUDGETPLANID = BG.BUDGETPLANID
    LEFT JOIN OAGWBG_V_EXT_OAGGL_BUDGET_PRODUCT_V PV
        ON PV.ID = CASE WHEN BG.PRODUCTID = 0 THEN '00000' ELSE TO_CHAR(BG.PRODUCTID) END
       AND BG.BUDGETPLANID = PV.BUDGETPLAN_ID
    WHERE BR.BUDGETTYPEID = 1
    AND NOT EXISTS (
        SELECT 1
        FROM OAGWBG_BUDGETREQUEST BR2
        WHERE BR2.PARENTID IS NOT NULL
          AND BR2.PARENTID = BG.BUDGETREQUESTID
    )
    AND ( BG.PROJECTID IS NULL OR NOT EXISTS (
        SELECT 1
        FROM OAGWBG_PROJECT
        WHERE TEMP IS NOT NULL
          AND TEMP = BG.PROJECTID
    ))
);
