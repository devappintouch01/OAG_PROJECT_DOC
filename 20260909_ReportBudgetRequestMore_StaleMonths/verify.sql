-- ตรวจสอบเคส "รายงานยังจำเดือนเดิมที่เคยบันทึกไว้"
-- PREPROD: 172.16.11.19:1541 / SERVICE_NAME=ebs_PRE / User=OAGWBG
-- เคสอ้างอิง: คำขอ 100-335/2569

-- 1) หาคำขอ
SELECT ID, CODE, BUDGETYEAR, STATUSID, COSTCENTERID, DEPARTMENTID, VERSION, CREATEON, UPDATEON
FROM   OAGWBG.OAGWBG_BUDGETREQUEST
WHERE  CODE = '100-335/2569';
-- => ID 2288, BUDGETYEAR 2569, STATUSID 10101

-- 2) รายการค่าใช้จ่ายใต้คำขอ
SELECT ID, CODE, BUDGETDETAIL, CATEGORYID, PRODUCTID, ACTIVITYCODEID,
       TOTALREQUESTAMOUNT, EQUIPMENTCASE, IS_COSTCENTER
FROM   OAGWBG.OAGWBG_BUDGETGOVERNMENT
WHERE  BUDGETREQUESTID = 2288
ORDER  BY ID;
-- => ID 73621 "วัสดุเชื้อเพลิง"

-- 3) แถวประมาณการใช้จ่าย — เรียงตามปีงบประมาณ (ต.ค. -> ก.ย.)
--    ดู CREATEON/UPDATEON เพื่อแยกแถวที่บันทึกครั้งแรก กับแถวที่โดน update เป็น 0 ตอนแก้ไข
SELECT E.BUDGETGOVERNMENTID, E.ID, E.MONTH, E.PLANAMOUNT,
       E.BUDGETYEAR, E.VERSION, E.CREATEON, E.UPDATEON
FROM   OAGWBG.OAGWBG_BUDGETDISBURSEMENTESTIMATED E
WHERE  E.BUDGETGOVERNMENTID IN (
           SELECT ID FROM OAGWBG.OAGWBG_BUDGETGOVERNMENT WHERE BUDGETREQUESTID = 2288
       )
ORDER  BY E.BUDGETGOVERNMENTID,
          CASE WHEN E.MONTH >= 10 THEN E.MONTH - 12 ELSE E.MONTH END;
-- => 1549/เดือน 10/ยอด 0 (UPDATEON 14:41:19)
--    1550/เดือน 11/ยอด 0 (UPDATEON 14:41:19)
--    1551/เดือน 1/ยอด 500, 1552/เดือน 2/ยอด 500, 1553/เดือน 3/ยอด 500


-- ============================================================
-- 4) จำลองการเลือกเดือนของรายงาน (pickedMonths .Take(3))
--    ก่อนแก้ — ไม่กรอง PLANAMOUNT
-- ============================================================
SELECT MONTH
FROM   (
    SELECT DISTINCT E.MONTH
    FROM   OAGWBG.OAGWBG_BUDGETDISBURSEMENTESTIMATED E
    WHERE  E.BUDGETGOVERNMENTID IN (
               SELECT ID FROM OAGWBG.OAGWBG_BUDGETGOVERNMENT WHERE BUDGETREQUESTID = 2288
           )
    AND    E.BUDGETYEAR = 2569
    AND    E.MONTH IS NOT NULL
    ORDER  BY CASE WHEN MONTH >= 10 THEN MONTH - 12 ELSE MONTH END
)
WHERE ROWNUM <= 3;
-- => 10, 11, 1   (ต.ค. 0 / พ.ย. 0 / ม.ค. 500 — ก.พ. + มี.ค. หลุด)


-- ============================================================
-- 5) หลังแก้ — กรอง PLANAMOUNT > 0
-- ============================================================
SELECT MONTH
FROM   (
    SELECT DISTINCT E.MONTH
    FROM   OAGWBG.OAGWBG_BUDGETDISBURSEMENTESTIMATED E
    WHERE  E.BUDGETGOVERNMENTID IN (
               SELECT ID FROM OAGWBG.OAGWBG_BUDGETGOVERNMENT WHERE BUDGETREQUESTID = 2288
           )
    AND    E.BUDGETYEAR = 2569
    AND    E.MONTH IS NOT NULL
    AND    NVL(E.PLANAMOUNT, 0) > 0
    ORDER  BY CASE WHEN MONTH >= 10 THEN MONTH - 12 ELSE MONTH END
)
WHERE ROWNUM <= 3;
-- => 1, 2, 3   (ม.ค. 500 / ก.พ. 500 / มี.ค. 500 = 1,500 ถูกต้อง)


-- ============================================================
-- 6) ขนาดของขยะที่ค้างทั้งระบบ ปีงบ 2569
--    แถว PLANAMOUNT = 0 ที่เคยถูกบันทึกแล้วโดนแก้ทีหลัง (UPDATEON IS NOT NULL)
-- ============================================================
SELECT COUNT(*) AS ZERO_ROWS,
       COUNT(DISTINCT BUDGETGOVERNMENTID) AS AFFECTED_BG
FROM   OAGWBG.OAGWBG_BUDGETDISBURSEMENTESTIMATED
WHERE  BUDGETYEAR = 2569
AND    NVL(PLANAMOUNT, 0) = 0;
-- => ZERO_ROWS 30 / AFFECTED_BG 10  (รันเมื่อ 2026-09-09)

-- รายการที่ "จำนวนเดือนทั้งหมด" มากกว่า "เดือนที่มียอดจริง" = โดนผลกระทบแน่นอน
SELECT BUDGETGOVERNMENTID,
       COUNT(*)                                          AS TOTAL_MONTHS,
       SUM(CASE WHEN NVL(PLANAMOUNT,0) > 0 THEN 1 ELSE 0 END) AS MONTHS_WITH_AMOUNT
FROM   OAGWBG.OAGWBG_BUDGETDISBURSEMENTESTIMATED
WHERE  BUDGETYEAR = 2569
GROUP  BY BUDGETGOVERNMENTID
HAVING COUNT(*) > SUM(CASE WHEN NVL(PLANAMOUNT,0) > 0 THEN 1 ELSE 0 END)
ORDER  BY BUDGETGOVERNMENTID;
-- => 10 รายการ (รันเมื่อ 2026-09-09)
