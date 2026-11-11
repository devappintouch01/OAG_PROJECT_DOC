/* =====================================================================
   Issue 611 — แก้เลขที่เงินกันของรายการ (item) ให้ตรงกับหัวใบ
   เขียน 2026-11-05 / ยังไม่เคยรันจริง — ผู้รันต้องตรวจผล preview แล้ว COMMIT เอง
   (script นี้ไม่มี COMMIT ถ้าผลไม่ถูกให้ ROLLBACK)

   ตารางที่เก็บเลขที่เงินกัน (ตรวจ PROD แล้ว 2026-11-05):
     OAGWBG_BUDGETRESERVED.TRANSFERNO             หัวใบ (หน้าจอแสดงค่านี้)
     OAGWBG_BUDGETRESERVEDITEM.TRANSFERNO         รายการ (interface ใช้ตั้งชื่อ batch/REFERENCE4) — อาจมีต่อท้าย .n
     OAGWBG_BUDGETRESERVEDITEM.RESERVEDNO_ADD     เลขที่เงินกันเพิ่ม (<เลข>.n) ถูก stamp ตอนยืนยันรอบขยาย
     OAGWBG_BUDGETRESERVED_BANKACCOUNT.TRANSFERNO บัญชีธนาคาร
     OAGWBG_RECEIVE_BATCH_NO.ROUNDNO/BATCHNAME    เกิดตอนส่ง interface ใช้เลขหัวใบอยู่แล้ว
     OAGWBG_LOG_INTERFACE                         ประวัติที่ส่งเข้า EBS แล้ว — ไม่แก้ (ดูหมายเหตุใน PART A)
   views (V_BUDGETRESERVEDITEM, V_BUDGET_OVERLAPYEAR_DETAIL_INTERFACE, R_BUDGETOVERLAP_*, R_KTBPAYMENT)
   อ่านจากตารางด้านบนโดยตรง จึงเปลี่ยนตามเอง
   ===================================================================== */


/* =====================================================================
   PART A — แก้ใบ 34 (692043) และ 35 (692045) ที่ส่ง interface ไปแล้ว
   สิ่งที่ต้องแก้มีแค่ ITEM.TRANSFERNO (item 53, 54) — หัวใบ / bank / RECEIVE_BATCH_NO ถูกอยู่แล้ว
   RESERVEDNO_ADD ของ 2 แถวนี้เป็น null (ยังไม่เคยขยาย)

   ⚠ ไม่แก้ OAGWBG_LOG_INTERFACE 4 แถว (ID 43035–43038, เลข 69220001):
     เป็นหลักฐานของ journal ที่ลง EBS ไปแล้ว ทีมการเงินต้องใช้เลขนี้ตาม reverse
   ⚠ ห้ามกด "ยกเลิกการยืนยัน" กับใบ 34/35 ทั้งก่อนและหลังรัน script นี้:
     ระบบหาบรรทัดที่จะกลับรายการจาก REFERENCE4 ที่ลงท้ายด้วยเลขของ item
       - ก่อนแก้: เลข 69220001 จับได้ทั้ง 4 แถว → ยกเลิกใบ 34 จะ reverse ของใบ 35 ด้วย
       - หลังแก้: เลข 692043 ไม่ตรงกับแถวใดเลย → ไม่ reverse อะไร
     และถ้าการเงิน reverse เองด้วย จะกลับรายการซ้ำ
   ===================================================================== */

-- A1) preview ก่อนแก้: NEW_TRANSFERNO ต้องเป็น 692043 / 692045
SELECT I.ID ITEM_ID, I.BUDGETREVERSEDID HID, H.TRANSFERNO HEADER_NO,
       I.TRANSFERNO OLD_TRANSFERNO,
       TRIM(H.TRANSFERNO) || REGEXP_SUBSTR(TRIM(I.TRANSFERNO), '[.-][0-9]+$') NEW_TRANSFERNO,
       I.RESERVEDNO_ADD
