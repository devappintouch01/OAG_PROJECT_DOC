-- ROLLBACK: OAGWBG_R_KTBPAYMENT กลับเป็นเวอร์ชันก่อนแก้
-- ที่มา: DBMS_METADATA.GET_DDL จาก PREPROD (ebs_PRE) 2026-10-16

CREATE OR REPLACE FORCE EDITIONABLE VIEW "OAGWBG"."OAGWBG_R_KTBPAYMENT" ("BUDGETYEAR", "REGIONID", "REGIONNAME", "TRANSFERDATE", "ROUNDNO", "BOOKNO", "BANKNUMBER", "RECIEVERNO", "RECIEVERNAME", "TRANFERAMOUNT", "CITIZENID", "DDAREF", "DEPARTMENTID", "COSTCENTERNAME", "COSTCENTERID", "EMAIL", "MOBILENO", "RESERVEDID", "BUDGETPLANID", "EXPENSETYPEID", "TRANSFERTYPE") AS
  WITH
transfer_cte AS (
  SELECT
    t.ID,
    t.BUDGETYEAR,
    t.REGIONID,
    t.REGIONNAME,
    t.TRANSFERDATE,
    t.ROUNDNO,
    t.BOOKNO
  FROM OAGWBG_V_BUDGETALLOCATETRANSFER t
--  WHERE TRANSFERSTATUS = '80201'
),
cc AS (
  SELECT
    c.BUDGETALLOCATETRANSFERID,
    c.BANKACCOUNTID,
    c.COSTCENTERNAME,
    c.COSTCENTERID,
    c.DEPARTMENTID,
    c.PLANID,
    c.EXPENSETYPEID,
    SUM(c.TOTALRECEIVEAMOUNT) AS TOTALRECEIVEAMOUNT
  FROM OAGWBG_V_BUDGETALLOCATETRANSFER_COSTCENTER c
  GROUP BY
    c.BUDGETALLOCATETRANSFERID,
    c.BANKACCOUNTID,
    c.COSTCENTERID,
    c.COSTCENTERNAME,
    c.DEPARTMENTID,
    c.PLANID,
    c.EXPENSETYPEID
),
bank_acc AS (
  SELECT
    b.BANK_ACCOUNT_ID,
    MIN(b.BANK_NUMBER)       AS BANK_NUMBER,
    MIN(b.BANK_ACCOUNT_NUM)  AS BANK_ACCOUNT_NUM,
    MIN(b.BANK_ACCOUNT_NAME) AS BANK_ACCOUNT_NAME
  FROM OAGWBG_V_EXT_OAGCE_BANK_ACCOUNT_V b
  GROUP BY b.BANK_ACCOUNT_ID
),
cat_exists AS (
  SELECT DISTINCT BUDGETALLOCATETRANSFERID
  FROM OAGWBG_V_BUDGETALLOCATETRANSFER_CATEGORY
),BRR AS (
        SELECT BUDGETYEAR, TRANSFERID, EXPENSE_TYPE_ID, BUDGETPLANID, TOTALREFUNDAMOUNT, RECEIVEID
        FROM OAGWBG_BUDGETRECEIVEREFUND
        JOIN OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V CC
                ON CC.ID = CATEGORYID
)
SELECT
  t.BUDGETYEAR                           AS BUDGETYEAR,
  t.REGIONID                             AS REGIONID,
  t.REGIONNAME                           AS REGIONNAME,
  t.TRANSFERDATE                         AS TRANSFERDATE,
  t.ROUNDNO                              AS ROUNDNO,
  t.BOOKNO                               AS BOOKNO,
  b.BANK_NUMBER                          AS BANKNUMBER,
  b.BANK_ACCOUNT_NUM                     AS RECIEVERNO,
  b.BANK_ACCOUNT_NAME                    AS RECIEVERNAME,
  cc.TOTALRECEIVEAMOUNT                  AS TRANFERAMOUNT,
  ''                                     AS CITIZENID,
  (t.BOOKNO || '-' || t.ROUNDNO)         AS DDAREF,
  cc.DEPARTMENTID                            AS DEPARTMENTID,
  cc.COSTCENTERNAME                      AS COSTCENTERNAME,
  cc.COSTCENTERID                            AS COSTCENTERID,
  ''                                     AS EMAIL,
  ''                                     AS MOBILENO,
  CAST(NULL AS NUMBER(10))               AS RESERVEDID,
  cc.PLANID                                                                 AS BUDGETPLANID,
  cc.EXPENSETYPEID                                                 AS EXPENSETYPEID,
  '1'                                                                             AS TRANSFERTYPE
FROM transfer_cte t
JOIN cat_exists ce
  ON ce.BUDGETALLOCATETRANSFERID = t.ID
LEFT JOIN cc
  ON cc.BUDGETALLOCATETRANSFERID = t.ID
LEFT JOIN bank_acc b
  ON b.BANK_ACCOUNT_ID = cc.BANKACCOUNTID

UNION ALL

