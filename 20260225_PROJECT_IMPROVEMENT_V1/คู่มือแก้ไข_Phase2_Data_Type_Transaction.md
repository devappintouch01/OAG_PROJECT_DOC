# Phase 2: ปิดวงจร Bug วนซ้ำ — Data Type + Transaction + Race Condition

> ระยะเวลา: 2-4 สัปดาห์ | ความเสี่ยง: ปานกลาง | ต้อง test ทุกหน้าที่แสดงยอดเงิน

---

## 2.1 Standardize Data Type เงินเป็น decimal ทั้งหมด

### ปัญหา
ยอดเงินใช้ 4 type ปนกัน → ทุกรอบที่ข้อมูลผ่าน API ยอดจะเพี้ยนจาก truncation

### จุดที่ต้องแก้ทั้งหมด:

---

#### 2.1a แก้ `OagwbgVBudgetreceive.Totalreservedamount` จาก long → decimal

**ไฟล์:** `OAGBudget.DAL/Models/OagwbgVBudgetreceive.cs`
**บรรทัด:** 37

```csharp
// แก้จาก:
public long? Totalreservedamount { get; set; }  // บรรทัด 37

// เป็น:
public decimal? Totalreservedamount { get; set; }
```

**แก้เพิ่มที่ DbContext:**
**ไฟล์:** `OAGBudget.DAL/Models/MOENDBContextBase.cs`
ค้นหา `Totalreservedamount` ใน entity configuration ของ `OagwbgVBudgetreceive` → เปลี่ยน column mapping ให้เป็น `HasPrecision(12, 2)` ถ้าเป็น `NUMBER(12)` ต้องเปลี่ยนเป็น `NUMBER(12,2)`

---

#### 2.1b แก้ Convert.ToInt64 ใน SaveBudgetReservedCentrall

**ไฟล์:** `OAGBudget.API/Services/Repository/BudgetService.cs`
**บรรทัด:** 16419, 16433

```csharp
// แก้จาก (บรรทัด 16419):
receiveToRefund.Totalreservedamount =
    (receiveToRefund.Totalreservedamount ?? 0L) - Convert.ToInt64(oldAmount);

// เป็น:
receiveToRefund.Totalreservedamount =
    (receiveToRefund.Totalreservedamount ?? 0m) - oldAmount;
```

```csharp
// แก้จาก (บรรทัด 16433):
receiveToDeduct.Totalreservedamount =
    (receiveToDeduct.Totalreservedamount ?? 0L) + Convert.ToInt64(newAmount);

// เป็น:
receiveToDeduct.Totalreservedamount =
    (receiveToDeduct.Totalreservedamount ?? 0m) + newAmount;
```

---

#### 2.1c แก้ ViewModel Mapping จาก decimal → int casting

**ไฟล์:** `OAGBudget.API/Services/Repository/BudgetService.cs`
**บรรทัด:** 15950-15951

```csharp
// แก้จาก:
Totalhaspoamount = data.Totalhaspoamount != null ? (int?)data.Totalhaspoamount : null,
Totalhaspramount = data.Totalhaspramount != null ? (int?)data.Totalhaspramount : null,

// เป็น:
Totalhaspoamount = data.Totalhaspoamount,
Totalhaspramount = data.Totalhaspramount,
```

**แก้เพิ่มที่ ViewModel:**
ตรวจสอบ property type ใน ViewModel ที่รับค่านี้ — ถ้าเป็น `int?` ต้องเปลี่ยนเป็น `decimal?`

---

#### 2.1d แก้ Totalbalanceamount = Totalreservedamount (ไม่หักเบิกจ่าย)

**ไฟล์:** `OAGBudget.API/Services/Repository/BudgetService.cs`
**บรรทัด:** 15263

```csharp
// แก้จาก:
header.Totalbalanceamount = header.Totalreservedamount;  // ← reset ทุกครั้ง!

// เป็น: คำนวณ balance จาก reserved - เบิกจ่ายแล้ว
var totalDisbursed = await _context.OagwbgBudgetreserveditems
    .Where(x => x.Budgetreversedid == header.Id
        && x.Parentid == null
        && (x.Statusid == 90110))  // status เบิกจ่ายแล้ว
    .SumAsync(x => (x.Totalhaspoamount ?? 0m) + (x.Totalhaspramount ?? 0m));
header.Totalbalanceamount = header.Totalreservedamount - totalDisbursed;
```

*หมายเหตุ: ต้องตรวจสอบ status code ที่หมายถึง "เบิกจ่ายแล้ว" ให้ถูกต้องกับระบบจริง*

---

#### 2.1e แก้ OagwbgBudgetreserveditem.Statusid จาก decimal → int

**ไฟล์:** `OAGBudget.DAL/Models/OagwbgBudgetreserveditem.cs`
**บรรทัด:** 84

```csharp
// แก้จาก:
public decimal? Statusid { get; set; }

// เป็น:
public int? Statusid { get; set; }
```

