# Roadmap แก้ไขปัญหา OAG Budget — ระยะสั้น / กลาง / ยาว

> จากผลวิเคราะห์คุณภาพ Source Code เทียบกับ Bug List
> จัดลำดับตาม: ความเร่งด่วน × ผลกระทบ × ความเสี่ยงของการแก้

---

## ภาพรวม Roadmap

```
Phase 1: Quick Wins (1-2 สัปดาห์)
    → แก้จุดอันตรายที่ง่ายและไม่กระทบโครงสร้าง
    → ลด bug ค้างได้ ~8-10 รายการทันที

Phase 2: ปิด Bug วนซ้ำ (2-4 สัปดาห์)
    → แก้ Data Type + Transaction + Race Condition
    → ตัดวงจร bug ที่ยอดเงินเพี้ยน/ข้อมูลค้างครึ่งๆ

Phase 3: แยก God Class (4-8 สัปดาห์)
    → Refactor BudgetService.cs → Service ย่อยต่อ module
    → แก้จุดนี้ = แก้ต้นตอ bug ลามข้ามโมดูล

Phase 4: ปรับ Infrastructure (ต่อเนื่อง)
    → DbContext FK, Cache, Performance, Monitoring
    → ป้องกัน bug ชุดใหม่ไม่ให้เกิด
```

---

## Phase 1: Quick Wins (1-2 สัปดาห์)

> เป้าหมาย: แก้จุดอันตรายที่ไม่ต้องเปลี่ยนโครงสร้าง ใช้เวลาน้อย impact สูง

### 1.1 แก้ Hardcoded Date — ระเบิดเวลา
- **ไฟล์:** `OAGBudget.API/Services/Repository/BudgetService.cs` บรรทัด 9885-9886
- **ปัญหา:** `new DateTime(2026, 9, 30)` และ `new DateTime(2026, 10, 1)` hardcode ปีงบ 2026
- **แก้:** คำนวณจากปีงบประมาณปัจจุบัน
  ```csharp
  // แก้จาก:
  var step1Date = new DateTime(2026, 9, 30);
  var step2Date = new DateTime(2026, 10, 1);
  // เป็น:
  var fiscalYear = GetThaiFiscalYear(DateTime.Now);
  var step1Date = new DateTime(fiscalYear - 543, 9, 30);
  var step2Date = new DateTime(fiscalYear - 543, 10, 1);
  ```
- **ความเสี่ยง:** ต่ำ — เปลี่ยนแค่ 2 บรรทัด
- **Bug ที่ปิดได้:** ป้องกัน bug ใหม่ปีหน้า (กันเงินส่วนกลาง GL Interface)

### 1.2 แก้ Dead Code if/else — รายการหายจากหน้าจอ
- **ไฟล์:** `OAGBudget.API/Services/Repository/BudgetService.cs` บรรทัด 15893-15928
- **ปัญหา:** Status 90201/90102 ถูกจับที่ branch แรก → expandList ไม่มีทาง set
- **แก้:** แยก status ให้ถูก branch
  ```csharp
  // แก้: เอา 90201, 90102 ออกจาก if แรก ให้ตกไป else if
  if (data.Statusid == 90101 || data.Statusid == 90301 || ...)
  { overlapList = ... }
  else if (data.Statusid == 90201 || data.Statusid == 90102)
  { expandList = ... }
  ```
- **ความเสี่ยง:** ต่ำ — แก้ logic condition
- **Bug ที่ปิดได้:** #316 (หน้าจอขยายระยะเวลา), #321 (เพิ่ม Column PO กรณีขยาย)

### 1.3 แก้ IsAllCancle ที่คำนวณแล้วไม่ใช้
- **ไฟล์:** `OAGBudget.API/Services/Repository/BudgetService.cs` บรรทัด 16023-16024
- **แก้:** นำ IsAllCancle ไปใช้กำหนด status label
- **ความเสี่ยง:** ต่ำ
- **Bug ที่ปิดได้:** #309 (รายงานแสดงรายการยกเลิก)

### 1.4 แก้ SQL Injection ใน Budget Check
- **ไฟล์:** `OAGBudget.API/Services/Repository/BudgetService.cs` บรรทัด 12440-12444
- **แก้:** ใช้ parameterized query
  ```csharp
  // แก้จาก:
  cmd.CommandText = $"... P_I_CONCAT_SEGMENT => '{accountSegment.Trim()}' ...";
  // เป็น:
  cmd.CommandText = "... P_I_CONCAT_SEGMENT => :segment ...";
  cmd.Parameters.Add("segment", OracleDbType.Varchar2).Value = accountSegment.Trim();
  ```
