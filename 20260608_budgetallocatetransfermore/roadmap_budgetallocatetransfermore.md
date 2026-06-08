# Roadmap: โอนจัดสรรเพิ่มเติม (BudgetAllocateTransferMore)
**Version:** 1.0  
**วันที่:** 2026-06-08  
**สถานะ:** วิเคราะห์เสร็จสิ้น — พร้อมพัฒนา (รอยืนยัน DB structure)

---

## 1. ภาพรวม Feature

สร้างหน้าจอใหม่ **"โอนจัดสรรเพิ่มเติม" (BudgetAllocateTransferMore)** ที่:
- ใช้โครงสร้าง List + Header เดิมจากหน้า **โอนจัดสรร (BudgetAllocateTransfer)**
- ดึงรายการจาก **ขอรับจัดสรรเพิ่มเติม (BudgetRequestMoreCostcenter)** ที่สถานะยืนยัน (20101)
- 1 ใบโอนจัดสรรเพิ่มเติม รองรับ **หลายคำขอ (1:N)**
- แต่ละรายการจากคำขอ ผู้ใช้ระบุว่าจะโอนออกจากแหล่งเงินใด
- บันทึกลงตาราง OAGWBG_BUDGETRECEIVE (รับโอน) และ OAGWBG_BUDGETALLOCATETRANSFER_CATEGORY (โอนออก)
- กระบวนการยืนยัน reuse logic เดิมจาก ConfirmBudgetAllocateTransfer

---

## 2. Feature Dependencies

| Feature | ชื่อระบบ | วัตถุประสงค์ใน Feature นี้ |
|---|---|---|
| โอนจัดสรร | BudgetAllocateTransfer | ยืม List + Header structure |
| ขอรับจัดสรรเพิ่มเติม | BudgetRequestMoreCostcenter | แหล่งข้อมูลคำขอที่จะโอน (หลายคำขอต่อ 1 ใบโอน) |

---

## 3. ตาราง Oracle ที่เกี่ยวข้อง

### 3.1 ตารางหลัก (Read + Write)

| ตาราง | วัตถุประสงค์ | C# Model |
|---|---|---|
| `OAGWBG_BUDGETALLOCATETRANSFER` | Header ใบโอนจัดสรรเพิ่มเติม | `OagwbgBudgetallocatetransfer` |
| `OAGWBG_BUDGETALLOCATETRANSFER_CATEGORY` | รายการโอนออก (ต้นทาง) — `Ref` ชี้ไป `BudgetGovernment.Id` | `OagwbgBudgetallocatetransferCategory` |
| `OAGWBG_BUDGETALLOCATETRANSFER_COSTCENTER` | ศูนย์ต้นทุนในใบโอน | `OagwbgBudgetallocatetransferCostcenter` |
| `OAGWBG_BUDGETRECEIVE` | รายการรับโอน (ปลายทาง) + ตัดยอดต้นทาง | `OagwbgBudgetreceive` |

### 3.2 ตารางอ้างอิง (Read-only)

| ตาราง | วัตถุประสงค์ | C# Model |
|---|---|---|
| `OAGWBG_BUDGETREQUEST` | Header คำขอรับจัดสรรเพิ่มเติม | `OagwbgBudgetrequest` |
| `OAGWBG_BUDGETGOVERNMENT` | รายการในคำขอ | `OagwbgBudgetgovernment` |
| `OAGWBG_BUDGETGOVERNMENTITEM` | รายละเอียดรายการในคำขอ | `OagwbgBudgetgovernmentitem` |

### 3.3 Oracle View (Read-only)

| View | วัตถุประสงค์ |
|---|---|
| `OAGWBG_V_BUDGETALLOCATETRANSFER` | แสดงรายการ Header พร้อม join |
| `OAGWBG_V_BUDGETALLOCATETRANSFER_CATEGORY` | แสดง Category พร้อม join |
| `OAGWBG_V_BUDGETALLOCATETRANSFER_COSTCENTER` | แสดง Cost Center พร้อม join |
| `OAGWBG_V_BUDGETRECEIVE` | แสดงรายการรับโอนพร้อม join |

### 3.4 Oracle Function

| Function | วัตถุประสงค์ |
|---|---|
| `OAGWBG_FN_GETBUDGET_ALLOCATE_TRANSFER_CATEGORY` | ดึงรายการ Category พร้อม balance (ใช้ในหน้าโอนจัดสรรปกติ) |

