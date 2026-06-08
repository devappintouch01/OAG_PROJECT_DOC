## ผลการวิเคราะห์ (Analysis Results)
**วันที่วิเคราะห์:** 2026-06-08  
**สถานะ:** วิเคราะห์เสร็จสิ้น — รอการพัฒนา

---

## 1. ความเข้าใจ Feature และ Dependency

### Feature ที่เกี่ยวข้อง
- **โอนจัดสรร (BudgetAllocateTransfer)** — feature หลักที่จะ "ยืมโครงสร้าง" มาใช้ (List + Header)
- **ขอรับจัดสรรเพิ่มเติม (BudgetRequestMoreCostcenter)** — feature ที่เก็บ "คำขอ" ที่ BudgetAllocateTransferMore จะดึงรายการมา

### ตาราง Oracle ที่ใช้งาน

| ตาราง | วัตถุประสงค์ | Model C# |
|---|---|---|
| `OAGWBG_BUDGETALLOCATETRANSFER` | Header ใบโอนจัดสรร | `OagwbgBudgetallocatetransfer` |
| `OAGWBG_BUDGETALLOCATETRANSFER_CATEGORY` | รายการโอนออก (ต้นทาง) | `OagwbgBudgetallocatetransferCategory` |
| `OAGWBG_BUDGETALLOCATETRANSFER_COSTCENTER` | ศูนย์ต้นทุนในใบโอน | `OagwbgBudgetallocatetransferCostcenter` |
| `OAGWBG_BUDGETRECEIVE` | รายการรับโอน (ปลายทาง + ต้นทางที่ถูกตัด) | `OagwbgBudgetreceive` |
| `OAGWBG_BUDGETREQUEST` | Header คำขอรับจัดสรรเพิ่มเติม | `OagwbgBudgetrequest` |
| `OAGWBG_BUDGETGOVERNMENT` | รายการในคำขอ | `OagwbgBudgetgovernment` |
| `OAGWBG_BUDGETGOVERNMENTITEM` | รายละเอียดรายการในคำขอ | `OagwbgBudgetgovernmentitem` |

### Oracle View ที่ใช้ (Read-only)

| View | วัตถุประสงค์ |
|---|---|
| `OAGWBG_V_BUDGETALLOCATETRANSFER` | แสดงรายการโอนพร้อม join ข้อมูล |
| `OAGWBG_V_BUDGETALLOCATETRANSFER_CATEGORY` | แสดงรายการ Category พร้อม join |
| `OAGWBG_V_BUDGETALLOCATETRANSFER_COSTCENTER` | แสดง Cost Center พร้อม join |
| `OAGWBG_V_BUDGETRECEIVE` | แสดงรายการรับโอนพร้อม join |

### Oracle Function ที่เกี่ยวข้อง

| Function | วัตถุประสงค์ |
|---|---|
| `OAGWBG_FN_GETBUDGET_ALLOCATE_TRANSFER_CATEGORY` | ดึงรายการ Category พร้อม balance สำหรับหน้าโอนจัดสรร |

> ⚠️ **หมายเหตุ:** ยังไม่พบ Stored Procedure เฉพาะ — logic ส่วนใหญ่อยู่ใน BudgetService.cs

---

## 2. Flow ปัจจุบัน (BudgetAllocateTransfer — ระบบต้นแบบ)

