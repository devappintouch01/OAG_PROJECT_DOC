# โอนปรับเงินเหลือจ่าย — กรณี "แหล่งเงินกัน (400)" ทำรายการแล้วยอดเงินไม่ตัดออก

**วันที่วิเคราะห์:** 2026-09-07
**ฟีเจอร์:** โอนปรับเงินเหลือจ่าย (`OAGWBG_BUDGETTRANSFER.TRANSFERTYPE = '3'`)
**หน้าจอ:** `OAGBudget/Views/Budget/BudgetReserveTransferDetail.cshtml`
**Service:** `OAGBudget.API/Services/Repository/BudgetService.cs`
**ฐานข้อมูลที่ใช้ยืนยัน:** PREPROD (172.16.11.19:1541 / ebs_PRE / OAGWBG) — ตรวจจริงเมื่อ 2026-09-07

---

## 1) อาการที่แจ้ง

> "โอนเงินปรับเงินเหลือจ่าย — รายการกรณีแหล่งเงินกัน หลังทำรายการแล้ว ยอดเงินไม่ตัดออก"

= เลือกแถวงบประมาณที่ **แหล่งเงิน 400 (เงินกันเหลื่อมปี)** มาทำโอนปรับเงินเหลือจ่าย แล้วยอดต้นทางไม่ลด

---

## 2) สรุปสาเหตุ (ทั้งหมดยืนยันด้วยข้อมูลจริงบน PREPROD แล้ว)

| # | สาเหตุ | ผลที่เห็น | หลักฐาน |
|---|--------|-----------|---------|
| **A** | **ตัดผิดใบเงินกัน** — giver query ไม่ล็อก `BUDGETRESERVEDCATEGORYID` (และไม่กรอง `PRODUCTID`) เรียงตามยอดคงเหลือมากสุดแล้วตัดจากใบนั้น | ใบที่ผู้ใช้ติ๊กยอดไม่ลด (ใบอื่นในหมวดเดียวกันลดแทน) | ✅ มีข้อมูลจริงที่ชนคีย์ 2 คู่ (ดู §3.3) |
| **B** | **BUDGETCODEID ของแถวเงินกันเป็น NULL** ใน `OAGWBG_V_BUDGETRECEIVESUMMARY_REFUND` → เว็บแทนด้วย `00000000000000000000` | (b1) ตารางที่ 1 โชว์คงเหลือ **0.00** ทุกแถวเงินกัน (b2) ขา CR ของ journal ชี้บัญชีที่ **ไม่มีอยู่จริง** → GL ไม่ถูกตัด | ✅ ยืนยันจาก DDL + GL account (ดู §4) |
| **C** | หน้านี้**ไม่ส่ง GL interface เอง** — พึ่ง view `OAGWBG_V_BUDGET_RESERVE_TRANSFER_DETAIL_INTERFACE` + job ฝั่ง EBS | ยอด GL ไม่ลดทันทีที่กดยืนยัน | ✅ ยืนยันจากโค้ด + DDL (ดู §5) |

> **ข้อเท็จจริงสำคัญจาก PREPROD:** ยังไม่เคยมีรายการโอนปรับเงินเหลือจ่ายใบไหนตัดจากแถวแหล่งเงิน 400 สำเร็จเลย
> — link ทั้งหมด 28 แถวจาก 17 ใบ ตัดจากแหล่งเงิน **100** ทั้งหมด และหัวเอกสารทุกใบมี `BUDGETSOURCEID = '100'`
> ```
> GIVER_SRC | GIVER_TYPE | LINKS | TRANSFERS
> 100       | G          | 27    | 16
> 100       | A          |  1    |  1
> (แหล่ง 400 = 0 แถว)
> ```
> ⚠️ ต้องขอ **เลขที่รายการ (TRANSFERNO/ROUNDNO)** ของใบที่ผู้ใช้ทดสอบ เพื่อระบุว่าใบนั้นตกที่สาเหตุ A หรือ B/C
> (ถ้าไม่ใช่บน PREPROD ให้ระบุ environment ด้วย)

---

## 3) สาเหตุ A — ตัดผิดใบเงินกัน

### 3.1 เงินกันถูกเก็บยังไง

`BudgetService.cs:28392-28412` (SaveBudgetReservedInterface) สร้างถังเงินกันลง `OAGWBG_BUDGETRECEIVE`:

```csharp
Budgetreceivetype        = "O",
Budgetreservedid         = item.Budgetreservedid,
Budgetreservedcategoryid = item.Id,     // ← ระบุว่ามาจากใบเงินกันใบไหน
Budgetsourceid           = "400",
Budgetyear               = budget.Budgetyear,
```

**1 หมวด/ศูนย์ต้นทุน/ปี มีได้หลายแถว** แยกกันด้วย `BUDGETRESERVEDCATEGORYID` เท่านั้น

