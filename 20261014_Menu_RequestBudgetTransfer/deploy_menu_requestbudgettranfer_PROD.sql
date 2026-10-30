-- =====================================================================
-- DEPLOY (PROD): เพิ่มเมนู "แจ้งการโอนเงินกลับ" (Budget/RequestBudgettranferList) ในกลุ่ม "โอนเงินกลับ"
--
-- สภาพปัจจุบัน (ตรวจด้วย SELECT เมื่อ 2026-10-14)
--   PROD    : 135 "โอนเงินกลับ" เป็นเมนูเดี่ยวระดับบน ISPARENT='0' → Budget/BudgetTransferList SEQ 10
--             role ที่เห็น 135 = 1 (ผู้ดูแลระบบ1), 31 (สำนักบริหารงบประมาณ — 4 users)
--             MAX(ID) : SYSTEMMENU = 231, SYSTEMMENUROLEASSIGN = 337
--             ไม่มี trigger บน OAGWBG_SYSTEMMENU / OAGWBG_SYSTEMMENUROLEASSIGN → ID ที่ใส่คือ ID จริง
--   PREPROD : deploy แล้ว 2026-10-14 ด้วย deploy_menu_requestbudgettranfer.sql
--               135 โอนเงินกลับ (แม่, ISPARENT 1)
--                 232 โอนเงินกลับ      SEQ 0 → Budget/BudgetTransferList
--                 233 แจ้งการโอนเงินกลับ   SEQ 1 → Budget/RequestBudgettranferList
--             (233 ถูกเปลี่ยนชื่อจาก "แจ้งการโอนกลับ" เป็น "แจ้งการโอนเงินกลับ" บน PREPROD ภายหลัง — สคริปต์นี้ใช้ชื่อใหม่แล้ว)
--             ID บน PROD จะออกมาเป็น 232 / 233 เหมือนกัน (MAX = 231 เท่ากัน) ถ้าไม่มีใครเพิ่มเมนูก่อนรัน
--
-- สิ่งที่สคริปต์นี้ทำ
--   2.1 เปลี่ยน 135 เป็นเมนูแม่ (ล้าง controller/action)
--   2.2 เพิ่มลูก "โอนเงินกลับ"     SEQ 0 → Budget/BudgetTransferList (หน้าเดิม ย้ายมาเป็นลูก)
--   2.3 เพิ่มลูก "แจ้งการโอนเงินกลับ"  SEQ 1 → Budget/RequestBudgettranferList
--   2.4 ให้ลูกทั้ง 2 ตัวมีสิทธิ role เดียวกับ 135 (1, 31)
--
-- ⛔ เงื่อนไขก่อนรัน: เว็บบน PROD ต้องมี action Budget/RequestBudgettranferList แล้ว
--    ณ 2026-10-14 ยังไม่มีใน source (OAGBudget\Controllers\BudgetController.cs) → ถ้ารันก่อน กดเมนูได้ 404
-- ⚠️ ชื่อ action สะกด "tranfer" ตามที่ PREPROD ใช้ — ต้องตรงกับชื่อ action ที่ deploy จริง
--
-- ประเภท : DML (ไม่แตะ schema)   Reversibility = R1 (มี rollback §5)
-- DB     : PROD 172.16.11.18:1531 / PROD / OAGWBG
-- วิธีรัน : SQL Developer — รัน §1 เทียบกับสภาพด้านบน → รัน §2 (PL/SQL block เดียว
--          ถ้าตรวจในตัวไม่ผ่านจะ RAISE และ Oracle rollback ทั้ง block เอง) → ดู §3 → COMMIT ใน §4
-- =====================================================================


-- ---------------------------------------------------------------------
-- §1  BEFORE — บันทึกสภาพก่อนแก้
-- ---------------------------------------------------------------------
SELECT ID, MENUNAME, PARENTMENUID, SEQUENCE, CONTROLLERNAME, ACTIONNAME, ISPARENT, ACTIVE, ISSHOWINSITEMENU
FROM   OAGWBG_SYSTEMMENU
WHERE  ID = 135 OR PARENTMENUID = 135 OR ACTIONNAME IN ('BudgetTransferList', 'RequestBudgettranferList')
ORDER  BY ID;
-- คาดว่า: 1 แถว — 135 | โอนเงินกลับ | (null) | 10 | Budget | BudgetTransferList | 0 | 1 | 1

SELECT SYSTEMROLEID, SYSTEMMENUID FROM OAGWBG_SYSTEMMENUROLEASSIGN WHERE SYSTEMMENUID = 135 ORDER BY 1;
-- คาดว่า: role 1, 31

SELECT (SELECT MAX(ID) FROM OAGWBG_SYSTEMMENU) AS MAX_MENU,
       (SELECT MAX(ID) FROM OAGWBG_SYSTEMMENUROLEASSIGN) AS MAX_ASSIGN
FROM   DUAL;
-- ณ 2026-10-14: MAX_MENU = 231, MAX_ASSIGN = 337