```
[UI: BudgetAllocateTransferList.cshtml]
    │  ค้นหาด้วย Filter (RoundNo, Date, Region, BudgetYear, OrgType, Status)
    ▼
[MVC: BudgetController.SearchBudgetAllocateTransferList (line ~3530)]
    │  POST → API
    ▼
[API: BudgetController.GetBudgetAllocateTransferList (line 1181)]
    │  เรียก _service.GetBudgetAllocateTransferList()
    ▼
[Service: BudgetService.GetBudgetAllocateTransferList (line 7951)]
    │  Query OAGWBG_V_BUDGETALLOCATETRANSFER
    ▼
[DB: Oracle SELECT จาก OAGWBG_V_BUDGETALLOCATETRANSFER]

─────────────────────────────────────────────────────

[UI: BudgetAllocateTransferDetail.cshtml]  (new / edit)
    │  กรอกข้อมูล header + เลือกรายการงบประมาณจาก Modal (SearchBudgetTransferCategory)
    ▼
[MVC: BudgetController.SaveBudgetAllocateTransferDetail (line ~3580)]
    │  POST body: BudgetAllocateTransferDetailModel
    ▼
[API: BudgetController.SaveBudgetAllocateTransferDetail (line 1223)]
    │  เรียก _service.SaveBudgetAllocateTransferDetail()
    ▼
[Service: BudgetService.SaveBudgetAllocateTransferDetail (line 8306)]
    │  ├─ สร้าง/อัปเดต OAGWBG_BUDGETALLOCATETRANSFER (header)
    │  ├─ SaveBudgetAllocateTransferCategory → OAGWBG_BUDGETALLOCATETRANSFER_CATEGORY
    │  └─ SaveBudgetAllocateTransferCostCenter → OAGWBG_BUDGETALLOCATETRANSFER_COSTCENTER

─────────────────────────────────────────────────────

[UI: กดปุ่ม "ยืนยัน" (Confirm)]
    ▼
[MVC: BudgetController.ConfirmBudgetAllocateTransfer (line ~3620)]
    ▼
[API: BudgetController.ConfirmBudgetAllocateTransfer (line 1307)]
    ▼
[Service: BudgetService.ConfirmBudgetAllocateTransfer (line 15391)]
    │  ├─ อัปเดตสถานะเป็น "80201"
    │  ├─ หา OAGWBG_BUDGETRECEIVE ที่ตรงกับแต่ละ Category
    │  │   (Match โดย: Categoryid + Productid + Activityid + BudgetSourceId)
    │  ├─ ถ้าไม่เจอ → สร้าง OAGWBG_BUDGETRECEIVE ใหม่ ยอด = 0
    │  └─ อัปเดต Totaltransferamount ใน OAGWBG_BUDGETRECEIVE (ตัดยอดต้นทาง)
         และสร้าง OAGWBG_BUDGETRECEIVE ปลายทาง
```

### Status Codes (BudgetAllocateTransfer)
| Code | ความหมาย |
|---|---|
| 80101 | ร่าง (Draft) |
| 80201 | ยืนยัน (Confirmed) |
| 90109 | ยกเลิก (Cancelled) |

### Status Codes (BudgetRequestMoreCostcenter — ขอรับจัดสรรเพิ่มเติม)
| Code | ความหมาย |
|---|---|
| 10101 | ร่าง (Draft) |
| 10102 | ส่งเรื่องแล้ว (Submitted) |
| 20101 | **ยืนยัน (Confirmed)** ← สถานะที่ต้องดึงมาแสดงในหน้าใหม่ |

---

## 3. ไฟล์ทั้งหมดที่ต้องสร้างใหม่ / แก้ไข

### 3.1 ไฟล์ใหม่ที่ต้องสร้าง (New Files)