> ⚠️ ไม่พบ Stored Procedure เฉพาะ — business logic อยู่ใน BudgetService.cs

---

## 4. Status Codes

### BudgetAllocateTransfer / BudgetAllocateTransferMore (ใบโอน)

| Code | ความหมาย |
|---|---|
| 80101 | ร่าง (Draft) |
| 80201 | ยืนยัน (Confirmed) |
| 90109 | ยกเลิก (Cancelled) |

### BudgetRequestMoreCostcenter (ขอรับจัดสรรเพิ่มเติม)

| Code | ความหมาย | หมายเหตุ |
|---|---|---|
| 10101 | ร่าง (Draft) | — |
| 10102 | ส่งเรื่องแล้ว (Submitted) | — |
| **20101** | **ยืนยัน (Confirmed)** | **← Filter เฉพาะสถานะนี้ใน modal เลือกคำขอ** |

---

## 5. กฎ Business ที่สำคัญ

### 5.1 ความสัมพันธ์ใบโอน : คำขอ = 1 : N
- 1 ใบโอนจัดสรรเพิ่มเติม สามารถดึงจาก **หลายคำขอ** ได้
- แต่ละรายการใน Category ผูกกับ BudgetGovernment (และรู้ว่ามาจากคำขอใด ผ่าน `Ref` → `BudgetGovernment.Id` → `BudgetGovernment.BudgetRequestId`)
- ใน DB ไม่จำเป็นต้องเก็บ RequestId ที่ Header — ดูจาก Category ได้เลย

### 5.2 กรณี BudgetSource = "100" (เงินรายจ่ายประจำปี)
- ระบบ **auto-fill** รายการโอนออกจากรายการรับโอนเดียวกัน (Category, Plan, Product, Activity, BudgetCode เหมือนกัน)
- **DepartmentId และ CostCenterId ถูก fix เป็นค่าคงที่** — user ไม่ต้องเลือก:
  - `DEPARTMENTID = 2900600000` (fixed)
  - `COSTCENTERID = 2906999999` (fixed)
- **`Budgettypeid` = fixed เป็น "งบประมาณ"** — ค่าคงที่ ไม่ให้ user เลือก

### 5.3 กรณี BudgetSource อื่น เช่น "200", "400"
- User ต้องเลือกทุก field เอง: หน่วยเบิกจ่าย, ศูนย์ต้นทุน, แหล่งเงิน, แผนงาน, ผลผลิต, กิจกรรม, รายการ, รหัสงบประมาณ

### 5.4 การบันทึกรายการรับโอน (Req 6.1)
- บันทึกลง `OAGWBG_BUDGETRECEIVE`
- **`Budgetsourceid`** = แหล่งเงินฝั่งโอนออก (ไม่ใช่แหล่งเงินในคำขอ)
- `Departmentid` = BudgetRequest.Departmentid, `Costcenterid` = BudgetRequest.Costcenterid

### 5.5 การบันทึกรายการโอนออก + ตัดยอด (Req 6.2)
- บันทึกลง `OAGWBG_BUDGETALLOCATETRANSFER_CATEGORY`
- ตัดยอดจาก `OAGWBG_BUDGETRECEIVE` ที่ตรงกัน (Match: Category + Plan + Product + Activity + BudgetSource + CostCenter + Department + BudgetYear)
- ถ้าไม่พบ → สร้าง `OAGWBG_BUDGETRECEIVE` ใหม่ ยอด = 0
- **กระบวนการนี้ reuse จาก `ConfirmBudgetAllocateTransfer` (BudgetService.cs line 15391)**

---

## 6. DB Changes ที่ต้องทำ

### ตัวเลือก (ต้องตัดสินใจก่อน Phase 1)

**Option A (แนะนำ):** เพิ่ม column `TRANSFERTYPE` ใน `OAGWBG_BUDGETALLOCATETRANSFER`

| ตาราง | Column ใหม่ | Type | ค่า |
|---|---|---|---|
| `OAGWBG_BUDGETALLOCATETRANSFER` | `TRANSFERTYPE` | VARCHAR2(10) nullable | NULL = โอนจัดสรรปกติ, `'MORE'` = โอนจัดสรรเพิ่มเติม |

- ไม่ต้องสร้างตารางใหม่
- List page filter ด้วย `TRANSFERTYPE = 'MORE'`
- ความสัมพันธ์กับคำขอ (1:N) ดูผ่าน CATEGORY.Ref → BudgetGovernment.BudgetRequestId (ไม่ต้องเก็บที่ Header)

