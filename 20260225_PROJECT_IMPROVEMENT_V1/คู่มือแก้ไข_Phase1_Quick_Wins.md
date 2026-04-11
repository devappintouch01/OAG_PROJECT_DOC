# Phase 1: Quick Wins — คู่มือแก้ไขทีละจุด

> ระยะเวลา: 1-2 สัปดาห์ | ความเสี่ยง: ต่ำ | ไม่กระทบโครงสร้าง

---

## 1.1 แก้ Hardcoded Date — ระเบิดเวลาปีงบ 2027

### ปัญหา
วันที่สำหรับ GL Interface ส่วนกลาง hardcode เป็นปี 2026 — พอเข้าปีงบ 2027 จะบันทึกผิดวันที่ทั้งหมด

### แก้ที่ไหน
**ไฟล์:** `OAGBudget.API/Services/Repository/BudgetService.cs`
**บรรทัด:** 9885-9886

### Code เดิม
```csharp
// บรรทัด 9885-9886
var step1Date = new DateTime(2026, 9, 30);
var step2Date = new DateTime(2026, 10, 1);
```

### แก้เป็น
```csharp
// คำนวณจากปีงบประมาณของ header
var fiscalYearCE = (header.Budgetyear ?? GetThaiFiscalYear(DateTime.Now)) - 543;
var step1Date = new DateTime(fiscalYearCE, 9, 30);
var step2Date = new DateTime(fiscalYearCE, 10, 1);
```

### ทดสอบ
- สร้างรายการกันเงินส่วนกลาง → Confirm → ตรวจสอบวันที่ใน OagwbgLogInterface ว่าตรงกับปีงบประมาณ
- ทดสอบกับปีงบ 2568, 2569, 2570

### Bug ที่ปิดได้
ป้องกัน bug ใหม่เมื่อเข้าปีงบ 2027+

---

## 1.2 แก้ Dead Code if/else — รายการขยายเวลาหายจากหน้าจอ

### ปัญหา
Status 90201 และ 90102 ถูกจับที่ `if` แรก (บรรทัด 15893) → `else if` บรรทัด 15899 ไม่มีทางเข้า → `expandList` ไม่ถูก set จาก branch นี้
แต่บรรทัด 15926 เขียนทับ `expandList` แบบ unconditional อีกที → logic สับสน

### แก้ที่ไหน
**ไฟล์:** `OAGBudget.API/Services/Repository/BudgetService.cs`
**บรรทัด:** 15893-15928

### Code เดิม
```csharp
// บรรทัด 15893-15928
if (data.Statusid == 90101 || data.Statusid == 90201 || data.Statusid == 90102
    || data.Statusid == 20101 || data.Statusid == 10102
    || data.Statusid == 20202 || data.Statusid == 10197)
{
    overlapList = await _context.OagwbgVBudgetreserveditems
        .Where(x => x.Budgetreversedid == id && (x.Statusid == 90101
            || x.Statusid == 90201 || x.Statusid == 20101
            || x.Statusid == 20202 || x.Statusid == 10102 || x.Statusid == 10197))
        .ToListAsync();
}
else if (data.Statusid == 90201 || data.Statusid == 90102)  // ← DEAD CODE!
{
    expandList = await _context.OagwbgVBudgetreserveditems
        .Where(x => x.Budgetreversedid == id &&
                    (x.Statusid == 90101 || x.Statusid == 90102
                    || x.Statusid == 90110 || x.Statusid == 90201 || x.Statusid == 90109))
        .ToListAsync();
}
else if (data.Statusid == 10102)  // ← DEAD CODE! 10102 อยู่ใน if แรกแล้ว
{
    overlapList = await _context.OagwbgVBudgetreserveditems
        .Where(x => x.Budgetreversedid == id && (x.Statusid == 10102))
        .ToListAsync();
}

// ... cancelList logic ...

expandList = await _context.OagwbgVBudgetreserveditems     // ← เขียนทับทุกกรณี!
   .Where(x => x.Budgetreversedid == id && x.Statusid == 90102)
   .ToListAsync();
```

