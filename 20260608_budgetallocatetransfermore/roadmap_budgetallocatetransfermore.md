# Roadmap: โอนจัดสรรเพิ่มเติม (BudgetAllocateTransferMore)
**Version:** 1.1  
**วันที่:** 2026-06-09  
**สถานะ:** วิเคราะห์เสร็จสิ้น — พร้อมพัฒนา ✅ (ทุกประเด็นยืนยันแล้ว)

---

## 1. ภาพรวม Feature

สร้างหน้าจอใหม่ **"โอนจัดสรรเพิ่มเติม" (BudgetAllocateTransferMore)** ที่:
- ใช้โครงสร้าง List + Header เดิมจากหน้า **โอนจัดสรร (BudgetAllocateTransfer)**
- ดึงรายการจาก **ขอรับจัดสรรเพิ่มเติม (BudgetRequestMoreCostcenter)** ที่สถานะยืนยัน (20101)
- 1 ใบโอนจัดสรรเพิ่มเติม รองรับ **หลายคำขอ (1:N)**
- แต่ละรายการจากคำขอ ผู้ใช้ระบุว่าจะโอนออกจากแหล่งเงินใด
- บันทึกลงตาราง OAGWBG_BUDGETRECEIVE (รับโอน) และ OAGWBG_BUDGETALLOCATETRANSFERMORE_CATEGORY (โอนออก)
- กระบวนการยืนยัน reuse logic เดิมจาก ConfirmBudgetAllocateTransfer

---

## 2. Feature Dependencies

| Feature | ชื่อระบบ | วัตถุประสงค์ใน Feature นี้ |
|---|---|---|
| โอนจัดสรร | BudgetAllocateTransfer | ยืม List + Header structure |
| ขอรับจัดสรรเพิ่มเติม | BudgetRequestMoreCostcenter | แหล่งข้อมูลคำขอที่จะโอน (หลายคำขอต่อ 1 ใบโอน) |

### ⚠️ Prerequisite — ต้องทำก่อน BudgetAllocateTransferMore

| งาน | รายละเอียด | ผลกระทบ |
|---|---|---|
| เพิ่ม `IS_APPROVE` ใน `OAGWBG_V_BUDGETGOVERNMENT` | การอนุมัติย้ายลงระดับ item (ไม่ใช่ Header) | `GetBudgetGovernmentByRequestId()` ใช้ View ได้โดยตรง ไม่ต้อง JOIN BUDGETREQUEST |
| นำ `IS_APPROVE` ออกจาก `OAGWBG_BUDGETREQUEST` | Header ไม่มี approval flag อีกต่อไป | `OagwbgBudgetrequest.IsApprove` และ `OagwbgVBudgetrequest` จะไม่มี field นี้ |

---

## 3. ตาราง Oracle ที่เกี่ยวข้อง

### 3.1 ตารางหลัก (Read + Write)

| ตาราง | วัตถุประสงค์ | C# Model | หมายเหตุ |
|---|---|---|---|
| `OAGWBG_BUDGETALLOCATETRANSFERMORE` | Header ใบโอนจัดสรรเพิ่มเติม | `OagwbgBudgetallocatetransfermore` | **ตารางใหม่ (Option B)** |
| `OAGWBG_BUDGETALLOCATETRANSFERMORE_CATEGORY` | รายการโอนออก (ต้นทาง) — `Ref` ชี้ไป `BudgetGovernment.Id` | `OagwbgBudgetallocatetransfermorecategory` | **ตารางใหม่ (Option B)** |
| `OAGWBG_BUDGETRECEIVE` | รายการรับโอน (ปลายทาง) + ตัดยอดต้นทาง | `OagwbgBudgetreceive` | ใช้ร่วมกับ feature อื่น |

### 3.2 ตารางอ้างอิง (Read-only)

| ตาราง | วัตถุประสงค์ | C# Model |
|---|---|---|
| `OAGWBG_BUDGETREQUEST` | Header คำขอรับจัดสรรเพิ่มเติม | `OagwbgBudgetrequest` |
| `OAGWBG_BUDGETGOVERNMENT` | รายการในคำขอ | `OagwbgBudgetgovernment` |
| `OAGWBG_BUDGETGOVERNMENTITEM` | รายละเอียดรายการในคำขอ | `OagwbgBudgetgovernmentitem` |

### 3.3 Oracle View (Read-only)

| View | วัตถุประสงค์ | หมายเหตุ |
|---|---|---|
| `OAGWBG_V_BUDGETALLOCATETRANSFERMORE` | แสดงรายการ Header พร้อม join | **View ใหม่ (Option B)** |
| `OAGWBG_V_BUDGETALLOCATETRANSFERMORE_CATEGORY` | แสดง Category พร้อม join | **View ใหม่ (Option B)** |
| `OAGWBG_V_BUDGETRECEIVE` | แสดงรายการรับโอนพร้อม join | ใช้ร่วมกับ feature อื่น |

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
- **หน่วยเบิกจ่ายและศูนย์ต้นทุน fix เป็นค่าของ "งบประมาณ"** — user ไม่ต้องเลือก:
  - `DEPARTMENTID = 2900600000` (fixed — หน่วยเบิกจ่ายงบประมาณ)
  - `COSTCENTERID = 2906999999` (fixed — ศูนย์ต้นทุนงบประมาณ)
<!-- - นี่คือความหมายของ "fix เป็นงบประมาณ" ใน Requirement 5.1 — ไม่เกี่ยวกับ field `Budgettypeid` ในฐานข้อมูล -->

### 5.3 กรณี BudgetSource อื่น เช่น "200", "400"
- User ต้องเลือกทุก field เอง: หน่วยเบิกจ่าย, ศูนย์ต้นทุน, แหล่งเงิน, แผนงาน, ผลผลิต, กิจกรรม, รายการ, รหัสงบประมาณ

### 5.4 การบันทึกรายการรับโอน (Req 6.1)
- บันทึกลง `OAGWBG_BUDGETRECEIVE`
- **`Budgetsourceid`** = แหล่งเงินฝั่งโอนออก (ไม่ใช่แหล่งเงินในคำขอ)
- `Departmentid` = BudgetRequest.Departmentid, `Costcenterid` = BudgetRequest.Costcenterid

### 5.5 การบันทึกรายการโอนออก + ตัดยอด (Req 6.2)
- บันทึกลง `OAGWBG_BUDGETALLOCATETRANSFERMORE_CATEGORY`
- ตัดยอดจาก `OAGWBG_BUDGETRECEIVE` ที่ตรงกัน (Match: Category + Plan + Product + Activity + BudgetSource + CostCenter + Department + BudgetYear)
- ถ้าไม่พบ → สร้าง `OAGWBG_BUDGETRECEIVE` ใหม่ ยอด = 0
- **กระบวนการนี้ reuse จาก `ConfirmBudgetAllocateTransfer` (BudgetService.cs line 15391)** โดยกระบวนการตัดยอดต้องใช้รายการโอนออกจากจาก ข้อ 5.2 และ 5.3

---

## 6. DB Changes ที่ต้องทำ

### ✅ ตัดสินใจแล้ว: Option B — สร้างตารางใหม่แยกออกมา

ไม่แตะตาราง `OAGWBG_BUDGETALLOCATETRANSFER` เดิมเลย — code แยกชัดเจน

#### DDL ที่ต้องสร้างใน Oracle

**1. Header table** (โครงสร้างเหมือน `OAGWBG_BUDGETALLOCATETRANSFER` ทุกคอลัมน์):

```sql
CREATE TABLE OAGWBG_BUDGETALLOCATETRANSFERMORE (
    ID                   NUMBER        NOT NULL,
    BUDGETYEAR           NUMBER(4),
    ROUNDNO              NUMBER,
    TRANSFERDATE         DATE,
    REGIONID             VARCHAR2(20),
    ORGTYPEID            VARCHAR2(20),
    DEPARTMENTID         VARCHAR2(20),
    COSTCENTERID         VARCHAR2(20),
    BUDGETSOURCEID       VARCHAR2(20),
    REMARK               VARCHAR2(4000),
    STATUSID             NUMBER,
    CREATEBY             VARCHAR2(100),
    CREATEDATE           DATE,
    UPDATEBY             VARCHAR2(100),
    UPDATEDATE           DATE,
    CONSTRAINT PK_BUDGETALLOCATETRANSFERMORE PRIMARY KEY (ID)
);
-- Sequence ใหม่
CREATE SEQUENCE SEQ_BUDGETALLOCATETRANSFERMORE START WITH 1 INCREMENT BY 1;
```

**2. Category table** (โครงสร้างเหมือน `OAGWBG_BUDGETALLOCATETRANSFER_CATEGORY`):

```sql
CREATE TABLE OAGWBG_BUDGETALLOCATETRANSFERMORE_CATEGORY (
    ID                          NUMBER        NOT NULL,
    BUDGETALLOCATETRANSFERMOREID NUMBER       NOT NULL,  -- FK → OAGWBG_BUDGETALLOCATETRANSFERMORE.ID
    REF                         NUMBER,                  -- FK → OAGWBG_BUDGETGOVERNMENT.ID
    BUDGETSOURCEID              VARCHAR2(20),
    DEPARTMENTID                VARCHAR2(20),
    COSTCENTERID                VARCHAR2(20),
    CATEGORYID                  VARCHAR2(20),
    BUDGETPLANID                VARCHAR2(20),
    BUDGETTYPEID                VARCHAR2(20),
    PRODUCTID                   VARCHAR2(20),
    ACTIVITYID                  VARCHAR2(20),
    BUDGETCODEID                VARCHAR2(20),
    TOTALTRANSFERAMOUNT         NUMBER(18,2),
    CREATEBY                    VARCHAR2(100),
    CREATEDATE                  DATE,
    CONSTRAINT PK_BUDGETALLOCATETRANSFERMORE_CAT PRIMARY KEY (ID),
    CONSTRAINT FK_BATM_CAT_HEADER FOREIGN KEY (BUDGETALLOCATETRANSFERMOREID)
        REFERENCES OAGWBG_BUDGETALLOCATETRANSFERMORE(ID)
);
CREATE SEQUENCE SEQ_BUDGETALLOCATETRANSFERMORE_CAT START WITH 1 INCREMENT BY 1;
```

**3. Views ใหม่** (mirror จาก View เดิม แต่ join กับตารางใหม่):

```sql
CREATE OR REPLACE VIEW OAGWBG_V_BUDGETALLOCATETRANSFERMORE AS
  SELECT h.*, r.REGIONNAME, o.ORGTYPENAME, s.STATUSNAME
  FROM OAGWBG_BUDGETALLOCATETRANSFERMORE h
  LEFT JOIN ...  -- join ตามแบบ OAGWBG_V_BUDGETALLOCATETRANSFER เดิม

CREATE OR REPLACE VIEW OAGWBG_V_BUDGETALLOCATETRANSFERMORE_CATEGORY AS
  SELECT c.*, ...
  FROM OAGWBG_BUDGETALLOCATETRANSFERMORE_CATEGORY c
  LEFT JOIN ...  -- join ตามแบบ OAGWBG_V_BUDGETALLOCATETRANSFER_CATEGORY เดิม
```

#### DAL C# Models ใหม่ที่ต้องสร้าง (`OAGBudget.DAL\Models\`)

| ไฟล์ | ตาราง/View |
|---|---|
| `OagwbgBudgetallocatetransfermore.cs` | `OAGWBG_BUDGETALLOCATETRANSFERMORE` |
| `OagwbgBudgetallocatetransfermorecategory.cs` | `OAGWBG_BUDGETALLOCATETRANSFERMORE_CATEGORY` |
| `OagwbgVBudgetallocatetransfermore.cs` | `OAGWBG_V_BUDGETALLOCATETRANSFERMORE` |
| `OagwbgVBudgetallocatetransfermorecategory.cs` | `OAGWBG_V_BUDGETALLOCATETRANSFERMORE_CATEGORY` |

ตาราง `OAGWBG_BUDGETALLOCATETRANSFER` และ `OAGWBG_BUDGETALLOCATETRANSFER_CATEGORY` เดิม **ไม่ต้องแก้ไขใดๆ**

---

## 7. Flow ระบบ

### 7.1 หน้า List

