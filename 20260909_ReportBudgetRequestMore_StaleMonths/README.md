# รายงานรายละเอียดขอรับจัดสรรงบประมาณเพิ่มเติม — รายงานยังจำเดือนเดิมที่เคยบันทึกไว้

**วันที่:** 2026-09-09
**เคสที่แจ้ง:** คำขอ `100-335/2569` แถบ **ประมาณการใช้จ่าย** แก้ไขเดือนที่เคยบันทึกไปแล้ว แต่รายงานยังจำเดือนเดิม
**ตรวจสอบบน:** PREPROD (ebs_PRE, 172.16.11.19:**1541**) — ยืนยันด้วยข้อมูลจริงแล้ว
**สถานะ:** แก้โค้ดครบ 3 จุดแล้ว (build ผ่าน 0 Error, verify กับ PREPROD แล้ว) — เหลือล้างข้อมูลขยะ + checkin

> ⚠️ ต่อเนื่องจาก [20260904_ReportBudgetRequestMore_Fixes](../20260904_ReportBudgetRequestMore_Fixes/README.md)
> รอบนั้นแก้เรื่อง "ค่าลงผิดคอลัมน์เดือน" รอบนี้เป็นคนละสาเหตุ — เดือนเก่ายอด 0 ที่ค้างใน DB

---

## สรุปย่อ

ไม่ใช่แค่หัวคอลัมน์เดือนผิด — **เงินหายจากรายงานจริง**
เคส `100-335/2569` ยอดจริง 1,500 บาท (ม.ค./ก.พ./มี.ค. เดือนละ 500) แต่รายงานออกมาแสดงแค่ **500 บาท**

| | ต.ค. 69 | พ.ย. 69 | ม.ค. 69 | รวมที่เห็น |
|---|---|---|---|---|
| **รายงานปัจจุบัน** | 0 | 0 | 500 | **500** ❌ |
| **ที่ควรได้** (ม.ค./ก.พ./มี.ค.) | 500 | 500 | 500 | **1,500** ✅ |

ก.พ. กับ มี.ค. หลุดออกจากรายงานไปเลย เพราะเดือนเก่ายอด 0 ไปกินโควตา 3 คอลัมน์

---

## หลักฐานจาก PREPROD

`OAGWBG_BUDGETREQUEST` `CODE = '100-335/2569'` → **ID 2288** (ปี 2569, STATUSID 10101)
→ `OAGWBG_BUDGETGOVERNMENT` **ID 73621** (`1/2569` — "วัสดุเชื้อเพลิง")

`OAGWBG_BUDGETDISBURSEMENTESTIMATED`:

| ID | MONTH | PLANAMOUNT | CREATEON | UPDATEON |
|---|---|---|---|---|
| 1549 | 10 (ต.ค.) | **0** | 09/09/2026 14:39:24 | 09/09/2026 14:41:19 |
| 1550 | 11 (พ.ย.) | **0** | 09/09/2026 14:39:24 | 09/09/2026 14:41:19 |
| 1551 | 1 (ม.ค.) | 500 | 09/09/2026 14:41:19 | |
| 1552 | 2 (ก.พ.) | 500 | 09/09/2026 14:41:19 | |
| 1553 | 3 (มี.ค.) | 500 | 09/09/2026 14:41:19 | |

อ่าน timeline ออกชัดเจน:

- **14:39:24** บันทึกครั้งแรก → ลง ต.ค. + พ.ย.
- **14:41:19** แก้ไข → ย้ายไป ม.ค./ก.พ./มี.ค. แต่แถว ต.ค./พ.ย. **ไม่ถูกลบ แค่ถูก UPDATE เป็น 0**

### ขนาดปัญหา (ปีงบ 2569 บน PREPROD)

```
แถว PLANAMOUNT = 0 ที่ค้างอยู่                              30 แถว
รายการ (BudgetGovernment) ที่มีเดือนขยะปนอยู่               10 รายการ
```

ทั้ง 10 รายการมีจำนวนเดือนทั้งหมด > จำนวนเดือนที่มียอดจริง คือกลุ่มที่รายงานเพี้ยนแน่นอน

