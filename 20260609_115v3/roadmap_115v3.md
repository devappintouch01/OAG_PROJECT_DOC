# Roadmap: CR-115v3 — โอนเปลี่ยนแปลงงบประมาณ (อัปเดตจาก v2)

> วันที่วิเคราะห์: 2026-06-09  
> อ้างอิงก่อนหน้า: `_brain_OAGBUDGET\20260605_115v2\roadmap_115v2.md`  
> หน้าที่เกี่ยวข้อง: **BudgetAdjustDetail.cshtml** + **BudgetAdjustDetail_TransferIn_Edit.cshtml**

---

## ผลการ Verify Items [ทำแล้ว] (1–8)

### ✅ Item 1 — เลือก ปีงบประมาณ และประเภทหน่วย
**สถานะ: ทำแล้ว ถูกต้อง**  
- `BudgetAdjustDetail.cshtml` line 108: `<input id="Budgetyear" />`  
- line 60: `<select id="Transferorgtype">` (สบง./สบอ.)  
- เมื่อ `pageId > 0` ทั้งสอง field ถูก disable ป้องกันแก้ไขหลังบันทึก ✅

---

### ✅ Item 2 — กรอก วันที่โอน คำอธิบาย และเหตุความจำเป็น
**สถานะ: ทำแล้ว ถูกต้อง**  
- line 44: `<input id="Transferdate" />` พร้อม datepicker  
- line 118: `<input id="Itemdetail" />` (คำอธิบาย)  
- line 124: `<textarea id="Reason" />` (เหตุความจำเป็น)  
- ทั้ง 3 field มี `required` validation ✅

---

### ✅ Item 3 — Modal เพิ่มรายการโอนออก
**สถานะ: ทำแล้ว ส่วนใหญ่ถูกต้อง — มีข้อสังเกต 1 จุด**  
Modal `#modalTransferOut` มีทุก field ตาม concept:
- แหล่งเงิน (Budgetsource) ✅
- หน่วยเบิกจ่าย (DepartmentId) ✅
- ศูนย์ต้นทุน — **กรองจากหน่วยเบิกจ่าย** ผ่าน `DropdownCostCenter.filter(x => x.Departmentid == departmentId)` ✅
- แผนงาน ✅
- ผลผลิต — กรองจากแผนงาน via AJAX ✅
- กิจกรรม — กรองจากแผนงาน via AJAX ✅
- ประเภทค่าใช้จ่าย — กรองจาก ปีงบ + แหล่งเงิน + หน่วยเบิกจ่าย + ศูนย์ต้นทุน + แผนงาน + ผลผลิต + กิจกรรม ✅
- รายการงบประมาณ — กรองจากประเภทค่าใช้จ่าย ✅
- รหัสงบประมาณ (SegmentCate) ⚠️ **dropdown โหลดจาก ViewBag ไม่ได้ dynamic filter** ตาม concept ที่ระบุว่าควรกรองจาก ปีงบ+แหล่งเงิน+หน่วยเบิกจ่าย+ศูนย์ต้นทุน+แผนงาน+ผลผลิต+กิจกรรม+รายการงบประมาณ ที่มีใน OAGWBG_BUDGETRECEIVE

---

### ✅ Item 4 — เช็คงบ
**สถานะ: ทำแล้ว ถูกต้อง**  
- ปุ่ม `#btn-CheckBudget` → POST `${baseURL}/Budget/CheckTotalBudget`  
- แสดงยอดเงินคงเหลือใน `#remainingbudget`  
- เก็บ AccountSegment, TemplateId, TemplateName ใน hidden fields ✅  
- ปุ่ม "บันทึกรายการ" (`#btn-AddTransferOut`) จะ disabled จนกว่าจะกดเช็คงบสำเร็จ ✅

---

### ✅ Item 5 — บันทึกรายการ → แสดงในตารางรายการโอนเปลี่ยนแปลง
**สถานะ: ทำแล้ว ถูกต้อง — มีข้อสังเกต**  
- กดปุ่ม `#btn-AddTransferOut` → `loadTransferOutRowToTable()` → push ลง `transferOutRows[]` → `renderTransferOutTable()`  
- ตาราง render เป็น hierarchy 4 ระดับ: **แหล่งเงิน → แผนงาน → ผลผลิต → กิจกรรม** ✅  
- แสดง รหัสงบประมาณ, ศูนย์ต้นทุน, ประเภทค่าใช้จ่าย, รายการงบประมาณ, ยอดคงเหลือ, ยอดโอนออก ✅

⚠️ **ข้อสังเกต**: เมื่อเพิ่มรายการใหม่ ยอดโอนออก (`amountNum`) ถูกตั้งเป็น 0 เสมอ (`var amountNum = 0`) และ comment บอกว่า validation ยอดเงินถูก comment ออก — **ผู้ใช้ต้องกรอกยอดโอนออกในตารางหลังเพิ่มรายการ** (ใน data row มี `transfer-out-amount` div แต่ไม่ใช่ input — ต้องตรวจสอบว่ากรอกได้จริงไหม)

---

### ✅ Item 6 — ปุ่มแก้ไขแสดงขึ้นหลังบันทึก
**สถานะ: ทำแล้ว ถูกต้อง**  
- `renderTransferOutTable()`: ถ้า `pageId > 0 && item.id > 0 && isDisabled !== "true"` → แสดงปุ่ม Edit (สีเหลือง) ลิงก์ไปที่ `/Budget/BudgetAdjustDetail_TransferIn_Edit/{pageId}?rowIdx={idx}` ✅

---

### ⚠️ Item 7 — กดแก้ไข → แสดงหน้ารับโอน Header แสดงข้อมูลโอนออก
**สถานะ: ทำแล้ว — มีข้อบกพร่อง**  
- `BudgetAdjustDetail_TransferIn_Edit.cshtml` มี section แสดง Header ข้อมูลโอนออก ✅  
- **แต่ Razor HTML ใช้ hardcoded static values** (line 19-81: `value="เงินงบประมาณรายจ่ายประจำปี"` เป็นต้น)  
- JS จะ override ด้วยข้อมูลจริงจาก `transferOutRows[rowIdx]` ภายหลัง (line 280-296) ✅  
- ⚠️ **ถ้า JS โหลดช้าหรือ rowIdx ไม่ถูกต้อง ผู้ใช้จะเห็น hardcoded text** — ควรแก้ให้ Razor render ค่าจริงจาก Model แทน

---

### ✅ Item 8 — Modal เพิ่มรายการรับโอน
**สถานะ: ทำแล้ว ถูกต้อง**  
- Modal `#modalTransferIn` ใน `BudgetAdjustDetail_TransferIn_Edit.cshtml` มีทุก field ✅  
- Cascading dropdowns: แผนงาน → ผลผลิต / กิจกรรม / ประเภทค่าใช้จ่าย → รายการงบประมาณ ✅

---

## สรุปผล Verify Items 1-8

| Item | สถานะจริง | หมายเหตุ |
|------|-----------|---------|
| 1 | ✅ ถูกต้อง | |
| 2 | ✅ ถูกต้อง | |
| 3 | ✅ ส่วนใหญ่ถูก | รหัสงบประมาณไม่ dynamic filter |
| 4 | ✅ ถูกต้อง | |
| 5 | ✅ ส่วนใหญ่ถูก | ยอดโอนออกเริ่มต้น 0 ต้องกรอกเอง |
| 6 | ✅ ถูกต้อง | |
| 7 | ⚠️ ทำงานได้แต่ Header ใช้ hardcoded | JS override ทีหลัง แต่ UX ไม่ดี |
| 8 | ✅ ถูกต้อง | |

