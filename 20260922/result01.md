# วิเคราะห์บั๊ก: บันทึกคำของบประมาณเพิ่มเติม แล้วเขียนทับคำขอเดียว

**วันที่วิเคราะห์:** 2026-09-22
**หน้าที่เกี่ยวข้อง:** `Budget/BudgetRequestSummaryDetail` (คำของบประมาณ ภาพรวม)
**สถานะ:** วิเคราะห์อย่างเดียว **ไม่มีการแก้ไขโค้ดใด ๆ** ตามที่กำหนดใน prompt ข้อ 4

---

## สรุปสั้น

ยืนยันบั๊กตามที่แจ้งมา และหาสาเหตุรากได้แล้ว **สรุปได้เป็นประโยคเดียว:**

> ## `Totalkeptcentral` ไม่ควรใช้ `g.Sum()`

ช่อง **"คำของบประมาณ"** ต้องรวมทุกศูนย์ต้นทุน — ส่วนช่อง **"คำของบประมาณเพิ่มเติม"** เป็น
**เงินก้อนเดียวระดับกลุ่มรายการ** ที่ส่วนกลางเติมให้ **ห้ามรวมข้ามแถว**
แต่โค้ดใช้ `Sum` เหมือนกันทั้งสองช่อง

```csharp
// BudgetService.cs:8964-8966
Totalrequestamount  = g.Sum(x => x.Totalrequestamount ?? 0),   // ✅ ถูก
Totalkeptcentral    = g.Sum(x => x.Totalkeptcentral ?? 0),     // ❌ ผิด — ก้อนเดียว ห้ามรวม
Totalreceiveamount  = g.Sum(x => x.Totalreceiveamount ?? 0),   // ❌ ผิดตาม
```

พอรวมข้ามแถว ยอดบนจอจึงเกิน และตอนบันทึกก็เหลือ `Id` เดียวให้เขียน
→ ยอดที่รวมเกินมาถูกยัดลงคำขอใบเดียว และ **บวกทบขึ้นทุกครั้งที่กดบันทึก**

---

## หลักฐานจาก PROD

### กรณีตัวอย่าง — CATEGORY_ID 2372 ปีงบ 2570

view `OAGWBG_V_BUDGETREQUESTSUMMARY` คืน **4 แถว** ที่มี grouping key เหมือนกันทุกช่อง
(`BUDGETPLANID 3124` · `PRODUCTNAME "การอำนวยความยุติธรรม..."` · `ACTIVITYNAME "งานอำนวยความยุติธรรม"` · `CATEGORY_ID 2372`):

| REF_GOVERNMENTID | คำขอ | เพิ่มเติม | ที่มาของค่า | คำขอ | ศูนย์ต้นทุน |
|---|---|---|---|---|---|
| **51,074** | 129,600 | **59,010** | ของตัวเอง (type-4 row 56,985) | 941 | 2900600011 |
| 49,479 | — | NULL | — | | |
| **73,147** | 64,800 | **59,010** | fallback จากคำขอแม่ 1073 | 1776 | 2900600103 |
| 73,275 | — | NULL | — | | |

### สิ่งที่ JS ส่งขึ้นไปจริง (console จากเครื่อง PROD)

```
{DetailId: "56985", RefId: "51074", kept: "118,020.00"}
{DetailId: "72087", RefId: "47495", kept:  "-32,400.00"}
length: 2
```

**4 แถวยุบเหลือ 1 บรรทัด** ยอดรวม `59,010 + 0 + 59,010 + 0 = 118,020`
แต่ `DetailId` มีแค่ **56,985** ตัวเดียว ซึ่งเป็น type-4 row ของ **คำขอ 941 (ศูนย์ต้นทุน 2900600011)**

> ยอดที่แสดงบนจอ **ถูกต้อง** (118,020 − 32,400 = 85,620) — เสียหายเฉพาะตอน **กดบันทึก**

### ผลเมื่อกดบันทึก

```
รอบ 1   51,074 ← 118,020 (ทับของเดิม 59,010)   |  73,147 ไม่ได้อะไรเลย
รอบ 2   51,074 own 118,020 + 73,147 fallback 59,010 = 177,030
รอบ 3   177,030 + 59,010 = 236,040
```

**บวกทบ 59,010 ทุกครั้งที่กดบันทึก** และ BG 73,147 (ศูนย์ 2900600103) ไม่เคยได้ค่าเป็นของตัวเองเลย

### ขนาดของปัญหา (วัดจาก PREPROD)

| ปีงบ | บรรทัดบนจอ | บรรทัดที่ยุบจากหลาย BG | % | ยุบมากสุด |
|---|---|---|---|---|
| 2569 | 576 | 222 | 38.5% | **391 BG** |
| 2570 | 631 | 310 | 49.1% | **552 BG** |

**เกือบครึ่งของบรรทัดบนหน้าจอมีปัญหานี้ ไม่ใช่เคสหายาก** และบางบรรทัดยุบถึง 552 รายการ
= กดบันทึก 1 ครั้ง ยอดของ 552 รายการถูกยัดลง type-4 row เดียว

---

## Task 1 — ไฟล์ทั้งหมดที่เกี่ยวข้อง

### 🔴 ไฟล์ที่ต้องแก้แน่นอน

