--------------------------------------------------------------------------------
-- STEP 3 : ตรวจหลัง deploy
-- READ-ONLY ล้วน
--
-- เทียบกับ baseline ที่เก็บไว้จาก 01_preflight_ALL.sql
--   [V2] ต้องตรงกับฝั่ง "NEW" ของ [P1a][P1b][P1c] ทุกบรรทัด
--   ถ้าไม่ตรง → rollback ด้วย 00_capture_rollback_from_PROD ที่เก็บไว้
--------------------------------------------------------------------------------


-- ════════════════════════════════════════════════════════════════════
-- [V1] ★ GATE : view ทั้ง 3 ตัวต้อง VALID
-- ════════════════════════════════════════════════════════════════════
SELECT OBJECT_NAME, OBJECT_TYPE, STATUS,
       TO_CHAR(LAST_DDL_TIME,'YYYY-MM-DD HH24:MI:SS') LAST_DDL
FROM   ALL_OBJECTS
WHERE  OWNER = 'OAGWBG'
AND    OBJECT_NAME IN ('OAGWBG_V_BUDGETREQUESTSUMMARY',
                       'OAGWBG_R_BUDGETREQUEST',
                       'OAGWBG_V_BUDGETREQUESTSUMMARYLIST')
ORDER  BY OBJECT_NAME;
-- STATUS ต้องเป็น VALID ทั้ง 3 แถว


-- ════════════════════════════════════════════════════════════════════
-- [V2] ยอดจริงจาก view หลังแก้ — ต้องตรงกับฝั่ง NEW ใน preflight
-- ════════════════════════════════════════════════════════════════════
SELECT 'V_BUDGETREQUESTSUMMARY' VIEW_, TO_CHAR(BUDGETYEAR) YR, NULL FORMTYPE,
       COUNT(*) ROWS_, COUNT(TOTALKEPTCENTRAL) HAS_KEPT, SUM(NVL(TOTALKEPTCENTRAL,0)) SUM_KEPT
FROM   OAGWBG_V_BUDGETREQUESTSUMMARY GROUP BY BUDGETYEAR
UNION ALL
SELECT 'R_BUDGETREQUEST', TO_CHAR(BUDGETYEAR), NULL,
       COUNT(*), COUNT(REQUESTAMOUNT_ADD), SUM(NVL(REQUESTAMOUNT_ADD,0))
FROM   OAGWBG_R_BUDGETREQUEST GROUP BY BUDGETYEAR
UNION ALL
SELECT 'V_BUDGETREQUESTSUMMARYLIST', TO_CHAR(BUDGETYEAR), TO_CHAR(BUDGETFORMTYPEID),
       1, 1, TOTALRECEIVEAMOUNT
FROM   OAGWBG_V_BUDGETREQUESTSUMMARYLIST
ORDER  BY 1, 2, 3;


-- ════════════════════════════════════════════════════════════════════
-- [V3] Spot check — เคสที่ไล่กันมาแล้วทั้งสาย
--      category 2372 ปี 2570 ต้องได้ยอดรวม 85,620
--      (−32,400 ของคำขอ 918 + 59,010 ของคำขอ 941 + 59,010 ที่กู้คืนให้คำขอ 1776)
-- ════════════════════════════════════════════════════════════════════
SELECT ID, REF_GOVERNMENTID, BUDGETYEAR, CATEGORY_ID,
       TOTALREQUESTAMOUNT, TOTALKEPTCENTRAL, TOTALRECEIVEAMOUNT
FROM   OAGWBG_V_BUDGETREQUESTSUMMARY
WHERE  BUDGETYEAR = 2570 AND CATEGORY_ID = 2372
ORDER  BY REF_GOVERNMENTID;

SELECT SUM(NVL(TOTALKEPTCENTRAL,0)) AS ต้องได้_85620
FROM   OAGWBG_V_BUDGETREQUESTSUMMARY
WHERE  BUDGETYEAR = 2570 AND CATEGORY_ID = 2372;


-- ════════════════════════════════════════════════════════════════════
-- [V4] คำขอ 1776 (ลูกของ 1073) — 19 แถว keptcentral ควรมีค่าแล้ว
-- ════════════════════════════════════════════════════════════════════
SELECT V.REF_GOVERNMENTID, V.ID AS KEPT_ROW_ID, V.CATEGORY_ID,
       V.TOTALREQUESTAMOUNT, V.TOTALKEPTCENTRAL
FROM   OAGWBG_V_BUDGETREQUESTSUMMARY V
WHERE  V.REF_GOVERNMENTID IN (SELECT ID FROM OAGWBG_BUDGETGOVERNMENT WHERE BUDGETREQUESTID = 1776)
ORDER  BY V.REF_GOVERNMENTID;


-- ════════════════════════════════════════════════════════════════════
-- [V5] ยอดที่กู้คืนได้จริง เทียบกับที่ preflight [P2] คาดไว้
--      ส่วนต่าง TABLE - VIEW ควรลดลงจาก 114,693,702 เหลือใกล้ 0
-- ════════════════════════════════════════════════════════════════════
SELECT 'TABLE (type4)' SRC, BUDGETYEAR, COUNT(*) CNT, SUM(NVL(KEPTCENTRAL,0)) SUM_KEPT
FROM   OAGWBG_BUDGETGOVERNMENT WHERE BUDGETGOVERNMENTTYPE = '4' GROUP BY BUDGETYEAR
UNION ALL
SELECT 'VIEW  (summary)', BUDGETYEAR, COUNT(TOTALKEPTCENTRAL), SUM(NVL(TOTALKEPTCENTRAL,0))
FROM   OAGWBG_V_BUDGETREQUESTSUMMARY GROUP BY BUDGETYEAR
ORDER  BY 2, 1;
