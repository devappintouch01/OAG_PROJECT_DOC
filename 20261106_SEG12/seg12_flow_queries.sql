-- =====================================================================
-- SEG12: รายการ interface แยกตามงานธุรกิจ 11 งาน พร้อมชุดบัญชี 13 segment
-- แหล่งข้อมูล: OAGWBG.OAGWBG_LOG_INTERFACE (audit log ที่ SaveInterface เขียนคู่กับ oaggl_journal_interface)
-- แยกงานด้วย prefix ของ WEB_BATCH_NO ตามที่ BudgetService.cs ตั้งชื่อ batch
-- ขายกเลิก/กลับรายการ = batch ที่ขึ้นต้นด้วย REVERSE_
-- SELECT อย่างเดียว
--
-- ผลบน PREPROD 2026-11-06 (Q0): SEGMENT12 = '00' ทุกแถวทุกงาน
--   ไม่มีแถวของ Q2 พ.ร.บ.(โครงการ), Q9 งบเพิ่มเติม, Q11 โอนปรับเงินเหลือจ่าย บน PREPROD
--   แถวที่ไม่เข้ากลุ่ม 175 แถวเป็นเงินนอกงบประมาณ batch รูปแบบเก่า จึงจับด้วย PAGE_NAME เพิ่ม
-- =====================================================================


-- ---------------------------------------------------------------------
-- Q0. สรุปต่องาน: จำนวนแถว / batch / ชุดบัญชีที่ไม่ซ้ำ / ค่า SEGMENT12 ที่พบ
-- ---------------------------------------------------------------------
WITH L AS (
    SELECT l.*,
           CASE
             WHEN l.WEB_BATCH_NO LIKE '%BUDGET\_ACT\_%' ESCAPE '\' AND l.PAGE_NAME LIKE '%(โครงการ)%' THEN '02 พ.ร.บ. (โครงการ)'
             WHEN l.WEB_BATCH_NO LIKE '%BUDGET\_ACT\_%' ESCAPE '\'                                   THEN '01 พ.ร.บ. (แผนงาน)'
             WHEN l.WEB_BATCH_NO LIKE '%BUDGET\_WD\_%' ESCAPE '\'                                    THEN '03 เบิกเงินจากกรมบัญชีกลาง (GF)'
             WHEN l.WEB_BATCH_NO LIKE '%BUDGET\_TRANSFER\_REMAINING\_%' ESCAPE '\'                   THEN '11 โอนปรับเงินเหลือจ่าย'
             WHEN l.WEB_BATCH_NO LIKE '%BUDGET\_TRANSFER\_%' ESCAPE '\'                              THEN '04 โอนจัดสรร (รวมเพิ่มเติม)'
             WHEN l.WEB_BATCH_NO LIKE '%BUDGET\_ADJUST\_%' ESCAPE '\'                                THEN '05 โอนเปลี่ยนแปลง'
             WHEN l.WEB_BATCH_NO LIKE '%BUDGET\_RETURN\_%' ESCAPE '\'
               OR l.WEB_BATCH_NO LIKE '%BUDGET\_RENEXT\_%' ESCAPE '\'
               OR l.WEB_BATCH_NO LIKE '%BUDGET\_REBACK\_%' ESCAPE '\'                                THEN '06 โอนกลับ'
             WHEN INSTR(l.WEB_BATCH_NO, 'เบิกแทน') > 0                                               THEN '07 เบิกแทน'
             WHEN l.WEB_BATCH_NO LIKE '%CARRY\_FORWARD\_%' ESCAPE '\'                                THEN '08 เงินกันเหลื่อมปี'
             WHEN l.WEB_BATCH_NO LIKE '%ADD\_BUDGET\_%' ESCAPE '\'                                   THEN '09 งบเพิ่มเติม / งบกลาง'
             WHEN l.WEB_BATCH_NO LIKE '%RECEIPT\_RCV%' ESCAPE '\'
               OR l.PAGE_NAME = 'บันทึกรับเงินนอกงบประมาณ'                                            THEN '10 เงินนอกงบประมาณ'
             ELSE '99 ไม่เข้ากลุ่ม'
           END AS FLOW,
           CASE WHEN l.WEB_BATCH_NO LIKE 'REVERSE\_%' ESCAPE '\' THEN 'ยกเลิก' ELSE 'ส่ง' END AS DIRECTION
      FROM OAGWBG.OAGWBG_LOG_INTERFACE l
)
SELECT FLOW,
       DIRECTION,
       COUNT(*)                                   AS ROWS_CNT,
       COUNT(DISTINCT WEB_BATCH_NO)               AS BATCH_CNT,
       COUNT(DISTINCT SEGMENT1||'.'||SEGMENT2||'.'||SEGMENT3||'.'||SEGMENT4||'.'||SEGMENT5||'.'||SEGMENT6||'.'||SEGMENT7||'.'||
                      SEGMENT8||'.'||SEGMENT9||'.'||SEGMENT10||'.'||SEGMENT11||'.'||SEGMENT12||'.'||SEGMENT13) AS ACCOUNT_CNT,
       LISTAGG(DISTINCT NVL(SEGMENT12, '(null)'), ',') WITHIN GROUP (ORDER BY SEGMENT12) AS SEG12_VALUES,
       MIN(CREATEON)                              AS FIRST_ON,
       MAX(CREATEON)                              AS LAST_ON
  FROM L
 GROUP BY FLOW, DIRECTION
 ORDER BY FLOW, DIRECTION DESC;


