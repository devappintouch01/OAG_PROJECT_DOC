-- =============================================================================
-- คำขอโอนเงินกลับ — สถานะ "อยู่ระหว่างโอนกลับ" (70701)
-- วันที่: 2026-10-20 (ต่อจาก 03_create_item_source_history.sql)
--
-- ที่มา: เดิมคำขอขึ้น "ดำเนินการโอนกลับครบแล้ว" (70601) ทันทีที่ทุกรายการถูกดึงไปอยู่ในใบโอนกลับ
--        แม้ใบโอนกลับยังเป็นร่าง (เช่น RQ700003 → ใบ 2866 สถานะ 80101) ผู้แจ้งจึงเข้าใจว่าโอนเสร็จแล้ว
-- ใหม่:  ดึงครบแต่ยังมีใบโอนกลับที่ยังไม่ยืนยัน (80201) = 70701 อยู่ระหว่างโอนกลับ
--        ดึงครบและใบโอนกลับทุกใบยืนยันแล้ว             = 70601 ดำเนินการโอนกลับครบแล้ว
--
-- โค้ดไม่ได้อ่านชื่อสถานะคำขอจากตารางนี้ (ใช้ BudgetTransferRequestStatus.NameOf) และ STATUSID ไม่มี FK
-- → deploy code ก่อนหรือหลังสคริปต์นี้ก็ได้ ส่วนที่ 1 เพิ่มให้ master data ครบเหมือนสถานะอื่น
-- ส่วนที่ 2 ปรับข้อมูลเดิมให้ตรงกฎใหม่ทันที (ถ้าไม่รัน จะถูกปรับเองเมื่อบันทึก/ยืนยันใบโอนกลับที่เกี่ยวข้อง)
-- =============================================================================

-- 1) master data
INSERT INTO OAGWBG_MASTERSTATUS (ID, CREATEBY, CREATEON, ACTIVE, NAME)
VALUES (70701, -1, SYSTIMESTAMP, '1', 'อยู่ระหว่างโอนกลับ');

-- 2) คำขอที่ขึ้นครบแล้ว แต่ยังมีรายการอยู่ในใบโอนกลับที่ยังไม่ยืนยัน → อยู่ระหว่างโอนกลับ
--    ตรวจก่อน:
--    SELECT r.ID, r.REQUESTNO, i.BUDGETTRANSFERID, t.TRANSFERSTATUSID
--      FROM OAGWBG_BUDGETTRANSFERREQUEST r
--      JOIN OAGWBG_BUDGETTRANSFERREQUESTITEM i ON i.REQUESTID = r.ID
--      JOIN OAGWBG_BUDGETTRANSFER t ON t.ID = i.BUDGETTRANSFERID
--     WHERE r.STATUSID = 70601 AND NVL(t.TRANSFERSTATUSID, 0) <> 80201;
UPDATE OAGWBG_BUDGETTRANSFERREQUEST r
   SET r.STATUSID = 70701,
       r.UPDATEBY = -1,
       r.UPDATEON = SYSTIMESTAMP
 WHERE r.STATUSID = 70601
   AND EXISTS (
         SELECT 1
           FROM OAGWBG_BUDGETTRANSFERREQUESTITEM i
           JOIN OAGWBG_BUDGETTRANSFER t ON t.ID = i.BUDGETTRANSFERID
          WHERE i.REQUESTID = r.ID
            AND NVL(t.TRANSFERSTATUSID, 0) <> 80201);

COMMIT;

-- ตรวจผล
SELECT ID, NAME, ACTIVE FROM OAGWBG_MASTERSTATUS WHERE ID BETWEEN 70000 AND 79999 ORDER BY ID;  -- ต้องได้ 7 แถว
SELECT STATUSID, COUNT(*) FROM OAGWBG_BUDGETTRANSFERREQUEST GROUP BY STATUSID ORDER BY STATUSID;

-- ROLLBACK
-- UPDATE OAGWBG_BUDGETTRANSFERREQUEST SET STATUSID = 70601 WHERE STATUSID = 70701;
-- DELETE FROM OAGWBG_MASTERSTATUS WHERE ID = 70701;
-- COMMIT;
