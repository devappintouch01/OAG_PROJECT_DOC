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
- OAG_รายงานเลขที่กันเงิน_รายละเอียด - _brain_OAGBUDGET\20260702_310_รายงานเลขที่กันเงิน\OAG_รายงานเลขที่กันเงิน_รายละเอียด.pdf
   
## Page in Scope
รายงานเลขที่กันเงิน

## Required Changes
view ที่สร้างใหม่ OAGWBG_R_BUDGETOVERLAP_RESERVED  
view ที่คล้ายกัน OAGWBG_R_BUDGETOVERLAP
ลำดับเป็นเลขที่ รันไปเรื่อยๆ 
เลขที่ โอนจัดสรร = ใช้ transferno 
พื้นที่ ภาค = REGIONNAME ที่ REGIONID ที่ตรงกับ REGIONNAME นั้นๆ
รายการใช้ CATEGORYNAME 
จำนวนเงินจัดสรร TOTALBALANCEAMOUNT จาก RESERVEDITEM
เลขที่เอกสาร BOOKNUMBER จาก RESERVEDITEM

คอลัม อนุมัติขยาย 
ถ้ามีหนี้ ใช้ USAGEAMOUNT ที่มี BUDGETRESERVEDTYPE EXPAND_PO 
ถ้าไม่มีหนี้ ใช้ USAGEAMOUNT ที่มี BUDGETRESERVEDTYPE EXPAND_PR 
ดำเนินการมีหนี้ ใช้ USAGEAMOUNT ที่มี BUDGETRESERVEDTYPE  CANCEL_PO
ดำเนินการมีไม่มีหนี้ ช้ USAGEAMOUNT ที่มี BUDGETRESERVEDTYPE CANCEL_PR

หมายเหตุ = NOTE จาก RESERVEDITEM

RESERVEDNO_ADD จาก RESERVEDITEM เข้าไปใน VIEW ด้วย

## Tasks
1. ขอ VIEW ที่เอามาใช้กับ Report นี้
2. ห้ามแก้ไข code — วิเคราะห์และอธิบายเท่านั้น
3. ถ้าข้อมูลไม่เพียงพอ ให้ถามก่อนดำเนินการต่อ
4. สรุปผลเป็นภาษาไทย บันทึกไฟล์ที่
   _brain_OAGBUDGET\20260702_310_รายงานเลขที่กันเงิน\result_310_opus_max.md