---

## สาเหตุ (2 จุดต่อกัน)

### จุดที่ 1 — ตอนบันทึกไม่เคยลบเดือนเก่าทิ้ง

`OAGBudget.API/Services/Repository/BudgetService.cs` → `SaveBudgetDisbursementEstimate` (~บรรทัด 35251)

หน้าจอส่งมาครบ 12 เดือนทุกครั้งรวมเดือนที่เป็น 0
(`BudgetRequestMoreCostcenterExpensesDetail.cshtml` ~บรรทัด 572 วน `.BudgetDisbursementEstimatedInput` ทุกช่อง ไม่มีเงื่อนไขตัด 0)

```csharp
var entity = existingRecords.FirstOrDefault(x => x.Month == item.Month);

if (entity != null)
{
    // ===== UPDATE (ทั้ง > 0 และ = 0 → update ค่าตามจริง) =====
    entity.PlanAmount = item.PlanAmount;   // ← เดือนที่ล้างค่าแล้วกลายเป็น 0 แต่แถวยังอยู่
    ...
}
else if ((item.PlanAmount ?? 0) > 0)
{
    // ===== INSERT (เฉพาะเดือนที่ยังไม่มีข้อมูล และ PlanAmount > 0) =====
}
```

grep ทั้งไฟล์ — **ไม่มี `Remove` / `RemoveRange` สำหรับ `OagwbgBudgetdisbursementestimated` เลย**
แถวเดือนเก่าจึงค้างใน `OAGWBG_BUDGETDISBURSEMENTESTIMATED` ด้วย `PLANAMOUNT = 0` ตลอดไป

### จุดที่ 2 — รายงานเลือกคอลัมน์เดือนโดยไม่สนยอดเงิน

`OAGBudget.API/Services/Repository/ReportService.cs` → `ReportBudgetRequestMore` (~บรรทัด 8122)

```csharp
var rawData = await _context.OagwbgBudgetdisbursementestimated
    .Where(d => bgIds.Contains(d.BudgetGovernmentId)
             && d.BudgetYear == model.BudgetYear
             && d.BudgetGovernmentId != null
             && d.Month != null)          // ← ไม่มีเงื่อนไข PlanAmount > 0
    ...

var pickedMonths = rawData.Select(x => x.Month).Distinct()
    .OrderBy(m => m >= 10 ? m - 12 : m)
    .Take(3).ToList();
```

`pickedMonths` นับแถว 0 บาทเป็นเดือนที่ "มีข้อมูล" ด้วย แล้วส่งไปเป็นหัวคอลัมน์ 6/7/8 ตรง ๆ (~บรรทัด 9072)

**เดินตามเคสจริง:**

```
distinct months            = {10, 11, 1, 2, 3}
OrderBy(m >= 10 ? m-12 : m) = 10(-2), 11(-1), 1, 2, 3
Take(3)                     = [10, 11, 1]      ← ต.ค.(0), พ.ย.(0), ม.ค.(500)
                                                  ก.พ. + มี.ค. หลุดออกทั้งคู่
```

### จุดที่ 3 (ผลพลอยได้) — หน้าจอโหมดดูอย่างเดียวก็เพี้ยนตาม

`OAGBudget/Views/Budget/_partialView/_tableBudgetRequestDisbursementEstimated.cshtml` (~บรรทัด 37)

```csharp
var savedMonths = (Model ?? new List<OagwbgVBudgetdisbursementestimated>())
    .Where(x => x.Month != null)        // ← ดูแค่ Month ไม่ดูยอด
    .Select(x => x.Month.Value).ToHashSet();
```

ตอน `isView` (ยืนยันคำขอแล้ว) จะโชว์เดือนเก่ายอด 0 ปนมาด้วย
เคสนี้จะเห็น 5 แถว (ต.ค. 0, พ.ย. 0, ม.ค. 500, ก.พ. 500, มี.ค. 500) แทนที่จะเห็น 3 แถว

---

## การแก้ (ทำครบทั้ง 3 จุดแล้ว)