| Layer | ไฟล์ | บรรทัด | บทบาทในบั๊ก |
|---|---|---|---|
| **API Service** | `OAGBudget.API/Services/Repository/BudgetService.cs` | **8927** | `GroupBy` 9 field **ไม่มีศูนย์ต้นทุน** ← ต้นเหตุหลัก |
| | ↑ | **8944** | `itemWithId = g.OrderBy(x => x.Id).FirstOrDefault(x => x.Id != null)` |
| | ↑ | **8949** | `Id = itemWithId?.Id ?? 0` ← เก็บ ID เดียวจากทั้งกลุ่ม |
| | ↑ | **8965** | `Totalkeptcentral = g.Sum(...)` ← รวมยอดข้ามศูนย์ต้นทุน |
| | ↑ | **~9007** | `RefGovernmentid = (int)(firstItem?.RefGovernmentid)` ← มาจากคนละแถวกับ `itemWithId` |
| | ↑ | **8412–8460** | `SaveBudgetRequestSummaryDetail` สาขา `Id != 0` เขียนทับแถวเดียว |
| **View (partial)** | `OAGBudget/Views/Budget/_partialView/_tabBudgetRequestSummaryDetail.cshtml` | 174 | `<tr id="GrandChild">` — 1 แถวต่อ 1 กลุ่ม |
| | ↑ | 192 | `<input id="DetailId" value="@detail.Id" />` |
| | ↑ | 200 | `<input id="RefId" value="@detail.RefGovernmentid" />` |
| | ↑ | 204 | `<input class="detail-Totalkeptcentral" />` ← ช่องกรอกช่องเดียวต่อกลุ่ม |
| **View (หลัก)** | `OAGBudget/Views/Budget/BudgetRequestSummaryDetail.cshtml` | 129 | `$('tr#GrandChild')` เก็บทุกแถวทั้ง 4 แท็บ |
| | ↑ | 154 | `id: parseInt($grandChild.find('#DetailId').val()) \|\| 0` |
| | ↑ | 168 | `RefGovernmentid: ...#RefId...` |

### 🟢 ไฟล์ที่อยู่ในเส้นทางแต่ **ไม่ต้องแก้** (เป็น pass-through)

| Layer | ไฟล์ | บรรทัด | หมายเหตุ |
|---|---|---|---|
| MVC Controller | `OAGBudget/Controllers/BudgetController.cs` | 1482 | `BudgetRequestSummaryDetail(budgetYear, budgetFormTypeId)` |
| | ↑ | 1562 | `SaveBudgetRequestSummaryDetail` |
| | ↑ | 1505 | `ConfirmBudgetRequestSummary` |
| MVC Service | `OAGBudget/Services/Repository/BudgetService.cs` | 2381 / 2416 / 2453 | proxy ผ่าน HTTP ไป API เฉย ๆ |
| API Controller | `OAGBudget.API/Controllers/BudgetController.cs` | 1142 / 1054 / 1184 / 1170 | endpoint เรียก service ตรง ๆ |
| API Service | `OAGBudget.API/Services/Repository/BudgetService.cs` | 8388 | `GetBudgetRequestSummaryDetail` เรียก `GetGroupBudgetSummaryPlan` 4 รอบ (แท็บละรอบ) |

> **หมายเหตุ:** `Budget/GetGroupBudgetSummaryPlan` มี endpoint อยู่ที่ API (บรรทัด 1184)
> แต่ **หน้าจอไม่ได้เรียก endpoint นี้โดยตรง** — ถูกเรียกภายในจาก `GetBudgetRequestSummaryDetail`
> ฝั่ง MVC ไม่มี action ชื่อนี้

### 🟡 DAL — ไม่ต้องแก้ แต่ต้องรู้ว่า map อะไรอยู่

| Entity | ไฟล์ | บรรทัด | map ไปที่ |
|---|---|---|---|
| `OagwbgBudgetgovernment` | `OAGBudget.DAL/Models/OAGDBContextBase.cs` | 3267 | **TABLE** `OAGWBG_BUDGETGOVERNMENT` |
| `OagwbgVBudgetrequestsummary` | ↑ | 16155 | VIEW `OAGWBG_V_BUDGETREQUESTSUMMARY` |
| `OagwbgVBudgetrequestsummarylist` | ↑ | 16239 | VIEW `OAGWBG_V_BUDGETREQUESTSUMMARYLIST` |
| `OagwbgVExtOaginvCategoryCodesV` | ↑ | 18177 | VIEW `OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V` |

### 🟡 Models / DTO — ต้องเพิ่ม 1 property (ดูหัวข้อ "แนวทางแก้ไข")

| ไฟล์ | class | บทบาท |
|---|---|---|
| `OAGBudget.Models/ViewModel/BudgetRequestSummaryDetailViewModel.cs` | `BudgetRequestSummaryDetailViewModel` | โครงหลัก 4 แท็บ |
| ↑ | `BudgetRequestSummaryProductGroup` | ระดับผลผลิต |
| ↑ | `BudgetRequestSummaryActivityGroup` | ระดับกิจกรรม |
| ↑ | `BudgetRequestSummaryParentDetail` | ระดับประเภทรายจ่าย |
| ↑ | `BudgetRequestSummaryChildDetail` | ระดับหมวด → มี `List<OagwbgVBudgetrequestsummary> Detail` คือแถว GrandChild |
| `OAGBudget.DAL/Models/OagwbgVBudgetrequestsummary.cs` | — | DTO ที่ใช้ทั้งขารับและขาส่ง **ไม่มีฟิลด์ศูนย์ต้นทุน** |
| `OAGBudget.Models/RawData/SubAccountEbudgetingResult.cs` | — | ผลจาก raw SQL รหัส E-Budgeting |

