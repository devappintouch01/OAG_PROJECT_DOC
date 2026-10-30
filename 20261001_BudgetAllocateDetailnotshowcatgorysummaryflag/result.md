# วิเคราะห์: รายละเอียดคำของบประมาณ พ.ร.บ. (BudgetAllocateDetail) — ย้ายรายการค่ากลางแล้วไม่รู้ที่มา และค่ากลางเหลือยอด 0

> วันที่วิเคราะห์: 2026-10-01 · ขอบเขต: วิเคราะห์อย่างเดียว ไม่ได้แก้ code และไม่ได้แก้ DB
> หลักฐาน DB: query แบบ read-only บน PREPROD (`172.16.11.19:1541/ebs_PRE`) ซึ่งเป็น DB ที่ `OAGBudget.API/appsettings.Development.json` ชี้อยู่ตอนนี้

---

## 0. สรุปสั้น (ตอบคำถามผู้ใช้)

| คำถาม | คำตอบ |
|---|---|
| รายการค่ากลางยังอยู่ไหม | **ไม่ได้ถูกลบ แต่ถูก "ย้าย" ทั้งแถว** ระบบไม่ได้คัดลอกคำขอไป แต่ `UPDATE OAGWBG_BUDGETGOVERNMENT.CATEGORYID` ของแถวคำขอเดิมจาก Category ค่ากลางไปเป็น Category ใหม่ แล้วจำ Category เดิมไว้ใน `DUMMY_CATEGORY` ยอดเงินจึงย้ายไปพร้อมคำขอ ไม่หายและไม่ถูกนับซ้ำ |
| ทำไมค่ากลางเหลือยอด 0 | แถว 0 ที่เห็น **ไม่ใช่แถวค่ากลางเดิม** แต่เป็น record ใหม่ชื่อ `"รายการจัดสรร พรบ"` (`BUDGETREQUESTID = 0`, ไม่มียอด) ที่ `SaveBudgetAllocateDetail` สร้างขึ้นมาในการบันทึกครั้งเดียวกับที่ย้าย เหตุผลคือหน้าจอยังส่ง Category ค่ากลาง (จากแถวที่ซ่อนอยู่) มาใน `budgetAllocateNew` และฝั่ง server เห็นว่าปี/Category นี้ไม่มี record เหลือแล้วจึงสร้างแถวเปล่าขึ้นมา (รายละเอียดอยู่ในข้อ 4.2) |
| ทำไมไม่รู้ว่าเคยเป็นค่ากลาง | version บน TFS server **บันทึก** `DUMMY_CATEGORY` อยู่แล้ว แต่ **ไม่มีจุดไหนอ่านมาแสดง** ทั้ง API, ViewModel และ View |

> ⚠️ **สิ่งที่พบระหว่างวิเคราะห์:** ใน workspace มี **pending change ที่ยังไม่ checkin** อยู่ 4 ไฟล์ ซึ่งเป็นงานแก้ปัญหานี้บางส่วนแล้ว (ดูข้อ 5) ต้องตัดสินใจว่าจะใช้ต่อหรือไม่ก่อนลงมือแก้

---

## 1. คำศัพท์: "Summaryflag = Y" ในโจทย์หมายถึงอะไรในระบบ

- สิ่งที่ผู้ใช้เรียกว่า "Summaryflag = Y / ค่ากลาง" ในระบบคือ **`DUMMY_FLAG = 'YES'`** ของ `OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V` (รหัสลงท้าย `.9999999999` และชื่อมีคำว่า "(อื่นๆ โปรดระบุ...)")
- view นี้ **ไม่มีคอลัมน์ SUMMARYFLAG** (ตรวจจาก `all_tab_columns` แล้ว) ส่วน `Summaryflag` ที่พบในโค้ดเป็นของ view segment GL (Plan/Product/Activity/BudgetCode/Account) ซึ่ง filter `= 'N'` และไม่เกี่ยวกับเรื่องนี้
- Category ค่ากลางบน PREPROD มีทั้งหมด 16 ตัว เช่น 2158 ค่าใช้จ่ายบุคลากร, 2185 ค่าใช้จ่ายดำเนินงาน, 2191 ค่าตอบแทน, 2210 ค่าใช้สอยไม่ผูกพัน, 2288 ค่าวัสดุ ฯลฯ (ทั้งหมดเป็น "(อื่นๆ โปรดระบุ...)")

---

## 2. ไฟล์ที่เกี่ยวข้อง

