-- =============================================================================
-- VIEW : OAGWBG.OAGWBG_V_BUDGET_RESERVE_TRANSFER_DETAIL_INTERFACE
-- ใช้ : สร้าง journal (DR/CR) ส่งเข้า EBS ของ "โอนปรับเงินเหลือจ่าย" (TRANSFERTYPE = '3')
--        หน้าเว็บไม่ได้ส่ง interface เอง (SaveBudgetReserveTransfer return ก่อน) — journal มาจาก view นี้
-- ที่มา : ดึงจาก PREPROD (172.16.11.19:1541 / ebs_PRE / OAGWBG) เมื่อ 2026-09-08
--        ตรงกับ definition ที่ deploy อยู่จริง (LAST_DDL_TIME = 2026-08-20 12:03) ทุกตัวอักษร
-- วิธีใช้ : รันทั้งไฟล์ด้วย user OAGWBG (SQL Developer / SQL*Plus)
-- หมายเหตุ: เป็น CREATE OR REPLACE — รันซ้ำได้ ไม่ต้อง DROP ก่อน
--           ไฟล์นี้ใช้เป็น rollback script ของการแก้ view นี้ได้ด้วย (คือสถานะปัจจุบัน)
-- =============================================================================

CREATE OR REPLACE FORCE EDITIONABLE VIEW "OAGWBG"."OAGWBG_V_BUDGET_RESERVE_TRANSFER_DETAIL_INTERFACE"
( "WEB_BATCH_NO", "USER_JE_SOURCE_NAME", "REFERENCE4", "REFERENCE5", "LEDGER_ID",
  "USER_JE_CATEGORY_NAME", "TRANSFER_DATE", "DEFAULT_EFFECTIVE_DATE", "ACTUAL_FLAG",
  "BUDGET_ENCUMBRANCE_NAME", "CURRENCY_CODE", "ATTRIBUTE3", "ATTRIBUTE4", "LINE_NUMBER",
  "SEGMENT1", "SEGMENT2", "SEGMENT3", "SEGMENT4", "SEGMENT5", "SEGMENT6", "SEGMENT7",
  "SEGMENT8", "SEGMENT9", "SEGMENT10", "SEGMENT11", "SEGMENT12", "SEGMENT13",
  "ENTERED_DR", "ACCOUNTED_DR", "ENTERED_CR", "ACCOUNTED_CR", "REFERENCE1",
  "CREATED_BY", "LAST_UPDATED_BY", "CREATION_DATE", "LAST_UPDATE_DATE", "REFERENCE10",
  "ENCUMBRANCE_TYPE", "TRANSFER_NO", "RECEIPIENT_ACCOUNT", "SENDER_ACCOUNT", "TYPE",
  "TRANSFERTYPE" )