-- =====================================================================
-- Q1–Q11 รายละเอียดต่องาน (แต่ละ query รันเดี่ยวได้)
-- คอลัมน์ ACCOUNT_CODE = ชุดบัญชี 13 segment ที่ส่งจริง
-- หมายเหตุ "ต้นทางชุดบัญชี" = ตอนส่ง/ตอนยกเลิกโค้ดได้ segment มาจากไหน (ตรวจจาก BudgetService.cs 2026-11-06)
-- =====================================================================

-- ---------------------------------------------------------------------
-- Q1. พ.ร.บ. (แผนงาน)   SaveBudgetAllocate / ReverseBudgetAllocateItems / PushReconfirmBudgetAllocateItemsInterface
-- ต้นทางชุดบัญชี: ส่ง = ประกอบจาก Category + expense account rule, seg12 = "00" ใส่ในโค้ด
--                 ยกเลิก = ประกอบใหม่ (ไม่อ่าน log) seg12 = "00" ใส่ในโค้ด
-- ---------------------------------------------------------------------
SELECT CASE WHEN l.WEB_BATCH_NO LIKE 'REVERSE\_%' ESCAPE '\' THEN 'ยกเลิก' ELSE 'ส่ง' END AS DIRECTION,
       l.WEB_BATCH_NO, l.REFERENCE4 AS JOURNAL_NAME, l.PAGE_NAME, l.ACTION_NAME, l.ACTUAL_FLAG,
       l.SEGMENT1||'.'||l.SEGMENT2||'.'||l.SEGMENT3||'.'||l.SEGMENT4||'.'||l.SEGMENT5||'.'||l.SEGMENT6||'.'||l.SEGMENT7||'.'||
       l.SEGMENT8||'.'||l.SEGMENT9||'.'||l.SEGMENT10||'.'||l.SEGMENT11||'.'||l.SEGMENT12||'.'||l.SEGMENT13 AS ACCOUNT_CODE,
       l.SEGMENT12, l.ENTERED_DR, l.ENTERED_CR, l.STATUS, l.CREATEON
  FROM OAGWBG.OAGWBG_LOG_INTERFACE l
 WHERE l.WEB_BATCH_NO LIKE '%BUDGET\_ACT\_%' ESCAPE '\'
   AND NVL(l.PAGE_NAME, '-') NOT LIKE '%(โครงการ)%'
 ORDER BY l.CREATEON DESC, l.WEB_BATCH_NO, l.LINE_NUMBER;

