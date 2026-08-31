# วิเคราะห์ `OAGWBG_R_BUDGETOVERLAP_CATEGORY` — รายงานกันเงินงบประมาณเรียกไม่ออก (timeout)

> **วันที่วิเคราะห์:** 2026-08-27
> **อาการที่แจ้ง:** รายงานกันเงินงบประมาณ export ไม่ออก ขึ้น error timeout ที่ประมาณ 90 วินาที
> **ขอบเขต:** เจาะเฉพาะ view `OAGWBG_R_BUDGETOVERLAP_CATEGORY` (Template 1 — รายงานเงินไว้เบิกเหลื่อมปี)
> **สภาพแวดล้อมที่วัด:** Oracle PREPROD `172.16.11.19:1541 / ebs_PRE` ผ่าน VPN (F5 BIG-IP) — ตัวเลขทุกตัวในเอกสารนี้วัดจริง
>
> **🟢 สถานะ: แก้แล้ว — deploy ลง PREPROD เมื่อ 2026-08-27** (ดูข้อ 11) — ยังไม่ได้ deploy ขึ้น PROD

---

## 0. สรุปสั้น (TL;DR)

| ประเด็น | ข้อสรุป |
|---|---|
| **ปัญหาอยู่ที่ไหน** | **Oracle view ไม่ใช่โค้ด C#** — `COUNT(*)` เปล่า ๆ ยังเกิน 300 วินาที ทั้งที่ข้อมูลจริงมีแค่ 63 แถว |
| **ทำไม 90 วิ** | `new HttpClient()` ใน `ClientService.CreateClient()` ไม่ตั้ง `Timeout` → ใช้ default **100 วินาที** แล้วโยน `TaskCanceledException` |
| **ต้นตอทางเทคนิค** | join `CFPO` ใน `OAGWBG_V_BUDGETRESERVEDITEM` ใช้ `OR` คร่อม correlated `NOT EXISTS` → Oracle แปลงเป็น lateral view (`VW_LAT_*`) แล้วทำได้แค่ `MERGE JOIN OUTER` + `BUFFER SORT` บน 123K แถว |
| **ตัวเร่ง** | **121 จาก 125 ตาราง** ใน schema OAGWBG **ไม่มี optimizer statistics เลย** (`LAST_ANALYZED IS NULL`) |
| **ทางแก้ที่พิสูจน์แล้ว** | ย้าย `APPS.OAGPO_TRANSACTION_STATUS_V` ไปเป็น **CTE (`WITH`)** แล้วอ่าน `OAGWBG_BUDGETRESERVEDITEM` (ตารางจริง) แทน view → **จาก >300 วิ เหลือ 12.9 วิ โดยไม่เปลี่ยน logic เลย** (ถ้ายอมเปลี่ยน logic `CFPO` ด้วยจะเหลือ 6.4 วิ) |
| **ข้อควรรู้** | **การทำเป็น inline subquery เฉย ๆ ไม่ช่วย — ยัง timeout** ต้องเป็น `WITH` CTE เท่านั้น (ดูข้อ 5.2) |
| **blast radius** | **แคบมาก** — ไม่มี DB object อื่นพึ่งพา view นี้ (`ALL_DEPENDENCIES` = 0 แถว) มีแค่ C# 2 จุดที่เรียก |

---

## 1. ลำดับการไหลของข้อมูล (End-to-End)

```
[Browser]  ReportBudgetOverlap.cshtml
  │  downloadReport() → ConfirmSubmitDialog → form.submit()   ← form post ธรรมดา ไม่มี AJAX / ไม่มี timeout ฝั่ง JS
  ▼
[MVC] OAGBudget\Controllers\ReportController.cs:354  ReportBudgetOverlapExport(BudgetOverlap model)
  │  ReportTypeID "1" → "รายงานเงินไว้เบิกเหลื่อมปี.xlsx"
  ▼
[MVC Service] OAGBudget\Services\Repository\ReportService.cs:56  GetReportFile()
  │  var client = CreateClient();                    ← ⚠️ ไม่ตั้ง client.Timeout
  │  await client.GetAsync(...)                      ← ตัดที่ 100 วิ (default ของ HttpClient)
  ▼
[API Controller] OAGBudget.API\Controllers\ReportController.cs:124  ReportBudgetOverlap
  ▼
[API Service] OAGBudget.API\Services\Repository\ReportService.cs:3363  ReportBudgetOverlap()
  │  case "1" → _context.OagwbgRBudgetoverlapCategories   ← ⚠️ ค้างตรงนี้
  ▼
[Oracle PREPROD]  OAGWBG_R_BUDGETOVERLAP_CATEGORY
  │  ├─ OAGWBG_V_BUDGETRESERVED
  │  ├─ OAGWBG_V_BUDGETRESERVED_CATEGORY
  │  ├─ OAGWBG_V_BUDGETRESERVEDITEM ──────────────┐
  │  └─ OAGWBG_V_EXT_OAGPO_TRANSACTION_STATUS_V ──┤
  │                                               ▼
  │                              APPS.OAGPO_TRANSACTION_STATUS_V   ← 🔥 คอขวดตัวจริง (EBS)
  ▼
  ⏱ ไม่เคยเสร็จ — MVC ตัดที่ 100 วิ ก่อนเสมอ
```

> **ข้อสังเกต:** ฝั่ง API **ไม่ได้ตั้ง `CommandTimeout`** (`Program.cs:40` เรียก `option.UseOracle(...)` เปล่า ๆ) → Oracle ยังรันต่อไปเรื่อย ๆ แม้ MVC ตัดการเชื่อมต่อไปแล้ว = session ค้างกินทรัพยากร DB ต่อ

---

## 2. โครงสร้างของ view

`OAGWBG_R_BUDGETOVERLAP_CATEGORY` มี **50 คอลัมน์** เป็น `UNION ALL` ของ 2 branch ที่ grain ต่างกัน

