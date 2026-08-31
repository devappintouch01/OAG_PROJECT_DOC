--------------------------------------------------------------------------------
-- OAGWBG_R_BUDGETOVERLAP_CATEGORY  (v2 — perf fix 2026-08-27)
--------------------------------------------------------------------------------
-- ใช้สำหรับ : รายงานกันเงินไว้เบิกเหลื่อมปี (ReportBudgetOverlap Template "1")
--
-- สิ่งที่เปลี่ยนจาก v1 (เหตุผลเชิง performance เท่านั้น — ผลลัพธ์ต้องเหมือนเดิม) :
--
--   1) เพิ่ม CTE `TSV_RAW` ครอบ APPS.OAGPO_TRANSACTION_STATUS_V
--      view ของ EBS ตัวนี้ push predicate เข้าไปข้างในไม่ได้ (กรอง PO_NUMBER เดียว
--      ก็ยังใช้ 9.2 วิ เท่ากับ scan ทั้ง 18,507 แถว) และ v1 อ้างถึงมัน 4 ครั้ง
--      ผ่าน OAGWBG_V_BUDGETRESERVEDITEM + อีก 1 ครั้งที่ TSV = 5 x 10 วิ
--      การยกมาเป็น CTE ทำให้ Oracle materialize ลง temp ครั้งเดียว แล้วอ่านซ้ำได้ฟรี
--      และยังทำหน้าที่เป็น optimizer barrier กัน view merging ไปด้วย
--
--   2) เลิกใช้ OAGWBG_V_BUDGETRESERVEDITEM ใน branch 2 → อ่านตาราง
--      OAGWBG_BUDGETRESERVEDITEM ตรง ๆ (11 ms) แล้ว join CFPO เอง
--      จาก 18 คอลัมน์ที่ branch 2 ใช้ มี 17 ตัวมาจากตารางจริงอยู่แล้ว
--      เหลือแค่ CONTRACT_CARRY_FORWARD_PO ตัวเดียวที่ต้องคำนวณ
--      view ตัวนั้นยัง join MASTERSTATUS / BANKACCOUNT / V_BUDGETRESERVED และ
--      ยิง EBS อีก 2 ครั้ง (ovbr, ovbo) ซึ่ง view นี้ไม่ได้ใช้เลย
--
--   ⚠️ logic ของ CFPO (OR + NOT EXISTS) คงไว้ครบตามเดิมทุกตัวอักษร
--      เปลี่ยนแค่ว่าอ้าง TSV_RAW แทนการอ้าง APPS.OAGPO_TRANSACTION_STATUS_V ตรง ๆ
--
--   ผลวัดจริงบน PREPROD : COUNT(*) จาก TIMEOUT >300 วิ เหลือ ~12.9 วิ (63 แถวเท่าเดิม)
--
--   หมายเหตุ : การแปลงเป็น inline subquery (FROM (SELECT ...)) เฉย ๆ ไม่ช่วยเลย
--   ยัง timeout อยู่ เพราะ Oracle merge กลับเข้าคิวรีหลัก — ต้องเป็น WITH เท่านั้น
--
-- rollback : rollback_view_budgetoverlap_category.sql
--------------------------------------------------------------------------------
-- grain (ไม่เปลี่ยนจาก v1) :
--   Region 'C'     -> 1 แถวต่อ (BUDGETRESERVEDID, CATEGORYID)  ไม่ join item
--   Region อื่น ๆ  -> 1 แถวต่อ item เฉพาะรายการที่กันเงินแล้ว ('O','R')
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW OAGWBG_R_BUDGETOVERLAP_CATEGORY AS
WITH TSV_RAW AS (
    -- materialize ครั้งเดียว แล้วให้ทุกจุดข้างล่างอ่านซ้ำจาก temp
    SELECT /*+ MATERIALIZE */
           PR_STATUS, PR_BUDGET_ACCOUNT,
           PO_STATUS, PO_BUDGET_ACCOUNT,
           PO_NUMBER, PO_LINE_ID, PO_CONTRACT_DATE
    FROM   APPS.OAGPO_TRANSACTION_STATUS_V
)
--==============================================================================
-- 1) ส่วนกลาง : ระดับหมวด (ยอดกันเงินก้อนแรก)
--==============================================================================
SELECT
    BRS.ID                                   AS BUDGETRESERVEDID,
    CAT.BUDGETYEAR                           AS BUDGETYEAR,
    BRS.TRANSFERNO                           AS TRANSFERNO,
    BRS.RESERVATIONNAME                      AS RESERVATIONNAME,
    BRS.RESERVATIONTYPE                      AS RESERVATIONTYPE,
    BRS.BUDGETRESERVEDTYPE                   AS BUDGETRESERVEDTYPE,
    BRS.REASON                               AS REASON,
    BRS.CREATEON                             AS RESERVEDDATE,
    BRS.DEPARTMENTID                         AS DEPARTMENTID,
    DEPTV.NAME                               AS DEPARTMENTNAME,
    BRS.COSTCENTERID                         AS COSTCENTERID,
    COSTV.NAME                               AS COSTCENTERNAME,
    COSTV.REGIONID                           AS REGIONID,
    BRS.BUDGETRESERVEDREGION                 AS BUDGETRESERVEDREGION,

    -- ไม่มี item ในระดับหมวด
    CAST(NULL AS NUMBER)                     AS ITEMID,
    CAT.CATEGORYNAME                         AS DESCRIPTION,
    CAST(NULL AS VARCHAR2(240))              AS SUPPLIER,
    CAST(NULL AS VARCHAR2(50))               AS ITEMRESERVEDTYPE,
    CAST(NULL AS NUMBER)                     AS PRAMOUNT,
    CAST(NULL AS NUMBER)                     AS POAMOUNT,

    -- ยอดกันเงินก้อนแรกของหมวด
    CAT.TOTALRESERVEDAMOUNT                  AS TOTALBALANCEAMOUNT,

    CAST(NULL AS VARCHAR2(4000))             AS ITEMREASON,
    BRS.STATUSID                             AS STATUSID,
    CASE
        WHEN BRS.ROUNDINTERFACE = 1 THEN 'กันเงิน'
        WHEN BRS.ROUNDINTERFACE > 1 THEN 'ขยายระยะเวลา'
        ELSE 'ร่าง'
    END                                      AS STATUSNAME,
    BRS.CREATEON                             AS RESERVEDITEMDATE,
    TO_CHAR(BRS.CREATEON,'MM')               AS RESERVEDMONTH,
    CAST(NULL AS VARCHAR2(240))              AS PO_CONTRACT,
    CAST(NULL AS VARCHAR2(240))              AS PO_CONTRACT_DATE,
    CAST(NULL AS VARCHAR2(240))              AS PO_CONTRACT_START_DATE,
    CAST(NULL AS VARCHAR2(240))              AS PO_CONTRACT_DUE_DATE,
    CAST(NULL AS VARCHAR2(20))               AS BOOKNUMBER,
    CAST(NULL AS VARCHAR2(240))              AS COSTCENTERCODE,
    CAST(NULL AS VARCHAR2(337))              AS ACCOUNTCODE,
    BRS.BUDGETSOURCEID                       AS BUDGETSOURCEID,
    CAST(NULL AS VARCHAR2(1348))             AS BUDGETCODE,

    CAT.CATEGORYID                           AS CATEGORYID,
    CAT.CATEGORYNAME                         AS CATEGORYNAME,
    CAT.CATEGORY_CODE                        AS CATEGORY_CODE,
    CAT.TOTALRESERVEDAMOUNT                  AS TOTALRESERVEDAMOUNT,
    CAT.BUDGETPLANID                         AS BUDGETPLANID,
    CAT.PLAN_NAME                            AS PLAN_NAME,
    CAT.PRODUCTID                            AS PRODUCTID,
    CAT.PRODUCT_NAME                         AS PRODUCT_NAME,
    CAT.ACTIVITYID                           AS ACTIVITYID,
    CAT.ACTIVITY_NAME                        AS ACTIVITY_NAME,
    CAT.BUDGETCODEID                         AS BUDGETCODEID,

    -- ระดับหมวดไม่ผูกกับ PR/PO จึงระบุมีหนี้/ไม่มีหนี้ไม่ได้
    'ไม่ระบุ'                                AS RESERVEDTYPENAME,

    -- ผลพิจารณา : ส่วนกลางยึดสถานะของหัวกันเงิน
    CASE BRS.STATUSID
        WHEN 20202 THEN 'พิจารณาแล้ว'
        WHEN 90102 THEN 'ขยายเวลา'
        WHEN 90109 THEN 'ยกเลิก'
        WHEN 90110 THEN 'ยกเลิกการกันเงิน'
        WHEN 90101 THEN 'ปกติ'
        ELSE 'อื่น ๆ'
    END                                      AS RESERVEDSTATUSNAME,

    CAST(NULL AS VARCHAR2(240))              AS PR_STATUS,
    CAST(NULL AS VARCHAR2(240))              AS PO_STATUS