```
[UI: BudgetAllocateTransferMoreList.cshtml]
  → Filter: RoundNo, TransferDate, Region, BudgetYear, OrgType, Status
  → POST: SearchBudgetAllocateTransferMoreList
  → API: GetBudgetAllocateTransferMoreList
  → Service: GetBudgetAllocateTransferMoreList()
  → DB: SELECT จาก OAGWBG_V_BUDGETALLOCATETRANSFERMORE
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
  │             AND Rn IS NULL            ← Rn = Id ของต้นฉบับที่ถูกแทนที่; NULL = active/ล่าสุด (View เก็บทุก version)
  │             AND Budgetyear = ปีที่เลือก (optional filter จาก user)
  │           หมายเหตุ: BudgetFormTypeId=3 หมายถึง "ขอรับจัดสรรเพิ่มเติม" (1=แผนงาน, 2=โครงการ, 3=เพิ่มเติม)
  │     แสดง: เลขที่คำขอ, หน่วยเบิกจ่าย, ศูนย์ต้นทุน, ยอดรวม
  │
  ├─ [ตารางรายการจากคำขอ] (สะสมจากหลายคำขอได้)
  │     → API: GetBudgetGovernmentByRequestId/{id}
  │     → Service: GetBudgetGovernmentByRequestId()
  │     → DB: SELECT จาก OAGWBG_V_BUDGETGOVERNMENT
  │           WHERE BudgetRequestId = คำขอที่เลือก
  │             AND BudgetStatus = 'C'    ← ยืนยันรายการแล้ว
  │             AND IS_APPROVE = 1        ← อนุมัติระดับ item (field ใหม่ใน View — prerequisite)
  │     หมายเหตุ: IS_APPROVE จะถูกเพิ่มใน OAGWBG_V_BUDGETGOVERNMENT (item-level)
  │               และนำออกจาก OAGWBG_BUDGETREQUEST ก่อน feature นี้จะเริ่มพัฒนา
  │     แสดง: [คำขอ], แผนงาน, ผลผลิต, กิจกรรม, รายการ, รหัสงบ, ยอดที่ขอ, ปุ่มโอนออก
  │
  └─ [แต่ละรายการ: ปุ่ม "ระบุโอนออก"] → Modal แหล่งเงินโอนออก
        Dropdown: BudgetSource
        ├─ Source = "100" (เงินรายจ่ายประจำปี):
        │   Auto-fill: Category, Plan, Product, Activity, BudgetCode จากรายการรับโอน
        │   Fixed (ไม่มี input ให้ user):
        │     DEPARTMENTID = 2900600000  ← หน่วยเบิกจ่ายงบประมาณ
        │     COSTCENTERID = 2906999999  ← ศูนย์ต้นทุนงบประมาณ
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
      ├─ สร้าง/อัปเดต OAGWBG_BUDGETALLOCATETRANSFERMORE (Header)
      ├─ สร้าง OAGWBG_BUDGETALLOCATETRANSFERMORE_CATEGORY (รายการโอนออก)
      │   Ref = OagwbgBudgetgovernment.Id  ← เชื่อมกลับไปคำขอได้ผ่าน field นี้
      │   BudgetSourceId = แหล่งเงินโอนออก
      │   ถ้า Source = 100:
      │     Departmentid = "2900600000" (fixed — หน่วยเบิกจ่ายงบประมาณ)
      │     Costcenterid = "2906999999" (fixed — ศูนย์ต้นทุนงบประมาณ)
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
| `GetBudgetAllocateTransferMoreList()` | Query OAGWBG_V_BUDGETALLOCATETRANSFERMORE |
| `GetBudgetAllocateTransferMoreDetail(int id)` | Header (OAGWBG_BUDGETALLOCATETRANSFERMORE) + Category (OAGWBG_BUDGETALLOCATETRANSFERMORE_CATEGORY) + ข้อมูลคำขออ้างอิง |
| **`GetBudgetRequestMoreForTransfer()`** | Query OAGWBG_V_BUDGETREQUEST WHERE Budgetformtypeid=3 AND IS_COSTCENTER=1 AND Statusid=20101 AND Rn=NULL |
| **`GetBudgetGovernmentByRequestId(int id)`** | Query OAGWBG_V_BUDGETGOVERNMENT WHERE BudgetRequestId=id AND BudgetStatus="C" AND IS_APPROVE=1 — ใช้ View ได้โดยตรง (IS_APPROVE จะถูกเพิ่มใน View ใน prerequisite task) |
| `SaveBudgetAllocateTransferMoreDetail()` | บันทึก OAGWBG_BUDGETALLOCATETRANSFERMORE (Header) + OAGWBG_BUDGETALLOCATETRANSFERMORE_CATEGORY (Ref=BudgetGovernment.Id) + OAGWBG_BUDGETRECEIVE |
| `ConfirmBudgetAllocateTransferMore()` | Reuse/extract logic จาก ConfirmBudgetAllocateTransfer (line 15391) |

#### Navigation / Menu
เพิ่ม menu item **"โอนจัดสรรเพิ่มเติม"** ใน layout/menu file

---

## 9. Mapping รายการคำขอ → รายการโอน

```
OagwbgBudgetgovernment (รายการคำขอ)      → OagwbgBudgetallocatetransfermorecategory
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
| 10.1 | DB structure — เพิ่ม column หรือสร้างตารางใหม่? | ✅ | **Option B** — สร้างตารางใหม่แยก: `OAGWBG_BUDGETALLOCATETRANSFERMORE` + `OAGWBG_BUDGETALLOCATETRANSFERMORE_CATEGORY` ไม่แตะตารางเดิม |
| 10.2 | เงื่อนไข filter รายการใน OAGWBG_BUDGETGOVERNMENT | ✅ | **`BudgetStatus = "C" AND IS_APPROVE = 1`** — `IS_APPROVE` จะถูกเพิ่มใน `OAGWBG_V_BUDGETGOVERNMENT` ระดับ item (prerequisite) ทำให้ query ใช้ View ได้โดยตรง ไม่ต้อง JOIN |
| 10.3 | ✅ ความสัมพันธ์ใบโอน : คำขอ | ✅ | **1:N** — 1 ใบโอนรองรับหลายคำขอ |
| 10.4 | ✅ "fix เป็นงบประมาณ" หมายถึงอะไร? | ✅ | **fix DepartmentId = 2900600000 และ CostCenterId = 2906999999** (หน่วยเบิกจ่าย/ศูนย์ต้นทุนของงบประมาณ) — `Budgettypeid` ไม่เกี่ยวข้อง ผู้วิเคราะห์นำมาเองจากโค้ดโดยไม่ถูกต้อง |

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
| R-7 | 1:N — ใบโอนเดียวมีหลายคำขอ → รายการใน OAGWBG_BUDGETALLOCATETRANSFERMORE_CATEGORY อาจปะปนกัน | กลาง | แสดง UI แยกกลุ่มตามคำขอ, ใช้ `Ref` → `BudgetGovernment.BudgetRequestId` แยกกลุ่มได้ |
| R-8 | `IS_APPROVE` จะย้ายจาก Header (`OAGWBG_BUDGETREQUEST`) → item-level (`OAGWBG_V_BUDGETGOVERNMENT`) ก่อน feature นี้เริ่ม — ถ้า prerequisite ยังไม่เสร็จ feature นี้พัฒนาไม่ได้ | สูง | ต้องรอ prerequisite (เพิ่ม IS_APPROVE ใน OAGWBG_V_BUDGETGOVERNMENT + นำออกจาก BUDGETREQUEST) ให้เสร็จก่อน Phase 2 |

---

## 12. ลำดับการพัฒนา (Development Phases)

> **อัปเดตล่าสุด: 2026-06-12 14:30**

### Phase 0 — Prerequisite (ทำก่อน — ไม่ใช่งานของ Feature นี้)
> Phase 0 ไม่บล็อก feature นี้ — 0.1 + 0.2 เสร็จแล้ว ✅

| # | งาน | สถานะ (PREPROD) | สถานะ (PROD) | หมายเหตุ |
|---|---|---|---|---|
| 0.1 | เพิ่ม `IS_APPROVE` column ใน `OAGWBG_BUDGETGOVERNMENT` (table) | ✅ เสร็จแล้ว | ✅ เสร็จแล้ว | `NUMBER(1)`, NULLABLE, DEFAULT NULL — สร้างโดย dev อื่น; verified 2026-06-12 |
| 0.2 | อัปเดต View `OAGWBG_V_BUDGETGOVERNMENT` ให้ expose `IS_APPROVE` | ✅ เสร็จแล้ว | ✅ เสร็จแล้ว | **ทำโดย Claude** — `CREATE OR REPLACE VIEW` (PREPROD + PROD) |
| 0.2b | อัปเดต C# model `OagwbgVBudgetgovernment.cs` + DbContext | ✅ เสร็จแล้ว | ✅ (ใช้ร่วมกัน) | **ทำโดย Claude** — เพิ่ม `public int? Is_Approve` + entity config |
| 0.3 | นำ `IS_APPROVE` ออกจาก `OAGWBG_BUDGETREQUEST` (table) + View | ⏳ ยังไม่ได้ทำ | ⏳ ยังไม่ได้ทำ | ไม่บล็อก feature — ทำทีหลังได้ |
| 0.4 | อัปเดต `OagwbgBudgetrequest.cs` / `OagwbgVBudgetrequest.cs` | ⏳ รอ 0.3 | ⏳ รอ 0.3 | ไม่บล็อก feature |

### Phase 1 — DB + DAL

| # | งาน | สถานะ (PREPROD) | สถานะ (PROD) | หมายเหตุ |
|---|---|---|---|---|
| 1.1 | DDL: `OAGWBG_BUDGETALLOCATETRANSFERMORE` + Sequence | ✅ เสร็จแล้ว | ❌ ยังไม่ได้รัน | verified 2026-06-12 |
| 1.2 | DDL: `OAGWBG_BUDGETALLOCATETRANSFERMORE_CATEGORY` + Sequence | ✅ เสร็จแล้ว | ❌ ยังไม่ได้รัน | verified 2026-06-12 |
| 1.3 | DDL: `OAGWBG_V_BUDGETALLOCATETRANSFERMORE` | ✅ เสร็จแล้ว | ❌ ยังไม่ได้รัน | verified 2026-06-12 |
| 1.4 | DDL: `OAGWBG_V_BUDGETALLOCATETRANSFERMORE_CATEGORY` | ✅ เสร็จแล้ว | ❌ ยังไม่ได้รัน | verified 2026-06-12 |
| 1.5 | DAL Model: `OagwbgBudgetallocatetransfermore.cs` | ✅ เสร็จแล้ว | ✅ (ใช้ร่วมกัน) | สร้างไฟล์แล้ว 2026-06-12 |
| 1.6 | DAL Model: `OagwbgBudgetallocatetransfermorecategory.cs` | ✅ เสร็จแล้ว | ✅ (ใช้ร่วมกัน) | สร้างไฟล์แล้ว 2026-06-12 |
| 1.7 | DAL Model: `OagwbgVBudgetallocatetransfermore.cs` | ✅ เสร็จแล้ว | ✅ (ใช้ร่วมกัน) | สร้างไฟล์แล้ว 2026-06-12 |
| 1.8 | DAL Model: `OagwbgVBudgetallocatetransfermorecategory.cs` | ✅ เสร็จแล้ว | ✅ (ใช้ร่วมกัน) | สร้างไฟล์แล้ว 2026-06-12 |
| 1.9 | Register DbSets + Entity Config ใน `MOENDBContextBase.cs` | ✅ เสร็จแล้ว | ✅ (ใช้ร่วมกัน) | แก้ไขแล้ว 2026-06-12 |

### Phase 2 — Application Models + Service + API
> ⚠️ `GetBudgetGovernmentByRequestId` ต้องการ Phase 0.2 ก่อน (View ต้องมี `IS_APPROVE`)

| # | งาน | สถานะ | หมายเหตุ |
|---|---|---|---|
| 2.1 | `SearchBudgetAllocateTransferMoreList.cs` | ✅ เสร็จแล้ว | สร้างไฟล์แล้ว 2026-06-12 |
| 2.2 | `BudgetAllocateTransferMoreDetailModel.cs` | ✅ เสร็จแล้ว | สร้างไฟล์แล้ว 2026-06-12 |
| 2.3 | `BudgetAllocateTransferMoreDetailViewModel.cs` | ✅ เสร็จแล้ว | สร้างไฟล์แล้ว 2026-06-12 |
| 2.4 | Service Interface — 8 method signatures | ✅ เสร็จแล้ว | แก้ไข BudgetService.cs 2026-06-12 |
| 2.5 | Service Implementation — GetList, GetDetail, Save, Confirm, Delete | ✅ เสร็จแล้ว | แก้ไข BudgetService.cs 2026-06-12 |
| 2.6 | API Controller — 8 endpoints | ✅ เสร็จแล้ว | แก้ไข OAGBudget.API BudgetController.cs 2026-06-12 |

### Phase 3 — MVC Controller + Views

| # | งาน | สถานะ | หมายเหตุ |
|---|---|---|---|
| 3.1 | MVC Controller — 7 actions + dropdown loading | ✅ เสร็จแล้ว | แก้ไข OAGBudget BudgetController.cs 2026-06-12 |
| 3.2 | `BudgetAllocateTransferMoreList.cshtml` + partial table | ✅ เสร็จแล้ว | สร้างไฟล์แล้ว 2026-06-12 |
| 3.3 | `BudgetAllocateTransferMoreDetail.cshtml` พร้อม 2 modals | ✅ เสร็จแล้ว | สร้างไฟล์แล้ว 2026-06-12 |
| 3.4 | เพิ่ม menu navigation (Route: **<span style="color: red">/Budget/BudgetAllocateTransferMoreList</span>**) | ✅ เสร็จแล้ว (PREPROD) | ดู Section 13.4 สำหรับ SQL scripts และ debug history |

### Phase 4 — Code Build + Integration & Test

