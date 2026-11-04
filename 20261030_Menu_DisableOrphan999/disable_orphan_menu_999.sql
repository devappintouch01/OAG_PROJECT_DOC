-- =====================================================================
-- ปิดเมนูรายงานเก่าที่ PARENTMENUID = 999 (แม่ไม่มีอยู่จริง)
-- ที่ไปโผล่ซ้ำเป็นเมนูระดับบนในหน้า System/PermissionDetail
--
-- สาเหตุ (ตรวจบน PREPROD 2026-10-30)
--   OAGWBG_FN_GETMENU_PERMISSION มีส่วน ORPHAN-SAFE: ถ้าหาแม่ไม่เจอ ให้ดันขึ้นเป็นเมนูระดับบน
--   → เมนูเก่า Budget/Report* ใต้ 999 แทรกปนกับเมนูจริงชื่อเดียวกัน (เช่น 171 โอนเงินกลับ vs 135)
--   ฟังก์ชันกรอง ACTIVE = '1' อยู่แล้ว → ปิด ACTIVE แล้วจะหายจากหน้าจัดการสิทธิ์
--
-- สภาพก่อนแก้ (PREPROD)
--   ACTIVE = '1' 7 แถว : 164 คำของบประมาณ (ใน/นอก) / 165 คำของบประมาณโครงการ / 167 แผนการใช้จ่าย /
--                        168 โอนจัดสรร / 171 โอนเงินกลับ / 172 เบิกแทนกัน / 173 โอนเงินสะสมเหลือจ่าย
--   ACTIVE = '0' 1 แถว : 170 โอนเปลี่ยนแปลงงบประมาณ (ปิดไว้ก่อนแล้ว — ไม่แตะ)
--   sidebar: OAGWBG_FN_BOOKINGSYSTEMMENU ส่ง 171 ออกมาให้ user role 11/31 แต่
--            Views/Shared/Components/CategoryMenu/Default.cshtml วาดเฉพาะ Parentmenuid = null
--            แล้วไล่ลูกจากแม่ที่มีอยู่ → แถวใต้ 999 ไม่ถูกวาดเลย ปิดแล้ว sidebar จึงหน้าตาเหมือนเดิม
--   ไม่มีลิงก์ไหนในโค้ดชี้ไป Budget/Report* เหล่านี้ (มีแค่ action เปล่าใน BudgetController)
--   PROD ยังไม่ได้ตรวจ — ให้ดูผล §1 ก่อนรัน §2
--
-- สิ่งที่ไม่แตะ : แถวเมนู (ไม่ลบ), สิทธิ์ใน OAGWBG_SYSTEMMENUROLEASSIGN, action ใน BudgetController
--
-- ใช้ได้ทั้ง PREPROD และ PROD (อ้างด้วย PARENTMENUID + "แม่ไม่มีจริง" ไม่อ้าง ID) รันซ้ำได้
-- ประเภท : DML   Reversibility = R2 (rollback §5)
-- วิธีรัน : §1 → §2 (PL/SQL block เดียว ตรวจไม่ผ่านจะ RAISE และ rollback ทั้ง block เอง) → §3 → COMMIT §4
-- =====================================================================


-- ---------------------------------------------------------------------
-- §1  BEFORE — จด ID ที่ ACTIVE = '1' ไว้ (ใช้ใน rollback §5)
-- ---------------------------------------------------------------------
SELECT M.ID, M.MENUNAME, M.PARENTMENUID, M.SEQUENCE,
       M.CONTROLLERNAME || '/' || M.ACTIONNAME AS CODE, M.ACTIVE,
       (SELECT LISTAGG(A.SYSTEMROLEID, ',') WITHIN GROUP (ORDER BY A.SYSTEMROLEID)
        FROM   OAGWBG_SYSTEMMENUROLEASSIGN A WHERE A.SYSTEMMENUID = M.ID) AS ROLES
