
  CREATE OR REPLACE FORCE EDITIONABLE VIEW "OAGWBG"."OAGWBG_R_BUDGETOVERLAP_RESERVED" ("BUDGETRESERVEDID", "BUDGETYEAR", "TRANSFERNO", "RESERVATIONNAME", "RESERVATIONTYPE", "BUDGETRESERVEDREGION", "ALLOCATE_TRANSFERNO", "REGIONID", "REGIONNAME", "COSTCENTERID", "COSTCENTERNAME", "DEPARTMENTID", "DEPARTMENTNAME", "CATEGORYID", "CATEGORYNAME", "CATEGORY_CODE", "TOTALRESERVEDAMOUNT", "ITEMID", "DESCRIPTION", "SUPPLIER", "BOOKNUMBER", "ACCOUNTCODE", "ITEMRESERVEDTYPE", "TOTALBALANCEAMOUNT", "USAGEAMOUNT", "RESERVEDNO_ADD", "NOTE", "OVERLAPYEAR", "OVERLAPROUND", "RESERVEDITEMDATE", "APPROVE_EXPAND_HASOBLIGATION", "APPROVE_EXPAND_NOOBLIGATION", "PROCESS_HASOBLIGATION", "PROCESS_NOOBLIGATION", "RESERVEDTYPENAME", "STATUSID", "STATUSNAME") AS 
  WITH TSV_RAW AS (
    SELECT /*+ MATERIALIZE */
           PR_NUMBER, PR_TRANSFER_NO, PR_BUDGET_ACCOUNT,
           PO_NUMBER, PO_TRANSFER_NO, PO_BUDGET_ACCOUNT
    FROM   APPS.OAGPO_TRANSACTION_STATUS_V
)
SELECT
    -- ===== à¸£à¸°à¸”à¸±à¸šà¸«à¸±à¸§à¸à¸±à¸™à¹€à¸‡à¸´à¸™ (group) =====
    BRS.ID                                   AS BUDGETRESERVEDID,
    BRSI.BUDGETYEAR                           AS BUDGETYEAR,
    BRS.TRANSFERNO                           AS TRANSFERNO,            -- à¹€à¸¥à¸‚à¸—à¸µà¹ˆà¸à¸±à¸™à¹€à¸‡à¸´à¸™ (à¸«à¸±à¸§à¸à¸¥à¸¸à¹ˆà¸¡à¸£à¸²à¸¢à¸‡à¸²à¸™)
    BRS.RESERVATIONNAME                      AS RESERVATIONNAME,
    BRS.RESERVATIONTYPE                      AS RESERVATIONTYPE,
    BRS.BUDGETRESERVEDREGION                 AS BUDGETRESERVEDREGION,

    -- ===== à¹€à¸¥à¸‚à¸—à¸µà¹ˆà¹‚à¸­à¸™à¸ˆà¸±à¸”à¸ªà¸£à¸£ (?? à¸”à¸¹à¸‚à¹‰à¸­ 7.1) =====
    COALESCE(BRSI.PO_TRANSFER_NO, BRSI.PR_TRANSFER_NO, BRSI.TRANSFERNO) AS ALLOCATE_TRANSFERNO,

    -- ===== à¸žà¸·à¹‰à¸™à¸—à¸µà¹ˆà¸ à¸²à¸„ / à¸ªà¸³à¸™à¸±à¸à¸‡à¸²à¸™ (à¸ˆà¸²à¸à¸¨à¸¹à¸™à¸¢à¹Œà¸•à¹‰à¸™à¸—à¸¸à¸™) =====
    COSTV.REGIONID                           AS REGIONID,
    COSTV.REGIONNAME                         AS REGIONNAME,            -- à¸žà¸·à¹‰à¸™à¸—à¸µà¹ˆ à¸ à¸²à¸„
    BRS.COSTCENTERID                         AS COSTCENTERID,
    COSTV.NAME                               AS COSTCENTERNAME,        -- à¸ªà¸³à¸™à¸±à¸à¸‡à¸²à¸™
    BRS.DEPARTMENTID                         AS DEPARTMENTID,
    DEPTV.NAME                               AS DEPARTMENTNAME,

    -- ===== à¸£à¸²à¸¢à¸à¸²à¸£ (à¸«à¸¡à¸§à¸”) =====
    CAT.CATEGORYID                           AS CATEGORYID,
    CAT.CATEGORYNAME                         AS CATEGORYNAME,          -- à¸£à¸²à¸¢à¸à¸²à¸£ (à¸•à¸²à¸¡ prompt)
    CAT.CATEGORY_CODE                        AS CATEGORY_CODE,
    CAT.TOTALRESERVEDAMOUNT                  AS TOTALRESERVEDAMOUNT,   -- à¸¢à¸­à¸”à¸à¸±à¸™à¹€à¸‡à¸´à¸™à¸£à¸§à¸¡à¸‚à¸­à¸‡à¸«à¸¡à¸§à¸”

    -- ===== à¸£à¸°à¸”à¸±à¸šà¸£à¸²à¸¢à¸à¸²à¸£ (item) =====
    BRSI.ID                                  AS ITEMID,
    BRSI.DESCRIPTION                         AS DESCRIPTION,           -- à¸Šà¸·à¹ˆà¸­à¸£à¸²à¸¢à¸à¸²à¸£à¸£à¸°à¸”à¸±à¸š item (à¸—à¸µà¹ˆ PDF à¹‚à¸Šà¸§à¹Œà¹ƒà¸™à¸šà¸£à¸£à¸—à¸±à¸”à¸¢à¹ˆà¸­à¸¢)
    BRSI.SUPPLIER                            AS SUPPLIER,
    BRSI.BOOKNUMBER                          AS BOOKNUMBER,            -- à¹€à¸¥à¸‚à¸—à¸µà¹ˆà¹€à¸­à¸à¸ªà¸²à¸£
    BRSI.ACCOUNTCODE                         AS ACCOUNTCODE,
    BRSI.BUDGETRESERVEDTYPE                  AS ITEMRESERVEDTYPE,      -- O/R/EXPAND_*/CANCEL_*
    BRSI.TOTALBALANCEAMOUNT                  AS TOTALBALANCEAMOUNT,    -- à¸ˆà¸³à¸™à¸§à¸™à¹€à¸‡à¸´à¸™à¸ˆà¸±à¸”à¸ªà¸£à¸£
    BRSI.USAGEAMOUNT                         AS USAGEAMOUNT,           -- à¸¢à¸­à¸”à¸—à¸µà¹ˆà¹ƒà¸Šà¹‰ (raw)
    BRSI.RESERVEDNO_ADD                      AS RESERVEDNO_ADD,        -- à¹€à¸¥à¸‚à¸—à¸µà¹ˆà¹€à¸‡à¸´à¸™à¸à¸±à¸™à¹€à¸žà¸´à¹ˆà¸¡ .n
    BRSI.NOTE                                AS NOTE,                  -- à¸«à¸¡à¸²à¸¢à¹€à¸«à¸•à¸¸
    BRSI.OVERLAPYEAR                         AS OVERLAPYEAR,
    BRSI.OVERLAPROUND                        AS OVERLAPROUND,
    BRSI.CREATEON                            AS RESERVEDITEMDATE,

    -- ===== pivot à¸¢à¸­à¸”à¸•à¸²à¸¡à¸›à¸£à¸°à¹€à¸ à¸— (à¸„à¸­à¸¥à¸±à¸¡à¸™à¹Œà¸£à¸²à¸¢à¸‡à¸²à¸™à¸•à¸£à¸‡ à¹†) =====
    CASE WHEN BRSI.BUDGETRESERVEDTYPE = 'EXPAND_PO' THEN BRSI.USAGEAMOUNT END AS APPROVE_EXPAND_HASOBLIGATION,  -- à¸­à¸™à¸¸à¸¡à¸±à¸•à¸´à¸‚à¸¢à¸²à¸¢: à¸¡à¸µà¸«à¸™à¸µà¹‰
    CASE WHEN BRSI.BUDGETRESERVEDTYPE = 'EXPAND_PR' THEN BRSI.USAGEAMOUNT END AS APPROVE_EXPAND_NOOBLIGATION,   -- à¸­à¸™à¸¸à¸¡à¸±à¸•à¸´à¸‚à¸¢à¸²à¸¢: à¹„à¸¡à¹ˆà¸¡à¸µà¸«à¸™à¸µà¹‰
    CASE WHEN BRSI.BUDGETRESERVEDTYPE = 'CANCEL_PO' THEN BRSI.USAGEAMOUNT END AS PROCESS_HASOBLIGATION,         -- à¸”à¸³à¹€à¸™à¸´à¸™à¸à¸²à¸£: à¸¡à¸µà¸«à¸™à¸µà¹‰
    CASE WHEN BRSI.BUDGETRESERVEDTYPE = 'CANCEL_PR' THEN BRSI.USAGEAMOUNT END AS PROCESS_NOOBLIGATION,          -- à¸”à¸³à¹€à¸™à¸´à¸™à¸à¸²à¸£: à¹„à¸¡à¹ˆà¸¡à¸µà¸«à¸™à¸µà¹‰

    -- ===== à¹à¸›à¸¥à¸›à¸£à¸°à¹€à¸ à¸— / à¸ªà¸–à¸²à¸™à¸° (à¸ªà¹„à¸•à¸¥à¹Œà¹€à¸”à¸µà¸¢à¸§à¸à¸±à¸šà¸§à¸´à¸§à¹€à¸”à¸´à¸¡) =====
    CASE
        WHEN BRSI.BUDGETRESERVEDTYPE IN ('O','EXPAND_PO','CANCEL_PO') THEN 'à¸¡à¸µà¸«à¸™à¸µà¹‰'
        WHEN BRSI.BUDGETRESERVEDTYPE IN ('R','EXPAND_PR','CANCEL_PR') THEN 'à¹„à¸¡à¹ˆà¸¡à¸µà¸«à¸™à¸µà¹‰'
        ELSE 'à¹„à¸¡à¹ˆà¸£à¸°à¸šà¸¸'
    END                                      AS RESERVEDTYPENAME,
    CASE WHEN BRS.BUDGETRESERVEDREGION = 'C' THEN BRS.STATUSID   ELSE BRSI.STATUSID   END AS STATUSID,
    CASE WHEN BRS.BUDGETRESERVEDREGION = 'C' THEN BRS.STATUSNAME ELSE BRSI.STATUSNAME END AS STATUSNAME