---

## Task 2 — Oracle Table / View / Stored Procedure

### ตารางจริงที่ถูกเขียน

| Object | ชนิด | บทบาท |
|---|---|---|
| **`OAGWBG_BUDGETGOVERNMENT`** | **TABLE** | **ตารางเดียวที่ถูกเขียนในเส้นทางนี้** |

เงินกั้นส่วนกลางเก็บเป็น **แถวแยก** ในตารางเดียวกัน:

```
BUDGETGOVERNMENTTYPE   = '4'          ← แถวเงินกั้นส่วนกลาง
REF_BUDGETGOVERNMENTID = <BG.ID>      ← ชี้กลับไปยังรายการงบประมาณทีละแถว
KEPTCENTRAL            = <จำนวนเงิน>
BUDGETREQUESTID        = NULL         ← แถว type-4 ไม่ผูกกับคำขอโดยตรง
```

> **นี่คือหัวใจของปัญหา** — โครงสร้างเก็บ **รายบรรทัด** แต่หน้าจอให้กรอก **รายหมวด**

ความหมายของ `BUDGETGOVERNMENTTYPE`:

| ค่า | ความหมาย |
|---|---|
| `NULL` | รายการงบประมาณปกติ |
| `'4'` | **เงินกั้นส่วนกลาง** |
| `'5'` | แปรญัตติ |
| `'6'` | รวมงบประมาณ |
| `'7'` | แถวที่ clone มาจากการตีกลับคำขอ |

### View ที่ถูกอ่าน

| Object | ใช้ที่ |
|---|---|
| `OAGWBG_V_BUDGETREQUESTSUMMARY` | แหล่งข้อมูลหลักของ `GetGroupBudgetSummaryPlan` |
| `OAGWBG_V_BUDGETREQUESTSUMMARYLIST` | ช่อง "งบประมาณรวม" หัวหน้าจอ |
| `OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V` | ชื่อหมวด / รหัส / ประเภทรายจ่าย |
| `APPS.OAGINV_GL_SUBACCOUNT_EBUDGETING_V` | raw SQL รหัส E-Budgeting (บรรทัด ~9012) |

ตารางอื่นที่ view ใช้ภายใน: `OAGWBG_BUDGETREQUEST`, `OAGWBG_PROJECT`, `OAGWBG_PROJECTTARGETS`,
`OAGWBG_V_EXT_OAGGL_BUDGET_ACTIVITY_V`, `OAGWBG_V_EXT_OAGGL_BUDGET_PRODUCT_V`

### ❌ Stored Procedure และ Temp table

**ไม่มีทั้งคู่**

- ตรวจ `FromSqlRaw` / `ExecuteSqlRaw` / `SqlQueryRaw` / `CommandType.StoredProcedure` ทั้งไฟล์แล้ว
  จุดที่ใช้ SP (บรรทัด 11030, 23247) เป็นงาน GL/EBS interface **คนละ feature**
- เส้นทางนี้ใช้ **EF Core ตรงกับตาราง/วิว 100%**
- **ขั้นตอนยืนยันไม่มี temp table** — `ConfirmBudgetRequestSummary` (บรรทัด 8627)
  แค่ `UPDATE OAGWBG_BUDGETGOVERNMENT SET BUDGETSTATUS = 'B'` บนแถวที่เกี่ยวข้อง
- **ไม่มีขั้นตอน "ยกเลิก" ในหน้านี้** (มีในหน้าอื่นคนละ flow)

---

## Task 3 — Flow ปัจจุบัน และสิ่งที่ต้องเปลี่ยนในแต่ละ layer

### ขาอ่าน (เปิดหน้า)

```
[Browser] GET /Budget/BudgetRequestSummaryDetail?budgetYear=2570&budgetFormTypeId=1
   │
[MVC Controller] BudgetController.cs:1482
   │
[MVC Service] BudgetService.cs:2381  →  HTTP GET ไป API
   │
[API Controller] BudgetController.cs:1142
   │
[API Service] BudgetService.cs:8388  GetBudgetRequestSummaryDetail
   ├─ อ่าน OAGWBG_V_BUDGETREQUESTSUMMARYLIST      → ช่อง "งบประมาณรวม"
   └─ เรียก GetGroupBudgetSummaryPlan 4 รอบ (แผนงานบุคลากร / พื้นฐาน / ยุทธศาสตร์ / บูรณาการ)
        │
        [API Service] BudgetService.cs:8841
        ├─ อ่าน OAGWBG_V_BUDGETREQUESTSUMMARY (กรอง budgetYear + formType + budgetPlanId)
        ├─ ⚠️ ถ้าเจอแถว Id เป็น null → INSERT แถว type-4 ใหม่ลง DB  ← GET แต่เขียน DB
        │     (สร้างแค่ 1 แถวต่อ Category เพราะ guard createdCategories บรรทัด 8883)
        ├─ 🔴 บรรทัด 8927  GroupBy 9 field ที่ "ไม่มีศูนย์ต้นทุน"
        │       Budgetyear, Budgetformtypeid, CategoryId, Productid,
        │       Activitycodeid, Projectid, Budgetplanid, Expensetypeid, Budgetexpensetypeid
        ├─ 🔴 บรรทัด 8949  Id = itemWithId?.Id ?? 0        ← เก็บ ID เดียวจากทั้งกลุ่ม
        ├─ 🔴 บรรทัด 8965  Totalkeptcentral = g.Sum(...)   ← รวมยอดข้ามศูนย์ต้นทุน
        ├─ 🔴 บรรทัด ~9007 RefGovernmentid = firstItem     ← คนละแถวกับ itemWithId
        └─ ห่อเป็น 4 ชั้น: Product → Activity → ExpenseType → Detail(GrandChild)
   │
[View] _tabBudgetRequestSummaryDetail.cshtml:174  render 1 <tr id="GrandChild"> ต่อ 1 กลุ่ม
        พร้อม hidden #DetailId (บรรทัด 192) และช่องกรอก .detail-Totalkeptcentral (บรรทัด 204)
```

