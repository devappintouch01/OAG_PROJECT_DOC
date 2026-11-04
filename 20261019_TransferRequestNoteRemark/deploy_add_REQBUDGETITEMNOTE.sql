-- deploy: หมายเหตุชี้แจงของผู้แจ้งโอนกลับ ราย note ของโอนจัดสรร (modal "ยอดขอโอนกลับตาม note ของโอนจัดสรร") — 2026-10-19
-- คอลัมน์ NOTE เดิมเป็นสำเนาข้อความ note ของโอนจัดสรร ณ วันที่ขอ ใช้เก็บหมายเหตุไม่ได้ จึงเพิ่มคอลัมน์ใหม่
-- ต้องรันก่อน deploy โค้ด — entity map คอลัมน์นี้แล้ว ทุก query ของตารางนี้จะ SELECT REQBUDGETITEMNOTE (ไม่มีคอลัมน์ = ORA-00904)
ALTER TABLE OAGWBG.OAGWBG_BUDGETTRANSFERREQUESTITEM_NOTE ADD REQBUDGETITEMNOTE VARCHAR2(4000);

COMMENT ON COLUMN OAGWBG.OAGWBG_BUDGETTRANSFERREQUESTITEM_NOTE.REQBUDGETITEMNOTE IS 'หมายเหตุชี้แจงของผู้แจ้งโอนกลับ ราย note';
