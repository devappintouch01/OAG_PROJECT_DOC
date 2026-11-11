# แก้ปัญหา keptcentral หายเมื่อมีคำขอเพิ่มเติม

**วันที่:** 2026-09-21
**ผลกระทบที่วัดได้บน PROD:** 318 แถว / **114,693,702.00 บาท** หายจากหน้าจอและรายงาน (ปีงบ 2570)

---

## สาเหตุ

ระบบ clone คำขอเป็นเวอร์ชันใหม่ (`OAGWBG_BUDGETREQUEST.PARENTID`) ทำให้ BG ของคำขอเดิม
หลุดจาก view ทั้งชุด แต่ตอน duplicate ระบบ **ไม่ได้ copy แถว keptcentral ตามไปด้วย**
ค่าเดิมจึงค้างอยู่กับ BG เก่าที่มองไม่เห็นอีกแล้ว

### 🔑 ตัวกระตุ้น — ปุ่ม "แก้ไข" ในขั้นตอนส่งเรื่องกลับ

**ไม่ใช่ "คำขอเพิ่มเติม" แต่เป็น workflow ส่งเรื่อง → สำนักฯ ตีกลับมาแก้ไข**

```
ศูนย์ต้นทุน กด "ส่งเรื่อง"
        └─► STATUSID = 20101  "ส่งเรื่องให้สำนักบริหารงบประมาณ"
                │
สำนักบริหารงบประมาณ กด "แก้ไข"   (ปุ่ม #btnEdt, pageType="2")
        └─► STATUSID = 20102  "สำนักบริหารงบประมาณดำเนินการแก้ไข"
                │
                └─► UpdateBudgetRequestStatus() เรียก DuplicateBudgetRequest()
                        ├─ สร้าง BUDGETREQUEST ใหม่ (Version=2, PARENTID=เดิม, Statusid=20102)
                        ├─ DuplicatePlanData() copy BG ทุกแถวเป็น BGTYPE='7'
                        └─ ❌ ไม่ copy แถว keptcentral (BGTYPE='4') → orphan ทันที
```

โค้ดที่เกี่ยวข้อง:

| ที่ | ไฟล์ / บรรทัด |
|---|---|
| ปุ่ม "แก้ไข" ตั้ง `statusID = 20102` | `OAGBudget/Views/Budget/BudgetRequestDetail.cshtml` ~625 |
| ตรวจ `StatusId == 20102` แล้วสั่ง duplicate | `BudgetService.cs` → `UpdateBudgetRequestStatus` ~34046 |
| สร้างคำขอลูก | `BudgetService.cs` → `DuplicateBudgetRequest` ~34660 |

```csharp
if (model.StatusId == 20102)
{
    var existing = await _context.OagwbgBudgetrequests.AsNoTracking()
        .FirstOrDefaultAsync(x => x.Id == budgetRequest.Id);

    // duplicate first time only
    if (existing != null && (existing.Parentid == null || existing.Parentid == 0))
    {
        result.Data = await DuplicateBudgetRequest(...);
    }
}
```

**แปลว่าเกิดขึ้นเป็นเรื่องปกติของกระบวนการ ไม่ใช่เคสพิเศษ** — บน PREPROD ยิงไปแล้ว
40 ครั้ง (ปี 2568: 1, **ปี 2569: 37**, ปี 2570: 2) ทุกครั้งที่สำนักฯ ตีกลับมาแก้ไข
keptcentral ของคำขอนั้นจะหายจากจอทันที

สถานะที่เกี่ยวข้อง (`OAGWBG_MASTERSTATUS`):

| ID | NAME |
|---|---|
| 20101 | ส่งเรื่องให้สำนักบริหารงบประมาณ |
| **20102** | **สำนักบริหารงบประมาณดำเนินการแก้ไข** ← trigger |
| 20201 | อนุมัติคำของบประมาณ |

### ① ก่อนสร้างคำขอเพิ่มเติม — ข้อมูลถูก

```
   BUDGETREQUEST 857  (PARENTID = null)
         │ BUDGETREQUESTID
         ▼
   BG 47636  ◄─────────────────── view เห็น ✓
   BGTYPE=null · RUNNING=n
         ▲
         │ REF_BUDGETGOVERNMENTID
   BG 56990
   BGTYPE='4' · KEPTCENTRAL = -36,000

   จอแสดง: เพิ่มเติม = -36,000  ✓
```