| Branch | เงื่อนไข | grain | แหล่งข้อมูล |
|---|---|---|---|
| **1. ส่วนกลาง** | `BUDGETRESERVEDREGION = 'C'` | 1 แถวต่อ (BUDGETRESERVEDID, CATEGORYID) | `OAGWBG_V_BUDGETRESERVED` + `OAGWBG_V_BUDGETRESERVED_CATEGORY` (DISTINCT) |
| **2. ภูมิภาค** | `BUDGETRESERVEDREGION <> 'C'` **และ** `BUDGETRESERVEDTYPE IN ('O','R')` | 1 แถวต่อ item | `OAGWBG_V_BUDGETRESERVED` + **`OAGWBG_V_BUDGETRESERVEDITEM`** + subquery aggregate บน EBS |

Branch 1 **ไม่แตะ EBS เลย** (`PR_STATUS` / `PO_STATUS` hardcode เป็น `NULL`) — ความช้าทั้งหมดอยู่ที่ branch 2

**ไฟล์ DDL ในโปรเจกต์:** `create_view_budgetoverlap_category.sql` (208 บรรทัด) — ตรงกับที่ deploy อยู่บน PREPROD

---

## 3. ผลการวัดจริง (PREPROD, 2026-08-27)

### 3.1 view ของรายงานกันเงินทั้ง 4 template

| Template | ชื่อรายงาน | View | แถว | เวลา `COUNT(*)` |
|---|---|---|---|---|
| **1** | รายงานเงินไว้เบิกเหลื่อมปี | `OAGWBG_R_BUDGETOVERLAP_CATEGORY` | 63 | **TIMEOUT > 300,000 ms** 🔥 |
| 2 | รายงานขอขยายเวลาเบิกจ่าย | `OAGWBG_R_BUDGETOVERLAP_EXPAND` | 9 | **81,252 ms** |
| 3 | แบบรายงานผลการเบิกจ่าย | `OAGWBG_R_BUDGETOVERLAP` | 71 | **31,568 ms** |
| 4 | รายงานรายละเอียดเงินกัน | `OAGWBG_R_BUDGETOVERLAP_RESERVED` | 7 | **15,742 ms** |

→ **Template 1 เรียกไม่ออก 100%** / Template 2 เกิน 100 วิเมื่อรวม N+1 / Template 3-4 ผ่านแบบเฉียดฉิว

### 3.2 ไล่ทีละชั้น — คอขวดอยู่ที่ EBS

| Object | ชนิด | แถว | เวลา |
|---|---|---|---|
| `OAGWBG_BUDGETRESERVEDITEM` | **ตารางจริง** | 60 | **11 ms** ✅ |
| `OAGWBG_BUDGETRESERVED` | **ตารางจริง** | 39 | **11 ms** ✅ |
| `OAGWBG_V_BUDGETRESERVED` | View | 39 | 678 ms |
| `OAGWBG_V_BUDGETRESERVED_CATEGORY` | View | 12 | 279 ms |
| `OAGWBG_V_EXT_OAGGL_DEPARTMENT_V` | View | 266 | 24 ms |
| `OAGWBG_V_EXT_OAGGL_COST_CENTER_V` | View | 396 | 41 ms |
| `OAGWBG_V_EXT_CARRY_FORWARD_PO` | View (EBS) | 562 | 404 ms |
| **`APPS.OAGPO_TRANSACTION_STATUS_V`** | **View (EBS)** | **18,507** | **10,142 ms** 🔥 |
| ↳ กรอง `PO_NUMBER` เดียว | | 0 | **9,193 ms** ← predicate pushdown **ไม่ทำงาน** |
| **`OAGWBG_V_BUDGETRESERVEDITEM`** | View | 60 | **14,605 ms** 🔥 |

**บทเรียนสำคัญ:** ตารางจริงเร็ว 11 ms — ความช้าทั้งหมดมาจากการ join เข้า EBS

### 3.3 การกรองไม่ช่วยเลย

| Query | เวลา |
|---|---|
| `COUNT(*)` เปล่า | > 300,000 ms |
| `WHERE BUDGETYEAR = 2568` | > 200,000 ms |
| `WHERE BUDGETRESERVEDREGION = 'C'` | 30,625 ms |

→ Oracle ต้อง materialize join กับ EBS ทั้งก้อนก่อนเสมอ การใส่ filter จึงไม่ช่วย

> ข้อนี้ตรงกับที่ทีมเคยบันทึกไว้แล้วใน `MasterService.cs:2499-2501` (วัดได้ 75.7 วิ เทียบกับใส่ `WHERE BUDGETYEAR` แล้ว 79.7 วิ)

---

## 4. Root cause — 3 ชั้นซ้อนกัน

### ชั้นที่ 1 — `APPS.OAGPO_TRANSACTION_STATUS_V` คือกำแพงตายตัว ~10 วิ/ครั้ง

view ของ EBS ตัวนี้ **push predicate เข้าไปข้างในไม่ได้** — กรอง `PO_NUMBER` เดียวก็ยังใช้ 9.2 วิ เท่ากับ scan ทั้ง 18,507 แถว ทุกครั้งที่ query ไหนอ้างถึง = จ่าย 10 วิเต็ม

### ชั้นที่ 2 — `OAGWBG_V_BUDGETRESERVEDITEM` อ้าง view นั้น **4 ครั้ง** ในคิวรีเดียว

```sql
LEFT JOIN (SELECT * FROM OAGWBG_V_EXT_OAGPO_TRANSACTION_STATUS_V a WHERE a.PR_TRANSFER_NO IS NOT NULL) ovbr  -- ครั้งที่ 1
LEFT JOIN (SELECT * FROM OAGWBG_V_EXT_OAGPO_TRANSACTION_STATUS_V b WHERE b.PO_TRANSFER_NO IS NOT NULL) ovbo  -- ครั้งที่ 2
LEFT JOIN APPS.OAGPO_TRANSACTION_STATUS_V CFPO                                                               -- ครั้งที่ 3
ON (
    CFPO.PR_BUDGET_ACCOUNT = BR.ACCOUNTCODE
    OR (                                          -- ⚠️ OR คร่อม correlated subquery
        CFPO.PO_BUDGET_ACCOUNT = BR.ACCOUNTCODE
        AND NOT EXISTS (
            SELECT 1 FROM APPS.OAGPO_TRANSACTION_STATUS_V X                                                  -- ครั้งที่ 4
            WHERE X.PO_NUMBER = BR.BOOKNUMBER
              AND X.PO_LINE_ID = COALESCE(BR.LINEID, BR1.LINEID)
              AND X.PR_BUDGET_ACCOUNT = BR.ACCOUNTCODE
        )
    )
)
AND CFPO.PO_NUMBER = BR.BOOKNUMBER
AND CFPO.PO_LINE_ID = COALESCE(BR.LINEID, BR1.LINEID)
```

