## Context
- Solution: OAGBudget (7 projects)
  - OAGBudget          → Frontend (ASP.NET Core MVC + Razor Views + jQuery)
  - OAGBudget.API      → Backend REST API
  - OAGBudget.DAL      → Data Access Layer
  - OAGBudget.Global   → Shared constants / enums
  - OAGBudget.Models   → DTOs / Domain models
  - OAGBudget.Reports  → Reports
  - OAGBudget.Utilities → Helpers

- Source paths:
  - D:\TFS\OAG Budget\OAGBudget\
  - D:\TFS\OAG Budget\OAGBudget.API\

- DB: Oracle PREPROD
```json
{
    "ConnectionStrings": {
        // PRE PROD
        "DBContext": "DATA SOURCE=(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(HOST=172.16.11.19)(PORT=1541)))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=ebs_PRE)));User Id=OAGWBG;Password=Oag#2025;",
        // PROD
        "OAGDBContext": "DATA SOURCE=(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(HOST=172.16.11.18)(PORT=1531)))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=PROD)));User Id=OAGWBG;Password=Oag#2025;",
    }
}
```
## Reference and screenshort
- issue611_description - D:\TFS\OAG Budget_1\_brain_OAGBUDGET\20261104_issue_611\issue611_description.png

## Issue
issue 611

## Tasks
1. ค้นหาและระบุไฟล์ทั้งหมดที่ต้องแก้:
   - BudgetController.cs และไฟล์อื่น ๆ ที่เกี่ยวข้อง (Action ที่เกี่ยวข้อง)
   - Views/Budget/*.cshtml และไฟล์อื่น ๆ ที่เกี่ยวข้อง (View ที่เกี่ยวข้อง)
   - OAGBudget.API และไฟล์อื่น ๆ ที่เกี่ยวข้อง (Controller + endpoint)
   - OAGBudget.DAL และไฟล์อื่น ๆ ที่เกี่ยวข้อง (Repository / SP call) 
   - OAGBudget.Models และไฟล์อื่น ๆ ที่เกี่ยวข้อง (DTO ที่เกี่ยวข้อง)
2. อธิบาย flow ปัจจุบัน (UI → Controller → API → DAL → DB)
   และระบุว่าต้องเปลี่ยนอะไรในแต่ละ layer
3. ห้ามแก้ไข code — วิเคราะห์และอธิบายเท่านั้น
4. ถ้าข้อมูลไม่เพียงพอ ให้ถามก่อนดำเนินการต่อ
5. สรุปผลเป็นภาษาไทย บันทึกไฟล์ที่ D:\TFS\OAG Budget_1\_brain_OAGBUDGET\20261104_issue_611\result_issue_611.md