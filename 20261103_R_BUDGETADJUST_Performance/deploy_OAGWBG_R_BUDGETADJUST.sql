-- DEPLOY: OAGWBG_R_BUDGETADJUST — ลดเวลา hard parse (ผลลัพธ์ต้องเหมือนเดิมทุกแถว)
--
-- เดิม: UNION ALL 10 branch, แต่ละ branch join V_EXT_* เอง และอ้าง V_BUDGETRECEIVE 6 ครั้ง
--       รวมอ้าง view อื่นราว 45 ครั้ง → Oracle hard parse ~50 วิ (execute จริง ~2 วิ)
-- ใหม่:
--   (ข้อ 1) lookup ชื่อ (ศูนย์ต้นทุน/แหล่งเงิน/แผนงาน/กิจกรรม/ผลผลิต/หมวด) ย้ายไป join ครั้งเดียวที่ชั้นนอก
--           branch ส่ง key มาใน L_* และส่งชื่อที่ได้มากับแถว (จาก R / G / BTV / BCV) มาใน F_*
--           ชั้นนอกเลือกตามลำดับเดิมของแต่ละ branch:
--             - ชื่อมิติงบ          = NVL(F_*, lookup)   branch ที่เดิมใช้ชื่อจากแถวอย่างเดียวส่ง L_* = NULL
--             - BUDGETTYPENAME   = NVL(CAT, F_*)      F_* มีค่าเฉพาะเบิกแทนกัน (BTV) ซึ่ง CATEGORYID เป็น NULL
--             - CATEGORYNAME     = NVL(CAT, F_*)      เหมือนเดิม: NVL(CAT.NAME, R/G.CATEGORYNAME) และ BCV ของเบิกแทนกัน
--   (ข้อ 2) รวม branch ที่ source เดียวกัน 10 → 5
--             A  1) ฝั่งโอนออก                    (เหมือนเดิม)
--             B  1) ฝั่งรับโอน                     (เหมือนเดิม)
--             C  2/3/5 ฝั่งรับโอน                  BUDGETRECEIVE type T/R/T
--             D  2/3/5 ฝั่งโอนออก                  BUDGETRECEIVEREFUND — ประเภท 3 ยังเป็น inner join G
--             E  4) เบิกแทนกัน O + I
--   อ้าง view อื่นเหลือ 13 ครั้ง (V_BUDGETRECEIVE 3, V_EXT_* 10)
--   ส่วน RL / AV ไม่ได้แตะ
--   TRANSFERTYPE ที่มาจาก DECODE ครอบ CAST AS CHAR(1) ให้ type ของคอลัมน์ยังเป็น CHAR(1) เหมือนเดิม
--
-- ตรวจผลด้วย compare_OAGWBG_R_BUDGETADJUST.sql ก่อน deploy, ย้อนด้วย rollback_OAGWBG_R_BUDGETADJUST.sql