#### Frontend (Views)
| ไฟล์ | Path | รายละเอียด |
|---|---|---|
| `BudgetAllocateTransferMoreList.cshtml` | `OAGBudget\Views\Budget\` | Copy โครงสร้างจาก `BudgetAllocateTransferList.cshtml` — Filter, Table เหมือนเดิม |
| `BudgetAllocateTransferMoreDetail.cshtml` | `OAGBudget\Views\Budget\` | **ไฟล์หลัก** — Header จาก `BudgetAllocateTransferDetail.cshtml` + ส่วนแสดงรายการจากคำขอ + Modal เลือกคำขอ + Modal เลือกแหล่งเงินโอนออก |
| `_tableBudgetAllocateTransferMoreList.cshtml` | `OAGBudget\Views\Budget\_partialView\` | Partial view table สำหรับหน้า List |

#### Models / DTOs
| ไฟล์ | Path | รายละเอียด |
|---|---|---|
| `BudgetAllocateTransferMoreDetailModel.cs` | `OAGBudget.Models\Data\` | Model สำหรับ Save — Header + รายการรับโอน (จากคำขอ) + รายการโอนออกแต่ละรายการ |
| `BudgetAllocateTransferMoreItemModel.cs` | `OAGBudget.Models\Data\` | Model แต่ละรายการจากคำขอ + ข้อมูลฝั่งโอนออก (BudgetSourceId, DeptId, CostCenterId, etc.) |
| `SearchBudgetAllocateTransferMore.cs` | `OAGBudget.Models\Search\` | อาจ reuse `SearchBudgetAllocateTransferList` ได้เลย หรือสร้างใหม่ถ้ามี filter พิเศษ |
| `BudgetAllocateTransferMoreDetailViewModel.cs` | `OAGBudget.Models\ViewModel\` | ViewModel สำหรับส่งไปหน้า Detail (Header + Dropdown + รายการคำขอ) |

#### DAL (Entity/Model)
| ไฟล์ | Path | รายละเอียด |
|---|---|---|
| *(อาจไม่ต้องสร้างใหม่ ถ้าใช้ตารางเดิม)* | — | ใช้ `OagwbgBudgetallocatetransfer`, `OagwbgBudgetallocatetransferCategory`, `OagwbgBudgetreceive` เดิม |

### 3.2 ไฟล์ที่ต้องแก้ไข (Modified Files)

#### MVC Controller
| ไฟล์ | Path | Actions ที่ต้องเพิ่ม |
|---|---|---|
| `BudgetController.cs` | `OAGBudget\Controllers\` | `BudgetAllocateTransferMoreList()`, `SearchBudgetAllocateTransferMoreList()`, `BudgetAllocateTransferMoreDetail(int? id)`, `SaveBudgetAllocateTransferMoreDetail()`, `ConfirmBudgetAllocateTransferMore()`, `CancelBudgetAllocateTransferMore()`, `DeleteBudgetAllocateTransferMore()` |

#### API Controller
| ไฟล์ | Path | Endpoints ที่ต้องเพิ่ม |
|---|---|---|
| `BudgetController.cs` | `OAGBudget.API\Controllers\` | `GetBudgetAllocateTransferMoreList`, `GetBudgetAllocateTransferMoreDetail/{id}`, `SaveBudgetAllocateTransferMoreDetail`, `ConfirmBudgetAllocateTransferMore`, `CancelBudgetAllocateTransferMore`, `DeleteBudgetAllocateTransferMore`, **`GetBudgetRequestMoreForTransfer`** (ดึงคำขอยืนยัน), **`GetBudgetGovernmentByRequestId/{id}`** (ดึงรายการในคำขอ) |

#### Service (Business Logic)
| ไฟล์ | Path | Methods ที่ต้องเพิ่ม |
|---|---|---|
| `BudgetService.cs` | `OAGBudget.API\Services\Repository\` | `GetBudgetAllocateTransferMoreList()`, `GetBudgetAllocateTransferMoreDetail()`, `SaveBudgetAllocateTransferMoreDetail()`, `ConfirmBudgetAllocateTransferMore()`, **`GetBudgetRequestMoreForTransfer()`** (Query OAGWBG_BUDGETREQUEST ที่ StatusId = 20101), **`GetBudgetGovernmentByRequestId()`** (Query OAGWBG_BUDGETGOVERNMENT + OAGWBG_BUDGETGOVERNMENTITEM) |

#### Navigation / Menu
| ไฟล์ | Path | รายละเอียด |
|---|---|---|
| *(ไฟล์ Menu/Navigation)* | `OAGBudget\Views\Shared\` หรือ `_Layout.cshtml` | เพิ่ม menu item "โอนจัดสรรเพิ่มเติม" |

---

## 4. DB Changes ที่อาจต้องทำ

| # | ตาราง | Column ใหม่ | ประเภท | วัตถุประสงค์ |
|---|---|---|---|---|
| DB-1 | `OAGWBG_BUDGETALLOCATETRANSFER` | `TRANSFERMORETYPE` หรือ `BUDGETREQUESTID` | NUMBER (nullable) | ระบุว่าเป็น TransferMore หรือเชื่อมกับคำขอ — ⚠️ ต้องตัดสินใจว่าจะแยกตาราง หรือเพิ่ม column ใน existing table |

> **ทางเลือก:**  
> - **Option A (แนะนำ):** เพิ่ม column `BUDGETREQUESTID` ใน `OAGWBG_BUDGETALLOCATETRANSFER` — ถ้าเป็น NULL = TransferปกติH ถ้ามีค่า = TransferMore  
> - **Option B:** สร้างตารางใหม่ `OAGWBG_BUDGETALLOCATETRANSFERMORE` แยกออกมา  

---

## 5. Flow ใหม่ที่ต้องสร้าง (BudgetAllocateTransferMore)

```
[UI: BudgetAllocateTransferMoreList.cshtml]
    │  ใช้โครงสร้าง Filter + Table เหมือน BudgetAllocateTransferList
    ▼