-- ---------------------------------------------------------------------
-- §2  DEPLOY + ตรวจในตัว
-- ---------------------------------------------------------------------
DECLARE
  v_cnt NUMBER;
BEGIN
  -- 2.1 เปลี่ยน 135 เป็นเมนูแม่ — WHERE ล็อกสภาพเดิม (รันซ้ำจะได้ 0 rows ซึ่งไม่เป็นไร ดูตัวตรวจถัดไป)
  UPDATE OAGWBG_SYSTEMMENU
  SET    ISPARENT       = '1',
         CONTROLLERNAME = NULL,
         ACTIONNAME     = NULL,
         UPDATEBY       = -1,
         UPDATEON       = SYSTIMESTAMP
  WHERE  ID = 135
  AND    ISPARENT = '0'
  AND    ACTIONNAME = 'BudgetTransferList';

  SELECT COUNT(*) INTO v_cnt FROM OAGWBG_SYSTEMMENU
  WHERE  ID = 135 AND ISPARENT = '1' AND ACTIONNAME IS NULL AND PARENTMENUID IS NULL;
  IF v_cnt <> 1 THEN
    RAISE_APPLICATION_ERROR(-20001, '135 ไม่อยู่ในสภาพที่คาดไว้ — หยุด ตรวจ §1 ก่อน');
  END IF;

  -- 2.2 ลูก: โอนเงินกลับ (หน้าเดิม)
  INSERT INTO OAGWBG_SYSTEMMENU
    (ID, ACTIVE, MENUNAME, CONTROLLERNAME, ACTIONNAME, CONTROLLERMAINNAME,
     SEQUENCE, ISPARENT, PARENTMENUID, ISSHOWINSITEMENU, SYSTEMMENUGROUPID, SYSTEMNAMEID,
     CREATEBY, CREATEON)
  SELECT (SELECT NVL(MAX(ID), 0) + 1 FROM OAGWBG_SYSTEMMENU),
         '1', 'โอนเงินกลับ', 'Budget', 'BudgetTransferList', 'Budget',
         0, '0', 135, '1', 2, 2,
         -1, SYSTIMESTAMP
  FROM   DUAL
  WHERE  NOT EXISTS (SELECT 1 FROM OAGWBG_SYSTEMMENU
                     WHERE PARENTMENUID = 135 AND ACTIONNAME = 'BudgetTransferList');

  -- 2.3 ลูก: แจ้งการโอนเงินกลับ
  INSERT INTO OAGWBG_SYSTEMMENU
    (ID, ACTIVE, MENUNAME, CONTROLLERNAME, ACTIONNAME, CONTROLLERMAINNAME,
     SEQUENCE, ISPARENT, PARENTMENUID, ISSHOWINSITEMENU, SYSTEMMENUGROUPID, SYSTEMNAMEID,
     CREATEBY, CREATEON)
  SELECT (SELECT NVL(MAX(ID), 0) + 1 FROM OAGWBG_SYSTEMMENU),
         '1', 'แจ้งการโอนเงินกลับ', 'Budget', 'RequestBudgettranferList', 'Budget',
         1, '0', 135, '1', 2, 2,
         -1, SYSTIMESTAMP
  FROM   DUAL
  WHERE  NOT EXISTS (SELECT 1 FROM OAGWBG_SYSTEMMENU
                     WHERE PARENTMENUID = 135 AND ACTIONNAME = 'RequestBudgettranferList');

  -- 2.4 สิทธิ: ลูกทั้ง 2 ตัว × role ที่เห็น 135 (1, 31)
  INSERT INTO OAGWBG_SYSTEMMENUROLEASSIGN (ID, SYSTEMROLEID, SYSTEMMENUID, CREATEBY, CREATEON)
  SELECT (SELECT NVL(MAX(ID), 0) FROM OAGWBG_SYSTEMMENUROLEASSIGN) + ROWNUM,
         X.SYSTEMROLEID, X.MENUID, -1, SYSTIMESTAMP
  FROM  (SELECT R.SYSTEMROLEID, M.ID AS MENUID
         FROM   (SELECT DISTINCT SYSTEMROLEID FROM OAGWBG_SYSTEMMENUROLEASSIGN WHERE SYSTEMMENUID = 135) R
         CROSS  JOIN (SELECT ID FROM OAGWBG_SYSTEMMENU WHERE PARENTMENUID = 135) M
         WHERE  NOT EXISTS (SELECT 1 FROM OAGWBG_SYSTEMMENUROLEASSIGN A
                            WHERE A.SYSTEMROLEID = R.SYSTEMROLEID AND A.SYSTEMMENUID = M.ID)
         ORDER  BY M.ID, R.SYSTEMROLEID) X;

  -- ตรวจ: ลูกต้องมี 2 ตัว
  SELECT COUNT(*) INTO v_cnt FROM OAGWBG_SYSTEMMENU WHERE PARENTMENUID = 135;
  IF v_cnt <> 2 THEN
    RAISE_APPLICATION_ERROR(-20002, 'ลูกของ 135 มี ' || v_cnt || ' ตัว (คาด 2)');
  END IF;

  -- ตรวจ: ลูกทุกตัวต้องมีสิทธิครบทุก role ของ 135
  SELECT COUNT(*) INTO v_cnt
  FROM   (SELECT DISTINCT SYSTEMROLEID FROM OAGWBG_SYSTEMMENUROLEASSIGN WHERE SYSTEMMENUID = 135) R
  CROSS  JOIN (SELECT ID FROM OAGWBG_SYSTEMMENU WHERE PARENTMENUID = 135) M
  WHERE  NOT EXISTS (SELECT 1 FROM OAGWBG_SYSTEMMENUROLEASSIGN A
                     WHERE A.SYSTEMROLEID = R.SYSTEMROLEID AND A.SYSTEMMENUID = M.ID);
  IF v_cnt <> 0 THEN
    RAISE_APPLICATION_ERROR(-20003, 'สิทธิลูกขาด ' || v_cnt || ' แถว');
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
-- คาดว่า: PL/SQL procedure successfully completed.
--   ได้ SYSTEMMENU 232 (โอนเงินกลับ) / 233 (แจ้งการโอนเงินกลับ) + ROLEASSIGN 338–341


