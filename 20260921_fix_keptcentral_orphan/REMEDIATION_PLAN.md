# แผนแก้บั๊กทั้งหมดที่เจอ — คำของบประมาณ ภาพรวม / keptcentral

**สำรวจเมื่อ:** 2026-09-21 ถึง 2026-09-22
**ขอบเขต:** ทุกอย่างที่เจอระหว่างไล่เคส "งบหาย" ของ keptcentral

---

## 🔥 เริ่มตรงนี้ก่อน (วันนี้)

### 0.1 แจ้งผู้ใช้ให้หยุดกดปุ่ม "บันทึก" ที่หน้า "คำของบประมาณ ภาพรวม"

**ใช้เวลา:** 5 นาที · **ความเสี่ยง:** 0 · **ได้:** หยุดความเสียหายที่กำลังเกิดอยู่

ตัวเลขบนจอ **ถูกต้องแล้ว** (ยืนยัน category 2372 ปี 2570 = 85,620) ดูได้ตามปกติ
เสียหายเฉพาะตอน **กดบันทึก** เพราะบั๊ก **D** และ **E** ด้านล่าง — ทุกคลิกทำให้ยอดบวมและข้อมูลไปกองผิดศูนย์ต้นทุน

### 0.2 checkin JS 2 ไฟล์ที่แก้แล้ว

**ใช้เวลา:** 10 นาที · **ความเสี่ยง:** ต่ำ · build ผ่าน 0 Error แล้ว

```
OAGBudget/Views/Budget/BudgetRequestSummaryDetail.cshtml                  (บั๊ก B)
OAGBudget/Views/Budget/_partialView/_tabBudgetRequestSummaryDetail.cshtml (บั๊ก C)
```

ทั้งคู่แก้คนละจุดกับ D/E ขึ้นได้เลยไม่ต้องรอ

### 0.3 ถามเจ้าของระบบ 1 คำถาม (บล็อกงานใหญ่สุด)

> **หน้า "คำของบประมาณ ภาพรวม" ควรให้กรอกเงินกั้นส่วนกลางแบบไหน**
> **(ก) 1 ช่องต่อ 1 หมวด** รวมทุกศูนย์ต้นทุน  หรือ
> **(ข) 1 ช่องต่อ 1 รายการ** แยกตามศูนย์ต้นทุน

คำตอบนี้กำหนดว่าจะแก้บั๊ก **D** ทางไหน และเป็นงานที่เสียหายหนักสุด
ระหว่างรอคำตอบ ทำข้อ **1** ได้เลย

---

## ตารางสรุปบั๊กทั้งหมด

| # | บั๊ก | ความรุนแรง | สถานะ | ทำได้เลยไหม |
|---|---|---|---|---|
| **A** | keptcentral orphan เมื่อคำขอถูกตีกลับ | 🔴 114.69 ล้าน | ✅ แก้ view แล้ว (กู้ 114.57 ล้าน) | ต้นเหตุยังไม่ปิด → ข้อ 1 |
| **B** | JS `\|\| null` ทำให้ค่า 0 กลายเป็น NULL | 🟠 | ✅ แก้แล้ว รอ checkin | ✅ |
| **C** | JS `td:eq(3)` ผิดคอลัมน์ 4 จุด | 🟡 หน้าจอเท่านั้น | ✅ แก้แล้ว รอ checkin | ✅ |
| **D** | UI ยุบแถวข้ามศูนย์ต้นทุน → บันทึกลง ID เดียว | 🔴🔴 ยอดบวมทบต้น | ❌ | ต้องตัดสินใจก่อน |
| **E** | กดบันทึก 1 ครั้ง เขียน 951 แถว ไม่มี concurrency | 🔴🔴 ล้างงานคนอื่น | ❌ | ต้องตัดสินใจก่อน |
| **F** | GET ที่ INSERT ลง DB ไม่มี lock | 🟡 | ❌ | ✅ |
| **G** | สร้าง type-4 แค่ 1 แถวต่อ Category | 🟡 | ❌ | ขึ้นกับ D |
| **H** | save หาแถวด้วย REF ไม่กรอง type/ปี แล้วบังคับเป็น '4' | 🟠 ระเบิดเวลา | ❌ | ✅ |
| **I** | เรียก `Add()` กับ entity ที่ track อยู่แล้ว | 🟡 | ❌ | ✅ |
| **J** | guard clone ไม่กันการ clone ซ้ำที่คำขอต้นฉบับ | 🟠 ระเบิดเวลา | ❌ | ✅ |
| **K** | ไฟล์แนบหาย 4 กลไก | 🟠 | ❌ | รอยืนยันอาการ |
| **L** | `GROUP BY REF, BUDGETDETAIL` ใน report view | 🟡 ระเบิดเวลา | ❌ | ✅ |
| **M** | `R_BUDGETREQUEST_ASSET` มี dead join | 🟢 | ❌ | ✅ |

