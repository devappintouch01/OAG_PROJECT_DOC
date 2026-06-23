# Roadmap 308 — BudgetOverlapYearCentral (โอนงปม. เข้าบัญชีเงินกัน)

> เอกสารวิเคราะห์ (analysis only) — **ยังไม่แก้โค้ด** ตาม prompt ข้อ 4
> วันที่: 2026-06-23 · โมเดล: Opus 4.8 (max)
> Source ref: `prompt_308_budgetoverlapyearcentral.md`

---

## 0. บทสรุปผู้บริหาร (Executive Summary)

หน้าจอ **"โอนงปม. เข้าบัญชีเงินกัน" (BudgetOverlapYearCentral)** ปัจจุบันรองรับ workflow แบบ **รอบเดียว** ได้แก่ กันเงิน → ขยายเวลา/ส่งคืน (รอบที่ 1) → พิจารณา → ยืนยัน (interface ขึ้นปีถัดไป) แต่ requirement 308 ต้องการขยายให้รองรับ **"ขยายเวลา รอบที่ n"** (ทำซ้ำได้ทุก 6 เดือน) พร้อมเก็บ**ประวัติแบบ group level** และเพิ่มกติกา **disable หน้าจอตามช่วงเวลา/รอบ**

มี **3 การเปลี่ยนแปลงหลัก** ที่กระทบทุก layer:

| # | Requirement | กระทบหลักที่ | ระดับความเสี่ยง |
|---|---|---|---|
| 1 | ขยายเวลา รอบที่ n + เก็บประวัติ + เลขที่เงินกันเพิ่ม `.1/.2/.n` | DB schema, API read/save logic, ViewModel, Partial views | **R1 (สูง)** — เปลี่ยน data model + เปลี่ยนพฤติกรรม save จาก "replace" เป็น "append" |
| 2 | ช่วงเวลากิจกรรมทุก 6 เดือน (กันเงิน เม.ย.–ก.ย. / ขยายเวลา ต.ค.–มี.ค.) | Logic ตัดสินรอบ + ปีงบฯ (Oracle FN / C# helper) | **R1** — ตรรกะใหม่ ใช้ร่วมหลายหน้า |
| 3 | disable หน้าจอตามจังหวะอนุมัติ vs ตัดรอบ | View locking logic + ข้อ 2 | **R1** — ผูกกับข้อ 2 |

**ข้อสังเกตสำคัญที่สุด (blast radius):** ฟังก์ชัน save ปัจจุบัน `SynchronizeReservedItemsAsync` ใช้วิธี **ลบทิ้งทั้งหมดแล้วเขียนใหม่** (`RemoveRange(existingItems)` → re-insert) ซึ่ง **ขัดกับ requirement ข้อ 1 โดยตรง** เพราะ requirement ต้องการให้รอบเก่าคงอยู่เป็นประวัติ ต้องเปลี่ยนเป็น append-by-round ดูรายละเอียดข้อ 5.1

> ⚠️ ในเอกสารนี้ระบุ "ต้องเปลี่ยนอะไร" เป็นเชิงออกแบบ ยังมี **คำถามค้าง (ข้อ 8)** ที่ต้องการคำยืนยันก่อนลงมือเขียนจริง โดยเฉพาะรูปแบบเลขที่เงินกันเพิ่มและ schema ของ group level

---

## 1. ความเข้าใจ Requirement (ตีความ + จุดที่ต้องยืนยัน)

### 1.1 ขยายเวลา รอบที่ n

**Tab ไม่มีหนี้ (PR):**
- รอบ 1: ดึงจาก `OAGWBG_V_BUDGETOVERLAPYEAR_PR` → ถ้ากรอกยอดขยายเวลา+บันทึก ลง `OAGWBG_BUDGETRESERVEDITEM` → รีเฟรช: ดึงจาก `BUDGETRESERVEDITEM` ก่อน แล้วค่อยไปหาใน view PR (พฤติกรรมนี้ **มีอยู่แล้วบางส่วน** — ดูข้อ 4.2)
- รอบ n: ดึงจาก view PR ก่อนเสมอ (เพื่ออัปเดต**ยอดคงเหลือ**) แม้รายการเดิมถูก save แล้ว — รายการที่ขยายเวลารอบก่อนแสดงเป็น **group level** (เช่น `ขยายเวลา-ปีงบประมาณ 2569`, `กันเงินเหลื่อมปี`, `ปีงบประมาณ 2570`) เป็นประวัติใน DB → ถ้ากรอก+บันทึก ลง `BUDGETRESERVEDITEM` เป็น **record ใหม่** แม้เป็นรายการเดิม

**Tab มีหนี้ (PO):**
- รอบ 1: ดึงจาก `OAGWBG_V_BUDGETOVERLAPYEAR_PO` → ถ้ากรอก+บันทึก ลง `BUDGETRESERVEDITEM` → บันทึก **เลขที่เงินกันเพิ่ม** โดยเติม `.1` → รีเฟรช: ดึงจาก `BUDGETRESERVEDITEM` ก่อน แล้วค่อยไป view PO
- รอบ n: ดึงจาก `BUDGETRESERVEDITEM` ก่อน → รอบก่อนแสดงใต้ level `เลขที่เงินกัน.1` → แล้วดึงจาก view PO มาแสดงใน level ใหม่ → ถ้ากรอก+บันทึก ต่อเลข `.2 , .3 , ... , .n` ตามรอบ

> 📌 **ต้องเพิ่ม field** ใน `OAGWBG_BUDGETRESERVEDITEM` สำหรับเก็บ **เลขที่เงินกันเพิ่ม** (running `.n`) ของรายการขยายเวลา
> 📌 ใช้คำว่า **"เลขที่เงินกันเพิ่ม"** (แก้จาก "เลขที่เงินเพิ่ม" ตามที่ผู้ใช้ระบุ 2026-06-23)

### 1.2 ช่วงเวลากิจกรรม (ทุก 6 เดือน)
- **กันเงิน:** 1 เม.ย. 00:00 – 30 ก.ย. 23:59 (ปกติทำ ก.ย.)
- **ขยายเวลา:** 1 ต.ค. 00:00 – 31 มี.ค. 23:59 (ปกติทำ มี.ค.)

**วงจรชีวิตของเลขที่เงินกัน (lifecycle) — เพิ่มเติม 2026-06-23:**
1. สร้างเงินกันใหม่ ~**ก.ย.** = **กันเงินครั้งแรก** → ได้ **เลขที่เงินกัน**
2. พิจารณายืนยัน → **ส่ง interface** → เข้าสู่ช่วงขยายเวลา
3. ~**มี.ค.** = **ขยายเวลาครั้งแรก** (ของเลขที่เงินกันเดิม) → พิจารณายืนยัน → **ไม่ส่ง interface**
4. จากนั้นขยายเวลาครั้งต่อๆ ไป **สลับ ก.ย./มี.ค.** จนกว่ายอดจะถูกใช้หมด
5. **เมื่อวนกลับมารอบ ก.ย. ใหม่ → ส่ง interface อีกครั้ง**

> 🔑 **กติกา interface:** รอบ **ก.ย. = ส่ง interface** / รอบ **มี.ค. = ไม่ส่ง interface** (สลับกัน)
> 🔑 **เชื่อมโยงกับโค้ดที่มีอยู่แล้ว:** กติกานี้ = พฤติกรรมของ `Roundinterface` (toggle คู่/คี่) ใน `ConfirmBudgetReserved` พอดี → **ส่วน interface alternation มีอยู่แล้ว** ดูตารางใน 4.4 และ gap จริงใน 5.2

### 1.3 หลักการ disable หน้าจอ
เมื่อมีการทำรายการ (กันเงินใหม่/ขยายเวลา):
1. **อนุมัติหน้าพิจารณา *ก่อน* ตัดรอบ** → disable หน้าจอ จนกว่าจะขึ้นรอบถัดไป
2. **อนุมัติหน้าพิจารณา *หลัง* ขึ้นรอบถัดไป** → เปิดให้ใช้งานต่อได้เลย

ใช้เหมือนกันทั้ง **กันเหลื่อมส่วนกลาง (หน้าโอนงปม.)** และ **กันเหลื่อมหน่วยงาน (หน้ากันเหลื่อม/ขยายเวลา)**
ตัวอย่าง: กันเงินครั้งแรกปี 68 ทำที่ปีงบฯ 68 → หลังอนุมัติเงินกัน ส่ง interface ขึ้นหน้าจอปี 69

---

## 2. แผนผังไฟล์ที่เกี่ยวข้อง (File Inventory)

สถาปัตยกรรม **2 ชั้น**: Frontend MVC เรียก API ผ่าน HTTP (frontend มี proxy service ของตัวเอง) แล้ว API เรียก DAL/Oracle

### 2.1 UI — Views (Frontend `OAGBudget`)

| ไฟล์ | บทบาท | ต้องแก้? |
|---|---|---|
| [BudgetOverlapYearCentralList.cshtml](OAGBudget/Views/Budget/BudgetOverlapYearCentralList.cshtml) | หน้า list/ค้นหา | อาจแก้ (filter รอบ/ปี) |
| [BudgetOverlapYearCentralDetail.cshtml](OAGBudget/Views/Budget/BudgetOverlapYearCentralDetail.cshtml) (1,596 บรรทัด) | หน้า detail หลัก (pageType 1=แก้ไข, 2=พิจารณา) — มี `isLocked`, tabs, JS save/confirm | **แก้มาก** — locking, group level, save payload |
| [BudgetOverlapYearConsider.cshtml](OAGBudget/Views/Budget/BudgetOverlapYearConsider.cshtml) | หน้า list "พิจารณากันเงินเหลื่อมปี" | อาจแก้ (filter) |
| [_partialView/_tableExpandHasObligation.cshtml](OAGBudget/Views/Budget/_partialView/_tableExpandHasObligation.cshtml) | ตารางขยายเวลา-มีหนี้ (PO) — **ปัจจุบัน flat** | **แก้** — render group level + คอลัมน์เลขที่เงินกันเพิ่ม |
| [_partialView/_tableExpandNoObligation.cshtml](OAGBudget/Views/Budget/_partialView/_tableExpandNoObligation.cshtml) | ตารางขยายเวลา-ไม่มีหนี้ (PR) | **แก้** — render group level |
| [_partialView/_tableCancleHasObligation.cshtml](OAGBudget/Views/Budget/_partialView/_tableCancleHasObligation.cshtml) | เงินเหลือส่งคืน-มีหนี้ | อาจแก้ |
| [_partialView/_tableCancleNoObligation.cshtml](OAGBudget/Views/Budget/_partialView/_tableCancleNoObligation.cshtml) | เงินเหลือส่งคืน-ไม่มีหนี้ | อาจแก้ |
| [_partialView/_tableSummaryBalance.cshtml](OAGBudget/Views/Budget/_partialView/_tableSummaryBalance.cshtml) | สรุปยอด | review |

### 2.2 Frontend Controller + Proxy Service

| ไฟล์ / Action | บรรทัด | บทบาท |
|---|---|---|
| [Controllers/BudgetController.cs](OAGBudget/Controllers/BudgetController.cs) `BudgetOverlapYearCentralList()` | ~3260 | render list |
| `BudgetOverlapYearCentralDetail(id, pagetype, Departmentid, budgetYear)` | ~3017 | render detail; เซ็ต session `pageType`, dropdown bank |
| `SaveBudgetReservedCentrall([FromBody] BudgetReservedCentralFormModel)` | ~3331 | save → API |
| `GetBudgetReservedCentralList([FromQuery] ...)` | ~3435 | โหลด list tab "กันเงิน" |
| `SaveBudgetReserved` / `UpdateBudgetReserved` / `SubmitBudgetReservedModel` / `UpdateBudgetOverlapStatus` / `DeleteBudgetReservedItem` | 3256–3416 | save/submit/สถานะ/ลบ |
| [Services/Repository/BudgetService.cs](OAGBudget/Services/Repository/BudgetService.cs) `SubmitBudgetReservedtDetail` | ~2115 | proxy → API `/Budget/ConfirmBudgetReserved` |

### 2.3 API Controller + Service (Backend `OAGBudget.API`)

| ไฟล์ / Endpoint | บรรทัด | บทบาท |
|---|---|---|
| [Controllers/BudgetController.cs](OAGBudget.API/Controllers/BudgetController.cs) `GET GetBudgetOverlapYearCentralDetail/{id}` | ~2006 | |
| `POST SaveBudgetReservedCentrall` | ~2020 | |
| `GET GetBudgetReservedCentralList` | ~2073 | |
| `POST GetBudgetOverlapYearCentralList` | ~2090 | |
| `POST ConfirmBudgetReserved` | ~1964 | ยืนยัน + interface |
| **[Services/Repository/BudgetService.cs](OAGBudget.API/Services/Repository/BudgetService.cs)** `GetBudgetOverlapYearCentralList(model)` | **19435** | **เมธอดหลักดึง+merge รายการ (≈900 บรรทัด)** |
| `SynchronizeReservedItemsAsync(...)` | **21470** | **เขียน `BUDGETRESERVEDITEM` (ลบทิ้ง+เขียนใหม่)** |
| `SaveBudgetReservedCentrall(data)` | 21177 | save header/category/bank/items (transaction) |
| `ConfirmBudgetReserved(model)` | 19143 | ยืนยัน → toggle `Roundinterface` → `SaveBudgetReserved`/`SaveInterface` → `Budgetyear+1`, `Statusid=20202` |
| `GetBudgetYear()` | 5772 | เรียก Oracle FN `OAGWBG_FN_GETBUDGETYEAR(:date)` |
| `GetThaiFiscalYear(dt)` | 19010 | BE = ปี+543, +1 ถ้าเดือน ≥ 10 |
| `SaveInterface(...)` | 11696 | เขียน log interface → GL |

### 2.4 DAL Models / DbContext

| ไฟล์ | Map ไปยัง (Oracle) | บรรทัดใน DbContext |
|---|---|---|
| [OagwbgBudgetreserveditem.cs](OAGBudget.DAL/Models/OagwbgBudgetreserveditem.cs) | TABLE `OAGWBG_BUDGETRESERVEDITEM` | 4727 |
| [OagwbgVBudgetreserveditem.cs](OAGBudget.DAL/Models/OagwbgVBudgetreserveditem.cs) | VIEW `OAGWBG_V_BUDGETRESERVEDITEM` | 16071 |
| OagwbgBudgetreserved.cs | TABLE `OAGWBG_BUDGETRESERVED` | 4357 |
| [OagwbgVBudgetoverlapyearPr.cs](OAGBudget.DAL/Models/OagwbgVBudgetoverlapyearPr.cs) | VIEW `OAGWBG_V_BUDGETOVERLAPYEAR_PR` | 14532 |
| [OagwbgVBudgetoverlapyearPo.cs](OAGBudget.DAL/Models/OagwbgVBudgetoverlapyearPo.cs) | VIEW `OAGWBG_V_BUDGETOVERLAPYEAR_PO` | 14332 |
| [OAGDBContextBase.cs](OAGBudget.DAL/Models/OAGDBContextBase.cs) | DbContext (mapping) | — |

### 2.5 Models / DTOs (`OAGBudget.Models`)

| ไฟล์ | บทบาท | ต้องแก้? |
|---|---|---|
| [BudgetReservedCentralFormModel.cs](OAGBudget.Models/Data/BudgetReservedCentralFormModel.cs) | payload ตอน save | อาจเพิ่ม field (round, เลขที่เงินกันเพิ่ม) |
| [BudgetReservedCentralViewModel.cs](OAGBudget.Models/ViewModel/BudgetReservedCentralViewModel.cs) | model ส่งให้ view | **แก้** — เพิ่มโครงสร้าง group level |
| `SearchBudgetReversedItem` | filter ดึงรายการ | อาจเพิ่ม round |

---

## 3. Oracle Objects ที่เกี่ยวข้อง

### 3.1 Tables (เขียน)

| Table | บทบาทในหน้านี้ |
|---|---|
| `OAGWBG_BUDGETRESERVED` | header เอกสารกันเหลื่อม/โอนเข้าบัญชีเงินกัน (`Statusid`, `Budgetyear`, `Roundinterface`, `Transferno`) |
| `OAGWBG_BUDGETRESERVEDITEM` | **รายการขยายเวลา/ส่งคืน** (`Budgetreservedtype` = EXPAND_PO/EXPAND_PR/CANCEL_PO/CANCEL_PR) — **ต้องเพิ่ม column ใหม่** (ข้อ 5.1) |
| `OAGWBG_BUDGETRESERVED_CATEGORY` | หมวดงบที่กันเงิน (ยอดสำรอง) |
| `OAGWBG_BUDGETRESERVED_BANKACCOUNT` | บัญชีธนาคารต่อ expense type |
| `OAGWBG_BUDGETRECEIVE` | งบที่ส่ง interface ขึ้นปีถัดไป (สร้างตอน confirm รอบ 1) |
| `OAGWBG_RECEIVE_BATCH_NO` | running batch ของ interface (BG/ENC CARRY_FORWARD) |

### 3.2 Views (อ่าน)

| View | บทบาท |
|---|---|
| `OAGWBG_V_BUDGETOVERLAPYEAR_PR` | รายการ PR (ไม่มีหนี้) คงเหลือ — filter `BudgetSource='400'` + `Caryfwd_no = Transferno` |
| `OAGWBG_V_BUDGETOVERLAPYEAR_PO` | รายการ PO (มีหนี้) คงเหลือ — filter เดียวกัน |
| `OAGWBG_V_BUDGETRESERVEDITEM` | view รายการที่ save (มี `po_transfer_no`, `pr_transfer_no`) |
| `OAGWBG_V_BUDGETRESERVED` | header view |
| `OAGWBG_V_BUDGETRECEIVE` | งบรับจัดสรร (allocate) |

### 3.3 Functions / Stored

| Object | ใช้ที่ |
|---|---|
| `OAGWBG.OAGWBG_FN_GETBUDGETYEAR(:date)` | `GetBudgetYear()` — คืนปีงบฯ ตามวันที่ (**แกนกลางของ requirement ข้อ 2/3**) |
| `OAGWBG_FN_GETBUDGET_ALLOCATE_TRANSFER_CATEGORY(...)` | งบจัดสรร (ใช้ใน flow อื่นที่เกี่ยว) |

### 3.4 Temp / Interface objects (สำหรับ "ยืนยัน/ยกเลิก")

| Object | บทบาท |
|---|---|
| `APPS.OAG_GL_FUNDS_AVAILABLE_PKG_BYPASS` | **temp/bypass** คำนวณ funds available — pattern DELETE→INSERT→SELECT ต่อ `P_CODE_COMBINATION_ID` (ใน `GetBudgetOverlapYearCentralList`) |
| `OAGWBG_LOG_INTERFACE` | log การ interface ไป GL (`SaveInterface`) |
| `APPS.OAGGL_CALENDAR_V`, `APPS.GL_LEDGERS`, `APPS.OAGGL_ACCOUNT_HIERARCHIES_V`, `APPS.GL_CODE_COMBINATIONS_KFV` | lookup period/ledger/CCID |

> **หมายเหตุ:** การ "ยืนยัน/ยกเลิก" รายการ ปัจจุบัน **ไม่มี temp table แยก** — ใช้ field สถานะใน `OAGWBG_BUDGETRESERVEDITEM` แทน: `Statusid` 90102 (ขยาย), 90109 (ยกเลิก) → 90110 (ยกเลิก-ยืนยัน) + flag `Approve` (ดู `ConfirmBudgetReserved` / `UpdateBudgetOverlapStatus`)

### 3.5 รหัสสถานะ (Status) ที่พบ

| Statusid | ความหมาย (จากโค้ด) |
|---|---|
| 90101 | ร่าง/สร้างใหม่ |
| 90102 | มีรายการขยายเวลา (รอส่ง/แก้ได้) |
| 90109 / 90110 | ยกเลิก / ยกเลิก-ยืนยัน |
| 90201 | รอพิจารณา (locked) |
| 20202 | พิจารณาแล้ว |
| 20101 / 10197 / 10102 | สถานะ interface/ปิด (บางตัว locked) |

---

## 4. Flow ปัจจุบัน (As-Is)

### 4.1 โหลดหน้า detail
```
[User] เปิด BudgetOverlapYearCentralDetail?id=&pagetype=
  → MVC Controller.BudgetOverlapYearCentralDetail()  (OAGBudget/Controllers/BudgetController.cs:3017)
      • set SearchBudgetReversedItem { Budgetyear=GetBudgetYear(), Id, BudgetReversedType="O" }
      • _budgetService.GetBudgetOverlapYearCentralList(model)   → (proxy → API)
  → API Service.GetBudgetOverlapYearCentralList(model)  (BudgetService.cs:19435)
      1. โหลด header OagwbgBudgetreserved (by id)
      2. ดึง poRaw/prRaw จาก V_BUDGETOVERLAPYEAR_PO/PR  (WHERE BudgetSource='400' AND Caryfwd_no=Transferno)
      3. คำนวณ funds available ผ่าน OAG_GL_FUNDS_AVAILABLE_PKG_BYPASS (DELETE→INSERT→SELECT)
      4. โหลด savedItems = OAGWBG_BUDGETRESERVEDITEM (WHERE Budgetreversedid=id)
      5. ถ้า savedItems.Count==0 → ListExpand/Cancel มาจาก raw view ตรงๆ
         ถ้า >0 → merge: (FromSaved) + (Remaining จาก raw ที่ไม่ซ้ำ key Booknumber|Accountcode)
  → View render 4 tab ผ่าน partial (_tableExpand*/_tableCancle*) + isLocked
```

### 4.2 สถานะ "merge" ปัจจุบัน (สำคัญต่อ requirement 1)
- Key dedup = `Booknumber|Accountcode` (เก็บใน `CheckedExpand*Keys`)
- รายการที่ save แล้ว → ติ๊ก checkbox ไว้ (checked) และดึงค่า `Usageamount`/`Note` กลับมา
- **ข้อจำกัด:** key รวมรายการเดิมเป็น 1 แถวเสมอ → **ทำ "รอบที่ n ของรายการเดิม" ไม่ได้** (จะถูกมองเป็นรายการเดียว)
- โครงสร้างเป็น **flat list** ไม่มีแนวคิด round/level

### 4.3 บันทึก (save)
```
[btnSave] → JS รวบรวม 4 list → POST /Budget/SaveBudgetReservedCentrall
  → MVC → API.SaveBudgetReservedCentrall(BudgetReservedCentralFormModel)  (BudgetService.cs:21177)
      • upsert header (+GenerateTransferNoAsync ถ้าใหม่)
      • คำนวณ/refund OAGWBG_BUDGETRECEIVE, เขียน OAGWBG_BUDGETRESERVED_CATEGORY
      • SynchronizeReservedItemsAsync()  ← (BudgetService.cs:21470)
          - RemoveRange(existingItems ของ header)   ← ⚠️ ลบทิ้งทั้งหมด
          - re-insert จาก incoming list (dedup Booknumber|Accountcode|Type)
      • SynchronizeCentralBankAccountsAsync()
```

### 4.4 พิจารณา → ยืนยัน → interface (รอบ)
```
[btnConfirm pageType=2] → JS updateBudgetReservedItem() → POST /Budget/SubmitBudgetReservedModel
  → MVC proxy SubmitBudgetReservedtDetail → API /Budget/ConfirmBudgetReserved
  → API.ConfirmBudgetReserved(model)  (BudgetService.cs:19143)
      • Roundinterface == null → set 1 (คี่ = อนุญาต interface)
      • Roundinterface คู่ → ไม่ interface รอบนี้ แล้ว +1 (คู่→คี่)
      • Roundinterface คี่ → SaveBudgetReserved(id) → SaveInterface → GL,
                              สร้าง OAGWBG_BUDGETRECEIVE (รอบ 1) + RECEIVE_BATCH_NO,
                              แล้ว +1 (คี่→คู่ เพื่อบล็อกรอบถัดไป)
      • UpdateHeaderAndItemsStatusAsync: Statusid=20202, Budgetyear = Budgetyear+1
```
> ✅ จุดนี้ตรงกับตัวอย่าง requirement: "หลังอนุมัติเงินกัน ส่ง interface หน้าจอปี 69" (Budgetyear+1)
> ⚠️ การ enable/disable หน้าจอ **ผูกกับ Statusid อย่างเดียว** ไม่ผูกกับ "วันที่ตัดรอบ" → ยังไม่ตรง requirement ข้อ 3

**🔑 การ map `Roundinterface` (คู่/คี่) → lifecycle ก.ย./มี.ค. (ยืนยันจากโค้ด L19143-19413, L19156-19189):**

| ครั้งที่ confirm | Roundinterface (ก่อน→หลัง) | คู่/คี่ | ส่ง interface? | lifecycle | ช่วง |
|---|---|---|---|---|---|
| 1 | `null → 1 → 2` | คี่ | ✅ ส่ง | กันเงินครั้งแรก | ก.ย. |
| 2 | `2 → 3` | คู่ | ❌ ไม่ส่ง (+ set `Approve=1`) | ขยายเวลาครั้งที่ 1 | มี.ค. |
| 3 | `3 → 4` | คี่ | ✅ ส่ง | ขยายเวลาครั้งที่ 2 | ก.ย. |
| 4 | `4 → 5` | คู่ | ❌ ไม่ส่ง (+ set `Approve=1`) | ขยายเวลาครั้งที่ 3 | มี.ค. |

→ **ข้อสรุป:** ตรรกะ "สลับส่ง/ไม่ส่ง interface" ตาม requirement ข้อ 2.1 **มีอยู่แล้ว** ผ่าน toggle คู่/คี่
→ แต่มี **2 ช่องโหว่** ที่ต้องแก้ (ดู 5.2):
>  (a) ตัวนับ `Roundinterface` นับจาก **จำนวนครั้งที่ confirm** ไม่ได้ผูกกับ **ปฏิทินจริง (ก.ย./มี.ค.)** → ถ้า user confirm ผิดจังหวะ/ข้ามรอบ ความเป็นคู่/คี่จะ**เพี้ยน**จากความจริง
>  (b) `Budgetyear = Budgetyear + 1` ถูกเรียก **ทุกครั้งที่ confirm** (ทั้งรอบ ก.ย. และ มี.ค.) → ปีงบฯ เด้ง +1 ทุก 6 เดือน **ต้องยืนยันว่าตั้งใจ** หรือควร +1 เฉพาะรอบ ก.ย. (ดูคำถามข้อ 8)

### 4.5 Locking ปัจจุบันใน View (BudgetOverlapYearCentralDetail.cshtml:26-31)
```csharp
bool isLocked = Model.Statusid == 90201 || Model.Statusid == 20101 || Model.Statusid == 10197;
bool showActionTabs = Model.Statusid == 20202 || Model.Statusid == 90102 || Model.Roundinterface != null;
```
→ ไม่มีเงื่อนไข **วันที่/ช่วงเวลา** เลย

---

## 5. สิ่งที่ต้องเปลี่ยน (To-Be) แยกตาม Requirement × Layer

### 5.1 Requirement 1 — ขยายเวลา รอบที่ n + ประวัติ group level + เลขที่เงินกันเพิ่ม

#### (A) DB / DAL  — **R1, ต้องทำก่อน**
1. **เพิ่ม column ใหม่** ใน `OAGWBG_BUDGETRESERVEDITEM` เก็บ **เลขที่เงินกันเพิ่ม** (เช่น `RESERVENO_ADD` / `EXPAND_RESERVENO` — รูปแบบ `<เลขที่เงินกัน>.1`, `.2`, ... `.n`)
   - ✅ **ยืนยันจาก DB จริง (2026-06-23):** ทั้งตารางและวิว `OAGWBG_V_BUDGETRESERVEDITEM` **ยังไม่มี** column สำหรับเลขที่เงินกันเพิ่ม → ต้องเพิ่มใหม่จริง (ดูภาคผนวก ก)
   - ⚠️ `BOOKNUMBER` ปัจจุบันเป็น `VARCHAR2(20)` — ถ้าจะ append `.n` ลง booknumber ตรงๆ พื้นที่ตึง ควรเป็น column แยก
   - ตามด้วยอัปเดต model [OagwbgBudgetreserveditem.cs](OAGBudget.DAL/Models/OagwbgBudgetreserveditem.cs) + DbContext mapping (4727) + view model [OagwbgVBudgetreserveditem.cs](OAGBudget.DAL/Models/OagwbgVBudgetreserveditem.cs) + view `OAGWBG_V_BUDGETRESERVEDITEM` (16071)
2. ใช้ฟิลด์ที่ "มีอยู่แล้วแต่ยังไม่ถูกใช้บนหน้า central" ให้เป็นประโยชน์: `Overlapround` (เลขรอบ), `Overlapyear` (ปีของรอบ), `Parentid`/`Transferno` (ผูกประวัติ) — ปัจจุบัน save central **ไม่เซ็ตค่าพวกนี้**
   - **ต้องยืนยัน (ข้อ 8):** จะเก็บ "เลขที่เงินกันเพิ่ม" เป็น column ใหม่ หรือ derive จาก `Overlapround` + `Transferno`?

#### (B) API Save — `SynchronizeReservedItemsAsync` (BudgetService.cs:21470)
- **เปลี่ยนพฤติกรรมจาก replace → append-by-round**: ห้ามลบรายการของรอบก่อน
  - ปัจจุบัน `RemoveRange(existingItems)` ทั้งหมด → ต้องจำกัดให้ลบ/อัปเดตเฉพาะ **รอบปัจจุบัน** (เช่นรายการที่ยังไม่ถูก confirm/interface) และ insert รอบใหม่เป็น record ใหม่
- คำนวณ **เลขที่เงินกันเพิ่ม `.n`**: หา max suffix ของเลขที่เงินกันเดิม ในรายการเดียวกัน แล้ว +1 (logic คล้าย running ใน `OagwbgReceiveBatchNos` ที่ใช้ใน `ConfirmBudgetReserved`)
- เซ็ต `Overlapround` / `Overlapyear` ตามรอบ/ปีงบฯ ปัจจุบัน

#### (C) API Read — `GetBudgetOverlapYearCentralList` (BudgetService.cs:19435)
- เปลี่ยน merge ให้ **round-aware** และคืนเป็น **โครงสร้าง group level** แทน flat:
  - **PR (ไม่มีหนี้):** ดึง view PR ก่อนเสมอ (ยอดคงเหลือสด) + แนบประวัติรอบก่อนเป็น group (`ขยายเวลา-ปีงบประมาณ 25xx`, `กันเงินเหลื่อมปี`, ...)
  - **PO (มีหนี้):** ดึง saved (`BUDGETRESERVEDITEM`) ก่อน จัด level `เลขที่เงินกัน.1`, `.2`, ... แล้วต่อด้วย view PO เป็น level ใหม่
- เลิกใช้ dedup key `Booknumber|Accountcode` ที่รวมรอบ (หรือเพิ่มมิติ round เข้า key)

#### (D) Models / ViewModel
- [BudgetReservedCentralViewModel.cs](OAGBudget.Models/ViewModel/BudgetReservedCentralViewModel.cs): เพิ่มโครงสร้าง group (เช่น `List<ExpandGroup>` โดยแต่ละ group มี `GroupLabel`, `Round`, `Items`) — แทน/เสริม `ListExpand*`/`ListCancel*`
- [BudgetReservedCentralFormModel.cs](OAGBudget.Models/Data/BudgetReservedCentralFormModel.cs): เพิ่ม `Round`/เลขที่เงินกันเพิ่ม ต่อ item ที่ส่ง save

#### (E) Views / Partial
- [_tableExpandHasObligation.cshtml](OAGBudget/Views/Budget/_partialView/_tableExpandHasObligation.cshtml) & [_tableExpandNoObligation.cshtml](OAGBudget/Views/Budget/_partialView/_tableExpandNoObligation.cshtml): render **group header row** ต่อ level + คอลัมน์ "เลขที่เงินกันเพิ่ม"
- ปรับ JS เก็บ payload (`window.initializeExpand*Data`) ให้ส่ง round/level/เลขที่เงินกันเพิ่ม
- รอบเก่า (ประวัติ) แสดงแบบ read-only; เฉพาะ level/รอบปัจจุบันที่กรอกได้

### 5.2 Requirement 2 — ช่วงเวลากิจกรรม 6 เดือน

**สิ่งที่มีอยู่แล้ว (อย่าทำซ้ำ):** การ **สลับส่ง/ไม่ส่ง interface** (ก.ย.=ส่ง / มี.ค.=ไม่ส่ง) ทำงานอยู่แล้วผ่าน `Roundinterface` คู่/คี่ ใน `ConfirmBudgetReserved` (ดูตาราง 4.4) → **ไม่ต้องเขียนใหม่** เพียงทำให้ "เชื่อถือได้" ขึ้น

**Gap ที่ต้องปิด:**
1. **ผูกรอบกับปฏิทินจริง** — ต้องมีตรรกะกลางตัดสิน "ขณะนี้อยู่ช่วงกันเงิน (เม.ย.–ก.ย.) / ขยายเวลา (ต.ค.–มี.ค.) / นอกช่วง" + คืน **ปีงบฯ + พาริตี้รอบ (ก.ย.↔คี่, มี.ค.↔คู่)** เพื่อกัน `Roundinterface` เพี้ยนจากความจริง
2. **เลือกที่เก็บตรรกะ:**
   - (i) Oracle FN ใหม่ เช่น `OAGWBG_FN_GET_RESERVE_PERIOD(:date)` คู่กับ `OAGWBG_FN_GETBUDGETYEAR` — แนะนำ (single source, ใช้ร่วมหน้า central + หน่วยงาน)
   - (ii) C# helper ใน `OAGBudget.Global`/`Utilities` — เร็วกว่าแต่ต้อง sync ปฏิทินเอง
3. **ทบทวน `Budgetyear+1` ต่อ confirm** — ปัจจุบันเด้ง +1 ทุก confirm (ทุก 6 เดือน) อาจต้อง +1 เฉพาะรอบ ก.ย. (ดูคำถามข้อ 8.8)

- **ยืนยันไม่มีของเดิม:** grep พบเฉพาะ `OAGWBG_FN_GETBUDGETYEAR` และ `..._RECEIVE_PERIOD_CATEGORY` (คนละเรื่อง) → **ยังไม่มี** helper ช่วงกันเงิน/ขยายเวลา ต้องสร้างใหม่

### 5.3 Requirement 3 — disable หน้าจอตามจังหวะอนุมัติ vs ตัดรอบ
- แก้ logic `isLocked` ใน [BudgetOverlapYearCentralDetail.cshtml](OAGBudget/Views/Budget/BudgetOverlapYearCentralDetail.cshtml#L26) ให้รวมเงื่อนไข **วันที่ปัจจุบันเทียบช่วง/รอบ** (จากข้อ 5.2):
  - อนุมัติแล้ว (20202/90201) **และยังไม่ถึงรอบถัดไป** → `isLocked=true`
  - อนุมัติแล้ว **และข้ามไปรอบถัดไปแล้ว** → `isLocked=false` (เปิดใช้งาน)
- ควรส่งค่า "รอบ/ช่วงปัจจุบัน" จาก Controller → ViewModel เพื่อไม่คำนวณวันที่ใน View ตรงๆ (ฝั่ง server เป็น source of truth)
- บังคับซ้ำที่ **API** (`SaveBudgetReservedCentrall` / `ConfirmBudgetReserved`) กันการ bypass จาก client
- ใช้ logic เดียวกันกับหน้า **กันเหลื่อมหน่วยงาน** (`BudgetOverlapYearPR.cshtml` / `BudgetOverlapYearPO.cshtml` + `GetBudgetOverlap`) → ควร**สกัดเป็น helper ใช้ร่วม**

---

## 6. สรุปตาราง "ต้องเปลี่ยนอะไรในแต่ละ Layer"

| Layer | ไฟล์หลัก | Req 1 (รอบ n) | Req 2 (ช่วงเวลา) | Req 3 (disable) |
|---|---|---|---|---|
| **DB** | `OAGWBG_BUDGETRESERVEDITEM`, `OAGWBG_V_BUDGETRESERVEDITEM`, (FN ใหม่?) | เพิ่ม column เลขที่เงินกันเพิ่ม + ใช้ Overlapround/year | FN ช่วงเวลา (ทางเลือก i) | — |
| **DAL** | OagwbgBudgetreserveditem.cs, OagwbgVBudgetreserveditem.cs, OAGDBContextBase.cs | map column ใหม่ | map FN ใหม่ | — |
| **API Service** | BudgetService.cs (19435 / 21470 / 19143) | read round-aware + save append + running `.n` | helper/FN ช่วงเวลา + รอบ | บังคับ lock ฝั่ง server |
| **API Controller** | BudgetController.cs | pass-through | — | — |
| **Models** | BudgetReservedCentralViewModel / FormModel | group level + round | period flags | period flags |
| **MVC Controller** | BudgetController.cs (3017) | ส่ง group + round ให้ view | คำนวณช่วง→ViewModel | ส่ง flag lock |
| **MVC Proxy Svc** | Services/Repository/BudgetService.cs | DTO ใหม่ | — | — |
| **View/Partial** | BudgetOverlapYearCentralDetail + _tableExpand* | render group level + คอลัมน์เลขที่เงินกันเพิ่ม | — | isLocked ตามช่วง/รอบ |

---

## 7. ความเสี่ยง / Blast Radius / Reversibility (ตาม AI Behavior Rules)

- **R0 (irreversible):** การ **ALTER TABLE `OAGWBG_BUDGETRESERVEDITEM`** บน PREPROD/PROD และการ interface ขึ้น GL จริง → ต้อง backup + review DBA ก่อน (ทำใน _brain/SQL script แยก ห้ามรันมั่ว)
- **R1 (costly):** เปลี่ยน save จาก replace→append → ถ้าพลาด **ข้อมูลรอบเก่าหาย** หรือ **เกิด record ซ้ำ**; เปลี่ยน read merge → กระทบการแสดงผล/ยอดคงเหลือทั้งหน้า
- **Shared logic:** ข้อ 2/3 ใช้ทั้งหน้า central และหน้าหน่วยงาน → แก้ที่เดียวกระทบหลายหน้า ต้อง regression ทั้งคู่
- **VPN/DB:** การ validate ข้อมูล/โครงสร้างจริง **ต้องต่อ F5 BIG-IP Edge Client** ก่อน (ตาม CLAUDE.md) — เอกสารนี้อ้างอิงจาก **โค้ด** ยังไม่ได้ query DB จริง
- **Reversibility path:** ทำ schema change ผ่าน script ที่มี rollback; โค้ด C#/View อยู่ใน TFS (revert ได้); แนะนำเปิด feature flag (`isConnection` มีอยู่แล้วเป็นตัวอย่าง pattern) เพื่อปิด/เปิดพฤติกรรมรอบ n

---

## 8. คำถามที่ต้องการคำยืนยันก่อนลงมือ (Open Questions)

1. **เลขที่เงินกันเพิ่ม `.n`** — เก็บเป็น **column ใหม่** (string `<เลขที่เงินกัน>.1`) หรือ derive จาก `Overlapround`? ชื่อ column ที่ต้องการ? และ `.n` ต่อท้าย **เลขที่เงินกัน (Transferno)** หรือ **เลขที่เอกสาร PO (Booknumber)**?
2. **Group level labels** — ลำดับ/รูปแบบที่แน่นอน (เช่น `ขยายเวลา-ปีงบประมาณ 2569` > `กันเงินเหลื่อมปี` > `ปีงบประมาณ 2570`) เป็น hierarchy กี่ชั้น และมาจาก field ไหน (Overlapyear? Budgetyear? Round?)
3. **นิยาม "รอบ"** — ยืนยันการ map: `Roundinterface` คี่ = รอบ ก.ย. (ส่ง interface), คู่ = รอบ มี.ค. (ไม่ส่ง) ใช่หรือไม่? และจะ **ผูกพาริตี้กับเดือนจริง** (กัน confirm ผิดจังหวะแล้วเพี้ยน) หรือคงนับจากจำนวน confirm ตามเดิม? "รอบขยายเวลาครั้งที่ n" (req 1) ใช้ตัวนับเดียวกับ `Roundinterface` หรือแยกตัวนับ?
4. **ช่วงเวลา (ข้อ 2)** — ยืนยันขอบเขตวันแบบ inclusive ตาม prompt; กรณีทำ **นอกช่วง** (เช่น ก.พ. ซึ่งอยู่ช่วงขยายเวลา แต่ user มากันเงิน) ระบบควร block หรือเตือน?
5. **ที่เก็บตรรกะช่วงเวลา** — ต้องการ **Oracle FN ใหม่** (แนะนำ, single source) หรือ **C# helper**?
6. **PR (ไม่มีหนี้) ในรอบ n** — prompt บอก "ดึง view PR ก่อนเสมอ" → ต่างจาก PO ที่ "ดึง saved ก่อน" ใช่หรือไม่? และ PR ต้องมี "เลขที่เงินกันเพิ่ม `.n`" เหมือน PO ไหม (prompt ระบุ `.1` เฉพาะฝั่ง PO)
7. **ขอบเขตงานรอบนี้** — แก้เฉพาะหน้า central ก่อน แล้วค่อยขยายไปหน้าหน่วยงาน หรือทำพร้อมกัน?
8. **`Budgetyear + 1` ต่อ confirm** — ปัจจุบันปีงบฯ เด้ง +1 **ทุกครั้งที่ confirm** (ทั้งรอบ ก.ย. และ มี.ค. = +2 ต่อปีปฏิทิน) → เป็นพฤติกรรมที่ตั้งใจ หรือควร +1 เฉพาะรอบ ก.ย. (interface)? กระทบยอด/หน้าจอปีถัดไปโดยตรง
9. **เงื่อนไขจบ "จนกว่ายอดจะถูกใช้จนหมด"** — ใช้อะไรเป็นตัวชี้วัดว่ายอดหมด (เช่น `Totalbalanceamount` ของรายการ/header = 0) แล้วระบบควรปิดรอบขยายเวลาอัตโนมัติ หรือให้ user หยุดเอง?

---

## 8.A คำตอบ/ข้อเสนอแนะ (Proposed Answers — ร่างโดย Opus, อิงโค้ด + DB จริง)

> **สัญลักษณ์:** ✅ = ตัดสินใจเชิงเทคนิคได้เลย (ผมแนะนำ) · ⚠️ = เป็น business decision **ต้องให้ BA/ผู้ใช้ยืนยัน**
> หลักฐานอ้างอิง: ภาคผนวก ก + query รอบ 2 (item EXPAND_* ทั้งหมด `TRANSFERNO/OVERLAPYEAR/OVERLAPROUND/PARENTID = ว่าง`; doc ROUNDIF=3 มีแค่ 3 items ไม่มีตัวแยกรอบ; `OVERLAPROUND=2` ถูกใช้จริง 10 แถวฝั่งหน่วยงาน)

### Q1 — เลขที่เงินกันเพิ่ม `.n` เก็บยังไง ⚠️(รูปแบบ) / ✅(วิธี)
- 💡 **เพิ่ม column ใหม่** (อย่า append ลง `BOOKNUMBER` เพราะเป็น VARCHAR2(20) + เป็นเลข PO/PR ไม่ใช่เลขเงินกัน)
- ชื่อแนะนำ: `EXPAND_RESERVENO VARCHAR2(30)` เก็บค่าเต็ม เช่น `68030009.1`
- `.n` ต่อท้าย **เลขที่เงินกัน = `header.Transferno`** (ฟอร์แมตจริง 8 หลัก เช่น `68030009`) **ไม่ใช่** Booknumber
- เก็บคู่กับ `OVERLAPROUND` (int = n) เพื่อ group/query ง่าย
- ⚠️ ขอ BA ยืนยัน "ชื่อ column + รูปแบบ string" สุดท้าย (เป็น business identifier ที่อาจโชว์/พิมพ์)

### Q2 — Group level labels กี่ชั้น/มาจากไหน ⚠️
- 💡 เสนอ **2 ชั้น**: ชั้นบน = หัวข้อรอบ, ชั้นล่าง = รายการ
  - **PR (ไม่มีหนี้):** label จาก `OVERLAPYEAR`+`OVERLAPROUND` เช่น `ขยายเวลา ครั้งที่ 1 - ปีงบประมาณ 2569`
  - **PO (มีหนี้):** label = `เลขที่เงินกัน.n` จาก column Q1 เช่น `68030009.1`
- ประวัติ = group by `OVERLAPROUND` จาก saved items (read-only); รอบปัจจุบัน = จาก view
- ⚠️ ขอ BA ยืนยัน **ข้อความ label + จำนวนชั้น** (แนะนำทำ mockup 1 หน้าให้ดูก่อน)

### Q3 — นิยาม "รอบ" + ผูกเดือนจริง ⚠️
- 💡 ยืนยัน map (มีหลักฐาน): `Roundinterface` คี่=ก.ย.(ส่ง interface) / คู่=มี.ค.(ไม่ส่ง)
- 💡 **แยกตัวแปร 2 ความหมาย** ลดความสับสน:
  - `Roundinterface` → คุม interface (คงเดิม)
  - `OVERLAPROUND` → เลขรอบขยายเวลา n (1,2,3…) สำหรับ history/level (มี precedent ใช้แล้ว)
- 💡 **ผูกพาริตี้กับเดือนจริง** ผ่าน FN ใหม่ (Q5) กัน `Roundinterface` เพี้ยนถ้า confirm ผิดจังหวะ
- ⚠️ ขอ BA ยืนยันว่า "ขยายเวลาครั้งที่ n" = `OVERLAPROUND` ใช่ไหม

### Q4 — ช่วงเวลา inclusive? นอกช่วง block/เตือน? ⚠️
- 💡 ขอบเขต inclusive ตาม prompt และ **ครอบคลุมทุกวัน** (เม.ย.–ก.ย. / ต.ค.–มี.ค. ต่อเนื่องไม่มีช่องว่าง) → ไม่มี "นอกช่วง" จริง
- 💡 ประเด็นจริง = "ทำผิดประเภทในช่วง" เช่นอยู่ช่วงขยายเวลาแต่จะกันเงินใหม่ → แนะนำ **block (disable ปุ่ม)** ตามช่วง
- ⚠️ ขอ BA ยืนยัน: block แข็ง หรือเตือนแบบ soft (ยอมให้ทำได้แต่เตือน)

### Q5 — ที่เก็บตรรกะช่วงเวลา ✅
- 💡 **Oracle FN ใหม่** เช่น `OAGWBG_FN_GET_RESERVE_PERIOD(:date)` → คืน (period_type `RESERVE`/`EXPAND`, budget_year, parity)
- เหตุผล: เข้าชุดกับ `OAGWBG_FN_GETBUDGETYEAR` เดิม, single source ใช้ร่วม central+หน่วยงาน, ปฏิทินงบฯ อยู่ใน DB แล้ว (`OAGGL_CALENDAR_V`)
- เสริม C# wrapper บางๆ ให้ View — เป็น technical decision (R1) แนะนำได้เลย

### Q6 — PR รอบ n ดึง view ก่อน (ต่างจาก PO)? PR มี `.n` ไหม? ⚠️
- 💡 ตาม prompt: PR ดึง view ก่อนเสมอ (refresh ยอด), PO ดึง saved ก่อน → ทำต่างได้ แต่ **ผลลัพธ์สุดท้ายเหมือนกัน** (ประวัติ read-only + รอบปัจจุบันจาก view) ต่างแค่ลำดับ merge
- 💡 prompt ระบุ `.1` เฉพาะ PO → เสนอ PR ใช้ `OVERLAPROUND` พอ **ไม่ต้องมี `EXPAND_RESERVENO`**
- ⚠️ ขอ BA ยืนยัน (อาจอยากให้ PR/PO consistent มี `.n` เหมือนกัน)

### Q7 — ขอบเขตงานรอบนี้ ⚠️
- 💡 **ทำ central ก่อน** (เป็น scope ของ 308) แล้วค่อย extract period-FN + disable-helper ไปหน่วยงาน — ลด blast radius, ทดสอบทีละหน้า
- 💡 แต่ออกแบบ FN/helper ให้ generic ตั้งแต่แรกเพื่อ reuse
- ⚠️ ขอผู้ใช้ยืนยัน priority

### Q8 — `Budgetyear+1` ต่อ confirm ตั้งใจไหม? ⚠️ (สำคัญ/เสี่ยง)
- 📊 ข้อมูลจริง: ที่ `ROUNDIF=2` มี YEAR 2568/2569/2570 ปนกัน → **ไม่สม่ำเสมอ ดูน่าสงสัย**
- 💡 เสนอ: ปีงบฯ ควรขยับ **เฉพาะรอบ ก.ย. (interface)** ไม่ใช่ทุก confirm
- ⚠️ **ต้องยืนยันกับ dev เดิม/BA ก่อนแตะ** ว่าเป็น bug หรือ intended — R1 เสี่ยง regression flow ที่ใช้งานอยู่

### Q9 — เงื่อนไขจบ "ยอดหมด" ⚠️
- 💡 ใช้ **ยอดคงเหลือรวม = 0** (`header.Totalbalanceamount` หรือผลรวม balance ของ items) เป็นตัวชี้วัด
- 💡 เมื่อยอด=0 → **ไม่เปิดรอบขยายเวลาใหม่ (auto-close)** แต่เก็บประวัติไว้; ถ้ายัง>0 → เปิดรอบถัดไปได้
- ⚠️ ขอ BA ยืนยันนิยาม "ยอดหมด" (รวม PO+PR? เฉพาะ balance? เกณฑ์ปัดเศษ?)

**สรุป:** เทคนิคที่ผมเดินหน้าได้เลย = **Q5** (และวิธีของ Q1, Q3, Q6, Q7) · ที่ต้องรอ BA/ผู้ใช้ยืนยันก่อนเขียน = **Q1(รูปแบบ), Q2, Q4, Q8, Q9**

---

## 8.B มติที่ได้รับจากผู้ใช้/BA (2026-06-23) ✅

> มติยืนยันแล้ว 6 ข้อ — ใช้เป็น spec สำหรับออกแบบ Phase ต่อไป

### มติ 1 (Q1) — เลขที่เงินกัน ฝั่ง "มีหนี้ (PO)" + **เก็บแยก 2 ส่วน**
- ✅ format = `<เลขที่เงินกัน>.รอบ` (เช่น `68030009.1`, `.2`)
- ✅ **เก็บข้อมูลแยกกัน** ระหว่าง **เลขที่เงินกันต้นฉบับ** กับ **เลขที่เงินกันที่แตกย่อย**
- 🔧 **Design:**
  - `OAGWBG_BUDGETRESERVEDITEM.TRANSFERNO` (มีอยู่ ปัจจุบันว่าง) = **เลขต้นฉบับ** `68030009`
  - `OAGWBG_BUDGETRESERVEDITEM.EXPAND_RESERVENO` (**column ใหม่**) = **เลขแตกย่อย** `68030009.1`
  - `OVERLAPROUND` (มีอยู่) = เลขรอบ (int) = 1, 2, 3 …

### มติ 2 (Q2) — "ไม่มีหนี้ (PR)" ไม่แตกย่อยเลข
- ✅ PR **ไม่มี `.รอบ`** — ใช้เลขที่เงินกันเดิม (ไม่แตกย่อย)
- 🔧 **Design:** PR items ไม่ต้องเซ็ต `EXPAND_RESERVENO` (เว้นว่าง) ใช้ `TRANSFERNO` ต้นฉบับ; แยกรอบด้วย `OVERLAPROUND`/`OVERLAPYEAR` เท่านั้น

### มติ 3 (Q3) — หัวกลุ่ม (group level) **2 tab แสดงต่างกัน**
- ✅ **ไม่มีหนี้ (PR):** `<ประเภทกิจกรรม> - ปีงบประมาณ {ปี}` เช่น `ขยายเวลา - ปีงบประมาณ 2569` หรือ `กันเหลื่อม - ปีงบประมาณ 2569`
- ✅ **มีหนี้ (PO):** `<เลขที่เงินกัน>.รอบ` เช่น `68030009.1`
- 🔧 **Design:** PR ต้องมี field บอก **ประเภทกิจกรรม** (กันเหลื่อม/ขยายเวลา) + ปี (`OVERLAPYEAR`/`Budgetyear`) เพื่อประกอบ label; PO ใช้ `EXPAND_RESERVENO`. โครงสร้าง 2 ชั้น (หัวกลุ่ม + รายการ) ดู [mockup](mockup_group_level_308.html)

### มติ 4 (Q4) — disable: ห้ามย้อนกลับ tab กันเงิน + Header
- ✅ ห้ามทำกิจกรรมผิดช่วง
- ✅ **เมื่อผ่านการกันเงินครั้งแรกแล้ว → ห้ามกลับไปทำที่ tab "กันเงิน" อีก + lock ส่วน Header ด้วย**
- 🔧 **Design:** เมื่อ `Roundinterface != null` (กันเงินครั้งแรกผ่าน/ส่ง interface แล้ว) → disable tab กันเงิน + header fields (ปัจจุบัน header ปลดล็อกตาม `IsNew`/status เท่านั้น ต้องเพิ่มเงื่อนไขนี้)

### มติ 5 (Q8) — Budgetyear +1 เฉพาะรอบ ก.ย. + interface ใช้ปีของรายการ
- ✅ ปีงบฯ (header) **+1 เฉพาะรอบ ก.ย. (ที่ส่ง interface)** ไม่ใช่ทุก confirm
- ✅ **สำคัญ:** ชุดบัญชี (account/budget code) ที่ส่ง interface **ยังใช้ปีงบประมาณที่มากับตัวรายการ** ไม่ใช่ปี header ที่ +1 แล้ว
- 🔧 **Design:** แก้ `ConfirmBudgetReserved` → `Budgetyear+1` เฉพาะรอบคี่ (ก.ย./interface); ตอนประกอบ account segment ของ interface ให้ใช้ปีจาก **รายการ** (เช่น `item.Budgetyear`/`OVERLAPYEAR`) — ต้องตรวจให้แน่ใจว่าโค้ด interface ไม่ได้อ้างปี header ที่ถูก +1
- ⚠️ R1 เสี่ยง regression — ทดสอบ interface บน PREPROD ทั้งรอบ ก.ย. และ มี.ค.

### มติ 6 (Q9) — "ยอดหมด" = view หารายการตรงเงื่อนไขไม่เจอ
- ✅ เกณฑ์ "ยอดถูกใช้หมด" = **เช็คกับ view ที่ดึงรายการ** — ถ้า **เลขที่เงินกันนี้หา (PR/PO view) รายการที่ตรงเงื่อนไขไม่เจอแล้ว = ยอดหมด**
- ✅ **verify DB แล้ว (2026-06-23, VPN กลับมา):** view มี indicator จริง + ยืนยัน `CARRYFWD_NO` = `header.Transferno` (เห็นค่า `68030009`, `68030001`, `68030011`)
- 🔧 **Design แยก 2 ฝั่ง (ตามพฤติกรรม view จริง):**
  - **PR (`OAGWBG_V_BUDGETOVERLAPYEAR_PR`):** `REMAINING_AMOUNT > 0` ทั้งหมด (194/194 แถว) → **view กรองรายการที่หมดออกเองแล้ว** → ใช้ "query ไม่เจอ row = หมด" ได้ตรงๆ
  - **PO (`OAGWBG_V_BUDGETOVERLAPYEAR_PO`):** view **ยังรวม** รายการ `CLOSED_CODE='CLOSED'` (21/215) และ `REMAINING_AMOUNT < 0` (12/215) → "ไม่เจอ row" อย่างเดียว **ไม่พอ** ต้องเพิ่มเกณฑ์ตัดออก เช่น `CLOSED_CODE='CLOSED'` **หรือ** `REMAINING_AMOUNT <= 0` ถือว่ารายการนั้นหมด/ปิด
  - คอลัมน์จริง: `REMAINING_AMOUNT`, `REMAINING_QUANTITY`, `CLOSED_CODE`, `QUANTITY_RECEIVED`, `RECEIPT_NUM` (PO) · `REMAINING_AMOUNT` (PR) — *หมายเหตุ: ชื่อ DB ใช้ `_` เช่น `CARRYFWD_NO`/`REMAINING_AMOUNT` ต่างจาก property ใน C# model (`Caryfwd_no`/`RemainingAmount`)*

---

## 9. ลำดับงานที่แนะนำ (Phased Plan — ยังไม่เริ่มจนกว่าจะยืนยันข้อ 8)

1. **Phase 0 — ยืนยัน requirement** (ข้อ 8) + ออกแบบ schema/ViewModel บนกระดาษ
2. **Phase 1 — DB/DAL**: SQL script เพิ่ม column + ปรับ view `OAGWBG_V_BUDGETRESERVEDITEM` + update DAL models/DbContext (build ผ่าน)
3. **Phase 2 — ตรรกะช่วงเวลา/รอบ** (ข้อ 2): FN/helper + unit ทดสอบขอบวัน (1 เม.ย./30 ก.ย./1 ต.ค./31 มี.ค.)
4. **Phase 3 — API read round-aware + group level** (`GetBudgetOverlapYearCentralList`)
5. **Phase 4 — API save append-by-round + running `.n`** (`SynchronizeReservedItemsAsync`/`SaveBudgetReservedCentrall`)
6. **Phase 5 — ViewModel + Views/Partial** render group level + คอลัมน์เลขที่เงินกันเพิ่ม
7. **Phase 6 — disable logic** (ข้อ 3) ทั้ง View + API guard
8. **Phase 7 — regression** หน้า central + หน่วยงาน (ต่อ VPN, ทดสอบ interface บน PREPROD)

> ทุกครั้งที่แก้ `.cs` ต้อง `dotnet build "D:\TFS\OAG Budget\OAGBudget.sln"` ให้ผ่านก่อน checkin (ตาม CLAUDE.md ข้อ 6)

---

## 10. ภาคผนวก ก — ผลตรวจสอบฐานข้อมูลจริง (PREPROD, 2026-06-23, ผ่าน VPN F5)

> query แบบ read-only ผ่าน scratch project `QueryDB/` (ในโฟลเดอร์งานนี้) — `OAGWBG_FN_GETBUDGETYEAR(SYSDATE) = 2569`

### ก.1 โครงสร้าง `OAGWBG_BUDGETRESERVEDITEM` (table)
มี column: `ID, CREATEBY/ON, UPDATEBY/ON, BUDGETYEAR, BUDGETREVERSEDID, TOTALHASPOAMOUNT, TOTALHASPRAMOUNT, TOTALBALANCEAMOUNT, BOOKNUMBER(VARCHAR2 20), DESCRIPTION, SUPPLIER, COSTCENTERCODE, HEADERID, CATEGORYCODE, ACCOUNTCODE, STATUSID, REASON, BUDGETBANKACCOUNTID, BUDGETRESERVEDTYPE(255), ACTIVITYID, PRODUCTID, BUDGETPLANID, PARENTID, TRANSFERNO, PO_CONTRACT*, OVERLAPYEAR, OVERLAPROUND, APPROVE, LINEID, REMAININGREFUND, NOTE, USAGEAMOUNT`

- ✅ **ยังไม่มี** column เลขที่เงินกันเพิ่ม → ต้องเพิ่มใหม่
- ✅ `OVERLAPYEAR`, `OVERLAPROUND`, `PARENTID`, `TRANSFERNO` **มีจริง** (ใช้ทำ round/level/ประวัติได้)
- ⚠️ `BOOKNUMBER` = `VARCHAR2(20)` (พื้นที่จำกัด)

### ก.2 โครงสร้าง view `OAGWBG_V_BUDGETRESERVEDITEM`
เพิ่มจาก table: `STATUSNAME, BANKACCOUNTGIVER/RECEIVER, COSTCENTERID, DEPARTMENTID, PR_TRANSFER_NO, PO_TRANSFER_NO, ` **`CONTRACT_CARRY_FORWARD_PO`**

- 🔎 **พบช่องว่าง model:** view มี `CONTRACT_CARRY_FORWARD_PO` แต่ C# model [OagwbgVBudgetreserveditem.cs](OAGBudget.DAL/Models/OagwbgVBudgetreserveditem.cs) **ยังไม่ map** field นี้ (ไม่ blocker แต่ควร map ถ้าจะใช้)

### ก.3 ข้อมูลจริง `OAGWBG_BUDGETRESERVED` REGION='C' — ตรวจ Roundinterface

| ID | TRANSFERNO | YEAR | STATUS | ROUNDIF |
|---|---|---|---|---|
| 65 | 68030015 | 2570 | 20202 | 2 |
| 58 | 68030009 | 2569 | 90102 | 2 |
| 57 | 68030008 | 2568 | 20202 | 2 |
| 56 | 68030007 | 2568 | 90201 | 1 |
| 54 | 68030006 | 2569 | 20202 | 2 |

การกระจาย `ROUNDINTERFACE` (REGION=C): `1→1, 2→18, 3→1, null→7` · (REGION=P): `1→2, 2→13, 3→3, null→20`

- ✅ **ยืนยันทฤษฎี:** มีเอกสารที่ `ROUNDINTERFACE=3` จริง → วงจร **ขยายเวลารอบที่ 2 (วนกลับ ก.ย.)** เกิดขึ้นจริงในข้อมูล
- ✅ doc ที่ STATUS=90201 (รอพิจารณา) อยู่ที่ ROUNDIF=1 (คี่, ก่อน interface) สอดคล้องกับ flow
- ⚠️ **พบความไม่นิ่งของ `BUDGETYEAR`:** ที่ `ROUNDIF=2` เท่ากัน แต่ YEAR เป็นได้ทั้ง 2568/2569/2570 → ตอกย้ำ **คำถามข้อ 8** ว่า `Budgetyear+1` ต่อ confirm ตั้งใจหรือไม่ (พฤติกรรมไม่สม่ำเสมอในข้อมูลจริง)

### ก.4 ชนิดรายการใน `OAGWBG_BUDGETRESERVEDITEM`
`O→12, R→33, EXPAND_PO→2, EXPAND_PR→3, CANCEL_PR→1` (ยังไม่มี CANCEL_PO ในข้อมูลทดสอบ)
- ของเก่า (`O`/`R` = หน่วยงาน) และของใหม่ (`EXPAND_*`/`CANCEL_*` = central) **อยู่ปนในตารางเดียวกัน** → ต้องระวัง filter ตอนแก้ logic

> 🧹 **หมายเหตุ cleanup:** `QueryDB/` เป็น scratch tool (อยู่ใน _brain/Git ไม่ใช่ TFS) — ลบได้เมื่อไม่ใช้ หรือเก็บไว้ debug รอบหน้า

---

## 11. ภาคผนวก ข — เอกสารสรุป Q&A

**เรื่อง:** พัฒนาเพิ่มหน้า **"โอนงปม. เข้าบัญชีเงินกัน"** (กันเหลื่อมส่วนกลาง) — รองรับ **ขยายเวลาหลายรอบ** + กติกา **ช่วงเวลา/ปิดหน้าจอ**
**วันที่:** 2026-06-23 · **ผู้จัดทำ:** ทีมพัฒนา · **ต้องการ:** มติ BA ใน 6 ข้อด้านล่าง

**บริบทย่อ:** ระบบปัจจุบันทำได้แค่ "กันเงิน → ขยายเวลา 1 รอบ" งานนี้จะขยายให้ **ขยายเวลาได้หลายรอบ** (ทุก ~6 เดือน สลับ ก.ย./มี.ค.) และ **เก็บประวัติแต่ละรอบ** ไว้ดูได้

**ส่วนที่ทีมพัฒนาตัดสินเชิงเทคนิคแล้ว:** วิธีจัดเก็บข้อมูลรอบในฐานข้อมูล · ตำแหน่งตรรกะช่วงเวลา (สร้างเป็น Oracle function ใช้ร่วมกัน) · ลำดับงาน (ทำส่วนกลางก่อน แล้วหน่วยงานทีหลัง)

| # | ประเด็นที่ต้องตัดสิน | ทำไมสำคัญ | ทีมพัฒนาแนะนำ | ✍️ มติ BA |
|---|---|---|---|---|
| 1 | **รูปแบบ "เลขที่เงินกันเพิ่ม"** ของรายการขยายเวลา ฝั่ง **มีหนี้ (PO)** | เป็นเลขอ้างอิงที่ผู้ใช้เห็น/พิมพ์ออกรายงาน | `<เลขที่เงินกัน>.รอบ` เช่น `68030009.1`, `.2`, `.3` | ✅ ตามนี้ + **เก็บแยก** ต้นฉบับ/แตกย่อย (`TRANSFERNO` + `EXPAND_RESERVENO`) |
| 2 | ฝั่ง **ไม่มีหนี้ (PR)** ต้องมีเลข `.รอบ` ด้วยไหม หรือใช้แค่ "ครั้งที่ n" | ความสอดคล้องสองฝั่ง | ไม่ต้องมี `.รอบ` (PR ใช้ "ครั้งที่ n" พอ) | ✅ ไม่มี `.รอบ` — PR ใช้เลขที่เงินกันเดิม (ไม่แตกย่อย) |
| 3 | **หัวข้อกลุ่ม (group)** ที่โชว์ประวัติแต่ละรอบบนหน้าจอ ใช้ข้อความ/กี่ชั้น | กระทบหน้าจอที่ผู้ใช้เห็น | 2 ชั้น เช่น `ขยายเวลา ครั้งที่ 1 - ปีงบประมาณ 2569` *(จะทำตัวอย่างหน้าจอให้ดู)* | ✅ 2 ชั้น แต่ **2 tab ต่างกัน**: PR=`<ประเภท> - ปีงบประมาณ {ปี}` / PO=`<เลขที่เงินกัน>.รอบ` |
| 4 | **ทำกิจกรรมผิดช่วง** (เช่น อยู่ช่วงขยายเวลา แต่จะกดกันเงินใหม่) ควร **ห้าม (ปิดปุ่ม)** หรือ **เตือนแต่ยังทำได้** | กันความผิดพลาดของผู้ใช้ | ห้าม = ปิดปุ่มตามช่วง | ✅ ห้าม + หลังกันเงินครั้งแรก **lock tab กันเงิน & Header** ห้ามย้อนกลับ |
| 5 | 🔴 **ปีงบประมาณเด้ง +1 ทุกครั้งที่กดยืนยัน** (ทั้งรอบ ก.ย.และ มี.ค.) — ของเดิมเป็นแบบนี้ ตั้งใจหรือเป็นบั๊ก? *(ข้อมูลจริงพบปีไม่สม่ำเสมอ)* | กระทบยอด/ปีบนหน้าจอโดยตรง | ควร +1 **เฉพาะรอบ ก.ย.** (ที่ส่ง interface) — ขอตรวจกับผู้พัฒนาเดิม | ✅ +1 เฉพาะรอบ ก.ย. · แต่ **ชุดบัญชีที่ส่ง interface ใช้ปีของรายการ** (ไม่ใช่ปี header) |
| 6 | **นิยาม "ยอดถูกใช้จนหมด"** ที่จะปิดไม่ให้ขยายเวลาต่อ | กำหนดจุดจบของวงจร | ยอดคงเหลือรวม = 0 → ปิดรอบอัตโนมัติ (ยังเก็บประวัติ) | ✅ verify แล้ว — PR: view กรองให้ (ไม่เจอ row = หมด) · PO: เพิ่มเกณฑ์ `CLOSED_CODE='CLOSED'`/`REMAINING_AMOUNT<=0` |

> **จุดเสี่ยงสุด = ข้อ 5** เพราะเป็นพฤติกรรมที่ระบบใช้งานจริงอยู่ ถ้าแก้ผิดกระทบของเดิม → **ต้องยืนยันร่วมกับผู้พัฒนาเดิมก่อนแก้**
> รายละเอียดเทคนิคเต็ม: ดู section 5–8.A ของเอกสารนี้

---

## 12. ภาคผนวก ค — Mockup หน้าจอ Group Level (ไฟล์แยก)

ตัวอย่างหน้าจอ (static HTML, เปิดในเบราว์เซอร์) ประกอบการตัดสิน **Q2 / ข้อ 3 (group level)**:

➡️ **[mockup_group_level_308.html](mockup_group_level_308.html)** (self-contained ไม่พึ่ง CDN)

แสดง 2 tab พร้อมหัวกลุ่ม "ประวัติ + รอบปัจจุบัน":
- **PR (ไม่มีหนี้):** หัวกลุ่ม = `<ประเภทกิจกรรม> - ปีงบประมาณ {ปี}` เช่น `กันเหลื่อม - ปีงบประมาณ 2569`, `ขยายเวลา - ปีงบประมาณ 2570` (ไม่มี `.รอบ` ตามมติ 2/3)
- **PO (มีหนี้):** หัวกลุ่ม = `เลขที่เงินกัน {Transferno}.{n}` (เช่น `68030009.1`, `.2`)
- แถวประวัติ = read-only · แถวรอบปัจจุบัน = กรอกช่อง "จำนวนเงินขยาย" ได้
- ท้ายไฟล์มี checklist 4 ข้อให้ BA เคาะ (label, จำนวนชั้น, PR ต้องมี `.n` ไหม, พับกลุ่มได้ไหม)

> ข้อมูลตัวอย่างอิงของจริง PREPROD (booknumber 169xxxxx/269xxxxx, เลขที่เงินกัน 68030009) — ยังไม่ผูกข้อมูลจริง/ไม่ใช่โค้ดระบบ

---

*จัดทำโดย Claude Opus 4.8 — analysis only, ไม่มีการแก้ไข source code ของระบบ ตาม prompt ข้อ 4 (DB query เป็น read-only)*

---

## 13. รายการไฟล์ที่ต้องแก้ + รายละเอียด (Implementation Checklist)

> สรุปจาก section 2/5/6 หลังมติ BA ครบ 6 ข้อ — รวม **~15 ไฟล์ + 3 Oracle objects**
> ลำดับลงมือ: **DB → DAL → Models → API → MVC → View** (จากชั้นในออกชั้นนอก) เพื่อให้ build ผ่านทีละชั้น
> code block ด้านล่างอ้างอิงโค้ด **ของจริง ณ 2026-06-23** (อ่านจากไฟล์ในระบบ) — ส่วน "After" เป็น **ข้อเสนอ** ยังไม่ได้แก้จริง

> **📋 As-Built Log** — อัปเดต 2026-06-23 (TFS Changeset #19113)

---

### ✅ 13.1 Oracle DB — SQL script แยก (**R0, ต้อง DBA review + backup**)

- [x] **`OAGWBG_BUDGETRESERVEDITEM`** — เพิ่ม column `RESERVEDNO_ADD VARCHAR2(250)` *(as-built: ชื่อต่างจากแผน `EXPAND_RESERVENO` — DBA รันแล้วบน PREPROD)*
- [x] **`OAGWBG_V_BUDGETRESERVEDITEM`** — CREATE OR REPLACE เพิ่ม column `RESERVEDNO_ADD` ใน select list *(DBA รันแล้ว)*
- [ ] **`OAGWBG_FN_GET_RESERVE_PERIOD`** — ข้ามได้ *(C# `BudgetPeriodHelper.GetPeriod()` ทำหน้าที่เดียวกัน ไม่มี stored proc อื่น call ตรง)*

```sql
-- ① เพิ่มคอลัมน์ "เลขที่เงินกันเพิ่ม"  (เก็บแยกจาก TRANSFERNO ตามมติ 1)
ALTER TABLE OAGWBG.OAGWBG_BUDGETRESERVEDITEM
    ADD (EXPAND_RESERVENO VARCHAR2(30));
COMMENT ON COLUMN OAGWBG.OAGWBG_BUDGETRESERVEDITEM.EXPAND_RESERVENO
    IS 'เลขที่เงินกันเพิ่ม รูปแบบ <Transferno>.<รอบ> เช่น 68030009.1 (เฉพาะฝั่งมีหนี้ PO)';

-- ② เพิ่ม column ใน view ที่ map กับ OagwbgVBudgetreserveditem
--    (CREATE OR REPLACE — copy select list เดิม + เพิ่ม i.EXPAND_RESERVENO)
-- CREATE OR REPLACE VIEW OAGWBG.OAGWBG_V_BUDGETRESERVEDITEM AS
--   SELECT ... , i.EXPAND_RESERVENO , ...
--   FROM OAGWBG_BUDGETRESERVEDITEM i ... ;

-- ③ function ช่วงเวลา/พาริตี้รอบ — กันเงิน เม.ย.–ก.ย.(คี่) / ขยายเวลา ต.ค.–มี.ค.(คู่)
CREATE OR REPLACE FUNCTION OAGWBG.OAGWBG_FN_GET_RESERVE_PERIOD(p_date IN DATE)
    RETURN VARCHAR2   -- 'RESERVE' (เม.ย.-ก.ย.) | 'EXPAND' (ต.ค.-มี.ค.)
IS
    v_month NUMBER := TO_NUMBER(TO_CHAR(p_date, 'MM'));
BEGIN
    IF v_month BETWEEN 4 AND 9 THEN
        RETURN 'RESERVE';   -- รอบกันเงิน → ก.ย. = ส่ง interface (คี่)
    ELSE
        RETURN 'EXPAND';    -- รอบขยายเวลา → มี.ค. = ไม่ส่ง interface (คู่)
    END IF;
END;
/
```

```sql
-- ROLLBACK script (เก็บคู่กันไว้)
ALTER TABLE OAGWBG.OAGWBG_BUDGETRESERVEDITEM DROP COLUMN EXPAND_RESERVENO;
DROP FUNCTION OAGWBG.OAGWBG_FN_GET_RESERVE_PERIOD;
-- view: restore จาก DDL เดิม
```

> ⚠️ **ห้ามรันบน PROD ตรง** — เก็บเป็น `.sql` ใน `_brain/SQL`, มี rollback, ให้ DBA รันบน PREPROD ก่อน

---

### ✅ 13.2 DAL — `OAGBudget.DAL` (R2)

- [x] เพิ่ม property `Reservedno` ใน [OagwbgBudgetreserveditem.cs](OAGBudget.DAL/Models/OagwbgBudgetreserveditem.cs) *(as-built: property name = `Reservedno` map `RESERVEDNO_ADD`)*
- [x] เพิ่ม property `Reservedno` ใน [OagwbgVBudgetreserveditem.cs](OAGBudget.DAL/Models/OagwbgVBudgetreserveditem.cs)
- [x] map column ทั้ง 2 entity ใน [OAGDBContextBase.cs](OAGBudget.DAL/Models/OAGDBContextBase.cs)

**model** ([OagwbgBudgetreserveditem.cs](OAGBudget.DAL/Models/OagwbgBudgetreserveditem.cs) — ต่อท้ายกลุ่ม `Overlapyear/Overlapround/Transferno` ที่มีอยู่แล้ว L116-118):

```csharp
public int? Overlapyear { get; set; }

public int? Overlapround { get; set; }

// ⬇️ เพิ่มใหม่ — เลขที่เงินกันเพิ่ม <Transferno>.<รอบ> (มติ 1)
public string? ExpandReserveno { get; set; }
```

**DbContext mapping** ([OAGDBContextBase.cs](OAGBudget.DAL/Models/OAGDBContextBase.cs) — ในบล็อก `entity.ToTable("OAGWBG_BUDGETRESERVEDITEM")` ~L4727 ตาม pattern เดิม):

```csharp
entity.Property(e => e.ExpandReserveno)
    .HasMaxLength(30)
    .IsUnicode(false)
    .HasComment("เลขที่เงินกันเพิ่ม <Transferno>.<รอบ>")
    .HasColumnName("EXPAND_RESERVENO");
```
> ทำซ้ำในบล็อก view `OAGWBG_V_BUDGETRESERVEDITEM` (~L16071) ด้วย

---

### ✅ 13.3 Models / DTOs — `OAGBudget.Models` (R2)

- [x] เพิ่มโครงสร้าง group level `ExpandGroup` (+ `CheckedKeys HashSet`) ใน [BudgetReservedCentralViewModel.cs](OAGBudget.Models/ViewModel/BudgetReservedCentralViewModel.cs)
- [x] เพิ่ม period flags `IsReservePeriod / IsExpandPeriod / IsReserveTabLocked` ใน ViewModel
- [x] `BudgetReservedCentralFormModel` — ไม่ต้องแก้ *(Overlapround ถูก handle ใน API จาก header.Roundinterface โดยตรง ไม่ต้องส่งผ่าน form)*

```csharp
// โครงสร้าง group level (ใช้ render หัวกลุ่ม "ประวัติ + รอบปัจจุบัน")
public class ExpandGroup
{
    public string GroupLabel { get; set; }   // PR: "ขยายเวลา - ปีงบประมาณ 2569" | PO: "68030009.1"
    public int Round { get; set; }           // = Overlapround
    public bool IsReadOnly { get; set; }      // รอบเก่า = true (มติ 4: lock ประวัติ)
    public List<OagwbgVBudgetreserveditem> Items { get; set; } = new();
}

// ใน BudgetReservedCentralViewModel — เสริมของเดิม ListExpand*/ListCancel*
public List<ExpandGroup> ExpandGroupsHasObligation { get; set; } = new();  // PO
public List<ExpandGroup> ExpandGroupsNoObligation { get; set; } = new();   // PR

// period flags — server เป็น source of truth (อย่าคำนวณวันที่ใน View)
public bool IsReservePeriod { get; set; }   // อยู่ช่วง เม.ย.-ก.ย.
public bool IsExpandPeriod { get; set; }    // อยู่ช่วง ต.ค.-มี.ค.
public bool IsReserveTabLocked { get; set; } // มติ 4: lock tab กันเงิน + Header หลัง confirm รอบแรก
```

---

### ✅ 13.4 API Service — `OAGBudget.API` / [BudgetService.cs](OAGBudget.API/Services/Repository/BudgetService.cs) (**R1**)

- [x] 🔴 `SynchronizeReservedItemsAsync` — append-by-round: ลบเฉพาะ `Overlapround == currentRound && Approve == null`; เซ็ต `Overlapround/Overlapyear/Reservedno` ทุก insert
- [x] `GetBudgetOverlapYearCentralList` — populate `ExpandGroupsHasObligation` (PO) + `ExpandGroupsNoObligation` (PR) grouped by Overlapround; PR balance refresh จาก view สำหรับ current round (มติ 6)
- [x] `ConfirmBudgetReserved` — period guard (block นอกช่วง, มติ ก); `Budgetyear+1` เฉพาะ RESERVE round (มติ 5)
- [x] `SynchronizeReservedItemsAsync` (first-time path) — สร้าง ExpandGroup เดียวจาก `ListExpand*` เมื่อยังไม่มี savedItems

**(A) 🔴 `SynchronizeReservedItemsAsync` — ปัจจุบันลบทิ้งหมด (L21500-21507):**

```csharp
// ❌ AS-IS — ลบทุกรายการของ header แล้วเขียนใหม่ → ประวัติรอบเก่าหาย
var existingItems = await _context.OagwbgBudgetreserveditems
    .Where(x => x.Budgetreversedid == header.Id)
    .ToListAsync();

if (existingItems.Count > 0)
{
    _context.OagwbgBudgetreserveditems.RemoveRange(existingItems);   // ⚠️ ลบหมด
}
```

```csharp
// ✅ TO-BE — append-by-round: ลบเฉพาะ "รอบปัจจุบันที่ยังไม่ confirm" เท่านั้น
var currentRound = header.Roundinterface ?? 1;

var existingItems = await _context.OagwbgBudgetreserveditems
    .Where(x => x.Budgetreversedid == header.Id)
    .ToListAsync();

// รอบเก่า/ที่ confirm แล้ว (Approve == 1) = ประวัติ → คงไว้
var editableItems = existingItems
    .Where(x => x.Overlapround == currentRound && x.Approve == null)
    .ToList();

if (editableItems.Count > 0)
    _context.OagwbgBudgetreserveditems.RemoveRange(editableItems);   // ลบเฉพาะรอบปัจจุบัน

// ... ตอนสร้าง entity ใหม่ ให้เซ็ต round/year/เลขที่เงินกันเพิ่ม:
//   Overlapround   = currentRound,
//   Overlapyear    = header.Budgetyear,
//   Transferno     = header.Transferno,
//   ExpandReserveno = t.Type == "EXPAND_PO"
//                     ? $"{header.Transferno}.{currentRound}"   // PO มี .n (มติ 1)
//                     : null,                                    // PR ไม่มี .n (มติ 2)
```

> ปัจจุบันตอน insert (L21540-21559) **ไม่เซ็ต** `Overlapround/Overlapyear/Transferno/ExpandReserveno` เลย — ต้องเพิ่ม
> dedup key เดิม `{Booknumber, Accountcode, Type}` (L21536) → เพิ่มมิติ `Overlapround` กันรอบใหม่ชนรอบเก่า

**(B) `ConfirmBudgetReserved` — `Budgetyear+1` ทุก confirm (L19181-19188):**

```csharp
// ❌ AS-IS — +1 ทุกครั้งที่ confirm (ทั้งรอบ ก.ย. และ มี.ค. = +2 ต่อปี)
var nextYear = budget.Budgetyear + 1;
async Task UpdateHeaderAndItemsStatusAsync()
{
    budget.Statusid = targetStatus;
    budget.Updateby  = userId;
    budget.Updateon  = now;
    budget.Budgetyear = nextYear;          // ⚠️ เด้งทุกรอบ
    ...
}
```

```csharp
// ✅ TO-BE — +1 เฉพาะรอบ ก.ย. (คี่ = ส่ง interface) ตามมติ 5
bool isSeptemberRound = (budget.Roundinterface % 2) != 0;   // คี่ = ก.ย.
async Task UpdateHeaderAndItemsStatusAsync()
{
    budget.Statusid = targetStatus;
    budget.Updateby  = userId;
    budget.Updateon  = now;
    if (isSeptemberRound)
        budget.Budgetyear = budget.Budgetyear + 1;   // +1 เฉพาะรอบ ก.ย.
    ...
}
// ⚠️ มติ 5 ต่อ: ชุดบัญชีที่ "ส่ง interface" ต้องใช้ปีของ "ตัวรายการ (item.Budgetyear/Overlapyear)"
//    ไม่ใช่ปี header ที่เพิ่ง +1 — ตรวจจุดประกอบ account segment ใน SaveInterface (~L11696)
```

**(C) `GetBudgetOverlapYearCentralList` (~L19435):** เปลี่ยน merge flat → จัดกลุ่มตาม `Overlapround` คืน `ExpandGroups*`; PR ดึง view ก่อนเสมอ (มติ 6) / PO ดึง saved ก่อนแล้วต่อ view; เกณฑ์ "ยอดหมด" PO = `CLOSED_CODE='CLOSED' OR REMAINING_AMOUNT<=0` (ภาคผนวก ก)

> 🔴 (A) = จุดเสี่ยงสูงสุด — แก้ผิด = รอบเก่าหาย/ซ้ำ → ทำก่อน + เขียน test + ทดสอบ 2 รอบ (กันเงิน→ขยาย)

---

### ✅ 13.5 MVC Controller + Proxy — `OAGBudget` (R2)

- [x] `BudgetOverlapYearCentralDetail` — set `IsReservePeriod / IsExpandPeriod / IsReserveTabLocked` ลง ViewModel ก่อน return View
- [x] `SaveBudgetReservedCentrall` — ไม่ต้องแก้ *(Overlapround/Reservedno ถูก compute ฝั่ง API service โดยตรงจาก header)*
- [x] proxy BudgetService — ไม่ต้องแก้ DTO mapping เพิ่ม *(fields ใหม่ผ่าน ViewModel แล้ว)*

```csharp
// BudgetOverlapYearCentralDetail() — คำนวณช่วงเวลาฝั่ง server (เรียก FN ใหม่ผ่าน service)
// แล้วเซ็ตลง ViewModel ก่อน return View(model)
var period = await _budgetService.GetReservePeriod(DateTime.Now);   // 'RESERVE' | 'EXPAND'
model.IsReservePeriod = period == "RESERVE";
model.IsExpandPeriod  = period == "EXPAND";
// lock tab กันเงิน + Header เมื่อพ้นการกันเงินครั้งแรก (มติ 4)
model.IsReserveTabLocked = model.Roundinterface != null;   // confirm รอบแรกแล้ว Roundinterface != null
```

---

### ✅ 13.6 Views / Partials — `OAGBudget` (R2)

- [x] [BudgetOverlapYearCentralDetail.cshtml](OAGBudget/Views/Budget/BudgetOverlapYearCentralDetail.cshtml) — `isReserveTabLocked` wires tab กันเงิน lock icon + header fields disabled + `applyOverlapLock()` JS; period guard บน btnConfirm
- [x] [_tableExpandHasObligation.cshtml](OAGBudget/Views/Budget/_partialView/_tableExpandHasObligation.cshtml) — model เปลี่ยนเป็น `List<ExpandGroup>`; group header rows; history read-only; คอลัมน์ "เลขที่เงินกันเพิ่ม" ต่อแถว
- [x] [_tableExpandNoObligation.cshtml](OAGBudget/Views/Budget/_partialView/_tableExpandNoObligation.cshtml) — model เปลี่ยนเป็น `List<ExpandGroup>`; group header rows; history read-only

**isLocked ปัจจุบัน (L25-33):**

```csharp
// ❌ AS-IS — ไม่มีเงื่อนไขช่วงเวลา/รอบเลย
bool isLocked = Model.Statusid == 90201 || Model.Statusid == 20101 || Model.Statusid == 10197;
bool showActionTabs = Model.Statusid == 20202 || Model.Statusid == 90102 || Model.Roundinterface != null;
```

```csharp
// ✅ TO-BE — รวมเงื่อนไขช่วงเวลา + lifecycle stage (flags มาจาก server)
bool isLocked = Model.Statusid == 90201 || Model.Statusid == 20101 || Model.Statusid == 10197;

// tab "กันเงิน" + Header: lock เมื่อพ้นการกันเงินครั้งแรก (มติ 4)
bool isReserveTabLocked = Model.IsReserveTabLocked;

// tab "ขยายเวลา": แก้ได้เฉพาะเมื่ออยู่ช่วงขยายเวลา (ต.ค.-มี.ค.) ตามมติ 4
bool canEditExpand = Model.IsExpandPeriod && !isLocked;
```

> partial: วน `Model.ExpandGroupsHasObligation` → render `<tr class="group-header">@g.GroupLabel</tr>` แล้ววน `g.Items`; ถ้า `g.IsReadOnly` ปิด input "จำนวนเงินขยาย" + checkbox

---

### 📊 13.7 สรุปสถานะ As-Built (อัปเดต 2026-06-23)

| ชั้น | สถานะ | หมายเหตุ |
|---|---|---|
| Oracle SQL | ✅ 2/3 done | table + view รันแล้ว; FN_GET_RESERVE_PERIOD ข้าม (C# แทน) |
| DAL | ✅ done | property `Reservedno` map `RESERVEDNO_ADD` |
| Models | ✅ done | `ExpandGroup` + `CheckedKeys` + period flags |
| API Service | ✅ done | append-by-round, ExpandGroups, period guard, PR refresh |
| MVC Controller | ✅ done | period flags → ViewModel |
| View / Partial | ✅ done | group headers, read-only history, Reservedno column |
| **TFS Checkin** | ✅ **Changeset #19113** | 5 ไฟล์ checkin 2026-06-23 23:09 |

---

### ✅ 13.8 Unit Tests — `OAGBudget.Tests` (2026-06-23)

> `dotnet test` — **9/9 Passed** · ไม่ต้องต่อ DB (pure function)

| Test | วันที่ทดสอบ | คาด | ผล |
|---|---|---|---|
| `GetPeriod_ReturnsCorrectPeriodType` | 1 เม.ย. | RESERVE | ✅ |
| `GetPeriod_ReturnsCorrectPeriodType` | 30 ก.ย. | RESERVE | ✅ |
| `GetPeriod_ReturnsCorrectPeriodType` | 15 ก.ค. | RESERVE | ✅ |
| `GetPeriod_ReturnsCorrectPeriodType` | 1 ต.ค. | EXPAND | ✅ |
| `GetPeriod_ReturnsCorrectPeriodType` | 31 มี.ค. | EXPAND | ✅ |
| `GetPeriod_ReturnsCorrectPeriodType` | 15 ม.ค. (ข้ามปี) | EXPAND | ✅ |
| `GetPeriod_ReservePeriod_HasCorrectDateRange` | StartDate=1เม.ย. EndDate=30ก.ย.23:59:59 | — | ✅ |
| `GetPeriod_ExpandPeriod_OctToMar_HasCorrectDateRange` | StartDate=1ต.ค. EndDate=31มี.ค.ปีถัดไป | — | ✅ |
| `GetPeriod_ExpandPeriod_JanToMar_StartDateIsOctPreviousYear` | ม.ค.2027 → StartDate=1ต.ค.2026 | — | ✅ |

```
Total tests: 9  |  Passed: 9  |  Failed: 0  |  Time: 5.71s
```

---

### 🔲 13.9 งานที่เหลือ

| # | งาน | ระดับ | ใคร |
|---|---|---|---|
| 1 | **Oracle function** `OAGWBG_FN_GET_RESERVE_PERIOD` | optional | DBA |
| 2 | **List screen filters** (รอบ/ปี) บนหน้า BudgetOverlapYearCentralList | optional | Dev |

---

## 14. คำถาม — หน้า List (BudgetOverlapYearCentralList)

> **วันที่:** 2026-06-23 · **รอมติ**

### บริบท

หน้า list ปัจจุบันมี filter 3 ตัว: **ปีงบประมาณ / หน่วยเบิกจ่าย / สถานะ**

หลังจาก feature นี้ รายการหนึ่งจะมีหลาย "รอบ" สะสมอยู่ใน `Roundinterface` (กันเงิน → ขยายเวลาครั้งที่ 1 → ขยายเวลาครั้งที่ 2 ...) ผู้ใช้อาจต้องการค้นหาตามรอบที่กำลังดำเนินการอยู่

### ❓ คำถาม

**ข้อ 1 — ต้องการ filter "รอบ" ในหน้าค้นหาไหม?**

| ตัวเลือก | ความหมาย |
|---|---|
| **(ก) เพิ่ม dropdown filter "รอบ"** | กรองได้ว่า "กันเงิน / ขยายเวลาครั้งที่ 1 / ครั้งที่ 2 ..." |
| **(ข) ไม่ต้องกรองรอบ** | ดูจาก filter สถานะเพียงพอแล้ว |

**ข้อ 2 — ต้องการแสดง "รอบปัจจุบัน" ในคอลัมน์ตารางผลลัพธ์ไหม?**

| ตัวเลือก | ความหมาย |
|---|---|
| **(ก) เพิ่มคอลัมน์ "รอบ"** | แสดง เช่น "ขยายเวลาครั้งที่ 1" ต่อท้ายแต่ละแถว |
| **(ข) ไม่ต้องเพิ่ม** | ดูรายละเอียดรอบได้ในหน้า detail อยู่แล้ว |

> ถ้า BA ตอบ (ข) ทั้ง 2 ข้อ → ข้าม list filters ได้เลย ไม่มีงานเพิ่ม

---

## 15. ข้อเสนอ — BypassPeriodGuard สำหรับ UAT/QA

> **วันที่:** 2026-06-24 · **เสนอโดย:** Dev · **รอมติ:** หัวหน้าทีม

### ปัญหา

Feature นี้มี period guard เข้มงวด — ยืนยันรายการ (Confirm) ได้เฉพาะในช่วงเวลาที่กำหนด:

| รอบ | ช่วงที่ Confirm ได้ |
|---|---|
| กันเงิน | 1 เม.ย. – 30 ก.ย. |
| ขยายเวลา | 1 ต.ค. – 31 มี.ค. |

ทำให้ **Tester ไม่สามารถทดสอบ flow เต็มรูปแบบ (กันเงิน → ขยายเวลา → ขยายเวลา) ในวันเดียวได้** เพราะต้องรอวันที่เปลี่ยนช่วงจริง ซึ่งใช้เวลาข้ามเดือน

### ข้อเสนอ

เพิ่ม feature flag `BypassPeriodGuard` บน **PREPROD เท่านั้น** เพื่อเปิด/ปิด period gate สำหรับการทดสอบ

**สิ่งที่ bypass:**
- เงื่อนไข "ห้าม confirm นอกช่วงเวลา" ใน `ConfirmBudgetReserved`

**สิ่งที่ไม่ bypass (ทำงานตามปกติทุกกรณี):**
- ตรรกะ Roundinterface คี่/คู่ → ส่ง / ไม่ส่ง GL interface
- Budgetyear+1 เฉพาะรอบ RESERVE (คี่)
- Reservedno = `{Transferno}.{n}`
- ประวัติรอบเก่า read-only

### การ implement (2 จุด)

**① `appsettings.json` (PREPROD)**
```json
"FeatureFlags": {
  "BypassPeriodGuard": true
}
```

**② `BudgetService.cs` — `ConfirmBudgetReserved`**
```csharp
var bypass = _configuration.GetValue<bool>("FeatureFlags:BypassPeriodGuard");
if (!bypass)
{
    // period guard เดิม
    var expectReserve = budget.Roundinterface == null || (budget.Roundinterface % 2) != 0;
    var actualReserve = period.PeriodType == BudgetPeriodType.RESERVE;
    if (expectReserve != actualReserve)
        return new ApiResultsModel { Success = false, Message = "...", Id = model.Id };
}
```

### Flow ทดสอบเมื่อเปิด bypass (ทำได้ในวันเดียว)

| ขั้น | Roundinterface | ผลที่คาด |
|---|---|---|
| สร้าง + กันเงิน + **Confirm** | null → 1 (คี่) | ส่ง GL interface · Budgetyear+1 |
| เปิดรายการ | 1 | tab กันเงิน lock icon · header disabled |
| ขยายเวลา ครั้งที่ 1 + **Confirm** | 1 → 2 (คู่) | ไม่ส่ง interface · Reservedno = `xxx.1` |
| เปิดรายการ | 2 | tab ขยายเวลา: กลุ่มประวัติ read-only + กลุ่มปัจจุบัน |
| ขยายเวลา ครั้งที่ 2 + **Confirm** | 2 → 3 → 4 (คู่) | Reservedno = `xxx.2` · ประวัติ 2 กลุ่ม |

> Roundinterface 3 (คี่) ถูก toggle เป็น 4 (คู่) อัตโนมัติหลัง confirm รอบขยายเวลาครั้งที่ 2

### Checklist ก่อน Deploy PROD

- [ ] ตั้ง `BypassPeriodGuard: false` ใน `appsettings.json` PROD (หรือใช้ `appsettings.Production.json` ที่ไม่มี key นี้ → default = false)
- [ ] ตรวจสอบว่าไม่มี `BypassPeriodGuard: true` หลุดไป PROD

### ความเสี่ยง

| ความเสี่ยง | ระดับ | มิติการลด |
|---|---|---|
| หลุดไปเปิดบน PROD | 🔴 สูง | ใช้ `appsettings.Production.json` แยก / ตรวจ pre-deploy checklist |
| Tester confirm ผิด sequence | 🟡 กลาง | แนบ flow ทดสอบนี้ให้ Tester ยึดตาม |

### มติที่ต้องการ

- [ ] **(ก) อนุมัติ** — Dev implement + ทดสอบบน PREPROD
- [ ] **(ข) ไม่อนุมัติ** — Tester รอช่วงเวลาจริง (UAT กันเงิน เม.ย.–ก.ย. / UAT ขยายเวลา ต.ค.–มี.ค.)
