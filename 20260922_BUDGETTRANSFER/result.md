# วิเคราะห์: โอนเงินกลับ (BudgetTransferDetail) — เคสเงินกัน แหล่งเงิน 400 ดึงยอดจาก GL แล้วซ้ำหลายแถว

วันที่วิเคราะห์: 2026-09-22
สถานะ: **วิเคราะห์อย่างเดียว ยังไม่แก้โค้ด และยังไม่ deploy view** (ตาม prompt ข้อ 4)
ฐานข้อมูลที่ใช้ตรวจ: Oracle PREPROD `172.16.11.19:1541/ebs_PRE` (OAGWBG) — ต่อ VPN สำเร็จ ข้อมูลด้านล่างคือของจริงจาก PREPROD

---

## 0.1 สถานะการลงมือแก้ (2026-09-22)

| # | งาน | สถานะ |
|---|---|---|
| 1 | Deploy view เพิ่ม 2 คอลัมน์ | ⛔ **ยังไม่ได้ทำ — ถูกบล็อก ต้องขออนุญาต** |
| 2 | `OagwbgVBudgetreceivesummaryRefund.cs` + mapping ใน `OAGDBContextBase.cs` | ✅ แก้แล้ว |
| 3 | `UsesBudgetReceiveAmounts` / `GetAmountsFromBudgetReceive` (helper กลาง) | ✅ เพิ่มแล้ว |
| 4 | `SearchBudgetTransferDetail` | ✅ แก้แล้ว |
| 5 | `GetBudgetTransferDetailRows` | ✅ แก้แล้ว |
| 6 | `GetBudgetTransferDetail` | ✅ แก้แล้ว (+ เติม `Reservedno` ที่เดิมไม่เคย map ทำให้ป้าย `[เงินกัน]` ไม่ขึ้นตอนเปิดใบเดิม) |
| 7 | `BudgetTransferDetail.cshtml` แท็บ 1 + แท็บ 2 | ✅ แก้แล้ว |
| 8 | Build | ✅ VS build สำเร็จ แอปรันด้วยโค้ดใหม่แล้ว (`dotnet build` จาก CLI ยังติด file lock ตอนแอปรันอยู่ แต่ `CoreCompile` ผ่านครบ 4 โปรเจกต์ ไม่มี error CS) |
| 9 | ทดสอบจริงบน PREPROD | ✅ ผ่าน — ดูหัวข้อ 0.2 |

---

## 0.2 ผลทดสอบจริง (PREPROD, 2026-09-22)

### ⚠️ บทเรียน: API ชี้ไป PROD อยู่ ไม่ใช่ PREPROD

รอบแรกกดค้นหาแล้วขึ้น **"ไม่สามารถโหลดข้อมูลได้"** / HTTP 500:

```
ORA-00904: "o"."TOTALPAYMENTAMOUNT": ตัวระบุไม่ถูกต้อง
```

สาเหตุ: `OAGBudget.API/appsettings.Development.json` เปิดบล็อก `// PROD`
(`172.16.11.18:1531 / SERVICE_NAME=PROD`) ไว้ ขณะที่ view ถูก deploy ที่ PREPROD
**ก่อนทดสอบทุกครั้งต้องเช็ค connection string ที่ active ก่อน อย่าเชื่อว่าเป็น PREPROD ตาม CLAUDE.md**
หลังสลับกลับไป PREPROD (บรรทัด 29-31) แล้ว restart API → HTTP 200

### ผลทดสอบ — คู่ที่เคยแสดงยอดซ้ำ (cc 2906999999, ปีบัญชี 2568, แหล่งเงิน 400)

| เลขที่เงินกัน | หมวด | รหัสงบประมาณ | จัดสรร | คงเหลือ |
|---|---|---|---|---|
| 68030003 | 2213 | 29006630001004100280 | **1,000** | 1,000 |
| 68030004 | 2213 | 29006630001004100280 | **5,000** | 5,000 |
| 68030002 | 2291 | 29006500000000000000 | 8,000,000 | 8,000,000 |
| *(orphan)* | 2480 | 00000000000000000000 | 1,000,000 | 69,050 |
| 68030006 | 27125 | 29006500000000000000 | **6,000** | **6,000** |
| 681203 | 27125 | 29006500000000000000 | **25,837,440** | **24,373,420** |

✅ คู่ `68030003/68030004` และ `68030006/681203` ใช้ **ชุดบัญชีเดียวกัน** แต่แสดงยอดแยกรายใบถูกต้องแล้ว
(เดิม 68030006 เคยเห็นเพดาน ~24.38 ล้านของใบ 681203)
✅ แถว orphan (BUDGETRECEIVE ID 51068) ถูกจับด้วยเงื่อนไข `BUDGETSOURCEID = '400'` ตามที่คาดไว้

### ผลทดสอบ regression — แหล่งเงิน 100 ต้องยังใช้ GL

| เลขที่เงินกัน | จัดสรร (GL) | คงเหลือ (GL) | TOTALBALANCEAMOUNT (ถัง) |
|---|---|---|---|
| *(ไม่ใช่เงินกัน)* | 200,000 | 200,000 | **-63,558.99** |
| 681253 | 24,600 | 24,600 | 24,600 |
| *(ไม่ใช่เงินกัน)* | 0 | 0 | **100** |

✅ แถวที่ไม่ใช่เงินกัน ยอด GL **ไม่เท่ากับ** ยอดถัง → ยืนยันว่ายังเดินเส้นทาง GL เดิมจริง ไม่ถูกเปลี่ยน
✅ ใบ 681253 (region P, แหล่งเงิน 100) ถูกจับด้วย `RESERVEDNO != null` และหาเจอเมื่อเลือกแหล่งเงิน **100**

### อื่น ๆ ที่ทดสอบ

| กรณี | ผล |
|---|---|
| filter `reservedNo=68030006` | ✅ ได้ 1 แถว ยอด 6,000 |
| `GetBudgetTransferDetail/2376` (11 รายการ) | ✅ HTTP 200 `fundsAvailableError=false` |
| `GetBudgetTransferDetail/2737` | ✅ HTTP 200 |

⚠️ **ยังไม่ได้ทดสอบ**: เส้นทาง "เปิดใบที่บันทึกแล้วซึ่งมีแถวเงินกัน" เพราะ PREPROD **ยังไม่มีใบโอนกลับ
(`TRANSFERTYPE='3'`) ใบไหนที่ giver เป็นแถวเงินกันเลย** — ต้องสร้างใบใหม่จากผลค้นหาแล้วบันทึกก่อนถึงจะทดสอบได้
จุดนี้คือส่วนที่แก้เยอะสุด (เติม `Reservedno` + ยอดถังจากแถว giver) จึงควรทดสอบก่อนขึ้นจริง

---

## 0. ข้อสรุปที่ผู้ใช้ตัดสินใจแล้ว (2026-09-22)