- **ความเสี่ยง:** ต่ำ — เปลี่ยน query เป็น parameterized
- **Bug ที่ปิดได้:** ป้องกัน security vulnerability + เกี่ยวข้อง Bug #96

### 1.5 แก้ HttpClient Leak ใน MVC BudgetService
- **ไฟล์:** `OAGBudget/Services/Repository/BudgetService.cs` หลายจุด (1992, 2022, 6029, 6057 ฯลฯ)
- **แก้:** ใช้ `_httpClient` ที่ inject มาแทน `new HttpClient()`
  ```csharp
  // แก้จาก:
  var client = new HttpClient();
  client.Timeout = TimeSpan.FromMinutes(10);
  // เป็น: ใช้ _httpClient ที่ inject มาใน constructor
  ```
- **ความเสี่ยง:** ต่ำ — เปลี่ยน variable reference
- **ผล:** ระบบไม่ค้างเมื่อมีคนใช้พร้อมกัน

### 1.6 แก้ Deadlock `.GetAwaiter().GetResult()`
- **ไฟล์:** `OAGBudget/Services/Repository/BudgetService.cs` บรรทัด 6001
- **แก้:** เปลี่ยนเป็น `await`
  ```csharp
  // แก้จาก:
  var res = response.GetAwaiter().GetResult();
  // เป็น:
  var res = await _httpClient.SendAsync(request);
  ```
- **ความเสี่ยง:** ต่ำ

### 1.7 เปิด BudgetRequestMore ที่ถูก comment (ตรวจสอบก่อน)
- **ไฟล์:** `OAGBudget.API/Services/Repository/BudgetService.cs` บรรทัด 2328-2475
- **ตรวจสอบ:** ทำไมถึง comment ออก? ถ้าเป็น feature ที่ยังต้องใช้ → เปิดกลับ
- **Bug ที่ปิดได้:** อาจเกี่ยวข้อง Bug #274

---

## Phase 2: ปิดวงจร Bug วนซ้ำ (2-4 สัปดาห์)

> เป้าหมาย: แก้ 3 สาเหตุหลักที่ทำให้ bug วนซ้ำ — ยอดเพี้ยน, ข้อมูลค้าง, เลขซ้ำ

### 2.1 Standardize Data Type เงินเป็น decimal ทั้งหมด

**ขั้นตอน:**

1. **สำรวจและ list ทุก column ที่เป็น long/int ในขณะที่ควรเป็น decimal:**
   - `OagwbgVBudgetreceive.Totalreservedamount` (long? → decimal?)
   - `OagwbgBudgetreservedBankaccount.Totaltransferamount` (long? → decimal?)
   - `BudgetReservedModel` DTO: TotalReservedAmount (string? → decimal?)
   - ViewModel mapping ที่ cast decimal → int (บรรทัด 15950-15951)

2. **แก้ DAL Model:** เปลี่ยน property type
3. **แก้ DbContext:** ตรวจสอบ `HasPrecision` — ทุก column เงินต้องมี scale 2
4. **แก้ DTO/ViewModel:** เปลี่ยนจาก string/int เป็น decimal
5. **แก้ Service code:** ลบ `Convert.ToInt64()`, `(int?)` casting ออก

**Bug ที่ปิดได้:** #274 (ยอดสะสมไม่ขึ้น), #306 (ไม่แสดงยอดเงิน)
**ความเสี่ยง:** ปานกลาง — ต้อง test ทุกหน้าที่แสดงยอดเงิน

### 2.2 เพิ่ม Transaction ครอบ Confirm Operations ทั้งหมด

**ขั้นตอน:**

1. **ConfirmBudgetReserved** (บรรทัด 15530) — ครอบ 4 SaveChangesAsync ด้วย Transaction:
   ```csharp
   using var transaction = await _context.Database.BeginTransactionAsync();
   try {
       // ... existing code ...
       await transaction.CommitAsync();
   } catch {
       await transaction.RollbackAsync();
       throw;
   }
   ```

2. **ConfirmBudgetAllocateTransfer** (บรรทัด 13891) — เหมือนกัน
3. **UpdateBudgetOverlapStatus** (บรรทัด 16562) — เหมือนกัน
4. **SaveBudgetAllocateTransferCategory** (บรรทัด 8080) — เหมือนกัน

**Bug ที่ปิดได้:** #309 (รายการค้างสถานะ), #375 (ข้อมูลแสดงผิดกลุ่ม)
**ความเสี่ยง:** ต่ำ — เพิ่ม wrapper ไม่เปลี่ยน logic

