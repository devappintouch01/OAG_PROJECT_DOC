# Roadmap การแก้ไข: ขอจัดสรรเพิ่มเติม — หน้าจอหมุนนานมากเมื่อกดบันทึก

## สรุปปัญหา

เมื่อผู้ใช้บันทึกเอกสาร "ขอจัดสรรเพิ่มเติม" เป็นรอบที่ 2 (ส่งเรื่องไปแล้ว 1 รอบ → ส่งกลับ → แก้ไขยอดเงินและ/หรือเดือน → กดบันทึก) หน้าจอจะหมุนนานมาก

---

## ไฟล์ที่เกี่ยวข้อง

| ไฟล์ | หน้าที่ |
|------|---------|
| `OAGBudget\Views\Budget\BudgetRequestMoreCostcenterExpensesDetail.cshtml` | หน้า UI + ฟังก์ชัน `submitPage()` ที่ส่ง AJAX |
| `OAGBudget\Controllers\BudgetController.cs` บรรทัด 4624 | MVC Controller รับ request แล้วส่งต่อไป API |
| `OAGBudget.API\Services\Repository\BudgetService.cs` บรรทัด 22057 | `SaveBudgetRequestMoreCostcenterExpensesDetail` — จุดหลักของปัญหา |
| `OAGBudget.API\Services\Repository\BudgetService.cs` บรรทัด 22245 | `SaveBudgetMoreCostcenterGovernmentItem` |
| `OAGBudget.API\Services\Repository\BudgetService.cs` บรรทัด 22152 | `SaveBudgetDisbursementEstimate` |
| `OAGBudget.API\Services\Repository\BudgetService.cs` บรรทัด 1502 | `SaveBudgetGovernmentAssetItem` |
| `OAGBudget.API\Services\Repository\BudgetService.cs` บรรทัด 22381 | `SaveBudgetCodeMoreYear` |
| `OAGBudget.API\Services\Repository\AuthenService.cs` บรรทัด 283 | `ValidateTokenAndGetUserInfo` |

---

## สาเหตุหลักที่พบ (เรียงตามความรุนแรง)

### 🔴 สาเหตุที่ 1 (รุนแรงที่สุด) — `ValidateTokenAndGetUserInfo()` ถูกเรียก 5 ครั้งต่อการบันทึก 1 ครั้ง

**ที่ไหน:**  
ฟังก์ชัน Save ย่อยทุกตัวเรียก `_auth.ValidateTokenAndGetUserInfo()` แยกกัน:
- `SaveBudgetRequestMoreCostcenterExpensesDetail` (บรรทัด 22061)
- `SaveBudgetMoreCostcenterGovernmentItem` (บรรทัด 22249)
- `SaveBudgetDisbursementEstimate` (บรรทัด 22163)
- `SaveBudgetGovernmentAssetItem` (บรรทัด 1506)
- `SaveBudgetCodeMoreYear` (บรรทัด 22385)

**`ValidateTokenAndGetUserInfo()` ทำอะไร (AuthenService.cs บรรทัด 283):**
ทุกครั้งที่เรียก จะยิง DB query ไป Oracle 3 รอบ:
1. `OagwbgSystemusers.FirstOrDefaultAsync(x => x.Username == userId)`
2. `OagwbgVExtOagglCostCenterVs.FirstOrDefaultAsync(x => x.Id == user.Costcenterid)`
3. `OagwbgVSystemuserroleassigns...FirstAsync()`

**ผลกระทบ:** 5 × 3 = **15 DB queries เพิ่มเติมเฉพาะ Auth** ต่อการกดบันทึก 1 ครั้ง

---

### 🔴 สาเหตุที่ 2 (รุนแรงมาก) — `MaxAsync` สแกนทั้งตาราง `OAGWBG_BudgetDisbursementEstimated`

**ที่ไหน:** `SaveBudgetDisbursementEstimate` บรรทัด 22175:
```csharp
var currentMaxId = await _context.OagwbgBudgetdisbursementestimated.MaxAsync(x => (int?)x.Id) ?? 0;
```

