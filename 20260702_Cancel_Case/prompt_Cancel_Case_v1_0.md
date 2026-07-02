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

## Reference and screenshort
- สเปคการส่ง Interface - _brain_OAGBUDGET\20260702_Cancel_Case\OAG_Budget_View_Detail.xlsx
จากไฟล์นี้ ถ้าเป็นสเปคการส่ง Interface จะเป็นชีทที่มีคำว่า "ยกเลิก"
- log-interface-cancel - _brain_OAGBUDGET\20260702_Cancel_Case\log-interface-cancel.jpg

## Page in Scope
- คำของบประมาณตาม พรบ.
- เบิกเงินจากกรมบัญชีกลาง
- โอนปรับเปลี่ยนรายการ
- โอนเงินปรับเงินเหลือจ่าย
- เบิกแทน
- กันเงินเหลื่อมปี

## Required Changes
จากรายการหน้าจอใน Page in Scope เมื่อมีการดำเนินการทางบัญชีในขั้นตอนต่าง ๆ จะมีขั้นตอนการ Interface จาก Web application นี้ ไปยังระบบ Oracle EBS โดยมีการส่งข้อมูลไปตาม สเปคการส่ง Interface ซึ่งการพัฒนาส่วนนี้ สามารถใช้งานได้ล้ว แต่ต้องการเพิ่มฟีเจอร์คือ การส่ง Interface ยกเลิก เมื่อผู้ใช้ต้องการยกเลิกรายการต่าง ๆ ตามหน้าจอ จะต้องมีการส่ง Interface ไปยกเลิกที่ Oracle EBS ด้วย วิเคราะห์อย่างรอบคอบ

## Tasks
1. ค้นหาและระบุไฟล์ทั้งหมดที่ต้องแก้:
   - BudgetController.cs และไฟล์อื่น ๆ ที่เกี่ยวข้อง (Action ที่เกี่ยวข้อง)
   - Views/Budget/*.cshtml และไฟล์อื่น ๆ ที่เกี่ยวข้อง (View ที่เกี่ยวข้อง)
   - OAGBudget.API และไฟล์อื่น ๆ ที่เกี่ยวข้อง (Controller + endpoint)
   - OAGBudget.DAL และไฟล์อื่น ๆ ที่เกี่ยวข้อง (Repository / SP call) 
   - OAGBudget.Models และไฟล์อื่น ๆ ที่เกี่ยวข้อง (DTO ที่เกี่ยวข้อง)
2. อธิบายการส่ง Interface ไปยัง Oracle EBS และ List หน้าจอที่มีการส่ง Interface
3. วางแผนการพัฒนาส่วนของการทำ Intrerface ยกเลิก
4. วางแผนการทดสอบ (Test Sec)
3. ระบุ Oracle Table และ Stored Procedure ที่เกี่ยวข้อง
   รวมถึง Temp table ที่ใช้บันทึกข้อมูลยืนยัน/ยกเลิก
4. อธิบาย flow ปัจจุบัน (UI → Controller → API → DAL → DB)
   และระบุว่าต้องเปลี่ยนอะไรในแต่ละ layer
5. ห้ามแก้ไข code — วิเคราะห์และอธิบายเท่านั้น
5. ถ้าข้อมูลไม่เพียงพอ ให้ถามก่อนดำเนินการต่อ
6. สรุปผลเป็นภาษาไทย บันทึกไฟล์ที่
   D:\TFS\OAG Budget\_brain_OAGBUDGET\20260702_Cancel_Case\result_Cancel_Case_opus_max_v1_0.md