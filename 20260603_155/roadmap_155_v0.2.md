# Roadmap การแก้ไข #155 — ค่า remainingamount ในตาราง BudgetAdjust ไม่ตรงกับที่แสดงหน้าบ้าน

## สรุปปัญหา

เมื่อผู้ใช้บันทึกรายการโอนงบประมาณ ค่า `Remainingamount` ที่ถูกบันทึกลงตาราง `OAGWBG_BUDGETADJUST` มีค่าไม่ตรงกับ `remainingbudget` ที่แสดงบน Modal ฝั่งหน้าบ้าน แม้ว่า Payload ที่ Frontend ส่งมาจะถูกต้อง

---

## การวิเคราะห์สาเหตุ (Root Cause)

### จุดเกิดปัญหา

**ไฟล์:** `OAGBudget.API\Services\Repository\BudgetService.cs`  
**เมธอด:** `SaveTransferModifyItem`  
**บรรทัด:** 13882–13890

```csharp
decimal? finalRemainingAmount = 0m;
if (currentTotalAvailable.HasValue)              // ← เงื่อนไขนี้เป็นจริงเสมอ
{
    finalRemainingAmount = currentTotalAvailable.Value - (currentHeader.Totaltransferamount ?? 0m);
}
else if (giverItem.RemainingBudget > 0)          // ← ไม่เคยถูก execute
{
    finalRemainingAmount = giverItem.RemainingBudget - (currentHeader.Totaltransferamount ?? 0m);
}
```

### สาเหตุหลัก: แหล่งข้อมูล (Data Source) ไม่ตรงกัน

| | แหล่งข้อมูล | ค่าที่ได้ |
|---|---|---|
| **CheckTotalBudget** (ที่หน้าบ้านใช้แสดงผล) | Oracle GL — `OagwbgVExtOagglAccountHierachiesVs` ผ่าน `GetTotalBudget()` | ยอดวงเงินตาม GL |
| **SaveTransferModifyItem** (ที่บันทึกลง DB) | ตารางภายใน — `OagwbgBudgetreceives.Totalbalanceamount` | ยอดคงเหลือตาม internal ledger |

ค่าสองแหล่งนี้อาจแตกต่างกันได้ ขึ้นอยู่กับสถานะการ sync ระหว่าง GL กับตารางภายในของระบบ

### สาเหตุรอง: ลำดับความสำคัญ (Priority) ของ Fallback ผิด

- `currentTotalAvailable` ถูกตั้งค่าเสมอเมื่อ `newAmount >= 0` (บรรทัด 13734) และมีแถวอยู่ใน `OagwbgBudgetreceives`
- ทำให้ branch `else if (giverItem.RemainingBudget > 0)` **ไม่ถูก execute ในทางปฏิบัติเลย**
- ค่า `RemainingBudget` ที่ Frontend ส่งมาอย่างถูกต้อง (มาจาก `CheckTotalBudget` / GL) จึงถูกละเลย

---

## แผนการแก้ไข

### ขั้นตอนที่ 1 — แก้ไข Priority ของ `finalRemainingAmount`

**ไฟล์:** `OAGBudget.API\Services\Repository\BudgetService.cs`  
**บรรทัด:** 13882–13890

**เปลี่ยนจาก:**
```csharp
decimal? finalRemainingAmount = 0m;
if (currentTotalAvailable.HasValue)
{
    finalRemainingAmount = currentTotalAvailable.Value - (currentHeader.Totaltransferamount ?? 0m);
}
else if (giverItem.RemainingBudget > 0)
{
    finalRemainingAmount = giverItem.RemainingBudget - (currentHeader.Totaltransferamount ?? 0m);
}
```