### แก้เป็น
```csharp
// แยก status ให้ชัดเจน — overlapList สำหรับรายการกันเงินปกติ
var overlapStatuses = new[] { 90101, 20101, 10102, 10197 };
if (overlapStatuses.Contains(data.Statusid ?? 0))
{
    overlapList = await _context.OagwbgVBudgetreserveditems
        .Where(x => x.Budgetreversedid == id && overlapStatuses.Contains((int)(x.Statusid ?? 0)))
        .ToListAsync();
}

// expandList สำหรับรายการขยายเวลา
var expandStatuses = new[] { 90201, 90102, 20202 };
if (expandStatuses.Contains(data.Statusid ?? 0))
{
    expandList = await _context.OagwbgVBudgetreserveditems
        .Where(x => x.Budgetreversedid == id &&
                    new[] { 90101, 90102, 90110, 90201, 90109 }.Contains((int)(x.Statusid ?? 0)))
        .ToListAsync();
}

// cancelList สำหรับรายการยกเลิก
if (data.Roundinterface != null || expandStatuses.Contains(data.Statusid ?? 0))
{
    cancelList = await _context.OagwbgVBudgetreserveditems
        .Where(x => x.Budgetreversedid == id &&
                    (x.Statusid == 90110 || x.Statusid == 90109))
        .ToListAsync();
}

// ลบ unconditional overwrite ของ expandList (บรรทัด 15926-15928 เดิม) ออก
```

### ทดสอบ
- เปิดรายการกันเงินที่มี status 90201 (ขยายระยะเวลา) → ตรวจว่า expandList แสดงครบ
- เปิดรายการ status 90102 → ตรวจว่า expandList แสดงถูกต้อง
- เปิดรายการ status 90101 → ตรวจว่า overlapList แสดงถูกต้อง

### Bug ที่ปิดได้
- **#316** (หน้าจอเลือกรายการขยายระยะเวลา)
- **#321** (กรณีขยายเวลา เพิ่ม Column PO)

---

## 1.3 แก้ IsAllCancle คำนวณแล้วไม่ใช้

### ปัญหา
คำนวณ `IsAllCancle` (รายการยกเลิกทั้งหมด) แล้วไม่เอาไปใช้ → รายการยกเลิกแสดง label ผิด

### แก้ที่ไหน
**ไฟล์:** `OAGBudget.API/Services/Repository/BudgetService.cs`
**บรรทัด:** 16023-16030

### Code เดิม
```csharp
// บรรทัด 16023-16024
bool IsAllCancle = reservedItems
    .Where(x => x.Parentid != null && (x.Statusid == 90110 || x.Statusid == 90109))
    .Count() == reservedItems.Where(x => x.Parentid == null).Count();

// บรรทัด 16026-16029
var lastRound = reservedItems
    .OrderByDescending(x => x.Overlapyear)
    .ThenByDescending(x => x.Overlapround)
    .FirstOrDefault().Overlapround;  // ← NullReferenceException เป็นไปได้
```

### แก้เป็น
```csharp
bool isAllCancelled = reservedItems
    .Where(x => x.Parentid != null && (x.Statusid == 90110 || x.Statusid == 90109))
    .Count() == reservedItems.Where(x => x.Parentid == null).Count();

var lastItem = reservedItems
    .OrderByDescending(x => x.Overlapyear)
    .ThenByDescending(x => x.Overlapround)
    .FirstOrDefault();

var lastRound = lastItem?.Overlapround;

// นำ isAllCancelled ไปใช้กำหนด OverlapStatus
if (isAllCancelled)
{
    item.OverlapStatus = "ยกเลิกทั้งหมด";
}
else if (lastRound == 2)
{
    item.OverlapStatus = "ขยายระยะเวลา";
}
else
{
    item.OverlapStatus = "กันเงิน";
}
```

### Bug ที่ปิดได้
- **#309** (รายงานแสดงรายการยกเลิก — ป้ายสถานะถูกต้อง)

---

## 1.4 แก้ SQL Injection ใน Budget Check

### ปัญหา
`accountSegment` จาก user input ถูก interpolate ลง SQL string ตรงๆ — inject ได้