### ขาเขียน (กดบันทึก)

```
[Browser] คลิก #btnSave  →  BudgetRequestSummaryDetail.cshtml:124
   ├─ 🔴 บรรทัด 129  $('tr#GrandChild')  เป็น selector ระดับ document
   │     → เก็บทุกแถวของ "ทั้ง 4 แท็บ" ไม่ใช่แค่แท็บที่เปิดอยู่
   └─ สร้าง payload ต่อแถว: { id: #DetailId, totalkeptcentral: ..., RefGovernmentid: #RefId, ... }
   │
[MVC Controller] BudgetController.cs:1562
[MVC Service]    BudgetService.cs:2416   →  HTTP POST ไป API
[API Controller] BudgetController.cs:1054
   │
[API Service] BudgetService.cs:8412  SaveBudgetRequestSummaryDetail
   │
   ├─ 🔴 สาขา Id != 0 (บรรทัด 8422)
   │     item = Where(x => x.Id == 56985).FirstOrDefault()   ← หาด้วย ID ตรง ๆ
   │     item.Keptcentral = 118020                            ← ยอดรวมของทุกศูนย์ต้นทุน!
   │     item.Categoryid / Budgetplanid / Projectid / Productid / Activitycodeid
   │     item.Budgetdetail = budgetRequestSummary.Description  ← มาจาก firstItem (อาจคนละศูนย์)
   │     item.Budgetgovernmenttype = "4"
   │
   └─ สาขา Id == 0 (บรรทัด 8452)
         หาด้วย RefBudgetgovernmentid → ถ้าไม่เจอ สร้างใหม่
   │
[DB] UPDATE OAGWBG_BUDGETGOVERNMENT SET KEPTCENTRAL = 118020 WHERE ID = 56985
```

### สิ่งที่ต้องเปลี่ยนในแต่ละ layer

| Layer | ต้องเปลี่ยนอะไร |
|---|---|
| **DB / DAL** | **ไม่ต้องเปลี่ยน** — โครงสร้างปัจจุบัน (`REF_BUDGETGOVERNMENTID` รายบรรทัด) ถูกต้องอยู่แล้ว ปัญหาอยู่ที่ชั้นบนที่ยุบข้อมูลก่อนแสดง |
| **API Service (ขาอ่าน)** | แก้ `GetGroupBudgetSummaryPlan` — ต้องทำให้ **1 บรรทัดบนจอ = 1 แถวที่เขียนได้** ไม่ยุบข้ามศูนย์ต้นทุน |
| **API Service (ขาเขียน)** | `SaveBudgetRequestSummaryDetail` ไม่ต้องแก้ logic หลัก **ถ้า** ขาอ่านส่ง `Id` ที่ถูกต้องมาให้ทีละแถว |
| **Models / DTO** | `OagwbgVBudgetrequestsummary` ไม่มีฟิลด์ศูนย์ต้นทุน — ถ้าจะแสดงแยกศูนย์ ต้องเพิ่ม `COSTCENTERID` / `COSTCENTERNAME` เข้า view และ DTO |
| **View** | เพิ่มคอลัมน์ศูนย์ต้นทุน + จำนวนแถวเพิ่มขึ้นมาก (576 → หลายพัน) ต้องคิดเรื่อง paging/performance |
| **MVC Controller / Service** | **ไม่ต้องเปลี่ยน** — เป็น pass-through ล้วน |

---

## Task 5 — คำถาม: ได้คำตอบครบแล้ว

### ✅ กฎธุรกิจที่ user ยืนยัน (2026-09-22)

| ช่อง | ความหมาย | การรวมยอด |
|---|---|---|
| **คำของบประมาณ** | ยอดคำขอจาก **ทุกศูนย์ต้นทุน** มารวมกัน | **รวม** ✅ |
| **คำของบประมาณเพิ่มเติม** | งบที่ส่วนกลางเติมให้ **เพื่อเสริมงบตั้งต้น** | **ก้อนเดียว ห้ามรวม** ❌ |
| **รวม** | คำของบประมาณ + เพิ่มเติม | — |

**ตัวอย่างที่ user ให้มา — เป็นตัวชี้ขาดทั้งหมด:**

```
ศูนย์ A ขอ 4,100  +  ศูนย์ B ขอ 4,100   →  คำของบประมาณ  8,200
ส่วนกลางเติมให้ (เงินก้อนเดียว)          →  เพิ่มเติม      1,800
                                           รวม          10,000

หน้าจอต้องแสดง:  ตู้เหล็กใส่ A4 | 8,200 | 1,800 | 10,000
```

> **"เพิ่มเติม" ผูกกับ *กลุ่มรายการ* ไม่ได้ผูกกับศูนย์ต้นทุน** — แต่ละกลุ่มมีได้ก้อนเดียว

### ❓ คำถามที่ยังเหลือ

