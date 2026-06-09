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
- บันทึกลง `OAGWBG_BUDGETALLOCATETRANSFER_CATEGORY`
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
| 10.2 | เงื่อนไข filter รายการใน OAGWBG_BUDGETGOVERNMENT | ✅ | **`BudgetStatus = "C" AND IS_APPROVE = 1`** — `IS_APPROVE` อยู่ใน OAGWBG_BUDGETREQUEST (Header, ไม่ใช่ Line item) ต้อง JOIN กับ BUDGETREQUEST และใช้ตารางโดยตรง (ไม่ใช่ View เพราะ View ไม่มี IS_APPROVE) |
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

### Phase 0 — Prerequisite (ทำก่อน — ไม่ใช่งานของ Feature นี้)
> งานนี้จะดำเนินการก่อน BudgetAllocateTransferMore ทั้งหมดอยู่แล้ว
1. เพิ่ม `IS_APPROVE` column ใน `OAGWBG_BUDGETGOVERNMENT` (item-level approval)
2. อัปเดต View `OAGWBG_V_BUDGETGOVERNMENT` ให้ expose `IS_APPROVE`
3. นำ `IS_APPROVE` ออกจาก `OAGWBG_BUDGETREQUEST` (Header)
4. อัปเดต `OagwbgBudgetrequest.cs` และ `OagwbgVBudgetrequest.cs` ให้ตรงกัน

### Phase 1 — DB + DAL
1. รัน DDL สร้างตารางใหม่:
   - `OAGWBG_BUDGETALLOCATETRANSFERMORE` + Sequence
   - `OAGWBG_BUDGETALLOCATETRANSFERMORE_CATEGORY` + Sequence
2. สร้าง Oracle Views:
   - `OAGWBG_V_BUDGETALLOCATETRANSFERMORE`
   - `OAGWBG_V_BUDGETALLOCATETRANSFERMORE_CATEGORY`
3. สร้าง DAL C# Models:
   - `OagwbgBudgetallocatetransfermore.cs`
   - `OagwbgBudgetallocatetransfermorecategory.cs`
   - `OagwbgVBudgetallocatetransfermore.cs`
   - `OagwbgVBudgetallocatetransfermorecategory.cs`
4. Register Models ใน `OagwbgContext.cs`

### Phase 2 — Backend Service + API
> ⚠️ ต้อง Phase 0 เสร็จก่อน (เพื่อให้ `OAGWBG_V_BUDGETGOVERNMENT.IS_APPROVE` ใช้ได้)
1. `GetBudgetRequestMoreForTransfer()` — Query คำขอสถานะ 20101
2. `GetBudgetGovernmentByRequestId()` — Query `OAGWBG_V_BUDGETGOVERNMENT` WHERE BudgetStatus="C" AND IS_APPROVE=1
3. Extract private method จาก `ConfirmBudgetAllocateTransfer` (line 15391)
4. `SaveBudgetAllocateTransferMoreDetail()` — Header + Category + BudgetReceive
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
