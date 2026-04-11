# Phase 3: แยก God Class — BudgetService 17,932 บรรทัด

> ระยะเวลา: 4-8 สัปดาห์ | ความเสี่ยง: สูง | ทำทีละ module ทดสอบทุกขั้น

---

## เป้าหมาย

แยก `OAGBudget.API/Services/Repository/BudgetService.cs` (17,932 บรรทัด)
เป็น Service ย่อย ไฟล์ละ 1 module

---

## แผนแยก

```
BudgetService.cs (17,932 lines)
    │
    ├── BudgetRequestService.cs       ← คำของบประมาณ / พรบ. / เพิ่มเติม
    ├── BudgetPlanService.cs          ← แผนการใช้จ่ายงบประมาณ
    ├── BudgetAllocateService.cs      ← โอนจัดสรร
    ├── BudgetTransferService.cs      ← โอนกลับ / โอนปรับเปลี่ยน
    ├── BudgetReserveService.cs       ← กันเงินเหลื่อมปี (32 methods)
    ├── BudgetDisbursementService.cs  ← เบิกเงิน
    ├── BudgetCheckService.cs         ← เช็คงบ / Budget validation
    ├── BudgetInterfaceService.cs     ← GL Interface (Oracle EBS)
    ├── BudgetDashboardService.cs     ← Dashboard / สรุปภาพรวม
    └── BudgetHelpers.cs              ← Shared helpers (static)
```

---

## ขั้นตอนแยก (ทำทีละ module)

### ลำดับที่แนะนำ:
1. **BudgetReserveService** ← เริ่มตัวนี้ก่อน (bug เยอะสุด, 32 methods)
2. **BudgetInterfaceService** ← แยก GL Interface ออก (ลด complexity ลงมาก)
3. **BudgetCheckService** ← แยก budget validation ออก
4. **BudgetTransferService** ← โอนเงิน
5. **BudgetAllocateService** ← โอนจัดสรร
6. ที่เหลือตามลำดับ

---

## 3.1 แยก BudgetReserveService (ตัวอย่างวิธีทำ)

### Step 1: สร้าง Interface

**สร้างไฟล์ใหม่:** `OAGBudget.API/Services/Interface/IBudgetReserveService.cs`

```csharp
namespace OAGBudget.API.Services.Interface;

public interface IBudgetReserveService
{
    // === CRUD กันเงิน (หน่วยงาน) ===
    Task<ApiResultsModel> SaveBudgetReserved(BudgetReservedModel model);
    Task<ApiResultsModel> ConfirmBudgetReserved(BudgetReservedModel model);
    Task<ApiResultsModel> ConfirmBudgetRequestOutside(BudgetReservedModel model);
    Task<object> GetBudgetReservedDetail(int id);
    Task<SearchResult<OagwbgVBudgetreserved>> GetBudgetReservedList(SearchBudgetReserved data);
    Task<ApiResultsModel> DeleteBudgetReservedItem(int id);
    Task<ApiResultsModel> UpdateBudgetOverlapStatus(UpdateBudgetOverlapStatusModel model);

    // === กันเงิน (ส่วนกลาง) ===
    Task<SearchResult<OagwbgVBudgetreserveditem>> GetBudgetOverlapYearCentralList(SearchBudgetReversedItem model);
    Task<object> GetBudgetOverlapYearCentralDetail(int id);
    Task<SearchResult<OagwbgVBudgetreserved>> GetBudgetReservedCentralList(BudgetReservedCentralViewModel query);
    Task<ApiResultsModel> SaveBudgetReservedCentrall(BudgetReservedCentralFormModel data);

    // === รายการ / ค้นหา ===
    Task<SearchResult<OagwbgVBudgetreserveditem>> GetBudgetReversedItemList<T>(SearchBudgetReversedItem data);
    Task<List<OagwbgVBudgetoverlapyearPo>> GetBudgetReservedPoListForExpand(string? prNumber);
    Task<SearchResult<BudgetReservedViewModel>> GetVBudgetoverlapYearlist(BudgetReservedViewModel model);
    Task<SearchResult<OagwbgVBudgetreserved>> GetBudgetOverlapConsiderList(SearchBudgetOverlapConsiderFilter data);
}
```

### Step 2: สร้าง Service ใหม่

**สร้างไฟล์ใหม่:** `OAGBudget.API/Services/Repository/BudgetReserveService.cs`

