-- =====================================================================
-- SEG12: นับข้อมูลที่ "ยังมีชีวิต" แยกตามงานธุรกิจ
--   X.1 = ข้อมูลที่ตอนนี้ยังนำไปทำรายการต่อได้ (ถังเงิน / รายการต้นทางที่ยังมียอด)
--   X.2 = เอกสารที่กำลังทำอยู่หรือยังทำไม่เสร็จ (ร่าง / จองงบ) และเอกสารที่ยืนยันแล้วแต่ยังยกเลิกได้
-- ทำไมต้องนับ: เอกสารพวกนี้ถ้าทำต่อหลังวันตัดเปลี่ยน seg12 จะส่ง interface ปนกันระหว่าง 00 กับค่าใหม่
-- SELECT อย่างเดียว / ปีงบปัจจุบัน = 2570 (เริ่ม 1 ต.ค. 2569) จึงดูตั้งแต่ปี 2569 ขึ้นไป
--
-- ความหมายสถานะ (OAGWBG_MASTERSTATUS ตรวจ PREPROD 2026-11-10)
--   80101 ร่าง / 80401 จองงบประมาณ / 80201 บันทึกการโอน (ยืนยัน ส่ง GL แล้ว) / 80501 ยกเลิกการโอน / 90109 ยกเลิก
--   90101 ร่าง / 90102 ขยายเวลา / 90201 บันทึก / 90202 ตรวจสอบแล้ว / 20202 อนุมัติเงินกัน / 90110 ยกเลิกการกันเงิน
--   10101 ร่าง / 10102 ส่งกลับแก้ไข / 10199 เจ้าของเรื่องยกเลิก / 20101 ส่งเรื่อง / 20102 สบง.แก้ไข / 20201 อนุมัติคำของบ
--   BUDGETGOVERNMENT.BUDGETSTATUS (CHAR 1): R ร่าง / C ยืนยันส่ง GL แล้ว / D ยกเลิกการยืนยัน /
--     B ยังไม่ยืนยันหรือถูกเปิดกลับมาแก้ (C→B ตอนยกเลิก) / X ลบทั้งใบ / U, A สถานะช่วงคำของบ (ไม่เกี่ยวกับ interface)
--   OAGWBG_BUDGETTRANSFER.TRANSFERTYPE: 1 โอนเปลี่ยนแปลง / 2 โอนกลับ / 3 โอนปรับเงินเหลือจ่าย / 4 โอนกลับข้ามหลายปี
--
-- ผลบน PREPROD 2026-11-10 (รันครบ 13 statement ไม่มี error)
--   1.1 ถังโอนจัดสรรได้ ปี 2569: แหล่ง 100 = 268 แถว (3,084 ล้าน) / 200 = 72 แถว (915 ล้าน) / 400 = 11 แถว (32.7 ล้าน)
--       ปี 2570: แหล่ง 200 = 3 แถว / แหล่ง 100 ยังไม่มี เพราะ พ.ร.บ. 2570 ยังไม่ยืนยัน (ข้อ 6 สถานะ B)
--   1.2 ใบโอนจัดสรร ค้าง: ร่าง 1,461 + จองงบ 21 / ยืนยันแล้วยกเลิกได้ 873 (+ โอนจัดสรรเพิ่มเติม ร่าง 112, จองงบ 7, ยืนยัน 8)
--   2.1 บรรทัดงบที่โอนกลับได้ ปี 2569 แหล่ง 100 = 18,221 บรรทัด 391 ศูนย์ต้นทุน (16,961 ล้าน)
--   2.2 ใบโอนกลับ ค้าง: ร่าง 332 + จองงบ 9 / ยืนยันแล้วยกเลิกได้ 21
--   3.2 โอนเปลี่ยนแปลง ค้าง 9 / ยืนยันแล้ว 12   4.2 โอนปรับเงินเหลือจ่าย ร่าง 8 / ยืนยันแล้ว 11 (ไม่ส่ง interface)
--   5.1 PR คงเหลือ 378 บรรทัด / PO คงเหลือ (ไม่ปิด) 496 บรรทัด — SEGMENT12 จาก EBS = 00 ทุกแถว
--       ⚠️ BUDGETYEAR ใน view PO เป็น 2 หลัก (68, 69) แต่ view PR เป็น 4 หลัก (2568, 2569)
--   5.2 ใบเงินกันที่ยังไม่ยกเลิก 45 ใบ (อนุมัติ 33, ขยายเวลา 7, ร่าง 2, บันทึก 2, ตรวจสอบแล้ว 1 — บางใบอยู่ปี 2570 แล้ว)
--   5.3 รายการเงินกันที่มี ACCOUNTCODE ทั้งหมดเป็น 00 (101 รายการ) / LUMP ไม่มี ACCOUNTCODE
--   6   พ.ร.บ. ปี 2569 ยืนยันแล้ว (C) 9,692 แถว / ปี 2570 ยังไม่ยืนยัน (B) 14,739 แถว
--   7   GF ยืนยันแล้ว 12 ใบ / ร่าง 15 ใบ
--   8.2 เบิกแทน ร่าง 3 / ยืนยันแล้ว 5     9.2 เงินนอกงบประมาณ ร่าง 1 / ยืนยันแล้ว 46
--   10  นับทุก form type ไว้เทียบ / งบเพิ่มเติม = ฟอร์ม 3 (ดูข้อ 10.1)
--
-- ผลรายรายการบน PREPROD 2026-11-11 (เพิ่ม 7 statement 6.3–10.1 รันทั้งไฟล์ 20 statement ไม่มี error, ช้าสุด 3–5 วิ)
--   6.3 รายการ พ.ร.บ. แผนงาน 2569 = 482 รายการ (C) / 2570 = 633 รายการ (B) — 1,140 แถวรวมปีอื่น
--       ✅ ยอด พ.ร.บ. รวมตรงกับหัวหน้าจอ (V_BUDGETALLOCATELIST) ทั้ง 2569 = 15,000,461,400 และ 2570 = 14,951,991,382.48
--       ยอดคำขอที่หัวหน้าจอ = คำของบ + คำขอแปรญัตติ (2569 ต่างกัน 114,262,600 = ยอดคำขอแปรญัตติพอดี)
--   6.4 แถวรายคำขอ 1,452 แถว   6.5 โครงการ 48 โครงการ (2569 = 45 / 2573 = 3) — 3 โครงการใช้ ALLOCATEDBUDGET เพราะไม่ใช่ 1:1
--   7.1 GF 2569 งบประจำปี ยืนยันแล้ว 4 ใบ 718 บรรทัด = 15,000,461,400 (เท่ายอด พ.ร.บ. 2569) มี log ครบทุกบรรทัด seg12 = 00
--       GF งบเพิ่มเติม ยืนยันแล้ว 6 ใบ 6 บรรทัด / ร่าง 1 ใบ 1 บรรทัด
--   8.1 เบิกแทน ยืนยันแล้ว 5 ใบ 6 ชุดบัญชี / ร่าง 3 ใบยังไม่มีชุดบัญชี   9.1 เงินนอกงบประมาณ ยืนยันแล้ว 46 ใบ 174 ชุดบัญชี / ร่าง 1 ใบ 3 ชุดบัญชี
--   10.1 งบเพิ่มเติม 2569 ร่าง 219 คำขอ 334 บรรทัด / ยืนยันแล้ว 177 คำขอ 296 บรรทัด (+ เวอร์ชันเก่า 3 คำขอ) / 2570 ยืนยันแล้ว 11 คำขอ
--       ⚠️ ไม่มี batch ADD_BUDGET_ เลยทั้งที่มีคำขอยืนยันแล้ว — น่าจะยืนยันตอน isConnection = false (เปลี่ยนสถานะอย่างเดียว) ยังไม่ได้ตรวจ
--
-- ⚠️ ข้อจำกัด
--   - X.1 นับจากยอดคงเหลือในระบบเรา ไม่ได้เช็คงบจริงใน GL (หน้าจอเช็คผ่าน find_budget ซึ่งสร้าง CCID ได้ จึงไม่เรียกใน query นี้)
--   - "ยืนยันแล้ว ยังยกเลิกได้" นับจากสถานะอย่างเดียว ด่านยกเลิกจริงยังตรวจเอกสารปลายทางและยอดใน GL เพิ่ม
-- =====================================================================


-- =====================================================================
-- 1. โอนจัดสรร
-- =====================================================================

