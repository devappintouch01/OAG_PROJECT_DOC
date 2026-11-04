--------------------------------------------------------------------------------
-- OAGWBG_R_BUDGETOVERLAP_RESERVED  (v2 — perf fix 2026-08-27)
--------------------------------------------------------------------------------
-- ใช้สำหรับ : รายงานรายละเอียดเงินกัน (ReportBudgetOverlap Template "4")
--
-- ปัญหาเดิม : 15.7 วิ (หลังแก้ V_BUDGETRESERVEDITEM แล้วเหลือ 13.9 วิ)
--   ทั้งที่ view นี้ไม่ได้อ้าง EBS โดยตรงเลย — ต้นทุนมาจาก
--   OAGWBG_V_BUDGETRESERVEDITEM ที่ลากงานที่ view นี้ไม่ได้ใช้เข้ามาทั้งก้อน
--
-- สิ่งที่เปลี่ยน :
--   1) เพิ่ม CTE `TSV_RAW` ครอบ APPS.OAGPO_TRANSACTION_STATUS_V
--   2) inline logic ของ OAGWBG_V_BUDGETRESERVEDITEM เข้ามา เอาเฉพาะที่ใช้จริง :
--      - ovbr / ovbo  → ต้องใช้ (PR_TRANSFER_NO / PO_TRANSFER_NO อยู่ใน WHERE)
--      - MASTERSTATUS → ต้องใช้ (BRSI.STATUSNAME ถูกใช้จริงใน SELECT)
--      - CFPO (join OR + NOT EXISTS ที่แพงที่สุด) → **ตัดทิ้งได้**
--        เพราะ view นี้ไม่ได้ใช้ CONTRACT_CARRY_FORWARD_PO เลย (grep = 0)
--      - BANKACCOUNT / V_BUDGETRESERVED (BS) → ตัดทิ้ง ไม่ได้ใช้
--
--   ⚠️ SELECT list / WHERE / join condition คงไว้เหมือนเดิมทุกตัวอักษร
--
-- rollback : rollback_view_budgetoverlap_reserved.sql
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW OAGWBG_R_BUDGETOVERLAP_RESERVED AS
WITH TSV_RAW AS (
    SELECT /*+ MATERIALIZE */
           PR_NUMBER, PR_TRANSFER_NO, PR_BUDGET_ACCOUNT,
           PO_NUMBER, PO_TRANSFER_NO, PO_BUDGET_ACCOUNT
    FROM   APPS.OAGPO_TRANSACTION_STATUS_V
)
SELECT
    -- ===== ระดับหัวกันเงิน (group) =====
    BRS.ID                                   AS BUDGETRESERVEDID,
    BRSI.BUDGETYEAR                           AS BUDGETYEAR,
    BRS.TRANSFERNO                           AS TRANSFERNO,            -- เลขที่กันเงิน (หัวกลุ่มรายงาน)
    BRS.RESERVATIONNAME                      AS RESERVATIONNAME,
    BRS.RESERVATIONTYPE                      AS RESERVATIONTYPE,
    BRS.BUDGETRESERVEDREGION                 AS BUDGETRESERVEDREGION,

    -- ===== เลขที่โอนจัดสรร (?? ดูข้อ 7.1) =====
    COALESCE(BRSI.PO_TRANSFER_NO, BRSI.PR_TRANSFER_NO, BRSI.TRANSFERNO) AS ALLOCATE_TRANSFERNO,

    -- ===== พื้นที่ภาค / สำนักงาน (จากศูนย์ต้นทุน) =====
    COSTV.REGIONID                           AS REGIONID,
    COSTV.REGIONNAME                         AS REGIONNAME,            -- พื้นที่ ภาค
    BRS.COSTCENTERID                         AS COSTCENTERID,
    COSTV.NAME                               AS COSTCENTERNAME,        -- สำนักงาน
    BRS.DEPARTMENTID                         AS DEPARTMENTID,
    DEPTV.NAME                               AS DEPARTMENTNAME,

    -- ===== รายการ (หมวด) =====
    CAT.CATEGORYID                           AS CATEGORYID,
    CAT.CATEGORYNAME                         AS CATEGORYNAME,          -- รายการ (ตาม prompt)
    CAT.CATEGORY_CODE                        AS CATEGORY_CODE,
    CAT.TOTALRESERVEDAMOUNT                  AS TOTALRESERVEDAMOUNT,   -- ยอดกันเงินรวมของหมวด

    -- ===== ระดับรายการ (item) =====
    BRSI.ID                                  AS ITEMID,
    BRSI.DESCRIPTION                         AS DESCRIPTION,           -- ชื่อรายการระดับ item (ที่ PDF โชว์ในบรรทัดย่อย)
    BRSI.SUPPLIER                            AS SUPPLIER,
    BRSI.BOOKNUMBER                          AS BOOKNUMBER,            -- เลขที่เอกสาร
    BRSI.ACCOUNTCODE                         AS ACCOUNTCODE,
    BRSI.BUDGETRESERVEDTYPE                  AS ITEMRESERVEDTYPE,      -- O/R/EXPAND_*/CANCEL_*
    BRSI.TOTALBALANCEAMOUNT                  AS TOTALBALANCEAMOUNT,    -- จำนวนเงินจัดสรร
    BRSI.USAGEAMOUNT                         AS USAGEAMOUNT,           -- ยอดที่ใช้ (raw)
    BRSI.RESERVEDNO_ADD                      AS RESERVEDNO_ADD,        -- เลขที่เงินกันเพิ่ม .n
    BRSI.NOTE                                AS NOTE,                  -- หมายเหตุ
    BRSI.OVERLAPYEAR                         AS OVERLAPYEAR,
    BRSI.OVERLAPROUND                        AS OVERLAPROUND,
    BRSI.CREATEON                            AS RESERVEDITEMDATE,

    -- ===== pivot ยอดตามประเภท (คอลัมน์รายงานตรง ๆ) =====
    CASE WHEN BRSI.BUDGETRESERVEDTYPE = 'EXPAND_PO' THEN BRSI.USAGEAMOUNT END AS APPROVE_EXPAND_HASOBLIGATION,  -- อนุมัติขยาย: มีหนี้
    CASE WHEN BRSI.BUDGETRESERVEDTYPE = 'EXPAND_PR' THEN BRSI.USAGEAMOUNT END AS APPROVE_EXPAND_NOOBLIGATION,   -- อนุมัติขยาย: ไม่มีหนี้
    CASE WHEN BRSI.BUDGETRESERVEDTYPE = 'CANCEL_PO' THEN BRSI.USAGEAMOUNT END AS PROCESS_HASOBLIGATION,         -- ดำเนินการ: มีหนี้
    CASE WHEN BRSI.BUDGETRESERVEDTYPE = 'CANCEL_PR' THEN BRSI.USAGEAMOUNT END AS PROCESS_NOOBLIGATION,          -- ดำเนินการ: ไม่มีหนี้

    -- ===== แปลประเภท / สถานะ (สไตล์เดียวกับวิวเดิม) =====
    CASE
        WHEN BRSI.BUDGETRESERVEDTYPE IN ('O','EXPAND_PO','CANCEL_PO') THEN 'มีหนี้'
        WHEN BRSI.BUDGETRESERVEDTYPE IN ('R','EXPAND_PR','CANCEL_PR') THEN 'ไม่มีหนี้'
        ELSE 'ไม่ระบุ'
    END                                      AS RESERVEDTYPENAME,
    CASE WHEN BRS.BUDGETRESERVEDREGION = 'C' THEN BRS.STATUSID   ELSE BRSI.STATUSID   END AS STATUSID,
    CASE WHEN BRS.BUDGETRESERVEDREGION = 'C' THEN BRS.STATUSNAME ELSE BRSI.STATUSNAME END AS STATUSNAME
