```
Context:
- D:\TFS\OAG Budget\*
- D:\TFS\OAG Budget\OAGBudget\*
- D:\TFS\OAG Budget\OAGBudget.API\*

ConnectionStrings:
```json
{
    "ConnectionStrings": {
        "EBSContext": "DATA SOURCE=(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(HOST=172.16.11.19)(PORT=1541)))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=ebs_PRE)));User Id=OAGWBG;Password=Oag#2025;",
    }
}

Observation:
ที่หน้า คำของบประมาณรายจ่ายประจำปี โครงการ (/Budget/BudgetRequestProjectDetail/126?pageType=1&statusId=10101&CostCenterId=2900600001&BudgetFormRequestType=1) จะมี Tab "กำหนดค่าค่าเป้าหมายความสำเร็จของโครงการ" ใน Tab นี้ จะมี Section กลุ่มเป้าหมาย / ผู้ที่ได้รับประโยชน์ ระบบจะ Default ไว้ 1 record จะมี Column ลำดับ, กลุ่มเป้าหมาย, ปริมาณกลุ่มเป้าหมาย, หน่วยเป้าหมาย, พื้นที่กลุ่มเป้าหมาย สามารถกดเพิ่มรายการ กลุ่มเป้าหมาย / ผู้ได้รับประโยชน์ ได้
ต้องการเพิ่มการ validate ว่าจะต้องกรอกข้อมูล ที่ช่อง กลุ่มเป้าหมาย และให้ validate ว่าจะต้องมีการระบุค่าลงในช่องนี้ และถ้ามีหลายรายการ จะต้องระบุอย่างน้อย 1 รายการ

Task:
Task:
1. หาสาเหตุ วางแผนการแก้ไข และ Verify การแก้ไข
2. ยังไม่ต้องแก้ไข code ใด ๆ
3. ถ้าข้อมูลไม่เพียงพอ ต้องการสอบถามเพิ่ม ให้สอบถามก่อน
4. สรุป roadmap การแก้ไขนี้นี้เป็นภาษาไทยลงใน brain_OAGBUDGET\20260601_BudgetRequestProjectDetail_BudgetFormRequestType_1\roadmap_claude.md

```