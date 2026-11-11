# FIX: OAGWBG_FN_GETBUDGET_ALLOCATE_TRANSFER_CATEGORY — เงิน 400 ผิดเมื่อไม่ส่ง p_BudgetSource

วันที่: 2026-09-14
ไฟล์ DDL: `OAGWBG_FN_GETBUDGET_ALLOCATE_TRANSFER_CATEGORY_fix_source400.sql`
Baseline: `../20260817_optimized_savebudgetallocatetransferdetail/OAGWBG_FN_GETBUDGET_ALLOCATE_TRANSFER_CATEGORY_optimized.sql`

## อาการ

| การเรียก | ผลของเงิน 400 |
|---|---|
| `FN(2569, 1)` (p_BudgetSource = NULL) | ยอด **ผิด** (บวกเกิน) |
| `FN(2569, 1, 400)` | ยอด **ถูก** |

## สาเหตุ

WHERE ของทั้ง CTE `BRC` และ `BATC` ใช้เงื่อนไขคนละชุดกันระหว่างสองเคส

- เคส `p_BudgetSource = 400` → `ob.BUDGETSOURCEID = 400 AND ob.BUDGETRECEIVETYPE = 'O' AND ob.BUDGETRESERVEDID IS NOT NULL`
- เคส `p_BudgetSource IS NULL` → `ob.BUDGETSOURCEID = 400` เฉย ๆ (ดึงมาหมด)

แถวเงิน 400 ส่วนเกินที่หลุดเข้ามาตอน NULL คือแถวที่ `BUDGETRECEIVETYPE <> 'O'` และ/หรือ `BUDGETRESERVEDID IS NULL`
(ซึ่งทำให้ `BRS.TRANSFERNO` เป็น NULL) ส่งผลเสีย 2 ทาง

1. `ROW_NUMBER() OVER (PARTITION BY TRANSFERNO ...)` — แถว `TRANSFERNO = NULL` ทั้งหมดตกอยู่ partition
   เดียวกัน แล้วถูก `RN_TRANSFERNO = 1` ตัดเหลือแถวเดียว
2. เงื่อนไข join `AND (BATC.TRANSFERNO = BRC.TRANSFERNO OR BATC.TRANSFERNO IS NULL)` — แถว BATC ที่
   `TRANSFERNO IS NULL` จะ join ติดกับ **ทุก** แถว BRC ที่ key อื่นตรงกัน ทำให้ `SUM()` บวกยอดซ้ำ

ข้อ 2 คือตัวที่ทำให้ยอดเงิน 400 บวกเกินจริง (จำนวนแถวเท่าเดิม 10 แถว แต่ยอดพอง)

## การแก้

ปรับเฉพาะสาขา `p_BudgetSource IS NULL` ของ WHERE ทั้งใน `BRC` และ `BATC` ให้เงิน 400 ใช้ predicate
ชุดเดียวกับตอนส่ง `p_BudgetSource = 400` และกันไม่ให้เคสที่ 2 (เช็กคลัง/แผนก/สถานะ) ไปรับแถวเงิน 400 ซ้ำ

```sql
p_BudgetSource IS NULL
AND (
    -- เคสที่ 1: เงิน 400
    (
        ob.BUDGETSOURCEID = 400
        AND ob.BUDGETRECEIVETYPE = 'O'
        AND ob.BUDGETRESERVEDID IS NOT NULL
    )
    OR
    -- เคสที่ 2: เงื่อนไขเดิม — เฉพาะแหล่งงบที่ไม่ใช่ 400
    (
        (ob.BUDGETSOURCEID IS NULL OR ob.BUDGETSOURCEID <> 400)
        AND ( ...เงื่อนไขเดิมทั้งชุด... )
    )
)
```

> หมายเหตุ: ตอนแรกใช้ `COALESCE(ob.BUDGETSOURCEID, 100) <> 400` แล้วได้ **ORA-00932 inconsistent datatypes**
> เพราะ `BUDGETSOURCEID` เป็น VARCHAR2 จึงเปลี่ยนเป็น `IS NULL OR <> 400` ที่ไม่ผสม type

ไม่มีการแก้ส่วนอื่น — CTE/MATERIALIZE, ROW_NUMBER, join, GROUP BY, SELECT list คงเดิมทั้งหมด

## การทดสอบ (PREPROD 172.16.11.19:1541 / ebs_PRE, 2026-09-14)

รัน query body แบบ standalone (แทน `p_BudgetYear` = 2569, `p_BudgetSource` = NULL / 400)

| Variant | totalRows | rows(400) | sumAllocate | sumBalance | sumTransfer |
|---|---|---|---|---|---|
| เดิม, p=400 | 10 | 10 | 43,062,440.00 | 40,680,470.00 | 2,381,970.00 |
| เดิม, p=NULL | 711 | 10 | **45,736,800.99** | **43,354,830.99** | **5,056,330.99** |
| แก้แล้ว, p=NULL | 711 | 10 | 43,062,440.00 | 40,680,470.00 | 2,381,970.00 |
| แก้แล้ว, p=400 | 10 | 10 | 43,062,440.00 | 40,680,470.00 | 2,381,970.00 |

- แถวเงิน 400 ของ "แก้แล้ว p=NULL" **เท่ากันทุกคอลัมน์ทุกแถว** กับ p=400 (diff = ว่าง)
- เทียบผลทั้ง 711 แถวของ p=NULL ก่อน/หลังแก้ → ต่างกัน **เฉพาะ 5 แถวของเงิน 400** เท่านั้น
  แหล่งงบอื่น (701 แถว) ไม่กระทบเลย
- เวลา query ยังคง ~1.8 วินาที (ไม่เสีย performance จาก optimize 2026-08-17)

ตัวอย่างยอดที่เพี้ยน (CATEGORYID 27125, TRANSFERNO 68030006): เดิม 1,343,020.00 → ที่ถูกคือ 6,000.00

หลักฐาน: `evidence_before_null_source400.txt`, `evidence_after_null_source400.txt`, `evidence_param400_source400.txt`
(รูปแบบ: CATEGORYID|PRODUCTID|ACTIVITYID|TRANSFERNO|ACCOUNTCODE|ALLOCATE|BALANCE|TRANSFER)

## สถานะ / สิ่งที่ต้องทำต่อ

- [x] แก้ DDL + verify ด้วยข้อมูลจริงบน PREPROD
- [ ] **ยังไม่ได้ deploy** — ยังไม่ได้รัน `CREATE OR REPLACE` บน PREPROD (รอผู้ใช้/DBA ตัดสินใจ)
- [ ] Git commit ในโฟลเดอร์ `_brain_OAGBUDGET` (ผู้ใช้ commit เอง)