| ลำดับ | ไฟล์ | การแก้ | ระดับ |
|---|---|---|---|
| 1 | `OAGBudget.API/Services/Repository/ReportService.cs` | เติม `&& d.PlanAmount > 0` ใน `rawData` | R2 |
| 2 | `OAGBudget/Views/Budget/_partialView/_tableBudgetRequestDisbursementEstimated.cshtml` | `savedMonths` กรอง `(x.PlanAmount ?? 0) > 0` | R2 |
| 3 | `OAGBudget.API/Services/Repository/BudgetService.cs` | เปลี่ยน update-เป็น-0 → **ลบแถว** (`removedItems` + `RemoveRange`) | R1 |

### จุดที่ 3 — โครงสร้างใหม่ของ `SaveBudgetDisbursementEstimate`

```csharp
var removedItems = new List<OagwbgBudgetdisbursementestimated>();

if (entity != null && (item.PlanAmount ?? 0) > 0)
{
    // ===== UPDATE (เดือนที่ยังมียอดอยู่) =====
}
else if (entity != null)
{
    // ===== DELETE (เดือนที่ถูกล้างค่าออก) =====
    removedItems.Add(entity);
}
else if ((item.PlanAmount ?? 0) > 0)
{
    // ===== INSERT =====
}

// 3.1 ลบเดือนที่ถูกล้างค่าออก ไม่เก็บไว้เป็นแถวยอด 0
if (removedItems.Any())
    _context.OagwbgBudgetdisbursementestimated.RemoveRange(removedItems);
```

**ตรวจ dependency ก่อนเปลี่ยนมาลบแถว:** ไม่มี FK ชี้มาที่ตารางนี้เลย

```sql
SELECT ... FROM ALL_CONSTRAINTS c JOIN ALL_CONSTRAINTS r ON ...
WHERE c.CONSTRAINT_TYPE = 'R' AND r.TABLE_NAME = 'OAGWBG_BUDGETDISBURSEMENTESTIMATED';
-- => 0 rows
```

และแถวขยะทั้งหมดมี `BUDGETDISBURSEMENTPLANID = NULL` + `BUDGETGOVERNMENTID` ไม่ว่าง
คือของฝั่ง BudgetGovernment ล้วน ไม่มีแถวของโมดูลแผนการเบิกจ่ายปนมา

---

## ผลการ verify

### Build

```
dotnet build OAGBudget.sln -p:BaseOutputPath=<temp>
Build succeeded.  0 Error(s)
```

> ต้อง build ลง output แยก เพราะแอปรันค้างอยู่ใน VS แล้ว lock ไฟล์ใน `bin\` (MSB3021/MSB3027)
> เป็น file lock ไม่ใช่ compile error

### EF translation — รันจริงกับ PREPROD

SQL ที่ EF สร้างจาก LINQ ที่แก้:

```sql
SELECT "o"."BUDGETGOVERNMENTID", "o"."MONTH", COALESCE("o"."PLANAMOUNT", 0.0)
FROM "OAGWBG"."OAGWBG_BUDGETDISBURSEMENTESTIMATED" "o"
WHERE ("o"."BUDGETGOVERNMENTID" = 73621) AND ("o"."BUDGETYEAR" = :budgetYear_1)
  AND ("o"."BUDGETGOVERNMENTID" IS NOT NULL) AND ("o"."MONTH" IS NOT NULL)
  AND ("o"."PLANAMOUNT" > 0.0)