AS
WITH 
BASE_DATA AS (
  SELECT
  	RBN.BATCHNAME          AS BATCHNAME,
    BT.ID                AS BT_ID,
    BT.BUDGETYEAR        AS BT_BUDGETYEAR,
    BT.TRANSFERDATE      AS BT_TRANSFERDATE,
    BT.RUNNING           AS BT_RUNNING,
    BT.ROUNDNO           AS BT_ROUNDNO,
    BT.FROMBUDGETYEAR    AS BT_FROMBUDGETYEAR,
    BR.ID                AS BR_ID,
    BR.BUDGETYEAR        AS BR_BUDGETYEAR,
    BR.BUDGETSOURCEID    AS BR_BUDGETSOURCEID,
    BR.BUDGETPLANID      AS BR_BUDGETPLANID,
    BR.CATEGORYID        AS BR_CATEGORYID,
    BR.CATEGORYNAME      AS BR_CATEGORYNAME,
	BRR.COSTCENTERIDGIVER  AS BR_COSTCENTERID,
    BR.PRODUCTID         AS BR_PRODUCTID,
    BR.ACTIVITYID        AS BR_ACTIVITYID,
    BRR.TOTALRECEIVEAMOUNT AS BR_TOTALRECEIVEAMOUNT,
    BR.CREATEBY          AS BR_CREATEBY,
    NVL(BR.UPDATEBY, BR.CREATEBY)   AS BR_LAST_UPDATED_BY,
    BR.CREATEON          AS BR_CREATEON,
    NVL(BR.UPDATEON, BR.CREATEON)   AS BR_LAST_UPDATE_DATE,
    BRR.BUDGETSOURCEID   AS BRR_BUDGETSOURCEID,
    BRR.BUDGETCODEID     AS BRR_BUDGETCODEID,
    BRR.PRODUCTID        AS BRR_PRODUCTID,
    BRR.ACTIVITYID       AS BRR_ACTIVITYID,
    BRR.BUDGETYEAR       AS BRR_BUDGETYEAR,
    CC.EXPENSE_TYPE_ID   AS CC_EXPENSE_TYPE_ID,
    CF.CONFIG_VALUE      AS LEDGER_ID,
    CCV.REGIONNAME		 AS REGIONNAME,
    CCV.ID				 AS GIVERCOSTCENTERID,
    CCV.DEPARTMENTID 	 AS GIVERDEPARTMENTID,
    CASE 
      WHEN BT.TRANSFERDATE < SYSDATE 
      THEN TO_CHAR(BT.TRANSFERDATE, 'YYYY-MM-DD')
      ELSE TO_CHAR(SYSDATE, 'YYYY-MM-DD')
    END AS DEFAULT_EFFECTIVE_DATE,
  GIVER.BUDGETSOURCEID AS GIVERSOURCE
  FROM OAGWBG_V_BUDGETTRANSFER BT
  LEFT JOIN OAGWBG_SYSTEMCONFIG CF 
         ON CF.CONFIG_KEY = 'Ledger'
  LEFT JOIN OAGWBG_V_BUDGETRECEIVE BR 
         ON BR.BUDGETTRANSFERID = BT.ID
  LEFT JOIN OAGWBG_V_BUDGETRECEIVEREFUND BRR 
         ON BRR.RECEIVEID = BR.ID
  LEFT JOIN OAGWBG_V_BUDGETRECEIVE GIVER
  		 ON GIVER.ID = BRR.GIVERID
  LEFT JOIN OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V CC 
         ON CC.ID = BR.CATEGORYID
  LEFT JOIN (
    SELECT *
    FROM (
      SELECT RBN.*,
        ROW_NUMBER() OVER (
          PARTITION BY RECEIVEID, ROUNDNO,INTERFACETYPE
          ORDER BY RUNNING DESC
        ) AS RN
      FROM OAGWBG_RECEIVE_BATCH_NO RBN
      WHERE RBN.INTERFACETYPE = 'R' OR RBN.INTERFACETYPE = 'RR' 
    )
    WHERE RN = 1
  ) RBN
    ON RBN.RECEIVEID = BR.ID
   AND RBN.ROUNDNO = BT.ROUNDNO
  LEFT JOIN OAGWBG_V_EXT_OAGGL_COST_CENTER_V CCV
  		 ON CCV.ID = BRR.COSTCENTERIDGIVER
  WHERE (BT.TRANSFERSTATUSID  = '80201' OR BT.TRANSFERSTATUSID  = '80501')
    AND BT.TRANSFERTYPE      = '3'
    AND BR.TOTALRECEIVEAMOUNT > 0
),

