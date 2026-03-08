# Phase 4: ปรับ Infrastructure — ป้องกัน Bug ชุดใหม่

> ระยะเวลา: ต่อเนื่อง | ทำควบคู่กับ Phase 3 ได้

---

## 4.1 เพิ่ม FK Relationships ใน DbContext

### ปัญหา
`MOENDBContextBase.cs` 19,023 บรรทัด ไม่มี FK เลย → orphan records สะสม

### แก้ที่ไหน
**ไฟล์:** `OAGBudget.DAL/Models/MOENDBContextBase.cs`

### Step 1: เพิ่ม Navigation Properties

**ไฟล์:** `OAGBudget.DAL/Models/OagwbgBudgetreserved.cs`
```csharp
// เพิ่มท้ายไฟล์:
public virtual ICollection<OagwbgBudgetreserveditem> Items { get; set; }
    = new List<OagwbgBudgetreserveditem>();
public virtual ICollection<OagwbgBudgetreservedBankaccount> BankAccounts { get; set; }
    = new List<OagwbgBudgetreservedBankaccount>();
```

**ไฟล์:** `OAGBudget.DAL/Models/OagwbgBudgetreserveditem.cs`
```csharp
// เพิ่ม:
public virtual OagwbgBudgetreserved? Header { get; set; }
```

### Step 2: กำหนด Relationships ใน OnModelCreating

**ไฟล์:** `OAGBudget.DAL/Models/MOENDBContextBase.cs`
เพิ่มใน method `OnModelCreating`:

```csharp
// กันเงิน: Header → Items
modelBuilder.Entity<OagwbgBudgetreserveditem>()
    .HasOne(i => i.Header)
    .WithMany(h => h.Items)
    .HasForeignKey(i => i.Budgetreversedid)
    .OnDelete(DeleteBehavior.Cascade);

// กันเงิน: Header → BankAccounts
modelBuilder.Entity<OagwbgBudgetreservedBankaccount>()
    .HasOne<OagwbgBudgetreserved>()
    .WithMany(h => h.BankAccounts)
    .HasForeignKey(b => b.Budgetreservedid)
    .OnDelete(DeleteBehavior.Cascade);
```

### Step 3: ตรวจสอบ 62 ตารางที่เป็น HasNoKey()

ค้นหาตารางจริง (ไม่ใช่ View) ที่ถูก map เป็น `HasNoKey()`:
```
grep -B2 "HasNoKey" OAGBudget.DAL/Models/MOENDBContextBase.cs | grep -v "ToView"
```

ตารางที่น่าจะต้องเปลี่ยนเป็น `HasKey()`:
- `OAGWBG_BUDGETDISBURSEMENTITEM`
- `OAGWBG_BUDGETREFUND`
- `OAGWBG_BUDGETRECEIVEPERIODALLOCATION`
- `OAGWBG_ASSET`
- `OAGWBG_ASSETIMAGE`

### Step 4: สร้าง Migration Script

```sql
-- เพิ่ม FK ใน Oracle
ALTER TABLE OAGWBG_BUDGETRESERVEDITEM
ADD CONSTRAINT FK_RESERVEDITEM_HEADER
FOREIGN KEY (BUDGETREVERSEDID) REFERENCES OAGWBG_BUDGETRESERVED(ID)
ON DELETE CASCADE;

ALTER TABLE OAGWBG_BUDGETRESERVED_BANKACCOUNT
ADD CONSTRAINT FK_RESERVEDBANKACCT_HEADER
FOREIGN KEY (BUDGETRESERVEDID) REFERENCES OAGWBG_BUDGETRESERVED(ID)
ON DELETE CASCADE;
```

### ทดสอบ
- ลบ header กันเงิน → items และ bank accounts ต้องลบตาม
- ตรวจว่าไม่มี orphan records ใน OAGWBG_BUDGETRESERVEDITEM

### Bug ที่ปิดได้
- **#307** (รายการส่วนกลางไม่ออกในรายงาน — orphan items)
- **#376** (สรุปภาพรวมผิด — orphan records รวมในยอด)

