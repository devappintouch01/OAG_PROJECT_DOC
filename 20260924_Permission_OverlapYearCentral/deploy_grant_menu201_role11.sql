-- =====================================================================
-- DEPLOY: ให้ role "ศูนย์ต้นทุน" (ID 11) เห็นเมนู 201 "โอนงปม. เข้าบัญชีเงินกัน"
--
-- อาการ  : ศูนย์ต้นทุนเปิดเมนู "โอนงปม. เข้าบัญชีเงินกัน" ไม่เจอ (เมนูไม่ขึ้นเลย)
-- สาเหตุ : ไม่มีแถว (SYSTEMROLEID=11, SYSTEMMENUID=201) ใน OAGWBG_SYSTEMMENUROLEASSIGN
--          ปัจจุบันเมนู 201 ผูกไว้กับ role 1 / 31 / 61 เท่านั้น
-- ผลกระทบ: user ที่ถือ role 11 อย่างเดียว 822 คน
--
-- ประเภท : DML (ไม่แตะ schema)   Reversibility = R1
-- วันที่  : 2026-09-24
-- DB     : PREPROD 172.16.11.19:1541 / ebs_PRE / OAGWBG
--
-- ⛔ ยังไม่ถึงเวลารันสคริปต์นี้ (สถานะ ณ 2026-09-24)
--    เคยรันไปแล้วรอบหนึ่งวันนี้ (ID 307 เวลา 11:31:08) และ rollback ออกแล้ว
--    เพราะการเปิดเมนูโดยที่โค้ดยังไม่กรองตามศูนย์ต้นทุน ทำให้ role 11 (822 คน)
--    ไม่ใช่แค่ "เห็น" แต่ "กดบันทึกทับ" ใบของศูนย์ต้นทุนอื่นได้ด้วย
--      - ปุ่มบันทึกคุมด้วย isLocked/pageType ไม่ได้คุมด้วย role
--        (BudgetOverlapYearCentralDetail.cshtml:30, 440)
--      - SaveBudgetReservedCentrall ไม่มี guard เรื่อง role/ศูนย์ต้นทุน
--        (OAGBudget.API/Services/Repository/BudgetService.cs:33400)
--
--    เงื่อนไขก่อนรัน: BA ตอบ Q1-Q3 ใน README.md แล้ว และแก้โค้ดกรอง + คุมปุ่ม
--    + เพิ่ม guard ฝั่ง API เสร็จแล้วเท่านั้น — อ่าน README.md ให้จบก่อน
-- =====================================================================


-- ---------------------------------------------------------------------
-- §1  BEFORE — บันทึกสภาพก่อนแก้ไว้เทียบ
-- ---------------------------------------------------------------------
SELECT R.ID  AS ROLEID,
       R.ROLENAME,
       M.ID  AS MENUID,
       M.MENUNAME,
       CASE WHEN A.ID IS NULL THEN 'ไม่มีสิทธิ' ELSE 'มีสิทธิ' END AS STATE
FROM       OAGWBG_SYSTEMROLE R
CROSS JOIN OAGWBG_SYSTEMMENU M
LEFT JOIN  OAGWBG_SYSTEMMENUROLEASSIGN A
       ON  A.SYSTEMROLEID = R.ID AND A.SYSTEMMENUID = M.ID
WHERE M.ID IN (213, 35, 201, 215)     -- กันเงินเหลื่อมปี + ลูกทั้ง 3
ORDER BY R.ID, M.ID;
-- คาดว่าก่อนแก้: role 11 มีสิทธิ 213, 35 / ไม่มีสิทธิ 201, 215


-- ---------------------------------------------------------------------
-- §2  DEPLOY — เพิ่มสิทธิเมนู 201 ให้ role 11
--     * ใช้ MAX(ID)+1 เพราะแอป gen id แบบเดียวกัน และ
--       SEQ_SYSTEMMENUROLEASSIGN_ID หลุด sync (LAST_NUMBER=1 แต่ MAX(ID)=306)
--     * NOT EXISTS กันแถวซ้ำ เพราะตารางไม่มี unique constraint
--     * CREATEBY = -1 ตามแถวอื่นทั้งตาราง
-- ---------------------------------------------------------------------
INSERT INTO OAGWBG_SYSTEMMENUROLEASSIGN (ID, SYSTEMROLEID, SYSTEMMENUID, CREATEBY, CREATEON)
SELECT (SELECT NVL(MAX(ID), 0) + 1 FROM OAGWBG_SYSTEMMENUROLEASSIGN),
       11,
       201,
       -1,
       SYSTIMESTAMP
