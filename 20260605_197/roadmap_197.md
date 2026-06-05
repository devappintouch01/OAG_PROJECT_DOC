# Roadmap การวิเคราะห์: รายงานคำขอเพิ่มเติม (Prompt #197)

## สรุปปัญหาที่พบ

รายงาน "รายงานคำของบประมาณเพิ่มเติม" มีประเด็นที่ต้องแก้ไข 3 จุด ดังนี้

---

## ประเด็นที่ 1 — ก้อนถัวเฉลี่ย: ยอดรวมเบิ้ลตามจำนวนรายการงบประมาณภายใต้ก้อน

### ไฟล์ที่เกี่ยวข้อง
- `OAGBudget.API\Services\Repository\ReportService.cs` บรรทัด **6444–7551** (method `ReportBudgetRequestMore`)

### สาเหตุของปัญหา

ในขั้นตอนการสร้างรายงาน มีการคำนวณยอดรวมระดับ Template, ผลผลิต (Product), และกิจกรรม (Activity) โดยใช้:

```csharp
// บรรทัด 7400–7417 (ระดับ Template)
decimal templateBudget = templateGroup
    .Where(x => oracleFundsSummaryMap.ContainsKey(x.Categoryid?.ToString() ?? ""))
    .Sum(x => oracleFundsSummaryMap[x.Categoryid!.ToString()].Budget);
```

และในระดับ ExpenseType (g1) และ BudgetExpenseType (g2) บรรทัด 7295–7314:
```csharp
decimal expAddSum = g1.Sum(x => x.RequestamountAdd ?? 0m);
decimal bexpSum = g2.Sum(x => x.RequestamountAdd ?? 0m);
```

**จุดบกพร่อง** มี 2 ส่วน:

#### ส่วนที่ 1.A — Oracle GL Amount เบิ้ล (oracleFundsMap / oracleFundsSummaryMap)

Map ทั้งสองตัวนี้ใช้ **`categoryIdStr` (CategoryId)** เป็น key:
```csharp
oracleFundsMap[categoryIdStr] = normalFunds.Value;
```

แต่เมื่อคำนวณยอดรวมระดับ Template/Product/Activity จะ **iterate ทุก row** ในกลุ่มและ Sum Oracle GL amount:
```csharp
.Sum(x => oracleFundsSummaryMap[x.Categoryid!.ToString()].Budget)
```

สำหรับ "ก้อนถัวเฉลี่ย" — ถ้ามีหลาย BudgetGovernment row แชร์ **CategoryId เดียวกัน** (เช่น 3 หน่วยงานอยู่ในก้อนถัวเฉลี่ยเดียวกัน) ผลคือ:

```
Budget Oracle GL = 300,000
Items ในกลุ่ม = 3 rows (CategoryId เดียวกัน)
templateBudget ที่คำนวณได้ = 300,000 × 3 = 900,000  ❌ (ผิด)
ควรเป็น = 300,000  ✅
```

#### ส่วนที่ 1.B — RequestamountAdd เบิ้ล

View `OAGWBG_R_BUDGETREQUEST_MORE` อาจ return ยอดรวม Pool ทั้งหมดใน column `REQUESTAMOUNT` สำหรับ **ทุก row** ที่อยู่ในก้อนถัวเฉลี่ยเดียวกัน เช่น:
- ก้อนถัวเฉลี่ย มีหน่วยงาน 3 แห่ง
- ทั้ง 3 rows ใน allData มี `RequestamountAdd` = 300,000 (ยอดรวม pool)
- Sum ที่ g2 level = 300,000 × 3 = 900,000  ❌ (ควรเป็น 300,000)

### แนวทางแก้ไข

**วิธีที่ 1 (แก้ Oracle GL amount):** ใช้ DistinctBy CategoryId ก่อน Sum ที่ระดับ Template/Product/Activity:
```csharp
decimal templateBudget = templateGroup
    .Where(x => oracleFundsSummaryMap.ContainsKey(x.Categoryid?.ToString() ?? ""))
    .GroupBy(x => x.Categoryid)          // ← distinct by CategoryId
    .Sum(g => oracleFundsSummaryMap[g.Key!.ToString()].Budget);
```

**วิธีที่ 2 (แก้ RequestamountAdd):** ต้องยืนยันก่อนว่า View `OAGWBG_R_BUDGETREQUEST_MORE` return ยอดรวม pool หรือยอดรายบุคคลต่อ row
- ถ้า return ยอดรวม pool: ต้องแก้ที่ View (Oracle) ให้ return ยอดเฉพาะของ row นั้น
- หรือแก้ที่ C# โดย identify "ถัวเฉลี่ย" rows และ Sum เพียงครั้งเดียว

### ⚠️ ต้องตรวจสอบก่อนแก้ไข

ยังต้องยืนยันจากข้อมูลจริง (DB) ว่า:
1. View `OAGWBG_R_BUDGETREQUEST_MORE` return `REQUESTAMOUNT` ต่อ BudgetGovernment row หรือต่อ BudgetGovernmentItem row
2. หน่วยงานในก้อนถัวเฉลี่ยมี CategoryId เดียวกันหรือต่างกัน

---

## ประเด็นที่ 2 — หัวรายงานผิด

### ที่ตั้งในโค้ด

**ไฟล์:** `OAGBudget.API\Services\Repository\ReportService.cs`  
**บรรทัด:** 7144