### 3.2 API เลือกแถวที่จะตัดยังไง — `BudgetService.cs:26710-26728`

```csharp
var giverQuery = _context.OagwbgBudgetreceives
    .Where(x => (x.Budgetreceivetype != "T" && x.Budgetreceivetype != "R")
             && x.Departmentid == dept
             && x.Costcenterid == cost
             && x.Budgetyear   == yearOfGroup
             && x.Categoryid   == categoryId);

if (fromSrcId != null)                                   // กรองแค่ "แหล่งเงิน" (400)
    giverQuery = giverQuery.Where(x => x.Budgetsourceid == fromSrcId);

var giverRows = await giverQuery
    .OrderByDescending(x => x.Totalbalanceamount ?? 0m)   // ← ตัดจากใบที่ยอดเยอะสุดก่อน
    .ThenBy(x => x.Id)
    .ToListAsync();
```

**ไม่มี** เงื่อนไข `Budgetreservedcategoryid` และ **ไม่มี** เงื่อนไข `Productid`
→ ทุกใบเงินกันในหมวดเดียวกันถูกรวมเป็นกองเดียว แล้วไล่ตัดจากใบที่ยอดเยอะสุด (`:26766-26800`)

### 3.3 ข้อมูลจริงที่ทำให้เกิดอาการ (PREPROD)

จำลองลำดับที่โค้ดจะเลือกตัด (dept 2900600000 / cc 2906999999 / ปี 2568 / แหล่ง 400):

```
CATEGORYID | RECEIVE_ID | RESCAT | RESERVEDNO | RECV        | BAL         | ลำดับที่โค้ดจะตัด
2213       | 52114      | 16     | 68030004   | 5,000       | 5,000       | 1  ← ถูกตัดก่อนเสมอ
2213       | 52072      | 14     | 68030003   | 1,000       | 1,000       | 2
27125      | 53467      | 27     | 681203     | 25,837,440  | 25,837,420  | 1  ← ถูกตัดก่อนเสมอ
27125      | 53447      | 22     | 68030006   | 6,000       | 6,000       | 2
```

**เคสจริงที่จะพัง:** ผู้ใช้ติ๊กใบเงินกัน `68030003` (หมวด 2213, คงเหลือ 1,000) แล้วกรอก 1,000
→ โค้ดไปตัดใบ `68030004` แทน → เปิดดูใบ `68030003` **ยอดยังเท่าเดิม = "ยอดเงินไม่ตัดออก"**
เช่นเดียวกับหมวด 27125 (ติ๊กใบ `68030006` แต่ไปตัดใบ `681203`)

### 3.4 หน้าบ้านไม่ได้ส่งข้อมูลใบเงินกันไปเลย

`BudgetReserveTransferDetail.cshtml:2753-2768` (payload ที่ส่งไป save):

```javascript
selectedItems.push({
    Id: item.id, Categoryid: item.categoryId || null, ...
    Budgetsourceid: "200",
    Frombudgetsource: item.fromBudgetSource || null,
    Budgetcodeid: item.budgetCodeId || null,
    // ❌ ไม่มี Budgetreservedcategoryid
});
```

`grep -n "reservedCategoryId" BudgetReserveTransferDetail.cshtml` → **ไม่พบเลยทั้งไฟล์**

ทั้งที่ทุกชั้นรองรับอยู่แล้ว:
- View ส่งค่ามาให้แล้ว: `OAGWBG_V_BUDGETRECEIVESUMMARY_REFUND.BUDGETRESERVEDCATEGORYID` (group by ระดับใบ)
- API map ให้แล้ว: `BudgetService.cs:18128-18130` (`Budgetreservedcategoryid`, `Reservedno`, `Reservedbudgetyear`)
- DTO มีฟิลด์แล้ว: `OAGBudget.Models/Data/BudgetTransferDetailModel.cs:58-64`

### 3.5 เทียบกับหน้า "โอนเงินกลับ" (`SaveBudgetTransferDetailV2`) ที่แก้เคสนี้ไปแล้ว

| จุด | โอนเงินกลับ (V2) — ถูก | โอนปรับเงินเหลือจ่าย — ยังไม่มี |
|---|---|---|
| หน้าบ้านส่ง `Budgetreservedcategoryid` | ✅ `BudgetTransferDetail.cshtml:3310` | ❌ |
| group key มีใบเงินกัน | ✅ `k.ReservedCategoryId, k.Id` (`:20370`) | ❌ (`:26595`) |
| ล็อก giver ด้วยใบเงินกัน | ✅ `:20515-20519` | ❌ |
| กรอง giver ด้วยผลผลิต | ✅ `:20505-20506` | ❌ |
| ปีที่ใช้หา giver | ✅ `g.BudgetYear ?? year.Value` (`:20478`) | ⚠️ `year.Value` flat (`:26687`) |
| link เก็บปี/แหล่งเงินต้นทาง | ✅ `yearOfSource`, `srcId` (`:20662-20679`) | ❌ `receiveBudgetYear`, `"200"` (`:26851-26880`) |

