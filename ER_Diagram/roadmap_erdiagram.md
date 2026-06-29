# Roadmap: จัดทำ ER Diagram ระบบ OAGWBG

**วันที่สำรวจ:** 2026-06-29
**อ้างอิงตัวอย่าง:** `_brain_OAGBUDGET\ER_Diagram\OAGWXP.png`
**สถานะ:** สำรวจเสร็จ + **สรุป Scope แล้ว** (2026-06-29)

> ### ✅ ผลการ Discuss (ยืนยันแล้ว)
> - **Scope:** **A — โมดูลหลักครบ** (`OAGWBG_*` ~127 ตาราง แตกเป็น 8–10 รูปรายโมดูล 1 รูป = 1 โมดูล)
> - **เส้นความสัมพันธ์:** ใช้ **Virtual Foreign Key ของ DBeaver** (ไม่แตะ DB จริง, R2) — ดูแผนลงมือข้อ 6

---

## 0. สรุปสำหรับผู้บริหาร (TL;DR)

- ระบบ OAGWBG **ใหญ่มาก**: ~**127 ตารางหลัก** (`OAGWBG_*`) + ~**120 View** (`OAGWBG_V_*`) + View interface ฝั่ง Oracle EBS (`OAGWBG_V_EXT_*`) + PL/SQL Package อีกหลายตัว
- ตัวอย่าง `OAGWXP.png` มีแค่ ~**10 ตาราง** = **1 โมดูล** → ดังนั้น ER Diagram ของ OAGWBG **ไม่ควรทำรวมทั้งระบบในรูปเดียว** ควรแยกเป็น Diagram ราย "โมดูล"
- **ข้อค้นพบสำคัญ (ความเสี่ยงข้อ 4):** โค้ด EF Core **ไม่มีการประกาศ FK/Navigation เลย** (`HasForeignKey`/`HasOne`/`WithMany` = 0 รายการ) → คาดว่าฐานข้อมูลจริงก็ **ไม่มี FK Constraint** เช่นกัน ความสัมพันธ์ผูกกันด้วย "convention ของชื่อคอลัมน์" (เช่น `BUDGETTRANSFERID`, `REQ_HEADER_ID`) เท่านั้น → **DBeaver จะ auto-draw เส้นโยงให้ไม่ได้ ต้องลากเส้นเอง** หรือเพิ่ม Virtual FK / FK จริง
- โปรแกรมที่ใช้ทำรูปตัวอย่าง: **DBeaver** (ไอคอน `123` / `A-Z` / นาฬิกา เป็นสไตล์ ER View ของ DBeaver Community)

---

## 1. ตอบคำถามใน prompt

### 1.1 รูปตัวอย่างมาจากโปรแกรมอะไร
**DBeaver** (มั่นใจสูง) — สังเกตจาก:
- ไอคอน data type หน้าคอลัมน์: `123` (number) / `A-Z` (string) / สัญลักษณ์นาฬิกา (date/timestamp) → เป็น UI เฉพาะของ DBeaver ER Diagram
- หัวตารางมีไอคอนตารางสีฟ้า + เส้นความสัมพันธ์แบบจุดประ
- ทางเลือกอื่น (Toad / SQL Navigator / Navicat) มีสไตล์ไอคอนต่างออกไป

> แนะนำใช้ **DBeaver Community (ฟรี)** ทำต่อให้ได้สไตล์ตรงกับตัวอย่าง

### 1.3 ระยะเวลาในการทำ (ประเมิน)
| Scope | ปริมาณ | เวลาโดยประมาณ |
|---|---|---|
| Diagram 1 โมดูล (เช่น โอนเปลี่ยนแปลงงบ) | ~10–15 ตาราง | 0.5 วัน |
| Scope A — โมดูลหลักทั้งหมด (แยกเป็นหลายรูป) | ~127 ตาราง / 8–10 โมดูล | 2–3 วัน |
| Scope B — Interface Oracle EBS | ~25–30 View + Package | 1 วัน |
| Scope C — ทั้งระบบ (รูปเดียว) | 127 ตาราง + 120 view | **ไม่แนะนำ** (รก อ่านไม่ออก) |

*หมายเหตุ:* ถ้าต้องการ **ลากเส้น FK เอง** (เพราะ DB ไม่มี FK) เพิ่มเวลาอีก ~30–50% ต่อ Diagram