| # | งาน | สถานะ | หมายเหตุ |
|---|---|---|---|
| 4.0 | Build solution — ตรวจ compile error | ✅ เสร็จแล้ว | Build succeeded (0 errors) — 2026-06-12 10:00 |
| 4.1 | ทดสอบ flow ครบ: สร้าง → เพิ่มจากหลายคำขอ → ระบุโอนออก → บันทึก → ยืนยัน | ⏳ รอ DB (Phase 1.1-1.4 PREPROD) + Phase 0.2 |
| 4.2 | ตรวจสอบ balance ใน `OAGWBG_BUDGETRECEIVE` หลังยืนยัน | ⏳ รอ 4.1 |
| 4.3 | Edge case: ไม่พบ BudgetReceive ต้นทาง → สร้างใหม่ยอด 0 | ⏳ รอ 4.1 |
| 4.4 | Edge case: ใบโอนเดียวดึงจาก 2+ คำขอ | ⏳ รอ 4.1 |

---

## Build Fixes (2026-06-12 10:00)

### CS Compiler Errors (5 items fixed)

| ปัญหา | ไฟล์ | สาเหตุ | วิธีแก้ |
|---|---|---|---|
| CS1503 | BudgetService.cs (API) line 16258 | `.Skip(data.Skip).Take(data.Take)` — ไม่มี property | เปลี่ยนเป็น `.Sort(data.Sorting).Page(data.Paging)` pattern |
| CS1061 | BudgetService.cs (API) line 16308 | `x.IS_APPROVE` แต่ property ชื่อ `Is_Approve` | เปลี่ยนเป็น `x.Is_Approve` |
| CS1739 | BudgetService.cs (API) line 16433 | `deleteFuncAsync:` แต่ signature ใช้ `removeFuncAsync:` | เปลี่ยน parameter name เป็น `removeFuncAsync:` |
| CS1061 x8 | BudgetController.cs (MVC) lines 3699-3787 | MVC project มี `IBudgetService` แยก ไม่มี TransferMore methods | เพิ่ม interface region + 8 implementation methods ใน MVC BudgetService.cs |
| RZ1031 x2 | BudgetAllocateTransferMoreDetail.cshtml lines 94-95 | `@(Model.detail?.Transferorgtype == "1" ? "selected" : "")` ใน attribute | เปลี่ยนเป็น `selected="@(Model.detail != null && Model.detail.Transferorgtype == "1")"` pattern |

**Status**: ✅ All fixed — Build succeeded (0 errors)

---

### สรุปสิ่งที่ต้องทำต่อ (Critical Path)

```
[✅ เสร็จ]  Phase 0.2 — อัปเดต OAGWBG_V_BUDGETGOVERNMENT ให้ expose IS_APPROVE (PREPROD + PROD)
[✅ เสร็จ]  Phase 1.1-1.4 — รัน SQL DDL สร้าง table/view บน PREPROD
[✅ เสร็จ]  Build solution + ตรวจ compile error (0 errors)
[✅ เสร็จ]  Phase 3.4 — เพิ่ม menu navigation บน PREPROD (ดู Section 13.4)
[ต่อไป]  Phase 1.1-1.4 — รัน SQL DDL สร้าง table/view บน PROD
[ต่อไป]  Phase 4.1-4.4 — ทดสอบ flow บน PREPROD
```

---

## 13. SQL Scripts

> **หมายเหตุ:** Section 6 DDL stub มี `STATUSID NUMBER` — section นี้ใช้ `TRANSFERSTATUS VARCHAR2(10)` ให้ตรงกับตารางเดิม `OAGWBG_BUDGETALLOCATETRANSFER`

### 13.1 Phase 0 — Prerequisite (ไม่ใช่งานของ Feature นี้)

```sql
-- เพิ่ม IS_APPROVE ระดับ item ใน OAGWBG_BUDGETGOVERNMENT
ALTER TABLE OAGWBG.OAGWBG_BUDGETGOVERNMENT
    ADD IS_APPROVE NUMBER(1) DEFAULT NULL;

COMMENT ON COLUMN OAGWBG.OAGWBG_BUDGETGOVERNMENT.IS_APPROVE
    IS 'ระบุว่าให้งบประมาณหรือไม่ (0=ยังไม่อนุมัติ, 1=อนุมัติ)';

-- อัปเดต OAGWBG_V_BUDGETGOVERNMENT ให้ expose IS_APPROVE
-- (DBA ต้องดู DDL ของ View เดิมแล้วเพิ่ม column นี้)
CREATE OR REPLACE VIEW OAGWBG.OAGWBG_V_BUDGETGOVERNMENT AS
    SELECT g.*, g.IS_APPROVE
    -- ... (เพิ่ม IS_APPROVE เข้าไปใน SELECT ของ View เดิม)
    FROM OAGWBG.OAGWBG_BUDGETGOVERNMENT g
    -- ... (JOIN เดิมทั้งหมด)
;

-- นำ IS_APPROVE ออกจาก OAGWBG_BUDGETREQUEST
ALTER TABLE OAGWBG.OAGWBG_BUDGETREQUEST
    DROP COLUMN IS_APPROVE;
```

### 13.2 Phase 1 — New Tables

```sql
-- ─────────────────────────────────────────────────────────────────
-- 1. Header table
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE OAGWBG.OAGWBG_BUDGETALLOCATETRANSFERMORE (
    ID                NUMBER(10)    NOT NULL,
    BOOKNO            VARCHAR2(200),
    BOOKDATE          VARCHAR2(255),
    BANKACCOUNTID     NUMBER(15),
    TRANSFERDATE      TIMESTAMP(6),
    REGIONID          VARCHAR2(250),
    TOTALRECEIVEAMOUNT NUMBER(38,2),
    TRANSFERSTATUS    VARCHAR2(10),
    RUNNING           NUMBER(10),
    ROUNDNO           NUMBER(10),
    CREATEBY          NUMBER(10)    DEFAULT -1,
    CREATEON          TIMESTAMP(6)  DEFAULT SYSTIMESTAMP,
    UPDATEBY          NUMBER(10),
    UPDATEON          TIMESTAMP(6),
    BUDGETYEAR        NUMBER(10),
    TRANSFERORGTYPE   VARCHAR2(255),
    BUDGETSOURCEID    VARCHAR2(255),
    CONSTRAINT PK_BUDGETALLOCATETRANSFERMORE PRIMARY KEY (ID)
);
COMMENT ON TABLE OAGWBG.OAGWBG_BUDGETALLOCATETRANSFERMORE
    IS 'ใบโอนจัดสรรเพิ่มเติม';

CREATE SEQUENCE OAGWBG.SEQ_BUDGETALLOCATETRANSFERMORE
    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- ─────────────────────────────────────────────────────────────────
-- 2. Category table
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE OAGWBG.OAGWBG_BUDGETALLOCATETRANSFERMORE_CATEGORY (
    ID                           NUMBER(10)   NOT NULL,
    CREATEBY                     NUMBER(10)   DEFAULT -1,
    CREATEON                     TIMESTAMP(6) DEFAULT SYSTIMESTAMP,
    UPDATEBY                     NUMBER(10),
    UPDATEON                     TIMESTAMP(6),
    TRANSFERSTATUS               VARCHAR2(10),
    BUDGETALLOCATETRANSFERMOREID NUMBER(10)   NOT NULL,
    CATEGORYID                   NUMBER(10),
    TOTALRECEIVEAMOUNT           NUMBER(38,2),
    TOTALALLOCATEAMOUNT          NUMBER(38,2),
    BUDGETYEAR                   NUMBER(10),
    BUDGETPLANID                 VARCHAR2(150),
    BUDGETTYPEID                 VARCHAR2(150),
    PRODUCTID                    VARCHAR2(150),
    ACTIVITYID                   VARCHAR2(150),
    SUMMARYACCOUNTCODE           VARCHAR2(255),
    BUDGETSOURCEID               VARCHAR2(3),
    BUDGETCODEID                 VARCHAR2(20),
    REF                          NUMBER(10),
    COSTCENTERID                 VARCHAR2(20),
    DEPARTMENTID                 VARCHAR2(20),
    CONSTRAINT PK_BUDGETALLOCATETRANSFERMORE_CAT PRIMARY KEY (ID),
    CONSTRAINT FK_BATM_CAT_HEADER
        FOREIGN KEY (BUDGETALLOCATETRANSFERMOREID)
        REFERENCES OAGWBG.OAGWBG_BUDGETALLOCATETRANSFERMORE(ID)
);
COMMENT ON TABLE OAGWBG.OAGWBG_BUDGETALLOCATETRANSFERMORE_CATEGORY
    IS 'รายการโอนออก (ต้นทาง) ของใบโอนจัดสรรเพิ่มเติม';
COMMENT ON COLUMN OAGWBG.OAGWBG_BUDGETALLOCATETRANSFERMORE_CATEGORY.REF
    IS 'FK → OAGWBG_BUDGETGOVERNMENT.ID — รายการจากคำขอที่โอน';

CREATE SEQUENCE OAGWBG.SEQ_BUDGETALLOCATETRANSFERMORE_CAT
    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
```

### 13.3 Phase 1 — New Views

> DBA สร้างโดย mirror DDL จาก View เดิม แล้วเปลี่ยนชื่อตาราง/FK ให้ชี้มาที่ตารางใหม่

```sql
-- View ของ Header
CREATE OR REPLACE VIEW OAGWBG.OAGWBG_V_BUDGETALLOCATETRANSFERMORE AS
    SELECT
        h.ID, h.BOOKNO, h.BOOKDATE, h.BANKACCOUNTID,
        h.TRANSFERDATE, h.REGIONID, h.TOTALRECEIVEAMOUNT,
        h.TRANSFERSTATUS,
        ms.STATUSNAME AS TRANSFERSTATUSNAME,
        h.RUNNING, h.ROUNDNO,
        h.CREATEBY, h.CREATEON, h.UPDATEBY, h.UPDATEON,
        h.BUDGETYEAR, h.TRANSFERORGTYPE, h.BUDGETSOURCEID
    FROM OAGWBG.OAGWBG_BUDGETALLOCATETRANSFERMORE h
    LEFT JOIN OAGWBG.OAGWBG_MASTERSTATUS ms
        ON h.TRANSFERSTATUS = ms.ID;

-- View ของ Category
CREATE OR REPLACE VIEW OAGWBG.OAGWBG_V_BUDGETALLOCATETRANSFERMORE_CATEGORY AS
    SELECT
        c.ID, c.CREATEBY, c.CREATEON, c.UPDATEBY, c.UPDATEON,
        c.TRANSFERSTATUS,
        c.BUDGETALLOCATETRANSFERMOREID,
        c.CATEGORYID,
        mc.CATEGORYNAME,
        c.PRODUCTID,
        c.ACTIVITYID,
        c.BUDGETPLANID,
        c.BUDGETTYPEID,
        c.TOTALRECEIVEAMOUNT, c.TOTALALLOCATEAMOUNT,
        c.BUDGETYEAR, c.REGIONID,
        c.SUMMARYACCOUNTCODE,
        c.BUDGETSOURCEID,
        c.BUDGETCODEID,
        c.REF,
        c.COSTCENTERID, c.DEPARTMENTID,
        h.ROUNDNO AS CODE
    FROM OAGWBG.OAGWBG_BUDGETALLOCATETRANSFERMORE_CATEGORY c
    LEFT JOIN OAGWBG.OAGWBG_BUDGETALLOCATETRANSFERMORE h
        ON c.BUDGETALLOCATETRANSFERMOREID = h.ID
    LEFT JOIN OAGWBG.OAGWBG_MASTERCATEGORY mc
        ON c.CATEGORYID = mc.ID;
```

### 13.4 Phase 3.4 — Menu Navigation

**Executed on PREPROD: 2026-06-12 10:45 – 14:30**

#### Final Menu Structure

```
📂 โอนเงินจัดสรรงบประมาณ  (ID=137, ISPARENT='1')
   ├── โอนจัดสรรงบประมาณ        (ID=222, SEQ=0) → Budget.BudgetAllocateTransferList
   └── โอนจัดสรรงบประมาณ เพิ่มเติม (ID=221, SEQ=1) → Budget.BudgetAllocateTransferMoreList
```

#### SQL Scripts (ลำดับการ execute จริง)

```sql
-- ── Step 1: Set ID=137 as PARENT ──
UPDATE OAGWBG_SYSTEMMENU SET ISPARENT = 'Y' WHERE ID = 137;

-- ── Step 2: Insert child ID=221 ──
INSERT INTO OAGWBG_SYSTEMMENU 
(ID, MENUNAME, PARENTMENUID, SEQUENCE, CONTROLLERNAME, ACTIONNAME,
 ISPARENT, ACTIVE, ISSHOWINSITEMENU, SYSTEMNAMEID, SYSTEMMENUGROUPID,
 ICONCSS, CREATEBY, CREATEON)
VALUES (221, 'โอนจัดสรรงบประมาณ เพิ่มเติม', 137, 1, 'Budget', 'BudgetAllocateTransferMoreList',
        'N', 'Y', '1', 2, 2, NULL, -1, SYSDATE);

COMMIT;
```

**Debug Fixes ที่ต้องทำเพิ่ม (สำคัญมาก — บันทึกไว้สำหรับ PROD):**