คอมเมนต์ใน V2 (`BudgetService.cs:20515-20517`) เขียนบั๊กนี้ไว้ตรง ๆ:

> เงินกันเหลื่อมปี: 1 หมวดอาจมีหลายใบเงินกัน (BUDGETRESERVEDCATEGORYID ต่างกัน)
> ถ้าไม่ล็อกใบ giverRows จะรวมทุกใบแล้วตัดจากใบที่ยอดเยอะสุดก่อน = **ตัดผิดใบ**

**→ เป็นบั๊กเดียวกันเป๊ะ ที่แก้ไปแล้วบนหน้าโอนเงินกลับ แต่ยังไม่ได้ port มาหน้านี้**

> **หมายเหตุ:** หน้าโอนเปลี่ยนแปลง (`SaveBudgetTransferDetail`, `:20027-20034`) แย่กว่านั้นอีก —
> ไม่กรองแม้แต่ `BUDGETSOURCEID` จึงตัดข้ามแหล่งเงินได้ (100 ไปกิน 400) ควรตรวจแยกอีกรอบ
> (ในข้อมูลจริงมีแถวเงินกันที่ยอดถูกตัดไปแล้วโดยไม่มี link: RESCAT 2 → 1,000,000 เหลือ 69,050,
> RESCAT 37 → 200,000 เหลือ 199,000, RESCAT 27 → ถูกตัด 20 บาท)

---

## 4) สาเหตุ B — BUDGETCODEID ของแถวเงินกันหาย → SEGMENT9 เป็นศูนย์

### 4.1 View ไม่ได้ดึงเลขงบประมาณของใบเงินกัน

`OAGWBG_V_BUDGETRECEIVESUMMARY_REFUND` หา `BUDGETCODEID` จาก 4 ทางเท่านั้น:

```sql
COALESCE(BCC_A.BUDGETCODEID,   -- TYPE 'A'
         BCC_G.BUDGETCODEID,   -- TYPE 'G'
         BCY_P1.BUDGETCODEID,  -- ต้องมี BUDGETRECEIVEPERIOD + PERIOD_TYPE = 1
         BCY_P2.BUDGETCODEID)  -- ต้องมี BRP.BUDGETGOVERNMENTID / BRP.BUDGETSOURCEID
```

แถวเงินกัน (`TYPE = 'O'`) มี `BUDGETRECEIVEPERIODID = NULL` → BRP เป็น null → ทั้ง BCY_P1/BCY_P2 join ไม่ติด
→ **BUDGETCODEID = NULL ทุกแถวเงินกัน** (ยืนยันจากข้อมูลจริง — ทุกแถวที่มี RESERVEDNO ได้ `(null)`)

ทั้งที่ค่าจริงมีอยู่ในตาราง `OAGWBG_BUDGETRESERVED_CATEGORY.BUDGETCODEID` แล้ว (9 จาก 10 แถวมีค่า):

```
RECEIVE_ID | RESCAT | RESERVEDNO | RSC_CODE (ค่าที่ถูกต้อง)   | ค่าที่ view คืน
52072      | 14     | 68030003   | 29006630001004100280      | (null)
52114      | 16     | 68030004   | 29006630001004100280      | (null)
53447      | 22     | 68030006   | 29006500000000000000      | (null)
53467      | 27     | 681203     | 29006500000000000000      | (null)
55149      | 37     | 68030008   | 29006630001004100204      | (null)
```

### 4.2 เว็บแทน NULL ด้วยเลขศูนย์ แล้วใช้ต่อทั้ง 2 ทาง

`BudgetService.cs:18124` → `Budgetcodeid = x.Budgetcodeid ?? "00000000000000000000"`

**(b1) ตารางที่ 1 โชว์ 0.00** — `SearchBudgetTransferDetail` เอา 13 segment ไปหา CCID
(`:18211-18256`) ถ้าไม่เจอ `codeCombinationId == 0` → `continue` → `FundsAvailable = null`
และคอลัมน์ "จำนวนเงินคงเหลือ" ของตารางที่ 1 คือค่านี้ (`BudgetReserveTransferDetail.cshtml:1897-1901`)

ตรวจบน GL จริง:
```
บัญชี 2900600000.2906999999.68.400.*                        → มีจริง 7 บัญชี
บัญชี 2900600000.2906999999.68.400.*.00000000000000000000.* → 0 บัญชี  ← หาไม่เจอแน่นอน
```
บัญชี 68-400 ที่มีจริงล้วนมี SEGMENT9 เป็นเลขงบประมาณจริง เช่น
`...68.400.20000.21000.21100.241001.29006630001004100281.1211010102.500005.00.000`