FROM   OAGWBG_SYSTEMMENU M
WHERE  M.PARENTMENUID = 999
ORDER  BY M.ID;
-- PREPROD คาดว่า 8 แถว: 164,165,167,168,171,172,173 ACTIVE 1 / 170 ACTIVE 0

-- 1.2 ต้องได้ 0 แถว (ยืนยันว่า 999 ไม่มีอยู่จริง) — ถ้ามีแถว ให้หยุด ไม่ต้องรัน §2
SELECT ID, MENUNAME FROM OAGWBG_SYSTEMMENU WHERE ID = 999;

-- 1.3 จำนวนแถวในหน้าจัดการสิทธิ์ก่อนแก้ (PREPROD = 76)
SELECT COUNT(*) AS PERMISSION_PAGE_ROWS FROM OAGWBG_FN_GETMENU_PERMISSION(1);


-- ---------------------------------------------------------------------
-- §2  DEPLOY + ตรวจในตัว
-- ---------------------------------------------------------------------
DECLARE
  v_user       NUMBER;
  v_site_before NUMBER;
  v_site_after  NUMBER;
  v_cnt        NUMBER;
BEGIN
  -- กันพลาด: ถ้า 999 มีอยู่จริง แถวพวกนี้ไม่ใช่เมนูกำพร้า → หยุด
  SELECT COUNT(*) INTO v_cnt FROM OAGWBG_SYSTEMMENU WHERE ID = 999;
  IF v_cnt <> 0 THEN
    RAISE_APPLICATION_ERROR(-20001, 'มีเมนู ID 999 อยู่จริง — หยุด ตรวจ §1 ก่อน');
  END IF;

  -- เมนูที่ sidebar วาดได้จริง (ไม่นับแถวใต้ 999) ของ user แรกใน role 31 — ต้องเท่าเดิมหลังแก้
  -- (ใช้ role 31 เพราะบน PREPROD role 1 ไม่มี user เลย และ role 31 มีสิทธิ์ 171)
  SELECT MIN(U.ID) INTO v_user
  FROM   OAGWBG_SYSTEMUSERROLEASSIGN A
  JOIN   OAGWBG_SYSTEMUSER U ON U.ID = A.SYSTEMUSERID
  WHERE  A.SYSTEMROLEID = 31;
  IF v_user IS NULL THEN
    RAISE_APPLICATION_ERROR(-20005, 'role 31 ไม่มี user — ตรวจ sidebar ไม่ได้ หยุด');
  END IF;

  SELECT COUNT(*) INTO v_site_before FROM OAGWBG_FN_BOOKINGSYSTEMMENU(v_user, 2)
  WHERE  NVL(PARENTMENUID, 0) <> 999;

  UPDATE OAGWBG_SYSTEMMENU
  SET    ACTIVE   = '0',
         UPDATEBY = -1,
         UPDATEON = SYSTIMESTAMP
  WHERE  PARENTMENUID = 999
  AND    ACTIVE = '1';

  DBMS_OUTPUT.PUT_LINE('ปิด ACTIVE ' || SQL%ROWCOUNT || ' แถว');

  -- ตรวจ: ใต้ 999 ต้องไม่เหลือ ACTIVE = '1'
  SELECT COUNT(*) INTO v_cnt FROM OAGWBG_SYSTEMMENU WHERE PARENTMENUID = 999 AND ACTIVE = '1';
  IF v_cnt <> 0 THEN
    RAISE_APPLICATION_ERROR(-20002, 'ใต้ 999 ยังเหลือ ACTIVE = 1 อีก ' || v_cnt || ' แถว');
  END IF;

  -- ตรวจ: เมนูที่ sidebar วาดได้ต้องไม่เปลี่ยน
  SELECT COUNT(*) INTO v_site_after FROM OAGWBG_FN_BOOKINGSYSTEMMENU(v_user, 2)
  WHERE  NVL(PARENTMENUID, 0) <> 999;
  IF v_site_after <> v_site_before THEN
    RAISE_APPLICATION_ERROR(-20003, 'เมนูใน sidebar เปลี่ยนจาก ' || v_site_before || ' เป็น ' || v_site_after || ' — หยุด');
  END IF;

  -- ตรวจ: หน้าจัดการสิทธิ์ต้องไม่มีเมนูที่แม่เป็น 999 แล้ว
  SELECT COUNT(*) INTO v_cnt
  FROM   OAGWBG_FN_GETMENU_PERMISSION(1) F
  JOIN   OAGWBG_SYSTEMMENU M ON M.ID = F.ID
  WHERE  M.PARENTMENUID = 999;
  IF v_cnt <> 0 THEN
    RAISE_APPLICATION_ERROR(-20004, 'หน้าจัดการสิทธิ์ยังเห็นเมนูใต้ 999 อีก ' || v_cnt || ' แถว');
  END IF;
