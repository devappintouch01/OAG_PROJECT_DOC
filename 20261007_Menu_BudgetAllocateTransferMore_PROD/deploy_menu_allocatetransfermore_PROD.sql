-- =====================================================================
-- DEPLOY: เพิ่มเมนู "โอนจัดสรรงบประมาณ เพิ่มเติม" บน PROD ให้เหมือน PREPROD
--
-- สภาพปัจจุบัน (ตรวจด้วย SELECT เมื่อ 2026-10-07)
--   PROD    : 137 "โอนเงินจัดสรรงบประมาณ" เป็นเมนูเดี่ยว ลิงก์ตรงไป Budget/BudgetAllocateTransferList (ISPARENT='0')
--             role ที่เห็น 137 = 1 (ผู้ดูแลระบบ1), 31 (สำนักบริหารงบประมาณ)
--   PREPROD : 137 เป็นเมนูแม่ (ISPARENT='1') มีลูก 2 ตัว
--               224 โอนจัดสรรงบประมาณ          SEQ 0 → Budget/BudgetAllocateTransferList
--               223 โอนจัดสรรงบประมาณ เพิ่มเติม SEQ 1 → Budget/BudgetAllocateTransferMoreList
--   หมายเหตุ: ID 221/222 ใน roadmap 20260608 ล้าสมัยแล้ว — ทั้ง 2 เครื่องเป็นเมนูรายงานไปแล้ว ห้ามใช้
--
-- สิ่งที่สคริปต์นี้ทำ
--   §2.1 เปลี่ยน 137 เป็นเมนูแม่ (ล้าง controller/action)
--   §2.2 เพิ่มลูก "โอนจัดสรรงบประมาณ" (หน้าเดิม ย้ายมาเป็นลูก)
--   §2.3 เพิ่มลูก "โอนจัดสรรงบประมาณ เพิ่มเติม"
--   §2.4 ให้ลูกทั้ง 2 ตัวมีสิทธิ role เดียวกับ 137 ตอนนี้ (1, 31) — คนที่เห็นเมนูเดิมยังเห็นหน้าเดิมเหมือนเดิม
--   role 11 (ศูนย์ต้นทุน) ไม่ได้ให้ — ถ้าต้องการให้เหมือน PREPROD ดู §6 (ต้องให้ BA ยืนยันก่อน)
--
-- ข้อเท็จจริงที่สคริปต์พึ่งพา (ตรวจแล้วบน PROD)
--   - ตาราง/view ของโอนจัดสรรเพิ่มเติมมีครบ VALID (สร้าง 2026-09-01) — กดเมนูแล้วไม่ควรเจอ ORA-00942
--   - OAGWBG_SYSTEMMENU / OAGWBG_SYSTEMMENUROLEASSIGN ไม่มี trigger → ID ที่ใส่คือ ID จริง
--   - ใช้ MAX(ID)+1 เหมือนที่แอป gen (SEQ ของ roleassign หลุด sync) ; ตารางไม่มี unique constraint จึงกันซ้ำด้วย NOT EXISTS
--   - Default.cshtml เช็ค Isparent == "1" เฉพาะเมนูระดับบนสุด ลูกแสดงเป็นลิงก์เสมอ → ลูกใช้ '0' ตามแถวลูกอื่นบน PROD
--   - OAGWBG_FN_BOOKINGSYSTEMMENU กรอง ACTIVE = '1' และ ISSHOWINSITEMENU = '1' และต้องมีแถวใน ROLEASSIGN
--   - สิทธิเข้าหน้า (URL) ไม่ได้อ่านจากตารางเมนู → ย้าย 137 เป็นแม่ไม่ทำให้ใครเข้า BudgetAllocateTransferList ไม่ได้
--
-- สมมติฐานที่ยังไม่ได้ตรวจ: เว็บที่ deploy บน PROD มี action Budget/BudgetAllocateTransferMoreList แล้ว
--
-- ประเภท : DML (ไม่แตะ schema)   Reversibility = R1 (มี rollback §5)
-- DB     : PROD 172.16.11.18:1531 / PROD / OAGWBG
-- วิธีรัน : SQL Developer รันทีละ section — §2 แล้วดู §3 ให้ผ่านก่อน ค่อย COMMIT ใน §4
-- =====================================================================


