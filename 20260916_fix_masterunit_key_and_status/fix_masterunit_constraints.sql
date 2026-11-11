--------------------------------------------------------------------------------
-- OAGWBG_MASTERUNIT : เพิ่ม Primary Key + Unique ชื่อหน่วยนับ
--
-- ปัญหา : ตาราง OAGWBG_MASTERUNIT ไม่มี PK และไม่มี unique constraint
--          1) EF Core scaffold ออกมาเป็น HasNoKey() -> แก้ไข/เพิ่ม/ลบ ผ่าน EF ไม่ได้
--          2) ชื่อหน่วยนับซ้ำกันได้ -> การตรวจสอบชื่อซ้ำฝั่ง C# เตือนผิดเวลาแก้สถานะ
--
-- ผู้จัดทำ : Claude Opus 5 (2026-09-16)
-- ผู้รัน   : DBA  (ต้องรันบน PREPROD ก่อน แล้วค่อย PROD)
-- Schema  : OAGWBG
--------------------------------------------------------------------------------

--==============================================================================
-- STEP 0 : ตรวจสอบก่อน (SELECT อย่างเดียว ปลอดภัย)
--==============================================================================

-- 0.1 ปัจจุบันมี constraint / index อะไรอยู่บ้าง
SELECT constraint_name, constraint_type, status
  FROM all_constraints
 WHERE owner = 'OAGWBG' AND table_name = 'OAGWBG_MASTERUNIT';

SELECT index_name, uniqueness FROM all_indexes
 WHERE table_owner = 'OAGWBG' AND table_name = 'OAGWBG_MASTERUNIT';

-- 0.2 ID ซ้ำหรือเป็น NULL ไหม  (ต้องได้ 0 แถว ถึงจะเพิ่ม PK ได้)
SELECT id, COUNT(*) cnt
  FROM OAGWBG.OAGWBG_MASTERUNIT
 GROUP BY id
HAVING COUNT(*) > 1;

SELECT COUNT(*) null_id FROM OAGWBG.OAGWBG_MASTERUNIT WHERE id IS NULL;

-- 0.3 ชื่อซ้ำ (ดู EGPID ประกอบ)
--     ชื่อเดียวกันแต่ EGPID ต่างกัน = ข้อมูลถูกต้อง ไม่ถือว่าซ้ำ
--     (ตัวที่ผูกรหัส e-GP กับตัวที่ไม่ผูก อยู่ด้วยกันได้)
SELECT UPPER(TRIM(namethai)) name_key, COUNT(*) cnt,
       LISTAGG(id || CASE WHEN egpid IS NULL THEN '(egp:-)' ELSE '(egp:' || egpid || ')' END, ', ')
         WITHIN GROUP (ORDER BY id) ids
  FROM OAGWBG.OAGWBG_MASTERUNIT
 GROUP BY UPPER(TRIM(namethai))
HAVING COUNT(*) > 1;

-- 0.3.1 ซ้ำจริงตามกติกาใหม่ = ชื่อเดียวกัน "และ" EGPID เดียวกัน
--       ถ้าคิวรีนี้ไม่มีแถวออกมา = ข้อมูลปัจจุบันผ่านกติกาใหม่แล้ว ไม่ต้องล้างอะไร
SELECT UPPER(TRIM(namethai)) name_key, egpid, COUNT(*) cnt,
       LISTAGG(id, ',') WITHIN GROUP (ORDER BY id) ids
  FROM OAGWBG.OAGWBG_MASTERUNIT
 GROUP BY UPPER(TRIM(namethai)), egpid
HAVING COUNT(*) > 1;

-- 0.4 ดูว่าแถวที่ชื่อซ้ำ ถูกใช้งานอยู่หรือไม่ (ก่อนตัดสินใจว่าจะเก็บ id ไหน)
SELECT u.id, u.namethai, u.active, u.egpid,
       (SELECT COUNT(*) FROM OAGWBG.OAGWBG_ASSET a
         WHERE a.unitid = u.id) used_in_asset,
       (SELECT COUNT(*) FROM OAGWBG.OAGWBG_BUDGETGOVERNMENTITEM b
         WHERE b.quantityunitid = u.id) used_in_govitem
  FROM OAGWBG.OAGWBG_MASTERUNIT u
 WHERE UPPER(TRIM(u.namethai)) IN (
       SELECT UPPER(TRIM(namethai)) FROM OAGWBG.OAGWBG_MASTERUNIT
        GROUP BY UPPER(TRIM(namethai)) HAVING COUNT(*) > 1)
 ORDER BY UPPER(TRIM(u.namethai)), u.id;

--==============================================================================
-- STEP 1 : ล้างข้อมูลซ้ำ (ทำเฉพาะเมื่อ STEP 0.3.1 มีแถวออกมา คือชื่อ+EGPID ซ้ำกันจริง)
--          แถวที่ชื่อเดียวกันแต่ EGPID ต่างกัน = ข้อมูลถูกต้อง ห้ามลบ
--          *** ห้ามรันอัตโนมัติ ให้ผู้ใช้งานระบบตัดสินใจทีละคู่ก่อน ***
--==============================================================================

-- 1.1 ตัด space หัว-ท้ายออกก่อน (ปลอดภัย ไม่เปลี่ยนความหมายของข้อมูล)
-- UPDATE OAGWBG.OAGWBG_MASTERUNIT
--    SET namethai = TRIM(namethai)
--  WHERE namethai <> TRIM(namethai);
-- COMMIT;