1. **ข้อมูลที่ถูกเขียนทับไปแล้วต้องแก้ย้อนหลังไหม**
   ตรวจได้จาก `UPDATEON` ที่ซ้ำกันถึงระดับวินาที — พบ event ชัดเจน 2 ครั้ง:
   `2026-09-21 14:16:20.471` เขียน 951 แถว และ `2026-09-18 17:41:43` ล้าง 187 แถวเป็น NULL

2. **รายงาน `OAGWBG_R_BUDGETREQUEST` ออกผลรายศูนย์ต้นทุน** แต่ยอด "เพิ่มเติม" เป็นก้อนเดียวระดับกลุ่ม
   ควรแสดงอย่างไร — แถวแยก "ส่วนกลาง" / เฉลี่ยตามสัดส่วน / ไม่แสดงในรายงานรายศูนย์

---

## 🔧 แนวทางแก้ไข (สรุปหลังได้กฎธุรกิจครบ)

### หลักการ

> **ตัดสินยอด "เพิ่มเติม" ที่ระดับ *กลุ่ม* ไม่ใช่ระดับ *แถว***

ปัจจุบัน view ทำ `COALESCE` ให้เสร็จที่ระดับแถว แล้ว C# เอาไป `Sum` → ได้ `own + parent`
ที่ถูกคือ: **กลุ่มมีก้อนของตัวเองก็ใช้ก้อนนั้น ไม่มีเลยค่อยดึงก้อนที่ค้างอยู่กับคำขอแม่**

### จุดที่ 1 — Oracle view: คืน 2 คอลัมน์แยก อย่า `COALESCE` ให้เสร็จ

```sql
BG4.KEPTCENTRAL   AS TOTALKEPTCENTRAL        -- ก้อนของกลุ่มตัวเอง (เหมือนเดิม)
BG4P.KEPTCENTRAL  AS KEPTCENTRAL_FROMPARENT  -- ก้อนที่ค้างกับคำขอแม่ (คอลัมน์ใหม่)
```

### จุดที่ 2 — DAL / DTO

เพิ่ม property `KeptcentralFromparent` ใน `OAGBudget.DAL/Models/OagwbgVBudgetrequestsummary.cs`

### จุดที่ 3 — `GetGroupBudgetSummaryPlan` (`BudgetService.cs:8964-8966`)

```csharp
// ก้อนของกลุ่ม: ใช้ของตัวเองถ้ามี ไม่มีเลยค่อยดึงของคำขอแม่
var ownPot  = g.Where(x => x.Totalkeptcentral != null).ToList();
var keptPot = ownPot.Any()
    ? ownPot.Sum(x => x.Totalkeptcentral ?? 0)
    : g.Sum(x => x.KeptcentralFromparent ?? 0);

var requestSum = g.Sum(x => x.Totalrequestamount ?? 0);

Totalrequestamount = requestSum,             // 8,200  ← รวมทุกศูนย์ (เหมือนเดิม)
Totalkeptcentral   = keptPot,                // 1,800  ← ก้อนเดียว ไม่รวม
Totalreceiveamount = requestSum + keptPot    // 10,000 ← คำนวณใหม่ ไม่ Sum จาก view
```

> `g.Any(...)` ตรงนี้เป็น LINQ-to-Objects (ข้อมูลอยู่ใน memory หลัง `ToListAsync` แล้ว)
> **ใช้ได้ปกติ** ไม่ใช่ `AnyAsync` ที่พังบน Oracle ด้วย ORA-00904

### จุดที่ 4 — ขาบันทึก

`SaveBudgetRequestSummaryDetail` **ไม่ต้องแก้ logic หลัก** เพราะเมื่อยอดที่ส่งมาเป็น "ก้อนเดียว"
การเขียนลง `Id` เดียวก็ถูกต้องตามกฎแล้ว

แต่ต้องทำให้ `Id` ที่ส่งมา **deterministic** — ปัจจุบัน `itemWithId` (บรรทัด 8944) ใช้
`OrderBy(x => x.Id).FirstOrDefault(...)` ซึ่งใช้ได้ แต่ `RefGovernmentid` (บรรทัด ~9007)
มาจาก `firstItem` ซึ่ง **ไม่มี `OrderBy` กำกับ** → ถ้ากลุ่มยังไม่มีก้อนเลย (`Id = 0`)
การสร้างก้อนใหม่อาจไปลง BG คนละตัวในแต่ละครั้งที่บันทึก **ควรใส่ `OrderBy` ให้ตรงกัน**

### ผลที่ได้

| กรณี | จำนวนกลุ่ม | ผล |
|---|---|---|
| กลุ่มไม่มีก้อนเลย (ก้อนค้างอยู่กับคำขอแม่) | 15 | ✅ กู้คืน **116,764,144** บาท |
| กลุ่มมีก้อนอยู่แล้ว + fallback ไปเติมซ้ำ | 5 (CAT 2238/2372/2387/2396/2432) | ✅ กลับไปใช้ก้อนเดิม แก้ส่วนเกิน |
| `Totalreceiveamount` | ทุกกลุ่ม | ✅ เลิกนับ kept ซ้ำตามจำนวนแถว |

### 📋 หลักฐานประกอบการตัดสินใจ

ตรวจบน PROD ด้วย `02_check_fallback_group_level.sql`:

```
2570 | B) กลุ่มว่างเปล่า -> กู้คืนจริง    | 15 กลุ่ม | +116,764,144
2570 | A) กลุ่มมีก้อนแล้ว -> บวกเพิ่ม     |  9 กลุ่ม |   −2,190,186
                                                      ─────────────
                                              รวม      114,573,958
```