> path จริงอยู่ที่ `C:\Users\thiha\Documents\TFS\OAG Budget\` ไม่ใช่ `D:\TFS\...` ตามที่ prompt เขียน
> หน้าที่เกี่ยวข้องจริงคือ **`BudgetAllocateDetail.cshtml`** ไม่ใช่ `BudgetRequestDetail.cshtml` ตามที่ระบุใน "Page in Scope" (หน้า BudgetRequestDetail เป็นแค่จุดที่สร้างคำขอค่ากลางขึ้นมาตั้งแต่แรก)

| Layer | ไฟล์ | จุดที่เกี่ยวข้อง |
|---|---|---|
| View (หน้าหลัก) | `OAGBudget/Views/Budget/BudgetAllocateDetail.cshtml` | `#btn-save` (L1272), `#btn-Confirm` (L895), `collectRequestRows` (L1760), `pushMovedRequestToCategory` (L1816), การ์ดกัน dummy ที่ยังมียอดตอนยืนยัน (L1043–1090) |
| Partial (ตารางแต่ละแท็บ) | `OAGBudget/Views/Shared/Partialviews/_tableBudgetAllocateDetailPersonal.cshtml` | แถวรายการ `tr.alloc-item-row` (L226), แถวคำขอ + dropdown `ReqCategoryId` ไว้ย้าย Category (L325–357), CSS ซ่อนแถว dummy (L447), handler ตอนย้าย (L720), `#btn-save-@ExpenseType` "บันทึกเฉพาะแผน" (L839) |
| MVC Controller | `OAGBudget/Controllers/BudgetController.cs` | `BudgetAllocateDetail` (L1828), `GetBudgetAllocateTabData` (L1922), `GetTypeCategoryByPlan(filterDummy)` (L1863), `SaveBudgetAllocateDetail` (L1990), `SaveAndConfirmBudgetAllocatePlan` (L2984), `SaveAndReconfirmBudgetAllocateItems` (L2998) |
| MVC → API proxy | `OAGBudget/Services/Repository/BudgetService.cs` | `GetBudgetAllocateItemsByTabPlanId` (L6507), `SaveBudgetAllocateDetail` (L6571) ทำหน้าที่แค่ส่ง HTTP ต่อให้ API |
| API Controller | `OAGBudget.API/Controllers/BudgetController.cs` | `SaveBudgetAllocateDetail` (L584), `GetBudgetAllocateItemsByTabPlanId` (L687), `SaveAndConfirmBudgetAllocatePlan` (L715), `SaveAndReconfirmBudgetAllocateItems` (L743) |
| API Service (business logic) | `OAGBudget.API/Services/Repository/BudgetService.cs` | **`SaveBudgetAllocateDetail` (L4813)**: ย้าย Category, สร้าง "รายการจัดสรร พรบ", type 5/6/8 · **`GetBudgetAllocateItemsGroupByPlanId` (L6009)**: โหลดตาราง · `SaveRequestAllocateAmountsAsync` (L5957) · `ConfirmBudgetAllocatePlan` (L6300) · `SaveBudgetAllocate` (L13318) ส่ง GL |
| Models (DTO) | `OAGBudget.Models/ViewModel/BudgetAllocateDetailViewModel.cs` | `BudgetAllocateRequestItem` (L80–110): `DummyFlag`, `DummyCategory`, `DummyCategoryName` |
| DAL | `OAGBudget.DAL/Models/OagwbgBudgetgovernment.cs` (`DummyCategory`, L127) · `OagwbgVBudgetallocateitem.cs` (`DummyFlag`) · `OAGDBContextBase.cs` (L3349 map `DUMMY_CATEGORY`) | ใช้ EF Core ตรง ๆ ไม่มี Repository/SP แยก |

---

## 3. Oracle objects ที่เกี่ยวข้อง

| Object | ประเภท | บทบาทในเรื่องนี้ |
|---|---|---|
| `OAGWBG_BUDGETGOVERNMENT` | Table | เก็บทุกอย่าง แยกด้วย `BUDGETGOVERNMENTTYPE`: `NULL`/`7` = แถวคำขอ (`BUDGETREQUESTID` ≠ 0) หรือ "รายการจัดสรร พรบ" (`BUDGETREQUESTID = 0`) · `4` = กันส่วนกลาง (`REF_BUDGETGOVERNMENTID`) · `5` = แปรญัตติ · `6` = เสนอจัดสรร · `8` = คำขอแปรญัตติ · **`DUMMY_CATEGORY`** = Category ค่ากลางต้นทาง · `REQ_TOTAL*` = ยอดรายคำขอ |
| `OAGWBG_V_BUDGETALLOCATEITEM` | View | แหล่งข้อมูลของตารางบนหน้าจอ **(ดึง DDL สดจาก PREPROD แล้ว)** แบ่งเป็น 2 สาขา: `FINAL_NON_YES` สำหรับ Category ปกติ (รวม 1 แถวต่อ Category และ join ยอด type 5/6/8) กับ `FINAL_YES_BG` สำหรับ Category ค่ากลาง (1 แถวต่อคำขอ และ **ตั้งยอดจัดสรร/แปรญัตติ/คำขอแปรญัตติเป็น 0 ตายตัว**) |
| `OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V` | View (EBS) | master Category มี `DUMMY_FLAG`, `EXPENSE_TYPE_ID` |
| `OAGWBG_BUDGETDISBURSEMENTPLANITEM` | Table | แผนการใช้จ่ายรายเดือน `CATEGORYID` ถูกย้ายตามคำขอ และมี 12 แถวยอด 0 ถูกสร้างพร้อม "รายการจัดสรร พรบ" |
| `OAGWBG_BUDGETCODE_YEAR` | Table | รหัสงบประมาณต่อ (ปี, Category, ผลผลิต, กิจกรรม) |
| `OAGWBG_BUDGETREQUEST` | Table | คำขอต้นทาง (`PARENTID`) |
| `OAGWBG_V_BUDGETGOVERNMENT` | View | ใช้ตอนส่ง GL (type 6/5) ใน `SaveBudgetAllocate` |
| `OAGWBG_LOG_INTERFACE` + `oagwbg.oaggl_journal_interface` | Table | log และ staging GL ตอนยืนยัน (ผ่าน `SaveInterface`) |

**Stored Procedure / Temp table:** flow นี้ **ไม่มี SP และไม่มี temp table** ทุกอย่างทำผ่าน EF Core และ raw `UPDATE ... REQ_*` ใน C#
- ยืนยัน (`ConfirmBudgetAllocatePlan`): เปลี่ยน `BUDGETSTATUS` จาก `B` เป็น `C` แล้วส่ง GL ผ่าน `SaveBudgetAllocate` เข้า `oaggl_journal_interface` และ `OAGWBG_LOG_INTERFACE`
- ยกเลิกยืนยัน (`CancelConfirmBudgetAllocateItems`, L6440): เปลี่ยน `C` กลับเป็น `B` และอ้างบรรทัดใน `OAGWBG_LOG_INTERFACE`
- Category ค่ากลางไม่มี type 6 (โค้ดข้ามไว้ L5164) ยอด GL ของค่ากลางจึงเป็น 0 เสมอ ส่วนหน้าจอมีการ์ดกันไม่ให้ยืนยันถ้า dummy ยังมียอดค้าง (View L1043)

---

## 4. Flow ปัจจุบัน และสาเหตุของแต่ละอาการ

### 4.1 Flow การย้ายรายการค่ากลาง (version บน server)