**Option B:** สร้างตาราง `OAGWBG_BUDGETALLOCATETRANSFERMORE` แยก — code แยกชัดเจน แต่ซ้ำซ้อนมาก

**DAL ที่ต้องอัปเดต (ถ้าเลือก Option A):**
- `OagwbgBudgetallocatetransfer.cs` — เพิ่ม property `Transfertype`
- `OagwbgVBudgetallocatetransfer.cs` — เพิ่ม `Transfertype`

---

## 7. Flow ระบบ

### 7.1 หน้า List

```
[UI: BudgetAllocateTransferMoreList.cshtml]
  → Filter: RoundNo, TransferDate, Region, BudgetYear, OrgType, Status
  → POST: SearchBudgetAllocateTransferMoreList
  → API: GetBudgetAllocateTransferMoreList
  → Service: GetBudgetAllocateTransferMoreList()
  → DB: SELECT จาก OAGWBG_V_BUDGETALLOCATETRANSFER
        WHERE TRANSFERTYPE = 'MORE'
```

### 7.2 หน้า Detail — สร้าง/แก้ไข

```
[UI: BudgetAllocateTransferMoreDetail.cshtml]
  │
  ├─ [Header] TransferDate, Region, OrgType, BudgetYear, RoundNo (auto)
  │
  ├─ [ปุ่ม "เพิ่มจากคำขอ"] → Modal เลือกคำขอ (เรียกซ้ำได้เพื่อเพิ่มจากหลายคำขอ)
  │     → API: GetBudgetRequestMoreForTransfer
  │     → Service: GetBudgetRequestMoreForTransfer()
  │     → DB: SELECT จาก OAGWBG_V_BUDGETREQUEST (View)
  │           WHERE Budgetformtypeid = 3  ← ขอรับจัดสรรเพิ่มเติม (mandatory — ref: MasterService.cs:3107)
  │             AND IS_COSTCENTER = 1     ← Cost Center type (mandatory — ใช้คู่กับ formtype=3 เสมอ)
  │             AND Statusid = 20101      ← เฉพาะสถานะยืนยัน
  │             AND Rn IS NULL            ← version ล่าสุดเท่านั้น
  │             AND Budgetyear = ปีที่เลือก (optional filter จาก user)
  │           หมายเหตุ: BudgetFormTypeId=3 หมายถึง "ขอรับจัดสรรเพิ่มเติม" (1=แผนงาน, 2=โครงการ, 3=เพิ่มเติม)
  │     แสดง: เลขที่คำขอ, หน่วยเบิกจ่าย, ศูนย์ต้นทุน, ยอดรวม
  │
  ├─ [ตารางรายการจากคำขอ] (สะสมจากหลายคำขอได้)
  │     → API: GetBudgetGovernmentByRequestId/{id}
  │     → Service: GetBudgetGovernmentByRequestId()
  │     → DB: SELECT จาก OAGWBG_BUDGETGOVERNMENT + OAGWBG_BUDGETGOVERNMENTITEM
  │           WHERE BudgetRequestId = คำขอที่เลือก
  │           AND BudgetStatus = "A" (สถานะยืนยัน — ต้องยืนยัน field กับ PO)
  │     แสดง: [คำขอ], แผนงาน, ผลผลิต, กิจกรรม, รายการ, รหัสงบ, ยอดที่ขอ, ปุ่มโอนออก
  │
  └─ [แต่ละรายการ: ปุ่ม "ระบุโอนออก"] → Modal แหล่งเงินโอนออก
        Dropdown: BudgetSource
        ├─ Source = "100" (เงินรายจ่ายประจำปี):
        │   Auto-fill: Category, Plan, Product, Activity, BudgetCode จากรายการรับโอน
        │   Fixed ทั้งหมด (ไม่มี input ให้ user):
        │     DEPARTMENTID = 2900600000
        │     COSTCENTERID = 2906999999
        │     Budgettypeid = "งบประมาณ"
        └─ Source อื่น (200, 400 ฯลฯ):
            Input ทุก field: DepartmentId, CostCenterId, BudgetSource,
                             Plan, Product, Activity, Category, BudgetCode
```

### 7.3 บันทึก

