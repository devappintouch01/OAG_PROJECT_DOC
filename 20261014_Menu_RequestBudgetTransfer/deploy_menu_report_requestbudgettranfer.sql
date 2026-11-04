-- =====================================================================
-- DEPLOY: เมนูรายงาน "รายละเอียดการแจ้งการโอนเงินกลับ" (Report/ReportRequestBudgettranfer)
--         ในกลุ่มรายงาน 228 และเปลี่ยนชื่อกลุ่ม "โอนเงินจัดสรร" → "โอนจัดสรร/โอนเงินกลับ"
--
-- ใช้ได้ทั้ง PREPROD และ PROD (ไม่ผูก ID ใหม่ — หาแถวจาก ACTIONNAME, กันซ้ำด้วย NOT EXISTS, รันซ้ำได้)
--
-- สภาพก่อนแก้ (ตรวจด้วย SELECT เมื่อ 2026-10-14 — ทั้ง 2 เครื่องโครงเหมือนกัน)
--   153 รายงาน (ระดับบน)
--     228 โอนเงินจัดสรร (ISPARENT 1) ลูก SEQ 1–5:
--         193 ReportBudgetAllocateTransfer / 189 ReportBudgetTransferKTBPaymentTextFile /
--         210 ReportBudgetTransferControl / 216 ReportBudgetAnnualAllocationSummary /
--         217 ReportBudgetAllocateTransferDetail
--   role ของกลุ่ม 228 : PREPROD 1, 11, 21, 31 / PROD 1, 11, 31
--   MAX(ID) : PREPROD SYSTEMMENU 233, ROLEASSIGN 346 / PROD SYSTEMMENU 231, ROLEASSIGN 337
--   หมายเหตุ: 168 "โอนจัดสรร" (Budget/ReportBudgetAllocateTransfer) เป็นแถวกำพร้าใต้ 999 ที่ไม่มีอยู่จริง
--             ไม่ใช่กลุ่ม → ไม่ใช้ ไม่แตะ
--
-- สิ่งที่สคริปต์นี้ทำ
--   2.1 เปลี่ยนชื่อ 228 "โอนเงินจัดสรร" → "โอนจัดสรร/โอนเงินกลับ"
--   2.2 เพิ่มลูกของ 228 "รายละเอียดการแจ้งการโอนเงินกลับ" → Report/ReportRequestBudgettranfer
--       SEQUENCE = ต่อท้ายลูกเดิม (ตอนนี้ = 6)
--   2.3 สิทธิ role 1 (ผู้ดูแลระบบ1), 31 (สำนักบริหารงบประมาณ) — เท่ากับเมนู "แจ้งการโอนเงินกลับ"
--       ไม่ได้ให้ role 11 ศูนย์ต้นทุน (PROD 814 users) / 21 แม้กลุ่ม 228 จะมี — ถ้าต้องการดู §6
--
-- ⛔ ณ 2026-10-14 ยังไม่มี action ReportRequestBudgettranfer ใน OAGBudget\Controllers\ReportController.cs
--    → กดเมนูได้ 404 จนกว่าจะสร้างหน้า (บน PROD ให้รันหลัง deploy หน้าแล้ว)
-- ⚠️ ชื่อ action สะกด "tranfer" ตามที่สั่ง — ตอนสร้าง action ต้องสะกดให้ตรงกัน
--
-- ประเภท : DML (ไม่แตะ schema)   Reversibility = R1 (มี rollback §5)
-- วิธีรัน : §1 → §2 (PL/SQL block เดียว ตรวจไม่ผ่านจะ RAISE และ rollback ทั้ง block เอง) → §3 → COMMIT §4
-- =====================================================================


-- ---------------------------------------------------------------------
-- §1  BEFORE
-- ---------------------------------------------------------------------
SELECT ID, MENUNAME, PARENTMENUID, SEQUENCE, CONTROLLERNAME, ACTIONNAME, ISPARENT, ACTIVE, ISSHOWINSITEMENU
FROM   OAGWBG_SYSTEMMENU
WHERE  ID = 228 OR PARENTMENUID = 228 OR ACTIONNAME = 'ReportRequestBudgettranfer'
ORDER  BY NVL(PARENTMENUID, 0), SEQUENCE;
-- คาดว่า: 6 แถว — 228 | โอนเงินจัดสรร | 153 | 4 | | | 1 + ลูก 5 ตัว SEQ 1–5

SELECT (SELECT MAX(ID) FROM OAGWBG_SYSTEMMENU) AS MAX_MENU,
       (SELECT MAX(ID) FROM OAGWBG_SYSTEMMENUROLEASSIGN) AS MAX_ASSIGN
FROM   DUAL;


-- ---------------------------------------------------------------------
-- §2  DEPLOY + ตรวจในตัว
-- ---------------------------------------------------------------------
DECLARE
  v_cnt NUMBER;