FROM       OAGWBG_V_BUDGETRESERVED           BRS
LEFT JOIN (
    -- แทน OAGWBG_V_BUDGETRESERVEDITEM : เอาเฉพาะ join ที่ view นี้ใช้จริง
    -- (ตัด CFPO / BANKACCOUNT / BS ทิ้ง — ไม่ได้ใช้)
    SELECT BR0.ID,
           BR0.BUDGETREVERSEDID,
           BR0.BUDGETYEAR,
           BR0.DESCRIPTION,
           BR0.SUPPLIER,
           BR0.BUDGETRESERVEDTYPE,
           BR0.TOTALBALANCEAMOUNT,
           BR0.STATUSID,
           CASE
               WHEN MS.NAME LIKE '%บันทึก%' THEN 'ส่งเรื่องให้พิจารณา'
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
LEFT JOIN  OAGWBG_V_BUDGETRESERVED_CATEGORY  CAT   ON BRS.ID = CAT.BUDGETRESERVEDID   -- ?? ดูข้อ 7.2 (1 หมวด/หัว)
LEFT JOIN  OAGWBG_V_EXT_OAGGL_DEPARTMENT_V   DEPTV ON BRS.DEPARTMENTID = DEPTV.ID
LEFT JOIN  OAGWBG_V_EXT_OAGGL_COST_CENTER_V  COSTV ON BRS.COSTCENTERID = COSTV.ID
WHERE  BRSI.BUDGETRESERVEDTYPE IN ('EXPAND_PO','EXPAND_PR','CANCEL_PO','CANCEL_PR')  

