# Roadmap v2: โอนจัดสรรเพิ่มเติม (BudgetAllocateTransferMore)

**Version:** 2.5
**วันที่:** 2026-07-27
**สถานะ:** ✅ Analysis เสร็จ (Q1-12) → 🔨 **Implementation เสร็จ Phase 5.0-5.7 แล้ว กำลังทดสอบบน PREPROD** — พบและแก้บั๊กหลายจุด ดู §11
**อ้างอิง:** `prompt_budgetallocatetransfermore_2.md`, `issue_budgetallocatetransfermore.md`, `roadmap_budgetallocatetransfermore.md` (v1.1)
**Prototype:** `prototype_budgetallocatetransfermore_2.html` (เปิดด้วย browser)

> ⚠️ ส่วน §1-10 ด้านล่างเป็นเอกสาร**วิเคราะห์ก่อนเริ่มพัฒนา** (2026-07-20) — เก็บไว้ตามเดิมเพื่ออ้างอิงประวัติการตัดสินใจ (Q1-12)
> ส่วน **§11 (ใหม่)** คือบั๊ก/ข้อค้นพบจริงที่เจอระหว่าง implement + ทดสอบบน PREPROD (2026-07-22 ถึง 2026-07-27)

---

## 1. สรุปผู้บริหาร (Executive Summary)

Feature นี้ถูกพัฒนาไปแล้ว (roadmap v1 — Phase 1-3 เสร็จ, build ผ่าน) แต่ **UI/UX ยังไม่ตรงกับ requirement** ที่ระบุใน prompt_2

จุดสำคัญที่สุด: โค้ดปัจจุบันเข้าใจผิดว่ารายการจากคำขอ = "รายการโอนออก" (ตารางชื่อ *รายการโอนออก* แสดงรายการคำขอตรงๆ แถวเดียว)
แต่ requirement จริงคือ **1 รายการคำขอ (รับโอน) = แถวแม่ / รายการโอนออกที่ผู้ใช้เลือก = แถวลูก** — เป็นโครงสร้าง 2 ระดับแบบเดียวกับหน้าโอนจัดสรรปกติ

**ขนาดงาน:** UI layer ต้องรื้อค่อนข้างมาก (~70% ของ `BudgetAllocateTransferMoreDetail.cshtml`), Service layer แก้ปานกลาง, DB ต้องเพิ่ม 1 ตาราง + 1 view (tab ศูนย์ต้นทุน)

---

## 2. เปรียบเทียบ Flow: โอนจัดสรร (เดิม) vs โอนจัดสรรเพิ่มเติม (ใหม่)

| # | Budget Allocate Transfer (โอนเงินจัดสรรงบประมาณ) | Budget Allocate Transfer More (โอนจัดสรรเพิ่มเติม) | เหมือน/ต่าง |
|---|---|---|---|
| 1 | กด "เลือกรายการงบประมาณ" → modal | กด "เลือกรายการคำขอ" → modal | 🟡 คล้าย (แหล่งข้อมูลต่างกัน) |
| 2 | dropdown **แหล่งเงิน (เงินกัน)** → ค้นหา → เลือก **1 รายการ** ด้วย checkbox → "เลือกรายการที่เลือก" | dropdown **เลขที่คำขอ** → ค้นหา → **"เลือกทั้งหมด"** (ไม่มี checkbox รายแถว) | 🔴 ต่าง |
| 3 | expand ประเภทค่าใช้จ่าย → ตรวจสอบ → บันทึก | แสดงรายการทั้งหมดในคำขอ (= รายการ**รับโอน**) | 🔴 ต่าง |
| 4 | กด `btn-select-transfer-account` → modal บัญชีรับโอน → dropdown เลขที่ → **เลือกจากรายการที่มีอยู่** (มีค้นหา + checkbox) | กด `btn-select-transfer-account` (แสดงหลัง save เท่านั้น) → modal บัญชีรับโอน → **ฟอร์มเพิ่มรายการใหม่ล้วน** (ไม่มีค้นหา ไม่มีรายการให้เลือก — กรอกแหล่งเงิน/หน่วยเบิกจ่าย/ศูนย์ต้นทุน/แผนงาน/ผลผลิต/กิจกรรม/รายการ/รหัสงบ แล้วกด "เพิ่มรายการใหม่" ได้หลายครั้ง) | 🟡 **คล้ายแค่ trigger (ปุ่ม 🏛) — เนื้อหา modal ต่างกัน** |
| 5 | ปุ่ม chevron `btn-toggle-children` → expand **รายการโอนออก** → บันทึก | ปุ่ม chevron → expand **รายการโอนออก** (Level ลูก) → บันทึก | 🟢 **เหมือน — reuse pattern ได้** |
| 6 | ปุ่ม "แก้ไขรายละเอียด" → หน้า `BudgetAllocateTransferCostCenter` → เลือกศูนย์ต้นทุน → เพิ่มรายการ → กรอกยอด → บันทึก → กลับ | ❌ **ไม่มีขั้นตอนนี้** — ศูนย์ต้นทุนถูกกำหนดมาแล้วจากคำขอ | 🔴 ตัดออก |
| 7 | เห็นยอดงบประมาณจัดสรรเพิ่มในตาราง | **ยอดคำขอ** (แถวแม่) fix จากคำขอ / **งบประมาณจัดสรร** (แถวลูก) กรอกได้ | 🟡 คล้าย |
| 8 | tab "รายชื่อศูนย์ต้นทุนที่โอนจัดสรร" → เลือกบัญชีผู้โอน/ผู้รับโอน → บันทึก | tab เดียวกัน → เลือกบัญชีผู้โอน/ผู้รับโอน → บันทึก | 🟢 **เหมือน — reuse pattern ได้** |

### ข้อสรุปเชิงสถาปัตยกรรม

```
โอนจัดสรรปกติ:  เลือกงบต้นทาง (โอนออก) → กระจายไปศูนย์ต้นทุนปลายทาง (รับโอน)   [ต้นทาง → ปลายทาง]
โอนจัดสรรเพิ่มเติม: เลือกคำขอปลายทาง (รับโอน) → ระบุงบต้นทางที่จะตัด (โอนออก)   [ปลายทาง → ต้นทาง]  ← ทิศทางกลับกัน
```

นี่คือเหตุผลที่ขั้นตอนที่ 6 (หน้า CostCenter) หายไป และทำไมยอดคำขอถึง fix

> **สรุป:** ขั้นตอนที่ 5, 8 **เหมือนหน้าโอนจัดสรรปกติ** — reuse pattern ได้โดยตรง (chevron/tree, tab ศูนย์ต้นทุน)
> ขั้นตอนที่ 4 **เหมือนแค่ trigger** (ปุ่ม 🏛 `btn-select-transfer-account` แสดงหลัง save) แต่เนื้อหา modal **ต่างกันโดยสิ้นเชิง** — หน้าโอนจัดสรรปกติเป็น modal ค้นหา+เลือกจากรายการที่มีอยู่, ส่วนโอนจัดสรรเพิ่มเติมเป็น**ฟอร์มเพิ่มรายการใหม่ล้วน** ไม่มีค้นหา ไม่มีรายการให้เลือก (ผู้ใช้ระบุ หน่วยเบิกจ่าย/ศูนย์ต้นทุน/แผนงาน/ผลผลิต/กิจกรรม/รายการ/รหัสงบ เองทั้งหมด แล้วกด "+ เพิ่มรายการใหม่" ทีละแถว)
> ที่ต่างเพิ่มเติม: ① แหล่งข้อมูลตั้งต้น (คำขอ แทน งบประมาณต้นทาง) ② การจัดกลุ่ม 2 ระดับ (เลขที่คำขอ → แหล่งเงิน) ③ ตัดขั้นตอนที่ 6 ออก

---

## 3. Gap Analysis — โค้ดปัจจุบัน vs Requirement

ไฟล์หลักที่ตรวจ: [BudgetAllocateTransferMoreDetail.cshtml](../../OAGBudget/Views/Budget/BudgetAllocateTransferMoreDetail.cshtml)