```sql
-- Fix 1: ISPARENT ต้องเป็น '1' ไม่ใช่ 'Y'
-- (code ใน Default.cshtml เช็ค item.Isparent == "1")
UPDATE OAGWBG_SYSTEMMENU SET ISPARENT = '1' WHERE ID = 137;

-- Fix 2: ACTIVE ต้องเป็น '1' ไม่ใช่ 'Y'
-- (Oracle Function OAGWBG_FN_BOOKINGSYSTEMMENU เช็ค M.ACTIVE = '1')
UPDATE OAGWBG_SYSTEMMENU SET ACTIVE = '1' WHERE ID = 221;

-- Fix 3: ต้อง insert role ใน OAGWBG_SYSTEMMENUROLEASSIGN
-- (function join กับ table นี้ ถ้าไม่มี record = menu ไม่ return ให้ user)
INSERT INTO OAGWBG_SYSTEMMENUROLEASSIGN (ID, SYSTEMROLEID, SYSTEMMENUID, CREATEBY, CREATEON)
VALUES (290, 1, 221, -1, SYSDATE);
INSERT INTO OAGWBG_SYSTEMMENUROLEASSIGN (ID, SYSTEMROLEID, SYSTEMMENUID, CREATEBY, CREATEON)
VALUES (291, 31, 221, -1, SYSDATE);

-- Fix 4: สร้าง child ใหม่ ID=222 สำหรับเมนูเดิม + ล้าง controller/action ของ parent
INSERT INTO OAGWBG_SYSTEMMENU 
(ID, MENUNAME, CONTROLLERNAME, ACTIONNAME, CONTROLLERMAINNAME, ICONCSS, SEQUENCE, 
 ISPARENT, PARENTMENUID, ACTIVE, ISSHOWINSITEMENU, SYSTEMNAMEID, SYSTEMMENUGROUPID, CREATEBY, CREATEON)
VALUES (222, 'โอนจัดสรรงบประมาณ', 'Budget', 'BudgetAllocateTransferList', 'Budget',
        NULL, 0, 'N', 137, '1', '1', 2, 2, -1, SYSDATE);

UPDATE OAGWBG_SYSTEMMENU SET CONTROLLERNAME=NULL, ACTIONNAME=NULL WHERE ID=137;

-- Role สำหรับ ID=222
INSERT INTO OAGWBG_SYSTEMMENUROLEASSIGN (ID, SYSTEMROLEID, SYSTEMMENUID, CREATEBY, CREATEON)
VALUES (292, 1, 222, -1, SYSDATE);
INSERT INTO OAGWBG_SYSTEMMENUROLEASSIGN (ID, SYSTEMROLEID, SYSTEMMENUID, CREATEBY, CREATEON)
VALUES (293, 31, 222, -1, SYSDATE);

COMMIT;
```

#### Root Causes ที่พบระหว่าง Debug

| ปัญหา | สาเหตุ | แก้ไข |
|---|---|---|
| Parent menu ไม่แสดง sub-items | `ISPARENT = 'Y'` แต่ code เช็ค `== "1"` | UPDATE เป็น `'1'` |
| Child menu ไม่ถูก return จาก function | `ACTIVE = 'Y'` แต่ function เช็ค `M.ACTIVE = '1'` | UPDATE เป็น `'1'` |
| Child menu ไม่ถูก return จาก function | ไม่มี record ใน `OAGWBG_SYSTEMMENUROLEASSIGN` | INSERT role 1 และ 31 |
| Parent menu ต้องการ child ของตัวเดิมด้วย | Parent เดิม (ID=137) link ตรงไปหน้า List แต่ถูกเปลี่ยนเป็น parent label | สร้าง child ID=222 + ล้าง controller/action ของ parent |

> ⚠️ **สำคัญสำหรับ PROD**: ต้อง run ทุก Fix ข้างต้น ไม่ใช่แค่ Step 1-2 เดิม

---

## 14. DAL Models — ไฟล์ใหม่

### 📄 [สร้างใหม่] `OAGBudget.DAL\Models\OagwbgBudgetallocatetransfermore.cs`

```csharp
namespace OAGBudget.DAL.Models;

public partial class OagwbgBudgetallocatetransfermore
{
    public int Id { get; set; }
    public string? Bookno { get; set; }
    public string? Bookdate { get; set; }
    public long? Bankaccountid { get; set; }
    public DateTime? Transferdate { get; set; }
    public string? Regionid { get; set; }
    public decimal? Totalreceiveamount { get; set; }
    public string? Transferstatus { get; set; }
    public int? Running { get; set; }
    public int? Roundno { get; set; }
    public int? Createby { get; set; }
    public DateTime? Createon { get; set; }
    public int? Updateby { get; set; }
    public DateTime? Updateon { get; set; }
    public int? Budgetyear { get; set; }
    public string? Transferorgtype { get; set; }
    public string? Budgetsourceid { get; set; }
}
```

### 📄 [สร้างใหม่] `OAGBudget.DAL\Models\OagwbgBudgetallocatetransfermorecategory.cs`

```csharp
namespace OAGBudget.DAL.Models;

public partial class OagwbgBudgetallocatetransfermorecategory
{
    public int Id { get; set; }
    public int? Createby { get; set; }
    public DateTime? Createon { get; set; }
    public int? Updateby { get; set; }
    public DateTime? Updateon { get; set; }
    public string? Transferstatus { get; set; }
    public int? Budgetallocatetransfermoreid { get; set; }
    public int? Categoryid { get; set; }
    public decimal? Totalreceiveamount { get; set; }
    public decimal? Totalallocateamount { get; set; }
    public int? Budgetyear { get; set; }
    public string? Budgetplanid { get; set; }
    public string? Budgettypeid { get; set; }
    public string? Productid { get; set; }
    public string? Activityid { get; set; }
    public string? SummaryAccountCode { get; set; }
    public string? BudgetSourceId { get; set; }
    public string? BudgetCodeId { get; set; }
    public int? Ref { get; set; }
    public string? CostCenterId { get; set; }
    public string? DepartmentId { get; set; }
}
```

### 📄 [สร้างใหม่] `OAGBudget.DAL\Models\OagwbgVBudgetallocatetransfermore.cs`

```csharp
namespace OAGBudget.DAL.Models;

public partial class OagwbgVBudgetallocatetransfermore
{
    public int Id { get; set; }
    public string? Bookno { get; set; }
    public string? Bookdate { get; set; }
    public long? Bankaccountid { get; set; }
    public DateTime? Transferdate { get; set; }
    public string? Regionid { get; set; }
    public decimal? Totalreceiveamount { get; set; }
    public string? Transferstatus { get; set; }
    public string? Transferstatusname { get; set; }
    public int? Running { get; set; }
    public int? Roundno { get; set; }
    public int? Createby { get; set; }
    public DateTime? Createon { get; set; }
    public int? Updateby { get; set; }
    public DateTime? Updateon { get; set; }
    public int? Budgetyear { get; set; }
    public string? Transferorgtype { get; set; }
    public string? Budgetsourceid { get; set; }
}
```

### 📄 [สร้างใหม่] `OAGBudget.DAL\Models\OagwbgVBudgetallocatetransfermorecategory.cs`

```csharp
namespace OAGBudget.DAL.Models;

public partial class OagwbgVBudgetallocatetransfermorecategory
{
    public int Id { get; set; }
    public int? Createby { get; set; }
    public DateTime? Createon { get; set; }
    public int? Updateby { get; set; }
    public DateTime? Updateon { get; set; }
    public string? Transferstatus { get; set; }
    public int? Budgetallocatetransfermoreid { get; set; }
    public int? Budgetplanid { get; set; }
    public string? Budgetplanname { get; set; }
    public int? Budgettypeid { get; set; }
    public string? Budgettypename { get; set; }
    public int? Categoryid { get; set; }
    public string? Categoryname { get; set; }
    public string? Productid { get; set; }
    public string? Productname { get; set; }
    public string? Activityid { get; set; }
    public string? Activityname { get; set; }
    public decimal? Totalreceiveamount { get; set; }
    public decimal? Totalallocateamount { get; set; }
    public int? Budgetyear { get; set; }
    public string? Regionid { get; set; }
    public string? SummaryAccountCode { get; set; }
    public string? BudgetSourceId { get; set; }
    public string? Budgetcodeid { get; set; }
    public int? Ref { get; set; }
    public string? CostCenterId { get; set; }
    public string? DepartmentId { get; set; }
    public string? Code { get; set; }
}
```

### 📄 [แก้ไข] `OAGBudget.DAL\Models\MOENDBContextBase.cs`

เพิ่ม DbSet ใน class body (ต่อจากบรรทัด `OagwbgBudgetallocatetransferCostcenterNotes`):

```csharp
public virtual DbSet<OagwbgBudgetallocatetransfermore> OagwbgBudgetallocatetransfezmores { get; set; }
public virtual DbSet<OagwbgBudgetallocatetransfermorecategory> OagwbgBudgetallocatetransfermoreCategories { get; set; }
public virtual DbSet<OagwbgVBudgetallocatetransfermore> OagwbgVBudgetallocatetransfermores { get; set; }
public virtual DbSet<OagwbgVBudgetallocatetransfermorecategory> OagwbgVBudgetallocatetransfermoreCategories { get; set; }
```

เพิ่ม entity config ใน `OnModelCreating` (ต่อจาก config ของ `OagwbgBudgetallocatetransferCostcenter`):

