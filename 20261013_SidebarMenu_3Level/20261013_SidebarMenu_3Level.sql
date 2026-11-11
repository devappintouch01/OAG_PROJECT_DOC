-- =====================================================================
-- Sidebar เมนู 3 ชั้น : แบ่งกลุ่มรายงานใต้ "รายงาน" (ID 153) เป็น 7 กลุ่ม
-- วันที่ : 2026-10-13
-- เอกสารประกอบ : _sidebarMenu3Level.md (โฟลเดอร์เดียวกัน)
--
-- ⚠️ ลำดับ deploy : ต้อง deploy โค้ด (CategoryMenu.cs, Default.cshtml,
--    _tableSystemMenuRoleAssignManage.cshtml) ขึ้น environment นั้นก่อน
--    ถ้ารันสคริปต์นี้กับโค้ดเดิม (วาดได้แค่ 2 ชั้น) รายงานทั้ง 18 ตัวจะหายจาก sidebar
--
-- ⚠️ ID : ตารางนี้ gen ID ด้วย MAX(ID)+1 — SEQ_SYSTEMMENU_ID / SEQ_SYSTEMMENUROLEASSIGN_ID
--    ไม่เคยถูกใช้ (LAST_NUMBER = 1) ห้ามใช้ NEXTVAL จะชน ID 1
-- =====================================================================


-- ---------------------------------------------------------------------
-- §0 PRE-CHECK (ต้องได้ตามที่ระบุ ไม่งั้นหยุด)
-- ---------------------------------------------------------------------
-- 0.1 รายงานทั้ง 18 ตัวต้องอยู่ใต้ 153  → ต้องได้ 18
SELECT COUNT(*) AS N_UNDER_153
FROM   OAGWBG_SYSTEMMENU
WHERE  PARENTMENUID = 153
AND    ID IN (187,190,222,221,191,208, 218,220, 192,207, 193,189,210,216,217, 194, 195, 188);

-- 0.2 ยังไม่เคยรันมาก่อน  → ต้องได้ 0
SELECT COUNT(*) AS N_GROUP_EXISTS
FROM   OAGWBG_SYSTEMMENU
WHERE  PARENTMENUID = 153 AND CONTROLLERNAME IS NULL;


-- ---------------------------------------------------------------------
-- §1 APPLY  (ไม่มี COMMIT ในบล็อก — ตรวจ §2 ก่อนแล้วค่อย COMMIT เอง)
-- ---------------------------------------------------------------------
DECLARE
  C_ROOT CONSTANT NUMBER := 153;   -- เมนู "รายงาน"
  V_EXISTS NUMBER;

  PROCEDURE ADD_GROUP(P_NAME VARCHAR2, P_SEQ NUMBER, P_CHILDREN SYS.ODCINUMBERLIST) IS
    V_GID NUMBER;
  BEGIN
    SELECT NVL(MAX(ID), 0) + 1 INTO V_GID FROM OAGWBG_SYSTEMMENU;

    -- แถวกลุ่ม : ไม่มี Controller/Action (sidebar ใช้ "มีลูก" ตัดสินว่าเป็นกลุ่ม)
    INSERT INTO OAGWBG_SYSTEMMENU
      (ID, CREATEBY, CREATEON, ACTIVE, MENUNAME, SEQUENCE, ISPARENT, PARENTMENUID,
       ISSHOWINSITEMENU, SYSTEMMENUGROUPID, SYSTEMNAMEID)
    VALUES
      (V_GID, -1, SYSTIMESTAMP, '1', P_NAME, P_SEQ, '1', C_ROOT,
       '1', 2, 2);

    -- ย้ายรายงานเข้ากลุ่ม + เรียงลำดับตามรายการที่ส่งมา
    FOR I IN 1 .. P_CHILDREN.COUNT LOOP
      UPDATE OAGWBG_SYSTEMMENU
         SET PARENTMENUID = V_GID, SEQUENCE = I, UPDATEBY = -1, UPDATEON = SYSTIMESTAMP
       WHERE ID = P_CHILDREN(I) AND PARENTMENUID = C_ROOT;
      IF SQL%ROWCOUNT <> 1 THEN
        RAISE_APPLICATION_ERROR(-20001, 'เมนู ID ' || P_CHILDREN(I) || ' ไม่ได้อยู่ใต้ ' || C_ROOT);
      END IF;
    END LOOP;

    -- สิทธิ์ของกลุ่ม : FN_BOOKINGSYSTEMMENU กรองสิทธิ์รายแถว กลุ่มจึงต้องมีแถว assign ของตัวเอง
    -- ให้เฉพาะ role ที่มีสิทธิ์ลูกในกลุ่มอย่างน้อย 1 ตัว และ role ต้องมีอยู่จริง (ตัด 9931 ที่ค้าง)
    INSERT INTO OAGWBG_SYSTEMMENUROLEASSIGN (ID, SYSTEMROLEID, SYSTEMMENUID, CREATEBY, CREATEON)
    SELECT (SELECT NVL(MAX(ID), 0) FROM OAGWBG_SYSTEMMENUROLEASSIGN) + ROWNUM,
           R.SYSTEMROLEID, V_GID, -1, SYSTIMESTAMP
    FROM  (SELECT DISTINCT RA.SYSTEMROLEID
           FROM   OAGWBG_SYSTEMMENUROLEASSIGN RA
           JOIN   OAGWBG_SYSTEMROLE SR ON SR.ID = RA.SYSTEMROLEID
           WHERE  RA.SYSTEMMENUID IN (SELECT COLUMN_VALUE FROM TABLE(P_CHILDREN))) R;
  END;