-- 1.1 ถังเงินที่ยังโอนจัดสรรได้ (ผลของ fn เดียวกับหน้าจอ แถวที่ TOTALBALANCEAMOUNT > 0)
--     fn รับ (ปี, TRANSFERORGTYPE, แหล่งเงิน) ต้องเรียกทีละชุด
--     ตรวจ PREPROD 2026-11-10: ORGTYPE 1 กับ 2 ได้ผลเท่ากันทุกแถว จึงเรียกแค่ 1 (ไม่งั้นนับซ้ำ)
--     แหล่ง 400 (เงินกันส่วนกลาง) ได้ผลเท่ากันทั้งปี 2569 และ 2570 = ถังเดียวกัน ให้นับครั้งเดียว
SELECT '1.1 โอนจัดสรรได้' TOPIC, p.Y BUDGETYEAR, p.SRC BUDGETSOURCEID,
       COUNT(*) ROWS_CNT, COUNT(DISTINCT f.ACCOUNTCODE) ACCOUNT_CNT, SUM(f.TOTALBALANCEAMOUNT) BALANCE_AMT
FROM (SELECT 2569 Y, 100 SRC FROM DUAL UNION ALL SELECT 2569,200 FROM DUAL UNION ALL SELECT 2569,400 FROM DUAL
      UNION ALL SELECT 2570,100 FROM DUAL UNION ALL SELECT 2570,200 FROM DUAL) p,
     TABLE(OAGWBG.OAGWBG_FN_GETBUDGET_ALLOCATE_TRANSFER_CATEGORY(p.Y, 1, p.SRC)) f
WHERE f.TOTALBALANCEAMOUNT > 0
GROUP BY p.Y, p.SRC
ORDER BY 2,3;

-- 1.2 ใบโอนจัดสรร (รวมโอนจัดสรรเพิ่มเติม) ที่ยังทำไม่เสร็จ / ยืนยันแล้วยังยกเลิกได้
SELECT '1.2 ใบโอนจัดสรร' TOPIC, t.DOC, t.BUDGETYEAR, t.TRANSFERSTATUS, s.NAME STATUS_NAME,
       CASE WHEN t.TRANSFERSTATUS IN ('80101','80401') THEN 'ค้าง (ยังไม่ส่ง GL หรือจองงบอยู่)'
            WHEN t.TRANSFERSTATUS = '80201' THEN 'ยืนยันแล้ว ยกเลิกได้ (ขากลับต้องใช้ 00)' END STATE,
       COUNT(*) DOC_CNT, SUM(t.TOTALRECEIVEAMOUNT) AMT
FROM (SELECT 'โอนจัดสรร' DOC, BUDGETYEAR, TRANSFERSTATUS, TOTALRECEIVEAMOUNT FROM OAGWBG_BUDGETALLOCATETRANSFER
      UNION ALL
      SELECT 'โอนจัดสรรเพิ่มเติม', BUDGETYEAR, TRANSFERSTATUS, TOTALRECEIVEAMOUNT FROM OAGWBG_BUDGETALLOCATETRANSFERMORE) t
LEFT JOIN OAGWBG_MASTERSTATUS s ON TO_CHAR(s.ID) = t.TRANSFERSTATUS
WHERE t.TRANSFERSTATUS IN ('80101','80401','80201') AND t.BUDGETYEAR >= 2569
GROUP BY t.DOC, t.BUDGETYEAR, t.TRANSFERSTATUS, s.NAME
ORDER BY 2,3,4;


-- =====================================================================
-- 2. โอนกลับ (TRANSFERTYPE 2 และ 4)
-- =====================================================================

-- 2.1 รายการที่ยังโอนกลับได้ = บรรทัดงบของหน่วยงานที่ยอดคงเหลือ > 0
--     (เงื่อนไขเดียวกับ GetBudgetTransferDetailRows: V_BUDGETRECEIVESUMMARY_REFUND.TOTALBALANCEAMOUNT > 0)
--     view นี้ยุบเป็นบรรทัดงบ 1 แถวต่อ (หน่วยงาน, ศูนย์ต้นทุน, ปี, แหล่งเงิน, หมวด, ...)
SELECT '2.1 โอนกลับได้' TOPIC, BUDGETYEAR, BUDGETSOURCEID,
       COUNT(*) LINE_CNT, COUNT(DISTINCT COSTCENTERID) COSTCENTER_CNT, SUM(TOTALBALANCEAMOUNT) BALANCE_AMT
FROM OAGWBG_V_BUDGETRECEIVESUMMARY_REFUND
WHERE TOTALBALANCEAMOUNT > 0 AND BUDGETYEAR >= 2569
GROUP BY BUDGETYEAR, BUDGETSOURCEID
ORDER BY 2,3;

-- 2.2 ใบโอนกลับที่ยังทำไม่เสร็จ / ยืนยันแล้วยังยกเลิกได้
SELECT '2.2 ใบโอนกลับ' TOPIC,
       DECODE(t.TRANSFERTYPE,'2','โอนกลับ','4','โอนกลับข้ามหลายปี') DOC,
       CASE WHEN t.TRANSFERTYPE = '4' THEN 'ข้ามหลายปี'
            WHEN NVL(t.FROMBUDGETYEAR, t.BUDGETYEAR) = t.BUDGETYEAR THEN 'ปีเดียวกัน' ELSE 'ข้ามปี' END YEAR_KIND,
       t.BUDGETYEAR, t.TRANSFERSTATUSID, s.NAME STATUS_NAME,
       CASE WHEN t.TRANSFERSTATUSID IN (80101,80401) THEN 'ค้าง (ยังไม่ส่ง GL หรือจองงบอยู่)'
            WHEN t.TRANSFERSTATUSID = 80201 THEN 'ยืนยันแล้ว ยกเลิกได้ (ขากลับต้องใช้ 00)' END STATE,
       COUNT(*) DOC_CNT, SUM(t.TOTALTRANSFERAMOUNT) AMT
FROM OAGWBG_BUDGETTRANSFER t
LEFT JOIN OAGWBG_MASTERSTATUS s ON s.ID = t.TRANSFERSTATUSID
WHERE t.TRANSFERTYPE IN ('2','4') AND t.TRANSFERSTATUSID IN (80101,80401,80201) AND t.BUDGETYEAR >= 2569
GROUP BY t.TRANSFERTYPE,
         CASE WHEN t.TRANSFERTYPE = '4' THEN 'ข้ามหลายปี'
              WHEN NVL(t.FROMBUDGETYEAR, t.BUDGETYEAR) = t.BUDGETYEAR THEN 'ปีเดียวกัน' ELSE 'ข้ามปี' END,
         t.BUDGETYEAR, t.TRANSFERSTATUSID, s.NAME
ORDER BY 2,3,4,5;


-- =====================================================================
-- 3. โอนเปลี่ยนแปลง (TRANSFERTYPE 1)
--    3.1 ใช้ถังเดียวกับโอนกลับ (ยอดคงเหลือของบรรทัดงบ) ดูข้อ 2.1 ไม่นับซ้ำ
-- =====================================================================

-- 3.2 ใบโอนเปลี่ยนแปลงที่ยังทำไม่เสร็จ / ยืนยันแล้วยังยกเลิกได้
--     หัวใบ (TRANSFERTYPE 1) ไม่เก็บยอด ยอดอยู่ที่ OAGWBG_BUDGETADJUST (ขาโอนออก)
SELECT '3.2 ใบโอนเปลี่ยนแปลง' TOPIC, t.BUDGETYEAR, t.TRANSFERSTATUSID, s.NAME STATUS_NAME,
       CASE WHEN t.TRANSFERSTATUSID IN (80101,80401) THEN 'ค้าง'
            WHEN t.TRANSFERSTATUSID = 80201 THEN 'ยืนยันแล้ว ยกเลิกได้ (ขากลับต้องใช้ 00)' END STATE,
       COUNT(*) DOC_CNT, SUM(a.AMT) AMT
FROM OAGWBG_BUDGETTRANSFER t
LEFT JOIN (SELECT BUDGETTRANSFERID, SUM(TOTALTRANSFERAMOUNT) AMT FROM OAGWBG_BUDGETADJUST GROUP BY BUDGETTRANSFERID) a
       ON a.BUDGETTRANSFERID = t.ID
LEFT JOIN OAGWBG_MASTERSTATUS s ON s.ID = t.TRANSFERSTATUSID
WHERE t.TRANSFERTYPE = '1' AND t.TRANSFERSTATUSID IN (80101,80401,80201) AND t.BUDGETYEAR >= 2569
GROUP BY t.BUDGETYEAR, t.TRANSFERSTATUSID, s.NAME
ORDER BY 2,3;


-- =====================================================================
-- 4. โอนปรับเงินเหลือจ่าย (TRANSFERTYPE 3) — ไม่ส่ง interface (โค้ดถูก comment) นับไว้เผื่อเปิดใช้
--    4.1 ใช้ V_BUDGETRECEIVESUMMARY_REFUND เหมือนข้อ 2.1 แต่หน้าจอใช้เงื่อนไข TOTALBALANCEAMOUNT >= 0
-- =====================================================================

