-- =============================================================================
-- ALTER OAGWBG_BUDGETALLOCATETRANSFER_IMPORT_EXCEL → กติกา all-or-nothing
-- วันที่: 2026-10-28
--
-- ใช้เฉพาะ environment ที่สร้างตารางจากสคริปต์เวอร์ชันแรก (19 คอลัมน์)
-- PREPROD สร้างไว้ 2026-10-28 09:58 ด้วยเวอร์ชันแรก จึงต้องรันไฟล์นี้
-- environment ใหม่ (เช่น PROD) ให้รัน create_table_budgetallocatetransfer_import.sql อย่างเดียวพอ
--
-- สิ่งที่เปลี่ยน
--   1. ตัด SUCCESSROWS — ผลมีแค่ผ่านทั้งไฟล์หรือตีกลับทั้งไฟล์
--   2. ERRORMESSAGE VARCHAR2(4000) → CLOB — เก็บ error ทุกแถวได้ไม่จำกัด
--      (Oracle เปลี่ยน VARCHAR2 เป็น CLOB ด้วย MODIFY ไม่ได้ ORA-22858
--       จึง DROP แล้ว ADD ใหม่ — ทำได้เพราะตารางยังว่าง)
--   3. CHECK สถานะ ตัด 'P' (นำเข้าบางส่วน) ออก
--
-- ⚠️ ตรวจก่อนรันว่าตารางยังว่าง (ขั้น 0) — ถ้ามีข้อมูลแล้ว ERRORMESSAGE เดิมจะหาย
-- =============================================================================

-- 0. ต้องได้ 0
SELECT COUNT(*) FROM OAGWBG_BUDGETALLOCATETRANSFER_IMPORT_EXCEL;

-- 1. ตัด SUCCESSROWS
ALTER TABLE OAGWBG_BUDGETALLOCATETRANSFER_IMPORT_EXCEL DROP COLUMN SUCCESSROWS;

-- 2. ERRORMESSAGE เป็น CLOB
ALTER TABLE OAGWBG_BUDGETALLOCATETRANSFER_IMPORT_EXCEL DROP COLUMN ERRORMESSAGE;
ALTER TABLE OAGWBG_BUDGETALLOCATETRANSFER_IMPORT_EXCEL ADD (ERRORMESSAGE CLOB);

-- 3. CHECK สถานะ
ALTER TABLE OAGWBG_BUDGETALLOCATETRANSFER_IMPORT_EXCEL DROP CONSTRAINT CK_OAGWBG_BGALLOCTRF_IMP_STS;
ALTER TABLE OAGWBG_BUDGETALLOCATETRANSFER_IMPORT_EXCEL ADD CONSTRAINT CK_OAGWBG_BGALLOCTRF_IMP_STS
    CHECK (IMPORTSTATUS IN ('U','V','I','E','C'));

-- 4. comment ใหม่
COMMENT ON COLUMN OAGWBG_BUDGETALLOCATETRANSFER_IMPORT_EXCEL.ERRORROWS    IS 'จำนวนแถวที่ไม่ผ่านการตรวจ (มากกว่า 0 = ตีกลับทั้งไฟล์)';
COMMENT ON COLUMN OAGWBG_BUDGETALLOCATETRANSFER_IMPORT_EXCEL.IMPORTSTATUS IS 'สถานะ U=อัปโหลดแล้ว, V=ตรวจผ่านรอยืนยัน, I=นำเข้าแล้ว, E=ตีกลับ (ผิดอย่างน้อย 1 แถว ไม่นำเข้าเลย), C=ยกเลิก';
COMMENT ON COLUMN OAGWBG_BUDGETALLOCATETRANSFER_IMPORT_EXCEL.ERRORMESSAGE IS 'รายการ error ทุกแถว (แถวที่/คอลัมน์/สาเหตุ) ของไฟล์ที่ถูกตีกลับ';

-- 5. ยืนยันผล — 18 คอลัมน์, ไม่มี SUCCESSROWS, ERRORMESSAGE เป็น CLOB, CHECK ไม่มี 'P'
SELECT COLUMN_ID, COLUMN_NAME, DATA_TYPE, CHAR_LENGTH, NULLABLE
FROM   USER_TAB_COLUMNS
WHERE  TABLE_NAME = 'OAGWBG_BUDGETALLOCATETRANSFER_IMPORT_EXCEL'
ORDER  BY COLUMN_ID;

SELECT CONSTRAINT_NAME, SEARCH_CONDITION_VC
FROM   USER_CONSTRAINTS
WHERE  TABLE_NAME = 'OAGWBG_BUDGETALLOCATETRANSFER_IMPORT_EXCEL'
  AND  CONSTRAINT_NAME = 'CK_OAGWBG_BGALLOCTRF_IMP_STS';