### ② 14:12:32 — สำนักฯ กด "แก้ไข" → ระบบ clone คำขอเป็น 1789

```
   BUDGETREQUEST 857 ◄──PARENTID── BUDGETREQUEST 1789 (Version=2, st.20102)
         │                               │
         ▼                               ▼
   BG 47636  ✗ view กรองทิ้ง        BG 73586  ◄── view เห็น ✓
   (ติด NOT EXISTS "มีคำขอลูก")      BGTYPE='7' · RUNNING=n
         ▲                               ▲
         │ REF                           │ REF
   BG 56990                          ((( ว่าง )))
   KEPTCENTRAL = -36,000             ไม่มีใคร copy มาให้
   💰 ยังอยู่ แต่มองไม่เห็น

   จอแสดง: เพิ่มเติม = (ว่าง)
```

### ③ 14:15:43 — เปิดหน้าใหม่

```
   GetGroupBudgetSummaryPlan เห็น ID = null
        └─► INSERT BG 73661 (BGTYPE='4', KEPTCENTRAL = NULL) ──REF──► BG 73586

   จอแสดง: เพิ่มเติม = 0.00   ❌ ของเดิม -36,000 หายสนิท
```

### เงื่อนไขที่กรอง BG แม่ทิ้ง (มีอยู่ในทั้ง 3 view)

```sql
AND NOT EXISTS (
    SELECT 1 FROM OAGWBG_BUDGETREQUEST BR
    WHERE BR.PARENTID IS NOT NULL AND BR.PARENTID = BG.BUDGETREQUESTID
)
```

### จุดที่โค้ดพลาด

`OAGBudget.API/Services/Repository/BudgetService.cs` → `DuplicatePlanData` (~บรรทัด 34702)

```csharp
var oldGovs = await _context.OagwbgBudgetgovernments
    .Where(x => x.Budgetrequestid == oldRequestId)   // ← แถว type-4 มี BUDGETREQUESTID = NULL
    .ToListAsync();                                   //    เลยไม่เคยถูกเห็น

govIdMap[oldGov.Id] = newGov.Id;   // ← เขียน map ไว้ แต่ทั้งไฟล์ไม่มีที่ไหนอ่านมันเลย
```

เหมือนกันที่ `DuplicateProjectData` (~34924) และ `DuplicateProjectsInRequest` (~35259)

---

## หลักฐานจาก PROD

| ตรวจ | ผล |
|---|---|
| `OAGWBG_BUDGETGOVERNMENT` type-4 ปี 2570 | 1,297 แถว / 5,608,560,323.16 |
| `OAGWBG_V_BUDGETREQUESTSUMMARY` ปี 2570 | 970 แถว / 5,493,866,621.16 |
| **ส่วนต่าง** | **327 แถว / 114,693,702.00** |

แยกตามสาเหตุ:

| REASON | CNT | SUM_KEPT |
|---|---|---|
| `0_OK` | 970 | 5,493,866,621.16 |
| **`7_มีคำขอลูก`** (ถูก clone ตอนสำนักฯ กด "แก้ไข") | **318** | **114,693,702** |
| `1_BG แม่ถูกลบ` | 9 | 0 |

ลำดับเหตุการณ์ของคำขอ 1789 (`PARENTID = 857`):

```
2026-06-15 19:20  สร้างแถว keptcentral ของคำขอ 857  (เปิดหน้า)
       ...        กรอกค่าใช้งานมาตลอด 3 เดือน  ← ★ ช่วงที่ข้อมูลถูก
2026-09-21 14:12:32  สำนักฯ กด "แก้ไข" (st.20102) → clone เป็นคำขอ 1789
                     → BG ของ 857 หลุดจาก view ทันที
2026-09-21 14:14:42  กดบันทึกจากหน้าที่เปิดค้างไว้ → เขียน 39 แถวของ 857 สำเร็จ
2026-09-21 14:15:43  เปิดหน้าใหม่ → สร้างแถว keptcentral ใหม่ 19 แถว ค่า NULL
2026-09-21 14:16:20  กดบันทึก → 951 แถวในวินาทีเดียว
```