-- ---------------------------------------------------------------------
-- Q2. พ.ร.บ. (โครงการ)   SaveBudgetAllocateProject
-- ต้นทางชุดบัญชี: เหมือน Q1 (batch BUDGET_ACT_ เหมือนกัน แยกด้วย PAGE_NAME)
-- ---------------------------------------------------------------------
SELECT CASE WHEN l.WEB_BATCH_NO LIKE 'REVERSE\_%' ESCAPE '\' THEN 'ยกเลิก' ELSE 'ส่ง' END AS DIRECTION,
       l.WEB_BATCH_NO, l.REFERENCE4 AS JOURNAL_NAME, l.PAGE_NAME, l.ACTION_NAME, l.ACTUAL_FLAG,
       l.SEGMENT1||'.'||l.SEGMENT2||'.'||l.SEGMENT3||'.'||l.SEGMENT4||'.'||l.SEGMENT5||'.'||l.SEGMENT6||'.'||l.SEGMENT7||'.'||
       l.SEGMENT8||'.'||l.SEGMENT9||'.'||l.SEGMENT10||'.'||l.SEGMENT11||'.'||l.SEGMENT12||'.'||l.SEGMENT13 AS ACCOUNT_CODE,
       l.SEGMENT12, l.ENTERED_DR, l.ENTERED_CR, l.STATUS, l.CREATEON
  FROM OAGWBG.OAGWBG_LOG_INTERFACE l
 WHERE l.WEB_BATCH_NO LIKE '%BUDGET\_ACT\_%' ESCAPE '\'
   AND l.PAGE_NAME LIKE '%(โครงการ)%'
 ORDER BY l.CREATEON DESC, l.WEB_BATCH_NO, l.LINE_NUMBER;

-- ---------------------------------------------------------------------
-- Q3. เบิกเงินจากกรมบัญชีกลาง (GF)   SaveBudgetPaymentGf / ReverseBudgetPaymentGf
-- ต้นทางชุดบัญชี: ส่ง = seg12 "00" ใส่ในโค้ด / ยกเลิก = อ่านจาก log บรรทัดที่ส่งไปแล้ว (ใช้ seg12 เดิม)
-- ---------------------------------------------------------------------
SELECT CASE WHEN l.WEB_BATCH_NO LIKE 'REVERSE\_%' ESCAPE '\' THEN 'ยกเลิก' ELSE 'ส่ง' END AS DIRECTION,
       l.WEB_BATCH_NO, l.REFERENCE4 AS JOURNAL_NAME, l.PAGE_NAME, l.ACTION_NAME, l.ACTUAL_FLAG,
       l.SEGMENT1||'.'||l.SEGMENT2||'.'||l.SEGMENT3||'.'||l.SEGMENT4||'.'||l.SEGMENT5||'.'||l.SEGMENT6||'.'||l.SEGMENT7||'.'||
       l.SEGMENT8||'.'||l.SEGMENT9||'.'||l.SEGMENT10||'.'||l.SEGMENT11||'.'||l.SEGMENT12||'.'||l.SEGMENT13 AS ACCOUNT_CODE,
       l.SEGMENT12, l.ENTERED_DR, l.ENTERED_CR, l.STATUS, l.CREATEON
  FROM OAGWBG.OAGWBG_LOG_INTERFACE l
 WHERE l.WEB_BATCH_NO LIKE '%BUDGET\_WD\_%' ESCAPE '\'
 ORDER BY l.CREATEON DESC, l.WEB_BATCH_NO, l.LINE_NUMBER;

