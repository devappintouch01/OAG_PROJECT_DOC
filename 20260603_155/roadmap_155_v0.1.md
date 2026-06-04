# Roadmap การแก้ไข — Issue 155 (2026-06-03)

## บริบทของปัญหา

หน้าจอ **โอนเปลี่ยนแปลงงบประมาณ (TransferIn)** พบปัญหา 4 ข้อที่เชื่อมโยงกัน  
ไฟล์หลักที่เกี่ยวข้อง:
- Frontend: `OAGBudget/Views/Budget/BudgetAdjustDetail_TransferIn.cshtml`
- ViewModel: `OAGBudget.Models/ViewModel/BudgetAdjustDetailViewModel.cs`
- Service: `OAGBudget.API/Services/Repository/BudgetService.cs` → `SaveTransferModifyItem` (~line 13415)

---

## สรุปสาเหตุของปัญหาแต่ละข้อ

---

### ปัญหาที่ 1 — `remainingamount` ในฐานข้อมูล ≠ ยอดคงเหลือที่แสดงในหน้าจอ

#### สาเหตุหลัก (A): Confirm handler ส่ง Giver key ผิด element

ใน `$("#btn-Confirm").on("click", ...)` (ประมาณบรรทัด 781–784):

```javascript
// ❌ ผิด — ใช้ element ฝั่งรับโอน (Reciver) มาเป็น Giver
CostcenteridGiver: $('#CostCenterIdRecive').val(),
DepartmentidGiver: $('#DepartmentIdRecive').val(),
```

ค่า `CostcenteridGiver` และ `DepartmentidGiver` ที่ส่งไปหลังบ้านคือ **ศูนย์ต้นทุน/หน่วยงานของฝั่งรับโอน** ไม่ใช่ฝั่งโอนออก  
ผลที่ตามมา: backend query `senderRows` จาก `OagwbgBudgetreceive` ด้วย key ที่ผิด  
→ ได้แถวที่ไม่ถูกต้อง หรือได้ totalAvailable = 0  
→ `finalRemainingAmount = currentTotalAvailable - newAmount` ออกมาผิดหรือเป็นลบ

```csharp
// BudgetService.cs ~line 13882–13885
decimal? finalRemainingAmount = 0m;
if (currentTotalAvailable.HasValue)
{
    finalRemainingAmount = currentTotalAvailable.Value - (currentHeader.Totaltransferamount ?? 0m);
}
```

#### สาเหตุรอง (B): `TransferInItemViewModel` ไม่มี field `RemainingBudget`

Frontend ส่ง `RemainingBudget` ใน `TransferInItems[]` แต่ class `TransferInItemViewModel`  
(`OAGBudget.Models/ViewModel/BudgetAdjustDetailViewModel.cs` ~line 109–129)  
ไม่มี property `RemainingBudget` → ค่าถูกตัดทิ้งระหว่าง JSON deserialization  
ทำให้ `giverItem.RemainingBudget = 0` เสมอ

Backend ใช้ `giverItem.RemainingBudget` เป็น fallback เท่านั้น (line 13887–13889):
```csharp
else if (giverItem.RemainingBudget > 0)
{
    finalRemainingAmount = giverItem.RemainingBudget - (currentHeader.Totaltransferamount ?? 0m);
}
```
แต่ถ้า `currentTotalAvailable` มีค่า (กรณีปกติ) บรรทัดนี้จะไม่ถูกใช้

#### สาเหตุรอง (C): ค่า `remainingBudget` ที่แสดงในตาราง ≠ ยอดหลังหัก

Frontend เก็บ `remainingBudget` ของแต่ละแถวเป็น:
```javascript
remainingBudget: $('#TotalBudgetGiver').val() || '-',  // ~line 1252
```
ซึ่งคือ **ยอดรวมก่อนโอน** ไม่ใช่ยอดหลังหัก (TotalBudgetGiver − ยอดโอน)  
ทำให้คอลัมน์ "ยอดคงเหลือ" ในตารางแสดงไม่ตรงกับที่ DB เก็บจริง

---

### ปัญหาที่ 2 — กดยืนยัน (Confirm) ไม่ได้ เพราะ JavaScript Scope Error

**สาเหตุหลัก**: `newData` ถูกประกาศด้วย `const` ภายใน `$('#btnSave').on('click', ...)` (block scope)

```javascript
// ใน Save handler (~line 838) — block-scoped
const newData = {
    TransferInItems: (transferInRows || []).map(...)
};
```

แต่ Confirm handler (~line 798) อ้างถึง `newData.TransferInItems`:
```javascript
// ใน Confirm handler (~line 797–798) — อ้างถึง newData ที่ไม่มีใน scope นี้
IsConfirm: true,
TransferInItems: newData.TransferInItems  // ❌ ReferenceError: newData is not defined
```