---

## การวิเคราะห์ Items [ยังไม่ทำ] (9–16)

### Item 9 — แสดงรายการรับโอน (Group Level แหล่งเงิน หน่วยเบิกจ่าย ศูนย์ต้นทุน แผนงาน)
**สถานะปัจจุบัน: ทำแล้วบางส่วน ✅**

`renderTransferInTable()` ใน `BudgetAdjustDetail_TransferIn_Edit.cshtml` มี hierarchy 4 ระดับ:
- Level 1: แหล่งเงิน ✅
- Level 2: หน่วยเบิกจ่าย ✅
- Level 3: ศูนย์ต้นทุน ✅
- Level 4: แผนงาน ✅

ตรงตาม concept ✅ แต่ Collapse/Expand ยังไม่ได้ wire จริง (ปุ่ม `-` ในแต่ละ header row ไม่มี click event handler)

---

### Item 10 — กรอกยอดรับโอน + Validate ไม่เกินยอดคงเหลือ
**สถานะปัจจุบัน: ทำแล้ว (UI) — ขาด Backend validate**

- `<input class="row-amount-input" />` ใน data row ✅
- `change` event: ตรวจสอบยอดรวมไม่เกิน `#TransferOutRemainingHeader` ✅
- แสดง SweetAlert เมื่อเกิน ✅

**ยังขาด:**
- Backend Validate (API ไม่ได้ตรวจสอบยอดรับโอน ≤ ยอดคงเหลือ)
- Format `row-amount-input` เมื่อ blur ไม่มี

---

### Item 11 — บันทึกรายการรับโอน
**สถานะปัจจุบัน: ทำแล้วบางส่วน — มีปัญหาสำคัญ (Critical Bug)**

**Flow ปัจจุบัน:**
1. ปุ่ม `#btnSaveDraft` → POST `SaveTransferModifyItem` ด้วย `IsTransferInAction: true`
2. API เรียก `SaveBudgetReceiveTransferIn(model)` (BudgetService.cs line 13499)
3. ลบ `OagwbgBudgetreceive` type "J" เก่าทั้งหมดของ `Budgettransferid` นั้น
4. สร้าง `OagwbgBudgetreceive` ใหม่ type "J" ต่อแต่ละ TransferInItem
5. สร้าง `OagwbgBudgetreceiverefund` (link)
6. อัปเดต `currentHeader.Budgetreceiveidtarget = targetIdList.FirstOrDefault()`

**🔴 Critical Bug — ลบ TransferIn ทั้งหมดของ Header:**
```csharp
// line 13533 — ลบ *ทุก* TransferIn ที่ link กับ header นี้
var oldTargets = await _context.OagwbgBudgetreceives
    .Where(x => x.Budgettransferid == currentHeaderId 
             && x.Budgetreceivetype == "J")  // ✗ ไม่ filter ด้วย BudgetAdjustId
    .ToListAsync();
```
กรณีที่ 1 Header มีหลาย TransferOut → บันทึก TransferIn ของ TransferOut ที่ 2 จะลบ TransferIn ของ TransferOut ที่ 1 ด้วย!

**🟡 Bug อื่น:**
- `Budgetreceiveidtarget = targetIdList.FirstOrDefault()` เก็บแค่ target แรก
- `Totalbalanceamount = isConfirm ? inAmount : 0` ยอดไม่ปรากฏจนกว่า Confirm
- ไม่มี field `Budgetadjustid` ใน OagwbgBudgetreceive เพื่อ link กลับไปยัง TransferOut

**วิธีแก้ (ต้องทำ Phase 1+2 ก่อน):**
```csharp
// Phase 1: ALTER TABLE OAGWBG_BUDGETRECEIVE ADD BUDGETADJUSTID NUMBER;
// Phase 2: แก้ filter ใน SaveBudgetReceiveTransferIn
var budgetAdjustId = /* หา BudgetAdjustId จาก model.Id ที่เป็น TransferOutId */;
var oldTargets = await _context.OagwbgBudgetreceives
    .Where(x => x.Budgettransferid == currentHeaderId
             && x.Budgetreceivetype == "J"
             && x.Budgetadjustid == budgetAdjustId)  // ✓ filter เฉพาะของ TransferOut นี้
    .ToListAsync();

// เมื่อ create target ใหม่
var target = new OagwbgBudgetreceive {
    ...
    Budgetadjustid = budgetAdjustId,  // ✓ เพิ่ม FK
    ...
};
```

---

### Item 12 — Tab ศูนย์ต้นทุนโอนเปลี่ยนแปลง (แสดงหลังบันทึก TransferIn)
**สถานะปัจจุบัน: ทำบางส่วน — แต่มีปัญหา**

`buildAdjustedCostCenterTab()` (BudgetAdjustDetail.cshtml) มีอยู่แล้ว render Tab "ศูนย์ที่โอนเปลี่ยนแปลง"  
Group ด้วย แผนงาน → ประเภทค่าใช้จ่าย → หน่วยเบิกจ่าย ✅ (แต่มีปัญหาดูด้านล่าง)

**ปัญหาที่พบ:**

1. ใช้ `pageModel.departmentidReciver` และ `pageModel.costcenteridReciver` จาก Header Model — เป็นค่าเดียว ไม่รองรับ TransferIn หลาย หน่วยเบิกจ่าย/ศูนย์ต้นทุน

2. ปุ่มธนาคาร render เป็น `<select disabled>` ไม่โหลด dropdown จริง

3. ไม่มีปุ่มบันทึกหลังจากเลือกธนาคาร

4. ข้อมูลไม่ถูก save ลง DB (ไม่มี endpoint)

**วิธีแก้:**
```javascript
// อ่าน dept/costcenter จากแต่ละ TransferInItem แทน Header
var groupKey = (item.planText || '') + '|' + (item.budgetTypeText || '') + '|' + 
               (item.departmentText || '') + '|' + (item.costCenterText || '');
```

---

### Item 13 — เลือกบัญชีธนาคาร + หมายเหตุ + บันทึก
**สถานะปัจจุบัน: ยังไม่ทำ**

**สิ่งที่ต้องพัฒนา:**

**Frontend:**
```javascript
// dropdown ธนาคารใน Tab (dynamic โหลดจาก API)
$.get(`${baseURL}/Budget/GetBankAccountList`, { departmentId: deptId })
  .done(function(data) { /* populate select */ });
```
ดู pattern จากหน้าโอนกลับ: ตาราง `OAGWBG_BUDGETRECEIVEREFUND_COSTCENTER` (columns: Costcenterid, Bankaccountid, Bankaccountgiverid, Note, Budgetplanid, Expensetypeid)

**Backend (API) — endpoint ใหม่:**
```
POST /api/Budget/SaveBudgetAdjustCostCenter
Body: List<BudgetAdjustCostCenterViewModel>
Action: Insert/Update OAGWBG_BUDGETADJUST_COSTCENTER
```

**ViewModel ใหม่:**
```csharp
public class BudgetAdjustCostCenterViewModel {
    public int Id { get; set; }
    public int BudgetTransferId { get; set; }
    public int? BudgetAdjustId { get; set; }
    public int? BudgetReceiveId { get; set; }
    public string? DepartmentId { get; set; }
    public string? CostCenterId { get; set; }
    public string? BudgetPlanId { get; set; }
    public int? CategoryId { get; set; }
    public string? BankAccountIdOut { get; set; }
    public string? BankAccountIdIn { get; set; }
    public string? Note { get; set; }
}
```