---

## 1. ปิดต้นเหตุ orphan — `DuplicatePlanData` (ทำได้เลย ไม่ต้องรอใคร)

**ทำไมเร่ง:** ทุกครั้งที่สำนักฯ กดปุ่ม "แก้ไข" (`STATUSID 20101 → 20102`) จะเกิด orphan ใหม่
PREPROD ยิงไปแล้ว 37 ครั้งในปี 2569 ปีเดียว และตอนนี้ **คำขอ 918 กับ 941 ยังนั่งรออยู่ที่ 20101**

**ไฟล์:** `OAGBudget.API/Services/Repository/BudgetService.cs`

| method | บรรทัด | ต้องทำ |
|---|---|---|
| `DuplicatePlanData` | ~34704 | duplicate แถว type-4 + repoint REF ด้วย `govIdMap` |
| `DuplicateProjectData` | ~34922 | เหมือนกัน + copy ไฟล์แนบ `Referencetable='Project'` ด้วย |
| `DuplicateProjectsInRequest` | ~35257 | เหมือนกัน + copy ไฟล์แนบ (ตอนนี้ไม่ copy เลย) |

แนวทาง — หลัง build `govIdMap` เสร็จ (ตอนนี้เขียนแล้วไม่เคยถูกอ่าน):

```csharp
// แถว type-4 มี BUDGETREQUESTID = NULL จึงไม่เคยอยู่ใน oldGovs
// ต้องดึงด้วย REF แทน
var oldIds = govIdMap.Keys.ToList();
var oldKept = await _context.OagwbgBudgetgovernments
    .AsNoTracking()
    .Where(x => x.Budgetgovernmenttype == "4"
             && x.RefBudgetgovernmentid != null
             && oldIds.Contains((int)x.RefBudgetgovernmentid.Value))
    .ToListAsync();

foreach (var k in oldKept)
{
    _context.OagwbgBudgetgovernments.Add(new OagwbgBudgetgovernment {
        Budgetgovernmenttype  = "4",
        RefBudgetgovernmentid = govIdMap[(int)k.RefBudgetgovernmentid.Value],  // ← ชี้ BG ใหม่
        Keptcentral    = k.Keptcentral,
        Budgetyear     = k.Budgetyear,
        Budgetplanid   = k.Budgetplanid,
        Budgetformtypeid = k.Budgetformtypeid,
        Budgetexpensetypeid = k.Budgetexpensetypeid,
        Expensetypeid  = k.Expensetypeid,
        Categoryid     = k.Categoryid,
        Projectid      = k.Projectid,
        Budgetdetail   = k.Budgetdetail,
        RefBudgetdetail = k.RefBudgetdetail,
        Productid      = k.Productid,
        Activitycodeid = k.Activitycodeid,
    });
}
await _context.SaveChangesAsync();
```

> ⚠️ `oldIds.Contains(...)` แปลงเป็น `IN (...)` — ถ้าเกิน 1,000 ตัวต้องแบ่ง batch (Oracle จำกัด)
> ⚠️ อย่าใช้ `AnyAsync` ที่ไหนในงานนี้ — พังบน Oracle ด้วย ORA-00904 "FALSE"

**ทดสอบ:** ตีกลับคำขอ 1 ใบบน TEST แล้วเช็คว่าคำขอลูกมี type-4 ครบเท่าแม่
**ผลพลอยได้:** fallback ใน view จะกลายเป็นตาข่ายสำรองสำหรับข้อมูลเก่าเท่านั้น
สมมติฐาน 3 ข้อที่ view ฝากไว้ (ลึกไม่เกิน 2 ชั้น / พ่อมีลูกใบเดียว / REF เป็น 1:1) ไม่ต้องรักษาอีก

---

## 2. บั๊ก D + E — ต้องรอคำตอบข้อ 0.3 ก่อน

### D. UI ยุบแถวข้ามศูนย์ต้นทุนแล้วบันทึกลง ID เดียว

**หลักฐาน (console จาก PROD):**
```
{DetailId: "56985", RefId: "51074", kept: "118,020.00"}   ← ยุบ 4 BG เป็น 1 บรรทัด
```
4 แถวใน view (BG 51,074 / 49,479 / 73,147 / 73,275) ยุบเป็นบรรทัดเดียว
กดบันทึก → `118,020` ลง type-4 row **56,985** ซึ่งเป็นของ **คำขอ 941 ศูนย์ต้นทุน 2900600011**
ส่วน BG 73,147 (คำขอ 1776 ศูนย์ 2900600103) ไม่เคยได้ค่าเป็นของตัวเอง

