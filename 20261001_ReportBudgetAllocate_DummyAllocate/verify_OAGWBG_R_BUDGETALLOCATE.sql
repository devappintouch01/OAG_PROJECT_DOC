-- ============================================================
-- verify: OAGWBG_R_BUDGETALLOCATE (ยอดจัดสรรรายการ dummy) — SELECT ล้วน ไม่แก้ข้อมูล
-- แต่ละ statement คั่นด้วยบรรทัด "/"
-- ============================================================

-- ------------------------------------------------------------
-- [ก่อน deploy 1] DDL บน server ยังตรงกับ rollback_OAGWBG_R_BUDGETALLOCATE.sql ไหม
--   ถ้าไม่ตรง = มีคนแก้ view ไปแล้ว ต้องดึง DDL ใหม่แล้วทำ deploy/rollback ใหม่ก่อน
-- ------------------------------------------------------------
SELECT DBMS_METADATA.GET_DDL('VIEW','OAGWBG_R_BUDGETALLOCATE','OAGWBG') AS DDL FROM DUAL
/
-- ------------------------------------------------------------
-- [ก่อน deploy 2] ยอดต่อปีของ view เดิม — จดไว้เทียบ [หลัง deploy 3]
--   PROD 2026-10-01:
--     2569 | 568 | REQ 21,011,775,000 | PROP 14,922,118,100 | AMEND 78,343,300
--     2570 | 670 | REQ 21,584,934,000 | PROP 14,587,096,500 | AMEND 216,326,700
-- ------------------------------------------------------------
SELECT BUDGETYEAR, COUNT(*) N, SUM(REQUESTAMOUNT) REQ, SUM(PROPOSEAMOUNT) PROP, SUM(AMENDAMOUNT) AMEND
FROM OAGWBG_R_BUDGETALLOCATE GROUP BY BUDGETYEAR ORDER BY BUDGETYEAR
/
-- ------------------------------------------------------------
-- [ก่อน deploy 3] ยอดที่ PROP/AMEND ควรเพิ่มขึ้นหลัง deploy = ผลรวม REQ_* ของแถวคำขอ dummy ที่อยู่ในรายงาน
--   PROD 2026-10-01: 2569 → 0 / 0, 2570 → 58,455,399 / 0
--   (ตอนวิเคราะห์ 73799 เคยเป็น 10,135,600 แล้วเปลี่ยนเป็น 10,135,599 ระหว่างวัน — ผู้ใช้บันทึกใหม่)
-- ------------------------------------------------------------
SELECT a.BUDGETYEAR, COUNT(*) N_DUMMY_REQ,
       SUM(NVL(BG.REQ_TOTALALLOCATEAMOUNT,0)) EXPECT_PROP_DELTA,
       SUM(NVL(BG.REQ_TOTALADJUSTEDAMOUNT,0)) EXPECT_AMEND_DELTA
FROM OAGWBG_V_BUDGETALLOCATEITEM a
JOIN OAGWBG_BUDGETGOVERNMENT BG ON BG.ID = a.BUDGET_GOVERNMENT_ID
WHERE a.BUDGETGOVERNMENTTYPE = 'DUMMY' AND BG.BUDGETSTATUS != 'A'
GROUP BY a.BUDGETYEAR ORDER BY 1
/

-- ============================================================
-- หลัง deploy
-- ============================================================

-- [หลัง deploy 1] view ต้อง VALID
SELECT OBJECT_NAME, STATUS, LAST_DDL_TIME FROM USER_OBJECTS WHERE OBJECT_NAME = 'OAGWBG_R_BUDGETALLOCATE'
/
-- [หลัง deploy 2] ไม่มีคีย์ซ้ำ — ต้องได้ 0 แถว
SELECT BUDGETYEAR, BUDGETPLANID, PRODUCTID, ACTIVITYID, CATEGORYID, CATEGORYNAME, COUNT(*) CNT
FROM OAGWBG_R_BUDGETALLOCATE
GROUP BY BUDGETYEAR, BUDGETPLANID, PRODUCTID, ACTIVITYID, CATEGORYID, CATEGORYNAME
HAVING COUNT(*) > 1
/
-- [หลัง deploy 3] ยอดต่อปี — N / REQ ต้องเท่า [ก่อน deploy 2], PROP/AMEND = เดิม + [ก่อน deploy 3]
SELECT BUDGETYEAR, COUNT(*) N, SUM(REQUESTAMOUNT) REQ, SUM(PROPOSEAMOUNT) PROP, SUM(AMENDAMOUNT) AMEND
FROM OAGWBG_R_BUDGETALLOCATE GROUP BY BUDGETYEAR ORDER BY BUDGETYEAR
/
-- [หลัง deploy 4] เคสที่แจ้ง — หมวด 2475 กิจกรรม 21100 ปี 2570 PROPOSEAMOUNT ต้องเท่า REQ_TOTALALLOCATEAMOUNT ของแถว 73799
SELECT r.CATEGORYID, r.CATEGORYNAME, r.REQUESTAMOUNT, r.PROPOSEAMOUNT, r.AMENDAMOUNT,
       (SELECT REQ_TOTALALLOCATEAMOUNT FROM OAGWBG_BUDGETGOVERNMENT WHERE ID = 73799) AS EXPECT_PROP
FROM OAGWBG_R_BUDGETALLOCATE r
WHERE r.BUDGETYEAR = 2570 AND r.CATEGORYID = 2475 AND TO_CHAR(r.ACTIVITYID) = '21100'
/