```csharp
namespace OAGBudget.API.Services.Repository;

public class BudgetReserveService : IBudgetReserveService
{
    private readonly MOENDBContext _context;
    private readonly EBSContext _ebsContext;
    private readonly IAuthService _auth;
    private readonly IBudgetInterfaceService _interfaceService;  // ← dependency ใหม่

    public BudgetReserveService(
        MOENDBContext context,
        EBSContext ebsContext,
        IAuthService auth,
        IBudgetInterfaceService interfaceService)
    {
        _context = context;
        _ebsContext = ebsContext;
        _auth = auth;
        _interfaceService = interfaceService;
    }

    // ย้าย methods จาก BudgetService.cs มาที่นี่:
    // - SaveBudgetReserved (บรรทัด 15074-15395)
    // - ConfirmBudgetReserved (บรรทัด 15530-15690)
    // - GetBudgetReservedDetail (บรรทัด 15862-15970)
    // - GetBudgetReservedList (บรรทัด 15977-16055)
    // - ... และ methods อื่นๆ ทั้ง 32 ตัว

    // ย้าย helper methods:
    // - GenerateTransferNoAsync (บรรทัด 15403)
    // - SetStatusName (บรรทัด 15970)
    // - SynchronizeReservedItemsAsync (บรรทัด 16471)
    // - MapFromPoToReservedItem (บรรทัด 16949)
    // - MapFromPrToReservedItem (บรรทัด 16974)
}
```

### Step 3: ย้าย Code

**วิธีย้ายแบบปลอดภัย:**

1. **Copy method ทั้งก้อน** จาก BudgetService.cs ไป BudgetReserveService.cs
2. **ใน BudgetService.cs เดิม เปลี่ยนเป็น wrapper:**
   ```csharp
   // BudgetService.cs — ชั่วคราว เพื่อไม่ให้ Controller พัง
   private readonly IBudgetReserveService _reserveService;

   public async Task<ApiResultsModel> SaveBudgetReserved(BudgetReservedModel model)
       => await _reserveService.SaveBudgetReserved(model);
   ```
3. **ทดสอบ** → ทุก function ยังทำงาน
4. **ค่อยๆ แก้ Controller** ให้เรียก BudgetReserveService ตรง
5. **ลบ wrapper** จาก BudgetService.cs

### Step 4: อัพเดต DI Registration

**ไฟล์:** `OAGBudget.API/Program.cs`

```csharp
// เพิ่ม:
builder.Services.AddScoped<IBudgetReserveService, BudgetReserveService>();
```

### Step 5: อัพเดต Controller

**ไฟล์:** `OAGBudget.API/Controllers/BudgetController.cs`

```csharp
// แก้จาก:
public class BudgetController : Controller
{
    private readonly IBudgetService _budgetService;

    public BudgetController(IBudgetService budgetService)
    {
        _budgetService = budgetService;
    }
}

// เป็น:
public class BudgetController : Controller
{
    private readonly IBudgetService _budgetService;
    private readonly IBudgetReserveService _reserveService;

    public BudgetController(
        IBudgetService budgetService,
        IBudgetReserveService reserveService)
    {
        _budgetService = budgetService;
        _reserveService = reserveService;
    }
}
```

### Step 6: อัพเดต MVC Proxy Layer

ทำเหมือนกันกับ `OAGBudget/Services/Repository/BudgetService.cs` — แยก method ที่เรียก Reserve API ไปเป็น `BudgetReserveService.cs` ฝั่ง MVC

---

## 3.2 แยก BudgetInterfaceService (GL Interface)

### Methods ที่ย้าย:
- `SaveBudgetReserved(int? id)` — บรรทัด 9449 (760+ บรรทัด!) GL Interface สำหรับกันเงิน
- `SaveBudgetReserveTransfer(int? id)` — บรรทัด 10213
- `SaveBudgetAllocateTransfer()` — GL Interface สำหรับโอนจัดสรร
- `SaveBudgetRequisition()` — บรรทัด 9336
- `SaveInterface()` — บรรทัด 10625
- `GetTotalBudget()` — บรรทัด 10594

### Interface:
```csharp
public interface IBudgetInterfaceService
{
    Task<ApiResultsModel> InterfaceReserve(int? id);
    Task<ApiResultsModel> InterfaceReserveTransfer(int? id);
    Task<ApiResultsModel> InterfaceAllocateTransfer(int? budgetAllocateTransferId);
    Task<ApiResultsModel> InterfaceRequisition(int? id);
    Task<decimal?> GetTotalBudget(string orgId, string accountCode);
}
```

---

## 3.3 สร้าง BudgetBalanceService — Single Source of Truth

### เป้าหมาย
ทุก module ที่ต้องการ อ่าน/แก้ ยอดเงิน ต้องผ่าน service นี้

