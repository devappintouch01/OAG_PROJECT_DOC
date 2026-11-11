--------------------------------------------------------------------------------
-- ตรวจว่า fallback (BG4P) ที่เพิ่มเข้า view เป็นการ "กู้คืน" หรือ "บวกเพิ่ม"
-- READ-ONLY ล้วน · ทดสอบรันบน PREPROD แล้ว (syntax ผ่าน, CTE นับกลุ่มถูก)
--
-- เทียบยอดที่ "ระดับกลุ่ม" (เท่ากับ 1 บรรทัดบนหน้าจอ) ไม่ใช่ระดับแถว
--   SUM_OLD = ผลรวมค่าของตัวเองในกลุ่ม        (สภาพก่อน view fix)
--   SUM_NEW = ผลรวมหลังใส่ fallback           (สภาพปัจจุบันบน PROD)
--
-- อ่านผล :
--   B) กลุ่มว่างเปล่า -> fallback กู้คืนจริง   ✅ view fix ถูกต้อง เก็บไว้
--   A) กลุ่มมีค่าอยู่แล้ว -> fallback บวกเพิ่ม ⚠️ ยอดบนจอเกินจริงเท่ากับคอลัมน์สุดท้าย
--
-- ถ้า A) มียอดมาก = ต้อง rollback view fix หรือเพิ่ม guard ระดับกลุ่ม
--------------------------------------------------------------------------------

WITH OWN4 AS (
  SELECT REF_BUDGETGOVERNMENTID REF, SUM(KEPTCENTRAL) K
  FROM OAGWBG_BUDGETGOVERNMENT WHERE BUDGETGOVERNMENTTYPE='4'
  GROUP BY REF_BUDGETGOVERNMENTID
),
P4 AS (
  SELECT PBG.BUDGETREQUESTID PR, PBG.RUNNING RN, SUM(B4P.KEPTCENTRAL) K
  FROM OAGWBG_BUDGETGOVERNMENT PBG
  JOIN OAGWBG_BUDGETGOVERNMENT B4P
       ON B4P.REF_BUDGETGOVERNMENTID = PBG.ID AND B4P.BUDGETGOVERNMENTTYPE='4'
  WHERE PBG.RUNNING IS NOT NULL
  GROUP BY PBG.BUDGETREQUESTID, PBG.RUNNING HAVING COUNT(*)=1
),
ROWS_ AS (
  SELECT BR.BUDGETYEAR, BG.BUDGETFORMTYPEID,
         CASE WHEN NVL(BG.DUMMY_CATEGORY,0)<>0 THEN BG.DUMMY_CATEGORY ELSE BG.CATEGORYID END CAT,
         BG.PRODUCTID, BG.ACTIVITYCODEID, BG.PROJECTID, BG.BUDGETPLANID,
         NVL(O.K,0) OWN_K,
         NVL(COALESCE(O.K, P4.K),0) NEW_K
  FROM OAGWBG_BUDGETREQUEST BR
  JOIN OAGWBG_BUDGETGOVERNMENT BG ON BG.BUDGETREQUESTID = BR.ID
       AND BG.BUDGETFORMTYPEID IN (1,2) AND BG.ID IS NOT NULL
       AND (BG.BUDGETGOVERNMENTTYPE IS NULL OR BG.BUDGETGOVERNMENTTYPE='7')
       AND BG.BUDGETSTATUS NOT IN ('A','X')
  LEFT JOIN OWN4 O ON O.REF = BG.ID
  LEFT JOIN P4      ON P4.PR = BR.PARENTID AND P4.RN = BG.RUNNING
  WHERE BR.BUDGETTYPEID = 1
  AND NOT EXISTS (SELECT 1 FROM OAGWBG_BUDGETREQUEST B2
                  WHERE B2.PARENTID IS NOT NULL AND B2.PARENTID = BG.BUDGETREQUESTID)
  AND (BG.PROJECTID IS NULL OR NOT EXISTS (
       SELECT 1 FROM OAGWBG_PROJECT WHERE TEMP IS NOT NULL AND TEMP = BG.PROJECTID))
),
GRP AS (
  SELECT BUDGETYEAR, BUDGETFORMTYPEID, CAT, PRODUCTID, ACTIVITYCODEID, PROJECTID, BUDGETPLANID,
         SUM(OWN_K) SUM_OLD, SUM(NEW_K) SUM_NEW
  FROM ROWS_
  GROUP BY BUDGETYEAR, BUDGETFORMTYPEID, CAT, PRODUCTID, ACTIVITYCODEID, PROJECTID, BUDGETPLANID
)
SELECT BUDGETYEAR,
       CASE WHEN SUM_OLD <> 0 THEN 'A) กลุ่มมีค่าอยู่แล้ว -> fallback บวกเพิ่ม'
            ELSE 'B) กลุ่มว่างเปล่า -> fallback กู้คืนจริง' END AS ผล,
       COUNT(*) จำนวนกลุ่ม,
       SUM(SUM_NEW - SUM_OLD) ยอดที่_fallback_เติมเข้าไป
FROM GRP
WHERE SUM_NEW <> SUM_OLD
GROUP BY BUDGETYEAR,
       CASE WHEN SUM_OLD <> 0 THEN 'A) กลุ่มมีค่าอยู่แล้ว -> fallback บวกเพิ่ม'
            ELSE 'B) กลุ่มว่างเปล่า -> fallback กู้คืนจริง' END
ORDER BY 1,2
;