ผลข้างเคียงต่อเนื่อง: เพดานยอดโอนหน้าบ้าน (`getRowBalanceCap`, `:1053-1060`) คืน `null` เมื่อยอด ≤ 0
→ **ไม่มีการกันกรอกเกิน** และด่าน `find_budget` ฝั่ง API ก็ถูกปิดไว้ตั้งแต่ 2026-09-02 (`:26635-26680`)

**(b2) ขา CR ของ journal ชี้บัญชีที่ไม่มีจริง** — link เก็บ `BUDGETCODEID = '00000000000000000000'`
และ view interface ใช้ `NVL(BRR_BUDGETCODEID, EAR_BUDGETCODE) AS SEGMENT9` — ค่าเลขศูนย์ไม่ใช่ NULL
NVL จึงไม่ fallback → SEGMENT9 = ศูนย์ทั้งชุด → **ไม่มี code_combination_id ให้ post → ยอด GL ไม่ถูกตัด**

---

## 4.3) 4 คอลัมน์ยอดในตารางที่ 1 มาจากไหน — และแหล่งเงิน 400 หาบัญชีไม่เจอกี่แถว (ตรวจ 2026-09-08)

> 📊 **แผนภาพลำดับการทำงานเต็ม (กดค้นหา → ข้อมูลแสดง):** ดู [`flow_search_to_display.md`](flow_search_to_display.md)

คอลัมน์ **จำนวนเงินจัดสรร / จำนวนเงินกันไว้เบิก / จำนวนเงินเบิกจ่าย / จำนวนเงินคงเหลือ**
(`BudgetReserveTransferDetail.cshtml:312-315`) = `budget / encumbrance / actual / fundsAvailable`
ซึ่ง **มาจาก EBS GL ล้วน ๆ** ผ่าน `APPS.OAG_GL_FUNDS_AVAILABLE_PKG_BYPASS` ต่อชุดบัญชี 13 segment ของแถวนั้น
(`BudgetService.cs:18200-18400`) — **ไม่ได้อ่านจากถังเว็บ** (`OAGWBG_BUDGETRECEIVE.TOTALBALANCEAMOUNT`) เลย

⇒ ทำรายการบนเว็บเสร็จ ตัวเลข 4 ช่องนี้ **จะไม่ขยับ** จนกว่า journal จะเข้า GL จริง (ดู §5)

**จำลองการหาบัญชีแบบเดียวกับโค้ดกับแถวแหล่งเงิน 400 ทั้ง 28 แถว (read-only):**

| ผลลัพธ์ | จำนวนแถว | หน้าจอจะแสดง |
|---|---|---|
| หา `CODE_COMBINATION_ID` เจอ | **8** | ตัวเลขจริงจาก GL |
| หาไม่เจอ → โค้ด `continue` (`:18256`) | **20** | 0.00 ทั้ง 4 ช่อง |

แถวที่หาบัญชีเจอ (จึง "มียอดแสดง") — เป็นแถวชนิด `A` (จัดสรร) ทั้งหมด และยังไม่เคยถูกใช้เลย (`USED = 0`):

```
RECEIVE_ID | CC         | ปี   | หมวด  | CCID   | ยอดถัง
53460      | 2900600001 | 2568 | 2161  | 129490 | 150
51079      | 2900600001 | 2568 | 2480  | 88480  | 118,900   (จาก 'A' 4 แถวรวมกัน)
53461      | 2900600027 | 2568 | 2161  | 129487 | 100
51153      | 2900600027 | 2569 | 2160  | 97489  | 30
51154      | 2900600030 | 2569 | 2160  | 97480  | 20
51155      | 2900600037 | 2569 | 2160  | 97483  | 40
51156      | 2900600049 | 2569 | 2160  | 97486  | 10
52143      | 2900600001 | 2569 | 2468  | 119480 | 10,000
```

**แถวเงินกันจริง (มีเลขที่เงินกัน) หาบัญชีไม่เจอทุกแถว** เพราะ SEGMENT9 เป็นเลขศูนย์ (§4.1-4.2) เช่น
`2900600000.2906999999.68.400.20000.21000.21100.212001.00000000000000000000.5104010107.230003.00.000`

**แถวเงินกันที่ฝั่งเว็บถูกตัดยอดไปแล้วจริง มี 3 แถว** (ตัดโดย flow จัดสรร ซึ่งสร้างแถว `A` ใหม่คู่กัน ไม่ใช่โอนปรับเหลือจ่าย):

