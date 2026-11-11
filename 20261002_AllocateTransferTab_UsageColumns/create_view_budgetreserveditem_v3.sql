--------------------------------------------------------------------------------
-- OAGWBG_V_BUDGETRESERVEDITEM  (v3 — fix row fan-out 2026-10-02)
--------------------------------------------------------------------------------
-- ปัญหา : 1 แถวของ OAGWBG_BUDGETRESERVEDITEM ออกมาหลายแถวที่เหมือนกันทุกคอลัมน์
--   ตัวอย่าง ID 196 (EXPAND_PO 26900775 ยอด 10,000) ออกมา 9 แถว
--   เพราะ APPS.OAGPO_TRANSACTION_STATUS_V มี PO นี้ 3 แถว (เช็ค 3648 +10,000 / 3648 -10,000 VOIDED
--   และเช็ค 3649 ที่ออกใหม่) แล้ว view join ซ้ำ 2 จุด (ovbo x CFPO) = 3 x 3 = 9
--   ⇒ แท็บ "รายการโอนจัดสรร" รวมยอด "รายการมีหนี้" ของเลขที่โอน 6912568 ได้ 98,000 แทน 8,000
--
-- สิ่งที่เปลี่ยน : ใส่ DISTINCT ใน 3 subquery ที่อ่าน TSV_RAW (ovbr / ovbo / CFPO)
--   และเลือกเฉพาะคอลัมน์ที่ใช้ join + คอลัมน์ที่ส่งออกจาก view
--   ⇒ ตัดเฉพาะแถวที่ซ้ำกันทุกค่า ถ้าเอกสารเดียวกันมีเลขที่โอน/วันที่สัญญาต่างกันจริง ยังออกหลายแถวเหมือนเดิม
--
--   ⚠️ SELECT list / เงื่อนไข join / NOT EXISTS คงเดิมทุกตัวอักษร
--      CTE TSV_RAW (perf fix v2) คงไว้เหมือนเดิม
--
-- ตรวจกับ PREPROD 2026-10-02 (ทดสอบเป็น inline query ยังไม่ได้ CREATE จริง):
--   v2 : 85 แถว / 77 ID      v3 : 77 แถว / 77 ID
--   ชุดแถว (distinct) ของ v2 กับ v3 เท่ากันทุกคอลัมน์ (MINUS ทั้งสองทางได้ 0 แถว)
--
-- ผู้ใช้งาน view นี้ : ไม่มี view/package อื่นอ้าง (ALL_DEPENDENCIES ว่าง)
--   ใช้จาก C# เท่านั้น — BudgetService.cs (GetBudgetOverlapYearCentralList และจุดอื่นที่อ่าน OagwbgVBudgetreserveditems)
--
-- rollback : rollback_view_budgetreserveditem_v3.sql
--------------------------------------------------------------------------------

CREATE OR REPLACE FORCE EDITIONABLE VIEW "OAGWBG"."OAGWBG_V_BUDGETRESERVEDITEM" ("ID", "CREATEBY", "CREATEON", "UPDATEBY", "UPDATEON", "BUDGETYEAR", "BUDGETREVERSEDID", "TOTALHASPOAMOUNT", "TOTALHASPRAMOUNT", "TOTALBALANCEAMOUNT", "BOOKNUMBER", "DESCRIPTION", "SUPPLIER", "COSTCENTERCODE", "HEADERID", "CATEGORYCODE", "ACCOUNTCODE", "STATUSID", "STATUSNAME", "REASON", "BANKACCOUNTGIVER", "BANKACCOUNTRECEIVER", "COSTCENTERID", "DEPARTMENTID", "BUDGETRESERVEDTYPE", "PARENTID", "TRANSFERNO", "PO_CONTRACT", "PO_CONTRACT_START_DATE", "PO_CONTRACT_DUE_DATE", "OVERLAPYEAR", "OVERLAPROUND", "APPROVE", "REMAININGREFUND", "LINEID", "NOTE", "USAGEAMOUNT", "PR_TRANSFER_NO", "PO_TRANSFER_NO", "CONTRACT_CARRY_FORWARD_PO", "RESERVEDNO_ADD") AS
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
-- v3: DISTINCT — 1 เอกสารมีหลายแถวใน EBS (ตามจำนวนใบรับของ/ใบแจ้งหนี้/เช็ค) ห้ามให้แตกแถว BR
LEFT JOIN (SELECT DISTINCT a.PR_NUMBER, a.PR_BUDGET_ACCOUNT, a.PR_TRANSFER_NO
             FROM TSV_RAW a WHERE a.PR_TRANSFER_NO IS NOT NULL) ovbr
		ON ovbr.PR_BUDGET_ACCOUNT = BR.ACCOUNTCODE AND BR.BOOKNUMBER = ovbr.PR_NUMBER
LEFT JOIN (SELECT DISTINCT b.PO_NUMBER, b.PO_BUDGET_ACCOUNT, b.PO_TRANSFER_NO
             FROM TSV_RAW b WHERE b.PO_TRANSFER_NO IS NOT NULL) ovbo
		ON ovbo.PO_BUDGET_ACCOUNT = BR.ACCOUNTCODE AND BR.BOOKNUMBER = ovbo.PO_NUMBER
LEFT JOIN (SELECT DISTINCT c.PR_BUDGET_ACCOUNT, c.PO_BUDGET_ACCOUNT, c.PO_NUMBER, c.PO_LINE_ID, c.PO_CONTRACT_DATE
             FROM TSV_RAW c) CFPO
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
AND CFPO.PO_LINE_ID = COALESCE(BR.LINEID, BR1.LINEID);
