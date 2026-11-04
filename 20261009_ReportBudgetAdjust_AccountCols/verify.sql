-- =====================================================================================
-- verify v6 — รันบน PREPROD (ebs_PRE) 172.16.11.19:1541 หลัง deploy
-- view นี้ช้าอยู่แล้วตั้งแต่ v5 (~40 วินาทีต่อ query) ไม่ใช่ผลของ v6
-- =====================================================================================

-- 1) จำนวนแถวรวมต้องเท่าก่อน deploy — 2026-10-09 = 536
--    ถ้าเพิ่ม แปลว่า join rule ทำแถวบาน (rule ไม่ได้ถูกยุบเหลือ 1 แถวต่อ category)
SELECT COUNT(*) TOTAL_ROWS FROM OAGWBG_R_BUDGETADJUST;

-- 2) ความครบของคอลัมน์ใหม่ แยกตามประเภท/ฝั่ง
--    ผล probe ก่อน deploy 2026-10-09: ทุกประเภทครบ 100% ยกเว้นประเภท 4
--      4 RECEIVER 13 แถว -> 11 / 4 SENDER 4 แถว -> 3
--      (6900012/13/14 ไม่มี ACCOUNT_SEGMENT เลย — ข้อมูลค้างเดิมตั้งแต่ v5)
SELECT TRANSFERTYPE, ROLETYPE, COUNT(*) CNT,
       COUNT(BUDGETCODE) HAS_BC, COUNT(ACCOUNTNO) HAS_ACC,
       COUNT(ACCOUNTNAME) HAS_ACCNAME, COUNT(SUBACCOUNTNO) HAS_SUB
FROM   OAGWBG_R_BUDGETADJUST
GROUP  BY TRANSFERTYPE, ROLETYPE
ORDER  BY TRANSFERTYPE, ROLETYPE;

-- 3) เงื่อนไขที่ทำให้การยุบ rule เป็น 1 แถวต่อ category ปลอดภัย — ต้องได้ 0
--    ถ้าไม่ใช่ 0 แปลว่ามี category ที่บัญชีต่างกันตามปี/ผลผลิต/กิจกรรม ต้องกลับมาทบทวน
SELECT COUNT(*) CATS_WITH_MULTI_ACC
FROM  (SELECT CATEGORYID
       FROM   OAGWBG_V_EXT_OAGPO_EXPENSE_ACCOUNT_RULE_V
       GROUP  BY CATEGORYID
       HAVING COUNT(DISTINCT ACCOUNTNO || '.' || SUBACCOUNTNO) > 1);

-- 4) ตัวอย่างค่า
SELECT ROUNDNO, ROLETYPE, BUDGETTYPENAME, BUDGETCODE, ACCOUNTNO, ACCOUNTNAME, SUBACCOUNTNO, CATEGORYNAME
FROM   OAGWBG_R_BUDGETADJUST
WHERE  ROUNDNO LIKE '69%'
ORDER  BY TRANSFERTYPE, ROUNDNO, ROLETYPE
FETCH  FIRST 30 ROWS ONLY;