-- ---------------------------------------------------------------------
-- Q4. โอนจัดสรร (รวมโอนจัดสรรเพิ่มเติม)   SaveBudgetAllocateTransfer / SaveBudgetAllocateTransferReverse / SaveBudgetAllocateTransferMoreInterface
-- ต้นทางชุดบัญชี: ส่ง = seg12 "00" ใส่ในโค้ด / ยกเลิก = ประกอบใหม่ (ไม่อ่าน log) seg12 "00" ใส่ในโค้ด
-- ---------------------------------------------------------------------
SELECT CASE WHEN l.WEB_BATCH_NO LIKE 'REVERSE\_%' ESCAPE '\' THEN 'ยกเลิก' ELSE 'ส่ง' END AS DIRECTION,
       l.WEB_BATCH_NO, l.REFERENCE4 AS JOURNAL_NAME, l.PAGE_NAME, l.ACTION_NAME, l.ACTUAL_FLAG,
       l.SEGMENT1||'.'||l.SEGMENT2||'.'||l.SEGMENT3||'.'||l.SEGMENT4||'.'||l.SEGMENT5||'.'||l.SEGMENT6||'.'||l.SEGMENT7||'.'||
       l.SEGMENT8||'.'||l.SEGMENT9||'.'||l.SEGMENT10||'.'||l.SEGMENT11||'.'||l.SEGMENT12||'.'||l.SEGMENT13 AS ACCOUNT_CODE,
       l.SEGMENT12, l.ENTERED_DR, l.ENTERED_CR, l.STATUS, l.CREATEON
  FROM OAGWBG.OAGWBG_LOG_INTERFACE l
 WHERE l.WEB_BATCH_NO LIKE '%BUDGET\_TRANSFER\_%' ESCAPE '\'
   AND l.WEB_BATCH_NO NOT LIKE '%BUDGET\_TRANSFER\_REMAINING\_%' ESCAPE '\'
 ORDER BY l.CREATEON DESC, l.WEB_BATCH_NO, l.LINE_NUMBER;

-- ---------------------------------------------------------------------
-- Q5. โอนเปลี่ยนแปลง   SaveBudgetAdjust / ConfirmBudgetTransferAdjust / CancelBudgetTransferAdjust
-- ต้นทางชุดบัญชี: ส่ง = seg12 "00" ใส่ในโค้ด / ยกเลิก = ประกอบใหม่จากรายการรับโอน (ไม่อ่าน log) seg12 "00" ใส่ในโค้ด
-- ---------------------------------------------------------------------
SELECT CASE WHEN l.WEB_BATCH_NO LIKE 'REVERSE\_%' ESCAPE '\' THEN 'ยกเลิก' ELSE 'ส่ง' END AS DIRECTION,
       l.WEB_BATCH_NO, l.REFERENCE4 AS JOURNAL_NAME, l.PAGE_NAME, l.ACTION_NAME, l.ACTUAL_FLAG,
       l.SEGMENT1||'.'||l.SEGMENT2||'.'||l.SEGMENT3||'.'||l.SEGMENT4||'.'||l.SEGMENT5||'.'||l.SEGMENT6||'.'||l.SEGMENT7||'.'||
       l.SEGMENT8||'.'||l.SEGMENT9||'.'||l.SEGMENT10||'.'||l.SEGMENT11||'.'||l.SEGMENT12||'.'||l.SEGMENT13 AS ACCOUNT_CODE,
       l.SEGMENT12, l.ENTERED_DR, l.ENTERED_CR, l.STATUS, l.CREATEON
  FROM OAGWBG.OAGWBG_LOG_INTERFACE l
 WHERE l.WEB_BATCH_NO LIKE '%BUDGET\_ADJUST\_%' ESCAPE '\'
 ORDER BY l.CREATEON DESC, l.WEB_BATCH_NO, l.LINE_NUMBER;

-- ---------------------------------------------------------------------
-- Q6. โอนกลับ   SaveBudgetTransfer / SaveBudgetTransferReverse  (batch BUDGET_RETURN_ / BUDGET_RENEXT_ / BUDGET_REBACK_)
-- ต้นทางชุดบัญชี: ส่ง = seg12 "00" ใส่ในโค้ด / ยกเลิก = ประกอบใหม่ (ไม่อ่าน log) seg12 "00" ใส่ในโค้ด
-- ---------------------------------------------------------------------
SELECT CASE WHEN l.WEB_BATCH_NO LIKE 'REVERSE\_%' ESCAPE '\' THEN 'ยกเลิก' ELSE 'ส่ง' END AS DIRECTION,
       l.WEB_BATCH_NO, l.REFERENCE4 AS JOURNAL_NAME, l.PAGE_NAME, l.ACTION_NAME, l.ACTUAL_FLAG,
       l.SEGMENT1||'.'||l.SEGMENT2||'.'||l.SEGMENT3||'.'||l.SEGMENT4||'.'||l.SEGMENT5||'.'||l.SEGMENT6||'.'||l.SEGMENT7||'.'||
       l.SEGMENT8||'.'||l.SEGMENT9||'.'||l.SEGMENT10||'.'||l.SEGMENT11||'.'||l.SEGMENT12||'.'||l.SEGMENT13 AS ACCOUNT_CODE,
       l.SEGMENT12, l.ENTERED_DR, l.ENTERED_CR, l.STATUS, l.CREATEON
  FROM OAGWBG.OAGWBG_LOG_INTERFACE l
 WHERE l.WEB_BATCH_NO LIKE '%BUDGET\_RETURN\_%' ESCAPE '\'
    OR l.WEB_BATCH_NO LIKE '%BUDGET\_RENEXT\_%' ESCAPE '\'
    OR l.WEB_BATCH_NO LIKE '%BUDGET\_REBACK\_%' ESCAPE '\'
 ORDER BY l.CREATEON DESC, l.WEB_BATCH_NO, l.LINE_NUMBER;