```csharp
modelBuilder.Entity<OagwbgBudgetallocatetransfermore>(entity =>
{
    entity.HasKey(e => e.Id).HasName("PK_BUDGETALLOCATETRANSFERMORE");
    entity.ToTable("OAGWBG_BUDGETALLOCATETRANSFERMORE");
    entity.Property(e => e.Id).HasPrecision(10).HasColumnName("ID");
    entity.Property(e => e.Bookno).HasMaxLength(200).IsUnicode(false).HasColumnName("BOOKNO");
    entity.Property(e => e.Bookdate).HasMaxLength(255).IsUnicode(false).HasColumnName("BOOKDATE");
    entity.Property(e => e.Bankaccountid).HasPrecision(15).HasColumnName("BANKACCOUNTID");
    entity.Property(e => e.Transferdate).HasPrecision(6).HasColumnName("TRANSFERDATE");
    entity.Property(e => e.Regionid).HasMaxLength(250).IsUnicode(false).HasColumnName("REGIONID");
    entity.Property(e => e.Totalreceiveamount).HasColumnType("NUMBER(38,2)").HasColumnName("TOTALRECEIVEAMOUNT");
    entity.Property(e => e.Transferstatus).HasMaxLength(10).IsUnicode(false).HasColumnName("TRANSFERSTATUS");
    entity.Property(e => e.Running).HasPrecision(10).HasColumnName("RUNNING");
    entity.Property(e => e.Roundno).HasPrecision(10).HasColumnName("ROUNDNO");
    entity.Property(e => e.Createby).HasPrecision(10).HasDefaultValueSql("-1").HasColumnName("CREATEBY");
    entity.Property(e => e.Createon).HasPrecision(6).HasDefaultValueSql("SYSTIMESTAMP").HasColumnName("CREATEON");
    entity.Property(e => e.Updateby).HasPrecision(10).HasColumnName("UPDATEBY");
    entity.Property(e => e.Updateon).HasPrecision(6).HasColumnName("UPDATEON");
    entity.Property(e => e.Budgetyear).HasPrecision(10).HasColumnName("BUDGETYEAR");
    entity.Property(e => e.Transferorgtype).HasMaxLength(255).IsUnicode(false).HasColumnName("TRANSFERORGTYPE");
    entity.Property(e => e.Budgetsourceid).HasMaxLength(255).IsUnicode(false).HasColumnName("BUDGETSOURCEID");
});

modelBuilder.Entity<OagwbgBudgetallocatetransfermorecategory>(entity =>
{
    entity.HasKey(e => e.Id).HasName("PK_BUDGETALLOCATETRANSFERMORE_CAT");
    entity.ToTable("OAGWBG_BUDGETALLOCATETRANSFERMORE_CATEGORY");
    entity.Property(e => e.Id).HasPrecision(10).HasColumnName("ID");
    entity.Property(e => e.Createby).HasPrecision(10).HasDefaultValueSql("-1").HasColumnName("CREATEBY");
    entity.Property(e => e.Createon).HasPrecision(6).HasDefaultValueSql("SYSTIMESTAMP").HasColumnName("CREATEON");
    entity.Property(e => e.Updateby).HasPrecision(10).HasColumnName("UPDATEBY");
    entity.Property(e => e.Updateon).HasPrecision(6).HasColumnName("UPDATEON");
    entity.Property(e => e.Transferstatus).HasMaxLength(10).IsUnicode(false).HasColumnName("TRANSFERSTATUS");
    entity.Property(e => e.Budgetallocatetransfermoreid).HasPrecision(10).HasColumnName("BUDGETALLOCATETRANSFERMOREID");
    entity.Property(e => e.Categoryid).HasPrecision(10).HasColumnName("CATEGORYID");
    entity.Property(e => e.Totalreceiveamount).HasColumnType("NUMBER(38,2)").HasColumnName("TOTALRECEIVEAMOUNT");
    entity.Property(e => e.Totalallocateamount).HasColumnType("NUMBER(38,2)").HasColumnName("TOTALALLOCATEAMOUNT");
    entity.Property(e => e.Budgetyear).HasPrecision(10).HasColumnName("BUDGETYEAR");
    entity.Property(e => e.Budgetplanid).HasMaxLength(150).IsUnicode(false).HasColumnName("BUDGETPLANID");
    entity.Property(e => e.Budgettypeid).HasMaxLength(150).IsUnicode(false).HasColumnName("BUDGETTYPEID");
    entity.Property(e => e.Productid).HasMaxLength(150).IsUnicode(false).HasColumnName("PRODUCTID");
    entity.Property(e => e.Activityid).HasMaxLength(150).IsUnicode(false).HasColumnName("ACTIVITYID");
    entity.Property(e => e.SummaryAccountCode).HasMaxLength(255).IsUnicode(false).HasColumnName("SUMMARYACCOUNTCODE");
    entity.Property(e => e.BudgetSourceId).HasMaxLength(3).IsUnicode(false).HasColumnName("BUDGETSOURCEID");
    entity.Property(e => e.BudgetCodeId).HasMaxLength(20).IsUnicode(false).HasColumnName("BUDGETCODEID");
    entity.Property(e => e.Ref).HasPrecision(10).HasColumnName("REF");
    entity.Property(e => e.CostCenterId).HasMaxLength(20).IsUnicode(false).IsRequired(false).HasColumnName("COSTCENTERID");
    entity.Property(e => e.DepartmentId).HasMaxLength(20).IsUnicode(false).IsRequired(false).HasColumnName("DEPARTMENTID");
});

modelBuilder.Entity<OagwbgVBudgetallocatetransfermore>(entity =>
{
    entity.HasNoKey();
    entity.ToView("OAGWBG_V_BUDGETALLOCATETRANSFERMORE");
    entity.Property(e => e.Id).HasPrecision(10).HasColumnName("ID");
    entity.Property(e => e.Transferstatus).HasMaxLength(10).IsUnicode(false).HasColumnName("TRANSFERSTATUS");
    entity.Property(e => e.Transferstatusname).HasMaxLength(255).IsUnicode(false).HasColumnName("TRANSFERSTATUSNAME");
    entity.Property(e => e.Roundno).HasPrecision(10).HasColumnName("ROUNDNO");
    entity.Property(e => e.Running).HasPrecision(10).HasColumnName("RUNNING");
    entity.Property(e => e.Transferdate).HasPrecision(6).HasColumnName("TRANSFERDATE");
    entity.Property(e => e.Regionid).HasMaxLength(250).IsUnicode(false).HasColumnName("REGIONID");
    entity.Property(e => e.Totalreceiveamount).HasColumnType("NUMBER(38,2)").HasColumnName("TOTALRECEIVEAMOUNT");
    entity.Property(e => e.Budgetyear).HasPrecision(10).HasColumnName("BUDGETYEAR");
    entity.Property(e => e.Transferorgtype).HasMaxLength(255).IsUnicode(false).HasColumnName("TRANSFERORGTYPE");
    entity.Property(e => e.Budgetsourceid).HasMaxLength(255).IsUnicode(false).HasColumnName("BUDGETSOURCEID");
    entity.Property(e => e.Createby).HasPrecision(10).HasColumnName("CREATEBY");
    entity.Property(e => e.Createon).HasPrecision(6).HasColumnName("CREATEON");
    entity.Property(e => e.Updateby).HasPrecision(10).HasColumnName("UPDATEBY");
    entity.Property(e => e.Updateon).HasPrecision(6).HasColumnName("UPDATEON");
});

modelBuilder.Entity<OagwbgVBudgetallocatetransfermorecategory>(entity =>
{
    entity.HasNoKey();
    entity.ToView("OAGWBG_V_BUDGETALLOCATETRANSFERMORE_CATEGORY");
    entity.Property(e => e.Id).HasPrecision(10).HasColumnName("ID");
    entity.Property(e => e.Transferstatus).HasMaxLength(10).IsUnicode(false).HasColumnName("TRANSFERSTATUS");
    entity.Property(e => e.Budgetallocatetransfermoreid).HasPrecision(10).HasColumnName("BUDGETALLOCATETRANSFERMOREID");
    entity.Property(e => e.Categoryid).HasPrecision(10).HasColumnName("CATEGORYID");
    entity.Property(e => e.Categoryname).HasMaxLength(255).IsUnicode(false).HasColumnName("CATEGORYNAME");
    entity.Property(e => e.Productid).HasMaxLength(150).IsUnicode(false).HasColumnName("PRODUCTID");
    entity.Property(e => e.Productname).HasMaxLength(255).IsUnicode(false).HasColumnName("PRODUCTNAME");
    entity.Property(e => e.Activityid).HasMaxLength(150).IsUnicode(false).HasColumnName("ACTIVITYID");
    entity.Property(e => e.Activityname).HasMaxLength(255).IsUnicode(false).HasColumnName("ACTIVITYNAME");
    entity.Property(e => e.Totalreceiveamount).HasColumnType("NUMBER(38,2)").HasColumnName("TOTALRECEIVEAMOUNT");
    entity.Property(e => e.Totalallocateamount).HasColumnType("NUMBER(38,2)").HasColumnName("TOTALALLOCATEAMOUNT");
    entity.Property(e => e.Budgetyear).HasPrecision(10).HasColumnName("BUDGETYEAR");
    entity.Property(e => e.BudgetSourceId).HasMaxLength(3).IsUnicode(false).HasColumnName("BUDGETSOURCEID");
    entity.Property(e => e.Budgetcodeid).HasMaxLength(20).IsUnicode(false).HasColumnName("BUDGETCODEID");
    entity.Property(e => e.Ref).HasPrecision(10).HasColumnName("REF");
    entity.Property(e => e.CostCenterId).HasMaxLength(20).IsUnicode(false).HasColumnName("COSTCENTERID");
    entity.Property(e => e.DepartmentId).HasMaxLength(20).IsUnicode(false).HasColumnName("DEPARTMENTID");
    entity.Property(e => e.Code).HasMaxLength(50).IsUnicode(false).HasColumnName("CODE");
});
```

---

## 15. Application Models — ไฟล์ใหม่

### 📄 [สร้างใหม่] `OAGBudget.Models\Search\SearchBudgetAllocateTransferMoreList.cs`

```csharp
namespace OAGBudget.Models.Search
{
    public class SearchBudgetAllocateTransferMoreList : CriteriaBase
    {
        public int? Roundno { get; set; }
        public string? Regionid { get; set; }
        public DateTime? TransferDate { get; set; }
        public int? Budgetyear { get; set; }
        public string? Transferorgtype { get; set; }
        public string? StatusId { get; set; }
    }
}
```

### 📄 [สร้างใหม่] `OAGBudget.Models\Data\BudgetAllocateTransferMoreDetailModel.cs`

```csharp
using OAGBudget.DAL.Models;

namespace OAGBudget.Models.Data
{
    public class BudgetAllocateTransferMoreDetailModel
    {
        public OagwbgBudgetallocatetransfermore? BudgetAllocateTransferMore { get; set; }
        public List<OagwbgBudgetallocatetransfermorecategory> CategoryList { get; set; } = new();
    }
}
```

### 📄 [สร้างใหม่] `OAGBudget.Models\Data\BudgetAllocateTransferMoreItemModel.cs`

> ใช้ส่งจาก UI เมื่อ user เลือกรายการจากคำขอและระบุแหล่งเงินโอนออก

```csharp
namespace OAGBudget.Models.Data
{
    public class BudgetAllocateTransferMoreItemModel
    {
        // จากคำขอ (BudgetGovernment)
        public int BudgetGovernmentId { get; set; }       // → Category.Ref
        public int BudgetRequestId { get; set; }
        public int? Categoryid { get; set; }
        public string? Budgetplanid { get; set; }
        public string? Productid { get; set; }
        public string? Activityid { get; set; }
        public string? Budgetcode { get; set; }
        public decimal? Totalrequestamount { get; set; }

        // ฝั่งโอนออก (user เลือก)
        public string? BudgetSourceId { get; set; }
        public string? DepartmentId { get; set; }         // null เมื่อ Source=100 (fixed)
        public string? CostCenterId { get; set; }         // null เมื่อ Source=100 (fixed)
        public decimal? Totaltransferamount { get; set; }

        // flag
        public bool IsSource100 { get; set; }             // true = auto-fill จาก Source=100
    }
}
```

### 📄 [สร้างใหม่] `OAGBudget.Models\ViewModel\BudgetAllocateTransferMoreDetailViewModel.cs`

```csharp
using OAGBudget.DAL.Models;

namespace OAGBudget.Models.ViewModel
{
    public class BudgetAllocateTransferMoreDetailViewModel
    {
        public OagwbgVBudgetallocatetransfermore Detail { get; set; } = new();
        public List<OagwbgVBudgetallocatetransfermorecategory> Items { get; set; } = new();
    }
}
```

---

## 16. Service Interface — แก้ไข `BudgetService.cs` (interface region)

เพิ่มต่อจาก BudgetTransfer region (ประมาณบรรทัด 167):

```csharp
#region BudgetAllocateTransferMore
Task<SearchResult<OagwbgVBudgetallocatetransfermore>> GetBudgetAllocateTransferMoreList(SearchBudgetAllocateTransferMoreList data);
Task<BudgetAllocateTransferMoreDetailViewModel> GetBudgetAllocateTransferMoreDetail(int id);
Task<List<OagwbgVBudgetrequest>> GetBudgetRequestMoreForTransfer(int? budgetyear);
Task<List<OagwbgVBudgetgovernment>> GetBudgetGovernmentByRequestId(int requestId);
Task<int> SaveBudgetAllocateTransferMoreDetail(BudgetAllocateTransferMoreDetailModel data);
Task<ApiResultsModel> ConfirmBudgetAllocateTransferMore(int? id);
Task<int> ChangeStatusBudgetAllocateTransferMore(int id, string statusId);
Task<ApiResultsModel> DeleteBudgetAllocateTransferMore(int id);
#endregion
```

---

## 17. Service Methods — แก้ไข `BudgetService.cs`

เพิ่ม region ใหม่ต่อจาก `#endregion` ของ BudgetAllocateTransfer (หลังบรรทัดสุดท้ายของ region นั้น):