```
RECEIVE_ID | ใบเงินกัน  | RECV       | BAL        | ใช้ไป   | UPDATEON
53467      | 681203    | 25,837,440 | 25,837,420 | 20      | 2026-08-31 16:18  (คู่กับ 'A' id 55236 = 20)
55149      | 68030008  | 200,000    | 199,000    | 1,000   | 2026-08-21 14:13  (คู่กับ 'A' id 55150 = 1,000)
51068      | (ไม่มีเลข) | 1,000,000  | 69,050     | 930,950 | 2026-08-15 15:04
```

⚠️ ทั้ง 3 แถวนี้ SEGMENT9 เป็นศูนย์ → บนหน้าจอควรแสดง **0.00** ไม่ใช่ "ยังมียอด"
⇒ แถวที่ผู้ใช้เห็นว่า "ยังมียอดแสดงทั้งที่ทำรายการไปแล้ว" **ต้องเป็นแถวใน 8 แถวข้างบน** (ชนิด `A`)
   ต้องขอ ศูนย์ต้นทุน + ปี + หมวด (หรือภาพหน้าจอ) และรายการที่ทำ เพื่อ trace ต่อว่า journal ลงบัญชีไหน

---

## 5) สาเหตุ C — หน้านี้ไม่ส่ง GL เอง (ยอดจึงไม่ลดทันที)

`SaveBudgetReserveTransfer(int? id)` เขียนแค่ `OAGWBG_RECEIVE_BATCH_NO` แล้ว return ทันที
(`BudgetService.cs:15108-15113`) — โค้ดสร้าง journal ทั้งก้อนใต้บรรทัดนั้นถูกคอมเมนต์ทิ้ง (`:15116-15270`)

```csharp
//ไม่ต้อง interface
return new ApiResultsModel { Success = true, Type = "S" };
```

`ConfirmBudgetReserveTransfer` (`:27032-27094`) เรียกเมธอดนี้แล้วอัปสถานะเป็น 80201 เท่านั้น
journal มาจาก view `OAGWBG_V_BUDGET_RESERVE_TRANSFER_DETAIL_INTERFACE` ที่ EBS ดึงไปเอง

โครงสร้างขาบัญชีของ view (ยืนยันจาก DDL จริง):

| ขา | TYPE | SEGMENT1/2 | SEGMENT3 | SEGMENT4 | SEGMENT9 | ยอด |
|---|---|---|---|---|---|---|
| ตัดออก (CR) | `O` | GIVERDEPARTMENTID / GIVERCOSTCENTERID | `MOD(BT_BUDGETYEAR,100)` = ปีหัวเอกสาร | `GIVERSOURCE` (join `BRR.GIVERID`) ✅ | `NVL(BRR_BUDGETCODEID, EAR_BUDGETCODE)` | `ENTERED_CR` |
| รับเข้า (DR) | `I` | GIVERDEPARTMENTID / GIVERCOSTCENTERID | `MOD(BRR_BUDGETYEAR,100)` = ปีตาม TRANSFERDATE | `'200'` ฮาร์ดโค้ด | เหมือนกัน | `ENTERED_DR` |

ตัวอย่างผลลัพธ์จริงของใบที่ใช้แหล่งเงิน 100 (ทำงานถูกต้อง):
```
O | 6810031 | ... | SEG3=68 | SEG4=100 | SEG9=29006630001004100206 | CR 600
I | 6810031 | ... | SEG3=69 | SEG4=200 | SEG9=29006630001004100206 | DR 600
```

→ **`SEGMENT4 = GIVERSOURCE` ทำงานถูกกับ 400 อยู่แล้ว ไม่ใช่ปัญหา** ปัญหาอยู่ที่ `SEGMENT9` (§4.2)

---

## 5.1) สิ่งที่แก้ไปแล้ว (2026-09-08) — ทำตามหน้าโอนเงินกลับ

แก้ **สาเหตุ A** เรียบร้อย โดย port พฤติกรรมของ `SaveBudgetTransferDetailV2` (โอนเงินกลับ) มาทั้งชุด
**ยังไม่ได้ checkin เข้า TFS**

**`OAGBudget/Views/Budget/BudgetReserveTransferDetail.cshtml`**

| บรรทัด | สิ่งที่แก้ |
|---|---|
| 946-947 | `normalizeIds()` อ่าน `budgetreservedcategoryid` / `reservedno` จาก response |
| 984, 1008-1009 | `buildLeafRow()` ผูก `data-reservedcategoryid` / `data-reservedno` ที่ checkbox |
| 1182-1186, 1211 | `upsertSelectionFromRow()` เก็บใบเงินกันลง `__selectionState` |
| 1390 | `normalizeSelectionToUnified()` ส่งค่าต่อไปแท็บ 2 |
| 1452-1464 | `normalizeApiRowToUnified()` อ่านค่าจากใบเดิม + ต่อท้ายชื่อหมวดเป็น `[เงินกัน <เลขที่>]` |
| 1484-1485 | `buildTab2Items()` เติมใบเงินกันจากแถวที่ติ๊กในตารางที่ 1 ให้แถวที่โหลดจากใบเดิม |
| 1959-1960 | ตารางที่ 1 แสดง `[เงินกัน <เลขที่>]` ท้ายชื่อหมวด (แยกใบได้ด้วยตา) |
| 2803 | payload ส่ง `Budgetreservedcategoryid` ไป save |

