# วิเคราะห์ "สถานะข้อมูล" — หน้า BudgetRequestProjectList (คำของบประมาณรายจ่ายประจำปี)

> **วันที่วิเคราะห์:** 2026-08-18
> **ไฟล์ต้นทาง:** `OAGBudget\Views\Budget\BudgetRequestProjectList.cshtml`
> **ขอบเขต:** ไล่ตั้งแต่ View (หน้าบ้าน) → MVC Controller → HTTP → API Controller → API Service → Database

---

## 0. สรุปสั้น (TL;DR)

หน้านี้มี **สถานะ 3 ชนิด** ที่คนละแหล่งกันโดยสิ้นเชิง — อย่าสับสน:

| # | ชื่อบนหน้าจอ | ระดับ | Field | คำนวณจาก |
|---|---|---|---|---|
| 1 | **สถานะ** (ช่อง header) | คำขอ (BudgetRequest) | `Model.StatusName` / `StatusId` | คอลัมน์ `STATUSID` ใน `OAGWBG_V_BUDGETREQUEST` (มาจาก workflow ปุ่ม ส่งเรื่อง/อนุมัติ/ส่งกลับ) |
| 2 | **สถานะข้อมูล** (คอลัมน์ที่ 5 ในตาราง) | โครงการ (Project) | `isDetailComplete` | **คำนวณสดใน C# ตอน GET** โดยตรวจความครบถ้วนของข้อมูล 5 แท็บ — **ไม่ได้เก็บใน DB** |
| 3 | **สถานะการจัดสรร** (คอลัมน์ที่ 6) | โครงการ (Project) | `row.status` | คอลัมน์ `STATUS` ใน `OAGWBG_V_PROJECT` (`"1"` / `"0"` / `null`) |

**หัวใจของคำถาม "สถานะข้อมูลตรวจจากอะไร"** → คือข้อ 2: ตรวจ 5 แท็บ ถ้าครบทั้ง 5 = `ข้อมูลครบถ้วน` ถ้าขาดแม้แท็บเดียว = `รอดำเนินการต่อ`

---

## 1. ลำดับการไหลของข้อมูล (End-to-End)

```
[Browser]
  │  GET /Budget/BudgetRequestProjectList/{Id}?pageType=1
  ▼
[MVC] OAGBudget\Controllers\BudgetController.cs:971  BudgetRequestProjectList(int? Id, string? pageType)
  │  ├─ ถ้า Id == null  → สร้าง ViewModel เปล่า, StatusId = 10101 ("ร่าง"), Mode = "new"
  │  └─ ถ้า Id != null  → เรียก _budgetService.GetBudgetRequestProjectList(Id.Value), Mode = "edit"
  ▼
[MVC Service] OAGBudget\Services\Repository\BudgetService.cs:1777
  │  HttpClient GET  {BaseUrlApi}/Budget/GetBudgetRequestProjectList?budgetRequestId={Id}
  │  → JsonConvert.DeserializeObject<BudgetRequestProjectListViewModel>(json)
  ▼
[API Controller] OAGBudget.API\Controllers\BudgetController.cs:182  GetBudgetRequestProjectList
  ▼
[API Service] OAGBudget.API\Services\Repository\BudgetService.cs:1797  GetBudgetRequestProjectList
  │  ├─ (A) header คำขอ    ← OAGWBG_V_BUDGETREQUEST
  │  ├─ (B) ยอดรวมเงิน     ← SUM(TOTALREQUESTAMOUNT) จาก OAGWBG_BUDGETGOVERNMENT
  │  ├─ (C) รายการโครงการ  ← OAGWBG_V_PROJECT  (WHERE BUDGETREQUESTID = @id AND TEMP IS NULL)
  │  ├─ (D) สถานะการจัดสรร ← override ด้วย Status ของ TEMP-child (ถ้ามี)
  │  └─ (E) **สถานะข้อมูล** ← loop ตรวจ 5 แท็บ ต่อ 1 โครงการ → IsDetailComplete + MissingFields
  ▼
[Oracle PREPROD] OAGWBG_*
  ▲
  │  return BudgetRequestProjectListViewModel { ..., Projects: List<OagwbgVProject> }
  ▼
[View] BudgetRequestProjectList.cshtml:256
  │  var projects = @Html.Raw(Json.Serialize(Model.Projects));   ← ฝัง JSON ลง <script> ตรง ๆ
  ▼
[DataTables] BudgetRequestProjectList.cshtml:281  data: projects  (client-side, serverSide: false)
  ├─ column "สถานะข้อมูล"      : data: 'isDetailComplete'   (บรรทัด 376-385)
  └─ column "สถานะการจัดสรร"   : render จาก row.status       (บรรทัด 386-394)
```