EAR_DATA AS (
  SELECT DISTINCT
    BD.BR_CATEGORYID,
    BD.BR_BUDGETYEAR,
    BD.BR_PRODUCTID,
    BD.BR_ACTIVITYID,
    FIRST_VALUE(EAR.BUDGETPLANID) OVER (
      PARTITION BY BD.BR_CATEGORYID, BD.BR_BUDGETYEAR, BD.BR_PRODUCTID, BD.BR_ACTIVITYID
      ORDER BY CASE 
        WHEN EAR.BUDGETYEAR     = MOD(BD.BR_BUDGETYEAR, 100)
         AND EAR.PRODUCTID      = TO_NUMBER(BD.BR_PRODUCTID)
         AND EAR.ACTIVITYCODEID = TO_NUMBER(BD.BR_ACTIVITYID)
        THEN 1 ELSE 2 
      END
    ) AS BUDGETPLANID,
    FIRST_VALUE(EAR.BUDGETTYPEID) OVER (
      PARTITION BY BD.BR_CATEGORYID, BD.BR_BUDGETYEAR, BD.BR_PRODUCTID, BD.BR_ACTIVITYID
      ORDER BY CASE 
        WHEN EAR.BUDGETYEAR     = MOD(BD.BR_BUDGETYEAR, 100)
         AND EAR.PRODUCTID      = TO_NUMBER(BD.BR_PRODUCTID)
         AND EAR.ACTIVITYCODEID = TO_NUMBER(BD.BR_ACTIVITYID)
        THEN 1 ELSE 2 
      END
    ) AS BUDGETTYPEID,
    FIRST_VALUE(EAR.BUDGETCODE) OVER (
      PARTITION BY BD.BR_CATEGORYID, BD.BR_BUDGETYEAR, BD.BR_PRODUCTID, BD.BR_ACTIVITYID
      ORDER BY CASE 
        WHEN EAR.BUDGETYEAR     = MOD(BD.BR_BUDGETYEAR, 100)
         AND EAR.PRODUCTID      = TO_NUMBER(BD.BR_PRODUCTID)
         AND EAR.ACTIVITYCODEID = TO_NUMBER(BD.BR_ACTIVITYID)
        THEN 1 ELSE 2 
      END
    ) AS BUDGETCODE,
    FIRST_VALUE(EAR.ACCOUNTNO) OVER (
      PARTITION BY BD.BR_CATEGORYID, BD.BR_BUDGETYEAR, BD.BR_PRODUCTID, BD.BR_ACTIVITYID
      ORDER BY CASE 
        WHEN EAR.BUDGETYEAR     = MOD(BD.BR_BUDGETYEAR, 100)
         AND EAR.PRODUCTID      = TO_NUMBER(BD.BR_PRODUCTID)
         AND EAR.ACTIVITYCODEID = TO_NUMBER(BD.BR_ACTIVITYID)
        THEN 1 ELSE 2 
      END
    ) AS ACCOUNTNO,
    FIRST_VALUE(EAR.SUBACCOUNTNO) OVER (
      PARTITION BY BD.BR_CATEGORYID, BD.BR_BUDGETYEAR, BD.BR_PRODUCTID, BD.BR_ACTIVITYID
      ORDER BY CASE 
        WHEN EAR.BUDGETYEAR     = MOD(BD.BR_BUDGETYEAR, 100)
         AND EAR.PRODUCTID      = TO_NUMBER(BD.BR_PRODUCTID)
         AND EAR.ACTIVITYCODEID = TO_NUMBER(BD.BR_ACTIVITYID)
        THEN 1 ELSE 2 
      END
    ) AS SUBACCOUNTNO
  FROM BASE_DATA BD
  JOIN OAGWBG_V_EXT_OAGPO_EXPENSE_ACCOUNT_RULE_V EAR 
    ON EAR.CATEGORYID = BD.BR_CATEGORYID
),

BRRCC_BANK AS (
  SELECT
    BRRCC.TRANSFERID,
    BRRCC.EXPENSETYPEID,
    BRRCC.PLANID,
    BG.CASH_ACC AS BANK_GIVER_CASH_ACC,
    BI.CASH_ACC AS BANK_RECEIVER_CASH_ACC
  FROM OAGWBG_V_BUDGETRECEIVEREFUND_COSTCENTER BRRCC
  LEFT JOIN OAGWBG.OAGWBG_V_EXT_OAGCE_BANK_ACCOUNT_V BG 
         ON BG.BANK_ACCOUNT_ID = BRRCC.BANKACCOUNTGIVERID
  LEFT JOIN OAGWBG.OAGWBG_V_EXT_OAGCE_BANK_ACCOUNT_V BI 
         ON BI.BANK_ACCOUNT_ID = BRRCC.BANKACCOUNTID
),

COMBINED AS (
  SELECT
  	BD.BATCHNAME,
    BD.BT_ID,
    BD.BT_BUDGETYEAR,
    BD.BT_TRANSFERDATE,
    BD.BT_RUNNING,
    BD.BT_ROUNDNO,
    BD.BT_FROMBUDGETYEAR,
    BD.BR_ID,
    BD.BR_BUDGETYEAR,
    BD.BR_BUDGETSOURCEID,
    BD.BR_BUDGETPLANID,
    BD.BR_CATEGORYID,
    BD.BR_CATEGORYNAME,
    BD.BR_COSTCENTERID,
    BD.BR_PRODUCTID,
    BD.BR_ACTIVITYID,
    BD.BR_TOTALRECEIVEAMOUNT,
    BD.BR_CREATEBY,
    BD.BR_LAST_UPDATED_BY,
    BD.BR_CREATEON,
    BD.BR_LAST_UPDATE_DATE,
    BD.BRR_BUDGETSOURCEID,
    BD.BRR_BUDGETCODEID,
    BD.BRR_PRODUCTID,
    BD.BRR_ACTIVITYID,
    BD.LEDGER_ID,
    BD.DEFAULT_EFFECTIVE_DATE,
    BD.REGIONNAME,
    BD.GIVERSOURCE,
    BD.BRR_BUDGETYEAR AS BRR_BUDGETYEAR,
    ED.BUDGETPLANID  AS EAR_BUDGETPLANID,
    ED.BUDGETTYPEID  AS EAR_BUDGETTYPEID,
    ED.BUDGETCODE    AS EAR_BUDGETCODE,
    ED.ACCOUNTNO     AS EAR_ACCOUNTNO,
    ED.SUBACCOUNTNO  AS EAR_SUBACCOUNTNO,
    BB.BANK_GIVER_CASH_ACC,
    BB.BANK_RECEIVER_CASH_ACC,
    BD.GIVERDEPARTMENTID AS GIVERDEPARTMENTID,
    BD.GIVERCOSTCENTERID AS GIVERCOSTCENTERID,
    ROW_NUMBER() OVER (PARTITION BY BD.BT_ID ORDER BY BD.BT_ID) AS LINE_NUMBER
  FROM BASE_DATA BD
  LEFT JOIN EAR_DATA ED
         ON ED.BR_CATEGORYID = BD.BR_CATEGORYID
        AND ED.BR_BUDGETYEAR = BD.BR_BUDGETYEAR
        AND ED.BR_PRODUCTID  = BD.BR_PRODUCTID
        AND ED.BR_ACTIVITYID = BD.BR_ACTIVITYID
  LEFT JOIN BRRCC_BANK BB
         ON BB.TRANSFERID    = BD.BT_ID
        AND BB.EXPENSETYPEID = BD.CC_EXPENSE_TYPE_ID
        AND BB.PLANID        = BD.BR_BUDGETPLANID
  LEFT JOIN OAGWBG_V_EXT_OAGGL_COST_CENTER_V CS 
         ON CS.ID = BD.BR_COSTCENTERID
)

