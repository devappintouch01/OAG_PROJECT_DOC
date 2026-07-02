# ผลการวิเคราะห์: การส่ง Interface "ยกเลิก" (Cancel/Reverse) ไปยัง Oracle EBS

> **ประเภทงาน:** วิเคราะห์เท่านั้น (ห้ามแก้ code) — R2
> **วันที่:** 2026-07-02
> **ขอบเขต:** 6 หน้าจอตาม Page in Scope + อ้างอิงสเปค `OAG_Budget_View_Detail.xlsx` (ชีทที่มีคำว่า "ยกเลิก") และ log `log-interface-cancel.jpg`
> **สถานะการเชื่อมต่อ DB ขณะวิเคราะห์:** วิเคราะห์จาก source code + สเปค Excel เป็นหลัก (ยังไม่ได้ query PREPROD สด — ต้องต่อ VPN F5 ก่อน validate รายละเอียด package/segment)

---

## 0. บทสรุปผู้บริหาร (TL;DR)

ระบบส่ง Interface ไป Oracle EBS **ผ่านช่องทางเดียวกันทั้งหมด** คือ:

1. สร้าง record `OagwbgLogInterface` → เรียก `SaveInterface()` → **INSERT ลงตาราง `OAGGL_JOURNAL_INTERFACE`** (ฝั่ง EBS) + log ลง `OAGWBG_LOG_INTERFACE` (ฝั่ง App) ใน transaction เดียว
2. เรียก `GetBatchStatus(batchName)` → run Oracle package **`APPS.OAGGL_JOURNAL_INF_PKG.MAIN(P_WEB_BATCH_NO)`** → คืน `X_STATUS` (S/E), `X_MESSAGE`
3. ถ้าสำเร็จ → อัปเดตสถานะเอกสารเป็น `80201`

**ช่องว่างของฟีเจอร์ (Gap):** ปัจจุบันปุ่ม **"ยกเลิก"/"ลบ" เปลี่ยนสถานะเป็น `90109` เฉย ๆ โดยไม่ส่ง Interface กลับไป EBS** — ทำให้ยอดบัญชีใน Oracle EBS ไม่ถูกกลับรายการ

**แนวทางที่มีอยู่แล้ว (Precedent):** โค้ด **มี pattern การส่ง Interface ยกเลิกอยู่แล้ว** ในเคส "กันเงินเหลื่อมปี หน่วยกลาง" (`SaveBudgetReserved`) ที่สร้าง batch ชื่อ `REVERSE_ENC_CARRY_FORWARD_...` + Journal Name `กลับรายการบัญชี_...` และสลับขา DR/CR → **ใช้เป็นแม่แบบ (template) สำหรับหน้าจออื่นได้ทันที**

**สูตรการทำ Interface ยกเลิก** (สอดคล้องกับ Excel ทุกชีท "- ยกเลิก"):
- `web_batch_no` → เติม prefix **`REVERSE_`** หน้า prefix เดิม
- `reference4`/`reference5` (Journal Name/Desc) → เติม **`กลับรายการบัญชี_`** หน้าข้อความเดิม
- **สลับขา DR ↔ CR** (กลับรายการ) โดยใช้ Account segment ชุดเดิม/ยอดเดิม
- ส่งผ่าน **ตารางเดียวกัน + package เดียวกัน**

---

## 1. สถาปัตยกรรมการส่ง Interface ปัจจุบัน (Engine)

### 1.1 หัวใจของระบบ — 2 เมธอดใน `BudgetService.cs`

