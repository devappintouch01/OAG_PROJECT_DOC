--------------------------------------------------------------------------------
-- OAGWBG_V_BUDGETREQUESTSUMMARYLIST  v3  (2026-09-23)
--
-- ปัญหา : ยอด TOTALREQUESTAMOUNT ของคำขอประเภทโครงการ (formtype 2) เบิ้ล
--
-- สาเหตุ : REQ_AMT ของ formtype 2 = NVL(OPT.ALLOCATEDBUDGET,0) ต่อ 1 แถว BG
--          คำขอใบหนึ่งมีทั้ง "โครงการตัวแม่" และ "temp copy" ที่
--          DuplicateProjectData สร้างไว้ (BudgetService.cs:35011)
--          เช่น BR 1775 : project 283 (ตัวแม่) + 284 (copy)
--          -> SUM() บวกยอดของทั้งสองใบ = เบิ้ล
--
--          predicate เดิมตัด "โครงการที่ถูกชี้" (TEMP = BG.PROJECTID)
--          แต่ไม่ได้ตัด "โครงการที่ถือ TEMP" - 283 กับ 284 ไม่มีใครชี้ จึงรอดทั้งคู่
--
-- !! ทางที่ "ตัด copy ทิ้งทั้งหมด" ใช้ไม่ได้ - ตรวจกับข้อมูลจริงแล้ว :
--      ปี 2570 : ได้ 232,408,306 แต่ที่ถูกคือ 339,686,736 (ตัดเกิน 107 ล้าน)
--      ปี 2569 : ได้ 0.00 (45 โครงการเป็น copy 44 ใบ ตัวแม่ที่เหลือยอดเป็น 0)
--    เพราะ copy บางใบคือตัวจริงที่ต้องเก็บ
--
-- v3 : ยุบเป็น "กลุ่มตรรกะ" แล้วเลือกใบเดียวต่อกลุ่ม
--        PARTITION BY BR.ID, P.RUNNING, P.PROJECTNAME
--        ORDER BY  ตัวแม่ก่อน (TEMP IS NULL) -> P.ID สูงสุด
--      กลุ่มไหนไม่มีตัวแม่ จะ fallback ไปใช้ copy ที่ ID สูงสุดเอง -> ยอดไม่หาย
--
-- ยืนยันกับข้อมูล PROD แล้ว (2026-09-23) :
--      ปี | ก่อนแก้        | v3             | ที่ถูกต้อง
--    2571 |  27,598,660.00 |  27,598,660.00 | ไม่ขยับ (ไม่มี copy)
--    2570 | 532,136,542.00 | 339,686,736.00 | 339,686,736.00  OK
--    2569 | 109,356,663.00 | 109,356,663.00 | ไม่ลด            OK
--
-- คีย์นี้ตรงกับที่ C# ใช้ใน GetBudgetRequestSummaryProjectList (LogicalKey)
-- ถ้าจะเปลี่ยนคีย์ ต้องเปลี่ยนทั้งสองที่พร้อมกัน ไม่งั้นตัวเลขสองหน้าจะไม่ตรง
--
-- ที่ไม่ได้แตะ :
--   - predicate NOT EXISTS (TEMP = BG.PROJECTID) ของเดิม - คงไว้ทุกตัวอักษร
--     ตัวเลขที่ verify ข้างบนได้มาจากการคงมันไว้ ถ้าถอดออกผลจะเปลี่ยน
--   - LEFT JOIN OAGWBG_PROJECTTARGETS OPT ยังไม่ dedup
--     (ตรวจแล้ว PROJ_MULTI_OPT = 0 ทุกปี จึงยังไม่ระเบิด - ดูหมายเหตุท้ายไฟล์)
--   - logic KEPT_FINAL / BG4 / BG4P คงเดิมทุกตัวอักษร
--------------------------------------------------------------------------------

CREATE OR REPLACE FORCE EDITIONABLE VIEW "OAGWBG"."OAGWBG_V_BUDGETREQUESTSUMMARYLIST"
    ("BUDGETYEAR", "TOTALREQUESTAMOUNT", "TOTALRECEIVEAMOUNT",
     "STATUS_NAME", "BUDGETFORMTYPEID", "BUDGETFORMTYPENAME") AS
