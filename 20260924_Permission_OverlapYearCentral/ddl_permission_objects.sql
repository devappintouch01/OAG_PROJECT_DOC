-- =====================================================================
-- DDL ของ object ที่เกี่ยวกับ "การจัดการสิทธิ" + เมนู "โอนงปม. เข้าบัญชีเงินกัน"
-- ดึงสดจาก DBMS_METADATA.GET_DDL เมื่อ 2026-09-24
-- DB: PREPROD  172.16.11.19:1541 / ebs_PRE / OAGWBG  (ต่อผ่าน F5 BIG-IP Edge Client)
--
-- ไฟล์นี้เป็น "ของอ้างอิง" เท่านั้น — ไม่ต้องรัน object พวกนี้มีอยู่แล้วบน PREPROD
-- สคริปต์ที่ต้องรันจริงอยู่ที่ deploy_grant_menu201_role11.sql
--
-- LAST_DDL_TIME ที่ตรวจพบ ณ วันดึง:
--   TABLE    OAGWBG_SYSTEMMENU              2025-11-18 22:51:26   VALID
--   TABLE    OAGWBG_SYSTEMMENUROLEASSIGN    2025-11-18 22:51:26   VALID
--   TABLE    OAGWBG_SYSTEMROLE              2025-11-18 22:51:27   VALID
--   TABLE    OAGWBG_SYSTEMUSERROLEASSIGN    2025-11-19 01:57:53   VALID
--   SEQUENCE SEQ_SYSTEMMENUROLEASSIGN_ID    2025-11-19 01:33:33   VALID
--   TYPE     OAGWBG_OBJ_BOOKINGSYSTEMMENU   2025-11-22 16:44:46   VALID
--   TYPE     OAGWBG_TAB_BOOKINGSYSTEMMENU   2025-11-22 16:45:43   VALID
--   FUNCTION OAGWBG_FN_BOOKINGSYSTEMMENU    2025-11-22 16:46:59   VALID
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1) OAGWBG_SYSTEMMENU — ตารางเมนู
-- ---------------------------------------------------------------------
  CREATE TABLE "OAGWBG"."OAGWBG_SYSTEMMENU"
   (	"ID" NUMBER(10,0),
	"CREATEBY" NUMBER(10,0) DEFAULT -1,
	"CREATEON" TIMESTAMP (6) DEFAULT SYSTIMESTAMP,
	"UPDATEBY" NUMBER(10,0),
	"UPDATEON" TIMESTAMP (6),
	"ACTIVE" CHAR(1) DEFAULT 0,
	"MENUNAME" VARCHAR2(4000 CHAR),
	"MENUDESCRIPTION" VARCHAR2(500 CHAR),
	"URL" VARCHAR2(255 CHAR),
	"ACTIONNAME" VARCHAR2(100 CHAR),
	"CONTROLLERMAINNAME" VARCHAR2(100 CHAR),
	"CONTROLLERNAME" VARCHAR2(100 CHAR),
	"SEQUENCE" NUMBER(10,0),
	"ICONCSS" VARCHAR2(50 CHAR),
	"ISPARENT" CHAR(1) DEFAULT 0,
	"PARENTMENUID" NUMBER(10,0),
	"ISSHOWINSITEMENU" CHAR(1) DEFAULT 0,
	"SYSTEMMENUGROUPID" NUMBER(10,0),
	"SYSTEMNAMEID" NUMBER(10,0),
	 CONSTRAINT "SYS_C0011659" CHECK ("ID" IS NOT NULL) ENABLE,
	 CONSTRAINT "SYS_C0011865" CHECK ("ID" IS NOT NULL) ENABLE,
	 CONSTRAINT "SYS_C009602" PRIMARY KEY ("ID")
  USING INDEX  ENABLE
   ) ;


-- ---------------------------------------------------------------------
-- 2) OAGWBG_SYSTEMMENUROLEASSIGN — เมนูที่ role ไหนเห็นได้ (จุดที่ต้องแก้ข้อมูล)
-- ---------------------------------------------------------------------
  CREATE TABLE "OAGWBG"."OAGWBG_SYSTEMMENUROLEASSIGN"
   (	"ID" NUMBER(10,0),
	"SYSTEMROLEID" NUMBER(10,0),
	"SYSTEMMENUID" NUMBER(10,0),
	"CREATEBY" NUMBER(10,0) DEFAULT -1,
	"CREATEON" TIMESTAMP (6) DEFAULT SYSTIMESTAMP,
	"UPDATEBY" NUMBER(10,0),
	"UPDATEON" TIMESTAMP (6),
	 CONSTRAINT "SYS_C0011664" CHECK ("ID" IS NOT NULL) ENABLE,
	 CONSTRAINT "SYS_C0011665" CHECK ("SYSTEMROLEID" IS NOT NULL) ENABLE,
	 CONSTRAINT "SYS_C0011666" CHECK ("SYSTEMMENUID" IS NOT NULL) ENABLE,
	 CONSTRAINT "SYS_C00328245" CHECK ("ID" IS NOT NULL) ENABLE,
	 CONSTRAINT "SYS_C00328246" CHECK ("SYSTEMROLEID" IS NOT NULL) ENABLE,
	 CONSTRAINT "SYS_C00328247" CHECK ("SYSTEMMENUID" IS NOT NULL) ENABLE,
	 CONSTRAINT "SYS_C009733" CHECK ("SYSTEMROLEID" IS NOT NULL) ENABLE,
	 CONSTRAINT "SYS_C009734" CHECK ("SYSTEMMENUID" IS NOT NULL) ENABLE,
	 CONSTRAINT "SYS_C009735" PRIMARY KEY ("ID")
  USING INDEX  ENABLE
   ) ;