SELECT '4.2 ใบโอนปรับเงินเหลือจ่าย' TOPIC, t.BUDGETYEAR, t.TRANSFERSTATUSID, s.NAME STATUS_NAME,
       COUNT(*) DOC_CNT, SUM(t.TOTALTRANSFERAMOUNT) AMT
FROM OAGWBG_BUDGETTRANSFER t
LEFT JOIN OAGWBG_MASTERSTATUS s ON s.ID = t.TRANSFERSTATUSID
WHERE t.TRANSFERTYPE = '3' AND t.TRANSFERSTATUSID IN (80101,80401,80201) AND t.BUDGETYEAR >= 2568
GROUP BY t.BUDGETYEAR, t.TRANSFERSTATUSID, s.NAME
ORDER BY 2,3;


-- =====================================================================
-- 5. เงินกันเหลื่อมปี (ส่วนกลาง + หน่วยงาน)
-- =====================================================================

-- 5.1 PR/PO ใน EBS ที่ยังมียอดคงเหลือ (นำมากัน/ขยายเวลาต่อได้)
--     PR: view ตัดรายการยอดหมดออกให้แล้ว / PO: view ยังมีแถว CLOSED และยอดติดลบ ต้องกรองเอง
--     SEGMENT12 มาจาก EBS โดยตรง = ชุดบัญชีที่ PR/PO ผูกอยู่จริง
SELECT '5.1 PR คงเหลือ' TOPIC, TO_CHAR(BUDGETYEAR) BUDGETYEAR, TO_CHAR(BUDGETSOURCEID) BUDGETSOURCEID, TO_CHAR(SEGMENT12) SEGMENT12,
       COUNT(*) LINE_CNT, COUNT(DISTINCT PR_NUMBER) DOC_CNT, COUNT(DISTINCT BUDGET_ACCOUNT) ACCOUNT_CNT, SUM(REMAINING_AMOUNT) REMAIN_AMT
FROM OAGWBG_V_BUDGETOVERLAPYEAR_PR
WHERE REMAINING_AMOUNT > 0
GROUP BY TO_CHAR(BUDGETYEAR), TO_CHAR(BUDGETSOURCEID), TO_CHAR(SEGMENT12)
UNION ALL
SELECT '5.1 PO คงเหลือ', TO_CHAR(BUDGETYEAR), TO_CHAR(BUDGETSOURCEID), TO_CHAR(SEGMENT12),
       COUNT(*), COUNT(DISTINCT PO_NUMBER), COUNT(DISTINCT BUDGET_ACCOUNT), SUM(REMAINING_AMOUNT)
FROM OAGWBG_V_BUDGETOVERLAPYEAR_PO
WHERE REMAINING_AMOUNT > 0 AND NVL(CLOSED_CODE,'OPEN') <> 'CLOSED'
GROUP BY TO_CHAR(BUDGETYEAR), TO_CHAR(BUDGETSOURCEID), TO_CHAR(SEGMENT12)
ORDER BY 1,2,3,4;

-- 5.2 ใบเงินกันที่ยังไม่ยกเลิก แยกสถานะ (ร่าง / บันทึก / ตรวจสอบแล้ว / อนุมัติ / ขยายเวลา)
--     BUDGETRESERVEDTYPE R = ส่วนกลาง?, O = ?; RESERVATIONTYPE 20/30 — ยังไม่ได้ยืนยันความหมาย แสดงค่าดิบไว้
SELECT '5.2 ใบเงินกัน' TOPIC, r.BUDGETYEAR, r.BUDGETRESERVEDTYPE, r.RESERVATIONTYPE, r.STATUSID, s.NAME STATUS_NAME,
       COUNT(*) DOC_CNT, SUM(r.TOTALRESERVEDAMOUNT) RESERVED_AMT, MAX(r.ROUNDINTERFACE) MAX_ROUND
FROM OAGWBG_BUDGETRESERVED r
LEFT JOIN OAGWBG_MASTERSTATUS s ON s.ID = r.STATUSID
WHERE NVL(r.STATUSID,0) NOT IN (90109, 90110, 10197)
GROUP BY r.BUDGETYEAR, r.BUDGETRESERVEDTYPE, r.RESERVATIONTYPE, r.STATUSID, s.NAME
ORDER BY 2,3,4,5;

-- 5.3 รายการในใบเงินกันที่ยังไม่ยกเลิก แยกตาม seg12 ที่เก็บใน ACCOUNTCODE (สตริงนี้ถูกใช้ส่ง interface รอบถัดไป)
SELECT '5.3 รายการเงินกัน' TOPIC, i.BUDGETRESERVEDTYPE ITEM_TYPE, NVL(REGEXP_SUBSTR(i.ACCOUNTCODE,'[^.]+',1,12),'(ไม่มี ACCOUNTCODE)') SEG12,
       COUNT(*) ITEM_CNT, COUNT(DISTINCT i.ACCOUNTCODE) ACCOUNT_CNT, SUM(i.USAGEAMOUNT) USAGE_AMT
FROM OAGWBG_BUDGETRESERVEDITEM i
JOIN OAGWBG_BUDGETRESERVED r ON r.ID = i.BUDGETREVERSEDID
WHERE NVL(r.STATUSID,0) NOT IN (90109, 90110, 10197)
GROUP BY i.BUDGETRESERVEDTYPE, NVL(REGEXP_SUBSTR(i.ACCOUNTCODE,'[^.]+',1,12),'(ไม่มี ACCOUNTCODE)')
ORDER BY 2,3;


-- =====================================================================
-- 6. พ.ร.บ. (แผนงาน + โครงการ) — OAGWBG_BUDGETGOVERNMENT
--    6.1 ยังไม่ยืนยันส่ง GL (B) = กดยืนยันแล้วจะส่ง interface
--    6.2 ยืนยันแล้ว (C) = ยกเลิกการยืนยันได้ (ขากลับประกอบใหม่ด้วย 00) และยืนยันซ้ำได้
--    แสดงแยก BUDGETGOVERNMENTTYPE เพราะหน้า พ.ร.บ. ใช้ทั้งแถวหัวและแถวคำขอ (type 4/5/6/7/8/ว่าง) ยังไม่ได้ยืนยันว่า type ไหนส่ง GL
-- =====================================================================
SELECT '6 พ.ร.บ.' TOPIC, BUDGETYEAR, NVL(BUDGETGOVERNMENTTYPE,'(ว่าง)') GOV_TYPE, BUDGETSTATUS,
       DECODE(BUDGETSTATUS,'B','6.1 ยังไม่ยืนยัน/เปิดแก้','C','6.2 ยืนยันแล้ว ยกเลิกได้') STATE,
       COUNT(*) ROWS_CNT, SUM(TOTALALLOCATEAMOUNT) ALLOCATE_AMT
FROM OAGWBG_BUDGETGOVERNMENT
WHERE BUDGETSTATUS IN ('B','C') AND NVL(BUDGETGOVERNMENTTYPE,'-') <> '2' AND BUDGETYEAR >= 2569
GROUP BY BUDGETYEAR, NVL(BUDGETGOVERNMENTTYPE,'(ว่าง)'), BUDGETSTATUS
ORDER BY 2,3,4;