[MVC/API: SearchBudgetAllocateTransferMoreList → GetBudgetAllocateTransferMoreList]
    │  Query OAGWBG_V_BUDGETALLOCATETRANSFER (WHERE TransferMore flag หรือ BUDGETREQUESTID IS NOT NULL)
    ▼
[DB: SELECT จาก view เดิม หรือ view ใหม่ถ้าแยกตาราง]

─────────────────────────────────────────────────────

[UI: BudgetAllocateTransferMoreDetail.cshtml — หน้าใหม่]
    │
    ├─ [Header Section] (เหมือน BudgetAllocateTransferDetail)
    │   TransferDate, Region, TransferOrgType, BudgetYear, RoundNo
    │
    ├─ [ปุ่ม "เลือกคำขอรับจัดสรรเพิ่มเติม"]
    │   ▼
    │   [Modal: เลือกคำขอ]
    │       Query: OAGWBG_BUDGETREQUEST
    │         WHERE StatusId = 20101 (ยืนยัน)
    │         AND BudgetTypeId = 3 (More)
    │         AND BudgetYear = ปีที่เลือก
    │       แสดง: เลขที่คำขอ, หน่วยเบิกจ่าย, ศูนย์ต้นทุน, ยอดรวม
    │
    ├─ [ตารางรายการจากคำขอที่เลือก]
    │   Query: OAGWBG_BUDGETGOVERNMENT + OAGWBG_BUDGETGOVERNMENTITEM
    │     WHERE BudgetRequestId = คำขอที่เลือก
    │     AND สถานะยืนยัน (ยังไม่มีส่วนนี้ — ต้องพัฒนาเพิ่มที่หน้าขอรับจัดสรร)
    │   แสดง: แผนงาน, ผลผลิต, กิจกรรม, รายการ, รหัสงบ, ยอดที่ขอ
    │
    └─ [แต่ละรายการ: ปุ่ม "เลือกแหล่งเงินโอนออก"]
        ▼
        [Modal: เลือกแหล่งเงินโอนออก]
            ├─ Dropdown: แหล่งเงิน (BudgetSource)
            │
            ├─ ถ้าเลือก 100 (เงินรายจ่ายประจำปี):
            │   - ระบบ auto-fill รายการจากคำขอ (Category, Plan, Product, Activity, BudgetCode)
            │   - ให้ระบุเพิ่ม: หน่วยเบิกจ่าย (DepartmentId), ศูนย์ต้นทุน (CostCenterId)
            │   - fig = "budget" (ค่าคงที่)
            │
            └─ ถ้าเลือก 200, 400 (แหล่งเงินอื่น):
                - ให้ระบุ: หน่วยเบิกจ่าย, ศูนย์ต้นทุน, แหล่งเงิน, แผนงาน,
                           ผลผลิต, กิจกรรม, รายการ, รหัสงบประมาณ

─────────────────────────────────────────────────────

[UI: กด "บันทึก"]
    ▼
[MVC: SaveBudgetAllocateTransferMoreDetail]
    ▼
[API: SaveBudgetAllocateTransferMoreDetail]
    ▼
[Service: SaveBudgetAllocateTransferMoreDetail]
    │  ├─ สร้าง/อัปเดต OAGWBG_BUDGETALLOCATETRANSFER (header + BUDGETREQUESTID)
    │  ├─ สร้าง OAGWBG_BUDGETALLOCATETRANSFER_CATEGORY (รายการโอนออก)
    │  │   Ref = OagwbgBudgetgovernment.Id
    │  │   BudgetSourceId = แหล่งเงินที่เลือก
    │  │   รายการอื่นๆ จาก BudgetGovernment (Category, Plan, Product, Activity, BudgetCode)
    │  └─ บันทึก OAGWBG_BUDGETRECEIVE (รายการรับโอน)
    │      Departmentid = BudgetRequest.Departmentid (ผู้รับ)
    │      Costcenterid = BudgetRequest.Costcenterid
    │      BudgetSourceId = แหล่งเงินฝั่งโอนออก (ตาม Req 6.1)
    │      Totalreceiveamount = ยอดโอน