```
[พิจารณาคำขอ / คำขอภาพรวม]  คำขอที่ Category = ค่ากลาง ถูกอนุมัติ → BUDGETGOVERNMENT (type NULL, CATEGORYID = 2191 ฯลฯ)
        │
[UI] BudgetAllocateDetail → GetBudgetAllocateTabData → API GetBudgetAllocateItemsByTabPlanId
        │      view OAGWBG_V_BUDGETALLOCATEITEM: ค่ากลาง = 1 แถวต่อคำขอ (FINAL_YES_BG)
        │      service group ตาม CategoryId → แถวรายการค่ากลาง 1 แถว + แถวคำขอใต้แถวนั้น
        │      partial: ซ่อนแถวรายการค่ากลาง (CSS data-dummy=1 + data-has-req=1) และแสดงแถวคำขอที่มี dropdown Category
        │
[UI] ผู้ใช้เลือก Category ใหม่ใน dropdown ของแถวคำขอ → แถวนั้นได้ data-moved=1 และยอดถูกตัดออกจากแถวค่ากลาง
[UI] กด "บันทึก" → payload:
        budgetGovernment      : {budgetgovernmentid: <คำขอ>, categoryid: <ใหม่>}
        budgetGovernmentType  : type 5/6/8 ของ Category ใหม่ (pushMovedRequestToCategory)
        budgetCodeYear        : รหัสงบของ Category ใหม่
        budgetAllocateNew     : ทุกแถวรายการ **รวมแถวค่ากลางที่ซ่อนอยู่ด้วย**   ← จุดที่ก่อปัญหา
        budgetRequestAllocate : ยอด REQ_* รายคำขอ
        │
[MVC] BudgetController.SaveBudgetAllocateDetail → HTTP → [API] BudgetService.SaveBudgetAllocateDetail (L4813)
        ① L4928  ถ้า Category เปลี่ยน → DUMMY_CATEGORY = Category เดิม, CATEGORYID = ใหม่
                  (ย้ายแผนการใช้จ่าย, type 4 กันส่วนกลาง และแผนของคำขอลูกตามไปด้วย)
        ② L5015  วน budgetAllocateNew: ถ้า (ปี, Category) ไม่มี record → สร้าง "รายการจัดสรร พรบ" + แผน 12 เดือน
                  ↑ ค่ากลางที่เพิ่งถูกย้ายออกจนหมดใน ① จะไม่มี record เหลือ → ระบบสร้างแถวเปล่าให้ค่ากลาง
        ③ L5134  type 5/6/8 (ค่ากลางไม่สร้าง type ใหม่)
        ④ L5221  BUDGETCODE_YEAR
        ⑤ SaveRequestAllocateAmountsAsync → UPDATE REQ_*
        │
[reload] view: คำขอที่ย้ายแล้วไปอยู่ใน FINAL_NON_YES ของ Category ใหม่ (ไม่มีอะไรบอกว่าเคยเป็นค่ากลาง)
         ค่ากลาง: เหลือแค่แถว "รายการจัดสรร พรบ" (BUDGETREQUESTID = 0) ซึ่งผ่าน filter ของ service
         `Totalrequestsimmaryamount != 0 || Budgetrequestid == 0` (L6019) → requestList ว่าง → data-has-req ไม่ถูกตั้ง
         → CSS ไม่ซ่อนแถวแล้ว → **แถวค่ากลางยอด 0 โผล่ขึ้นมา**
```

### 4.2 หลักฐานจาก PREPROD (ปี 2572, แผน 3124, ผลผลิต 21000, กิจกรรม 21100)

| BG.ID | CATEGORYID | ประเภท | BUDGETREQUESTID | DUMMY_CATEGORY | ยอด | CREATEON |
|---|---|---|---|---|---|---|
| 73698 | 2212 ค่าซ่อมแซมยานพาหนะฯ | คำขอ | 2294 | **2191** | 21,000,000 | 2026-09-29 |
| 73699 | 2219 ค่าเช่าเครื่องถ่ายเอกสาร | คำขอ | 2294 | **2191** | 21,000,000 | 2026-09-29 |
| 73727 / 73730 | 2212 / 2219 | type 6 เสนอจัดสรร | – | – | 18,900,000 / 20,900,000 | 2026-09-30 03:02:40 |
| **73725** | **2191 ค่าตอบแทน (อื่นๆ โปรดระบุ...)** | **"รายการจัดสรร พรบ"** | **0** | – | **ว่าง** | **2026-09-30 03:02:38** |

- 73725 ถูกสร้างห่างจาก type 6 ของ Category ปลายทางแค่ 2 วินาที แปลว่าเกิดใน save ครั้งเดียวกัน ตรงกับขั้น ② ด้านบน
- view `OAGWBG_V_BUDGETALLOCATEITEM` ของ Category 2191 ปี 2572 คืนแถวเดียว คือ `DUMMY | BUDGETREQUESTID=0 | BG_ID=73725` และยอดทุกช่องเป็น 0 ซึ่งตรงกับที่ผู้ใช้เห็น
- 73725 มี `OAGWBG_BUDGETDISBURSEMENTPLANITEM` ติดอยู่ 12 แถว (ยอด 0) และไม่มี type 4 อ้างถึง
- ทั้ง PREPROD มี record แบบนี้ (Category ค่ากลาง + `BUDGETREQUESTID = 0`) **แค่ 1 แถว** คือ 73725
- แถวที่มี `DUMMY_CATEGORY` (เคยย้ายออกจากค่ากลาง) มีทั้งหมด 21 แถว: ปี 2569 = 1, 2570 = 18, 2572 = 2
- คำขอที่ยังค้างอยู่ใน Category ค่ากลาง (ยังไม่ได้ย้าย): ปี 2569 = 327, ปี 2570 = 335

### 4.3 สาเหตุแยกตามอาการ

