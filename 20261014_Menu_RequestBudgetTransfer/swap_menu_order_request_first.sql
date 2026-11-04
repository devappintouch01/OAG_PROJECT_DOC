-- =====================================================================
-- สลับลำดับเมนูในกลุ่ม 135 "โอนเงินกลับ" — ให้ "แจ้งการโอนเงินกลับ" อยู่ก่อน "โอนเงินกลับ" (ผู้ใช้ 2026-10-21)
--
-- สภาพก่อนแก้ (ตาม deploy_menu_requestbudgettranfer*.sql)
--   ลูกของ 135 : SEQ 0 โอนเงินกลับ        → Budget/BudgetTransferList
--                SEQ 1 แจ้งการโอนเงินกลับ → Budget/RequestBudgettranferList
-- หลังแก้      : SEQ 0 แจ้งการโอนเงินกลับ / SEQ 1 โอนเงินกลับ
--
-- ใช้ได้ทั้ง PREPROD และ PROD — อ้างด้วย PARENTMENUID + ACTIONNAME ไม่อ้าง ID (ID ลูกอาจต่างกันแต่ละ DB)
-- Default.cshtml (CategoryMenu) เรียงลูกด้วย OrderBy(Sequence)
--
-- ประเภท : DML 2 แถว   Reversibility = R2 (rollback §5)
-- หลัง COMMIT: เมนูอ่านตอน login → ให้ผู้ใช้ logout/login ใหม่
-- =====================================================================


-- ---------------------------------------------------------------------
-- §1  BEFORE — คาดว่า 3 แถว: 135 แม่ + ลูก SEQ 0 BudgetTransferList / SEQ 1 RequestBudgettranferList
-- ---------------------------------------------------------------------
SELECT ID, MENUNAME, PARENTMENUID, SEQUENCE, CONTROLLERNAME, ACTIONNAME, ISPARENT, ACTIVE
FROM   OAGWBG_SYSTEMMENU
WHERE  ID = 135 OR PARENTMENUID = 135
ORDER  BY NVL(PARENTMENUID, 0), SEQUENCE;


-- ---------------------------------------------------------------------
-- §2  DEPLOY + ตรวจในตัว (ถ้าตรวจไม่ผ่านจะ RAISE และ Oracle rollback ทั้ง block เอง)
-- ---------------------------------------------------------------------
DECLARE
  v_cnt NUMBER;
BEGIN
  UPDATE OAGWBG_SYSTEMMENU
  SET    SEQUENCE = 0, UPDATEBY = -1, UPDATEON = SYSTIMESTAMP
  WHERE  PARENTMENUID = 135 AND ACTIONNAME = 'RequestBudgettranferList';
  IF SQL%ROWCOUNT <> 1 THEN
    RAISE_APPLICATION_ERROR(-20001, 'RequestBudgettranferList ใต้ 135 อัปเดตได้ ' || SQL%ROWCOUNT || ' แถว (คาด 1)');
  END IF;

  UPDATE OAGWBG_SYSTEMMENU
  SET    SEQUENCE = 1, UPDATEBY = -1, UPDATEON = SYSTIMESTAMP
  WHERE  PARENTMENUID = 135 AND ACTIONNAME = 'BudgetTransferList';
  IF SQL%ROWCOUNT <> 1 THEN
    RAISE_APPLICATION_ERROR(-20002, 'BudgetTransferList ใต้ 135 อัปเดตได้ ' || SQL%ROWCOUNT || ' แถว (คาด 1)');
  END IF;

  -- ตรวจ: ลูกของ 135 ต้องไม่มี SEQUENCE ซ้ำ (ถ้ามีลูกตัวอื่นเพิ่มมาภายหลัง ลำดับจะกำกวม)
  SELECT COUNT(*) INTO v_cnt
  FROM  (SELECT SEQUENCE FROM OAGWBG_SYSTEMMENU WHERE PARENTMENUID = 135 GROUP BY SEQUENCE HAVING COUNT(*) > 1);
  IF v_cnt <> 0 THEN
    RAISE_APPLICATION_ERROR(-20003, 'ลูกของ 135 มี SEQUENCE ซ้ำ — ตรวจ §1');
  END IF;
END;
/


-- ---------------------------------------------------------------------
-- §3  VERIFY — คาดว่า SEQ 0 แจ้งการโอนเงินกลับ / SEQ 1 โอนเงินกลับ
-- ---------------------------------------------------------------------
SELECT ID, MENUNAME, PARENTMENUID, SEQUENCE, ACTIONNAME
FROM   OAGWBG_SYSTEMMENU
WHERE  PARENTMENUID = 135
ORDER  BY SEQUENCE;


-- ---------------------------------------------------------------------
-- §4  COMMIT / ROLLBACK
-- ---------------------------------------------------------------------
-- COMMIT;
-- ROLLBACK;


-- =====================================================================
-- §5  ROLLBACK หลัง COMMIT ไปแล้ว — คืนลำดับเดิม
-- =====================================================================
-- UPDATE OAGWBG_SYSTEMMENU SET SEQUENCE = 0, UPDATEBY = -1, UPDATEON = SYSTIMESTAMP
-- WHERE  PARENTMENUID = 135 AND ACTIONNAME = 'BudgetTransferList';
-- UPDATE OAGWBG_SYSTEMMENU SET SEQUENCE = 1, UPDATEBY = -1, UPDATEON = SYSTIMESTAMP
-- WHERE  PARENTMENUID = 135 AND ACTIONNAME = 'RequestBudgettranferList';
-- COMMIT;