FROM       OAGWBG_V_BUDGETRESERVED           BRS
LEFT JOIN (
    -- à¹à¸—à¸™ OAGWBG_V_BUDGETRESERVEDITEM : à¹€à¸­à¸²à¹€à¸‰à¸žà¸²à¸° join à¸—à¸µà¹ˆ view à¸™à¸µà¹‰à¹ƒà¸Šà¹‰à¸ˆà¸£à¸´à¸‡
    -- (à¸•à¸±à¸” CFPO / BANKACCOUNT / BS à¸—à¸´à¹‰à¸‡ â€” à¹„à¸¡à¹ˆà¹„à¸”à¹‰à¹ƒà¸Šà¹‰)
    SELECT BR0.ID,
           BR0.BUDGETREVERSEDID,
           BR0.BUDGETYEAR,
           BR0.DESCRIPTION,
           BR0.SUPPLIER,
           BR0.BUDGETRESERVEDTYPE,
           BR0.TOTALBALANCEAMOUNT,
           BR0.STATUSID,
           CASE
               WHEN MS.NAME LIKE '%à¸šà¸±à¸™à¸—à¸¶à¸%' THEN 'à¸ªà¹ˆà¸‡à¹€à¸£à¸·à¹ˆà¸­à¸‡à¹ƒà¸«à¹‰à¸žà¸´à¸ˆà¸²à¸£à¸“à¸²'
               ELSE MS.NAME
           END                              AS STATUSNAME,
           BR0.CREATEON,
           BR0.ACCOUNTCODE,
           BR0.BOOKNUMBER,
           BR0.NOTE,
           BR0.OVERLAPROUND,
           BR0.OVERLAPYEAR,
           BR0.RESERVEDNO_ADD,
           BR0.TRANSFERNO,
           BR0.USAGEAMOUNT,
           ovbr.PR_TRANSFER_NO              AS PR_TRANSFER_NO,
           ovbo.PO_TRANSFER_NO              AS PO_TRANSFER_NO
    FROM       OAGWBG_BUDGETRESERVEDITEM BR0
    LEFT JOIN  OAGWBG_MASTERSTATUS MS ON MS.ID = BR0.STATUSID
    LEFT JOIN  (SELECT * FROM TSV_RAW a WHERE a.PR_TRANSFER_NO IS NOT NULL) ovbr
           ON  ovbr.PR_BUDGET_ACCOUNT = BR0.ACCOUNTCODE AND BR0.BOOKNUMBER = ovbr.PR_NUMBER
    LEFT JOIN  (SELECT * FROM TSV_RAW b WHERE b.PO_TRANSFER_NO IS NOT NULL) ovbo
           ON  ovbo.PO_BUDGET_ACCOUNT = BR0.ACCOUNTCODE AND BR0.BOOKNUMBER = ovbo.PO_NUMBER
)                                            BRSI  ON BRS.ID = BRSI.BUDGETREVERSEDID AND (BRSI.PO_TRANSFER_NO IS NOT NULL OR BRSI.PR_TRANSFER_NO IS NOT NULL)
LEFT JOIN  OAGWBG_V_BUDGETRESERVED_CATEGORY  CAT   ON BRS.ID = CAT.BUDGETRESERVEDID   -- ?? à¸”à¸¹à¸‚à¹‰à¸­ 7.2 (1 à¸«à¸¡à¸§à¸”/à¸«à¸±à¸§)
LEFT JOIN  OAGWBG_V_EXT_OAGGL_DEPARTMENT_V   DEPTV ON BRS.DEPARTMENTID = DEPTV.ID
LEFT JOIN  OAGWBG_V_EXT_OAGGL_COST_CENTER_V  COSTV ON BRS.COSTCENTERID = COSTV.ID
WHERE  BRSI.BUDGETRESERVEDTYPE IN ('EXPAND_PO','EXPAND_PR','CANCEL_PO','CANCEL_PR')
