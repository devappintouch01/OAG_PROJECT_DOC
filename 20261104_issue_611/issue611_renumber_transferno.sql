/* =====================================================================
   เปลี่ยนเลขที่เงินกัน: หัวใบ + รายการ พร้อมกัน
     OAGWBG_BUDGETRESERVED.TRANSFERNO
     OAGWBG_BUDGETRESERVEDITEM.TRANSFERNO  (เก็บส่วนต่อท้าย .n / -n ไว้ เช่น 69220001.1 → 692043.1)

   วิธีใช้: ใส่ c_old_no / c_new_no → SET SERVEROUTPUT ON → รัน block
           ดูผลใน DBMS_OUTPUT + query ตรวจด้านล่าง → COMMIT เอง (ผิด → ROLLBACK)
   ถ้าไม่ผ่านด่านตรวจ จะ error และไม่แก้อะไรเลย
   ===================================================================== */

SET SERVEROUTPUT ON;

DECLARE
    c_old_no CONSTANT VARCHAR2(50) := '69220001';   -- << เลขเดิม (เลขที่ระบบออก)
    c_new_no CONSTANT VARCHAR2(50) := '692043';     -- << เลขใหม่

    v_id     OAGWBG_BUDGETRESERVED.ID%TYPE;
    v_status OAGWBG_BUDGETRESERVED.STATUSID%TYPE;
    v_round  OAGWBG_BUDGETRESERVED.ROUNDINTERFACE%TYPE;
    v_cnt    NUMBER;
BEGIN
    -- ด่าน 1: เลขเดิมต้องเจอหัวใบ 1 ใบพอดี (เลขของระบบเคยออกซ้ำได้ เช่น 69220001 มี 2 ใบ)
    SELECT COUNT(*) INTO v_cnt FROM OAGWBG_BUDGETRESERVED WHERE TRIM(TRANSFERNO) = TRIM(c_old_no);
    IF v_cnt = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'ไม่พบหัวใบเลข ' || c_old_no);
    ELSIF v_cnt > 1 THEN
        RAISE_APPLICATION_ERROR(-20002, 'เลข ' || c_old_no || ' มี ' || v_cnt || ' ใบ — ต้องแก้ทีละใบด้วย ID');
    END IF;

    SELECT ID, STATUSID, ROUNDINTERFACE INTO v_id, v_status, v_round
    FROM OAGWBG_BUDGETRESERVED WHERE TRIM(TRANSFERNO) = TRIM(c_old_no)
    FOR UPDATE;

    -- ด่าน 2: เลขใหม่ต้องไม่ซ้ำกับใบอื่น
    SELECT COUNT(*) INTO v_cnt FROM OAGWBG_BUDGETRESERVED
    WHERE TRIM(TRANSFERNO) = TRIM(c_new_no) AND ID <> v_id;
    IF v_cnt > 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'เลข ' || c_new_no || ' ถูกใช้กับหัวใบอื่นแล้ว');
    END IF;

    -- ด่าน 3: ต้องยังไม่ยืนยัน (ยืนยันแล้ว = ส่ง interface เข้า EBS ไปแล้ว)
    IF v_status = 20202 OR v_round IS NOT NULL THEN
        RAISE_APPLICATION_ERROR(-20004, 'ใบ ID ' || v_id || ' ยืนยันแล้ว (STATUSID=' || v_status
                                || ', ROUNDINTERFACE=' || v_round || ') — ห้ามเปลี่ยนเลขด้วย script นี้');
    END IF;

    -- แก้รายการทุกแถวของใบนี้ (อิงจากหัวใบ ไม่อิงเลขเดิมของรายการ)
    UPDATE OAGWBG_BUDGETRESERVEDITEM
    SET TRANSFERNO = TRIM(c_new_no) || REGEXP_SUBSTR(TRIM(TRANSFERNO), '[.-][0-9]+$'),
        UPDATEON   = SYSDATE
    WHERE BUDGETREVERSEDID = v_id AND TRANSFERNO IS NOT NULL;
    DBMS_OUTPUT.PUT_LINE('OAGWBG_BUDGETRESERVEDITEM : ' || SQL%ROWCOUNT || ' แถว');

    -- แก้หัวใบ
    UPDATE OAGWBG_BUDGETRESERVED
    SET TRANSFERNO = TRIM(c_new_no), UPDATEON = SYSDATE
    WHERE ID = v_id;
    DBMS_OUTPUT.PUT_LINE('OAGWBG_BUDGETRESERVED     : ' || SQL%ROWCOUNT || ' แถว (ID ' || v_id || ')');

    DBMS_OUTPUT.PUT_LINE(c_old_no || ' -> ' || c_new_no || ' — ยังไม่ COMMIT');
END;
/

-- ตรวจผล: ใส่เลขใหม่ — ทุกแถวต้อง MATCH = Y
SELECT 'HEADER' SRC, H.ID, H.TRANSFERNO NO_, 'Y' MATCH
FROM OAGWBG_BUDGETRESERVED H
WHERE TRIM(H.TRANSFERNO) = '692043'   -- << เลขใหม่
UNION ALL
SELECT 'ITEM', I.ID, I.TRANSFERNO,
       CASE WHEN REGEXP_REPLACE(TRIM(I.TRANSFERNO), '[.-][0-9]+$', '') = TRIM(H.TRANSFERNO) THEN 'Y' ELSE 'N' END
FROM OAGWBG_BUDGETRESERVEDITEM I JOIN OAGWBG_BUDGETRESERVED H ON H.ID = I.BUDGETREVERSEDID
WHERE TRIM(H.TRANSFERNO) = '692043';  -- << เลขใหม่

-- ถูกต้อง → COMMIT;   ไม่ถูก → ROLLBACK;