FROM OAGWBG_BUDGETRESERVEDITEM I
JOIN OAGWBG_BUDGETRESERVED H ON H.ID = I.BUDGETREVERSEDID
WHERE I.BUDGETREVERSEDID IN (34, 35)
ORDER BY I.ID;

-- A2) update — ต้องได้ 2 rows (เงื่อนไข TRANSFERNO = '69220001' กันรันซ้ำ / กันไปโดนแถวอื่น)
UPDATE OAGWBG_BUDGETRESERVEDITEM I
SET I.TRANSFERNO = (SELECT TRIM(H.TRANSFERNO) FROM OAGWBG_BUDGETRESERVED H WHERE H.ID = I.BUDGETREVERSEDID)
                   || REGEXP_SUBSTR(TRIM(I.TRANSFERNO), '[.-][0-9]+$'),
    I.UPDATEON = SYSDATE
WHERE I.BUDGETREVERSEDID IN (34, 35)
  AND REGEXP_REPLACE(TRIM(I.TRANSFERNO), '[.-][0-9]+$', '') = '69220001';

-- A3) ตรวจหลังแก้: ต้องได้ 0 rows (ไม่มี item ไหนในใบ 34/35 ที่ยังไม่ตรงหัวใบ)
SELECT I.ID, I.BUDGETREVERSEDID, I.TRANSFERNO, H.TRANSFERNO HEADER_NO
FROM OAGWBG_BUDGETRESERVEDITEM I
JOIN OAGWBG_BUDGETRESERVED H ON H.ID = I.BUDGETREVERSEDID
WHERE I.BUDGETREVERSEDID IN (34, 35)
  AND REGEXP_REPLACE(TRIM(I.TRANSFERNO), '[.-][0-9]+$', '') <> TRIM(H.TRANSFERNO);

-- A4) ดูข้อมูลที่จะส่ง interface ใหม่ — หลัง update ต้องได้ 4 แถว และ TRANSFERNO / REFERENCE1 / REFERENCE4
--     ต้องเป็นเลขเดียวกับใน WEB_BATCH_NO (ก่อนแก้ 4 แถวนี้ยังเป็น 69220001)
--     (view นี้ไม่มีคอลัมน์ ID / HEADER_TRANSFERNO จึงกรองด้วย WEB_BATCH_NO ที่ผูกกับเลขหัวใบ)
SELECT TRANSFERNO, REFERENCE1, REFERENCE4, WEB_BATCH_NO, ENTERED_DR, ENTERED_CR, TYPE
FROM OAGWBG_V_BUDGET_OVERLAPYEAR_DETAIL_INTERFACE
WHERE TRANSFERNO IN ('692043', '692045', '69220001')
   OR WEB_BATCH_NO LIKE '%\_692043\_%' ESCAPE '\'
   OR WEB_BATCH_NO LIKE '%\_692045\_%' ESCAPE '\';

-- ผลถูกต้อง → COMMIT;   ไม่ถูก → ROLLBACK;