### 1.4 ความเสี่ยง / ส่วนที่ขาด จากการไม่มี PK–FK
- **อาการ:** เปิด DBeaver ER View แล้ว **ตารางลอยเดี่ยว ไม่มีเส้นโยง** เพราะไม่มี FK Constraint ใน DB
- **ผลกระทบ:** เอกสารดูไม่เห็นความสัมพันธ์ ต้องอธิบายด้วยมือ
- **แก้ได้ไหม / ทำเลยได้ไหม?**
  - ✅ **ทำได้ในรูป (ไม่กระทบ DB):** ใช้ฟีเจอร์ **Virtual Foreign Key** ของ DBeaver — เพิ่มเส้นความสัมพันธ์เฉพาะใน metadata ของ DBeaver ไม่แตะ schema จริง → **R2 (ปลอดภัย ย้อนกลับได้)** **แนะนำวิธีนี้**
  - ⚠️ **เพิ่ม FK Constraint จริงใน DB:** **R0/R1 — อย่าทำบน PREPROD โดยไม่ประเมิน** เพราะ
    - ข้อมูลเดิมอาจมี orphan row ทำให้ `ADD CONSTRAINT` ล้มเหลว
    - กระทบ performance ของ insert/delete และอาจชน logic เดิมที่ลบข้อมูลแบบ manual
    - ต้องเทสต์ทั้ง flow บันทึก/ยกเลิก/interface ก่อน → ควรเป็นงานแยก ไม่ใช่ในงานทำ Diagram
- **ข้อสรุป:** ทำเอกสารด้วย **Virtual FK** ก่อน, ส่วน FK จริง เก็บเป็นข้อเสนอแยก

---

## 2. ขอบเขตที่เสนอ (Scope) — **ต้อง Discuss ก่อน**

ตาม prompt เสนอแบ่ง 3 ระดับ:

### Scope A — ระบบหลัก (Core `OAGWBG_*`, ~127 ตาราง)
ควร**แตกย่อยเป็นราย Diagram โมดูล** เช่น:
1. **โอนเปลี่ยนแปลง / รับโอนงบประมาณ** (โมดูลที่งานปัจจุบันเกี่ยวข้อง — periodModal/CR-115v3)
2. คำของบประมาณ (Budget Request)
3. จัดสรร/โอนจัดสรร (Budget Allocate / Allocate Transfer)
4. แผนเบิกจ่าย (Disbursement Plan)
5. กันเงิน (Budget Reserved)
6. สินทรัพย์ (Asset)
7. Master data
8. ผู้ใช้/สิทธิ์ (System/User/Permission)

### Scope B — Interface Oracle EBS (APPS)
View/Package ที่ระบบไปดึง/ส่งข้อมูลกับ Oracle EBS:
- View: `OAGWBG_V_EXT_OAGGL_*`, `OAGWBG_V_EXT_OAGHR_*`, `OAGWBG_V_EXT_OAGINV_*`, `OAGWBG_V_EXT_OAGAP_*`, `OAGWBG_V_EXT_OAGPO_*`, `OAGWBG_V_EXT_OAGCE_*`, `OAGWBG_V_EXT_OAGFA_*`
- Object APPS โดยตรง: `APPS.GL_CODE_COMBINATIONS_KFV`, `APPS.GL_LEDGERS`, `APPS.OAGFND_WEB_SEC`

### Scope C — ทั้งระบบ
รวม A + B + View ทั้งหมด — **ไม่แนะนำทำรูปเดียว** (ใช้เป็นดัชนีรายชื่อ object แทนดีกว่า)

> **คำแนะนำ:** เริ่มจาก **โมดูลโอนเปลี่ยนแปลง/รับโอนงบประมาณ** (Scope A.1) ก่อน เพราะตรงกับงาน periodModal ที่กำลังทำ และใช้เป็น template ขยายโมดูลอื่นต่อ

---

## 3. รายการ Oracle Object ที่เกี่ยวข้อง (ระบุตาม Task ข้อ 2)