| # | Requirement (prompt_2) | สถานะปัจจุบัน | ต้องแก้ |
|---|---|---|---|
| G-1 | เปิดหน้าใหม่ต้องยังไม่แสดง section รายการโอนออก (issue ข้อ 1) | แสดงตารางตลอด (บรรทัด 145-188) | ครอบด้วย `@if (!isNew)` |
| G-2 | modal ค้นหาด้วย **dropdown เลขที่คำขอ** | มีแต่ input ปีงบประมาณ (บรรทัด 200-204) | เพิ่ม dropdown + endpoint ดึงเลขที่คำขอ |
| G-3 | ปุ่ม **"เลือกทั้งหมด"** ระดับ modal ไม่มี checkbox รายแถว | มีปุ่ม "เลือก" ต่อแถว → `selectRequest(id)` (บรรทัด 376) | เปลี่ยนเป็นปุ่มเดียวใน modal-footer |
| G-3b | **column ใน modal เลือกคำขอ** ต้องเป็น แหล่งเงิน / แผนงาน / ผลผลิต / กิจกรรม / รายการ / รหัสงบ / ยอดคำขอ | มี เลขที่คำขอ / หน่วยเบิกจ่าย / ศูนย์ต้นทุน (บรรทัด 214-222) | **ตัด 3 column ออก** แล้วแทนด้วย แหล่งเงิน/แผนงาน/ผลผลิต/กิจกรรม แยก column |
| G-4 | ตารางต้องจัดกลุ่ม **2 ระดับ: เลขที่คำขอ → แหล่งเงิน** แล้วจึงเป็นแถวแม่ (รับโอน) / แถวลูก (โอนออก) + chevron | ตาราง flat ไม่มี group header (บรรทัด 310-322) | รื้อ `renderItems()` เป็น group 2 ระดับ + tree 2 ชั้น |
| G-4b | **column ตารางหลัก** = ศูนย์ต้นทุน / ผลผลิต / กิจกรรม / รายการงบประมาณ / รหัสงบประมาณ / ยอดคำขอ / งบประมาณจัดสรร | ใช้ แผนงาน/ผลผลิต/กิจกรรม/รายการ/รหัสงบ/ยอดที่ขอ/แหล่งเงิน/ยอดโอน (บรรทัด 161-172) | ปรับ column ตามภาพ (ตัด แผนงาน + แหล่งเงิน ออก — ย้ายไปเป็น group header) |
| G-5 | ⭐ **ปุ่ม `btn-select-transfer-account` (ไอคอน 🏛)** ที่แถวแม่ → เปิด **modal บัญชีรับโอน** → เกิดแถวลูก | ใช้ปุ่ม ✎ `openTransferOut(idx)` เปิด modal กรอกฟอร์ม (บรรทัด 306, 421-433) | **สร้าง trigger ใหม่** ให้เป็นปุ่ม 🏛 gate ด้วย `isSavedItem` (pattern trigger เดียวกับ [BudgetAllocateTransferDetail.cshtml:1746-1756](../../OAGBudget/Views/Budget/BudgetAllocateTransferDetail.cshtml#L1746-L1756)) แต่**เนื้อหา modal ต้องเขียนใหม่** — ไม่ reuse modal ค้นหา/checkbox ของหน้าเดิม |
| G-5b | ⭐ ปุ่ม 🏛 **แสดงเฉพาะหลังบันทึกครั้งที่ 1** (ตามภาพ กรอบเขียว) | ปุ่มแสดงตลอด | gate ด้วย `isSavedItem = item.id !== 0` (เหมือนหน้าโอนจัดสรรปกติ) |
| G-5c | ⭐ **Modal บัญชีรับโอน = ฟอร์มเพิ่มรายการใหม่ล้วน** — ไม่มีปุ่มค้นหา ไม่มีตารางรายการให้เลือก มีแต่ dropdown กรอกทุก field (แหล่งเงิน/หน่วยเบิกจ่าย/ศูนย์ต้นทุน/แผนงาน/ผลผลิต/กิจกรรม/รายการ/รหัสงบ) + ปุ่ม "+ เพิ่มรายการใหม่" กดซ้ำได้หลายครั้ง | ❌ ไม่มี (เดิมเป็นฟอร์มกรอกแบบง่าย 234-280) | เขียน modal ใหม่ทั้งหมด — **ห้าม copy** modal ค้นหา+checkbox จากหน้าโอนจัดสรรปกติ ([BudgetAllocateTransferDetail.cshtml:2285](../../OAGBudget/Views/Budget/BudgetAllocateTransferDetail.cshtml#L2285)) เพราะ requirement ต่างกัน — ดู prototype v2.1 modal 2 |
| G-6 | **แหล่งเงิน 100 ไม่ fix** — ผู้ใช้เลือกหน่วยเบิกจ่าย/ศูนย์ต้นทุนเอง (ตอบ Q-1) | hardcode `2900600000`/`2906999999` ทั้ง UI (บรรทัด 456-458) และ Service ([:18154](../../OAGBudget.API/Services/Repository/BudgetService.cs#L18154), [:18190](../../OAGBudget.API/Services/Repository/BudgetService.cs#L18190)) | 🔴 **ลบ hardcode ทั้ง 3 จุด** |
| G-7 | **ยอดคำขอ (แถวแม่) fix แก้ไม่ได้** แต่ **งบประมาณจัดสรร (แถวลูก) แก้ไขได้** | มีช่องเดียวให้กรอก `#txtTransferAmount` ที่ระดับแม่ (บรรทัด 268-271) | ยอดคำขอ → readonly ที่แม่ / เพิ่ม input ที่แถวลูก + validate ผลรวมลูก ≤ ยอดคำขอ |
| G-8 | tab "รายชื่อศูนย์ต้นทุนที่โอนจัดสรร" + บัญชีผู้โอน/ผู้รับโอน | ❌ **ไม่มีเลย** | สร้างใหม่ทั้ง tab + DB table + API |
| G-9 | ปุ่ม **"อัพเดทงบประมาณ"** ที่หัวตาราง | ❌ ไม่มี | เพิ่ม (reuse `updateBudgetTransfer()` จากหน้าโอนจัดสรรปกติ) |
| G-10 | ไม่ต้องมีปุ่ม "แก้ไขรายละเอียด" (ไม่มีหน้า CostCenter) | ไม่มีอยู่แล้ว ✅ | — |
| G-11 | Header และตาราง/tabs รายการ ต้องอยู่**การ์ดเดียวกัน** (ปุ่มบันทึก/ยืนยัน/กลับหน้าหลัก ที่ card-footer ล่างสุด) | แยกเป็น **2 การ์ด** — การ์ด Header (บรรทัด 33-142, มี card-footer ของตัวเอง) + การ์ดตาราง (บรรทัด 145-188) | รวมเป็นการ์ดเดียว — ย้าย tabs เข้าไปอยู่ใน card-body เดียวกับ Header |

### ⭐ ความเข้าใจสำคัญที่เพิ่งชัดเจน: `btn-select-transfer-account` คืออะไร

ชื่อปุ่มทำให้เข้าใจผิดได้ — ในหน้าโอนจัดสรรปกติ ปุ่มนี้ (ไอคอน `fa-building-columns` 🏛)
**ไม่ได้ใช้เลือกเลขบัญชีธนาคาร** แต่คือปุ่มเปิด modal ชื่อ "บัญชีรับโอน" เพื่อ **เลือกรายการงบประมาณต้นทางที่จะโอนออก**
เมื่อเลือกเสร็จจะเกิด**แถวลูก** และปุ่ม chevron `btn-toggle-children` จะโผล่ขึ้นมา
(ดู prompt_2 §"Step ของ Budget Allocate Transfer" ข้อ 4-5 และโค้ด [BudgetAllocateTransferDetail.cshtml:1746](../../OAGBudget/Views/Budget/BudgetAllocateTransferDetail.cshtml#L1746))

ส่วนการเลือก**เลขบัญชีธนาคารจริง** (ผู้โอน/ผู้รับโอน) อยู่ที่ **tab 2** เท่านั้น

---

## 4. Oracle Tables / Views / Function ที่เกี่ยวข้อง

### 4.1 มีอยู่แล้ว (สร้างใน Phase 1 — PREPROD ✅ / PROD ❌)

| Object | บทบาท | สถานะ |
|---|---|---|
| `OAGWBG_BUDGETALLOCATETRANSFERMORE` | Header ใบโอนจัดสรรเพิ่มเติม | ✅ PREPROD |
| `OAGWBG_BUDGETALLOCATETRANSFERMORE_CATEGORY` | รายการ (ปัจจุบันเก็บทั้งรับโอน+โอนออกปนกัน) | ✅ PREPROD |
| `OAGWBG_V_BUDGETALLOCATETRANSFERMORE` | View Header | ✅ PREPROD |
| `OAGWBG_V_BUDGETALLOCATETRANSFERMORE_CATEGORY` | View Category | ✅ PREPROD |

### 4.2 ตารางอ้างอิง (Read-only)

| Object | บทบาท |
|---|---|
| `OAGWBG_V_BUDGETREQUEST` | คำขอ — filter `Budgetformtypeid=3 AND IS_COSTCENTER=1 AND Statusid=20101 AND Rn IS NULL` |
| `OAGWBG_V_BUDGETGOVERNMENT` | รายการในคำขอ — filter `Budgetstatus='C' AND IS_APPROVE=1` |
| `OAGWBG_BUDGETRECEIVE` | รายการรับโอน + ยอดต้นทางที่ถูกตัดตอนยืนยัน |
| `OAGWBG_V_EXT_OAGCE_BANK_ACCOUNT_V` | Dropdown บัญชีผู้โอน/ผู้รับโอน |
| `OAGWBG_FN_GETBUDGET_ALLOCATE_TRANSFER_CATEGORY` | Function ดึง balance ต้นทาง (ใช้ใน modal โอนออกกรณีแหล่งเงิน ≠ 100) |

> **ไม่มี Stored Procedure** และ **ไม่มี Temp table** สำหรับ confirm/cancel — business logic ทั้งหมดอยู่ใน `BudgetService.cs` และใช้ transaction ของ EF Core

### 4.3 ⭐ ต้องสร้างใหม่ (สำหรับ G-8 tab ศูนย์ต้นทุน)

```sql
-- mirror จาก OAGWBG_BUDGETALLOCATETRANSFER_COSTCENTER
CREATE TABLE OAGWBG.OAGWBG_BUDGETALLOCATETRANSFERMORE_COSTCENTER (
    ID                           NUMBER(10) NOT NULL,
    BUDGETALLOCATETRANSFERMOREID NUMBER(10) NOT NULL,
    DEPARTMENTID                 VARCHAR2(20),
    COSTCENTERID                 VARCHAR2(20),
    BUDGETSOURCEID               VARCHAR2(3),
    PLANID                       VARCHAR2(150),
    EXPENSETYPEID                VARCHAR2(150),
    TOTALRECEIVEAMOUNT           NUMBER(38,2),
    BANKACCOUNTGIVERID           NUMBER(15),   -- บัญชีผู้โอน
    BANKACCOUNTID                NUMBER(15),   -- บัญชีผู้รับโอน
    NOTE                         VARCHAR2(4000),
    CREATEBY   NUMBER(10) DEFAULT -1,
    CREATEON   TIMESTAMP(6) DEFAULT SYSTIMESTAMP,
    UPDATEBY   NUMBER(10),
    UPDATEON   TIMESTAMP(6),
    CONSTRAINT PK_BATM_COSTCENTER PRIMARY KEY (ID),
    CONSTRAINT FK_BATM_CC_HEADER FOREIGN KEY (BUDGETALLOCATETRANSFERMOREID)
        REFERENCES OAGWBG.OAGWBG_BUDGETALLOCATETRANSFERMORE(ID)
);
CREATE SEQUENCE OAGWBG.SEQ_BATM_COSTCENTER START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- View สำหรับแสดงพร้อมชื่อ (join MASTERDEPARTMENT / MASTERCOSTCENTER / MASTERPLAN)
CREATE OR REPLACE VIEW OAGWBG.OAGWBG_V_BUDGETALLOCATETRANSFERMORE_COSTCENTER AS ...
```

### 4.4 ⭐ ต้องเพิ่ม column ใน `..._CATEGORY` (สำหรับ G-4 tree)

ปัจจุบันตารางมี `REF` (→ `BUDGETGOVERNMENT.ID`) แต่ไม่มีทางแยกว่าแถวไหน "รับโอน" แถวไหน "โอนออก"

**แนวทางที่แนะนำ — mirror แบบหน้าโอนจัดสรรปกติ (self-reference):**

```sql
ALTER TABLE OAGWBG.OAGWBG_BUDGETALLOCATETRANSFERMORE_CATEGORY
    ADD PARENTID NUMBER(10);          -- NULL = แถวแม่ (รับโอน), มีค่า = แถวลูก (โอนออก)
ALTER TABLE OAGWBG.OAGWBG_BUDGETALLOCATETRANSFERMORE_CATEGORY
    ADD ROWTYPE  VARCHAR2(1);         -- 'R' = รับโอน, 'O' = โอนออก  (optional แต่ query ง่ายกว่า)
COMMENT ON COLUMN ...PARENTID IS 'FK → ตัวเอง (ID) — แถวโอนออกชี้ไปแถวรับโอน';
```

> หน้าโอนจัดสรรปกติใช้ field `ref` เป็น self-reference (ดู `BudgetAllocateTransferDetail.cshtml:1717` — `c.ref === item.id`)
> แต่ที่นี่ `REF` ถูกใช้ชี้ไป `BUDGETGOVERNMENT.ID` แล้ว จึงต้องเพิ่ม column ใหม่ ห้ามใช้ `REF` ซ้ำ

---

## 5. Flow ปัจจุบัน (UI → Controller → API → DAL → DB) และสิ่งที่ต้องเปลี่ยน

### 5.1 Flow ปัจจุบัน

```
[BudgetAllocateTransferMoreDetail.cshtml]
  │
  ├─ btnAddRequest → GET Budget/GetBudgetRequestMoreForTransfer?budgetyear=
  │    → API GetBudgetRequestMoreForTransfer
  │    → BudgetService.cs:18043  → OAGWBG_V_BUDGETREQUEST
  │
  ├─ selectRequest(id) → GET Budget/GetBudgetGovernmentByRequestId/{id}
  │    → BudgetService.cs:18062  → OAGWBG_V_BUDGETGOVERNMENT
  │    → push เข้า itemList (flat) → renderItems()
  │
  ├─ openTransferOut(idx) → modal → เขียนค่ากลับเข้า itemList[idx] ตรงๆ
  │
  ├─ btnSave → POST SaveBudgetAllocateTransferMoreDetail
  │    → BudgetService.cs:18076 SaveBudgetAllocateTransferMoreDetail()
  │       ├─ upsert OAGWBG_BUDGETALLOCATETRANSFERMORE (header) + ResolveRoundNoAsync
  │       └─ SaveBudgetAllocateTransferMoreCategory() :18137
  │            CollectionHelper.SaveCollectionAsync → 1 row ต่อ 1 รายการคำขอ
  │            (hardcode dept/cc = 2900600000/2906999999 เมื่อ source=100 — :18154)
  │
  └─ btnConfirm → ConfirmBudgetAllocateTransferMore() :18204
       → ตัดยอด OAGWBG_BUDGETRECEIVE + เปลี่ยนสถานะ 80201
```

### 5.2 สิ่งที่ต้องเปลี่ยนในแต่ละ Layer

| Layer | ไฟล์ | สิ่งที่ต้องเปลี่ยน |
|---|---|---|
| **DB** | Oracle | ① สร้าง `..._COSTCENTER` table + view (§4.3)  ② เพิ่ม `PARENTID` + `ROWTYPE` ใน `..._CATEGORY` (§4.4)  ③ รัน DDL Phase 1 ทั้งหมดบน **PROD** (ยังไม่ได้รัน) |
| **DAL** | `OAGBudget.DAL\Models\` | ① `OagwbgBudgetallocatetransfermorecategory.cs` — เพิ่ม `Parentid`, `Rowtype`  ② สร้าง `OagwbgBudgetallocatetransfermoreCostcenter.cs` + `OagwbgVBudgetallocatetransfermoreCostcenter.cs`  ③ ลงทะเบียน DbSet + entity config ใน `MOENDBContextBase.cs` |
| **Models** | `OAGBudget.Models\` | ① `BudgetAllocateTransferMoreDetailViewModel.cs` — เพิ่ม `CostCenterList`  ② `BudgetAllocateTransferMoreDetailModel.cs` — เพิ่ม `CostCenterList` สำหรับ save  ③ เพิ่ม DTO ของรายการโอนออก (plan/product/activity/category/budgetcode) |
| **API Service** | `OAGBudget.API\Services\Repository\BudgetService.cs` | ① `GetBudgetAllocateTransferMoreDetail` (:18028) — โหลด CostCenterList เพิ่ม  ② `SaveBudgetAllocateTransferMoreCategory` (:18137) — รองรับ parent/child 2 ระดับ + **เลิก hardcode dept/cc** (:18154, :18190) ตาม Q-1  ③ **method ใหม่** `GetBudgetRequestCodeList()` (dropdown เลขที่คำขอ)  ④ **method ใหม่** `SaveBudgetAllocateTransferMoreCostCenter()`  ⑤ **method ใหม่** `GenerateCostCenterRowsFromCategory()` — สร้างแถว tab 2 อัตโนมัติจาก category (group by source/plan/expensetype)  ⑥ `ConfirmBudgetAllocateTransferMore` (:18204) — ตัดยอดจากแถว **ลูก (โอนออก)** เท่านั้น ไม่ใช่ทุกแถว |
| **API Controller** | `OAGBudget.API\Controllers\BudgetController.cs` | เพิ่ม 3 endpoint: `GetBudgetRequestCodeList`, `GetBudgetAllocateTransferMoreCostCenter/{id}`, `SaveBudgetAllocateTransferMoreCostCenter` |
| **MVC Controller** | `OAGBudget\Controllers\BudgetController.cs` | ① ผ่าน 3 action ใหม่ตามข้างบน  ② `BudgetAllocateTransferMoreDetail(id)` — โหลด `ViewBag.DropdownBankAccount`, `DropdownRecieveBankAccount`, `DropdownDepartment`, `DropdownCostCenter`, `DropdownPlan`, `DropdownProduct`, `DropdownActivity`, `DropdownBudgetCode` |
| **View** | `BudgetAllocateTransferMoreDetail.cshtml` | รื้อตาม G-1…G-8 (§3) — ดูรายละเอียด §6 |

---

## 6. แผนแก้ไข View (ละเอียด)

| ส่วน | บรรทัดปัจจุบัน | การแก้ |
|---|---|---|
| การ์ด Header (33-142) + การ์ดตารางรายการ (145-188) | 33-188 | 🔴 **รวมเป็นการ์ดเดียว** (G-11) — ย้าย tabs+ตาราง เข้าไปอยู่ใน `card-body` เดียวกับ Header, ปุ่ม บันทึก/ยืนยัน/กลับหน้าหลัก อยู่ที่ `card-footer` ล่างสุดของการ์ดเดียว (pattern เดียวกับ [BudgetAllocateTransferDetail.cshtml](../../OAGBudget/Views/Budget/BudgetAllocateTransferDetail.cshtml) ที่ Header+Tabs อยู่ในการ์ดเดียวกันอยู่แล้ว) + ครอบ tabs ด้วย `@if (!isNew)` (G-1) + ปรับ column ตาม G-4b + เพิ่มปุ่ม "อัพเดทงบประมาณ" (G-9) |
| Modal เลือกคำขอ | 191-232 | เพิ่ม dropdown เลขที่คำขอ (G-2), ย้ายปุ่มเป็น "เลือกทั้งหมด" ที่ modal-footer (G-3), เปลี่ยน column ตาม G-3b |
| Modal โอนออก (ฟอร์มกรอก) | 234-280 | 🔴 **ทิ้งทั้งบล็อก** — แทนด้วย **modal บัญชีรับโอน = ฟอร์มเพิ่มรายการใหม่ล้วน** (ไม่มีค้นหา ไม่มีตาราง/checkbox ให้เลือกจากรายการเดิม) มี dropdown แหล่งเงิน/หน่วยเบิกจ่าย/ศูนย์ต้นทุน/แผนงาน/ผลผลิต/กิจกรรม/รายการ/รหัสงบ + ปุ่ม "+ เพิ่มรายการใหม่" กดซ้ำได้ (ดู prototype v2.1 modal 2 — **เขียนใหม่ทั้งหมด ห้าม copy modal ค้นหา+checkbox ของหน้าโอนจัดสรรปกติ**) |
| `renderItems()` | 289-328 | เขียนใหม่: group **เลขที่คำขอ → แหล่งเงิน** แล้วต่อด้วย tree แม่/ลูก — **copy pattern จาก [BudgetAllocateTransferDetail.cshtml:1713-1868](../../OAGBudget/Views/Budget/BudgetAllocateTransferDetail.cshtml#L1713-L1868)** (`ref-child` / `btn-toggle-children`) เฉพาะโครง tree/toggle เท่านั้น |
| `selectRequest()` | 387-418 | เปลี่ยนเป็น `selectAllRequests()` รับทุกรายการในคำขอ |
| `openTransferOut()` / `btnConfirmTransferOut` | 421-465 | 🔴 **ลบทิ้ง** — แทนด้วย `openAddOut(itemId)` (เปิด modal + reset ฟอร์ม) และ `addNewOut()` (validate ครบทุกช่อง → push แถวลูกเข้า `item.children[]` → re-render โดย modal ยังเปิดค้างไว้ให้กรอกรายการถัดไป) |
| hardcode dept/cc = 100 | 456-458 | 🔴 **ลบ** ตาม Q-1 — ทุกแหล่งเงินใช้ dropdown หน่วยเบิกจ่าย/ศูนย์ต้นทุนในฟอร์มเพิ่มรายการใหม่เดียวกัน |
| payload `CategoryList` | 492-507 | ส่ง 2 ระดับ (แถวแม่ + แถวลูกพร้อม `Parentid`, `Rowtype`) |
| **ใหม่** tab ศูนย์ต้นทุน | — | copy pattern จาก [BudgetAllocateTransferDetail.cshtml:296-500](../../OAGBudget/Views/Budget/BudgetAllocateTransferDetail.cshtml#L296-L500) (group by source→plan→expensetype + 2 dropdown บัญชี) |

---

## 7. ✅ คำตอบที่ได้รับ (2026-07-20)

| # | คำถาม | คำตอบ | ผลต่อการพัฒนา |
|---|---|---|---|
| **Q-1** | แหล่งเงิน 100 — หน่วยเบิกจ่าย/ศูนย์ต้นทุน fix หรือไม่? | ✅ **ไม่ fix** | 🔴 ลบ hardcode `2900600000`/`2906999999` ออกทั้ง 3 จุด (View บรรทัด 456-458, Service [:18154](../../OAGBudget.API/Services/Repository/BudgetService.cs#L18154) และ [:18190](../../OAGBudget.API/Services/Repository/BudgetService.cs#L18190)) — **ยกเลิก roadmap v1 §5.2 และ §10.4** ผู้ใช้เลือกเองทุกแหล่งเงิน |
| **Q-2** | ยอดโอนออก fix เท่ายอดคำขอ หรือแบ่งได้? | ✅ **"ยอดคำขอ" = ยอดของแต่ละรายการในคำขอ** (ระดับ item ไม่ใช่ระดับใบคำขอ) | แถวแม่แสดง `ยอดคำขอ` readonly / แถวลูกมี input `งบประมาณจัดสรร` แก้ได้ → รองรับ **1 รับโอน : N โอนออก** + validate ผลรวมลูก ≤ ยอดคำขอของ item นั้น |
| **Q-3** | แถวศูนย์ต้นทุนใน tab 2 มาจากฝั่งไหน? | ✅ **จาก list ศูนย์ต้นทุนของรายการรับโอน** | สร้างแถวจากศูนย์ต้นทุนฝั่ง**รับโอน** (คำขอ) ไม่ใช่ฝั่งโอนออก |
| **Q-4** | บัญชีผู้โอน/ผู้รับโอน บันทึกระดับใด? | ✅ **ระดับศูนย์ต้นทุน** | ตาราง `..._COSTCENTER` ตาม §4.3 ใช้ได้ตามที่ออกแบบไว้ (unique: transferMoreId + costcenter + source + plan + expensetype) |
| **Q-5** | "ยืนยันรายการ" ที่หน้าขอรับจัดสรรเพิ่มเติม ทำเมื่อไหร่? | ✅ **ทำก่อนโอนจัดสรร** | ยังเป็น **prerequisite ที่บล็อกการทดสอบ** (R-6) — ต้องมี UI ให้ติ๊ก `IS_APPROVE` ก่อน Phase 5.7 |

### ✅ คำตอบรอบใหม่ (Q-6 ถึง Q-11, 2026-07-20 — Q-12 ดูใน "ข้อค้นพบสำคัญ" ด้านล่าง)

| # | คำถาม | คำตอบ | สถานะ |
|---|---|---|---|
| **Q-6** | ผลรวม "งบประมาณจัดสรร" ของแถวลูกต้อง = ยอดคำขอพอดี หรือน้อยกว่าได้? | ✅ **1 รายการรับโอน โอนออกได้จากหลายรายการ (N โอนออก) — รองรับไว้เผื่อต้องใช้เงินจากหลายแหล่ง** และ **ไม่จำเป็นต้องรวมเท่ากับยอดคำขอพอดี** (requirement คือรองรับ "ทยอยโอน" — โอนน้อยกว่ายอดคำขอในรอบนี้ได้ แล้วมาเพิ่มทีหลังได้) | ✅ **ยืนยันแล้ว** — G-7 ใช้ field กรอกอิสระ (ไม่ fix), validate เป็น **≤ ยอดคำขอ** (ไม่ใช่ =) ตรงกับ R-14 ที่ออกแบบไว้อยู่แล้ว ไม่ต้องรื้อ |
| **Q-7** | รายการคำขอที่ถูกโอนออกไปแล้ว (บางส่วน/เต็มจำนวน) ยังเลือกซ้ำในใบโอนอื่นได้ไหม? ต้องมี "ยอดคงเหลือ" ไหม? | ✅ **แต่ละแถวโอนออกเป็นรายการที่ถูกสร้างขึ้นใหม่เฉพาะสำหรับรายการรับโอนนั้น** — **ไม่มีแนวคิด "ยอดคงเหลือ" ที่ต้อง track ข้ามเอกสาร** (ยังไม่นับเรื่อง**ถัวจ่าย** ซึ่งอยู่นอก scope ตอนนี้) | ✅ ตัด requirement "คงเหลือ"/กันเลือกซ้ำออกจากแผน — ไม่ต้องมี column คงเหลือ |
| **Q-8** | Scope ของ "ยืนยันรายการ" ที่หน้าขอรับจัดสรรเพิ่มเติม อยู่ใน scope งานนี้ไหม? | ✅ **อยู่ใน scope — ให้ทำเรื่องนี้รวมไปเลย** | ✅ เพิ่มเป็น Phase ใหม่ในแผน §9 — ดู **ข้อค้นพบสำคัญ** ด้านล่าง (มีกลไกสร้างไว้บางส่วนแล้วในโค้ด แต่ถูก comment ปิดอยู่) |
| **Q-9** | Cancel flow ของใบโอนจัดสรรเพิ่มเติม ต้องคืนยอดกลับ BudgetReceive ต้นทางเหมือนหน้าโอนจัดสรรปกติไหม? | ⏸️ **ตอบตอนนี้ไม่ได้** — ต้องทำ flow "ยืนยัน" ให้เรียบร้อยก่อน แล้วนำไปเสนอ **Owner/User** เพื่อหารือเรื่อง Cancel อีกครั้ง — ยืนยันแล้วว่า **Hold ไว้ก่อนได้/ทำภายหลังได้** | ⏸️ **Cancel flow เป็น OUT OF SCOPE ของรอบนี้ตามที่ยืนยัน** — ห้ามพัฒนา/แก้ logic cancel จนกว่าจะหารือกับ Owner/User เสร็จ (แผน §9 ไม่มี Phase สำหรับเรื่องนี้อยู่แล้ว) |
| **Q-10** | บัญชีผู้โอน/ผู้รับโอน (tab 2) บังคับเลือกครบทุกแถวก่อนกดยืนยันไหม? | ✅ **บังคับเลือกทั้งหมดก่อนยืนยัน** | ✅ เพิ่ม validation ก่อนเรียก `ConfirmBudgetAllocateTransferMore` — บล็อกถ้ามีแถวศูนย์ต้นทุนที่ยังไม่ได้เลือกบัญชีผู้โอนหรือผู้รับโอน |
| **Q-11** | ปุ่ม "ลบรายการ" ลบแถวแม่ (รับโอน) เดี่ยวๆ ได้ไหม? | ✅ **ลบได้แค่ ① แถวลูก (โอนออก) ทีละแถว หรือ ② ทั้งคำขอ (ทุกรายการของคำขอนั้น) พร้อมกัน** — ลบแถวรับโอนเดี่ยวๆ ไม่ได้ เพราะการโอนบังคับโอนทุกรายการของคำขอ (ตาม modal เลือกคำขอที่บังคับ "เลือกทั้งหมด" อยู่แล้ว — G-3) | ✅ ปรับ UI: checkbox อยู่ที่ระดับ group "เลขที่คำขอ" (ลบทั้งคำขอ) และระดับแถวลูก (ลบทีละรายการ) เท่านั้น — เอา checkbox ออกจากแถวแม่ |

### ⭐ ข้อค้นพบสำคัญจากการสำรวจโค้ด (สำหรับ Q-8): กลไก "ยืนยันรายการ" มีอยู่แล้วบางส่วน — แต่ถูกปิดอยู่

จากการสำรวจ [BudgetRequestMoreCostcenterDetail.cshtml](../../OAGBudget/Views/Budget/BudgetRequestMoreCostcenterDetail.cshtml) เพื่อประเมิน Phase ใหม่ของ Q-8 พบว่า:

1. **Column `IS_APPROVE` ที่ต้องใช้กรองใน `GetBudgetGovernmentByRequestId` (v1 Phase 0) มีอยู่แล้วจริง** และมี **2 ทางเข้าถึงคอลัมน์เดียวกัน**:
   - View model `OagwbgVBudgetgovernment.Is_Approve` — เพิ่มใหม่เฉพาะ feature นี้ (v1 Phase 0.2b)
   - Table model `OagwbgBudgetgovernment.ApproveStatus` — **มีอยู่แล้วก่อนหน้านี้** และ map ไปยัง column `IS_APPROVE` เดียวกัน ยืนยันจาก entity config:
     ```csharp
     // OAGBudget.DAL\Models\OAGDBContextBase.cs:3281
     entity.Property(e => e.ApproveStatus).HasColumnName("IS_APPROVE")
     ```
2. **มี UI ที่เขียนไว้แล้วแต่ comment ปิดอยู่** ที่ [BudgetRequestMoreCostcenterDetail.cshtml:168-203](../../OAGBudget/Views/Budget/BudgetRequestMoreCostcenterDetail.cshtml#L168-L203) — radio "อนุมัติ/ไม่อนุมัติ" ต่อรายการ (`ApproveStatus`) ที่ผูกกับ `Model.Is_Approve` แล้ว, เงื่อนไข enable คือ `Model.StatusId == 20101` (ตรงกับ prerequisite ที่ filter `Statusid=20101` ในหน้า BudgetAllocateTransferMore พอดี)
3. **มี JS handler ที่เขียนไว้แล้ว** (`#btnApprove`, [บรรทัด 663-694](../../OAGBudget/Views/Budget/BudgetRequestMoreCostcenterDetail.cshtml#L663-L694)) ที่รวบรวม toggle ต่อรายการ (`.budget-item-approve-toggle`) ส่งเป็น `BudgetGovernmentApproveList` ไปยัง API `UpdateBudgetRequestStatus` ซึ่ง**อัปเดต `gov.ApproveStatus` ต่อ item ได้ถูกต้องอยู่แล้ว**

✅ **Q-12 ตอบแล้ว (2026-07-20): สร้าง action ใหม่แยกต่างหาก — ไม่ reuse `#btnApprove`/`BudgetConsider` เดิม**

**เหตุผล:** ปุ่ม `#btnApprove` เดิมเปลี่ยน **header `Statusid` เป็น `20201`** (ไม่ใช่คงที่ 20101) และ **redirect ไปหน้า `BudgetRequestConsiderMoreList`** — เป็น flow "การพิจารณา/อนุมัติงบประมาณ" โดยคณะกรรมการ (`#region BudgetConsider`) ที่ใช้ร่วมกับหลายหน้าจอ (`BudgetRequestDetail`, `BudgetRequestProjectList`, `BudgetRequestMoreProjectList` ฯลฯ) — **เป็นคนละ flow กับ "ยืนยันรายการ" ที่ต้องการ** (เพื่อเปิดให้รายการไปปรากฏใน modal เลือกคำขอของ BudgetAllocateTransferMore) การ reuse ตรงๆ เสี่ยงกระทบ flow เดิมที่ไม่เกี่ยวข้อง

**แนวทางที่ยืนยันแล้ว:**
- สร้าง MVC action ใหม่แยก เช่น `ConfirmBudgetRequestMoreItems` (ชื่อ tentative — ปรับตาม convention จริงตอน implement)
- Set เฉพาะ `ApproveStatus` (= column `IS_APPROVE`) ต่อ item ผ่าน API ใหม่ — **ไม่แตะ `Statusid`** ของ header และ **ไม่ redirect ไป `BudgetRequestConsiderMoreList`**
- เขียน UI ใหม่แยกจากบล็อกที่ comment ปิดอยู่ที่บรรทัด 168-203 (ใช้เป็น reference ได้ แต่ต้องเขียนใหม่ ไม่ uncomment ตรงๆ เพราะ context ต่างกัน — ปุ่มเดิมผูกกับ `#btnApprove`/`BudgetGovernmentApproveList`/`UpdateBudgetRequestStatus` ของ flow เดิม)
- ยังใช้ pattern การเก็บ toggle ต่อรายการ (`.budget-item-approve-toggle`) และรูปแบบ radio ได้เป็นแนวทาง แต่ endpoint ปลายทางต้องเป็นของใหม่

### UI Feedback เพิ่มเติม (จากภาพประกอบ)

| สถานะ | สิ่งที่ต้องแสดง |
|---|---|
| **สถานะ 1** — เปิดหน้าใหม่ ยังไม่ save | ✅ ไม่ต้องแก้ — Header อย่างเดียว ไม่มี tab/ตาราง |
| **สถานะ 2** — เลือกคำขอแล้ว ยังไม่ save <span style="color:#c00">(กรอบแดง)</span> | group header **เลขที่คำขอ** (พื้นส้ม) → group header **แหล่งเงิน** (พื้นเหลือง) → แถวแม่ (รับโอน) &nbsp;— **ยังไม่มีปุ่ม 🏛 / ไม่มี chevron / ไม่มีแถวลูก** |
| **สถานะ 3** — หลังบันทึก <span style="color:#0a0">(กรอบเขียว)</span> | ปุ่ม 🏛 `btn-select-transfer-account` โผล่ที่แถวแม่ |
| **สถานะ 3** — เลือกโอนออกแล้ว <span style="color:#00c">(กรอบน้ำเงิน)</span> | แถวลูก (โอนออก) + chevron `btn-toggle-children` โผล่ พร้อม input **งบประมาณจัดสรร** |

---

## 8. ความเสี่ยง

| # | ความเสี่ยง | ระดับ | แนวทาง |
|---|---|---|---|
| R-9 | รื้อ `renderItems()` เป็น tree — logic คำนวณยอดรวมแม่/ลูกผิดพลาดได้ง่าย | สูง | copy pattern จากหน้าโอนจัดสรรปกติแบบตรงๆ (`parentTotalAllocate` :1722-1727) |
| R-10 | เพิ่ม `PARENTID` ใน `..._CATEGORY` — ข้อมูลเดิมที่ทดสอบไว้บน PREPROD จะกลายเป็นแถวแม่ทั้งหมด | ต่ำ | ล้างข้อมูลทดสอบก่อน (ยังไม่ขึ้น PROD) |
| R-11 | `ConfirmBudgetAllocateTransferMore` ตัดยอดจากทุกแถว — พอมี 2 ระดับจะ **ตัดยอดซ้ำ 2 เท่า** | 🔴 **สูงมาก** | ต้องแก้ให้ตัดเฉพาะ `ROWTYPE='O'` ก่อนทดสอบ Phase 4 |
| R-12 | DDL Phase 1 ยังไม่ได้รันบน PROD | สูง | รันพร้อมกันตอน deploy (§13.2 ของ roadmap v1) + Menu fix ทั้ง 4 ข้อ (§13.4) |
| R-13 | **ลบ hardcode dept/cc ของแหล่งเงิน 100** (Q-1) — ข้อมูลที่เคยบันทึกไว้บน PREPROD มีค่า `2900600000`/`2906999999` ติดอยู่ | กลาง | ล้างข้อมูลทดสอบพร้อม R-10 (ยังไม่ขึ้น PROD) |
| R-14 | ✅ **แก้แล้ว (Q-6 ยืนยัน)**: 1 รับโอน : N โอนออก, ผลรวมลูก **ไม่ต้องเท่ากับยอดคำขอ** (รองรับทยอยโอน) | ต่ำ (ปิดแล้ว) | validate ผลรวมลูก **≤ ยอดคำขอ** (ไม่ใช่ =) ทั้งฝั่ง JS และ Service ก่อน save/confirm — ไม่มีอะไรบล็อก Phase 5.5-5.6 อีกแล้ว |
| R-6 (เดิม) | **"ยืนยันรายการ" ที่หน้าขอรับจัดสรรเพิ่มเติมยังไม่มี** — Q-5/Q-8 ยืนยันว่าต้องทำก่อนโอนจัดสรร และอยู่ใน scope งานนี้ | ต่ำ (ปิดแล้ว) | ✅ ตัดสินใจแล้ว (Q-12) — สร้าง action ใหม่แยก ไม่ใช้ `#btnApprove`/`BudgetConsider` เดิม ไม่มีอะไรบล็อก Phase 5.0 อีกแล้ว |
| R-15 | ✅ **แก้แล้ว (Q-12 ยืนยัน)**: ปุ่ม `#btnApprove` เดิมเป็นคนละ flow กับที่ต้องการ (เปลี่ยน `Statusid→20201` + redirect ไป `BudgetRequestConsiderMoreList`) | ต่ำ (ปิดแล้ว) | สร้าง action ใหม่แยกต่างหาก set เฉพาะ `ApproveStatus`/`IS_APPROVE` ไม่แตะ `Statusid`/ไม่ redirect ไปหน้าอื่น |
| R-16 | **Q-9**: Cancel flow ของใบโอนจัดสรรเพิ่มเติมยังตอบไม่ได้ — ยืนยันแล้วว่า Hold ไว้ก่อน/ทำภายหลังได้ รอเสนอ Owner/User หลัง flow ยืนยันเสร็จ | กลาง (แต่ **ห้ามพัฒนาก่อนได้ข้อสรุปจาก Owner/User**) | **ตัด Cancel flow ออกจาก scope Phase ปัจจุบันทั้งหมด** — คง `CancelBudgetAllocateTransferMore` เดิมไว้เฉยๆ ไม่แตะ จนกว่าจะมีข้อสรุป |
| R-17 | **Q-11**: กติกาการลบ (ทั้งคำขอ / แถวลูกทีละแถว) ต้อง sync กันทั้ง prototype, JS จริง, และ payload ที่ส่งไป `SaveBudgetAllocateTransferMoreDetail` — ถ้า backend ไม่รองรับการลบแบบ "ทั้งกลุ่ม" (ลบหลาย category rows พร้อมกันตาม requestId) อาจต้อง loop เรียก delete ทีละรายการแทน | กลาง | ออกแบบ endpoint/payload ให้รับ "ลบตาม requestId" ได้โดยตรงแทนการวน delete ทีละ id |
| R-5 (เดิม) | สร้าง BudgetReceive ต้นทางยอด 0 อาจกระทบ balance รายงาน | สูง | ยังค้างจาก v1 — ต้องตรวจก่อน go-live |

---

## 9. ลำดับงานที่เสนอ

> ✅ **ตอบคำถามครบทั้ง 12 ข้อแล้ว — ไม่มี Phase ไหนถูกบล็อกอีกต่อไป เริ่มพัฒนาได้ทุก Phase**
> **Cancel flow (Q-9) ไม่รวมอยู่ใน Phase ใดๆ ด้านล่าง — ตัดออกจาก scope โดยเจตนา** จนกว่าจะมีข้อสรุปจาก Owner/User

| Phase | งาน | ประเมิน |
|---|---|---|
| **5.0** | ⭐ **ใหม่ (Q-8)**: ยืนยันรายการที่หน้าขอรับจัดสรรเพิ่มเติม — สร้าง **action ใหม่แยกต่างหาก** (ตัดสินใจแล้ว Q-12) เช่น `ConfirmBudgetRequestMoreItems` ที่ set เฉพาะ `ApproveStatus`/`IS_APPROVE` ต่อ item, **ไม่แตะ `Statusid`, ไม่ redirect ไป `BudgetRequestConsiderMoreList`** — เขียน UI ใหม่ (ใช้บล็อกที่ comment ปิดอยู่ที่ [BudgetRequestMoreCostcenterDetail.cshtml:168-203](../../OAGBudget/Views/Budget/BudgetRequestMoreCostcenterDetail.cshtml#L168-L203) เป็น reference เท่านั้น ไม่ uncomment ตรงๆ) | 2 วัน |
| **5.1** | DDL: `..._COSTCENTER` + view, `ALTER ..._CATEGORY ADD PARENTID/ROWTYPE` (PREPROD) | 0.5 วัน |
| **5.2** | DAL models + DbContext config | 0.5 วัน |
| **5.3** | Service: save/get 2 ระดับ + CostCenter + แก้ Confirm (R-11) + validate Q-10 (บัญชีครบก่อนยืนยัน) + validate Q-6 (ผลรวมลูก ≤ ยอดคำขอ) | 2 วัน |
| **5.4** | API + MVC Controller endpoints + dropdowns | 1 วัน |
| **5.5** | ✅ View modal เลือกคำขอ + modal บัญชีรับโอน (G-2,3,5,6,7) — field งบประมาณจัดสรรเป็น input กรอกอิสระ รองรับ N โอนออก/รับโอน (ยืนยันแล้ว Q-6) | 2 วัน |
| **5.6** | View tree table (G-4) + ปุ่มลบตาม Q-11 (ลบทั้งคำขอ/ลบทีละแถวลูก) + tab ศูนย์ต้นทุน (G-8) + G-1 | 2 วัน |
| **5.7** | Build + ทดสอบ flow ครบ (Phase 4.1-4.4 เดิม) | 1.5 วัน |
| **5.8** | Deploy DDL ทั้งหมด + Menu fix บน PROD | 0.5 วัน |
|  | **รวม (ไม่รวม Cancel flow)** | **~12 วันทำการ** |

---

## 10. Prototype

📄 `prototype_budgetallocatetransfermore_2.html` — เปิดด้วย browser (ต้องต่อ internet เพื่อโหลด Bootstrap CDN)

ครอบคลุม (อัปเดต v2.2 ตามภาพประกอบ + คำตอบ Q6-11):
- ปุ่มสลับ 3 สถานะหน้าจอ — G-1, G-5b
- Modal เลือกคำขอ: dropdown เลขที่คำขอ + ปุ่ม "เลือกทั้งหมด" + column แหล่งเงิน/แผนงาน/ผลผลิต/กิจกรรม — G-2, G-3, G-3b
- ตาราง: group **เลขที่คำขอ** (ส้ม) → **แหล่งเงิน** (เหลือง) → แถวแม่ + chevron + แถวลูก — G-4, G-4b
- **การลบ**: checkbox ที่ระดับกลุ่มเลขที่คำขอ (ลบทั้งคำขอ) หรือแถวลูก (ลบทีละรายการ) เท่านั้น — ไม่มี checkbox ที่แถวแม่ — G-11 (Q-11)
- ปุ่ม 🏛 `btn-select-transfer-account` (แสดงหลัง save) → **modal บัญชีรับโอน = ฟอร์มเพิ่มรายการใหม่ล้วน** (ไม่มีค้นหา/ไม่มีรายการให้เลือก, กด "+ เพิ่มรายการใหม่" ได้หลายครั้ง) — G-5, G-5b, G-5c — ⚠️ มี banner เตือนว่ายังรอคำตอบ Q-6
- ทุกแหล่งเงินเลือกหน่วยเบิกจ่าย/ศูนย์ต้นทุนเอง ไม่ fix — G-6
- ยอดคำขอ readonly ที่แม่ / งบประมาณจัดสรรเป็น input ที่ลูก — G-7 (⚠️ pending Q-6)
- ปุ่ม "อัพเดทงบประมาณ" — G-9
- tab "รายชื่อศูนย์ต้นทุนที่โอนจัดสรร" group by แหล่งเงิน→แผนงาน→ประเภท + บัญชีผู้โอน/ผู้รับโอน + note บังคับเลือกครบก่อนยืนยัน — G-8, Q-10

---

**สรุป:** โครงสร้าง Backend/DB ที่ทำไว้ใน v1 ยังใช้ได้เป็นฐาน แต่ต้องเพิ่ม 1 ตาราง (`..._COSTCENTER`) + 2 column (`PARENTID`, `ROWTYPE`) และรื้อ View เกือบทั้งหมด

**ข่าวดีจากรอบ feedback นี้:** ขั้นตอนที่ 5, 8 เหมือนหน้าโอนจัดสรรปกติ → **copy pattern ได้ตรงๆ** (`btn-toggle-children` tree + tab ศูนย์ต้นทุน มีโค้ดทำงานได้อยู่แล้วใน [BudgetAllocateTransferDetail.cshtml](../../OAGBudget/Views/Budget/BudgetAllocateTransferDetail.cshtml))
ส่วนขั้นตอนที่ 4 (modal บัญชีรับโอน) **reuse ได้แค่ trigger** (ปุ่ม 🏛 + gate หลัง save) — ตัว modal ต้อง**เขียนใหม่เป็นฟอร์มเพิ่มรายการใหม่ล้วน** เพราะ requirement ต่างจากหน้าโอนจัดสรรปกติ (ซึ่งเป็นค้นหา+เลือกจากรายการที่มีอยู่)

**ข่าวดีรอบนี้อีกข้อ:** Q-8 (ยืนยันรายการ) **ไม่ต้องเริ่มจากศูนย์** — พบว่ามี UI + backend เขียนไว้แล้วบางส่วนที่ `BudgetRequestMoreCostcenterDetail.cshtml` (comment ปิดอยู่) ใช้ column `IS_APPROVE` เดียวกันเป๊ะ ใช้เป็น reference ในการเขียน action ใหม่ได้เลย

**✅ Q-6 ตอบแล้ว** — 1 รับโอน โอนออกได้จากหลายรายการ (N โอนออก), ผลรวมไม่ต้องเท่ากับยอดคำขอ (รองรับทยอยโอน)

**✅ Q-12 ตอบแล้ว** — สร้าง action ใหม่แยกต่างหากสำหรับ "ยืนยันรายการ" ไม่ reuse `#btnApprove`/`BudgetConsider` เดิม เพื่อไม่ให้กระทบ flow การพิจารณาที่มีอยู่แล้ว

**🎉 ตอบคำถามครบทั้ง 12 ข้อแล้ว — ไม่มีตัวบล็อกเหลืออยู่ เริ่มพัฒนาได้ทุก Phase**

**3 งานเร่งด่วนที่สุดเมื่อเริ่มเขียนโค้ด:**
1. **R-11** — แก้ `ConfirmBudgetAllocateTransferMore` ให้ตัดยอดเฉพาะแถวลูก (ไม่งั้นตัดซ้ำ 2 เท่า)
2. **R-13** — ลบ hardcode `2900600000`/`2906999999` ทั้ง 3 จุด ตาม Q-1
3. **Phase 5.0** — สร้าง action ใหม่ "ยืนยันรายการ" แยกจาก `BudgetConsider` เดิม (Q-12) ให้เสร็จก่อน เพราะ Phase 5.7 (ทดสอบ) ต้องใช้ข้อมูลที่ผ่านขั้นตอนนี้

---

## 11. บั๊ก/ข้อค้นพบจริงจากการ Implement + ทดสอบบน PREPROD (2026-07-22 ถึง 2026-07-27)

Phase 5.0-5.7 (DDL, DAL, Service, API, MVC, Views, ยืนยันรายการ) implement เสร็จและ build ผ่าน 0 error แล้ว
ระหว่างทดสอบจริงบน PREPROD เจอบั๊ก/gap เพิ่มเติมที่ไม่ได้ถูกจับได้ตอน analysis (§1-10) เพราะเป็นรายละเอียดระดับ runtime/ข้อมูลจริง ไม่ใช่ gap เชิง requirement บันทึกไว้ที่นี่เพื่อไม่ให้ implement ซ้ำหรือหลงลืมตอน deploy PROD (Phase 5.8)

### 11.1 DB / DDL

| # | ปัญหา | สาเหตุ | แก้แล้ว |
|---|---|---|---|
| B-1 | `ORA-01400` ตอน insert header/category/costcenter ครั้งแรก | ตาราง 3 ตัวที่สร้างใน Phase 5.1 มี `ID NUMBER(10)` + sequence แยก แต่ไม่เคยผูก trigger เข้ากับ sequence — EF คาดว่า DB generate ID ให้ (mirror ตาราง `OAGWBG_BUDGETALLOCATETRANSFER` เดิมที่มี trigger อยู่แล้วแต่เราไม่รู้ตอนสร้างตารางใหม่) | ✅ สร้าง `TRG_BATM_ID` / `TRG_BATM_CAT_ID` / `TRG_BATM_CC_ID` (BEFORE INSERT ... SELECT seq.NEXTVAL) ผ่าน `run_phase5_1b_triggers_preprod.py` |
| B-2 | `ORA-00904 "o"."REGIONID"` ตอนโหลดหน้ารายละเอียดหลัง save | DAL model/config ของ `OagwbgVBudgetallocatetransfermorecategory` (view `..._CATEGORY`) มี property `Regionid` ที่ไม่มีอยู่จริงในตาราง/view นี้เลย (คัดลอกมาจาก entity อื่นผิด) | ✅ ลบ property + column mapping `Regionid` ออกจาก model และ `OAGDBContextBase.cs` (เหลือไว้เฉพาะที่ `OagwbgVBudgetallocatetransfermore` ระดับ header ซึ่งมีคอลัมน์นี้จริง) |

### 11.2 Service Layer — ตัวกรองสถานะผิด (กระทบ modal "เลือกรายการคำขอ" ทั้งหมด)

| # | ปัญหา | สาเหตุ | แก้แล้ว |
|---|---|---|---|
| B-3 | Dropdown "เลขที่คำขอ" ใน modal 1 ไม่ขึ้นคำขอที่อนุมัติแล้วจริง (`200-2/2569` สถานะ "อนุมัติคำของบประมาณ" ไม่ขึ้น) | `GetBudgetRequestMoreForTransfer` และ `GetBudgetRequestCodeList` กรอง `Statusid == 20101` ซึ่งตรวจสอบกับ DB จริง (`OAGWBG_MASTERSTATUS`) แล้วคือ **"ส่งเรื่องให้สำนักบริหารงบประมาณ"** (ยังไม่อนุมัติ) ไม่ใช่ **"อนุมัติคำของบประมาณ"** ซึ่งคือ `20201` — โค้ดเดิมกรองผิดรหัสตั้งแต่แรก (ไม่ใช่ copy-paste พลาดจากที่อื่น เพราะรหัสนี้ไม่เคยถูกยืนยันกับ DB มาก่อนตอน analysis) | ✅ เปลี่ยนเป็น `Statusid == 20201` ทั้ง 2 จุด พร้อม comment กันงงซ้ำ |
| B-4 | เลือกคำขอที่อนุมัติแล้วจริง (มี status ถูกต้อง + มี item ที่ "ยืนยันรายการ" แล้ว) แต่ modal ค้นหาไม่เจอรายการเลย ("ไม่พบรายการในคำขอนี้ หรือยังไม่ได้รับการอนุมัติ") | `GetBudgetGovernmentByRequestId` กรอง `Budgetstatus == "C"` เพิ่มเติมจาก `IS_APPROVE == 1` — ตรวจสอบแล้ว `Budgetstatus == "C"` หมายถึง **"บันทึกรับเงินจากคลังแล้ว"** ซึ่งเป็นขั้นตอนถัดไปที่ไกลกว่านี้มาก (หลังตัดงบจริงแล้ว) ไม่เกี่ยวกับ flow นี้เลย — ใส่เงื่อนไขผิดตั้งแต่ตอนเขียน Phase 5.3 | ✅ ลบเงื่อนไข `Budgetstatus == "C"` ออก เหลือกรองแค่ `IS_APPROVE == 1` ตามที่ระบุไว้ใน §7 ("ข้อค้นพบสำคัญ Q-8") อยู่แล้ว |
| B-5 | (ต่อเนื่องจาก B-4) แม้แก้ B-4 แล้วก็ยังว่างเปล่าเหมือนเดิมทุกครั้ง ไม่ว่าจะแก้ query ยังไง | **MVC action `GetBudgetGovernmentByRequestId(int requestId)` ไม่มี attribute route** — ใช้ conventional routing `{controller}/{action}/{id?}` ของ default route ซึ่ง placeholder ชื่อ `id` ไม่ใช่ `requestId` → ค่าจาก URL (`/898`) ไม่ถูก model-bind เข้าพารามิเตอร์เลย กลายเป็น `0` เสมอ ทำให้ query หาไม่เจอไม่ว่าจะแก้ WHERE ยังไงก็ตาม (บั๊กนี้ทำให้ debug วนหลายรอบเพราะดูเหมือนเป็นปัญหา process ค้าง/cache) | ✅ เปลี่ยนชื่อ parameter เป็น `int id` ให้ตรงกับ route pattern (ฝั่ง API endpoint ใช้ attribute route `[HttpGet("GetBudgetGovernmentByRequestId/{requestId}")]` อยู่แล้วจึงไม่มีปัญหา — บั๊กมีเฉพาะฝั่ง MVC proxy action) |

> ⚠️ **บทเรียน:** action ใหม่ที่เพิ่มในตัวควบคุมแบบ conventional routing (ไม่มี `[Route]`/`[HttpGet("...")]`) ต้องตั้งชื่อ parameter ตัวแรกเป็น `id` เสมอ ให้ตรงกับ default route `{controller}/{action}/{id?}` — ไม่งั้นค่าจาก URL segment จะ bind ไม่ติดแบบเงียบๆ (ไม่ throw error, แค่ได้ default value)

### 11.3 แหล่งเงิน (Budget Source) อยู่ระดับ "คำขอ" ไม่ใช่ระดับ "รายการ" — ข้อมูลเชิงโครงสร้างที่ analysis เดิมไม่ได้ระบุชัด

§10 (Prototype) ระบุไว้แล้วว่าตารางต้อง group **เลขที่คำขอ → แหล่งเงิน** (G-4) แต่ตอน implement จริงพบว่า field `budgetsourceid` **ไม่ได้อยู่ใน `OAGWBG_V_BUDGETGOVERNMENT`** (ระดับรายการ) เลย — มันอยู่ที่ `OAGWBG_V_BUDGETREQUEST.BUDGETSOURCEID` (ระดับคำขอทั้งใบ) เท่านั้น

ผลกระทบที่แก้แล้ว:
- Modal 1: dropdown "เลขที่คำขอ" ต้องพกค่า `budgetsourceid` ติดมาด้วย (`data-source` attribute) แล้วส่งต่อให้ทุกรายการที่ดึงมาจากคำขอนั้น (รายการทั้งหมดในคำขอเดียวกันใช้แหล่งเงินเดียวกันเสมอ)
- Service (`SaveBudgetAllocateTransferMoreCategory`): เดิม hardcode `BudgetSourceId = null` ให้แถวแม่เสมอ (ตกหล่นตั้งแต่ Phase 5.3) — แก้ให้บันทึกค่าจริงจาก client ทั้งตอน insert และ update
- View: เพิ่ม group header ระดับ 2 (แหล่งเงิน) ที่ขาดไปจากการ implement ครั้งแรก (มีแค่กลุ่มระดับ 1 เลขที่คำขอ) พร้อม map รหัส→ชื่อเต็มด้วย `ViewBag.DropdownBudgetSource` (เช่น `200` → `200 : เงินรายได้สะสมที่เหลือจ่ายของปีงบประมาณที่ล่วงมาแล้ว`) แทนที่จะโชว์รหัสดิบ
- **ไม่กระทบ logic ตอน "ยืนยัน"** — `ConfirmBudgetAllocateTransferMore` ใช้แหล่งเงินของ**แถวลูก** (`category.BudgetSourceId`) ในการตัดยอดอยู่แล้วตาม R-11/Q-1 ซึ่งถูกต้อง ไม่ต้องแก้

### 11.4 บั๊กอื่นๆ ที่เจอระหว่างทดสอบ

| # | ปัญหา | สาเหตุ | แก้แล้ว |
|---|---|---|---|
| B-6 | หน้ารายชื่อ (`BudgetAllocateTransferMoreList`) คอลัมน์ "ภาค" โชว์รหัสดิบ (`01`, `99`, `00`) แทนชื่อ | `_tableBudgetAllocateTransferMoreList.cshtml` render `item.regionid` ตรงๆ ไม่ผ่านการแปลงชื่อ ทั้งที่ dropdown filter ในหน้าเดียวกันใช้ข้อมูลชุดเดียวกัน (`OagwbgVRegions` ผ่าน `ViewBag.DropdownRegion`) อยู่แล้ว | ✅ สร้าง `regionNameMap` จาก `ViewBag.DropdownRegion` แล้วแปลงก่อน render (ไม่ hardcode ความหมายรหัส เพราะไม่เคยยืนยันกับ DB) |
| B-7 | วันที่โอนแสดงผิดเพี้ยนเป็น `22/07/3112` หลัง save | Save ใช้ raw `moment(...).format('YYYY-MM-DD')` ส่งค่าที่ field แสดงอยู่ (ซึ่งเป็น พ.ศ. ที่ TempusDominus locale `th` แปลงให้แล้ว) ตรงๆ ไปเก็บเป็น ค.ศ. โดยไม่ลบ 543 — ต่างจาก pattern มาตรฐานของเว็บที่ต้องใช้ helper `dateTextToSql()` (`date-utils.js`) ซึ่งแปลง พ.ศ.→ค.ศ. ให้ถูกต้อง (หน้าโอนจัดสรรปกติใช้ helper นี้อยู่แล้ว แต่หน้านี้เขียนแยกแบบ manual ตอน Phase 5.6) | ✅ เปลี่ยนมาใช้ `dateTextToSql()` เหมือนหน้าอ้างอิง |
| B-8 | กดบันทึกรายการที่มีอยู่แล้ว (ไม่ใช่สร้างใหม่) แล้วเจอหน้า 404 (`/Detail/12/12`) | `window.location.href` ใช้ `@Url.Action("BudgetAllocateTransferMoreDetail","Budget")/' + res.data` — เนื่องจากเรียก `Url.Action` ไปยัง action **เดียวกับหน้าปัจจุบัน** Razor จะดึงค่า route `id` ของหน้าปัจจุบันมาใส่ให้อัตโนมัติ (ambient value) แล้วโค้ดยังต่อ id ใหม่เข้าไปท้ายอีกที กลายเป็น URL ซ้อน id 2 ตัว — บั๊กนี้ไม่โผล่ตอนสร้างเรคคอร์ดใหม่เพราะหน้ายังไม่มี id ให้ดึง | ✅ เปลี่ยนไปใช้ placeholder string replace แทนการพึ่ง ambient route value |
| B-9 | Modal 1 "ปีงบประมาณ" เป็น free-text `<input type="number">` ไม่ตรงกับฟอร์มหลักที่เป็น dropdown (2569/2568/2567) | เขียนแยก pattern กันตอน Phase 5.5 ไม่ได้ copy จากฟอร์มหลัก | ✅ เปลี่ยนเป็น `<select>` ตัวเลือกเดียวกับฟอร์มหลัก (ทั้งใน code จริงและ prototype) |

### 11.5 สรุปผลกระทบต่อ Phase 5.8 (Deploy PROD)

ทุกบั๊กใน §11 ต้องรวมอยู่ใน checklist ก่อน deploy PROD (Phase 5.8, ยังไม่เริ่ม):
- DDL: ต้องรัน `run_phase5_1_preprod.py` **และ** `run_phase5_1b_triggers_preprod.py` (ทั้งคู่) — ถ้ารันแค่ตัวแรกจะเจอ B-1 ซ้ำบน PROD
- DAL: ยืนยันว่า `OagwbgVBudgetallocatetransfermorecategory` ไม่มี property `Regionid` ค้างอยู่ (B-2)
- ข้อมูลทดสอบบน PREPROD ที่บันทึกไปแล้วช่วง B-7 ยังเป็นบั๊ก (มี record ที่ `Transferdate` ผิดเพี้ยนค้างอยู่บน PREPROD จากการทดสอบ) — **ไม่กระทบ PROD** เพราะเป็นข้อมูลทดสอบคนละ instance แต่ควรลบ/แก้ทิ้งก่อนส่งต่อทีมอื่นทดสอบ

**ยืนยันแล้วว่า OUT OF SCOPE รอบนี้:** Cancel flow (Q-9) — Hold ไว้ก่อนได้ตามที่ยืนยัน ห้ามแตะจนกว่า flow ยืนยันจะเสร็จและเสนอ Owner/User