```csharp
#region BudgetAllocateTransferMore

public async Task<SearchResult<OagwbgVBudgetallocatetransfermore>> GetBudgetAllocateTransferMoreList(
    SearchBudgetAllocateTransferMoreList data)
{
    try
    {
        var result = new SearchResult<OagwbgVBudgetallocatetransfermore>();
        var query = _context.OagwbgVBudgetallocatetransfermores.AsNoTracking().AsQueryable();

        if (data.Roundno.HasValue && data.Roundno.Value != 0)
            query = query.Where(x => x.Roundno == data.Roundno);

        if (data.TransferDate.HasValue)
        {
            var d = data.TransferDate.Value;
            if (d.Year > 2400) d = d.AddYears(-543);
            query = query.Where(x => x.Transferdate >= d.Date && x.Transferdate < d.Date.AddDays(1));
        }

        if (!string.IsNullOrWhiteSpace(data.Regionid) && data.Regionid != "99")
            query = query.Where(x => x.Regionid == data.Regionid);

        if (data.Budgetyear.HasValue && data.Budgetyear.Value != 0)
            query = query.Where(x => x.Budgetyear == data.Budgetyear);

        if (!string.IsNullOrWhiteSpace(data.Transferorgtype))
            query = query.Where(x => x.Transferorgtype == data.Transferorgtype);

        if (!string.IsNullOrWhiteSpace(data.StatusId))
            query = query.Where(x => x.Transferstatus == data.StatusId);

        result.ItemCount = await query.CountAsync();
        result.ResultData = await query
            .OrderBy(x => x.Roundno).ThenBy(x => x.Transferdate)
            .Skip(data.Skip).Take(data.Take)
            .ToListAsync();

        return result;
    }
    catch (Exception) { throw; }
}

public async Task<BudgetAllocateTransferMoreDetailViewModel> GetBudgetAllocateTransferMoreDetail(int id)
{
    try
    {
        var vm = new BudgetAllocateTransferMoreDetailViewModel();
        vm.Detail = await _context.OagwbgVBudgetallocatetransfermores
            .AsNoTracking().FirstOrDefaultAsync(x => x.Id == id)
            ?? new OagwbgVBudgetallocatetransfermore();
        vm.Items = await _context.OagwbgVBudgetallocatetransfermoreCategories
            .AsNoTracking().Where(x => x.Budgetallocatetransfermoreid == id).ToListAsync();
        return vm;
    }
    catch (Exception) { throw; }
}

public async Task<List<OagwbgVBudgetrequest>> GetBudgetRequestMoreForTransfer(int? budgetyear)
{
    // prerequisite: OAGWBG_V_BUDGETREQUEST ต้องไม่มี IS_APPROVE แล้ว
    var query = _context.OagwbgVBudgetrequests
        .AsNoTracking()
        .Where(x => x.Budgetformtypeid == 3
                 && x.IS_COSTCENTER == 1
                 && x.Statusid == 20101
                 && x.Rn == null);

    if (budgetyear.HasValue && budgetyear.Value != 0)
        query = query.Where(x => x.Budgetyear == budgetyear);

    return await query.OrderBy(x => x.Code).ToListAsync();
}

public async Task<List<OagwbgVBudgetgovernment>> GetBudgetGovernmentByRequestId(int requestId)
{
    // prerequisite: OAGWBG_V_BUDGETGOVERNMENT ต้องมี IS_APPROVE แล้ว
    return await _context.OagwbgVBudgetgovernments
        .AsNoTracking()
        .Where(x => x.Budgetrequestid == requestId
                 && x.Budgetstatus == "C"
                 && x.IS_APPROVE == 1)    // IS_APPROVE เพิ่งถูก expose ใน View (prerequisite)
        .ToListAsync();
}

public async Task<int> SaveBudgetAllocateTransferMoreDetail(BudgetAllocateTransferMoreDetailModel data)
{
    try
    {
        var userInfo = await _auth.ValidateTokenAndGetUserInfo();
        var budgetYear = data.BudgetAllocateTransferMore?.Budgetyear;
        OagwbgBudgetallocatetransfermore header;

        var existing = data.BudgetAllocateTransferMore?.Id > 0
            ? await _context.OagwbgBudgetallocatetransfezmores
                .FirstOrDefaultAsync(x => x.Id == data.BudgetAllocateTransferMore!.Id)
            : null;

        if (existing != null) // UPDATE
        {
            existing.Updateby = userInfo.User.Id;
            existing.Updateon = DateTime.Now;
            existing.Bookno = data.BudgetAllocateTransferMore!.Bookno;
            existing.Bookdate = data.BudgetAllocateTransferMore.Bookdate;
            existing.Bankaccountid = data.BudgetAllocateTransferMore.Bankaccountid;
            existing.Totalreceiveamount = data.BudgetAllocateTransferMore.Totalreceiveamount;
            existing.Transferstatus = data.BudgetAllocateTransferMore.Transferstatus;
            existing.Transferorgtype = data.BudgetAllocateTransferMore.Transferorgtype;
            existing.Transferdate = data.BudgetAllocateTransferMore.Transferdate;
            existing.Regionid = data.BudgetAllocateTransferMore.Regionid;
            existing.Budgetsourceid = data.BudgetAllocateTransferMore.Budgetsourceid;
            header = existing;
        }
        else // INSERT
        {
            var orgType = data.BudgetAllocateTransferMore!.Transferorgtype;
            // TODO: พิจารณาใช้ sequence แยกสำหรับ More หรือใช้ ResolveRoundNoAsync ร่วมกัน
            int nextRound = await ResolveRoundNoAsync(budgetYear, orgType)
                ?? throw new Exception("ไม่สามารถออกเลขโอนได้");

            header = new OagwbgBudgetallocatetransfermore
            {
                Createby = userInfo.User.Id,
                Createon = DateTime.Now,
                Bookno = data.BudgetAllocateTransferMore.Bookno,
                Bookdate = data.BudgetAllocateTransferMore.Bookdate,
                Bankaccountid = data.BudgetAllocateTransferMore.Bankaccountid,
                Roundno = nextRound,
                Running = nextRound % 10000,
                Transferorgtype = orgType,
                Transferdate = data.BudgetAllocateTransferMore.Transferdate,
                Regionid = data.BudgetAllocateTransferMore.Regionid,
                Totalreceiveamount = data.BudgetAllocateTransferMore.Totalreceiveamount,
                Budgetyear = budgetYear,
                Transferstatus = data.BudgetAllocateTransferMore.Transferstatus ?? "80101",
                Budgetsourceid = data.BudgetAllocateTransferMore.Budgetsourceid
            };
            _context.OagwbgBudgetallocatetransfezmores.Add(header);
        }

        await _context.SaveChangesAsync();
        await SaveBudgetAllocateTransferMoreCategory(header, data.CategoryList);
        return header.Id;
    }
    catch (Exception) { throw; }
}

private async Task SaveBudgetAllocateTransferMoreCategory(
    OagwbgBudgetallocatetransfermore header,
    List<OagwbgBudgetallocatetransfermorecategory> categoryList)
{
    var userInfo = await _auth.ValidateTokenAndGetUserInfo();
    var existing = await _context.OagwbgBudgetallocatetransfermoreCategories
        .Where(x => x.Budgetallocatetransfermoreid == header.Id).ToListAsync();

    await CollectionHelper.SaveCollectionAsync(
        source: categoryList ?? new List<OagwbgBudgetallocatetransfermorecategory>(),
        destination: existing,
        matchFunc: (s, d) => s.Id != 0 && s.Id == d.Id,
        addFuncAsync: async (s) =>
        {
            var cleanSource = (s.BudgetSourceId == "null" || string.IsNullOrWhiteSpace(s.BudgetSourceId))
                ? null : s.BudgetSourceId;

            // Source=100: fix dept/costcenter เป็นงบประมาณ
            var dept = cleanSource == "100" ? "2900600000" : s.DepartmentId;
            var costcenter = cleanSource == "100" ? "2906999999" : s.CostCenterId;

            var item = new OagwbgBudgetallocatetransfermorecategory
            {
                Createby = userInfo.User.Id,
                Createon = DateTime.Now,
                Transferstatus = header.Transferstatus,
                Budgetallocatetransfermoreid = header.Id,
                Categoryid = s.Categoryid,
                Productid = s.Productid,
                Activityid = s.Activityid,
                Totalreceiveamount = s.Totalreceiveamount,
                Totalallocateamount = s.Totalallocateamount,
                Budgetplanid = s.Budgetplanid,
                Budgettypeid = s.Budgettypeid,
                Budgetyear = header.Budgetyear,
                SummaryAccountCode = s.SummaryAccountCode,
                BudgetSourceId = cleanSource,
                BudgetCodeId = s.BudgetCodeId,
                Ref = s.Ref,              // ← BudgetGovernment.Id
                DepartmentId = dept,
                CostCenterId = costcenter
            };
            _context.OagwbgBudgetallocatetransfermoreCategories.Add(item);
            await Task.CompletedTask;
        },
        updateFuncAsync: async (s, d) =>
        {
            var cleanSource = (s.BudgetSourceId == "null" || string.IsNullOrWhiteSpace(s.BudgetSourceId))
                ? null : s.BudgetSourceId;
            d.Updateby = userInfo.User.Id;
            d.Updateon = DateTime.Now;
            d.Totalreceiveamount = s.Totalreceiveamount;
            d.Totalallocateamount = s.Totalallocateamount;
            d.BudgetSourceId = cleanSource;
            d.DepartmentId = cleanSource == "100" ? "2900600000" : s.DepartmentId;
            d.CostCenterId = cleanSource == "100" ? "2906999999" : s.CostCenterId;
            d.BudgetCodeId = s.BudgetCodeId;
            await Task.CompletedTask;
        },
        deleteFuncAsync: async (d) =>
        {
            _context.OagwbgBudgetallocatetransfermoreCategories.Remove(d);
            await Task.CompletedTask;
        });

    await _context.SaveChangesAsync();
}

public async Task<ApiResultsModel> ConfirmBudgetAllocateTransferMore(int? id)
{
    try
    {
        var header = await _context.OagwbgBudgetallocatetransfezmores
            .FirstOrDefaultAsync(x => x.Id == id);
        if (header == null)
            return new ApiResultsModel { Success = false, Message = "ไม่พบข้อมูล", Type = "error" };

        var categories = await _context.OagwbgBudgetallocatetransfermoreCategories
            .Where(x => x.Budgetallocatetransfermoreid == id).ToListAsync();
        if (!categories.Any())
            return new ApiResultsModel { Success = false, Message = "ไม่พบรายการโอนออก", Type = "error" };

        var year = categories.First().Budgetyear;
        var categoryIds = categories.Select(x => x.Categoryid).ToList();
        var userInfo = await _auth.ValidateTokenAndGetUserInfo();
        var userId = userInfo?.User?.Id ?? 0;

        // ดึง BudgetReceive ที่เกี่ยวข้อง (ตรงกับ logic เดิมใน ConfirmBudgetAllocateTransfer)
        var budgetReceives = await (
            from br in _context.OagwbgBudgetreceives
            join rp in _context.OagwbgBudgetreceiveperiods on br.Budgetreceiveperiodid equals rp.Id
            join g in _context.OagwbgBudgetgovernments on rp.Budgetgovernmentid equals g.Id
            where categoryIds.Contains(br.Categoryid)
                && br.Budgetyear == year
                && br.Departmentid == "2900600000"
                && br.Costcenterid == "2906999999"
                && g.Budgetstatus == "C"
            select br
        ).ToListAsync();

        var budgetCodeYear = await _context.OagwbgBudgetcodeYears
            .Where(x => x.Budgetyear == year && categoryIds.Contains(x.Categoryid)).ToListAsync();

        categories.Where(x => x.Totalallocateamount == null).ForEach(x => x.Totalallocateamount = 0);

        if (!isConnection)
        {
            header.Transferstatus = "80201";
            categories.ForEach(x => x.Transferstatus = "80201");
            header.Updateby = userId;
            header.Updateon = DateTime.Now;
            await _context.SaveChangesAsync();
            return new ApiResultsModel { Success = true, Message = "บันทึกข้อมูลสำเร็จ", Type = "success" };
        }

        // reuse deduction logic เหมือน ConfirmBudgetAllocateTransfer
        foreach (var category in categories)
        {
            decimal totalAmount = category.Totalallocateamount ?? 0m;

            var query = budgetReceives.Where(x =>
                x.Categoryid == category.Categoryid &&
                x.Productid == category.Productid &&
                x.Activityid == category.Activityid &&
                x.Budgetsourceid == category.BudgetSourceId);

            if (!string.IsNullOrEmpty(category.DepartmentId))
                query = query.Where(x => x.Departmentid == category.DepartmentId);
            if (!string.IsNullOrEmpty(category.CostCenterId))
                query = query.Where(x => x.Costcenterid == category.CostCenterId);

            var receives = query.OrderByDescending(x => x.Totalbalanceamount ?? 0m).ToList();

            var budgetcode = budgetCodeYear.FirstOrDefault(x =>
                x.Categoryid == category.Categoryid &&
                x.Productid.ToString() == category.Productid &&
                x.Activitycodeid.ToString() == category.Activityid)?.Budgetcodeid;

            if (!receives.Any() || budgetcode == null ||
                (!string.IsNullOrEmpty(budgetcode) && budgetcode != category.BudgetCodeId))
            {
                var newReceive = new OagwbgBudgetreceive
                {
                    Departmentid = category.DepartmentId ?? "2900600000",
                    Costcenterid = category.CostCenterId ?? "2906999999",
                    Categoryid = category.Categoryid,
                    Budgetplanid = category.Budgetplanid,
                    Productid = category.Productid,
                    Activityid = category.Activityid,
                    Budgetsourceid = category.BudgetSourceId,
                    Budgetyear = category.Budgetyear,
                    Totalallocateamount = 0m,
                    Totaltransferamount = 0m,
                    Totalreceiveamount = 0m,
                    Totalbalanceamount = 0m,
                    Createby = userId,
                    Createon = DateTime.Now
                };
                _context.OagwbgBudgetreceives.Add(newReceive);
                budgetReceives.Add(newReceive);
                receives = new List<OagwbgBudgetreceive> { newReceive };
            }

            ExecuteBudgetCalculation(receives, totalAmount, userId, isDeduct: true);
        }

        header.Transferstatus = "80201";
        categories.ForEach(x => x.Transferstatus = "80201");
        header.Updateby = userId;
        header.Updateon = DateTime.Now;
        await _context.SaveChangesAsync();

        return new ApiResultsModel { Success = true, Message = "ยืนยันสำเร็จ", Type = "success", Data = header };
    }
    catch (Exception ex)
    {
        return new ApiResultsModel { Success = false, Message = ex.Message, Type = "error" };
    }
}

public async Task<int> ChangeStatusBudgetAllocateTransferMore(int id, string statusId)
{
    var header = await _context.OagwbgBudgetallocatetransfezmores.FirstOrDefaultAsync(x => x.Id == id);
    if (header == null) return 0;
    var userInfo = await _auth.ValidateTokenAndGetUserInfo();
    header.Transferstatus = statusId;
    header.Updateby = userInfo.User.Id;
    header.Updateon = DateTime.Now;
    await _context.SaveChangesAsync();
    return header.Id;
}

public async Task<ApiResultsModel> DeleteBudgetAllocateTransferMore(int id)
{
    try
    {
        var header = await _context.OagwbgBudgetallocatetransfezmores.FirstOrDefaultAsync(x => x.Id == id);
        if (header == null)
            return new ApiResultsModel { Success = false, Message = "ไม่พบข้อมูล", Type = "error" };

        var categories = await _context.OagwbgBudgetallocatetransfermoreCategories
            .Where(x => x.Budgetallocatetransfermoreid == id).ToListAsync();

        _context.OagwbgBudgetallocatetransfermoreCategories.RemoveRange(categories);
        _context.OagwbgBudgetallocatetransfezmores.Remove(header);
        await _context.SaveChangesAsync();

        return new ApiResultsModel { Success = true, Message = "ลบข้อมูลสำเร็จ", Type = "success" };
    }
    catch (Exception ex)
    {
        return new ApiResultsModel { Success = false, Message = ex.Message, Type = "error" };
    }
}

#endregion
```

