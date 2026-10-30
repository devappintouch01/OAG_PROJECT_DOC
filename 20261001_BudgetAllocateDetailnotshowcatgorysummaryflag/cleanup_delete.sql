-- ล้างแถวขยะ: "รายการจัดสรร พรบ" ยอด 0 ที่ถูกสร้างบน Category ค่ากลาง (DUMMY_FLAG = 'YES')
--   เกิดจาก SaveBudgetAllocateDetail ตอนย้ายคำขอออกจากค่ากลางจนหมด — ดู result.md ข้อ 4
--   ทำให้หน้า BudgetAllocateDetail แสดงแถวค่ากลางยอด 0 ค้างอยู่
-- ตาราง: OAGWBG.OAGWBG_BUDGETGOVERNMENT (1 แถว) + OAGWBG.OAGWBG_BUDGETDISBURSEMENTPLANITEM (12 แถว/รายการ)
-- PREPROD: 172.16.11.19:1541 / SERVICE_NAME=ebs_PRE / User=OAGWBG
--
-- ⚠️ ลำดับ: deploy code (BudgetService.cs กัน dummy ตอนสร้าง "รายการจัดสรร พรบ") ก่อน แล้วค่อยรัน script นี้
--          ถ้ารันก่อน — การย้ายคำขอออกจากค่ากลางครั้งถัดไปจะสร้างแถวขยะขึ้นมาใหม่
-- ⚠️ rollback: cleanup_rollback.sql (INSERT ครบทุกคอลัมน์ของ PREPROD ณ 2026-10-01)
--          ถ้ารันที่ PROD ต้องสร้าง rollback ของ PROD ใหม่ก่อน (ID ไม่ตรงกัน)
-- ⚠️ ตรวจแล้ว: ไม่มี FK ชี้มาที่ OAGWBG_BUDGETGOVERNMENT / OAGWBG_BUDGETDISBURSEMENTPLANITEM
--          และไม่มีตารางอื่นอ้าง BUDGETGOVERNMENTID ของแถวเป้าหมาย นอกจาก DISBURSEMENTPLANITEM (STEP 3)
--          แถวเป้าหมายเป็นสถานะ B (ยังไม่เคยยืนยัน) จึงไม่เคยส่ง GL


-- ---------- STEP 1: แถวเป้าหมาย — PREPROD ต้องได้ 1 แถว (ID 73725) ----------
SELECT BG.ID, BG.BUDGETYEAR, BG.CATEGORYID, CC.NAME AS CATEGORYNAME, BG.BUDGETPLANID, BG.PRODUCTID, BG.ACTIVITYCODEID,
       BG.BUDGETSTATUS, BG.BUDGETDETAIL, BG.CREATEON
FROM   OAGWBG.OAGWBG_BUDGETGOVERNMENT BG
JOIN   OAGWBG.OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V CC ON CC.ID = BG.CATEGORYID
WHERE  CC.DUMMY_FLAG = 'YES'
AND    BG.BUDGETREQUESTID = 0
AND    BG.BUDGETGOVERNMENTTYPE IS NULL
AND    BG.BUDGETFORMTYPEID = 1
AND    BG.BUDGETDETAIL = 'รายการจัดสรร พรบ'
AND    NVL(BG.TOTALREQUESTAMOUNT, 0) = 0
AND    NVL(BG.TOTALALLOCATEAMOUNT, 0) = 0
AND    NVL(BG.TOTALADJUSTEDAMOUNT, 0) = 0
AND    NVL(BG.TOTALREQUESTADJUSTAMOUNT, 0) = 0
AND    NVL(BG.KEPTCENTRAL, 0) = 0;
-- => PREPROD 2026-10-01: 73725 | 2572 | 2191 | ค่าตอบแทน (อื่นๆ โปรดระบุ...) | 3124 | 21000 | 21100 | B | รายการจัดสรร พรบ


-- ---------- STEP 2: ต้องได้ 0 — มีแถวไหนผูกกับเป้าหมายนอกจากแผนการใช้จ่าย (ถ้า > 0 หยุด อย่าลบ) ----------
SELECT COUNT(*) AS OTHER_REFS
FROM   OAGWBG.OAGWBG_BUDGETGOVERNMENT X
WHERE  X.REF_BUDGETGOVERNMENTID IN (73725);
-- => 0


-- ---------- STEP 3: แผนการใช้จ่ายที่จะลบ — ต้องได้ 12 แถว ยอดรวม 0 (ถ้ายอด > 0 หยุด อย่าลบ) ----------
SELECT BUDGETGOVERNMENTID, COUNT(*) AS CNT, SUM(NVL(PLANAMOUNT, 0)) AS PLANAMT, SUM(NVL(ALLOCATEAMOUNT, 0)) AS ALLOCAMT
FROM   OAGWBG.OAGWBG_BUDGETDISBURSEMENTPLANITEM
WHERE  BUDGETGOVERNMENTID IN (73725)
GROUP  BY BUDGETGOVERNMENTID;
-- => 73725 | 12 | 0 | 0


-- ---------- STEP 4: ลบ (ระบุ ID ตรง ๆ — ไม่ลบด้วยเงื่อนไขกว้าง) ----------
DELETE FROM OAGWBG.OAGWBG_BUDGETDISBURSEMENTPLANITEM
WHERE  BUDGETGOVERNMENTID IN (73725)
AND    NVL(PLANAMOUNT, 0) = 0;
-- => 12 rows deleted

DELETE FROM OAGWBG.OAGWBG_BUDGETGOVERNMENT
WHERE  ID IN (73725)
AND    BUDGETREQUESTID = 0
AND    BUDGETGOVERNMENTTYPE IS NULL;
-- => 1 row deleted


-- ---------- STEP 5: ตรวจหลังลบ ก่อน COMMIT ----------
-- 5.1 ต้องได้ 0
SELECT COUNT(*) AS REMAIN FROM OAGWBG.OAGWBG_BUDGETGOVERNMENT WHERE ID IN (73725);
SELECT COUNT(*) AS REMAIN FROM OAGWBG.OAGWBG_BUDGETDISBURSEMENTPLANITEM WHERE BUDGETGOVERNMENTID IN (73725);

-- 5.2 หน้าจอปี 2572 — Category 2191 (ค่ากลาง) ต้องหายไป เหลือ 2212 / 2219 ยอดเดิม (18,900,000 / 20,900,000)
SELECT CATEGORY_ID, CATEGORY_NAME, BUDGETGOVERNMENTTYPE, BUDGETREQUESTID, BUDGET_GOVERNMENT_ID, TOTALREQUESTSIMMARYAMOUNT, TOTALALLOCATEAMOUNT
FROM   OAGWBG.OAGWBG_V_BUDGETALLOCATEITEM
WHERE  BUDGETYEAR = 2572 AND BUDGETFORMTYPEID = 1 AND CATEGORY_ID IN (2191, 2212, 2219)
ORDER  BY CATEGORY_ID;

-- ถูกต้องครบ → COMMIT;   ไม่ตรง → ROLLBACK;
-- COMMIT;
