# Roadmap: แก้ไขปัญหา API ช้า — SearchBudgetTransferCategory (54 วินาที)

## 1. สาเหตุและการวิเคราะห์ปัญหา

### อาการ
- หน้า `/Budget/BudgetAllocateTransferDetail/1690` โหลดแล้ว ปุ่ม "เลือกรายการงบประมาณ" จะ disable ไว้ก่อน
- ระบบเรียก `/Budget/SearchBudgetTransferCategory?id=1690` เพื่อดึงข้อมูลรายการงบประมาณ
- ใช้เวลา **~54 วินาที** จึงจะโหลดเสร็จและปุ่มถึงกด enable

### Root Cause: N+1 Sequential Oracle Calls (ปัญหาหลัก)

ไฟล์: `OAGBudget.API\Services\Repository\BudgetService.cs` บรรทัด 8086–8094

```
flow:
  1. เรียก OAGWBG_FN_GETBUDGET_ALLOCATE_TRANSFER_CATEGORY → ได้ข้อมูล 468 รายการ
  2. หา distinct SummaryAccountCode → ได้ 176 ค่าที่ไม่ซ้ำกัน
  3. foreach (var item in ListSumAccCode) ← loop 176 ครั้ง
       → await GetTotalBudget("82", item) ← เรียก Oracle ทีละครั้ง, sequential
```

**แต่ละรอบของ `GetTotalBudget` ทำ:**
1. `new OracleConnection(...)` — เปิด connection ใหม่
2. Execute `APPS.oaggl_process.find_budget(p_org_id, p_concatenated_segments, p_date)` — stored procedure
3. `conn.Dispose()` — ปิด connection

**ผลลัพธ์:** 176 connection round-trips แบบ sequential → 54 วินาที (เฉลี่ย ~0.31 วินาที/ครั้ง)

### หลักฐานยืนยัน (Verification)
- Response JSON มี 468 items, นับ distinct `summaryAccountCode` ได้ **176** ค่าที่ไม่ซ้ำกัน
- Code ที่ `foreach` loop ใน `GetBudgetTransferCategory` ไม่มี `Task.WhenAll` หรือ parallelism
- แต่ละ iteration เรียก `GetTotalBudget` ที่รับ `existingConn = null` → สร้าง connection ใหม่ทุกครั้ง
- เวลา 54 วินาที ÷ 176 ครั้ง = ~0.31 วินาที/ครั้ง ซึ่งสมเหตุสมผลสำหรับ Oracle stored procedure call

### ปัญหารอง
- `loadPeriodModalData()` ถูกเรียกใน `$(document).ready()` ทุกครั้งที่โหลดหน้า แม้ผู้ใช้ยังไม่ได้จะกดปุ่ม

---

## 2. Roadmap การแก้ไข

### Phase 1 — แก้ปัญหา N+1 ที่ Backend (ลด 54s → ~1–2s)

**ตัวเลือก A: Parallel Execution ด้วย `Task.WhenAll`** *(แนะนำ — ทำได้เร็วที่สุด)*

แก้ไขใน `OAGBudget.API\Services\Repository\BudgetService.cs` ฟังก์ชัน `GetBudgetTransferCategory`:

```csharp
// เดิม: sequential foreach
foreach (var item in ListSumAccCode) {
    var result = await GetTotalBudget("82", item);
    ...
}

// ใหม่: parallel
var tasks = ListSumAccCode.Select(item => GetTotalBudget("82", item));
var results = await Task.WhenAll(tasks);
for (int i = 0; i < ListSumAccCode.Count; i++) {
    if (results[i] != null)
        data.FnGetBudgetTransferCategory
            .Where(x => x.SummaryAccountCode == ListSumAccCode[i])
            .ForEach(x => x.AvailableBudget = results[i]);
}
```

ข้อดี: แก้ง่าย เปลี่ยนน้อย ลดเวลาได้มาก  
ข้อระวัง: ต้องแน่ใจว่า Oracle connection pool รองรับ concurrent connections จำนวนมาก (176 concurrent) ควร limit concurrency หาก pool มีขนาดเล็ก เช่นใช้ `SemaphoreSlim`

**ตัวเลือก B: Reuse Single Oracle Connection**

ส่ง `existingConn` เดียวกันเข้าไปใน `GetTotalBudget` ทุกครั้ง (parameter นี้มีอยู่แล้ว)

```csharp
using var conn = new OracleConnection(_ebsContext.GetConnectionString());
await conn.OpenAsync();
foreach (var item in ListSumAccCode) {
    var result = await GetTotalBudget("82", item, conn); // ← ส่ง conn
    ...
}
```

ข้อดี: ลด connection overhead (ไม่ต้อง open/close 176 ครั้ง)  
ข้อเสีย: ยังเป็น sequential อยู่ ลดเวลาได้บ้างแต่ไม่มาก

**ตัวเลือก C: Batch Oracle Function (ยั่งยืนที่สุด แต่ทำงานมากกว่า)**

สร้าง Oracle function ใหม่ที่รับ list ของ account codes แล้วคืนค่าทั้งหมดในครั้งเดียว
→ ต้องแก้ฝั่ง Oracle DB ด้วย ใช้เวลานานกว่า

---

### Phase 2 — ปรับ UI เพื่อ UX ที่ดีขึ้น (Optional)

**Lazy Loading แทน Eager Loading**