SELECT
  r.BUDGETYEAR                                 AS BUDGETYEAR,
  CAST(NULL AS VARCHAR2(250))                  AS REGIONID,
  CAST(NULL AS VARCHAR2(240))                  AS REGIONNAME,
  CAST(NULL AS TIMESTAMP(6))                   AS TRANSFERDATE,
  CAST(r.TRANSFERNO AS NUMBER)                                   AS ROUNDNO,
  rb.TRANSFERNO                                AS BOOKNO,
  b2.BANK_NUMBER                               AS BANKNUMBER,
  b2.BANK_ACCOUNT_NUM                          AS RECIEVERNO,
  b2.BANK_ACCOUNT_NAME                         AS RECIEVERNAME,
  rb.TOTALTRANSFERAMOUNT                       AS TRANFERAMOUNT,
  ''                                           AS CITIZENID,
  rb.TRANSFERNO                                AS DDAREF,
  r.DEPARTMENTID                                              AS DEPARTMENTID,
  COSTV.NAME                                                 AS COSTCENTERNAME,
  r.COSTCENTERID                                              AS COSTCENTERID,
  ''                                           AS EMAIL,
  ''                                           AS MOBILENO,
  CAST(rb.RESERVEDID AS NUMBER(10))            AS RESERVEDID,
  BRI.BUDGETPLANID                                                            AS BUDGETPLANID,
  CAST(NULL AS VARCHAR(255))                                   AS EXPENSETYPEID,
  '2'                                                                                       AS TRANSFERTYPE
FROM OAGWBG_BUDGETRESERVED_BANKACCOUNT rb
LEFT JOIN OAGWBG_BUDGETRESERVED r
  ON r.ID = rb.RESERVEDID
  INNER JOIN OAGWBG.OAGWBG_V_EXT_OAGGL_COST_CENTER_V COSTV
  ON r.COSTCENTERID = COSTV.ID
LEFT JOIN OAGWBG_BUDGETRESERVEDITEM BRI
        ON BRI.BUDGETREVERSEDID = r.ID
LEFT JOIN bank_acc b2
  ON b2.BANK_ACCOUNT_ID = rb.BANKACCOUNTRECEIVER
WHERE r.STATUSID IN (20202 , 90102 , 90109 , 90201 )
        AND r.ROUNDINTERFACE IS NOT NULL
UNION ALL

SELECT
  BRR.BUDGETYEAR                                                           AS BUDGETYEAR,
  CAST(NULL AS VARCHAR2(250))                  AS REGIONID,
  CAST(NULL AS VARCHAR2(240))                  AS REGIONNAME,
  BT.TRANSFERDATE                                            AS TRANSFERDATE,
  BT.ROUNDNO                                                                    AS ROUNDNO,
  BT.TRANSFERNO                                AS BOOKNO,
  b3.BANK_NUMBER                               AS BANKNUMBER,
  b3.BANK_ACCOUNT_NUM                          AS RECIEVERNO,
  b3.BANK_ACCOUNT_NAME                         AS RECIEVERNAME,
  BRR.TOTALREFUNDAMOUNT                             AS TRANFERAMOUNT,
  ''                                           AS CITIZENID,
  CAST(BT.ROUNDNO AS varchar2(50))                    AS DDAREF,
  BRRCC.DEPARTMENTID                                      AS DEPARTMENTID,
  BRRCC.COSTCENTERNAME                               AS COSTCENTERNAME,
  BRRCC.COSTCENTERID                                      AS COSTCENTERID,
  ''                                           AS EMAIL,
  ''                                           AS MOBILENO,
  CAST(NULL AS NUMBER(10))                                   AS RESERVEDID,
  BRRCC.PLANID                                                               AS BUDGETPLANID,
  BRRCC.EXPENSETYPEID                                                   AS EXPENSETYPEID,
  '3'           AS TRANSFERTYPE
 FROM OAGWBG_BUDGETTRANSFER BT
 JOIN BRR
         ON BRR.TRANSFERID = BT.ID
 LEFT JOIN OAGWBG_V_BUDGETRECEIVEREFUND_COSTCENTER BRRCC
         ON BRRCC.PLANID = BRR.BUDGETPLANID
         AND BRRCC.EXPENSETYPEID = BRR.EXPENSE_TYPE_ID
         AND BRRCC.TRANSFERID = BRR.TRANSFERID
  LEFT JOIN bank_acc b3
  ON b3.BANK_ACCOUNT_ID = BRRCC.BANKACCOUNTID
  WHERE BT.TRANSFERTYPE = 2 AND BT.TRANSFERSTATUSID = 80201

 UNION ALL