---

### Item 14 — ไม่ให้กดยืนยัน ถ้ายังไม่เลือกธนาคารครบ
**สถานะปัจจุบัน: ยังไม่ทำ**

**วิธีแก้ — เพิ่ม Validation ใน `#btn-Confirm` click handler:**
```javascript
function validateCostCenterBankAccounts() {
    var missingRows = [];
    $('#tbodyAdjustCostCenter tr.group-child-refundcc').each(function(idx) {
        var bankOut = $(this).find('select.bank-out-select').val();
        var bankIn  = $(this).find('select.bank-in-select').val();
        if (!bankOut || !bankIn) {
            missingRows.push(idx + 1);
        }
    });
    return missingRows;
}

// เพิ่มใน btn-Confirm handler ก่อน submit
var missing = validateCostCenterBankAccounts();
if (missing.length > 0) {
    await AlertErrorDialog({
        title: 'ยังไม่เลือกบัญชีธนาคารครบ',
        html: 'กรุณาเลือกบัญชีผู้โอนและผู้รับในแถวที่: ' + missing.join(', ')
    });
    return;
}
```

---

### Item 15 — ยืนยัน + ส่ง Interface Oracle EBS
**สถานะปัจจุบัน: ยังไม่ทำ**

**Flow ที่ต้องพัฒนา:**
```
User กดปุ่ม "ยืนยัน"
  ↓
1. validateCostCenterBankAccounts() (Item 14)
  ↓
2. POST SaveTransferModifyItem (IsConfirm: true)
   → อัปเดต Status = "80201"
   → อัปเดต Totalbalanceamount ใน TransferIn records
  ↓
3. Generate Batch_Name (ดู pattern จากหน้าอื่น)
  ↓
4. POST ConfirmBudgetTransferModify (endpoint ใหม่)
   → เรียก SP/Package Oracle EBS
  ↓
5. Return Success → redirect ไปหน้า List
```

**สิ่งที่ต้องค้นหาเพิ่ม:**
- รูปแบบ Batch_Name ของ flow นี้
- ชื่อ SP/Package Oracle EBS ที่รับ interface
- ดู confirm flow ของ BudgetAllocateTransfer เป็น pattern

---

### Item 16 — Temp View สำหรับ Interface
**สถานะปัจจุบัน: ยังไม่ทำ**

ต้องศึกษา:
- `OAGWBG_VBUDGETRECEIVE_REFUND_COSTCENTER` ว่าใช้ pattern แบบไหน
- Temp table ของ BudgetAllocateTransfer interface

---

## ปัญหาสำคัญที่ต้องแก้ก่อน (Priority List)

### 🔴 Critical (Block หน้าอื่น)

**P1: SaveBudgetReceiveTransferIn ลบ TransferIn ทั้งหมดของ Header**
- ไฟล์: `BudgetService.cs` line 13533
- ปัญหา: `Where(x.Budgettransferid == headerID && Budgetreceivetype == "J")` ลบ *ทุก* TransferIn
- แก้: เพิ่ม `BUDGETADJUSTID` column ใน DB + filter ด้วย `x.Budgetadjustid == adjustId`
- Phase: 1 (DB) + 2 (Backend)

### 🟡 Medium

**P2: Header ของ TransferIn_Edit ใช้ hardcoded text**
- ไฟล์: `BudgetAdjustDetail_TransferIn_Edit.cshtml` line 19-81
- แก้: ใช้ Razor render ค่าจาก Model แทน (อ่านจาก `Model.TransferOutItems`)
- Phase: 3 (Frontend)

**P3: รหัสงบประมาณใน Modal โอนออก ไม่ dynamic filter**
- ควรเพิ่ม AJAX endpoint filter SegmentCate จาก OAGWBG_BUDGETRECEIVE
- Phase: 3

**P4: buildAdjustedCostCenterTab ใช้ Department จาก Header Model**
- แก้ให้อ่านจาก TransferInItems แต่ละ item
- Phase: 4

**P5: ยอดโอนออกใน data row เป็น static div ไม่ใช่ input**
- `renderTransferOutTable()` render ยอดโอนออกเป็น `<div class="transfer-out-amount">` ไม่ใช่ `<input>`  
  แต่ event handler ผูก `.on('blur', '.transfer-out-amount', ...)` — ต้องตรวจสอบว่า editable จริงไหม

---

## ลำดับการพัฒนา (Phase Plan)

```
Phase 1 — Database (ต้องทำก่อน เพราะ block Phase 2)
  1.1 ALTER TABLE OAGWBG_BUDGETRECEIVE ADD BUDGETADJUSTID NUMBER (nullable, FK → OAGWBG_BUDGETADJUST)
  1.2 CREATE TABLE OAGWBG_BUDGETADJUST_COSTCENTER (ดู schema ใน roadmap_v2 section 4.1.4)
  1.3 อัปเดต OagwbgBudgetreceive.cs ใน DAL เพิ่ม property Budgetadjustid

Phase 2 — Backend Fix (แก้ Critical Bug)
  2.1 แก้ SaveBudgetReceiveTransferIn: filter + set Budgetadjustid ✓ (แก้ P1)
  2.2 เพิ่ม Backend validation ยอดรับโอน ≤ ยอดคงเหลือ
  2.3 เพิ่ม Endpoint + Service SaveBudgetAdjustCostCenter

Phase 3 — Frontend Fix
  3.1 แก้ Header ใน BudgetAdjustDetail_TransferIn_Edit ให้ Razor render ค่าจริง (แก้ P2)
  3.2 Wire Collapse/Expand ใน renderTransferInTable
  3.3 Format row-amount-input เมื่อ blur
  3.4 ตรวจสอบและแก้ transfer-out-amount ว่า editable ได้จริงไหม (P5)
  3.5 Dynamic filter รหัสงบประมาณ (P3, ถ้าอยู่ใน scope)

Phase 4 — Tab ศูนย์ต้นทุน (Items 12-13-14)
  4.1 แก้ buildAdjustedCostCenterTab ให้อ่าน dept/costcenter จาก TransferInItems จริง (แก้ P4)
  4.2 โหลด dropdown ธนาคาร (ผู้โอน/ผู้รับ) via AJAX
  4.3 ปุ่มบันทึกธนาคาร + เรียก SaveBudgetAdjustCostCenter
  4.4 Validate ธนาคารครบก่อน Confirm (Item 14)

Phase 5 — Oracle Interface (Items 15-16)
  5.1 ศึกษา pattern Batch_Name จากหน้า BudgetAllocateTransfer
  5.2 ค้นหา SP Oracle ที่รับ interface budget adjust
  5.3 พัฒนา ConfirmBudgetTransferModify service + endpoint
  5.4 สร้าง Temp view สำหรับ interface

Phase 6 — Report Text File
  6.1 วิเคราะห์ format รายงาน Text file ของ BudgetAdjust
  6.2 พัฒนา Report endpoint + download
```

---

## ไฟล์ทั้งหมดที่ต้องแก้ไข

### Frontend (OAGBudget)