> **หมายเหตุ:** ตารางเป็น **client-side DataTables** ไม่มี AJAX เรียกซ้ำ — ข้อมูลทั้งหมดถูก serialize มาพร้อมหน้า ดังนั้นสถานะที่เห็นคือ snapshot ณ ตอน render เท่านั้น ต้อง reload หน้าถึงจะอัปเดต

---

## 2. "สถานะข้อมูล" (`isDetailComplete`) — รายละเอียดเต็ม

### 2.1 จุดแสดงผล (หน้าบ้าน)

`BudgetRequestProjectList.cshtml:376-385`

```js
{
    data: 'isDetailComplete',
    render: function (data, type, row) {
        if (data) return '<span class="badge badge-light-success">ข้อมูลครบถ้วน</span>';
        return '<span class="badge badge-light-warning">รอดำเนินการต่อ</span>';
    }
}
```

### 2.2 จุดนิยาม Field

`OAGBudget.DAL\Models\OagwbgVProject.cs:125-129`

```csharp
[NotMapped] public bool IsDetailComplete { get; set; }
[NotMapped] public List<string> MissingFields { get; set; } = new List<string>();
```

→ ทั้งคู่เป็น `[NotMapped]` = **ไม่มีคอลัมน์นี้ใน View/Table ของ Oracle** เป็นค่าที่ C# คำนวณใส่ให้ตอน runtime เท่านั้น

### 2.3 ตรรกะการตรวจ (หลังบ้าน)

`OAGBudget.API\Services\Repository\BudgetService.cs:1836-1931` — loop ทีละโครงการ

| แท็บ | ตาราง | เงื่อนไข "ไม่ครบ" (tabNMissing = true) | ข้อความที่แสดง |
|---|---|---|---|
| **1** | `OAGWBG_V_PROJECT` + `OAGWBG_PROJECTMONITORINGREPORT` + `OAGWBG_PROJECTRESPONSIBLEPERSONS` | `Categoryid` หรือ `Projectname` ว่าง **หรือ** ไม่มีแถวใน MONITORINGREPORT **หรือ** `Projecttype` / `Responsibleagency` / `Implementationmethod` ว่าง **หรือ** ไม่มีผู้รับผิดชอบ `Type = "R"` **หรือ** ไม่มีผู้ให้ข้อมูล `Type = "I"` | `แท็บ 1: ข้อมูลพื้นฐานโครงการ` |
| **2** | `OAGWBG_PROJECTSTRATEGICALIGNMENTFIRST` | ไม่มีแถว **หรือ** `Primarynationalstrategy` / `Primarystrategygoal` / `Primarystrategyissue` ว่าง | `แท็บ 2: ความเชื่อมโยงแผน (แผนระดับที่ 1)` |
| **3** | `OAGWBG_PROJECTSTRATEGICALIGNMENTSECOND` | ไม่มีแถว **หรือ** `Plangrouptitlefirst` / `Subplannamefirst` / `Goalsubplanfirst` ว่าง | `แท็บ 3: แผนระดับที่ 2` |
| **4** | `OAGWBG_PROJECTSTRATEGICALIGNMENTTHIRD` | ไม่มีแถว **หรือ** ว่างแม้แต่ field เดียวใน **20 fields** (ดู 2.4) | `แท็บ 4: แผนระดับที่ 3` |
| **5** | `OAGWBG_PROJECTTARGETS` | ไม่มีแถว **หรือ** `Projectfromdate` / `Projecttodate` เป็น null **หรือ** `Activitytargetcount` เป็น null **หรือ** `Activitydetails` ว่าง | `แท็บ 5: กำหนดค่าเป้าหมายความสำเร็จตามโครงการฯ` |

**สรุปผล** (`BudgetService.cs:1930`):
```csharp
project.IsDetailComplete = project.MissingFields.Count == 0;
```

### 2.4 20 fields ของแท็บ 4 (เข้มที่สุด — พังบ่อยที่สุด)

`JusticeMasterPlan`, `JusticeDimension`, `JusticeImplementationApproach`, `DigitalDevelopmentAlignment`, `AntiCorruptionAlignmentDesc`, `GovernmentPolicyAlignment`, `SdgsAlignmentDesc`, `FiveyearPlanDevelopment`, `FiveyearImplementationApproach`, `FiveyearStrategy`, `YearPlanDevelopment`, `YearImplementationApproach`, `YearStrategy`, `PolicyAlignment`, `OtherStrategicAlignment`, `PrinciplesAndRationale`, `Objectives`, `OutputTargets`, `OutcomeTargets`, `ExpectedResults`