FROM DUAL
WHERE NOT EXISTS (
    SELECT 1 FROM OAGWBG_SYSTEMMENUROLEASSIGN
    WHERE SYSTEMROLEID = 11 AND SYSTEMMENUID = 201
);
-- คาดว่า: 1 row inserted


-- ---------------------------------------------------------------------
-- §3  VERIFY — ตรวจก่อน COMMIT
-- ---------------------------------------------------------------------

-- 3.1 ต้องได้ 1 แถวพอดี (ไม่ซ้ำ)
SELECT COUNT(*) AS SHOULD_BE_1
FROM OAGWBG_SYSTEMMENUROLEASSIGN
WHERE SYSTEMROLEID = 11 AND SYSTEMMENUID = 201;

-- 3.2 PK ต้องไม่ซ้ำทั้งตาราง
SELECT COUNT(*) AS DUP_PK_SHOULD_BE_0
FROM (SELECT ID FROM OAGWBG_SYSTEMMENUROLEASSIGN GROUP BY ID HAVING COUNT(*) > 1);

-- 3.3 ทดสอบผ่านฟังก์ชันจริงที่หน้าเว็บใช้ render เมนู
--     เลือก user ที่ถือ "role 11 อย่างเดียว" เพื่อไม่ให้ role อื่นบังผล
--     (user id 371 = username 58011 ถือ role 11 ตัวเดียว ณ 2026-09-24)
SELECT ID, MENUNAME, CONTROLLERNAME, ACTIONNAME, PARENTMENUID
FROM OAGWBG_FN_BOOKINGSYSTEMMENU(371, 2)
WHERE PARENTMENUID = 213 OR ID = 213
ORDER BY ID;
-- ก่อนแก้ ได้ 2 แถว: 35, 213
-- หลังแก้ ต้องได้ 3 แถว: 35, 201, 213

-- 3.4 ตรวจว่าไม่ได้เผลอไปกระทบ role อื่น — จำนวนสิทธิรวมของแต่ละ role
SELECT SYSTEMROLEID, COUNT(*) AS CNT
FROM OAGWBG_SYSTEMMENUROLEASSIGN
GROUP BY SYSTEMROLEID
ORDER BY SYSTEMROLEID;
-- ก่อนแก้ role 11 = 25 แถว → หลังแก้ต้องเป็น 26 แถว, role อื่นต้องเท่าเดิม


-- ---------------------------------------------------------------------
-- §4  COMMIT / ROLLBACK
-- ---------------------------------------------------------------------
-- COMMIT;
-- ROLLBACK;


-- =====================================================================
-- §5  ROLLBACK หลัง COMMIT ไปแล้ว
-- =====================================================================
-- DELETE FROM OAGWBG_SYSTEMMENUROLEASSIGN
-- WHERE SYSTEMROLEID = 11 AND SYSTEMMENUID = 201;
-- COMMIT;


-- =====================================================================
-- §6  (ทางเลือก) ถ้าต้องการให้ศูนย์ต้นทุนเห็นหน้า "พิจารณากันเงินเหลื่อมปี" (menu 215) ด้วย
--     ⚠️ ไม่แนะนำ — 215 คือหน้าพิจารณา/อนุมัติ ซึ่งตาม requirement เป็นของสำนักการคลัง
--        ใส่ไว้เป็นทางเลือกเฉย ๆ อย่ารันถ้า BA ไม่ได้สั่ง
-- =====================================================================
-- INSERT INTO OAGWBG_SYSTEMMENUROLEASSIGN (ID, SYSTEMROLEID, SYSTEMMENUID, CREATEBY, CREATEON)
-- SELECT (SELECT NVL(MAX(ID), 0) + 1 FROM OAGWBG_SYSTEMMENUROLEASSIGN), 11, 215, -1, SYSTIMESTAMP
-- FROM DUAL
-- WHERE NOT EXISTS (SELECT 1 FROM OAGWBG_SYSTEMMENUROLEASSIGN
--                   WHERE SYSTEMROLEID = 11 AND SYSTEMMENUID = 215);