> ไม่มีใครเขียนทับข้อมูลเดิม — ค่าทั้ง 114.69 ล้านยังอยู่ครบในตาราง
> แค่ REF ชี้ไป BG ของคำขอเก่าที่ view กรองทิ้ง

---

## วิธีแก้ที่เลือก

ใช้ **`RUNNING` เป็น key เชื่อม BG เก่า ↔ ใหม่** เพราะ `DuplicatePlanData` copy
`Running = oldGov.Running` มาตรง ๆ ตรวจกับ PREPROD (คำขอ 722 → 783) แล้ว map 1:1 ครบ 24/24 แถว

> แถว RUNNING=2 มี CATEGORYID ต่างกัน (2199 → 2197) → **RUNNING เชื่อถือได้กว่า category/จำนวนเงิน**

ความปลอดภัยของ key (ตรวจบน PREPROD):

| เช็ค | ผล | ผลต่อการแก้ |
|---|---|---|
| คำขอลึกเกิน 2 ชั้น (มีหลาน) | **0** | ไม่ต้องทำ recursive |
| type-4 ที่ REF ซ้ำ | **0** | เปลี่ยนเป็น `SUM(KEPTCENTRAL)` ได้ปลอดภัย |
| RUNNING ซ้ำในคำขอเดียวกัน | 21 | ใส่ `HAVING COUNT(*) = 1` เป็น guard |
| RUNNING เป็น NULL | 1 | LEFT JOIN ไม่ match เฉย ๆ ไม่พัง |

### รูปแบบการแก้ (เหมือนกันทั้ง 3 view)

```sql
-- [1] คง NULL ไว้ให้ COALESCE ทำงาน (ปลอดภัยเพราะ REF เป็น 1:1)
    SUM(NVL(KEPTCENTRAL,0))  →  SUM(KEPTCENTRAL)

-- [2] เพิ่ม fallback join ผ่าน RUNNING
LEFT JOIN (
    SELECT PBG.BUDGETREQUESTID AS PARENT_REQID, PBG.RUNNING,
           SUM(B4P.KEPTCENTRAL) AS KEPTCENTRAL, MAX(B4P.BUDGETDETAIL) AS BUDGETDETAIL
    FROM OAGWBG_BUDGETGOVERNMENT PBG
    JOIN OAGWBG_BUDGETGOVERNMENT B4P
         ON B4P.REF_BUDGETGOVERNMENTID = PBG.ID AND B4P.BUDGETGOVERNMENTTYPE = '4'
    WHERE PBG.RUNNING IS NOT NULL
    GROUP BY PBG.BUDGETREQUESTID, PBG.RUNNING
    HAVING COUNT(*) = 1
) BG4P ON BG4P.PARENT_REQID = <BR>.PARENTID AND BG4P.RUNNING = BG.RUNNING

-- [3] ของตัวเองก่อน ไม่มีค่อยถอยไปเอาของแม่
    COALESCE(BG4.KEPTCENTRAL, BG4P.KEPTCENTRAL)
```

### ⭐ ข้อมูลย้ายตัวเองอัตโนมัติ

**ไม่แตะคอลัมน์ `ID`** ให้คงเป็น `BG4.ID` (ของแถวใหม่) เหมือนเดิม

`GetGroupBudgetSummaryPlan` (BudgetService.cs ~8888) สร้างแถว type-4 ใหม่โดย
seed `Keptcentral = budgetRequestSummary.Totalkeptcentral` → พอเปิดหน้าครั้งถัดไป
ค่าจากคำขอแม่จะถูกเขียนลงแถวใหม่เอง **ไม่ต้อง migrate ข้อมูลด้วยมือ**

---

## ไฟล์ในโฟลเดอร์นี้

| ไฟล์ | คำอธิบาย |
|---|---|
| `OAGWBG_V_BUDGETREQUESTSUMMARY_new.sql` | DDL แก้แล้ว — `TOTALKEPTCENTRAL`, `TOTALRECEIVEAMOUNT`, `DESCRIPTION` |
| `OAGWBG_R_BUDGETREQUEST_new.sql` | DDL แก้แล้ว — `REQUESTAMOUNT_ADD` ("เพิ่มเติม" ในรายงาน Excel) |
| `OAGWBG_V_BUDGETREQUESTSUMMARYLIST_new.sql` | DDL แก้แล้ว — `TOTALRECEIVEAMOUNT` ("งบประมาณรวม" หัวหน้าจอ) |
| `*_rollback.sql` | DDL เดิม (dump จาก PREPROD 2026-09-21) |
| `preflight_V_BUDGETREQUESTSUMMARY.sql` | read-only ตรวจก่อนแก้ |

