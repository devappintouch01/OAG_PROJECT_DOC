# วิเคราะห์คุณภาพ Source Code vs Bug List — OAG Budget

> วิเคราะห์เชิงลึกว่า bug จะวนเกิดซ้ำ หรือกระทบข้ามโมดูลจนแก้ไม่จบหรือไม่

---

## คำตอบสั้น: ใช่ — โครงสร้าง code ปัจจุบันทำให้ bug วนซ้ำและลามข้ามโมดูลได้

---

## สารบัญ

1. [ภาพรวมปัญหาเชิงโครงสร้าง](#1-ภาพรวม)
2. [God Class — BudgetService 17,932 บรรทัด](#2-god-class)
3. [ยอดเงินไม่ sync — ต้นตอ bug วนซ้ำ](#3-ยอดเงินไม่-sync)
4. [Data Type ปนกัน — decimal, long, int, string](#4-data-type-ปนกัน)
5. [Transaction ไม่ครอบคลุม — ข้อมูลค้างครึ่งๆ](#5-transaction-ไม่ครอบคลุม)
6. [Race Condition — เลขที่เงินกันซ้ำได้](#6-race-condition)
7. [Dead Code & Hardcoded Date — ระเบิดเวลา](#7-dead-code--hardcoded)
8. [DbContext ไม่มี FK — Orphan Records](#8-dbcontext-ไม่มี-fk)
9. [HttpClient Leak & Deadlock](#9-httpclient-leak)
10. [Budget Check ข้ามได้ 3 ทาง](#10-budget-check-bypass)
11. [N+1 Query & ไม่มี Cache](#11-performance)
12. [แผนผัง — Bug วนซ้ำอย่างไร](#12-แผนผัง)
13. [สรุปและลำดับความสำคัญ](#13-สรุป)

---

## 1. ภาพรวม

| ตัวชี้วัด | ค่า | ระดับความเสี่ยง |
|---|---|---|
| API BudgetService.cs | **17,932 บรรทัด** | วิกฤต |
| MVC BudgetService.cs | 6,528 บรรทัด | สูง |
| MOENDBContextBase.cs | **19,023 บรรทัด** | วิกฤต |
| FK Relationships ที่กำหนดใน DbContext | **0** | วิกฤต |
| SaveChangesAsync ที่ไม่มี Transaction ครอบ | **137 จาก 151 จุด** | วิกฤต |
| ตารางจริงที่ map เป็น HasNoKey() | **62 ตาราง** | สูง |
| Cache สำหรับ Dropdown/Master | **ไม่มี** | ปานกลาง |

---

## 2. God Class — BudgetService 17,932 บรรทัด

**ไฟล์:** `OAGBudget.API/Services/Repository/BudgetService.cs`

ไฟล์เดียวรวมทุก module:
- คำของบประมาณ / พรบ.
- แผนการใช้จ่าย
- โอนจัดสรร / โอนกลับ / โอนปรับเปลี่ยน
- กันเงินเหลื่อมปี (32 methods)
- เบิกเงิน
- Dashboard
- GL Interface (Oracle EBS)

### ทำไมถึงทำให้ bug วนซ้ำ:

```
แก้ method กันเงิน (บรรทัด 15,074)
    → ต้อง scroll ผ่าน code โอนเงิน (บรรทัด 12,555)
    → ไปเจอ budget check (บรรทัด 7,390)
    → แก้ผิดจุด หรือ แก้ถูกจุดแต่กระทบ method ข้างๆ
    → เกิด bug ใหม่ในโมดูลอื่น
```

**ตัวอย่างจริง:** Bug #96 (โอนปรับเปลี่ยน — การเช็คงบ) อยู่ใน method เดียวกับ Bug #274 (คำของบประมาณเพิ่มเติม — ยอดสะสม) เพราะ code อยู่ไฟล์เดียวกัน ใช้ `_context` ตัวเดียวกัน

---

## 3. ยอดเงินไม่ Sync — ต้นตอ Bug วนซ้ำ

### ปัญหาหลัก: ไม่มี Single Source of Truth สำหรับยอดเงิน

```
OagwbgBudgetreceive.Totalbalanceamount   ← คำนวณใน C# code
Oracle EBS (APPS.oaggl_process.find_budget) ← ยอดจริงใน EBS
```

**สองระบบนี้ไม่ sync กัน** เพราะ:

1. **เมื่อ "โอนจัดสรร" (ConfirmBudgetAllocateTransfer):** อัพเดต `Totalbalanceamount` ใน `OagwbgBudgetreceive` ผ่าน C# code (บรรทัด 14094)
2. **เมื่อ "เบิกเงิน":** เขียน journal ไป Oracle EBS เท่านั้น **ไม่ได้อัพเดต** `Totalbalanceamount` กลับมา
3. **เมื่อ "กันเงิน":** ตั้ง `Totalbalanceamount = Totalreservedamount` เสมอ (บรรทัด 15263) — **ไม่หักเบิกจ่าย**

### ผลกระทบตรงกับ Bug List:

| Bug | ปัญหา | สาเหตุจาก code |
|---|---|---|
| #274 | ยอดเงินสะสมรอบ 2 ไม่ขึ้น | Parent request ไม่ recalculate `Totalrequestamount` เมื่อมี child |
| #306 | เงินกันส่วนกลาง ไม่แสดงยอดเงิน | `Totalbalanceamount` ถูก set = `Totalreservedamount` แต่ไม่คิดเบิกจ่าย |
| #308 | เปลี่ยนไม่มีหนี้→มีหนี้ ยอดไม่อัพเดต | Type switching (O/R/A) แต่ไม่ recalculate ยอดรวม header |
| #338 | Header แผนการใช้จ่าย ไม่แสดงรวมผล พรบ. | ไม่มี computed view, คำนวณใน C# แบบ manual |

### สาเหตุที่ Bug #274 เกิด (วิเคราะห์ code):

```csharp
// API BudgetService.cs บรรทัด 863
budgetRequest.Totalrequestamount = sumTotalRequestAmount;
// ↑ Sum จาก governments ของ child request เท่านั้น
// ↑ ไม่ sum กลับไปที่ parent request
```

เมื่อรับเงินรอบแรกแล้ว สร้างคำขอรอบ 2 (child) → parent ไม่อัพเดตยอดรวม → หน้าจอสรุปดึงจาก parent → **ยอดสะสมไม่ขึ้น**

---

## 4. Data Type ปนกัน — decimal, long, int, string

### ในฐานข้อมูล (MOENDBContextBase.cs):

| Pattern | จำนวน column | ปัญหา |
|---|---|---|
| `NUMBER(12,2)` | 127 | ปกติ — 2 ทศนิยม |
| `NUMBER(38,2)` | 8 | ปกติ — 2 ทศนิยม |
| `NUMBER(12)` ไม่มี scale | 32 | **ตัดทศนิยมทิ้ง** เช่น `Totaladjustedamount` |
| `NUMBER` เปล่า | 391 | ไม่มี precision — ขึ้นกับ Oracle default |

### ในตัวแปร C# ปัญหาร้ายแรง:

```
OagwbgBudgetreserved.Totalbalanceamount   → decimal?  ✓
OagwbgVBudgetreceive.Totalreservedamount  → long?     ✗ ตัดทศนิยม!
OagwbgBudgetreservedBankaccount.Amount    → long?     ✗ ตัดทศนิยม!
BudgetReservedModel (DTO).TotalReserved   → string?   ✗ เป็น text!
ViewModel mapping                         → cast เป็น int?  ✗ overflow!
```

### ตัวอย่างจุดที่ตัดทศนิยม:

```csharp
// API BudgetService.cs บรรทัด 16419
receiveToRefund.Totalreservedamount =
    (receiveToRefund.Totalreservedamount ?? 0L) - Convert.ToInt64(oldAmount);
// ↑ Convert.ToInt64 ตัดทศนิยม: 1,500.75 → 1,501
```

```csharp
// API BudgetService.cs บรรทัด 15950
Totalhaspoamount = data.Totalhaspoamount != null
    ? (int?)data.Totalhaspoamount   // ← decimal? → int? ตัดทศนิยม + overflow ที่ >2.1 พันล้าน
    : null,
```

### ผลกระทบ:

ทุกครั้งที่ข้อมูลผ่าน API → MVC (ผ่าน DTO string) → กลับไป API → บันทึก DB
**ยอดเงินจะเพี้ยนเล็กน้อยทุกรอบ** สะสมไปเรื่อยๆ → ยอดไม่ตรง → bug

---

## 5. Transaction ไม่ครอบคลุม — ข้อมูลค้างครึ่งๆ

### สรุป Transaction Coverage:

| Operation | มี Transaction? | SaveChanges หลายจุด? | ความเสี่ยง |
|---|---|---|---|
| SaveBudgetReserved (กันเงิน-หน่วยงาน) | ✅ มี | 2 จุด | ปานกลาง |
| SaveBudgetReservedCentrall (กันเงิน-ส่วนกลาง) | ✅ มี | หลายจุด | ปานกลาง |
| **ConfirmBudgetReserved** | ❌ ไม่มี | **4 จุด** (บรรทัด 15592, 15618, 15631, 15670) | **วิกฤต** |
| **ConfirmBudgetAllocateTransfer (โอนจัดสรร)** | ❌ ไม่มี | หลายจุด + เรียก Oracle SP | **วิกฤต** |
| SaveBudgetTransferDetail (โอนกลับ) | ✅ มี | | ต่ำ |
| SaveTransferModifyItem (โอนปรับเปลี่ยน) | ✅ มี | | ต่ำ |
| **UpdateBudgetOverlapStatus** | ❌ ไม่มี | | สูง |
| **SaveBudgetAllocateTransferCategory** | ❌ ไม่มี | 3 จุด (บรรทัด 8173, 8201, 8206) | **วิกฤต** |

### กรณีที่ Bug จะเกิด:

```
ConfirmBudgetReserved (ไม่มี Transaction):
    SaveChangesAsync() #1 → สำเร็จ (เปลี่ยน Status)
    SaveChangesAsync() #2 → สำเร็จ (อัพเดต Round)
    SaveChangesAsync() #3 → ❌ FAIL (เช่น Oracle timeout)

    ผลลัพธ์: Status เปลี่ยนแล้ว แต่ Round ไม่ตรง
    → รายการค้างสถานะผิด → แก้ไม่ได้จากหน้าจอ → bug ค้าง
```

### ตรงกับ Bug List:

| Bug | ปัญหา | สาเหตุ |
|---|---|---|
| #309 | รายงานแสดงรายการที่ยังไม่ดึง/ยกเลิก | Status ค้างครึ่งทาง จาก Confirm ไม่มี transaction |
| #375 | บางรายการ สบอ. ควรเห็นเฉพาะส่วนกลาง | Status/Region อัพเดตไม่ atomic |

---

## 6. Race Condition — เลขที่เงินกันซ้ำได้

### วิธีสร้างเลขที่เงินกัน (GenerateTransferNoAsync):

```csharp
// บรรทัด 15403-15450
// Step 1: Query DB หาเลข max
var existing = await _context.OagwbgBudgetreserveds
    .Where(x => x.Transferno.StartsWith(prefix))
    .Select(x => x.Transferno!)
    .ToListAsync();

// Step 2: +1
var nextRunning = (maxRunning + 1).ToString("0000");
```

**ปัญหา:** ถ้า 2 คน กดสร้างพร้อมกัน:

```
User A: SELECT MAX → ได้ 0005 → สร้าง 0006
User B: SELECT MAX → ได้ 0005 → สร้าง 0006  ← ซ้ำ!
```

ไม่มี database-level unique constraint หรือ pessimistic lock

### ตรงกับ Bug #312:
เลขที่เงินกันต้องแก้ format (YYABRRRR) — ถ้า format เปลี่ยนแต่ logic SELECT MAX ยังเดิม → **เลขกระโดดหรือซ้ำ**

---

## 7. Dead Code & Hardcoded Date — ระเบิดเวลา

### Hardcoded Date ใน GL Interface (ส่วนกลาง):

```csharp
// API BudgetService.cs บรรทัด 9885-9886
var step1Date = new DateTime(2026, 9, 30);   // ← ใช้ได้แค่ปีงบ 2026!
var step2Date = new DateTime(2026, 10, 1);
```

เมื่อเข้าปีงบประมาณ 2027 → GL Interface ส่วนกลางจะบันทึกผิดวันที่ → **bug ใหม่**

### Dead Code ที่เป็นอันตราย:

1. **if/else if ซ้อนกัน (บรรทัด 15893-15928):**
```csharp
if (data.Statusid == 90101 || data.Statusid == 90201 || data.Statusid == 90102 || ...)
{ overlapList = ... }
else if (data.Statusid == 90201 || data.Statusid == 90102)  // ← DEAD CODE ไม่มีทางเข้า!
{ expandList = ... }
```
Status 90201 และ 90102 ถูกจับที่ branch แรก → `expandList` ไม่มีทางถูก set จากตรงนี้
→ **รายการขยายเวลาหายจากหน้าจอ** → ตรงกับ Bug #316, #321

2. **IsAllCancle คำนวณแล้วไม่ใช้ (บรรทัด 16023-16024):**
```csharp
var IsAllCancle = items.All(x => x.Statusid == 90301);
// ↑ คำนวณแล้ว แต่ไม่เอาไปใช้อะไรเลย
```
→ รายการที่ยกเลิกทั้งหมดยังแสดงสถานะผิด

3. **BudgetRequestMore ถูก comment ทั้ง region (บรรทัด 2328-2475):**
ทั้ง method `GetVBudgetRequestMoreList`, `SaveBudgetRequestMoreDetail` ถูก comment ออก
→ **Bug #274 อาจเกิดเพราะ feature ถูก disable ไปแล้วไม่ได้เปิดกลับ**

4. **StoredProcedureExecutor stub ทั้งหมด:**
```csharp
// OAGBudget.API/MiddleDb/StoredProcedureExecutor.cs
// ทุก method return ค่าว่าง
public async Task<DataTable> ExecuteAsync(...)
    => new DataTable();  // ← ไม่ทำอะไรเลย
```
ยังลงทะเบียนใน DI → ถ้าใครเรียกใช้จะได้ผลลัพธ์เปล่า โดยไม่มี error

---

## 8. DbContext ไม่มี FK — Orphan Records

**ไฟล์:** `OAGBudget.DAL/Models/MOENDBContextBase.cs` (19,023 บรรทัด)

- **HasOne/HasMany/HasForeignKey = 0** ไม่มี relationship เลย
- 62 ตารางจริงถูก map เป็น `HasNoKey()` → EF ถือว่า read-only

### ผลกระทบ:

```
ลบ header กันเงิน (OagwbgBudgetreserved)
    → items (OagwbgBudgetreserveditem) ยังอยู่ → orphan
    → bank accounts (OagwbgBudgetreservedBankaccount) ยังอยู่ → orphan
    → ยอดรวมจาก query ที่ join กลับมา → ยอดผิด
```

### ตรงกับ Bug List:

| Bug | ปัญหา | สาเหตุ |
|---|---|---|
| #307 | รายการส่วนกลางไม่ออกในรายงาน | Orphan items ไม่มี header → query join ไม่เจอ |
| #309 | รายงานแสดงรายการยกเลิก | Items ไม่ถูกลบตาม header เพราะไม่มี cascade |
| #376 | สรุปภาพรวมผิด | ยอดรวมรวม orphan records |

---

## 9. HttpClient Leak & Deadlock

### Socket Exhaustion:

```csharp
// MVC BudgetService.cs — ทุก method ที่เกี่ยวกับ Save:
var client = new HttpClient();              // ← สร้างใหม่ทุกครั้ง!
client.Timeout = TimeSpan.FromMinutes(10);  // ← ไม่ dispose!
```

จุดที่พบ: บรรทัด 1992, 2022, 6029, 6057 และอีกหลายจุด

ถ้ามีคน Save พร้อมกัน 50 คน → socket หมด → request ค้าง → timeout
→ **user เห็นว่าระบบช้า/ค้าง → กดซ้ำ → ซ้ำ → วนลูป**

### Deadlock:

```csharp
// MVC BudgetService.cs บรรทัด 6001
var response = _httpClient.SendAsync(request).ConfigureAwait(false);
var res = response.GetAwaiter().GetResult();  // ← Blocking call ใน async method!
```

ใน ASP.NET context ที่มี SynchronizationContext → **Deadlock ได้**

---

## 10. Budget Check ข้ามได้ 3 ทาง

### ทาง 1: EBS ไม่ตอบ = ไม่เช็ค

```csharp
// บรรทัด 8975
if (totalBudget != null && budgetReceive.Totalreceiveamount > totalBudget)
// ↑ ถ้า totalBudget == null (EBS timeout/ไม่เจอ account) → ข้าม check ทั้งหมด
```

### ทาง 2: Config ปิด = ไม่เช็ค

```csharp
// บรรทัด 10319, 13704, 13956
if (isConnection == false) { /* skip EBS calls entirely */ }
```

### ทาง 3: SQL Injection ใน account segment

```csharp
// บรรทัด 12440-12444
cmd.CommandText = $@"
    SELECT APPS.oaggl_utilities_pkg.AUTO_COMBINE_ACCOUNT(
        P_I_CONCAT_SEGMENT => '{accountSegment.Trim()}'  // ← ไม่ parameterize!
    ) AS COMBINE_CODE_ID FROM dual";
```

`accountSegment` มาจาก user input → สามารถ inject SQL ได้

### ผลกระทบ:
Bug #96 (โอนปรับเปลี่ยน — การเช็คงบ) น่าจะเกิดจาก budget check ไม่ทำงาน → โอนเงินเกินงบ → ยอดติดลบ → bug ลามไปทุก module ที่อ่านยอดคงเหลือ

---

## 11. N+1 Query & ไม่มี Cache

### N+1 Query ในหน้ารายการกันเงิน:

```csharp
// GetBudgetReservedList บรรทัด 15977
foreach (var item in list) {
    var reservedItems = await _context.OagwbgBudgetreserveditems
        .Where(x => x.Budgetreversedid == item.Id)
        .ToListAsync();  // ← query ทุก item ใน loop!
}
```

100 รายการกันเงิน = **101 queries** → หน้าจอช้า

### Load ข้อมูลทั้งตาราง:

```csharp
// GetVBudgetoverlapYearlist บรรทัด 16898
var poRows = await _context.OagwbgVBudgetoverlapyearPos
    .AsNoTracking()
    .ToListAsync();  // ← ไม่มี WHERE! ดึงทั้งตาราง
```

### ไม่มี Cache:

Dropdown 100+ method เรียก DB ทุก request → เพิ่ม load → ระบบช้า → user กดซ้ำ → วนลูป

---

## 12. แผนผัง — Bug วนซ้ำอย่างไร

```
┌─────────────────────────────────────────────────────────────────┐
│                    BudgetService.cs (17,932 lines)              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐    │
│  │คำของบฯ   │  │แผนใช้จ่าย│  │ โอนเงิน  │  │กันเงินเหลื่อมปี│   │
│  │ Bug:47+45│  │ Bug: 42  │  │ Bug: 33  │  │  Bug: 39     │    │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └──────┬───────┘    │
│       │              │             │                │            │
│       └──────────────┼─────────────┼────────────────┘            │
│                      ▼                                           │
│           OagwbgBudgetreceive.Totalbalanceamount                │
│           (ไม่มี single source of truth)                         │
│           (decimal vs long vs int vs string)                    │
│           (ไม่มี transaction ครอบ)                                │
│                      │                                           │
│                      ▼                                           │
│              Oracle EBS (ยอดจริง)                                 │
│              ← ไม่ sync กลับ →                                    │
│              ← budget check ข้ามได้ →                             │
└─────────────────────────────────────────────────────────────────┘

วงจร Bug:
  แก้ยอดใน Module A
    → ไม่ sync ไป Module B (ไม่มี trigger, ไม่มี event)
    → Module B แสดงยอดผิด
    → แก้ Module B
    → กระทบ Module C (ใน God Class เดียวกัน)
    → Bug ใหม่ใน Module C
    → วนซ้ำ...
```

---

## 13. สรุปและลำดับความสำคัญ

### ปัญหาที่ทำให้ Bug วนซ้ำมากที่สุด (ต้องแก้ก่อน):

| ลำดับ | ปัญหา | ผลกระทบ | Bug ที่เกี่ยวข้อง |
|---|---|---|---|
| 🔴 1 | **God Class 17,932 บรรทัด** — แยกเป็น Service ย่อยต่อ module | แก้ 1 จุด กระทบทั้งไฟล์ | ทุก bug |
| 🔴 2 | **ยอดเงินไม่มี single source of truth** — ใช้ computed view หรือ event-driven sync | ยอดเพี้ยน ลาม ทุก module | #274, #306, #308, #338 |
| 🔴 3 | **Data type ปนกัน (decimal/long/int/string)** — standardize เป็น decimal ทั้งหมด | ยอดตัดทศนิยม สะสมทุกรอบ | #274, #306 |
| 🔴 4 | **Transaction ไม่ครอบ Confirm** — ใส่ transaction ทุก multi-step operation | ข้อมูลค้างครึ่งทาง | #309, #375 |
| 🟡 5 | **Race condition เลขที่เงินกัน** — ใช้ DB sequence | เลขซ้ำ | #312 |
| 🟡 6 | **Hardcoded date 2026** — ใช้คำนวณจากปีงบประมาณ | พังปีหน้า | กันเงินส่วนกลาง |
| 🟡 7 | **Dead code / if-else ซ้อน** — ลบ dead branch, แก้ logic | รายการหาย/แสดงผิด | #316, #321 |
| 🟡 8 | **DbContext ไม่มี FK** — เพิ่ม relationship + cascade | Orphan records | #307, #309, #376 |
| 🟠 9 | **HttpClient leak** — ใช้ IHttpClientFactory | Socket หมด ระบบค้าง | performance |
| 🟠 10 | **SQL Injection ใน budget check** — ใช้ parameterized query | ข้ามเช็คงบได้ | #96, security |
| 🟠 11 | **N+1 query + ไม่มี cache** — ใช้ Include() + MemoryCache | ระบบช้า | performance |

### คำตอบสุดท้าย:

**Bug จะวนซ้ำแน่นอน** ตราบใดที่:
1. ทุก module อยู่ในไฟล์เดียว (God Class) — แก้จุดหนึ่งกระทบจุดอื่น
2. ยอดเงินไม่มี single source of truth — ทุก module คำนวณเอง → ไม่ตรงกัน
3. Data type ปนกัน — ยอดเพี้ยนทุกรอบที่ผ่าน API
4. Transaction ไม่ครอบคลุม — ข้อมูลค้างครึ่งทางเมื่อเกิด error

**Bug จะลามข้ามโมดูลแน่นอน** เพราะ:
1. `OagwbgBudgetreceive` เป็น shared mutable state ที่ทุก module อ่าน/เขียน โดยไม่มี lock
2. Oracle EBS balance กับ Web app balance ไม่ sync
3. Budget check ข้ามได้ → โอนเงินเกินงบ → กระทบทุก module ที่ดึงยอดคงเหลือ
