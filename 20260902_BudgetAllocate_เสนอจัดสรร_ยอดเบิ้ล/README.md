# หน้าพิจารณาคำขอ ปี 2570 — ช่อง "เสนอจัดสรร" ยอดเบิ้ล

**วันที่วิเคราะห์:** 2026-09-02
**สถานะ:** ✅ แก้โค้ดแล้ว build ผ่าน 0 error และ verify กับข้อมูลจริงบน PREPROD (`172.16.11.19:1541/ebs_PRE`) — ยังไม่ได้ checkin
**ความรุนแรง:** สูง — ยอดผิดสะสมทบต้นทุกครั้งที่กดบันทึก และข้อมูลใน DB เพี้ยนไปแล้ว 6 รายการ

---

## 1. อาการ

หน้า **รายละเอียดงบประมาณประจำปี** (`BudgetAllocateDetail`) ปีงบประมาณ 2570
ระบุจำนวนเงินในช่อง **เสนอจัดสรร** เช่นรายการ **ค่าโทรศัพท์** → กดบันทึก → หน้าจอ reload → **ยอดกลายเป็น 2 เท่า**

และถ้ากดบันทึกซ้ำอีก จะกลายเป็น 4 เท่า, 8 เท่า ไปเรื่อย ๆ (ทบต้น)

---

## 2. Root Cause

### จุดที่ผิด