SELECT
  BUDGETYEAR,
  SUM(REQ_AMT)              AS TOTALREQUESTAMOUNT,
  SUM(NVL(KEPT_FINAL,0))    AS TOTALRECEIVEAMOUNT,      --  ก้อนเดียวต่อกลุ่ม
  CASE
    WHEN SUM(CASE WHEN BUDGETSTATUS = 'B' THEN 1 ELSE 0 END) > 0 THEN 'B'
    WHEN SUM(CASE WHEN BUDGETSTATUS = 'U' THEN 1 ELSE 0 END) > 0 THEN 'U'
    WHEN SUM(CASE WHEN BUDGETSTATUS = 'X' THEN 1 ELSE 0 END) > 0 THEN 'X'
    ELSE MAX(BUDGETSTATUS)
  END AS STATUS_NAME,
  BUDGETFORMTYPEID,
  CASE
        WHEN BUDGETFORMTYPEID IN ('1','3') THEN 'แผนงาน'
        WHEN BUDGETFORMTYPEID IN ('2','4','5') THEN 'โครงการ'
        ELSE 'โครงการ'
  END AS BUDGETFORMTYPENAME
FROM (
  SELECT
    BR.BUDGETYEAR,
    BR.BUDGETFORMTYPEID,
    BG.BUDGETSTATUS,
    BG.PROJECTID,
    CASE
        WHEN BG.BUDGETFORMTYPEID IN (1,3) THEN NVL(BG.TOTALREQUESTAMOUNT, 0)
        WHEN BG.BUDGETFORMTYPEID IN (2,4) THEN NVL(OPT.ALLOCATEDBUDGET, 0)
        ELSE NVL(BG.TOTALREQUESTAMOUNT, 0)
    END AS REQ_AMT,
    ---------------------------------------------------------------- [2] v3
    -- ยุบโครงการซ้ำ : 1 กลุ่มตรรกะ = 1 แถว
    --   กลุ่ม = คำขอใบเดียวกัน + RUNNING + ชื่อโครงการ
    --   ลำดับ = ตัวแม่ (TEMP IS NULL) ก่อน -> P.ID สูงสุด
    --           -> แถวที่ถือ KEPTCENTRAL ก่อน (กันก้อนเงินหายถ้า 1 โครงการมีหลาย BG)
    --           -> BG.ID กัน tie ให้ผลคงที่
    ROW_NUMBER() OVER (
        PARTITION BY BR.ID, P.RUNNING, P.PROJECTNAME
        ORDER BY NVL2(P.TEMP, 1, 0),
                 P.ID DESC,
                 NVL2(BG4.KEPTCENTRAL, 0, 1),
                 BG.ID
    ) AS PRJ_RN,
    ----------------------------------------------------------------
    ---------------------------------------------------------------- [1]
    -- ก้อนเงินของกลุ่ม : คืนค่าเฉพาะแถวเดียวต่อกลุ่ม แถวอื่นเป็น NULL
    CASE
      WHEN BG4.KEPTCENTRAL IS NOT NULL THEN BG4.KEPTCENTRAL
      WHEN COUNT(BG4.KEPTCENTRAL) OVER (
             PARTITION BY BR.BUDGETYEAR, BR.BUDGETFORMTYPEID,
                          CASE WHEN NVL(BG.DUMMY_CATEGORY,0) <> 0
                               THEN BG.DUMMY_CATEGORY ELSE BG.CATEGORYID END,
                          BG.PRODUCTID, BG.ACTIVITYCODEID, BG.PROJECTID, BG.BUDGETPLANID
           ) = 0
       AND ROW_NUMBER() OVER (
             PARTITION BY BR.BUDGETYEAR, BR.BUDGETFORMTYPEID,
                          CASE WHEN NVL(BG.DUMMY_CATEGORY,0) <> 0
                               THEN BG.DUMMY_CATEGORY ELSE BG.CATEGORYID END,
                          BG.PRODUCTID, BG.ACTIVITYCODEID, BG.PROJECTID, BG.BUDGETPLANID
             ORDER BY NVL2(BG4P.KEPTCENTRAL, 0, 1), BG.ID
           ) = 1
      THEN BG4P.KEPTCENTRAL
    END AS KEPT_FINAL
    ----------------------------------------------------------------
  FROM OAGWBG_BUDGETREQUEST BR
  LEFT JOIN OAGWBG_BUDGETGOVERNMENT BG
      ON BG.BUDGETREQUESTID = BR.ID
     AND BG.ID IS NOT NULL
     AND ( BG.BUDGETGOVERNMENTTYPE IS NULL OR BG.BUDGETGOVERNMENTTYPE = 7 )
  LEFT JOIN (
      SELECT
          REF_BUDGETGOVERNMENTID,
          SUM(KEPTCENTRAL) AS KEPTCENTRAL,
          MAX(ID) KEEP (DENSE_RANK FIRST ORDER BY NVL(KEPTCENTRAL,0) DESC) AS ID
      FROM OAGWBG_BUDGETGOVERNMENT
      WHERE BUDGETGOVERNMENTTYPE = 4
      GROUP BY REF_BUDGETGOVERNMENTID
  ) BG4 ON BG.ID = BG4.REF_BUDGETGOVERNMENTID
  LEFT JOIN (
      SELECT
          PBG.BUDGETREQUESTID  AS PARENT_REQID,
          PBG.RUNNING          AS RUNNING,
          SUM(B4P.KEPTCENTRAL) AS KEPTCENTRAL
      FROM OAGWBG_BUDGETGOVERNMENT PBG
      JOIN OAGWBG_BUDGETGOVERNMENT B4P
           ON B4P.REF_BUDGETGOVERNMENTID = PBG.ID
          AND B4P.BUDGETGOVERNMENTTYPE   = '4'
      WHERE PBG.RUNNING IS NOT NULL
      GROUP BY PBG.BUDGETREQUESTID, PBG.RUNNING
      HAVING COUNT(*) = 1
  ) BG4P
      ON  BG4P.PARENT_REQID = BR.PARENTID
      AND BG4P.RUNNING      = BG.RUNNING
  LEFT JOIN OAGWBG_PROJECTTARGETS OPT ON OPT.PROJECTID = BG.PROJECTID
  ------------------------------------------------------------------ [3] v3
  -- join เพิ่มเพื่อเอา TEMP / RUNNING / PROJECTNAME มาใช้จัดกลุ่ม
  -- P.ID เป็น PK จึงเป็น 1:1 ไม่ทำให้แถวคูณเพิ่ม
  LEFT JOIN OAGWBG_PROJECT P ON P.ID = BG.PROJECTID
  ------------------------------------------------------------------
  WHERE NOT EXISTS (
      SELECT 1
      FROM OAGWBG_BUDGETREQUEST BR2
      WHERE BR2.PARENTID IS NOT NULL
        AND BR2.PARENTID = BG.BUDGETREQUESTID
  )
  AND ( BG.PROJECTID IS NULL OR NOT EXISTS (
      SELECT 1
      FROM OAGWBG_PROJECT
      WHERE TEMP IS NOT NULL
        AND TEMP = BG.PROJECTID
  ))
  AND BG.BUDGETSTATUS NOT IN ('A','X')
  AND BR.BUDGETFORMTYPEID IN (1, 2)
)
------------------------------------------------------------------ [4] v3
-- แถวแผนงาน (formtype 1) ไม่มี PROJECTID ต้องปล่อยผ่านทั้งหมด
-- ไม่งั้นจะเหลือใบละแถวเดียวและยอดแผนงานหาย
WHERE PROJECTID IS NULL OR PRJ_RN = 1
------------------------------------------------------------------
GROUP BY BUDGETYEAR, BUDGETFORMTYPEID
ORDER BY
  BUDGETYEAR DESC,
  BUDGETFORMTYPEID ASC;

