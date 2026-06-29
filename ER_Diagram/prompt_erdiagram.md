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
- Example ER Diagram - _brain_OAGBUDGET\ER_Diagram\OAGWXP.png
   
## Page in Scope


## Required Changes
ต้องการ ER Diagram ตามรูปตัวอย่าง
1. จากรูปมาจากโปรแกรมอะไร DBeaver, Toad for Oracle, SQL Navigator, Navicat
2. ถ้าจะของโปรเจคนี้ OAGWBG คิดว่าจะต้องทำ Scope อะไรบ้าง อาจแบ่งเป็น
   - Scope ของ ระบบหลัก
   - Scope ของ APPS Oracle ที่เราไป interface
   - Scope ของ ระบบทั้งหมด
** ส่วนนี้หลังจากสำรวจแล้ว ให้มา Discuss กันก่อน
3. ระยะเวลาในการทำ
4. ความเสี่ยง หรือส่วนที่ยังขาด ของการไม่ได้เชื่อม PK FK ระหว่างตาราง
   - ถ้าแก้เรื่องนี้ ทำได้เลยไหม
5. มี BA SA ให้สามารถถามเพิ่มเติมได้
6. ไม่ต้องซับซ้อนมากก็ได้ การนำไปใช้ก็คือใช้สำหรับประกอบเอกสารส่งงาน Capture ไปประกอบเอกสารอีกมี

## Tasks
1. วางแผน
2. ระบุ Oracle Table และ Stored Procedure ที่เกี่ยวข้อง
   รวมถึง Temp table ที่ใช้บันทึกข้อมูลยืนยัน/ยกเลิก
3. ถ้าข้อมูลไม่เพียงพอ ให้ถามก่อนดำเนินการต่อ
4. สรุปผลเป็นภาษาไทย บันทึกไฟล์ที่
   _brain_OAGBUDGET\ER_Diagram\roadmap_erdiagram.md