### Interface:
```csharp
public interface IBudgetBalanceService
{
    /// <summary>ดึงยอดคงเหลือของ BudgetReceive</summary>
    Task<decimal> GetBalance(int budgetReceiveId);

    /// <summary>ดึงยอดกันเงินของ BudgetReserved</summary>
    Task<decimal> GetReservedBalance(int budgetReservedId);

    /// <summary>อัพเดตยอดเงิน — ใช้ภายใน Transaction เท่านั้น</summary>
    Task UpdateBalance(int budgetReceiveId, decimal amount, BalanceOperation operation);

    /// <summary>ตรวจสอบว่ายอดเงินเพียงพอหรือไม่</summary>
    Task<bool> ValidateBalance(int budgetReceiveId, decimal requestedAmount);

    /// <summary>Reconcile ยอดใน Web App กับ Oracle EBS</summary>
    Task<ReconcileResult> ReconcileWithEBS(int budgetReceiveId);
}

public enum BalanceOperation
{
    Allocate,       // จัดสรร (เพิ่ม)
    Transfer,       // โอน (ย้าย)
    Reserve,        // กัน (หัก)
    Disburse,       // เบิก (หัก)
    Refund,         // คืน (เพิ่ม)
    Cancel          // ยกเลิก (คืน)
}
```

### Implementation:
```csharp
public class BudgetBalanceService : IBudgetBalanceService
{
    private readonly MOENDBContext _context;
    private readonly IBudgetInterfaceService _interfaceService;

    public async Task UpdateBalance(int budgetReceiveId, decimal amount, BalanceOperation operation)
    {
        var receive = await _context.OagwbgBudgetreceives
            .FirstOrDefaultAsync(x => x.Id == budgetReceiveId)
            ?? throw new DataNotFoundException($"BudgetReceive {budgetReceiveId} not found");

        receive.Totalbalanceamount ??= 0m;

        switch (operation)
        {
            case BalanceOperation.Allocate:
            case BalanceOperation.Refund:
            case BalanceOperation.Cancel:
                receive.Totalbalanceamount += amount;
                break;

            case BalanceOperation.Reserve:
            case BalanceOperation.Disburse:
            case BalanceOperation.Transfer:
                if (receive.Totalbalanceamount < amount)
                    throw new InvalidOperationException(
                        $"ยอดคงเหลือไม่เพียงพอ (คงเหลือ: {receive.Totalbalanceamount:N2}, ขอ: {amount:N2})");
                receive.Totalbalanceamount -= amount;
                break;
        }

        receive.Updateon = DateTime.Now;
        await _context.SaveChangesAsync();
    }
}
```

### ผลลัพธ์:
ทุก module เรียก `_balanceService.UpdateBalance()` แทนการ set ค่าตรง
→ ยอดเงินถูกคำนวณจากจุดเดียว → ไม่เพี้ยน → ไม่ลามข้ามโมดูล

---

## 3.4 แยก BudgetHelpers (Static Utilities)

**สร้างไฟล์ใหม่:** `OAGBudget.API/Services/BudgetHelpers.cs`

```csharp
public static class BudgetHelpers
{
    public static int GetThaiFiscalYear(DateTime dt)
    {
        int be = dt.Year + 543;
        if (dt.Month >= 10) be += 1;
        return be;
    }

    public static string GetBudgetReservedTypeName(string? type) => type switch
    {
        "O" => "มีหนี้",
        "R" => "ไม่มีหนี้",
        "A" => "มีหนี้และไม่มีหนี้",
        _ => ""
    };
}
```

---

## Checklist สำหรับแต่ละ Service ที่แยก

- [ ] สร้าง Interface
- [ ] สร้าง Service class
- [ ] ย้าย methods + private helpers
- [ ] ลงทะเบียน DI ใน Program.cs
- [ ] สร้าง wrapper ใน BudgetService เดิม (ชั่วคราว)
- [ ] ทดสอบผ่าน wrapper
- [ ] อัพเดต API Controller ให้เรียกตรง
- [ ] อัพเดต MVC proxy layer
- [ ] ลบ wrapper จาก BudgetService เดิม
- [ ] ทดสอบ end-to-end

---

## ผลลัพธ์หลังแยกทั้งหมด

```
ก่อน:
  BudgetService.cs          17,932 บรรทัด  ← ไฟล์เดียวทุก module

หลัง:
  BudgetRequestService.cs    ~2,500 บรรทัด
  BudgetPlanService.cs       ~1,500 บรรทัด
  BudgetAllocateService.cs   ~2,000 บรรทัด
  BudgetTransferService.cs   ~2,000 บรรทัด
  BudgetReserveService.cs    ~3,000 บรรทัด
  BudgetDisbursementService  ~1,500 บรรทัด
  BudgetCheckService.cs      ~1,000 บรรทัด
  BudgetInterfaceService.cs  ~3,000 บรรทัด
  BudgetDashboardService.cs  ~1,000 บรรทัด
  BudgetBalanceService.cs    ~500 บรรทัด (ใหม่)
  BudgetHelpers.cs           ~200 บรรทัด
```

แก้ bug ใน module กันเงิน → กระทบแค่ BudgetReserveService.cs ~3,000 บรรทัด
แทนที่จะต้อง navigate ใน 17,932 บรรทัด