CREATE OR REPLACE FORCE EDITIONABLE VIEW "OAGWBG"."OAGWBG_R_BUDGETADJUST" ("RECEIVE_ID", "BUDGETYEAR", "DEPARTMENTNAME", "COSTCENTERNAME", "ACTIVITYID", "PRODUCTID", "TOTALTRANSFERAMOUNT", "TOTALRECEIVEAMOUNT", "TOTALBALANCEAMOUNT", "ROLETYPE", "BUDGETSOURCEID", "TRANSFER_ID", "TRANSFERNO", "TRANSFERTYPE", "TRANSFER_AMOUNT", "BUDGETSOURCENAME", "BUDGETPLANNAME", "ACTIVITYNAME", "PRODUCTNAME", "ROUNDNO", "ITEMDETAIL", "BUDGETTYPENAME", "CATEGORYNAME", "BUDGETCODE", "CATEGORYID", "ACCOUNTNO", "ACCOUNTNAME", "SUBACCOUNTNO") AS
  SELECT
    U.RECEIVE_ID, U.BUDGETYEAR,
    NVL(U.F_DEPARTMENTNAME,   CC.DEPARTMENTNAME)    AS DEPARTMENTNAME,
    NVL(U.F_COSTCENTERNAME,   CC.NAME)              AS COSTCENTERNAME,
    U.ACTIVITYID, U.PRODUCTID,
    U.TOTALTRANSFERAMOUNT, U.TOTALRECEIVEAMOUNT, U.TOTALBALANCEAMOUNT, U.ROLETYPE,
    U.BUDGETSOURCEID, U.TRANSFER_ID, U.TRANSFERNO, U.TRANSFERTYPE, U.TRANSFER_AMOUNT,
    NVL(U.F_BUDGETSOURCENAME, SRCV.NAME)            AS BUDGETSOURCENAME,
    NVL(U.F_BUDGETPLANNAME,   PLANV.NAME)           AS BUDGETPLANNAME,
    NVL(U.F_ACTIVITYNAME,     ACTV.ACTIVITY_NAME)   AS ACTIVITYNAME,
    NVL(U.F_PRODUCTNAME,      PRODV.NAME)           AS PRODUCTNAME,
    U.ROUNDNO, U.ITEMDETAIL,
    NVL(CAT.BUDGET_TYPE_NAME, U.F_BUDGETTYPENAME)   AS BUDGETTYPENAME,
    NVL(CAT.NAME,             U.F_CATEGORYNAME)     AS CATEGORYNAME,
    U.BUDGETCODE,
    U.CATEGORYID,
    NVL(U.ACCOUNTNO, RL.ACCOUNTNO)           AS ACCOUNTNO,
    AV.NAME                                  AS ACCOUNTNAME,
    NVL(U.SUBACCOUNTNO, RL.SUBACCOUNTNO)     AS SUBACCOUNTNO
FROM (
-- ============================================================ A) 1) โอนเปลี่ยนแปลงงบประมาณ — ฝั่งโอนออก
SELECT
    A.ID                                     AS RECEIVE_ID,
    TO_CHAR(NVL(A.BUDGETYEAR, T.BUDGETYEAR)) AS BUDGETYEAR,
    A.ACTIVITYID                             AS ACTIVITYID,
    A.PRODUCTID                              AS PRODUCTID,
    A.TOTALTRANSFERAMOUNT                    AS TOTALTRANSFERAMOUNT,
    CAST(NULL AS NUMBER)                     AS TOTALRECEIVEAMOUNT,
    A.REMAININGAMOUNT                        AS TOTALBALANCEAMOUNT,
    'SENDER'                                 AS ROLETYPE,
    A.BUDGETSOURCEID                         AS BUDGETSOURCEID,
    T.ID                                     AS TRANSFER_ID,
    T.TRANSFERNO                             AS TRANSFERNO,
    '1'                                      AS TRANSFERTYPE,
    T.TOTALTRANSFERAMOUNT                    AS TRANSFER_AMOUNT,
    TO_CHAR(T.ROUNDNO)                       AS ROUNDNO,
    T.ITEMDETAIL                             AS ITEMDETAIL,
    A.BUDGETCODE                             AS BUDGETCODE,
    A.CATEGORYID                             AS CATEGORYID,
    CAST(NULL AS VARCHAR2(150))              AS ACCOUNTNO,
    CAST(NULL AS VARCHAR2(150))              AS SUBACCOUNTNO,
    -- ชื่อที่ได้มากับแถว (branch นี้ไม่มี — ใช้ lookup ทั้งหมด)
    NULL                                     AS F_DEPARTMENTNAME,
    NULL                                     AS F_COSTCENTERNAME,
    NULL                                     AS F_BUDGETSOURCENAME,
    NULL                                     AS F_BUDGETPLANNAME,
    NULL                                     AS F_ACTIVITYNAME,
    NULL                                     AS F_PRODUCTNAME,
    NULL                                     AS F_BUDGETTYPENAME,
    NULL                                     AS F_CATEGORYNAME,
    -- key สำหรับ lookup ชั้นนอก (กิจกรรม/ผลผลิตใช้ ACTIVITYID/PRODUCTID คู่กับ L_BUDGETPLANID)
    A.COSTCENTERID                           AS L_COSTCENTERID,
    A.BUDGETSOURCEID                         AS L_BUDGETSOURCEID,
    A.BUDGETPLANID                           AS L_BUDGETPLANID