-- 6.3 พ.ร.บ. แผนงาน (ฟอร์ม 1) — 1 แถวต่อ "รายการ" เหมือนหน้า BudgetAllocateDetail (แท็บแผนงานบุคลากร/พื้นฐาน/ยุทธศาสตร์/บูรณาการ)
--     ตามสูตร GetBudgetAllocateItemsGroupByPlanId:
--       กรองแถว view: (TOTALREQUESTSIMMARYAMOUNT <> 0 หรือ null) หรือ BUDGETREQUESTID = 0 / ตัดแถวคำขอแม่ที่มีคำขอลูกในปีเดียวกัน
--       ยอดเสนอจัดสรร/แปรญัตติ/คำขอแปรญัตติ/กันส่วนกลาง: view แปะยอด record เดียวซ้ำทุกแถวคำขอ จึงนับ 1 ครั้งต่อ record id
--       รายการค่ากลาง (DUMMY_FLAG = YES) ไม่มี record type 8/6/5 ยอดจริงอยู่ที่ REQ_* ของแถวคำขอ
--     ชื่อคอลัมน์ยอดตามหัวตารางหน้าจอ / "งบประมาณ (พ.ร.บ.)" = เสนอจัดสรร + แปรญัตติ
--     ROW_STATUS = สถานะแถวที่หน้าจอใช้ (แถวไม่ใช่ค่ากลางก่อน) / B_ROWS, C_ROWS = จำนวนแถว view ที่เป็น B / C ในรายการนั้น
--     ตรวจแล้ว: ผลรวม "งบประมาณ (พ.ร.บ.)" ต่อปีเท่ากับ "รวมเงินงบประมาณ (พ.ร.บ.)" ที่หัวหน้าจอ
WITH v0 AS (           -- view หนัก (~4 วิ) อ่านครั้งเดียว ใช้ทั้งกรองแถวและเช็คคำขอลูก
  SELECT /*+ MATERIALIZE */ * FROM OAGWBG_V_BUDGETALLOCATEITEM WHERE BUDGETYEAR >= 2569
), v AS (
  SELECT x.*
  FROM v0 x
  WHERE x.BUDGETFORMTYPEID = 1
    AND (NVL(x.TOTALREQUESTSIMMARYAMOUNT, -1) <> 0 OR x.BUDGETREQUESTID = 0)
    AND (x.PARENTID IS NOT NULL
         OR NOT EXISTS (SELECT 1 FROM v0 c
                        WHERE c.BUDGETYEAR = x.BUDGETYEAR AND c.PARENTID IS NOT NULL AND c.PARENTID = x.BUDGETREQUESTID))
), r AS (
  SELECT v.*,
         MAX(CASE WHEN UPPER(v.DUMMY_FLAG) = 'YES' THEN 1 ELSE 0 END)
           OVER (PARTITION BY v.BUDGETYEAR, v.BUDGET_PLAN_ID, v.PRODUCTID, v.ACTIVITYCODEID, v.BUDGET_TYPE_ID, v.CATEGORY_ID) IS_DUMMY,
         CASE WHEN v.REQUESTADJUSTID IS NULL OR ROW_NUMBER() OVER (PARTITION BY v.BUDGETYEAR, v.BUDGET_PLAN_ID, v.PRODUCTID, v.ACTIVITYCODEID, v.BUDGET_TYPE_ID, v.CATEGORY_ID, v.REQUESTADJUSTID ORDER BY v.BUDGET_GOVERNMENT_ID) = 1 THEN v.TOTALREQUESTADJUSTAMOUNT END RQADJ_1,
         CASE WHEN v.ALLOCATEID      IS NULL OR ROW_NUMBER() OVER (PARTITION BY v.BUDGETYEAR, v.BUDGET_PLAN_ID, v.PRODUCTID, v.ACTIVITYCODEID, v.BUDGET_TYPE_ID, v.CATEGORY_ID, v.ALLOCATEID      ORDER BY v.BUDGET_GOVERNMENT_ID) = 1 THEN v.TOTALALLOCATEAMOUNT END ALLOC_1,
         CASE WHEN v.ADJUSTEDID      IS NULL OR ROW_NUMBER() OVER (PARTITION BY v.BUDGETYEAR, v.BUDGET_PLAN_ID, v.PRODUCTID, v.ACTIVITYCODEID, v.BUDGET_TYPE_ID, v.CATEGORY_ID, v.ADJUSTEDID      ORDER BY v.BUDGET_GOVERNMENT_ID) = 1 THEN v.TOTALADJUSTEDAMOUNT END ADJ_1,
         CASE WHEN v.KEPTCENTRALID   IS NULL OR ROW_NUMBER() OVER (PARTITION BY v.BUDGETYEAR, v.BUDGET_PLAN_ID, v.PRODUCTID, v.ACTIVITYCODEID, v.BUDGET_TYPE_ID, v.CATEGORY_ID, v.KEPTCENTRALID   ORDER BY v.BUDGET_GOVERNMENT_ID) = 1 THEN v.KEPTCENTRAL END KEPT_1,
         CASE WHEN NVL(v.BUDGETREQUESTID, 0) <> 0 AND v.BUDGET_GOVERNMENT_ID IS NOT NULL
               AND ROW_NUMBER() OVER (PARTITION BY v.BUDGETYEAR, v.BUDGET_PLAN_ID, v.PRODUCTID, v.ACTIVITYCODEID, v.BUDGET_TYPE_ID, v.CATEGORY_ID, v.BUDGET_GOVERNMENT_ID ORDER BY v.BUDGET_GOVERNMENT_ID) = 1
              THEN 1 ELSE 0 END REQGOV_1,
         g.REQ_TOTALREQUESTADJUSTAMOUNT, g.REQ_TOTALALLOCATEAMOUNT, g.REQ_TOTALADJUSTEDAMOUNT
  FROM v
  LEFT JOIN OAGWBG_BUDGETGOVERNMENT g ON g.ID = v.BUDGET_GOVERNMENT_ID
), a AS (
  SELECT r.BUDGETYEAR, r.BUDGET_PLAN_ID, r.BUDGET_PLAN_NAME, r.PRODUCTID, r.PRODUCTNAME, r.ACTIVITYCODEID, r.ACTIVITYNAME,
         r.BUDGET_TYPE_ID, r.BUDGET_TYPE_NAME, r.CATEGORY_ID, r.CATEGORY_NAME, MAX(r.IS_DUMMY) IS_DUMMY,
         MAX(r.CODE)          KEEP (DENSE_RANK FIRST ORDER BY CASE WHEN UPPER(r.DUMMY_FLAG) = 'YES' THEN 1 ELSE 0 END, r.CREATEON) CODE,
         MAX(r.EXPENSETYPEID) KEEP (DENSE_RANK FIRST ORDER BY CASE WHEN UPPER(r.DUMMY_FLAG) = 'YES' THEN 1 ELSE 0 END, r.CREATEON) EXPENSETYPEID,
         MAX(r.BUDGETSTATUS)  KEEP (DENSE_RANK FIRST ORDER BY CASE WHEN UPPER(r.DUMMY_FLAG) = 'YES' THEN 1 ELSE 0 END, r.CREATEON) ROW_STATUS,
         MAX(r.BUDGETCODEID)  KEEP (DENSE_RANK FIRST ORDER BY CASE WHEN UPPER(r.DUMMY_FLAG) = 'YES' THEN 1 ELSE 0 END, r.CREATEON) BUDGETCODEID,
         MAX(r.BUDGETDETAIL)  KEEP (DENSE_RANK FIRST ORDER BY CASE WHEN UPPER(r.DUMMY_FLAG) = 'YES' THEN 1 ELSE 0 END, r.CREATEON) BUDGETDETAIL,
         SUM(CASE WHEN NVL(r.BUDGETREQUESTID, 0) <> 0 THEN 1 ELSE 0 END) REQUEST_ROWS,
         SUM(CASE WHEN r.BUDGETSTATUS = 'B' THEN 1 ELSE 0 END) B_ROWS,
         SUM(CASE WHEN r.BUDGETSTATUS = 'C' THEN 1 ELSE 0 END) C_ROWS,
         SUM(r.TOTALREQUESTSIMMARYAMOUNT) REQ_AMT,
         CASE WHEN MAX(r.IS_DUMMY) = 1 THEN SUM(CASE WHEN r.REQGOV_1 = 1 THEN NVL(r.REQ_TOTALREQUESTADJUSTAMOUNT, 0) ELSE 0 END) ELSE SUM(NVL(r.RQADJ_1, 0)) END REQ_ADJUST_AMT,
         CASE WHEN MAX(r.IS_DUMMY) = 1 THEN SUM(CASE WHEN r.REQGOV_1 = 1 THEN NVL(r.REQ_TOTALALLOCATEAMOUNT, 0)      ELSE 0 END) ELSE SUM(NVL(r.ALLOC_1, 0)) END ALLOCATE_AMT,
         CASE WHEN MAX(r.IS_DUMMY) = 1 THEN SUM(CASE WHEN r.REQGOV_1 = 1 THEN NVL(r.REQ_TOTALADJUSTEDAMOUNT, 0)      ELSE 0 END) ELSE SUM(NVL(r.ADJ_1, 0)) END ADJUSTED_AMT,
         SUM(NVL(r.KEPT_1, 0)) KEPTCENTRAL_AMT
  FROM r
  GROUP BY r.BUDGETYEAR, r.BUDGET_PLAN_ID, r.BUDGET_PLAN_NAME, r.PRODUCTID, r.PRODUCTNAME, r.ACTIVITYCODEID, r.ACTIVITYNAME,
           r.BUDGET_TYPE_ID, r.BUDGET_TYPE_NAME, r.CATEGORY_ID, r.CATEGORY_NAME
)
SELECT '6.3 พ.ร.บ. แผนงาน รายรายการ' TOPIC, a.BUDGETYEAR, a.BUDGET_PLAN_ID, a.BUDGET_PLAN_NAME,
       a.PRODUCTID, a.PRODUCTNAME, a.ACTIVITYCODEID, a.ACTIVITYNAME, a.EXPENSETYPEID, a.BUDGET_TYPE_ID, a.BUDGET_TYPE_NAME,
       a.CATEGORY_ID, a.CODE CATEGORY_CODE, a.CATEGORY_NAME, DECODE(a.IS_DUMMY, 1, 'YES') DUMMY_FLAG, a.BUDGETDETAIL,
       a.REQ_AMT              "คำของบประมาณ",
       a.REQ_ADJUST_AMT       "คำขอแปรญัตติ",
       a.REQ_AMT + a.REQ_ADJUST_AMT "คำของบประมาณรวม",
       a.ALLOCATE_AMT         "เสนอจัดสรร",
       a.ADJUSTED_AMT         "แปรญัตติ",
       a.ALLOCATE_AMT + a.ADJUSTED_AMT "งบประมาณ (พ.ร.บ.)",
       a.KEPTCENTRAL_AMT, a.BUDGETCODEID "รหัสงบประมาณ",
       a.ROW_STATUS, DECODE(a.ROW_STATUS, 'B', '6.1 ยังไม่ยืนยัน/เปิดแก้', 'C', '6.2 ยืนยันแล้ว ยกเลิกได้') STATE,
       a.REQUEST_ROWS, a.B_ROWS, a.C_ROWS