| # | อาการ | สาเหตุ | Layer |
|---|---|---|---|
| A | ย้ายแล้วไม่รู้ว่าเคยเป็นค่ากลาง | `DUMMY_CATEGORY` ถูกบันทึกแต่ไม่ถูกอ่านไปแสดง: API ไม่ select, DTO ไม่มี field, partial ไม่ render | API / Model / View |
| B | ค่ากลางเหลือแถวยอด 0 | หน้าจอส่ง Category ค่ากลาง (แถวที่ซ่อนอยู่) ใน `budgetAllocateNew` ร่วมกับที่ server ไม่กัน `DUMMY_FLAG = YES` ในขั้นสร้าง "รายการจัดสรร พรบ" ทำให้เกิด record เปล่า และ filter `Budgetrequestid == 0` ปล่อยให้แสดง | View (JS) / API |
| C | (แฝง) ย้ายซ้ำแล้วร่องรอยหาย | L4931 บน server ใช้ `DummyCategory = Categoryid` (เขียนทับ) ถ้าย้าย ค่ากลาง → A → B จะได้ `DUMMY_CATEGORY = A` แทนที่จะเป็นค่ากลาง | API |
| D | (แฝง) ยอดค่ากลางในคอลัมน์จัดสรร/แปรญัตติเป็น 0 เสมอ | ออกแบบไว้แบบนั้นใน view สาขา `FINAL_YES_BG` (ตั้ง 0 ตายตัว) ยอดรายคำขอของค่ากลางเก็บใน `REQ_*` และแสดงที่แถวคำขอแทน | View DB |
| E | (แฝง) ไม่มี audit ตอนย้าย | ขั้น ① ไม่ได้ตั้ง `UPDATEBY`/`UPDATEON` ให้แถวคำขอที่ถูกย้าย | API |

---

## 5. Pending change ใน workspace (ยังไม่ checkin)

ผลจาก `tf status` / `tf diff` เทียบ server: BudgetService.cs C19545, partial C19539, view C19542, ViewModel C19528

| ไฟล์ | สิ่งที่แก้ไว้แล้ว | ปิดอาการ |
|---|---|---|
| `OAGBudget.API/.../BudgetService.cs` | `DummyCategory ??=` (เก็บค่ากลางครั้งแรกครั้งเดียว) | C |
| 〃 | ข้ามการสร้าง "รายการจัดสรร พรบ" เมื่อ Category เป็น `DUMMY_FLAG = YES` | B (เฉพาะการบันทึกครั้งต่อไป) |
| 〃 | select `DUMMY_CATEGORY` และ resolve ชื่อ Category ค่ากลางเข้า `BudgetAllocateRequestItem` | A |
| `OAGBudget.Models/.../BudgetAllocateDetailViewModel.cs` | เพิ่ม `DummyCategory`, `DummyCategoryName` | A |
| `_tableBudgetAllocateDetailPersonal.cshtml` | ไอคอน `fa-random` + tooltip "ย้ายมาจากค่ากลาง: …" ที่แถวรายการและแถวคำขอ · hidden `SingleReqBudgetGovernmentId` | A |
| `BudgetAllocateDetail.cshtml` | `collectRequestRows` ส่ง `REQ_*` ของรายการที่มีคำขอเดียวด้วย | ยอดรายคำขอตรงหลังย้าย |

**สิ่งที่ WIP ยังไม่ครอบคลุม:**
1. **ข้อมูลเสียที่มีอยู่แล้ว** (73725 บน PREPROD และอาจมีบน PROD) ยังโผล่เป็นแถว 0 เหมือนเดิม เพราะ WIP กันแค่การสร้างใหม่
2. หลังย้ายออกครบ แถวค่ากลาง **จะหายไปทั้งแถว** ซึ่งอาจ **ขัดกับ requirement** ที่ว่า "รายการที่เป็นค่ากลางยังคงแสดงอยู่" (ดูคำถามข้อ 7)
3. สิ่งที่บอกว่าเคยเป็นค่ากลางมีแค่ tooltip (ต้อง hover) ซึ่งผู้ใช้อาจมองไม่เห็น
4. ยังไม่ได้ build/ทดสอบ WIP ในรอบนี้ (งานนี้เป็น analysis-only)
5. JS ฝั่งหน้าจอยังส่ง Category ค่ากลางใน `budgetAllocateNew` อยู่ ตอนนี้กันไว้ที่ server ชั้นเดียว

---

## 6. สิ่งที่ต้องเปลี่ยนในแต่ละ layer (ข้อเสนอ ยังไม่ได้แก้)

| Layer | ต้องทำ | หมายเหตุ |
|---|---|---|
| **DB (ข้อมูล)** | ทำ script ลบ record "รายการจัดสรร พรบ" ที่อยู่บน Category ค่ากลาง (`BUDGETREQUESTID = 0`) พร้อม `BUDGETDISBURSEMENTPLANITEM` ที่ผูกอยู่ (PREPROD = 73725 + 12 แถว) | **R1** ต้องรัน query ตรวจบน PROD ก่อน (ภาคผนวก Q1) และทำ rollback script ที่ backup แถวไว้ก่อนลบ |
| **DB (view)** | ไม่ต้องแก้ถ้าเลือกแนวทาง A · ถ้าเลือกแนวทาง B อาจต้องเพิ่มสาขาใน `OAGWBG_V_BUDGETALLOCATEITEM` หรือ query แยกใน service | ถ้าแก้ view ต้องดึง DDL สดและพิสูจน์จำนวนแถวด้วย COUNT + MINUS สองทาง |
| **API Service** | (1) checkin WIP: `??=`, กัน dummy ใน "รายการจัดสรร พรบ", ส่ง `DummyCategory/Name` · (2) ตั้ง `Updateby/Updateon` ให้แถวคำขอที่ย้าย · (3) ถ้าเลือกแนวทาง B: ใน `GetBudgetAllocateItemsGroupByPlanId` ดึงแถวที่ `DUMMY_CATEGORY = <ค่ากลาง>` มาแสดงเป็นแถวประวัติใต้ค่ากลาง โดยไม่นำไปรวมยอด | ระวังไม่ให้ยอดชั้นบนถูกนับซ้ำ |
| **Model** | WIP พอแล้วสำหรับแนวทาง A · แนวทาง B ต้องเพิ่ม DTO สำหรับแถวประวัติ เช่น `MovedTo`, `MovedToName`, ยอดคำขอเดิม | |
| **View / Partial** | (1) checkin WIP · (2) เปลี่ยน tooltip เป็นข้อความที่มองเห็นได้เลย เช่น badge "เดิม: ค่าตอบแทน (อื่นๆ)" ถ้าผู้ใช้ต้องการ · (3) ใน JS `#btn-save`, `#btn-Confirm`, `#btn-save-@ExpenseType` ไม่ push แถว `data-dummy="1"` เข้า `budgetAllocateNew` (ป้องกันสองชั้น) | มี 3 handler ที่สร้าง payload ซ้ำกัน ต้องแก้ให้ครบทุกตัว |
| **MVC Controller / proxy** | ไม่ต้องแก้ (ส่งต่ออย่างเดียว) | |

