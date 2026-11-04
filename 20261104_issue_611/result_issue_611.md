# ผลวิเคราะห์ Issue 611: กันเงินหน่วยงาน ส่ง Interface/ข้อมูล Temp เลขที่เงินกันไม่ตรงกับหน้าจอ

> วิเคราะห์อย่างเดียว **ไม่ได้แก้ code และไม่ได้แก้ DB** (ตาม Task 3) / วันที่: 2026-11-04 / ตรวจ PROD ด้วย SELECT อย่างเดียว
> หมายเหตุ: ไฟล์ภาพจริงชื่อ `issue611_description.jpg` (ใน prompt เขียน .png)

## 1. สรุปสั้น

| รายการ | ค่า |
|---|---|
| Issue | PROD เงินกันหน่วยงาน (region "P") ส่ง Interface และลง Temp แล้วเลขที่เงินกันไม่ตรงกับหน้าจอ 2 รายการ: **692043**, **692045** (view `OAGWBG_V_BUDGET_OVERLAPYEAR_DETAIL_INTERFACE`) |
| บริบทจาก issue | กรณีมีการอัพเดตเลขที่เงินกันใน `OAGWBG_BUDGETRESERVED` ก่อนส่งเรื่อง (ตามคำแนะนำของคุณเจมส์ว่าเคสยอดยกมาอัพเดตเลขได้) ตอนนี้ระบบส่งเป็นเลขตามระบบ และ **ซ้ำกันด้วยเลข 69220001** |
| สาเหตุราก | เลขที่เงินกันถูกเก็บ **สองที่**: หัวใบ `OAGWBG_BUDGETRESERVED.TRANSFERNO` (ที่หน้าจอแสดง และถูกอัพเดตเป็น 692043/692045) กับแถวรายการ `OAGWBG_BUDGETRESERVEDITEM.TRANSFERNO` (ยังเป็นเลขที่ระบบออกให้ตอนสร้าง = 69220001) การอัพเดตเลขทำที่หัวใบอย่างเดียว ส่วน interface อ่านเลขจาก **รายการ** |
| ผลที่เกิดแล้ว | ส่ง interface ไป EBS แล้ว 4 batch (BG/ENC × 2 ใบ) สถานะ **S (สำเร็จ)** แต่ชื่อ batch/reference มี `69220001` ทั้งสองใบ |

## 2. หลักฐานจาก PROD (SELECT)

| ตรวจ | ผล |
|---|---|
| หัวใบ | id 34 → TRANSFERNO **692043** (ศูนย์ 2900600025, ยืนยันแล้ว 20202, รอบ 1); id 35 → **692045** (เหมือนกัน) |
| รายการ | item 53 (ใบ 34, PO 26900651) และ item 54 (ใบ 35, PO 26900681) มี `TRANSFERNO` = **69220001 ทั้งคู่** |
| บัญชีธนาคาร | `OAGWBG_BUDGETRESERVED_BANKACCOUNT` ใบ 34/35 เป็น 692043/692045 (ตามหัวใบ) |
| log interface | `OAGWBG_LOG_INTERFACE` 4 แถว: `BG_/ENC_CARRY_FORWARD_2569_69220001_2026_261104144727` และ `..._261104145120` (ทั้งหมด STATUS=S, ACTION=SaveBudgetReserved) |
| ตารางชื่อ batch | `OAGWBG_RECEIVE_BATCH_NO` เก็บ batch ของใบเดียวกันด้วย **เลขหัวใบ** (`..._692045_...`, `..._692043_...`) → **ไม่ตรงกับ log ที่ใช้ 69220001** |
| view ตอนนี้ | `V_BUDGET_OVERLAPYEAR_DETAIL_INTERFACE` ให้ `TRANSFERNO = 69220001` (REFERENCE1 เป็น `..._69220001_...`) แต่ `WEB_BATCH_NO` ดึงชื่อ batch ที่ผูกกับเลขหัวใบ (`...692043...`) → ในแถวเดียวกันมีทั้งสองเลขปนกัน |
| ใบที่ item ≠ header ทั้งหมด | ใบเก่าปี 68 (id 1–26, 2 ฯลฯ) เป็นรูปแบบเดียวกัน: item `68110001`... แต่ header `681229`... คือเกิดซ้ำเป็นแบบแผนเดิม ไม่ใช่เหตุการณ์ใหม่ |

## 3. สาเหตุเชิง code