-- ---------------------------------------------------------------------
-- Q7. เบิกแทน   SaveBudgetRequisition / SaveBudgetRequisitionReverse
-- ต้นทางชุดบัญชี: ทั้งส่งและยกเลิกอ่านจาก OAGWBG_ACCOUNT_SEGMENT (ผ่าน OAGWBG_V_ACCOUNT_SEGMENT) seg12 = RESERVE1 ?? "00"
--                 ⚠️ ถ้าแก้ RESERVE1 ของใบเก่าเป็น 0000000 ตอนยกเลิกจะส่งไม่ตรงกับที่ส่งไปครั้งแรก
-- ---------------------------------------------------------------------
SELECT CASE WHEN l.WEB_BATCH_NO LIKE 'REVERSE\_%' ESCAPE '\' THEN 'ยกเลิก' ELSE 'ส่ง' END AS DIRECTION,
       l.WEB_BATCH_NO, l.REFERENCE4 AS JOURNAL_NAME, l.PAGE_NAME, l.ACTION_NAME, l.ACTUAL_FLAG,
       l.SEGMENT1||'.'||l.SEGMENT2||'.'||l.SEGMENT3||'.'||l.SEGMENT4||'.'||l.SEGMENT5||'.'||l.SEGMENT6||'.'||l.SEGMENT7||'.'||
       l.SEGMENT8||'.'||l.SEGMENT9||'.'||l.SEGMENT10||'.'||l.SEGMENT11||'.'||l.SEGMENT12||'.'||l.SEGMENT13 AS ACCOUNT_CODE,
       l.SEGMENT12, l.ENTERED_DR, l.ENTERED_CR, l.STATUS, l.CREATEON
  FROM OAGWBG.OAGWBG_LOG_INTERFACE l
 WHERE INSTR(l.WEB_BATCH_NO, 'เบิกแทน') > 0
 ORDER BY l.CREATEON DESC, l.WEB_BATCH_NO, l.LINE_NUMBER;

-- ---------------------------------------------------------------------
-- Q8. เงินกันเหลื่อมปี (หน่วยกลาง + หน่วยงาน)   SaveBudgetReserved / ConfirmBudgetReserved / ReverseBudgetReservedBatch
--     batch BG_CARRY_FORWARD_ / ENC_CARRY_FORWARD_ / CARRY_FORWARD_
-- ต้นทางชุดบัญชี: ส่ง = ส่วนใหญ่ split จาก OAGWBG_BUDGETRESERVEDITEM.ACCOUNTCODE (สตริง 13 segment ที่เก็บไว้)
--                 บางกรณีประกอบเองด้วย seg12 "00" / ยกเลิก = อ่านจาก log บรรทัดที่ส่งไปแล้ว
-- ---------------------------------------------------------------------
SELECT CASE WHEN l.WEB_BATCH_NO LIKE 'REVERSE\_%' ESCAPE '\' THEN 'ยกเลิก' ELSE 'ส่ง' END AS DIRECTION,
       l.WEB_BATCH_NO, l.REFERENCE4 AS JOURNAL_NAME, l.PAGE_NAME, l.ACTION_NAME, l.ACTUAL_FLAG,
       l.SEGMENT1||'.'||l.SEGMENT2||'.'||l.SEGMENT3||'.'||l.SEGMENT4||'.'||l.SEGMENT5||'.'||l.SEGMENT6||'.'||l.SEGMENT7||'.'||
       l.SEGMENT8||'.'||l.SEGMENT9||'.'||l.SEGMENT10||'.'||l.SEGMENT11||'.'||l.SEGMENT12||'.'||l.SEGMENT13 AS ACCOUNT_CODE,
       l.SEGMENT12, l.ENTERED_DR, l.ENTERED_CR, l.STATUS, l.CREATEON
  FROM OAGWBG.OAGWBG_LOG_INTERFACE l
 WHERE l.WEB_BATCH_NO LIKE '%CARRY\_FORWARD\_%' ESCAPE '\'
 ORDER BY l.CREATEON DESC, l.WEB_BATCH_NO, l.LINE_NUMBER;

