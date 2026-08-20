-- =============================================================================
-- OAGWBG_FN_GETMENU_PERMISSION
-- ฟังก์ชันสำหรับหน้า "จัดการสิทธิ์การใช้งานเมนู" (System/PermissionDetail)
--
-- สถานะ : *** สร้างขึ้นใหม่ (reconstructed) *** — ของเดิมไม่มีอยู่บน DB
--          ตรวจแล้วบน PREPROD (172.16.11.19:1541 / ebs_PRE / OAGWBG) 2026-08-20
--          ALL_OBJECTS ไม่มี object ชื่อนี้เลย (มีแต่ OAGWBG_FN_GETSYSTEMMENUROLEASSIGN
--          และ OAGWBG_FN_BOOKINGSYSTEMMENU)
--
-- อ้างอิงเหตุผลการออกแบบทั้งหมด (อะไรแน่ชัด / อะไรเดา) : _brain/_menuPermission.md
--
-- ผู้เรียกใช้ในโค้ด :
--   OAGBudget.API/Services/Repository/SystemService.cs:167
--   OAGBudget.API/Controllers/SystemController.cs:209
--   ทั้งสองที่เรียกด้วย  Select * from OAGWBG_FN_GETMENU_PERMISSION({SystemRoleId})
--   แล้ว map ลง C# class OAGBudget.Models.RawData.OagwbgFnGetMenuPermission
--   => ชื่อคอลัมน์ที่ pipe ออกมา ต้องตรงกับชื่อ property ทุกตัว (case-insensitive)
--
-- DB : Oracle 19c (19.25) — รองรับ SELECT * FROM fn(x) โดยไม่ต้องใส่ TABLE()
-- Schema owner = OAGWBG (แอปเชื่อมต่อด้วย user OAGWBG เอง จึงไม่ต้อง GRANT)
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1) OBJECT TYPE — 1 attribute ต่อ 1 property ของ OagwbgFnGetMenuPermission
--    ลำดับ attribute เรียงตามลำดับ property ในไฟล์ C# (EF map ด้วย "ชื่อ" ไม่ใช่ลำดับ
--    แต่เรียงให้ตรงกันไว้เพื่ออ่านง่าย)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TYPE OAGWBG.OAGWBG_MENUPERMISSION_OBJ AS OBJECT (
  ID                NUMBER,          -- = OAGWBG_SYSTEMMENU.ID  (ใช้ save เป็น SYSTEMMENUID)
  MENUID            NUMBER,          -- (ไม่แน่ชัด) ให้ค่าเดียวกับ ID
  MENUNAME          VARCHAR2(4000),  -- ตามความยาวจริงของ OAGWBG_SYSTEMMENU.MENUNAME
  CONTROLLERNAME    VARCHAR2(100),
  ACTIONNAME        VARCHAR2(100),
  SEQUENCE          NUMBER,
  ACTIVE            CHAR(1),
  ISSHOWINSITEMENU  CHAR(1),
  NODEID            NUMBER,          -- (ไม่แน่ชัด) node ของ simpleTreeTable = ID
  PARENTID          NUMBER,          -- = PARENTMENUID (NULL = เมนูระดับบน)
  CODE              VARCHAR2(255),   -- (ไม่แน่ชัด) CONTROLLERNAME/ACTIONNAME
  ISPERMISSION      NUMBER           -- 1 = role นี้มีสิทธิ์เมนูนี้, 0 = ไม่มี
);
/

CREATE OR REPLACE TYPE OAGWBG.OAGWBG_MENUPERMISSION_TAB
  AS TABLE OF OAGWBG.OAGWBG_MENUPERMISSION_OBJ;
/