```
[UI: กด "บันทึก"]
  → MVC: SaveBudgetAllocateTransferMoreDetail
  → API: SaveBudgetAllocateTransferMoreDetail
  → Service: SaveBudgetAllocateTransferMoreDetail()
      ├─ สร้าง/อัปเดต OAGWBG_BUDGETALLOCATETRANSFER (TRANSFERTYPE = 'MORE')
      ├─ สร้าง OAGWBG_BUDGETALLOCATETRANSFER_CATEGORY (รายการโอนออก)
      │   Ref = OagwbgBudgetgovernment.Id  ← เชื่อมกลับไปคำขอได้ผ่าน field นี้
      │   BudgetSourceId = แหล่งเงินโอนออก
      │   ถ้า Source = 100:
      │     Departmentid = "2900600000" (fixed)
      │     Costcenterid = "2906999999" (fixed)
      │     Budgettypeid = "งบประมาณ"   (fixed)
      │   ถ้า Source อื่น: ใช้ค่าที่ user เลือก
      │   ⚠️ Type cast: Productid (long→string), Activitycodeid (long→string)
      └─ สร้าง OAGWBG_BUDGETRECEIVE (รายการรับโอน)
          Departmentid = BudgetRequest.Departmentid (ผู้รับ)
          Costcenterid = BudgetRequest.Costcenterid
          Budgetsourceid = แหล่งเงินฝั่งโอนออก  ← ตาม Req 6.1
          Totalreceiveamount = ยอดโอน
```

### 7.4 ยืนยัน

```
[UI: กดปุ่ม "ยืนยัน"]
  → MVC: ConfirmBudgetAllocateTransferMore
  → API: ConfirmBudgetAllocateTransferMore
  → Service: ConfirmBudgetAllocateTransferMore()
      └─ Reuse logic จาก ConfirmBudgetAllocateTransfer (line 15391):
          ├─ Match OAGWBG_BUDGETRECEIVE ต้นทาง
          │   (Categoryid + Productid + Activityid + Budgetsourceid)
          ├─ ถ้าไม่เจอ → สร้างใหม่ ยอด = 0
          ├─ ตัด Totaltransferamount ใน BudgetReceive ต้นทาง
          └─ อัปเดตสถานะเป็น 80201
```

---

## 8. ไฟล์ที่ต้องสร้าง/แก้ไข

### 8.1 ไฟล์ใหม่

#### Views (`OAGBudget\Views\Budget\`)

| ไฟล์ | รายละเอียด |
|---|---|
| `BudgetAllocateTransferMoreList.cshtml` | Copy จาก BudgetAllocateTransferList — Filter + Table เหมือนเดิม |
| `BudgetAllocateTransferMoreDetail.cshtml` | Header จาก BudgetAllocateTransferDetail + ส่วนรายการจากคำขอ + Modal เลือกคำขอ + Modal โอนออก |
| `_partialView/_tableBudgetAllocateTransferMoreList.cshtml` | Partial table สำหรับหน้า List |

#### Models (`OAGBudget.Models\`)