### 2.3 แก้ Race Condition เลขที่เงินกัน

**ขั้นตอน:**

1. **สร้าง Oracle Sequence:**
   ```sql
   CREATE SEQUENCE OAGWBG_RESERVE_SEQ START WITH 1 INCREMENT BY 1;
   ```

2. **แก้ GenerateTransferNoAsync** (บรรทัด 15403):
   ```csharp
   // แก้จาก: SELECT MAX + 1
   // เป็น: SELECT OAGWBG_RESERVE_SEQ.NEXTVAL FROM DUAL
   var nextVal = await _context.Database
       .SqlQueryRaw<int>("SELECT OAGWBG_RESERVE_SEQ.NEXTVAL AS Value FROM DUAL")
       .FirstAsync();
   var nextRunning = nextVal.ToString("0000");
   ```

3. **เพิ่ม Unique Constraint:**
   ```sql
   ALTER TABLE OAGWBG_BUDGETRESERVED ADD CONSTRAINT UQ_TRANSFERNO UNIQUE (TRANSFERNO);
   ```

**Bug ที่ปิดได้:** #312 (เลขที่เงินกัน format)
**ความเสี่ยง:** ปานกลาง — ต้อง migrate sequence start value จากข้อมูลเดิม

### 2.4 แก้ Budget Check ให้ไม่ข้ามได้เมื่อ EBS ไม่ตอบ

**ขั้นตอน:**

1. **เปลี่ยน null check:**
   ```csharp
   // แก้จาก:
   if (totalBudget != null && amount > totalBudget)
   // เป็น:
   if (totalBudget == null)
       throw new DataErrorException("ไม่สามารถตรวจสอบงบประมาณได้ กรุณาลองใหม่");
   if (amount > totalBudget)
       throw new DataErrorException("จำนวนเงินเกินงบประมาณที่เหลือ");
   ```

**Bug ที่ปิดได้:** #96 (การเช็คงบโอนปรับเปลี่ยน)
**ความเสี่ยง:** ปานกลาง — ต้องตรวจสอบว่า EBS connection stable พอ

---

## Phase 3: แยก God Class (4-8 สัปดาห์)

> เป้าหมาย: แก้ต้นตอที่ bug ลามข้ามโมดูล

### 3.1 แยก BudgetService.cs เป็น Service ย่อย

**แผนแยก:**

```
BudgetService.cs (17,932 lines)
    ↓ แยกเป็น:
    ├── BudgetRequestService.cs       ← คำของบประมาณ / พรบ. / เพิ่มเติม
    ├── BudgetPlanService.cs          ← แผนการใช้จ่ายงบประมาณ
    ├── BudgetAllocateService.cs      ← โอนจัดสรร
    ├── BudgetTransferService.cs      ← โอนกลับ / โอนปรับเปลี่ยน
    ├── BudgetReserveService.cs       ← กันเงินเหลื่อมปี (32 methods)
    ├── BudgetDisbursementService.cs  ← เบิกเงิน
    ├── BudgetCheckService.cs         ← เช็คงบ / Budget validation
    ├── BudgetInterfaceService.cs     ← GL Interface (Oracle EBS)
    └── BudgetDashboardService.cs     ← Dashboard / สรุปภาพรวม
```

**ขั้นตอน:**

1. **สร้าง Interface ก่อน:**
   ```csharp
   public interface IBudgetReserveService {
       Task<ApiResultsModel> SaveBudgetReserved(BudgetReservedModel model);
       Task<ApiResultsModel> ConfirmBudgetReserved(BudgetReservedModel model);
       // ... ย้าย method signatures จาก IBudgetService
   }
   ```

2. **ย้าย method ทีละ module** (เริ่มจากกันเงินเหลื่อมปีเพราะมี bug เยอะสุด):
   - Copy methods ไปไฟล์ใหม่
   - เปลี่ยน DI registration
   - ปล่อย method เดิมไว้ใน BudgetService เป็น wrapper ชั่วคราว
   - ทดสอบ → ลบ wrapper

3. **แยก shared dependencies:**
   - `_context` → inject เหมือนเดิม (Scoped)
   - Helper methods (GetThaiFiscalYear, SetStatusName) → ย้ายไป `BudgetHelper.cs`
   - GL Interface methods → แยกเป็น `BudgetInterfaceService.cs`

