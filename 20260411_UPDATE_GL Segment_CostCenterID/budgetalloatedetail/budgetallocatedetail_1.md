# รายละเอียดการทำงานของปุ่ม "ยืนยัน" (btn-ConfirmBudgetCode)

สรุปขั้นตอนการทำงานเมื่อผู้ใช้งานกดปุ่ม **"ยืนยัน"** (`id="btn-ConfirmBudgetCode"`) ในหน้า **BudgetAllocateDetail.cshtml** ของระบบ OAG Budget

---

## 1. การทำงานในส่วน jQuery (Frontend)

เมื่อมีการคลิกปุ่ม `#btn-ConfirmBudgetCode` (เฉพาะในโหมดแก้ไขรหัสงบประมาณหลังจากสถานะของรายการเป็น 'C' หรือ Confirmed แล้ว) jQuery จะดำเนินการดังนี้:

1.  **คัดเลือกรายการที่เปลี่ยนข้อมูล**: ลูปหาทุกแถวในตาราง (`tbltab_...`) เพื่อเปรียบเทียบรหัสงบประมาณเดิมที่เก็บไว้ใน Hidden Input (`BudgetcodeId`) กับค่าที่เลือกใหม่ใน Dropdown (`select[name^="BudgetCode_"]`)
2.  **ตรวจสอบความถูกต้อง**:
    -   หากไม่มีการแก้ไขรหัสใดๆ จะแสดง Alert เตือน "ยังไม่มีการแก้ไข"
    -   หากมีการแก้ไขแต่ระบไม่ครบ จะแสดง Alert "กรุณาระบุรหัสงบประมาณให้ครบ"
3.  **ส่งข้อมูล (AJAX)**:
    -   **URL**: `/Budget/SaveBudgetCodeChanges`
    -   **Method**: `POST`
    -   **Payload**: ส่งรหัสปีงบประมาณ, ประเภทฟอร์ม และรายการที่แก้ไข (`changedItems`) ในรูปแบบ JSON
    -   **Data Structure**:
        ```json
        {
          "budgetYear": 2568,
          "budgetFormTypeId": 1,
          "items": [
            {
              "productId": 123,
              "activitycodeId": 456,
              "categoryId": 789,
              "oldBudgetcodeid": "ID_เดิม",
              "newBudgetcodeid": "ID_ใหม่"
            }
          ]
        }
        ```

---

## 2. การทำงานในส่วน Web Controller (C#)

### BudgetController (ฝั่ง Web)
เรียกใช้ Method `SaveBudgetCodeChanges(SaveBudgetCodeChangesRequest data)` ซึ่งทำหน้าที่เป็น Pass-through โดยเรียกใช้ Interface `_budgetService`:
-   เรียก `await _budgetService.SaveBudgetCodeChanges(data)`
-   `BudgetService` (ฝั่ง Web) จะทำหน้าที่ยิง Request ต่อไปยัง **Backend API** ที่ระบุไว้ใน `BaseUrlApi`

---

## 3. การทำงานในส่วน Backend API และ Business Logic

เมื่อ Request มาถึง **OAGBudget.API** จะทำงานผ่านลำดับดังนี้:

### BudgetController (ฝั่ง API)
รับข้อมูลผ่าน HTTP POST และเรียกใช้ `IBudgetService` ของฝั่ง Backend:
```csharp
var result = await _service.SaveBudgetCodeChanges(data);
```

### BudgetService Implementation (Backend)
ฟังก์ชัน `SaveBudgetCodeChanges` ใน `Services/Repository/BudgetService.cs` มีตรรกะการทำงานหลักดังนี้:

1.  **ประมวลผลข้อมูลในระบบ OAG (Internal DB)**:
    -   ตรวจสอบข้อมูลในตาราง `OagwbgBudgetcodeYears`
    -   Update ฟิลด์ `Budgetcodeid`, `Updateby`, และ `Updateon` ตามรายการที่ส่งมาจาก UI
2.  **การเชื่อมต่อระบบภายนอก (Integration)**:
    -   หากสถานะระบบเป็นการเชื่อมต่อ (`isConnection == true`) จะเรียกฟังก์ชัน `SaveBudgetAllocate(data)`
    -   **SaveBudgetAllocate**: จะทำหน้าที่ Synchronize ข้อมูลไปยังระบบ **Oracle EBS (General Ledger)**
    -   มีการคำนวณ Segment ต่างๆ (เช่น Segment9 สำหรับรหัสงบประมาณ) เพื่อทำรายการปรับปรุงงบประมาณใน EBS
    -   ใช้ `OracleConnection` และ `IEbsContext` ในการติดต่อกับฐานข้อมูล Oracle โดยตรง
3.  **บันทึกการเปลี่ยนแปลง**: เรียก `_context.SaveChangesAsync()` เพื่อ Commit ข้อมูลลง Oracle (Local DB)

---

## 4. การส่งและการใช้งาน Interface

ระบบมีการออกแบบโดยใช้ **Dependency Injection (DI)** และ Interface ในหลายระดับ:

-   **IBudgetService**: ใช้แยกส่วน Web (Frontend Logic) และ API (Business Logic) โดย Web Service จะทำหน้าที่เป็น Client เรียก API อีกที
-   **IMasterService / IDropdowns**: ใช้สำหรับจัดการข้อมูล Dropdown และความสัมพันธ์ของ Category/Plan ในหน้า UI
-   **IAuthService**: ใช้ตรวจสอบสิทธิ์และดึงข้อมูล User (`ValidateTokenAndGetUserInfo`) เพื่อนำมาบันทึกในฟิลด์ `Updateby`
-   **IEbsContext (Backend)**: Interface สำหรับจัดการ Connection ไปยังระบบ Oracle EBS ภายนอก เพื่อให้ Business Logic สามารถสลับหรือจัดการรหัสผ่าน/ConnectionString ได้ง่ายขึ้น
-   **DbContext (OagwbgContext)**: ใช้เข้าถึงข้อมูลหลักใน Oracle สำหรับ Entity ต่างๆ เช่น `OagwbgBudgetcodeYears`

---
*หมายเหตุ: ข้อมูลอ้างอิงจากรหัสต้นฉบับในโปรเจกต์ OAG Budget และ OAGBudget.API ณ วันที่ 10/04/2026*