```
รอบ 1  59,010 + 59,010 = 118,020
รอบ 2 118,020 + 59,010 = 177,030
รอบ 3 177,030 + 59,010 = 236,040     ← บวกทบทุกครั้ง
```

**ขนาด (PREPROD):** ~50% ของบรรทัดบนจอยุบจากหลาย BG บางบรรทัดยุบถึง **552 แถว**

**สาเหตุราก:** ข้อมูลเก็บ **รายบรรทัด** (`REF_BUDGETGOVERNMENTID` ชี้ BG ทีละแถว)
แต่หน้าจอให้กรอก **รายหมวด** (ยุบข้ามศูนย์ต้นทุน) → 1 ช่องกรอกแทน N บรรทัด
**ตอนบันทึกจึงไม่มีทางรู้ว่าควรกระจายยังไง ไม่ว่าเขียนโค้ดยังไงก็ผิด**

**ทางเลือก:**

| | ทำอะไร | ผล |
|---|---|---|
| **A** | เพิ่ม `RefGovernmentid` เข้า grouping key ที่ [BudgetService.cs:8956](../../OAGBudget.API/Services/Repository/BudgetService.cs) | ✅ ถูกตามโครงสร้าง ❌ 576 → หลายพันบรรทัด |
| **B** | บรรทัดที่ยุบหลาย BG → readonly | ✅ กันเสียหาย ❌ ~50% กรอกไม่ได้ ต้องมีหน้าอื่น |
| **C** | เอาปุ่มบันทึกออก ให้เป็นหน้าดูอย่างเดียว | ❌ ต้องมีที่อื่นให้กั้นเงิน |

**แนะนำ A** — เป็นทางเดียวที่ตรงกับวิธีเก็บข้อมูล แต่เปลี่ยนหน้าตาหน้าจอชัดเจน

### E. กดบันทึก 1 ครั้ง เขียน 951 แถว ไม่มี optimistic concurrency

**หลักฐาน:** `UPDATEON = 2026-09-21 14:16:20.471` ตรงกันถึงมิลลิวินาที **951 แถว**
และ `2026-09-18 17:41:43` → **187 แถว ถูกล้างเป็น NULL ทั้งหมดในคลิกเดียว**

**สาเหตุ:**
- [BudgetRequestSummaryDetail.cshtml:129](../../OAGBudget/Views/Budget/BudgetRequestSummaryDetail.cshtml) `$('tr#GrandChild')` เป็น selector ระดับ document → เก็บทั้ง 4 แท็บ
- หน้านี้เป็น **ภาพรวมทั้งปี ไม่มี filter ศูนย์ต้นทุน** → เขียนทับทุกศูนย์
- [BudgetService.cs:8433](../../OAGBudget.API/Services/Repository/BudgetService.cs) `item.Keptcentral = ...` ไม่เช็ค version

**ทางเลือก:** ส่งเฉพาะแถวที่แก้ / จำกัดที่แท็บที่เปิดอยู่ / เพิ่ม version check
ทั้งหมดเปลี่ยน behavior → ต้องให้เจ้าของระบบเลือก

---

## 3. ไฟล์แนบ (K) — รอยืนยันอาการก่อน

4 กลไกแยกกัน ไล่มาแล้วแต่ยังไม่รู้ว่าผู้ใช้เจอตัวไหน:

| # | กลไก | หลักฐาน |
|---|---|---|
| **K1** | save เขียนหลายไฟล์ แต่ read ใช้ `FirstOrDefaultAsync()` คืนไฟล์เดียว | **397 เจ้าของมีไฟล์ > 1** (สูงสุด 46 ไฟล์) |
| **K2** | `DuplicateProjectsInRequest` ไม่ copy ไฟล์แนบเลย | ยิงตอนอนุมัติคำขอโครงการ |
| **K3** | clone copy เฉพาะ `Referencetable='BudgetGovernment'` ไม่ copy `'Project'` | 322 ไฟล์กลุ่มนี้เสี่ยงทั้งหมด |
| **K4** | ลบ BG/Project แต่ไม่ลบไฟล์แนบตาม | **942 ไฟล์ orphan** (ก.ค. 2026 พุ่ง 621 ไฟล์) |

**K1 น่าจะตรงอาการ "บางไฟล์หาย" ที่สุด และแก้ง่ายที่สุด** — เปลี่ยน `FirstOrDefaultAsync()`
เป็น `ToListAsync()` + ส่งกลับเป็น list (ต้องแก้ ViewModel และหน้าจอด้วย)

