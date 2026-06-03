# Roadmap #144 — สิทธิศูนย์ต้นทุน: เพิ่มการเข้าถึงรายงานรายละเอียดการโอนเงินจัดสรรงบประมาณรายจ่ายประจำปี

## สาเหตุของปัญหา

ผู้ใช้งานที่มีสิทธิ **Role 11 (ศูนย์ต้นทุน)** ไม่สามารถเข้าถึงรายงาน "รายละเอียดการโอนเงินจัดสรรงบประมาณรายจ่ายประจำปี" ได้ เนื่องจากมี 3 สาเหตุหลัก:

### สาเหตุที่ 1 — สิทธิเมนู (Database)
Role 11 ยังไม่ได้รับสิทธิเข้าถึงหน้า `Report/ReportBudgetAllocateTransferDetail` ใน Database ผ่าน function `OAGWBG_FN_GETMENU_PERMISSION`  
ต้องเพิ่มสิทธิให้ Role 11 เข้าถึงเมนูนี้ได้ผ่านหน้าจัดการสิทธิใน System Admin

### สาเหตุที่ 2 — Service ไม่ filter ข้อมูลตาม หน่วยเบิกจ่าย (Code)
ใน `ReportService.cs` เมธอด `GetTransferDetailTypeAllocateTransfer()` (บรรทัด 5767) และ `GetTransferDetailTypeReserveTransfer()` (บรรทัด 5832) ไม่มีการกรองข้อมูลตาม `model.Departmentid` แม้ว่า parameter จะถูกส่งมาจาก View แล้ว ทำให้ Role 11 จะเห็นข้อมูลของทุกหน่วยงาน ไม่ใช่เฉพาะหน่วยเบิกจ่ายของตัวเอง

### สาเหตุที่ 3 — View ไม่ lock ศูนย์ต้นทุน และ Costcenterid ไม่ถูกส่งกลับเมื่อ lock (Code)
ใน `ReportBudgetAllocateTransferDetail.cshtml` มีการ lock ภาค (`RegionID`) และ หน่วยเบิกจ่าย (`Departmentid`) สำหรับ Role 11 แล้ว (บรรทัด 369–374, 432–453)  
แต่ **ศูนย์ต้นทุน (`Costcenterid`)** ไม่ถูก lock — Role 11 ควรเห็น dropdown ศูนย์ต้นทุนได้ทุกตัวในหน่วยเบิกจ่ายของตัวเอง และเลือกกรองได้อิสระ (ไม่ต้อง lock)

---

## ข้อสังเกตเพิ่มเติม

- ปัจจุบัน MVC Controller (`ReportController.cs` บรรทัด 659–690) ได้ตั้งค่า `Departmentid`, `Regionid`, `Costcenterid` ใน model จาก `userCur.Officer` ให้ Role 11 ไว้แล้ว — ส่วนนี้ถูกต้องแล้ว ไม่ต้องแก้
- Parameter **ใบโอนครั้งที่** (`TransferRound`) มีอยู่แล้วในฟอร์มและเป็น required field — ไม่ต้องเพิ่ม

---

## แผนการแก้ไข

### ขั้นตอนที่ 1 — เพิ่มสิทธิเมนูให้ Role 11 (Database / System Admin)

เปิดหน้าจัดการสิทธิใน System Admin แล้วให้สิทธิ Role 11 (ศูนย์ต้นทุน) เข้าถึงเมนู:
- Controller: `Report`
- Action: `ReportBudgetAllocateTransferDetail`

> ⚠️ **ต้องสอบถามว่าใช้หน้า Admin ไหนในการจัดการสิทธิเมนู** หรือต้อง insert ตรงเข้าฐานข้อมูล (ตาราง assign สิทธิ role กับ menu)

---

### ขั้นตอนที่ 2 — เพิ่ม filter Departmentid และ Costcenterid ใน Service

