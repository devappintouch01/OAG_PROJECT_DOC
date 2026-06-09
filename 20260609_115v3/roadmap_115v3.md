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