| ไฟล์ | Path | รายละเอียด |
|---|---|---|
| `BudgetAllocateTransferMoreDetailModel.cs` | `Data\` | Save model: Header + รายการ (รับโอน + โอนออก) |
| `BudgetAllocateTransferMoreItemModel.cs` | `Data\` | แต่ละรายการ: ข้อมูลจากคำขอ + ข้อมูลโอนออก (Source, Dept, CostCenter, etc.) |
| `BudgetAllocateTransferMoreDetailViewModel.cs` | `ViewModel\` | ViewModel → View: Header + Dropdowns + รายการจากคำขอ |

### 8.2 ไฟล์ที่ต้องแก้ไข

#### MVC Controller (`OAGBudget\Controllers\BudgetController.cs`)

| Action | HTTP | รายละเอียด |
|---|---|---|
| `BudgetAllocateTransferMoreList()` | GET | Load dropdowns → Return View |
| `SearchBudgetAllocateTransferMoreList()` | POST | Call API → JSON |
| `BudgetAllocateTransferMoreDetail(int? id)` | GET | Load dropdowns + ดึง Detail → Return View |
| `SaveBudgetAllocateTransferMoreDetail()` | POST | Call API Save |
| `ConfirmBudgetAllocateTransferMore(int id)` | POST | Call API Confirm |
| `CancelBudgetAllocateTransferMore(int id)` | POST | Call API Cancel |
| `DeleteBudgetAllocateTransferMore(int id)` | POST | Call API Delete |

#### API Controller (`OAGBudget.API\Controllers\BudgetController.cs`)

| Endpoint | HTTP | Service Method |
|---|---|---|
| `GetBudgetAllocateTransferMoreList` | GET | `GetBudgetAllocateTransferMoreList()` |
| `GetBudgetAllocateTransferMoreDetail/{id}` | GET | `GetBudgetAllocateTransferMoreDetail()` |
| `SaveBudgetAllocateTransferMoreDetail` | POST | `SaveBudgetAllocateTransferMoreDetail()` |
| `ConfirmBudgetAllocateTransferMore` | POST | `ConfirmBudgetAllocateTransferMore()` |
| `CancelBudgetAllocateTransferMore` | POST | `ChangeStatus(..., "90109")` |
| `DeleteBudgetAllocateTransferMore/{id}` | DELETE | `DeleteBudgetAllocateTransferMore()` |
| **`GetBudgetRequestMoreForTransfer`** | GET | `GetBudgetRequestMoreForTransfer()` |
| **`GetBudgetGovernmentByRequestId/{id}`** | GET | `GetBudgetGovernmentByRequestId()` |

#### Service (`OAGBudget.API\Services\Repository\BudgetService.cs`)

| Method | รายละเอียด |
|---|---|
| `GetBudgetAllocateTransferMoreList()` | Query OAGWBG_V_BUDGETALLOCATETRANSFER WHERE TRANSFERTYPE='MORE' |
| `GetBudgetAllocateTransferMoreDetail(int id)` | Header + Category + ข้อมูลคำขออ้างอิง |
| **`GetBudgetRequestMoreForTransfer()`** | Query OAGWBG_V_BUDGETREQUEST WHERE Budgetformtypeid=3 AND IS_COSTCENTER=1 AND Statusid=20101 AND Rn=NULL |
| **`GetBudgetGovernmentByRequestId(int id)`** | Query OAGWBG_BUDGETGOVERNMENT + OAGWBG_BUDGETGOVERNMENTITEM WHERE BudgetRequestId=id AND BudgetStatus="A" |
| `SaveBudgetAllocateTransferMoreDetail()` | บันทึก Header (TRANSFERTYPE='MORE') + Category (Ref=BudgetGovernment.Id) + BudgetReceive |
| `ConfirmBudgetAllocateTransferMore()` | Reuse/extract logic จาก ConfirmBudgetAllocateTransfer (line 15391) |

#### Navigation / Menu
เพิ่ม menu item **"โอนจัดสรรเพิ่มเติม"** ใน layout/menu file

---

## 9. Mapping รายการคำขอ → รายการโอน

```
OagwbgBudgetgovernment (รายการคำขอ)      → OagwbgBudgetallocatetransferCategory
──────────────────────────────────────────────────────────────────────────
.Id                                       → .Ref  (มีอยู่แล้ว — เชื่อมกลับได้)
.Categoryid                               → .Categoryid
.Budgetplanid (int)          ⚠️ cast      → .Budgetplanid (string)
.Budgettypeid (int)          ⚠️ cast      → .Budgettypeid (string)
                                            หรือ fixed = "งบประมาณ" (Source=100)
.Productid (long)            ⚠️ cast      → .Productid (string)
.Activitycodeid (long)       ⚠️ cast      → .Activityid (string)
.Budgetcode                               → .BudgetCodeId
.Totalrequestamount                       → .Totalreceiveamount (default, แก้ไขได้)
แหล่งเงินโอนออก (user เลือก)                → .BudgetSourceId