เมื่อ Confirm handler ทำงาน `newData` ไม่ถูก define → `dataList` object สร้างไม่สำเร็จ  
→ `SaveBudgetAdjustDetail(dataList)` ไม่ถูกเรียก → confirm ไม่สามารถทำงานได้

---

### ปัญหาที่ 3 — ตัดยอดโอนออกจาก `BudgetReceive` ไม่ได้

**สาเหตุ**: สืบเนื่องจากปัญหาที่ 2 โดยตรง

ตัดยอด `Totalbalanceamount` ของ sender rows จะเกิดขึ้นเฉพาะเมื่อ `isConfirm = true` เท่านั้น:
```csharp
// BudgetService.cs ~line 13776–13796
if (isConfirm)
{
    foreach (var r in senderRows)
    {
        ...
        r.Totalbalanceamount = bal - cut;
        r.Totaltransferamount = (r.Totaltransferamount ?? 0m) + cut;
        ...
    }
}
```

เนื่องจาก Confirm ไม่ทำงาน (ปัญหาที่ 2) → `isConfirm = true` ไม่เคยถึง backend  
→ `Totalbalanceamount` ของ sender ไม่ถูกลดลงเลย

---

### ปัญหาที่ 4 — แถบ "ศูนย์โอนเปลี่ยนแปลง" ที่ ref จาก โอนกลับ ยังไม่ทำงาน

**สาเหตุ**: สืบเนื่องจากปัญหาที่ 2 และ 3

- เมื่อ Confirm ไม่ทำงาน → ไม่มีการสร้าง `BudgetReceive` type `"J"` พร้อม `Totalreceiveamount`/`Totalbalanceamount` จริง
- ระบบ "โอนกลับ" อาศัยข้อมูล `BudgetReceive` type `"J"` ที่ถูก confirm แล้วเป็น reference
- ไม่มีข้อมูลต้นทาง → แถบ "ศูนย์โอนเปลี่ยนแปลง" ไม่มีข้อมูลให้แสดง

---

## แผนการแก้ไข (Roadmap)

### ลำดับการแก้ไข

```
ปัญหาที่ 2 (JavaScript Scope) ← แก้ก่อน เพราะ unblock ทุกอย่าง
    ↓
ปัญหาที่ 1A (Confirm handler ส่ง Giver key ผิด)
    ↓
ปัญหาที่ 1B+1C (TransferInItemViewModel + remainingBudget display)
    ↓
ปัญหาที่ 3 (ตัดยอด BudgetReceive) ← จะทำงานหลังจาก 2 แก้แล้ว
    ↓
ปัญหาที่ 4 (ศูนย์โอนเปลี่ยนแปลง) ← จะทำงานหลังจาก 2+3 แก้แล้ว
```

---

### Step 1 — แก้ JavaScript Scope (แก้ปัญหาที่ 2)

**ไฟล์**: `OAGBudget/Views/Budget/BudgetAdjustDetail_TransferIn.cshtml`

**วิธีแก้**: ย้ายตัวแปรที่เก็บ `TransferInItems` ออกไปเป็น module-level variable  
ที่ทั้ง Save handler และ Confirm handler เข้าถึงได้

แนวทาง:
1. ประกาศ `let lastTransferInItems = [];` ในระดับ module (นอก click handlers)
2. ใน Save handler: อัพเดต `lastTransferInItems = newData.TransferInItems`
3. ใน Confirm handler: ใช้ `TransferInItems: lastTransferInItems` แทน `newData.TransferInItems`

**ผล**: กด Confirm แล้ว `dataList` สร้างสำเร็จ → `SaveBudgetAdjustDetail` ถูกเรียก → backend ได้รับ `isConfirm = true`

---

### Step 2 — แก้ Confirm Handler ส่ง Giver Key ผิด (แก้ปัญหาที่ 1A)

**ไฟล์**: `OAGBudget/Views/Budget/BudgetAdjustDetail_TransferIn.cshtml`

**วิธีแก้**: ใน `$('#btn-Confirm').on('click', ...)` handler แก้ element ID ของ Giver ให้ถูกต้อง

```javascript
// ❌ ผิด
CostcenteridGiver: $('#CostCenterIdRecive').val(),
DepartmentidGiver: $('#DepartmentIdRecive').val(),

// ✅ ถูก
CostcenteridGiver: $('#CostCenterId').val(),
DepartmentidGiver: $('#DepartmentId').val(),
```

หมายเหตุ: ต้องตรวจสอบ element IDs จริงในหน้าจอว่าชื่อ `CostCenterId` และ `DepartmentId` ตรงกับ Giver's field หรือไม่

**ผล**: Backend query `senderRows` ด้วย key ที่ถูกต้อง → `currentTotalAvailable` ถูกต้อง → `finalRemainingAmount` ถูกต้อง

---

### Step 3 — แก้ TransferInItemViewModel + remainingBudget (แก้ปัญหาที่ 1B, 1C)

