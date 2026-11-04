-- rollback: ต้องถอยโค้ด (entity/BudgetService/หน้าจอ) ออกก่อน ไม่งั้น query ของตารางนี้จะ ORA-00904
-- ข้อมูลหมายเหตุที่กรอกไว้จะหายไปด้วย
ALTER TABLE OAGWBG.OAGWBG_BUDGETTRANSFERREQUESTITEM_NOTE DROP COLUMN REQBUDGETITEMNOTE;