**แนวทาง A** (WIP ปัจจุบัน): ค่ากลางที่ถูกย้ายออกครบจะหายจากหน้าจอ และรายการปลายทางมีไอคอนบอกที่มา ขอบเขตงานเล็ก
**แนวทาง B**: ค่ากลางยังแสดงต่อเป็นแถวประวัติ เช่น "ย้ายไป: ค่าซ่อมแซมยานพาหนะฯ 21,000,000" โดยไม่นำไปรวมยอด ตรงกับ requirement ตามตัวอักษร แต่ต้องแก้ทั้ง service, DTO และ partial

---

## 7. คำถามที่ต้องให้ผู้ใช้/BA ตอบก่อนลงมือแก้

1. **"รายการที่เป็นค่ากลางยังคงแสดงอยู่"** หมายถึงอะไร
   - (A) หลังย้ายออกครบ ค่ากลางไม่ต้องแสดงแล้ว แค่ให้รายการปลายทางบอกว่ามาจากค่ากลาง
   - (B) ค่ากลางต้องยังแสดง พร้อมบอกว่าย้ายไปที่ไหนและยอดเท่าไร (เป็นประวัติ ไม่นำไปรวมยอด)
   - (C) ค่ากลางต้องยังแสดงยอดเดิมด้วย ⚠️ ถ้าเลือกข้อนี้ยอดจะถูกนับซ้ำกับรายการปลายทาง ไม่แนะนำ
2. การบอกที่มาต้องเห็นได้ทันที (badge หรือข้อความ) หรือ tooltip ตอน hover ก็พอ
3. ต้องแสดงที่มาค่ากลางในรายงานด้วยหรือไม่ เช่น ReportBudgetAllocate (มีงานคู่ขนานอยู่ใน `20261001_ReportBudgetAllocate_DummyAllocate`)
4. อนุมัติให้ลบ record 73725 บน PREPROD และตรวจ/ลบแบบเดียวกันบน PROD หรือไม่ (**R1**)
5. pending change ใน workspace (ข้อ 5) เป็นของใคร และใช้เป็นฐานต่อได้หรือไม่

---

## 8. สมมติฐาน ข้อจำกัด และความเสี่ยง

- **สมมติฐาน:** อาการที่ผู้ใช้แจ้งมาจากเคสปี 2572 (คำขอ 2294 "การออกทดสอบพื้นฐาน4") เพราะเป็น record ยอด 0 บนค่ากลางแถวเดียวที่พบใน PREPROD ถ้าผู้ใช้เจอบน PROD ต้องรัน Q1 บน PROD เพื่อยืนยัน (รอบนี้ไม่ได้ query PROD)
- `UPDATEON` ของแถวคำขอที่ย้ายไม่บอกเวลาที่ย้ายจริง เพราะโค้ดไม่ได้ตั้งค่า ข้อสรุปว่าเกิดใน save เดียวกันจึงอิงจาก `CREATEON` ของ 73725 เทียบกับ type 6 ซึ่งห่างกัน 2 วินาที
- **Blast radius ถ้าแก้:** `SaveBudgetAllocateDetail` ถูกเรียกจาก 3 ทาง คือ บันทึก, บันทึก+ยืนยัน และบันทึก+ยืนยันใหม่ และ partial ถูกใช้ทั้ง 4 แท็บแผนงาน ต้องทดสอบครบทุกแท็บ
- **Reversibility:** แก้ code = R2 (rollback ผ่าน TFS ได้) · ลบข้อมูล 73725 = R1 (ต้อง backup ก่อน) · แก้ view = R1
- **Scope:** โจทย์คือเรื่องการแสดงที่มาและแถวยอด 0 การแก้อาการ D (view ตั้งยอดค่ากลางเป็น 0) และการแสดงในรายงานอยู่นอกขอบเขต ยังไม่ควรรวมเข้ามา

---

## 9. ข้อสรุปหลังผู้ใช้ตอบ (2026-10-01)

> "ถ้าเปลี่ยนไปเป็นรายการจริงแล้ว ไม่ควรสร้างแถวค่ากลาง (DUMMY) ขึ้นมาอีก แค่บอกว่ารายการนี้เคยเป็นค่ากลางมาก่อนก็พอ"

| ข้อ | คำตอบ | ผลต่อการแก้ |
|---|---|---|
| 7.1 | **A** | ค่ากลางที่ย้ายออกครบไม่ต้องแสดงอีก |
| 7.2 | tooltip ตอน hover พอ | ใช้ไอคอน `fa-random` + `title` ตามที่ทำไว้ใน WIP |
| 7.3 | ไม่ต้องทำรายงาน | ไม่แตะ ReportService/view รายงาน |
| 7.4 | ทำ script ลบ (ไม่ต้องรัน) | `cleanup_delete.sql` + `cleanup_rollback.sql` |
| 7.5 | ไม่ต้องสนใจ | ใช้ pending change ใน workspace เป็นตัวแก้ |

**สถานะ code:** pending change ใน workspace ครอบคลุมแนวทาง A ครบแล้ว จึง **ไม่ได้แก้ code เพิ่ม**
- `SaveBudgetAllocateDetail` ข้ามการสร้าง "รายการจัดสรร พรบ" เมื่อ Category เป็น `DUMMY_FLAG = YES` (ทางเดียวในระบบที่สร้าง record นี้ — grep ทั้ง solution แล้ว)
- `DUMMY_CATEGORY ??=` เก็บค่ากลางต้นทางครั้งแรกครั้งเดียว
- API ส่ง `DummyCategory` / `DummyCategoryName` และ partial แสดงไอคอน + tooltip "ย้ายมาจากค่ากลาง: …"
- ไม่ได้ทำ (นอกขอบเขต): กันซ้ำที่ JS `budgetAllocateNew`, ตั้ง `UPDATEBY/UPDATEON` ตอนย้าย

