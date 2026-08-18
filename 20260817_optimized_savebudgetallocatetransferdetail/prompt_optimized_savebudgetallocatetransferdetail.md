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
view : Budget/BudgetAllocateTransferDetail
controller : BudgetController
api : Budget/SaveBudgetAllocateTransferDetail

## Function to Analyze
1. Controller
- SaveBudgetAllocateTransferDetail
2. View
- Budget/BudgetAllocateTransferDetail.cshtml
3. API
- Budget/SaveBudgetAllocateTransferDetail

## Issue
เมื่อกดบันทึก บันทึกสำเร็จ แต่ยังใช้เวลานานมากๆ เมื่อมีผู้ใช้เยอะก็นานขึ้นไปอีก โดยเฉพาะใบโอนที่มีรายการงบประมาณจำนวนมาก

### Step of Save Budget Allocate Transfer Detail
1. ปุ่มถูก render แบบมีเงื่อนไข — บรรทัด 332-335
ปุ่มบันทึกจะโผล่เฉพาะเมื่อ transferstatus == "80101" (ร่าง) หรือเป็นรายการใหม่ (Id == 0/null) เท่านั้น สถานะอื่น (80401/80201/80501/90109) ไม่มีปุ่มนี้

2. คลิกปุ่ม → เช็ค auto-update ก่อน — บรรทัด 915-917
blockedByAutoUpdate() ถ้ามี background auto-update งบประมาณกำลังทำงานอยู่ (isAutoUpdateInProgress) จะเด้ง error แล้ว return — กันการเขียนทับกันแบบ last-writer-wins

3. Validate ฟิลด์บังคับ — บรรทัด 918-951
เก็บ missingFields จาก 3 ตัว: ภาค (Region), หน่วยงานที่โอน (TransferOrgType), วันที่โอน (Transferdate) ถ้าขาดตัวใดเด้ง AlertErrorDialog ว่า "กรุณาระบุ..." แล้วหยุด (แบบรวมไม่บังคับแหล่งเงินโอน)

4. Validate ยอดจัดสรรลูก vs แม่ — บรรทัด 953-962
getChildrenOverAllocatedParents() (บรรทัด 1506) จับคู่แถวลูกด้วย ref == parent.id แล้วรวม totalallocateamount ถ้าเกิน totalreceiveamount ของแม่เกิน 0.005 (epsilon กันปัดเศษ) → เด้ง error หยุด

5. เข้าฟังก์ชัน SaveBudgetAllocateTransferDetail() — บรรทัด 1206 ประกอบ payload 3 ก้อน

6. ก้อนที่ 1 — header (object) — บรรทัด 1208-1220
อ่านจาก input: id, transferorgtype, bookno, bookdate, bankaccountid, transferdate (แปลงผ่าน dateTextToSql), regionid, totalreceiveamount, budgetsourceid, budgetyear — roundno ส่ง null เสมอ (ให้ backend ออกเลขเอง)

7. คำนวณ displayRemain ต่อกลุ่ม — บรรทัด 1222-1243
จัดกลุ่ม periodData ด้วย key = templateid + summaryaccountcode แล้วหยิบ availablebudget ตัวแรกที่ไม่เป็น null มาเป็นยอดคงเหลือของกลุ่ม เก็บใน groupDisplayRemainMap

8. ก้อนที่ 2 — รายการงบประมาณ (items) — บรรทัด 1245-1278
วน periodData (ทั้งของเก่าที่โหลดมาและที่เพิ่งเลือกจาก modal) แปลงเป็น budgetAllocateTransferCategoryList โดย:

id: 0 = รายการใหม่, > 0 = รายการเดิม
totaltemplateamount = displayRemain ของกลุ่มตัวเอง
budgetcodeid ส่งเฉพาะรายการที่เพิ่มใหม่เท่านั้น
templateid ที่เป็น __NO_TEMPLATE__ แปลงเป็น null
9. ก้อนที่ 3 — ศูนย์ต้นทุน (costCenterItems) — บรรทัด 1280-1312
สแกน #tbCostCenter tbody tr.group-child-costcenter อ่าน data-* attributes + ค่า dropdown บัญชีผู้โอน/ผู้รับโอน + textarea หมายเหตุ

10. ยืนยัน + ล็อกปุ่ม — บรรทัด 1323-1332
เช็ค isSaving กันกดซ้ำ → ConfirmSubmitDialog("ยืนยันที่จะบันทึกข้อมูล ?") → showLoading() → isSaving = true

11. ยิง AJAX POST — บรรทัด 1334-1338
POST /Budget/SaveBudgetAllocateTransferDetail แบบ application/json ด้วย payload { budgetAllocateTransfer, budgetAllocateTransferCategoryList, budgetAllocateTransferCostCenterList }

🔌 ฝั่ง MVC (Frontend Server)
12. MVC Controller รับ — BudgetController.cs:3911
bind เป็น BudgetAllocateTransferDetailModel แล้วส่งต่อ service ทันที (ไม่มี logic)

13. MVC Service proxy ไป API — BudgetService.cs:4414
สร้าง HttpClient (Timeout 10 นาที เพราะใบโอนรายการเยอะ) แนบ Bearer token จาก CurrentSignInUser → PostAsJsonAsync ไป {BaseUrlApi}/Budget/SaveBudgetAllocateTransferDetail → อ่านค่า int id กลับมา ถ้า id != 0 ถือว่าสำเร็จ
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