FROM OAGWBG_BUDGETTRANSFER T
JOIN OAGWBG_BUDGETADJUST A ON A.BUDGETTRANSFERID = T.ID
WHERE T.TRANSFERTYPE = '1'

UNION ALL
-- ============================================================ B) 1) โอนเปลี่ยนแปลงงบประมาณ — ฝั่งรับโอน
-- ชื่อมิติงบใช้จาก R อย่างเดียว (L_* = NULL), หมวดยังใช้ CAT ก่อนแล้วค่อย R.CATEGORYNAME
SELECT
    R.ID, TO_CHAR(R.BUDGETYEAR),
    R.ACTIVITYID, R.PRODUCTID,
    CAST(NULL AS NUMBER), R.TOTALRECEIVEAMOUNT, R.TOTALBALANCEAMOUNT,
    'RECEIVER', R.BUDGETSOURCEID,
    T.ID, T.TRANSFERNO, '1', T.TOTALTRANSFERAMOUNT,
    TO_CHAR(T.ROUNDNO), T.ITEMDETAIL,
    RF.BUDGETCODEID, R.CATEGORYID, NULL, NULL,
    R.DEPARTMENTNAME, R.COSTCENTERNAME, R.BUDGETSOURCEIDNAME,
    R.PLANNAME, R.ACTIVITYNAME, R.PRODUCTNAME,
    NULL, R.CATEGORYNAME,
    NULL, NULL, NULL
FROM OAGWBG_BUDGETTRANSFER T
JOIN OAGWBG_BUDGETADJUST    A ON A.BUDGETTRANSFERID = T.ID
JOIN OAGWBG_V_BUDGETRECEIVE R ON R.BUDGETADJUSTID   = A.ID
LEFT JOIN OAGWBG_BUDGETRECEIVEREFUND RF ON R.ID = RF.RECEIVEID
WHERE T.TRANSFERTYPE = '1'

UNION ALL
-- ============================================================ C) 2/3/5 — ฝั่งรับโอน
-- TRANSFERTYPE ในตาราง → ประเภทในรายงาน / BUDGETRECEIVETYPE:
--   '2' โอนเงินกลับ → '2' / 'T'    '3' โอนปรับเงินเหลือจ่าย → '3' / 'R'    '4' โอนเงินกลับหลายปี → '5' / 'T'
SELECT
    R.ID, TO_CHAR(R.BUDGETYEAR),
    R.ACTIVITYID, R.PRODUCTID,
    CAST(NULL AS NUMBER), R.TOTALRECEIVEAMOUNT, R.TOTALBALANCEAMOUNT,
    'RECEIVER', R.BUDGETSOURCEID,
    T.ID, T.TRANSFERNO, CAST(DECODE(T.TRANSFERTYPE, '2', '2', '3', '3', '4', '5') AS CHAR(1)), T.TOTALTRANSFERAMOUNT,
    TO_CHAR(T.ROUNDNO), T.ITEMDETAIL,
    R.BUDGETCODEID, R.CATEGORYID, NULL, NULL,
    R.DEPARTMENTNAME, R.COSTCENTERNAME, R.BUDGETSOURCEIDNAME,
    R.PLANNAME, R.ACTIVITYNAME, R.PRODUCTNAME,
    NULL, R.CATEGORYNAME,
    NULL, NULL, NULL
FROM OAGWBG_BUDGETTRANSFER T
JOIN OAGWBG_V_BUDGETRECEIVE R
       ON R.BUDGETTRANSFERID = T.ID
      AND R.BUDGETRECEIVETYPE = DECODE(T.TRANSFERTYPE, '3', 'R', 'T')
WHERE T.TRANSFERTYPE IN ('2', '3', '4')

