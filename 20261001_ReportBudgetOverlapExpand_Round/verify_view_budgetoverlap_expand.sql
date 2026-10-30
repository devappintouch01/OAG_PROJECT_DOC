--------------------------------------------------------------------------------
-- VERIFY หลังรัน deploy_view_budgetoverlap_expand.sql
--------------------------------------------------------------------------------

-- 0) view ต้อง VALID
SELECT OBJECT_NAME, STATUS, LAST_DDL_TIME
FROM   USER_OBJECTS
WHERE  OBJECT_NAME = 'OAGWBG_R_BUDGETOVERLAP_EXPAND';

-- 1) จำนวนแถวแยกตามสถานะรายการ
--    ก่อน deploy (PREPROD 2026-10-01) :  90102 = 31 แถว / 19 item
--                                       90110 =  3 แถว /  3 item
--    หลัง deploy ที่คาด            :  90102 / 90110 ต้องเท่าเดิม (ของเดิมไม่หาย ไม่เพิ่ม)
--                                       90109 =  3 แถว /  3 item (item 238, 239, 240 ของใบ 681203)
SELECT I.STATUSID, COUNT(*) VIEW_ROWS, COUNT(DISTINCT V.ITEMID) ITEMS
FROM   OAGWBG_R_BUDGETOVERLAP_EXPAND V
JOIN   OAGWBG_BUDGETRESERVEDITEM I ON I.ID = V.ITEMID
GROUP  BY I.STATUSID
ORDER  BY 1;

-- 2) แถว 90109 ที่เพิ่มเข้ามา ต้องเป็น CANCEL_* เท่านั้น (ห้ามมี 'R')
SELECT V.BUDGETRESERVEDID, V.ITEMID, V.ITEMRESERVEDTYPE, V.OVERLAPROUND, V.RESERVEDTYPENAME, V.POAMOUNT
FROM   OAGWBG_R_BUDGETOVERLAP_EXPAND V
JOIN   OAGWBG_BUDGETRESERVEDITEM I ON I.ID = V.ITEMID
WHERE  I.STATUSID = 90109
ORDER  BY V.ITEMID;