| ไฟล์ | Path | สิ่งที่ต้องทำ |
|------|------|--------------|
| `BudgetAdjustDetail.cshtml` | `Views/Budget/` | แก้ buildAdjustedCostCenterTab, เพิ่ม dropdown ธนาคาร, validate confirm bank |
| `BudgetAdjustDetail_TransferIn_Edit.cshtml` | `Views/Budget/_partialView/` | แก้ Header hardcoded → Razor, wire collapse, format amount |
| `BudgetController.cs` | `Controllers/` | เพิ่ม Action SaveBudgetAdjustCostCenter, เชื่อม API |

### Backend API (OAGBudget.API)

| ไฟล์ | Path | สิ่งที่ต้องทำ |
|------|------|--------------|
| `BudgetController.cs` | `Controllers/` | เพิ่ม Endpoint SaveBudgetAdjustCostCenter, ConfirmBudgetTransferModify |
| `BudgetService.cs` | `Services/Repository/` | แก้ SaveBudgetReceiveTransferIn (P1), เพิ่ม SaveBudgetAdjustCostCenter, ConfirmBudgetTransferModify |

### Models (OAGBudget.Models)

| ไฟล์ | Path | สิ่งที่ต้องทำ |
|------|------|--------------|
| `BudgetAdjustCostCenterViewModel.cs` | `ViewModel/` | สร้างใหม่ |

### DAL (OAGBudget.DAL)

| ไฟล์ | Path | สิ่งที่ต้องทำ |
|------|------|--------------|
| `OagwbgBudgetreceive.cs` | `Models/` | เพิ่ม property `Budgetadjustid` (nullable int?) |
| `OagwbgBudgetadjustCostcenter.cs` | `Models/` | สร้างใหม่ ถ้าสร้างตารางใหม่ |

---

## Oracle Tables ที่ต้องดำเนินการ

| ตาราง | Action | รายละเอียด |
|-------|--------|-----------|
| `OAGWBG_BUDGETRECEIVE` | ALTER — เพิ่ม column | `ALTER TABLE OAGWBG_BUDGETRECEIVE ADD BUDGETADJUSTID NUMBER;` + FK constraint |
| `OAGWBG_BUDGETADJUST_COSTCENTER` | CREATE — ตารางใหม่ | ดู schema ใน roadmap_115v2 section 4.1.4 |

---

## ประเด็นที่ต้องถาม

1. **ตารางธนาคาร** — ใช้ `OAGWBG_BUDGETRECEIVEREFUND_COSTCENTER` เดิม (ขยาย/เพิ่ม column) หรือสร้าง `OAGWBG_BUDGETADJUST_COSTCENTER` ใหม่?
2. **Oracle Interface** — มี SP/Package ฝั่ง Oracle EBS สำหรับ BudgetAdjust แล้วหรือไม่? ชื่อ SP คืออะไร?
3. **Batch_Name format** — ของ BudgetAdjust ต่างจาก flow อื่นไหม?
4. **รายงาน Text File** — format และ layout ของ Text file ต้องการเป็นแบบใด?
5. **ยอดโอนออก** — ผู้ใช้ต้องการกรอกยอดโอนออกในตาราง หรือกรอกใน Modal ก่อนเพิ่ม?
6. **กรณี Confirm** — `Totalbalanceamount` ของ TransferIn ควรเป็น inAmount ตั้งแต่ draft หรือรอ confirm?

---

## Bug Report: เลขที่โอนของรายการรับโอนไม่ตรงกับรายการโอนออก

> วันที่พบ: 2026-06-09

### สาเหตุ

เมื่อผู้ใช้กด **"บันทึกรายการรับโอน"** ใน `BudgetAdjustDetail_TransferIn_Edit.cshtml`:

```javascript
// line 324 — ส่ง Id ของ OagwbgBudgetadjust (รายการโอนออก) ไปเป็น payload.Id
var transferOutId = transferOutRows[rowIdx].id || transferOutRows[rowIdx].Id;
let payload = {
    Id: transferOutId,        // ← OagwbgBudgetadjust.Id
    IsTransferInAction: true,
    TransferInItems: [...]
};
```

ใน `SaveBudgetReceiveTransferIn` (BudgetService.cs line 13507) รับ `model.Id = OagwbgBudgetadjust.Id` แล้ว **ค้นหา BudgetTransfer ด้วย ID เดียวกันก่อนเลย**:

```csharp
int currentHeaderId = model.Id;   // = OagwbgBudgetadjust.Id

// ❌ จุดบกพร่อง: ค้นหา BudgetTransfer ด้วย OagwbgBudgetadjust.Id โดยตรง
var currentHeader = await _context.OagwbgBudgettransfers
    .FirstOrDefaultAsync(x => x.Id == currentHeaderId);

// Fallback เข้าเฉพาะตอน currentHeader == null
if (currentHeader == null)
{
    var adjustForHeader = await _context.OagwbgBudgetadjusts
        .FirstOrDefaultAsync(a => a.Id == model.Id);
    // ... ถึงจะหา BudgetTransferId ที่ถูกต้อง
}
```

Oracle ใช้ Sequence แยกกันต่อตาราง แต่ตัวเลข ID อาจซ้ำกันข้ามตารางได้:

```
OAGWBG_BUDGETADJUST:    Id = 5  → Budgettransferid = 12
OAGWBG_BUDGETTRANSFER:  Id = 5  → (document อื่น เลขที่โอน "BG25-0005")  ← match ผิดตัว!
OAGWBG_BUDGETTRANSFER:  Id = 12 → (document ที่ถูกต้อง เลขที่โอน "BG25-0012")
```

เมื่อ `BudgetAdjust.Id = 5` บังเอิญตรงกับ `BudgetTransfer.Id = 5` (document อื่น) → `currentHeader` ≠ null → ไม่เข้า fallback → BudgetReceive ใหม่ link ไปที่ BudgetTransfer.Id = 5 (เลขที่โอนผิด)

### วิธีแก้

**ไฟล์:** `OAGBudget.API\Services\Repository\BudgetService.cs` ~line 13507

```csharp
// ❌ ก่อนแก้ (เปิดช่องให้ match ผิดตัว)
int currentHeaderId = model.Id;
var currentHeader = await _context.OagwbgBudgettransfers
    .FirstOrDefaultAsync(x => x.Id == currentHeaderId);
if (currentHeader == null) { /* fallback */ }
```

```csharp
// ✅ หลังแก้ (ค้นหา BudgetAdjust ก่อนเสมอ เพื่อหา BudgetTransferId จริง)
var adjustRecord = await _context.OagwbgBudgetadjusts
    .FirstOrDefaultAsync(a => a.Id == model.Id);

if (adjustRecord?.Budgettransferid == null)
{
    await transaction.RollbackAsync();
    return new TransferResultModel
    {
        Success = false,
        Message = $"ไม่พบรายการโอนออกที่ระบุ (BudgetAdjust.Id: {model.Id})"
    };
}

int currentHeaderId = adjustRecord.Budgettransferid.Value;
var currentHeader = await _context.OagwbgBudgettransfers
    .FirstOrDefaultAsync(x => x.Id == currentHeaderId);

if (currentHeader == null)
{
    await transaction.RollbackAsync();
    return new TransferResultModel
    {
        Success = false,
        Message = $"ไม่พบ Header เลขที่โอน (BudgetTransfer.Id: {currentHeaderId})"
    };
}
```

### สรุปผลกระทบ