**ไฟล์ 1**: `OAGBudget.Models/ViewModel/BudgetAdjustDetailViewModel.cs`

เพิ่ม `RemainingBudget` ใน `TransferInItemViewModel`:
```csharp
public class TransferInItemViewModel
{
    ...
    public decimal RemainingBudget { get; set; }  // ← เพิ่ม
    public string? TotalBudgetGiver { get; set; }  // ← เพิ่ม (optional)
}
```

**ไฟล์ 2**: `OAGBudget.API/Services/Repository/BudgetService.cs`

ใน `unifiedItems` mapping (line ~13447) ให้ copy `RemainingBudget` ด้วย:
```csharp
unifiedItems.AddRange(transferInItems.Select(x => new TransferOutItemViewModel
{
    Amount = x.Amount,
    CategoryId = x.CategoryId,
    PlanId = x.PlanId,
    OutputId = x.OutputId,
    ActivityId = x.ActivityId,
    BudgetTypeId = x.BudgetTypeId,
    AccountSegment = x.AccountSegment,
    RemainingBudget = x.RemainingBudget  // ← เพิ่ม
}));
```

**ไฟล์ 3**: Frontend `BudgetAdjustDetail_TransferIn.cshtml`

แก้การคำนวณ `remainingBudget` ในตาราง (line ~1252) ให้แสดงยอดหลังหัก:
```javascript
remainingBudget: (parseFloat(($('#TotalBudgetGiver').val() || '0').replace(/,/g,'')) - amountNum).toFixed(2)
```

---

### Step 4 — Verify ปัญหาที่ 3 และ 4 (ทำงานอัตโนมัติหลัง Step 1)

**ปัญหาที่ 3** (ตัดยอด BudgetReceive):
- หลัง Step 1 แก้แล้ว → Confirm ส่ง `isConfirm: true` ไปหลังบ้านได้  
- `if (isConfirm)` block ใน `SaveTransferModifyItem` จะทำงาน  
- `r.Totalbalanceamount = bal - cut` จะตัดยอดจาก sender rows  
- ✅ ตรวจสอบโดย query ดู `Totalbalanceamount` ใน `OagwbgBudgetreceive` หลัง Confirm

**ปัญหาที่ 4** (ศูนย์โอนเปลี่ยนแปลง):
- หลัง Step 1+3 → `BudgetReceive` type `"J"` ถูกสร้างพร้อมยอดจริง  
- ระบบ "โอนกลับ" มี source data → แถบ "ศูนย์โอนเปลี่ยนแปลง" แสดงได้  
- ✅ ตรวจสอบโดยเปิดหน้า BudgetTransferDetail และดูแถบที่ ref โอนกลับ

---

## สรุปไฟล์ที่ต้องแก้ไข

| ไฟล์ | การแก้ไข | ปัญหาที่แก้ |
|------|-----------|-------------|
| `BudgetAdjustDetail_TransferIn.cshtml` | ย้าย `transferInItems` เป็น module scope | ปัญหา 2 |
| `BudgetAdjustDetail_TransferIn.cshtml` | แก้ element ID ใน Confirm handler | ปัญหา 1A |
| `BudgetAdjustDetail_TransferIn.cshtml` | แก้การคำนวณ `remainingBudget` ในตาราง | ปัญหา 1C |
| `BudgetAdjustDetailViewModel.cs` | เพิ่ม `RemainingBudget` ใน `TransferInItemViewModel` | ปัญหา 1B |
| `BudgetService.cs` | Map `RemainingBudget` ใน `unifiedItems` | ปัญหา 1B |

ปัญหาที่ 3 และ 4 จะหายไปเองเมื่อปัญหา 2 ได้รับการแก้ไข

---

## ข้อมูลที่ต้องตรวจสอบเพิ่มเติม

1. **Element IDs ของ Giver fields** ในหน้า `BudgetAdjustDetail_TransferIn.cshtml`:
   - ยืนยันว่า `#CostCenterId` และ `#DepartmentId` คือ field ของฝั่ง Giver (โอนออก)
   - ยืนยันว่า `#CostCenterIdRecive` และ `#DepartmentIdRecive` คือ field ของฝั่ง Reciver (รับโอน)

2. **Logic ศูนย์โอนเปลี่ยนแปลง**: ตรวจสอบว่า backend ดึงข้อมูล "ศูนย์โอนเปลี่ยนแปลง"  
   จากที่ใด (อาจอยู่ใน `GetBudgetAdjustDetail` หรือ view `OagwbgVBudgettransferChanges`)  
   เพื่อยืนยันว่าหลังแก้ปัญหา 2+3 แล้วจะทำงานได้จริง

3. **GetBudgetBalanceAmount** ถูกเรียกจาก frontend ด้วย `method: 'POST'` (line ~1007)  
   แต่ controller ประกาศเป็น `[HttpGet]` (line 1697) — ควรตรวจสอบว่า endpoint นี้ตอบสนองได้จริงหรือไม่
