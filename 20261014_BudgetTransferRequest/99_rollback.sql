-- =============================================================================
-- ROLLBACK: คำขอโอนเงินกลับ (01_create_tables.sql)
-- ⚠️ ข้อมูลคำขอทั้งหมดหายถาวร — ใบโอนกลับ (OAGWBG_BUDGETTRANSFER) ที่ดึงไปแล้วไม่ถูกกระทบ
--    เพราะตารางคำขอเป็นฝ่ายชี้ไปหาใบโอนกลับ ไม่มีคอลัมน์ฝั่ง BUDGETTRANSFER
-- =============================================================================
-- 05_create_transfer_note.sql (ถ้ารันแล้ว) — ไม่มี FK ไปตารางคำขอ drop เมื่อไรก็ได้
DROP TABLE OAGWBG_BUDGETTRANSFER_NOTE PURGE;
-- 03_create_item_source_history.sql (ถ้ารันแล้ว)
DROP TABLE OAGWBG_BUDGETTRANSFERREQUESTITEM_SOURCE PURGE;
DROP TABLE OAGWBG_BUDGETTRANSFERREQUEST_HISTORY PURGE;
-- 02_create_item_note.sql (ถ้ารันแล้ว) — ต้อง drop ก่อนตารางรายการเพราะมี FK ชี้ไป
DROP TABLE OAGWBG_BUDGETTRANSFERREQUESTITEM_NOTE PURGE;
DROP TABLE OAGWBG_BUDGETTRANSFERREQUEST_COSTCENTER PURGE;
DROP TABLE OAGWBG_BUDGETTRANSFERREQUESTITEM PURGE;
DROP TABLE OAGWBG_BUDGETTRANSFERREQUEST PURGE;

DELETE FROM OAGWBG_MASTERSTATUS WHERE ID IN (70101, 70201, 70301, 70401, 70501, 70601, 70701);  -- 70701 จาก 04_status_inprogress.sql
COMMIT;