---

## 18. API Controller — แก้ไข `OAGBudget.API\Controllers\BudgetController.cs`

เพิ่ม region ต่อจาก `#endregion` ของ BudgetAllocateTransfer (หลังบรรทัด 1320):

```csharp
#region BudgetAllocateTransferMore

[HttpGet("GetBudgetAllocateTransferMoreList")]
public async Task<IActionResult> GetBudgetAllocateTransferMoreList(
    [FromQuery] SearchBudgetAllocateTransferMoreList data)
{
    try { return Ok(await _service.GetBudgetAllocateTransferMoreList(data)); }
    catch (Exception ex) { return StatusCode(500, ex.Message); }
}

[HttpGet("GetBudgetAllocateTransferMoreDetail/{id}")]
public async Task<IActionResult> GetBudgetAllocateTransferMoreDetail(int id)
{
    try { return Ok(await _service.GetBudgetAllocateTransferMoreDetail(id)); }
    catch (Exception ex) { return StatusCode(500, ex.Message); }
}

[HttpGet("GetBudgetRequestMoreForTransfer")]
public async Task<IActionResult> GetBudgetRequestMoreForTransfer([FromQuery] int? budgetyear)
{
    try { return Ok(await _service.GetBudgetRequestMoreForTransfer(budgetyear)); }
    catch (Exception ex) { return StatusCode(500, ex.Message); }
}

[HttpGet("GetBudgetGovernmentByRequestId/{requestId}")]
public async Task<IActionResult> GetBudgetGovernmentByRequestId(int requestId)
{
    try { return Ok(await _service.GetBudgetGovernmentByRequestId(requestId)); }
    catch (Exception ex) { return StatusCode(500, ex.Message); }
}

[HttpPost("SaveBudgetAllocateTransferMoreDetail")]
public async Task<IActionResult> SaveBudgetAllocateTransferMoreDetail(
    [FromBody] BudgetAllocateTransferMoreDetailModel data)
{
    try { return Ok(await _service.SaveBudgetAllocateTransferMoreDetail(data)); }
    catch (Exception ex) { return StatusCode(500, ex.Message); }
}

[HttpPost("ConfirmBudgetAllocateTransferMore")]
public async Task<IActionResult> ConfirmBudgetAllocateTransferMore([FromBody] int? id)
{
    try { return Ok(await _service.ConfirmBudgetAllocateTransferMore(id)); }
    catch (Exception ex) { return StatusCode(500, ex.Message); }
}

[HttpGet("CancelBudgetAllocateTransferMore")]
public async Task<IActionResult> CancelBudgetAllocateTransferMore(int id)
{
    try { return Ok(await _service.ChangeStatusBudgetAllocateTransferMore(id, "90109")); }
    catch (Exception ex) { return StatusCode(500, ex.Message); }
}

[HttpDelete("DeleteBudgetAllocateTransferMore/{id}")]
public async Task<IActionResult> DeleteBudgetAllocateTransferMore(int id)
{
    try { return Ok(await _service.DeleteBudgetAllocateTransferMore(id)); }
    catch (Exception ex) { return StatusCode(500, ex.Message); }
}

#endregion
```

---

## 19. MVC Controller — แก้ไข `OAGBudget\Controllers\BudgetController.cs`

เพิ่ม region ต่อจาก `#endregion` ของ BudgetAllocateTransfer (หลังบรรทัด 3674):

```csharp
#region BudgetAllocateTransferMore

public async Task<IActionResult> BudgetAllocateTransferMoreList()
{
    ViewBag.DropdownRegion = await _dropdowns.DropdownRegion();
    var statusList = await _dropdowns.DropdownMasterStatus();
    string[] allowedStatus = { "80101", "80201" };
    ViewBag.DropdownStatus = statusList.Where(x => allowedStatus.Contains(x.Value)).OrderBy(x => x.Value);
    return View();
}

[HttpPost]
public async Task<IActionResult> SearchBudgetAllocateTransferMoreList(
    SearchBudgetAllocateTransferMoreList filter)
{
    try
    {
        var data = await _budgetService.GetBudgetAllocateTransferMoreList(filter);
        if (data != null)
        {
            return Json(new
            {
                draw = Request.Form["draw"],
                recordsTotal = data.ItemCount,
                recordsFiltered = data.ItemCount,
                data = data.ResultData
            });
        }
        return Json(new { success = false, message = "ไม่พบข้อมูล" });
    }
    catch (Exception ex)
    {
        return Json(new { success = false, message = ex.Message });
    }
}

public async Task<IActionResult> BudgetAllocateTransferMoreDetail(int? id)
{
    ViewBag.DropdownRegion = await _dropdowns.DropdownRegion() ?? new List<SelectListItem>();
    ViewBag.DropdownPlan = await _dropdowns.DropdownBudgetPlanCode();
    ViewBag.DropdownProduct = await _dropdowns.DropdownBudgetProduct();
    ViewBag.DropdownActivity = await _dropdowns.DropdownBudgetActivity();
    ViewBag.DropdownCategoryAll = await _dropdowns.DropdownCategory();
    ViewBag.DropdownBudgetCode = await _dropdowns.DropdownBudgetCode();

    var budgetSourceDropdown = await _dropdowns.DropdownBudgetSource();
    var allowBudgetSourceIds = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "100", "200", "300", "400" };
    ViewBag.DropdownBudgetSource = budgetSourceDropdown
        .Where(x => !string.IsNullOrEmpty(x.Value) && allowBudgetSourceIds.Contains(x.Value))
        .ToList();

    var bankDropdown = await _dropdowns.DropdownBankAccountList();
    ViewBag.DropdownBankAccount = bankDropdown
        .Where(x => string.Equals(x.S11Attribute8, "YES", StringComparison.OrdinalIgnoreCase))
        .ToList();

    var data = new BudgetAllocateTransferMoreDetailViewModel();
    if (id != null)
        data = await _budgetService.GetBudgetAllocateTransferMoreDetail(id.Value);
    else
        data.Detail = new OagwbgVBudgetallocatetransfermore();

    return View(data);
}

public async Task<IActionResult> SaveBudgetAllocateTransferMoreDetail(
    [FromBody] BudgetAllocateTransferMoreDetailModel model)
{
    try
    {
        var id = await _budgetService.SaveBudgetAllocateTransferMoreDetail(model);
        return Json(new { success = true, data = id });
    }
    catch (Exception ex)
    {
        return Json(new { success = false, message = ex.Message });
    }
}

public async Task<IActionResult> ConfirmBudgetAllocateTransferMore(int id)
{
    var result = await _budgetService.ConfirmBudgetAllocateTransferMore(id);
    return Ok(result);
}

public async Task<IActionResult> CancelBudgetAllocateTransferMore(int id)
{
    var result = await _budgetService.ChangeStatusBudgetAllocateTransferMore(id, "90109");
    return Ok(result);
}

public async Task<IActionResult> DeleteBudgetAllocateTransferMore(int id)
{
    var result = await _budgetService.DeleteBudgetAllocateTransferMore(id);
    return Ok(result);
}

#endregion
```

---

## 20. Razor Views — ไฟล์ใหม่

### 📄 [สร้างใหม่] `OAGBudget\Views\Budget\BudgetAllocateTransferMoreList.cshtml`

> Copy จาก `BudgetAllocateTransferList.cshtml` แล้วเปลี่ยน:
> - URL ทุก action → `BudgetAllocateTransferMore`
> - Title → "โอนจัดสรรเพิ่มเติม"
> - Column ตาราง DataTable เหมือนเดิม

```html
@{
    ViewData["Title"] = "โอนจัดสรรเพิ่มเติม";
    Layout = "~/Views/Shared/_Layout.cshtml";
}

<div class="content-header">
    <h1>โอนจัดสรรเพิ่มเติม</h1>
</div>

<section class="content">
    <div class="card">
        <div class="card-body">
            @* Filter form — เหมือน BudgetAllocateTransferList *@
            <form id="searchForm">
                <div class="row">
                    <div class="col-md-3">
                        <label>ครั้งที่</label>
                        <input type="number" id="Roundno" name="Roundno" class="form-control" />
                    </div>
                    <div class="col-md-3">
                        <label>วันที่โอน</label>
                        <input type="text" id="TransferDate" name="TransferDate" class="form-control datepicker" />
                    </div>
                    <div class="col-md-3">
                        <label>ภาค</label>
                        <select id="Regionid" name="Regionid" class="form-control select2">
                            <option value="">-- ทั้งหมด --</option>
                            @foreach (var item in ViewBag.DropdownRegion as IEnumerable<SelectListItem> ?? new List<SelectListItem>())
                            {
                                <option value="@item.Value">@item.Text</option>
                            }
                        </select>
                    </div>
                    <div class="col-md-3">
                        <label>สถานะ</label>
                        <select id="StatusId" name="StatusId" class="form-control select2">
                            <option value="">-- ทั้งหมด --</option>
                            @foreach (var item in ViewBag.DropdownStatus as IEnumerable<SelectListItem> ?? new List<SelectListItem>())
                            {
                                <option value="@item.Value">@item.Text</option>
                            }
                        </select>
                    </div>
                </div>
                <div class="row mt-2">
                    <div class="col-md-12 text-right">
                        <button type="button" id="btnSearch" class="btn btn-primary">ค้นหา</button>
                        <a href="@Url.Action("BudgetAllocateTransferMoreDetail","Budget")" class="btn btn-success">+ สร้างใหม่</a>
                    </div>
                </div>
            </form>
        </div>
    </div>

    <div class="card mt-2">
        <div class="card-body">
            <table id="dataTable" class="table table-bordered table-striped" style="width:100%">
                <thead>
                    <tr>
                        <th>ครั้งที่</th>
                        <th>วันที่โอน</th>
                        <th>ภาค</th>
                        <th>ปีงบประมาณ</th>
                        <th>ยอดรวม</th>
                        <th>สถานะ</th>
                        <th>จัดการ</th>
                    </tr>
                </thead>
                <tbody></tbody>
            </table>
        </div>
    </div>
</section>

@section Scripts {
<script>
    var table = $('#dataTable').DataTable({
        processing: true, serverSide: false,
        ajax: {
            url: '@Url.Action("SearchBudgetAllocateTransferMoreList","Budget")',
            type: 'POST',
            data: function (d) {
                return $.extend({}, d, {
                    Roundno: $('#Roundno').val(),
                    TransferDate: $('#TransferDate').val(),
                    Regionid: $('#Regionid').val(),
                    StatusId: $('#StatusId').val()
                });
            }
        },
        columns: [
            { data: 'roundno' },
            { data: 'transferdate', render: function(d){ return d ? new Date(d).toLocaleDateString('th-TH') : ''; } },
            { data: 'regionid' },
            { data: 'budgetyear' },
            { data: 'totalreceiveamount', render: $.fn.dataTable.render.number(',', '.', 2) },
            { data: 'transferstatusname' },
            {
                data: 'id',
                render: function (id, type, row) {
                    var btns = '<a href="@Url.Action("BudgetAllocateTransferMoreDetail","Budget")/' + id + '" class="btn btn-xs btn-info">แก้ไข</a> ';
                    if (row.transferstatus === '80101') {
                        btns += '<button onclick="deleteRow(' + id + ')" class="btn btn-xs btn-danger">ลบ</button>';
                    }
                    return btns;
                }
            }
        ]
    });

    $('#btnSearch').click(function () { table.ajax.reload(); });

    function deleteRow(id) {
        if (!confirm('ยืนยันการลบ?')) return;
        $.ajax({
            url: '@Url.Action("DeleteBudgetAllocateTransferMore","Budget")/' + id,
            type: 'GET',
            success: function () { table.ajax.reload(); }
        });
    }
</script>
}
```

### 📄 [สร้างใหม่] `OAGBudget\Views\Budget\BudgetAllocateTransferMoreDetail.cshtml`

> โครงสร้างหลัก — ส่วน Header copy จาก `BudgetAllocateTransferDetail.cshtml`