| เมธอด | บรรทัด | หน้าที่ |
|---|---|---|
| `SaveInterface(OagwbgLogInterface data, ...)` | [BudgetService.cs:11840](../../OAGBudget.API/Services/Repository/BudgetService.cs#L11840) | INSERT 1 บรรทัด journal ลง `OAGGL_JOURNAL_INTERFACE` (EBS) + log ลง `OAGWBG_LOG_INTERFACE` (App) ใน transaction เดียว |
| `GetBatchStatus(string batchName, ...)` | [BudgetService.cs:16450](../../OAGBudget.API/Services/Repository/BudgetService.cs#L16450) | เรียก `APPS.OAGGL_JOURNAL_INF_PKG.MAIN` เพื่อ process batch → คืนสถานะ + อัปเดต `Status`/`Message` ใน log |

**พารามิเตอร์สำคัญของ `SaveInterface`:**
- `preFetchedLedgerId` — ส่ง ledger id ที่ query ไว้ล่วงหน้า (ลด query ซ้ำ)
- `overrideTempActualFlag` — override ActualFlag เฉพาะฝั่ง log (temp)
- `skipInterface` — ถ้า `true` จะ **ไม่** INSERT ลง EBS (log อย่างเดียว) → มีประโยชน์สำหรับ dry-run/บันทึกประวัติ

### 1.2 โครงสร้าง `OAGGL_JOURNAL_INTERFACE` (ปลายทาง EBS)

INSERT จริงอยู่ที่ [BudgetService.cs:11901-11982](../../OAGBudget.API/Services/Repository/BudgetService.cs#L11901). ฟิลด์หลักที่เกี่ยวกับการยกเลิก:

| ฟิลด์ | ความหมาย | ค่าปกติ | ค่ากรณียกเลิก |
|---|---|---|---|
| `WEB_BATCH_NO` | รหัส batch (key ให้ package process) | `BUDGET_ADJUST_2568_...` | `REVERSE_BUDGET_ADJUST_2568_...` |
| `REFERENCE4` / `REFERENCE5` | Journal Name / Description | `โอนเปลี่ยนแปลง...` | `กลับรายการบัญชี_โอนเปลี่ยนแปลง...` |
| `USER_JE_CATEGORY_NAME` | หมวด journal | `Budget - เปลี่ยนแปลง` | เหมือนเดิม (บางเคสเปลี่ยน) |
| `ACTUAL_FLAG` | B=Budget / E=Encumbrance | ตามเคส | ตามสเปค (มักสลับ E↔B เป็นคู่) |
| `ENTERED_DR` / `ACCOUNTED_DR` | ยอดเดบิต | ตามยอดจริง | **ย้ายไปขา CR** |
| `ENTERED_CR` / `ACCOUNTED_CR` | ยอดเครดิต | ตามยอดจริง | **ย้ายไปขา DR** |
| `SEGMENT1..13` | ชุดบัญชี (Account combination) | ตามรายการ | ใช้ชุดเดิม |
| `ATTRIBUTE3` | Transaction ID จากเว็บ | id หน้าเว็บ | id หน้าเว็บ (อ้างเอกสารเดิม) |
| `ATTRIBUTE4` | Transfer No | เลขที่เอกสาร | เลขที่เอกสารเดิม |
| `TRANSFER_TYPE` | ประเภทการโอน | `ADJUSTMENT`/`REVENUE`/`CARRYFWD`/`CARRYPRPO` | เหมือนเดิม |
| `ENCUMBRANCE_TYPE` | ประเภท encumbrance | `Web Encumbrance` | เหมือนเดิม |

> **หมายเหตุสำคัญ:** ในชีท `INTERFACE GL` ของ Excel มีคอลัมน์ `REVERS_FLAG (VARCHAR2 10)`, `X_RE_JE_BATCH_ID`, `X_RE_JE_HEADER_ID`, `X_RE_JE_LINE_NUM` ซึ่ง Oracle GL รองรับการ reverse แบบ native อยู่แล้ว **แต่** โค้ด precedent ที่มีอยู่ (`REVERSE_ENC_CARRY_FORWARD`) **ไม่ได้ใช้ `REVERS_FLAG`** — เลือกวิธี **สร้างบรรทัด journal ขากลับด้วยมือ (manual DR/CR swap)** แทน ⇒ **ต้องยืนยันกับทีม Oracle ว่าจะใช้วิธีไหน** (ดูข้อ 8 คำถามค้าง)

### 1.3 การ process batch — `OAGGL_JOURNAL_INF_PKG.MAIN`

[BudgetService.cs:16499-16528](../../OAGBudget.API/Services/Repository/BudgetService.cs#L16499):
```
cmd.CommandText = "APPS.OAGGL_JOURNAL_INF_PKG.MAIN";   // Stored Procedure
IN  : P_WEB_BATCH_NO = batchName
OUT : X_STATUS  (S = Success, E = Error)
OUT : X_MESSAGE (ข้อความ)
```
- ตั้ง NLS session (date format, language, timezone Asia/Bangkok) ก่อนเรียก
- หลัง process → อัปเดต `Status`/`Message` ของทุก log row ที่ `WebBatchNo == batchName`
- ถ้า `receives` ไม่ว่าง → บันทึก running number ลง `OAGWBG_RECEIVE_BATCH_NO`

### 1.4 ตารางที่เกี่ยวข้อง (Oracle)

| ตาราง / Object | ฝั่ง | บทบาท |
|---|---|---|
| `OAGGL_JOURNAL_INTERFACE` | EBS (`_ebsContext`) | **Staging/Temp table** ที่รับ journal ก่อน package ประมวลผลเข้า GL จริง |
| `OAGWBG_LOG_INTERFACE` | App (`_context`) | Log ประวัติทุก journal ที่ส่ง + สถานะตอบกลับ (Model: [OagwbgLogInterface.cs](../../OAGBudget.DAL/Models/OagwbgLogInterface.cs)) |
| `OAGWBG_RECEIVE_BATCH_NO` | App | Map batch ↔ receive id + running number ต่อรอบ (Model: [OagwbgReceiveBatchNo.cs](../../OAGBudget.DAL/Models/OagwbgReceiveBatchNo.cs)) |
| `APPS.OAGGL_JOURNAL_INF_PKG.MAIN` | EBS | **Package** ดึงข้อมูลจาก staging → ลง GL + คืนสถานะ |
| `OAGGL_JOURNAL_INTERFACE` (ต่อ) | EBS | มีคอลัมน์ `INTERFACE_STATUS`(S/E), `INTERFACE_MSG`, `PROCESS_FLAG`, `X_JE_*`, `REVERS_FLAG` |

> **"Temp table ยืนยัน/ยกเลิก" ที่ task ถามถึง = `OAGGL_JOURNAL_INTERFACE`** (staging ฝั่ง EBS) โดยมี `OAGWBG_LOG_INTERFACE` เป็นตัวบันทึกฝั่ง app ทั้งขายืนยันและขายกเลิก (แยกด้วย `WEB_BATCH_NO` prefix + `ActionName`)

---

## 2. รายการหน้าจอที่มีการส่ง Interface (In Scope) + เมธอด/Batch Prefix

| # | หน้าจอ (Page in Scope) | เมธอดที่ส่ง Interface (ยืนยัน) | Batch Prefix ปัจจุบัน | Batch Prefix ยกเลิก (สเปค) | ชีท Excel |
|---|---|---|---|---|---|
| 1 | **คำของบประมาณตาม พรบ.** | `SaveBudgetAllocate` ([9222](../../OAGBudget.API/Services/Repository/BudgetService.cs#L9222), [9315](../../OAGBudget.API/Services/Repository/BudgetService.cs#L9315)), `SaveBudgetAllocateProject` ([9498](../../OAGBudget.API/Services/Repository/BudgetService.cs#L9498)) | `BUDGET_ACT_` | พ.ร.บ.-แก้ไข/ยกเลิก (ส่ง reverse ภายใต้ context เดิม) | [11] |
| 2 | **เบิกเงินจากกรมบัญชีกลาง** | `SaveBudgetPaymentGf` ([9571](../../OAGBudget.API/Services/Repository/BudgetService.cs#L9571)) | `BUDGET_WD_` | `REVERSE_BUDGET_` | [13] |
| 3 | **โอนปรับเปลี่ยนรายการ** | `SaveBudgetAdjust` ([10118](../../OAGBudget.API/Services/Repository/BudgetService.cs#L10118)), `ConfirmBudgetTransferAdjust` ([16172](../../OAGBudget.API/Services/Repository/BudgetService.cs#L16172)) | `BUDGET_ADJUST_` | `REVERSE_BUDGET_ADJUST_` | [19] |
| 4 | **โอนเงินปรับเงินเหลือจ่าย** | `SaveBudgetReserveTransfer` ([11193](../../OAGBudget.API/Services/Repository/BudgetService.cs#L11193)) | `BUDGET_TRANSFER_REMAINING_` | `REVERSE_BUDGET_TRANSFER_REMAINING_` | [27] |
| 5 | **เบิกแทน** | `SaveBudgetRequisition` ([10536](../../OAGBudget.API/Services/Repository/BudgetService.cs#L10536)) | `BUDGET_เบิกแทน_` | `REVERSE_Budget_เบิกแทน_` | [25] |
| 6 | **กันเงินเหลื่อมปี** | `SaveBudgetReserved` ([10649](../../OAGBudget.API/Services/Repository/BudgetService.cs#L10649)) | `ENC_CARRY_FORWARD_` / `BG_CARRY_FORWARD_` | `REVERSE_ENC_CARRY_FORWARD_` / `REVERSE_BG_CARRY_FORWARD_` ✅ **มี precedent แล้ว** ([11027](../../OAGBudget.API/Services/Repository/BudgetService.cs#L11027)) | [32][33][35] |

> **นอกขอบเขตแต่เกี่ยวข้อง (สังเกตไว้):** โอนเงินจัดสรร (`BUDGET_TRANSFER_`, [9673](../../OAGBudget.API/Services/Repository/BudgetService.cs#L9673)) และ โอนเงินกลับ (`BUDGET_RETURN_`, [10304](../../OAGBudget.API/Services/Repository/BudgetService.cs#L10304)) ตาม log ระบุสถานะ **Accepted แล้ว** — ทำ Interface ยกเลิกเสร็จแล้ว จึงใช้เทียบเป็นตัวอย่างได้

---

## 3. ไฟล์ทั้งหมดที่ต้องแก้ (แยกตาม Layer)

### 3.1 View (`OAGBudget/Views/Budget/*.cshtml`)
เพิ่ม/ปรับปุ่ม "ยกเลิก" ให้เรียก endpoint ยกเลิกที่ส่ง Interface (ปัจจุบันปุ่มยกเลิกเรียกตัวที่เปลี่ยนสถานะเฉย ๆ):

| หน้าจอ | View หลัก (List ที่มีปุ่มยกเลิก) |
|---|---|
| คำของบประมาณตาม พรบ. | `BudgetAllocateList.cshtml`, `BudgetAllocateProjectList.cshtml`, `BudgetAllocateDetail.cshtml` |
| เบิกเงินจากกรมบัญชีกลาง | `BudgetPaymentGfList.cshtml`, `BudgetPaymentGfDetail.cshtml` |
| โอนปรับเปลี่ยนรายการ | `BudgetAdjustList.cshtml`, `BudgetAdjustDetail.cshtml`, `BudgetAdjustDetail_TransferIn.cshtml` |
| โอนเงินปรับเงินเหลือจ่าย | `BudgetReserveTransfer*` / `BudgetTransfer*` (ตรวจชื่อ view ให้ตรงกับ controller action) |
| เบิกแทน | `BudgetRequisition*` (view เบิกแทน) |
| กันเงินเหลื่อมปี | `BudgetOverlapYearList.cshtml`, `BudgetOverlapYearCentralList.cshtml`, `BudgetOverlapYearConsider.cshtml` |

*จุดแก้ใน View:* ปุ่ม/สคริปต์ JS (ajax) ให้ชี้ไป action ยกเลิกตัวใหม่ + เพิ่ม modal ยืนยัน + แสดงผลสถานะ interface (สำเร็จ/error) + (ถ้าต้องมี "View") เพิ่มลิงก์/ตารางแสดงรายการที่ยกเลิก

### 3.2 MVC Controller ([OAGBudget/Controllers/BudgetController.cs](../../OAGBudget/Controllers/BudgetController.cs))
เป็น **proxy บาง ๆ** ส่งต่อไป API — ต้องเพิ่ม action ยกเลิกที่ชี้ endpoint ใหม่ เช่น
`CancelBudgetAllocateTransfer` ([3612](../../OAGBudget/Controllers/BudgetController.cs#L3612)) เป็นตัวอย่าง pattern เดิม

### 3.3 API Controller ([OAGBudget.API/Controllers/BudgetController.cs](../../OAGBudget.API/Controllers/BudgetController.cs))
เพิ่ม endpoint ยกเลิก + ส่ง interface ต่อหน้าจอ (แนะนำ pattern `[HttpPost("CancelXxxInterface")]`).
*ปัจจุบัน* `CancelBudgetAllocateTransfer` ([1209](../../OAGBudget.API/Controllers/BudgetController.cs#L1209)) เรียกแค่ `ChangeStatusBudgetAllocateTransfer(id,"90109")` — ยังไม่ส่ง interface

### 3.4 Service ([OAGBudget.API/Services/Repository/BudgetService.cs](../../OAGBudget.API/Services/Repository/BudgetService.cs)) — **แก้หลักที่นี่**
เพิ่มเมธอด `CancelXxx` (หรือ `ReverseXxxInterface`) 1 ตัว/หน้าจอ ที่:
1. โหลดเอกสารเดิม + รายการ journal เดิม (จาก `OAGWBG_LOG_INTERFACE` โดย `WebBatchNo` เดิม หรือ rebuild จากตารางต้นทาง)
2. สร้าง batch `REVERSE_...` + Journal `กลับรายการบัญชี_...` + สลับ DR/CR
3. เรียก `SaveInterface()` → `GetBatchStatus()` (ใช้ engine เดิม — **ไม่ต้องแก้ engine**)
4. ถ้าสำเร็จ → เปลี่ยนสถานะเอกสารเป็นสถานะ "ยกเลิกแล้ว" (เช่น `90109` หรือสถานะใหม่)

*ใช้ `SaveBudgetReserved` (block `REVERSE_ENC_CARRY_FORWARD`, [11027-11159](../../OAGBudget.API/Services/Repository/BudgetService.cs#L11027)) เป็นแม่แบบ*

### 3.5 DAL / Models
- **ไม่ต้องเพิ่มฟิลด์** — `OagwbgLogInterface` มีครบแล้ว (`WebBatchNo`, `Reference4/5`, `EnteredDr/Cr`, `TransferType`, `EncumbranceType`)
- อาจเพิ่ม **View ใหม่ฝั่ง DB** สำหรับ deliverable "View" (แสดงรายการที่ยกเลิก/กลับรายการ) — ต้องยืนยันสเปค (ข้อ 8)

### 3.6 Models (DTO)
- อาจเพิ่ม request DTO เล็ก ๆ (เช่น `CancelInterfaceRequest { int Id; string Reason; }`) ถ้าต้องเก็บเหตุผลการยกเลิก — **ต้องยืนยันว่าต้องเก็บเหตุผลไหม**

---

## 4. Flow ปัจจุบัน vs. สิ่งที่ต้องเปลี่ยน (แต่ละ Layer)

### 4.1 Flow "ยืนยัน" ปัจจุบัน (ทำงานได้แล้ว)
```
[View] กดยืนยัน
  → [MVC Controller] proxy
    → [API Controller] ConfirmXxx
      → [Service] ConfirmXxx / SaveXxx
          - gen BatchName (prefix ปกติ)
          - build OagwbgLogInterface (DR/CR ตามจริง)
          - SaveInterface() → INSERT OAGGL_JOURNAL_INTERFACE + OAGWBG_LOG_INTERFACE
          - GetBatchStatus() → OAGGL_JOURNAL_INF_PKG.MAIN → X_STATUS
          - ถ้า S → เอกสาร status = 80201
```

### 4.2 Flow "ยกเลิก" ปัจจุบัน (ช่องว่าง)
```
[View] กดยกเลิก/ลบ
  → [MVC] → [API] CancelXxx / DeleteXxx
      → [Service] ChangeStatus(id, "90109")   ← เปลี่ยนสถานะเฉย ๆ
      ✗ ไม่ส่ง Interface กลับ EBS  ← ยอดใน GL ไม่ถูกกลับรายการ
```

### 4.3 Flow "ยกเลิก" เป้าหมาย (ต้องพัฒนา)
```
[View] กดยกเลิก → modal ยืนยัน
  → [MVC] → [API] CancelXxxInterface(id)
      → [Service] CancelXxx:
          0. ตรวจเงื่อนไข (เช่น พ.ร.บ.: ต้องยังไม่มีการรับเงินจากคลัง)   ← ใหม่
          1. gen BatchName = "REVERSE_" + prefix เดิม                    ← ใหม่
          2. build OagwbgLogInterface: Journal="กลับรายการบัญชี_...",
             สลับ DR↔CR, segment/ยอดชุดเดิม                              ← ใหม่
          3. SaveInterface()  ← ใช้ engine เดิม (ไม่แก้)
          4. GetBatchStatus() ← ใช้ engine เดิม (ไม่แก้)
          5. ถ้า S → เอกสาร status = 90109 (หรือสถานะยกเลิกใหม่)          ← ปรับ
```

### 4.4 สรุปการเปลี่ยนต่อ Layer

| Layer | เปลี่ยนอะไร |
|---|---|
| **View** | ปุ่มยกเลิกชี้ endpoint ใหม่ + modal ยืนยัน + แสดงผล interface + (ถ้ามี) ตาราง/ลิงก์ "View" รายการยกเลิก |
| **MVC Controller** | เพิ่ม proxy action ยกเลิกใหม่ |
| **API Controller** | เพิ่ม endpoint `CancelXxxInterface` |
| **Service** | เพิ่มเมธอด reverse 1 ตัว/หน้าจอ (สร้าง REVERSE batch + swap DR/CR) — **หัวใจของงาน** |
| **DAL** | (เป็นไปได้) เพิ่ม DB View แสดงรายการยกเลิก |
| **Models** | (เป็นไปได้) DTO เก็บเหตุผลยกเลิก |
| **Engine (`SaveInterface`/`GetBatchStatus`)** | **ไม่ต้องแก้** ✅ |

---

## 5. แผนการพัฒนา (Development Plan)

### Phase 0 — เตรียม/ยืนยันสเปค (ต่อ VPN + ทีม Oracle)
- ยืนยันวิธี reverse: **manual DR/CR swap** (ตาม precedent) หรือใช้ **`REVERS_FLAG`** ของ package
- ยืนยัน `USER_JE_CATEGORY_NAME`, `ACTUAL_FLAG`, `EFFECTIVE_DATE` ต่อหน้าจอ (ตาม Excel แต่ละชีท)
- ยืนยันเงื่อนไขห้ามยกเลิก (business rules) ต่อหน้าจอ
- ยืนยันสเปค deliverable "View" (ข้อ 8)

### Phase 1 — Service layer (แกนหลัก)
พัฒนาทีละหน้าจอ โดยยึด **`SaveBudgetReserved` REVERSE block** เป็นแม่แบบ เรียงลำดับตามความเสี่ยง/ความง่าย:
1. **โอนปรับเปลี่ยนรายการ** (มี `ConfirmBudgetTransferAdjust` โครงชัด, TransferType=ADJUSTMENT) — reverse ตรงไปตรงมา
2. **เบิกเงินจากกรมบัญชีกลาง** (`REVERSE_BUDGET_`)
3. **เบิกแทน** (`REVERSE_Budget_เบิกแทน_` — ระวัง DR/CR ต่างกันตามเคสเบิกแทน/ถูกเบิกแทน)
4. **โอนเงินปรับเงินเหลือจ่าย** (`REVERSE_BUDGET_TRANSFER_REMAINING_`)
5. **กันเงินเหลื่อมปี** (ต่อยอด precedent ให้ครบ หน่วยงาน STEP1/STEP2 + ส่วนกลาง)
6. **คำของบประมาณตาม พรบ.** (⚠️ เงื่อนไขพิเศษ: "ทำได้กรณียังไม่มีการบันทึกรับเงินจากคลัง" — ต้องมี guard)

### Phase 2 — API + MVC + View
- เพิ่ม endpoint/action/ปุ่ม ต่อหน้าจอ + modal ยืนยัน + จัดการผลลัพธ์ (S/E)

### Phase 3 — "View" deliverable
- สร้าง DB View / หน้าแสดงรายการที่ยกเลิก (ตามสเปคที่ยืนยันในข้อ 8)

### Phase 4 — ทดสอบ (ดูข้อ 6)

> **Blast radius / ความเสี่ยง:** ส่ง journal ผิดขา = ยอด GL ผิด (R1 — costly to reverse ในระบบบัญชีจริง). ต้องทดสอบบน PREPROD ก่อนเสมอ และมี guard กันยกเลิกซ้ำ (idempotency ผ่านการเช็ค batch ยกเลิกที่มีอยู่แล้วใน `OAGWBG_LOG_INTERFACE`)

---

## 6. แผนการทดสอบ (Test Plan)

### 6.1 Unit / Logic
- ตรวจ mapping field ต่อหน้าจอ (batch prefix, Journal name, category, effective date) ตรงกับ Excel ชีท "- ยกเลิก"
- ตรวจการสลับ DR↔CR: ยอด reverse = ยอดต้นทางทุกบรรทัด, ผลรวม DR=CR (balanced)
- ตรวจ guard: ยกเลิกซ้ำต้องถูกบล็อก, ยกเลิกเอกสารที่ยังไม่ interface (draft) ต้องไม่ยิง reverse

### 6.2 Integration (บน PREPROD — ต้องต่อ VPN)
ต่อหน้าจอทั้ง 6:
1. สร้าง+ยืนยันเอกสาร → ตรวจ `OAGGL_JOURNAL_INTERFACE` + GL ยอดเข้า
2. กดยกเลิก → ตรวจมี batch `REVERSE_...` ใน `OAGWBG_LOG_INTERFACE` + `INTERFACE_STATUS=S`
3. ตรวจยอด GL สุทธิ = 0 (ยืนยัน + ยกเลิก หักล้างกัน)
4. ตรวจสถานะเอกสารเปลี่ยนถูกต้อง (90109/สถานะยกเลิก)

### 6.3 Edge cases
- ยกเลิกเอกสารหลายบรรทัด / หลายผู้รับโอน (โอนปรับเปลี่ยน 1:N)
- เบิกแทน: เคสอัยการเบิกแทนหน่วยอื่น vs หน่วยอื่นเบิกแทนอัยการ (ทิศ DR/CR ต่างกัน)
- กันเงินเหลื่อมปี: 2 journal (E ปีปัจจุบัน / B ปีถัดไป) ต้อง reverse ครบทั้งคู่
- พ.ร.บ.: บล็อกยกเลิกเมื่อมีการรับเงินจากคลังแล้ว
- Oracle คืน `E` (error) กลางคัน → ต้อง rollback/ไม่เปลี่ยนสถานะเอกสาร + แจ้ง user

### 6.4 Regression
- เคส "โอนเงินจัดสรร" + "โอนเงินกลับ" (Accepted แล้ว) ต้องไม่พัง

---

## 7. Oracle Objects สรุป (ที่ต้องใช้/แตะ)

| Object | ชนิด | ใช้ตอนยืนยัน | ใช้ตอนยกเลิก |
|---|---|---|---|
| `OAGGL_JOURNAL_INTERFACE` | Staging table (EBS) | INSERT ขาปกติ | INSERT ขา REVERSE (batch `REVERSE_`) |
| `APPS.OAGGL_JOURNAL_INF_PKG.MAIN` | Package/SP | process batch ปกติ | process batch REVERSE (ตัวเดิม) |
| `OAGWBG_LOG_INTERFACE` | Log table (App) | log + status | log + status (ActionName=Cancel*) |
| `OAGWBG_RECEIVE_BATCH_NO` | Map table (App) | running no. | running no. ของ batch ยกเลิก |
| `REVERS_FLAG` / `X_RE_JE_*` (ในตาราง interface) | Column | ไม่ใช้ | **อาจใช้** ถ้าเลือก native reverse (ต้องยืนยัน) |
| DB View ใหม่ (เช่น `OAGWBG_V_..._CANCEL`) | View | — | deliverable "View" (ต้องยืนยันสเปค) |

---

## 8. คำถามที่ต้องการคำตอบก่อนลงมือ (Open Questions)

1. **วิธี reverse:** ใช้ **manual DR/CR swap** (ตาม precedent `REVERSE_ENC_CARRY_FORWARD`) หรือใช้ **`REVERS_FLAG`/native GL reversal** ของ package? (กระทบ logic ทั้งหมด)
2. **deliverable "View":** log เขียนว่า *"Interface ยกเลิก และ View — รอทดสอบ"* — "View" หมายถึง (ก) DB View ใหม่แสดงรายการที่ยกเลิก, (ข) หน้าจอ read-only ดูรายละเอียดเอกสารที่ยกเลิก, หรือ (ค) คอลัมน์/สถานะในตาราง list เดิม? ต้องการสเปคของแต่ละหน้าจอ
3. **สถานะเอกสารหลังยกเลิก:** ใช้ `90109` เดิม หรือเพิ่มสถานะใหม่แยก "ยกเลิก+ส่ง interface แล้ว" ออกจาก "ยกเลิก (ยังไม่เคย interface)"?
4. **เงื่อนไขห้ามยกเลิก (พ.ร.บ.):** "ยังไม่มีการบันทึกรับเงินจากคลัง" ตรวจจากตาราง/ฟิลด์ไหน? และหน้าจออื่นมีเงื่อนไขห้ามยกเลิกอะไรบ้าง (เช่น มี PO/PR ผูกพันแล้ว)?
5. **เก็บเหตุผลการยกเลิกไหม?** ต้องมี field เหตุผล + ผู้ยกเลิก + วันที่ เพื่อ audit หรือไม่?
6. **Effective Date ของ journal ยกเลิก:** ใช้วันที่ยกเลิกจริง หรือตามสเปค (บางชีทระบุ OCT ของปีงบ / 30-SEP)? ต้องยืนยันต่อหน้าจอ
7. **ขอบเขตรอบนี้:** log ระบุหลายรายการเป็น "Opened/รอทดสอบ" — จะทำครบ 6 หน้าจอในรอบเดียว หรือเรียงลำดับส่งมอบ?

---

## 9. ภาคผนวก — ไฟล์อ้างอิงหลักในโค้ด

- Engine: [`SaveInterface`](../../OAGBudget.API/Services/Repository/BudgetService.cs#L11840) / [`GetBatchStatus`](../../OAGBudget.API/Services/Repository/BudgetService.cs#L16450)
- Precedent reverse: [`SaveBudgetReserved` REVERSE block](../../OAGBudget.API/Services/Repository/BudgetService.cs#L11027)
- ตัวอย่าง confirm ครบ flow: [`ConfirmBudgetTransferAdjust`](../../OAGBudget.API/Services/Repository/BudgetService.cs#L16172)
- Model: [`OagwbgLogInterface`](../../OAGBudget.DAL/Models/OagwbgLogInterface.cs), [`OagwbgReceiveBatchNo`](../../OAGBudget.DAL/Models/OagwbgReceiveBatchNo.cs)
- API endpoints: [OAGBudget.API/Controllers/BudgetController.cs](../../OAGBudget.API/Controllers/BudgetController.cs)
- MVC proxy: [OAGBudget/Controllers/BudgetController.cs](../../OAGBudget/Controllers/BudgetController.cs)
- สเปค Interface: `OAG_Budget_View_Detail.xlsx` — ชีท `INTERFACE GL`[9], และชีท "- ยกเลิก" [11][13][19][25][27][32][33][35]

---

# ภาคผนวก B — ผลตรวจสอบจริงกับ PREPROD (2026-07-02, ต่อ VPN แล้ว)

> query ด้วย OAGWBG@ebs_PRE (172.16.11.19:1541) ผ่าน Oracle Instant Client

## 10. ผลตรวจสอบ Package / ตาราง (ตอบคำถามค้างข้อ 1 ได้แล้ว)

### 10.1 ยืนยันโครงสร้าง
- `OAGGL_JOURNAL_INTERFACE` = **TABLE ของ APPS** + **SYNONYM ของ OAGWBG** (VALID ทั้งคู่)
- `APPS.OAGGL_JOURNAL_INF_PKG` = PACKAGE + PACKAGE BODY สถานะ **VALID**
- `MAIN(P_WEB_BATCH_NO IN, X_STATUS OUT, X_MESSAGE OUT)` ✔ ตรงกับที่โค้ดเรียก
- คอลัมน์จริงชื่อ **`REVERSE_FLAG`** VARCHAR2(10) (Excel สะกดผิดเป็น `REVERS_FLAG`) + `X_RE_JE_BATCH_ID/HEADER_ID/LINE_NUM`, `INTERFACE_STATUS`, `INTERFACE_MSG`, `PROCESS_FLAG`

### 10.2 🎯 Package รองรับ Reverse ในตัว (Native) — สำคัญมาก
Package body มี logic (บรรทัด 627–633):
```
IF nvl(rec.reverse_flag,'N') = 'Y' THEN
    l_journal.reference1 := 'Revers_' || rec.reference1 || '-' || rec.ou_name;  -- BATCH_NAME
    l_journal.reference4 := 'Revers_' || rec.reference4;                        -- JOURNAL_NAME
    l_journal.entered_dr := xx_to_null(rec.entered_cr);   -- **สลับ DR/CR ให้อัตโนมัติ**
    l_journal.entered_cr := xx_to_null(rec.entered_dr);
    l_journal.accounted_dr := xx_to_null(rec.accounted_cr);
    l_journal.accounted_cr := xx_to_null(rec.accounted_dr);
```
และบรรทัด 857–868 จะ **ไปค้นหา je_batch_id/je_header_id ของ journal เดิม** (จาก `GL_JE_BATCHES_V` ด้วยชื่อ `%Revers_...%`) เพื่อเชื่อมโยงการกลับรายการ

> **สรุป: มี 2 วิธีทำ Reverse และห้ามผสมกัน**
>
> | | **วิธี A — Manual (แม่แบบที่ app ใช้อยู่)** | **วิธี B — Native (`REVERSE_FLAG='Y'`)** |
> |---|---|---|
> | ใครสลับ DR/CR | **app สลับเอง** | **package สลับให้** |
> | ตั้งชื่อ batch | app ตั้ง `REVERSE_...` เอง | package เติม `Revers_` ให้ |
> | ต้องแก้ engine `SaveInterface` | ❌ ไม่ต้อง (INSERT ไม่มีคอลัมน์ reverse_flag อยู่แล้ว) | ✅ ต้องเพิ่มคอลัมน์ `REVERSE_FLAG` + field ใน model |
> | ตรงกับสเปค Excel | ✅ (Excel โชว์ batch `REVERSE_` + ยอดที่สลับแล้ว) | ✗ (สเปคไม่ได้พูดถึง flag) |
> | ต้องรู้ je_batch_id เดิม | ไม่ต้อง | ต้อง match ได้ (เสี่ยง lookup ไม่เจอ) |
>
> ⚠️ **กับดักร้ายแรง:** ถ้า set `REVERSE_FLAG='Y'` **แล้วสลับ DR/CR เองด้วย** → package สลับซ้ำ = **กลับทิศผิด (double swap)** ยอดบัญชีผิดทั้งหมด

### 10.3 หลักฐานจาก Production (สำคัญต่อการตัดสินใจ)
1. **RF='Y' มีใช้จริง 343 แถว — แต่มาจากระบบอื่น** (batch ขึ้นต้น `GL-YYYYMMDD-...`, `encumbrance_type` ว่าง, status **S**) ⇒ เป็น feed GL อีกตัว **ไม่ใช่จาก OAG Budget web app** ⇒ ฝั่งเว็บยัง**ไม่เคย**ใช้วิธี B
2. **แม่แบบ `REVERSE_ENC_CARRY_FORWARD` ของ app (วิธี A) — ล้มเหลวใน production!** ทั้ง 2 batch ล่าสุด status = **E**
   - สาเหตุจริง: `INTERFACE_MSG = "Check Status : Date not within any period in an open enc. year"`
   - **ไม่ใช่ปัญหาการสลับ DR/CR** แต่เป็น **effective date ตกอยู่ใน period ที่ไม่เปิด (open period)** ของ encumbrance year
   - ⇒ บทเรียน: **effective date + open GL period เป็นจุดพังหลัก** ต้องออกแบบให้ถูก

### 10.4 Status Master (ยืนยันชื่อจริง จาก `OAGWBG_MASTERSTATUS`)
| Code | ชื่อ |
|---|---|
| `80201` | บันทึกการโอน (ยืนยัน/ส่ง interface แล้ว) |
| `90109` | **ยกเลิก** |
| `90110` | **ยกเลิกการกันเงิน** |

⇒ **มีสถานะ "ยกเลิก" อยู่แล้ว** แต่ปัจจุบันใช้สถานะเดียวกันทั้งกรณี "ยกเลิกที่เคยส่ง interface" และ "ยกเลิก draft ที่ยังไม่ส่ง" (ดูข้อเสนอข้อ 12.4)

---

## 11. เจาะลึก Reverse Logic — หน้าจอ "โอนปรับเปลี่ยนรายการ" (BudgetAdjust)

### 11.1 Forward ปัจจุบัน (ขายืนยัน) — ยืนยันด้วยข้อมูลจริง
มี 2 เมธอดทำงานคนละสเต็ป:

**(1) `SaveBudgetAdjust` ([10118](../../OAGBudget.API/Services/Repository/BudgetService.cs#L10118))** — ส่ง journal ประเภท **B (Budget)** 2 บรรทัด, category `Budget - เปลี่ยนแปลง`:
- LINE 1 = ผู้รับ (ค่าใหม่): **DR** = `TotalTransferAmount`
- LINE 2 = ผู้ให้ (ค่าเดิม): **CR** = `TotalTransferAmount`
- แล้ว insert `OAGWBG_BUDGETADJUST`

**(2) `ConfirmBudgetTransferAdjust` ([16172](../../OAGBudget.API/Services/Repository/BudgetService.cs#L16172))** — ส่ง journal ประเภท **E (Encumbrance)**, `TransferType='ADJUSTMENT'`, 1 บรรทัด/ผู้รับ (**DR** อย่างเดียว) แล้วเปลี่ยนสถานะ → `80201`

**ข้อมูลจริงจาก log (batch `BUDGET_ADJUST_2569_2026062513294`, docid 1884):**
```
LINE | AF | CAT                  | DR   | CR | TT         | ET             | STATUS
 1   | E  | Budget - เปลี่ยนแปลง | 60   |    | ADJUSTMENT | Web Encumbrance | S
 2   | E  | Budget - เปลี่ยนแปลง | 800  |    | ADJUSTMENT | Web Encumbrance | S
 3   | E  | Budget - เปลี่ยนแปลง | 200  |    | ADJUSTMENT | Web Encumbrance | S
```
⇒ **`ATTRIBUTE3` = document id (เต็ม 127/127 แถว)** ⇒ ใช้ join กลับหาเอกสารต้นทางได้ 100%

### 11.2 กลยุทธ์ Reverse ที่แนะนำ (แม่นและปลอดภัยที่สุด)
**"อ่าน journal เดิมที่ส่งสำเร็จ แล้วสร้างขากลับให้ตรงข้ามเป๊ะ"** แทนการคำนวณ segment ใหม่:

```
1. โหลด rows เดิมจาก OAGWBG_LOG_INTERFACE
   WHERE ATTRIBUTE3 = :docId AND WEB_BATCH_NO LIKE 'BUDGET_ADJUST_%' AND STATUS='S'
2. สำหรับแต่ละ row → clone แล้ว:
   - WebBatchNo  = "REVERSE_" + เดิม
   - Reference4/5 = "กลับรายการบัญชี_" + เดิม
   - สลับ EnteredDr↔EnteredCr, AccountedDr↔AccountedCr   (วิธี A — ไม่ set reverse_flag)
   - segment/ปี/category/ActualFlag = เดิมทุกตัว
   - DefaultEffectiveDate = **คำนวณให้ตกใน open period** (ดู 11.3)
3. SaveInterface() ทุก row  → GetBatchStatus("REVERSE_...")
4. ถ้า S → header.Transferstatusid = 90109 ; receive.Budgetreceivestatus = "90109"
```
**ข้อดี:** reverse offset ยอดเดิมเป๊ะทุกบรรทัด, ไม่ต้องคำนวณ segment rule ซ้ำ (ลดโอกาสผิด), รองรับกรณีหลายผู้รับ (1:N) อัตโนมัติ

> หมายเหตุสเปค [19]: *"ส่ง interface ต้นทาง กรณียกเลิก = ปลายทาง"* → การสลับ DR↔CR ก็คือการกลับทิศ ผู้ให้↔ผู้รับ อยู่แล้ว

### 11.3 ⚠️ Effective Date (จุดที่ทำ precedent พังมาแล้ว)
- ต้องเลือกวันที่ให้ตกใน **GL open period** ของ ledger/enc year เป้าหมาย
- ตาม Excel: ถ้าก่อน OCT → ส่งเป็น 1-OCT ของปีงบ; ถ้าหลัง → วันที่ทำรายการ
- **ต้อง validate open period ก่อนส่ง** (เช็คกับ `GL_PERIOD_STATUSES`) มิฉะนั้นได้ status E เหมือน carry-forward

### 11.4 ตาราง/Object ที่หน้าจอนี้แตะตอน Cancel
| Object | ใช้ทำอะไร |
|---|---|
| `OAGWBG_BUDGETTRANSFER` | header — อ่าน Transferno, เปลี่ยน `Transferstatusid`=90109 |
| `OAGWBG_BUDGETADJUST` | detail ผู้ให้ |
| `OAGWBG_BUDGETRECEIVE` (type J) | ผู้รับ — เปลี่ยน `Budgetreceivestatus`=90109 |
| `OAGWBG_LOG_INTERFACE` | อ่าน journal เดิม (by ATTRIBUTE3) + log ขา REVERSE |
| `OAGGL_JOURNAL_INTERFACE` (syn) | ปลายทาง EBS |
| `APPS.OAGGL_JOURNAL_INF_PKG.MAIN` | process batch REVERSE |

---

## 12. การวิเคราะห์ความเสี่ยง (Risk Analysis) — สิ่งที่ต้องระวัง

### 12.1 ความเสี่ยงระดับบัญชี (R1 — แก้คืนแพง, กระทบ GL จริง)
| # | ความเสี่ยง | ผลกระทบ | การป้องกัน |
|---|---|---|---|
| R-1 | **Double swap** (set `REVERSE_FLAG='Y'` + สลับ DR/CR เอง) | ยอด GL กลับทิศผิดทั้งก้อน | **เลือกวิธีเดียว** (แนะนำวิธี A: สลับเอง, ห้ามแตะ reverse_flag) |
| R-2 | **Effective date นอก open period** | Interface status E, กลับรายการไม่สำเร็จ แต่ user เข้าใจว่ายกเลิกแล้ว | validate open period + logic วันที่ตาม Excel; **ถ้า E ห้ามเปลี่ยนสถานะเอกสาร** |
| R-3 | **ยกเลิกซ้ำ (double cancel)** | ส่ง reverse 2 รอบ = ยอดเกิน | idempotency guard: เช็คว่ามี batch `REVERSE_...` ของ docId นี้ที่ status S แล้วหรือยัง |
| R-4 | **ยกเลิกทั้งที่มี downstream แล้ว** (เช่น พ.ร.บ. รับเงินจากคลังแล้ว / มี PO-PR ผูกพัน) | กลับรายการที่ถูกใช้ไปแล้ว → ยอดติดลบ/ไม่ตรง | **guard เงื่อนไขก่อนยกเลิก** ต่อหน้าจอ (ข้อ 12.3) |
| R-5 | **reverse ไม่ครบทุกขา** (เช่น โอนเปลี่ยนแปลงมีทั้ง B + E journal, กันเงินมี STEP1+STEP2) | บัญชีค้างข้างเดียว | reverse โดย**อ่านจาก log เดิมทุก row** (11.2) ไม่ใช่ rebuild เอง |

### 12.2 ความเสี่ยงเชิงเทคนิค / ระบบ
| # | ความเสี่ยง | การป้องกัน |
|---|---|---|
| R-6 | **Transaction atomicity**: `SaveInterface` commit ทีละ row (loop) — ถ้าพังกลางทาง reverse ค้างครึ่ง | ควร process แล้วเช็ค `GetBatchStatus` เป็น batch เดียว; ถ้า E ให้ถือว่าfail ทั้ง batch + ไม่เปลี่ยนสถานะ + มี report รายการค้าง |
| R-7 | **EBS ล่ม/VPN หลุดกลางคัน** (`isConnection` flag) | โค้ดมี branch `!isConnection` อยู่แล้ว → กำหนดพฤติกรรม offline ให้ชัด (ไม่ปลอมว่า success) |
| R-8 | **je_batch_id lookup ไม่เจอ** (เฉพาะถ้าเลือกวิธี B) | อีกเหตุผลที่แนะนำวิธี A |
| R-9 | **NLS/date format** — package sensitive ต่อ session date | `GetBatchStatus` ตั้ง NLS ให้แล้ว ✔ ใช้ path เดิม |
| R-10 | **โค้ด Service ไฟล์เดียว 24,000+ บรรทัด** — เพิ่ม 6 เมธอด reverse ยิ่งใหญ่ | แยก partial class / helper `BuildReverseFromLog(docId, prefix)` ใช้ร่วมทุกหน้าจอ ลดโค้ดซ้ำ |

### 12.3 เงื่อนไขห้ามยกเลิก (ต้อง confirm business rule ต่อหน้าจอ)
| หน้าจอ | เงื่อนไขห้ามยกเลิก (คาดการณ์ — ต้องยืนยัน) |
|---|---|
| คำของบประมาณตาม พรบ. | **มีการบันทึกรับเงินจากคลังแล้ว** (ระบุใน log ข้อ 362 ชัดเจน) |
| เบิกเงินจากกรมบัญชีกลาง | เบิกงวดถัดไป/มีการใช้จ่ายต่อแล้ว |
| โอนปรับเปลี่ยน / เหลือจ่าย | ปลายทางถูกนำไปโอน/ใช้ต่อ |
| เบิกแทน | หน่วยที่เกี่ยวข้องเบิกจ่ายจริงแล้ว |
| กันเงินเหลื่อมปี | มี PO/PR ผูกพัน หรือเบิกจ่ายในปีถัดไปแล้ว |

### 12.4 ข้อเสนอเชิงออกแบบ (ลดความเสี่ยง)
1. **แยกเส้นทางตามสถานะ:** ยกเลิกเอกสารที่ **ยังไม่เคยส่ง interface (draft)** → เปลี่ยนสถานะเฉย ๆ (เหมือนเดิม, ไม่ส่ง reverse); ยกเลิกเอกสารที่ **status=80201 (ส่งแล้ว)** → ต้องส่ง reverse
2. **แยกสถานะให้ audit ได้:** พิจารณาเพิ่มธง/ฟิลด์ระบุ "ยกเลิกแบบกลับบัญชีแล้ว" แยกจาก 90109 เดิม (หรือใช้ `OAGWBG_LOG_INTERFACE` เป็นหลักฐาน)
3. **1 helper กลาง** `BuildReverseFromLog()` + reuse `SaveInterface`/`GetBatchStatus` — **ไม่แตะ engine**
4. **ทดสอบบน PREPROD ต่อหน้าจอ** โดยตรวจ 3 อย่าง: (ก) มี REVERSE batch status S, (ข) ยอด GL สุทธิ = 0, (ค) สถานะเอกสารถูก — **ห้าม deploy PROD ก่อนครบ**

### 12.5 Scope check
- log ระบุหลายรายการเป็น **Opened/รอทดสอบ** — โอนจัดสรร/โอนกลับ **Accepted แล้ว** (ใช้เทียบได้)
- แนะนำส่งมอบทีละหน้าจอ ไล่จากที่ตรงไปตรงมา (โอนปรับเปลี่ยน) ก่อนเคสซับซ้อน (กันเงินเหลื่อมปี, พ.ร.บ. ที่มี guard พิเศษ)

---

## 13. อัปเดตคำตอบของคำถามค้าง (จากการ verify)
| ข้อ | คำถามเดิม | คำตอบจากการ verify |
|---|---|---|
| 1 | manual swap หรือ REVERS_FLAG? | **package รองรับทั้งคู่** — แนะนำ **วิธี A (manual swap, ไม่แตะ reverse_flag)** เพราะตรงสเปค Excel + ไม่ต้องแก้ engine + เลี่ยง je_batch lookup; ⚠️ ห้าม double swap |
| 3 | สถานะหลังยกเลิก | มี `90109`=ยกเลิก, `90110`=ยกเลิกการกันเงิน อยู่แล้ว — เสนอแยก draft/interfaced (12.4) |
| — | (ใหม่) ทำไม precedent carry-forward ล้มเหลว | **effective date นอก open period** ไม่ใช่ปัญหา logic — เป็น lesson สำคัญ (R-2) |

**ยังต้องถามผู้ใช้/ทีม Oracle:** สเปค "View" (ข้อ 2 เดิม), เงื่อนไขห้ามยกเลิกต่อหน้าจอ (12.3), เก็บเหตุผลยกเลิกไหม (ข้อ 5 เดิม), effective date rule ที่ถูกต้องต่อหน้าจอ (ข้อ 6 เดิม)

---

## 14. แผนปิดงาน — Task Breakdown (ต้องทำอะไรบ้างจึงจะจบ)

### PHASE 0 — ปิด Open Questions *(BLOCKER — ต้องได้คำตอบก่อนเขียนโค้ด)*
| T | งาน | ผู้ให้คำตอบ | ผลต่อ |
|---|---|---|---|
| 0.1 | เลือกวิธี reverse — **แนะนำ A (manual swap)** | ทีม dev + Oracle | logic ทั้งหมด |
| 0.2 | สเปค deliverable **"View"** ต่อหน้าจอ (DB view / หน้า read-only / คอลัมน์สถานะ) | BA/ผู้ใช้ | Phase 3 |
| 0.3 | **เงื่อนไขห้ามยกเลิก** ต่อหน้าจอ (ดู 12.3) | BA/ผู้ใช้ | guard แต่ละหน้าจอ |
| 0.4 | **effective date rule** ที่ถูกต้องต่อหน้าจอ | Oracle/บัญชี | แก้ R-2 |
| 0.5 | เก็บ **เหตุผล/ผู้ยกเลิก/สถานะ audit** แยกไหม | BA/ผู้ใช้ | DTO + สถานะ |

### PHASE 1 — Foundation *(ทำครั้งเดียว ใช้ร่วมทุกหน้าจอ — ลดโค้ดซ้ำ + คุมความเสี่ยง)*
| T | งาน | แก้ความเสี่ยง |
|---|---|---|
| 1.1 | Helper `BuildReverseFromLog(docId, srcPrefix)` — อ่าน log เดิม status S → clone + swap DR/CR + เติม `REVERSE_`/`กลับรายการบัญชี_` | R-1, R-5 |
| 1.2 | Helper `ValidateOpenPeriod(effectiveDate, ledger)` — เช็ค `GL_PERIOD_STATUSES` ก่อนส่ง | **R-2** |
| 1.3 | Helper `HasReversedAlready(docId)` — idempotency guard | R-3 |
| 1.4 | Logic แยกเส้นทาง **draft (ไม่ส่ง reverse) vs interfaced/80201 (ต้องส่ง)** | R-4 |
| 1.5 | `CancelInterfaceRequest` DTO (ถ้า 0.5 = ต้องเก็บเหตุผล) | — |
| 1.6 | จัดระเบียบ: ทำเป็น partial class `BudgetService.CancelInterface.cs` | R-10 |

### PHASE 2 — พัฒนาต่อหน้าจอ (6 หน้าจอ) *— แต่ละหน้าจอมี 6 sub-task เหมือนกัน*
> โครง sub-task/หน้าจอ: **(a)** Service `CancelXxxInterface` **(b)** API endpoint **(c)** MVC proxy **(d)** View: ปุ่ม+modal ยืนยัน+แสดงผล S/E **(e)** guard เงื่อนไข (จาก 0.3) **(f)** ทดสอบ PREPROD (ยอด GL net=0)

| ลำดับ | หน้าจอ | ความยาก | หมายเหตุ |
|---|---|---|---|
| 2.1 | **โอนปรับเปลี่ยนรายการ** | ⭐ ง่าย (มี deep-dive ข้อ 11 แล้ว) | ทำก่อนเป็น pilot |
| 2.2 | เบิกเงินจากกรมบัญชีกลาง | ⭐⭐ | `REVERSE_BUDGET_` |
| 2.3 | เบิกแทน | ⭐⭐⭐ | DR/CR ต่างตามเคส (เบิกแทน/ถูกเบิกแทน) |
| 2.4 | โอนเงินปรับเงินเหลือจ่าย | ⭐⭐ | `REVERSE_BUDGET_TRANSFER_REMAINING_` |
| 2.5 | **กันเงินเหลื่อมปี** (หน่วยงาน STEP1+STEP2 + ส่วนกลาง) | ⭐⭐⭐⭐ ยากสุด | มี 2 journal/2 ปีงบ; แก้ precedent ที่ status E อยู่ |
| 2.6 | **คำของบประมาณตาม พรบ.** | ⭐⭐⭐ | guard พิเศษ: ห้ามยกเลิกถ้ารับเงินจากคลังแล้ว |

### PHASE 3 — "View" deliverable
| T | งาน |
|---|---|
| 3.1 | สร้าง DB View / หน้าแสดงรายการที่ยกเลิก+กลับบัญชี ต่อหน้าจอ (ตาม 0.2) |
| 3.2 | ผูก View เข้าหน้า list/detail |

### PHASE 4 — ทดสอบ (ดูรายละเอียดข้อ 6)
| T | งาน |
|---|---|
| 4.1 | Unit/logic: mapping field, swap ถูกทิศ, balanced |
| 4.2 | Integration PREPROD ต่อหน้าจอ: REVERSE batch=S + **ยอด GL net=0** + สถานะเอกสารถูก |
| 4.3 | Edge cases: 1:N, เบิกแทน 2 ทิศ, กันเงิน 2 journal, พ.ร.บ. guard, EBS error → ไม่เปลี่ยนสถานะ |
| 4.4 | Regression: โอนจัดสรร/โอนกลับ (Accepted แล้ว) ไม่พัง |

### PHASE 5 — ส่งมอบ
| T | งาน |
|---|---|
| 5.1 | Build ผ่าน (0 error) → bump FileVersion |
| 5.2 | `tf get` → `tf checkin` (source code) / `git commit` (docs) |
| 5.3 | UAT sign-off ต่อหน้าจอ |
| 5.4 | Deploy PROD **(R0 — ห้ามก่อน UAT ครบทุกหน้าจอ)** |

### Critical Path & Effort
```
Phase 0 (blocker) → Phase 1 (foundation) → 2.1 pilot(pilot ผ่าน = template นิ่ง)
   → 2.2–2.6 (ขนานได้) + Phase 3 → Phase 4 → Phase 5
```
- **ถ้า Phase 0 ยังไม่ปิด = เริ่มไม่ได้** (โดยเฉพาะ 0.1 วิธี reverse, 0.4 date rule)
- Phase 1 + 2.1 เป็น **หัวใจ** — ทำ pilot ให้ผ่าน PREPROD ก่อน แล้วที่เหลือคือ apply template
- ประเมินคร่าว: 6 หน้าจอ × (service+api+mvc+view+test) + foundation + view deliverable — **งานหลักอยู่ Service layer + การทดสอบ PREPROD ต่อหน้าจอ**

---

## 15. ✅ แก้ R-2 (Open Period) แล้ว — กติกา Effective Date ที่ verify จริง (2026-07-02)

### 15.1 สาเหตุที่ precedent พัง (พิสูจน์แล้ว)
- `latest_encumbrance_year` ของ `OAG Ledger` (ledger_id=**2024**) = 2027 **แต่** period ที่เปิดจริงต่างกันตาม application:

| Application | ใช้กับ actual_flag | ช่วงที่ OPEN (verify) |
|---|---|---|
| **GL (101)** | **B** (Budget) | 2019-10 → **2027-09-30** (เปิดยาว) |
| **PO (201)** | **E** (Encumbrance) | 2024-10 → **2026-08-31 (AUG-26)** ← ตัวจำกัด |

- Precedent `REVERSE_ENC_CARRY_FORWARD` ส่ง journal **E** วันที่ **1-OCT-2026** → OCT-26 เปิดใน GL แต่ **ไม่เปิดใน PO(201)** ⇒ error *"Date not within any period in an open enc. year"* ← **นี่คือสาเหตุ ไม่ใช่ logic swap**

### 15.2 กติกา `ValidateOpenPeriod` (พร้อมใช้)
```
ถ้า actual_flag = 'B'  → effective date ต้องอยู่ใน GL period ที่เปิด (application_id=101, closing_status='O')
ถ้า actual_flag = 'E'  → effective date ต้องอยู่ในช่วงที่ PO เปิด (application_id=201, closing_status='O')
กติกา clamp: ถ้า date ที่ต้องการ > boundary ที่เปิด → ใช้ปลายงวดที่เปิดล่าสุด (หรือ SYSDATE ถ้า SYSDATE เปิด)
              ห้ามส่ง date เกิน boundary เด็ดขาด
```

**SQL ตรวจว่า date เปิดไหม (ใช้ก่อน SaveInterface ทุกครั้ง):**
```sql
SELECT COUNT(*)                       -- >0 = เปิด, ส่งได้
FROM   apps.gl_period_statuses
WHERE  ledger_id = 2024
   AND application_id = CASE :actual_flag WHEN 'E' THEN 201 ELSE 101 END
   AND closing_status = 'O'
   AND :eff_date BETWEEN start_date AND end_date;
```

**SQL หา boundary (ไว้ clamp date):**
```sql
SELECT MAX(end_date)
FROM   apps.gl_period_statuses
WHERE  ledger_id = 2024
   AND application_id = CASE :actual_flag WHEN 'E' THEN 201 ELSE 101 END
   AND closing_status = 'O';
```

### 15.3 ผลต่อการออกแบบ cancel
- การกลับรายการ (โดยเฉพาะขา **E**) **ต้อง validate/clamp effective date** ก่อนส่งเสมอ (ไม่งั้นซ้ำรอย precedent)
- **ก่อน enable ปุ่มยกเลิก** ควรเช็ค boundary → ถ้า date ที่จำเป็น (เช่น OCT ปีถัดไป) ยังไม่เปิด encumbrance period → **แจ้ง user / บล็อก** แทนที่จะส่งแล้ว error
- ค่าคงที่ที่ยืนยันแล้ว: `ledger_id=2024` (OAG Ledger), GL=app 101, Encumbrance=app 201
- ⚠️ boundary เลื่อนตามการเปิด/ปิดงวดของฝ่ายบัญชี — **ต้อง query สด ห้าม hardcode วันที่**
