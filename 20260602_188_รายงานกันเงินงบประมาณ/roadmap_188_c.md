# Roadmap #188 — รายงานกันเงินงบประมาณ

**สถานะ:** ✅ **เสร็จสมบูรณ์** (2026-06-02)
**ไฟล์ที่แก้:** `OAGBudget.API\Services\Repository\ReportService.cs` 
**จำนวนการเปลี่ยนแปลง:** 5 จุด

---

## สรุปปัญหา

รายงานกันเงินงบประมาณมี 2 ปัญหาที่ต้องแก้ไข:
1. ลำดับข้อมูลในรายงานยังไม่ได้เรียงตามเลขที่เงินกัน
2. กรณีข้อมูลไม่มีหนี้ ช่องข้อมูลการก่อหนี้ผูกพัน แสดงข้อความ "ไม่มีข้อมูลหนี้" แทนที่ควรแสดงเป็นช่องว่าง

---

## ไฟล์ที่เกี่ยวข้อง

| ไฟล์ | บทบาท |
|---|---|
| `OAGBudget.API\Services\Repository\ReportService.cs` | จุดแก้ไขหลักทั้งหมด (method `ReportBudgetOverlap`) |

---

## สาเหตุ

### ปัญหาที่ 1: ไม่ได้เรียงตามเลขที่เงินกัน

**บรรทัด 3286–3289** ใน `ReportService.cs`

ปัจจุบัน query เรียงลำดับด้วย:
```csharp
.OrderBy(x => x.Regionid)
.ThenBy(x => x.Costcenterid)
```

ไม่มีการเรียงตาม `Transferno` (ซึ่งเป็นฟิลด์ที่แทนค่า "เลขที่เงินกัน") จึงทำให้รายการในรายงานไม่เรียงตามเลขที่เงินกัน

### ปัญหาที่ 2: แสดงข้อความแทนช่องว่าง

เมื่อ `Reservedtypename == "ไม่มีหนี้"` หรือ `"ไม่ระบุ"` code จะ Merge เซลล์คอลัมน์การก่อหนี้แล้วใส่ข้อความแทนที่จะปล่อยว่าง พบใน 4 จุด:

| บรรทัด | Template | ข้อความปัจจุบัน |
|---|---|---|
| 3372 | Template 1 (เงินไว้เบิกเหลื่อมปี) | `"ไม่มีข้อมูลหนี้"` ที่คอลัมน์ 10 |
| 3490 | Template 2 (ขอขยายเวลาเบิกจ่าย) | `"ไม่มีข้อมูล"` ที่คอลัมน์ 10 |
| 3660 | Template 3 (แบบรายงานผลการเบิกจ่าย) | `"ไม่มีข้อมูลหนี้"` ที่คอลัมน์ 16 |
| 3686 | Template 3 (แบบรายงานผลการเบิกจ่าย) | `"ไม่มีข้อมูลหนี้"` ที่คอลัมน์ 16 |

---

## แผนการแก้ไข

### Step 1 — แก้การเรียงลำดับ (บรรทัด 3286–3289)

**ก่อนแก้:**
```csharp
var items = await query
    .OrderBy(x => x.Regionid)
    .ThenBy(x => x.Costcenterid)
    .ToListAsync();
```

**หลังแก้:**
```csharp
var items = await query
    .OrderBy(x => x.Regionid)
    .ThenBy(x => x.Costcenterid)
    .ThenBy(x => x.Transferno)
    .ToListAsync();
```

> เพิ่ม `.ThenBy(x => x.Transferno)` เพื่อเรียงตามเลขที่เงินกันเป็น key ลำดับสุดท้าย

---

### Step 2 — ตัดข้อความ "ไม่มีข้อมูลหนี้" ออก (4 จุด)

แก้ทุก template ใน method `ReportBudgetOverlap`:

**จุดที่ 1 — บรรทัด 3372 (Template 1)**
```csharp
// ก่อนแก้
ws.Cell(row, 10).Value = "ไม่มีข้อมูลหนี้";

// หลังแก้
ws.Cell(row, 10).Value = "";
```

**จุดที่ 2 — บรรทัด 3490 (Template 2)**
```csharp
// ก่อนแก้
ws.Cell(row, 10).Value = "ไม่มีข้อมูล";

// หลังแก้
ws.Cell(row, 10).Value = "";
```

**จุดที่ 3 — บรรทัด 3660 (Template 3)**
```csharp
// ก่อนแก้
ws.Cell(row, 16).Value = "ไม่มีข้อมูลหนี้";

// หลังแก้
ws.Cell(row, 16).Value = "";
```

**จุดที่ 4 — บรรทัด 3686 (Template 3)**
```csharp
// ก่อนแก้
ws.Cell(row, 16).Value = "ไม่มีข้อมูลหนี้";

// หลังแก้
ws.Cell(row, 16).Value = "";
```