ตรวจกลุ่มที่มีมากกว่า 1 ก้อน (ใช้ key ตรงกับ UI ครบ 9 ช่อง) — ได้ **5 กลุ่ม**:

```
2570 | CAT 2,238 | PRODUCT 21,000 | ACTIVITY 21,100 | PLAN 3,124 | 2 ก้อน
2570 | CAT 2,396 | ...                                           | 2 ก้อน
2570 | CAT 2,432 | ...                                           | 2 ก้อน
2570 | CAT 2,387 | ...                                           | 2 ก้อน
2570 | CAT 2,372 | ...                                           | 2 ก้อน
```

ทั้ง 5 กลุ่มเป็น **1 ก้อนของตัวเอง + 1 ก้อนจาก fallback** (ไม่ใช่ 2 ก้อนจริงในตาราง)
→ **แก้ด้วยโค้ดจุดที่ 3 ได้หมด ไม่ต้อง cleanup ข้อมูล**

ยืนยันอีกชั้นว่าไม่ใช่การนับซ้ำของค่าเดียวกัน — ไล่รายแถวด้วย `03_drilldown_9_groups.sql` พบว่า
เป็นคนละคำขอ คนละศูนย์ต้นทุน คนละ BG จริง ๆ:

| CAT | คำขอ | ศูนย์ต้นทุน | BG_ID | ยอดคำขอ | รายการ |
|---|---|---|---|---|---|
| 2387 | 1231 | 2900600108 | 54,057 | 12,000 | ขอเพิ่มเติม-ตู้รางแฟ้มเอกสาร (CB-3) |
| 2387 | 1776 | 2900600103 | 73,103 | 12,000 | ตู้รางแฟ้มเอกสาร |
| 2396 | 1133 | 2900600365 | 50,037 | 4,100 | ขอทดแทน - ตู้เหล็กใส่ A4 |
| 2396 | 1776 | 2900600103 | 73,172 | 4,100 | ตู้เหล็กใส่ A4 (ทดแทน) |
| 2432 | 1007 | 2900600227 | 50,859 | 10,000 | เครื่องตัดหญ้า แบบเลื่อนล้อจักรยาน |
| 2432 | 1776 | 2900600103 | 73,199 | 10,000 | เครื่องตัดหญ้า แบบล้อจักรยาน |

ยอดเท่ากันเพราะเป็น**ครุภัณฑ์รายการเดียวกัน ราคามาตรฐานเดียวกัน** — และทุกคู่มีคำขอ **1776**
(ลูกของ 1073 ที่ถูกตีกลับ) อยู่ด้วยเสมอ คือฝั่งที่ได้ค่าจาก fallback

---

---

## ⚠️ สิ่งที่ควรทำทันทีระหว่างยังไม่แก้

**แจ้งผู้ใช้ให้หยุดกดปุ่ม "บันทึก" ที่หน้านี้**

ตัวเลขบนจอถูกต้องแล้ว ดูและ export ได้ตามปกติ — เสียหายเฉพาะตอนกดบันทึก
และเสียหายแบบ **สะสมทบต้น** ยิ่งกดยิ่งเพี้ยนมากขึ้น

---

## บั๊กที่พบเพิ่มระหว่างวิเคราะห์ (คนละตัวกับที่แจ้ง)

| เรื่อง | รายละเอียด |
|---|---|
| **กดบันทึกครั้งเดียวเขียนทุกแท็บ** | `$('tr#GrandChild')` ที่บรรทัด 129 เป็น selector ระดับ document + หน้านี้ไม่มี filter ศูนย์ต้นทุน + ไม่มี optimistic concurrency → ใครเปิดหน้าค้างไว้แล้วกดบันทึก จะทับงานของทุกศูนย์ต้นทุน |
| **GET ที่เขียน DB** | `GetGroupBudgetSummaryPlan` INSERT แถว type-4 ตอนเปิดหน้า ไม่มี lock — เปิดพร้อมกันอาจได้แถวซ้ำ |
| **สร้าง type-4 แค่ 1 แถวต่อ Category** | guard `createdCategories` บรรทัด 8883 ทำให้ BG แถวอื่นใน category เดียวกันไม่มีแถวของตัวเองถาวร ← เกี่ยวโดยตรงกับบั๊กหลัก |
| **สาขา `Id == 0` หาแถวด้วย REF อย่างเดียว** | บรรทัด 8452 ไม่กรอง type ไม่กรองปี แล้วบังคับ `Budgetgovernmenttype = "4"` → อาจกลืนแถวรายการจริง (ตรวจแล้วยังไม่เคยเกิด) |

รายละเอียดทั้งหมดอยู่ใน `_brain_OAGBUDGET/20260921_fix_keptcentral_orphan/REMEDIATION_PLAN.md`

---

## ตรวจโค้ดปัจจุบันอีกรอบ — ถูกหรือผิดกันแน่ (2026-09-22)

หลังเลือกแนวทาง "แก้ที่ Oracle view" แล้ว ต้องกลับมาดูว่าโค้ด C# ที่เคยบอกว่าผิด **ยังผิดอยู่ไหม**

### ขาแสดงผล — `GetGroupBudgetSummaryPlan` (BudgetService.cs:8964-8966)