**`OAGBudget.API/Services/Repository/BudgetService.cs` — `ExecuteBudgetReservedTransferCoreAsync`**

| บรรทัด | สิ่งที่แก้ |
|---|---|
| 26592-26612 | เพิ่ม `ReservedCategoryId` ทั้งใน select และ group key (หลายใบในหมวดเดียวกันไม่ถูกยุบรวม) |
| 26724-26727 | กรอง giver ด้วย `Productid` เมื่อรายการระบุผลผลิตมา |
| 26735-26740 | **ล็อก giver ด้วย `Budgetreservedcategoryid`** ← แก้อาการหลัก |
| 26757-26760 | ข้อความ error ตอนหา giver ไม่เจอ บอกผลผลิต/รายการเงินกันด้วย |

**ผลการตรวจสอบ**
- Build: `OAGBudget.API` และ `OAGBudget` → **0 Error** (build ลง output แยก เพราะ bin ปกติถูกล็อกโดยแอปที่รันอยู่ + VS)
- จำลอง query หลังแก้กับข้อมูลจริง (dept 2900600000 / cc 2906999999 / ปี 2568 / หมวด 2213 / แหล่ง 400
  / ผลผลิต 21000 / ใบเงินกัน 14) → คืน **แถวเดียว** คือ `ID 52072 = ใบ 68030003` (เดิมจะคืน 2 แถวแล้วไปตัดใบ 68030004)

**ข้อจำกัดที่ยังเหลือ (เหมือนหน้าโอนเงินกลับทุกประการ)**
- `GetBudgetTransferDetail` (API ที่ใช้โหลดใบเดิม, `:17584-17630`) ยังไม่ map `Budgetreservedcategoryid`
  → ถ้าเปิดใบเดิมแล้วกดบันทึกทันทีโดยไม่กดค้นหาใหม่ในตารางที่ 1 การล็อกใบจะเป็น null (พฤติกรรมเดิม)
  → บรรเทาแล้วบางส่วนด้วยการ merge ที่ `buildTab2Items()` (ถ้าผู้ใช้กดค้นหาแล้วติ๊กแถวเดิม จะได้ใบที่ถูกต้อง)
  → แก้ถาวรต้องเพิ่ม map ที่ API ตัวนี้ ซึ่งกระทบหน้าโอนเงินกลับด้วย (ยังไม่ได้ทำ)
- **สาเหตุ B ยังไม่ได้แก้** — ตารางที่ 1 ของแถวเงินกันยังโชว์ 0.00 และขา CR ของ journal ยังได้ SEGMENT9
  เป็นเลขศูนย์ → **ยอดใน GL ยังไม่ถูกตัดอยู่ดี** ต้องแก้ที่ view (ดู §6 "แก้ B")

---

## 6) แนวทางแก้

### แก้ A — ล็อกใบเงินกัน (port จาก V2) ★ ทำก่อน — R1

1. **หน้าบ้าน** `BudgetReserveTransferDetail.cshtml`
   - เก็บ `budgetreservedcategoryid` จาก response ตอน render ตารางที่ 1/2 (แบบเดียวกับ `BudgetTransferDetail.cshtml:1053, 1332, 1750`)
   - ส่งใน payload: `Budgetreservedcategoryid: item.reservedCategoryId ?? null`
2. **API** `ExecuteBudgetReservedTransferCoreAsync`
   - เพิ่ม `ReservedCategoryId` เข้า group key (`:26578-26608`)
   - เพิ่มเงื่อนไข giver ก่อน `OrderByDescending` (`:26723`):
     ```csharp
     if (reservedCategoryId != null)
         giverQuery = giverQuery.Where(x => x.Budgetreservedcategoryid == reservedCategoryId);
     if (!string.IsNullOrWhiteSpace(prodId))
         giverQuery = giverQuery.Where(x => x.Productid == prodId);
     ```
   - เติมข้อมูลใบเงินกันในข้อความ error ตอนหา giver ไม่เจอ (ตาม V2 `:20530-20538`)