SELECT
  BRR.BUDGETYEAR                                                           AS BUDGETYEAR,
  CAST(NULL AS VARCHAR2(250))                  AS REGIONID,
  CAST(NULL AS VARCHAR2(240))                  AS REGIONNAME,
  BT.TRANSFERDATE                                            AS TRANSFERDATE,
  BT.ROUNDNO                                                                    AS ROUNDNO,
  BT.TRANSFERNO                                AS BOOKNO,
  b3.BANK_NUMBER                               AS BANKNUMBER,
  b3.BANK_ACCOUNT_NUM                          AS RECIEVERNO,
  b3.BANK_ACCOUNT_NAME                         AS RECIEVERNAME,
  BRR.TOTALREFUNDAMOUNT                             AS TRANFERAMOUNT,
  ''                                           AS CITIZENID,
  CAST(BT.ROUNDNO AS varchar2(50))                    AS DDAREF,
  BRRCC.DEPARTMENTID                                      AS DEPARTMENTID,
  BRRCC.COSTCENTERNAME                               AS COSTCENTERNAME,
  BRRCC.COSTCENTERID                                      AS COSTCENTERID,
  ''                                           AS EMAIL,
  ''                                           AS MOBILENO,
  CAST(NULL AS NUMBER(10))                                   AS RESERVEDID,
  BRRCC.PLANID                                                               AS BUDGETPLANID,
  BRRCC.EXPENSETYPEID                                                   AS EXPENSETYPEID,
  '4'           AS TRANSFERTYPE
 FROM OAGWBG_BUDGETTRANSFER BT
 JOIN BRR
         ON BRR.TRANSFERID = BT.ID
 LEFT JOIN OAGWBG_V_BUDGETRECEIVEREFUND_COSTCENTER BRRCC
         ON BRRCC.PLANID = BRR.BUDGETPLANID
         AND BRRCC.EXPENSETYPEID = BRR.EXPENSE_TYPE_ID
         AND BRRCC.TRANSFERID = BRR.TRANSFERID
  LEFT JOIN bank_acc b3
  ON b3.BANK_ACCOUNT_ID = BRRCC.BANKACCOUNTID
 WHERE BT.TRANSFERTYPE = 3 AND BT.TRANSFERSTATUSID = 80201
UNION ALL

SELECT
  BA.BUDGETYEAR                                AS BUDGETYEAR,
  BA.TRANSFERREGION                            AS REGIONID,
  CAST(NULL AS VARCHAR2(240))                  AS REGIONNAME,
  BT.TRANSFERDATE                                            AS TRANSFERDATE,
  BA.ROUNDNO                                                                    AS ROUNDNO,
  BT.TRANSFERNO                                AS BOOKNO,
  b4.BANK_NUMBER                               AS BANKNUMBER,
  b4.BANK_ACCOUNT_NUM                          AS RECIEVERNO,
  b4.BANK_ACCOUNT_NAME                         AS RECIEVERNAME,
  RE.TOTALRECEIVEAMOUNT                             AS TRANFERAMOUNT,
  ''                                           AS CITIZENID,
  CAST(BT.ROUNDNO AS varchar2(50))                    AS DDAREF,
  BA.DEPARTMENTID                                         AS DEPARTMENTID,
  COSTV1.NAME                                       AS COSTCENTERNAME,
  BA.COSTCENTERID                                         AS COSTCENTERID,
  ''                                           AS EMAIL,
  ''                                           AS MOBILENO,
  CAST(NULL AS NUMBER(10))                                   AS RESERVEDID,
  BA.BUDGETPLANID                                                       AS BUDGETPLANID,
  BRR.EXPENSE_TYPE_ID                                                   AS EXPENSETYPEID,
  '5'            AS TRANSFERTYPE
 FROM OAGWBG_BUDGETADJUST BA
 JOIN OAGWBG_BUDGETTRANSFER BT
    ON BT.ID = BA.BUDGETTRANSFERID
 LEFT JOIN OAGWBG_BUDGETRECEIVE RE
    ON RE.BUDGETADJUSTID = BA.ID
     AND RE.BUDGETRECEIVETYPE = 'J'
  JOIN BRR
         ON BRR.RECEIVEID = RE.ID
  LEFT JOIN (
    SELECT DISTINCT
        TRANSFERID, COSTCENTERID, PLANID, EXPENSETYPEID,
        BANKACCOUNTID, BANKACCOUNTGIVERID
    FROM OAGWBG_V_BUDGETRECEIVEREFUND_COSTCENTER
 ) BRRCC
    ON BRRCC.TRANSFERID                    = BT.ID
    AND NVL(BRRCC.COSTCENTERID,  '0')     = NVL(RE.COSTCENTERID, '0')
    AND NVL(BRRCC.PLANID,        '0')     = NVL(BRR.BUDGETPLANID, '0')
    AND NVL(BRRCC.EXPENSETYPEID, '0')     = NVL(BRR.EXPENSE_TYPE_ID, '0')
LEFT JOIN bank_acc b4
   ON b4.BANK_ACCOUNT_ID = BRRCC.BANKACCOUNTID
INNER JOIN OAGWBG.OAGWBG_V_EXT_OAGGL_COST_CENTER_V COSTV1
  ON RE.COSTCENTERID = COSTV1.ID
     WHERE BT.TRANSFERSTATUSID = 80201
/