ไฟล์: `OAGBudget.API\Services\Repository\ReportService.cs`

#### 2.1 เมธอด `GetTransferDetailTypeAllocateTransfer()` บรรทัด ~5793
เพิ่มหลังบรรทัด filter `BudgetSourceID`:
```csharp
if (!string.IsNullOrEmpty(model.Departmentid))
    query = query.Where(x => x.Departmentid == model.Departmentid);

if (!string.IsNullOrEmpty(model.Costcenterid))
    query = query.Where(x => x.Costcenterid == model.Costcenterid);
```

#### 2.2 เมธอด `GetTransferDetailTypeReserveTransfer()` บรรทัด ~5867
เพิ่มหลังบรรทัด filter `BudgetSourceID`:
```csharp
if (!string.IsNullOrEmpty(model.Departmentid))
    query = query.Where(x => x.Departmentid == model.Departmentid);

if (!string.IsNullOrEmpty(model.Costcenterid))
    query = query.Where(x => x.Costcenterid == model.Costcenterid);
```

> ✅ ทั้ง `OagwbgRBudgetallocatetransfers` และ `OagwbgRBudgetTransfers` มี field `Departmentid` และ `Costcenterid` อยู่แล้ว

---

### ขั้นตอนที่ 3 — ไม่ต้องแก้ไข View (Costcenterid ไม่ต้อง lock)

Role 11 ต้องการเห็น **ทุกศูนย์ต้นทุนในหน่วยเบิกจ่ายของตัวเอง** และเลือกกรองได้อิสระ  
ดังนั้น **ไม่ต้อง lock `Costcenterid`** — ปล่อยให้ dropdown ทำงานตามปกติ (cascade จาก Departmentid ที่ถูก lock แล้ว)

> ✅ ผลลัพธ์: Role 11 จะเห็น dropdown ศูนย์ต้นทุนเฉพาะในหน่วยเบิกจ่ายของตัวเองโดยอัตโนมัติ เพราะ Departmentid ถูก lock ไว้แล้ว

---

## สรุปขอบเขตการแก้ไข

| # | ประเภท | ไฟล์/ระบบ | รายละเอียด |
|---|--------|-----------|-----------|
| 1 | Database | System Admin / DB | เพิ่มสิทธิเมนูให้ Role 11 เข้าถึง `ReportBudgetAllocateTransferDetail` |
| 2 | Code | `ReportService.cs` บรรทัด ~5793 | เพิ่ม filter `Departmentid` และ `Costcenterid` ใน `GetTransferDetailTypeAllocateTransfer()` |
| 3 | Code | `ReportService.cs` บรรทัด ~5867 | เพิ่ม filter `Departmentid` และ `Costcenterid` ใน `GetTransferDetailTypeReserveTransfer()` |
| 4 | — | `ReportBudgetAllocateTransferDetail.cshtml` | ไม่ต้องแก้ — Costcenterid cascade ตาม Departmentid ที่ lock ไว้แล้ว |

---

## คำถามก่อนแก้ไข

1. การเพิ่มสิทธิเมนูให้ Role 11 ทำผ่านหน้าไหน? (System Admin UI หรือ SQL ตรง?)
   - ✅ **ข้อ 2 ตอบแล้ว:** Role 11 เห็นทุกศูนย์ต้นทุนในหน่วยเบิกจ่ายของตัวเอง (ไม่ lock Costcenterid)

---

## ข้อควรระวัง

- filter `Departmentid`/`Costcenterid` ที่เพิ่มเป็น optional (ถ้าไม่มีค่าจะไม่กรอง) — สำหรับ role อื่นที่ไม่ใช่ Role 11 ยังคงเห็นข้อมูลทั้งหมดได้ตามเดิม
- ทดสอบกับ account ที่เป็น Role 11 จริงเพื่อยืนยัน cascade dropdown และการกรองข้อมูลทำงานถูกต้อง