- **Blast radius:** เฉพาะ flow บันทึกโอนปรับเงินเหลือจ่าย — ใบเก่าที่ตัดผิดไปแล้วไม่ถูกแก้ย้อนหลัง
- **ระวัง:** เคสที่เดิม "ตัดข้ามใบได้" จะกลายเป็น error `ไม่พบแถวงบประมาณต้นทาง` หรือปล่อยให้ใบนั้นติดลบแทน
  (ด่านตรวจยอดถูกปิดไว้ทั้ง 2 ชั้นตั้งแต่ 2026-09-02: `:26635-26680`, `:26749-26766`)

### แก้ B — คืน BUDGETCODEID ให้แถวเงินกัน — R1

เพิ่ม `RSC.BUDGETCODEID` เข้า COALESCE ของ `OAGWBG_V_BUDGETRECEIVESUMMARY_REFUND`
(view join `OAGWBG_BUDGETRESERVED_CATEGORY RSC` อยู่แล้ว ใช้ต่อได้ทันที ไม่ต้องเพิ่ม join):

```sql
COALESCE(BCC_A.BUDGETCODEID, BCC_G.BUDGETCODEID,
         BCY_P1.BUDGETCODEID, BCY_P2.BUDGETCODEID,
         RSC.BUDGETCODEID)          -- ← เพิ่มบรรทัดนี้ (ต้องใส่ใน GROUP BY ด้วย)
```

ได้ผล 2 ต่อ: ตารางที่ 1 แสดงยอดคงเหลือจาก GL ได้จริง + SEGMENT9 ของ journal ชี้บัญชีที่มีอยู่จริง
- ต้องทดสอบ regression: view นี้ถูกใช้ทั้งหน้าโอนกลับ/โอนปรับเหลือจ่าย/dropdown เลขที่เงินกัน
- ต้อง deploy เป็น SQL script + rollback script ตามแนวทางโฟลเดอร์ `_brain_OAGBUDGET` เดิม
- ทางเลือกเสริม (ถ้าไม่อยากแตะ view): แก้ `:18124` ไม่ให้ default เป็นเลขศูนย์ แล้ว fallback เป็น NULL
  เพื่อให้ `NVL(BRR_BUDGETCODEID, EAR_BUDGETCODE)` ใน view ทำงาน — แต่แก้ที่ view ตรงกว่า

### แก้ C — สื่อสารรอบ interface (ไม่ใช่บั๊ก)
ถ้าผู้ใช้คาดหวังว่ายอด GL ลดทันทีหลังกดยืนยัน ต้องอธิบายว่าฟีเจอร์นี้ post ผ่าน view + job ของ EBS
หรือไม่ก็เปิด interface ฝั่งเว็บกลับ (โค้ดยังอยู่ครบที่ `:15116-15270`) — **R0/R1 ต้องคุยกับ BA ก่อน**

---

## 7) SQL ที่ใช้ยืนยัน (rerun ได้)

```sql
-- 7.1 ใบเงินกันที่ชนคีย์เดียวกัน = เคสที่จะตัดผิดใบ
SELECT DEPARTMENTID, COSTCENTERID, BUDGETYEAR, CATEGORYID,
       COUNT(*) AS ROWS_IN_KEY, COUNT(DISTINCT BUDGETRESERVEDCATEGORYID) AS RESERVED_DOCS
  FROM OAGWBG_BUDGETRECEIVE
 WHERE BUDGETSOURCEID = '400' AND BUDGETRECEIVETYPE = 'O'
 GROUP BY DEPARTMENTID, COSTCENTERID, BUDGETYEAR, CATEGORYID
HAVING COUNT(*) > 1;

-- 7.2 BUDGETCODEID ที่หายไปของแถวเงินกัน (view vs ค่าจริง)
SELECT BR.ID, BR.BUDGETRESERVEDCATEGORYID, RS.TRANSFERNO AS RESERVEDNO,
       RSC.BUDGETCODEID AS CODE_จริง, V.BUDGETCODEID AS CODE_ที่_VIEW_คืน
  FROM OAGWBG_BUDGETRECEIVE BR
  LEFT JOIN OAGWBG_BUDGETRESERVED_CATEGORY RSC ON RSC.ID = BR.BUDGETRESERVEDCATEGORYID
  LEFT JOIN OAGWBG_BUDGETRESERVED RS ON RS.ID = RSC.BUDGETRESERVEDID
  LEFT JOIN OAGWBG_V_BUDGETRECEIVESUMMARY_REFUND V ON V.ID = BR.ID
 WHERE BR.BUDGETRECEIVETYPE = 'O';

-- 7.3 ใบที่ผู้ใช้ร้องเรียน (ใส่เลขที่โอน) — ดูว่าไปตัดใบไหนจริง
SELECT T.ID, T.TRANSFERNO, T.BUDGETYEAR AS HDR_YR,
       RF.ID AS LINK_ID, RF.BUDGETYEAR AS LINK_YR, RF.BUDGETSOURCEID AS LINK_SRC,
       RF.BUDGETCODEID AS LINK_CODE, RF.TOTALREFUNDAMOUNT AS AMT,
       G.ID AS GIVER_ID, G.BUDGETSOURCEID AS GIVER_SRC, G.BUDGETRESERVEDCATEGORYID AS GIVER_RESCAT,
       G.TOTALBALANCEAMOUNT AS G_BAL, G.REFUNDAMOUNT AS G_REFUND
  FROM OAGWBG_BUDGETTRANSFER T
  JOIN OAGWBG_BUDGETRECEIVEREFUND RF ON RF.TRANSFERID = T.ID
  LEFT JOIN OAGWBG_BUDGETRECEIVE G ON G.ID = RF.GIVERID
 WHERE T.TRANSFERTYPE = '3' AND T.TRANSFERNO = :transferNo;

-- 7.4 บรรทัด journal ที่ view จะส่งให้ EBS
SELECT TYPE, WEB_BATCH_NO, TRANSFER_NO, SEGMENT3, SEGMENT4, SEGMENT9, ENTERED_DR, ENTERED_CR
  FROM OAGWBG_V_BUDGET_RESERVE_TRANSFER_DETAIL_INTERFACE
 WHERE TRANSFER_NO = :roundNo;

-- 7.5 บัญชี GL ของชุด segment (ตรวจว่าเลขงบประมาณศูนย์หาบัญชีไม่เจอ)
SELECT ACCOUNT_CODE, CODE_COMBINATION_ID
  FROM APPS.OAGGL_ACCOUNT_HIERARCHIES_V
 WHERE ACCOUNT_CODE LIKE '2900600000.2906999999.68.400.%';
```

