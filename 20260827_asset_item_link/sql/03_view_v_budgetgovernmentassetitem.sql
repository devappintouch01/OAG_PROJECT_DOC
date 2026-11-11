-- =============================================================================
-- 03_view_v_budgetgovernmentassetitem.sql
-- แก้ view ให้คาย BUDGETGOVERNMENTITEMID ออกมาด้วย
--
-- ที่มา: DBMS_METADATA.GET_DDL ของ PREPROD 2026-08-27 (คงของเดิมทุกบรรทัด
--        เพิ่มเฉพาะคอลัมน์ใหม่ "ต่อท้าย" เพื่อไม่ให้ลำดับคอลัมน์เดิมขยับ)
--
-- ผู้ใช้ view นี้: EF (OagwbgVBudgetgovernmentassetitem),
--                  OAGWBG_R_BUDGETREQUEST_ASSET, OAGWBG_R_BUDGETREQUEST_ASSET_MORE
-- =============================================================================

CREATE OR REPLACE FORCE EDITIONABLE VIEW OAGWBG.OAGWBG_V_BUDGETGOVERNMENTASSETITEM
(
    "ID", "ASSET_ID", "ASSET_NUMBER", "ASSET_NAME", "BUDGETGOVERNMENTID",
    "ASSETTYPE_ID", "ASSETTYPE_NAME", "ASSETTYPESUB_ID", "ASSETTYPESUB_NAME",
    "ASSETCLASS_ID", "ASSETCLASS_NAME", "DEPARTMENT_ID", "DEPARTMENT_NAME",
    "COSTCENTER_ID", "COSTCENTER_NAME", "BUDGETYEAR",
    "BUDGETGOVERNMENTITEMID"          -- << เพิ่มใหม่
) AS
SELECT
    ga.ID,
    CASE
        WHEN ea.ASSET_ID IS NOT NULL THEN ea.ASSET_ID
        ELSE ga.ASSETID
    END AS ASSET_ID,
    TRIM(NVL(ea.ASSET_NUMBER, ga.ASSETNUMBER)) AS ASSET_NUMBER,
    TRIM(NVL(ea.DESCRIPTION,  ga.ASSETNAME))   AS ASSET_NAME,

    ga.BUDGETGOVERNMENTID,

    ea.CATEGORY_SEGMENT1             AS ASSETTYPE_ID,
    ea.CATEGORY_SEGMENT1_DESCRIPTION AS ASSETTYPE_NAME,

    ea.CATEGORY_SEGMENT2             AS ASSETTYPESUB_ID,
    ea.CATEGORY_SEGMENT2_DESCRIPTION AS ASSETTYPESUB_NAME,

    ea.CATEGORY_SEGMENT3             AS ASSETCLASS_ID,
    ea.CATEGORY_SEGMENT3_DESCRIPTION AS ASSETCLASS_NAME,

    ea.EXPENSE_SEGMENT1              AS DEPARTMENT_ID,
    ea.EXPENSE_SEGMENT1_DESCRIPTION  AS DEPARTMENT_NAME,

    ea.EXPENSE_SEGMENT2              AS COSTCENTER_ID,
    ea.EXPENSE_SEGMENT2_DESCRIPTION  AS COSTCENTER_NAME,

    ga.BUDGETYEAR,

    ga.BUDGETGOVERNMENTITEMID        -- << เพิ่มใหม่

FROM OAGWBG.OAGWBG_BUDGETGOVERNMENTASSETITEM ga
LEFT JOIN APPS.OAGFA_ASSET_V ea
    ON ea.ASSET_ID = ga.ASSETID;


-- ---------------------------------------------------------------------------
-- VERIFY
-- ---------------------------------------------------------------------------
SELECT status, object_name FROM user_objects
WHERE  object_name IN ('OAGWBG_V_BUDGETGOVERNMENTASSETITEM',
                       'OAGWBG_R_BUDGETREQUEST_ASSET',
                       'OAGWBG_R_BUDGETREQUEST_ASSET_MORE');
-- ทั้ง 3 ตัวต้อง VALID (view รายงานสองตัว depend อยู่ ถ้า INVALID ให้ recompile)

SELECT * FROM OAGWBG.OAGWBG_V_BUDGETGOVERNMENTASSETITEM WHERE ROWNUM <= 5;