**ปัญหา:** Query นี้สแกนทั้งตาราง `OAGWBG_BudgetDisbursementEstimated` เพื่อหาค่า MAX(ID) โดยไม่มี WHERE clause เลย  
ตารางนี้สะสมข้อมูลของทุก BudgetGovernment ทุกปีงบประมาณ เมื่อข้อมูลมากขึ้นเรื่อย ๆ query นี้จะช้าลงเรื่อย ๆ

**หมายเหตุ:** มีฟังก์ชัน `SaveBudgetDisbursementEstimate` เวอร์ชันเก่า (บรรทัด ~20419, ~20611, ~21001) ที่ใช้รูปแบบเดียวกัน แต่เวอร์ชันปัจจุบัน (22152) ดึง existingRecords มาเปรียบเทียบใน memory แล้ว ซึ่งดีขึ้น แต่ยังมี MaxAsync ที่ Full Table Scan อยู่

---

### 🟠 สาเหตุที่ 3 (รุนแรงปานกลาง) — `SaveChangesAsync()` ถูกเรียก 4–5 ครั้งแยกกัน

**ที่ไหน:** ใน `SaveBudgetRequestMoreCostcenterExpensesDetail` บรรทัด 22057 เรียก sub-method ต่อไปนี้แบบ sequential:

```
บรรทัด 22084: SaveChangesAsync()                    ← อัปเดต BudgetGovernment
บรรทัด 22134: SaveBudgetMoreCostcenterGovernmentItem → SaveChangesAsync() (22344)
บรรทัด 22135: SaveBudgetDisbursementEstimate         → SaveChangesAsync() (22232)
บรรทัด 22136: SaveBudgetGovernmentAssetItem          → SaveChangesAsync() (1603)
บรรทัด 22137: SaveBudgetCodeMoreYear                 → SaveChangesAsync() (22438)
```

แต่ละ `SaveChangesAsync()` คือ 1 DB transaction round-trip ไป Oracle  
รวม **5 round-trips** ที่ต้องรอทีละรอบ

---

### 🟠 สาเหตุที่ 4 (รุนแรงปานกลาง) — Max Running Number ไม่ filter ด้วย GovernmentId

**ที่ไหน:** `SaveBudgetMoreCostcenterGovernmentItem` บรรทัด 22255–22258:
```csharp
var lastRunning = await _context.OagwbgBudgetgovernmentitems
    .OrderByDescending(x => x.Running)
    .Select(x => x.Running)
    .FirstOrDefaultAsync() ?? 0;
```

**ปัญหา:** ดึงค่า Running สูงสุดจาก **ทั้งตาราง** `OAGWBG_BudgetGovernmentItem` โดยไม่ filter ด้วย `BudgetGovernmentId` ซึ่งอาจทำให้ตัวเลข Running ผิดพลาด และยังสแกนทั้งตารางโดยไม่จำเป็น

---

### 🟡 สาเหตุที่ 5 (รุนแรงน้อย) — `AddAsync` ใน `SaveBudgetGovernmentAssetItem` เรียก DB ซ้ำ

**ที่ไหน:** บรรทัด 1554–1584:
```csharp
addFuncAsync: async (s) =>
{
    var checkItem = await _context.OagwbgBudgetgovernmentassetitems
        .FirstOrDefaultAsync(x => x.Budgetyear == ...&& x.Assetid == s.Assetid ...);
    ...
}
```

**ปัญหา:** สำหรับแต่ละ Asset ใหม่ที่เพิ่ม จะยิง DB query ตรวจ duplicate ทีละรายการ (N+1 pattern) ถ้ามี asset หลายชิ้น จะยิง query หลายรอบ

---

## แผนการแก้ไข (เรียงตามลำดับความสำคัญ)

### แก้ไขที่ 1 — ส่ง `userInfo` เป็น parameter แทนเรียก `ValidateTokenAndGetUserInfo()` ซ้ำ

**วิธีแก้:** เรียก `ValidateTokenAndGetUserInfo()` เพียงครั้งเดียวใน `SaveBudgetRequestMoreCostcenterExpensesDetail` แล้วส่ง `userInfo` เป็น parameter ให้ทุก sub-method