### สถานะการตรวจสอบ

| view | parse ผ่าน | row count เท่าเดิม | ไม่ double count |
|---|---|---|---|
| `V_BUDGETREQUESTSUMMARY` | ✅ | ✅ 9693 / 12930 / 2 | ✅ (BG 41028) |
| `R_BUDGETREQUEST` | ✅ | ✅ 9649 / 12894 / 2 | ✅ |
| `V_BUDGETREQUESTSUMMARYLIST` | ✅ | ✅ 5 กลุ่ม | ✅ |

> ⚠️ **ทดสอบการกู้ค่าจริงยังทำไม่ได้** — PREPROD ไม่มี orphan ที่มีค่าและยังไม่ถูกกรอกซ้ำ
> ที่พิสูจน์ได้คือ SQL ถูก / ไม่ fan-out / ไม่ double count
> **การพิสูจน์จริงครั้งแรกคือ preflight [P2] บน PROD**

---

## เงื่อนไขก่อนขึ้น PROD

### 1. แก้ JS ก่อน (ทำแล้ว รอ checkin)

`OAGBudget/Views/Budget/BudgetRequestSummaryDetail.cshtml` บรรทัด ~155

```diff
- totalkeptcentral: parsePrice($grandChild.find('.detail-Totalkeptcentral').val() || 0) || null,
+ totalkeptcentral: keptIsEmpty ? null : parsePrice(keptRaw),
```

**เหตุผล:** เดิม `|| null` ทำให้ค่า `0` ถูกส่งเป็น `null` ระบบจึงแยกไม่ออกระหว่าง
"ตั้งใจใส่ 0" กับ "ไม่เคยกรอก" — **พอมี fallback แล้ว ถ้าผู้ใช้ตั้งใจล้างค่าเป็น 0
ค่าเก่าของคำขอแม่จะผุดกลับมา** ต้องปิดช่องนี้ก่อน (build ผ่าน 0 Error แล้ว)

### 2. ลำดับ deploy

```
1. รัน preflight [P1] → ROWS_ ของ OLD ต้องเท่ากับ NEW (ถ้าไม่เท่า = fan-out หยุด)
2. [P2] ดู 318 แถวที่จะกลับมา ตรวจสัก 5-10 แถวกับผู้ใช้
3. deploy JS
4. GET_DDL จาก PROD เก็บเป็น rollback ของจริง (LAST_DDL_TIME อาจไม่ตรงกับ PREPROD)
5. รัน 3 DDL → SELECT STATUS FROM ALL_OBJECTS ยืนยัน VALID ทั้งหมด
6. เปิดหน้าจอตรวจ + export Excel เทียบไฟล์เดิม
```

---

## งานที่ยังค้าง

1. **ปิดต้นเหตุ (สำคัญสุด)** — `DuplicatePlanData` / `DuplicateProjectData` / `DuplicateProjectsInRequest`
   ให้ duplicate แถว type-4 พร้อม repoint `REF_BUDGETGOVERNMENTID` ด้วย `govIdMap`
   (ตอนนี้ `govIdMap` ถูกสร้างแต่ไม่เคยถูกใช้) → แก้แล้วจะไม่ต้องพึ่ง fallback อีก

   **เร่งด่วนเพราะเป็น workflow ปกติ** ไม่ใช่เคสหายาก ทุกครั้งที่สำนักฯ กด "แก้ไข"
   จะเกิด orphan ใหม่ทันที (PREPROD ยิงไปแล้ว 37 ครั้งในปี 2569 ปีเดียว)