FROM       OAGWBG_V_BUDGETRESERVED          BRS
INNER JOIN (
    -- DISTINCT กันแถวซ้ำจากบั๊ก join BUDGETCODE_YEAR ใน view ต้นทาง
    SELECT DISTINCT
           BUDGETRESERVEDID, CATEGORYID, CATEGORYNAME, CATEGORY_CODE,
           BUDGETYEAR, TOTALRESERVEDAMOUNT, BUDGETPLANID, PLAN_NAME,
           PRODUCTID, PRODUCT_NAME, ACTIVITYID, ACTIVITY_NAME, BUDGETCODEID
    FROM   OAGWBG_V_BUDGETRESERVED_CATEGORY
)                                            CAT ON BRS.ID = CAT.BUDGETRESERVEDID
LEFT JOIN  OAGWBG_V_EXT_OAGGL_DEPARTMENT_V   DEPTV ON BRS.DEPARTMENTID = DEPTV.ID
LEFT JOIN  OAGWBG_V_EXT_OAGGL_COST_CENTER_V  COSTV ON BRS.COSTCENTERID = COSTV.ID
WHERE      BRS.BUDGETRESERVEDREGION = 'C'

UNION ALL

--==============================================================================
-- 2) ภูมิภาค : ระดับรายการ เฉพาะรายการที่กันเงินแล้ว
--==============================================================================
SELECT
    BRS.ID                                   AS BUDGETRESERVEDID,
    COALESCE(BRSI.BUDGETYEAR, BRS.BUDGETYEAR) AS BUDGETYEAR,
    BRS.TRANSFERNO                           AS TRANSFERNO,
    BRS.RESERVATIONNAME                      AS RESERVATIONNAME,
    BRS.RESERVATIONTYPE                      AS RESERVATIONTYPE,
    BRS.BUDGETRESERVEDTYPE                   AS BUDGETRESERVEDTYPE,
    BRS.REASON                               AS REASON,
    BRS.CREATEON                             AS RESERVEDDATE,
    BRS.DEPARTMENTID                         AS DEPARTMENTID,
    DEPTV.NAME                               AS DEPARTMENTNAME,
    BRS.COSTCENTERID                         AS COSTCENTERID,
    COSTV.NAME                               AS COSTCENTERNAME,
    COSTV.REGIONID                           AS REGIONID,
    BRS.BUDGETRESERVEDREGION                 AS BUDGETRESERVEDREGION,

    BRSI.ID                                  AS ITEMID,
    BRSI.DESCRIPTION                         AS DESCRIPTION,
    BRSI.SUPPLIER                            AS SUPPLIER,
    BRSI.BUDGETRESERVEDTYPE                  AS ITEMRESERVEDTYPE,
    BRSI.TOTALHASPRAMOUNT                    AS PRAMOUNT,
    BRSI.TOTALHASPOAMOUNT                    AS POAMOUNT,
    BRSI.TOTALBALANCEAMOUNT                  AS TOTALBALANCEAMOUNT,
    BRSI.REASON                              AS ITEMREASON,
    BRSI.STATUSID                            AS STATUSID,
    CASE
        WHEN BRS.ROUNDINTERFACE = 1 THEN 'กันเงิน'
        WHEN BRS.ROUNDINTERFACE > 1 THEN 'ขยายระยะเวลา'
        ELSE 'ร่าง'
    END                                      AS STATUSNAME,
    BRSI.CREATEON                            AS RESERVEDITEMDATE,
    TO_CHAR(BRSI.CREATEON,'MM')              AS RESERVEDMONTH,
    BRSI.PO_CONTRACT                         AS PO_CONTRACT,
    BRSI.CONTRACT_CARRY_FORWARD_PO           AS PO_CONTRACT_DATE,
    BRSI.PO_CONTRACT_START_DATE              AS PO_CONTRACT_START_DATE,
    BRSI.PO_CONTRACT_DUE_DATE                AS PO_CONTRACT_DUE_DATE,
    BRSI.BOOKNUMBER                          AS BOOKNUMBER,
    BRSI.COSTCENTERCODE                      AS COSTCENTERCODE,
    BRSI.ACCOUNTCODE                         AS ACCOUNTCODE,
    CASE
        WHEN BRS.BUDGETRESERVEDREGION = 'P' AND BRSI.ACCOUNTCODE IS NOT NULL
             THEN REGEXP_SUBSTR(BRSI.ACCOUNTCODE, '[^.]+', 1, 4)
        ELSE BRS.BUDGETSOURCEID
    END                                      AS BUDGETSOURCEID,
    REGEXP_SUBSTR(BRSI.ACCOUNTCODE, '[^.]+', 1, 9) AS BUDGETCODE,

    CAST(NULL AS NUMBER)                     AS CATEGORYID,
    CAST(NULL AS VARCHAR2(240))              AS CATEGORYNAME,
    CAST(NULL AS VARCHAR2(240))              AS CATEGORY_CODE,
    CAST(NULL AS NUMBER)                     AS TOTALRESERVEDAMOUNT,
    CAST(NULL AS VARCHAR2(240))              AS BUDGETPLANID,
    CAST(NULL AS VARCHAR2(240))              AS PLAN_NAME,
    CAST(NULL AS VARCHAR2(240))              AS PRODUCTID,
    CAST(NULL AS VARCHAR2(240))              AS PRODUCT_NAME,
    CAST(NULL AS VARCHAR2(240))              AS ACTIVITYID,
    CAST(NULL AS VARCHAR2(240))              AS ACTIVITY_NAME,
    CAST(NULL AS VARCHAR2(240))              AS BUDGETCODEID,

    CASE
        WHEN BRSI.BUDGETRESERVEDTYPE = 'O' THEN 'มีหนี้'
        WHEN BRSI.BUDGETRESERVEDTYPE = 'R' THEN 'ไม่มีหนี้'
        ELSE 'ไม่ระบุ'
    END                                      AS RESERVEDTYPENAME,

    -- ผลพิจารณา : ภูมิภาคยึดสถานะของรายการ
    CASE BRSI.STATUSID
        WHEN 20202 THEN 'พิจารณาแล้ว'
        WHEN 90102 THEN 'ขยายเวลา'
        WHEN 90109 THEN 'ยกเลิก'
        WHEN 90110 THEN 'ยกเลิกการกันเงิน'
        WHEN 90101 THEN 'ปกติ'
        ELSE 'อื่น ๆ'
    END                                      AS RESERVEDSTATUSNAME,

    TSV.PR_STATUS                            AS PR_STATUS,
    TSV.PO_STATUS                            AS PO_STATUS