---

## 4.2 เพิ่ม Memory Cache สำหรับ Dropdown

### แก้ที่ไหน

**Step 1:** `OAGBudget.API/Program.cs`
```csharp
// เพิ่ม:
builder.Services.AddMemoryCache();
```

**Step 2:** `OAGBudget/Program.cs`
```csharp
// เพิ่ม:
builder.Services.AddMemoryCache();
```

**Step 3:** `OAGBudget/Services/Dropdown.cs`

```csharp
public class Dropdown : IDropdowns
{
    private readonly IMasterService _masterService;
    private readonly IBudgetService _budgetService;
    private readonly IMemoryCache _cache;  // ← เพิ่ม

    public Dropdown(
        IMasterService masterService,
        IBudgetService budgetService,
        IMemoryCache cache)  // ← เพิ่ม
    {
        _masterService = masterService;
        _budgetService = budgetService;
        _cache = cache;
    }

    public async Task<List<SelectListItem>> DropdownBudgetType(int? BudgetPlan)
    {
        var cacheKey = $"DropdownBudgetType_{BudgetPlan}";
        if (!_cache.TryGetValue(cacheKey, out List<SelectListItem>? result))
        {
            result = await _masterService.GetBudgetType(BudgetPlan);
            _cache.Set(cacheKey, result, TimeSpan.FromMinutes(30));
        }
        return result!;
    }

    // ทำเหมือนกันกับ Dropdown อื่นๆ ที่เป็น Master Data
    // (ไม่ต้อง cache ข้อมูลที่เปลี่ยนบ่อย เช่น status)
}
```

---

## 4.3 แก้ N+1 Query ในรายการกันเงิน

### แก้ที่ไหน
**ไฟล์:** `OAGBudget.API/Services/Repository/BudgetService.cs`
**บรรทัด:** 16015-16019

### Code เดิม
```csharp
// N+1 query: 1 query ต่อ 1 item ใน loop
foreach (var item in list)
{
    item.OverlapStatus = "กันเงิน";
    var reservedItems = await _context.OagwbgBudgetreserveditems
        .Where(x => x.Budgetreversedid == item.Id).ToListAsync();
    // ...
}
```

### แก้เป็น
```csharp
// Batch query: 1 query ดึงทุก items
var headerIds = list.Select(x => x.Id).ToList();
var allReservedItems = await _context.OagwbgBudgetreserveditems
    .Where(x => headerIds.Contains(x.Budgetreversedid ?? 0))
    .ToListAsync();

var itemsByHeader = allReservedItems
    .GroupBy(x => x.Budgetreversedid)
    .ToDictionary(g => g.Key ?? 0, g => g.ToList());

foreach (var item in list)
{
    item.OverlapStatus = "กันเงิน";
    var reservedItems = itemsByHeader.GetValueOrDefault(item.Id, new List<OagwbgBudgetreserveditem>());
    // ... logic เดิม ...
}
```

**ทำเหมือนกันกับ** `GetBudgetOverlapConsiderList` (บรรทัด 17089)

---

## 4.4 แก้ Load ข้อมูลทั้งตาราง

### แก้ที่ไหน
**ไฟล์:** `OAGBudget.API/Services/Repository/BudgetService.cs`
**บรรทัด:** 16909-16920

### Code เดิม
```csharp
var poRows = await _context.OagwbgVBudgetoverlapyearPos
    .AsNoTracking()
    .ToListAsync();  // ← ดึงทั้งตาราง!
```

### แก้เป็น
```csharp
var poRows = await _context.OagwbgVBudgetoverlapyearPos
    .AsNoTracking()
    .Where(x => x.Budgetyear == model.Budgetyear)  // ← กรองตามปีงบ
    .ToListAsync();
```

---

## 4.5 แก้ Static MyHttpContext

### แก้ที่ไหน
**ไฟล์:** `OAGBudget/Services/MyHttpContext.cs` (ทั้งไฟล์)
**ไฟล์:** `OAGBudget/Services/ClientService.cs` (บรรทัด 19)