BEGIN
  -- 2.1 เปลี่ยนชื่อกลุ่ม 228 — WHERE ล็อกสภาพเดิม (รันซ้ำจะได้ 0 rows ซึ่งไม่เป็นไร ดูตัวตรวจถัดไป)
  UPDATE OAGWBG_SYSTEMMENU
  SET    MENUNAME = 'โอนจัดสรร/โอนเงินกลับ',
         UPDATEBY = -1,
         UPDATEON = SYSTIMESTAMP
  WHERE  ID = 228
  AND    PARENTMENUID = 153
  AND    MENUNAME = 'โอนเงินจัดสรร';

  SELECT COUNT(*) INTO v_cnt FROM OAGWBG_SYSTEMMENU
  WHERE  ID = 228 AND PARENTMENUID = 153 AND ISPARENT = '1' AND MENUNAME = 'โอนจัดสรร/โอนเงินกลับ';
  IF v_cnt <> 1 THEN
    RAISE_APPLICATION_ERROR(-20001, '228 ไม่อยู่ในสภาพที่คาดไว้ — หยุด ตรวจ §1 ก่อน');
  END IF;

  -- 2.2 ลูก: รายละเอียดการแจ้งการโอนเงินกลับ (CONTROLLERMAINNAME เว้นว่างเหมือนลูกตัวอื่นของ 228)
  INSERT INTO OAGWBG_SYSTEMMENU
    (ID, ACTIVE, MENUNAME, CONTROLLERNAME, ACTIONNAME, CONTROLLERMAINNAME,
     SEQUENCE, ISPARENT, PARENTMENUID, ISSHOWINSITEMENU, SYSTEMMENUGROUPID, SYSTEMNAMEID,
     CREATEBY, CREATEON)
  SELECT (SELECT NVL(MAX(ID), 0) + 1 FROM OAGWBG_SYSTEMMENU),
         '1', 'รายละเอียดการแจ้งการโอนเงินกลับ', 'Report', 'ReportRequestBudgettranfer', NULL,
         (SELECT NVL(MAX(SEQUENCE), 0) + 1 FROM OAGWBG_SYSTEMMENU WHERE PARENTMENUID = 228),
         '0', 228, '1', 2, 2,
         -1, SYSTIMESTAMP
  FROM   DUAL
  WHERE  NOT EXISTS (SELECT 1 FROM OAGWBG_SYSTEMMENU
                     WHERE PARENTMENUID = 228 AND ACTIONNAME = 'ReportRequestBudgettranfer');

  -- 2.3 สิทธิ: role 1, 31
  INSERT INTO OAGWBG_SYSTEMMENUROLEASSIGN (ID, SYSTEMROLEID, SYSTEMMENUID, CREATEBY, CREATEON)
  SELECT (SELECT NVL(MAX(ID), 0) FROM OAGWBG_SYSTEMMENUROLEASSIGN) + ROWNUM,
         X.SYSTEMROLEID, X.MENUID, -1, SYSTIMESTAMP
  FROM  (SELECT R.ID AS SYSTEMROLEID, M.ID AS MENUID
         FROM   OAGWBG_SYSTEMROLE R
         CROSS  JOIN (SELECT ID FROM OAGWBG_SYSTEMMENU
                      WHERE PARENTMENUID = 228 AND ACTIONNAME = 'ReportRequestBudgettranfer') M
         WHERE  R.ID IN (1, 31)
         AND    NOT EXISTS (SELECT 1 FROM OAGWBG_SYSTEMMENUROLEASSIGN A
                            WHERE A.SYSTEMROLEID = R.ID AND A.SYSTEMMENUID = M.ID)
         ORDER  BY R.ID) X;

  -- ตรวจ: เมนูใหม่ต้องมี 1 แถว
  SELECT COUNT(*) INTO v_cnt FROM OAGWBG_SYSTEMMENU WHERE ACTIONNAME = 'ReportRequestBudgettranfer';
  IF v_cnt <> 1 THEN
    RAISE_APPLICATION_ERROR(-20002, 'เมนู ReportRequestBudgettranfer มี ' || v_cnt || ' แถว (คาด 1)');
  END IF;

  -- ตรวจ: สิทธิต้องครบ role 1, 31
  SELECT COUNT(DISTINCT A.SYSTEMROLEID) INTO v_cnt
  FROM   OAGWBG_SYSTEMMENUROLEASSIGN A
  JOIN   OAGWBG_SYSTEMMENU M ON M.ID = A.SYSTEMMENUID
  WHERE  M.ACTIONNAME = 'ReportRequestBudgettranfer' AND A.SYSTEMROLEID IN (1, 31);
  IF v_cnt <> 2 THEN
    RAISE_APPLICATION_ERROR(-20003, 'สิทธิ role 1/31 มี ' || v_cnt || ' role (คาด 2)');
  END IF;

  -- ตรวจ: PK ต้องไม่ซ้ำ
  SELECT (SELECT COUNT(*) FROM (SELECT ID FROM OAGWBG_SYSTEMMENU GROUP BY ID HAVING COUNT(*) > 1))
       + (SELECT COUNT(*) FROM (SELECT ID FROM OAGWBG_SYSTEMMENUROLEASSIGN GROUP BY ID HAVING COUNT(*) > 1))
  INTO   v_cnt FROM DUAL;
  IF v_cnt <> 0 THEN
    RAISE_APPLICATION_ERROR(-20004, 'ID ซ้ำ ' || v_cnt || ' ค่า');
  END IF;