-- ---------------------------------------------------------------------
-- §1  BEFORE — บันทึกสภาพก่อนแก้
-- ---------------------------------------------------------------------
SELECT ID, MENUNAME, PARENTMENUID, SEQUENCE, CONTROLLERNAME, ACTIONNAME, ISPARENT, ACTIVE, ISSHOWINSITEMENU
FROM   OAGWBG_SYSTEMMENU
WHERE  ID = 137 OR PARENTMENUID = 137 OR ACTIONNAME LIKE 'BudgetAllocateTransfer%'
ORDER  BY ID;
-- คาดว่า: 1 แถว — 137 | โอนเงินจัดสรรงบประมาณ | (null) | 9 | Budget | BudgetAllocateTransferList | 0 | 1 | 1

SELECT SYSTEMROLEID, SYSTEMMENUID FROM OAGWBG_SYSTEMMENUROLEASSIGN WHERE SYSTEMMENUID = 137 ORDER BY 1;
-- คาดว่า: role 1, 31

SELECT (SELECT MAX(ID) FROM OAGWBG_SYSTEMMENU) AS MAX_MENU,
       (SELECT MAX(ID) FROM OAGWBG_SYSTEMMENUROLEASSIGN) AS MAX_ASSIGN
FROM   DUAL;
-- ณ 2026-10-07 15:xx: MAX_MENU = 222, MAX_ASSIGN = 306
-- ⚠️ 2026-10-07 16:09 มีการรัน §2.3 + §2.4 ไปแล้วบางส่วน (เห็นจาก session อื่น — committed):
--     223 = "โอนจัดสรรงบประมาณ เพิ่มเติม" (ลูกของ 137) + roleassign 307 (role 1), 308 (role 31)
--     แต่ §2.1 (137 เป็นแม่) และ §2.2 (ลูก "โอนจัดสรรงบประมาณ") ยังไม่เกิด
--     → รันทั้งไฟล์ซ้ำได้ เพราะทุกคำสั่งกันซ้ำไว้: 2.3 จะได้ 0 rows, 2.2 จะได้ ID 224, 2.4 จะเพิ่มแค่ 2 แถวของ 224
--     ⛔ ห้ามรัน 2.1 โดยไม่รัน 2.2 + 2.4 ตามทันที — role 31 จะเหลือแค่ "เพิ่มเติม" ไม่มีลิงก์หน้าโอนจัดสรรเดิม


-- ---------------------------------------------------------------------
-- §2  DEPLOY
-- ---------------------------------------------------------------------

-- 2.1 เปลี่ยน 137 เป็นเมนูแม่ — WHERE ล็อกสภาพเดิมไว้ ถ้ามีคนแก้ไปแล้วจะได้ 0 rows (ให้หยุดตรวจก่อน)
UPDATE OAGWBG_SYSTEMMENU
SET    ISPARENT       = '1',
       CONTROLLERNAME = NULL,
       ACTIONNAME     = NULL,
       UPDATEBY       = -1,
       UPDATEON       = SYSTIMESTAMP
WHERE  ID = 137
AND    ISPARENT = '0'
AND    ACTIONNAME = 'BudgetAllocateTransferList';
-- คาดว่า: 1 row updated

-- 2.2 ลูก: โอนจัดสรรงบประมาณ (หน้าเดิม)
INSERT INTO OAGWBG_SYSTEMMENU
  (ID, ACTIVE, MENUNAME, CONTROLLERNAME, ACTIONNAME, CONTROLLERMAINNAME,
   SEQUENCE, ISPARENT, PARENTMENUID, ISSHOWINSITEMENU, SYSTEMMENUGROUPID, SYSTEMNAMEID,
   CREATEBY, CREATEON)
SELECT (SELECT NVL(MAX(ID), 0) + 1 FROM OAGWBG_SYSTEMMENU),
       '1', 'โอนจัดสรรงบประมาณ', 'Budget', 'BudgetAllocateTransferList', 'Budget',
       0, '0', 137, '1', 2, 2,
       -1, SYSTIMESTAMP
FROM   DUAL
WHERE  NOT EXISTS (SELECT 1 FROM OAGWBG_SYSTEMMENU
                   WHERE PARENTMENUID = 137 AND ACTIONNAME = 'BudgetAllocateTransferList');
