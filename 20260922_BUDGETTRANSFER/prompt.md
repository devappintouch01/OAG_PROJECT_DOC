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
view : /Budget/BudgetTransferDetail.cshtml
controller : BudgetController


## Function to Analyze

. View
/Budget/BudgetTransferDetail.cshtml


## Issue
เคสเงินกัน หน่วยงาน ตัวอย่างใบ TRANSFERNO = 681253 จากตาราง OAGWBG_BUDGETRESERVED ที่เป็นแหล่งเงินต้นทาง 100 ตอนกดค้นหารายการแหล่งเงิน 400 จะมีรายการที่เป็น เลขที่เงินกันเดียวกัน หลายรายการ จำนวนเงินจัดสรร จะต่างกันไปในแต่ละรายการ แต่ตอนนี ถ้าใช้ ชุดบัญชีไปหางบประมาณ จาก GL แบบเดิม ผลคือจะเป็น งบประมาณรวม ของ เงินกันใบนี้ แบบแสดงซ้าหลายแถว 

1.สามารถปรับเป็นดึงจากเลขที่เงินกันเลยได้ไหม แล้ว link แหล่งเงินกับปีงบประมาณมาให้
2.รายการงบประมาณตอนนี้แสดงยอดรวม แต่รายการมีวงเล็บเลขที่เงินกันจะยังไม่ถูก
3.เฉพาะแหล่งเงิน 400 เงินกัน ให้ ดึงยอดมาจาก BUDGET RECEIVE แทนการใช้ยอดจาก GL 


### Step of Search Budget Transfer Detail
1. คลิกปุ่ม เเหล่งเงิน เลือกเป็น 400 เงินกัน แล้ว ปีงบประมาณของบัญชี (ที่ใช้ค้นหา) เป็นปี 2568 ภาค เลือกเป็นทั้งหมด  
2. เลือก หน่วยเบิกจ่าย เป็น สำนัก อัยการสูงสุด ศูนย์ต้นทุน เป็น สำนักงานเลขาธิการสำนักงานอัยการสูงสุด และหน่วยงานในสังกัด 13 หน่วยงาน
3. เลือก เลขที่เงินกัน เป็น 681253 
4. กดค้นหา จะแสดง ขึ้นรายการที่เป็นรายการแหล่ง เงินกัน 400 


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
   _brain_OAGBUDGET\20260922_BUDGETTRANSFER\result.md