### แก้ที่ไหน
**ไฟล์:** `OAGBudget.API/Services/Repository/BudgetService.cs`
**บรรทัด:** 12440-12444

### Code เดิม
```csharp
// บรรทัด 12440-12444
cmd.CommandText = $@"
    SELECT APPS.oaggl_utilities_pkg.AUTO_COMBINE_ACCOUNT(
        P_I_CONCAT_SEGMENT => '{accountSegment.Trim()}'
    ) AS COMBINE_CODE_ID
    FROM dual";
```

### แก้เป็น
```csharp
cmd.CommandText = @"
    SELECT APPS.oaggl_utilities_pkg.AUTO_COMBINE_ACCOUNT(
        P_I_CONCAT_SEGMENT => :segment
    ) AS COMBINE_CODE_ID
    FROM dual";

cmd.Parameters.Add(new Oracle.ManagedDataAccess.Client.OracleParameter(
    "segment",
    Oracle.ManagedDataAccess.Client.OracleDbType.Varchar2,
    accountSegment.Trim(),
    System.Data.ParameterDirection.Input));
```

### ทดสอบ
- ทดสอบโอนปรับเปลี่ยน → budget check ยังทำงานปกติ
- ตรวจสอบว่า account segment ที่มีอักขระพิเศษ (', --, ;) ไม่ทำให้ SQL เปลี่ยน

### Bug ที่เกี่ยวข้อง
- **#96** (โอนปรับเปลี่ยน — การเช็คงบ) + ป้องกัน security vulnerability

---

## 1.5 แก้ HttpClient Leak ใน MVC BudgetService

### ปัญหา
สร้าง `new HttpClient()` ทุกครั้งที่เรียก Save → socket ไม่ถูก dispose → socket หมดเมื่อมี user เยอะ

### แก้ที่ไหน
**ไฟล์:** `OAGBudget/Services/Repository/BudgetService.cs`
**บรรทัด:** 1992-1993, 2022-2023, 6029-6030, 6057-6058 และจุดอื่นๆ ที่มี `new HttpClient()`

### Code เดิม (ตัวอย่าง บรรทัด 1992)
```csharp
var client = new HttpClient();
client.Timeout = TimeSpan.FromMinutes(10);
client.DefaultRequestHeaders.Authorization =
    new AuthenticationHeaderValue("Bearer", userCur?.UserToken);
var response = await client.PostAsJsonAsync(apiUrl, model);
```

### แก้เป็น
ใช้ `_httpClient` ที่ inject มาทาง constructor (field มีอยู่แล้วใน class) หรือใช้ `CreateClient()` จาก `ClientService`:

```csharp
// ลบ: var client = new HttpClient();
// ลบ: client.Timeout = TimeSpan.FromMinutes(10);
// ใช้ _httpClient ที่มีอยู่แล้ว:
_httpClient.DefaultRequestHeaders.Authorization =
    new AuthenticationHeaderValue("Bearer", userCur?.UserToken);
var response = await _httpClient.PostAsJsonAsync(apiUrl, model);
```

**ทำซ้ำกับทุกจุดที่มี `new HttpClient()`** — ค้นหาด้วย:
```
grep -n "new HttpClient()" OAGBudget/Services/Repository/BudgetService.cs
```

### แก้เพิ่มที่ Program.cs
**ไฟล์:** `OAGBudget/Program.cs`
**บรรทัด:** 45 (แก้จาก 3 บรรทัดเหลือ 1 + เปลี่ยนเป็น AddHttpClient)

```csharp
// แก้จาก:
builder.Services.AddScoped<IBudgetService, BudgetService>();  // บรรทัด 45
builder.Services.AddScoped<IBudgetService, BudgetService>();  // บรรทัด 52 ← ซ้ำ
builder.Services.AddScoped<IBudgetService, BudgetService>();  // บรรทัด 55 ← ซ้ำ

// เป็น:
builder.Services.AddHttpClient<IBudgetService, BudgetService>(client => {
    client.Timeout = TimeSpan.FromMinutes(10);
});
```

### ทดสอบ
- Save รายการกันเงิน/โอนเงิน 10 ครั้งติดต่อกัน → ไม่ค้าง
- ดู netstat ว่าไม่มี socket ค้าง TIME_WAIT มากผิดปกติ

---

## 1.6 แก้ Deadlock `.GetAwaiter().GetResult()`

### ปัญหา
ใช้ blocking call `.GetAwaiter().GetResult()` ใน async method → deadlock ใน ASP.NET

### แก้ที่ไหน
**ไฟล์:** `OAGBudget/Services/Repository/BudgetService.cs`
**บรรทัด:** 6001-6003

### Code เดิม
```csharp
// บรรทัด 6001-6003
var response = _httpClient.SendAsync(request).ConfigureAwait(false);
var res = response.GetAwaiter().GetResult();  // ← Blocking!

res.EnsureSuccessStatusCode();
if (res.IsSuccessStatusCode)  // ← ซ้ำซ้อน เพราะ EnsureSuccess throw แล้ว
```

### แก้เป็น
```csharp
var res = await _httpClient.SendAsync(request);

res.EnsureSuccessStatusCode();
// ลบ if (res.IsSuccessStatusCode) ออก เพราะ EnsureSuccessStatusCode throw แล้ว
```

### ทดสอบ
- เปิดหน้ารายละเอียดรายการกันเงิน → ไม่ค้าง/hang
- ลองเปิดหลายหน้าพร้อมกัน → ไม่มี deadlock

---

## 1.7 แก้ Hardcoded User ID 123456789

### ปัญหา
Disbursement plan บันทึก `Createby`/`Updateby` เป็น `123456789` แทน user จริง → audit trail ปลอม

### แก้ที่ไหน
**ไฟล์:** `OAGBudget.API/Services/Repository/BudgetService.cs`
**บรรทัด:** 5412, 5429

### Code เดิม
```csharp
// บรรทัด 5412
updatedData.Updateby = 123456789; //UserInfo.User.Id

// บรรทัด 5429
Createby = 123456789, //userInfo.User.Id
```

### แก้เป็น
```csharp
// บรรทัด 5412
var userInfo = await _auth.ValidateTokenAndGetUserInfo();
updatedData.Updateby = userInfo?.User?.Id ?? 0;

// บรรทัด 5429
Createby = userInfo?.User?.Id ?? 0,
```

*หมายเหตุ: ตรวจสอบว่า `userInfo` ถูก validate แล้วก่อนหน้าใน method — ถ้ามีแล้วใช้ตัวที่มีอยู่*

### ทดสอบ
- สร้างแผนการใช้จ่าย → ตรวจ Createby ใน DB ว่าเป็น user ID จริง

---

## 1.8 ลบ Dead Code ที่ชัดเจน

### 1.8a StoredProcedureExecutor — stub ทั้งหมด
**ไฟล์:** `OAGBudget.API/MiddleDb/StoredProcedureExecutor.cs`
**ทั้งไฟล์** — ทุก method return ค่าว่าง

**ตรวจสอบก่อน:** ค้นหาว่ามี code ไหนเรียกใช้:
```
grep -rn "StoredProcedureExecutor\|ExecuteAsync\|ExecuteNonQueryAsync\|ExecuteScalarAsync" OAGBudget.API/
```
- ถ้าไม่มี code เรียก → ลบไฟล์ + ลบ DI registration ใน `OAGBudget.API/Program.cs` บรรทัด 55
- ถ้ามี code เรียก → **ต้องแก้ให้ทำงานจริง** (เปลี่ยนจาก SqlConnection เป็น OracleConnection)

### 1.8b app.Run() ซ้ำ ใน MVC
**ไฟล์:** `OAGBudget/Program.cs`
**บรรทัด 216+:** code หลัง `app.Run()` ตัวแรกเป็น dead code ทั้งหมด → ลบออก

### 1.8c catch (Exception) { throw; } เปล่า
**ค้นหาทั้ง project:**
```
grep -n "catch (Exception)" OAGBudget.API/Services/Repository/BudgetService.cs
```
ลบ try/catch ที่มีแค่ `throw;` ออก เพราะไม่ได้ทำอะไรนอกจากเพิ่ม stack frame