-- Q8b. ชุดบัญชีที่เก็บไว้ในใบเงินกัน (ใช้ส่ง interface รอบถัดไปและเทียบกับ PR/PO) แยกตามค่า seg12
SELECT REGEXP_SUBSTR(i.ACCOUNTCODE, '[^.]+', 1, 12) AS SEG12_IN_ACCOUNTCODE,
       COUNT(*)                                     AS ITEM_CNT,
       COUNT(DISTINCT i.ACCOUNTCODE)                AS ACCOUNT_CNT
  FROM OAGWBG.OAGWBG_BUDGETRESERVEDITEM i
 WHERE i.ACCOUNTCODE IS NOT NULL
 GROUP BY REGEXP_SUBSTR(i.ACCOUNTCODE, '[^.]+', 1, 12)
 ORDER BY 2 DESC;

-- ---------------------------------------------------------------------
-- Q9. งบเพิ่มเติม / งบกลาง (แผนงาน + โครงการ)   SaveBudgetRequestMore / SaveBudgetRequestMoreProjectInterface
-- ต้นทางชุดบัญชี: ส่ง = seg12 "00" ใส่ในโค้ด / ไม่พบ method ยกเลิกที่ส่ง interface
-- ---------------------------------------------------------------------
SELECT CASE WHEN l.WEB_BATCH_NO LIKE 'REVERSE\_%' ESCAPE '\' THEN 'ยกเลิก' ELSE 'ส่ง' END AS DIRECTION,
       l.WEB_BATCH_NO, l.REFERENCE4 AS JOURNAL_NAME, l.PAGE_NAME, l.ACTION_NAME, l.ACTUAL_FLAG,
       l.SEGMENT1||'.'||l.SEGMENT2||'.'||l.SEGMENT3||'.'||l.SEGMENT4||'.'||l.SEGMENT5||'.'||l.SEGMENT6||'.'||l.SEGMENT7||'.'||
       l.SEGMENT8||'.'||l.SEGMENT9||'.'||l.SEGMENT10||'.'||l.SEGMENT11||'.'||l.SEGMENT12||'.'||l.SEGMENT13 AS ACCOUNT_CODE,
       l.SEGMENT12, l.ENTERED_DR, l.ENTERED_CR, l.STATUS, l.CREATEON
  FROM OAGWBG.OAGWBG_LOG_INTERFACE l
 WHERE l.WEB_BATCH_NO LIKE '%ADD\_BUDGET\_%' ESCAPE '\'
 ORDER BY l.CREATEON DESC, l.WEB_BATCH_NO, l.LINE_NUMBER;