| โค้ด | เดิมประเมินว่า | ผลจริงหลัง view v2 |
|---|---|---|
| `Totalrequestamount = g.Sum(x => x.Totalrequestamount ?? 0)` | ✅ ถูก | ✅ **ถูก** รวมทุกศูนย์ต้นทุน = 8,200 |
| `Totalkeptcentral = g.Sum(x => x.Totalkeptcentral ?? 0)` | ❌ ผิด ต้องเลิก Sum | ✅ **ถูกแล้ว ไม่ต้องแก้** |
| `Totalreceiveamount = g.Sum(x => x.Totalreceiveamount ?? 0)` | ❌ ผิด | ⚠️ **ยังผิด แต่เป็น dead field** |

**ทำไม `Totalkeptcentral = g.Sum()` ถึงกลายเป็นถูก**

ต้นเหตุจริงคือ **ความไม่เข้ากันระหว่าง 2 ชั้น** — view ทำ `COALESCE` ที่ระดับแถว
แล้ว C# `Sum` ที่ระดับกลุ่ม แก้ข้างใดข้างหนึ่งก็หายทั้งคู่

v2 แก้ที่ view โดยให้ **คืนก้อนเงินแค่แถวเดียวต่อกลุ่ม แถวอื่นเป็น NULL**
→ `g.Sum()` จึงบวกค่าเดียว = ก้อนเดียว **ถูกต้องตามกฎธุรกิจโดยอัตโนมัติ**

> **ข้อดีของการแก้ฝั่ง view:** ไม่ต้องแตะ C# / DAL / DTO / .cshtml เลยสักบรรทัด
> diff แคบ rollback ง่าย และไม่ต้อง deploy แอป

**`Totalreceiveamount` — ผิดมาตลอด แต่ไม่มีใครใช้**

view คำนวณ `TOTALRECEIVEAMOUNT = BR.TOTALREQUESTAMOUNT + KEPTCENTRAL` ต่อแถว
โดย `BR.TOTALREQUESTAMOUNT` คือ **ยอดรวมของทั้งคำขอ** ซึ่งซ้ำอยู่บนทุกแถวของคำขอนั้น
พอ `Sum` ข้ามแถวจึงคูณซ้ำตามจำนวนแถว

หลักฐาน — ปี 2569: `SUM_RECV` = 2,137,588,972,585.85 (2.1 ล้านล้าน)
เทียบกับยอดคำขอจริง 18,299,944,059.33 (18.3 พันล้าน) → **เกินจริงราว 117 เท่า**

แต่ตรวจแล้ว **ไม่มีใครใช้ค่านี้**:

| ที่ใช้ | ใช้อะไรแทน |
|---|---|
| คอลัมน์ "รวม" ทั้ง 3 ระดับ (`_tabBudgetRequestSummaryDetail.cshtml` 132 / 164 / 207) | `Totalrequestamount + Totalkeptcentral` คำนวณฝั่ง server |
| ช่อง "งบประมาณรวม" หัวหน้าจอ (`BudgetRequestSummaryDetail.cshtml:26`) | `Model.Summary.*` ซึ่งมาจาก **`V_BUDGETREQUESTSUMMARYLIST`** คนละ view |

→ **ไม่กระทบผู้ใช้** แต่เป็นระเบิดเวลาถ้าวันหน้ามีคนเอาไปใช้ ควรแก้สูตรหรือลบคอลัมน์ทิ้ง

### ขาบันทึก — `SaveBudgetRequestSummaryDetail` (BudgetService.cs:8412-8495)

| จุด | บรรทัด | สถานะ |
|---|---|---|
| สาขา `Id != 0` → `Where(x => x.Id == ...)` แล้ว update | 8422-8440 | ✅ **ถูก** หลัง v2 เพราะ `Id` ชี้ก้อนเดียวของกลุ่มเสมอ |
| สาขา `Id == 0` → หาด้วย `RefBudgetgovernmentid` | 8450 | ⚠️ `RefGovernmentid` มาจาก `firstItem` ที่ **ไม่มี `OrderBy`** |
| `_context.OagwbgBudgetgovernments.Add(item)` | **8492** | ❌ **บั๊กจริง** อยู่นอก if/else |
| หาแถวด้วย REF อย่างเดียว **ไม่กรอง type ไม่กรองปี** แล้วบังคับ `Budgetgovernmenttype = "4"` | 8450 / 8461 | ⚠️ ระเบิดเวลา |
| เขียนทับ `Categoryid` / `Budgetdetail` / `Productid` / `Activitycodeid` ด้วยค่าจากบรรทัดที่ยุบรวม | 8430-8438 | ⚠️ `Description` มาจาก `firstItem` คนละแถวกับ `itemWithId` |

**บั๊ก `Add()` อยู่นอก if/else**

```csharp
if (item != null) { ...update ฟิลด์... }      // ← เจอแถวเดิม ควรแค่ update
else              { item = new Oagwbg...(); }  // ← ไม่เจอ ค่อยสร้างใหม่
_context.OagwbgBudgetgovernments.Add(item);    // ← ❌ ทำทั้งสองกรณี
```

`Add()` กับ entity ที่ context track อยู่แล้ว จะเปลี่ยน state เป็น `Added`
→ EF พยายาม INSERT แถวใหม่แทนที่จะ UPDATE

**ตรวจข้อมูลแล้วยังไม่เคยเกิดจริง** (type-4 ไม่มี REF ซ้ำสักแถว) — อาจเพราะสาขานี้ไม่ค่อยทำงาน
หรือ EF จัดการให้ แต่โค้ดผิดแน่นอน **ควรย้าย `Add()` เข้าไปใน `else`**