FROM a
ORDER BY a.BUDGETYEAR, a.BUDGET_PLAN_ID, a.PRODUCTID, a.ACTIVITYCODEID, a.EXPENSETYPEID, a.CODE;

-- 6.4 พ.ร.บ. แผนงาน — แถวย่อยรายคำขอใต้แต่ละรายการ (ศูนย์ต้นทุนที่ขอ) เหมือนแถวที่กางออกในหน้า BudgetAllocateDetail
--     คำอธิบาย: BUDGETDETAIL ของแถวคำขอก่อน ถ้าว่างใช้ BUDGETDETAIL ของ type 4 ที่ REF ชี้แถวคำขอ (คำอธิบายจากหน้าคำขอภาพรวม)
--     ยอด REQ_* = ยอดรายคำขอที่กรอกในหน้า พ.ร.บ. (ว่าง = ยังไม่ได้กรอกรายคำขอ)
WITH v0 AS (           -- view หนัก (~4 วิ) อ่านครั้งเดียว ใช้ทั้งกรองแถวและเช็คคำขอลูก
  SELECT /*+ MATERIALIZE */ * FROM OAGWBG_V_BUDGETALLOCATEITEM WHERE BUDGETYEAR >= 2569
), v AS (
  SELECT x.*
  FROM v0 x
  WHERE x.BUDGETFORMTYPEID = 1
    AND (NVL(x.TOTALREQUESTSIMMARYAMOUNT, -1) <> 0 OR x.BUDGETREQUESTID = 0)
    AND (x.PARENTID IS NOT NULL
         OR NOT EXISTS (SELECT 1 FROM v0 c
                        WHERE c.BUDGETYEAR = x.BUDGETYEAR AND c.PARENTID IS NOT NULL AND c.PARENTID = x.BUDGETREQUESTID))
    AND NVL(x.BUDGETREQUESTID, 0) <> 0
)
SELECT '6.4 พ.ร.บ. แผนงาน รายคำขอ' TOPIC, v.BUDGETYEAR, v.BUDGET_PLAN_NAME, v.PRODUCTID, v.ACTIVITYCODEID,
       v.BUDGET_TYPE_NAME, v.CODE CATEGORY_CODE, v.CATEGORY_NAME, v.DUMMY_FLAG,
       v.BUDGETREQUESTID, v.BUDGET_GOVERNMENT_ID, g.COSTCENTERID, cc.NAME COSTCENTER_NAME,
       NVL(TRIM(g.BUDGETDETAIL),
           (SELECT MAX(TRIM(t4.BUDGETDETAIL)) KEEP (DENSE_RANK FIRST ORDER BY t4.ID)
            FROM OAGWBG_BUDGETGOVERNMENT t4
            WHERE t4.BUDGETGOVERNMENTTYPE = '4' AND t4.REF_BUDGETGOVERNMENTID = g.ID AND TRIM(t4.BUDGETDETAIL) IS NOT NULL)) BUDGETDETAIL,
       g.DUMMY_CATEGORY, dc.NAME DUMMY_CATEGORY_NAME,
       v.TOTALREQUESTSIMMARYAMOUNT "คำของบประมาณ",
       g.REQ_TOTALREQUESTADJUSTAMOUNT "คำขอแปรญัตติ (รายคำขอ)",
       g.REQ_TOTALALLOCATEAMOUNT "เสนอจัดสรร (รายคำขอ)",
       g.REQ_TOTALADJUSTEDAMOUNT "แปรญัตติ (รายคำขอ)",
       v.BUDGETSTATUS
FROM v
LEFT JOIN OAGWBG_BUDGETGOVERNMENT g ON g.ID = v.BUDGET_GOVERNMENT_ID
LEFT JOIN OAGWBG_V_EXT_OAGGL_COST_CENTER_V cc ON cc.ID = g.COSTCENTERID
LEFT JOIN OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V dc ON dc.ID = g.DUMMY_CATEGORY
ORDER BY v.BUDGETYEAR, v.BUDGET_PLAN_ID, v.PRODUCTID, v.ACTIVITYCODEID, v.EXPENSETYPEID, v.CODE, g.COSTCENTERID, v.BUDGETREQUESTID;