```csharp
// ใน SaveBudgetRequestMoreCostcenterExpensesDetail
var userInfo = await _auth.ValidateTokenAndGetUserInfo();  // ← เรียกครั้งเดียว

await SaveBudgetMoreCostcenterGovernmentItem(data, userInfo);
await SaveBudgetDisbursementEstimate(..., userInfo);
await SaveBudgetGovernmentAssetItem(..., userInfo);
await SaveBudgetCodeMoreYear(data, userInfo);
```

**ผลลัพธ์:** ลด DB queries ลง **12 queries** (จาก 15 เหลือ 3)

---

### แก้ไขที่ 2 — เปลี่ยนการหา Max ID ใน `SaveBudgetDisbursementEstimate`

**วิธีแก้:** ใช้ Oracle Sequence หรือ `GENERATED BY DEFAULT AS IDENTITY` แทนการ MaxAsync  
หรือถ้ายังต้องใช้วิธีเดิม ให้ filter ด้วย condition ที่เหมาะสมหรือ cache ค่าไว้

```csharp
// แนะนำ: ให้ Oracle จัดการ ID อัตโนมัติ (ถ้า schema รองรับ)
// หรือ: ใช้ sequence ที่มีอยู่แล้ว
// หรือ: เปลี่ยนเป็น Id = 0 แล้วปล่อยให้ EF Core + Oracle Sequence จัดการ
```

**ผลลัพธ์:** หลีกเลี่ยง Full Table Scan บนตารางขนาดใหญ่

---

### แก้ไขที่ 3 — รวม `SaveChangesAsync()` เป็น 1 ครั้ง

**วิธีแก้:** ให้ sub-method ทุกตัวแค่ Add/Update/Remove entities ลงใน context โดยไม่เรียก `SaveChangesAsync()` เอง แล้วเรียก `SaveChangesAsync()` ครั้งเดียวตอนท้ายใน method หลัก

```csharp
// ใน SaveBudgetRequestMoreCostcenterExpensesDetail
// ... (update budgetGovernment, ยังไม่ SaveChanges)
await SaveBudgetMoreCostcenterGovernmentItem(data, userInfo);    // ← ไม่ SaveChanges
await SaveBudgetDisbursementEstimate(...);                        // ← ไม่ SaveChanges
await SaveBudgetGovernmentAssetItem(...);                         // ← ไม่ SaveChanges
await SaveBudgetCodeMoreYear(data, userInfo);                     // ← ไม่ SaveChanges
await _context.SaveChangesAsync();                                // ← SaveChanges ครั้งเดียว
```

**ผลลัพธ์:** ลด DB round-trips จาก 5 เหลือ 1

**ข้อควรระวัง:** ต้องตรวจสอบ logic ที่ใช้ `data.Id = budgetGovernment.Id` (บรรทัด 22132) เพราะการสร้าง record ใหม่ต้องการ Id ก่อน จึงยังต้อง `SaveChangesAsync()` รอบแรก (เฉพาะกรณี Insert ใหม่)

---

### แก้ไขที่ 4 — แก้ Max Running Number ใน `SaveBudgetMoreCostcenterGovernmentItem`

**วิธีแก้:** เพิ่ม filter `WHERE Budgetgovernmentid = data.Id` หรือ `WHERE Budgetrequestid = ...`

```csharp
var lastRunning = await _context.OagwbgBudgetgovernmentitems
    .Where(x => x.Budgetgovernmentid == data.Id)  // ← เพิ่ม filter
    .OrderByDescending(x => x.Running)
    .Select(x => x.Running)
    .FirstOrDefaultAsync() ?? 0;
```

---

## สรุปผลที่คาดหวังหลังแก้ไข

| หัวข้อ | ก่อนแก้ | หลังแก้ |
|--------|---------|---------|
| DB queries สำหรับ Auth | 15 queries | 3 queries |
| SaveChangesAsync round-trips | 4–5 ครั้ง | 1–2 ครั้ง |
| Full Table Scan MaxAsync | มี | ไม่มี |
| รวม DB calls โดยประมาณ | 25–35 calls | 8–12 calls |

---

## ผลการตรวจสอบ DB จริง (ตอบคำถามเพิ่มเติม)

ตรวจสอบจาก Connection: `172.16.11.18:1531 / PROD / OAGWBG`