FROM       OAGWBG_V_BUDGETRESERVED          BRS
INNER JOIN (
    -- แทน OAGWBG_V_BUDGETRESERVEDITEM : อ่านตารางจริง แล้วคำนวณ
    -- CONTRACT_CARRY_FORWARD_PO เองด้วย logic เดิมทุกตัวอักษร (อ้าง TSV_RAW แทน EBS view)
    SELECT BR.ID,
           BR.BUDGETREVERSEDID,
           BR.BUDGETYEAR,
           BR.DESCRIPTION,
           BR.SUPPLIER,
           BR.BUDGETRESERVEDTYPE,
           BR.TOTALHASPRAMOUNT,
           BR.TOTALHASPOAMOUNT,
           BR.TOTALBALANCEAMOUNT,
           BR.REASON,
           BR.STATUSID,
           BR.CREATEON,
           BR.PO_CONTRACT,
           BR.PO_CONTRACT_START_DATE,
           BR.PO_CONTRACT_DUE_DATE,
           BR.BOOKNUMBER,
           BR.COSTCENTERCODE,
           BR.ACCOUNTCODE,
           CFPO.PO_CONTRACT_DATE            AS CONTRACT_CARRY_FORWARD_PO
    FROM       OAGWBG_BUDGETRESERVEDITEM BR
    LEFT JOIN  OAGWBG_BUDGETRESERVEDITEM BR1 ON BR.PARENTID = BR1.ID
    LEFT JOIN  TSV_RAW CFPO
           ON (
                CFPO.PR_BUDGET_ACCOUNT = BR.ACCOUNTCODE
                OR (
                    CFPO.PO_BUDGET_ACCOUNT = BR.ACCOUNTCODE
                    AND NOT EXISTS (
                        SELECT 1
                        FROM   TSV_RAW X
                        WHERE  X.PO_NUMBER  = BR.BOOKNUMBER
                          AND  X.PO_LINE_ID = COALESCE(BR.LINEID, BR1.LINEID)
                          AND  X.PR_BUDGET_ACCOUNT = BR.ACCOUNTCODE
                    )
                )
              )
          AND CFPO.PO_NUMBER  = BR.BOOKNUMBER
          AND CFPO.PO_LINE_ID = COALESCE(BR.LINEID, BR1.LINEID)
)                                            BRSI  ON BRS.ID = BRSI.BUDGETREVERSEDID
LEFT JOIN  OAGWBG_V_EXT_OAGGL_DEPARTMENT_V  DEPTV ON BRS.DEPARTMENTID = DEPTV.ID
LEFT JOIN  OAGWBG_V_EXT_OAGGL_COST_CENTER_V COSTV ON BRS.COSTCENTERID = COSTV.ID
LEFT JOIN (
    SELECT PR_BUDGET_ACCOUNT, PO_BUDGET_ACCOUNT,
           MAX(PR_STATUS) AS PR_STATUS,
           MAX(PO_STATUS) AS PO_STATUS
    FROM   TSV_RAW
    GROUP BY PR_BUDGET_ACCOUNT, PO_BUDGET_ACCOUNT
)                                            TSV ON BRSI.ACCOUNTCODE = TSV.PR_BUDGET_ACCOUNT
                                                AND BRSI.ACCOUNTCODE = TSV.PO_BUDGET_ACCOUNT
WHERE      BRS.BUDGETRESERVEDREGION <> 'C'
       AND BRSI.BUDGETRESERVEDTYPE IN ('O','R')
