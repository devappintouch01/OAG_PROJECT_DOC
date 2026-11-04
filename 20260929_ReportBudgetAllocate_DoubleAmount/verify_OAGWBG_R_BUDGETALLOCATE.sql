-- ============================================================
-- verify: OAGWBG_R_BUDGETALLOCATE (แก้ยอดเบิ้ล) — SELECT ล้วน ไม่แก้ข้อมูล
-- แต่ละ statement คั่นด้วยบรรทัด "/"
-- ============================================================

-- ------------------------------------------------------------
-- [ก่อน deploy 1] ยอดที่ "ควรได้" หลังแก้ = view เดิมยุบ 1 แถวต่อคีย์
--   จดตัวเลขไว้เทียบกับ [หลัง deploy 3]
--   ค่าที่ได้เมื่อ 2026-09-29 (PREPROD):
--     2569 | 568 | 14,922,118,100    | 78,343,300 | 21,011,775,000
--     2570 | 632 | 15,402,043,842.6  | 0          | 17,851,153,920.44
--     2571 | 2   | 14,000,000        | 0          | 14,003,000
-- ------------------------------------------------------------
SELECT BUDGETYEAR, COUNT(*) AS KEY_ROWS, SUM(P) AS EXPECT_PROPOSE, SUM(A) AS EXPECT_AMEND, SUM(R) AS EXPECT_REQUEST
FROM (
  SELECT BUDGETYEAR, BUDGETPLANID, PRODUCTID, ACTIVITYID, CATEGORYID, CATEGORYNAME,
         MAX(PROPOSEAMOUNT) P, MAX(AMENDAMOUNT) A, MAX(REQUESTAMOUNT) R
  FROM OAGWBG_R_BUDGETALLOCATE
  GROUP BY BUDGETYEAR, BUDGETPLANID, PRODUCTID, ACTIVITYID, CATEGORYID, CATEGORYNAME
) GROUP BY BUDGETYEAR ORDER BY BUDGETYEAR
/
-- ------------------------------------------------------------
-- [ก่อน deploy 2] MAX() ใน GOV_NAME ปลอดภัยไหม
--   ต้องได้ 0 แถว = ทุกคีย์มีค่าที่ไม่ใช่ NULL ไม่เกิน 1 ค่า (ต่างกันแค่ 10 กับ NULL)
--   ถ้ามีแถว = คีย์นั้นมีประเภทรายจ่ายจริง 2 ค่า MAX จะหยิบตัวเดียว → ต้องคุยกันก่อน deploy
-- ------------------------------------------------------------
SELECT BUDGETYEAR, BUDGETPLANID, PRODUCTID, ACTIVITYCODEID, CATEGORYID,
       COUNT(DISTINCT EXPENSETYPEID)          AS N_EXPENSETYPEID,
       COUNT(DISTINCT BUDGET_EXPENSE_TYPE_ID) AS N_BUDGET_EXPENSE_TYPE_ID,
       COUNT(DISTINCT EXPENSETYPENAME)        AS N_EXPENSETYPENAME,
       COUNT(DISTINCT BUDGETEXPENSETYPENAME)  AS N_BUDGETEXPENSETYPENAME
FROM OAGWBG_V_BUDGETGOVERNMENT
GROUP BY BUDGETYEAR, BUDGETPLANID, PRODUCTID, ACTIVITYCODEID, CATEGORYID
HAVING COUNT(DISTINCT EXPENSETYPEID) > 1
    OR COUNT(DISTINCT BUDGET_EXPENSE_TYPE_ID) > 1
    OR COUNT(DISTINCT EXPENSETYPENAME) > 1
    OR COUNT(DISTINCT BUDGETEXPENSETYPENAME) > 1
/
-- ------------------------------------------------------------
-- [ก่อน deploy 3] DDL บน server ยังตรงกับ rollback_OAGWBG_R_BUDGETALLOCATE.sql ไหม
--   เอาผลไป diff กับไฟล์ rollback — ถ้าไม่ตรง = มีคนแก้ view ไปแล้ว ต้องอัปเดต rollback/deploy ก่อน
-- ------------------------------------------------------------
SELECT DBMS_METADATA.GET_DDL('VIEW','OAGWBG_R_BUDGETALLOCATE','OAGWBG') AS DDL FROM DUAL
/

-- ============================================================
-- หลัง deploy
-- ============================================================

-- [หลัง deploy 1] view ต้อง VALID
SELECT OBJECT_NAME, STATUS, LAST_DDL_TIME
FROM USER_OBJECTS
WHERE OBJECT_NAME = 'OAGWBG_R_BUDGETALLOCATE'
/
-- [หลัง deploy 2] ไม่มีคีย์ซ้ำ — ต้องได้ 0 แถว
SELECT BUDGETYEAR, BUDGETPLANID, PRODUCTID, ACTIVITYID, CATEGORYID, CATEGORYNAME, COUNT(*) CNT
FROM OAGWBG_R_BUDGETALLOCATE
GROUP BY BUDGETYEAR, BUDGETPLANID, PRODUCTID, ACTIVITYID, CATEGORYID, CATEGORYNAME
HAVING COUNT(*) > 1
/
-- [หลัง deploy 3] ยอดรวมต่อปี — ต้องตรงกับ [ก่อน deploy 1] ทุกคอลัมน์
SELECT BUDGETYEAR, COUNT(*) AS VIEW_ROWS, SUM(PROPOSEAMOUNT) AS PROPOSE, SUM(AMENDAMOUNT) AS AMEND, SUM(REQUESTAMOUNT) AS REQUEST
FROM OAGWBG_R_BUDGETALLOCATE
GROUP BY BUDGETYEAR ORDER BY BUDGETYEAR
/
-- [หลัง deploy 4] ตัวอย่างที่เคยเบิ้ล — หมวด 2159 ปี 2569 กิจกรรม 11100 ต้องเหลือ 1 แถว ยอดเสนอ 3,532,009,000, EXPENSETYPEID = 10
SELECT BUDGETYEAR, ACTIVITYID, CATEGORYID, CATEGORYNAME, EXPENSETYPEID, EXPENSETYPENAME, BUDGETEXPENSETYPEID, PROPOSEAMOUNT, AMENDAMOUNT, REQUESTAMOUNT
FROM OAGWBG_R_BUDGETALLOCATE
WHERE BUDGETYEAR = 2569 AND CATEGORYID = 2159 AND TO_CHAR(ACTIVITYID) = '11100'
/
-- [หลัง deploy 5] แถวที่ยังไม่มีประเภทรายจ่าย (ข้อมูล — ไม่ใช่ error)
--   รายงานเติม Expensetypename จาก OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V ให้อยู่แล้วถ้าว่าง (ReportService.ReportBudgetAllocate)
SELECT BUDGETYEAR, COUNT(*) AS ROWS_NO_EXPENSETYPE
FROM OAGWBG_R_BUDGETALLOCATE
WHERE EXPENSETYPEID IS NULL
GROUP BY BUDGETYEAR ORDER BY BUDGETYEAR
/