| คำถาม | ผลที่พบ | ผลกระทบ |
|-------|---------|---------|
| จำนวนแถว `OAGWBG_BUDGETDISBURSEMENTESTIMATED` | **12 แถว** (ข้อมูลน้อย แต่จะสะสมมากขึ้นทุกปี) | ยังไม่ช้ามากตอนนี้ แต่จะช้าขึ้นเรื่อย ๆ |
| ID column เป็น IDENTITY หรือไม่ | **ไม่ใช่** (IDENTITY_COLUMN = NO) | ต้องสร้าง Oracle Sequence ใหม่ |
| มี Oracle Sequence สำหรับตารางนี้หรือไม่ | **ไม่มี** sequence ที่ตรงชื่อ ไม่มี `ISEQ$$_` สำหรับตารางนี้ | ต้อง `CREATE SEQUENCE` ใหม่ |
| Index บน `BUDGETGOVERNMENTID` ของ `OAGWBG_BUDGETDISBURSEMENTESTIMATED` | **ไม่มี** — มีแค่ PK index บน `ID` | **Full Table Scan ทุกครั้ง** ที่ query `WHERE BUDGETGOVERNMENTID = ?` |
| Index บน `BUDGETGOVERNMENTID` ของ `OAGWBG_BUDGETGOVERNMENTITEM` | **ไม่มี** — มีแค่ PK index `PK_BUDGETGOVERNMENTITEM` บน `ID` | **Full Table Scan บน 24,137 แถว** ทุกครั้งที่ดึง items |
| จำนวนแถว `OAGWBG_BUDGETGOVERNMENTITEM` | **24,137 แถว** | กระทบมาก เพราะ query ไม่มี index |
| จำนวนแถว `OAGWBG_BUDGETGOVERNMENT` | **18,398 แถว** | ข้อมูลมาก |

---

## แผนการแก้ไขที่ปรับปรุงใหม่ (เรียงตามลำดับความสำคัญ)

### 🔴 แก้ไขที่ 0 (เร็วที่สุด ผลชัดที่สุด) — สร้าง Index บน `BUDGETGOVERNMENTID`

**ปัญหาที่พบจาก DB:** ทั้ง 2 ตารางหลักที่ query บ่อยไม่มี index บน `BUDGETGOVERNMENTID` เลย

```sql
-- สร้าง index บน OAGWBG_BUDGETDISBURSEMENTESTIMATED
CREATE INDEX IDX_DISBEST_BUDGETGOVID
ON OAGWBG_BUDGETDISBURSEMENTESTIMATED (BUDGETGOVERNMENTID);

-- สร้าง index บน OAGWBG_BUDGETGOVERNMENTITEM
CREATE INDEX IDX_GOVITEM_BUDGETGOVID
ON OAGWBG_BUDGETGOVERNMENTITEM (BUDGETGOVERNMENTID);
```

**ผลลัพธ์:** Query `WHERE BUDGETGOVERNMENTID = ?` จาก Full Table Scan → Index Range Scan  
ช่วยได้ใน `SaveBudgetMoreCostcenterGovernmentItem`, `SaveBudgetDisbursementEstimate`, `SaveBudgetGovernmentAssetItem`  
**ทำได้ทันทีโดยไม่ต้องแก้โค้ด**

---

### 🔴 แก้ไขที่ 1 — ส่ง `userInfo` เป็น parameter แทนเรียก `ValidateTokenAndGetUserInfo()` ซ้ำ

**วิธีแก้:** เรียก `ValidateTokenAndGetUserInfo()` เพียงครั้งเดียวใน `SaveBudgetRequestMoreCostcenterExpensesDetail` แล้วส่ง `userInfo` เป็น parameter ให้ทุก sub-method

```csharp
// ใน SaveBudgetRequestMoreCostcenterExpensesDetail
var userInfo = await _auth.ValidateTokenAndGetUserInfo();  // ← เรียกครั้งเดียว

await SaveBudgetMoreCostcenterGovernmentItem(data, userInfo);
await SaveBudgetDisbursementEstimate(..., userInfo);
await SaveBudgetGovernmentAssetItem(..., userInfo);
await SaveBudgetCodeMoreYear(data, userInfo);
```