-- -----------------------------------------------------------------------------
-- 2) FUNCTION
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION OAGWBG.OAGWBG_FN_GETMENU_PERMISSION (
  P_SYSTEMROLEID IN NUMBER DEFAULT NULL
)
RETURN OAGWBG.OAGWBG_MENUPERMISSION_TAB PIPELINED
AS
BEGIN
  FOR R IN (
    WITH MENUS AS (
      /* ชุดเมนูที่ "มีสิทธิ์ปรากฏบนหน้าจัดการสิทธิ์"
         - ACTIVE = '1'  : ตามฟังก์ชันพี่น้อง OAGWBG_FN_GETSYSTEMMENUROLEASSIGN
                           และ OAGWBG_FN_BOOKINGSYSTEMMENU (ปัจจุบันมี 1 แถวที่ ACTIVE='0'
                           คือ ID=170 ReportBudgetAdjust ซึ่งจะถูกตัดออก)
         - ไม่กรอง ISSHOWINSITEMENU เพราะคอลัมน์นี้ถูกส่งกลับเป็นข้อมูลให้ฝั่ง client
           (ข้อมูลจริงตอนนี้ทุกแถว = '1' จึงไม่มีผลต่างกันเลย — ดู §4.2 ในเอกสาร)
           ถ้าต้องการให้เหมือนฟังก์ชันเดิมเป๊ะ ให้เปิดบรรทัดล่างนี้ */
      SELECT M.*
      FROM   OAGWBG.OAGWBG_SYSTEMMENU M
      WHERE  M.ACTIVE = '1'
      --  AND M.ISSHOWINSITEMENU = '1'
    )
    SELECT *
    FROM (
      SELECT
          SM.ID                                    AS ID,
          SM.ID                                    AS MENUID,
          SM.MENUNAME                              AS MENUNAME,
          SM.CONTROLLERNAME                        AS CONTROLLERNAME,
          SM.ACTIONNAME                            AS ACTIONNAME,
          SM.SEQUENCE                              AS SEQUENCE,
          SM.ACTIVE                                AS ACTIVE,
          SM.ISSHOWINSITEMENU                      AS ISSHOWINSITEMENU,
          SM.ID                                    AS NODEID,
          /* ORPHAN-SAFE : ถ้าแถวแม่ไม่อยู่ในชุดผลลัพธ์ (เช่น PARENTMENUID = 999 ซึ่งไม่มีจริง
             หรือแม่ถูกตัดเพราะ ACTIVE='0') ให้ดันขึ้นมาเป็นเมนูระดับบนแทน
             มิฉะนั้น _tableSystemMenuRoleAssignManage.cshtml จะไม่ render แถวนั้นเลย
             (view วน parent = ParentId IS NULL แล้ว child = ParentId == parent.Id เท่านั้น)
             ปัจจุบันมี 7 แถวเข้าเงื่อนไขนี้ : 164,165,167,168,171,172,173
             --- ถ้าต้องการพฤติกรรม "ตรงตามข้อมูลดิบ" ให้เปลี่ยนบรรทัดนี้เป็น
                 SM.PARENTMENUID AS PARENTID
                 (ผลคือ 7 เมนูนั้นจะหายไปจากหน้าจอ = แก้สิทธิ์ไม่ได้) */
          CASE WHEN PM.ID IS NULL THEN NULL ELSE SM.PARENTMENUID END AS PARENTID,
          NVL(SM.CONTROLLERNAME, '-') || '/' || NVL(SM.ACTIONNAME, '-') AS CODE,
          CASE
            WHEN EXISTS (
                   SELECT 1
                   FROM   OAGWBG.OAGWBG_SYSTEMMENUROLEASSIGN RA
                   WHERE  RA.SYSTEMMENUID  = SM.ID
                     AND  RA.SYSTEMROLEID  = P_SYSTEMROLEID
                 )
            THEN 1 ELSE 0
          END                                      AS ISPERMISSION
      FROM       MENUS SM
      LEFT JOIN  MENUS PM ON PM.ID = SM.PARENTMENUID
    )
    /* เรียง: เมนูระดับบนก่อน (ตาม SEQUENCE) แล้วค่อยลูกทั้งหมดจัดกลุ่มตามแม่
       view หยิบไปกรองซ้ำอยู่แล้ว จึงต้องการแค่ให้ลำดับภายในแต่ละกลุ่มถูกต้อง */
    ORDER BY CASE WHEN PARENTID IS NULL THEN 0 ELSE 1 END,
             PARENTID,
             SEQUENCE,
             ID
  )
  LOOP
    PIPE ROW (
      OAGWBG.OAGWBG_MENUPERMISSION_OBJ(
        R.ID,
        R.MENUID,
        R.MENUNAME,
        R.CONTROLLERNAME,
        R.ACTIONNAME,
        R.SEQUENCE,
        R.ACTIVE,
        R.ISSHOWINSITEMENU,
        R.NODEID,
        R.PARENTID,
        R.CODE,
        R.ISPERMISSION
      )
    );
  END LOOP;
  RETURN;
