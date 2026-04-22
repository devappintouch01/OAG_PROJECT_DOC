```
Context:
- D:\TFS\OAG Budget\*
- D:\TFS\OAG Budget\OAGBudget\*
- D:\TFS\OAG Budget\OAGBudget.API\*
- D:\TFS\OAG Budget\brain_OAGBUDGET\20260421_CREATE_VIEW_OAGWBG_V_BUDGET_OVERLAPYEAR_DETAIL_INTERFACE\OAGWBG_V_BUDGET_OVERLAPYEAR_DETAIL_INTERFACE.xlsx

Observation:
ต้องการสร้าง view ใหม่ ที่ชื่อว่า OAGWBG_V_BUDGET_OVERLAPYEAR_DETAIL_INTERFACE
โดยที่ view จะมีโครงสร้างคล้ายกับ view OAGWBG_V_BUDGET_OVERLAPYEAR_CENTRAL_DETAIL_INTERFACE

ConnectionStrings:
"DATA SOURCE=(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(HOST=172.16.11.19)(PORT=1541)))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=ebs_PRE)));User Id=OAGWBG;Password=Oag#2025;"

Task
1. ทำความเข้าใจ view OAGWBG_V_BUDGET_OVERLAPYEAR_CENTRAL_DETAIL_INTERFACE
1.1 จาก view ต้องการอยากทราบ Table ทั้งหมด ที่เกี่ยวข้องกับ view นี
1.2 จากในไฟล์ Excel OAGWBG_V_BUDGET_OVERLAPYEAR_DETAIL_INTERFACE.xlsx อยากให้ช่วยตรวจสอบว่า จาก view ผม list filed ครบไหม
1.3 อยากให้อธิบาย แต่ละ filed ลงใน column Lookup และ Condition ในไฟล์ Excel OAGWBG_V_BUDGET_OVERLAPYEAR_DETAIL_INTERFACE.xlsx
1.4 ทำสรุปออกมาเป็น md file V_BUDGET_OVERLAPYEAR_CENTRAL_DETAIL_INTERFACE_gclaude.md

2. สร้าง view ใหม่ ที่ชื่อว่า OAGWBG_V_BUDGET_OVERLAPYEAR_DETAIL_INTERFACE โดยมี condition ดังนี้
2.1 major condition ตาม view เดิม
2.2 view ใหม่จะไม่มี column ENCUMBRANCE_TYPE
2.3 WEB_BATCH_NO ต้องต่อ TRANSFERNO เพิ่ม เพราะเป็นส่วนหนึ่งใน format 
2.4 REFERENCE4 ใช้แค่ ข้อความ"เงินกันเหลื่อมปี" BUDGETYEAR และ TRANSFERNO
2.5 REFERENCE5 ใช้แค่ ข้อความ"เงินกันเหลื่อมปี" BUDGETYEAR และ TRANSFERNO
2.6 USER_JE_CATEGORY_NAME ต้อง Fixrd ข้อความต่างกัน ของ record ทั้งขา B และ E
2.7 DEFAULT_EFFECTIVE_DATE ใช้เงื่อนไขเหมือน view นี้ได้เลย
2.8 TYPE ต้อง Fixed เป็น I ของ record ทั้งขา BG และ ENC
2.9 TRANSFERTYPE ต้อง Fixed เป็น CARRYPRPO
2.10 RECEIPIENT_ACCOUNT ใช้เฉพาะ ENC
2.11 SENDER_ACCOUNT ใช้เฉพาะ BG
2.12 ตาราง OAGWBG.OAGWBG_BUDGETRESERVED ข้อมูลจากตารางนี้ต้องมี BUDGETRESERVEDREGION = P
2.13 ตาราง OAGWBG.OAGWBG_BUDGETRESERVED_CATEGORY ไม่ใช้ตารางนี้ เนื่องจากเป็นข้อมูลที่ ref กับ ข้อมูลในตาราง OAGWBG.OAGWBG_BUDGETRESERVED ที่มี BUDGETRESERVEDREGION = C ต้องใช้ตาราง OAGWBG_BUDGETRESERVEDITEM แทน
2.14 ขอสรุปการสร้าง view ใหม่เป็น create_view_xxx.md file และมี sql ในนั้น
```