-- ⚠️ ไม่มี UNIQUE (SYSTEMROLEID, SYSTEMMENUID) — DB ไม่กันแถวซ้ำให้
--    สคริปต์ deploy จึงต้องใส่ NOT EXISTS เอง


-- ---------------------------------------------------------------------
-- 3) OAGWBG_SYSTEMROLE — ตาราง role
--    ⚠️ ROLELEVEL ไม่ใช่ ID — ค่าจริงบน PREPROD คือ
--       ID 11 ศูนย์ต้นทุน                = ROLELEVEL 10
--       ID 31 สำนักบริหารงบประมาณ        = ROLELEVEL 20
--       ID 41 ผู้ดูแลระบบ                = ROLELEVEL 30
--       ID 51 สำนักยุทธศาสตร์ฯ           = ROLELEVEL 40
--       ID 61 สำนักการคลัง               = ROLELEVEL 50
--       ID 21 สนง.บริหารเงินนอกงบฯ       = ROLELEVEL 100
--       ID  1 ผู้ดูแลระบบ1 (ACTIVE=0)    = ROLELEVEL 200
--    ไม่มี role ใดที่ ROLELEVEL = 31 — ดู README ข้อ 1
-- ---------------------------------------------------------------------
  CREATE TABLE "OAGWBG"."OAGWBG_SYSTEMROLE"
   (	"ID" NUMBER(10,0),
	"CREATEBY" NUMBER(10,0) DEFAULT -1,
	"CREATEON" TIMESTAMP (6) DEFAULT SYSTIMESTAMP,
	"UPDATEBY" NUMBER(10,0),
	"UPDATEON" TIMESTAMP (6),
	"ACTIVE" CHAR(1) DEFAULT 1,
	"ROLENAME" VARCHAR2(100 CHAR),
	"DESCRIPTION" VARCHAR2(1000 CHAR),
	"ROLELEVEL" NUMBER(10,0),
	"PRIORITY" NUMBER(10,0),
	 CONSTRAINT "SYS_C0011670" CHECK ("ID" IS NOT NULL) ENABLE,
	 CONSTRAINT "SYS_C009578" PRIMARY KEY ("ID")
  USING INDEX  ENABLE
   ) ;


-- ---------------------------------------------------------------------
-- 4) OAGWBG_SYSTEMUSERROLEASSIGN — user ถือ role อะไรบ้าง
-- ---------------------------------------------------------------------
  CREATE TABLE "OAGWBG"."OAGWBG_SYSTEMUSERROLEASSIGN"
   (	"ID" NUMBER(10,0),
	"CREATEBY" NUMBER(10,0) DEFAULT -1,
	"CREATEON" TIMESTAMP (6) DEFAULT SYSTIMESTAMP,
	"UPDATEBY" NUMBER(10,0),
	"UPDATEON" TIMESTAMP (6),
	"ACTIVE" CHAR(1) DEFAULT 0,
	"EFFECTIVEDATE" TIMESTAMP (6),
	"EXPIREDATE" TIMESTAMP (6),
	"ISACTING" CHAR(1) DEFAULT 0,
	"PRIORITY" NUMBER(10,0),
	"SYSTEMMENUGROUPID" NUMBER(10,0),
	"SYSTEMROLEID" NUMBER(10,0),
	"SYSTEMUSERID" NUMBER(10,0),
	 CONSTRAINT "SYS_C0011676" CHECK ("ID" IS NOT NULL) ENABLE,
	 CONSTRAINT "SYS_C009581" PRIMARY KEY ("ID")
  USING INDEX  ENABLE
   ) ;


-- ---------------------------------------------------------------------
-- 5) SEQ_SYSTEMMENUROLEASSIGN_ID
--    ⚠️ LAST_NUMBER = 1 แต่ MAX(ID) ในตาราง = 306 → sequence หลุด sync
--       (แอปไม่ได้ใช้ sequence นี้ แต่ gen id เองด้วย Max(Id)+1 ใน
--        OAGBudget.API/Controllers/SystemController.cs)
--       สคริปต์ deploy จึงใช้ MAX(ID)+1 ไม่ใช่ .NEXTVAL
-- ---------------------------------------------------------------------
   CREATE SEQUENCE  "OAGWBG"."SEQ_SYSTEMMENUROLEASSIGN_ID"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 NOCACHE  NOORDER  NOCYCLE  NOKEEP  NOSCALE  GLOBAL ;


