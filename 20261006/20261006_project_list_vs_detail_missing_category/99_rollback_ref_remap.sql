-- [99] ROLLBACK — คืนค่า REF_BUDGETGOVERNMENTID / UPDATEON ตาม backup จาก [02]
-- คืนเฉพาะแถวที่ REF ยังเป็นค่าที่ [02] ใส่ไว้ (ถ้าผู้ใช้กดบันทึกเปลี่ยน REF เองหลังจากนั้น จะไม่ทับ)

UPDATE OAGWBG_BUDGETGOVERNMENT T
   SET (T.REF_BUDGETGOVERNMENTID, T.UPDATEON) =
       (SELECT B.OLD_REF_ID, B.OLD_UPDATEON FROM OAGWBG_BK20261006_PJREF B WHERE B.BG_ID = T.ID)
 WHERE EXISTS (SELECT 1 FROM OAGWBG_BK20261006_PJREF B
                WHERE B.BG_ID      = T.ID
                  AND B.NEW_REF_ID = T.REF_BUDGETGOVERNMENTID);

-- จำนวนแถวควรเท่ากับ SELECT COUNT(*) FROM OAGWBG_BK20261006_PJREF (ยกเว้นแถวที่ผู้ใช้แก้เองไปแล้ว)
-- COMMIT;

-- เก็บตาราง backup ไว้จนกว่าจะยืนยันว่าไม่ต้องย้อนกลับแล้ว จึงค่อย
-- DROP TABLE OAGWBG_BK20261006_PJREF;