UNION ALL
-- ============================================================ D) 2/3/5 — ฝั่งโอนออก (OAGWBG_BUDGETRECEIVEREFUND)
-- '2' โอนเงินกลับ:        GIVERID resolve ไม่ครบ (มีแถวค้าง) — ใช้ฟิลด์ของ G ก่อน แล้ว NVL ไปหาฟิลด์ giver บนตัว link
-- '3' โอนปรับเงินเหลือจ่าย: 1 แถว = 1 กองเงินต้นทางที่ถูกตัด ต้องมี G เสมอ (เดิม inner join)
--                          มิติงบ / รหัสงบ / หมวด อ่านจาก G ทั้งหมด จึงไม่ lookup จาก link (L_* = NULL)
-- '4' โอนเงินกลับหลายปี:   ไม่ join G เลย (เหมือนเดิม) ทุกมิติอ่านจากฟิลด์บนตัว link
--                          สูตรของ '2' จึงให้ค่าเดียวกับสูตรเดิมของ '4' เมื่อ G เป็น NULL
SELECT
    RF.ID,
    CASE WHEN T.TRANSFERTYPE = '3' THEN TO_CHAR(G.BUDGETYEAR)
         ELSE NVL(TO_CHAR(G.BUDGETYEAR), TO_CHAR(RF.BUDGETYEAR)) END,
    CASE WHEN T.TRANSFERTYPE = '3' THEN G.ACTIVITYID ELSE RF.ACTIVITYID END,
    CASE WHEN T.TRANSFERTYPE = '3' THEN G.PRODUCTID  ELSE RF.PRODUCTID  END,
    RF.TOTALREFUNDAMOUNT, CAST(NULL AS NUMBER), G.TOTALBALANCEAMOUNT,
    'SENDER',
    CASE WHEN T.TRANSFERTYPE = '3' THEN G.BUDGETSOURCEID ELSE RF.BUDGETSOURCEID END,
    T.ID, T.TRANSFERNO, CAST(DECODE(T.TRANSFERTYPE, '2', '2', '3', '3', '4', '5') AS CHAR(1)), T.TOTALTRANSFERAMOUNT,
    TO_CHAR(T.ROUNDNO), T.ITEMDETAIL,
    CASE WHEN T.TRANSFERTYPE = '3' THEN G.BUDGETCODEID
         ELSE NVL(RF.BUDGETCODEID, G.BUDGETCODEID) END,
    CASE WHEN T.TRANSFERTYPE = '3' THEN G.CATEGORYID ELSE RF.CATEGORYID END,
    NULL, NULL,
    G.DEPARTMENTNAME, G.COSTCENTERNAME, G.BUDGETSOURCEIDNAME,
    G.PLANNAME, G.ACTIVITYNAME, G.PRODUCTNAME,
    NULL, G.CATEGORYNAME,
    CASE WHEN T.TRANSFERTYPE <> '3' THEN RF.COSTCENTERIDGIVER END,
    CASE WHEN T.TRANSFERTYPE <> '3' THEN RF.BUDGETSOURCEID END,
    CASE WHEN T.TRANSFERTYPE <> '3' THEN RF.BUDGETPLANID END
FROM OAGWBG_BUDGETTRANSFER T
JOIN OAGWBG_BUDGETRECEIVEREFUND RF ON RF.TRANSFERID = T.ID
LEFT JOIN OAGWBG_V_BUDGETRECEIVE G
       ON G.ID = RF.GIVERID AND T.TRANSFERTYPE IN ('2', '3')
WHERE T.TRANSFERTYPE IN ('2', '3', '4')
  AND (T.TRANSFERTYPE <> '3' OR G.ID IS NOT NULL)