[`OAGBudget.API/Services/Repository/BudgetService.cs:5630-5642`](../../OAGBudget.API/Services/Repository/BudgetService.cs#L5630-L5642)
เมธอด `GetBudgetAllocateItemsGroupByPlanId`

```csharp
BudgetAllocateList = g.GroupBy(x => x.CategoryId)
    .Select(gi =>
    {
        var first = gi.OrderBy(x => (x.DummyFlag?.ToUpper() ?? "") == "YES" ? 1 : 0).First();
        first.Totalrequestsimmaryamount = gi.Sum(x => x.Totalrequestsimmaryamount);  // ✅ ถูก
        first.Totalrequestamount        = gi.Sum(x => x.Totalrequestamount);         // ✅ ถูก
        first.Keptcentral               = gi.Sum(x => x.Keptcentral);                // ❌ ผิด
        first.Totalrequestadjustamount  = gi.Sum(x => x.Totalrequestadjustamount);   // ❌ ผิด
        first.Totalrequestsumadjustamount = gi.Sum(x => x.Totalrequestsumadjustamount);
        first.Totalallocateamount       = gi.Sum(x => x.Totalallocateamount);        // ❌ ต้นเหตุ "เบิ้ล"
        first.Totaladjustedamount       = gi.Sum(x => x.Totaladjustedamount);        // ❌ ผิด
        return first;
    }).ToList(),
```

และแบบเดียวกันที่ระดับ ExpenseType — บรรทัด [5628-5629](../../OAGBudget.API/Services/Repository/BudgetService.cs#L5628-L5629)

### กลไก

| คอลัมน์ | แหล่งข้อมูล | ระดับความละเอียด | `Sum()` ถูกไหม |
|---|---|---|---|
| `TOTALREQUESTSIMMARYAMOUNT`, `TOTALREQUESTAMOUNT` | คำของบของแต่ละหน่วย | **1 ค่าต่อ 1 แถวคำขอ** | ✅ ถูก |
| `TOTALALLOCATEAMOUNT` (เสนอจัดสรร) | `OAGWBG_BUDGETGOVERNMENT` type `6` | **1 record ต่อ (ปี+category+product+activity+plan)** | ❌ ผิด |
| `TOTALADJUSTEDAMOUNT` (แปรญัตติ) | `OAGWBG_BUDGETGOVERNMENT` type `5` | เหมือนกัน | ❌ ผิด |
| `TOTALREQUESTADJUSTAMOUNT` (คำขอแปรญัตติ) | `OAGWBG_BUDGETGOVERNMENT` type `8` | เหมือนกัน | ❌ ผิด |

View `OAGWBG_V_BUDGETALLOCATEITEM` คืน **1 แถวต่อ 1 คำขอ** แล้ว join ค่าจาก `BUDGETGOVERNMENT`
เข้ามาแปะซ้ำในทุกแถว → พอโค้ด `Sum()` ทับลงไป ค่าเลย **× จำนวนแถวคำขอ**

### ทำไมถึงทบต้น

1. บันทึกสำเร็จ → JS สั่ง `location.reload()` — [`BudgetAllocateDetail.cshtml:1456`](../../OAGBudget/Views/Budget/BudgetAllocateDetail.cshtml#L1456)
2. หน้าโหลดใหม่ → ช่องเสนอจัดสรรแสดงค่าที่เบิ้ลแล้ว
3. กดบันทึกอีกครั้ง → JS อ่านค่าจาก input ตัวเดิม ([`_tableBudgetAllocateDetailPersonal.cshtml`](../../OAGBudget/Views/Shared/Partialviews/_tableBudgetAllocateDetailPersonal.cshtml) → `Totalallocateamount3`) ส่งค่าเบิ้ลไปเขียนทับ DB
4. ฝั่ง save เขียนแบบ `=` ไม่ใช่ `+=` ([BudgetService.cs:4862](../../OAGBudget.API/Services/Repository/BudgetService.cs#L4862)) — DB เลยเก็บค่าเบิ้ลถาวร

**สรุป: บันทึก N ครั้ง → DB เก็บ 2ⁿ⁻¹ เท่าของค่าที่ตั้งใจ, หน้าจอแสดง 2ⁿ เท่า**

---

## 3. หลักฐานจาก Database (PREPROD, 2026-09-02)

### 3.1 View คืน 2 แถว แต่ ALLOCATEID เป็นตัวเดียวกัน

```sql
SELECT BUDGETREQUESTID, PARENTID, PRODUCTID, ACTIVITYCODEID,
       ALLOCATEID, TOTALALLOCATEAMOUNT, TOTALREQUESTSIMMARYAMOUNT
FROM   OAGWBG_V_BUDGETALLOCATEITEM
WHERE  BUDGETYEAR = 2570 AND CATEGORY_ID = 2299;   -- ค่าโทรศัพท์
```

| BUDGETREQUESTID | PARENTID | PRODUCTID | ACTIVITYCODEID | ALLOCATEID | TOTALALLOCATEAMOUNT | REQSUM |
|---|---|---|---|---|---|---|
| 1095 | *(null)* | 0 | 0 | 73373 | 0 | 24,000 |
| **1200** | *(null)* | **21000** | **0** | **71756** | **68,000** | 12,000 |
| **1200** | *(null)* | **21000** | **0** | **71756** | **68,000** | 5,000 |
| **838** | *(null)* | **21000** | **21100** | **71966** | **488,295,999.52** | 122,063,999.88 |
| **954** | *(null)* | **21000** | **21100** | **71966** | **488,295,999.52** | 10,000 |
| 841 | *(null)* | 21000 | 21200 | 72905 | 0 | 602,200 |
| 855 | *(null)* | 21000 | 21300 | 73148 | 0 | 6,179,900.12 |

→ กลุ่ม `(21000, 0)` และ `(21000, 21100)` มี 2 แถว แชร์ `ALLOCATEID` เดียวกัน
→ โค้ด `Sum()` ทำให้แสดง **136,000** และ **976,591,999.04**

### 3.2 ตารางจริงไม่มี record ซ้ำ — ยืนยันว่าไม่ใช่ปัญหาข้อมูล แต่เป็นบั๊กโค้ด

```sql
SELECT PRODUCTID, ACTIVITYCODEID, BUDGETPLANID, BUDGETGOVERNMENTTYPE, COUNT(*)
FROM   OAGWBG_BUDGETGOVERNMENT
WHERE  BUDGETYEAR = 2570 AND CATEGORYID = 2299
  AND  BUDGETGOVERNMENTTYPE IN ('5','6','8')
GROUP  BY PRODUCTID, ACTIVITYCODEID, BUDGETPLANID, BUDGETGOVERNMENTTYPE
HAVING COUNT(*) > 1;
-- ผลลัพธ์: 0 rows  ✅ ไม่มี record ซ้ำ
```

`OAGWBG_BUDGETGOVERNMENT` มี type 5/6/8 อย่างละ 1 record ต่อ key เป๊ะ (15 records / 5 keys)
→ **ฝั่ง save ทำงานถูก ปัญหาอยู่ที่ฝั่งอ่านล้วน ๆ**

### 3.3 หลักฐานการทบต้น — ทุกรายการที่เพี้ยน DB เก็บไว้ 4 เท่าพอดี

| รายการ | Product/Activity | GOV ID | DB เก็บอยู่ | ยอดคำขอรวม | อัตราส่วน |
|---|---|---|---|---|---|
| ค่าโทรศัพท์ | 21000 / 21100 | 71966 | 488,295,999.52 | 122,073,999.88 | **4.00** |
| วัสดุสำนักงาน | 21000 / 21100 | 71936 | 222,876,760.00 | 55,719,190.00 | **4.00** |
| ค่าใช้จ่ายเดินทางไปราชการในประเทศ | 21000 / 21100 | 71834 | 105,185,936.16 | 26,296,484.04 | **4.00** |
| วัสดุเชื้อเพลิงและหล่อลื่น | 21000 / 21100 | 71939 | 88,366,080.80 | 22,203,520.20 | 3.98 |
| รถนั่งส่วนกลาง 1,400-1,600 ซีซี | 21000 / 21100 | 71993 | 9,604,800.00 | 2,401,200.00 | **4.00** |
| ค่าโทรศัพท์ | 21000 / 0 | 71756 | 68,000.00 | 17,000.00 | **4.00** |

ตรงเป๊ะ 4 เท่าทั้งกระดาน = ผู้ใช้กรอกยอดเท่ากับคำของบ แล้วกดบันทึก 3 ครั้ง (1 → 2 → 4)
หน้าจอตอนนี้จึงแสดง **8 เท่า** ของค่าที่ตั้งใจ

---

## 4. ขอบเขตผลกระทบ (Blast Radius)

```sql
-- นับกลุ่มที่ view คืนหลายแถวต่อ ALLOCATEID เดียว
WITH F AS (
  SELECT v.* FROM OAGWBG_V_BUDGETALLOCATEITEM v
  WHERE (v.TOTALREQUESTSIMMARYAMOUNT <> 0 OR v.BUDGETREQUESTID = 0)
    AND ( v.PARENTID IS NOT NULL
          OR NOT EXISTS (SELECT 1 FROM OAGWBG_V_BUDGETALLOCATEITEM c
                         WHERE c.BUDGETYEAR = v.BUDGETYEAR AND c.PARENTID IS NOT NULL
                           AND c.PARENTID = v.BUDGETREQUESTID) )
)
SELECT BUDGETYEAR, BUDGETFORMTYPEID, COUNT(*) FROM (
  SELECT BUDGETYEAR, BUDGETFORMTYPEID, BUDGET_PLAN_ID, PRODUCTID, ACTIVITYCODEID,
         BUDGET_TYPE_ID, CATEGORY_ID
  FROM F GROUP BY BUDGETYEAR, BUDGETFORMTYPEID, BUDGET_PLAN_ID, PRODUCTID,
                  ACTIVITYCODEID, BUDGET_TYPE_ID, CATEGORY_ID
  HAVING COUNT(*) > COUNT(DISTINCT ALLOCATEID)
) GROUP BY BUDGETYEAR, BUDGETFORMTYPEID;
```

**ผล: ปี 2570 ฟอร์ม 1 → 24 กลุ่ม** (ปี 2569 ไม่โดน เพราะแต่ละกลุ่มมีคำขอเดียว)

ตัวคูณต่อกลุ่ม (`COUNT(*) / COUNT(DISTINCT ALLOCATEID)`):

| ตัวคูณ | รายการ | ยอดจัดสรรตอนนี้ |
|---|---|---|
| **×100** | ค่าใช้สอย รายการไม่ผูกพัน (อื่นๆ โปรดระบุ...) — 21000/21100 | 0 (ยังไม่กรอก) |
| **×73** | ครุภัณฑ์ไม่ผูกพัน < 1 ล้าน (อื่นๆ) — 21000/21100 | 0 |
| **×45** | ค่าตอบแทน (อื่นๆ) — 21000/21100 | 0 |
| ×23, ×17, ×16, ×13, ×7, ×6, ×6, ×5, ×4, ×4, ×3 (×4 กลุ่ม) | หมวด "(อื่นๆ โปรดระบุ...)" อื่น ๆ | 0 |
| **×2** (6 กลุ่ม) | ค่าโทรศัพท์, วัสดุสำนักงาน, ค่าเดินทางฯ, วัสดุเชื้อเพลิงฯ, รถนั่งส่วนกลาง | **ผิดแล้ว** ดูตาราง 3.3 |

> ⚠️ กลุ่ม `(อื่นๆ โปรดระบุ...)` อันตรายที่สุด — เป็น dummy category ที่รวบรายการ free-text หลายสิบรายการเข้าเป็น category เดียว
> ถ้ามีคนไปกรอกเสนอจัดสรรที่รายการ **ค่าใช้สอย รายการไม่ผูกพัน (อื่นๆ)** จะเด้งเป็น **100 เท่า** ทันที

---

## 5. แนวทางแก้

### 5.1 แก้โค้ด (R2 — ย้อนกลับง่าย) — ✅ ทำแล้ว 2026-09-02

เพิ่ม helper `SumDistinctByRecord` ใน `BudgetService.cs` แล้วใช้แทน `Sum()` ตรง ๆ
กับทุกยอดที่มาจาก `OAGWBG_BUDGETGOVERNMENT` (จัดสรร / แปรญัตติ / คำขอแปรญัตติ / กันส่วนกลาง)

```csharp
/// view คืน 1 แถวต่อ 1 คำขอ แล้วแปะยอดจาก record เดียวกันซ้ำทุกแถว
/// Sum() ตรง ๆ จะคูณตามจำนวนคำขอ → ต้องนับแต่ละ record แค่ครั้งเดียว
private static decimal? SumDistinctByRecord(
    IEnumerable<OagwbgVBudgetallocateitem> items,
    Func<OagwbgVBudgetallocateitem, decimal?> idSelector,
    Func<OagwbgVBudgetallocateitem, decimal?> amountSelector)
{
    decimal total = 0;
    var counted = new HashSet<decimal>();

    foreach (var item in items)
    {
        var id = idSelector(item);
        if (id.HasValue && !counted.Add(id.Value))
        {
            continue;   // record เดิม นับไปแล้ว
        }
        total += amountSelector(item) ?? 0;
    }

    return total;
}
```

จุดที่เปลี่ยน (ทั้งระดับ ExpenseTypeGroup และระดับ Category ข้างใน):

| ฟิลด์ | เดิม | ใหม่ | key ที่ใช้ dedupe |
|---|---|---|---|
| `Totalrequestamount` | `Sum()` | `Sum()` *(คงเดิม)* | — per-request |
| `Totalrequestsimmaryamount` | `Sum()` | `Sum()` *(คงเดิม)* | — per-request |
| `Totalallocateamount` | `Sum()` | `SumDistinctByRecord` | `Allocateid` |
| `Totaladjustedamount` | `Sum()` | `SumDistinctByRecord` | `Adjustedid` |
| `Totalrequestadjustamount` | `Sum()` | `SumDistinctByRecord` | `Requestadjustid` |
| `Keptcentral` | `Sum()` | `SumDistinctByRecord` | `Keptcentralid` |
| `Totalrequestsumadjustamount` | `Sum()` | คำนวณจาก 2 ตัวข้างบน | — |

> `Totalrequestsumadjustamount` เดิม `Sum()` ค่าจาก view ซึ่งมี `Totalrequestadjustamount` ปนอยู่
> เปลี่ยนเป็นคำนวณเอง = `Totalrequestsimmaryamount + Totalrequestadjustamount` (หลัง dedupe แล้ว)

ชั้น 2-4 (`expensetypeGroups`, `activityGroup`, `productGroup`) รวมค่าจากชั้น 1 ที่ dedupe แล้ว → ถูกเองอัตโนมัติ ไม่ต้องแก้

**Build:** ผ่านทั้ง 2 โปรเจกต์ 0 error
(VS รันแอปค้างไว้ทำให้ bin ถูก lock — ต้อง build ลง `OutDir` แยกเพื่อยืนยัน)
```powershell
dotnet build "...\OAGBudget.API\OAGBudget.API.csproj" -p:OutDir=<temp>\api\   # Build succeeded, 0 Error(s)
dotnet build "...\OAGBudget\OAGBudget.csproj"         -p:OutDir=<temp>\web\   # Build succeeded, 0 Error(s)
```

**Verify กับข้อมูลจริง** — จำลอง logic ใหม่ด้วย SQL (`SUM` ของ `DISTINCT ALLOCATEID`):

| รายการ | Product/Activity | แสดงผลเดิม (ผิด) | แสดงผลใหม่ (ถูก) |
|---|---|---|---|
| ค่าโทรศัพท์ | 21000 / 21100 | 976,591,999.04 | **488,295,999.52** |
| วัสดุสำนักงาน | 21000 / 21100 | 445,753,520.00 | **222,876,760.00** |
| ค่าใช้จ่ายเดินทางไปราชการในประเทศ | 21000 / 21100 | 210,371,872.32 | **105,185,936.16** |
| วัสดุเชื้อเพลิงและหล่อลื่น | 21000 / 21100 | 176,732,161.60 | **88,366,080.80** |
| รถนั่งส่วนกลาง 1,400-1,600 ซีซี | 21000 / 21100 | 19,209,600.00 | **9,604,800.00** |
| ค่าโทรศัพท์ | 21000 / 0 | 136,000.00 | **68,000.00** |

ค่าใหม่ตรงกับที่เก็บใน `OAGWBG_BUDGETGOVERNMENT` เป๊ะ — ไม่คูณซ้ำแล้ว
และอีก 18 กลุ่มที่ยังเป็น 0 (ตัวคูณสูงสุด ×100) ก็ปลอดภัยแล้วเช่นกัน

### 5.2 ป้องกันการทบต้นซ้ำ (แนะนำเพิ่ม)

ตอนนี้ user กดบันทึกซ้ำ = ยอดเบิ้ลอีกรอบ ทั้งที่ไม่ได้แก้อะไร
ควรเพิ่ม guard ฝั่ง save — ถ้าค่าที่ส่งมาเท่ากับค่าเดิมใน DB ไม่ต้องเขียนทับ หรือส่ง `AllocateId` + ค่าเดิมไป validate

### 5.3 แก้ข้อมูลที่เพี้ยนแล้ว (R1 — ต้องยืนยันกับเจ้าของข้อมูลก่อน)

6 records ใน `OAGWBG_BUDGETGOVERNMENT` (ID: 71756, 71834, 71936, 71939, 71966, 71993)
ปัจจุบันเก็บค่าไว้ **4 เท่า** ของที่ควรจะเป็น

> ❗ **อย่าเพิ่งรัน UPDATE** — ต้องให้ผู้ใช้ยืนยันก่อนว่ายอดที่ถูกต้องคือเท่าไร
> ตัวเลข "4 เท่าของยอดคำขอรวม" เป็นการอนุมานจาก pattern ไม่ใช่ค่าที่ระบบบันทึกเจตนาไว้
> ทางที่ปลอดภัยกว่า: แก้โค้ดตาม 5.1 → deploy → ให้ผู้ใช้เข้าไปกรอกค่าที่ถูกต้องใหม่เอง

ตรวจรายการที่ต้องแก้:
```sql
SELECT ID, CATEGORYID, PRODUCTID, ACTIVITYCODEID, TOTALALLOCATEAMOUNT, BUDGETSTATUS
FROM   OAGWBG_BUDGETGOVERNMENT
WHERE  ID IN (71756, 71834, 71936, 71939, 71966, 71993);
```

---

## 6. หมายเหตุ — ข้อมูล DB ใน CLAUDE.md ไม่ตรงกับของจริง

`CLAUDE.md` ระบุ `HOST=172.16.11.19, SERVICE=ebs_PRE` แต่ไม่ได้ระบุ port และไฟล์
`DbCheck.ps1` ใช้ port **1521** ซึ่ง **ต่อไม่ได้**

ค่าที่ใช้งานได้จริง (ตรงกับ `OAGBudget.API/appsettings.Development.json` บรรทัดที่ยัง active):

```
HOST=172.16.11.19  PORT=1541  SERVICE_NAME=ebs_PRE  User=OAGWBG
```

- `172.16.11.19:1521` → ปิด
- `172.16.11.19:1561` → เปิด แต่เป็น service `ebs_TEST` (คนละ credential)
- `10.3.22.20:1561` → ต่อไม่ได้จาก VPN profile `_Common_ERP-MCR`

ควรอัปเดต `CLAUDE.md` และ `DbCheck.ps1` ให้ตรง

---

## 7. ไฟล์ที่เกี่ยวข้อง

| ไฟล์ | บทบาท |
|---|---|
| `OAGBudget.API/Services/Repository/BudgetService.cs:5564` | `GetBudgetAllocateItemsGroupByPlanId` — **จุดที่ต้องแก้** |
| `OAGBudget.API/Services/Repository/BudgetService.cs:4489` | `SaveBudgetAllocateDetail` — ทำงานถูก ไม่ต้องแก้ |
| `OAGBudget.API/Controllers/BudgetController.cs:687` | endpoint `GetBudgetAllocateItemsByTabPlanId` |
| `OAGBudget/Controllers/BudgetController.cs:1915` | `GetBudgetAllocateTabData` (MVC proxy) |
| `OAGBudget/Views/Budget/BudgetAllocateDetail.cshtml` | หน้าหลัก + JS บันทึก/`location.reload()` |
| `OAGBudget/Views/Shared/Partialviews/_tableBudgetAllocateDetailPersonal.cshtml` | ตารางที่มีคอลัมน์ "เสนอจัดสรร" (`Totalallocateamount3`) |
| `OAGWBG_V_BUDGETALLOCATEITEM` | View ที่คืนหลายแถวต่อ 1 record จัดสรร |
| `OAGWBG_BUDGETGOVERNMENT` | ตารางจริง — type 5 แปรญัตติ / 6 เสนอจัดสรร / 8 คำขอแปรญัตติ |