| # | ประเด็น | คำตอบ |
|---|---|---|
| 1 | **Issue 1** (ดึงจากเลขที่เงินกัน / link แหล่งเงิน) | **ไม่ต้องแก้ — ปล่อยกรองแหล่งเงิน 400 ตามเดิม** → ตัดออกจาก scope |
| 2 | คอลัมน์ "กันไว้เบิก" / "เบิกจ่าย" ที่ไม่มีข้อมูล | **แสดง 0** |
| 3 | เงื่อนไข "แถวนี้เป็นเงินกัน" | **`RESERVEDNO != null` OR `BUDGETSOURCEID = '400'`** (ดูข้อสังเกตที่หัวข้อ 6) |
| 4 | ด่านตรวจงบตอนจอง (`GetTotalBudget`) | **ใช้ GL เหมือนเดิม ไม่แก้** |

> **Scope ที่เหลือ = Issue 2 + Issue 3 เท่านั้น**
> หัวข้อ 1.2 ด้านล่างยังคงไว้เป็นบันทึกว่าทำไมใบ 681253 หาไม่เจอด้วยแหล่งเงิน 400 (เป็นพฤติกรรมที่ยอมรับแล้ว ไม่ใช่ bug ที่จะแก้รอบนี้)

---

## 1. สรุปข้อเท็จจริงที่ตรวจจาก PREPROD ก่อน (สำคัญต่อการตัดสินใจ)

### 1.1 ใบ TRANSFERNO = 681253 เป็น "เงินกันของหน่วยงาน (region P)"

```
OAGWBG_BUDGETRESERVED
ID=17  TRANSFERNO=681253  BUDGETYEAR=2569  DEPARTMENTID=2900600000  COSTCENTERID=2900600001
BUDGETSOURCEID=100  BUDGETRESERVEDREGION=P  BUDGETRESERVEDTYPE=R  STATUSID=90102
TOTALRESERVEDAMOUNT=24,600  TOTALBALANCEAMOUNT=24,600

OAGWBG_BUDGETRESERVED_CATEGORY
ID=39  BUDGETYEAR=2568  CATEGORYID=2370  BUDGETPLANID=20000  PRODUCTID=21000  ACTIVITYID=21100
TOTALRESERVEDAMOUNT=24,600  BUDGETCODEID=29006630001004100205   <-- มีแค่ 1 แถว

OAGWBG_BUDGETRECEIVE (ถังเงิน)
ID=59235  BUDGETRECEIVETYPE='O'  BUDGETRESERVEDCATEGORYID=39  BUDGETSOURCEID=100  BUDGETYEAR=2568
TOTALALLOCATEAMOUNT=24,600  TOTALRECEIVEAMOUNT=24,600  TOTALBALANCEAMOUNT=24,600
TOTALPAYMENTAMOUNT=NULL  TOTALOBLIGATIONAMOUNT=NULL
```

### 1.2 ข้อค้นพบสำคัญ — ใบ 681253 **หาไม่เจอ** เมื่อเลือกแหล่งเงิน 400

เงินกัน 2 กิ่งเก็บแหล่งเงินไม่เหมือนกัน (ยืนยันจากข้อมูลจริงทั้ง 13 ใบใน PREPROD):

| กิ่ง | RESERVED.BUDGETSOURCEID | BUDGETRECEIVE.BUDGETSOURCEID ที่เกิดจริง |
|---|---|---|
| **C** (ส่วนกลาง) | 100 หรือ 200 | **แปลงเป็น 400 เสมอ** |
| **P** (หน่วยงาน) | 100 หรือ 200 | **คงค่าต้นทาง 100/200 ไม่แปลงเป็น 400** |