END;
/


-- ---------------------------------------------------------------------
-- §3  VERIFY
-- ---------------------------------------------------------------------

-- 3.1 ใต้ 999 ต้องเป็น ACTIVE 0 ทุกแถว
SELECT ID, MENUNAME, ACTIVE, UPDATEON FROM OAGWBG_SYSTEMMENU WHERE PARENTMENUID = 999 ORDER BY ID;

-- 3.2 จำนวนแถวหน้าจัดการสิทธิ์ (PREPROD ต้องได้ 69 = 76 − 7)
SELECT COUNT(*) AS PERMISSION_PAGE_ROWS FROM OAGWBG_FN_GETMENU_PERMISSION(1);

-- 3.3 sidebar ของ user แรกใน role 31 — แถวใต้ 999 ต้องหาย (PREPROD ก่อนแก้มี 171 อยู่ 1 แถว)
SELECT F.ID, F.MENUNAME
FROM   OAGWBG_FN_BOOKINGSYSTEMMENU(
         (SELECT MIN(U.ID) FROM OAGWBG_SYSTEMUSERROLEASSIGN A
          JOIN OAGWBG_SYSTEMUSER U ON U.ID = A.SYSTEMUSERID WHERE A.SYSTEMROLEID = 31), 2) F
WHERE  F.PARENTMENUID = 999;

-- 3.4 เมนูระดับบนในหน้าจัดการสิทธิ์ — ต้องไม่มี Budget/Report* และไม่มีชื่อซ้ำ
SELECT ID, SEQUENCE, MENUNAME, CODE
FROM   OAGWBG_FN_GETMENU_PERMISSION(1)
WHERE  PARENTID IS NULL
ORDER  BY SEQUENCE, ID;


-- ---------------------------------------------------------------------
-- §4  COMMIT / ROLLBACK
-- ---------------------------------------------------------------------
-- COMMIT;
-- ROLLBACK;
--
-- หลัง COMMIT: เปิดหน้า System/PermissionDetail ใหม่ (sidebar ไม่เปลี่ยน ไม่ต้อง logout)


-- =====================================================================
-- §5  ROLLBACK หลัง COMMIT ไปแล้ว — เปิดกลับเฉพาะ ID ที่ §1 เคยเป็น ACTIVE 1
--     (ห้ามใช้ WHERE PARENTMENUID = 999 เฉย ๆ เพราะจะไปเปิด 170 ที่ปิดไว้ตั้งแต่แรกด้วย)
--     ด้านล่างเป็น ID ของ PREPROD — บน PROD ให้ใช้ ID จากผล §1 ของ PROD
-- =====================================================================
-- UPDATE OAGWBG_SYSTEMMENU
-- SET    ACTIVE = '1', UPDATEBY = -1, UPDATEON = SYSTIMESTAMP
-- WHERE  PARENTMENUID = 999
-- AND    ID IN (164, 165, 167, 168, 171, 172, 173);
-- COMMIT;