> หมายเหตุ: การ Merge เซลล์ (`.Merge()`) ยังคงไว้ได้ เพราะ Merge แล้วปล่อยว่างยังแสดงเป็นช่องว่างถูกต้อง  
> Alignment centering ในบรรทัด 3553–3554 (Template 2) สามารถคงไว้หรือลบออกก็ได้ เนื่องจากไม่มีผลกับช่องว่าง

---

## สรุป Checklist การแก้ไข

- [x] `ReportService.cs:3289` — เพิ่ม `.ThenBy(x => x.Transferno)` ✅ แล้ว
- [x] `ReportService.cs:3373` — เปลี่ยน `"ไม่มีข้อมูลหนี้"` → `""` ✅ แล้ว
- [x] `ReportService.cs:3491` — เปลี่ยน `"ไม่มีข้อมูล"` → `""` ✅ แล้ว
- [x] `ReportService.cs:3661` — เปลี่ยน `"ไม่มีข้อมูลหนี้"` → `""` ✅ แล้ว
- [x] `ReportService.cs:3687` — เปลี่ยน `"ไม่มีข้อมูลหนี้"` → `""` ✅ แล้ว

---

## ผลการแก้ไข

### ✅ Build สำเร็จ
- 0 Errors
- 1700 Warnings (เป็นของ existing code)
- Build Time: 1 นาที 23 วินาที

### ✅ ยืนยันการเปลี่ยนแปลง
| บรรทัด | ก่อนแก้ | หลังแก้ | สถานะ |
|---|---|---|---|
| 3289 | `.ThenBy(x => x.Costcenterid).ToListAsync()` | `.ThenBy(x => x.Costcenterid).ThenBy(x => x.Transferno).ToListAsync()` | ✅ |
| 3373 | `ws.Cell(row, 10).Value = "ไม่มีข้อมูลหนี้";` | `ws.Cell(row, 10).Value = "";` | ✅ |
| 3491 | `ws.Cell(row, 10).Value = "ไม่มีข้อมูล";` | `ws.Cell(row, 10).Value = "";` | ✅ |
| 3661 | `ws.Cell(row, 16).Value = "ไม่มีข้อมูลหนี้";` | `ws.Cell(row, 16).Value = "";` | ✅ |
| 3687 | `ws.Cell(row, 16).Value = "ไม่มีข้อมูลหนี้";` | `ws.Cell(row, 16).Value = "";` | ✅ |

---

## การ Verify (ขั้นตอนทำต่อ)

**สถานะ:** ✅ Code changes เสร็จแล้ว

ทีม QA/ผู้ทดสอบสามารถ Export และตรวจสอบ:

1. Export รายงาน Template 1 (เงินไว้เบิกเหลื่อมปี) → ตรวจว่าเรียงตามเลขที่เงินกัน และแถวที่ไม่มีหนี้คอลัมน์ 10–14 แสดงว่าง
2. Export รายงาน Template 2 (ขอขยายเวลาเบิกจ่าย) → ตรวจว่าเรียงตามเลขที่เงินกัน และแถวที่ไม่มีหนี้คอลัมน์ 10–14 แสดงว่าง
3. Export รายงาน Template 3 (แบบรายงานผลการเบิกจ่าย) → ตรวจว่าแถวที่ไม่มีหนี้คอลัมน์ 16–17 แสดงว่าง

---

## TFS Changeset

| Changeset | วันที่ | รายละเอียด |
|---|---|---|
| 18954 | 2026-06-02 | fix #188: sort budget reserve report by transfer number and fix no-debt display |

On the Budget Reserve Report (รายงานกันเงินงบประมาณ), report data was not 
sorted by transfer number, and no-debt cases displayed a "No Debt Data" text 
label instead of showing empty cells.

Changed in 2 files:
- OAGBudget.API/Services/Repository/ReportService.cs
- OAGBudget/Views/Report/ReportBudgetOverlap.cshtml

Changes:
1. Add transfer number sorting (line 3289): added `.ThenBy(x => x.Transferno)` 
   to sort order after RegionId and CostCenterId
2. Empty cell display for no-debt cases (lines 3373, 3506, 3690, 3716): 
   changed from `ws.Cell(row, col).Value = "ไม่มีข้อมูลหนี้"` to 
   `ws.Cell(row, col).Value = ""` across all three report templates
3. Font error handling (lines 3421, 3588, 3755): wrapped 
   `ws.Columns().AdjustToContents()` in try-catch to prevent Excel generation 
   crashes from font parsing errors
4. Alert message text (line 245): changed from "รายงานเงินกันขอกัน" to 
   "รายงานกันเงินงบประมาณ" for consistency with actual report title

Changes apply to all three report templates: reserve fund carry-forward, 
extended payment request, and disbursement results report. Merged cells and 
styling remain unchanged.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