END;
/


-- ---------------------------------------------------------------------
-- §3  VERIFY
-- ---------------------------------------------------------------------

-- 3.1 โครงเมนู — ต้องได้ 7 แถว: 228 "โอนจัดสรร/โอนเงินกลับ" + ลูก SEQ 1–6 (ตัวใหม่ SEQ 6)
SELECT ID, MENUNAME, PARENTMENUID, SEQUENCE, CONTROLLERNAME, ACTIONNAME, ISPARENT, ACTIVE, ISSHOWINSITEMENU
FROM   OAGWBG_SYSTEMMENU
WHERE  ID = 228 OR PARENTMENUID = 228
ORDER  BY NVL(PARENTMENUID, 0), SEQUENCE;

-- 3.2 สิทธิเมนูใหม่ — ต้องได้ 2 แถว: role 1, 31
SELECT A.ID, A.SYSTEMMENUID, M.MENUNAME, A.SYSTEMROLEID, R.ROLENAME
FROM   OAGWBG_SYSTEMMENUROLEASSIGN A
JOIN   OAGWBG_SYSTEMMENU M ON M.ID = A.SYSTEMMENUID
LEFT   JOIN OAGWBG_SYSTEMROLE R ON R.ID = A.SYSTEMROLEID
WHERE  M.ACTIONNAME = 'ReportRequestBudgettranfer'
ORDER  BY A.SYSTEMROLEID;

-- 3.3 ผ่านฟังก์ชันจริงที่เว็บใช้ render เมนู — user แรกของ role 31 ต้องเห็นเมนูใหม่ใต้ 228
SELECT F.ID, F.MENUNAME, F.PARENTMENUID, F.SEQUENCE, F.ACTIONNAME
FROM   OAGWBG_FN_BOOKINGSYSTEMMENU(
         (SELECT MIN(U.ID)
          FROM   OAGWBG_SYSTEMUSERROLEASSIGN A
          JOIN   OAGWBG_SYSTEMUSER U ON U.ID = A.SYSTEMUSERID
          WHERE  A.SYSTEMROLEID = 31), 2) F
WHERE  F.ID = 228 OR F.PARENTMENUID = 228
ORDER  BY F.PARENTMENUID NULLS FIRST, F.SEQUENCE;


-- ---------------------------------------------------------------------
-- §4  COMMIT / ROLLBACK
-- ---------------------------------------------------------------------
-- COMMIT;
-- ROLLBACK;
--
-- หลัง COMMIT: เมนูอ่านตอน login → ให้ผู้ใช้ logout/login ใหม่


-- =====================================================================
-- §5  ROLLBACK หลัง COMMIT ไปแล้ว — คืนสภาพเดิมทั้งหมด
-- =====================================================================
-- DELETE FROM OAGWBG_SYSTEMMENUROLEASSIGN
-- WHERE  SYSTEMMENUID IN (SELECT ID FROM OAGWBG_SYSTEMMENU WHERE ACTIONNAME = 'ReportRequestBudgettranfer');
--
-- DELETE FROM OAGWBG_SYSTEMMENU WHERE ACTIONNAME = 'ReportRequestBudgettranfer';
--
-- UPDATE OAGWBG_SYSTEMMENU
-- SET    MENUNAME = 'โอนเงินจัดสรร', UPDATEBY = -1, UPDATEON = SYSTIMESTAMP
-- WHERE  ID = 228;
--
-- COMMIT;


-- =====================================================================
-- §6  (ทางเลือก — ต้องให้ BA ยืนยันก่อน) ให้ role 11 ศูนย์ต้นทุน เห็นรายงานนี้ด้วย เหมือนลูกตัวอื่นของ 228
-- =====================================================================
-- INSERT INTO OAGWBG_SYSTEMMENUROLEASSIGN (ID, SYSTEMROLEID, SYSTEMMENUID, CREATEBY, CREATEON)
-- SELECT (SELECT NVL(MAX(ID), 0) + 1 FROM OAGWBG_SYSTEMMENUROLEASSIGN), 11, M.ID, -1, SYSTIMESTAMP
-- FROM   OAGWBG_SYSTEMMENU M
-- WHERE  M.ACTIONNAME = 'ReportRequestBudgettranfer'
-- AND    NOT EXISTS (SELECT 1 FROM OAGWBG_SYSTEMMENUROLEASSIGN A
--                    WHERE A.SYSTEMROLEID = 11 AND A.SYSTEMMENUID = M.ID);
-- COMMIT;