UNION ALL
-- ============================================================ E) 4) เบิกแทนกัน — O = ฝั่งโอนออก, I = ฝั่งรับโอน
-- บัญชีหลัก/รายจ่ายย่อยถูกเลือกเก็บไว้ใน ACCOUNT_SEGMENT ตรง ๆ ไม่ต้องหาจาก rule
-- ประเภทงบ / ชื่อรหัสงบ มาจาก BTV / BCV (มีแค่ branch นี้) จึง join ไว้ที่นี่แล้วส่งผ่าน F_*
SELECT
    OAS.ID, BR.BUDGETYEAR,
    OAS.ACTIVITYID, OAS.PRODUCTID,
    CASE WHEN BR.TRANSFERTYPE = 'O' THEN OAS.TOTALRECEIVEAMOUNT END,
    CASE WHEN BR.TRANSFERTYPE = 'I' THEN OAS.TOTALRECEIVEAMOUNT END,
    BR.TOTALREQUESTAMOUNT,
    DECODE(BR.TRANSFERTYPE, 'O', 'SENDER', 'RECEIVER'), OAS.BUDGETSOURCEID,
    CAST(NULL AS NUMBER), TO_CHAR(BR.RUNNING), '4', BR.TOTALREQUESTAMOUNT,
    TO_CHAR(BR.RUNNING), OAS.DESCRIPTION,
    OAS.BUDGETCODENAME, CAST(NULL AS NUMBER), OAS.ACCOUNT, OAS.SUBACCOUNT,
    NULL, NULL, NULL,
    NULL, NULL, NULL,
    BTV.NAME, BCV.NAME,
    NVL(OAS.COSTCENTERID, BR.COSTCENTERID), OAS.BUDGETSOURCEID, OAS.BUDGETPLANID
FROM OAGWBG_BUDGETREQUISITION BR
LEFT JOIN OAGWBG_ACCOUNT_SEGMENT OAS
       ON OAS.REFERENCEID = BR.ID AND OAS.REFERENCETABLE = 'BudgetRequisition'
LEFT JOIN OAGWBG_V_EXT_OAGGL_BUDGET_TYPE_V     BTV   ON BTV.ID   = OAS.BUDGETTYPEID
LEFT JOIN OAGWBG_V_EXT_OAGGL_BUDGET_CODE_V     BCV   ON BCV.ID   = OAS.BUDGETCODENAME
WHERE BR.TRANSFERTYPE IN ('O', 'I')
) U
-- ============================================================ lookup ชื่อ — join ครั้งเดียวสำหรับทุก branch
LEFT JOIN OAGWBG_V_EXT_OAGGL_COST_CENTER_V     CC    ON CC.ID    = U.L_COSTCENTERID
LEFT JOIN OAGWBG_V_EXT_BUDGET_SOURCE_V         SRCV  ON SRCV.ID  = U.L_BUDGETSOURCEID
LEFT JOIN OAGWBG_V_EXT_OAGGL_BUDGET_PLAN_V     PLANV ON PLANV.ID = U.L_BUDGETPLANID
LEFT JOIN OAGWBG_V_EXT_OAGGL_BUDGET_ACTIVITY_V ACTV
       ON ACTV.ACTIVITY_ID = U.ACTIVITYID AND ACTV.PLAN_ID = U.L_BUDGETPLANID
LEFT JOIN OAGWBG_V_EXT_OAGGL_BUDGET_PRODUCT_V  PRODV
       ON PRODV.ID = U.PRODUCTID AND PRODV.BUDGETPLANCODE_ID = U.L_BUDGETPLANID
LEFT JOIN OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V CAT   ON CAT.ID   = U.CATEGORYID
-- ============================================================ บัญชีหลัก / รายจ่ายย่อย — join ด้วย CATEGORYID
LEFT JOIN (
    SELECT CATEGORYID,
           MIN(ACCOUNTNO)    KEEP (DENSE_RANK FIRST ORDER BY ACCOUNTNO, SUBACCOUNTNO) AS ACCOUNTNO,
           MIN(SUBACCOUNTNO) KEEP (DENSE_RANK FIRST ORDER BY ACCOUNTNO, SUBACCOUNTNO) AS SUBACCOUNTNO
    FROM   OAGWBG_V_EXT_OAGPO_EXPENSE_ACCOUNT_RULE_V
    GROUP  BY CATEGORYID
) RL ON RL.CATEGORYID = U.CATEGORYID
LEFT JOIN OAGWBG_V_EXT_OAGGL_ACCOUNT_V AV ON AV.ID = NVL(U.ACCOUNTNO, RL.ACCOUNTNO);