```

ผลของเคส `100-335/2569`:

```
rawData (3 rows):  Month=1 500 / Month=2 500 / Month=3 500
pickedMonths:      1, 2, 3          <-- เดิมได้ 10, 11, 1
รวมยอดที่แสดง:      1,500           <-- เดิมแสดง 500
รวมยอดจริง:         1,500  ✅ ตรงกัน
```

---

## ล้างข้อมูลขยะ (ยังไม่ได้รัน)

สคริปต์พร้อมแล้ว — ดู [`cleanup_delete.sql`](cleanup_delete.sql) และ [`cleanup_rollback.sql`](cleanup_rollback.sql)

```sql
DELETE FROM OAGWBG.OAGWBG_BUDGETDISBURSEMENTESTIMATED
WHERE  NVL(PLANAMOUNT, 0) = 0
AND    BUDGETGOVERNMENTID IS NOT NULL
AND    BUDGETDISBURSEMENTPLANID IS NULL;
-- 41 แถว (2569 = 30, 2570 = 11)
```

`cleanup_rollback.sql` เก็บ INSERT ครบ 29 คอลัมน์ทั้ง 41 แถวไว้แล้ว คืนค่าได้ทันที

**ข้อสังเกต:** BG `70815` (2569) มีแถวเดียวยอด 0 → หลังลบจะเหลือ 0 แถว
เป็นสถานะที่ถูกต้อง (ผู้ใช้ล้างประมาณการทิ้งไปแล้วจริง) ไม่ใช่ข้อมูลหาย

**ข้อสังเกต 2:** BG `48436` (2570) แถวยอด 0 ทั้ง 11 แถวมี `UPDATEON = NULL`
คือถูก INSERT เป็น 0 มาตั้งแต่แรก (โค้ดเวอร์ชันเก่าที่ยัง insert เดือนยอด 0)
ไม่ใช่ร่องรอยการแก้ไขเหมือนเคสอื่น แต่เป็นขยะแบบเดียวกันและลบได้เหมือนกัน

---

## ข้อควรระวังเพิ่มเติม

`Take(3)` เป็นข้อจำกัดของรายงานเอง (มีแค่ 3 คอลัมน์เดือน)
ถ้าคำขอมีเดือนที่มียอดจริงเกิน 3 เดือน จะยังตกหล่นอยู่ดี — **เป็นคนละเรื่องกับบั๊กนี้** และยังไม่ได้แก้

---

## หมายเหตุ: พอร์ต DB ใน CLAUDE.md ไม่ตรง

`CLAUDE.md` ระบุ PREPROD เป็น `172.16.11.19` เฉย ๆ และสคริปต์เก่าใช้พอร์ต **1521** ซึ่งต่อไม่ได้

ค่าที่ใช้จริง (จาก `OAGBudget.API/appsettings.Development.json` บรรทัดที่ไม่ถูก comment):

```
HOST=172.16.11.19  PORT=1541  SERVICE_NAME=ebs_PRE  User=OAGWBG
```

พอร์ตอื่นที่มีในไฟล์ config: `172.16.11.19:1561` (ebs_TEST), `172.16.11.18:1531` (PROD), `10.3.22.20:1561` (ebs_TEST)

## หมายเหตุ 2: ข้อมูล environment ใน CLAUDE.md ที่ไม่ตรงอีก 2 จุด

| หัวข้อ | CLAUDE.md | ของจริงบนเครื่องนี้ |
|---|---|---|
| Workspace path | `D:\TFS\OAG Budget\` | `C:\Users\thiha\Documents\TFS\OAG Budget\` |
| VS edition (path ของ TF.exe) | `...\2022\Community\...` | `...\2022\Professional\...` |

path ของ `TF.exe` ที่ใช้ได้จริง:

```
C:\Program Files\Microsoft Visual Studio\2022\Professional\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\TF.exe
```

## หมายเหตุ 3: ต่อ VPN แล้ว TFS จะเข้าไม่ได้

F5 (`_Common_ERP-MCR`) ยึด default route `0.0.0.0/0` ทั้งหมด
TFS server (`dev.softsuite.co.th\SSCollection` → `172.26.22.241:8080`) จึงติดต่อไม่ได้ระหว่างต่อ VPN

```
TF400324: Azure DevOps services are not available from server dev.softsuite.co.th\SSCollection.
  No connection could be made because the target machine actively refused it 172.26.22.241:8080
```

⇒ **ต่อ VPN = คุย DB ได้ แต่ checkin ไม่ได้** / **ตัด VPN = checkin ได้ แต่คุย DB ไม่ได้**
ต้องสลับกันทำ

---

## SQL ที่ใช้ตรวจสอบ

ดู [`verify.sql`](verify.sql)