### 3.1 โมดูลแนะนำ A.1 — โอนเปลี่ยนแปลง/รับโอนงบประมาณ (ตาราง)
| ตาราง | บทบาท | Key เชื่อม (convention) |
|---|---|---|
| `OAGWBG_BUDGETTRANSFER` | Header TransferOut (1 row/1 item) | PK `ID` |
| `OAGWBG_BUDGETADJUST` | Detail ของ TransferOut | `BUDGETTRANSFERID` → BUDGETTRANSFER.ID |
| `OAGWBG_BUDGETTRANSFER_CATEGORY` | หมวดงบของรายการโอน | → BUDGETTRANSFER.ID |
| `OAGWBG_BUDGETTRANSFERSOURCEITEM` | รายการต้นทาง | → BUDGETTRANSFER.ID |
| `OAGWBG_BUDGETTRANSFERTARGETITEM` | รายการปลายทาง | → BUDGETTRANSFER.ID |
| `OAGWBG_BUDGETTRANSFERHISTORY` | ประวัติการแก้ไข/สถานะ | → BUDGETTRANSFER.ID |
| `OAGWBG_BUDGETRECEIVE` | TransferIn (type "J") | → BUDGETTRANSFER.ID |
| `OAGWBG_BUDGETRECEIVEREFUND` | เชื่อม TransferIn → รหัสงบ | → BUDGETRECEIVE |
| `OAGWBG_BUDGETRECEIVEREFUND_COSTCENTER` | บัญชีธนาคารต่อ cost center | `TRANSFERID` = BUDGETTRANSFER.ID |

### 3.2 โมดูล Allocate Transfer (เกี่ยวกับ periodModal โดยตรง)
| ตาราง | บทบาท |
|---|---|
| `OAGWBG_BUDGETALLOCATETRANSFER` | Header โอนจัดสรร |
| `OAGWBG_BUDGETALLOCATETRANSFER_CATEGORY` | หมวด |
| `OAGWBG_BUDGETALLOCATETRANSFER_COSTCENTER` | cost center |
| `OAGWBG_BUDGETALLOCATETRANSFER_COSTCENTER_NOTE` | หมายเหตุ cost center |
| `OAGWBG_BUDGETALLOCATETRANSFERMORE` (+`_CATEGORY`) | รายการเพิ่มเติม |

### 3.3 Temp table / Log สำหรับ "ยืนยัน / ยกเลิก / Interface" (Task ข้อ 2)
| Object | ชนิด | บทบาท |
|---|---|---|
| `APPS.OAGGL_AUTO_COMBINE_ACCOUNT_T` | **Temp table (APPS)** | บันทึกชั่วคราวก่อนส่ง Journal Interface (`INSERT INTO ...` ที่ API line ~13885) |
| `OAGWBG_LOG_INTERFACE` | Table | Log ผลการส่ง interface ไป Oracle (ดู View `OAGWBG_V_LOG_INTERFACE`) |
| `OAGWBG_CANCELREASONLOG` | Table | บันทึกเหตุผลการ **ยกเลิก** |
| `OAGWBG_BUDGETREFUNDHISTORY` | Table | ประวัติการคืน/ปรับงบ |
| `OAGWBG_WORKFLOWJOBLOG` | Table | Log workflow |

### 3.4 Stored Procedure / PL/SQL Package ที่เรียกใช้
| Package.Procedure | บทบาท |
|---|---|
| `APPS.OAGGL_JOURNAL_INF_PKG.MAIN` | ส่งข้อมูล Journal เข้า Oracle EBS (ยืนยัน/interface) — API line ~16427 |
| `APPS.OAG_BUDGET_PKG.GET_FUNDS` | ดึงยอดงบคงเหลือ |
| `APPS.gl_funds_available_pkg.calc_funds` | คำนวณงบที่ใช้ได้ |
| `APPS.oaggl_process.find_budget` | ค้นหางบ |
| `APPS.oaggl_utilities_pkg.AUTO_COMBINE_ACCOUNT` | รวมรหัสบัญชีอัตโนมัติ (ใช้คู่กับ temp table `OAGGL_AUTO_COMBINE_ACCOUNT_T`) |
| `OAGWBG.OAGWBG_FN_GETBUDGET_ALLOCATE_TRANSFER_CATEGORY` | Table Function ดึงข้อมูลงบใน periodModal |

---

## 4. แผนแตกโมดูล Scope A (1 รูป = 1 โมดูล)

