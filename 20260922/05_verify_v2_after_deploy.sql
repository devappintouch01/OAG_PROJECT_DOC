--------------------------------------------------------------------------------
-- ตรวจหลัง deploy v2  (READ-ONLY ล้วน)
-- เทียบกับค่าที่ preflight ทำนายไว้ ถ้าไม่ตรง → rollback ด้วย DDL ที่เก็บไว้
--------------------------------------------------------------------------------

-- ════════════════════════════════════════════════════════════════════
-- [V1] ★ GATE : view ต้อง VALID
-- ════════════════════════════════════════════════════════════════════
SELECT OBJECT_NAME, STATUS, TO_CHAR(LAST_DDL_TIME,'YYYY-MM-DD HH24:MI:SS') LAST_DDL
FROM   ALL_OBJECTS
WHERE  OWNER = 'OAGWBG' AND OBJECT_NAME = 'OAGWBG_V_BUDGETREQUESTSUMMARY';


-- ════════════════════════════════════════════════════════════════════
-- [V2] ★ GATE : ยอดต้องตรงกับที่ preflight ทำนาย
--   2569  ROWS  9,693  HAS_KEPT 617  SUM 2,597,568,340.67
--   2570  ROWS 13,025  HAS_KEPT 528  SUM 5,610,630,765.16
--   2571  ROWS 11,979  HAS_KEPT   0  SUM 0
-- ════════════════════════════════════════════════════════════════════
SELECT BUDGETYEAR, COUNT(*) ROWS_, COUNT(TOTALKEPTCENTRAL) HAS_KEPT,
       SUM(NVL(TOTALKEPTCENTRAL,0)) SUM_KEPT,
       SUM(NVL(TOTALRECEIVEAMOUNT,0)) SUM_RECV
FROM   OAGWBG_V_BUDGETREQUESTSUMMARY
GROUP  BY BUDGETYEAR ORDER BY 1;


-- ════════════════════════════════════════════════════════════════════
-- [V3] ★ GATE : เคสที่ไล่กันมาทั้งสาย — CATEGORY_ID 2372 ปี 2570
--   ต้องได้ 59,010  (เดิม v1 ให้ 118,020 เพราะนับสองก้อน)
--   และต้องมี "แถวเดียว" ที่ TOTALKEPTCENTRAL ไม่เป็น NULL ในกลุ่มนั้น
-- ════════════════════════════════════════════════════════════════════
SELECT ID, REF_GOVERNMENTID, CATEGORY_ID, PRODUCTID, ACTIVITYCODEID, BUDGETPLANID,
       TOTALREQUESTAMOUNT, TOTALKEPTCENTRAL, TOTALRECEIVEAMOUNT
FROM   OAGWBG_V_BUDGETREQUESTSUMMARY
WHERE  BUDGETYEAR = 2570 AND CATEGORY_ID = 2372
ORDER  BY REF_GOVERNMENTID;

SELECT SUM(NVL(TOTALKEPTCENTRAL,0)) AS ต้องได้_59010
FROM   OAGWBG_V_BUDGETREQUESTSUMMARY
WHERE  BUDGETYEAR = 2570 AND CATEGORY_ID = 2372;


-- ════════════════════════════════════════════════════════════════════
-- [V4] ★ GATE : ต้องไม่มีกลุ่มไหนเหลือมากกว่า 1 ก้อนอีก
--   ใช้ key ตรงกับ GetGroupBudgetSummaryPlan ครบ 9 ช่อง
--   ก่อนแก้ได้ 5 กลุ่ม (CAT 2238/2372/2387/2396/2432) → หลังแก้ต้องได้ 0 แถว
-- ════════════════════════════════════════════════════════════════════
SELECT BUDGETYEAR, CATEGORY_ID, PRODUCTID, ACTIVITYCODEID, BUDGETPLANID, COUNT(*) N_ก้อน
FROM   OAGWBG_V_BUDGETREQUESTSUMMARY
WHERE  TOTALKEPTCENTRAL IS NOT NULL AND NVL(DUMMY_FLAG,'NO') <> 'YES'
GROUP  BY BUDGETYEAR, BUDGETFORMTYPEID, CATEGORY_ID, PRODUCTID, ACTIVITYCODEID,
          PROJECTID, BUDGETPLANID, EXPENSETYPEID, BUDGETEXPENSETYPEID
HAVING COUNT(*) > 1
ORDER  BY 1,2;


-- ════════════════════════════════════════════════════════════════════
-- [V5] ยอดที่กู้คืนได้ เทียบกับตาราง
--   ส่วนต่าง TABLE − VIEW ควรเหลือเฉพาะก้อนที่ถูกแทนที่/กู้ไม่ได้
-- ════════════════════════════════════════════════════════════════════
SELECT 'TABLE (type4)' SRC, BUDGETYEAR, SUM(NVL(KEPTCENTRAL,0)) S
FROM   OAGWBG_BUDGETGOVERNMENT WHERE BUDGETGOVERNMENTTYPE='4' GROUP BY BUDGETYEAR
UNION ALL
SELECT 'VIEW  (v2)', BUDGETYEAR, SUM(NVL(TOTALKEPTCENTRAL,0))
FROM   OAGWBG_V_BUDGETREQUESTSUMMARY GROUP BY BUDGETYEAR
ORDER  BY 2, 1;
