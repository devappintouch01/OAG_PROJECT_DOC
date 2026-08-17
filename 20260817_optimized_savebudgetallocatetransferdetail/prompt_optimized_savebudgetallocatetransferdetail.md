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
    }
}
```

## Page in Scope

## Issue

### Step of Save Budget Allocate Transfer Detail

## Tasks
1. ค้นหาและระบุไฟล์ทั้งหมดที่ต้องแก้:
   - BudgetController.cs (Action ที่เกี่ยวข้อง)
   - Views/Budget/*.cshtml (View ที่เกี่ยวข้อง)
   - OAGBudget.API (Controller + endpoint)
   - OAGBudget.DAL (Repository / SP call)
   - OAGBudget.Models (DTO ที่เกี่ยวข้อง)
2. ระบุ Oracle Table และ Stored Procedure ที่เกี่ยวข้อง
   รวมถึง Temp table ที่ใช้บันทึกข้อมูลยืนยัน/ยกเลิก
3. อธิบาย flow ปัจจุบัน (UI → Controller → API → DAL → DB)
   และระบุว่าต้องเปลี่ยนอะไรในแต่ละ layer
4. ห้ามแก้ไข code — วิเคราะห์และอธิบายเท่านั้น
5. ถ้าข้อมูลไม่เพียงพอ ให้ถามก่อนดำเนินการต่อ
6. สรุปผลเป็นภาษาไทย บันทึกไฟล์ที่
   _brain_OAGBUDGET\20260817_optimized_savebudgetallocatetransferdetail\result_optimized_savebudgetallocatetransferdetail.md