CREATE OR REPLACE VIEW OAGWBG_R_BUDGETOVERLAP_RESERVED AS
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
LEFT JOIN  OAGWBG_V_BUDGETRESERVEDITEM       BRSI  ON BRS.ID = BRSI.BUDGETREVERSEDID AND (BRSI.PO_TRANSFER_NO IS NOT NULL OR BRSI.PR_TRANSFER_NO IS NOT NULL)
LEFT JOIN  OAGWBG_V_BUDGETRESERVED_CATEGORY  CAT   ON BRS.ID = CAT.BUDGETRESERVEDID   -- ?? ดูข้อ 7.2 (1 หมวด/หัว)
LEFT JOIN  OAGWBG_V_EXT_OAGGL_DEPARTMENT_V   DEPTV ON BRS.DEPARTMENTID = DEPTV.ID
LEFT JOIN  OAGWBG_V_EXT_OAGGL_COST_CENTER_V  COSTV ON BRS.COSTCENTERID = COSTV.ID
WHERE  BRSI.BUDGETRESERVEDTYPE IN ('EXPAND_PO','EXPAND_PR','CANCEL_PO','CANCEL_PR')  


/