**ต้องรู้ก่อน:** อาการเกิดที่หน้าไหน / ขั้นตอนไหน — เดาผิดจะแก้ผิดจุด

---

## 4. งานเก็บกวาด (ยังไม่เกิด แต่ควรปิด)

| # | เรื่อง | รายละเอียด |
|---|---|---|
| **H** | `SaveBudgetRequestSummaryDetail` สาขา `Id == 0` หาแถวด้วย `RefBudgetgovernmentid` **ไม่กรอง type ไม่กรองปี** แล้วบังคับ `Budgetgovernmenttype = "4"` | มี 142 แถว type-null ถือ REF อยู่ และชน REF เดียวกับ type-4 — ตรวจแล้ว **ยังไม่เคยเกิด** (type-4 ทุกแถวไม่มีร่องรอยแถวจริง) |
| **J** | guard clone เช็ค `existing.Parentid == null` ซึ่งเป็น "ตัวเองไม่มีพ่อ" ไม่ใช่ "ตัวเองไม่มีลูก" | ตั้งคำขอต้นฉบับเป็น 20102 ซ้ำ → clone อีกใบ → ยอดนับซ้ำ **ยังไม่เคยเกิด (0 เคส)**<br>🚨 แก้ต้องเก็บ **ทั้งสอง** เงื่อนไข: `(Parentid == null) && !hasChild`<br>ถ้าตัด `Parentid == null` ทิ้ง จะเกิด **หลาน** และ fallback ใน view รองรับแค่ชั้นเดียว → พังทันที |
| **F** | `GetGroupBudgetSummaryPlan` เป็น GET แต่ INSERT ลง DB ไม่มี lock | เปิดหน้าพร้อมกันอาจได้แถวซ้ำ |
| **G** | สร้าง type-4 แค่ 1 แถวต่อ Category | BG แถวอื่นใน category เดียวกันได้ NULL ถาวร — ขึ้นกับว่า D เลือกทางไหน |
| **I** | สาขา `Id == 0` เรียก `Add(item)` นอก if/else จึงโดน entity ที่ track อยู่แล้วด้วย | อาจ insert ซ้ำ |
| **L** | `R_BUDGETREQUEST` / `R_BUDGETREQUEST_ASSET` ใช้ `GROUP BY REF_BUDGETGOVERNMENTID, BUDGETDETAIL` | ถ้าวันหน้ามี type-4 หลายแถวต่อ REF ที่ BUDGETDETAIL ต่างกัน → fan-out และ `REQUESTAMOUNT` นับซ้ำ (ตอนนี้ REF เป็น 1:1 ยังไม่เกิด) |
| **M** | `R_BUDGETREQUEST_ASSET` มี BG4 join แต่ไม่มีคอลัมน์จาก BG4 ใน select list | dead join ลบทิ้งได้ ลดภาระ query |

---

## ลำดับที่แนะนำ

```
วันนี้     0.1 แจ้งผู้ใช้หยุดกดบันทึก          ← หยุดเลือดทันที
           0.2 checkin JS 2 ไฟล์
           0.3 ถามเจ้าของระบบ (ก) หรือ (ข)

สัปดาห์นี้  1.  DuplicatePlanData + อีก 2 method  ← ปิดต้นเหตุ ทำได้เลย
           3.  ยืนยันอาการไฟล์แนบ แล้วแก้ K1

รอคำตอบ    2.  บั๊ก D + E                        ← หนักสุด แต่ต้องตัดสินใจก่อน

ทีหลัง     4.  H J F G I L M
```

**ถ้าเลือกได้อย่างเดียววันนี้: ข้อ 0.1** — ไม่ต้องเขียนโค้ดสักบรรทัด แต่หยุดความเสียหายที่กำลังเกิดจริง

---

## หลักฐานทั้งหมดอยู่ที่

| ไฟล์ | เนื้อหา |
|---|---|
| `README.md` | สาเหตุ A + diagram + หลักฐาน + ตัวกระตุ้น |
| `RUNBOOK.md` | ขั้นตอน deploy view fix |
| `01_preflight_ALL.sql` | ตรวจก่อน deploy (7 คำสั่ง) |
| `03_verify_after_deploy.sql` | ตรวจหลัง deploy |
| `04_explain_gap.sql` | อธิบายส่วนต่าง TABLE vs VIEW ทีละบาท |
| `05_check_fallback_leak.sql` | ตรวจว่า fallback ดึงยอดเกินหรือไม่ |
