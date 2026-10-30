-- ตรวจผล OAGWBG_FN_GETBUDGET_ALLOCATE_TRANSFER_CATEGORY ก่อน/หลังรัน fix_fn_allocate_transfer_category.sql — SELECT อย่างเดียว
-- รันได้ทั้ง PREPROD (172.16.11.19:1541/ebs_PRE) และ PROD (172.16.11.18:1531/PROD) ด้วย user OAGWBG
-- ค่าคาดหวังด้านล่างได้จากการ dry-run query ชุดใหม่ (แทนพารามิเตอร์เป็นค่าคงที่) เมื่อ 2026-10-07 — ข้อมูลเปลี่ยนตามเวลา ตัวเลขอาจขยับได้เล็กน้อย

-- Q0: function ต้อง VALID หลัง compile
SELECT OBJECT_NAME, STATUS, LAST_DDL_TIME
FROM   ALL_OBJECTS
WHERE  OWNER = 'OAGWBG' AND OBJECT_NAME = 'OAGWBG_FN_GETBUDGET_ALLOCATE_TRANSFER_CATEGORY';

-- Q1: เคสที่แจ้งมา — หนองคาย/ยะลา ต้องเหลือ 1 แถวต่อรายการ และรหัสงบต้องเป็นของปีนั้น
--   ปี 2569 คาดหวัง: 2614 -> ...167 (12,271,700) / 2620 -> ...167 (12,997,400) / 2628 -> ...158 (5,480,300)
--   ปี 2570 คาดหวัง (PROD): 2614 -> ...158 (5,201,500) / 2620 -> ...141 (0) / 2628 -> ...135 (7,698,400)
--   ก่อนแก้: แต่ละรายการขึ้น 2 แถว รหัสคนละปี ยอดเท่ากัน
SELECT F.BUDGETYEAR, F.CATEGORYID, SUBSTR(F.CATEGORYNAME, 1, 50) AS CATEGORYNAME,
       REGEXP_SUBSTR(F.ACCOUNTCODE, '[^.]+', 1, 9) AS BUDGETCODEID,
       F.TOTALRECEIVEAMOUNT, F.TOTALBALANCEAMOUNT
FROM   TABLE(OAGWBG.OAGWBG_FN_GETBUDGET_ALLOCATE_TRANSFER_CATEGORY(2569, 1, NULL)) F
WHERE  F.CATEGORYID IN (2614, 2620, 2628)
UNION ALL
SELECT F.BUDGETYEAR, F.CATEGORYID, SUBSTR(F.CATEGORYNAME, 1, 50),
       REGEXP_SUBSTR(F.ACCOUNTCODE, '[^.]+', 1, 9),
       F.TOTALRECEIVEAMOUNT, F.TOTALBALANCEAMOUNT
FROM   TABLE(OAGWBG.OAGWBG_FN_GETBUDGET_ALLOCATE_TRANSFER_CATEGORY(2570, 1, NULL)) F
WHERE  F.CATEGORYID IN (2614, 2620, 2628)
ORDER  BY 1, 2, 4;

