# โอนกลับ — เคสเงินกัน "หน่วยงาน" ดึงรายการไม่ได้

วิเคราะห์เมื่อ 2026-09-16 · หน้า **โอนกลับ** (`BudgetTransferDetail.cshtml`, TransferType = 2)

> ⚠ **สถานะการตรวจสอบ:** เอกสารนี้วิเคราะห์จาก **โค้ดอย่างเดียว**
> ขณะเขียนยังต่อ PREPROD (172.16.11.19:1541) ไม่ได้ — **ยังไม่ได้ยืนยันกับข้อมูลจริงของใบ 681253**
> SQL สำหรับยืนยันอยู่ใน §6 ต้องเปิด F5 BIG-IP Edge Client แล้วรันก่อนสรุปปิดเคส

---

## 1 · เคสที่แจ้ง

| หัวข้อ | ค่า |
|---|---|
| เลขที่เงินกัน | **681253** |
| ประเภท | เงินกันของ **หน่วยงาน** (`OAGWBG_BUDGETRESERVED.BUDGETRESERVEDREGION = 'P'`) |
| แหล่งเงินต้นทาง | **100** |
| ชุดบัญชี | `2900600000.2900600001.68.100.20000.21000.21100.231001.29006630001004100205.1206010102.300043.00.000` |
| อาการ | ต้องการ **ดึงเงินกลับ** แต่หน้าโอนกลับ **ยังดึงรายการไม่ได้** |

แกะชุดบัญชี 13 segment:

```
SEG1  2900600000            หน่วยเบิกจ่าย (DEPARTMENTID)
SEG2  2900600001            ศูนย์ต้นทุน (COSTCENTERID)   ← ของ "หน่วยงาน" ไม่ใช่ 2906999999 ของส่วนกลาง
SEG3  68                    ปีงบประมาณของบัญชี = 2568
SEG4  100                   แหล่งเงิน = 100              ← ไม่ใช่ 400
SEG9  29006630001004100205  รหัสงบประมาณ (BUDGETCODEID)
```

สอง segment ที่ตัดสินทุกอย่างในเคสนี้คือ **SEG3 = 68** และ **SEG4 = 100**
เพราะกลไก "เงินกัน" ที่มีอยู่บนหน้าโอนกลับ ถูกเขียนไว้สำหรับ **แหล่งเงิน 400 เท่านั้น**

---

## 2 · สรุปสาเหตุ (4 ชั้น ซ้อนกัน)

| # | สาเหตุ | ระดับ | ผลที่ผู้ใช้เห็น |
|---|---|---|---|
| **A** | เงินกัน region `P` **ไม่สร้างแถวใน `OAGWBG_BUDGETRECEIVE` เลย** | 🔴 ราก | ไม่มีแถวเงินกันใน view → ไม่มี `RESERVEDNO` ให้เลือกตลอดกาล |
| **B** | ตัวกรอง "เลขที่เงินกัน" **hardcode แหล่งเงิน `'400'`** ทั้งฝั่ง UI และ API | 🔴 ราก | แหล่งเงิน 100 → ช่อง "ปีงบประมาณของบัญชี" + "เลขที่เงินกัน" ไม่โผล่ |
| **C** | ปีที่ใช้ค้นหาถูกล็อกเป็น **ปีเอกสาร** เมื่อไม่ใช่แหล่งเงิน 400 | 🟠 ตรง | ค้นปี 2569 แต่แถวอยู่ปี 2568 → **ได้ 0 แถว** |
| **D** | คอลัมน์ "คงเหลือ" = **GL `FUNDS_AVAILABLE`** ซึ่งถูกกันเป็น Encumbrance ไปแล้ว | 🟠 ตรง | ต่อให้แถวโผล่ ก็ได้ **0.00** → กรอกยอดโอนกลับไม่ได้ |

ถ้าจะพูดเป็นประโยคเดียว:

> ทั้ง "ใบเงินกัน" และ "ยอดคงเหลือ" ที่หน้าโอนกลับต้องใช้ ถูกออกแบบมาจากโฟลว์ **เงินกันส่วนกลาง (region C / แหล่งเงิน 400)**
> เงินกันของหน่วยงาน (region P) เดินคนละเส้นทาง — เขียนลง GL อย่างเดียว ไม่แตะถังเว็บ และไม่แปลงแหล่งเงินเป็น 400
> หน้าโอนกลับจึง "มองไม่เห็น" เงินก้อนนี้ทั้งสองทาง

---

## 3 · แผนภาพ — ทำไมทั้ง 2 ทางถึงตัน

```mermaid
flowchart TD
    R["ใบเงินกัน 681253<br/>BUDGETRESERVEDREGION = 'P' (หน่วยงาน)"]

    subgraph CONF["ConfirmBudgetReserved — BudgetService.cs:29037-29158"]
        CC["กิ่ง region = 'C' (ส่วนกลาง) :29037<br/>สร้าง OAGWBG_BUDGETRECEIVE type 'O'<br/><b>Budgetsourceid = \"400\"</b> :29061"]
        CP["กิ่ง region = 'P' (หน่วยงาน) :29117<br/>เขียนแค่ OAGWBG_RECEIVE_BATCHNO<br/><b>Receiveid = null — ไม่มี BUDGETRECEIVE</b>"]
    end

    subgraph POST["SaveBudgetReserved — BudgetService.cs:14650-15190"]
        PP["region 'P' :14691<br/>post B + E ที่ <b>ชุดบัญชีเดิม</b><br/>SEG4 ไม่ถูกเปลี่ยน (คง 100)"]
        PC["region 'C' :14909<br/>SEG4 = headerData.Budgetsourceid (400)<br/>Part 2 พลิก 100→400 :15064/15130<br/>(คอมเมนต์ระบุว่า <b>ยังไม่เคยทำงาน</b>)"]
    end

    V["OAGWBG_V_BUDGETRECEIVESUMMARY_REFUND<br/>แหล่งแถวเดียวของหน้าโอนกลับ"]
    GL["GL — OAG_GL_FUNDS_AVAILABLE_PKG_BYPASS<br/>FUNDS_AVAILABLE = budget − encumbrance − actual"]

    S["หน้าโอนกลับ · กดค้นหา<br/>loadRowsFromSearch() :2336"]
    X1["❌ ทางที่ 1 ตัน — ไม่มีแถวเงินกันใน view<br/>GetBudgetTransferReservedNoList กรอง<br/>Budgetsourceid = '400' :18167"]
    X2["❌ ทางที่ 2 ตัน — คงเหลือ = FUNDS_AVAILABLE<br/>ยอดถูกกันเป็น Encumbrance แล้ว ⇒ 0.00<br/>const balance = raw.fundsAvailable :1429"]
    X3["❌ ทางที่ 3 ตัน — ปีค้นหา = ปีเอกสาร (2569)<br/>แต่แถวอยู่ปี 2568 ⇒ 0 แถว :2339"]

    R --> CONF
    R --> POST
    CC --> V
    CP -.->|"ไม่เขียนอะไรลงถังเว็บ"| V
    PP --> GL
    PC --> GL

    S --> V --> X1
    S --> V --> X3
    S --> GL --> X2

    classDef bad stroke-dasharray: 4 3;
    class X1,X2,X3 bad;
```

---

## 4 · รายละเอียดแต่ละสาเหตุ

### A · region "P" ไม่สร้าง `OAGWBG_BUDGETRECEIVE` เลย — ต้นตอที่แท้จริง

`ConfirmBudgetReserved` แยกสองกิ่งชัดเจน:

- **กิ่ง `"C"`** — [BudgetService.cs:29037](../../OAGBudget.API/Services/Repository/BudgetService.cs#L29037)
  วน `OAGWBG_BUDGETRESERVED_CATEGORY` แล้ว `AddRange` ลง `OagwbgBudgetreceives` เป็น type `"O"`
  โดย **hardcode `Budgetsourceid = "400"`** ([:29061](../../OAGBudget.API/Services/Repository/BudgetService.cs#L29061))

- **กิ่ง `"P"`** — [BudgetService.cs:29117](../../OAGBudget.API/Services/Repository/BudgetService.cs#L29117)
  เขียนเฉพาะ `OAGWBG_RECEIVE_BATCHNO` 2 แถว (BG_ + ENC_) และคอมเมนต์ในโค้ดเองระบุว่า
  `Receiveid = null, // ✅ ไม่มี receive`

`Budgetsourceid = "400"` ปรากฏใน `OAGBudget.API` **จุดเดียวในไฟล์ทั้งไฟล์** คือบรรทัด 29061 (กิ่ง C)

และ `UpdateHeaderAndItemsStatusAsync` กิ่ง `"P"` ([:28847](../../OAGBudget.API/Services/Repository/BudgetService.cs#L28847))
ก็แตะแค่ `OAGWBG_BUDGETRESERVEDITEM` (stamp `Reservedno`, `Approve`) — ไม่แตะ `BUDGETRECEIVE`

**⇒ เงินกันหน่วยงานไม่เคยมีตัวตนในถังเว็บ** view `OAGWBG_V_BUDGETRECEIVESUMMARY_REFUND`
จึงไม่มีแถวที่ `RESERVEDNO = '681253'` ให้หน้าโอนกลับหยิบไปใช้

---

### B · ตัวกรอง "เลขที่เงินกัน" ผูกกับแหล่งเงิน 400 แบบตายตัว

**ฝั่ง UI** — [BudgetTransferDetail.cshtml:770](../../OAGBudget/Views/Budget/BudgetTransferDetail.cshtml#L770)

```js
var RESERVED_BUDGET_SOURCE_ID = '400';
```

`isReservedSourceSelected()` ([:2266](../../OAGBudget/Views/Budget/BudgetTransferDetail.cshtml#L2266))
คืน true ก็ต่อเมื่อ dropdown แหล่งเงิน = `'400'` แล้ว `syncReservedFilterState()`
([:2272](../../OAGBudget/Views/Budget/BudgetTransferDetail.cshtml#L2272)) จะ:

- toggle `d-none` ทั้ง `#colAccountBudgetYear` และ `#colReservedNo`
- ตั้ง `disabled` ทั้งคู่
- **บังคับ reset** `ddAccountBudgetYear` กลับไปเท่ากับ `#fieldBudgetYear` และ `ddReservedNo` เป็นค่าว่าง

**ฝั่ง API** — [BudgetService.cs:18167](../../OAGBudget.API/Services/Repository/BudgetService.cs#L18167)

```csharp
.Where(x => x.Budgetsourceid == "400"
         && x.Reservedno != null
         && (x.Totalbalanceamount ?? 0) >= 0);
```

**⇒ เคสแหล่งเงิน 100 ไม่มีทางเห็นช่อง "เลขที่เงินกัน" และ `reservedNo` ที่ส่งไป API จะเป็นค่าว่างเสมอ**

หมายเหตุ: ต่อให้แก้ (A) ให้ region P สร้างแถว `BUDGETRECEIVE` แล้ว เงื่อนไข `== "400"` บรรทัดนี้
ก็ยังกรองแถวของหน่วยงานทิ้งอยู่ดี ถ้าแถวนั้นถูกบันทึกด้วยแหล่งเงิน 100 — **ต้องแก้คู่กัน**

---

### C · ปีที่ใช้ค้นหาถูกล็อกเป็นปีเอกสาร

[BudgetTransferDetail.cshtml:2339](../../OAGBudget/Views/Budget/BudgetTransferDetail.cshtml#L2339)

```js
const budgetYear = isReservedSourceSelected()
  ? ($('#ddAccountBudgetYear').val() || $('#fieldBudgetYear').val())
  : $('#fieldBudgetYear').val();
```

ฝั่ง API กรองตรง ๆ ([BudgetService.cs:18270](../../OAGBudget.API/Services/Repository/BudgetService.cs#L18270)):

```csharp
query = query.Where(x => x.Budgetyear != null && x.Budgetyear.ToString() == effectiveBudgetYear);
```

แถวของเคสนี้อยู่ที่บัญชีปี **2568** (SEG3 = 68) แต่เอกสารโอนกลับทำในปี **2569**
⇒ เงื่อนไขไม่ match ⇒ **ได้ 0 แถว**

**ทางเลี่ยงที่ผู้ใช้จะลองแล้วพังซ้ำ:** เลือก "ปีงบประมาณที่โอน" = 2568 เอง
จะไปพลิก `isCrossYear` เป็น true ([:16](../../OAGBudget/Views/Budget/BudgetTransferDetail.cshtml#L16))
แล้วแหล่งเงินของทุกแถวถูกทับเป็น `"200"` ([:2377](../../OAGBudget/Views/Budget/BudgetTransferDetail.cshtml#L2377))
— เอกสารกลายเป็น "โอนข้ามปีงบประมาณ" ซึ่งไม่ใช่เจตนา

นี่คือปัญหาเดียวกับที่คอมเมนต์ในโค้ดเตือนไว้แล้วที่
[:226-232](../../OAGBudget/Views/Budget/BudgetTransferDetail.cshtml#L226-L232)
— และเป็นเหตุผลที่เขาแยกช่อง "ปีงบประมาณของบัญชี" ออกมา **แต่เปิดให้เฉพาะแหล่งเงิน 400**

---

### D · "คงเหลือ" มาจาก GL ไม่ใช่ถังเว็บ — และยอดถูกกันไปแล้ว

[BudgetTransferDetail.cshtml:1429](../../OAGBudget/Views/Budget/BudgetTransferDetail.cshtml#L1429)

```js
// const balance = raw.totalbalanceamount ?? raw.Totalbalanceamount ?? 0;   ← ของเดิม ถูกคอมเมนต์ทิ้ง
const balance = raw.fundsAvailable ?? raw.FundsAvailable ?? 0;
```

`fundsAvailable` มาจาก `APPS.OAG_GL_FUNDS_AVAILABLE_PKG_BYPASS` ด้วย `P_AMOUNT_TYPE = 'YTDE'`
([BudgetService.cs:18509](../../OAGBudget.API/Services/Repository/BudgetService.cs#L18509))
ซึ่งหักยอด **Encumbrance** ออกไปแล้ว

ส่วน `SaveBudgetReserved` region `"P"` ([:14691](../../OAGBudget.API/Services/Repository/BudgetService.cs#L14691))
post 2 batch ที่ **ชุดบัญชีเดิม ไม่แตะ SEG4**:

| Step | ActualFlag | ผลต่อบัญชี `68.100.…` |
|---|---|---|
| 1 (B) `BG_CARRY_FORWARD_*` | `B` | ตั้งงบ DR |
| 2 (E) `ENC_CARRY_FORWARD_*` | `E` | **กันเงิน DR** |

`parts[3]` (SEG4) ถูกแตะจุดเดียวคือ default เมื่อว่าง → `"100"`
([:14744](../../OAGBudget.API/Services/Repository/BudgetService.cs#L14744) และ [:14834](../../OAGBudget.API/Services/Repository/BudgetService.cs#L14834)) — ไม่มีการแปลงเป็น 400

เทียบกับ region `"C"` ที่ Part 2 ตั้งใจพลิก `parts[3] = "100"` → `parts[3] = "400"`
([:15064](../../OAGBudget.API/Services/Repository/BudgetService.cs#L15064) /
[:15130](../../OAGBudget.API/Services/Repository/BudgetService.cs#L15130))
แต่คอมเมนต์เหนือบล็อกนั้นระบุชัดว่า **"Part 2 ยังไม่เคยทำงาน"**
([:15026-15037](../../OAGBudget.API/Services/Repository/BudgetService.cs#L15026-L15037))

**⇒ เงินยังนอนอยู่บัญชี `68.100` ในสถานะ Encumbrance**
ต่อให้แถวโผล่บนจอ `FUNDS_AVAILABLE` ก็เป็น 0 และ input ยอดโอนกลับถูก cap ด้วย `maxBalance`
([:2211-2260](../../OAGBudget/Views/Budget/BudgetTransferDetail.cshtml#L2211-L2260)) → กรอกไม่ได้

---

### E · กับดักที่รออยู่ถ้าแก้แค่ (A) — `BUDGETCODEID` ของแถว type 'O' เป็น NULL

ถ้าเพิ่มโค้ดให้ region P สร้างแถว `BUDGETRECEIVE` type `'O'` เฉย ๆ จะไปเจอบั๊กเดิมที่เคยวิเคราะห์ไว้ใน
[`20260907_ReserveTransfer_ReservedFund_NotDeducted/flow_search_to_display.md`](../20260907_ReserveTransfer_ReservedFund_NotDeducted/flow_search_to_display.md)

ใน `OAGWBG_V_BUDGETRECEIVESUMMARY_REFUND` คอลัมน์ `BUDGETCODEID` มาจาก
`COALESCE(BCC_A, BCC_G, BCY_P1, BCY_P2)` ซึ่งแถว type `'O'` (ไม่มี `BUDGETRECEIVEPERIODID`)
**เข้าไม่ถึงทั้ง 4 ทาง** ⇒ ได้ NULL ⇒ API map เป็น `"00000000000000000000"`
([:18332](../../OAGBudget.API/Services/Repository/BudgetService.cs#L18332))
⇒ ประกอบ SEG9 เป็นเลขศูนย์ ⇒ หา `CODE_COMBINATION_ID` ไม่เจอ ⇒ `continue`
([:18476](../../OAGBudget.API/Services/Repository/BudgetService.cs#L18476)) ⇒ โชว์ 0.00 ทั้งแถว

`OAGWBG_BUDGETRESERVED_CATEGORY` **มี `BUDGETCODEID` ที่ถูกต้องอยู่แล้ว** แต่ view ไม่ได้หยิบมาใช้
— ต้องเพิ่มเข้าไปใน `COALESCE` ด้วย

---

## 5 · ลำดับที่ควรแก้

> ⚠ **ห้ามแก้ (A) อย่างเดียวแล้วปิดเคส** — จะได้แถวที่โชว์ 0.00 ซึ่งผู้ใช้ยังทำงานไม่ได้เหมือนเดิม
> ทั้ง 4 ชั้นต้องแก้ครบถึงจะดึงเงินกลับได้จริง

| ลำดับ | สิ่งที่ต้องแก้ | ไฟล์ | R-level |
|---|---|---|---|
| 1 | View `OAGWBG_V_BUDGETRECEIVESUMMARY_REFUND` — เพิ่ม `RSC.BUDGETCODEID` เข้า `COALESCE` | Oracle DDL | R1 |
| 2 | `ConfirmBudgetReserved` กิ่ง `"P"` — สร้างแถว `BUDGETRECEIVE` type `'O'` แบบเดียวกับกิ่ง `"C"` **แต่คงแหล่งเงินต้นทาง ไม่ hardcode 400** | `BudgetService.cs:29117` | R1 |
| 3 | `GetBudgetTransferReservedNoList` — เลิกบังคับ `Budgetsourceid == "400"` ใช้ `Reservedno != null` เป็นเกณฑ์แทน | `BudgetService.cs:18167` | R2 |
| 4 | UI — เปลี่ยน `RESERVED_BUDGET_SOURCE_ID` จากค่าเดี่ยวเป็น "แถวนี้มีเลขที่เงินกันหรือไม่" เพื่อเปิดช่องปีบัญชี + เลขที่เงินกันกับแหล่งเงิน 100 ด้วย | `BudgetTransferDetail.cshtml:770, 2266, 2339` | R2 |
| 5 | ตัดสินเชิงธุรกิจ: การโอนกลับเงินกันต้อง **กลับรายการ Encumbrance** ที่บัญชี `68.100` ก่อนหรือไม่ ถ้าไม่ `FUNDS_AVAILABLE` จะเป็น 0 ตลอด | ต้องคุยกับ BA/บัญชี | **R0** |

**ข้อ 5 คือคำถามที่ต้องตอบก่อนเขียนโค้ดข้อ 1-4** — ถ้ายอดยังถูกกันเป็น Encumbrance อยู่
การเปิดให้หน้าจอ "เห็น" แถวก็ยังกรอกยอดไม่ได้อยู่ดี เพราะ cap อยู่ที่ `FUNDS_AVAILABLE`

มีสองทางเลือกเชิงออกแบบ:

- **(ก)** ให้หน้าโอนกลับใช้ `TOTALBALANCEAMOUNT` (ถังเว็บ) เป็นเพดานสำหรับแถวเงินกัน แทน `FUNDS_AVAILABLE`
  — blast radius แคบ แต่เพดานจะไม่สอดคล้องกับ GL
- **(ข)** ให้การโอนกลับ post reversal ของ Encumbrance เข้า GL ก่อน แล้วค่อยให้ `FUNDS_AVAILABLE` ขึ้นเอง
  — ตรงตามบัญชีมากกว่า แต่แตะ EBS = **R0 / ย้อนยาก**

---

## 6 · SQL สำหรับยืนยัน (ต้องต่อ VPN ก่อน)

> เปิด **F5 BIG-IP Edge Client** → Connect → แล้วรันชุดนี้บน PREPROD (`OAGWBG`)
> ผลลัพธ์ที่คาดไว้เขียนกำกับไว้ใต้แต่ละข้อ — ถ้าไม่ตรง แปลว่าข้อสรุปข้างบนต้องแก้

```sql
-- 6.1 ยืนยันว่าใบ 681253 เป็น region 'P' และดูแหล่งเงิน/ปีของ header
SELECT ID, TRANSFERNO, BUDGETRESERVEDREGION, BUDGETYEAR, BUDGETSOURCEID,
       DEPARTMENTID, COSTCENTERID, STATUSID, ROUNDINTERFACE
  FROM OAGWBG_BUDGETRESERVED
 WHERE TRANSFERNO = '681253';
-- คาด: BUDGETRESERVEDREGION = 'P'

-- 6.2 ยืนยันสาเหตุ A — ไม่มีแถว BUDGETRECEIVE ผูกกับใบนี้เลย
SELECT COUNT(*) AS CNT
  FROM OAGWBG_BUDGETRECEIVE
 WHERE BUDGETRESERVEDID = (SELECT ID FROM OAGWBG_BUDGETRESERVED WHERE TRANSFERNO = '681253');
-- คาด: 0

-- 6.3 ยืนยันสาเหตุ B — view ไม่มีแถวของใบนี้
SELECT COUNT(*) AS CNT
  FROM OAGWBG_V_BUDGETRECEIVESUMMARY_REFUND
 WHERE RESERVEDNO = '681253';
-- คาด: 0

-- 6.4 ยืนยันสาเหตุ C — แถวแหล่งเงิน 100 ของศูนย์ต้นทุนนี้อยู่ปีไหน
SELECT BUDGETYEAR, BUDGETSOURCEID, BUDGETCODEID,
       TOTALRECEIVEAMOUNT, TOTALTRANSFERAMOUNT, TOTALBALANCEAMOUNT
  FROM OAGWBG_V_BUDGETRECEIVESUMMARY_REFUND
 WHERE DEPARTMENTID = '2900600000'
   AND COSTCENTERID = '2900600001'
   AND BUDGETSOURCEID = '100'
 ORDER BY BUDGETYEAR;
-- คาด: มีแถว BUDGETYEAR = 2568 (ไม่ใช่ 2569 ที่หน้าจอใช้ค้น)

-- 6.5 ยืนยันสาเหตุ D — journal ที่ post จริง SEG4 เป็นอะไร
SELECT WEB_BATCH_NO, ACTUAL_FLAG, SEGMENT3, SEGMENT4, SEGMENT9,
       ENTERED_DR, ENTERED_CR, REFERENCE4
  FROM OAGWBG_LOG_INTERFACE
 WHERE WEB_BATCH_NO LIKE '%CARRY_FORWARD%681253%'
 ORDER BY WEB_BATCH_NO, LINE_NUMBER;
-- คาด: SEGMENT4 = '100' ทุกบรรทัด และมี ACTUAL_FLAG = 'E' (Encumbrance)

-- 6.6 ยืนยันสาเหตุ D (ต่อ) — ยอดคงเหลือจริงใน GL ของบัญชีที่แจ้ง
SELECT CODE_COMBINATION_ID
  FROM APPS.GL_CODE_COMBINATIONS_KFV
 WHERE CONCATENATED_SEGMENTS =
       '2900600000.2900600001.68.100.20000.21000.21100.231001.29006630001004100205.1206010102.300043.00.000';
-- แล้วเอา CCID ไปดูยอดผ่าน APPS.OAG_GL_FUNDS_AVAILABLE_PKG_BYPASS (P_AMOUNT_TYPE = 'YTDE')
-- คาด: P_ENCUMBRANCE > 0 และ P_FUNDS_AVAILABLE = 0
```

---

## 7 · ไฟล์/บรรทัดอ้างอิงทั้งหมด

| จุด | ไฟล์ | บรรทัด |
|---|---|---|
| กิ่ง region C สร้าง BUDGETRECEIVE | `OAGBudget.API/Services/Repository/BudgetService.cs` | 29037-29115 |
| `Budgetsourceid = "400"` (จุดเดียวในไฟล์) | เดียวกัน | 29061 |
| กิ่ง region P — ไม่มี receive | เดียวกัน | 29117-29158 |
| `UpdateHeaderAndItemsStatusAsync` กิ่ง P | เดียวกัน | 28847 |
| `SaveBudgetReserved` region P (post ที่บัญชีเดิม) | เดียวกัน | 14691-14907 |
| default SEG4 = "100" เมื่อว่าง | เดียวกัน | 14744, 14834 |
| `SaveBudgetReserved` region C | เดียวกัน | 14909-15188 |
| Part 2 พลิก 100→400 (ยังไม่เคยทำงาน) | เดียวกัน | 15026-15160 |
| `GetBudgetTransferReservedNoList` กรอง 400 | เดียวกัน | 18160-18196 |
| `SearchBudgetTransferDetail` กรองปี/แหล่งเงิน | เดียวกัน | 18209-18290 |
| map `Budgetcodeid ?? "0000…"` | เดียวกัน | 18332 |
| `if (codeCombinationId == 0) continue;` | เดียวกัน | 18476 |
| `RESERVED_BUDGET_SOURCE_ID = '400'` | `OAGBudget/Views/Budget/BudgetTransferDetail.cshtml` | 770 |
| `const balance = raw.fundsAvailable` | เดียวกัน | 1429 |
| คอมเมนต์เตือนเรื่องปีบัญชี vs ปีเอกสาร | เดียวกัน | 226-232 |
| `isReservedSourceSelected` / `syncReservedFilterState` | เดียวกัน | 2266 / 2272 |
| `loadRowsFromSearch` เลือกปีค้นหา | เดียวกัน | 2336-2345 |
| ทับแหล่งเงินแถวตาม `isCrossYear` | เดียวกัน | 2377 |
| DDL view (สำเนา) | `_brain_OAGBUDGET/20260907_.../ddl_OAGWBG_V_BUDGETRECEIVESUMMARY_REFUND.sql` | — |
