-- =====================================================================
-- find_plan_items_converted_to_project.sql   (2026-10-20, อ่านอย่างเดียว)
-- หาแถวคำขอแผนงาน (ฟอร์ม 1) ที่ถูกนำไปเป็นโครงการ (ฟอร์ม 2)
--
-- ไม่มี flag / log บอกตรง ๆ ใช้ 2 สัญญาณจากข้อมูล:
--   1) REF  : แถวงบประมาณของโครงการ (BUDGETFORMTYPEID = 2) ชี้ REF_BUDGETGOVERNMENTID มาที่แถวแผนงาน
--             — หน้าโครงการบังคับเลือก "รายการ" จากแถวแผนงาน ทุกโครงการจึงมี REF
--             — REF อาจชี้แถวในคำขอเวอร์ชันเก่า (ตอนสร้างเวอร์ชันใหม่ระบบ copy แถวเป็น ID ใหม่แต่ไม่แก้ REF)
--               จึงจับคู่ด้วย คำขอเดียวกันหรือคำขอแม่ + RUNNING เดียวกัน แบบ ResolveLatestRefBudgetGovernmentId
--   2) DUMMY_CATEGORY : แถวแผนงานถูกย้ายออกจากหมวดค่ากลาง (เก็บหมวดเดิมไว้) — มักย้ายไปหมวดเฉพาะโครงการ
--
-- เปลี่ยนปีที่ :Y (ค่าเริ่ม 2570)
-- =====================================================================

WITH P AS (   -- แถวแผนงานในคำขอเวอร์ชันล่าสุด
  SELECT g.ID, g.BUDGETYEAR, g.BUDGETREQUESTID, r.PARENTID REQ_PARENT, g.RUNNING, g.COSTCENTERID,
         g.CATEGORYID, g.DUMMY_CATEGORY, g.PRODUCTID, g.ACTIVITYCODEID, g.TOTALREQUESTAMOUNT, g.BUDGETSTATUS
  FROM OAGWBG_BUDGETGOVERNMENT g
  JOIN OAGWBG_BUDGETREQUEST r ON r.ID = g.BUDGETREQUESTID
  WHERE g.BUDGETYEAR = 2570
    AND g.BUDGETFORMTYPEID = 1
    AND (g.BUDGETGOVERNMENTTYPE IS NULL OR g.BUDGETGOVERNMENTTYPE = '7')
    AND NOT EXISTS (SELECT 1 FROM OAGWBG_BUDGETREQUEST c WHERE c.PARENTID = r.ID)
), PJ AS (    -- โครงการทุกตัว (ต้นฉบับ + สำเนา) กับแถวแผนงานที่ REF ชี้
  SELECT p.ID PROJECTID, p.TEMP, ref.ID REF_ID, ref.BUDGETREQUESTID REF_REQ, ref.RUNNING REF_RUNNING,
         (SELECT SUM(t.ALLOCATEDBUDGET) FROM OAGWBG_PROJECTTARGETS t WHERE t.PROJECTID = p.ID) TARGET_AMT
  FROM OAGWBG_PROJECT p
  JOIN OAGWBG_BUDGETGOVERNMENT bg ON bg.ID = p.BUDGETGOVERNMENTID AND bg.BUDGETFORMTYPEID = 2
  JOIN OAGWBG_BUDGETGOVERNMENT ref ON ref.ID = bg.REF_BUDGETGOVERNMENTID
  WHERE p.BUDGETYEAR = 2570
)
SELECT P.ID PLAN_ROW_ID, P.BUDGETREQUESTID, P.COSTCENTERID, P.RUNNING,
       P.CATEGORYID, cc.NAME CATEGORY_NAME, P.DUMMY_CATEGORY MOVED_FROM_DUMMY, dcc.NAME DUMMY_NAME,
       P.TOTALREQUESTAMOUNT PLAN_REQ_AMT, P.BUDGETSTATUS,
       CASE WHEN MAX(CASE WHEN PJ.REF_ID = P.ID THEN 1 ELSE 0 END) = 1 THEN 'REF_DIRECT' ELSE 'REF_OLD_VERSION' END LINK,
       LISTAGG(PJ.PROJECTID || CASE WHEN PJ.TEMP IS NULL THEN '(src)' ELSE '(copy)' END, ', ') WITHIN GROUP (ORDER BY PJ.PROJECTID) PROJECTS,
       MAX(CASE WHEN PJ.TEMP IS NOT NULL THEN PJ.TARGET_AMT END) COPY_TARGET_AMT
FROM P
JOIN PJ ON PJ.REF_ID = P.ID
        OR (PJ.REF_REQ = P.REQ_PARENT AND PJ.REF_RUNNING = P.RUNNING)
LEFT JOIN OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V cc ON cc.ID = P.CATEGORYID
LEFT JOIN OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V dcc ON dcc.ID = P.DUMMY_CATEGORY
GROUP BY P.ID, P.BUDGETREQUESTID, P.COSTCENTERID, P.RUNNING, P.CATEGORYID, cc.NAME, P.DUMMY_CATEGORY, dcc.NAME, P.TOTALREQUESTAMOUNT, P.BUDGETSTATUS
ORDER BY P.BUDGETREQUESTID, P.RUNNING
/