**`RefGovernmentid` ไม่ deterministic**

```csharp
var itemWithId = g.OrderBy(x => x.Id).FirstOrDefault(x => x.Id != null);  // ✅ มี OrderBy
...
RefGovernmentid = (int)(firstItem?.RefGovernmentid)                        // ❌ firstItem = g.FirstOrDefault() ไม่มี OrderBy
```

ถ้ากลุ่มยังไม่มีก้อนเลย (`Id = 0`) การสร้างก้อนใหม่จะผูกกับ BG ที่ Oracle คืนมาเป็นแถวแรก
ซึ่ง**อาจเปลี่ยนไปในแต่ละครั้ง** → บันทึกคนละครั้งอาจสร้างก้อนลง BG คนละตัว = ได้หลายก้อนในกลุ่มเดียว

**ควรใส่ `OrderBy` ให้ตรงกับ `itemWithId`** เช่น `g.OrderBy(x => x.RefGovernmentid).First()`

### สรุป — อะไรต้องแก้ อะไรไม่ต้อง

| | สถานะ |
|---|---|
| ✅ `Totalrequestamount = g.Sum()` | ถูก ไม่ต้องแก้ |
| ✅ `Totalkeptcentral = g.Sum()` | ถูกแล้วหลัง view v2 **ไม่ต้องแก้** |
| ✅ สาขาบันทึก `Id != 0` | ถูกแล้วหลัง view v2 **ไม่ต้องแก้** |
| ⚠️ `Totalreceiveamount` | ผิดแต่ dead — ควรเก็บกวาด ไม่เร่ง |
| ❌ `Add()` นอก if/else (บรรทัด 8492) | **ควรแก้** ย้ายเข้า `else` |
| ❌ `RefGovernmentid` ไม่มี `OrderBy` | **ควรแก้** ใส่ `OrderBy` ให้ deterministic |
| ⚠️ หาแถวด้วย REF ไม่กรอง type/ปี | ควรแก้ตามหลัง (ยังไม่เคยเกิด) |

**งานที่ต้องแก้ใน C# เหลือแค่ 2 บรรทัด** และไม่บล็อกการ deploy view v2

---

## ไฟล์ DDL v2 ที่เตรียมไว้ (2026-09-22)

| View | ไฟล์ | คอลัมน์ที่แก้ | parse |
|---|---|---|---|
| `OAGWBG_V_BUDGETREQUESTSUMMARY` | `OAGWBG_V_BUDGETREQUESTSUMMARY_v2.sql` | `TOTALKEPTCENTRAL`, `TOTALRECEIVEAMOUNT`, `DESCRIPTION` | ✅ |
| `OAGWBG_V_BUDGETREQUESTSUMMARYLIST` | `OAGWBG_V_BUDGETREQUESTSUMMARYLIST_v2.sql` | `TOTALRECEIVEAMOUNT` | ✅ |
| `OAGWBG_R_BUDGETREQUEST` | `OAGWBG_R_BUDGETREQUEST_v2.sql` | `REQUESTAMOUNT_ADD`, `BUDGETDETAIL` | ✅ |

ทั้ง 3 ตัวใช้ตรรกะเดียวกัน — **คืนก้อนเงินแค่แถวเดียวต่อกลุ่ม**:

```sql
CASE
  WHEN BG4.KEPTCENTRAL IS NOT NULL THEN BG4.KEPTCENTRAL        -- มีก้อนของตัวเอง
  WHEN COUNT(BG4.KEPTCENTRAL) OVER (PARTITION BY <group key>) = 0   -- ทั้งกลุ่มไม่มีเลย
   AND ROW_NUMBER()          OVER (PARTITION BY <group key>
                                   ORDER BY NVL2(BG4P.KEPTCENTRAL,0,1), BG.ID) = 1
  THEN BG4P.KEPTCENTRAL                                         -- ดึงของคำขอแม่ แถวเดียว
END
```

**ตรวจบน PREPROD แล้วทั้ง 3 ตัว** — row count และยอดรวมเท่ากับ v1 ทุกปี ไม่ regress

**ผลบน PROD (จาก `04_preflight_v2.sql`)** — ปี 2570 `SUM_KEPT` 5,608,440,579.16 → 5,610,630,765.16
(+2,190,186 เพราะตัดส่วนเกินที่ติดลบออก) ปี 2569/2571 ไม่เปลี่ยนเลย

### ⚠️ ข้อค้างของ `R_BUDGETREQUEST`

รายงานนี้ออกผล **รายศูนย์ต้นทุน** แต่ก้อนเงินเป็นของ **กลุ่มรายการ**
v2 ให้ยอดโผล่ที่แถวของศูนย์ต้นทุนแรกในกลุ่ม (เรียงตาม `BG.ID`)
→ **ยอดรวมทั้งรายงานถูก แต่ยอดรายศูนย์ต้นทุนยังอ่านตรง ๆ ไม่ได้**

ยังต้องถามเจ้าของระบบ: แถวแยก "ส่วนกลาง" / เฉลี่ยตามสัดส่วน / ไม่แสดงในระดับศูนย์

---

## ยืนยันขอบเขตงาน

✅ วิเคราะห์และอธิบายเท่านั้น
✅ **ไม่มีการแก้ไขโค้ดใด ๆ ในงานนี้** ตาม prompt ข้อ 4
✅ สรุปเป็นภาษาไทย บันทึกที่ `_brain_OAGBUDGET/20260922/result01.md`
