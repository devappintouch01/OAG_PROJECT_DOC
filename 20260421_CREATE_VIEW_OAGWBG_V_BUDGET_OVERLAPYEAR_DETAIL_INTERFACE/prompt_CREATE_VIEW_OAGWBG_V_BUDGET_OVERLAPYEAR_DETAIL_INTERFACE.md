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
```