**ผลตรวจ:**
- `dotnet build OAGBudget.sln` → Build succeeded, 0 Error(s)
- รัน API (PREPROD) เรียก `GET api/Budget/GetBudgetAllocateItemsByTabPlanId?BudgetYear=2572&BudgetFormTypeId=1&PlanId=3124` → HTTP 200 คำขอ 73698 (→2212) และ 73699 (→2219) ได้ `dummyCategory: 2191`, `dummyCategoryName: "ค่าตอบแทน (อื่นๆ โปรดระบุ...)"`
- dry-run SELECT ทุก STEP ของ `cleanup_delete.sql` บน PREPROD ได้ค่าตามที่คาด (เป้าหมาย 1 แถว / อ้างอิงอื่น 0 / แผน 12 แถวยอด 0)
- **ยังไม่ได้ทดสอบ:** หน้าจอ MVC จริง (ต้อง login) และการกดบันทึกย้ายค่ากลาง (เขียน DB) — ควรทดสอบบน PREPROD ก่อน checkin
- `cleanup_rollback.sql` สร้างจากข้อมูลจริงทุกคอลัมน์ แต่ยังไม่ได้รันจริง

**ลำดับ deploy:** checkin + deploy code → รัน `cleanup_delete.sql` (ถ้ารัน PROD ต้องรัน STEP 1 ที่ PROD และสร้าง rollback ของ PROD ก่อน)

**PROD:** ใช้ `cleanup_delete_PROD.sql` / `cleanup_rollback_PROD.sql` แทน — เลือกแถวด้วยเงื่อนไข (ไม่ผูก ID), backup ลง `OAGWBG_BK1001_DUMMY_BG` / `OAGWBG_BK1001_DUMMY_DPI` ก่อนลบ, ลบเฉพาะ ID ในตาราง BK, rollback = INSERT กลับจาก BK, ไม่อ้างคอลัมน์ `REQ_*` / `DUMMY_CATEGORY`
- dry-run ส่วน SELECT ทั้งหมดบน PREPROD แล้ว รันผ่านไม่มี error (ณ เวลาตรวจ 73725 ถูกลบออกจาก PREPROD ไปแล้ว ผลจึงเป็น 0 แถว — ทางที่เจอแถวแล้วสร้าง BK/ลบ ยังไม่ได้ทดสอบจริง)

---

## 10. ยอด "เสนอจัดสรร" ชั้นงบรายจ่ายขาดยอดของคำขอค่ากลาง (ผู้ใช้แจ้ง 2026-10-01)

**อาการ:** ปี 2570 แผนงานพื้นฐาน แถว "ค่าใช้สอย - รายการไม่ผูกพัน" ช่องเสนอจัดสรร (78,023,2xx) ไม่รวมคำขอ "โครงการจัดทำคู่มือการปฏิบัติงานของพนักงานอัยการ สำนักงานคดีปราบปรามทุจริต" (เสนอจัดสรร 469,200) ที่ยังอยู่ใต้ค่ากลาง "ค่าใช้สอย รายการไม่ผูกพัน (อื่นๆ โปรดระบุ...)"

**สาเหตุ:**
1. ค่ากลางไม่มี record type 8/6/5 (`SaveBudgetAllocateDetail` ข้ามการสร้าง) และ view `OAGWBG_V_BUDGETALLOCATEITEM` สาขา `FINAL_YES_BG` ตั้งยอดเป็น 0 ไว้ ยอดจริงอยู่ที่ `REQ_*` ของแถวคำขอ
2. `GetBudgetAllocateItemsGroupByPlanId` จึงได้ยอดแถวรายการค่ากลางเป็น 0 ซึ่งเป็นแถวที่ถูกซ่อนไว้ด้วย CSS
3. `recalcParent` ในหน้าจอรวมเฉพาะ `Totalallocateamount*` ของแถวลูก ส่วนแถวคำขอใช้ชื่อ `ReqAllocate` ซึ่งตั้งใจไม่ให้นับซ้ำ ยอดของคำขอค่ากลางจึงขึ้นไปชั้นบนผ่านแถวรายการที่ซ่อนอยู่เท่านั้น เมื่อแถวนั้นเป็น 0 ยอดชั้นบนจึงขาด จนกว่าผู้ใช้จะพิมพ์ในแถวคำขอ (event `input` คำนวณใหม่)
4. **ผลข้างเคียงที่ร้ายกว่า:** การ์ดกันยืนยัน (View L1043) อ่านยอดจากแถวที่ซ่อนอยู่ซึ่งเป็น 0 จึงไม่เตือน ทำให้ยืนยันได้ทั้งที่ค่ากลางยังมียอด และยอดนั้นไม่ถูกส่ง GL เพราะค่ากลางไม่มี type 6

**สิ่งที่แก้ (`OAGBudget.API/Services/Repository/BudgetService.cs`, `GetBudgetAllocateItemsGroupByPlanId`):** เพิ่ม local function `SumAllocateAmounts` ถ้ากลุ่มเป็นค่ากลาง ให้รวม `REQ_TOTALREQUESTADJUSTAMOUNT / REQ_TOTALALLOCATEAMOUNT / REQ_TOTALADJUSTEDAMOUNT` ของคำขอที่ยังอยู่ในค่ากลาง ถ้าเป็นรายการปกติ ใช้ `SumDistinctByRecord` แบบเดิม ใช้ทั้งระดับกลุ่ม Category และแถวรายการ
- คำขอที่ย้ายออกไปแล้วมี `CATEGORYID` เป็นของใหม่ จึงไม่ถูกนับในค่ากลาง ไม่นับซ้ำ
- method นี้มีผู้เรียกที่เดียว (`api/Budget/GetBudgetAllocateItemsByTabPlanId` ที่หน้านี้)
- **behavior ที่เปลี่ยน:** การ์ดกันยืนยันจะเริ่มเตือนรายการค่ากลางที่ยังมียอดค้าง (ตาม design เดิมที่ตั้งใจไว้)