**ผลลัพธ์:** ลด DB queries ลง **12 queries** (จาก 15 เหลือ 3)

---

### 🔴 แก้ไขที่ 2 — สร้าง Oracle Sequence และเปลี่ยน `MaxAsync` ใน `SaveBudgetDisbursementEstimate`

**ที่มา:** ID column ไม่ใช่ IDENTITY และไม่มี Sequence รองรับ ทำให้โค้ดต้อง `MaxAsync` ทั้งตารางทุกครั้ง

```sql
-- สร้าง Sequence ใหม่ (กำหนด START WITH ให้สูงกว่าค่า MAX(ID) ปัจจุบัน)
CREATE SEQUENCE SEQ_OAGWBG_BUDGETDISBURSEMENTESTIMATED
  START WITH 100
  INCREMENT BY 1
  NOCACHE
  NOCYCLE;
```

```csharp
// แทนที่ MaxAsync ด้วย Oracle Sequence ผ่าน raw SQL
var nextId = await _context.Database
    .ExecuteSqlRawAsync("SELECT SEQ_OAGWBG_BUDGETDISBURSEMENTESTIMATED.NEXTVAL FROM DUAL");
// หรือ: ปล่อยให้ EF Core จัดการโดย map sequence ใน OnModelCreating
```

**ผลลัพธ์:** ไม่มี Full Table Scan เพื่อหา Max ID อีกต่อไป

---

### 🟠 แก้ไขที่ 3 — รวม `SaveChangesAsync()` เป็น 1 ครั้ง

**วิธีแก้:** ให้ sub-method ทุกตัวแค่ Add/Update/Remove entities ลงใน context โดยไม่เรียก `SaveChangesAsync()` เอง แล้วเรียก `SaveChangesAsync()` ครั้งเดียวตอนท้ายใน method หลัก

```csharp
// ใน SaveBudgetRequestMoreCostcenterExpensesDetail
// ... (update budgetGovernment, ยังไม่ SaveChanges)
await SaveBudgetMoreCostcenterGovernmentItem(data, userInfo);    // ← ไม่ SaveChanges
await SaveBudgetDisbursementEstimate(...);                        // ← ไม่ SaveChanges
await SaveBudgetGovernmentAssetItem(...);                         // ← ไม่ SaveChanges
await SaveBudgetCodeMoreYear(data, userInfo);                     // ← ไม่ SaveChanges
await _context.SaveChangesAsync();                                // ← SaveChanges ครั้งเดียว
```

**ผลลัพธ์:** ลด DB round-trips จาก 5 เหลือ 1–2

**ข้อควรระวัง:** กรณี Insert ใหม่ (`data.Id == 0`) ต้องการ Id หลัง Insert ก่อน จึงยังต้อง `SaveChangesAsync()` รอบแรก 1 ครั้ง

---

### 🟠 แก้ไขที่ 4 — แก้ Max Running Number ใน `SaveBudgetMoreCostcenterGovernmentItem`

**วิธีแก้:** เพิ่ม filter เพื่อไม่สแกนทั้งตาราง

```csharp
var lastRunning = await _context.OagwbgBudgetgovernmentitems
    .Where(x => x.Budgetgovernmentid == data.Id)  // ← เพิ่ม filter
    .OrderByDescending(x => x.Running)
    .Select(x => x.Running)
    .FirstOrDefaultAsync() ?? 0;
```

---

## สรุปผลที่คาดหวังหลังแก้ไข

| หัวข้อ | ก่อนแก้ | หลังแก้ |
|--------|---------|---------|
| DB queries สำหรับ Auth | 15 queries | 3 queries |
| SaveChangesAsync round-trips | 4–5 ครั้ง | 1–2 ครั้ง |
| Full Table Scan MaxAsync | มี | ไม่มี |
| Full Table Scan บน 24,137 แถว (GOVITEM) | มี | ไม่มี (หลังสร้าง index) |
| Full Table Scan บน DISBURSEMENT | มี | ไม่มี (หลังสร้าง index) |
| รวม DB calls โดยประมาณ | 25–35 calls | 6–10 calls |

---