4. **อัพเดต Controller:**
   ```csharp
   // แก้จาก:
   public BudgetController(IBudgetService budgetService)
   // เป็น:
   public BudgetController(
       IBudgetReserveService reserveService,
       IBudgetTransferService transferService,
       // ...
   )
   ```

5. **อัพเดต MVC proxy layer** (BudgetService.cs ฝั่ง MVC) ให้ตรง

**ความเสี่ยง:** สูง — ต้อง test ครบทุก module หลังแยก
**ลดความเสี่ยง:** แยกทีละ module, ใช้ wrapper method ชั่วคราว, ทดสอบหลังแยกแต่ละตัว

### 3.2 สร้าง BudgetBalanceService — Single Source of Truth

**แนวคิด:** สร้าง service กลางที่ทุก module ต้องผ่านเมื่อต้องการ อ่าน/แก้ ยอดเงิน

```csharp
public interface IBudgetBalanceService {
    Task<decimal> GetBalance(int budgetReceiveId);
    Task<decimal> GetReservedBalance(int budgetReservedId);
    Task UpdateBalance(int budgetReceiveId, decimal amount, BalanceOperation operation);
    Task ValidateBalance(int budgetReceiveId, decimal requestedAmount);
}

public enum BalanceOperation {
    Allocate,       // จัดสรร (เพิ่ม)
    Transfer,       // โอน (ย้าย)
    Reserve,        // กัน (หัก)
    Disburse,       // เบิก (หัก)
    Refund          // คืน (เพิ่ม)
}
```

**ประโยชน์:**
- ทุก module เรียก `ValidateBalance` ก่อน → ไม่มีการข้ามเช็คงบ
- ยอดเงินคำนวณจากจุดเดียว → ไม่เพี้ยน
- Transaction จัดการในจุดเดียว → ไม่ค้างครึ่งทาง

---

## Phase 4: ปรับ Infrastructure (ต่อเนื่อง)

> เป้าหมาย: ป้องกัน bug ชุดใหม่ไม่ให้เกิด

### 4.1 เพิ่ม FK Relationships ใน DbContext

**ขั้นตอน:**

1. เพิ่ม Navigation Properties ใน Entity Models:
   ```csharp
   public class OagwbgBudgetreserved {
       // ... existing properties ...
       public virtual ICollection<OagwbgBudgetreserveditem> Items { get; set; }
       public virtual ICollection<OagwbgBudgetreservedBankaccount> BankAccounts { get; set; }
   }
   ```

2. กำหนด Relationships ใน OnModelCreating:
   ```csharp
   modelBuilder.Entity<OagwbgBudgetreserveditem>()
       .HasOne<OagwbgBudgetreserved>()
       .WithMany(h => h.Items)
       .HasForeignKey(i => i.Budgetreversedid)
       .OnDelete(DeleteBehavior.Cascade);
   ```

3. ตรวจสอบ 62 ตารางที่เป็น `HasNoKey()` → เปลี่ยนเป็น `HasKey()` ที่ถูกต้อง

**ผล:** ลบ header → items ลบตาม → ไม่มี orphan → ยอดรวมไม่ผิด

### 4.2 เพิ่ม Cache สำหรับ Dropdown / Master Data

```csharp
// ใน Program.cs:
builder.Services.AddMemoryCache();

// ใน Dropdown Service:
public async Task<List<SelectListItem>> DropdownBudgetType(int? BudgetPlan)
{
    var cacheKey = $"BudgetType_{BudgetPlan}";
    if (!_cache.TryGetValue(cacheKey, out List<SelectListItem> result))
    {
        result = await _masterService.GetBudgetType(BudgetPlan);
        _cache.Set(cacheKey, result, TimeSpan.FromMinutes(30));
    }
    return result;
}
```

**ผล:** ลด DB load → ระบบเร็วขึ้น → user ไม่กดซ้ำ

### 4.3 แก้ N+1 Query

```csharp
// แก้จาก: (N+1)
foreach (var item in list) {
    var reservedItems = await _context.OagwbgBudgetreserveditems
        .Where(x => x.Budgetreversedid == item.Id).ToListAsync();
}

// เป็น: (1 query)
var allItems = await _context.OagwbgBudgetreserveditems
    .Where(x => headerIds.Contains(x.Budgetreversedid))
    .ToListAsync();
var itemsByHeader = allItems.GroupBy(x => x.Budgetreversedid)
    .ToDictionary(g => g.Key, g => g.ToList());
```

### 4.4 แก้ Load ข้อมูลทั้งตาราง