ต้องแก้ DbContext mapping ให้ตรงกัน + ตรวจสอบทุกจุดที่เปรียบเทียบ `Statusid` ว่า cast ถูกต้อง

---

#### 2.1f ตรวจสอบ DbContext column precision

**ไฟล์:** `OAGBudget.DAL/Models/MOENDBContextBase.cs`
ค้นหาทุก column ที่ใช้ `HasPrecision(12)` โดยไม่มี scale:
```
grep -n "HasPrecision(12)" OAGBudget.DAL/Models/MOENDBContextBase.cs
```
แก้ทุก column เงินเป็น `HasPrecision(12, 2)` เพื่อรองรับ 2 ทศนิยม

---

### ทดสอบ Phase 2.1 ทั้งหมด
1. สร้างรายการกันเงิน ยอด 1,234,567.89 → ตรวจ DB ว่าเก็บ .89 ถูกต้อง
2. บันทึก → เปิดดู → บันทึกอีกรอบ → ตรวจว่ายอดไม่เปลี่ยน
3. ทำซ้ำ 5 รอบ → ยอดต้องยังเป็น 1,234,567.89 ไม่ใช่ 1,234,568
4. ตรวจหน้าจอ: กันเงิน, โอนจัดสรร, เบิกเงิน, แผนการใช้จ่าย, รายงาน

### Bug ที่ปิดได้
- **#274** (ยอดเงินสะสมไม่ขึ้น)
- **#306** (เงินกันส่วนกลางไม่แสดงยอดเงิน)
- **#308** (เปลี่ยนประเภทหนี้แล้วยอดไม่อัพเดต)

---

## 2.2 เพิ่ม Transaction ครอบ Confirm Operations

### ปัญหา
Confirm operations มี SaveChangesAsync หลายจุด โดยไม่มี Transaction → ถ้า fail กลางทาง ข้อมูลค้างครึ่งๆ

---

#### 2.2a ConfirmBudgetReserved (4 SaveChanges ไม่มี Transaction)

**ไฟล์:** `OAGBudget.API/Services/Repository/BudgetService.cs`
**บรรทัด:** 15530-15680

**SaveChanges ที่ไม่มี Transaction:**
- บรรทัด 15592 (อัพเดต items)
- บรรทัด 15618 (set Roundinterface = 1)
- บรรทัด 15631 (เพิ่ม Roundinterface)
- บรรทัด 15670 (อัพเดตหลัง SaveInterface สำเร็จ)

```csharp
// แก้: ครอบทั้ง method ด้วย Transaction
public async Task<ApiResultsModel> ConfirmBudgetReserved(BudgetReservedModel model)
{
    // เพิ่ม: สร้าง execution strategy สำหรับ Oracle
    var strategy = _context.Database.CreateExecutionStrategy();
    return await strategy.ExecuteAsync(async () =>
    {
        using var transaction = await _context.Database.BeginTransactionAsync();
        try
        {
            // ... code เดิมทั้งหมด ...

            await transaction.CommitAsync();
            return result;
        }
        catch
        {
            await transaction.RollbackAsync();
            throw;
        }
    });
}
```

---

#### 2.2b ConfirmBudgetAllocateTransfer (ไม่มี Transaction + เรียก Oracle SP)

**ไฟล์:** `OAGBudget.API/Services/Repository/BudgetService.cs`
**บรรทัด:** 13891

```csharp
// แก้เหมือน 2.2a: ครอบด้วย Transaction
// หมายเหตุ: Oracle SP ที่เรียกภายใน method จะ commit เอง
// ดังนั้น Transaction นี้จะครอบเฉพาะ local DB changes
// ถ้า SP สำเร็จแต่ local fail → ต้องมี compensating logic
```

---

#### 2.2c UpdateBudgetOverlapStatus

**ไฟล์:** `OAGBudget.API/Services/Repository/BudgetService.cs`
**บรรทัด:** 16562

```csharp
// เพิ่ม Transaction wrapper เหมือน 2.2a
```

---

#### 2.2d SaveBudgetAllocateTransferCategory (3 SaveChanges ไม่มี Transaction)

**ไฟล์:** `OAGBudget.API/Services/Repository/BudgetService.cs`
**บรรทัด:** 8080

```csharp
// เพิ่ม Transaction wrapper เหมือน 2.2a
```

---

### ทดสอบ Phase 2.2
1. Confirm กันเงิน → ปกติ → ตรวจ Status + Roundinterface ถูกต้อง
2. จำลอง fail (เช่น ปิด EBS connection) → ตรวจว่า status ไม่เปลี่ยนกลางทาง
3. Confirm โอนจัดสรร → ตรวจ Totalbalanceamount ใน OagwbgBudgetreceive
4. ทดสอบ concurrent access — 2 คน Confirm พร้อมกัน

