-- =====================================================================
-- FIX: เมนูลูกของ 137 "โอนเงินจัดสรรงบประมาณ" เรียงสลับกันบน PROD
--
-- อาการ  : "โอนจัดสรรงบประมาณ เพิ่มเติม" ขึ้นก่อน "โอนจัดสรรงบประมาณ"
-- สาเหตุ : 224 ถูก insert เมื่อ 2026-10-07 16:14:15 ด้วย SEQUENCE = 2 (script ตั้งไว้ 0)
--          CategoryMenu.cs:61 เรียงด้วย OrderBy(Sequence) → 223 (SEQ 1) ขึ้นก่อน 224 (SEQ 2)
-- ที่ถูก : เหมือน PREPROD — 224 โอนจัดสรรงบประมาณ SEQ 0 / 223 เพิ่มเติม SEQ 1
--
-- ประเภท : DML 1 แถว   Reversibility = R2
-- DB     : PROD 172.16.11.18:1531 / PROD / OAGWBG
-- =====================================================================

-- §1 BEFORE — คาดว่า: 223 SEQ 1 / 224 SEQ 2
SELECT ID, MENUNAME, SEQUENCE, ACTIONNAME
FROM   OAGWBG_SYSTEMMENU
WHERE  PARENTMENUID = 137
ORDER  BY SEQUENCE;

-- §2 FIX — WHERE ล็อกสภาพเดิมไว้ คาดว่า: 1 row updated
UPDATE OAGWBG_SYSTEMMENU
SET    SEQUENCE = 0,
       UPDATEBY = -1,
       UPDATEON = SYSTIMESTAMP
WHERE  ID = 224
AND    PARENTMENUID = 137
AND    ACTIONNAME = 'BudgetAllocateTransferList'
AND    SEQUENCE = 2;

-- §3 VERIFY — ต้องได้ 224 โอนจัดสรรงบประมาณ (SEQ 0) ก่อน 223 เพิ่มเติม (SEQ 1)
SELECT ID, MENUNAME, SEQUENCE, ACTIONNAME
FROM   OAGWBG_SYSTEMMENU
WHERE  PARENTMENUID = 137
ORDER  BY SEQUENCE;

-- §4
-- COMMIT;
-- ROLLBACK;
-- หลัง COMMIT ให้ผู้ใช้ logout/login ใหม่ (เมนูโหลดตอน login)

-- §5 ROLLBACK หลัง COMMIT
-- UPDATE OAGWBG_SYSTEMMENU SET SEQUENCE = 2, UPDATEBY = -1, UPDATEON = SYSTIMESTAMP WHERE ID = 224;
-- COMMIT;