## แผนการ Verify ผลการแก้ไข

### ขั้นตอนที่ 1 — ตรวจสอบ DB Objects บน preprod

```sql
-- ยืนยัน Index ถูกสร้างแล้ว
SELECT INDEX_NAME, TABLE_NAME, STATUS
FROM ALL_INDEXES
WHERE TABLE_OWNER = 'OAGWBG'
  AND INDEX_NAME IN ('IDX_DISBEST_BUDGETGOVID', 'IDX_GOVITEM_BUDGETGOVID');

-- ยืนยัน Sequence ถูกสร้างแล้ว
SELECT SEQUENCE_NAME, LAST_NUMBER
FROM ALL_SEQUENCES
WHERE SEQUENCE_OWNER = 'OAGWBG'
  AND SEQUENCE_NAME = 'SEQ_OAGWBG_BUDGETDISBURSEMENTESTIMATED';
```

**ผลที่ต้องการ:** ได้ 2 rows จาก ALL_INDEXES และ 1 row จาก ALL_SEQUENCES

---

### ขั้นตอนที่ 2 — Functional Test: บันทึกรอบแรก (ปกติ)

**สถานการณ์:** สร้าง BudgetRequest ใหม่ → เพิ่มรายการค่าใช้จ่าย → กรอกยอดเงิน + เดือน → กดบันทึก

| จุดตรวจสอบ | วิธีตรวจ | ผลที่ต้องการ |
|-----------|---------|------------|
| บันทึกสำเร็จ | ดู popup "บันทึกสำเร็จ" | แสดง popup และ redirect |
| ข้อมูลถูกบันทึก | Query `SELECT * FROM OAGWBG_BUDGETGOVERNMENT WHERE ID = ?` | มีข้อมูล |
| ประมาณการเงินถูกบันทึก | Query `SELECT * FROM OAGWBG_BUDGETDISBURSEMENTESTIMATED WHERE BUDGETGOVERNMENTID = ?` | มีข้อมูลแต่ละเดือน |
| ID ของ DISBURSEMENTESTIMATED | ตรวจค่า ID ที่ถูก insert | ต้องมาจาก Sequence (≥ 200 สำหรับ preprod) |

---

### ขั้นตอนที่ 3 — Functional Test: บันทึกรอบสอง (กรณีที่มีปัญหา)

**สถานการณ์:** ส่งเรื่อง → ส่งเรื่องกลับ → แก้ไขยอดเงิน + เปลี่ยนเดือน → กดบันทึก

| จุดตรวจสอบ | วิธีตรวจ | ผลที่ต้องการ |
|-----------|---------|------------|
| ความเร็วในการบันทึก | จับเวลาตั้งแต่กดบันทึกจนถึง popup สำเร็จ | **ไม่เกิน 5 วินาที** (เทียบกับก่อนแก้ที่หมุนนานมาก) |
| ยอดเงินถูกอัปเดต | Query `SELECT PLANAMOUNT, MONTH FROM OAGWBG_BUDGETDISBURSEMENTESTIMATED WHERE BUDGETGOVERNMENTID = ?` | ตรงกับที่กรอกในหน้าจอ |
| เดือนที่เปลี่ยนถูกบันทึก | ดูข้อมูลใน DB | เดือนใหม่มีข้อมูล เดือนเก่าหายไปหรืออัปเดต |
| ไม่มี Duplicate Key Error | ดู SQL ด้านล่าง | ไม่มี error + 0 rows จาก duplicate check |
| Sequence ถูกใช้งาน | Query `SELECT LAST_NUMBER FROM ALL_SEQUENCES WHERE SEQUENCE_NAME = 'SEQ_OAGWBG_BUDGETDISBURSEMENTESTIMATED'` | ค่าเพิ่มขึ้นจากก่อนบันทึก |

#### วิธี Verify ไม่มี Duplicate Key แบบละเอียด

**ก่อนบันทึก** — จดค่าเหล่านี้ไว้:

```sql
-- จด LAST_NUMBER ของ Sequence
SELECT LAST_NUMBER AS SEQ_BEFORE
FROM ALL_SEQUENCES
WHERE SEQUENCE_OWNER = 'OAGWBG'
  AND SEQUENCE_NAME = 'SEQ_OAGWBG_BUDGETDISBURSEMENTESTIMATED';

-- จด MAX(ID) ที่มีอยู่แล้วสำหรับ record นี้
SELECT MAX(ID) AS MAX_ID_BEFORE
FROM OAGWBG_BUDGETDISBURSEMENTESTIMATED
WHERE BUDGETGOVERNMENTID = <BudgetGovernmentId ที่ทดสอบ>;
```

**หลังบันทึก** — ตรวจ 3 จุด:

```sql
-- 1. Sequence เลื่อนขึ้นตามจำนวนเดือนที่ INSERT ใหม่
--    (ถ้า INSERT 3 เดือนใหม่ → LAST_NUMBER ต้องเพิ่มขึ้น 3)
SELECT LAST_NUMBER AS SEQ_AFTER
FROM ALL_SEQUENCES
WHERE SEQUENCE_OWNER = 'OAGWBG'
  AND SEQUENCE_NAME = 'SEQ_OAGWBG_BUDGETDISBURSEMENTESTIMATED';

-- 2. ID ของ record ที่ INSERT ใหม่ ต้องมาจาก Sequence (>= 200) และไม่ซ้ำกัน
SELECT ID, MONTH, PLANAMOUNT
FROM OAGWBG_BUDGETDISBURSEMENTESTIMATED
WHERE BUDGETGOVERNMENTID = <BudgetGovernmentId ที่ทดสอบ>
ORDER BY ID;

-- 3. ตรวจ Duplicate ทั้งตาราง → ต้องได้ 0 rows
SELECT ID, COUNT(*) AS CNT
FROM OAGWBG_BUDGETDISBURSEMENTESTIMATED
GROUP BY ID
HAVING COUNT(*) > 1;
```

**ผลที่ต้องการ:**
- Query 1: `SEQ_AFTER` = `SEQ_BEFORE` + จำนวนเดือนที่ INSERT ใหม่
- Query 2: ID ใหม่ทุกตัว ≥ 200 และไม่ซ้ำกัน
- Query 3: **0 rows**

**Pre-condition ที่ต้องตรวจก่อน deploy** — Sequence ไม่ทับกับข้อมูลที่มีอยู่:

```sql
-- ต้องได้ 0 rows (MAX(ID) ปัจจุบัน < START WITH ของ Sequence)
SELECT COUNT(*) AS CONFLICT_COUNT
FROM OAGWBG_BUDGETDISBURSEMENTESTIMATED
WHERE ID >= 200;
-- preprod: MAX(ID) = 192 → ไม่ทับ START WITH 200 ✅
```

---

### ขั้นตอนที่ 4 — ตรวจสอบ Server Logs (ถ้าเข้าถึงได้)

ให้มองหา pattern เหล่านี้ใน log หลังการบันทึก:

```
// ก่อนแก้ จะเห็น ValidateTokenAndGetUserInfo ถูก log หลายครั้ง
// หลังแก้ ควรเห็นแค่ครั้งเดียว

// ตรวจสอบว่า Sequence ถูกเรียก
SELECT SEQ_OAGWBG_BUDGETDISBURSEMENTESTIMATED.NEXTVAL FROM DUAL
```

---

### ขั้นตอนที่ 5 — Regression Test: ฟีเจอร์อื่นที่ใช้ method เดียวกัน

method `SaveBudgetGovernmentAssetItem` ถูกเรียกจาก `SaveBudgetRequestExpensesDetail` ด้วย ต้องทดสอบ:

| ฟีเจอร์ | วิธีทดสอบ | ผลที่ต้องการ |
|--------|---------|------------|
| บันทึกรายการค่าใช้จ่ายปกติ (ไม่ใช่ MoreCostcenter) | เปิดหน้าบันทึกค่าใช้จ่ายแบบเดิม → กดบันทึก | บันทึกสำเร็จ ไม่มี error |
| Asset Replace ยังทำงานได้ | เพิ่ม/ลบ asset → บันทึก | บันทึกสำเร็จ ข้อมูล asset ถูก |

---

### เกณฑ์ตัดสิน (Pass/Fail)