-- 6.5 พ.ร.บ. โครงการ (ฟอร์ม 2) — 1 แถวต่อโครงการ เหมือนหน้า BudgetAllocateProjectList
--     โครงการที่แสดง (GetVisibleAllocateProjectIdsAsync): แถว TEMP not null ที่ TEMP ชี้ต้นฉบับ (TEMP null) ในคำขอเดียวกัน,
--       เฉพาะคำขอใบล่าสุดของ family (NVL(PARENTID, ID)) และถ้ายังซ้ำเลือก copy ID มากสุด
--     "คำของบประมาณ" (GetPlanAllocateAmountByProjectGovernmentAsync): ยอด พ.ร.บ. ของแถวแผนงานที่ REF ชี้ (type 6 + type 5)
--       ถ้า REF ค้างคำขอใบเก่า เลื่อนไปแถว RUNNING เดียวกันในใบล่าสุด / ใช้ได้เฉพาะ key ที่มีแถวคำขอแถวเดียวและเป็นแถวที่ REF ชี้
--       ไม่เข้าเงื่อนไข → ใช้ PROJECTTARGETS.ALLOCATEDBUDGET (AMOUNT_SOURCE บอกว่ามาจากไหน)
--     "รอยืนยันใหม่" = หัวปีนี้ยืนยันแล้ว (C) แต่โครงการถูกยกเลิกการยืนยันไว้ (BUDGETSTATUS ไม่ใช่ C)
WITH cand AS (
  SELECT p.ID, p.TEMP, p.BUDGETYEAR, r.ID REQID, NVL(r.PARENTID, r.ID) FAMID
  FROM OAGWBG_PROJECT p
  JOIN OAGWBG_PROJECT src ON src.ID = p.TEMP AND src.TEMP IS NULL AND src.BUDGETREQUESTID = p.BUDGETREQUESTID
  JOIN OAGWBG_BUDGETREQUEST r ON r.ID = p.BUDGETREQUESTID
  WHERE p.BUDGETYEAR >= 2569 AND p.TEMP IS NOT NULL
), vis AS (
  SELECT MAX(ID) ID
  FROM (SELECT c.*, MAX(c.REQID) OVER (PARTITION BY c.BUDGETYEAR, c.FAMID) MAXREQ FROM cand c)
  WHERE REQID = MAXREQ
  GROUP BY BUDGETYEAR, REQID, TEMP
), pref AS (            -- แถวแผนงานที่ REF ของโครงการชี้
  SELECT bg.ID PGOV_ID, rf.ID REF_ID, rf.BUDGETREQUESTID REF_REQ, rf.RUNNING REF_RUNNING
  FROM vis JOIN OAGWBG_PROJECT p ON p.ID = vis.ID
  JOIN OAGWBG_BUDGETGOVERNMENT bg ON bg.ID = p.BUDGETGOVERNMENTID
  JOIN OAGWBG_BUDGETGOVERNMENT rf ON rf.ID = bg.REF_BUDGETGOVERNMENTID
  WHERE bg.REF_BUDGETGOVERNMENTID > 0
), leaf AS (            -- คำขอใบล่าสุดของคำขอที่ REF ชี้ (แตกสาย = มีใบสุดท้ายหลายใบ → ไม่เลื่อน)
  SELECT ROOT_ID, MAX(LEAF_ID) LEAF_ID, COUNT(*) LEAF_CNT
  FROM (SELECT CONNECT_BY_ROOT ID ROOT_ID, ID LEAF_ID FROM OAGWBG_BUDGETREQUEST
        WHERE CONNECT_BY_ISLEAF = 1
        START WITH ID IN (SELECT REF_REQ FROM pref) CONNECT BY PRIOR ID = PARENTID AND LEVEL <= 11)
  GROUP BY ROOT_ID
), line AS (
  SELECT pref.PGOV_ID,
         NVL((SELECT MAX(n.ID) FROM OAGWBG_BUDGETGOVERNMENT n
              WHERE n.BUDGETREQUESTID = lf.LEAF_ID AND n.RUNNING = pref.REF_RUNNING AND n.CATEGORYTYPEID = '2'
                AND lf.LEAF_CNT = 1 AND lf.LEAF_ID <> pref.REF_REQ AND pref.REF_RUNNING IS NOT NULL
              HAVING COUNT(*) = 1), pref.REF_ID) LINE_ID
  FROM pref LEFT JOIN leaf lf ON lf.ROOT_ID = pref.REF_REQ
), lk AS (              -- key ของแถวแผนงาน (ต้องเป็นแถวโครงการ CATEGORYTYPEID 2 ฟอร์ม 1 ปีเดียวกัน)
  SELECT line.PGOV_ID, l.ID LINE_ID, l.BUDGETYEAR, l.CATEGORYID, l.BUDGETPLANID, l.PRODUCTID, l.ACTIVITYCODEID
  FROM line JOIN OAGWBG_BUDGETGOVERNMENT l ON l.ID = line.LINE_ID
  WHERE l.BUDGETFORMTYPEID = 1 AND l.CATEGORYTYPEID = '2' AND l.CATEGORYID IS NOT NULL
), amt AS (
  SELECT lk.PGOV_ID,
         (SELECT CASE WHEN COUNT(*) = 1 AND MAX(q.ID) = lk.LINE_ID THEN 1 ELSE 0 END
          FROM OAGWBG_BUDGETGOVERNMENT q
          WHERE q.BUDGETYEAR = lk.BUDGETYEAR AND q.BUDGETFORMTYPEID = 1 AND q.BUDGETREQUESTID IS NOT NULL
            AND (q.BUDGETGOVERNMENTTYPE IS NULL OR q.BUDGETGOVERNMENTTYPE = '7') AND q.BUDGETSTATUS IN ('B','C')
            AND q.CATEGORYID = lk.CATEGORYID AND DECODE(q.BUDGETPLANID, lk.BUDGETPLANID, 1, 0) = 1
            AND DECODE(q.PRODUCTID, lk.PRODUCTID, 1, 0) = 1 AND DECODE(q.ACTIVITYCODEID, lk.ACTIVITYCODEID, 1, 0) = 1
            AND NOT EXISTS (SELECT 1 FROM OAGWBG_BUDGETREQUEST ch WHERE ch.PARENTID = q.BUDGETREQUESTID)) ONE_TO_ONE,
         (SELECT SUM(CASE WHEN t.BUDGETGOVERNMENTTYPE = '6' THEN NVL(t.TOTALALLOCATEAMOUNT, 0) ELSE NVL(t.TOTALADJUSTEDAMOUNT, 0) END)
          FROM OAGWBG_BUDGETGOVERNMENT t
          WHERE t.BUDGETYEAR = lk.BUDGETYEAR AND t.BUDGETFORMTYPEID = 1 AND t.BUDGETGOVERNMENTTYPE IN ('5','6')
            AND t.CATEGORYID = lk.CATEGORYID AND DECODE(t.BUDGETPLANID, lk.BUDGETPLANID, 1, 0) = 1
            AND DECODE(t.PRODUCTID, lk.PRODUCTID, 1, 0) = 1 AND DECODE(t.ACTIVITYCODEID, lk.ACTIVITYCODEID, 1, 0) = 1) PLAN_AMT
  FROM lk
)
SELECT '6.5 พ.ร.บ. โครงการ รายโครงการ' TOPIC, p.BUDGETYEAR,
       ROW_NUMBER() OVER (PARTITION BY p.BUDGETYEAR ORDER BY m.RESPONSIBLEAGENCY, p.CREATEON) "ลำดับที่",
       p.ID PROJECTID, p.PROJECTNAME "รายการโครงการ",
       CASE WHEN amt.ONE_TO_ONE = 1 AND amt.PLAN_AMT IS NOT NULL THEN amt.PLAN_AMT ELSE pt.ALLOCATEDBUDGET END "คำของบประมาณ",
       CASE WHEN amt.ONE_TO_ONE = 1 AND amt.PLAN_AMT IS NOT NULL THEN 'พ.ร.บ. แผนงาน (type 6+5)' ELSE 'PROJECTTARGETS.ALLOCATEDBUDGET' END AMOUNT_SOURCE,
       DECODE(p.STATUS, '1', 'ได้รับจัดสรรงบประมาณ', '0', 'ไม่ได้รับจัดสรรงบประมาณ', 'รอการจัดสรรงบประมาณ') "สถานะโครงการ",
       org.NAME "หน่วยงาน", p.BUDGETGOVERNMENTID, bg.BUDGETSTATUS,
       CASE WHEN h.BUDGETSTATUS = 'C' AND NVL(bg.BUDGETSTATUS, '-') <> 'C' THEN 'รอยืนยันใหม่' END BADGE,
       DECODE(bg.BUDGETSTATUS, 'B', '6.1 ยังไม่ยืนยัน/เปิดแก้', 'C', '6.2 ยืนยันแล้ว ยกเลิกได้') STATE
FROM vis
JOIN OAGWBG_PROJECT p ON p.ID = vis.ID
LEFT JOIN OAGWBG_PROJECTMONITORINGREPORT m ON m.PROJECTID = p.ID
LEFT JOIN OAGWBG_V_EXT_OAGGL_KPI_ORG_MAPPING_V org ON org.ID = m.RESPONSIBLEAGENCY
LEFT JOIN OAGWBG_PROJECTTARGETS pt ON pt.PROJECTID = p.ID
LEFT JOIN OAGWBG_BUDGETGOVERNMENT bg ON bg.ID = p.BUDGETGOVERNMENTID
LEFT JOIN amt ON amt.PGOV_ID = p.BUDGETGOVERNMENTID
LEFT JOIN OAGWBG_V_BUDGETALLOCATELIST h ON h.BUDGETYEAR = p.BUDGETYEAR AND h.BUDGETFORMTYPEID = 2
ORDER BY p.BUDGETYEAR, 3;


-- =====================================================================
-- 7. เบิกเงินจากกรมบัญชีกลาง (GF) — BUDGETGOVERNMENT type 2 (สถานะตาม BudgetGovernmentStatus: R/C/D)
-- =====================================================================
SELECT '7 GF' TOPIC, BUDGETYEAR, BUDGETSTATUS,
       DECODE(BUDGETSTATUS,'R','7.2 ร่าง (ยังไม่ส่ง GL)','C','7.2 ยืนยันแล้ว ยกเลิกได้ (ขากลับอ่าน log ใช้ seg12 เดิม)') STATE,
       COUNT(*) DOC_CNT, SUM(TOTALALLOCATEAMOUNT) ALLOCATE_AMT
FROM OAGWBG_BUDGETGOVERNMENT
WHERE BUDGETGOVERNMENTTYPE = '2' AND BUDGETSTATUS IN ('R','C') AND BUDGETYEAR >= 2569
GROUP BY BUDGETYEAR, BUDGETSTATUS
ORDER BY 2,3;