1. **ออกเลขซ้ำ:** `GenerateTransferNoAsync` (`OAGBudget.API/Services/Repository/BudgetService.cs:32124`) หา running ถัดไปจากหัวใบที่ขึ้นต้นด้วย prefix (`YY`+ชนิด+`2`) และ **ยาว ≥ 8 หลัก** พอหัวใบถูกเปลี่ยนเป็นเลข 6 หลัก (692043) ใบนั้นก็หลุดจากการนับ → ใบถัดไปได้ `69220001` ซ้ำอีก (ทั้งสองใบจึงได้ 69220001)
2. **สร้างใบใหม่:** ใส่ `Transferno = header.Transferno` ให้ทั้ง item และ bank account (`:32057`, `:32072`) ณ ตอนสร้าง — หลังจากนั้นถ้าหัวใบถูกอัพเดต จะไม่มีโค้ดตามไปอัพเดต item
3. **ส่ง interface:** `SaveBudgetReserved(int? id)` (`BudgetService.cs:17536`) ฝั่ง region "P" ตั้งชื่อ batch/journal จาก **`grp.First().Transferno` ของรายการ** (`:17602`, `:17608`, `:17610`) ไม่ใช่เลขหัวใบ → ได้ 69220001
4. **view:** `V_BUDGET_OVERLAPYEAR_DETAIL_INTERFACE` คำนวณ `TRANSFERNO_KEY = NVL(I.TRANSFERNO, BRS.TRANSFERNO)` (**เลขรายการมาก่อนหัวใบ**) แล้วใช้กับ REFERENCE1/4/5, ATTRIBUTE4, TRANSFERNO ขณะที่ join หา batch name ใช้ `HEADER_TRANSFERNO` (เลขหัวใบ) → ภายใน view เดียวกันใช้สองเลขไม่ตรงกัน
5. รายการลูก (ยกเลิก/ขยาย) คัดลอกเลขจากรายการแม่ (`:31822` ฯลฯ) จึงสืบทอดเลขเก่าต่อไปเรื่อย ๆ

## 4. Flow ปัจจุบัน

```
[ผู้ใช้] สร้างใบกันเงิน PO/PR (BudgetOverlapYearPO.cshtml)
 → MVC SaveBudgetReservedtDetail → API SaveBudgetReserved(model) (BudgetService.cs:31747 / สร้างใหม่ :32030)
     header.Transferno = GenerateTransferNoAsync(...)  ⇒ 69220001
     item.Transferno = header.Transferno               ⇒ 69220001   (ทั้งสองใบได้เลขซ้ำเพราะข้อ 1 หลังมีการเปลี่ยนเลขหัวใบ)
[มีคนอัพเดต OAGWBG_BUDGETRESERVED.TRANSFERNO → 692043/692045]  (นอกระบบ/ก่อนส่งเรื่อง; item และ log ไม่ถูกอัพเดต)
 → ส่งเรื่อง/ยืนยัน → API ConfirmBudgetReserved → SaveBudgetReserved(int? id) (:17536)
     batch = BG_/ENC_CARRY_FORWARD_{ปี}_{item.Transferno=69220001}_{yyyy}_{ts}   → OAGWBG_LOG_INTERFACE (S) → EBS GL
     ตาราง OAGWBG_RECEIVE_BATCH_NO ถูกบันทึกด้วยเลขหัวใบ (692043/692045)
[view V_BUDGET_OVERLAPYEAR_DETAIL_INTERFACE] อ่าน NVL(item.TRANSFERNO, header.TRANSFERNO) = 69220001
```

## 5. สิ่งที่ต้องเปลี่ยนในแต่ละ Layer

| Layer | ไฟล์ / ตำแหน่ง | เปลี่ยน |
|---|---|---|
| DB (view) | `OAGWBG_V_BUDGET_OVERLAPYEAR_DETAIL_INTERFACE` (`TRANSFERNO_KEY`) | ให้ใช้เลขหัวใบก่อน: `NVL(BRS.TRANSFERNO, I.TRANSFERNO)` หรือใช้เลขหัวใบเสมอสำหรับ region "P" (ต้องรอ SA ยืนยันข้อ 6.1) |
| API Service | `BudgetService.cs:17602,17608,17610` (`SaveBudgetReserved(int?)` ฝั่ง "P") | ใช้ `header.Transferno` แทน `grp.First().Transferno` ให้ชื่อ batch/journal ตรงกับหน้าจอและกับ `OAGWBG_RECEIVE_BATCH_NO` |
| API Service | `BudgetService.cs:32124` `GenerateTransferNoAsync` | อย่านับเฉพาะหัวใบที่ยาว ≥ 8 หลัก/ขึ้นต้น prefix: ให้นับเลขจาก item ด้วย หรือเก็บ running แยก เพื่อกันซ้ำเมื่อหัวใบถูกเปลี่ยนเลข |
| API Service | จุดที่ "อัพเดตเลขที่เงินกัน" (ยังหาไม่พบใน code — น่าจะเป็น script/DBA ตามคำแนะนำคุณเจมส์) | ถ้าจะให้ทำได้ในระบบ ต้องมี operation เดียวที่แก้ครบ: header + item + bank account (+ ตารางอื่นที่เก็บ TRANSFERNO) ในธุรกรรมเดียว |
| DAL / Models | `OagwbgBudgetreserveditem`, `OagwbgVBudgetreserveditem` | ไม่ต้องแก้ (ไม่มีคอลัมน์ใหม่) |
| UI / MVC | หน้าจอแสดงเลขหัวใบถูกอยู่แล้ว | ไม่ต้องแก้ |
| **ข้อมูล PROD** | item 53/54; log interface 4 batch ที่ส่ง EBS ไปแล้ว | ต้องแก้ข้อมูล และตัดสินใจเรื่อง journal ที่ลง EBS แล้ว (ดูหัวข้อ 6) — **ยังไม่ได้ทำอะไร** |