-- =====================================================================
-- Debit (TYPE = 'O') — รวม RETURN + RENEXT
-- =====================================================================
SELECT
  BATCHNAME 														   AS WEB_BATCH_NO,
  'Web Budget'                                                         AS USER_JE_SOURCE_NAME,
  'โอนเงินสะสมเหลือจ่ายประจำปี ' || BT_BUDGETYEAR || ' ' || BT_ROUNDNO              AS REFERENCE4,
  'โอนเงินสะสมเหลือจ่ายประจำปี ' || BT_BUDGETYEAR || ' ' || BT_ROUNDNO         	   AS REFERENCE5,
  LEDGER_ID,
  'Budget - เงินเหลือจ่าย'               		                               AS USER_JE_CATEGORY_NAME,
  TO_CHAR(BT_TRANSFERDATE, 'YYYY-MM-DD')                               AS TRANSFER_DATE,
  DEFAULT_EFFECTIVE_DATE,
  'B'                                                                  AS ACTUAL_FLAG,
  'OAG_BG_FINAL'                                                       AS BUDGET_ENCUMBRANCE_NAME,
  'THB'                                                                AS CURRENCY_CODE,
  ''                                                                   AS ATTRIBUTE3,
  BT_ROUNDNO                                                           AS ATTRIBUTE4,
  LINE_NUMBER,
  GIVERDEPARTMENTID 												   AS SEGMENT1,
  GIVERCOSTCENTERID           										   AS SEGMENT2,
  MOD(BT_BUDGETYEAR, 100)                                              AS SEGMENT3,
  GIVERSOURCE                                                          AS SEGMENT4,
  EAR_BUDGETPLANID                                                     AS SEGMENT5,
  BRR_PRODUCTID                                                        AS SEGMENT6,
  BRR_ACTIVITYID                                                       AS SEGMENT7,
  EAR_BUDGETTYPEID                                                     AS SEGMENT8,
  NVL(BRR_BUDGETCODEID, EAR_BUDGETCODE)                                AS SEGMENT9,
  EAR_ACCOUNTNO                                                        AS SEGMENT10,
  EAR_SUBACCOUNTNO                                                     AS SEGMENT11,
  '00'                                                                 AS SEGMENT12,
  '000'                                                                AS SEGMENT13,
  NULL                                                				   AS ENTERED_DR,
  NULL                                                				   AS ACCOUNTED_DR,
  BR_TOTALRECEIVEAMOUNT                                                AS ENTERED_CR,
  BR_TOTALRECEIVEAMOUNT                                                AS ACCOUNTED_CR,
  'BUDGET_REVENUE_' || BT_BUDGETYEAR || '_NO_' || TO_CHAR(BT_TRANSFERDATE, 'yyyyMMddHHmmss') AS REFERENCE1,
  BR_CREATEBY                                                          AS CREATED_BY,
  BR_LAST_UPDATED_BY                                                   AS LAST_UPDATED_BY,
  BR_CREATEON                                                          AS CREATION_DATE,
  BR_LAST_UPDATE_DATE                                                  AS LAST_UPDATE_DATE,
  BR_CATEGORYNAME                                                      AS REFERENCE10,
  'Web Encumbrance'													   AS ENCUMBRANCE_TYPE,
  BT_ROUNDNO                                                           AS TRANSFER_NO,
  ''                                                                   AS RECEIPIENT_ACCOUNT,
  BANK_GIVER_CASH_ACC                                                  AS SENDER_ACCOUNT,
  'O'                                                                  AS TYPE,
  CASE 
   WHEN BATCHNAME LIKE '%REVERSE' THEN 'REV_REVENUE'
   ELSE 'REVENUE'
  END AS TRANSFERTYPE 
