-- =============================================================================
-- INSERT OAGWBG_MASTERSTATUS กลุ่ม 4xxxx — สถานะไฟล์นำเข้า Excel โอนจัดสรร
-- วันที่: 2026-10-28
-- ใช้กับ: OAGWBG_BUDGETALLOCATETRANSFER_IMPORT_EXCEL.IMPORTSTATUS
--
-- รูปแบบรหัส X YY ZZ (ตามกลุ่ม 7xxxx / 8xxxx): X=โมดูล, YY=ขั้นตอน, ZZ=ย่อย
--
-- ⚠️ รันทั้ง PREPROD และ PROD
-- ⚠️ OAGWBG_MASTERSTATUS ไม่มี PK/UNIQUE — INSERT จึงกันซ้ำด้วย NOT EXISTS
--    รันซ้ำได้ไม่เกิดแถวซ้ำ
-- =============================================================================

-- 0. ต้องได้ 0 แถว — ถ้าได้ > 0 แปลว่ามีคนใช้กลุ่ม 4 ไปแล้วใน environment นี้ ให้หยุด
SELECT ID, NAME FROM OAGWBG_MASTERSTATUS WHERE ID BETWEEN 40000 AND 49999 ORDER BY ID;

-- 1. เพิ่มสถานะ
INSERT INTO OAGWBG_MASTERSTATUS (ID, NAME, ACTIVE, CREATEBY)
SELECT 40101, 'อัปโหลดแล้ว', '1', -1 FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM OAGWBG_MASTERSTATUS WHERE ID = 40101);

INSERT INTO OAGWBG_MASTERSTATUS (ID, NAME, ACTIVE, CREATEBY)
SELECT 40201, 'ตรวจผ่านรอยืนยัน', '1', -1 FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM OAGWBG_MASTERSTATUS WHERE ID = 40201);

INSERT INTO OAGWBG_MASTERSTATUS (ID, NAME, ACTIVE, CREATEBY)
SELECT 40301, 'นำเข้าแล้ว', '1', -1 FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM OAGWBG_MASTERSTATUS WHERE ID = 40301);

INSERT INTO OAGWBG_MASTERSTATUS (ID, NAME, ACTIVE, CREATEBY)
SELECT 40401, 'ตีกลับ', '1', -1 FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM OAGWBG_MASTERSTATUS WHERE ID = 40401);

INSERT INTO OAGWBG_MASTERSTATUS (ID, NAME, ACTIVE, CREATEBY)
SELECT 40501, 'ยกเลิก', '1', -1 FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM OAGWBG_MASTERSTATUS WHERE ID = 40501);

COMMIT;

-- 2. ยืนยันผล — ต้องได้ 5 แถว ภาษาไทยไม่เพี้ยน
SELECT ID, NAME, ACTIVE FROM OAGWBG_MASTERSTATUS WHERE ID BETWEEN 40000 AND 49999 ORDER BY ID;

-- =============================================================================
-- ROLLBACK
-- DELETE FROM OAGWBG_MASTERSTATUS WHERE ID IN (40101,40201,40301,40401,40501);
-- COMMIT;
-- =============================================================================