| # | สถานะ | รูป/โมดูล | ตารางหลัก |
|---|---|---|---|
| M1 | ✅ เสร็จ (2026-06-29) | **โอน/รับโอนงบประมาณ** | BUDGETTRANSFER, BUDGETADJUST, BUDGETRECEIVE, BUDGETRECEIVEREFUND, BUDGETRECEIVEREFUND_COSTCENTER (5 ตาราง — 4 ตาราง code-only ไม่มีใน DB) |
| M2 | ⬜ รอทำ | **จัดสรร/โอนจัดสรร** | BUDGETALLOCATETRANSFER (+_CATEGORY/_COSTCENTER/_COSTCENTER_NOTE), BUDGETALLOCATETRANSFERMORE (+_CATEGORY) |
| M3 | 🔄 กำลังทำ | **คำของบประมาณ** *(SA ถามถึง BUDGETREQUESTOUTSIDE)* | BUDGETREQUEST, BUDGETREQUESTOUTSIDE, BUDGETREQUISITION, BUDGETGOVERNMENT (+ITEM/ASSETITEM) — **6 ตาราง, 5 Virtual FK** |
| M4 | ⬜ รอทำ | **รับงบ/รอบงบ (Receive Period)** | BUDGETRECEIVE, BUDGETRECEIVEPERIOD (+ALLOCATION/CATEGORY/REQUEST) |
| M5 | ⬜ รอทำ | **แผนเบิกจ่าย** | BUDGETDISBURSEMENTPLAN (+ITEM/RECEIVE), BUDGETDISBURSEMENT (+ITEM/AVERAGE/ESTIMATED/OUTSIDEITEM) |
| M6 | ⬜ รอทำ | **กันเงิน / คืนงบ** | BUDGETRESERVED (+ITEM/_CATEGORY/_BANKACCOUNT), BUDGETREFUND, BUDGETREFUNDHISTORY |
| M7 | ⬜ รอทำ | **สินทรัพย์ (Asset)** | ASSET, ASSETCHANGE, ASSETTRANSFER(+ITEM), ASSETBORROW(+ITEM), ASSETMAINTENANCE*, ASSETREQUISITION(+ITEM), ASSETRETURN(+ITEM), ASSETWRITEOFF(+ITEM) |
| M8 | ⬜ รอทำ | **Master data** | MASTER* (BANK/AMPHUR/ASSETTYPE/BUDGETEXPENSETYPE/ฯลฯ) + ACCOUNT_SEGMENT |
| M9 | ⬜ รอทำ | **ผู้ใช้ / สิทธิ์ / ระบบ** | SYSTEMUSER, SYSTEMPERMISSION, ROLE assign, WORKFLOWJOBLOG, LOG_INTERFACE, CANCELREASONLOG |

> M8/M9 อาจรวบหรือซอยเพิ่มได้ตามความหนาแน่นจริงตอนกาง
> ผลลัพธ์แต่ละโมดูล → [result_erdiagram.md](result_erdiagram.md)

## 5. ขั้นตอนลงมือ (Execution)
1. ต่อ **VPN F5 BIG-IP Edge Client** ก่อน (จำเป็นต่อ PREPROD)
2. DBeaver → connection schema `OAGWBG` (มีอยู่แล้วตามสกรีน 266 objects)
3. **New ER Diagram (Custom)** ต่อโมดูล → ลากเฉพาะตารางตามตาราง M1–M9
4. เพิ่ม **Virtual Foreign Key** ตาม convention ชื่อคอลัมน์ (ดูข้อ 3.1): คลิกขวาตาราง → *Create New Foreign Key* → เลือกเป็น *Logical/Virtual* (ไม่ Persist ลง DB)
5. จัด layout → **Export PNG** → Capture แนบเอกสารส่งงาน
6. (ทางเลือก) ทำ Markdown index รายชื่อ object ทั้งหมดไว้เป็นภาคผนวก

---

## 6. คำถามที่ Discuss แล้ว (ปิดประเด็น)
- ~~เลือก Scope ไหน~~ → **Scope A (โมดูลหลักครบ)** ✅
- ~~เส้น FK แบบไหน~~ → **Virtual FK ใน DBeaver** ✅
- ยังเปิดถาม BA/SA ได้ถ้าต้องการ: รูปไหนใช้แนบ CR/เอกสารใด, ต้องการ View ประกอบในรูปด้วยหรือเฉพาะ Table

---

## ภาคผนวก A — Virtual FK ของ M1 (โอน/รับโอนงบ)

> column ดึงจาก EF mapping (`HasColumnName`) ตรวจแล้ว — ใช้ลากเส้นใน DBeaver: คลิกขวาตารางลูก → *Create New Foreign Key* → เลือก **Logical (virtual)** → ไม่ Persist ลง DB

