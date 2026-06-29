-- =============================================================================
-- INSERT เมนู "หน่วยนับ" และกำหนดสิทธิ์ Role ผู้ดูแลระบบ
-- ค่าทั้งหมด query มาจาก DB จริง (2026-06-29)
--
--   Admin Role ID     = 1  (ผู้ดูแลระบบ1, Rolelevel=200)
--   Parent Menu ID    = 69 (เมนูกลุ่ม Master)
--   New SYSTEMMENU.ID = 225  (MAX=224 + 1)
--   New ROLEASSIGN.ID = 300  (MAX=299 + 1)
--   SEQUENCE          = 16   (Last item: Log Interface, SEQ=15)
--   SYSTEMMENUGROUPID = 2
--   SYSTEMNAMEID      = 2
-- =============================================================================

-- 1. INSERT เมนู
INSERT INTO OAGWBG_SYSTEMMENU
  (ID, ACTIVE, MENUNAME, MENUDESCRIPTION, URL,
   ACTIONNAME, CONTROLLERNAME, CONTROLLERMAINNAME,
   SEQUENCE, ISPARENT, PARENTMENUID, ISSHOWINSITEMENU,
   SYSTEMMENUGROUPID, SYSTEMNAMEID,
   CREATEBY, CREATEON)
VALUES
  (225, '1', 'หน่วยนับ', 'จัดการ Master หน่วยนับ', '/Master/MasterUnit',
   'MasterUnit', 'Master', 'Master',
   16, '0', 69, '1',
   2, 2,
   1, SYSDATE);

-- 2. กำหนดสิทธิ์ Role ผู้ดูแลระบบ (ID=1)
INSERT INTO OAGWBG_SYSTEMMENUROLEASSIGN
  (ID, SYSTEMROLEID, SYSTEMMENUID, CREATEBY, CREATEON)
VALUES
  (300, 1, 225, 1, SYSDATE);

COMMIT;

-- 3. ยืนยันผล
SELECT M.ID, M.MENUNAME, M.URL, M.ACTIVE, R.SYSTEMROLEID, SR.ROLENAME
FROM   OAGWBG_SYSTEMMENU M
JOIN   OAGWBG_SYSTEMMENUROLEASSIGN R ON R.SYSTEMMENUID = M.ID
JOIN   OAGWBG_SYSTEMROLE SR ON SR.ID = R.SYSTEMROLEID
WHERE  M.URL = '/Master/MasterUnit';
