-- [SUMMARY-NEW-ITEM 2026-10-16] เพิ่ม marker ใบคำขอส่วนกลางของ "รายการใหม่" ในหน้าคำของบประมาณภาพรวม (formtype 1)
-- NULL = ใบคำขอปกติ (ข้อมูลเดิมทั้งหมด) / 1 = ใบคำขอส่วนกลาง ศูนย์ต้นทุน 2906999999 หน่วยเบิกจ่าย 2900600000
-- nullable + ไม่มี default → ไม่แตะแถวเดิม, ไม่ lock ตารางนาน
-- ต้องรันก่อน 02_view_OAGWBG_V_BUDGETREQUEST.sql และก่อน deploy API ที่ map คอลัมน์นี้
-- PREPROD: ผู้ใช้รัน ALTER เองแล้ว 2026-10-16 (ชื่อ IS_SUMMARY_DUMMY_ITEM) — COMMENT ยังไม่ได้รัน
ALTER TABLE OAGWBG.OAGWBG_BUDGETREQUEST ADD (IS_SUMMARY_DUMMY_ITEM NUMBER(1));

COMMENT ON COLUMN OAGWBG.OAGWBG_BUDGETREQUEST.IS_SUMMARY_DUMMY_ITEM IS '1 = ใบคำขอส่วนกลางของรายการใหม่ในคำของบประมาณภาพรวม (ศูนย์ต้นทุน 2906999999 หน่วยเบิกจ่าย 2900600000), NULL = ใบคำขอปกติ';
