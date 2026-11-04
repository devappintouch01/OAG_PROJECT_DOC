--------------------------------------------------------------------------------
-- OAGWBG_V_BUDGETRESERVEDITEM  (v2 — perf fix 2026-08-27)
--------------------------------------------------------------------------------
-- ปัญหาเดิม : COUNT(*) ใช้ 14.6 วินาที ทั้งที่ตารางต้นทางมีแค่ 60 แถว / 11 ms
--
-- สาเหตุ : view นี้อ้าง APPS.OAGPO_TRANSACTION_STATUS_V (EBS) ถึง 4 ครั้ง
--   1) ovbr  — subquery กรอง PR_TRANSFER_NO
--   2) ovbo  — subquery กรอง PO_TRANSFER_NO
--   3) CFPO  — join ตรง
--   4) X     — correlated NOT EXISTS ข้างใน CFPO
--   EBS view ตัวนี้ push predicate เข้าไปข้างในไม่ได้ (กรอง PO_NUMBER เดียวก็ยังใช้
--   9.2 วิ เท่ากับ scan ทั้ง 18,507 แถว) → 4 x ~10 วิ
--
-- สิ่งที่เปลี่ยน : เพิ่ม CTE `TSV_RAW` ครอบ APPS.OAGPO_TRANSACTION_STATUS_V
--   แล้วให้ทั้ง 4 จุดอ้าง CTE แทน Oracle จะ materialize ลง temp ครั้งเดียว
--   (CTE ที่ถูกอ้าง >= 2 ครั้ง Oracle ทำให้เองอยู่แล้ว ใส่ hint ไว้ให้ชัดเจน)
--   และยังทำหน้าที่เป็น optimizer barrier กัน view merging ระเบิดด้วย
--
--   ⚠️ SELECT list / join condition / logic ทั้งหมดคงไว้เหมือนเดิมทุกตัวอักษร
--      เปลี่ยนแค่ "แหล่งที่อ้าง" จาก EBS view → CTE เท่านั้น
--
-- ผู้ใช้งาน view นี้ (ตรวจจาก ALL_DEPENDENCIES + grep C#) :
--   - OAGWBG_R_BUDGETOVERLAP           (รายงาน Template 3)
--   - OAGWBG_R_BUDGETOVERLAP_RESERVED  (รายงาน Template 4)
--   - BudgetService.cs : 13760, 13988, 27502
--   (OAGWBG_R_BUDGETOVERLAP_CATEGORY และ _EXPAND เลิกใช้ไปแล้วตั้งแต่ 2026-08-27)
--
-- rollback : rollback_view_budgetreserveditem.sql
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW OAGWBG_V_BUDGETRESERVEDITEM AS
WITH TSV_RAW AS (
    -- materialize ครั้งเดียว แล้วให้ ovbr / ovbo / CFPO / X อ่านซ้ำจาก temp
    SELECT /*+ MATERIALIZE */
           PR_NUMBER, PR_TRANSFER_NO, PR_BUDGET_ACCOUNT,
           PO_NUMBER, PO_TRANSFER_NO, PO_BUDGET_ACCOUNT,
           PO_LINE_ID, PO_CONTRACT_DATE
    FROM   APPS.OAGPO_TRANSACTION_STATUS_V
)
SELECT
    BR."ID",
    BR."CREATEBY",
    BR."CREATEON",
    BR."UPDATEBY",
    BR."UPDATEON",
    BR."BUDGETYEAR",
    BR."BUDGETREVERSEDID",
    BR."TOTALHASPOAMOUNT",
    BR."TOTALHASPRAMOUNT",
    BR."TOTALBALANCEAMOUNT",
    BR."BOOKNUMBER",
    BR."DESCRIPTION",
    BR."SUPPLIER",
    BR."COSTCENTERCODE",
    BR."HEADERID",
    BR."CATEGORYCODE",
    BR."ACCOUNTCODE",
    BR."STATUSID",
    CASE
        WHEN MS.NAME LIKE '%บันทึก%' THEN 'ส่งเรื่องให้พิจารณา'
        ELSE MS.NAME
    END AS STATUSNAME,
    BR."REASON",
    BB."BANKACCOUNTGIVER",
    BB."BANKACCOUNTRECEIVER",
    BS.COSTCENTERID,
    BS.DEPARTMENTID,
    BR.BUDGETRESERVEDTYPE,
    BR.PARENTID,
    BR.TRANSFERNO,
    BR.PO_CONTRACT,
    BR.PO_CONTRACT_START_DATE,
    BR.PO_CONTRACT_DUE_DATE,
    BR.OVERLAPYEAR,
    BR.OVERLAPROUND,
    BR.APPROVE,
    BR.REMAININGREFUND,
   COALESCE(BR.LINEID,BR1.LINEID) AS LINEID,
    --BR.LINEID AS LINEID,
    BR.NOTE,
    BR.USAGEAMOUNT,
    ovbr.PR_TRANSFER_NO AS PR_TRANSFER_NO,
    ovbo.PO_TRANSFER_NO AS PO_TRANSFER_NO,
    CFPO.PO_CONTRACT_DATE AS CONTRACT_CARRY_FORWARD_PO,
    BR.RESERVEDNO_ADD
FROM OAGWBG_BUDGETRESERVEDITEM BR
LEFT JOIN OAGWBG_BUDGETRESERVEDITEM BR1
	ON BR.PARENTID = BR1.ID
LEFT JOIN OAGWBG_MASTERSTATUS MS
       ON MS."ID" = BR."STATUSID"
LEFT JOIN OAGWBG_BUDGETRESERVED_BANKACCOUNT BB
       ON BR."BUDGETBANKACCOUNTID" = BB."ID"
LEFT JOIN OAGWBG_V_BUDGETRESERVED BS 
        ON BR.BUDGETREVERSEDID = BS.ID
LEFT JOIN (SELECT * FROM TSV_RAW a WHERE a.PR_TRANSFER_NO IS NOT NULL) ovbr
		ON ovbr.PR_BUDGET_ACCOUNT = BR.ACCOUNTCODE AND BR.BOOKNUMBER = ovbr.PR_NUMBER 
LEFT JOIN (SELECT * FROM TSV_RAW b WHERE b.PO_TRANSFER_NO IS NOT NULL) ovbo
		ON ovbo.PO_BUDGET_ACCOUNT = BR.ACCOUNTCODE AND BR.BOOKNUMBER = ovbo.PO_NUMBER 
LEFT JOIN TSV_RAW CFPO
ON (
    CFPO.PR_BUDGET_ACCOUNT = BR.ACCOUNTCODE
    OR (
        CFPO.PO_BUDGET_ACCOUNT = BR.ACCOUNTCODE
        AND NOT EXISTS (
            SELECT 1
            FROM TSV_RAW X
            WHERE X.PO_NUMBER = BR.BOOKNUMBER
              AND X.PO_LINE_ID = COALESCE(BR.LINEID, BR1.LINEID)
              AND X.PR_BUDGET_ACCOUNT = BR.ACCOUNTCODE
        )
    )
)
AND CFPO.PO_NUMBER = BR.BOOKNUMBER
AND CFPO.PO_LINE_ID = COALESCE(BR.LINEID, BR1.LINEID)