| | เดิม (Bug) | ใหม่ (Fix) |
|--|-----------|-----------|
| ลำดับค้นหา | BudgetTransfer ก่อน → fallback ถ้า null | BudgetAdjust ก่อนเสมอ → ไล่ FK หา BudgetTransferId |
| ความเสี่ยง | ถ้า `BudgetAdjust.Id` ตรงกับ `BudgetTransfer.Id` ของ document อื่น → link ผิดตัว | ไม่มีความเสี่ยง ไล่จาก FK ตาม schema |

---

## Bug Report: ปัญหาหลังจาก Dev แก้ Roundno (Item 11)

> วันที่พบ: 2026-06-09

### โครงสร้างข้อมูล (สำหรับ reference)

สำหรับ 1 เอกสารโอนเปลี่ยนแปลง ที่มี N รายการโอนออก — แต่ละ TransferOut row สร้าง record คู่กัน:

```
OagwbgBudgettransfer.Id = 10  (roundno=5)  ← TransferOut row 0
   └─ OagwbgBudgetadjust.Id = 20  (Budgettransferid=10)

OagwbgBudgettransfer.Id = 11  (roundno=5)  ← TransferOut row 1
   └─ OagwbgBudgetadjust.Id = 21  (Budgettransferid=11)

OagwbgVBudgettransferChanges → returns row Id=20, Id=21  (= BudgetAdjust.Id)
```

`GetBudgetAdjustDetail` จึง set `result.Id = firstHeader.Id = 20`  
→ `$('#Id').val()` บน BudgetAdjustDetail.cshtml = 20 เสมอ ทุก row ใช้ค่าเดิม

---

### ปัญหา A — รายการรับโอนซ้ำ / ลบไม่ออก

**สาเหตุ:** Frontend ส่ง payload.Id ผิด

`TransferIn_Edit.cshtml` (line ~362):
```javascript
var transferOutId = transferOutRows[rowIdx].id;  // ← คำนวณถูก เช่น = 21 ถ้า edit row 1
let payload = {
    Id: parseInt('@Model.Id') || 0,  // ❌ BUG: ส่ง 20 (first row) แทนที่จะส่ง 21
    ...
};
// transferOutId ถูกคำนวณไว้แต่ไม่ได้ใส่ใน payload!
```

`SaveBudgetReceiveTransferIn` รับ `model.Id = 20` เสมอ ไม่ว่า user จะกด Edit row ไหน:
- Delete filter: `Budgetadjustid == 20 OR Budgetadjustid == null`
- Insert: `Budgetadjustid = 20`

เมื่อ dev แก้ roundno โดยเปลี่ยน logic ทำให้ `model.Id` ถูก interpret ต่างกัน:
- Save ครั้งก่อน (pre-fix): records มี `Budgetadjustid = X`
- Save ครั้งหลัง (post-fix): delete filter ใช้ `Budgetadjustid == Y` (Y ≠ X)
- Records เก่า (X) ไม่ถูกลบ → insert records ใหม่ (Y) ซ้อนขึ้นมา = **ซ้ำ ลบไม่ออก**

**Fix:**
```javascript
// TransferIn_Edit.cshtml — เปลี่ยน payload.Id
let payload = {
    Id: transferOutId,  // ✅ ใช้ transferOutRows[rowIdx].id แทน Model.Id
    ...
};
```

---

### ปัญหา B — รายการทั้งหมด Sync กัน (กดแก้ไข row ไหนก็เห็นข้อมูลเดียวกัน)

**สาเหตุ:** `GetBudgetAdjustDetail` โหลด TransferIn โดยไม่ filter ด้วย BudgetAdjust.Id

`BudgetService.cs` (line 16306-16308):
```csharp
// ทำซ้ำสำหรับทุก header (row) ใน allHeaders:
var receiveJItems = await _context.OagwbgVBudgetreceives
    .Where(x => x.Budgettransferid == currentTransferId   // ← ดึง J ทั้งหมดของ BudgetTransfer
             && x.Budgetreceivetype == "J")
    // ❌ ขาด filter ด้วย BudgetAdjust.Id → ทุก row เห็น TransferIn ชุดเดียวกัน
    .ToListAsync();
```

**Fix:**
```csharp
var receiveJItems = await _context.OagwbgVBudgetreceives
    .Where(x => x.Budgettransferid == currentTransferId
             && x.Budgetreceivetype == "J"
             && x.Budgetadjustid == header.Id)   // ✅ เพิ่ม filter ด้วย BudgetAdjust.Id
    .ToListAsync();
```

> **หมายเหตุ:** ต้องตรวจสอบว่า `OagwbgVBudgetreceives` (View) มี column `Budgetadjustid` หรือไม่
> ถ้าไม่มี → ต้อง query จาก `OagwbgBudgetreceives` (Table) แทน หรือ alter view เพิ่ม column

---

### ปัญหา C — เพิ่มรายการโอนออกได้แค่ 1 รายการ (TransferIn หายเมื่อเพิ่ม row ใหม่)

**สาเหตุ:** `SaveTransferModifyItem` ลบ TransferIn ของ **ทุก header** ใน Roundno เดียวกัน ก่อน save TransferOut ใหม่

`BudgetService.cs` (line 13957-14033):
```csharp
foreach (var headerDraft in existingHeaders)   // ← วนทุก BudgetTransfer ใน roundno เดียวกัน
{
    // ลบ TransferIn ทั้งหมดของแต่ละ header
    var oldTargets = await _context.OagwbgBudgetreceives
        .Where(x => x.Budgettransferid == headerDraft.Id && x.Budgetreceivetype == "J")
        .ToListAsync();
    _context.OagwbgBudgetreceives.RemoveRange(oldTargets);  // ❌ ลบ TransferIn ของทุก row!
}
```

ผลที่เกิด: เมื่อ user เพิ่ม TransferOut row ที่ 2 → save ลบ TransferIn ของ row แรกทิ้งด้วย  
→ user เห็นว่า TransferIn หายไปเมื่อมีมากกว่า 1 TransferOut row

**Fix แนวทาง:** Decouple การ save TransferOut ออกจากการแตะ TransferIn  
- ในขั้นตอน edit TransferOut (เพิ่ม/แก้ row) ไม่ควร delete TransferIn ของ row อื่น
- ลบ TransferIn เฉพาะ row ที่ถูก replace จริงๆ เท่านั้น (filter ด้วย `Budgetadjustid` หรือ `Budgettransferid` ของ row นั้นโดยเฉพาะ)

---

### สรุปไฟล์และจุดที่ต้องแก้

| # | ปัญหา | ไฟล์ | บรรทัด | Fix |
|---|-------|------|--------|-----|
| A | payload.Id ผิด | `TransferIn_Edit.cshtml` | ~362 | เปลี่ยน `Model.Id` → `transferOutId` |
| B | โหลด TransferIn ไม่ filter | API `BudgetService.cs` | 16306 | เพิ่ม `&& x.Budgetadjustid == header.Id` |
| C | ลบ TransferIn ทุก row เมื่อ save TransferOut | API `BudgetService.cs` | 13963 | decouple — ลบเฉพาะ row ที่เปลี่ยนแปลง |

---

## Bug Report: รายการโอนออก row ที่ 2 กลายเป็นหน่วยงานของ row แรก

> วันที่พบ: 2026-06-10

### อาการ

เมื่อผู้ใช้เพิ่มรายการโอนออก row ที่ 2 จากหน่วยงานที่แตกต่างจาก row แรก หลังบันทึกพบว่า row ที่ 2 แสดงหน่วยงานเดียวกับ row แรก