1.1 **ความเสี่ยงแฝง: ตีกลับซ้ำ → คำขอลูก 2 ใบ → ยอดนับซ้ำ**

   guard เขียนว่า `existing.Parentid == null || == 0` ซึ่งเช็คจาก**คำขอที่กำลังอัปเดต**
   ถ้าใครตั้งคำขอ**ต้นฉบับ**เป็น 20102 ซ้ำอีกครั้ง (Parentid ของมันยังเป็น null เสมอ)
   ระบบจะ clone อีกใบ → พ่อ 1 คนมีลูก 2 ใบ → view จะเห็นลูกทั้งสองใบพร้อมกัน
   และ `TOTALREQUESTAMOUNT` จะถูกนับซ้ำ

   ตรวจ PREPROD แล้ว **ยังไม่เคยเกิด** (0 เคสที่ `COUNT(*) > 1` ต่อ PARENTID)
   และตรวจได้ด้วย:
   ```sql
   SELECT PARENTID, COUNT(*) FROM OAGWBG_BUDGETREQUEST
   WHERE PARENTID IS NOT NULL GROUP BY PARENTID HAVING COUNT(*) > 1;
   ```
   guard ที่ถูกต้องต้องเช็ค **ทั้งสองเงื่อนไข** :
   ```csharp
   var hasChild = await _context.OagwbgBudgetrequests
       .FirstOrDefaultAsync(x => x.Parentid == existing.Id) != null;

   // ต้องคง "ตัวเองไม่มีพ่อ" ไว้ด้วย ห้ามตัดทิ้ง
   if ((existing.Parentid == null || existing.Parentid == 0) && !hasChild) { ... }
   ```
   (⚠️ อย่าใช้ `AnyAsync` — พังบน Oracle ด้วย ORA-00904 "FALSE")

   > 🚨 **ห้ามเปลี่ยนเป็น `if (!hasChild)` เฉย ๆ** เงื่อนไข `Parentid == null` คือสิ่งเดียว
   > ที่กันไม่ให้เกิด **หลาน (คำขอ 3 ชั้น)** และ fallback ใน view รองรับแค่ **ชั้นเดียว**
   > (`BG4P.PARENT_REQID = BR.PARENTID`) ถ้ามีหลานเมื่อไร view จะกู้ค่าไม่ได้ทันที

2. **fan-out risk** — `R_BUDGETREQUEST` / `R_BUDGETREQUEST_ASSET` ใช้
   `GROUP BY REF_BUDGETGOVERNMENTID, BUDGETDETAIL` (ต่างจาก `V_BUDGETREQUESTSUMMARY`
   ที่ใช้ REF อย่างเดียว) ถ้าวันไหนมี type-4 หลายแถวต่อ REF ที่ `BUDGETDETAIL` ต่างกัน
   join จะ fan out และ `REQUESTAMOUNT` ถูกนับซ้ำ — ตอนนี้ยังไม่เกิด (REF เป็น 1:1)
   จึงยังไม่แตะเพื่อให้ diff แคบ

3. **`OAGWBG_R_BUDGETREQUEST_ASSET`** — มี BG4 join แบบเดียวกัน แต่ไม่มีคอลัมน์จาก BG4
   ใน select list เลย เป็น **dead join** ไม่กระทบตัวเลข ควรลบทิ้งเพื่อลดภาระ query

4. **บั๊กอื่นที่เจอระหว่างทาง (ยังไม่แก้)**
   - `GetGroupBudgetSummaryPlan` เป็น GET แต่ INSERT ลง DB และไม่มี lock
     → เปิดหน้าพร้อมกันอาจได้แถวซ้ำ
   - สร้างแถว type-4 แค่ **1 แถวต่อ Category** → BG แถวอื่นใน category เดียวกัน
     ได้ keptcentral เป็น NULL ถาวร
   - `SaveBudgetRequestSummaryDetail` สาขา `Id == 0` หาแถวด้วย `RefBudgetgovernmentid`
     เฉย ๆ **ไม่กรอง type ไม่กรองปี** แล้วบังคับ `Budgetgovernmenttype = "4"`
     → อาจกลืนแถวรายการจริงมาเป็นแถว keptcentral (ตรวจแล้วยังไม่เคยเกิด แต่ระเบิดยังฝังอยู่)
   - หน้า summary **ไม่มี optimistic concurrency** — กดบันทึก 1 ครั้งเขียนทุกแถวของทั้ง 4 แท็บ
     (วัดได้จริง: 951 แถวใน `UPDATEON` วินาทีเดียวกัน) ใครเปิดหน้าค้างไว้แล้วกดบันทึก
     จะทับงานคนอื่นทั้งฟอร์ม