-- คาดว่า: 1 row inserted (ID = MAX+1)

-- 2.3 ลูก: โอนจัดสรรงบประมาณ เพิ่มเติม
INSERT INTO OAGWBG_SYSTEMMENU
  (ID, ACTIVE, MENUNAME, CONTROLLERNAME, ACTIONNAME, CONTROLLERMAINNAME,
   SEQUENCE, ISPARENT, PARENTMENUID, ISSHOWINSITEMENU, SYSTEMMENUGROUPID, SYSTEMNAMEID,
   CREATEBY, CREATEON)
SELECT (SELECT NVL(MAX(ID), 0) + 1 FROM OAGWBG_SYSTEMMENU),
       '1', 'โอนจัดสรรงบประมาณ เพิ่มเติม', 'Budget', 'BudgetAllocateTransferMoreList', 'Budget',
       1, '0', 137, '1', 2, 2,
       -1, SYSTIMESTAMP
FROM   DUAL
WHERE  NOT EXISTS (SELECT 1 FROM OAGWBG_SYSTEMMENU
                   WHERE PARENTMENUID = 137 AND ACTIONNAME = 'BudgetAllocateTransferMoreList');
-- คาดว่า: 1 row inserted (ID = MAX+1) — หรือ 0 rows ถ้ามีเมนูนี้อยู่แล้ว (ตามสภาพ 16:09 จะได้ 0)

-- 2.4 สิทธิ: ลูกทั้ง 2 ตัว × role ที่เห็น 137 อยู่ตอนนี้ (1, 31)
INSERT INTO OAGWBG_SYSTEMMENUROLEASSIGN (ID, SYSTEMROLEID, SYSTEMMENUID, CREATEBY, CREATEON)
SELECT (SELECT NVL(MAX(ID), 0) FROM OAGWBG_SYSTEMMENUROLEASSIGN) + ROWNUM,
       X.SYSTEMROLEID, X.MENUID, -1, SYSTIMESTAMP
FROM  (SELECT R.SYSTEMROLEID, M.ID AS MENUID
       FROM   (SELECT DISTINCT SYSTEMROLEID FROM OAGWBG_SYSTEMMENUROLEASSIGN WHERE SYSTEMMENUID = 137) R
       CROSS  JOIN (SELECT ID FROM OAGWBG_SYSTEMMENU WHERE PARENTMENUID = 137) M
       WHERE  NOT EXISTS (SELECT 1 FROM OAGWBG_SYSTEMMENUROLEASSIGN A
                          WHERE A.SYSTEMROLEID = R.SYSTEMROLEID AND A.SYSTEMMENUID = M.ID)
       ORDER  BY M.ID, R.SYSTEMROLEID) X;
-- คาดว่า: 4 rows inserted ถ้ารันจากศูนย์ / 2 rows ถ้า 223 มีสิทธิอยู่แล้ว (สภาพ 16:09)
-- ผลสุดท้ายต้องเป็น role 1, 31 × ลูกทั้ง 2 ตัว ครบ 4 แถว — ดู §3.2


-- ---------------------------------------------------------------------
-- §3  VERIFY — ตรวจก่อน COMMIT
-- ---------------------------------------------------------------------

-- 3.1 โครงเมนู — ต้องได้ 3 แถว: 137 แม่ (ISPARENT 1, ไม่มี action) + ลูก 2 ตัว SEQ 0 / 1
SELECT ID, MENUNAME, PARENTMENUID, SEQUENCE, CONTROLLERNAME, ACTIONNAME, ISPARENT, ACTIVE, ISSHOWINSITEMENU
FROM   OAGWBG_SYSTEMMENU
WHERE  ID = 137 OR PARENTMENUID = 137
ORDER  BY NVL(PARENTMENUID, 0), SEQUENCE;

-- 3.2 สิทธิ — ต้องได้ 6 แถว: role 1, 31 × (137 + ลูก 2 ตัว)
SELECT A.SYSTEMMENUID, M.MENUNAME, A.SYSTEMROLEID, R.ROLENAME
FROM   OAGWBG_SYSTEMMENUROLEASSIGN A
JOIN   OAGWBG_SYSTEMMENU M ON M.ID = A.SYSTEMMENUID
LEFT   JOIN OAGWBG_SYSTEMROLE R ON R.ID = A.SYSTEMROLEID
WHERE  A.SYSTEMMENUID = 137 OR M.PARENTMENUID = 137
ORDER  BY A.SYSTEMMENUID, A.SYSTEMROLEID;