**ท่อนนี้คือตัวปัญหาที่สุด** — `OR` คร่อม `NOT EXISTS` ทำให้ Oracle เขียนเป็น hash join ไม่ได้ ต้องแปลงเป็น **lateral view** (`VW_LAT_1438564E` ใน execution plan) แล้วเลือกได้แค่ `MERGE JOIN OUTER` + `BUFFER SORT`

### ชั้นที่ 3 — `UNION ALL` ทำให้ optimizer เลือกแผนที่แย่กว่าเดิม ~1,900 เท่า

เปรียบเทียบ `EXPLAIN PLAN` (วัดจริง):

| Query | Cost | Rows ประเมิน | บรรทัดใน plan |
|---|---|---|---|
| branch 1 เดี่ยว ๆ | 1,171 | 1 | 304 |
| branch 2 เดี่ยว ๆ | 68,659 | 815 | 1,357 |
| **`UNION ALL` ทั้งสอง** | **131,000,000** | **14M** | 1,653 |
| **view จริง (`WHERE BUDGETYEAR=2568`)** | **502,000,000** | **54M** | **1,894** (มี 68 `TABLE ACCESS FULL`) |

จุดระเบิดอยู่ที่ `Id 302` ของ plan:

```
| 302 |  MERGE JOIN OUTER              |                            |    14M|   131M  (1)|
|1154 |   BUFFER SORT                  |                            |   123K|   131M  (1)|
|1155 |    VIEW                        | VW_LAT_1438564E            |   123K|  1129K  (1)|
|1157 |     VIEW                       | OAGPO_TRANSACTION_STATUS_V |   123K|  1129K  (1)|
```

→ สำหรับแถวซ้ายทุกแถว ต้อง buffer-sort ผลลัพธ์ 123,000 แถวใหม่ทุกครั้ง

### ตัวเร่ง — schema ไม่มี optimizer statistics เลย

```
OAGWBG tables ที่ LAST_ANALYZED IS NULL : 121 จาก 125 ตาราง
OAGWBG_BUDGETRESERVED       : NUM_ROWS=NULL, LAST_ANALYZED=NULL
OAGWBG_BUDGETRESERVEDITEM   : NUM_ROWS=NULL, LAST_ANALYZED=NULL
index ทั้งหมดบน BUDGETRESERVEDITEM : SYS_C0012201(ID) ← มีแค่ PK
```

ไม่มี index บน join key ที่ใช้จริงเลยสักตัว: `BUDGETREVERSEDID`, `BOOKNUMBER`, `ACCOUNTCODE`, `PARENTID`

---

## 5. ทางแก้ที่ทดสอบแล้วได้ผล ✅

**หลักการ:** branch 2 ใช้คอลัมน์จาก `OAGWBG_V_BUDGETRESERVEDITEM` ทั้งหมด **18 ตัว** — ในจำนวนนี้ **17 ตัวมาจากตารางจริง `OAGWBG_BUDGETRESERVEDITEM` ตรง ๆ** มีแค่ `CONTRACT_CARRY_FORWARD_PO` (→ output `PO_CONTRACT_DATE`) ตัวเดียวที่เป็นค่าคำนวณจาก EBS

จึงไม่จำเป็นต้องลาก view ที่แพง 14.6 วิเข้ามาทั้งก้อน

### 5.1 ผลการทดสอบทุกแนวทาง (เรียงจากช้าไปเร็ว)

| # | แนวทาง | เวลา | แถว | เปลี่ยน logic? |
|---|---|---|---|---|
| — | **เดิม** — อ้าง named view `OAGWBG_V_BUDGETRESERVEDITEM` | **TIMEOUT > 300,000 ms** | — | — |
| C | **inline subquery** copy นิยาม view มาครบทุก join | **TIMEOUT > 200,000 ms** ❌ | — | ไม่ |
| D | **inline subquery** ตัด join ที่ไม่ใช้ออก (คง `CFPO` เดิม) | **TIMEOUT > 200,000 ms** ❌ | — | ไม่ |
| **E** | **`WITH TSV AS (...)` + inline subquery** | **12,913 ms** ✅ | 63 | **ไม่** |
| A0 | `WITH` ทั้ง `TSV` และ `ITEM` (ไม่ใส่ hint) | 12,587 ms ✅ | 63 | ไม่ |
| A | `WITH` ทั้งคู่ + `/*+ MATERIALIZE */` | 13,262 ms ✅ | 63 | ไม่ |
| B | `WITH` + เปลี่ยน `CFPO` เป็น `GROUP BY` | **6,440 ms** ✅ | 63 | **ใช่** ⚠️ |

### 5.2 ข้อค้นพบสำคัญ — subquery ธรรมดา **ไม่ช่วย** ต้องเป็น CTE เท่านั้น

เทียบ D กับ E ต่างกันแค่ไวยากรณ์เดียว:

```sql
-- D : inline subquery ใน FROM → TIMEOUT
LEFT JOIN APPS.OAGPO_TRANSACTION_STATUS_V CFPO ON (...)
...
NOT EXISTS (SELECT 1 FROM APPS.OAGPO_TRANSACTION_STATUS_V X WHERE ...)

-- E : ยก EBS view ออกมาเป็น CTE → 12.9 วิ
WITH TSV AS (
  SELECT /*+ MATERIALIZE */ PR_BUDGET_ACCOUNT, PO_NUMBER, PO_BUDGET_ACCOUNT, PO_LINE_ID, PO_CONTRACT_DATE
  FROM APPS.OAGPO_TRANSACTION_STATUS_V
)
...
LEFT JOIN TSV CFPO ON (...)
...
NOT EXISTS (SELECT 1 FROM TSV X WHERE ...)
```