### Code เดิม (MyHttpContext.cs)
```csharp
public class MyHttpContext
{
    private static IHttpContextAccessor m_httpContextAccessor;
    public static HttpContext Current => m_httpContextAccessor.HttpContext;
    // ...
}
```

### แก้เป็น
**ลบ MyHttpContext.cs** แล้วแก้ ClientService.cs ให้ inject IHttpContextAccessor ตรง:

```csharp
public abstract class ClientService
{
    internal readonly SettingsModel _settings;
    private readonly IHttpContextAccessor _httpContextAccessor;

    protected ClientService(
        IOptions<SettingsModel> settings,
        IHttpContextAccessor httpContextAccessor)
    {
        _settings = settings.Value;
        _httpContextAccessor = httpContextAccessor;
    }

    internal HttpClient CreateClient()
    {
        var client = new HttpClient();  // หรือใช้ IHttpClientFactory
        var httpContext = _httpContextAccessor.HttpContext;
        var userCur = httpContext != null ? new Appz(httpContext)?.CurrentSignInUser : null;
        client.BaseAddress = new Uri(_settings.BaseUrlApi ?? "https://localhost:7068");
        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", userCur?.UserToken);
        return client;
    }
}
```

### ต้องอัพเดต:
- ทุก class ที่ extends `ClientService` → เพิ่ม `IHttpContextAccessor` ใน constructor
- `OAGBudget/Program.cs` → ลบ `app.UseHttpContext()` ถ้ามี

---

## 4.6 ลบ Dead Code ทั้งหมด

### Checklist:

| รายการ | ไฟล์ | บรรทัด | ทำอะไร |
|---|---|---|---|
| `app.Run()` ซ้ำ | `OAGBudget/Program.cs` | 216+ | ลบ code หลัง `app.Run()` ตัวแรก |
| StoredProcedureExecutor | `OAGBudget.API/MiddleDb/` | ทั้งไฟล์ | ลบไฟล์ + ลบ DI (Program.cs:55) |
| IBudgetService ลงทะเบียน 3 ครั้ง | `OAGBudget/Program.cs` | 45, 52, 55 | เหลือ 1 (หรือเปลี่ยนเป็น AddHttpClient) |
| catch (Exception) { throw; } | BudgetService.cs หลายจุด | 8074, 16557 ฯลฯ | ลบ try/catch เปล่า |
| Console.WriteLine logging | BudgetService.cs | 13885-13886 | เปลี่ยนเป็น ILogger |
| `EnsureSuccessStatusCode` + `if IsSuccessStatusCode` ซ้ำซ้อน | MVC BudgetService.cs | 6005-6006 | ลบ if ที่ซ้ำ |

---

## 4.7 เพิ่ม Logging ที่มีประโยชน์

### แทนที่ Console.WriteLine

**ไฟล์:** `OAGBudget.API/Services/Repository/BudgetService.cs`

```csharp
// เพิ่มใน constructor:
private readonly ILogger<BudgetService> _logger;

// แก้จาก:
Console.WriteLine($"General Error: {ex.Message}");

// เป็น:
_logger.LogError(ex, "Error in ConfirmBudgetAllocateTransfer, TransferId={Id}", budgetAllocateTransferId);
```

---

## สรุป Phase 4

| ข้อ | งาน | ผลลัพธ์ |
|---|---|---|
| 4.1 | เพิ่ม FK | ไม่มี orphan records |
| 4.2 | เพิ่ม Cache | DB load ลด ระบบเร็วขึ้น |
| 4.3 | แก้ N+1 Query | หน้ารายการเร็วขึ้น 10-50x |
| 4.4 | แก้ Load ทั้งตาราง | memory ไม่บวมเมื่อข้อมูลเยอะ |
| 4.5 | แก้ Static HttpContext | thread-safe, testable |
| 4.6 | ลบ Dead Code | code สะอาด maintain ง่ายขึ้น |
| 4.7 | เพิ่ม Logging | debug ง่าย เมื่อเกิดปัญหา |
