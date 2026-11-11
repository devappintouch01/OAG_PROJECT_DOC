-- =============================================================================
-- คำขอโอนเงินกลับ — โฟลว์พิจารณาก่อนแจ้งโอนกลับ
-- วันที่: 2026-11-10 (ต่อจาก 04_status_inprogress.sql)
--
-- โฟลว์ใหม่ (ปุ่ม → สถานะ):
--   ร่าง 70101 --(ส่งเรื่อง)--> รอพิจารณา 70301 --(ยืนยันการพิจารณา)--> พิจารณาแล้ว 70401
--   --(แจ้งโอนกลับ)--> แจ้งโอนกลับ 70201 --> อยู่ระหว่างโอนกลับ 70701 --> ดำเนินการโอนกลับครบแล้ว 70601
--   รอพิจารณา 70301 --(ส่งเรื่องกลับ)--> ร่าง 70101
--   ยกเลิกแจ้งโอนกลับ 70501 ได้จาก 70101/70301/70401/70201 เมื่อยังไม่มีรายการถูกดึง
--   หน้าโอนเงินกลับดึงได้เฉพาะ 70201 (เดิม 70201 + 70401)
--
-- โค้ดไม่ได้อ่านชื่อสถานะคำขอจากตารางนี้ (ใช้ BudgetTransferRequestStatus.NameOf) และ STATUSID ไม่มี FK
-- → สคริปต์นี้แค่ให้ master data ตรงกับหน้าจอ deploy code ก่อนหรือหลังก็ได้
-- ไม่ต้องย้ายข้อมูลคำขอ: คำขอเดิมที่ 70201 ("ส่งเรื่องแล้ว") ความหมายตรงกับ "แจ้งโอนกลับ" (ดึงได้) อยู่แล้ว
-- =============================================================================

-- ตรวจก่อน: ควรไม่มีคำขอค้างที่ 70301/70401 (config RequireApproval เดิม = false)
SELECT STATUSID, COUNT(*) FROM OAGWBG_BUDGETTRANSFERREQUEST GROUP BY STATUSID ORDER BY STATUSID;

UPDATE OAGWBG_MASTERSTATUS SET NAME = 'แจ้งโอนกลับ',  UPDATEBY = -1, UPDATEON = SYSTIMESTAMP WHERE ID = 70201;
UPDATE OAGWBG_MASTERSTATUS SET NAME = 'รอพิจารณา',   ACTIVE = '1', UPDATEBY = -1, UPDATEON = SYSTIMESTAMP WHERE ID = 70301;
UPDATE OAGWBG_MASTERSTATUS SET NAME = 'พิจารณาแล้ว', ACTIVE = '1', UPDATEBY = -1, UPDATEON = SYSTIMESTAMP WHERE ID = 70401;
UPDATE OAGWBG_MASTERSTATUS SET NAME = 'ยกเลิกแจ้งโอนกลับ', UPDATEBY = -1, UPDATEON = SYSTIMESTAMP WHERE ID = 70501;

COMMIT;

-- ตรวจผล
SELECT ID, NAME, ACTIVE FROM OAGWBG_MASTERSTATUS WHERE ID BETWEEN 70000 AND 79999 ORDER BY ID;  -- 7 แถว

-- ROLLBACK
-- UPDATE OAGWBG_MASTERSTATUS SET NAME = 'ส่งเรื่องแล้ว' WHERE ID = 70201;
-- UPDATE OAGWBG_MASTERSTATUS SET NAME = 'รออนุมัติ',  ACTIVE = '0' WHERE ID = 70301;
-- UPDATE OAGWBG_MASTERSTATUS SET NAME = 'อนุมัติแล้ว', ACTIVE = '0' WHERE ID = 70401;
-- UPDATE OAGWBG_MASTERSTATUS SET NAME = 'ยกเลิกคำขอ' WHERE ID = 70501;
-- COMMIT;