-- ---------------------------------------------------------------------
-- §3  VERIFY — ตรวจก่อน COMMIT
-- ---------------------------------------------------------------------

-- 3.1 โครงเมนู — ต้องได้ 3 แถว: 135 แม่ (ISPARENT 1, ไม่มี action) + ลูก SEQ 0 / 1
SELECT ID, MENUNAME, PARENTMENUID, SEQUENCE, CONTROLLERNAME, ACTIONNAME, ISPARENT, ACTIVE, ISSHOWINSITEMENU
FROM   OAGWBG_SYSTEMMENU
WHERE  ID = 135 OR PARENTMENUID = 135
ORDER  BY NVL(PARENTMENUID, 0), SEQUENCE;

-- 3.2 สิทธิ — ต้องได้ 6 แถว: role 1, 31 × (135 + ลูก 2 ตัว)
SELECT A.ID, A.SYSTEMMENUID, M.MENUNAME, A.SYSTEMROLEID, R.ROLENAME
FROM   OAGWBG_SYSTEMMENUROLEASSIGN A
JOIN   OAGWBG_SYSTEMMENU M ON M.ID = A.SYSTEMMENUID
LEFT   JOIN OAGWBG_SYSTEMROLE R ON R.ID = A.SYSTEMROLEID
WHERE  A.SYSTEMMENUID = 135 OR M.PARENTMENUID = 135
ORDER  BY A.SYSTEMMENUID, A.SYSTEMROLEID;

-- 3.3 ผ่านฟังก์ชันจริงที่เว็บใช้ render เมนู — user แรกของ role 31
--     ก่อนแก้ได้ 1 แถว (135 ลิงก์ BudgetTransferList) → หลังแก้ต้องได้ 3 แถว: 135 + ลูก SEQ 0 / 1
SELECT F.ID, F.MENUNAME, F.PARENTMENUID, F.SEQUENCE, F.ACTIONNAME
FROM   OAGWBG_FN_BOOKINGSYSTEMMENU(
         (SELECT MIN(U.ID)
          FROM   OAGWBG_SYSTEMUSERROLEASSIGN A
          JOIN   OAGWBG_SYSTEMUSER U ON U.ID = A.SYSTEMUSERID
          WHERE  A.SYSTEMROLEID = 31), 2) F
WHERE  F.ID = 135 OR F.PARENTMENUID = 135
ORDER  BY F.PARENTMENUID NULLS FIRST, F.SEQUENCE;


-- ---------------------------------------------------------------------
-- §4  COMMIT / ROLLBACK  (เลือกอย่างใดอย่างหนึ่งหลังดู §3)
-- ---------------------------------------------------------------------
-- COMMIT;
-- ROLLBACK;
--
-- หลัง COMMIT: เมนูอ่านตอน login → ให้ผู้ใช้ logout/login ใหม่ แล้วลองเปิดทั้ง 2 เมนู


-- =====================================================================
-- §5  ROLLBACK หลัง COMMIT ไปแล้ว — คืนสภาพเดิมทั้งหมด
-- =====================================================================
-- DELETE FROM OAGWBG_SYSTEMMENUROLEASSIGN
-- WHERE  SYSTEMMENUID IN (SELECT ID FROM OAGWBG_SYSTEMMENU WHERE PARENTMENUID = 135);
--
-- DELETE FROM OAGWBG_SYSTEMMENU WHERE PARENTMENUID = 135;
--
-- UPDATE OAGWBG_SYSTEMMENU
-- SET    ISPARENT = '0', CONTROLLERNAME = 'Budget', ACTIONNAME = 'BudgetTransferList',
--        UPDATEBY = -1, UPDATEON = SYSTIMESTAMP
-- WHERE  ID = 135;
--
-- COMMIT;
