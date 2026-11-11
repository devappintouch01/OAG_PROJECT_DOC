-- [03] VERIFY หลัง [02] COMMIT

-- 3.1 ทุกแถวใน backup ต้องชี้ NEW_REF_ID แล้ว → ต้องได้ 0 แถว
SELECT B.*, T.REF_BUDGETGOVERNMENTID AS CURRENT_REF
FROM OAGWBG_BK20261006_PJREF B
LEFT JOIN OAGWBG_BUDGETGOVERNMENT T ON T.ID = B.BG_ID
WHERE NVL(T.REF_BUDGETGOVERNMENTID, -1) <> B.NEW_REF_ID;

-- 3.2 รัน 01_preview_ref_remap.sql (:BUDGETYEAR = 2570) อีกครั้ง
--     → ต้องเหลือเฉพาะแถว NEW_OK = 'N' ที่ข้ามไว้ ไม่มี 'Y' เหลือ
--
-- 3.3 รัน find_projects_missing_category_in_detail.sql (:BUDGETYEAR = 2570) อีกครั้ง
--     → ต้องเหลือเฉพาะโครงการที่ข้ามไว้ใน 3.2 (ก่อนแก้ = 41 แถว)
--
-- 3.4 เปิดหน้า BudgetRequestProjectDetail ของโครงการที่แก้ 2-3 ตัว ช่อง "รายการ" ต้องมีค่าที่ถูกเลือก
