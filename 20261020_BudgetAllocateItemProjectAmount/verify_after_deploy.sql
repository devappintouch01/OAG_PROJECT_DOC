-- =====================================================================
-- verify_after_deploy.sql   (2026-10-20)
-- รันหลัง deploy_fix_V_BUDGETALLOCATEITEM.sql
-- =====================================================================

-- 1) จำนวนแถวต้องเท่าเดิม = 1,893 (ณ 2026-10-20)
SELECT COUNT(*) CNT FROM OAGWBG_V_BUDGETALLOCATEITEM
/

-- 2) ยอดโครงการใน view ต้องตรงกับ PROJECTTARGETS.ALLOCATEDBUDGET  → คาดว่า 0 แถว
SELECT v.BUDGETYEAR, v.PROJECTID, v.TOTALREQUESTAMOUNT VIEW_AMT, t.AMT TARGET_AMT
FROM OAGWBG_V_BUDGETALLOCATEITEM v
JOIN (SELECT PROJECTID, SUM(NVL(ALLOCATEDBUDGET,0)) AMT FROM OAGWBG_PROJECTTARGETS GROUP BY PROJECTID) t
  ON t.PROJECTID = v.PROJECTID
WHERE v.BUDGETFORMTYPEID = 2
  AND NVL(v.TOTALREQUESTAMOUNT,0) <> t.AMT
/

-- 3) แถวโครงการที่ยังเป็น 0  → คาดว่า 0 แถว (ก่อนแก้ = 44 แถวของปี 2569)
SELECT v.BUDGETYEAR, v.PROJECTID, v.ITEMDETAIL
FROM OAGWBG_V_BUDGETALLOCATEITEM v
WHERE v.BUDGETFORMTYPEID = 2 AND NVL(v.TOTALREQUESTAMOUNT,0) = 0
/