/* =====================================================================
   PART C — ย้อนใบ 34/35 ให้กลับไปอยู่ "ก่อนยืนยันรอบแรก" เพื่อกดยืนยัน (ส่ง interface) ใหม่จากหน้าจอ
   ทำต่อจาก PART A (ต้องแก้ item ก่อน ไม่งั้นส่งใหม่ก็ได้ 69220001 อีก)
   = สิ่งที่ "ยกเลิกการยืนยัน" ทำ ยกเว้นการกลับรายการใน EBS (การเงินจะ reverse เอง)

   ค่าก่อนยืนยันรอบแรก (ดูจาก PROD 2026-11-05):
     header  : STATUSID 20202 → 90201, ROUNDINTERFACE 1 → NULL, BUDGETYEAR 2570 → 2569
     RECEIVE_BATCH_NO 45438–45441 (P, ROUNDNO 692043/692045) → ลบ
   ทำไมต้องย้อน ROUNDINTERFACE: ConfirmBudgetReserved ส่ง interface เฉพาะเมื่อ ROUNDINTERFACE IS NULL
     ถ้าค้าง 1 ไว้ กดยืนยันจะแค่เดินรอบเป็น 2 + ปีไม่เปลี่ยน โดยไม่ส่งอะไรเข้า EBS
   ทำไมต้องย้อน BUDGETYEAR: SaveBudgetReserved ใช้ BUDGETYEAR ตั้งชื่อ batch/journal และคำนวณ effective date
     ถ้าค้าง 2570 จะได้ BG_CARRY_FORWARD_2570_... และวันที่ปี 2027 (ไม่ตรงกับรอบแรกที่เป็น 2569)
     และพอยืนยันสำเร็จระบบจะบวกปีให้เองอีกครั้ง → กลับมาเป็น 2570

   ไม่ต้องลบ OAGWBG_BUDGETRECEIVE 56746/56747 และ OAGWBG_BUDGETRESERVED_CATEGORY 14/15:
     ยังไม่มีใครใช้ (ตรวจทุกตารางที่อ้าง RECEIVEID/CATEGORYID แล้ว = 0) และยอดเท่าเดิม
     ตอนยืนยันใหม่ CreateBudgetReceiveForReservedRegionPAsync เจอ category เดิมแล้วข้าม → ไม่เกิดแถวซ้ำ
   ไม่แตะ OAGWBG_LOG_INTERFACE (การเงินใช้ตาม reverse)
   item 53/54 เป็นแถวแม่ (PARENTID null) ไม่มี APPROVE / RESERVEDNO_ADD ให้ล้าง

   หลัง COMMIT: เข้าหน้า BudgetOverlapYearPO ฝั่งพิจารณา (pageType=2)
     → กด "ตรวจสอบแล้ว" (90201 → 90202) → กด "ยืนยัน" = ส่ง interface ใหม่ด้วยเลข 692043 / 692045
   ===================================================================== */

-- C1) ตรวจก่อน: ต้องได้ 2 แถว STATUSID=20202, ROUNDINTERFACE=1, BUDGETYEAR=2570
SELECT ID, TRANSFERNO, STATUSID, ROUNDINTERFACE, BUDGETYEAR FROM OAGWBG_BUDGETRESERVED WHERE ID IN (34, 35);

-- C2) ลบ batch no ของการยืนยันรอบแรก — ต้องได้ 4 rows
DELETE FROM OAGWBG_RECEIVE_BATCH_NO
WHERE ID IN (45438, 45439, 45440, 45441)
  AND INTERFACETYPE = 'P' AND RECEIVEID IS NULL AND ROUNDNO IN (692043, 692045);

-- C3) ย้อน header — ต้องได้ 2 rows (เงื่อนไขกันรันซ้ำ)
UPDATE OAGWBG_BUDGETRESERVED
SET STATUSID = 90201, ROUNDINTERFACE = NULL, BUDGETYEAR = 2569, UPDATEON = SYSDATE
WHERE ID IN (34, 35) AND STATUSID = 20202 AND ROUNDINTERFACE = 1 AND BUDGETYEAR = 2570;

-- C4) ตรวจหลังแก้
SELECT H.ID, H.TRANSFERNO, H.STATUSID, H.ROUNDINTERFACE, H.BUDGETYEAR,
       (SELECT LISTAGG(I.TRANSFERNO, ',') WITHIN GROUP (ORDER BY I.ID) FROM OAGWBG_BUDGETRESERVEDITEM I WHERE I.BUDGETREVERSEDID = H.ID) ITEM_NOS,
       (SELECT COUNT(*) FROM OAGWBG_RECEIVE_BATCH_NO B WHERE B.INTERFACETYPE = 'P' AND B.ROUNDNO = TO_NUMBER(H.TRANSFERNO)) BATCH_ROWS
FROM OAGWBG_BUDGETRESERVED H WHERE H.ID IN (34, 35);
-- ต้องได้: STATUSID 90201, ROUNDINTERFACE (null), BUDGETYEAR 2569, ITEM_NOS = เลขหัวใบ, BATCH_ROWS 0

-- ผลถูกต้อง → COMMIT;   ไม่ถูก → ROLLBACK;

