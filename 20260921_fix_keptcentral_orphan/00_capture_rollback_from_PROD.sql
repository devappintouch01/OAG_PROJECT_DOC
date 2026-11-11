--------------------------------------------------------------------------------
-- STEP 0 : เก็บ DDL ปัจจุบันจาก PROD เป็น rollback ตัวจริง
--
-- ⚠️ ต้องทำก่อนเสมอ  ไฟล์ *_rollback.sql ในโฟลเดอร์นี้ dump มาจาก PREPROD
--    ซึ่ง LAST_DDL_TIME ไม่ตรงกับ PROD (SUMMARY 2026-07-07 / R_BUDGETREQUEST 2026-08-23)
--    ใช้เป็นตัวอ้างอิงได้ แต่ห้ามใช้ rollback จริงโดยไม่เทียบก่อน
--
-- วิธีใช้ใน SQL Developer :
--   รันทีละคำสั่ง แล้ว copy ผลลัพธ์ทั้งก้อนเก็บเป็นไฟล์
--   PROD_<ชื่อ view>_rollback_<YYYYMMDD>.sql
--------------------------------------------------------------------------------

SET LONG 200000
SET PAGESIZE 0
SET LINESIZE 32767

SELECT DBMS_METADATA.GET_DDL('VIEW','OAGWBG_V_BUDGETREQUESTSUMMARY','OAGWBG') FROM DUAL;

SELECT DBMS_METADATA.GET_DDL('VIEW','OAGWBG_R_BUDGETREQUEST','OAGWBG') FROM DUAL;

SELECT DBMS_METADATA.GET_DDL('VIEW','OAGWBG_V_BUDGETREQUESTSUMMARYLIST','OAGWBG') FROM DUAL;


-- เทียบว่า PROD ตรงกับ PREPROD ไหม (ถ้าตรง ใช้ไฟล์ในโฟลเดอร์นี้ rollback ได้เลย)
SELECT OBJECT_NAME,
       TO_CHAR(CREATED,'YYYY-MM-DD HH24:MI')       CREATED,
       TO_CHAR(LAST_DDL_TIME,'YYYY-MM-DD HH24:MI') LAST_DDL,
       STATUS
FROM   ALL_OBJECTS
WHERE  OWNER = 'OAGWBG'
AND    OBJECT_NAME IN ('OAGWBG_V_BUDGETREQUESTSUMMARY',
                       'OAGWBG_R_BUDGETREQUEST',
                       'OAGWBG_V_BUDGETREQUESTSUMMARYLIST')
ORDER  BY OBJECT_NAME;

-- ค่าที่ดึงจาก PREPROD เมื่อ 2026-09-21 :
--   OAGWBG_V_BUDGETREQUESTSUMMARY      created 2025-11-24 10:02 | last_ddl 2026-07-07 15:01
--   OAGWBG_R_BUDGETREQUEST             created 2025-11-19       | last_ddl 2026-08-23 06:32
--   OAGWBG_V_BUDGETREQUESTSUMMARYLIST  created 2025-11-19       | last_ddl (ดูจาก PROD)