FROM COMBINED

UNION ALL

-- =====================================================================
-- Credit (TYPE = 'I') — รวม RETURN + RENEXT
-- =====================================================================
SELECT
  BATCHNAME                                                            AS WEB_BATCH_NO,
  'Web Budget'                                                         AS USER_JE_SOURCE_NAME,
  'โอนเงินสะสมเหลือจ่ายประจำปี ' || BT_BUDGETYEAR || ' ' || BT_ROUNDNO              AS REFERENCE4,
  'โอนเงินสะสมเหลือจ่ายประจำปี ' || BT_BUDGETYEAR || ' ' || BT_ROUNDNO          	   AS REFERENCE5,
  LEDGER_ID,
  'Budget - เงินเหลือจ่าย'                                       		       AS USER_JE_CATEGORY_NAME,
  TO_CHAR(BT_TRANSFERDATE, 'YYYY-MM-DD')                               AS TRANSFER_DATE,
  DEFAULT_EFFECTIVE_DATE,
  'B'                                                                  AS ACTUAL_FLAG,
  'OAG_BG_FINAL'                                                       AS BUDGET_ENCUMBRANCE_NAME,
  'THB'                                                                AS CURRENCY_CODE,
  ''                                                                   AS ATTRIBUTE3,
  BT_ROUNDNO                                                           AS ATTRIBUTE4,
  LINE_NUMBER,
  --'2900600000'                                                         AS SEGMENT1,
  --'2900600000'                                                         AS SEGMENT2,
  GIVERDEPARTMENTID 												   AS SEGMENT1,
  GIVERCOSTCENTERID           										   AS SEGMENT2,
  --MOD(BR_BUDGETYEAR, 100)                                              AS SEGMENT3,
  MOD(BRR_BUDGETYEAR, 100)                                              AS SEGMENT3,
  '200'							                                       AS SEGMENT4,
  EAR_BUDGETPLANID                                                     AS SEGMENT5,
  BRR_PRODUCTID                                                        AS SEGMENT6,
  BRR_ACTIVITYID                                                       AS SEGMENT7,
  EAR_BUDGETTYPEID                                                     AS SEGMENT8,
  NVL(BRR_BUDGETCODEID, EAR_BUDGETCODE)                                AS SEGMENT9,
  EAR_ACCOUNTNO                                                        AS SEGMENT10,
  EAR_SUBACCOUNTNO                                                     AS SEGMENT11,
  '00'                                                                 AS SEGMENT12,
  '000'                                                                AS SEGMENT13,
  BR_TOTALRECEIVEAMOUNT                                                AS ENTERED_DR,
  BR_TOTALRECEIVEAMOUNT                                                AS ACCOUNTED_DR,
  NULL 					                                               AS ENTERED_CR,
  NULL                                             					   AS ACCOUNTED_CR,
  'BUDGET_REVENUE_' || BT_BUDGETYEAR || '_NO_' || TO_CHAR(BT_TRANSFERDATE, 'yyyyMMddHHmmss') AS REFERENCE1,
  BR_CREATEBY                                                          AS CREATED_BY,
  BR_LAST_UPDATED_BY                                                   AS LAST_UPDATED_BY,
  BR_CREATEON                                                          AS CREATION_DATE,
  BR_LAST_UPDATE_DATE                                                  AS LAST_UPDATE_DATE,
  BR_CATEGORYNAME                                                      AS REFERENCE10,
  'Web Encumbrance'													   AS ENCUMBRANCE_TYPE,
  BT_ROUNDNO                                                           AS TRANSFER_NO,
  BANK_RECEIVER_CASH_ACC                                               AS RECEIPIENT_ACCOUNT,
  ''                                                                   AS SENDER_ACCOUNT,
  'I'                                                                  AS TYPE,
  CASE  
   WHEN BATCHNAME LIKE '%REVERSE' THEN 'REV_REVENUE'
   ELSE 'REVENUE'
  END AS TRANSFERTYPE 
FROM COMBINED
;