-- 1.2 แถวที่ชื่อ+EGPID ซ้ำกัน : ย้าย reference ไปที่ id ที่จะเก็บไว้ แล้วค่อยลบตัวซ้ำ
--     (:keep_id = id ที่เก็บไว้ , :dup_id = id ที่จะลบ)
-- UPDATE OAGWBG.OAGWBG_ASSET               SET unitid         = :keep_id WHERE unitid         = :dup_id;
-- UPDATE OAGWBG.OAGWBG_BUDGETGOVERNMENTITEM SET quantityunitid = :keep_id WHERE quantityunitid = :dup_id;
-- DELETE FROM OAGWBG.OAGWBG_MASTERUNIT WHERE id = :dup_id;
-- COMMIT;

--==============================================================================
-- STEP 2 : เพิ่ม Primary Key  (แก้ปัญหา EF แก้ไข/เพิ่ม/ลบ ไม่ได้)
--          หมายเหตุ Oracle จะตั้ง ID เป็น NOT NULL ให้อัตโนมัติ
--==============================================================================
ALTER TABLE OAGWBG.OAGWBG_MASTERUNIT
  ADD CONSTRAINT PK_OAGWBG_MASTERUNIT PRIMARY KEY (ID);

--==============================================================================
-- STEP 3 : (ทางเลือก - ยังไม่ต้องรันก็ได้) บังคับห้ามซ้ำที่ระดับ DB
--
--   *** ไม่ทำ unique บน NAMETHAI อย่างเดียว ***
--   เพราะหน่วยนับชื่อเดียวกันมีได้ทั้งตัวที่ผูกรหัส e-GP และตัวที่ไม่ผูก
--   กติกาที่ใช้จริงคือ "ชื่อ + EGPID" ซึ่งฝั่งแอปเช็คให้แล้วที่
--   OAGBudget/Controllers/MasterController.cs -> SaveMasterUnit
--
--   ถ้าต้องการให้ DB ช่วยกันซ้ำอีกชั้น ค่อยรันคำสั่งข้างล่างนี้
--   (ต้องให้ STEP 0.3.1 ไม่มีแถวออกมาก่อน)
--
--   หมายเหตุพฤติกรรม Oracle : composite unique ที่บางคอลัมน์เป็น NULL
--   จะไม่ยอมให้ค่าที่ "ไม่เป็น NULL" ซ้ำกัน แปลว่า
--     ('ชิ้น', NULL) + ('ชิ้น', 123)  -> ได้
--     ('ชิ้น', NULL) + ('ชิ้น', NULL) -> ไม่ได้
--   ตรงกับกติกาฝั่งแอปพอดี แต่ให้ทดสอบยืนยันบน PREPROD ก่อนขึ้น PROD
--==============================================================================
-- CREATE UNIQUE INDEX OAGWBG.UX_MASTERUNIT_NAME_EGPID
--     ON OAGWBG.OAGWBG_MASTERUNIT (UPPER(TRIM(NAMETHAI)), EGPID);

--==============================================================================
-- STEP 4 : (ทำเฉพาะเมื่อยังไม่มี) ตัวสร้าง ID อัตโนมัติสำหรับการ "สร้างใหม่"
--          ตรวจก่อนว่ามี trigger / sequence อยู่แล้วหรือไม่
--==============================================================================
SELECT trigger_name, triggering_event, status
  FROM all_triggers
 WHERE table_owner = 'OAGWBG' AND table_name = 'OAGWBG_MASTERUNIT';

SELECT sequence_name, last_number FROM all_sequences
 WHERE sequence_owner = 'OAGWBG'
   AND sequence_name LIKE '%MASTERUNIT%';

-- ถ้า "ไม่มี" ทั้ง trigger และ sequence ให้สร้างตามนี้
-- (ฝั่งแอปมี fallback คำนวณ MAX(ID)+1 ให้อยู่แล้ว แต่ sequence ปลอดภัยกว่าเมื่อมีผู้ใช้พร้อมกัน)
--
-- DECLARE v_max NUMBER;
-- BEGIN
--   SELECT NVL(MAX(id), 0) + 1 INTO v_max FROM OAGWBG.OAGWBG_MASTERUNIT;
--   EXECUTE IMMEDIATE 'CREATE SEQUENCE OAGWBG.SEQ_OAGWBG_MASTERUNIT START WITH ' || v_max || ' INCREMENT BY 1 NOCACHE';
-- END;
-- /
--
-- CREATE OR REPLACE TRIGGER OAGWBG.TRG_OAGWBG_MASTERUNIT_ID
--   BEFORE INSERT ON OAGWBG.OAGWBG_MASTERUNIT
--   FOR EACH ROW
--   WHEN (NEW.id IS NULL OR NEW.id = 0)
-- BEGIN
--   :NEW.id := OAGWBG.SEQ_OAGWBG_MASTERUNIT.NEXTVAL;
-- END;
-- /

--==============================================================================
-- STEP 5 : ตรวจผลหลังรัน
--==============================================================================
SELECT constraint_name, constraint_type, status
  FROM all_constraints
 WHERE owner = 'OAGWBG' AND table_name = 'OAGWBG_MASTERUNIT'
   AND constraint_type = 'P';

SELECT index_name, uniqueness, status FROM all_indexes
 WHERE table_owner = 'OAGWBG' AND table_name = 'OAGWBG_MASTERUNIT';

--==============================================================================
-- ROLLBACK (ถ้าจำเป็นต้องถอย)
--==============================================================================
-- DROP INDEX OAGWBG.UX_MASTERUNIT_NAME_EGPID;   -- เฉพาะกรณีที่รัน STEP 3
-- ALTER TABLE OAGWBG.OAGWBG_MASTERUNIT DROP CONSTRAINT PK_OAGWBG_MASTERUNIT;
-- DROP TRIGGER OAGWBG.TRG_OAGWBG_MASTERUNIT_ID;
-- DROP SEQUENCE OAGWBG.SEQ_OAGWBG_MASTERUNIT;