**ผลตรวจ:** `dotnet build OAGBudget.API.csproj -o <scratch>` → 0 Error(s) (build ลง bin ปกติไม่ได้เพราะ VS กำลังรัน API อยู่ เป็น file lock ไม่ใช่ compile error)
**ยังไม่ได้ตรวจ:** ตัวเลขจริง — ภาพหน้าจอที่ผู้ใช้แจ้งมาจาก **PROD** (`appsettings.Development.json` ของ API ชี้ 172.16.11.18:1531 ณ 2026-10-02) ไม่ใช่ PREPROD
- PREPROD: คำขอ 57314 "โครงการจัดทำคู่มือ…" (2570, Category 2210) มี `REQ_TOTALALLOCATEAMOUNT = 0` และค่ากลาง 2210 ปี 2570 ทั้ง 136 คำขอเป็น 0 → ตรวจเคส 469,200 บน PREPROD ไม่ได้
- ไม่ได้ query PROD (ถูกปฏิเสธสิทธิ์) — ผู้ใช้ต้อง restart API ใน VS แล้วดูหน้าจอเอง: แถว "ค่าใช้สอย - รายการไม่ผูกพัน" ช่องเสนอจัดสรร ควรเพิ่มขึ้นเท่ากับผลรวม REQ_TOTALALLOCATEAMOUNT ของคำขอค่ากลาง 2210 ใต้แถวนั้น

---

## 11. รายงาน "รายละเอียดงบประมาณ พ.ศ." แสดงแถวยอด 0 ทุกช่อง (ผู้ใช้แจ้ง 2026-10-02)

**อาการ:** ReportBudgetAllocate ปี 2570 มีแถวที่คำของบรวม/เสนอจัดสรร/แปรญัตติ เป็น 0 ทั้งหมด เช่น ค่าตอบแทนพิเศษ, ค่าเบี้ยประชุมคณะอนุกรรมการ

**ผลบน PROD (ผู้ใช้รัน `verify_PROD_2570_report_zero_rows.sql`):**
- `OAGWBG_R_BUDGETALLOCATE` ปี 2570 มีแถว 0 ทุกช่อง **174 แถว** — ทั้ง Category ปกติและค่ากลาง
- ต้นทางใน `OAGWBG_V_BUDGETALLOCATEITEM` เป็นคำขอจริงที่ **ยอดสุทธิเหลือ 0** เช่น แถว DUMMY `TOTALREQUESTAMOUNT 228,000 / KEPTCENTRAL -228,000` (กันส่วนกลางทั้งหมด) และแถว REQ ที่มียอดคำขอแต่คำของบรวมหลังแปร = 0
- **ไม่ใช่ข้อมูลขยะ** — ไม่ต้องลบ
- หน้า BudgetAllocateDetail ซ่อนแถวเหล่านี้อยู่แล้ว (`Totalrequestsimmaryamount != 0 || Budgetrequestid == 0`) แต่รายงานไม่ได้กรอง

> ⚠️ **ถอนแล้ว (2026-10-02):** ผู้ใช้ยืนยันว่ารายการเหล่านี้ **มียอดบนหน้าจอ** — ข้อสรุป "ยอดสุทธิ 0 จริง" ด้านบนเป็นการเดาจากคอลัมน์ที่ถูกตัดในภาพ (ไม่เห็น `TOTALREQUESTSIMMARYAMOUNT`) จึงไม่ถูกต้อง
> การกรองแถว 0 ทิ้งจะซ่อนบั๊กที่รายงานคำนวณยอดหาย → ถอน code ออกแล้ว (`tf status` ไม่มี pending change ใน ReportService.cs)
> ต่อ: ผู้ใช้รัน `verify_PROD_2570_report_vs_screen.sql` เทียบแถวรายงาน / แถว view / record จริง ของ 3 รายการ แล้วหาว่ายอดที่หน้าจอเห็นหายไปตรงไหนใน `OAGWBG_R_BUDGETALLOCATE`

**ผลตรวจละเอียดบน PROD (CSV จาก `verify_PROD_2570_report_vs_screen.sql`, 2026-10-02) — แผน 3124 ผลผลิต 21000:**

| Category | กิจกรรม | คำขอที่ view นับ (สถานะ B/C, type ว่าง/7) | กันส่วนกลาง type 4 | สุทธิ (view = รายงาน) |
|---|---|---|---|---|
| 2199 ค่าตอบแทนพิเศษ | 21100 | 312,000 + 600,000 + 3,331,000 + 642,000 (type 7) = 4,885,000 | 51959: -4,885,000 | 0 |
| 〃 | 21200 | 72,000 | 72044: -72,000 | 0 |
| 〃 | 21300 | 130,000 + 124,800 = 254,800 | 72102: **+30,255,200** | 30,510,000 (เสนอจัดสรร 2,034,000) |
| 2200 ค่าเบี้ยประชุมคณะอนุกรรมการ | 21100 | 393,000 + 12,600 + 110,000 + 472,800 = 988,400 | 72021: -988,400 | 0 |
| 〃 | 21200 | 27,000 + 127,750 + 13,500 = 168,250 | 72045: -168,250 | 0 |
| 〃 | 21300 | 304,000 + 5,768,000 = 6,072,000 | 45761: -304,000 | 5,768,000 |
| 2201 (…0010) | 21100 | 1,391,000 | 72022: -1,391,000 | 0 |
| 〃 | 21300 | 117,137,300 | 45756: -29,387,300 | 87,750,000 |

- ยอดรายงานตรงกับ view และ record จริงทุกแถว → **รายงานคำนวณถูก ไม่มียอดหาย**
- แถว 0 = กิจกรรมที่คำขอถูกหักด้วยกันส่วนกลางเต็มจำนวน (ทำที่ขั้นคำขอภาพรวม)
- กันส่วนกลางฝั่งบวก (+30,255,200 ที่ 2199/21300) **ไม่เท่ากับ** ยอดที่หักจาก 21100+21200 (4,957,000) → ไม่ใช่การ "ย้าย" ตรง ๆ ระหว่างกิจกรรม เป็นยอดที่ผู้ใช้กำหนดเองตอนทำคำขอภาพรวม
- คำขอสถานะ U ไม่ถูกนับ (เช่น 43080 642,000) แต่มีฉบับ type 7 ยอดเท่ากันถูกนับแทน (71210)
- ค้างตอบ: ผู้ใช้เห็นยอดที่หน้าจอไหน (คาดว่าเป็นหน้าคำขอภาพรวม/พิจารณาคำขอ ซึ่งแสดงยอดก่อนกันส่วนกลาง)