## 5.1 คำตอบจาก SA (แชท 18:08-18:09)

- ข้อ 1: **ข้อมูลยึดตามเลขที่หัวใบเสมอ** เพราะผู้ใช้เห็นแค่เลขนั้น
- รายการเหล่านี้เป็นส่วน **ยอดยกมา** ที่ต้องอัพเดตเลขให้ตรงกับใบเดิม จนกว่าจะใช้ระบบ 100%
- ข้อ 2: ตอนนี้ **อัพเดตเลขเอง ผ่าน table ที่ได้รับมา** ตามที่แจ้งใน log และอัพเดต **หลังระบบ gen เลข แต่ก่อนส่งข้อมูล (interface)**
- ข้อ 3 (SA ตอบภาพที่สอง 18:10): **2 ใบแรกที่ผิด** ให้ (1) แก้เลขให้ตรงกับหัวใบใน **temp** และ (2) **ส่ง interface ใหม่**; ส่วนรายการที่ลงผิดใน EBS ไปแล้ว **ทีมการเงิน (นุ่ม/เจ) จะ reverse ออกเอง**
- ใบใหม่ ๆ: ให้ **หยิบข้อมูลให้ตรงกับเลขหัวใบ**
- ข้อ 4 (ใบปี 68 ย้อนหลัง): **ยังไม่ได้ตอบ**
- ยังไม่ชัดว่า "temp" = ตารางไหน (ใน DB ไม่มีตารางชื่อ TEMP/TMP/STAGING; ตารางที่เก็บเลขนี้และถูกส่ง interface คือ `OAGWBG_LOG_INTERFACE` — คอลัมน์ ATTRIBUTE4/REFERENCE1/4/5/WEB_BATCH_NO — ต้องถามยืนยัน)
- ผลต่อการออกแบบ: ตอนส่ง interface หัวใบมีเลขที่อัพเดตแล้วเสมอ ⇒ ใช้เลขหัวใบตอนตั้งชื่อ batch/reference ได้ตรงตามกติกา (แก้ `BudgetService.cs:17602,17608,17610` และ view `TRANSFERNO_KEY`)

## 6. ข้อมูลที่ยังไม่เพียงพอ — ขอถามก่อนดำเนินการต่อ (Task 4)

1. **เลขที่ถูกต้องคืออะไร และใครอัพเดตเลขหัวใบ** — ถือว่าเลขหัวใบที่เห็นบนหน้าจอ (692043/692045) คือเลขจริงทุกกรณี และ item ต้องตามหัวใบเสมอใช่ไหม หรือบางเคส (เช่นรายการลูกที่สืบทอดจากใบเก่า) ต้องคงเลขเดิม และการอัพเดตเลขหัวใบทำโดยใคร/วิธีไหน (script ของ DBA ตามที่คุณเจมส์แนะนำ หรือมีหน้าจอ)
2. **journal ที่ส่งเข้า EBS ไปแล้ว 4 batch** (ลงเลข 69220001) จะจัดการอย่างไร — แก้ reference ใน EBS, ยกเลิกแล้วส่งใหม่ (ปุ่ม "ยกเลิกการยืนยัน" ของใบ P ตามโค้ดมีอยู่ แต่ผมยังไม่เคยลองกับใบเหล่านี้) หรือยอมรับ? ต้องให้ทีมการเงิน/EBS ตัดสินใจ เพราะเป็นข้อมูลบัญชีที่ post แล้ว
3. ใบเก่าปี 68 (id 1–26 ฯลฯ ที่ item ≠ header) ต้องแก้ย้อนหลังด้วยไหม หรือเฉพาะ 692043/692045
4. ผมไม่เห็นใน code จุดที่ "อัพเดตเลขที่เงินกัน" — ขอทราบวิธีที่ใช้จริง เพื่อให้การแก้ครอบคลุมทุกตารางที่เก็บเลขนี้ (ตรวจแล้วอย่างน้อย item และ bank account เก็บเลขซ้ำ)

## 7. ความเสี่ยง (DISSENT)
- การแก้ view/ code ให้ใช้เลขหัวใบมีผลกับ **ทุกใบ region P** ที่ item ≠ header (ปี 68 อีกอย่างน้อย 26 ใบ) เลข batch/reference ที่ส่ง EBS ในอนาคต (เช่นรอบขยายเวลา) จะเปลี่ยนจากเดิม ซึ่งอาจไม่ตรงกับ journal ที่ส่งไปแล้วในรอบก่อน
- batch ที่ส่งไปแล้วใน EBS แก้ไม่ได้เงียบ ๆ ต้องประสานทีม EBS/การเงินก่อน
- ผมยังไม่ได้ทดสอบกับ PREPROD (ใบ P ใน PREPROD ที่ item ≠ header ยังไม่ได้ตรวจ)
