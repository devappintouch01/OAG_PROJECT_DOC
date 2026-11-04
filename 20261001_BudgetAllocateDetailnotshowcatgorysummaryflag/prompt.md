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
view : /Budget/Budgetrequestdetail.cshtml
controller : BudgetController


## Function to Analyze

. View
/Budget/Budgetrequestdetail.cshtml


## Issue
การสร้างคำของบประมาณ Budgetrequestdetail รายการที่ถูกสร้าง ถ้าเป็นรายการที่ยังไม่ทราบว่าเอาไปใช้ในส่วนไหน ซึ่งจะเป็นค่ากลางเอาไว้ก่อน โดยจะติด Sumaryflag = y ไว้ โดยจะได้รับการอนุมัติจาก พิจารณาคำขอ และ คำขอภาพรวมแล้ว พอถึงรายละเอียดคำของบประมาณ พ.ร.บ (BudgetAllocateDetail) ผู้ใช้ทราบว่า เป็นรายการอะไรให้เลือกที่ dropdown ที่ติด Summay flag = y ไว้ กดบันทึกระบบจะวิ่งไปหาว่ารายการนี้มีบัญชีไหน และแสดงยอดเงินของบัญชีนั้นขึ้นมา และจัดกลุ่มของรายการที่ถูกต้อง ก่อนมาแสดงที่หน้าจอ โดย รายการที่เป็นค่ากลางยังคงแสดงอยู่ 

ซึ่งโปรแกรมในตอนนี้ พบว่า หลังจากเลือก dropdown รายการงบประมาณไป และกดบันทึก ผู้ใช้ไม่ทราบว่ารายการนี้เคยเป็นรายการที่เป็นค่ากลางมาก่อนรึเปล่าและตอนย้ายค่ากลางไปผู้ใช้ เห็นว่ารายการที่เป็นค่ากลางนั้นเป็น 0  อยากทราบว่ารายการที่เป้นค่ากลางนั้น ยังคงอยู่หรือไม่ ทำไมยอดถึง เป็น 0  

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
   _C:\Users\thiha\Documents\TFS\OAG Budget\_brain_OAGBUDGET\20261001_BudgetAllocateDetailnotshowcatgorysummaryflag\result.md