-- 7.1 GF รายรายการ — หัวใบ → งวด/รอบ (BUDGETRECEIVEPERIOD) → รายการ Category (BUDGETRECEIVEPERIODCATEGORY) 1 แถว = 1 บรรทัด interface
--     ตาม SaveBudgetPaymentGf: ข้ามบรรทัดที่ TOTALRECEIVEAMOUNT = 0 / ATTRIBUTE3 ใน log = BUDGETRECEIVEPERIODCATEGORY.ID
--     GF_KIND: BUDGETFORMTYPEID ว่าง = หน้าเบิกเงินจาก กรมบัญชีกลาง (งบประจำปี) / 3 = หน้า GF งบเพิ่มเติม
--     LAST_* = บรรทัดที่ส่งล่าสุดใน log (batch BUDGET_WD_) ขากลับอ่าน seg12 จากตรงนี้
WITH lg AS (
  SELECT ATTRIBUTE3,
         MAX(WEB_BATCH_NO) KEEP (DENSE_RANK LAST ORDER BY CREATEON, ID) LAST_BATCH,
         MAX(SEGMENT12)    KEEP (DENSE_RANK LAST ORDER BY CREATEON, ID) LAST_SEG12,
         MAX(STATUS)       KEEP (DENSE_RANK LAST ORDER BY CREATEON, ID) LAST_STATUS
  FROM OAGWBG_LOG_INTERFACE
  WHERE REFERENCE_PAGE = 'BudgetPaymentGf' AND WEB_BATCH_NO LIKE 'BUDGET_WD_%'
  GROUP BY ATTRIBUTE3
)
SELECT '7.1 GF รายรายการ' TOPIC, g.BUDGETYEAR, DECODE(g.BUDGETFORMTYPEID, 3, 'GF งบเพิ่มเติม', 'GF งบประจำปี') GF_KIND,
       g.ID GF_ID, g.BUDGETSTATUS,
       DECODE(g.BUDGETSTATUS, 'R', '7.2 ร่าง (ยังไม่ส่ง GL)', 'C', '7.2 ยืนยันแล้ว ยกเลิกได้') STATE,
       g.TOTALALLOCATEAMOUNT GF_AMT,
       p.ID PERIOD_ID, p.PERIOD_TYPE, p.BUDGETPLANID, p.PERIOD "ไตรมาส (งวดที่)", p.ROUNDNO "รอบที่",
       p.ALLOCATEDATE "วันที่ได้รับจัดสรร", NVL(p.BUDGETSOURCEID, '100') BUDGETSOURCEID,
       p.TOTALALLOCATEAMOUNT "อนุมัติจำนวนเงิน", p.RECEIVEPERIODSTATUS,
       c.ID PERIODCATEGORY_ID, c.PRODUCTID, c.ACTIVITYID, c.CATEGORYID, cat.CODE CATEGORY_CODE, cat.NAME CATEGORY_NAME,
       cat.BUDGET_PLAN_NAME, c.TOTALRECEIVEAMOUNT LINE_AMT,
       lg.LAST_BATCH, lg.LAST_SEG12, lg.LAST_STATUS
FROM OAGWBG_BUDGETGOVERNMENT g
JOIN OAGWBG_BUDGETRECEIVEPERIOD p ON p.BUDGETGOVERNMENTID = g.ID
JOIN OAGWBG_BUDGETRECEIVEPERIODCATEGORY c ON c.BUDGETRECEIVEPERIODID = p.ID
LEFT JOIN OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V cat ON cat.ID = c.CATEGORYID
LEFT JOIN lg ON lg.ATTRIBUTE3 = TO_CHAR(c.ID)
WHERE g.BUDGETGOVERNMENTTYPE = '2' AND (g.BUDGETFORMTYPEID IS NULL OR g.BUDGETFORMTYPEID = 3)
  AND g.BUDGETSTATUS IN ('R','C') AND g.BUDGETYEAR >= 2569
  AND NVL(c.TOTALRECEIVEAMOUNT, 0) <> 0
ORDER BY g.BUDGETYEAR, GF_KIND, g.ID, p.BUDGETPLANID, p.PERIOD, p.ROUNDNO, cat.CODE;


-- =====================================================================
-- 8. เบิกแทน / 9. เงินนอกงบประมาณ — ผู้ใช้กรอกชุดบัญชีเอง ไม่มีถังให้นับ X.1
--    seg12 มาจาก OAGWBG_ACCOUNT_SEGMENT.RESERVE1 ของใบนั้น ทั้งตอนส่งและตอนยกเลิก
-- =====================================================================
SELECT '8.2 เบิกแทน' TOPIC, TO_NUMBER(q.BUDGETYEAR) BUDGETYEAR, q.STATUSID, s.NAME STATUS_NAME,
       CASE WHEN q.STATUSID = 80101 THEN 'ค้าง (ยังไม่ส่ง GL)' WHEN q.STATUSID = 80201 THEN 'ยืนยันแล้ว ยกเลิกได้' END STATE,
       COUNT(*) DOC_CNT, SUM(q.TOTALREQUESTAMOUNT) AMT
FROM OAGWBG_BUDGETREQUISITION q
LEFT JOIN OAGWBG_MASTERSTATUS s ON s.ID = q.STATUSID
WHERE q.STATUSID IN (80101, 80401, 80201)
GROUP BY TO_NUMBER(q.BUDGETYEAR), q.STATUSID, s.NAME
UNION ALL
SELECT '9.2 เงินนอกงบประมาณ', o.BUDGETYEAR, o.STATUSID, s.NAME,
       CASE WHEN o.STATUSID IN (10101) THEN 'ค้าง (ยังไม่ส่ง GL)' WHEN o.STATUSID = 90201 THEN 'ยืนยันแล้ว ยกเลิกได้' END,
       COUNT(*), SUM(o.TOTALREQUESTAMOUNT)
FROM OAGWBG_BUDGETREQUESTOUTSIDE o
LEFT JOIN OAGWBG_MASTERSTATUS s ON s.ID = o.STATUSID
WHERE o.STATUSID IN (10101, 90201)
GROUP BY o.BUDGETYEAR, o.STATUSID, s.NAME
ORDER BY 1,2,3;

-- 8.1 เบิกแทน รายรายการ — 1 แถว = 1 ชุดบัญชีใน OAGWBG_ACCOUNT_SEGMENT (REFERENCETABLE BudgetRequisition) = 1 บรรทัด interface
--     ตาม SaveBudgetRequisition: เลือกชุดบัญชีที่ BUDGETYEAR ตรงกับหัวใบ, seg3 = 2 หลักท้ายของปี (ค่า 00/T ใช้ตามนั้น),
--     seg12 = RESERVE1 ?? 00, TRANSFERTYPE I = โอนเข้า (Dr) / O = โอนออก (Cr)
SELECT '8.1 เบิกแทน รายรายการ' TOPIC, q.BUDGETYEAR, q.ID REQUISITION_ID, q.RUNNING, q.PROJECTNAME, q.DEPARTMENTREQUISITION,
       DECODE(q.TRANSFERTYPE, 'I', 'I โอนเข้า (Dr)', 'O', 'O โอนออก (Cr)', q.TRANSFERTYPE) TRANSFERTYPE,
       q.RECIEVEDBUDGETDATE, q.STATUSID, s.NAME STATUS_NAME,
       CASE WHEN q.STATUSID IN (80101, 80401) THEN 'ค้าง (ยังไม่ส่ง GL)' WHEN q.STATUSID = 80201 THEN 'ยืนยันแล้ว ยกเลิกได้' END STATE,
       q.TOTALREQUESTAMOUNT DOC_AMT,
       a.ID SEGMENT_ID, a.SEQUENCE, a.DESCRIPTION,
       CASE WHEN a.ID IS NOT NULL THEN
       a.DEPARTMENTID || '.' || a.COSTCENTERID || '.' ||
       CASE WHEN q.BUDGETYEAR IN ('00','T') THEN q.BUDGETYEAR WHEN LENGTH(q.BUDGETYEAR) = 4 THEN SUBSTR(q.BUDGETYEAR, 3, 2) ELSE NVL(q.BUDGETYEAR, '00') END || '.' ||
       a.BUDGETSOURCEID || '.' || NVL(TO_CHAR(a.BUDGETPLANID), '00000') || '.' || NVL(TO_CHAR(a.PRODUCTID), '00000') || '.' ||
       NVL(TO_CHAR(a.ACTIVITYID), '00000') || '.' || NVL(a.BUDGETTYPEID, '000000') || '.' || a.BUDGETCODENAME || '.' ||
       NVL(a.ACCOUNT, '0000000000') || '.' || NVL(a.SUBACCOUNT, '000000') || '.' || NVL(a.RESERVE1, '00') || '.' || NVL(a.RESERVE2, '000') END ACCOUNT_STRING,
       cc.NAME COSTCENTER_NAME, CASE WHEN a.ID IS NOT NULL THEN NVL(a.RESERVE1, '00') END SEG12, a.TOTALRECEIVEAMOUNT LINE_AMT
FROM OAGWBG_BUDGETREQUISITION q
LEFT JOIN OAGWBG_MASTERSTATUS s ON s.ID = q.STATUSID
LEFT JOIN OAGWBG_ACCOUNT_SEGMENT a ON a.REFERENCETABLE = 'BudgetRequisition' AND a.REFERENCEID = q.ID AND a.BUDGETYEAR = q.BUDGETYEAR
LEFT JOIN OAGWBG_V_EXT_OAGGL_COST_CENTER_V cc ON cc.ID = a.COSTCENTERID
WHERE q.STATUSID IN (80101, 80401, 80201)
ORDER BY q.BUDGETYEAR, q.STATUSID, q.ID, a.SEQUENCE, a.ID;