### Root Cause

**`SaveTransferModifyItem` (API `BudgetService.cs`)**

มี 2 จุดที่ใช้ค่าจาก **header-level** (`model.DepartmentId`, `model.CostCenterId`) แทน **per-item** (`giverItem.DepartmentId`, `giverItem.CostCenterId`):

**จุดที่ 1 — `resolvedRegion` คำนวณ _นอก_ loop (line 13798-13802)**
```csharp
// ❌ คำนวณครั้งเดียวก่อน foreach โดยใช้ model.CostCenterId (หน่วยงานจาก form header)
string? regionFromCc = await _context.OagwbgVExtOagglCostCenterVs
    .Where(x => x.Id == model.CostCenterId)   // ← ค่าของ row แรกเสมอ
    .Select(x => x.Regionid)
    .FirstOrDefaultAsync();
var resolvedRegion = regionFromCc?.ToString() ?? model.TransferRegion;
```

**จุดที่ 2 — ภายใน loop ตอน set currentHeader (line 14122-14125)**
```csharp
foreach (var giverItem in unifiedItems)
{
    currentHeader.Departmentid   = model.DepartmentId;   // ❌ header-level เสมอ
    currentHeader.Costcenterid   = model.CostCenterId;   // ❌ header-level เสมอ
    currentHeader.Transferregion = resolvedRegion;       // ❌ คำนวณจาก row แรก

    // fields อื่น ใช้ per-item ถูกต้อง:
    currentHeader.Activityid = giverItem.ActivityId ?? model.ActivityId;
    currentHeader.Productid  = giverItem.OutputId   ?? model.ProductId;
    currentHeader.Categoryid = giverItem.CategoryId ?? model.CategoryidGiver;
}
```

**จุดที่ 3 — OagwbgBudgetadjust insert (line 14380-14382) copy มาจาก currentHeader ที่ผิดแล้ว**
```csharp
Departmentid   = currentHeader.Departmentid,     // ❌ ผิดตาม currentHeader
Costcenterid   = currentHeader.Costcenterid,     // ❌ ผิดตาม currentHeader
Transferregion = currentHeader.Transferregion,   // ❌ ผิดตาม currentHeader
```

### ข้อสังเกต: Budget Sender Lookup ยังทำงานถูก

ยอดเงินที่ตัดใช้ per-item ถูกต้อง (line 14147-14148):
```csharp
// ✅ Sender lookup ใช้ giverItem ถูก
var searchDepartmentid = giverItem.DepartmentId ?? model.DepartmentId;
var searchCostcenterid = giverItem.CostCenterId ?? model.CostCenterId;
```

ดังนั้น **ยอดเงินตัดถูก แต่ record ที่บันทึกใน BudgetTransfer/BudgetAdjust แสดงหน่วยงานผิด**

### วิธีแก้

**`BudgetService.cs` ใน `SaveTransferModifyItem` — ย้าย region resolve เข้าใน loop และใช้ per-item:**

```csharp
// ✅ resolve per-item ภายใน loop แทนที่ model.DepartmentId/CostCenterId
var itemDepartmentId = giverItem.DepartmentId ?? model.DepartmentId;
var itemCostCenterId = giverItem.CostCenterId ?? model.CostCenterId;

string? itemRegionFromCc = await _context.OagwbgVExtOagglCostCenterVs
    .Where(x => x.Id == itemCostCenterId)
    .Select(x => x.Regionid)
    .FirstOrDefaultAsync();
var itemRegion = itemRegionFromCc?.ToString() ?? model.TransferRegion;

currentHeader.Departmentid   = itemDepartmentId;   // ✅
currentHeader.Costcenterid   = itemCostCenterId;   // ✅
currentHeader.Transferregion = itemRegion;         // ✅
```

### สรุปไฟล์และจุดที่ต้องแก้

| จุด | ไฟล์ | บรรทัด | ปัญหา | Fix |
|----|------|--------|-------|-----|
| 1 | API `BudgetService.cs` | 13798 | `resolvedRegion` คำนวณนอก loop ด้วย `model.CostCenterId` | ย้ายเข้าใน loop ใช้ `giverItem.CostCenterId` |
| 2 | API `BudgetService.cs` | 14122-14125 | `Departmentid`/`Costcenterid`/`Transferregion` ใช้ header-level | เปลี่ยนเป็น `giverItem.DepartmentId ?? model.DepartmentId` |
| 3 | API `BudgetService.cs` | 14380-14382 | BudgetAdjust insert copy จาก currentHeader ที่ผิดแล้ว | แก้ตามจุดที่ 2 จะถูกต้องเองโดยอัตโนมัติ |

---

## Bug Report: รายการรับโอนไม่แสดงหลัง Dev Checkin ใหม่

> วันที่พบ: 2026-06-11

### อาการ

หลังจาก Dev checkin code ใหม่ที่แก้ `roundno` และเพิ่ม `transferOutId` param ใน URL — รายการรับโอนที่เคยแสดงปกติกลับหายไปจากตาราง แม้ว่า record ยังคงถูกบันทึกลง `OAGWBG_BUDGETRECEIVE` เช่นเดิม

### บริบท: โครงสร้าง ID ที่ใช้

```
BudgetAdjustDetail.cshtml:
  pageId = $('#Id').val() = Model.Id = BudgetTransfer.Id  ← ID ของ header document

Edit URL (หลัง dev checkin ใหม่):
  /Budget/BudgetAdjustDetail_TransferIn_Edit/{pageId}
     ?rowIdx={idx}
     &transferOutId={item.id}   ← item.id = BudgetAdjust.Id (เพิ่มใหม่โดย dev)
     &roundNo={roundNo}
```

### สาเหตุ — Bug 1: Save payload ส่ง Id ผิด

**`BudgetAdjustDetail_TransferIn_Edit.cshtml` (line ~716)**

Dev เพิ่ม param `transferOutId` ใน URL เพื่อให้ frontend หา `selectedIndex` ได้ถูกต้อง แต่ **payload ที่ส่ง save ยังคงใช้ `pageId` (BudgetTransfer.Id)**:

```javascript
const transferOutIdParam = parseInt(urlParams.get('transferOutId'));  // BudgetAdjust.Id ✅
const pageId = parseInt('@Model.Id') || 0;   // BudgetTransfer.Id

// ✅ selectedIndex ใช้ transferOutIdParam ได้ถูก
if (!isNaN(transferOutIdParam) && transferOutIdParam > 0) {
    selectedIndex = transferOutRows.findIndex(r => parseInt(r.id) === transferOutIdParam);
}

// ❌ payload.Id ยังส่ง pageId (BudgetTransfer.Id) ไม่ใช่ transferOutIdParam (BudgetAdjust.Id)
var payload = {
    Id: pageId,          // ❌ BudgetTransfer.Id — ผิด!
    Roundno: roundNo,
    IsTransferInAction: true,
    TransferInItems: [...]
};
```

**ผลที่เกิด:**

```
API รับ model.Id = BudgetTransfer.Id
  → SaveBudgetReceiveTransferIn lookup: OagwbgBudgetadjusts.FirstOrDefault(a.Id == BudgetTransfer.Id)
  → ถ้าไม่มี BudgetAdjust.Id ตรงกับ BudgetTransfer.Id → null → return error → ไม่มีการบันทึก
  → ถ้าบังเอิญ sequence ซ้ำกัน → บันทึกแต่ Budgetadjustid = BudgetTransfer.Id (ผิด)
```