**เหตุผล:** `WITH` ที่ถูกอ้างตั้งแต่ 2 ครั้งขึ้นไป Oracle จะ materialize ลง temp table ให้อัตโนมัติ (A0 ไม่ใส่ hint ก็ได้ 12.6 วิ เท่ากัน) ผลคือ:
1. scan `APPS.OAGPO_TRANSACTION_STATUS_V` **ครั้งเดียว** แทน 4 ครั้ง (ประหยัด ~30 วิ)
2. เป็น **optimizer barrier** — กันไม่ให้ view merging ลาก plan ไประเบิดเป็น `MERGE JOIN OUTER` 54M แถว

> ส่วน inline subquery (`FROM (SELECT ...)`) Oracle merge กลับเข้าไปในคิวรีหลักเสมอ → ได้ plan เดิมที่ระเบิด **จึงไม่ช่วยอะไรเลย**

### 5.3 SQL ที่แนะนำ (แนวทาง E — ไม่เปลี่ยน logic)

```sql
WITH TSV AS (
    SELECT /*+ MATERIALIZE */
           PR_NUMBER, PR_STATUS, PR_TRANSFER_NO, PR_BUDGET_ACCOUNT,
           PO_NUMBER, PO_STATUS, PO_TRANSFER_NO, PO_BUDGET_ACCOUNT,
           PO_LINE_ID, PO_CONTRACT_DATE
    FROM   APPS.OAGPO_TRANSACTION_STATUS_V
)
-- branch 2 : อ่านตารางจริง + อ้าง TSV แทน EBS view โดยตรง
...
INNER JOIN OAGWBG_BUDGETRESERVEDITEM BRSI  ON BRS.ID = BRSI.BUDGETREVERSEDID
LEFT  JOIN OAGWBG_BUDGETRESERVEDITEM BRSI1 ON BRSI.PARENTID = BRSI1.ID
LEFT  JOIN TSV CFPO
       ON ( CFPO.PR_BUDGET_ACCOUNT = BRSI.ACCOUNTCODE
            OR ( CFPO.PO_BUDGET_ACCOUNT = BRSI.ACCOUNTCODE
                 AND NOT EXISTS (SELECT 1 FROM TSV X            -- ← อ้าง CTE ไม่ใช่ EBS view
                                 WHERE X.PO_NUMBER = BRSI.BOOKNUMBER
                                   AND X.PO_LINE_ID = COALESCE(BRSI.LINEID, BRSI1.LINEID)
                                   AND X.PR_BUDGET_ACCOUNT = BRSI.ACCOUNTCODE) ) )
      AND CFPO.PO_NUMBER  = BRSI.BOOKNUMBER
      AND CFPO.PO_LINE_ID = COALESCE(BRSI.LINEID, BRSI1.LINEID)
```

### 5.4 การตรวจความถูกต้อง

```sql
-- เทียบค่า CONTRACT_CARRY_FORWARD_PO ของเดิม vs CTE
FULL OUTER JOIN แล้วนับแถวที่ค่าไม่ตรงกัน  →  0 แถว ✅
```

> ⚠️ **ข้อจำกัดของการตรวจนี้:** บน PREPROD ปัจจุบัน `CONTRACT_CARRY_FORWARD_PO` เป็น `NULL` **ทั้ง 60 แถว** (ทั้ง view เดิมและ CTE) การเทียบจึงยืนยันได้แค่ว่า "ไม่ต่างกันบนข้อมูลชุดนี้" **ยังไม่ได้พิสูจน์กับข้อมูลที่มีค่าจริง** — ควรทดสอบซ้ำบน PROD หรือหาข้อมูลตัวอย่างที่มีค่าก่อนขึ้นจริง
>
> น่าสังเกตว่า join ที่แพงที่สุดในทั้ง query กลับให้ค่า `NULL` ทุกแถว — ควรตรวจกับ business ว่าคอลัมน์นี้ยังจำเป็นอยู่หรือไม่ ถ้าไม่จำเป็นก็ตัด `CFPO` ทิ้งได้เลย จะเร็วกว่าทุกแนวทางข้างต้น

### 5.5 สิ่งที่ต้องระวังตอน implement

1. `PO_CONTRACT_DATE` ใน EBS เป็น **`VARCHAR2(240)` ไม่ใช่ `DATE`** — branch 1 ต้อง `CAST(NULL AS VARCHAR2(240))` ให้ตรง ไม่งั้นเจอ `ORA-01790`
2. `PR_STATUS` / `PO_STATUS` — Template 1 **ไม่ได้ใช้เลย** (ตรวจแล้วที่ `ReportService.cs:3384-3570`) จะตัด subquery `TSV` เดิมที่ทำ `GROUP BY` ทิ้งก็ได้ แต่ต้องคง 2 คอลัมน์นี้ไว้เป็น `NULL` เพราะ EF model map ไว้
3. **ถ้าเลือกแนวทาง B** (6.4 วิ) ต้องรู้ว่าเปลี่ยน semantics: logic เดิมให้ความสำคัญกับ `PR_BUDGET_ACCOUNT` ก่อน `PO_BUDGET_ACCOUNT` แต่ B ตัดเงื่อนไข `ACCOUNTCODE` ออกใช้แค่ `PO_NUMBER + PO_LINE_ID` และ `MAX()` จะเลือกค่าเดียวถ้ามีหลายแถว → **ต้องยืนยันกับ business ก่อน**
4. CTE ต้องประกาศไว้**หน้าสุดของ view** (ก่อน branch 1) และ branch 1 ไม่ต้องอ้าง `TSV` ก็ได้ Oracle จัดการเอง

---

## 6. สิ่งที่ทดสอบแล้ว **ไม่ได้ผล** ❌

บันทึกไว้กันเสียเวลาลองซ้ำ:

| แนวทาง | ผล |
|---|---|
| **แปลงเป็น inline subquery (`FROM (SELECT ...)`) เฉย ๆ** | **timeout 200 วิ** — Oracle merge กลับเข้าคิวรีหลัก ได้ plan เดิม |
| ตัด subquery `TSV` (aggregate บน EBS) ออกจาก view | branch 2 ยังช้า 14.2 วิ / `UNION ALL` ยัง **timeout 320 วิ** |
| ใส่ hint `/*+ NO_MERGE */` ในแต่ละ branch ของ `UNION ALL` | **timeout 200 วิ** |
| `WITH ... /*+ MATERIALIZE */` ครอบ **ทั้ง branch** ของ `UNION ALL` | **timeout 200 วิ** |
| ใส่ `WHERE BUDGETYEAR` / `WHERE REGION` | ไม่ช่วย (ดูข้อ 3.3) |

**ข้อสรุป:** ตำแหน่งที่ต้องใส่ CTE สำคัญมาก — ต้องครอบ **`APPS.OAGPO_TRANSACTION_STATUS_V`** ไม่ใช่ครอบ branch ของ `UNION ALL` (ซึ่งลองแล้วไม่ได้ผล)

---

## 7. ผลกระทบ (blast radius) — แคบมาก

### 7.1 ฝั่ง Database

```sql
SELECT OWNER, NAME, TYPE FROM ALL_DEPENDENCIES
WHERE REFERENCED_NAME = 'OAGWBG_R_BUDGETOVERLAP_CATEGORY';
→ 0 rows
```

**ไม่มี view / package / trigger ตัวไหนพึ่งพา view นี้เลย**

### 7.2 ฝั่ง C# — มี 2 จุด

| ไฟล์ : บรรทัด | ใช้ทำอะไร | ผลกระทบ |
|---|---|---|
| `OAGBudget.API\Services\Repository\ReportService.cs` : 3384 | Export Excel Template 1 | ตัวที่พังอยู่ — ได้ประโยชน์เต็ม ๆ |
| `OAGBudget.API\Services\Repository\MasterService.cs` : 2513 | Dropdown `GetReportOverlapDomain("1")` | มี cache 10 นาที + warmup อยู่แล้ว จะเร็วขึ้นด้วย |

> ⚠️ ต้องคง **ทั้ง 50 คอลัมน์และลำดับเดิม** เพราะ EF model `OagwbgRBudgetoverlapCategory` map ไว้ครบ (`OAGDBContext.cs:264`)

---

## 8. ข้อสังเกตอื่นที่พบระหว่างวิเคราะห์

1. **`GetReportFile` ไม่ตั้ง timeout ต่างจากที่อื่นทั้งระบบ**
   `BudgetService.cs` ตั้ง `client.Timeout` ไว้ 5-30 นาทีกว่า **20 จุด** แต่ `ReportService.GetReportFile` (`:56`) ไม่ตั้งเลย → รายงานทุกตัวถูกตัดที่ 100 วิ

2. **ฝั่ง API ไม่มี `CommandTimeout`**
   `Program.cs:40` ใช้ `option.UseOracle(...)` เปล่า ๆ → เมื่อ MVC ตัดที่ 100 วิ Oracle **ยังรันต่อ** กิน session/CPU ของ PREPROD ทิ้งไว้

3. **N+1 query ในลูปเขียน Excel** (ทำให้แย่ลง แต่ไม่ใช่ต้นตอ)

   | บรรทัด | Query ต่อ 1 แถว | ต้นทุน/แถว |
   |---|---|---|
   | `ReportService.cs:3924` (Template 2) | `OagwbgVExtOagpoTransactionStatusVs.FirstOrDefault` | **~9,000 ms** 🔥 |
   | `ReportService.cs:3519` / `:3900` | `OagwbgVExtCarryForwardPos.FirstOrDefault` | ~200 ms |
   | `ReportService.cs:3489` / `:3828` | `OagwbgVExtBudgetSourceVs.FirstOrDefault` | เล็ก |

   ทั้งหมดเป็น **sync call ใน async method** (block thread) — Template 3 ทำ batch ไว้ถูกแล้วที่ `:4244-4258` ใช้เป็นต้นแบบได้

4. **ทีมเคยเจอปัญหานี้แล้วแต่แก้เฉพาะฝั่ง dropdown**
   `MasterService.GetReportOverlapDomain` + `ReportDropdownWarmupService` (cache 10 นาที, warm ทุก 8 นาที) มี comment ระบุชัดว่า query ใช้ 13-76 วินาที — แต่ **ฝั่ง export ไม่ได้รับการป้องกันแบบเดียวกัน**

5. **`OAGWBG_V_EXT_CARRY_FORWARD_PO` เร็ว (404 ms) แต่ไม่มี `PO_CONTRACT_DATE`**
   มีแค่ `PO_CONTRACT`, `PO_CONTRACT_START_DATE`, `PO_CONTRACT_DUE_DATE` จึงใช้แทน `CONTRACT_CARRY_FORWARD_PO` ตรง ๆ ไม่ได้

6. **`OAGWBG_V_BUDGETRESERVEDITEM` ถูกใช้โดย view อื่นอีก 2 ตัว**
   `OAGWBG_V_BUDGETOVERLAPYEAR_PO` และ `OAGWBG_V_BUDGETOVERLAPYEAR_PR` → **ถ้าจะแก้ view นั้นโดยตรง blast radius จะกว้างกว่านี้มาก** เอกสารนี้จึงเลือกแก้เฉพาะ `_CATEGORY` แทน

7. **Query เดิมซ้ำใน session เดียวกันเร็วผิดปกติ**
   รันซ้ำด้วย SQL text เดิมได้ 28-61 ms (buffer cache/cursor) แต่ SQL ที่ต่างออกไปแม้เล็กน้อยกลับมาช้า 10-14 วิเหมือนเดิม → **อย่าใช้การรันซ้ำเป็นหลักฐานว่าแก้สำเร็จ** ต้องวัดจาก cold cache เสมอ

---

## 9. ข้อเสนอลำดับการแก้