-- 3.3 PK ต้องไม่ซ้ำ — ต้องได้ 0 ทั้งคู่
SELECT (SELECT COUNT(*) FROM (SELECT ID FROM OAGWBG_SYSTEMMENU GROUP BY ID HAVING COUNT(*) > 1)) AS DUP_MENU,
       (SELECT COUNT(*) FROM (SELECT ID FROM OAGWBG_SYSTEMMENUROLEASSIGN GROUP BY ID HAVING COUNT(*) > 1)) AS DUP_ASSIGN
FROM   DUAL;

-- 3.4 ผ่านฟังก์ชันจริงที่เว็บใช้ render เมนู — user แรกของ role 31 (สำนักบริหารงบประมาณ)
--     ก่อนแก้ได้ 1 แถว (137 ลิงก์ BudgetAllocateTransferList) → หลังแก้ต้องได้ 3 แถว: 137 + ลูก SEQ 0 / 1
--     (role 1 ไม่ได้ทดสอบ เพราะ ณ 2026-10-07 บน PROD ไม่มี user ถือ role 1 เลย)
SELECT F.ID, F.MENUNAME, F.PARENTMENUID, F.SEQUENCE, F.ACTIONNAME
FROM   OAGWBG_FN_BOOKINGSYSTEMMENU(
         (SELECT MIN(U.ID)
          FROM   OAGWBG_SYSTEMUSERROLEASSIGN A
          JOIN   OAGWBG_SYSTEMUSER U ON U.ID = A.SYSTEMUSERID
          WHERE  A.SYSTEMROLEID = 31), 2) F
WHERE  F.ID = 137 OR F.PARENTMENUID = 137
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
-- WHERE  SYSTEMMENUID IN (SELECT ID FROM OAGWBG_SYSTEMMENU WHERE PARENTMENUID = 137);
--
-- DELETE FROM OAGWBG_SYSTEMMENU WHERE PARENTMENUID = 137;
--
-- UPDATE OAGWBG_SYSTEMMENU
-- SET    ISPARENT = '0', CONTROLLERNAME = 'Budget', ACTIONNAME = 'BudgetAllocateTransferList',
--        UPDATEBY = -1, UPDATEON = SYSTIMESTAMP
-- WHERE  ID = 137;
--
-- COMMIT;


-- =====================================================================
-- §6  (ทางเลือก — ต้องให้ BA ยืนยันก่อน) ให้ role 11 ศูนย์ต้นทุน เห็นเมนูเพิ่มเติม เหมือน PREPROD
--     PREPROD ใส่ role 11 ที่ 137 + เพิ่มเติม (ไม่ใส่ที่ "โอนจัดสรรงบประมาณ") เมื่อ 2026-10-02
--     PROD มี user ที่ถือ role 11 อย่างเดียว 814 คน — ตอนนี้ยังไม่เห็นเมนู 137 เลย
-- =====================================================================
-- INSERT INTO OAGWBG_SYSTEMMENUROLEASSIGN (ID, SYSTEMROLEID, SYSTEMMENUID, CREATEBY, CREATEON)
-- SELECT (SELECT NVL(MAX(ID), 0) FROM OAGWBG_SYSTEMMENUROLEASSIGN) + ROWNUM, 11, X.ID, -1, SYSTIMESTAMP
-- FROM  (SELECT ID FROM OAGWBG_SYSTEMMENU
--        WHERE  (ID = 137 OR (PARENTMENUID = 137 AND ACTIONNAME = 'BudgetAllocateTransferMoreList'))
--        AND    NOT EXISTS (SELECT 1 FROM OAGWBG_SYSTEMMENUROLEASSIGN A
--                           WHERE A.SYSTEMROLEID = 11 AND A.SYSTEMMENUID = OAGWBG_SYSTEMMENU.ID)
--        ORDER  BY ID) X;
-- -- คาดว่า: 2 rows inserted
-- COMMIT;