### สาเหตุ — Bug 2: Query แสดงผลใช้ View ที่ไม่มี J-type records

**`GetBudgetAdjustDetail` API (BudgetService.cs ~line 16356)**

Dev แก้ logic ใหม่: loop ตาม `OagwbgBudgetadjust` แต่ query TransferIn ผ่าน JOIN กับ `OagwbgVBudgetreceives`:

```csharp
foreach (var adj in adjusts)  // adj.Id = BudgetAdjust.Id
{
    // ❌ OagwbgVBudgetreceives เป็น View สำหรับงบประมาณคงเหลือ — ไม่รวม J-type records!
    var receiveJItems = await (
        from v in _context.OagwbgVBudgetreceives       // ❌ View นี้ไม่มี J-type
        join br in _context.OagwbgBudgetreceives on v.Id equals br.Id  // JOIN จึงไม่ได้ match
        where br.Budgetreceivetype == "J"
           && br.Budgetadjustid == adj.Id
        ...
    ).ToListAsync();  // ← ผลลัพธ์ Empty เสมอ

    if (!receiveJItems.Any())
    {
        // Fallback — query ตรงจาก table:
        // WHERE Budgettransferid == header.Id
        //   AND Budgetreceivetype == "J"
        //   AND (Budgetadjustid == adj.Id OR Budgetadjustid == null)
        //
        // ❌ ปัญหา: records ที่ถูกบันทึกมี Budgetadjustid = BudgetTransfer.Id (จาก Bug 1)
        //    แต่ fallback filter ด้วย adj.Id = BudgetAdjust.Id → ไม่ match → ยังคง Empty
    }
}
```

### ลำดับเหตุการณ์ (Chain of Events)

```
[1] User กด Save TransferIn
    payload.Id = pageId = BudgetTransfer.Id   ← Bug 1

[2] API: SaveBudgetReceiveTransferIn(model.Id = BudgetTransfer.Id)
    → หา BudgetAdjust ด้วย a.Id == BudgetTransfer.Id
    → ถ้า null → ไม่บันทึก, return error
    → ถ้า match (sequence ซ้ำ) → บันทึก Budgetadjustid = BudgetTransfer.Id  (ผิด FK)

[3] User reload หน้า / กด Edit
    API: GetBudgetAdjustDetail
    → Primary query: JOIN OagwbgVBudgetreceives + OagwbgBudgetreceives
       WHERE Budgetreceivetype=="J" AND Budgetadjustid==adj.Id(BudgetAdjust.Id)
       → View ไม่มี J-type → JOIN ไม่ match → Empty เสมอ  ← Bug 2

    → Fallback query: WHERE Budgetadjustid==adj.Id(BudgetAdjust.Id)
       → records ที่มีอยู่มี Budgetadjustid=BudgetTransfer.Id ≠ adj.Id → ไม่ match → ยัง Empty

[4] Frontend: ได้ TransferIn = [] → ตารางแสดงว่างเปล่า
```

### วิธีแก้

**Fix 1 — `TransferIn_Edit.cshtml` ~line 716:**

```javascript
// ❌ ก่อนแก้
var payload = {
    Id: pageId,   // BudgetTransfer.Id
    ...
};

// ✅ หลังแก้
var payload = {
    Id: transferOutIdParam,   // BudgetAdjust.Id — ตรงกับสิ่งที่ API คาดหวัง
    ...
};
```

**Fix 2 — API `GetBudgetAdjustDetail` ~line 16356:**

```csharp
// ❌ ก่อนแก้ — JOIN กับ View ที่ไม่มี J-type
var receiveJItems = await (
    from v in _context.OagwbgVBudgetreceives    // ❌
    join br in _context.OagwbgBudgetreceives on v.Id equals br.Id
    where br.Budgetreceivetype == "J" && br.Budgetadjustid == adj.Id
    ...
).ToListAsync();

// ✅ หลังแก้ — query ตรงจาก Table เสมอ ตัด JOIN กับ View ออก
var receiveJItems = await _context.OagwbgBudgetreceives
    .Where(x => x.Budgettransferid == header.Id
             && x.Budgetreceivetype == "J"
             && x.Budgetadjustid == adj.Id)
    .ToListAsync();
```

> **หมายเหตุ:** Fix 2 จะทำงานได้สมบูรณ์เมื่อ Fix 1 ถูก deploy แล้ว (records ใหม่มี `Budgetadjustid` ถูกต้อง)  
> สำหรับ records เก่าที่บันทึกด้วย `Budgetadjustid = BudgetTransfer.Id` ผิด อาจต้องมี data migration หรือ fallback query เพิ่มเติม

### สรุปไฟล์และจุดที่ต้องแก้

| # | ปัญหา | ไฟล์ | บรรทัด | Fix |
|---|-------|------|--------|-----|
| 1 | `payload.Id` ส่ง `BudgetTransfer.Id` แทน `BudgetAdjust.Id` | `BudgetAdjustDetail_TransferIn_Edit.cshtml` | ~716 | เปลี่ยน `Id: pageId` → `Id: transferOutIdParam` |
| 2 | Primary query JOIN กับ View ที่ไม่มี J-type → Empty เสมอ | API `BudgetService.cs` | ~16356 | ตัด JOIN กับ `OagwbgVBudgetreceives` — query ตรงจาก Table แทน |

---

## Verify Report: Items 1–14 (Dev แจ้งว่าทำแล้ว)

> วันที่ Verify: 2026-06-13  
> อ้างอิงไฟล์: `BudgetAdjustDetail.cshtml`, `BudgetAdjustDetail_TransferIn_Edit.cshtml`, `BudgetService.cs`

### สรุปผลรวม

| Item | ชื่อ | สถานะจริง | ปัญหาที่พบ |
|------|------|-----------|-----------|
| 1 | เลือกปีงบประมาณ + ประเภทหน่วย | ✅ ถูกต้อง | — |
| 2 | กรอกวันที่โอน + คำอธิบาย + เหตุผล | ✅ ถูกต้อง | — |
| 3 | Modal เพิ่มรายการโอนออก | ✅ ถูกต้อง | — (P3 รหัสงบประมาณ dynamic filter ถูกแก้แล้ว) |
| 4 | เช็คงบ | ✅ ถูกต้อง | — |
| 5 | บันทึกรายการ → แสดงในตาราง | ⚠️ บางส่วน | ยอดโอนออกเป็น `<div>` ไม่ใช่ `<input>` → ผู้ใช้กรอกยอดไม่ได้ |
| 6 | ปุ่มแก้ไขแสดงหลังบันทึก | ✅ ถูกต้อง | — |
| 7 | Header หน้ารับโอนแสดงข้อมูลโอนออก | ⚠️ Functional แต่ fragile | ยัง hardcoded ใน HTML, JS override ทีหลัง |
| 8 | Modal เพิ่มรายการรับโอน | ✅ ถูกต้อง | — |
| 9 | แสดงรายการรับโอน + Collapse/Expand | ⚠️ บางส่วน | Collapse All / Expand All ไม่มี handler |
| 10 | กรอกยอดรับโอน + Validate | ✅ ถูกต้อง | — |
| 11 | บันทึกรายการรับโอน | 🔴 มีบั๊กสำคัญ | 3 จุด (ดูด้านล่าง) |
| 12 | Tab ศูนย์ต้นทุนโอนเปลี่ยนแปลง | ⚠️ บางส่วน | ไม่มีปุ่ม Save แยกต่างหาก |
| 13 | เลือกบัญชีธนาคาร + หมายเหตุ + บันทึก | ⚠️ บางส่วน | Confirm ไม่ส่ง RefundCostCenters |
| 14 | ไม่ให้กดยืนยันถ้ายังไม่เลือกธนาคารครบ | ❌ ยังไม่ทำ | ไม่มี bank validation ใน btn-Confirm |