> ทุกตัวใช้ `string.IsNullOrEmpty()` → **ช่องว่าง `" "` ถือว่าผ่าน** (ไม่ได้ใช้ `IsNullOrWhiteSpace`)

### 2.5 การนำไปใช้บังคับ (Gate) — ปุ่ม "ส่งเรื่อง"

`BudgetRequestProjectList.cshtml:500-521`

```js
$("#btnSend").on("click", async function () {
    let incompleteProjects = projects.filter(p => !p.isDetailComplete);
    if (incompleteProjects.length > 0) {
        // แสดง popup "ไม่สามารถส่งเรื่องได้" พร้อมรายชื่อโครงการ + p.missingFields
        return;   // ← หยุด ไม่ยิง API
    }
    ...  GET /Budget/SendBudgetRequest/{id}
});
```

→ `missingFields` (จากข้อ 2.3) คือสิ่งที่ถูกนำมาแสดงเป็น bullet list ให้ผู้ใช้รู้ว่าขาดแท็บไหน

> ⚠️ **การตรวจนี้อยู่ฝั่ง Client เท่านั้น** — `SendBudgetRequest` → `ChangeStatusBudgetRequest(id, 20101)` (`API\Controllers\BudgetController.cs:283`) **ไม่ได้ตรวจ IsDetailComplete ซ้ำที่ฝั่ง Server** ถ้ายิง API ตรงจะข้ามด่านนี้ได้

---

## 3. "สถานะการจัดสรร" (`status`)

### 3.1 จุดแสดงผล — `BudgetRequestProjectList.cshtml:386-394`

```js
if (!row.status)            return '-';                 // null / "" / undefined
if (row.status === '1')     return 'ได้รับจัดสรร';
                            return 'ไม่ได้รับจัดสรร';    // "0" และค่าอื่น ๆ ทั้งหมด
```

### 3.2 ที่มาของค่า

- คอลัมน์ `STATUS` ใน `OAGWBG_V_PROJECT` (`OagwbgVProject.Status`, บรรทัด 123)
- ถูก **override ด้วยค่าจาก TEMP-child** ที่ `BudgetService.cs:1823-1842`:
  ```csharp
  var childStatuses = await _context.OagwbgVProjects
      .Where(p => p.Temp != null && projectIds.Contains(p.Temp))   // record ฉบับแก้ไข
      .Select(p => new { p.Temp, p.Status }).ToListAsync();
  ...
  if (child != null) project.Status = child.Status;   // ให้ค่าล่าสุดของ TEMP ชนะ
  ```
  เหตุผล: รายการหลักดึงเฉพาะ `Temp == null` (ตัวจริง) แต่ระหว่างพิจารณาผู้อนุมัติแก้ที่ record TEMP → ต้องเอาสถานะจาก TEMP มาโชว์
- ค่าถูกเขียนจากหน้า **BudgetRequestProjectDetail** ผ่าน radio `ApprovalStatus` → `data.Status` → `project.Status` (`BudgetService.cs:2039-2041`)
- ตอนอนุมัติจริง จะ propagate จาก TEMP กลับไป Original (`BudgetService.cs:5945-5958`)

### 3.3 ความหมายมาตรฐาน (อ้างจาก `BudgetService.cs:5354`)

| ค่า | ความหมาย (นิยามใน API) | ที่หน้านี้แสดง |
|---|---|---|
| `"1"` | ได้รับจัดสรรงบประมาณ | ได้รับจัดสรร |
| `"0"` | ไม่ได้รับจัดสรรงบประมาณ | ไม่ได้รับจัดสรร |
| `null` | รอการจัดสรรงบประมาณ | `-` |

---

## 4. "สถานะคำขอ" (`StatusId`) — ตัวคุมสิทธิ์ทั้งหน้า

### 4.1 รหัสสถานะที่ยืนยันได้จากโค้ด