─────────────────────────────────────────────────────

[UI: กดปุ่ม "ยืนยัน" (Confirm)]
    ▼
[MVC/API/Service: ConfirmBudgetAllocateTransferMore]
    │  ใช้ logic เดิมจาก ConfirmBudgetAllocateTransfer (line 15391)
    │  ├─ ตัดยอดจาก OAGWBG_BUDGETRECEIVE ต้นทาง
    │  │   (Match: Category + Plan + Product + Activity + BudgetSource ของฝั่งโอนออก)
    │  ├─ ถ้าไม่เจอ → สร้างใหม่ยอด = 0
    │  └─ อัปเดตสถานะเป็น 80201
```

---

## 6. สิ่งที่ต้องเปลี่ยนในแต่ละ Layer

| Layer | ไฟล์ | สิ่งที่ต้องทำ |
|---|---|---|
| **DB** | Oracle | เพิ่ม column `BUDGETREQUESTID` ใน `OAGWBG_BUDGETALLOCATETRANSFER` (หรือตัดสินใจสร้างตารางใหม่) |
| **DAL** | `OagwbgBudgetallocatetransfer.cs` | เพิ่ม property `Budgetrequestid` (ถ้าเพิ่ม column) |
| **DAL** | `OagwbgVBudgetallocatetransfer.cs` | เพิ่ม `Budgetrequestid`, `RequestCode` (ถ้า view รองรับ) |
| **Models** | ไฟล์ใหม่ | สร้าง Model/DTO สำหรับ TransferMore |
| **API Service** | `BudgetService.cs` | เพิ่ม methods ใหม่: Get, Save, Confirm รวมถึง `GetBudgetRequestMoreForTransfer`, `GetBudgetGovernmentByRequestId` |
| **API Controller** | `BudgetController.cs` (API) | เพิ่ม endpoints ใหม่ |
| **MVC Controller** | `BudgetController.cs` (MVC) | เพิ่ม Actions ใหม่ + ส่ง dropdown ไปหน้า View |
| **Views** | ไฟล์ใหม่ | สร้าง List + Detail views พร้อม Modals |
| **Navigation** | `_Layout.cshtml` หรือ menu file | เพิ่มเมนู "โอนจัดสรรเพิ่มเติม" |

---

## 7. ประเด็นที่ต้องชี้แจงก่อนพัฒนา

> ❗ ข้อ 7.1-7.3 เป็นเรื่องสำคัญที่ต้องได้รับคำตอบจาก PO/User ก่อน

### 7.1 โครงสร้าง DB — แยกตาราง หรือ เพิ่ม column ในตารางเดิม?
- **Option A:** เพิ่ม column `BUDGETREQUESTID` ใน `OAGWBG_BUDGETALLOCATETRANSFER` (ง่ายกว่า ไม่ต้องสร้าง view ใหม่)
- **Option B:** สร้างตาราง `OAGWBG_BUDGETALLOCATETRANSFERMORE` แยก (โค้ดแยกชัดเจน แต่ซ้ำซ้อน)

### 7.2 สถานะยืนยันของรายการในคำขอ — ใช้จาก field ไหน?
- Requirement ระบุ "ดึงรายการมาเฉพาะที่มีสถานะยืนยัน [ยังไม่มีส่วนนี้ที่หน้าขอรับจัดสรรเพิ่มเติม]"
- ปัจจุบัน `OAGWBG_BUDGETGOVERNMENT` มี field `BudgetStatus` ("A"/"U") — ต้องยืนยันว่า "ยืนยัน" คือ BudgetStatus = "A" หรือไม่
- ⚠️ ต้องพัฒนาฟังก์ชัน "ยืนยันรายการ" ที่หน้าขอรับจัดสรรเพิ่มเติมก่อน หรือใช้ตัวกรองระดับ Header (StatusId = 20101) แทน

### 7.3 กรณี Source 100 — "fig เป็นงบประมาณ" หมายถึงอะไร?
- Requirement 5.1 ระบุ "fig เป็นงบประมาณ" — ต้องชี้แจงว่า "fig" หมายถึง field ไหนในระบบ

### 7.4 ความสัมพันธ์ใบโอน : คำขอ (1:1 หรือ 1:N)
- 1 ใบโอนจัดสรรเพิ่มเติม รองรับได้ 1 คำขอเท่านั้น หรือหลายคำขอ?

---

## 8. ความเสี่ยงและข้อควรระวัง

| # | ความเสี่ยง | ระดับ | แนวทาง |
|---|---|---|---|
| R-1 | Logic ConfirmBudgetAllocateTransfer ซับซ้อน (line 15391 ยาว ~250 บรรทัด) — ต้อง reuse ให้ถูกต้อง | สูง | สร้าง private method แยก แล้วเรียกจากทั้ง Confirm ปกติและ ConfirmMore |
| R-2 | Type mismatch: `BudgetGovernment.Productid` เป็น `long?` แต่ `BudgetAllocateTransferCategory.Productid` เป็น `string?` | กลาง | ต้องแปลงค่าก่อน mapping |
| R-3 | `BudgetGovernment.Activitycodeid` เป็น `long?` แต่ `BudgetAllocateTransferCategory.Activityid` เป็น `string?` | กลาง | ต้องแปลงค่าก่อน mapping |
| R-4 | การสร้าง BudgetReceive ต้นทางใหม่ด้วยยอด 0 อาจส่งผลต่อ balance ในรายงาน | สูง | ตรวจสอบ logic คำนวณ balance ที่มีอยู่ |
| R-5 | BudgetGovernment ในคำขออาจมีหลาย record — ต้องมี BudgetReceive ต้นทางตาม Category | กลาง | ต้องตัดสินใจว่าสร้างอัตโนมัติหรือให้ user ระบุ |
| R-6 | ยังไม่มี "สถานะยืนยันรายการ" ที่หน้าขอรับจัดสรรเพิ่มเติม | สูง | ต้องพัฒนาส่วนนี้ก่อน หรือใช้ Filter ระดับ Header แทนชั่วคราว |

---

## 9. ลำดับการพัฒนาที่แนะนำ

> ⚠️ ทำได้หลังจากได้รับคำตอบประเด็น 7.1-7.4 แล้วเท่านั้น

### Phase 1 — DB + DAL
1. เพิ่ม column `BUDGETREQUESTID` ใน `OAGWBG_BUDGETALLOCATETRANSFER` (ถ้าเลือก Option A)
2. อัปเดต `OagwbgBudgetallocatetransfer.cs` + View entity

### Phase 2 — Backend Service + API
1. เพิ่ม `GetBudgetRequestMoreForTransfer()` — Query คำขอสถานะ 20101
2. เพิ่ม `GetBudgetGovernmentByRequestId()` — Query รายการในคำขอ
3. เพิ่ม `SaveBudgetAllocateTransferMoreDetail()` — บันทึก Header + Category + BudgetReceive
4. เพิ่ม `ConfirmBudgetAllocateTransferMore()` — reuse logic จาก ConfirmBudgetAllocateTransfer
5. เพิ่ม endpoints ใน API Controller

### Phase 3 — MVC Controller + Views
1. เพิ่ม Actions ใน MVC BudgetController
2. สร้าง `BudgetAllocateTransferMoreList.cshtml` (copy + adjust)
3. สร้าง `BudgetAllocateTransferMoreDetail.cshtml` พร้อม modals
4. เพิ่มเมนู Navigation

### Phase 4 — Integration & Test
1. ทดสอบ flow ครบ (สร้าง → เลือกคำขอ → เลือกแหล่งเงิน → บันทึก → ยืนยัน)
2. ตรวจสอบยอด balance ใน OAGWBG_BUDGETRECEIVE หลังยืนยัน
3. ทดสอบ edge case (Source 100 vs 200/400, ไม่พบ BudgetReceive ต้นทาง)