เหตุผลของกิ่ง P ระบุไว้ใน docstring ของ `CreateBudgetReceiveForReservedRegionPAsync`
([BudgetService.cs:29489](OAGBudget.API/Services/Repository/BudgetService.cs#L29489)):
*"แหล่งเงินคงค่าต้นทาง (100/200) ไม่แปลงเป็น 400 เพราะ journal ของกิ่ง P post ที่ชุดบัญชีเดิม ไม่ได้ย้ายเงินไปไหน"*

ผลคือ query ที่กรอง `BUDGETSOURCEID = '400'` จะไม่มีทางเจอใบ 681253 เลย:

```
-- dept 2900600000 / cc 2900600001 (สำนักงานเลขาธิการฯ และหน่วยงานในสังกัด 13 หน่วยงาน) / ปีบัญชี 2568
RESERVEDNO | RESERVEDBUDGETYEAR | BUDGETSOURCEID | TOTALBALANCEAMOUNT
68030005   | 2569               | 400            | 1,000
68030008   | 2569               | 400            | 199,000
681253     | 2569               | 100            | 24,600     <-- ถูกกรองทิ้งเมื่อเลือก 400
```

> **ต้องยืนยันกับผู้ใช้:** ตาม step ที่เขียนใน prompt (เลือกแหล่งเงิน **400** แล้วเลือกเลขที่เงินกัน **681253**)
> ปัจจุบัน dropdown "เลขที่เงินกัน" จะ **ไม่มี 681253 ให้เลือก** เลย เพราะ
> `GetBudgetTransferReservedNoList` กรองด้วย `budgetSourceId` ตรง ๆ
> ([BudgetService.cs:18249](OAGBudget.API/Services/Repository/BudgetService.cs#L18249))
> ข้อนี้ตรงกับ Issue ข้อ 1 ที่ผู้ใช้ขอ ("ดึงจากเลขที่เงินกันเลย แล้ว link แหล่งเงินกับปีงบประมาณมาให้")

### 1.3 อาการ "ยอดซ้ำหลายแถว" เกิดจริง แต่เป็นใบอื่นในชุดข้อมูลเดียวกัน

แถวเงินกันที่ปีบัญชี 2568 ทั้งหมดใน PREPROD:

| ID | CC | SRC | CATEGORYID | BUDGETCODEID | RESERVEDNO | TOTALRECEIVE | TOTALBALANCE |
|---|---|---|---|---|---|---|---|
| 51152 | 2906999999 | 400 | 2291 | 29006500000000000000 | 68030002 | 8,000,000 | 8,000,000 |
| 52072 | 2906999999 | 400 | 2213 | 29006630001004100280 | **68030003** | 1,000 | 1,000 |
| 52114 | 2906999999 | 400 | 2213 | 29006630001004100280 | **68030004** | 5,000 | 5,000 |
| 52144 | 2900600001 | 400 | 2477 | 29006630001004100206 | 68030005 | 1,000 | 1,000 |
| 53447 | 2906999999 | 400 | 27125 | 29006500000000000000 | **68030006** | 6,000 | 6,000 |
| 53467 | 2906999999 | 400 | 27125 | 29006500000000000000 | **681203** | 25,837,440 | 24,373,420 |
| 55149 | 2900600001 | 400 | 15131 | 29006630001004100204 | 68030008 | 200,000 | 199,000 |
| 59235 | 2900600001 | 100 | 2370 | 29006630001004100205 | 681253 | 24,600 | 24,600 |

คู่ที่เป็นปัญหา:
- **68030003 / 68030004** — CATEGORYID / PRODUCT / ACTIVITY / BUDGETCODEID เหมือนกันทุกตัว
- **68030006 / 681203** — CATEGORYID / PRODUCT / ACTIVITY / BUDGETCODEID เหมือนกันทุกตัว

เนื่องจาก **ชุดบัญชี 13 segment ไม่มี segment ไหนเก็บ "เลขที่เงินกัน"** แถวเหล่านี้จึงประกอบเป็น
account_code เดียวกัน ได้ `CODE_COMBINATION_ID` เดียวกัน และได้ `P_BUDGET / P_ENCUMBRANCE /
P_ACTUAL / P_FUNDS_AVAILABLE` ชุดเดียวกันทุกแถว

ตรวจ rule ที่ใช้ประกอบ segment ยืนยันแล้วว่า fallback ไปแถวเดียวกัน (ไม่มี rule ปี `68` ทั้งคู่):

```
OAGWBG_V_EXT_OAGPO_EXPENSE_ACCOUNT_RULE_V
CATEGORYID=2213  -> BUDGETPLANID=20000 BUDGETTYPEID=212001 ACCOUNTNO=5104010107 SUBACCOUNTNO=230003
CATEGORYID=27125 -> BUDGETPLANID=90000 BUDGETTYPEID=900002 ACCOUNTNO=1206010102 SUBACCOUNTNO=920001
```

**ข้อสรุป:** อาการที่ผู้ใช้เห็น ("จำนวนเงินจัดสรรต่างกันในแต่ละแถว แต่งบจาก GL เป็นยอดรวมซ้ำ ๆ")
เป็นอาการเชิงโครงสร้าง ไม่ใช่ bug เฉพาะใบ และจะเกิดกับทุกคู่ที่ใช้ชุดบัญชีเดียวกัน
(comment ในโค้ดที่ [BudgetTransferDetail.cshtml:1435-1440](OAGBudget/Views/Budget/BudgetTransferDetail.cshtml#L1435-L1440) เคยบันทึกเคส 68030006 เห็นเพดาน 24.38 ล้านของ 681203 ไว้แล้ว)

---

## 2. ไฟล์ทั้งหมดที่เกี่ยวข้อง (Task 1)

### 2.1 Frontend — MVC

| ไฟล์ / บรรทัด | บทบาท |
|---|---|
| [BudgetTransferDetail.cshtml](OAGBudget/Views/Budget/BudgetTransferDetail.cshtml) | หน้าจอหลัก (3,374 บรรทัด) |
| [L226-L263](OAGBudget/Views/Budget/BudgetTransferDetail.cshtml#L226-L263) | ช่อง "ปีงบประมาณของบัญชี" + "เลขที่เงินกัน" (ซ่อน/แสดงตามแหล่งเงิน) |
| [L426-L438](OAGBudget/Views/Budget/BudgetTransferDetail.cshtml#L426-L438) | หัวตาราง: จัดสรร / กันไว้เบิก / เบิกจ่าย / คงเหลือ / โอนกลับ |
| [L770-L774](OAGBudget/Views/Budget/BudgetTransferDetail.cshtml#L770-L774) | `RESERVED_BUDGET_SOURCE_IDS = ['400','100','200']` |
| [L1427-L1450](OAGBudget/Views/Budget/BudgetTransferDetail.cshtml#L1427-L1450) | **จุดที่ map ยอดลงตาราง** — `budget/encumbrance/actual` = GL ล้วน, `balance` = `min(GL, TOTALBALANCEAMOUNT)` |
| [L1495-L1498](OAGBudget/Views/Budget/BudgetTransferDetail.cshtml#L1495-L1498) | ต่อชื่อหมวด `[เงินกัน {reservedNo}]` — **Issue ข้อ 2** |
| [L1726-L1781](OAGBudget/Views/Budget/BudgetTransferDetail.cshtml#L1726-L1781) | แท็บ 2 (รายการที่เลือก) — `balance` ใช้ `Totalbalanceamount` ตรง ๆ แต่ `budget/encumbrance/actual` ยังเป็น GL |
| [L2240-L2255](OAGBudget/Views/Budget/BudgetTransferDetail.cshtml#L2240-L2255) | `markRefundOverLimitRow` — ใช้ `balance` เป็นเพดานกรอก |
| [L2307-L2352](OAGBudget/Views/Budget/BudgetTransferDetail.cshtml#L2307-L2352) | `loadReservedNoOptions()` — ส่ง `budgetSourceId` ไปกรอง dropdown |
| [L2356-L2420](OAGBudget/Views/Budget/BudgetTransferDetail.cshtml#L2356-L2420) | `loadRowsFromSearch()` — **ทับ `frombudgetsource` ด้วยค่าจาก dropdown ที่ค้นหา** |
| [BudgetController.cs:2736-2770](OAGBudget/Controllers/BudgetController.cs#L2736-L2770) | `SearchBudgetTransferDetail`, `GetBudgetTransferReservedNoList` (proxy) |
| [BudgetController.cs:2904-2951](OAGBudget/Controllers/BudgetController.cs#L2904-L2951) | `SaveBudgetTransferDetailV2`, `ReserveBudgetTransferDetail`, `CancelReserveBudgetTransferDetail` |
| [Services/Repository/BudgetService.cs:5382-5460](OAGBudget/Services/Repository/BudgetService.cs#L5382-L5460) | HttpClient เรียก API |

### 2.2 Backend — API

| ไฟล์ / เมธอด | บทบาท |
|---|---|
| [API/Controllers/BudgetController.cs:2078-2113](OAGBudget.API/Controllers/BudgetController.cs#L2078-L2113) | endpoint `SearchBudgetTransferDetail`, `GetBudgetTransferReservedNoList` |
| [API BudgetService.cs:18249](OAGBudget.API/Services/Repository/BudgetService.cs#L18249) | `GetBudgetTransferReservedNoList` — **กรอง `Budgetsourceid` (Issue 1)** |
| […:18301](OAGBudget.API/Services/Repository/BudgetService.cs#L18301) | `SearchBudgetTransferDetail` — **หัวใจของปัญหา (Issue 2, 3)** |
| […:18349-18381](OAGBudget.API/Services/Repository/BudgetService.cs#L18349-L18381) | ขั้น 1 query `OagwbgVBudgetreceivesummaryRefunds` + filter |
| […:18390-18436](OAGBudget.API/Services/Repository/BudgetService.cs#L18390-L18436) | ขั้น 2 map → `BudgetReceiveSummaryItemDto` |
| […:18503-18560](OAGBudget.API/Services/Repository/BudgetService.cs#L18503-L18560) | ขั้น 3 ประกอบ 13 segment แล้วหา CCID (**ไม่มี segment ของ RESERVEDNO**) |
| […:18585-18630](OAGBudget.API/Services/Repository/BudgetService.cs#L18585-L18630) | ขั้น 3.C `GetSiblingCodeCombinationIdsAsync` + `FetchGlFundsAvailableAsync` — **ยอด GL ก้อนเดียวกันทุกแถว** |
| […:18664](OAGBudget.API/Services/Repository/BudgetService.cs#L18664) | ขั้น 4 `FillUsableRefundAmountAsync` |
| […:18765-18917](OAGBudget.API/Services/Repository/BudgetService.cs#L18765-L18917) | `FetchGlFundsAvailableAsync` — เขียน/อ่าน `APPS.OAG_GL_FUNDS_AVAILABLE_PKG_BYPASS` |
| […:18929-18995](OAGBudget.API/Services/Repository/BudgetService.cs#L18929-L18995) | `FillUsableRefundAmountAsync` — กรองด้วย `budgetSourceId` ด้วย |
| […:17491](OAGBudget.API/Services/Repository/BudgetService.cs#L17491) | `GetBudgetTransferDetailRows` — GL loop ชุดที่ 2 (โหลดรายการของใบเดิม) |
| […:17835](OAGBudget.API/Services/Repository/BudgetService.cs#L17835) | `GetBudgetTransferDetail` — GL loop ชุดที่ 3 (เปิดใบที่บันทึกแล้ว) |
| […:20764](OAGBudget.API/Services/Repository/BudgetService.cs#L20764) | `SaveBudgetTransferDetailV2` — ตัดยอดจริง |
| […:21093-21098](OAGBudget.API/Services/Repository/BudgetService.cs#L21093-L21098) | ล็อก giver ด้วย `Budgetreservedcategoryid` (ส่วนนี้ถูกต้องอยู่แล้ว) |
| […:22529](OAGBudget.API/Services/Repository/BudgetService.cs#L22529) | `ConfirmBudgetTransferCore` (จอง 80401 / ยืนยัน 80201) |
| […:22931](OAGBudget.API/Services/Repository/BudgetService.cs#L22931) | `ReserveBudgetTransferDetail` |
| […:23004](OAGBudget.API/Services/Repository/BudgetService.cs#L23004) | `CancelReserveBudgetTransferDetail` |
| […:14433-14665](OAGBudget.API/Services/Repository/BudgetService.cs#L14433-L14665) | `SaveBudgetTransfer` — ส่ง interface (`GetTotalBudget` ตรวจงบจาก GL อีกจุด) |
| […:16014](OAGBudget.API/Services/Repository/BudgetService.cs#L16014) | `SaveInterface` — INSERT `OAGWBG.OAGGL_JOURNAL_INTERFACE` |

### 2.3 DAL / Models

| ไฟล์ | หมายเหตุ |
|---|---|
| [OagwbgVBudgetreceivesummaryRefund.cs](OAGBudget.DAL/Models/OagwbgVBudgetreceivesummaryRefund.cs) | entity ของ view หลัก — มี `Budgetreservedcategoryid`, `Reservedno`, `Reservedbudgetyear` แล้ว แต่ **ไม่มี `Totalpaymentamount` / `Totalobligationamount`** |
| [OagwbgBudgetreceive.cs](OAGBudget.DAL/Models/OagwbgBudgetreceive.cs) | ตารางถังเงิน — มี `Totalpaymentamount`, `Totalobligationamount`, `Totalreceiveamount`, `Totalbalanceamount` ครบ |
| [OagwbgBudgetreserved.cs](OAGBudget.DAL/Models/OagwbgBudgetreserved.cs) | `Transferno`, `Budgetsourceid`, `Budgetreservedregion`, `Budgetyear` |
| [OagwbgBudgetreservedCategory.cs](OAGBudget.DAL/Models/OagwbgBudgetreservedCategory.cs) | `Budgetyear` (ปีบัญชี), `Categoryid`, `Budgetcodeid`, `Totalreservedamount` |
| [SearchBudgetTransferDetailResponse.cs](OAGBudget.Models/Search/SearchBudgetTransferDetailResponse.cs) | `BudgetReceiveSummaryItemDto` — `Budget/Encumbrance/Actual/FundsAvailable/PendingRefundAmount/UsableRefundAmount` |

---

## 3. Oracle Objects ที่เกี่ยวข้อง (Task 2)

### 3.1 ตาราง (OAGWBG)

| Object | บทบาทในเคสนี้ |
|---|---|
| `OAGWBG_BUDGETRESERVED` | หัวใบเงินกัน — `TRANSFERNO` (เลขที่เงินกัน), `BUDGETSOURCEID`, `BUDGETRESERVEDREGION`, `BUDGETYEAR` (ปีใบ) |
| `OAGWBG_BUDGETRESERVED_CATEGORY` | รายการในใบ — `BUDGETYEAR` (**ปีบัญชี** คนละปีกับหัวใบ), `CATEGORYID`, `BUDGETCODEID`, `TOTALRESERVEDAMOUNT` |
| `OAGWBG_BUDGETRESERVEDITEM` | รายการระดับ item ของกิ่ง P (ไม่มี CATEGORYID ต้อง reverse map จากผังบัญชี) |
| `OAGWBG_BUDGETRECEIVE` | **ถังเงินจริง** — แถว `BUDGETRECEIVETYPE='O'` คือยอดเงินกัน ผูก `BUDGETRESERVEDCATEGORYID` |
| `OAGWBG_BUDGETTRANSFER` | หัวใบโอนกลับ (`TRANSFERTYPE='3'`, `TRANSFERSTATUSID` 80101 / 80401 / 80201 / 80501) |
| `OAGWBG_BUDGETRECEIVEREFUND` | link โอนกลับ — `TRANSFERID`, `GIVERID`, `RECEIVEID`, `TOTALREFUNDAMOUNT` |
| `OAGWBG_BUDGETRECEIVEREFUND_COSTCENTER` | แท็บ 3 (บัญชีธนาคารรายศูนย์ต้นทุน) |
| `OAGWBG_RECEIVE_BATCH_NO` | บันทึก batch interface — `INTERFACETYPE` `'T'` ขาไป / `'N'` ข้ามปี / `'TR'` กลับรายการ |
| `OAGWBG_SYSTEMCONFIG` | `ConfigKey='Ledger'` |

### 3.2 View (OAGWBG)

| View | บทบาท |
|---|---|
| **`OAGWBG_V_BUDGETRECEIVESUMMARY_REFUND`** | **view หลักที่หน้าจอนี้ค้นหา** — GROUP BY รวม `BUDGETRESERVEDCATEGORYID` และ join ไป `OAGWBG_BUDGETRESERVED` เพื่อดึง `RESERVEDNO` / `RESERVEDBUDGETYEAR` (DDL เก็บไว้ที่ `_brain_OAGBUDGET/20260907_ReserveTransfer_ReservedFund_NotDeducted/ddl_OAGWBG_V_BUDGETRECEIVESUMMARY_REFUND.sql`) |
| `OAGWBG_V_BUDGETRECEIVE` | base ของ view ข้างบน (ตัด type `'T'`, `'R'`) |
| `OAGWBG_V_EXT_OAGPO_EXPENSE_ACCOUNT_RULE_V` | rule ประกอบ segment 5 / 8 / 10 / 11 |
| `OAGWBG_V_EXT_OAGGL_COST_CENTER_V`, `..._OAGINV_CATEGORY_CODES_V`, `..._BUDGET_PRODUCT_V`, `..._BUDGET_ACTIVITY_V`, `..._BUDGET_PLAN_V` | dimension สำหรับชื่อ |
| `OAGWBG_V_BUDGETRECEIVEREFUND` | ใช้ตอนส่ง interface |
| `OAGWBG_V_BUDGETRECEIVEREFUND_COSTCENTER` | แท็บ 3 |

### 3.3 APPS (EBS) — รวม Temp table / Stored Procedure

| Object | บทบาท |
|---|---|
| `APPS.OAGGL_CALENDAR_V` | หา period ล่าสุด (ตัด ADJ1..ADJ4) |
| `APPS.GL_LEDGERS` | `LEDGER_ID` |
| `APPS.OAGGL_ACCOUNT_HIERARCHIES_V` / `APPS.GL_CODE_COMBINATIONS_KFV` | หา `CODE_COMBINATION_ID` จาก 13 segment |
| **`APPS.OAG_GL_FUNDS_AVAILABLE_PKG_BYPASS`** | **Temp table ที่ใช้ดึงยอดงบจาก GL** — flow คือ `DELETE` → `INSERT` (trigger คำนวณให้) → `COMMIT` → `SELECT P_BUDGET, P_ENCUMBRANCE, P_ACTUAL, P_FUNDS_AVAILABLE` |
| **`OAGWBG.OAGGL_JOURNAL_INTERFACE`** | **Temp / interface table ที่ใช้บันทึกข้อมูลยืนยัน-ยกเลิก** — `SaveInterface` INSERT ลงตารางนี้ด้วย `WEB_BATCH_NO` |
| **`APPS.OAGGL_JOURNAL_INF_PKG.MAIN`** | **Stored Procedure** ที่ push journal ตอนจอง / ยืนยัน / กลับรายการ |
| `OAGWBG.OAGWBG_LOG_INTERFACE` | log ของ interface |

**ชื่อ batch ที่ใช้ตามรอย** (`GetBudgetTransferBatchPrefix`):
`BUDGET_RETURN_{ปี}_NO_{yyyyMMddHHmmss}` (โอนกลับในปี) / `BUDGET_RENEXT_…` (ข้ามปี) / `BUDGET_REBACK_…` (ข้ามหลายปี)
ขากลับเติม prefix `REVERSE_`

---

## 4. Flow ปัจจุบัน (Task 3)

```
[UI] BudgetTransferDetail.cshtml
  |  ผู้ใช้เลือก: หน่วยเบิกจ่าย / ศูนย์ต้นทุน / แหล่งเงิน / ปีบัญชี / เลขที่เงินกัน
  |
  +--(A) ddBudgetSourceId change -> syncReservedFilterState() -> loadReservedNoOptions()
  |      GET /Budget/GetBudgetTransferReservedNoList?departmentId&costcenterId&budgetYear&budgetSourceId
  |        -> [MVC] BudgetController.GetBudgetTransferReservedNoList
  |        -> [MVC Svc] BudgetService (HttpClient)
  |        -> [API] BudgetController -> BudgetService.GetBudgetTransferReservedNoList
  |        -> SELECT DISTINCT RESERVEDNO, RESERVEDBUDGETYEAR
  |             FROM OAGWBG_V_BUDGETRECEIVESUMMARY_REFUND
  |            WHERE RESERVEDNO IS NOT NULL AND TOTALBALANCEAMOUNT >= 0
  |              AND BUDGETSOURCEID = :src        <== จุดที่ตัด 681253 ทิ้ง
  |              AND DEPARTMENTID = :dept AND COSTCENTERID = :cc AND BUDGETYEAR = :year
  |
  +--(B) กดค้นหา -> loadRowsFromSearch()
         GET /Budget/SearchBudgetTransferDetail?departmentId&costcenterId&budgetYear&budgetSourceId&reservedNo
           -> [MVC] -> [API] BudgetService.SearchBudgetTransferDetail
              1) query OAGWBG_V_BUDGETRECEIVESUMMARY_REFUND (filter dept/cc/year/source/reservedNo)
              2) map -> BudgetReceiveSummaryItemDto
              3) ต่อ Oracle APPS แล้ววนทีละแถว
                 3.a ประกอบ account_code 13 segment
                     seg1=DEPARTMENTID  seg2=COSTCENTERID  seg3=ปี2หลัก  seg4=BUDGETSOURCEID(ของแถว)
                     seg5=rule.BUDGETPLANID  seg6=PRODUCTID  seg7=ACTIVITYID  seg8=rule.BUDGETTYPEID
                     seg9=BUDGETCODEID  seg10=rule.ACCOUNTNO  seg11=rule.SUBACCOUNTNO  seg12='00' seg13='000'
                     ** ไม่มี segment ไหนเก็บ RESERVEDNO **
                 3.b หา CCID (OAGGL_ACCOUNT_HIERARCHIES_V -> GL_CODE_COMBINATIONS_KFV -> auto-combine)
                 3.c หา sibling CCID (ปล่อย seg10/12/13 ฟรี) แล้วดึงยอดจาก
                     APPS.OAG_GL_FUNDS_AVAILABLE_PKG_BYPASS -> Budget/Encumbrance/Actual/FundsAvailable
              4) FillUsableRefundAmountAsync -> PendingRefundAmount, UsableRefundAmount
           <- JSON กลับหน้าจอ
         renderRows()
             budget      = raw.budget         (GL)
             encumbrance = raw.encumbrance    (GL)
             actual      = raw.actual         (GL)
             balance     = reservedNo ? min(GL.fundsAvailable, TOTALBALANCEAMOUNT) : GL.fundsAvailable
             leafName    = reservedNo ? categoryName + " [เงินกัน " + reservedNo + "]" : categoryName
```

**บันทึก / จอง / ยืนยัน:**

```
บันทึก       POST SaveBudgetTransferDetailV2
             -> RevertAndClearOldAsyncV2 (คืนยอดของใบเดิมก่อน)
             -> group ตาม (dept, cc, year, category, source, frombudgetsource, plan, product,
                           activity, budgetcode, ReservedCategoryId, Id)
             -> giverQuery: OAGWBG_BUDGETRECEIVE ... AND BUDGETRESERVEDCATEGORYID = :reservedCategoryId
                (ล็อกรายใบถูกต้องแล้ว)
             -> หัก TOTALBALANCEAMOUNT / บวก REFUNDAMOUNT -> สร้าง T-row + OAGWBG_BUDGETRECEIVEREFUND
             (ด่านตรวจงบจาก EBS ขั้น 2.1 ถูก comment ปิดไว้ตั้งแต่ 2026-09-02)

จอง         POST ReserveBudgetTransferDetail (80101 -> 80401)
             -> ConfirmBudgetTransferCore(80401) -> SaveBudgetTransfer(recordBatchNo:false)
             -> GetTotalBudget(...) ตรวจ "ยอดเงินไม่เพียงพอ" จาก GL      <== ยังใช้ GL อยู่
             -> SaveInterface -> INSERT OAGWBG.OAGGL_JOURNAL_INTERFACE
             -> GetBatchStatus -> APPS.OAGGL_JOURNAL_INF_PKG.MAIN

ยืนยัน       POST ApproveBudgetTransferDetail (80401 -> 80201)
             ไม่ส่ง interface ซ้ำ ลงแค่ OAGWBG_RECEIVE_BATCH_NO ('T')

ยกเลิกจอง    POST CancelReserveBudgetTransferDetail (80401 -> 80101)
             SaveBudgetTransferReverse + ลบ batch ขาไปที่ค้าง (ไม่คืนถังเงิน)

ยกเลิกยืนยัน  ReverseConfirmBudgetTransferDetail (80201 -> 80501)
             กลับรายการบัญชี + คืนถังเงิน + ปิดแถวรับโอน (T)
```

---

## 5. สิ่งที่ต้องเปลี่ยนในแต่ละ Layer

### ~~Issue 1~~ — ตัดออกจาก scope (ผู้ใช้ตัดสินใจ 2026-09-22)

คงการกรอง `BUDGETSOURCEID` ทั้งใน `GetBudgetTransferReservedNoList` และ `SearchBudgetTransferDetail` ไว้ตามเดิม
ใบกิ่ง P (เช่น 681253 source 100) จะยังหาไม่เจอเมื่อเลือกแหล่งเงิน 400 — เป็นพฤติกรรมที่ยอมรับแล้ว
ผู้ใช้ต้องเลือกแหล่งเงินให้ตรงกับใบ (100) ถึงจะเจอ

**ผลพลอยได้:** ไม่ต้องแตะ `frombudgetsource` ที่ [L2396-L2399](OAGBudget/Views/Budget/BudgetTransferDetail.cshtml#L2396-L2399)
และไม่ต้องเปลี่ยน return type ของ dropdown → **ความเสี่ยงของงานรอบนี้ลดลงมาก**

### Issue 2 — ชื่อรายการมีวงเล็บเลขที่เงินกัน แต่ยอดเป็นยอดรวม

**ปัญหา:** ป้าย `[เงินกัน 68030006]` สื่อว่าเป็นยอดของใบนั้น แต่คอลัมน์ จัดสรร / กันไว้เบิก / เบิกจ่าย เป็นยอด GL ของ **ทั้งชุดบัญชี** (รวมทุกใบ และรวมงบที่ไม่ใช่เงินกันในบัญชีเดียวกัน)

ตัวอย่างจริง: `68030006` ยอดจริง 6,000 แต่จะเห็นยอด GL ก้อนเดียวกับ `681203` (~24.38 ล้าน)

> ปัจจุบันคอลัมน์ "จำนวนเงินคงเหลือ" ถูกแก้ไปแล้วบางส่วน (`min(GL, TOTALBALANCEAMOUNT)` ที่ [L1448](OAGBudget/Views/Budget/BudgetTransferDetail.cshtml#L1448))
> แต่ **3 คอลัมน์ซ้าย (จัดสรร / กันไว้เบิก / เบิกจ่าย) ยังเป็น GL ล้วน** และแท็บ 2 ก็ผสมสองแหล่งกันอยู่

แก้ร่วมกับ Issue 3 ได้เลย — ถ้ายอดมาจาก BUDGETRECEIVE รายใบ ป้ายวงเล็บก็จะถูกต้องทันที

### Issue 3 — แหล่งเงิน 400 (เงินกัน) ให้ดึงยอดจาก BUDGETRECEIVE แทน GL

| Layer | สิ่งที่ต้องเปลี่ยน |
|---|---|
| **DB (view)** | `OAGWBG_V_BUDGETRECEIVESUMMARY_REFUND` **ยังไม่ select `TOTALPAYMENTAMOUNT` / `TOTALOBLIGATIONAMOUNT`** ต้องแก้ DDL เพิ่ม `SUM(NVL(BR.TOTALPAYMENTAMOUNT,0))`, `SUM(NVL(BR.TOTALOBLIGATIONAMOUNT,0))` ใน CTE `BR_GRP` และใน SELECT ชั้นนอก → **ตรวจแล้ว ดูหัวข้อ 5.1** |
| **DAL** | เพิ่ม property `Totalpaymentamount`, `Totalobligationamount` ใน `OagwbgVBudgetreceivesummaryRefund.cs` |
| **API** `SearchBudgetTransferDetail` | ที่ลูปขั้น 3 ถ้าแถวเข้าเงื่อนไขเงินกัน ให้ **ข้ามบล็อก GL ทั้งหมด** แล้ว set `Budget = Totalreceiveamount`, `Encumbrance = Totalobligationamount`, `Actual = Totalpaymentamount`, `FundsAvailable = Totalbalanceamount` (ค่า NULL ให้เป็น **0** ตามที่ตกลง) — ผลพลอยได้คือลดจำนวนรอบยิง EBS ลงมาก |
| **API** `GetBudgetTransferDetailRows` / `GetBudgetTransferDetail` | ต้องแก้แบบเดียวกัน ไม่งั้น "ตอนค้นหา" กับ "ตอนเปิดใบเดิม" จะเห็นยอดไม่ตรงกัน |
| **API** `FillUsableRefundAmountAsync` | `UsableRefundAmount = FundsAvailable - Pending` ยังใช้ได้ เพราะ `FundsAvailable` เปลี่ยนมาเป็นยอดถังแล้ว |
| **View** | `renderRows()` [L1443-L1450](OAGBudget/Views/Budget/BudgetTransferDetail.cshtml#L1443-L1450) เอา `min(glBalance, rowBalance)` ออกได้ (ฝั่ง API จัดการแล้ว) และแท็บ 2 [L1735-L1738](OAGBudget/Views/Budget/BudgetTransferDetail.cshtml#L1735-L1738) ให้ใช้แหล่งเดียวกัน |
| **API** `SaveBudgetTransfer` (จอง) | `GetTotalBudget(...)` **ใช้ GL เหมือนเดิม ไม่แก้** (ผู้ใช้ตัดสินใจแล้ว) |

---

## 5.1 ผลตรวจ view ที่แก้ไข — จำนวนแถวเพิ่ม / ลด / เท่าเดิม?

**วิธีตรวจ** (ทั้งหมดเป็น read-only ไม่ได้ `CREATE OR REPLACE` จริง):

1. ดึง DDL ปัจจุบันจาก PREPROD ด้วย `DBMS_METADATA.GET_DDL('VIEW','OAGWBG_V_BUDGETRECEIVESUMMARY_REFUND','OAGWBG')`
   — **หมายเหตุ:** DDL ที่เก็บไว้ใน `_brain_OAGBUDGET/20260907_.../ddl_*.sql` **ล้าสมัยแล้ว** ของจริงบน PREPROD มี
   `RSC.BUDGETCODEID` ใน COALESCE (PATCH 1/2 + 2/2) และมี `EXPENSE_TYPE_ID` / `EXPENSE_TYPE_NAME` เพิ่มมา
2. แก้เฉพาะ 4 บรรทัดด้วย `sed` จาก DDL จริง (ไม่พิมพ์เอง เพื่อตัดความเสี่ยงคัดลอกผิด) — diff ที่ได้:

```diff
@@ CTE BR_GRP @@
-    SUM(NVL(BR.REFUNDAMOUNT,        0)) AS REFUNDAMOUNT
+    SUM(NVL(BR.REFUNDAMOUNT,        0)) AS REFUNDAMOUNT,
+    SUM(NVL(BR.TOTALPAYMENTAMOUNT,    0)) AS TOTALPAYMENTAMOUNT,
+    SUM(NVL(BR.TOTALOBLIGATIONAMOUNT, 0)) AS TOTALOBLIGATIONAMOUNT
@@ SELECT ชั้นนอก @@
-  EXTCC.EXPENSE_TYPE_NAME AS EXPENSE_TYPE_NAME
+  EXTCC.EXPENSE_TYPE_NAME AS EXPENSE_TYPE_NAME,
+  A.TOTALPAYMENTAMOUNT,
+  A.TOTALOBLIGATIONAMOUNT
```

**`GROUP BY` / `JOIN` / `WHERE` ไม่ถูกแตะแม้แต่ตัวอักษรเดียว**

3. รันเทียบกับ view จริงบน PREPROD

**ผลลัพธ์:**

| การตรวจ | ผล |
|---|---|
| `COUNT(*)` view เดิม | **17,367** |
| `COUNT(*)` query ที่แก้แล้ว | **17,367** |
| `(เดิม MINUS ใหม่)` บน 30 คอลัมน์เดิม | **0 แถว** |
| `(ใหม่ MINUS เดิม)` บน 30 คอลัมน์เดิม | **0 แถว** |
| multiset diff (`GROUP BY 30 คอลัมน์ + COUNT(*)`) สองทาง | **0 / 0** |
| แถวซ้ำใน view เดิม | **0** (17,367 แถวไม่ซ้ำกันเลย) |

> ✅ **จำนวนแถวเท่าเดิมเป๊ะ ไม่เพิ่ม ไม่ลด และค่าทุกคอลัมน์เดิมตรงกันทุกแถว**
>
> เหตุผลเชิงโครงสร้าง: การเพิ่ม `SUM(...)` เข้าไปใน SELECT list ของ aggregate query
> **ไม่แตะ `GROUP BY` จึงไม่เปลี่ยนจำนวนกลุ่ม** และ `SUM` เป็น aggregate จึงไม่เกิด fan-out
> ถ้าเผลอเพิ่มเป็นคอลัมน์ธรรมดา (ไม่ห่อ `SUM`) จะต้องใส่ใน `GROUP BY` ด้วย **แล้วแถวจะแตกเพิ่มทันที** — จุดนี้คือความเสี่ยงหลัก และเราหลบไปแล้ว

**ไฟล์ DDL ที่เสนอ (ยังไม่ deploy):**
[candidate_OAGWBG_V_BUDGETRECEIVESUMMARY_REFUND.sql](_brain_OAGBUDGET/20260922_BUDGETTRANSFER/candidate_OAGWBG_V_BUDGETRECEIVESUMMARY_REFUND.sql)

**ค่าที่ 2 คอลัมน์ใหม่จะให้ (ทั้ง view 17,367 แถว):**

| กลุ่ม | จำนวนแถว | `TOTALPAYMENTAMOUNT` / `TOTALOBLIGATIONAMOUNT` |
|---|---|---|
| แถวทั้งหมด | 17,367 | มีค่า (ไม่เป็น 0) 8,922 แถว |
| แถวเงินกันจริง (type `'O'`) | 11 | **0 ทุกแถว** (ตรงกับที่ตกลงว่า "แสดง 0") |

---

## 6. ข้อสังเกตสำคัญเรื่องเงื่อนไข `RESERVEDNO != null OR source = '400'`

ผู้ใช้เลือกใช้ OR ทั้งคู่ ผมตรวจผลกระทบจริงบน PREPROD แล้วได้ตัวเลขนี้:

| เงื่อนไข | แถวที่เข้าเงื่อนไข | ครอบคลุมเงินกันครบ? | ปนแถวที่ไม่ใช่เงินกัน? |
|---|---|---|---|
| `RESERVEDNO IS NOT NULL` | **10** | ✗ ขาด 1 แถว | ✓ ไม่ปน |
| `RESERVEDNO IS NOT NULL OR BUDGETSOURCEID='400'` | **36** | ✓ ครบ 11 | ⚠️ **ปน 25 แถว** |
| `BUDGETRESERVEDCATEGORYID IS NOT NULL` | **11** | ✓ ครบ 11 | ✓ ไม่ปน |

### 6.1 ทำไม `RESERVEDNO IS NOT NULL` อย่างเดียวไม่พอ (OR ช่วยได้จริง)

พบแถวเงินกัน **orphan** 1 แถว:

```
OAGWBG_BUDGETRECEIVE ID=51068  BUDGETRECEIVETYPE='O'  BUDGETRESERVEDCATEGORYID=2  BUDGETSOURCEID=400
TOTALRECEIVEAMOUNT=1,000,000  TOTALBALANCEAMOUNT=69,050
-> OAGWBG_BUDGETRESERVED_CATEGORY ID=2 ไม่มีอยู่จริง  => RESERVEDNO เป็น NULL
```

แถวนี้เป็นเงินกันจริง (type `'O'`) แต่ join ไปหาใบไม่เจอ ถ้าใช้ `RESERVEDNO IS NOT NULL` อย่างเดียวจะ **ตกหล่น**
→ การที่ผู้ใช้เลือก OR จึงถูกต้องในแง่ "ไม่ตกหล่น"

### 6.2 แต่ OR จะดึงแถวที่ **ไม่ใช่เงินกัน** เข้ามาด้วย 25 แถว

แยกแถวแหล่งเงิน 400 ตาม `BUDGETRECEIVETYPE` (ระดับ base table หลังตัด `'T'`,`'R'`):

| TYPE | ความหมาย | แถว base | เป็นเงินกัน? |
|---|---|---|---|
| `A` | จัดสรร / โอนจัดสรร | 33 | ✗ **ไม่ใช่** |
| `G` | รับจัดสรร | 1 | ✗ **ไม่ใช่** |
| `O` | **เงินกันเหลื่อมปี** | 10 (+1 ที่ source 100) | ✓ ใช่ |

34 แถว type `A`/`G` ยุบเหลือ **25 แถวใน view** — และแถวพวกนี้ **มี `TOTALOBLIGATIONAMOUNT` / `TOTALPAYMENTAMOUNT` เป็นค่าจริง ไม่ใช่ 0**
ถ้าใช้ OR แถวเหล่านี้จะถูกสลับจาก **GL → BUDGETRECEIVE** ไปด้วย ทั้งที่ไม่ได้เป็นปัญหาที่เรากำลังแก้

ตัวอย่างแถวที่จะโดนผลกระทบโดยไม่ตั้งใจ:

```
RESERVEDNO | SRC | TOTALRECEIVE | TOTALOBLIGATION | TOTALPAYMENT | TOTALBALANCE
(null)     | 400 | 1,007,020    | 1,007,020       | 1,007,020    | 1,007,020
(null)     | 400 | 800,000      | 800,000         | 800,000      | 800,000
(null)     | 400 | 118,900      | 98,900          | 98,900       | 118,900
```

### 6.3 ทางเลือกที่ได้ผลเดียวกับ OR แต่ไม่ปน

`BUDGETRESERVEDCATEGORYID IS NOT NULL` ให้ **11 แถวพอดี = แถว type `'O'` ทั้งหมด**
(ตรวจแล้ว: ทุกแถวที่มี `BUDGETRESERVEDCATEGORYID` เป็น type `'O'` และไม่มี type อื่นเลย)
และครอบคลุมแถว orphan 51068 ด้วย เพราะ `BUDGETRESERVEDCATEGORYID = 2` ยังมีค่าอยู่ (แค่ join ไม่เจอ)

> คอลัมน์นี้ **มีอยู่แล้วทั้งใน view และใน `BudgetReceiveSummaryItemDto`** (`Budgetreservedcategoryid`)
> จึงเปลี่ยนเงื่อนไขได้โดยไม่ต้องแก้ view เพิ่ม

**ขอการตัดสินใจ:**
- (ก) ใช้ `RESERVEDNO != null OR source = '400'` ตามที่สั่ง — ยอมรับว่ามี 25 แถว type `A`/`G` โดนเปลี่ยนแหล่งยอดไปด้วย
- (ข) ใช้ `BUDGETRESERVEDCATEGORYID != null` แทน — ผลตรงเป๊ะ 11 แถว ไม่ปน (**ผมแนะนำข้อนี้**)
- (ค) ใช้ `(RESERVEDNO != null OR BUDGETRESERVEDCATEGORYID != null)` — ผลเท่ากับ (ข) แต่เขียนชัดว่าเผื่อ orphan

ถ้ายืนยัน (ก) ผมทำตามได้ครับ แค่อยากให้เห็นตัวเลข 25 แถวก่อน

---

## 7. Blast radius / Reversibility

| รายการ | ระดับ | หมายเหตุ |
|---|---|---|
| แก้ DDL view เพิ่ม 2 คอลัมน์ | **R2** | **ตรวจแล้วจำนวนแถวเท่าเดิมเป๊ะ (17,367) และ MINUS สองทาง = 0** (หัวข้อ 5.1) เป็นการเพิ่มคอลัมน์อย่างเดียว view เดิมที่หน้าอื่นใช้อยู่ไม่เปลี่ยนพฤติกรรม / ย้อนกลับด้วย `CREATE OR REPLACE` ฉบับเดิมได้ทันที |
| เพิ่ม property ใน DAL entity | **R2** | เพิ่มอย่างเดียว ไม่แตะของเดิม |
| แก้ `SearchBudgetTransferDetail` ให้เงินกันข้าม GL | **R1** | ถ้าใช้เงื่อนไข `BUDGETRESERVEDCATEGORYID != null` → กระทบ **11 แถว**; ถ้าใช้ OR ตามที่สั่ง → กระทบ **36 แถว** (รวม 25 แถวที่ไม่ใช่เงินกัน) เป็นการเปลี่ยนตัวเลขที่ผู้ใช้ใช้ตัดสินใจ |
| แก้ `GetBudgetTransferDetailRows` / `GetBudgetTransferDetail` | **R1** | ต้องทำพร้อมกัน ไม่งั้นค้นหากับเปิดใบเดิมเห็นยอดคนละแบบ |
| แก้ฝั่ง View (renderRows / แท็บ 2) | **R2** | แสดงผลล้วน |
| ~~เลิกกรอง `budgetSourceId`~~ | — | **ตัดออกจาก scope แล้ว** |
| ~~แก้ `GetTotalBudget` ตอนจอง~~ | — | **ไม่แก้ ใช้ GL เหมือนเดิม** |

**ไม่มีรายการไหนเป็น R0** — ย้อนกลับได้ด้วยการ revert code หรือ `CREATE OR REPLACE VIEW` เวอร์ชันเดิม

> ⚠️ จุดเสี่ยงเดียวที่เหลือของฝั่ง DB: ถ้าตอน deploy จริงมีคนแก้ view เพิ่มระหว่างทาง
> ให้ **ดึง DDL สดจาก server แล้ว patch ใหม่** อย่าใช้ไฟล์ candidate ตรง ๆ
> (บทเรียนจากรอบนี้: ไฟล์ DDL ใน `_brain` ของ 2026-09-07 ล้าหลัง server ไปแล้ว 2 จุด)

---

## 8. Scope check

Prompt ขอ 3 ข้อ — หลังผู้ใช้ตัดสินใจ (หัวข้อ 0) เหลือ **Issue 2 + Issue 3** ซึ่งมีรากเดียวกันคือ
"ชุดบัญชี 13 segment ไม่มีที่เก็บเลขที่เงินกัน" จึงแก้เป็นชุดเดียวกันได้

**ลำดับงานที่เสนอ:**
1. ยืนยันเงื่อนไขที่หัวข้อ 6 (ก) / (ข) / (ค)
2. Deploy view ตาม `candidate_*.sql` (ดึง DDL สดมา patch ซ้ำก่อน) แล้ว verify จำนวนแถวอีกรอบ
3. เพิ่ม 2 property ใน `OagwbgVBudgetreceivesummaryRefund.cs`
4. แก้ 3 เมธอดฝั่ง API (`SearchBudgetTransferDetail`, `GetBudgetTransferDetailRows`, `GetBudgetTransferDetail`)
5. แก้ฝั่ง View ให้แท็บ 1 / แท็บ 2 ใช้แหล่งยอดเดียวกัน
6. Build + ทดสอบด้วยคู่ `68030003 / 68030004` และ `68030006 / 681203` ว่ายอดไม่ซ้ำกันแล้ว

สิ่งที่ **อยู่นอกขอบเขต** และยังไม่แตะในเอกสารนี้:
- หน้า `BudgetReserveTransferDetail.cshtml` (โอนปรับเงินเหลือจ่าย) ซึ่งใช้ view เดียวกันและมีอาการเดียวกัน
- หน้า `BudgetTransferReturnMoreYearsDetail.cshtml` (โอนกลับข้ามหลายปี)
- รายงานที่อ่าน view เดียวกัน

ถ้าต้องการให้ครอบคลุมหน้าดังกล่าวด้วย กรุณาระบุ เพื่อไม่ให้เกิด scope drift ระหว่างพัฒนา