| # | สิ่งที่ทำ | ผลคาดหวัง | R-level |
|---|---|---|---|
| 1 | `GATHER_SCHEMA_STATS('OAGWBG')` | optimizer เลิกเดามั่ว — ไม่แตะโค้ดเลย | R2 |
| 2 | index บน `BUDGETRESERVEDITEM(BUDGETREVERSEDID)`, `(BOOKNUMBER)`, `(PARENTID)` | ตัด full scan | R2 |
| 3 | **rewrite `_CATEGORY` ตามแนวทาง E (ข้อ 5.3)** | **>300 วิ → 12.9 วิ (พิสูจน์แล้ว) โดยไม่เปลี่ยน logic** | R1 |
| 3b | (ถ้า business ยืนยันได้) เปลี่ยน `CFPO` เป็น `GROUP BY` ตามแนวทาง B | 12.9 วิ → **6.4 วิ** แต่เปลี่ยน semantics | R1 |
| 4 | ตั้ง `client.Timeout` ใน `GetReportFile` + `CommandTimeout` ฝั่ง API | กันตัดกลางคัน (พลาสเตอร์ ไม่ใช่ยา) | R2 |
| 5 | แก้ N+1 ตามข้อ 8.3 | Template 1/2 เร็วขึ้นอีก | R2 |
| 6 | (ระยะยาว) materialized view ของ `APPS.OAGPO_TRANSACTION_STATUS_V` refresh รายวัน | ปลดกำแพง 10 วิถาวร ช่วยทุกรายงาน | R1 |

> **แนะนำ:** ทำ **1 + 2 ก่อน** (R2 ทั้งคู่ ไม่แตะโค้ด ย้อนกลับได้) แล้ววัดใหม่ ถ้ายังไม่พอค่อยทำข้อ 3
> ก่อนทำข้อ 3 ต้อง **เก็บ DDL เดิมไว้ rollback** และอ่านข้อจำกัดของการ verify ในข้อ 5.4 ให้ครบ
>
> **หมายเหตุ:** แม้ทำข้อ 3 แล้วเหลือ 12.9 วิ ก็ยัง**ไม่ควรข้ามข้อ 4** เพราะ Template 2 (81 วิ) และ N+1 ยังทำให้ export เกิน 100 วิได้อยู่

---

## 10. Reference — ตำแหน่งโค้ดสำคัญ

| หัวข้อ | ไฟล์ : บรรทัด |
|---|---|
| หน้าจอรายงาน | `OAGBudget\Views\Report\ReportBudgetOverlap.cshtml` |
| MVC action (GET) | `OAGBudget\Controllers\ReportController.cs` : 341-352 |
| MVC action (Export) | `OAGBudget\Controllers\ReportController.cs` : 354-378 |
| **HttpClient ที่ไม่ตั้ง timeout** | `OAGBudget\Services\ClientService.cs` : 16-23 |
| **`GetReportFile`** | `OAGBudget\Services\Repository\ReportService.cs` : 56-86 |
| API endpoint | `OAGBudget.API\Controllers\ReportController.cs` : 124-132 |
| **Template 1 (จุดที่ค้าง)** | `OAGBudget.API\Services\Repository\ReportService.cs` : 3363-3566 |
| Template 2 | `OAGBudget.API\Services\Repository\ReportService.cs` : 3569-4005 |
| Template 3 (batch ถูกต้อง — ใช้เป็นต้นแบบ) | `OAGBudget.API\Services\Repository\ReportService.cs` : 4130-4442 |
| N+1 ตัวแพงที่สุด | `OAGBudget.API\Services\Repository\ReportService.cs` : 3924 |
| Dropdown + cache | `OAGBudget.API\Services\Repository\MasterService.cs` : 2495-2537 |
| Warmup service | `OAGBudget.API\Services\ReportDropdownWarmupService.cs` |
| DbContext (ไม่มี CommandTimeout) | `OAGBudget.API\Program.cs` : 40-43 |
| EF model ของ view | `OAGBudget.DAL\Models\OagwbgRBudgetoverlapCategory.cs` |
| EF mapping | `OAGBudget.DAL\OAGDBContext.cs` : 264 |
| **DDL ของ view** | `create_view_budgetoverlap_category.sql` (root ของ solution) |

---

## 11. บันทึกการ deploy (2026-08-27)

### สิ่งที่ทำ

เลือก **แนวทาง E** (CTE ครอบ EBS view + อ่านตารางจริง) เพราะ **ไม่เปลี่ยน logic เดิมเลย** — ไม่ต้องรอ business ยืนยัน

| ไฟล์ | บทบาท |
|---|---|
| `create_view_budgetoverlap_category_v2.sql` | DDL ใหม่ที่ deploy จริง |
| `rollback_view_budgetoverlap_category.sql` | **DDL เดิม สำหรับ rollback** (ดึงจาก `USER_VIEWS` ก่อนแก้) |
| `create_view_budgetoverlap_category_v1_original.sql` | สำเนาไฟล์เดิมในโปรเจกต์ |
| `..\..\create_view_budgetoverlap_category.sql` | ไฟล์ในโปรเจกต์ — เขียนทับด้วย v2 แล้ว **(ยังไม่ได้ `tf checkin`)** |

### ขั้นตอนที่ทำจริง

1. `SELECT TEXT FROM USER_VIEWS` → เก็บ DDL เดิมเป็น rollback script
2. สร้าง view ทดสอบชื่อ `OAGWBG_R_BUDGETOVERLAP_CAT_V2` (ไม่แตะของจริง)
3. เทียบข้อมูล branch 2 แบบ row-by-row ทั้ง 50 คอลัมน์
4. เทียบชื่อ / ลำดับ / datatype ของคอลัมน์
5. `CREATE OR REPLACE` ลง view จริง แล้ว `DROP` view ทดสอบทิ้ง

### ผลการ verify

| การตรวจ | ผล |
|---|---|
| `(NEW MINUS OLD)` branch 2 ทั้ง 50 คอลัมน์ | **0 แถว** ✅ |
| `(OLD MINUS NEW)` branch 2 ทั้ง 50 คอลัมน์ | **0 แถว** ✅ |
| จำนวนแถว branch 2 | OLD 51 = NEW 51 ✅ |
| ชื่อ / ลำดับ / datatype ของคอลัมน์ | ตรงกันครบ **50/50** ✅ |
| `USER_OBJECTS.STATUS` หลัง deploy | **VALID** ✅ |
| `COUNT(*)` ทั้ง view | 63 แถว / **12,707 ms** ✅ |
| filter แบบที่ `ReportService` ยิงจริง | 63 แถว / **12,708 ms** ✅ |
| **ดึงครบ 50 คอลัมน์ + `ORDER BY` (คิวรีจริงของรายงาน)** | 63 แถว / **12,665 ms** ✅ |