-- 9.1 เงินนอกงบประมาณ รายรายการ — 1 แถว = 1 ชุดบัญชีใน OAGWBG_ACCOUNT_SEGMENT (REFERENCETABLE BudgetRequestOutside) = 1 บรรทัด interface
--     ตาม SaveBudgetRequestOutside: เลือกชุดบัญชีที่ BUDGETYEAR ตรงกับหัวใบ, seg3 = 2 หลักท้ายของปีในชุดบัญชี,
--     seg12 = RESERVE1 ตรง ๆ (ไม่มี fallback ตอนส่ง / ตอนยกเลิกใช้ RESERVE1 ?? 00)
SELECT '9.1 เงินนอกงบประมาณ รายรายการ' TOPIC, o.BUDGETYEAR, o.ID OUTSIDE_ID, o.RECEIPTNO, o.RUNNINGNO, o.PROJECTNAME, o.BUDGETGIVER,
       o.RECIEVEDBUDGETDATE, o.STATUSID, s.NAME STATUS_NAME,
       CASE WHEN o.STATUSID = 10101 THEN 'ค้าง (ยังไม่ส่ง GL)' WHEN o.STATUSID = 90201 THEN 'ยืนยันแล้ว ยกเลิกได้' END STATE,
       o.TOTALREQUESTAMOUNT DOC_AMT,
       a.ID SEGMENT_ID, a.SEQUENCE, a.DESCRIPTION,
       NVL(a.DEPARTMENTID, '0000000000') || '.' || a.COSTCENTERID || '.' || NVL(SUBSTR(a.BUDGETYEAR, 3, 2), '00') || '.' ||
       a.BUDGETSOURCEID || '.' || NVL(TO_CHAR(a.BUDGETPLANID), '00000') || '.' || NVL(TO_CHAR(a.PRODUCTID), '00000') || '.' ||
       NVL(TO_CHAR(a.ACTIVITYID), '00000') || '.' || NVL(a.BUDGETTYPEID, '000000') || '.' || NVL(a.BUDGETCODENAME, '00000000000000000000') || '.' ||
       NVL(a.ACCOUNT, '0000000000') || '.' || NVL(a.SUBACCOUNT, '000000') || '.' || a.RESERVE1 || '.' || a.RESERVE2 ACCOUNT_STRING,
       cc.NAME COSTCENTER_NAME, NVL(a.RESERVE1, '(ว่าง)') SEG12, a.TOTALRECEIVEAMOUNT LINE_AMT
FROM OAGWBG_BUDGETREQUESTOUTSIDE o
LEFT JOIN OAGWBG_MASTERSTATUS s ON s.ID = o.STATUSID
LEFT JOIN OAGWBG_ACCOUNT_SEGMENT a ON a.REFERENCETABLE = 'BudgetRequestOutside' AND a.REFERENCEID = o.ID AND a.BUDGETYEAR = TO_CHAR(o.BUDGETYEAR)
LEFT JOIN OAGWBG_V_EXT_OAGGL_COST_CENTER_V cc ON cc.ID = a.COSTCENTERID
WHERE o.STATUSID IN (10101, 90201)
ORDER BY o.BUDGETYEAR, o.STATUSID, o.ID, a.SEQUENCE, a.ID;


-- =====================================================================
-- 10. งบเพิ่มเติม / งบกลาง — SaveBudgetRequestMore อ่าน OAGWBG_BUDGETREQUEST (id) + BUDGETGOVERNMENT ที่ BUDGETREQUESTID ชี้
--     แสดงทุก form type ไว้เทียบ — งบเพิ่มเติม = ฟอร์ม 3 (GetBudgetRequestMoreCodeList กรองฟอร์ม 3, GF งบเพิ่มเติมก็ฟอร์ม 3) ดูรายรายการที่ 10.1
--     ดูว่าส่ง interface แล้วหรือยังจาก batch ADD_BUDGET_ ใน OAGWBG_LOG_INTERFACE (PREPROD ยังไม่มีเลย)
-- =====================================================================
SELECT '10 คำขอ (BUDGETREQUEST)' TOPIC, r.BUDGETYEAR, r.BUDGETFORMTYPEID, r.STATUSID, s.NAME STATUS_NAME,
       COUNT(*) DOC_CNT, SUM(r.TOTALREQUESTAMOUNT) REQUEST_AMT
FROM OAGWBG_BUDGETREQUEST r
LEFT JOIN OAGWBG_MASTERSTATUS s ON s.ID = r.STATUSID
WHERE r.BUDGETYEAR >= 2569 AND NVL(r.STATUSID,0) NOT IN (10198, 10199)
GROUP BY r.BUDGETYEAR, r.BUDGETFORMTYPEID, r.STATUSID, s.NAME
ORDER BY 2,3,4;

-- 10.1 งบเพิ่มเติม / งบกลาง รายรายการ — คำขอฟอร์ม 3 (BUDGETFORMTYPEID = 3) → แถว BUDGETGOVERNMENT ของคำขอ = 1 บรรทัด interface
--      ส่ง interface ตอนกดยืนยันคำขอ (ConfirmBudgetRequestMore / ...Project) แล้วสถานะเป็น 20101 ไม่มี method ยกเลิกที่ส่ง interface
--      ตาม SaveBudgetRequestMore: seg1/2/4 จากหัวคำขอ, seg6/7 จากแถว, seg9 = รหัสงบประมาณของ (ปี, Category), seg12 = 00 ในโค้ด
--      IS_LATEST = N คือคำขอเวอร์ชันเก่าที่มีใบลูกแล้ว / SENT_BATCH = batch ADD_BUDGET_ ที่ REFERENCE4 ตรงกับคำขอ (เฉพาะแบบแผนงาน)
SELECT '10.1 งบเพิ่มเติม รายรายการ' TOPIC, r.BUDGETYEAR, r.ID BUDGETREQUESTID, r.CODE, r.VERSION, r.PARENTID,
       CASE WHEN EXISTS (SELECT 1 FROM OAGWBG_BUDGETREQUEST ch WHERE ch.PARENTID = r.ID) THEN 'N' ELSE 'Y' END IS_LATEST,
       DECODE(r.IS_COSTCENTER, 1, 'ศูนย์ต้นทุน', 'ส่วนกลาง') REQUEST_KIND, r.BUDGETTYPEID,
       r.DEPARTMENTID, r.COSTCENTERID, rcc.NAME COSTCENTER_NAME, r.BUDGETSOURCEID,
       r.STATUSID, s.NAME STATUS_NAME,
       CASE WHEN r.STATUSID IN (10101, 10102) THEN 'ค้าง (ยังไม่ยืนยัน ยังไม่ส่ง GL)'
            WHEN r.STATUSID IN (20101, 20102, 20201) THEN 'ยืนยันแล้ว (โค้ดส่ง GL ตอนยืนยัน ดู SENT_BATCH)' END STATE,
       r.TOTALREQUESTAMOUNT DOC_AMT,
       g.ID BUDGETGOVERNMENT_ID, g.BUDGETGOVERNMENTTYPE, g.BUDGETPLANID, g.PRODUCTID, g.ACTIVITYCODEID,
       g.CATEGORYID, cat.CODE CATEGORY_CODE, cat.NAME CATEGORY_NAME, g.PROJECTID, g.BUDGETDETAIL,
       (SELECT MAX(bc.BUDGETCODEID) KEEP (DENSE_RANK FIRST ORDER BY bc.ID) FROM OAGWBG_V_BUDGETCODE_YEAR bc
        WHERE bc.BUDGETYEAR = g.BUDGETYEAR AND bc.CATEGORYID = g.CATEGORYID) BUDGETCODEID,
       g.TOTALREQUESTAMOUNT LINE_AMT, g.BUDGETSTATUS,
       (SELECT MAX(l.WEB_BATCH_NO) FROM OAGWBG_LOG_INTERFACE l
        WHERE l.WEB_BATCH_NO LIKE 'ADD_BUDGET_%' AND l.REFERENCE4 = 'เงินงบประมาณเพิ่มเติม ' || r.BUDGETYEAR || ' ' || r.CODE) SENT_BATCH
FROM OAGWBG_BUDGETREQUEST r
LEFT JOIN OAGWBG_MASTERSTATUS s ON s.ID = r.STATUSID
LEFT JOIN OAGWBG_V_EXT_OAGGL_COST_CENTER_V rcc ON rcc.ID = r.COSTCENTERID
LEFT JOIN OAGWBG_BUDGETGOVERNMENT g ON g.BUDGETREQUESTID = r.ID
LEFT JOIN OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V cat ON cat.ID = g.CATEGORYID
WHERE r.BUDGETFORMTYPEID = 3 AND r.BUDGETYEAR >= 2569 AND NVL(r.STATUSID, 0) NOT IN (10198, 10199)
ORDER BY r.BUDGETYEAR, r.STATUSID, r.CODE, r.ID, g.BUDGETPLANID, g.PRODUCTID, g.ACTIVITYCODEID, cat.CODE;
