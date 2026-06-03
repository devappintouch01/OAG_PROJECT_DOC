# Roadmap: การปรับกระบวนการโอนจัดสรร (Budget Allocate Transfer) จากใบขอรับจัดสรรเพิ่มเติม
**Version:** 0.1  
**วันที่:** 2026-06-03  
**สถานะ:** วิเคราะห์เบื้องต้น — รอข้อมูลเพิ่มเติมจาก User/PO

---

## 1. สรุปความต้องการ (Requirement Summary)

เดิมการสร้างใบโอนจัดสรร ผู้ใช้ต้องเลือกรายการและศูนย์ต้นทุนเอง  
ต้องการปรับให้ **ดึงชุดรายการจากใบขอรับจัดสรรเพิ่มเติม** มาใช้เป็นรายการรับโอนโดยตรง พร้อม default ยอดจากที่ขอ และให้โอนจากแหล่งเงินใดก็ได้ลงไปที่รายการตามคำขอ

---

## 2. โครงสร้างข้อมูลที่เกี่ยวข้อง (Data Structure Analysis)

### 2.1 ตารางหลักที่ใช้งาน

| ตาราง | วัตถุประสงค์ | C# Model |
|---|---|---|
| `OAGWBG_BUDGETALLOCATETRANSFER` | ใบโอนจัดสรร (header) | `OagwbgBudgetallocatetransfer` |
| `OAGWBG_BUDGETALLOCATETRANSFER_CATEGORY` | รายการในใบโอน | `OagwbgBudgetallocatetransferCategory` |
| `OAGWBG_BUDGETALLOCATETRANSFER_COSTCENTER` | ศูนย์ต้นทุนในใบโอน | `OagwbgBudgetallocatetransferCostcenter` |
| `OAGWBG_BUDGETRECEIVE` | ยอดจัดสรรที่หน่วยงานได้รับ (ทั้งต้นทางและปลายทาง) | `OagwbgBudgetreceive` |
| `OAGWBG_BUDGETREQUEST` | ใบคำขอ (header) | `OagwbgBudgetrequest` |
| `OAGWBG_BUDGETGOVERNMENT` | รายการในใบคำขอ | `OagwbgBudgetgovernment` |

### 2.2 Mapping รายการคำขอ → รายการในใบโอน

```
OagwbgBudgetgovernment (รายการคำขอ)          → OagwbgBudgetallocatetransferCategory
─────────────────────────────────────────────────────────────────────────────────
.Id                                           → .Ref  (field มีอยู่แล้ว — อ้างอิงต้นทาง)
.Categoryid                                   → .Categoryid
.Budgetplanid (int)                           → .Budgetplanid (string — ต้องตรวจ type)
.Budgettypeid (int)                           → .Budgettypeid (string — ต้องตรวจ type)
.Productid (long)                             → .Productid (string — ต้องตรวจ type)
.Activitycodeid (long)                        → .Activityid (string — ต้องตรวจ type)
.Budgetcode                                   → .BudgetCodeId
.Totalrequestamount                           → .Totalreceiveamount (default, แก้ไขได้)
แหล่งเงินที่ user ระบุ (ฝั่งโอนออก)                  → .BudgetSourceId
```

```
OagwbgBudgetrequest (header คำขอ)            → OagwbgBudgetallocatetransfer
─────────────────────────────────────────────────────────────────────────────────
.Departmentid                                 → .Bankaccountid (หน่วยเบิกจ่ายผู้รับ)
.Budgetyear                                   → .Budgetyear
.Id                                           → .Budgetrequestid (⚠️ ต้องเพิ่ม column ใหม่ใน DB)
```

### 2.3 Field ที่ต้องเพิ่มใน Database

| ตาราง | Column ใหม่ | ประเภท | วัตถุประสงค์ |
|---|---|---|---|
| `OAGWBG_BUDGETALLOCATETRANSFER` | `BUDGETREQUESTID` | NUMBER | FK → `OAGWBG_BUDGETREQUEST.ID` |

> **หมายเหตุ:** `OagwbgBudgetallocatetransferCategory.Ref` มีอยู่แล้ว — ใช้ผูก `BudgetGovernment.Id` ได้เลยโดยไม่ต้องเพิ่ม column

---

## 3. คำถามที่ต้องชี้แจงกับ User / Project Owner ก่อนพัฒนา

> ❗ **ยังไม่ดำเนินการพัฒนาใด ๆ จนกว่าจะได้คำตอบชัดเจน**

### คำถามที่ 1 — แหล่งเงินและรายการต้นทาง (ฝั่งโอนออก)