```csharp
// ปัจจุบัน (ผิด):
ws.Cell(row, 1).Value = "รายละเอียดคำของบประมาณเพิ่มเติม";

// ที่ถูกต้อง:
ws.Cell(row, 1).Value = "รายละเอียดขอรับจัดสรรงบประมาณเพิ่มเติม";
```

### สาเหตุ
ข้อความ Header ใช้คำว่า "คำของ" แทน "ขอรับจัดสรร" และคำว่า "งบประมาณ" หายไปบางส่วน

### แนวทางแก้ไข
แก้ไข text string ที่บรรทัด 7144 เพียงจุดเดียว — ไม่กระทบ logic ใด

---

## ประเด็นที่ 3 — Sheet รายงาน: รายการงบลงทุนไม่ต้องแสดง

### ที่ตั้งในโค้ด

**ไฟล์:** `OAGBudget.API\Services\Repository\ReportService.cs`  
**บรรทัด:** 7291 (ใน `RenderExpenseGroups`) และ/หรือบรรทัด 7376–7521 (ส่วน ผลผลิต → กิจกรรม)

### สาเหตุ
ปัจจุบัน `RenderExpenseGroups` และส่วนคำนวณยอดรวมแบ่งกลุ่มตาม `Expensetypename` (งบรายจ่าย) โดยไม่มีการกรองออก รายการประเภท "งบลงทุน" จึงปรากฏในรายงาน

```csharp
// บรรทัด 7291 — ปัจจุบันไม่มีการกรอง
foreach (var g1 in scope.GroupBy(x => x.Expensetypename))
{
    ...
}
```

### แนวทางแก้ไข

**วิธีที่ 1 (แนะนำ):** กรอง allData ก่อนเข้า loop:
```csharp
// เพิ่มหลังบรรทัด 6613 (ก่อน Step 6.5)
allData = allData.Where(x =>
    !string.Equals(x.Expensetypename, "งบลงทุน", StringComparison.OrdinalIgnoreCase))
    .ToList();
```

**วิธีที่ 2:** กรองใน `RenderExpenseGroups` โดย skip g1 ที่เป็นงบลงทุน:
```csharp
foreach (var g1 in scope.GroupBy(x => x.Expensetypename)
                         .Where(g => !string.Equals(g.Key, "งบลงทุน",
                                     StringComparison.OrdinalIgnoreCase)))
```

### ⚠️ ข้อควรระวัง
- ต้องยืนยันชื่อ "งบลงทุน" ที่แน่นอนจากข้อมูลใน column `EXPENSETYPENAME` ของ View (อาจมีช่องว่างหรือตัวอักษรต่างกัน)
- วิธีที่ 1 จะ exclude งบลงทุนออกจากยอดรวมระดับ Product/Activity/Template ด้วย — ต้องยืนยันว่าต้องการแบบนี้หรือไม่

---

## สรุปไฟล์ที่ต้องแก้ไข

| ประเด็น | ไฟล์ | บรรทัดโดยประมาณ | ความยาก |
|---------|------|----------------|---------|
| 1A. Oracle GL เบิ้ล | `ReportService.cs` | 7400–7450 | ปานกลาง |
| 1B. RequestamountAdd เบิ้ล | `ReportService.cs` + Oracle View | 7295–7314 | สูง (ต้องยืนยัน View) |
| 2. หัวรายงาน | `ReportService.cs` | 7144 | ต่ำ |
| 3. งบลงทุน | `ReportService.cs` | 6613 หรือ 7291 | ต่ำ |

---

## ลำดับการแก้ไขที่แนะนำ

1. **แก้ทันที (ไม่ต้อง verify data):**
   - ประเด็น 2: แก้หัวรายงาน (1 บรรทัด)
   - ประเด็น 3: filter งบลงทุน (1 บรรทัด)

2. **ต้อง verify ข้อมูลก่อน:**
   - ประเด็น 1A: ตรวจสอบ CategoryId ซ้ำใน "ถัวเฉลี่ย" items แล้วใช้ DistinctBy
   - ประเด็น 1B: query View จริงบน preprod เพื่อดูว่า REQUESTAMOUNT = pool total หรือ per-row amount

### SQL ที่ใช้ verify ประเด็น 1 (บน PREPROD):
```sql
-- ดูโครงสร้าง View สำหรับคำขอที่มีก้อนถัวเฉลี่ย
SELECT 
    COSTCENTERID, DEPARTMENTID, CATEGORYID, EXPENSETYPENAME,
    BUDGETEXPENSETYPENAME, REQUESTAMOUNT, REQUESTAMOUNT_ADD
FROM OAGWBG_R_BUDGETREQUEST_MORE
WHERE BUDGETYEAR = 2568        -- ปรับปีตามจริง
  AND BUDGETREQUESTID = <ID>   -- ใส่ ID ของคำขอที่ทดสอบ
ORDER BY CATEGORYID, COSTCENTERID;

-- ตรวจว่ามี CategoryId ซ้ำใน BudgetGovernment สำหรับ request เดียวกัน
SELECT CATEGORYID, COUNT(*) AS CNT
FROM OAGWBG_BUDGETGOVERNMENT
WHERE BUDGETREQUESTID = <ID>
  AND (IS_COSTCENTER = 1 OR IS_COSTCENTER IS NULL)
GROUP BY CATEGORYID
HAVING COUNT(*) > 1;
```