ปัจจุบัน: `loadPeriodModalData()` ถูกเรียกทันทีใน `$(document).ready()` → รอ 54 วินาทีตั้งแต่เปิดหน้า

แนวทางปรับ: เรียก API เฉพาะตอนที่ผู้ใช้กดปุ่ม "เลือกรายการงบประมาณ" ครั้งแรก (ตรรกะนี้มีอยู่แล้วบางส่วนในโค้ด modal)

ข้อดี: หน้าโหลดเร็วขึ้น ผู้ใช้ไม่ต้องรอ 54 วินาทีก่อนใช้งานส่วนอื่น  
ข้อเสีย: ผู้ใช้รอตอนกดปุ่มแทน (แต่หลัง Phase 1 ก็จะเหลือแค่ ~1–2 วินาที)

---

## 3. ลำดับความสำคัญ

| ลำดับ | งาน | ผลกระทบ | ความยาก |
|-------|-----|----------|---------|
| 1 | Phase 1 ตัวเลือก A: Parallel `Task.WhenAll` | ลด 54s → ~1–2s | ต่ำ |
| 2 | Phase 1 ตัวเลือก B: Reuse connection (ทำร่วมกับ A) | ลด overhead เพิ่มเติม | ต่ำ |
| 3 | Phase 2: Lazy loading UI | ลด perceived wait time | ต่ำ |
| 4 | Phase 1 ตัวเลือก C: Batch Oracle function | ยั่งยืน scalable | สูง |

---

## 4. ไฟล์ที่ต้องแก้ไข

- `OAGBudget.API\Services\Repository\BudgetService.cs`
  - ฟังก์ชัน `GetBudgetTransferCategory` บรรทัด ~8086–8094 (loop foreach → parallel)
- `OAGBudget\Views\Budget\BudgetAllocateTransferDetail.cshtml`
  - บรรทัด ~773 `loadPeriodModalData()` ใน `$(document).ready()` (Phase 2 เท่านั้น)

---

## 5. ผลการแก้ไข (Actual Result)

| ขั้นตอน | เวลาก่อน | เวลาหลัง |
|---------|----------|----------|
| Waiting for server response | ~54s | ~11.9s |

---

## 6. สิ่งที่แก้ไขจริง

### `OAGBudget.API/Services/Repository/BudgetService.cs`
- **line 8085**: เปลี่ยน sequential `foreach` → `Task.WhenAll` + `SemaphoreSlim(20)`
  เรียก `GetTotalBudget` แบบ parallel 20 concurrent แทนทีละครั้ง

### `OAGBudget/Views/Budget/BudgetAllocateTransferDetail.cshtml`
- **line 263**: ปุ่ม `#btnOpenPeriodModal` เริ่มต้น enabled พร้อม icon search แทน disabled + spinner
- **line 771**: ลบ `loadPeriodModalData()` ออกจาก `$(document).ready()` → lazy load เมื่อกดปุ่มครั้งแรก
- **line 658**: เพิ่ม spinner loading indicator เป็น `<div>` เหนือตาราง (ไม่ใช่ `<tr>` ใน `<tbody>`)
  แก้ไข DataTables TN/18 error ที่เกิดเมื่อ `<tr colspan>` อยู่ใน `<tbody>` ก่อน init
- **line 1868/1875/1882**: show/hide spinner ใน `openPeriodModal()` AJAX call

---

## 7. TFS Changeset

| Changeset | วันที่ | รายละเอียด |
|---|---|---|
| 18956 | 2026-06-02 | perf(budget): speed up SearchBudgetTransferCategory from 54s to ~12s (#129) |
| 18957 | 2026-06-03 | fix(budget): move spinner outside tbody to prevent DataTables TN/18 error (#129) |

### Changeset 18956
```
perf(budget): speed up SearchBudgetTransferCategory from 54s to ~12s (#129)

API endpoint /Budget/SearchBudgetTransferCategory ใช้เวลา ~54s เพราะ
เรียก APPS.oaggl_process.find_budget ทีละ 1 ครั้ง แบบ sequential
สำหรับ summaryAccountCode ที่ไม่ซ้ำกัน 176 ค่า

- Replace sequential foreach with Task.WhenAll + SemaphoreSlim(20)
  ใน GetBudgetTransferCategory ลดเวลาจาก ~54s → ~12s (line 8085)
- Remove eager loadPeriodModalData() from document.ready
  ปุ่มพร้อมใช้ทันทีที่หน้าโหลด (line 771)
- Button เริ่มต้น enabled แทน disabled (line 263)
- Add spinner loading row ใน periodModal table body ขณะรอโหลด (line 676)

Changed in 2 files:
- OAGBudget.API/Services/Repository/BudgetService.cs
- OAGBudget/Views/Budget/BudgetAllocateTransferDetail.cshtml

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

### Changeset 18957
```
fix(budget): move spinner outside tbody to prevent DataTables TN/18 error (#129)

การวาง <tr id="periodTableLoadingRow"> ไว้ใน <tbody> ทำให้ DataTables
นับ column count ผิดพลาด (TN/18) เมื่อเปิด modal ผ่านปุ่มใน list
โดยที่ยังไม่มี periodModalDataCache

- ย้าย spinner จาก <tr> ใน <tbody> เป็น <div> เหนือ table-responsive (line 658)
- แก้ error: DataTables warning: table id=periodTable - Incorrect column count

Changed in 1 file:
- OAGBudget/Views/Budget/BudgetAllocateTransferDetail.cshtml

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