ระบบต้องตัดยอดออกจาก `BudgetReceive` ของฝั่งโอน (สบง./ส่วนกลาง) ซึ่งต้องการทราบว่า:

**Option A (Possible 2 ในเอกสารคำขอ):** User ระบุเพียง **แหล่งเงิน** เดียว  
- ระบบจะประกอบชุดบัญชีจากรายการคำขอ (Categoryid, Productid, Activityid, Budgetplanid) + แหล่งเงินที่ระบุ  
- ค้นหา BudgetReceive ที่ตรงกัน — ถ้าไม่เจอ สร้าง record ใหม่ด้วยยอด 0  
- **ข้อจำกัด:** รายการในคำขออาจมีหลาย Category แต่ต้นทางเป็นแหล่งเงินเดียว → ต้องมี BudgetReceive ต้นทางหลาย record (ตาม Category)

**Option B (Possible 3 ในเอกสารคำขอ):** User เลือก **ชุดบัญชีชุดเดียว** (BudgetReceive record เดียว) + แหล่งเงิน  
- ตัดยอดรวมทั้งหมดจาก record เดียว แล้วกระจายไปหลายรายการรับโอน  
- **ข้อจำกัด:** record เดียวต้องรองรับยอดของทุก Category ในคำขอ

**คำถาม:** ต้องการใช้ Option ใด หรือต้องการให้ระบุ BudgetReceive ต้นทางแยกตามแต่ละรายการในคำขอ?

---

### คำถามที่ 2 — ศูนย์ต้นทุนของผู้รับโอน

`OagwbgBudgetrequest` มี field `Costcenterid` อยู่แล้ว (ศูนย์ต้นทุนของผู้ขอ)

**Option A:** ใช้ `BudgetRequest.Costcenterid` เป็น default โดยไม่ต้องให้ user เลือก  
**Option B:** ให้ user ระบุศูนย์ต้นทุนเองในหน้า modal  
**Option C:** แต่ละรายการในคำขออาจมีศูนย์ต้นทุนแตกต่างกัน → ต้องให้ระบุรายการต่อรายการ

**คำถาม:** ต้องการ Option ใด?

---

### คำถามที่ 3 — แหล่งเงินของรายการรับโอน (ฝั่งปลายทาง)

คำขอ (`OagwbgBudgetrequest.Budgetsourceid`) มี field แหล่งเงินอยู่แล้ว  
แต่ใน `OagwbgBudgetgovernment` (รายการ) ยังไม่พบ field Budgetsourceid โดยตรง  

**คำถาม:** แหล่งเงินของ BudgetReceive ปลายทาง (ผู้รับโอน) จะใช้จากคำขอ หรือต้องการระบุใหม่ตอนสร้างใบโอน?

---

### คำถามที่ 4 — สถานะใบคำขอที่สามารถนำมาโอนได้

**คำถาม:** ใบคำขอต้องผ่านสถานะ "อนุมัติ" (IsApprove = 1) ก่อนถึงจะนำมาสร้างใบโอนได้ หรือสามารถใช้ได้ทุกสถานะ?

---

### คำถามที่ 5 — ความสัมพันธ์ใบโอน : ใบคำขอ

Prompt ระบุ "ทำแยกเป็นใบคำขอ"  

**คำถาม:**  
- 1 ใบโอน = รองรับได้ 1 คำขอเท่านั้น?  
- หรือ 1 ใบโอน สามารถดึงจากหลายคำขอได้ (แต่แสดงแยกกัน)?

---

## 4. กระบวนการทำงานที่วิเคราะห์ไว้ (เงื่อนไขตามคำตอบของ User)

### 4.1 Flow หลัก (สมมุติ Option A + ศูนย์ต้นทุนจากคำขอ)