**ผู้ใช้ตัดสินใจ (2026-10-02): กรองแถวที่ `REQUESTAMOUNT = 0` ออก** (ไม่ดูช่องเสนอจัดสรร/แปรญัตติ)
- แก้ `ReportService.ReportBudgetAllocate`: `query.Where(x => (x.Requestamount ?? 0) != 0)` → build ผ่าน 0 Error(s)
- PREPROD: แถวคำขอ 0 มี 88 แถว (2569 = 86, 2570 = 1, 2572 = 1) **ไม่มีแถวไหนมียอดเสนอจัดสรร/แปรญัตติ** → ยอดรวมรายงานไม่เปลี่ยน (ปี 2570: 632 → 631 แถว ยอดเท่าเดิมทุกหลัก)
- ⚠️ PROD ยังไม่ได้ตรวจว่ามีแถว "คำขอ 0 แต่มีเสนอจัดสรร/แปรญัตติ" หรือไม่ — ถ้ามี ยอดเหล่านั้นจะหายจากรายงาน ต้องรัน query ตรวจก่อน deploy

**เปลี่ยนเงื่อนไขอีกครั้ง (ผู้ใช้สั่ง 2026-10-02): แสดงแถวถ้ามียอดช่องใดช่องหนึ่ง** — ตัดเฉพาะแถวที่ คำขอ / เสนอจัดสรร / แปรญัตติ เป็น 0 ทั้ง 3 ช่อง
- `query.Where(x => (x.Requestamount ?? 0) != 0 || (x.Proposeamount ?? 0) != 0 || (x.Amendamount ?? 0) != 0)`
- แถวที่ตัดเป็น 0 ล้วน → ยอดรวมทุกชั้นไม่เปลี่ยนแน่นอน ความเสี่ยงข้อบนหมดไป ไม่ต้องตรวจ PROD ก่อน deploy

~~**สิ่งที่แก้ (`OAGBudget.API/Services/Repository/ReportService.cs`, `ReportBudgetAllocate`):** เพิ่ม `Where` ตัดแถวที่ `Requestamount`, `Proposeamount`, `Amendamount` เป็น 0 ทั้ง 3 ช่อง (แปลงเป็น WHERE ใน SQL) — ไม่แตะ view~~
- `OAGWBG_R_BUDGETALLOCATE` มีผู้ใช้ใน code ที่เดียว (`ReportBudgetAllocate`) ครอบทั้ง 3 เงื่อนไข (เฉพาะปี / มีแผน / มีผลผลิต)
- แถวที่ตัดเป็น 0 ล้วน ยอดรวมทุกชั้นจึงไม่เปลี่ยน

**ผลตรวจ:**
- `dotnet build OAGBudget.API.csproj -o <scratch>` → 0 Error(s)
- PREPROD ปี 2570: ก่อนกรอง 632 แถว / หลังกรอง 631 แถว — ยอดคำขอ 17,851,177,920.44 / เสนอจัดสรร 15,183,144,576.60 / แปรญัตติ 200 **เท่ากันทุกหลัก**
- PROD: ยังไม่ได้รัน query เทียบ (คาดว่าตัด 174 แถว ยอดเท่าเดิม) และยังไม่ได้เปิดรายงานจริงหลัง restart API

---

## ภาคผนวก: Query ที่ใช้ (read-only)

```sql
-- Q1: record ยอด 0 บน Category ค่ากลาง (ตัวที่ทำให้เห็นแถว 0)
SELECT BG.ID, BG.BUDGETYEAR, BG.CATEGORYID, CC.NAME, BG.BUDGETPLANID, BG.PRODUCTID, BG.ACTIVITYCODEID, BG.BUDGETDETAIL, BG.CREATEON
FROM OAGWBG_BUDGETGOVERNMENT BG
JOIN OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V CC ON CC.ID = BG.CATEGORYID
WHERE CC.DUMMY_FLAG = 'YES' AND BG.BUDGETREQUESTID = 0;

-- Q2: คำขอที่เคยย้ายออกจากค่ากลาง
SELECT BG.ID, BG.BUDGETYEAR, BG.BUDGETREQUESTID, BG.DUMMY_CATEGORY, DC.NAME AS DUMMY_NAME, BG.CATEGORYID, NC.NAME AS NEW_CAT
FROM OAGWBG_BUDGETGOVERNMENT BG
LEFT JOIN OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V DC ON DC.ID = BG.DUMMY_CATEGORY
LEFT JOIN OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V NC ON NC.ID = BG.CATEGORYID
WHERE BG.DUMMY_CATEGORY IS NOT NULL ORDER BY BG.BUDGETYEAR, BG.ID;

-- Q3: สิ่งที่หน้าจอเห็น (ตัวอย่างปี 2572)
SELECT CATEGORY_ID, CATEGORY_NAME, DUMMY_FLAG, BUDGETGOVERNMENTTYPE, BUDGETREQUESTID, BUDGET_GOVERNMENT_ID,
       TOTALREQUESTSIMMARYAMOUNT, TOTALALLOCATEAMOUNT, TOTALADJUSTEDAMOUNT
FROM OAGWBG_V_BUDGETALLOCATEITEM
WHERE BUDGETYEAR = 2572 AND BUDGETFORMTYPEID = 1 AND CATEGORY_ID IN (2191, 2212, 2219);

-- Q4: แผนการใช้จ่ายที่ผูกกับ record ยอด 0
SELECT COUNT(*), SUM(NVL(PLANAMOUNT,0)) FROM OAGWBG_BUDGETDISBURSEMENTPLANITEM WHERE BUDGETGOVERNMENTID = 73725;
```