### ผลลัพธ์

```
ก่อนแก้ : TIMEOUT > 300,000 ms  (MVC ตัดที่ 100 วิ → export ไม่ออก)
หลังแก้ :          12,665 ms    (เหลือ margin ~87 วิ ก่อนถึง timeout)
```

**เร็วขึ้นอย่างน้อย 24 เท่า** และข้อมูลตรงกับของเดิมทุกแถวทุกคอลัมน์

### เรื่องที่ยังค้าง

1. **ยังไม่ได้ `tf checkin`** — `TF.exe` ไม่มีบนเครื่องที่รัน (path ใน CLAUDE.md ชี้ `D:\TFS\OAG Budget` แต่ workspace จริงอยู่ `C:\Users\thiha\Documents\TFS\OAG Budget`) ต้อง checkin เอง
   ```
   chore(db): rewrite OAGWBG_R_BUDGETOVERLAP_CATEGORY to fix report timeout
   ```
2. **ยังไม่ได้ deploy ขึ้น PROD** — ทำเฉพาะ PREPROD
3. **ยังไม่ได้ทดสอบ export จริงผ่านหน้าจอ** — verify ถึงระดับ SQL เท่านั้น (คิวรีที่รายงานยิงจริง 12.7 วิ) ควรกดปุ่มดาวน์โหลดจริงอีกครั้งเพื่อยืนยัน
4. **ข้อจำกัดของการ verify ค่า `CONTRACT_CARRY_FORWARD_PO`** — ดูข้อ 5.4 (บน PREPROD เป็น `NULL` ทั้ง 60 แถว)
   บนข้อมูลชุดนี้ไม่มีแถวที่เป็น "มีหนี้" เลย → loop N+1 ของ `carryforward` ไม่ทำงาน ถ้า PROD มีข้อมูลมีหนี้จริง จะเพิ่มอีก ~268 ms ต่อแถว **ควรแก้ N+1 ตามข้อ 8.3 ก่อนขึ้น PROD**
5. **Template 3 / 4 ยังไม่ได้แก้** — `_BUDGETOVERLAP` 31.5 วิ, `_RESERVED` 15.7 วิ ใช้แพตเทิร์นเดียวกัน แก้ด้วยวิธีเดียวกันได้

---

## 12. บันทึกการ deploy `OAGWBG_R_BUDGETOVERLAP_EXPAND` (2026-08-27)

Template 2 (รายงานขอขยายเวลาเบิกจ่าย) ใช้แพตเทิร์นเดียวกันเป๊ะ จึงแก้ด้วยวิธีเดียวกัน

### โครงสร้างเดิม (ง่ายกว่า `_CATEGORY` — ไม่มี `UNION ALL`)

```
FROM      OAGWBG_V_BUDGETRESERVED BRS
LEFT JOIN OAGWBG_V_BUDGETRESERVEDITEM BRSI              ← 14.6 วิ (ยิง EBS 4 ครั้ง)
LEFT JOIN OAGWBG_V_EXT_OAGGL_DEPARTMENT_V DEPTV         ← 24 ms
LEFT JOIN OAGWBG_V_EXT_OAGGL_COST_CENTER_V COSTV        ← 41 ms
LEFT JOIN OAGWBG_V_SYSTEMUSER SU                        ← 75 ms
LEFT JOIN OAGWBG_V_EXT_OAGPO_TRANSACTION_STATUS_V TSV   ← 10 วิ (join ด้วย OR อีกที)
LEFT JOIN OAGWBG_V_BUDGETRECEIVE BR                     ← 804 ms
```

### สิ่งที่เปลี่ยน

1. เพิ่ม CTE `TSV_RAW` ครอบ `APPS.OAGPO_TRANSACTION_STATUS_V` (อ้าง 3 ครั้ง → materialize อัตโนมัติ)
2. แทน `OAGWBG_V_BUDGETRESERVEDITEM` ด้วย inline subquery อ่านตารางจริง + คำนวณ `CONTRACT_CARRY_FORWARD_PO` เอง (logic เดิมทุกตัวอักษร)
3. `TSV` เดิม → อ้าง `TSV_RAW`

> **โชคดี:** `BRSI.STATUSNAME` (คอลัมน์เดียวที่ต้องพึ่ง `OAGWBG_MASTERSTATUS` ใน view เดิม) ถูก **comment ทิ้งไว้ใน SELECT อยู่แล้ว** จึงไม่ต้อง join `MASTERSTATUS` เลย

### ผลการ verify

| การตรวจ | ผล |
|---|---|
| `(NEW MINUS OLD)` ทั้ง 45 คอลัมน์ | **0 แถว** ✅ |
| `(OLD MINUS NEW)` ทั้ง 45 คอลัมน์ | **0 แถว** ✅ |
| จำนวนคอลัมน์ | OLD 45 = NEW 45 ✅ |
| ชื่อ / ลำดับ / datatype | ต่างกัน **0 จุด** ✅ |
| `USER_OBJECTS.STATUS` | **VALID** ✅ |
| `COUNT(*)` | 9 แถว / **12,966 ms** ✅ |
| filter แบบที่ `ReportService` ยิงจริง | 9 แถว / **12,826 ms** ✅ |
| ดึงครบ 45 คอลัมน์ + `ORDER BY` | 9 แถว / **12,916 ms** ✅ |

### ผลลัพธ์

```
ก่อนแก้ : 76,399 ms
หลังแก้ : 12,916 ms      → เร็วขึ้น ~5.9 เท่า
```

### ⚠️ ระเบิดเวลาที่ยังไม่ได้ปลด — N+1 ของ Template 2

`ReportService.cs:3924` ยิง query ต่อ **ทุกแถวที่ไม่ใช่ Region 'C'**:

```csharp
var paymentStatus = _context.OagwbgVExtOagpoTransactionStatusVs
    .FirstOrDefault(x => x.PoNumber == item.Booknumber
                      || x.PrNumber == item.Booknumber
                      || x.InvoiceNum == item.Booknumber);
```