END;
/

SHOW ERRORS FUNCTION OAGWBG.OAGWBG_FN_GETMENU_PERMISSION


-- =============================================================================
-- 3) VERIFY (รันหลัง deploy — read-only ทั้งหมด)
-- =============================================================================

-- 3.1 ต้อง VALID
-- SELECT OBJECT_NAME, OBJECT_TYPE, STATUS
-- FROM   ALL_OBJECTS
-- WHERE  OWNER = 'OAGWBG'
--   AND  OBJECT_NAME IN ('OAGWBG_FN_GETMENU_PERMISSION',
--                        'OAGWBG_MENUPERMISSION_OBJ',
--                        'OAGWBG_MENUPERMISSION_TAB');

-- 3.2 จำนวนแถวต้องเท่ากับจำนวนเมนู ACTIVE='1' (ปัจจุบัน = 65 จากทั้งหมด 66)
--     และต้องเท่ากับของฟังก์ชันพี่น้องเดิม
-- SELECT (SELECT COUNT(*) FROM OAGWBG_FN_GETMENU_PERMISSION(11))        AS NEW_FN,
--        (SELECT COUNT(*) FROM OAGWBG_FN_GETSYSTEMMENUROLEASSIGN(11))   AS OLD_FN,
--        (SELECT COUNT(*) FROM OAGWBG_SYSTEMMENU WHERE ACTIVE='1')      AS MENU_ACTIVE
-- FROM DUAL;

-- 3.3 ISPERMISSION ต้องตรงกับ OAGWBG_SYSTEMMENUROLEASSIGN เป๊ะ (ต้องได้ 0 แถว)
-- SELECT F.ID, F.MENUNAME, F.ISPERMISSION
-- FROM   OAGWBG_FN_GETMENU_PERMISSION(11) F
-- WHERE  F.ISPERMISSION <> CASE WHEN EXISTS (
--            SELECT 1 FROM OAGWBG_SYSTEMMENUROLEASSIGN RA
--            WHERE RA.SYSTEMROLEID = 11 AND RA.SYSTEMMENUID = F.ID) THEN 1 ELSE 0 END;

-- 3.4 ต้องไม่มีแถวที่ "หลุด" จากการ render ของ view
--     (PARENTID ไม่เป็น NULL แต่หา parent row ในชุดผลลัพธ์ไม่เจอ) — ต้องได้ 0 แถว
-- SELECT C.ID, C.MENUNAME, C.PARENTID
-- FROM   OAGWBG_FN_GETMENU_PERMISSION(11) C
-- WHERE  C.PARENTID IS NOT NULL
--   AND  NOT EXISTS (SELECT 1 FROM OAGWBG_FN_GETMENU_PERMISSION(11) P
--                    WHERE P.ID = C.PARENTID AND P.PARENTID IS NULL);

-- 3.5 ดูผลจริงแบบเรียงตามที่หน้าจอจะแสดง
-- SELECT ID, PARENTID, SEQUENCE, MENUNAME, CODE, ISPERMISSION
-- FROM   OAGWBG_FN_GETMENU_PERMISSION(11);


-- =============================================================================
-- 4) ROLLBACK
-- =============================================================================
-- DROP FUNCTION OAGWBG.OAGWBG_FN_GETMENU_PERMISSION;
-- DROP TYPE     OAGWBG.OAGWBG_MENUPERMISSION_TAB;
-- DROP TYPE     OAGWBG.OAGWBG_MENUPERMISSION_OBJ;