```
[หน้าโอนจัดสรร]
    │
    ▼
[กดปุ่ม "สร้างจากคำขอ"]
    │
    ▼
[Modal: เลือกเลขที่คำขอ (BudgetRequest.Code)]
    │   - Filter: เฉพาะที่อนุมัติแล้ว, ปีงบประมาณตรงกัน
    │   - แสดง: หน่วยงาน, ศูนย์ต้นทุน, ยอดรวมที่ขอ
    │
    ▼
[แสดงรายการทั้งหมดในคำขอ (BudgetGovernment)]
    │   - แสดง: แผนงาน, ผลผลิต, กิจกรรม, รายการ, รหัสงบ, ยอดที่ขอ
    │   - Input: ยอดที่จะโอน (default = ยอดที่ขอ)
    │
    ▼
[เลือกแหล่งเงินที่จะโอนออก (BudgetSource)]
    │   - Dropdown แหล่งเงินที่มีใน BudgetReceive ของต้นทาง
    │
    ▼
[กด "บันทึก"]
    │
    ▼
[Backend Logic]
    ├─ สร้าง OagwbgBudgetallocatetransfer (header)
    │     Budgetrequestid = คำขอที่เลือก
    │     Bankaccountid = BudgetRequest.Departmentid
    │     Budgetsourceid = แหล่งเงินที่เลือก
    │
    ├─ สำหรับแต่ละ BudgetGovernment ในคำขอ:
    │     สร้าง OagwbgBudgetallocatetransferCategory
    │       Ref = BudgetGovernment.Id
    │       BudgetSourceId = แหล่งเงินโอนออก
    │
    ├─ หา BudgetReceive ต้นทาง (ฝั่งโอนออก):
    │     WHERE Categoryid = รายการ
    │       AND Budgetplanid = แผนงาน
    │       AND Productid = ผลผลิต
    │       AND Activityid = กิจกรรม
    │       AND Budgetsourceid = แหล่งเงินที่เลือก
    │     ถ้าไม่เจอ → สร้าง BudgetReceive ใหม่ ยอด = 0
    │
    └─ สร้าง BudgetReceive ปลายทาง (ฝั่งรับโอน):
          Departmentid = BudgetRequest.Departmentid
          Costcenterid = BudgetRequest.Costcenterid
          Budgetsourceid = (ตามที่ตกลง)
          Totalreceiveamount = ยอดที่โอน
```

---

## 5. รายการการเปลี่ยนแปลงที่ต้องทำ (ตาม Scope ที่วิเคราะห์ได้เบื้องต้น)

### 5.1 Database (DB Changes)

| # | รายการ | ตาราง | รายละเอียด |
|---|---|---|---|
| DB-1 | เพิ่ม column `BUDGETREQUESTID` | `OAGWBG_BUDGETALLOCATETRANSFER` | FK → `OAGWBG_BUDGETREQUEST.ID` (nullable) |

### 5.2 DAL / Model

| # | ไฟล์ | รายการเปลี่ยนแปลง |
|---|---|---|
| DAL-1 | `OagwbgBudgetallocatetransfer.cs` | เพิ่ม property `Budgetrequestid` |
| DAL-2 | `OagwbgVBudgetallocatetransfer.cs` | เพิ่ม `Budgetrequestid`, `RequestCode`, `RequestDepartmentname` |
| DAL-3 | EF DbContext / Scaffold | Regenerate / manual mapping สำหรับ column ใหม่ |

### 5.3 API / Service

| # | ไฟล์ | Method | รายการเปลี่ยนแปลง |
|---|---|---|---|
| API-1 | `BudgetController.cs` (API) | `GetBudgetRequestMoreCodeList` (มีอยู่แล้ว) | ตรวจสอบ / เพิ่ม filter สถานะอนุมัติ |
| API-2 | `BudgetController.cs` (API) | `GetBudgetGovernmentByRequestId` (ใหม่) | ดึงรายการ BudgetGovernment ตาม RequestId |
| API-3 | `BudgetController.cs` (API) | `SaveBudgetAllocateTransferDetail` | รองรับ Budgetrequestid และ auto-map จากคำขอ |
| API-4 | `BudgetService.cs` | `GetBudgetGovernmentByRequestId` (ใหม่) | Query BudgetGovernment + join BudgetRequest |
| API-5 | `BudgetService.cs` | `SaveBudgetAllocateTransferDetail` | เพิ่ม logic หา/สร้าง BudgetReceive ต้นทางและปลายทาง |

### 5.4 MVC Controller

| # | ไฟล์ | Method | รายการเปลี่ยนแปลง |
|---|---|---|---|
| MVC-1 | `BudgetController.cs` (MVC) | `BudgetAllocateTransferDetail` | ส่ง dropdown คำขอไปหน้า View |
| MVC-2 | `BudgetController.cs` (MVC) | `SearchBudgetAllocateTransferList` | อาจเพิ่ม filter ตาม RequestCode |

### 5.5 ViewModel / Model

| # | ไฟล์ | รายการเปลี่ยนแปลง |
|---|---|---|
| VM-1 | `BudgetAllocateTransferDetailViewModel.cs` | เพิ่ม `BudgetRequestList` (dropdown), `SelectedRequestCode` |
| VM-2 | สร้างใหม่: `BudgetAllocateTransferFromRequestModel.cs` | Model สำหรับรับข้อมูลจาก Modal (RequestId, SelectedItems, BudgetSourceId) |

### 5.6 Frontend (Views)