### Bug ที่ปิดได้
- **#309** (รายการค้างสถานะผิด)
- **#375** (ข้อมูลแสดงผิดกลุ่ม)

---

## 2.3 แก้ Race Condition เลขที่เงินกัน

### ปัญหา
2 คนกดพร้อมกัน → SELECT MAX ได้เลขเดียวกัน → เลขซ้ำ

### แก้ที่ไหน
**ไฟล์:** `OAGBudget.API/Services/Repository/BudgetService.cs`
**บรรทัด:** 15403-15449 (GenerateTransferNoAsync)

### วิธี A: ใช้ Oracle Sequence (แนะนำ)

**Step 1: สร้าง Sequence ใน Oracle**
```sql
-- สร้าง sequence แยกตาม prefix pattern
CREATE SEQUENCE OAGWBG_RESERVE_NO_SEQ
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- หรือ ใช้ตาราง running number ที่ lock ได้
CREATE TABLE OAGWBG_RUNNING_NO (
    PREFIX VARCHAR2(10) PRIMARY KEY,
    LAST_NO NUMBER(4) DEFAULT 0
);
```

**Step 2: แก้ GenerateTransferNoAsync**
```csharp
private async Task<string> GenerateTransferNoAsync(
    int fiscalYearBE, string? budgetReservedType, string? Region, string? ReservationType)
{
    var yyStr = (Math.Abs(fiscalYearBE) % 100).ToString("00");

    string typeCode = Region?.ToUpper() == "C" ? "3"
        : budgetReservedType?.ToUpper() switch
        {
            "R" => "1",
            "O" => "2",
            _ => "0"
        };

    string reservationTypeNo = ReservationType switch
    {
        "30" => "1",
        "20" => "2",
        _ => "0"
    };

    var prefix = yyStr + reservationTypeNo + typeCode;

    // ใช้ row-level lock แทน SELECT MAX
    var nextNo = await _context.Database
        .SqlQueryRaw<int>(@"
            DECLARE
                v_next NUMBER;
            BEGIN
                UPDATE OAGWBG_RUNNING_NO
                SET LAST_NO = LAST_NO + 1
                WHERE PREFIX = :prefix
                RETURNING LAST_NO INTO v_next;

                IF SQL%ROWCOUNT = 0 THEN
                    INSERT INTO OAGWBG_RUNNING_NO (PREFIX, LAST_NO)
                    VALUES (:prefix, 1)
                    RETURNING LAST_NO INTO v_next;
                END IF;

                :result := v_next;
            END;",
            new Oracle.ManagedDataAccess.Client.OracleParameter("prefix", prefix))
        .FirstAsync();

    return prefix + nextNo.ToString("0000");
}
```

### วิธี B: ใช้ Pessimistic Lock (ง่ายกว่า ไม่ต้องสร้างตาราง)
```csharp
// แก้ query ให้ lock ตาราง
var maxNo = await _context.Database
    .SqlQueryRaw<int?>(@"
        SELECT MAX(TO_NUMBER(SUBSTR(TRANSFERNO, -4)))
        FROM OAGWBG_BUDGETRESERVED
        WHERE TRANSFERNO LIKE :prefix || '%'
        FOR UPDATE",
        new Oracle.ManagedDataAccess.Client.OracleParameter("prefix", prefix))
    .FirstOrDefaultAsync();

var nextRunning = ((maxNo ?? 0) + 1).ToString("0000");
return prefix + nextRunning;
```

**เพิ่ม Unique Constraint:**
```sql
ALTER TABLE OAGWBG_BUDGETRESERVED
ADD CONSTRAINT UQ_BUDGET_RESERVED_TRANSFERNO UNIQUE (TRANSFERNO);
```

### Bug ที่ปิดได้
- **#312** (เลขที่เงินกัน format + ป้องกันซ้ำ)

---

## 2.4 แก้ Budget Check ไม่ให้ข้ามเมื่อ EBS ไม่ตอบ

### แก้ที่ไหน
**ไฟล์:** `OAGBudget.API/Services/Repository/BudgetService.cs`
**บรรทัด:** 8975

### Code เดิม
```csharp
// บรรทัด 8975
if (totalBudget != null && budgetReceive.Totalreceiveamount > totalBudget)
```

### แก้เป็น
```csharp
if (totalBudget == null)
{
    return new ApiResultsModel
    {
        Success = false,
        Message = "ไม่สามารถตรวจสอบงบประมาณได้ กรุณาลองใหม่อีกครั้ง",
        Type = "Error"
    };
}

if (budgetReceive.Totalreceiveamount > totalBudget)
{
    return new ApiResultsModel
    {
        Success = false,
        Message = $"ยอดเงินไม่เพียงพอ (ขอ: {budgetReceive.Totalreceiveamount:N2}, คงเหลือ: {totalBudget:N2})",
        Type = "Error"
    };
}
```

### Bug ที่ปิดได้
- **#96** (โอนปรับเปลี่ยน — การเช็คงบ)