-- C5) หลังกดยืนยันในหน้าจอแล้ว: ตรวจ log ใหม่ — ต้องได้ 4 batch (BG/ENC × 2 ใบ) STATUS = S
--     ชื่อ batch / REFERENCE4 ต้องเป็น 2569_692043 / 2569_692045
SELECT ID, STATUS, WEB_BATCH_NO, REFERENCE4, ENTERED_DR, ENTERED_CR, TO_CHAR(CREATEON, 'YYYY-MM-DD HH24:MI:SS') CR
FROM OAGWBG_LOG_INTERFACE
WHERE ACTION_NAME = 'SaveBudgetReserved'
  AND (WEB_BATCH_NO LIKE '%\_692043\_%' ESCAPE '\' OR WEB_BATCH_NO LIKE '%\_692045\_%' ESCAPE '\')
ORDER BY ID;


/* =====================================================================
   PART B — script ใหม่สำหรับเปลี่ยนเลขที่เงินกัน (ยอดยกมา) ใช้แทน script เดิม
   แก้ครบ 3 ที่ในครั้งเดียว: หัวใบ + รายการ (เก็บ .n ต่อท้ายไว้) + บัญชีธนาคาร
   ต้องรัน "หลังระบบออกเลข แต่ก่อนส่งเรื่อง/ยืนยัน" เท่านั้น

   วิธีใช้: แก้ค่า 2 บรรทัด c_header_id / c_new_no แล้วรันทั้ง block
           ดูผลใน DBMS_OUTPUT (SET SERVEROUTPUT ON) แล้ว COMMIT เอง
   ด่านกันพลาด (เจอแล้ว RAISE ไม่แก้อะไรเลย):
     - ไม่พบหัวใบ
     - เลขใหม่ซ้ำกับหัวใบอื่น
     - หัวใบยืนยันแล้ว (20202) หรือมี log interface สำเร็จของเลขเดิมแล้ว → ต้องทำแบบ PART A
   ===================================================================== */

SET SERVEROUTPUT ON;

DECLARE
    c_header_id CONSTANT NUMBER       := 0;         -- << ID ของ OAGWBG_BUDGETRESERVED
    c_new_no    CONSTANT VARCHAR2(50) := 'XXXXXX';  -- << เลขที่เงินกันใหม่ เช่น '692043'

    v_old_no  OAGWBG_BUDGETRESERVED.TRANSFERNO%TYPE;
    v_status  OAGWBG_BUDGETRESERVED.STATUSID%TYPE;
    v_cnt     NUMBER;
BEGIN
    SELECT TRIM(TRANSFERNO), STATUSID INTO v_old_no, v_status
    FROM OAGWBG_BUDGETRESERVED WHERE ID = c_header_id
    FOR UPDATE;

    IF TRIM(c_new_no) IS NULL OR c_new_no = 'XXXXXX' THEN
        RAISE_APPLICATION_ERROR(-20001, 'ยังไม่ได้ใส่เลขใหม่');
    END IF;

    SELECT COUNT(*) INTO v_cnt FROM OAGWBG_BUDGETRESERVED
    WHERE TRIM(TRANSFERNO) = TRIM(c_new_no) AND ID <> c_header_id;
    IF v_cnt > 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'เลข ' || c_new_no || ' ถูกใช้กับหัวใบอื่นแล้ว');
    END IF;

    IF v_status = 20202 THEN
        RAISE_APPLICATION_ERROR(-20003, 'หัวใบยืนยันแล้ว (20202) — ห้ามเปลี่ยนเลขด้วย script นี้');
    END IF;

    SELECT COUNT(*) INTO v_cnt FROM OAGWBG_LOG_INTERFACE L
    WHERE L.STATUS = 'S' AND L.ACTION_NAME = 'SaveBudgetReserved'
      AND EXISTS (SELECT 1 FROM OAGWBG_BUDGETRESERVEDITEM I
                  WHERE I.BUDGETREVERSEDID = c_header_id AND I.TRANSFERNO IS NOT NULL
                    AND L.REFERENCE4 LIKE '% ' || REGEXP_REPLACE(TRIM(I.TRANSFERNO), '[.-][0-9]+$', '') || '%');
    IF v_cnt > 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 'มี log interface สำเร็จของเลขเดิมแล้ว ' || v_cnt || ' แถว — ห้ามเปลี่ยนเลขด้วย script นี้');
    END IF;

    DBMS_OUTPUT.PUT_LINE('header ' || c_header_id || ': ' || v_old_no || ' -> ' || c_new_no);

    UPDATE OAGWBG_BUDGETRESERVED
    SET TRANSFERNO = TRIM(c_new_no), UPDATEON = SYSDATE
    WHERE ID = c_header_id;
    DBMS_OUTPUT.PUT_LINE('  BUDGETRESERVED            : ' || SQL%ROWCOUNT || ' row');

    -- เก็บส่วนต่อท้าย .n / -n ไว้ เปลี่ยนเฉพาะเลขหลัก
    UPDATE OAGWBG_BUDGETRESERVEDITEM
    SET TRANSFERNO = TRIM(c_new_no) || REGEXP_SUBSTR(TRIM(TRANSFERNO), '[.-][0-9]+$'),
        UPDATEON   = SYSDATE
    WHERE BUDGETREVERSEDID = c_header_id AND TRANSFERNO IS NOT NULL;
    DBMS_OUTPUT.PUT_LINE('  BUDGETRESERVEDITEM.TRANSFERNO     : ' || SQL%ROWCOUNT || ' rows');

    UPDATE OAGWBG_BUDGETRESERVEDITEM
    SET RESERVEDNO_ADD = TRIM(c_new_no) || REGEXP_SUBSTR(TRIM(RESERVEDNO_ADD), '[.-][0-9]+$')
    WHERE BUDGETREVERSEDID = c_header_id AND RESERVEDNO_ADD IS NOT NULL;
    DBMS_OUTPUT.PUT_LINE('  BUDGETRESERVEDITEM.RESERVEDNO_ADD : ' || SQL%ROWCOUNT || ' rows');

    UPDATE OAGWBG_BUDGETRESERVED_BANKACCOUNT
    SET TRANSFERNO = TRIM(c_new_no)
    WHERE RESERVEDID = c_header_id;
    DBMS_OUTPUT.PUT_LINE('  BUDGETRESERVED_BANKACCOUNT: ' || SQL%ROWCOUNT || ' rows');

    DBMS_OUTPUT.PUT_LINE('ตรวจผลด้วย B-check ด้านล่าง แล้ว COMMIT / ROLLBACK เอง');