| StatusId | ที่มา (พิสูจน์ได้จากโค้ด) |
|---|---|
| `10101` | ร่าง — set ตอนสร้างใหม่ `MVC BudgetController.cs:1008-1009` (`StatusName = "ร่าง"`) |
| `10102` | ส่งเรื่องกลับ — `btnSendBack` ส่ง `statusId: 10102` (View:576) |
| `10198` | ยกเลิกโดยผู้พิจารณา — `btnDel` เมื่อ `pageType === "2"` (View:785) |
| `10199` | ยกเลิก/ลบคำขอ — `DeleteBudgetRequest` → `ChangeStatusBudgetRequest(id, 10199)` (`API\Controllers\BudgetController.cs:106`) |
| `20101` | ส่งเรื่องแล้ว/รอพิจารณา — `SendBudgetRequest` → `ChangeStatusBudgetRequest(id, 20101)` (`API\Controllers\BudgetController.cs:283`) |
| `20102` | ผู้พิจารณากดแก้ไข — `btnEdt` ส่ง `statusId: 20102` (View:639) |
| `20201` | อนุมัติ — `btnApprove` ส่ง `statusId: 20201` (View:683) |

### 4.2 ผลข้างเคียงของการเปลี่ยนสถานะ

`ChangeStatusBudgetRequest` (`API BudgetService.cs:2596-2655`) เขียน 3 ระดับพร้อมกัน:

```
OAGWBG_BUDGETREQUEST.STATUSID   = statusId
OAGWBG_BUDGETGOVERNMENT.BUDGETSTATUS = (statusId == 10199 ? "X" : "U")
OAGWBG_PROJECT.PROJECTSTATUS         = (statusId == 10199 ? "X" : "U")
+ ถ้ามี Parentid → ทำซ้ำทั้งชุดกับคำขอแม่ด้วย
```
Guard: ถ้าคำขอเป็น `10199` อยู่แล้ว จะส่งเรื่อง (`20101`) ไม่ได้ (`:2603`)

### 4.3 StatusId คุมอะไรบ้างในหน้านี้

| องค์ประกอบ | บรรทัด | เงื่อนไข |
|---|---|---|
| `ViewData["IsView"]` (โหมดอ่านอย่างเดียว) | 5 | ไม่ใช่ `10101`/`10102` และไม่ใช่ (`20102` + pageType 2) และมี Id |
| ปุ่ม **เพิ่มรายการ** | 161 | ซ่อนเมื่อ `20101`, `20201`, `10198`, `10199`, หรือ (`20102` + pageType 1) |
| ปุ่ม **บันทึก** | 189 | แสดงเมื่อ `10101`/`10102`/`20102` หรือสร้างใหม่ |
| ปุ่ม **ส่งเรื่อง** | 193 | เฉพาะ `10101`/`10102` |
| ปุ่ม **อนุมัติ** | 197 | `20102`/`20101` + pageType 2 |
| ปุ่ม **แก้ไข / ส่งเรื่องกลับ** | 201, 214 | `20101` + pageType 2 |
| ไอคอนในตาราง (ดู vs แก้ไข/ลบ) | 331-350 | ดูอย่างเดียวเมื่อ (`20102`+pt1), `10198`, `10199`, `20201`, `20101` |

> `pageType`: `"1"` = ฝั่งผู้ยื่นคำขอ, `"2"` = ฝั่งผู้พิจารณา (เก็บใน Session key `BudgetRequestDetail`, `MVC BudgetController.cs:1013-1018`)

---

## 5. ตารางฐานข้อมูลที่เกี่ยวข้องทั้งหมด

| Object | ชนิด | ใช้ทำอะไรในหน้านี้ |
|---|---|---|
| `OAGWBG_V_BUDGETREQUEST` | View | header คำขอ: Code, Budgetyear, Departmentid, Costcenterid, **Statusid/Statusname** |
| `OAGWBG_BUDGETGOVERNMENT` | Table | `SUM(TOTALREQUESTAMOUNT)` → รวมเงินคำของบประมาณ |
| `OAGWBG_V_PROJECT` | View | รายการโครงการ + **STATUS** (สถานะการจัดสรร) + TEMP (ลิงก์ฉบับแก้ไข) |
| `OAGWBG_PROJECTMONITORINGREPORT` | Table | ตรวจแท็บ 1 |
| `OAGWBG_PROJECTRESPONSIBLEPERSONS` | Table | ตรวจแท็บ 1 (Type = R / I) |
| `OAGWBG_PROJECTSTRATEGICALIGNMENTFIRST` | Table | ตรวจแท็บ 2 |
| `OAGWBG_PROJECTSTRATEGICALIGNMENTSECOND` | Table | ตรวจแท็บ 3 |
| `OAGWBG_PROJECTSTRATEGICALIGNMENTTHIRD` | Table | ตรวจแท็บ 4 (20 fields) |
| `OAGWBG_PROJECTTARGETS` | Table | ตรวจแท็บ 5 |