-- Q2: ภาพรวม — จำนวนแถว / แถวที่รหัสงบไม่ใช่ของปีนั้นแต่เป็นของปีอื่นใน BUDGETCODE_YEAR (OTHER_YEAR_CODE)
--   p_BudgetSource = NULL คือค่าที่ modal ส่งตอนเปิดครั้งแรก
--
--                     ก่อนแก้ (ROWS / OTHER_YEAR / SUM_RECV)          หลังแก้ (ROWS / OTHER_YEAR / SUM_RECV)
--   PROD    2569      739 / 270 / 29,810,228,075.55                    469 / 0 / 15,250,101,875.55
--   PROD    2570      464 / 193 /  8,336,846,587.00                    271 / 0 /  4,398,731,587.00
--   PREPROD 2569      715 /   6 / 32,724,609,128.55                    484 / 2 / 15,249,072,628.55
--   PREPROD 2570       10 /   2 /     43,068,440.00                     10 / 2 /     35,055,440.00
--
--   OTHER_YEAR ที่ยังเหลือบน PREPROD หลังแก้ = รหัสที่บันทึกไว้ในใบจอง/ใบโอน (BRSC / obc) ไม่ได้มาจาก BCY — ไม่เกี่ยวกับ fix นี้
--   PREPROD 2570 แถวเท่าเดิมแต่ยอดลด เพราะเงิน 400 (ปี 2568) เคยถูกคูณตามจำนวนปีใน BCY (2213 = x3, 2291/2477 = x2)
--   หลังแก้ตรงกับ OAGWBG_BUDGETRECEIVE จริง: 68030002 = 8,000,000 / 68030003 = 1,000 / 68030004 = 5,000 / 68030005 = 1,000
--   (จัดกลุ่มตามปีที่ส่งเข้า function ไม่ใช่ BUDGETYEAR ของแถว เพราะเงิน 400 ติดมาด้วยในปีของตัวเอง เช่น 2568)
WITH F AS (
    SELECT 2569 AS CALL_YEAR, X.*, REGEXP_SUBSTR(X.ACCOUNTCODE, '[^.]+', 1, 9) AS BC
    FROM   TABLE(OAGWBG.OAGWBG_FN_GETBUDGET_ALLOCATE_TRANSFER_CATEGORY(2569, 1, NULL)) X
    UNION ALL
    SELECT 2570, X.*, REGEXP_SUBSTR(X.ACCOUNTCODE, '[^.]+', 1, 9)
    FROM   TABLE(OAGWBG.OAGWBG_FN_GETBUDGET_ALLOCATE_TRANSFER_CATEGORY(2570, 1, NULL)) X
)
SELECT F.CALL_YEAR,
       COUNT(*) AS ROWS_,
       SUM(CASE WHEN NOT EXISTS (SELECT 1 FROM OAGWBG.OAGWBG_BUDGETCODE_YEAR Y
                                 WHERE Y.CATEGORYID = F.CATEGORYID AND Y.PRODUCTID = F.PRODUCTID
                                 AND   Y.ACTIVITYCODEID = F.ACTIVITYID AND Y.BUDGETYEAR = F.BUDGETYEAR
                                 AND   Y.BUDGETCODEID = F.BC)
                 AND EXISTS (SELECT 1 FROM OAGWBG.OAGWBG_BUDGETCODE_YEAR Y
                             WHERE Y.CATEGORYID = F.CATEGORYID AND Y.PRODUCTID = F.PRODUCTID
                             AND   Y.ACTIVITYCODEID = F.ACTIVITYID AND Y.BUDGETYEAR <> F.BUDGETYEAR
                             AND   Y.BUDGETCODEID = F.BC)
                THEN 1 ELSE 0 END) AS OTHER_YEAR_CODE,
       SUM(F.TOTALRECEIVEAMOUNT) AS SUM_RECV
FROM   F
GROUP  BY F.CALL_YEAR
ORDER  BY 1;

-- Q3: เงื่อนไขที่ fix พึ่งพา — BUDGETCODE_YEAR ต้องมีไม่เกิน 1 แถวต่อ ปี+ผลผลิต+กิจกรรม+รายการ (ต้องได้ 0 แถว)
--   ถ้าวันหน้ามีแถวซ้ำในปีเดียวกัน รายการจะกลับมาแตกแถวอีก
SELECT BUDGETYEAR, PRODUCTID, ACTIVITYCODEID, CATEGORYID, COUNT(*) AS N
FROM   OAGWBG.OAGWBG_BUDGETCODE_YEAR
GROUP  BY BUDGETYEAR, PRODUCTID, ACTIVITYCODEID, CATEGORYID
HAVING COUNT(*) > 1;