| เกณฑ์ | Pass | Fail |
|-------|------|------|
| บันทึกรอบ 2 ไม่หมุนนาน | เสร็จภายใน 5 วินาที | ยังหมุนนานกว่า 10 วินาที |
| ไม่มี Duplicate Key Error | ไม่มี exception | มี ORA-00001 |
| ข้อมูลถูกต้อง | ยอดเงินและเดือนตรงกับที่กรอก | ข้อมูลผิดหรือหาย |
| Regression ไม่พัง | ฟีเจอร์อื่น save ได้ปกติ | มี error ที่ไม่เคยมีก่อน |

---

## การแก้ไขที่ดำเนินการแล้ว (preprod)

### DB Changes (172.16.11.19 / ebs_PRE)

| รายการ | SQL | สถานะ |
|--------|-----|-------|
| Index บน `OAGWBG_BUDGETDISBURSEMENTESTIMATED(BUDGETGOVERNMENTID)` | `CREATE INDEX IDX_DISBEST_BUDGETGOVID ...` | ✅ แล้ว |
| Index บน `OAGWBG_BUDGETGOVERNMENTITEM(BUDGETGOVERNMENTID)` | `CREATE INDEX IDX_GOVITEM_BUDGETGOVID ...` | ✅ แล้ว |
| Oracle Sequence สำหรับ `OAGWBG_BUDGETDISBURSEMENTESTIMATED.ID` | `CREATE SEQUENCE SEQ_OAGWBG_BUDGETDISBURSEMENTESTIMATED START WITH 200` | ✅ แล้ว |

### Code Changes

#### `OAGBudget.API\Services\Repository\BudgetService.cs`

| รายการ | รายละเอียด | สถานะ |
|--------|-----------|-------|
| `ValidateTokenAndGetUserInfo` เรียกครั้งเดียว | เพิ่ม `AccountModel userInfo = null` เป็น optional parameter ให้ทุก sub-method, ใช้ `userInfo ??= await _auth.ValidateTokenAndGetUserInfo()` | ✅ แล้ว |
| `MaxAsync` → Oracle Sequence | ใน `SaveBudgetDisbursementEstimate` เปลี่ยนจาก `MaxAsync` เป็น `SEQ_OAGWBG_BUDGETDISBURSEMENTESTIMATED.NEXTVAL FROM DUAL` ต่อ record | ✅ แล้ว |
| Running Number filter | `SaveBudgetMoreCostcenterGovernmentItem` เพิ่ม `.Where(x => x.Budgetgovernmentid == data.Id)` (2 จุด) | ✅ แล้ว |
| `SaveBudgetDisbursementEstimate` — INSERT/UPDATE/skip logic | PlanAmount=0 + มี record → UPDATE=0 (แสดง 0.00), PlanAmount=0 + ไม่มี record → skip (ไม่ INSERT), PlanAmount>0 → INSERT/UPDATE ตามปกติ | ✅ แล้ว |

#### `OAGBudget\wwwroot\js\number-utils.js`

| รายการ | รายละเอียด | สถานะ |
|--------|-----------|-------|
| `parsePrice` crash เมื่อรับค่าที่ไม่ใช่ string | เปลี่ยนจาก `price.replace(...)` เป็น `String(price).replace(...)` พร้อม null/undefined/empty check | ✅ แล้ว |

#### `OAGBudget\Views\Budget\BudgetRequestMoreCostcenterExpensesDetail.cshtml`

| รายการ | รายละเอียด | สถานะ |
|--------|-----------|-------|
| `planAmount \|\| 1` crash เมื่อ field ว่าง | เปลี่ยนเป็น `\|\| '0'` (string ไม่ใช่ number) | ✅ แล้ว |
| `id \|\| 1` ค่า default ผิด | เปลี่ยนเป็น `\|\| 0` | ✅ แล้ว |

### รายการที่ยังไม่ได้แก้

| รายการ | เหตุผล |
|--------|--------|
| รวม `SaveChangesAsync()` เป็น 1 ครั้ง | ซับซ้อน มี risk เรื่อง INSERT ใหม่ที่ต้องการ Id ก่อน รอ verify ผลจาก fix ปัจจุบันก่อน |
