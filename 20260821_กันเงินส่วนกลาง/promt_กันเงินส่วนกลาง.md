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
view : Budget/BudgetOverlapYearCentralList,Budget/BudgetOverlapYearCentralDetail 
controller : BudgetController/GetBudgetOverlapYearCentralList,BudgetController/GetBudgetOverlapYearCentralDetail
api : Budget/GetBudgetOverlapYearCentralDetail,Budget/GetBudgetOverlapYearCentralList


## Function to Analyze
1. Controller
- GetBudgetOverlapYearCentralList
- GetBudgetOverlapYearCentralDetail
2. View
- Budget/BudgetOverlapYearCentralList.cshtml
- Budget/BudgetOverlapYearCentralDetail.cshtml
3. API
- Budget/GetBudgetOverlapYearCentralList
- Budget/GetBudgetOverlapYearCentralDetail
More about function: 
Task<List<T>> GetBudgetReversedItemList<T>(SearchBudgetReversedItem data) where T : class;
Task<List<OagwbgVExtOagpoTransactionStatusV>> GetBudgetReservedPoListForExpand(string? prNumber, string? lineId);
public Task<ApiResultsModel> SaveBudgetReserved(BudgetReservedModel model);
public Task<ApiResultsModel> ConfirmBudgetReserved(BudgetReservedModel model);
public Task<BudgetReservedCentralViewModel> GetBudgetOverlapYearCentralList(SearchBudgetReversedItem model);
public Task<BudgetReservedViewModel> GetBudgetReservedDetail(int id);
public Task<BudgetPeriod> GetReservePeriod(DateTime? date = null);
public Task<SearchResult<OagwbgVBudgetreserved>> GetBudgetReservedList(SearchBudgetReserved model);
public Task<BudgetReservedCentralViewModel> GetBudgetOverlapYearCentralDetail(int id);
public Task<int> SaveBudgetReservedCentrall(BudgetReservedCentralFormModel data);
public Task<List<SelectListItem>> GetBudgetExpanseType();
public Task<BudgetReservedCentralViewModel> GetBudgetReservedCentralList(BudgetReservedCentralViewModel query);
public Task<ApiResultsModel> UpdateBudgetOverlapStatus(UpdateBudgetOverlapStatusModel model);
public Task<ApiResultsModel> DeleteBudgetReservedItem(int id);
## Issue
ช่วยตรวจสอบการทำงานว่าตอนนี้ต่างจากอธิบายอย่างไรและแนะนำวิธีปรับปรุงยังไม่แก้ไขโค้ด
ช่วย List มาเป็น เรื่อง+ข้อที่ต่าง+แนวทางปรับปรุง+สิ่งที่ต้องการถามเพิ่มเติม

### Step of Save Budget Allocate Transfer Detail
การบันทึกหน้านี้จะวนเป็น cycle
กันเงิน
1.กดค้นหารายการเลือกรายการ
2.กรอกจำนวนเงินกัน
3.กดบันทึก OAGWBG_BUDGETRESERVED_CATEGORY และ OAGWBG_BUDGETRESERVED
4.เมื่อเสร็จสิ้นกด ส่งเรื่อง
5.ต้องผ่านการอนุมัติ(ส่ง Interface ,แสดงใน view OAGWBG_V_BUDGET_OVERLAPYEAR_CENTRAL_DETAIL_INTERFACE) ในอีกหน้า
เมื่อเสร็จสิ้นชุดบัญจะเปลี่ยนไป เช่น จาก 68.100 จะกลายเป็น 69.400

ขยายระยะเวลา
จะยืนยันได้ปีละสองครั้งตามรอบปีงบประมาณ
1.เมื่อกันเงินมาแล้วสถานะบจะเปลี่ยน และจะมีแท็บเพิ่มเข้ามา
2.แท็บ ขยายระยะเวลา/ส่งคืนมีหนี้ ขยายระยะเวลา/ส่งคืนไม่มีหนี้(เงินจากแท็บโอนจัดสรรคือเงินที่กันไว้แล้วเอาไปจัดสรรต่อ) ขยายระยะเวลา/ส่งคืน เงินก้อนใหญ่(เงินที่กันไว้ในตอนแรก)
    2.1 ขยายระยะเวลามีหนี้ จะพิเศษที่จะมี Reservedno_add เพิ่มเข้ามา เป็น Transferno.Roundinterface แต่ถ้าขยายใบเดิมอีกรอบ Reservedno_add จะเป็นเลขเดิม
    2.2 ส่งคืนมีหนี้ ขยายระยะเวลา/ส่งคืนไม่มีหนี้ จะบันทึกลง  OAGWBG_BUDGETRESERVEDITEM.OVERLAPROUND ว่าเป็นขยายรอบที่เท่าไหร่ ของกันเงินใบหลักนั้น 
    2.3 ขยายระยะเวลา/ส่งคืน เงินก้อนใหญ่ จะบันทึกลง  OAGWBG_BUDGETRESERVEDITEM.OVERLAPROUND ว่าเป็นขยายรอบที่เท่าไหร่ ของกันเงินใบหลักนั้น ซึ่งเงินก้อนใหญ่จะบันทึกได้แค่สองครั้งต่อใบคือรอบ1 ขยาย,2 ส่งคืน
    2.4 แท็บโอนจัดสรรเป็นแค้ข้อมูลที่บอกว่าใบนี้เอาไปจัดสรรส่วนไหนบ้าง OAGWBG_BUDGETALLOCATETRANSFER
3.กดส่งเรื่องและยืนยัน (รอบขยายไม่ส่ง Interface แต่แสดงใน view OAGWBG_V_BUDGET_OVERLAPYEAR_CENTRAL_DETAIL_INTERFACE)
3.การขยายจะขยายจนกว่าจะใช้เงินจัดสรรหมด

ตาราง
ยืนยันครั้งที่ | roundInterface in OAGWBG_BUDGETRESERVED | Overlapround in OAGWBG_BUDGETRESERVEDITEM | Reservedno_add | ปีงบประมาณ  
0 | null | ยังไม่มี | ยังไม่ | 2568
1 | 1 | 1 | Transferno.1 | 2569
2 | 2 | 2 | Transferno.2 | 2569 
3 | 3 | 3 | Transferno.3 | 2570
4 | 4 | 4 | Transferno.4 | 2570
4 | 4 | 4 | Transferno.5 | 2571

แต่เหมือนในโค้ดตอนนี้ผมเขียนให้ OAGWBG_BUDGETRESERVED.ROUNDINTERFACE นำค่ามาจาก OAGWBG_BUDGETRESERVEDITEM.overlapround อยู่และตอน insert ใส่ -1 ไป