| # | สถานะ | Child Table (ลาก**จาก**) | Column | Parent Table (ลากไป) | Ref Col |
|---|---|---|---|---|---|
| 1 | ✅ | BUDGETADJUST | `BUDGETTRANSFERID` | BUDGETTRANSFER | `ID` |
| 2 | ✅ | BUDGETRECEIVE | `BUDGETTRANSFERID` | BUDGETTRANSFER | `ID` |
| 3 | ✅ | BUDGETRECEIVE | `BUDGETADJUSTID` | BUDGETADJUST | `ID` |
| 4 | ✅ | BUDGETRECEIVEREFUND | `TRANSFERID` | BUDGETTRANSFER | `ID` |
| 5 | ✅ | BUDGETRECEIVEREFUND | `RECEIVEID` | BUDGETRECEIVE | `ID` |
| 6 | ✅ | BUDGETRECEIVEREFUND_COSTCENTER | `TRANSFERID` | BUDGETTRANSFER | `ID` |

> **วิธีลากแต่ละเส้น:** Tools → **Connection** → คลิก Child Table → ลากไป Parent Table → Dialog เลือก Column/Ref Column ตารางด้านบน → OK

**⚠️ ข้อควรระวัง type mismatch:** คอลัมน์ที่ทำเครื่องหมาย (`BUDGETTRANSFER_CATEGORY.BUDGETTRANSFERID`, `BUDGETRECEIVE.BUDGETADJUSTID`) ใน model เป็น `decimal` แต่ PK ปลายทางเป็น `int`/`NUMBER` — Virtual FK ใน DBeaver ลากได้ (ไม่บังคับ type) แต่ถ้าจะทำ FK จริงต้อง cast/แก้ชนิดก่อน

**ความสัมพันธ์ self/optional (ยังไม่ใส่ — ใส่เพิ่มได้):** `BUDGETTRANSFER.PARENTID → BUDGETTRANSFER.ID` (self), `BUDGETTRANSFER.BUDGETRECEIVEIDSOURCE/…TARGET → BUDGETRECEIVE`

> ### 🔴 ข้อค้นพบ (ตรวจสอบ 2026-06-29): ตารางที่มีใน Code แต่ **ไม่มีใน DB** (ทั้ง PROD และ PREPROD)
> | ตาราง | C# Model | DB (PROD) | DB (PREPROD) |
> |---|---|---|---|
> | `OAGWBG_BUDGETTRANSFER_CATEGORY` | ✅ มี | ❌ ไม่มี | ❌ ไม่มี |
> | `OAGWBG_BUDGETTRANSFERHISTORY` | ✅ มี | ❌ ไม่มี | ❌ ไม่มี |
> | `OAGWBG_BUDGETTRANSFERSOURCEITEM` | ✅ มี | ❌ ไม่มี | ❌ ไม่มี |
> | `OAGWBG_BUDGETTRANSFERTARGETITEM` | ✅ มี | ❌ ไม่มี | ❌ ไม่มี |
>
> **ผลกระทบ:** ER Diagram M1 ใช้ได้แค่ **5 ตาราง** (ไม่ใช่ 9) — FK #2–7 ในตาราง Virtual FK ด้านบนยังลากไม่ได้จนกว่าจะสร้างตาราง
> **คำถามสำหรับ BA/SA:** ตาราง 4 ตัวนี้วางแผนจะสร้างไหม หรือ feature ถูก cancel แล้ว?

---

> **ผลลัพธ์ ER Diagram:** ดูได้ที่ [result_erdiagram.md](result_erdiagram.md)

---

### SQL ตรวจ orphan ก่อนลาก (รันใน DBeaver ได้เลย)
```sql
-- ตัวอย่าง: เช็คว่ามี BUDGETADJUST ที่ชี้ไป BUDGETTRANSFER ที่ไม่มีจริงไหม
SELECT COUNT(*) AS orphan_adjust
FROM   OAGWBG.OAGWBG_BUDGETADJUST a
WHERE  a.BUDGETTRANSFERID IS NOT NULL
AND    NOT EXISTS (SELECT 1 FROM OAGWBG.OAGWBG_BUDGETTRANSFER t WHERE t.ID = a.BUDGETTRANSFERID);
```
> ถ้า orphan = 0 ทุกคู่ → อนาคตจะอัปเป็น FK จริงได้ปลอดภัย; ถ้า > 0 → Virtual FK เท่านั้น