| # | ไฟล์ | รายการเปลี่ยนแปลง |
|---|---|---|
| FE-1 | `BudgetAllocateTransferDetail.cshtml` | เพิ่มปุ่ม "สร้างจากคำขอ" และ Modal |
| FE-2 | Modal (inline หรือ Partial View ใหม่) | - Dropdown เลือก RequestCode<br>- ตารางแสดงรายการ (BudgetGovernment)<br>- Input ยอดที่จะโอนแต่ละรายการ<br>- Dropdown แหล่งเงินโอนออก |
| FE-3 | `_tableBudgetAllocateTransferList.cshtml` | อาจเพิ่มคอลัมน์ RequestCode ในรายการ |

---

## 6. ความเสี่ยงและข้อควรระวัง

| # | ความเสี่ยง | ระดับ | แนวทางจัดการ |
|---|---|---|---|
| R-1 | Type mismatch: `BudgetGovernment.Productid` เป็น `long?` แต่ `BudgetAllocateTransferCategory.Productid` เป็น `string?` | กลาง | ตรวจสอบและแปลงค่าก่อน mapping |
| R-2 | Type mismatch: `BudgetGovernment.Activitycodeid` เป็น `long?` แต่ `BudgetAllocateTransferCategory.Activityid` เป็น `string?` | กลาง | ตรวจสอบและแปลงค่าก่อน mapping |
| R-3 | การสร้าง BudgetReceive ต้นทางใหม่ด้วยยอด 0 อาจส่งผลต่อ balance ในรายงาน | สูง | ต้องตรวจสอบ logic คำนวณยอดคงเหลือที่มีอยู่ |
| R-4 | หนึ่งคำขออาจถูกโอนซ้ำถ้าไม่มี validation | กลาง | เพิ่ม check ว่า RequestId ถูกโอนไปแล้วหรือยัง |
| R-5 | BudgetGovernment ในคำขออาจมีหลาย record แต่ BudgetReceive ต้นทางอาจไม่ครบทุก Category | สูง | ต้องตัดสินใจว่าจะ block หรือสร้างใหม่ (ขึ้นกับคำตอบข้อ 1) |
| R-6 | Performance: การ query รายการใน BudgetGovernment ต่อ 1 คำขออาจมีจำนวนมาก | ต่ำ | ใช้ pagination หรือ lazy load ใน modal |

---

## 7. ขั้นตอนพัฒนาที่แนะนำ (Development Phases)

> ⚠️ ทำได้หลังจากได้รับคำตอบจาก User/PO ครบ 5 ข้อในหัวข้อ 3 แล้วเท่านั้น

### Phase 1 — ฐานข้อมูลและ Backend
1. รัน migration เพิ่ม `BUDGETREQUESTID` ใน `OAGWBG_BUDGETALLOCATETRANSFER`
2. อัปเดต DAL model และ View model
3. เพิ่ม API endpoint `GetBudgetGovernmentByRequestId`
4. ปรับ `SaveBudgetAllocateTransferDetail` รองรับ flow ใหม่

### Phase 2 — Frontend Modal
1. สร้าง Modal เลือกคำขอ
2. Implement logic แสดงรายการ + input ยอดโอน
3. Implement Dropdown แหล่งเงิน

### Phase 3 — Integration & Logic
1. Logic หา/สร้าง BudgetReceive ต้นทาง
2. Logic สร้าง BudgetReceive ปลายทาง
3. Validation ป้องกันโอนซ้ำ

### Phase 4 — Testing & Verification
1. ทดสอบ Flow ปกติ (คำขอที่มี BudgetReceive ต้นทางครบ)
2. ทดสอบ Edge case (ไม่พบ BudgetReceive ต้นทาง → สร้างใหม่)
3. ตรวจสอบยอดคงเหลือหลังโอน

---

## 8. สรุปประเด็นที่รอการตัดสินใจ

```
[ ] คำถามที่ 1: วิธีระบุ BudgetReceive ต้นทาง (Option A: แค่แหล่งเงิน | Option B: ชุดบัญชีชุดเดียว)
[ ] คำถามที่ 2: ศูนย์ต้นทุนผู้รับโอน (จากคำขอ | user ระบุ | รายการต่อรายการ)
[ ] คำถามที่ 3: แหล่งเงินของ BudgetReceive ปลายทาง (จากคำขอ | ระบุตอนสร้างใบโอน)
[ ] คำถามที่ 4: สถานะคำขอที่สามารถนำมาโอนได้ (เฉพาะอนุมัติ | ทุกสถานะ)
[ ] คำถามที่ 5: ความสัมพันธ์ใบโอน:คำขอ (1:1 | 1:N)
```