```html
@model OAGBudget.Models.ViewModel.BudgetAllocateTransferMoreDetailViewModel
@{
    ViewData["Title"] = "โอนจัดสรรเพิ่มเติม (รายละเอียด)";
    Layout = "~/Views/Shared/_Layout.cshtml";
    bool isNew = Model.Detail.Id == 0;
    bool isConfirmed = Model.Detail.Transferstatus == "80201";
}

<div class="content-header">
    <h1>@(isNew ? "สร้างใบโอนจัดสรรเพิ่มเติม" : $"ใบโอนจัดสรรเพิ่มเติม ครั้งที่ {Model.Detail.Roundno}")</h1>
</div>

<section class="content">
    @* ─── Header ─── *@
    <div class="card">
        <div class="card-body">
            <div class="row">
                <div class="col-md-3">
                    <label>วันที่โอน</label>
                    <input type="text" id="TransferDate" class="form-control datepicker"
                           value="@Model.Detail.Transferdate?.ToString("dd/MM/yyyy")"
                           @(isConfirmed ? "disabled" : "") />
                </div>
                <div class="col-md-3">
                    <label>ภาค</label>
                    <select id="Regionid" class="form-control select2" @(isConfirmed ? "disabled" : "")>
                        @foreach (var item in ViewBag.DropdownRegion as IEnumerable<SelectListItem> ?? new List<SelectListItem>())
                        {
                            <option value="@item.Value" @(item.Value == Model.Detail.Regionid ? "selected" : "")>@item.Text</option>
                        }
                    </select>
                </div>
                <div class="col-md-2">
                    <label>ปีงบประมาณ</label>
                    <input type="number" id="Budgetyear" class="form-control"
                           value="@Model.Detail.Budgetyear" @(isConfirmed ? "disabled" : "") />
                </div>
                <div class="col-md-2">
                    <label>ประเภท</label>
                    <select id="Transferorgtype" class="form-control" @(isConfirmed ? "disabled" : "")>
                        <option value="1" @(Model.Detail.Transferorgtype == "1" ? "selected":"")>สบง.</option>
                        <option value="2" @(Model.Detail.Transferorgtype == "2" ? "selected":"")>สบอ.</option>
                    </select>
                </div>
                <div class="col-md-2">
                    <label>สถานะ</label>
                    <input type="text" class="form-control" value="@Model.Detail.Transferstatusname" disabled />
                </div>
            </div>
        </div>
    </div>

    @* ─── ปุ่มเพิ่มจากคำขอ ─── *@
    @if (!isConfirmed)
    {
        <div class="mb-2">
            <button type="button" id="btnAddRequest" class="btn btn-primary">+ เพิ่มจากคำขอ</button>
        </div>
    }

    @* ─── ตารางรายการ ─── *@
    <div class="card">
        <div class="card-body">
            <table id="tblItems" class="table table-bordered table-sm">
                <thead>
                    <tr>
                        <th>คำขอ</th>
                        <th>แผนงาน</th>
                        <th>ผลผลิต</th>
                        <th>กิจกรรม</th>
                        <th>รายการ</th>
                        <th>รหัสงบ</th>
                        <th>ยอดที่ขอ</th>
                        <th>แหล่งเงินโอนออก</th>
                        <th>ยอดโอน</th>
                        @if (!isConfirmed) { <th>จัดการ</th> }
                    </tr>
                </thead>
                <tbody id="itemBody">
                    @* โหลดผ่าน JS จาก Model.Items *@
                </tbody>
            </table>
        </div>
    </div>

    @* ─── ปุ่ม Action ─── *@
    <div class="mt-2">
        @if (!isConfirmed)
        {
            <button id="btnSave" class="btn btn-success">บันทึก</button>
        }
        @if (!isNew && Model.Detail.Transferstatus == "80101")
        {
            <button id="btnConfirm" class="btn btn-warning">ยืนยัน</button>
        }
        <a href="@Url.Action("BudgetAllocateTransferMoreList","Budget")" class="btn btn-secondary">กลับ</a>
    </div>
</section>

@* ─── Modal เลือกคำขอ ─── *@
<div class="modal fade" id="modalSelectRequest" tabindex="-1">
    <div class="modal-dialog modal-xl">
        <div class="modal-content">
            <div class="modal-header"><h5>เลือกคำขอรับจัดสรรเพิ่มเติม</h5></div>
            <div class="modal-body">
                <div class="row mb-2">
                    <div class="col-md-3">
                        <input type="number" id="filterBudgetyear" class="form-control" placeholder="ปีงบประมาณ" />
                    </div>
                    <div class="col-md-2">
                        <button id="btnSearchRequest" class="btn btn-primary">ค้นหา</button>
                    </div>
                </div>
                <table id="tblRequests" class="table table-bordered table-sm">
                    <thead>
                        <tr>
                            <th>เลขที่คำขอ</th>
                            <th>หน่วยเบิกจ่าย</th>
                            <th>ศูนย์ต้นทุน</th>
                            <th>ปีงบประมาณ</th>
                            <th>ยอดรวม</th>
                            <th></th>
                        </tr>
                    </thead>
                    <tbody id="requestBody"></tbody>
                </table>
            </div>
        </div>
    </div>
</div>

@* ─── Modal ระบุโอนออก ─── *@
<div class="modal fade" id="modalTransferOut" tabindex="-1">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header"><h5>ระบุแหล่งเงินโอนออก</h5></div>
            <div class="modal-body">
                <input type="hidden" id="currentItemIndex" />
                <div class="mb-2">
                    <label>แหล่งเงิน</label>
                    <select id="selSource" class="form-control select2">
                        @foreach (var item in ViewBag.DropdownBudgetSource as IEnumerable<SelectListItem> ?? new List<SelectListItem>())
                        {
                            <option value="@item.Value">@item.Text</option>
                        }
                    </select>
                </div>
                <div id="divOtherSource">
                    @* แสดงเฉพาะเมื่อ Source != 100 *@
                    <div class="mb-2">
                        <label>หน่วยเบิกจ่าย</label>
                        <input type="text" id="txtDept" class="form-control" />
                    </div>
                    <div class="mb-2">
                        <label>ศูนย์ต้นทุน</label>
                        <input type="text" id="txtCostCenter" class="form-control" />
                    </div>
                </div>
                <div class="mb-2">
                    <label>ยอดโอน (บาท)</label>
                    <input type="number" id="txtTransferAmount" class="form-control" />
                </div>
            </div>
            <div class="modal-footer">
                <button id="btnConfirmTransferOut" class="btn btn-primary">ตกลง</button>
                <button type="button" class="btn btn-secondary" data-dismiss="modal">ยกเลิก</button>
            </div>
        </div>
    </div>
</div>

@section Scripts {
<script>
    var itemList = @Html.Raw(Newtonsoft.Json.JsonConvert.SerializeObject(Model.Items));

    // แสดงรายการที่มีอยู่แล้ว
    renderItems();

    // ─── Modal เลือกคำขอ ───
    $('#btnAddRequest').click(function () {
        loadRequests();
        $('#modalSelectRequest').modal('show');
    });

    $('#btnSearchRequest').click(function () { loadRequests(); });

    function loadRequests() {
        var year = $('#filterBudgetyear').val() || $('#Budgetyear').val();
        $.get('@Url.Action("GetBudgetRequestMoreForTransfer","Budget")', { budgetyear: year }, function (data) {
            // TODO: wire through MVC → API proxy action
            var html = '';
            $.each(data, function (i, r) {
                html += '<tr><td>' + (r.code||'') + '</td><td>' + (r.departmentid||'') + '</td>' +
                        '<td>' + (r.costcenterid||'') + '</td><td>' + (r.budgetyear||'') + '</td>' +
                        '<td>' + (r.totalrequestamount||0).toLocaleString() + '</td>' +
                        '<td><button class="btn btn-xs btn-success" onclick="selectRequest(' + r.id + ')">เลือก</button></td></tr>';
            });
            $('#requestBody').html(html);
        });
    }

    function selectRequest(requestId) {
        $.get('@Url.Action("GetBudgetGovernmentByRequestId","Budget")/' + requestId, function (items) {
            // TODO: wire through MVC → API proxy action
            $.each(items, function (i, item) {
                itemList.push({
                    ref: item.id,
                    budgetrequestid: requestId,
                    categoryid: item.categoryid,
                    budgetplanid: item.budgetplanid ? item.budgetplanid.toString() : null,
                    productid: item.productid ? item.productid.toString() : null,
                    activityid: item.activitycodeid ? item.activitycodeid.toString() : null,
                    budgetcode: item.budgetcode,
                    totalrequestamount: item.totalrequestamount,
                    categoryname: item.categoryname || '',
                    // ฝั่งโอนออก — รอ user เลือก
                    budgetsourceid: null, departmentid: null, costcenterid: null, totaltransferamount: null
                });
            });
            renderItems();
        });
        $('#modalSelectRequest').modal('hide');
    }

    // ─── Modal โอนออก ───
    function openTransferOut(idx) {
        $('#currentItemIndex').val(idx);
        var item = itemList[idx];
        $('#selSource').val(item.budgetsourceid || '100').trigger('change');
        $('#txtTransferAmount').val(item.totaltransferamount || item.totalrequestamount);
        $('#modalTransferOut').modal('show');
    }

    $('#selSource').change(function () {
        if ($(this).val() === '100') {
            $('#divOtherSource').hide();
        } else {
            $('#divOtherSource').show();
            var idx = $('#currentItemIndex').val();
            var item = itemList[idx];
            $('#txtDept').val(item.departmentid || '');
            $('#txtCostCenter').val(item.costcenterid || '');
        }
    });

    $('#btnConfirmTransferOut').click(function () {
        var idx = parseInt($('#currentItemIndex').val());
        var source = $('#selSource').val();
        itemList[idx].budgetsourceid = source;
        itemList[idx].totaltransferamount = parseFloat($('#txtTransferAmount').val()) || 0;
        if (source === '100') {
            itemList[idx].departmentid = '2900600000';
            itemList[idx].costcenterid = '2906999999';
        } else {
            itemList[idx].departmentid = $('#txtDept').val();
            itemList[idx].costcenterid = $('#txtCostCenter').val();
        }
        renderItems();
        $('#modalTransferOut').modal('hide');
    });

    function renderItems() {
        var html = '';
        $.each(itemList, function (i, item) {
            var sourceLabel = item.budgetsourceid
                ? (item.budgetsourceid === '100' ? '100 (งบประมาณ)' : item.budgetsourceid + ' (' + (item.departmentid||'') + ')')
                : '<span class="text-danger">ยังไม่ระบุ</span>';
            html += '<tr>' +
                '<td>' + (item.budgetrequestid||'') + '</td>' +
                '<td>' + (item.budgetplanid||'') + '</td>' +
                '<td>' + (item.productid||'') + '</td>' +
                '<td>' + (item.activityid||'') + '</td>' +
                '<td>' + (item.categoryname||'') + '</td>' +
                '<td>' + (item.budgetcode||'') + '</td>' +
                '<td class="text-right">' + (item.totalrequestamount||0).toLocaleString('th', {minimumFractionDigits:2}) + '</td>' +
                '<td>' + sourceLabel + '</td>' +
                '<td class="text-right">' + (item.totaltransferamount||0).toLocaleString('th', {minimumFractionDigits:2}) + '</td>' +
                '<td><button class="btn btn-xs btn-info" onclick="openTransferOut(' + i + ')">ระบุโอนออก</button> ' +
                '<button class="btn btn-xs btn-danger" onclick="removeItem(' + i + ')">ลบ</button></td>' +
                '</tr>';
        });
        $('#itemBody').html(html);
    }

    function removeItem(idx) { itemList.splice(idx, 1); renderItems(); }

    // ─── Save ───
    $('#btnSave').click(function () {
        var payload = {
            BudgetAllocateTransferMore: {
                Id: @Model.Detail.Id,
                Bookno: null,
                Transferdate: $('#TransferDate').val(),
                Regionid: $('#Regionid').val(),
                Budgetyear: parseInt($('#Budgetyear').val()),
                Transferorgtype: $('#Transferorgtype').val(),
                Transferstatus: '80101',
                Budgetsourceid: null,
                Totalreceiveamount: itemList.reduce(function(s,x){ return s + (x.totaltransferamount||0); }, 0)
            },
            CategoryList: itemList.map(function(x) {
                return {
                    Id: 0,
                    Ref: x.ref,
                    Categoryid: x.categoryid,
                    Budgetplanid: x.budgetplanid,
                    Productid: x.productid,
                    Activityid: x.activityid,
                    BudgetCodeId: x.budgetcode,
                    BudgetSourceId: x.budgetsourceid,
                    DepartmentId: x.departmentid,
                    CostCenterId: x.costcenterid,
                    Totaltransferamount: x.totaltransferamount,
                    Totalallocateamount: x.totaltransferamount
                };
            })
        };
        $.ajax({
            url: '@Url.Action("SaveBudgetAllocateTransferMoreDetail","Budget")',
            type: 'POST', contentType: 'application/json',
            data: JSON.stringify(payload),
            success: function (res) {
                if (res.success) {
                    alert('บันทึกสำเร็จ');
                    window.location.href = '@Url.Action("BudgetAllocateTransferMoreDetail","Budget")/' + res.data;
                } else {
                    alert('เกิดข้อผิดพลาด: ' + res.message);
                }
            }
        });
    });

    // ─── Confirm ───
    $('#btnConfirm').click(function () {
        if (!confirm('ยืนยันการโอนจัดสรรเพิ่มเติม?')) return;
        $.ajax({
            url: '@Url.Action("ConfirmBudgetAllocateTransferMore","Budget")/@Model.Detail.Id',
            type: 'POST',
            success: function (res) {
                alert(res.success ? 'ยืนยันสำเร็จ' : 'เกิดข้อผิดพลาด: ' + res.message);
                if (res.success) location.reload();
            }
        });
    });
</script>
}
```