OagwbgBudgetrequest (header คำขอ)        → OagwbgBudgetreceive (รายการรับโอน)
──────────────────────────────────────────────────────────────────────────
.Departmentid                             → .Departmentid
.Costcenterid                             → .Costcenterid
.Budgetyear                               → .Budgetyear
แหล่งเงินโอนออก (user เลือก)                → .Budgetsourceid  (ตาม Req 6.1)
ยอดโอน (user ระบุ)                          → .Totalreceiveamount
```

---

## 10. ประเด็นที่ได้รับการยืนยัน ✅ และรอยืนยัน ⏳

| # | ประเด็น | สถานะ | คำตอบ |
|---|---|---|---|
| 10.1 | DB structure — เพิ่ม column หรือสร้างตารางใหม่? | ⏳ รอ | แนะนำ Option A: เพิ่ม `TRANSFERTYPE VARCHAR2(10)` ใน OAGWBG_BUDGETALLOCATETRANSFER |
| 10.2 | สถานะยืนยันรายการใน OAGWBG_BUDGETGOVERNMENT — ใช้ `BudgetStatus = "A"`? | ⏳ รอ | ชั่วคราวใช้ filter ระดับ Header (StatusId=20101) แทนได้ |
| 10.3 | ✅ ความสัมพันธ์ใบโอน : คำขอ | ✅ | **1:N** — 1 ใบโอนรองรับหลายคำขอ |
| 10.4 | ✅ "fix เป็นงบประมาณ" หมายถึงอะไร? | ✅ | **"fix ค่า"** → `Budgettypeid` fixed = "งบประมาณ" เมื่อ Source = 100 |

---

## 11. ความเสี่ยงและข้อควรระวัง

| # | ความเสี่ยง | ระดับ | แนวทาง |
|---|---|---|---|
| R-1 | `ConfirmBudgetAllocateTransfer` ซับซ้อน (~250 บรรทัด line 15391) | สูง | Extract เป็น private method แล้ว reuse จากทั้ง Confirm ปกติและ ConfirmMore |
| R-2 | Type mismatch: `BudgetGovernment.Productid (long?)` vs `Category.Productid (string?)` | กลาง | `.ToString()` ก่อน mapping |
| R-3 | Type mismatch: `BudgetGovernment.Activitycodeid (long?)` vs `Category.Activityid (string?)` | กลาง | `.ToString()` ก่อน mapping |
| R-4 | Type mismatch: `BudgetGovernment.Budgetplanid (int?)` vs `Category.Budgetplanid (string?)` | กลาง | `.ToString()` ก่อน mapping |
| R-5 | การสร้าง BudgetReceive ต้นทางใหม่ยอด 0 อาจกระทบ balance รายงาน | สูง | ตรวจสอบ balance calculation logic ก่อน |
| R-6 | ยังไม่มี "ยืนยันรายการ" ที่หน้าขอรับจัดสรรเพิ่มเติม | สูง | ชั่วคราวใช้ Filter ระดับ Header (StatusId=20101) แทน หรือพัฒนาส่วนนี้ก่อน |
| R-7 | 1:N — ใบโอนเดียวมีหลายคำขอ → รายการในตาราง Category อาจปะปนกัน | กลาง | แสดง UI แยกกลุ่มตามคำขอ, ใช้ `Ref` → `BudgetGovernment.BudgetRequestId` แยกกลุ่มได้ |

---

## 12. ลำดับการพัฒนา (Development Phases)

### Phase 1 — DB + DAL
1. ตัดสินใจ DB structure (Option A/B)
2. รัน ALTER TABLE เพิ่ม `TRANSFERTYPE` ใน `OAGWBG_BUDGETALLOCATETRANSFER`
3. อัปเดต `OagwbgBudgetallocatetransfer.cs` + View entity

### Phase 2 — Backend Service + API
1. `GetBudgetRequestMoreForTransfer()` — Query คำขอสถานะ 20101
2. `GetBudgetGovernmentByRequestId()` — Query รายการในคำขอ
3. Extract private method จาก `ConfirmBudgetAllocateTransfer` (line 15391)
4. `SaveBudgetAllocateTransferMoreDetail()` — Header (TRANSFERTYPE='MORE') + Category + BudgetReceive
5. `ConfirmBudgetAllocateTransferMore()` — เรียก extracted private method
6. เพิ่ม endpoints ใน API Controller

### Phase 3 — MVC Controller + Views
1. เพิ่ม Actions ใน MVC BudgetController
2. สร้าง `BudgetAllocateTransferMoreList.cshtml`
3. สร้าง `BudgetAllocateTransferMoreDetail.cshtml` พร้อม 2 modals (เลือกคำขอ + โอนออก)
4. เพิ่ม menu navigation

### Phase 4 — Integration & Test
1. ทดสอบ flow ครบ: สร้าง → เพิ่มจากหลายคำขอ → ระบุโอนออก (Source 100 และ 200/400) → บันทึก → ยืนยัน
2. ตรวจสอบ balance ใน OAGWBG_BUDGETRECEIVE หลังยืนยัน
3. Edge case: ไม่พบ BudgetReceive ต้นทาง → สร้างใหม่ยอด 0
4. Edge case: ใบโอนเดียวดึงจาก 2+ คำขอ