```csharp
// แก้จาก:
var poRows = await _context.OagwbgVBudgetoverlapyearPos
    .AsNoTracking().ToListAsync();  // ดึงทั้งตาราง!

// เป็น:
var poRows = await _context.OagwbgVBudgetoverlapyearPos
    .AsNoTracking()
    .Where(x => x.Budgetyear == currentYear)
    .ToListAsync();
```

### 4.5 ลงทะเบียน HttpClientFactory (MVC)

```csharp
// Program.cs:
builder.Services.AddHttpClient<IBudgetService, BudgetService>(client => {
    client.BaseAddress = new Uri(apiBaseUrl);
    client.Timeout = TimeSpan.FromMinutes(10);
});
```

### 4.6 แก้ Static MyHttpContext

```csharp
// แก้จาก:
public static HttpContext Current => m_httpContextAccessor.HttpContext;
// เป็น: ใช้ IHttpContextAccessor inject ตรง ไม่ใช้ static
```

### 4.7 ลบ Dead Code

- ลบ `app.Run()` ตัวที่ 2 ใน MVC Program.cs (บรรทัด 234 ไม่มีทาง execute)
- ลบ StoredProcedureExecutor ที่ stub ทั้งหมด
- ลบ Triple registration ของ IBudgetService (เหลือ 1)
- ลบ BudgetRequestMore region ที่ comment ออก (ถ้าไม่ใช้แล้ว)

---

## สรุป Timeline

```
สัปดาห์ 1-2:  Phase 1 — Quick Wins
               ✅ Hardcoded date
               ✅ Dead code if/else
               ✅ SQL Injection
               ✅ HttpClient leak & deadlock
               ✅ IsAllCancle fix
               → ปิด bug ได้: #309, #312, #316, #321 + ป้องกัน bug ใหม่

สัปดาห์ 3-4:  Phase 2A — Data Type
               ✅ Standardize decimal ทั้งหมด
               ✅ แก้ DTO string → decimal
               ✅ ลบ int/long casting
               → ปิด bug ได้: #274, #306

สัปดาห์ 5-6:  Phase 2B — Transaction + Race Condition
               ✅ เพิ่ม Transaction ครอบ Confirm
               ✅ Oracle Sequence + Unique Constraint
               ✅ Budget Check ไม่ข้ามเมื่อ null
               → ปิด bug ได้: #96, #375

สัปดาห์ 7-10: Phase 3A — แยก God Class (เริ่มจากกันเงิน)
               ✅ BudgetReserveService
               ✅ BudgetInterfaceService
               ✅ BudgetCheckService
               → ลดความเสี่ยง bug ลามข้ามโมดูล

สัปดาห์ 11-14: Phase 3B — แยก God Class (ที่เหลือ)
               ✅ BudgetTransferService
               ✅ BudgetDisbursementService
               ✅ BudgetBalanceService (Single Source of Truth)
               → ปิดวงจร bug วนซ้ำ

สัปดาห์ 15+:  Phase 4 — Infrastructure
               ✅ FK Relationships
               ✅ Cache
               ✅ N+1 Query fix
               ✅ Cleanup dead code
               → ระบบเสถียรระยะยาว
```

---

## Bug Mapping — แต่ละ Phase ปิด Bug อะไรได้บ้าง

| Phase | Bug ที่ปิดได้ | จำนวน |
|---|---|---|
| 1 Quick Wins | #309, #316, #321 + ป้องกัน bug ปีหน้า + security | ~5 |
| 2A Data Type | #274, #306, #308 | ~3 |
| 2B Transaction | #96, #375, #309 | ~3 |
| 3 God Class | ลดโอกาส bug ลามข้ามโมดูล (ผลทางอ้อม) | ป้องกัน bug ใหม่ |
| 4 Infrastructure | #307 (orphan), #376 (ภาพรวมผิด) + performance | ~3+ |
| **รวม** | | **~14 bug ตรง + ป้องกัน bug วนซ้ำ** |

---

## ความเสี่ยงของแต่ละ Phase

| Phase | ความเสี่ยง | วิธีลด |
|---|---|---|
| 1 | ต่ำ | เปลี่ยนแค่ไม่กี่บรรทัด ไม่กระทบโครงสร้าง |
| 2A | ปานกลาง | Test ทุกหน้าที่แสดงยอดเงิน |
| 2B | ปานกลาง | Test Confirm flow ทุก module |
| 3 | สูง | แยกทีละ module, ใช้ wrapper ชั่วคราว, test หลังแยกแต่ละตัว |
| 4 | ปานกลาง | เพิ่มทีละ feature, migration script สำหรับ FK |