---

## 8) ที่ยังต้องถามผู้ใช้

1. **เลขที่รายการ (TRANSFERNO / ROUNDNO)** ของใบที่ทดสอบ + environment (PREPROD/TEST/PROD)
   — เพราะบน PREPROD ยังไม่มีใบไหนตัดจากแหล่งเงิน 400 เลย
2. ดู "ยอดไม่ตัด" จากหน้าจอไหน — ตารางที่ 1 ของหน้านี้ / รายงานเงินกัน / EBS
   (แต่ละที่คนละสาเหตุ: ตารางที่ 1 = §4-b1, EBS = §4-b2 + §5)
3. ถ้าตอนบันทึกเจอ error `ไม่พบแถวงบประมาณต้นทางสำหรับตัดยอด...` ให้ส่งข้อความเต็มมาด้วย

---

## 9) ไฟล์/บรรทัดที่เกี่ยวข้อง

| ไฟล์ | บรรทัด | เรื่อง |
|---|---|---|
| `OAGBudget.API/Services/Repository/BudgetService.cs` | 26463-26925 | `ExecuteBudgetReservedTransferCoreAsync` |
| ” | **26710-26728** | giver query ที่ขาดการล็อกใบเงินกัน ← **จุดบั๊ก A** |
| ” | 26851-26880 | สร้าง link (ทับแหล่งเงิน 200 / ปีที่ทำรายการ / code ศูนย์) |
| ” | 15044-15115 | `SaveBudgetReserveTransfer(id)` — return ก่อนส่ง interface |
| ” | 27032-27104 | `ConfirmBudgetReserveTransfer` |
| ” | 20185-20790 | `SaveBudgetTransferDetailV2` (ตัวอย่างที่แก้ถูกแล้ว) |
| ” | 20027-20034 | `SaveBudgetTransferDetail` (โอนเปลี่ยนแปลง — ไม่กรองแหล่งเงินเลย) |
| ” | **18124** | default `BUDGETCODEID` เป็นเลขศูนย์ ← **จุดบั๊ก B** |
| ” | 18200-18330 | คำนวณ funds available จาก GL |
| ” | 28392-28412 | สร้างถังเงินกัน type `O` / source `400` |
| `OAGBudget/Views/Budget/BudgetReserveTransferDetail.cshtml` | 1897-1901 | คงเหลือ = `fundsAvailable` |
| ” | 2753-2768 | payload ที่ไม่ได้ส่ง `Budgetreservedcategoryid` |
| `OAGBudget/Views/Budget/BudgetTransferDetail.cshtml` | 3310 | ตัวอย่างหน้าบ้านที่ส่งค่านี้ถูกแล้ว |
| `OAGBudget.Models/Data/BudgetTransferDetailModel.cs` | 47-65 | `ReceiveSummaryList` (มีฟิลด์รองรับอยู่แล้ว) |
| DB view | — | `OAGWBG_V_BUDGETRECEIVESUMMARY_REFUND` (COALESCE ที่ไม่ครอบคลุม type `O`) |
| DB view | — | `OAGWBG_V_BUDGET_RESERVE_TRANSFER_DETAIL_INTERFACE` (journal ขา DR/CR) |