---

## 6. ข้อสังเกต / จุดที่ควรระวัง (พบระหว่างวิเคราะห์)

1. **Dead code — ตัวแปร `tab1Ids` … `tab5Ids`**
   `API BudgetService.cs:1830-1834` ยิง query 5 ครั้งเพื่อดึงรายการ ProjectId ของแต่ละแท็บ **แต่ไม่ถูกใช้เลย** ในโค้ดถัดไป (ตรรกะจริงใช้ `FirstOrDefaultAsync` ต่อโครงการแทน) → เป็น query เปล่าที่กินเวลาโดยไม่จำเป็น

2. **N+1 query**
   ใน `foreach (var project in projects)` มี `await` ต่อ DB อย่างน้อย **6-7 ครั้งต่อโครงการ 1 รายการ** (tab1 report + 2 counts + tab2..tab5) ถ้าคำขอมี 50 โครงการ = ~350 round-trips ไป Oracle ต่อการเปิดหน้า 1 ครั้ง
   → ปรับเป็น bulk query แล้ว join ใน memory ได้ (ซึ่งดูเหมือนเป็นเจตนาเดิมของ `tabNIds` ในข้อ 1)

3. **การตรวจครบถ้วนไม่มีที่ฝั่ง Server**
   Gate อยู่ใน JS (`btnSend`) เท่านั้น API `SendBudgetRequest` ไม่ตรวจซ้ำ → ยิงตรงข้ามได้

4. **`IsNullOrEmpty` vs `IsNullOrWhiteSpace`**
   ข้อมูลที่เป็นช่องว่างล้วน (`" "`) จะถูกนับว่า "ครบถ้วน"

5. **การแสดงผลสถานะการจัดสรรไม่ตรงกับนิยามที่อื่น**
   หน้านี้แสดง `null` → `-` ขณะที่ API ที่อื่น (`BudgetService.cs:5354`) แปล `null` → `"รอการจัดสรรงบประมาณ"` → ผู้ใช้เห็นข้อความต่างกันในคนละหน้าจอสำหรับข้อมูลชุดเดียวกัน

6. **`totalRequestAmount` คำนวณ 2 ที่**
   View บรรทัด 9 คำนวณใหม่จาก `Model.Projects.Sum(...)` ทับค่า `Model.TotalRequestAmount` ที่ API ส่งมา (ซึ่ง SUM จาก `OAGWBG_BUDGETGOVERNMENT`) → ถ้า 2 แหล่งไม่ตรงกันจะเห็นตัวเลขต่างจากหน้าอื่น

7. **`OagwbgVProject` ถูกใช้เป็นทั้ง Entity และ ViewModel**
   `BudgetRequestProjectListViewModel.Projects` เป็น `List<OagwbgVProject>` (DAL model) → serialize ทุกคอลัมน์ของ view ลง HTML รวม field ที่หน้าจอไม่ใช้ (ข้อมูลรั่วเกินจำเป็น + payload ใหญ่)

---

## 7. Reference — ตำแหน่งโค้ดสำคัญ

| หัวข้อ | ไฟล์ : บรรทัด |
|---|---|
| Render "สถานะข้อมูล" | `OAGBudget\Views\Budget\BudgetRequestProjectList.cshtml` : 376-385 |
| Render "สถานะการจัดสรร" | `OAGBudget\Views\Budget\BudgetRequestProjectList.cshtml` : 386-394 |
| Gate ปุ่มส่งเรื่อง | `OAGBudget\Views\Budget\BudgetRequestProjectList.cshtml` : 500-521 |
| MVC action | `OAGBudget\Controllers\BudgetController.cs` : 971-1022 |
| MVC → API (HttpClient) | `OAGBudget\Services\Repository\BudgetService.cs` : 1777-1794 |
| API endpoint | `OAGBudget.API\Controllers\BudgetController.cs` : 182-194 |
| ตรรกะคำนวณสถานะข้อมูล | `OAGBudget.API\Services\Repository\BudgetService.cs` : 1797-1940 |
| นิยาม field `[NotMapped]` | `OAGBudget.DAL\Models\OagwbgVProject.cs` : 125-129 |
| ViewModel | `OAGBudget.Models\ViewModel\BudgetRequestProjectListViewModel.cs` |
| เปลี่ยนสถานะคำขอ | `OAGBudget.API\Services\Repository\BudgetService.cs` : 2596-2655 |
| Propagate Status TEMP → Original | `OAGBudget.API\Services\Repository\BudgetService.cs` : 5945-5958 |