END;
/

-- B-check) ใส่ ID เดียวกัน: ทุกแถวต้องมี MATCH = Y
SELECT 'HEADER' SRC, TO_CHAR(H.ID) ROW_ID, H.TRANSFERNO NO_, H.TRANSFERNO HEADER_NO, 'Y' MATCH
FROM OAGWBG_BUDGETRESERVED H WHERE H.ID = 0 /* << ID */
UNION ALL
SELECT 'ITEM', TO_CHAR(I.ID), I.TRANSFERNO, H.TRANSFERNO,
       CASE WHEN REGEXP_REPLACE(TRIM(I.TRANSFERNO), '[.-][0-9]+$', '') = TRIM(H.TRANSFERNO) THEN 'Y' ELSE 'N' END
FROM OAGWBG_BUDGETRESERVEDITEM I JOIN OAGWBG_BUDGETRESERVED H ON H.ID = I.BUDGETREVERSEDID
WHERE H.ID = 0 /* << ID */
UNION ALL
SELECT 'BANK', TO_CHAR(B.ID), B.TRANSFERNO, H.TRANSFERNO,
       CASE WHEN TRIM(B.TRANSFERNO) = TRIM(H.TRANSFERNO) THEN 'Y' ELSE 'N' END
FROM OAGWBG_BUDGETRESERVED_BANKACCOUNT B JOIN OAGWBG_BUDGETRESERVED H ON H.ID = B.RESERVEDID
WHERE H.ID = 0 /* << ID */;
