-- =============================================================================
-- ALTER TABLE OAGWBG_USERMANUAL — ลบคอลัมน์ MANUALNAME, ACTIVE (ไม่ได้ใช้แล้ว)
-- วันที่: 2026-09-15
--
-- ⚠️ ลำดับ: รัน SQL นี้ แล้วรัน/deploy code ใหม่ทันที
--    - code ใหม่ + ยังไม่รัน SQL → เพิ่มคู่มือไม่ได้ (MANUALNAME เป็น NOT NULL)
--    - รัน SQL + code เก่า     → หน้า UserManual error (EF หา MANUALNAME/ACTIVE ไม่เจอ)
-- ⚠️ DROP COLUMN ย้อนกลับไม่ได้ — ข้อมูลชื่อคู่มือเดิมจะหาย (ชื่อที่แสดงใช้ชื่อไฟล์จาก FILEPATH แทน)
-- =============================================================================

-- 0. (ถ้าต้องการเก็บไว้ดู) ข้อมูลก่อนลบ
SELECT ID, MANUALNAME, DESCRIPTION, FILEPATH, SEQUENCE, ACTIVE FROM OAGWBG_USERMANUAL ORDER BY ID;

-- 1. ลบคอลัมน์
ALTER TABLE OAGWBG_USERMANUAL DROP (MANUALNAME, ACTIVE);

-- 2. ยืนยันผล — ต้องไม่มี MANUALNAME, ACTIVE
SELECT COLUMN_NAME, DATA_TYPE, CHAR_LENGTH, NULLABLE
FROM   USER_TAB_COLUMNS
WHERE  TABLE_NAME = 'OAGWBG_USERMANUAL'
ORDER  BY COLUMN_ID;

SELECT ID, DESCRIPTION, FILEPATH, SEQUENCE FROM OAGWBG_USERMANUAL ORDER BY ID;