-- ---------------------------------------------------------------------
-- Q10. เงินนอกงบประมาณ   SaveBudgetRequestOutside / ConfirmBudgetRequestOutside / CancelConfirmBudgetRequestOutside
-- ต้นทางชุดบัญชี: ทั้งส่งและยกเลิกอ่านจาก OAGWBG_ACCOUNT_SEGMENT seg12 = RESERVE1 (ยกเลิกใช้ ?? "00")
--                 ⚠️ ความเสี่ยงเดียวกับ Q7 ถ้าแก้ RESERVE1 ของใบเก่า
-- ---------------------------------------------------------------------
SELECT CASE WHEN l.WEB_BATCH_NO LIKE 'REVERSE\_%' ESCAPE '\' THEN 'ยกเลิก' ELSE 'ส่ง' END AS DIRECTION,
       l.WEB_BATCH_NO, l.REFERENCE4 AS JOURNAL_NAME, l.PAGE_NAME, l.ACTION_NAME, l.ACTUAL_FLAG,
       l.SEGMENT1||'.'||l.SEGMENT2||'.'||l.SEGMENT3||'.'||l.SEGMENT4||'.'||l.SEGMENT5||'.'||l.SEGMENT6||'.'||l.SEGMENT7||'.'||
       l.SEGMENT8||'.'||l.SEGMENT9||'.'||l.SEGMENT10||'.'||l.SEGMENT11||'.'||l.SEGMENT12||'.'||l.SEGMENT13 AS ACCOUNT_CODE,
       l.SEGMENT12, l.ENTERED_DR, l.ENTERED_CR, l.STATUS, l.CREATEON
  FROM OAGWBG.OAGWBG_LOG_INTERFACE l
 WHERE l.WEB_BATCH_NO LIKE '%RECEIPT\_RCV%' ESCAPE '\'
    OR l.PAGE_NAME = 'บันทึกรับเงินนอกงบประมาณ'   -- batch รูปแบบเก่า BUDGET_#_# และ RECEIPT_#_#_# (ก่อน 2026-08)
 ORDER BY l.CREATEON DESC, l.WEB_BATCH_NO, l.LINE_NUMBER;

-- Q10b / Q7b. ค่า RESERVE1 ที่เก็บใน OAGWBG_ACCOUNT_SEGMENT (ใช้ทั้งเบิกแทนและเงินนอกงบประมาณ)
SELECT NVL(s.RESERVE1, '(null)') AS RESERVE1, COUNT(*) AS ROW_CNT
  FROM OAGWBG.OAGWBG_ACCOUNT_SEGMENT s
 GROUP BY s.RESERVE1
 ORDER BY 2 DESC;

-- ---------------------------------------------------------------------
-- Q11. โอนปรับเงินเหลือจ่าย   SaveBudgetReserveTransfer / ReverseConfirmBudgetReserveTransfer
-- ต้นทางชุดบัญชี: โค้ดส่ง interface ถูก comment ไว้ บันทึกแค่ batch ประวัติ (OAGWBG_RECEIVE_BATCHNO)
--                 คาดว่า query นี้จะไม่มีแถว ถ้ามีแถวแปลว่าเป็นข้อมูลก่อนที่จะปิดการส่ง
-- ---------------------------------------------------------------------
SELECT CASE WHEN l.WEB_BATCH_NO LIKE 'REVERSE\_%' ESCAPE '\' THEN 'ยกเลิก' ELSE 'ส่ง' END AS DIRECTION,
       l.WEB_BATCH_NO, l.REFERENCE4 AS JOURNAL_NAME, l.PAGE_NAME, l.ACTION_NAME, l.ACTUAL_FLAG,
       l.SEGMENT1||'.'||l.SEGMENT2||'.'||l.SEGMENT3||'.'||l.SEGMENT4||'.'||l.SEGMENT5||'.'||l.SEGMENT6||'.'||l.SEGMENT7||'.'||
       l.SEGMENT8||'.'||l.SEGMENT9||'.'||l.SEGMENT10||'.'||l.SEGMENT11||'.'||l.SEGMENT12||'.'||l.SEGMENT13 AS ACCOUNT_CODE,
       l.SEGMENT12, l.ENTERED_DR, l.ENTERED_CR, l.STATUS, l.CREATEON
  FROM OAGWBG.OAGWBG_LOG_INTERFACE l
 WHERE l.WEB_BATCH_NO LIKE '%BUDGET\_TRANSFER\_REMAINING\_%' ESCAPE '\'
 ORDER BY l.CREATEON DESC, l.WEB_BATCH_NO, l.LINE_NUMBER;
