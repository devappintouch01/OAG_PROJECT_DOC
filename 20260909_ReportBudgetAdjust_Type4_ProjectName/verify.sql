-- =====================================================================================
-- verify — รันบน PREPROD (ebs_PRE) 172.16.11.19:1541 / SERVICE_NAME=ebs_PRE
-- (พอร์ต 1541 ไม่ใช่ 1521 — ดู appsettings.Development.json)
-- =====================================================================================

-- 1) จำนวนแถวรวม ต้องเท่าเดิม 527 — ถ้าเพิ่ม แปลว่า join ใหม่ทำแถวบาน
SELECT COUNT(*) TOTAL_ROWS FROM OAGWBG_R_BUDGETADJUST;

-- 2) ความครบของ 3 คอลัมน์ แยกตามประเภท/ฝั่ง
--    ก่อน v5: type 4 = 0 ทั้ง 3 คอลัมน์
--    หลัง v5: type 4 RECEIVER 13 แถว -> HAS_ITEM 11 / HAS_BTNAME 11 / HAS_CATNAME 10
--             type 4 SENDER    4 แถว -> 3 / 3 / 3
SELECT TRANSFERTYPE, ROLETYPE, COUNT(*) CNT,
       COUNT(ITEMDETAIL) HAS_ITEM, COUNT(BUDGETTYPENAME) HAS_BTNAME, COUNT(CATEGORYNAME) HAS_CATNAME
FROM   OAGWBG_R_BUDGETADJUST
GROUP  BY TRANSFERTYPE, ROLETYPE
ORDER  BY TRANSFERTYPE, ROLETYPE;

-- 3) ค่าจริงของ type 4
SELECT ROUNDNO, ROLETYPE, COSTCENTERNAME, ITEMDETAIL, BUDGETTYPENAME, CATEGORYNAME,
       TOTALRECEIVEAMOUNT, TOTALTRANSFERAMOUNT
FROM   OAGWBG_R_BUDGETADJUST
WHERE  TRANSFERTYPE = '4'
ORDER  BY ROUNDNO, ROLETYPE;

-- 4) ต้นทางของทั้ง 3 คอลัมน์ — OAGWBG_ACCOUNT_SEGMENT ที่ REFERENCETABLE = 'BudgetRequisition'
SELECT ID, REFERENCEID, DESCRIPTION, BUDGETTYPEID, BUDGETCODENAME, CATEGORYID
FROM   OAGWBG_ACCOUNT_SEGMENT
WHERE  REFERENCETABLE = 'BudgetRequisition'
ORDER  BY ID;

-- 5) พิสูจน์ว่า CATEGORYID เส้นทางตัน — '0000' ทุกแถว และไม่มีใน master
SELECT COUNT(DISTINCT CATEGORYID) DISTINCT_CAT FROM OAGWBG_ACCOUNT_SEGMENT
WHERE  REFERENCETABLE = 'BudgetRequisition';
SELECT COUNT(*) FOUND_IN_MASTER FROM OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V WHERE ID = '0000';