--------------------------------------------------------------------------------
-- หมายเหตุค้างไว้ (ยังไม่แก้ในไฟล์นี้)
--
-- LEFT JOIN OAGWBG_PROJECTTARGETS OPT ON OPT.PROJECTID = BG.PROJECTID
--   ยังไม่ dedup ถ้าโครงการหนึ่งมี PROJECTTARGETS เกิน 1 แถว ยอดจะถูกคูณอีกชั้น
--   (เกิดได้จาก BudgetService.cs:2762 ที่ save ด้วย Id == 0 แล้ว insert ใหม่เสมอ)
--   ตรวจ 2026-09-23 แล้ว PROJ_MULTI_OPT = 0 ทุกปี จึงยังไม่กระทบ
--
--   ถ้าจะปิดช่องนี้ด้วย ให้เปลี่ยนเป็น :
--     LEFT JOIN (
--       SELECT PROJECTID, ALLOCATEDBUDGET FROM (
--         SELECT PROJECTID, ALLOCATEDBUDGET,
--                ROW_NUMBER() OVER (PARTITION BY PROJECTID ORDER BY ID DESC) RN
--         FROM OAGWBG_PROJECTTARGETS)
--       WHERE RN = 1
--     ) OPT ON OPT.PROJECTID = BG.PROJECTID
--
-- ต้นตอที่ทำให้ copy งอก : DuplicateProjectData (BudgetService.cs:35011)
--   ไม่ remap Temp ผ่าน projectIdMap ที่ตัวเองสร้างไว้ -> copy ใบใหม่ถือ TEMP
--   ที่ชี้ข้ามไปหาโครงการในคำขอใบเก่า view นี้แก้ที่ปลายทาง ไม่ได้หยุดการงอก
--------------------------------------------------------------------------------