---

### รายละเอียดปัญหาที่พบ

#### Item 5 — ยอดโอนออกเป็น `<div>` ไม่ใช่ `<input>`

**ไฟล์:** `BudgetAdjustDetail.cshtml` ~line 2033

```javascript
// ❌ ยอดโอนออกใน data row เป็น div — ผู้ใช้กรอกแก้ไขไม่ได้
'<div class="transfer-out-amount fw-bold text-end" data-raw="' + (item.amountNum || 0) + '">' +
     (item.amountFormatted || '0.00') +
'</div>'
```

ทุก TransferOut row ที่เพิ่มใหม่จะมี `amountNum = 0` (line 1739) และผู้ใช้ไม่สามารถแก้ยอดโอนออกได้โดยตรงในตาราง เมื่อ Confirm ระบบจะส่ง `Amount: r.amountNum || 0` = 0 เสมอ ทำให้ยอดโอนออกใน DB เป็น 0

**Fix:** เปลี่ยนจาก `<div>` เป็น `<input type="text">` และเพิ่ม event handler บันทึกค่าลงใน `transferOutRows[idx].amountNum`

---

#### Item 9 — Collapse All / Expand All ไม่มี Click Handler

**ไฟล์:** `BudgetAdjustDetail_TransferIn_Edit.cshtml`

ปุ่มใน `BudgetAdjustDetail_TransferIn.cshtml`:
```html
<button id="btn-CollapseAllTransferIn" ...>ย่อทั้งหมด</button>
<button id="btn-ExpandAllTransferIn"   ...>แสดงทั้งหมด</button>
```

แต่ใน `BudgetAdjustDetail_TransferIn_Edit.cshtml` ไม่มี handler สำหรับทั้งสอง ID นี้ — มีแค่ `.btn-tin-toggle` (individual collapse ต่อ row)

**Fix ที่ต้องเพิ่ม:**
```javascript
$('#btn-CollapseAllTransferIn').on('click', function() {
    $('#tbodyTransferInList tr[data-collapse-key]').each(function() {
        var key = $(this).data('collapse-key');
        if (key) {
            tinCollapsed[key] = true;
            $(this).find('.btn-tin-toggle').text('+');
            toggleTinChildren(key, true);
        }
    });
});

$('#btn-ExpandAllTransferIn').on('click', function() {
    Object.keys(tinCollapsed).forEach(k => { tinCollapsed[k] = false; });
    $('#tbodyTransferInList tr').show();
    $('#tbodyTransferInList .btn-tin-toggle').text('-');
});
```

---

#### Item 11 — 3 จุดที่ยังมีบั๊กหลัง Dev Checkin

**จุดที่ 1 — Delete filter ไม่กรองด้วย Budgetadjustid (ลบ TransferIn ทุก row)**

`BudgetService.cs` ~line 13647:
```csharp
// ❌ ลบ J ทั้งหมดของ header โดยไม่ filter budgetadjustid
var oldTargets = await _context.OagwbgBudgetreceives
    .Where(x => x.Budgettransferid == currentHeaderId
             && x.Budgetreceivetype == "J")   // ❌ ขาด && x.Budgetadjustid == budgetAdjustId
    .ToListAsync();
```

เมื่อ save TransferIn ของ row ที่ 2 → ลบ TransferIn ของ row แรกด้วย

**จุดที่ 2 — Insert ไม่ set Budgetadjustid ใน record ใหม่**

`BudgetService.cs` ~line 13700-13716:
```csharp
var target = new OagwbgBudgetreceive {
    Budgettransferid = currentHeader.Id,
    // ❌ ไม่มี Budgetadjustid = budgetAdjustId
    ...
};
```

records ใหม่ไม่รู้ว่าเป็นของ TransferOut row ไหน → แสดงผลผิดในภายหลัง

**จุดที่ 3 — GetBudgetAdjustDetail query J-type ผ่าน View ที่ไม่มี J-type**

`BudgetService.cs` ~line 16866:
```csharp
// ❌ OagwbgVBudgetreceives เป็น View สำหรับ budget balance — ไม่รวม J-type
var allDirectBrItems = await _context.OagwbgVBudgetreceives
    .Where(x => x.Budgettransferid == header.Id && x.Budgetreceivetype == "J")
    .ToListAsync();  // ← ผลลัพธ์ Empty เสมอ → TransferIn ไม่แสดง
```

**Fix ทั้ง 3 จุดต้องทำพร้อมกัน** (ต้องทำ Phase 1 DB ก่อน):
```csharp
// Fix 1 — ลบเฉพาะของ BudgetAdjust นี้
var oldTargets = await _context.OagwbgBudgetreceives
    .Where(x => x.Budgettransferid == currentHeaderId
             && x.Budgetreceivetype == "J"
             && x.Budgetadjustid == budgetAdjustId)   // ✅
    .ToListAsync();

// Fix 2 — Insert พร้อม FK
var target = new OagwbgBudgetreceive {
    Budgetadjustid = budgetAdjustId,  // ✅ เพิ่ม FK
    Budgettransferid = currentHeader.Id,
    ...
};

// Fix 3 — ใช้ Table แทน View
var allDirectBrItems = await _context.OagwbgBudgetreceives  // ✅ Table ไม่ใช่ View
    .Where(x => x.Budgettransferid == header.Id && x.Budgetreceivetype == "J")
    .ToListAsync();
```

---

#### Item 13 — Confirm Handler ไม่ส่ง RefundCostCenters

**ไฟล์:** `BudgetAdjustDetail.cshtml` ~line 1086

`#btnSave` handler เก็บ `refundCostCenters` และส่งใน payload ✅  
แต่ `#btn-Confirm` handler (line 1086) ไม่มีการเก็บหรือส่ง `RefundCostCenters`:

```javascript
// ❌ btn-Confirm handler ไม่รวม refundCostCenters
let dataList = {
    TransferInItems: ...,
    TransferOutItems: ...,
    IsConfirm: true
    // RefundCostCenters: ??? — ขาดหายไป
};
```

ถ้าผู้ใช้กด Confirm โดยตรงโดยไม่กด Save ก่อน → ข้อมูลธนาคารจาก Tab ศูนย์ต้นทุนจะหายไป

**Fix:** เพิ่มการเก็บ `refundCostCenters` ใน `#btn-Confirm` handler เหมือนใน `#btnSave`

---

#### Item 14 — ไม่มี Bank Validation ใน Confirm

**ไฟล์:** `BudgetAdjustDetail.cshtml` ~line 1086-1226

`#btn-Confirm` handler validate เฉพาะ: Transferdate, Budgetyear, Itemdetail, Reason, Transferorgtype  
**ไม่มีการตรวจสอบว่าเลือก giver-bank / receiver-bank ครบทุก row** ใน Tab ศูนย์ต้นทุน

ผู้ใช้สามารถ Confirm ได้โดยไม่เลือกธนาคาร → Oracle Interface อาจ error