-- ---------------------------------------------------------------------
-- 6) TYPE + FUNCTION ที่หน้าเว็บใช้ render เมนูซ้ายมือ
--    เรียกจาก OAGBudget.API/Services/Repository/RawDataService.cs:77
--      select * from OAGWBG_FN_BOOKINGSYSTEMMENU({SystemUserId}, {SystemMenuGroupId})
--    ⚠️ พารามิเตอร์ตัวแรกคือ "USER ID" ไม่ใช่ role id → เมนูที่ได้คือ
--       UNION ของทุก role ที่ user คนนั้นถืออยู่ (ดู README ข้อ 2 หมายเหตุ)
-- ---------------------------------------------------------------------
  CREATE OR REPLACE EDITIONABLE TYPE "OAGWBG"."OAGWBG_OBJ_BOOKINGSYSTEMMENU" AS OBJECT (
    ID                     NUMBER,
    CREATEBY               NUMBER,
    CREATEON               TIMESTAMP(6),
    UPDATEBY               NUMBER,
    UPDATEON               TIMESTAMP(6),
    ACTIVE                 CHAR(1),
    MENUNAME               VARCHAR2(4000),
    MENUDESCRIPTION        VARCHAR2(500),
    URL                    VARCHAR2(250),
    ACTIONNAME             VARCHAR2(100),
    CONTROLLERMAINNAME     VARCHAR2(100),
    CONTROLLERNAME         VARCHAR2(100),
    SEQUENCE               NUMBER,
    ICONCSS                VARCHAR2(50),
    ISPARENT               CHAR(1),
    PARENTMENUID           NUMBER,
    ISSHOWINSITEMENU       CHAR(1),
    SYSTEMMENUGROUPID      NUMBER,
    SYSTEMNAMEID           NUMBER
)
/

  CREATE OR REPLACE EDITIONABLE TYPE "OAGWBG"."OAGWBG_TAB_BOOKINGSYSTEMMENU" AS TABLE OF OAGWBG_OBJ_BOOKINGSYSTEMMENU
/

  CREATE OR REPLACE EDITIONABLE FUNCTION "OAGWBG"."OAGWBG_FN_BOOKINGSYSTEMMENU" (
    P_SYSTEMUSERID  IN NUMBER DEFAULT NULL,
    P_SYSTEMNAMEID  IN NUMBER DEFAULT NULL
) RETURN OAGWBG_TAB_BOOKINGSYSTEMMENU
PIPELINED
IS
BEGIN
    FOR R IN (
        SELECT DISTINCT
            M.ID,
            M.CREATEBY,
            M.CREATEON,
            M.UPDATEBY,
            M.UPDATEON,
            M.ACTIVE,
            M.MENUNAME,
            M.MENUDESCRIPTION,
            M.URL,
            M.ACTIONNAME,
            M.CONTROLLERMAINNAME,
            M.CONTROLLERNAME,
            M.SEQUENCE,
            M.ICONCSS,
            M.ISPARENT,
            M.PARENTMENUID,
            M.ISSHOWINSITEMENU,
            M.SYSTEMMENUGROUPID,
            M.SYSTEMNAMEID
        FROM OAGWBG_SYSTEMUSER SU
        LEFT JOIN OAGWBG_SYSTEMUSERROLEASSIGN URA
            ON URA.SYSTEMUSERID = SU.ID
        LEFT JOIN OAGWBG_SYSTEMMENUROLEASSIGN MRA
            ON MRA.SYSTEMROLEID = URA.SYSTEMROLEID
        LEFT JOIN OAGWBG_SYSTEMMENU M
            ON M.ID = MRA.SYSTEMMENUID
--        WHERE URA.SYSTEMROLEID = P_SYSTEMROLEID
          WHERE URA.SYSTEMUSERID = P_SYSTEMUSERID
          AND M.ACTIVE = '1'
          AND M.ISSHOWINSITEMENU = '1'
          -- AND URA.SYSTEMNAMEID = P_SYSTEMNAMEID
    )
    LOOP
        PIPE ROW(OAGWBG_OBJ_BOOKINGSYSTEMMENU(
            R.ID, R.CREATEBY, R.CREATEON, R.UPDATEBY, R.UPDATEON,
            R.ACTIVE, R.MENUNAME, R.MENUDESCRIPTION, R.URL,
            R.ACTIONNAME, R.CONTROLLERMAINNAME, R.CONTROLLERNAME,
            R.SEQUENCE, R.ICONCSS, R.ISPARENT, R.PARENTMENUID,
            R.ISSHOWINSITEMENU, R.SYSTEMMENUGROUPID, R.SYSTEMNAMEID
        ));
    END LOOP;

    RETURN;
END;
/