BEGIN
  SELECT COUNT(*) INTO V_EXISTS
  FROM   OAGWBG_SYSTEMMENU
  WHERE  PARENTMENUID = C_ROOT AND CONTROLLERNAME IS NULL;
  IF V_EXISTS > 0 THEN
    RAISE_APPLICATION_ERROR(-20000, 'มีกลุ่มใต้ ' || C_ROOT || ' อยู่แล้ว — สคริปต์นี้เคยรันแล้ว');
  END IF;

  ADD_GROUP('คำของบประมาณประจำปี',                 1, SYS.ODCINUMBERLIST(187, 190, 222, 221, 191, 208));
  ADD_GROUP('คำขอเพิ่มเติม',                        2, SYS.ODCINUMBERLIST(218, 220));
  ADD_GROUP('แผนการใช้จ่ายงบประมาณ',               3, SYS.ODCINUMBERLIST(192, 207));
  ADD_GROUP('โอนเงินจัดสรร',                        4, SYS.ODCINUMBERLIST(193, 189, 210, 216, 217));
  ADD_GROUP('การติดตามการใช้จ่ายและบริหารงบประมาณ', 5, SYS.ODCINUMBERLIST(194));
  ADD_GROUP('กันเงินเหลื่อมปี',                     6, SYS.ODCINUMBERLIST(195));
  ADD_GROUP('บันทึกรับเงินนอกงบประมาณ',            7, SYS.ODCINUMBERLIST(188));
END;
/


-- ---------------------------------------------------------------------
-- §2 VERIFY (ก่อน COMMIT)
-- ---------------------------------------------------------------------
-- 2.1 โครงสร้าง : ใต้ 153 ต้องเหลือ 7 กลุ่ม, รายงาน 18 ตัวอยู่ในกลุ่ม
SELECT LPAD(' ', 2 * (LEVEL - 1)) || MENUNAME AS MENU, ID, PARENTMENUID, SEQUENCE
FROM   OAGWBG_SYSTEMMENU
START WITH ID = 153
CONNECT BY PRIOR ID = PARENTMENUID
ORDER SIBLINGS BY SEQUENCE, ID;

-- 2.2 สิทธิ์ : ทุก role ที่เห็นรายงานในกลุ่ม ต้องเห็นกลุ่มด้วย  → ต้องได้ 0 แถว
SELECT RA.SYSTEMROLEID, M.ID AS REPORT_ID, M.PARENTMENUID AS GROUP_ID
FROM   OAGWBG_SYSTEMMENUROLEASSIGN RA
JOIN   OAGWBG_SYSTEMMENU M  ON M.ID = RA.SYSTEMMENUID
JOIN   OAGWBG_SYSTEMMENU G  ON G.ID = M.PARENTMENUID AND G.PARENTMENUID = 153
JOIN   OAGWBG_SYSTEMROLE SR ON SR.ID = RA.SYSTEMROLEID
WHERE  NOT EXISTS (SELECT 1 FROM OAGWBG_SYSTEMMENUROLEASSIGN X
                   WHERE X.SYSTEMROLEID = RA.SYSTEMROLEID AND X.SYSTEMMENUID = G.ID);

-- 2.3 ไม่มี ID ซ้ำใน role assign  → ต้องได้ 0
SELECT COUNT(*) AS DUP FROM (
  SELECT SYSTEMROLEID, SYSTEMMENUID FROM OAGWBG_SYSTEMMENUROLEASSIGN
  GROUP BY SYSTEMROLEID, SYSTEMMENUID HAVING COUNT(*) > 1);

-- ผ่านทั้งหมด → COMMIT;   ไม่ผ่าน → ROLLBACK;


-- ---------------------------------------------------------------------
-- §3 ROLLBACK SCRIPT (หลัง COMMIT ไปแล้ว) — คืนค่า PARENTMENUID / SEQUENCE เดิม
-- ---------------------------------------------------------------------
/*
DELETE FROM OAGWBG_SYSTEMMENUROLEASSIGN
WHERE  SYSTEMMENUID IN (SELECT ID FROM OAGWBG_SYSTEMMENU WHERE PARENTMENUID = 153 AND CONTROLLERNAME IS NULL);

UPDATE OAGWBG_SYSTEMMENU
   SET PARENTMENUID = 153,
       SEQUENCE = CASE ID WHEN 187 THEN 1  WHEN 188 THEN 2  WHEN 190 THEN 3  WHEN 191 THEN 4
                          WHEN 192 THEN 5  WHEN 193 THEN 6  WHEN 189 THEN 7  WHEN 194 THEN 8
                          WHEN 195 THEN 9  WHEN 207 THEN 10 WHEN 208 THEN 11 WHEN 210 THEN 12
                          WHEN 216 THEN 13 WHEN 217 THEN 14 WHEN 218 THEN 15 WHEN 220 THEN 16
                          WHEN 221 THEN 17 WHEN 222 THEN 18 END,
       UPDATEBY = -1, UPDATEON = SYSTIMESTAMP
 WHERE ID IN (187,188,189,190,191,192,193,194,195,207,208,210,216,217,218,220,221,222);

DELETE FROM OAGWBG_SYSTEMMENU WHERE PARENTMENUID = 153 AND CONTROLLERNAME IS NULL;

COMMIT;
*/