| วัดจริง | ค่า |
|---|---|
| ต้นทุนต่อ 1 ครั้ง | **4,623 ms** |
| แถวที่ไม่ใช่ Region C บน PREPROD ตอนนี้ | **0 แถว** → ยังไม่ยิงเลย |

**บน PREPROD ตอนนี้จึงยังไม่เจอปัญหา แต่ถ้า PROD มีข้อมูลฝั่งภูมิภาค:**

```
12.9 วิ (view) + N x 4.6 วิ  →  เกิน 100 วิ ตั้งแต่ N = 19 แถว
```

**ต้องแก้ N+1 ตัวนี้เป็น batch dictionary (แบบ Template 3 ที่ `:4244-4258`) ก่อนขึ้น PROD** ไม่งั้น Template 2 จะกลับมา timeout อีกทันทีที่มีข้อมูลภูมิภาค

### ไฟล์

| ไฟล์ | บทบาท |
|---|---|
| `create_view_budgetoverlap_expand_v2.sql` | DDL ใหม่ที่ deploy จริง |
| `rollback_view_budgetoverlap_expand.sql` | **DDL เดิม สำหรับ rollback** |
| `..\..\create_view_budgetoverlap_expand.sql` | **ไฟล์ใหม่ในโปรเจกต์ — ต้อง `tf add`** (เดิมไม่เคยมี DDL ตัวนี้ใน source control) |

---

## 13. บันทึกการ deploy `OAGWBG_V_BUDGETRESERVEDITEM` (2026-08-27)

view กลางที่ทุก template พึ่งพา — แก้ด้วยแพตเทิร์นเดียวกัน

### ⚠️ แก้ข้อมูลที่เคยเขียนผิดในข้อ 8.6

ข้อ 8.6 เขียนว่า dependents คือ `OAGWBG_V_BUDGETOVERLAPYEAR_PO` / `_PR` — **ผิด** view สองตัวนั้นพึ่ง `APPS.OAGPO_TRANSACTION_STATUS_V` โดยตรง ไม่ได้พึ่ง view นี้

**dependents จริง (จาก `ALL_DEPENDENCIES` + grep C#):**

| ผู้ใช้ | ประเภท |
|---|---|
| `OAGWBG_R_BUDGETOVERLAP` | View — **Template 3** |
| `OAGWBG_R_BUDGETOVERLAP_RESERVED` | View — **Template 4** |
| `BudgetService.cs` : 13760, 13988, 27502 | C# query ตรง |

> `_CATEGORY` และ `_EXPAND` เลิกใช้ view นี้ไปแล้วตั้งแต่การแก้ในข้อ 11-12

### สิ่งที่เปลี่ยน

เพิ่ม CTE `TSV_RAW` ครอบ `APPS.OAGPO_TRANSACTION_STATUS_V` แล้วให้ **ทั้ง 4 จุด** ที่เคยอ้าง EBS view ตรง ๆ มาอ้าง CTE แทน:

| จุด | เดิม |
|---|---|
| `ovbr` | subquery กรอง `PR_TRANSFER_NO IS NOT NULL` |
| `ovbo` | subquery กรอง `PO_TRANSFER_NO IS NOT NULL` |
| `CFPO` | join ตรง (`OR` + `NOT EXISTS`) |
| `X` | correlated `NOT EXISTS` ข้างใน `CFPO` |

**SELECT list / join condition / logic คงเดิมทุกตัวอักษร** — เปลี่ยนแค่แหล่งที่อ้าง

### ผลการ verify

| การตรวจ | ผล |
|---|---|
| `(NEW MINUS OLD)` ทั้ง 41 คอลัมน์ | **0 แถว** ✅ |
| `(OLD MINUS NEW)` ทั้ง 41 คอลัมน์ | **0 แถว** ✅ |
| ชื่อ / ลำดับ / datatype | ต่าง **0 จุด** (41/41) ✅ |
| `USER_OBJECTS.STATUS` ของ view นี้ + ลูกทั้ง 4 | **VALID ทั้งหมด** ✅ |

### ผลลัพธ์ — ได้ไม่มากเท่า 2 ตัวก่อนหน้า

| View | ก่อน | หลัง | ลดลง |
|---|---|---|---|
| `OAGWBG_V_BUDGETRESERVEDITEM` | 14,605 ms | **11,037 ms** | −24% |
| `OAGWBG_R_BUDGETOVERLAP` (T3) | 31,568 ms | **24,213 ms** | −23% |
| `OAGWBG_R_BUDGETOVERLAP_RESERVED` (T4) | 15,742 ms | **13,873 ms** | −12% |
| `_CATEGORY` (T1) | 12,707 ms | 12,825 ms | ไม่กระทบ ✅ |
| `_EXPAND` (T2) | 12,966 ms | 13,124 ms | ไม่กระทบ ✅ |

**ทำไมได้น้อยกว่า:** view นี้ชนเพดาน `APPS.OAGPO_TRANSACTION_STATUS_V` ที่ ~10 วิ/scan อยู่แล้ว
11 วิ จึงเกือบเป็นค่าต่ำสุดที่ทำได้ ตราบใดที่ยังต้องอ่าน EBS view สด ๆ

**Template 3 ยังช้า 24.2 วิ** เพราะ `OAGWBG_R_BUDGETOVERLAP` มีการอ้าง EBS view ของตัวเองเพิ่มอีก
→ ถ้าจะลดต่อ ต้องใส่ CTE ที่ view ตัวนั้นด้วย (ยังไม่ได้ทำ)

**ทางเดียวที่จะทะลุเพดาน 10 วิ คือข้อ 9.6** — ทำ materialized view ของ `APPS.OAGPO_TRANSACTION_STATUS_V` refresh รายวัน

### ไฟล์

| ไฟล์ | บทบาท |
|---|---|
| `create_view_budgetreserveditem_v2.sql` | DDL ใหม่ที่ deploy จริง |
| `rollback_view_budgetreserveditem.sql` | **DDL เดิม สำหรับ rollback** |
| `..\..\create_view_budgetreserveditem.sql` | **ไฟล์ใหม่ในโปรเจกต์ — ต้อง `tf add`** |