**เปลี่ยนเป็น:**
```csharp
decimal? finalRemainingAmount = 0m;
if (giverItem.RemainingBudget > 0)
{
    // ใช้ค่าจาก GL (ผ่าน CheckTotalBudget) ที่ Frontend ส่งมา เพื่อให้ตรงกับที่แสดงผลบน Modal
    finalRemainingAmount = giverItem.RemainingBudget - (currentHeader.Totaltransferamount ?? 0m);
}
else if (currentTotalAvailable.HasValue)
{
    // Fallback: ถ้า Frontend ไม่ได้ส่ง RemainingBudget มา ค่อยใช้จาก internal table
    finalRemainingAmount = currentTotalAvailable.Value - (currentHeader.Totaltransferamount ?? 0m);
}
```

**เหตุผล:**  
`giverItem.RemainingBudget` คือค่าที่มาจาก `CheckTotalBudget` (Oracle GL) ซึ่งเป็นค่าเดียวกับที่แสดงบน Modal — การเก็บค่านี้ลง DB จึงถูกต้องตาม Business Logic  

### ขั้นตอนที่ 2 — ตรวจสอบว่า Frontend ส่ง RemainingBudget ครบทุก Path

**ไฟล์:** `OAGBudget\Views\Budget\BudgetAdjustDetail.cshtml`

| Path | บรรทัด | สถานะ |
|------|--------|-------|
| ปุ่มยืนยัน (IsConfirm=true) | 1082–1100 | ✅ ส่ง `RemainingBudget: remainNum` |
| ปุ่ม btnSave (Draft) | 1173–1191 | ⚠️ **ไม่ส่ง** `RemainingBudget` (comment บอกว่า "ดึงสดจาก OagwbgBudgetreceives") |

สำหรับ Draft save (btnSave) ไม่ส่ง `RemainingBudget` → Backend จะ fallback ไปใช้ `currentTotalAvailable` ซึ่งอาจ acceptable สำหรับ draft  
แต่ถ้าต้องการให้ consistent ควรส่ง `RemainingBudget` ใน Draft path ด้วยเช่นกัน

### ขั้นตอนที่ 3 — Verify การแก้ไข

1. **Unit Test:** เรียก `SaveTransferModifyItem` โดยส่ง `giverItem.RemainingBudget = X` แล้วตรวจว่า `BudgetAdjust.Remainingamount = X - transferAmount`
2. **End-to-End Test:**
   - เปิด Modal โอนงบประมาณ → กด "เช็คงบ" → บันทึกจำนวนที่แสดง (`remainingbudget`)
   - กดบันทึกรายการ → ตรวจ payload ใน DevTools ว่า `RemainingBudget` ตรง
   - ตรวจข้อมูลในตาราง `OAGWBG_BUDGETADJUST` ว่า `REMAININGAMOUNT = remainingbudget (จาก UI) - จำนวนที่โอน`
3. **ตรวจสอบ Edge Case:** กรณีที่ `giverItem.RemainingBudget = 0` (ไม่ได้เช็คงบก่อนบันทึก) → ควร fallback ไป `currentTotalAvailable` ได้ถูกต้อง

---

## สรุปไฟล์ที่ต้องแก้ไข

| ไฟล์ | บรรทัด | การแก้ไข | ความสำคัญ |
|------|--------|----------|-----------|
| `OAGBudget.API\Services\Repository\BudgetService.cs` | 13882–13890 | สลับ priority ของ if/else if | **จำเป็น** |
| `OAGBudget\Views\Budget\BudgetAdjustDetail.cshtml` | ~1183 | พิจารณาส่ง `RemainingBudget` ใน Draft save path ด้วย | พิจารณา |

---

## หมายเหตุเพิ่มเติม

- การแก้ไขนี้ไม่กระทบ Logic การตัดยอด `OagwbgBudgetreceives.Totalbalanceamount` (ยังคง validate และตัดยอดอยู่ที่บรรทัด 13767–13803 ตามเดิม)
- `currentTotalAvailable` ยังคงใช้สำหรับ **validation** (ตรวจว่ายอดพอหรือไม่) — ไม่ได้เปลี่ยนส่วนนั้น
- เฉพาะการ **บันทึก** `Remainingamount` เท่านั้นที่เปลี่ยน priority
