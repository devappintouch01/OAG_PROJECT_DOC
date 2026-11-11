--------------------------------------------------------------------------------
-- PREFLIGHT ของ v2 — รันบน PROD ก่อนแก้ DDL  (READ-ONLY ล้วน)
--
-- เทียบ view ปัจจุบันบน PROD (v1 = COALESCE ระดับแถว) กับ v2 (ตัดสินระดับกลุ่ม)
--
-- GO / NO-GO :
--   ROWS_    ต้องเท่ากันทั้งสองฝั่ง        → ถ้าไม่เท่า = fan-out หยุด
--   SUM_KEPT ของ v2 ต่างจาก v1 เท่ากับ "ส่วนเกินที่ fallback เติมให้กลุ่มที่มีก้อนแล้ว"
--            ⚠️ ทิศทางขึ้นกับว่าส่วนเกินนั้นเป็นบวกหรือลบ
--            บน PROD ส่วนเกินเป็น −2,190,186 (ติดลบ) → v2 จึง "เพิ่มขึ้น" 2,190,186
--   HAS_KEPT ของ v2 น้อยลงเป็นเรื่องปกติ (คืนก้อนเงินแค่แถวเดียวต่อกลุ่ม)
--
-- ผลจริงจาก PROD 2026-09-22 :
--   2569  ROWS 9,693  HAS_KEPT 617→617  SUM 2,597,568,340.67 → เท่าเดิม  ✓ ไม่กระทบ
--   2570  ROWS 13,025 HAS_KEPT 552→528  SUM 5,608,440,579.16 → 5,610,630,765.16
--   2571  ROWS 11,979 HAS_KEPT   0→  0  SUM 0                → เท่าเดิม  ✓
--
--   ตรวจยอดย้อนกลับ (ปี 2570) :
--     own อย่างเดียว        5,493,866,621.16
--     + กู้คืน 15 กลุ่มว่าง   + 116,764,144.00
--     − ส่วนเกิน 9 กลุ่ม      −   2,190,186.00  → v1 = 5,608,440,579.16 ✓
--     v2 (ไม่มีส่วนเกิน)                         → v2 = 5,610,630,765.16 ✓
--
-- ผลจาก PREPROD (ที่นั่น fallback ให้ยอด 0 จึงเท่ากันทุกคอลัมน์) :
--   2569  ROWS 9693  SUM_KEPT 2,597,568,340.67  เท่ากันทั้ง v0 และ v2 ✓
--   2570  ROWS 12930 SUM_KEPT 0                 เท่ากัน ✓
--   2571  ROWS 2     SUM_KEPT 3,000,000         เท่ากัน ✓
--------------------------------------------------------------------------------

SELECT 'v2' SRC, BUDGETYEAR, COUNT(*) ROWS_, COUNT(TOTALKEPTCENTRAL) HAS_KEPT, SUM(NVL(TOTALKEPTCENTRAL,0)) SUM_KEPT, SUM(NVL(TOTALRECEIVEAMOUNT,0)) SUM_RECV FROM (
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
)

) GROUP BY BUDGETYEAR
UNION ALL
SELECT 'v1 (PROD ปัจจุบัน)', BUDGETYEAR, COUNT(*), COUNT(TOTALKEPTCENTRAL), SUM(NVL(TOTALKEPTCENTRAL,0)), SUM(NVL(TOTALRECEIVEAMOUNT,0))
FROM OAGWBG_V_BUDGETREQUESTSUMMARY GROUP BY BUDGETYEAR ORDER BY 2,1
;
