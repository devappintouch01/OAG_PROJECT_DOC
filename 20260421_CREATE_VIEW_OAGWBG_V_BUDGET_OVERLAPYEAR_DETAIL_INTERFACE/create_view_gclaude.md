# สรุป: สร้าง View ใหม่ OAGWBG_V_BUDGET_OVERLAPYEAR_DETAIL_INTERFACE

> **วันที่สร้าง:** 2026-04-22  
> **อ้างอิงจาก:** `OAGWBG_V_BUDGET_OVERLAPYEAR_CENTRAL_DETAIL_INTERFACE`  
> **Schema:** OAGWBG (Oracle EBS PRE — 172.16.11.19:1541)

<style scoped>
table {
  font-size: 13px;
}
li {
  font-size: 13px;
}
</style>

---

## 1. สรุป Conditions ที่เปลี่ยนแปลงจาก View เดิม

| # | Condition | View เดิม (CENTRAL) | View ใหม่ (DETAIL) |
|---|---|---|---|
| 2.2 | ENCUMBRANCE_TYPE | มี column นี้ | **ตัดออก** |
| 2.3 | WEB_BATCH_NO format | `..._BUDGETYEAR_TIMESTAMP` | **เพิ่ม `_TRANSFERNO`** → `..._BUDGETYEAR_TRANSFERNO_TIMESTAMP` |
| 2.4 | REFERENCE4 | `'เงินกันเหลื่อมปี '‖BUDGETYEAR‖'-'‖DEPARTMENTID‖' เลขที่เงินกัน '‖TRANSFERNO` | **`'เงินกันเหลื่อมปี '‖BUDGETYEAR‖' '‖TRANSFERNO`** |
| 2.5 | REFERENCE5 | เหมือน REFERENCE4 เดิม | **เหมือน REFERENCE4 ใหม่** |
| 2.6 | USER_JE_CATEGORY_NAME | ENC→`'Web Encumbrance'` / BG→`'Budget - เงินกัน'` | **Fixed ต่างกัน** (คงเงื่อนไขเดิม) |
| 2.7 | DEFAULT_EFFECTIVE_DATE | ENC→`SEP-30` / BG→`OCT-01` | **เหมือนเดิม** |
| 2.8 | TYPE | ENC→`'O'` / BG→`'I'` | **Fixed `'I'` ทั้งคู่** |
| 2.9 | TRANSFERTYPE | `'CARRYFWD'` | **`'CARRYPRPO'`** |
| 2.10 | RECEIPIENT_ACCOUNT | ENC→RECEIVER / BG→NULL | **เฉพาะ ENC** (เหมือนเดิม) |
| 2.11 | SENDER_ACCOUNT | ENC→NULL / BG→GIVER | **เฉพาะ BG** (เหมือนเดิม) |
| 2.12 | OAGWBG_BUDGETRESERVED กรอง | ไม่กรอง REGION | **เพิ่ม `BUDGETRESERVEDREGION = 'P'`** |
| 2.13 | ตารางหลัก (Line items) | `OAGWBG_BUDGETRESERVED_CATEGORY` | **`OAGWBG_BUDGETRESERVEDITEM`** |

---

## 2. การ Mapping ของ ACCOUNTCODE → SEGMENT 1–13

`OAGWBG_BUDGETRESERVEDITEM.ACCOUNTCODE` เก็บ 13 segments คั่นด้วย `.` ตัวอย่าง:

```
2900600000.2900600001.68.100.20000.21000.21100.241001.29006630001004100206.1211010102.500001.00.000
   SEG1       SEG2   SEG3 SEG4  SEG5  SEG6  SEG7   SEG8        SEG9            SEG10   SEG11 SEG12 SEG13
```

ใช้ `REGEXP_SUBSTR` เพื่อ parse แต่ละ segment:

```sql
REGEXP_SUBSTR(I.ACCOUNTCODE, '[^.]+', 1, N)  -- N = ลำดับที่ 1-13
```

---

## 3. SQL CREATE OR REPLACE VIEW

```sql
CREATE OR REPLACE VIEW OAGWBG_V_BUDGET_OVERLAPYEAR_DETAIL_INTERFACE AS
WITH BASE AS (
  SELECT
    I.ID,
    I.ACCOUNTCODE,
    I.BOOKNUMBER,
    I.TOTALHASPOAMOUNT,
    I.TOTALHASPRAMOUNT,
    I.TOTALBALANCEAMOUNT,
    I.CREATEBY,
    I.CREATEON,
    I.UPDATEBY,
    I.UPDATEON,
    I.STATUSID,
    I.TRANSFERNO                          AS I_TRANSFERNO,
    BRS.ID                                AS BUDGETRESERVEDID,
    BRS.BUDGETYEAR,
    BRS.DEPARTMENTID,
    BRS.COSTCENTERID,
    BRS.BUDGETSOURCEID,
    BRS.TRANSFERNO                        AS TRANSFERNO,
    BRS.TRANSFERDATE,
    BRS.ROUNDINTERFACE,
    SC.CONFIG_VALUE                       AS LEDGER_ID,
    BCC_GIVER.CASH_ACC                    AS GIVER,
    BCC_RECEIVER.CASH_ACC                 AS RECEIVER,
    -- Parse ACCOUNTCODE → individual segments
    REGEXP_SUBSTR(I.ACCOUNTCODE, '[^.]+', 1, 1)   AS SEG1,
    REGEXP_SUBSTR(I.ACCOUNTCODE, '[^.]+', 1, 2)   AS SEG2,
    REGEXP_SUBSTR(I.ACCOUNTCODE, '[^.]+', 1, 3)   AS SEG3,
    REGEXP_SUBSTR(I.ACCOUNTCODE, '[^.]+', 1, 4)   AS SEG4,
    REGEXP_SUBSTR(I.ACCOUNTCODE, '[^.]+', 1, 5)   AS SEG5,
    REGEXP_SUBSTR(I.ACCOUNTCODE, '[^.]+', 1, 6)   AS SEG6,
    REGEXP_SUBSTR(I.ACCOUNTCODE, '[^.]+', 1, 7)   AS SEG7,
    REGEXP_SUBSTR(I.ACCOUNTCODE, '[^.]+', 1, 8)   AS SEG8,
    REGEXP_SUBSTR(I.ACCOUNTCODE, '[^.]+', 1, 9)   AS SEG9,
    REGEXP_SUBSTR(I.ACCOUNTCODE, '[^.]+', 1, 10)  AS SEG10,
    REGEXP_SUBSTR(I.ACCOUNTCODE, '[^.]+', 1, 11)  AS SEG11,
    REGEXP_SUBSTR(I.ACCOUNTCODE, '[^.]+', 1, 12)  AS SEG12,
    REGEXP_SUBSTR(I.ACCOUNTCODE, '[^.]+', 1, 13)  AS SEG13
  FROM OAGWBG_BUDGETRESERVEDITEM I
  JOIN OAGWBG_BUDGETRESERVED BRS
    ON I.BUDGETREVERSEDID = BRS.ID
  LEFT JOIN OAGWBG_BUDGETRESERVED_BANKACCOUNT BRB
    ON BRB.RESERVEDID = BRS.ID
  LEFT JOIN OAGWBG_V_EXT_OAGCE_BANK_ACCOUNT_V BCC_GIVER
    ON BCC_GIVER.BANK_ACCOUNT_ID = BRB.BANKACCOUNTGIVER
  LEFT JOIN OAGWBG_V_EXT_OAGCE_BANK_ACCOUNT_V BCC_RECEIVER
    ON BCC_RECEIVER.BANK_ACCOUNT_ID = BRB.BANKACCOUNTRECEIVER
  LEFT JOIN OAGWBG_SYSTEMCONFIG SC
    ON SC.CONFIG_KEY = 'Ledger'
  WHERE BRS.BUDGETRESERVEDREGION = 'P'
    AND BRS.ROUNDINTERFACE IS NOT NULL
),
TYPE_MAP AS (
  SELECT 'ENC' AS DOC_TYPE, 'E' AS ACTUAL_FLAG, 'C' AS DRCR_FLAG FROM DUAL
  UNION ALL
  SELECT 'BG',  'B',        'D'                                   FROM DUAL
)
SELECT
  -- WEB_BATCH_NO: เพิ่ม TRANSFERNO เข้าใน format
  NVL(RBN.BATCHNAME,
    CASE
      WHEN T.DOC_TYPE = 'ENC'
        THEN 'ENC_CARRY_FORWARD_' || B.BUDGETYEAR || '_' || B.TRANSFERNO || '_'
             || TO_CHAR(NVL(B.TRANSFERDATE, SYSDATE), 'YYMMDDHH24MISS')
      ELSE   'BG_CARRY_FORWARD_'  || B.BUDGETYEAR || '_' || B.TRANSFERNO || '_'
             || TO_CHAR(NVL(B.TRANSFERDATE, SYSDATE), 'YYMMDDHH24MISS')
    END
  )                                                           AS WEB_BATCH_NO,

  'Web Budget'                                               AS USER_JE_SOURCE_NAME,

  -- REFERENCE4: 'เงินกันเหลื่อมปี' BUDGETYEAR TRANSFERNO (ไม่มี DEPARTMENTID)
  'เงินกันเหลื่อมปี ' || B.BUDGETYEAR || ' ' || B.TRANSFERNO   AS REFERENCE4,
  'เงินกันเหลื่อมปี ' || B.BUDGETYEAR || ' ' || B.TRANSFERNO   AS REFERENCE5,

  B.LEDGER_ID,

  -- USER_JE_CATEGORY_NAME: Fixed ต่างกันตาม DOC_TYPE
  CASE
    WHEN T.DOC_TYPE = 'ENC' THEN 'Web Encumbrance'
    ELSE 'Budget - เงินกัน'
  END                                                         AS USER_JE_CATEGORY_NAME,

  TO_CHAR(B.TRANSFERDATE, 'YYYY-MM-DD')                      AS TRANSFER_DATE,

  -- DEFAULT_EFFECTIVE_DATE: เหมือน view เดิม
  CASE
    WHEN T.DOC_TYPE = 'ENC' THEN (B.BUDGETYEAR - 543) || '-SEP-30'
    ELSE                          (B.BUDGETYEAR - 543) || '-OCT-01'
  END                                                         AS DEFAULT_EFFECTIVE_DATE,

  T.ACTUAL_FLAG,

  CASE WHEN T.DOC_TYPE = 'BG' THEN 'OAG_BG_FINAL' ELSE '' END  AS BUDGET_ENCUMBRANCE_NAME,

  'THB'                                                       AS CURRENCY_CODE,
  ''                                                          AS ATTRIBUTE3,
  B.TRANSFERNO                                                AS ATTRIBUTE4,

  ROW_NUMBER() OVER (
    PARTITION BY B.BUDGETRESERVEDID, T.DOC_TYPE
    ORDER BY B.ID
  )                                                           AS LINE_NUMBER,

  -- SEGMENTS จาก ACCOUNTCODE ที่ parse ไว้ใน CTE
  B.SEG1   AS SEGMENT1,
  B.SEG2   AS SEGMENT2,
  B.SEG3   AS SEGMENT3,
  B.SEG4   AS SEGMENT4,
  B.SEG5   AS SEGMENT5,
  B.SEG6   AS SEGMENT6,
  B.SEG7   AS SEGMENT7,
  B.SEG8   AS SEGMENT8,
  B.SEG9   AS SEGMENT9,
  B.SEG10  AS SEGMENT10,
  B.SEG11  AS SEGMENT11,
  B.SEG12  AS SEGMENT12,
  B.SEG13  AS SEGMENT13,

  -- จำนวนเงิน: ใช้ TOTALBALANCEAMOUNT (ยอดคงเหลือสุทธิ)
  B.TOTALBALANCEAMOUNT                                        AS ENTERED_DR,
  B.TOTALBALANCEAMOUNT                                        AS ACCOUNTED_DR,
  NULL                                                        AS ENTERED_CR,
  NULL                                                        AS ACCOUNTED_CR,

  -- REFERENCE1: เหมือน WEB_BATCH_NO
  NVL(RBN.BATCHNAME,
    CASE
      WHEN T.DOC_TYPE = 'ENC'
        THEN 'ENC_CARRY_FORWARD_' || B.BUDGETYEAR || '_' || B.TRANSFERNO || '_'
             || TO_CHAR(NVL(B.TRANSFERDATE, SYSDATE), 'YYMMDDHH24MISS')
      ELSE   'BG_CARRY_FORWARD_'  || B.BUDGETYEAR || '_' || B.TRANSFERNO || '_'
             || TO_CHAR(NVL(B.TRANSFERDATE, SYSDATE), 'YYMMDDHH24MISS')
    END
  )                                                           AS REFERENCE1,

  B.CREATEBY                                                  AS CREATED_BY,
  B.UPDATEBY                                                  AS LAST_UPDATED_BY,
  B.CREATEON                                                  AS CREATION_DATE,
  B.UPDATEON                                                  AS LAST_UPDATE_DATE,
  B.BOOKNUMBER                                                AS REFERENCE10,

  -- ไม่มี ENCUMBRANCE_TYPE (ตัดออกตาม 2.2)

  B.TRANSFERNO,

  -- RECEIPIENT_ACCOUNT: เฉพาะ ENC (2.10)
  CASE WHEN T.DOC_TYPE = 'ENC' THEN B.RECEIVER ELSE NULL END AS RECEIPIENT_ACCOUNT,

  -- SENDER_ACCOUNT: เฉพาะ BG (2.11)
  CASE WHEN T.DOC_TYPE = 'BG'  THEN B.GIVER    ELSE NULL END AS SENDER_ACCOUNT,

  -- TYPE: Fixed 'I' ทั้งสอง DOC_TYPE (2.8)
  'I'                                                         AS TYPE,

  -- TRANSFERTYPE: Fixed 'CARRYPRPO' (2.9)
  'CARRYPRPO'                                                 AS TRANSFERTYPE

FROM BASE B
CROSS JOIN TYPE_MAP T
LEFT JOIN OAGWBG_RECEIVE_BATCH_NO RBN
  ON  RBN.RECEIVEID   = B.ID
  AND RBN.ROUNDNO     = B.TRANSFERNO
  AND RBN.INTERFACETYPE = 'O'
  AND (
        (T.DOC_TYPE = 'ENC' AND RBN.BATCHNAME LIKE 'ENC%')
     OR (T.DOC_TYPE = 'BG'  AND RBN.BATCHNAME LIKE 'BG%')
  )
ORDER BY B.TRANSFERNO, B.ID, T.ACTUAL_FLAG DESC;
```

---

## 4. ความแตกต่างจาก View เดิม (Column-by-Column)

| Column | CENTRAL (เดิม) | DETAIL (ใหม่) | หมายเหตุ |
|---|---|---|---|
| WEB_BATCH_NO | `..._BUDGETYEAR_TIMESTAMP` | `..._BUDGETYEAR_TRANSFERNO_TIMESTAMP` | 2.3 |
| REFERENCE4 | `'เงินกันเหลื่อมปี '+BUDGETYEAR+'-'+DEPTID+' เลขที่เงินกัน '+TRANSFERNO` | `'เงินกันเหลื่อมปี '+BUDGETYEAR+' '+TRANSFERNO` | 2.4 |
| REFERENCE5 | เหมือน REFERENCE4 เดิม | เหมือน REFERENCE4 ใหม่ | 2.5 |
| ENCUMBRANCE_TYPE | มี | **ไม่มี** | 2.2 |
| TYPE | ENC=`'O'` / BG=`'I'` | **Fixed `'I'` ทั้งคู่** | 2.8 |
| TRANSFERTYPE | `'CARRYFWD'` | **`'CARRYPRPO'`** | 2.9 |
| ตารางหลัก (item) | `OAGWBG_BUDGETRESERVED_CATEGORY` | **`OAGWBG_BUDGETRESERVEDITEM`** | 2.13 |
| REGION filter | ไม่กรอง | **`BUDGETRESERVEDREGION = 'P'`** | 2.12 |
| SEGMENT 1-13 | Parse จาก fields แยก (`CATEGORYID`, `PRODUCTID`, ...) | **Parse จาก `ACCOUNTCODE` ด้วย `REGEXP_SUBSTR`** | 2.13 |
| ENTERED_DR | `BRSC.TOTALRESERVEDAMOUNT` | **`I.TOTALBALANCEAMOUNT`** | ยอดสุทธิ PR/PO |
| REFERENCE10 | `CC.NAME` (ชื่อหมวด) | **`I.BOOKNUMBER`** (เลข PR/PO) | |

---

## 5. Tables ที่ใช้ใน View ใหม่

| ประเภท | Object | Alias | เงื่อนไข JOIN |
|---|---|---|---|
| TABLE | `OAGWBG_BUDGETRESERVEDITEM` | I | หลัก |
| TABLE | `OAGWBG_BUDGETRESERVED` | BRS | `I.BUDGETREVERSEDID = BRS.ID` + `BUDGETRESERVEDREGION='P'` + `ROUNDINTERFACE IS NOT NULL` |
| TABLE | `OAGWBG_BUDGETRESERVED_BANKACCOUNT` | BRB | `BRB.RESERVEDID = BRS.ID` |
| VIEW | `OAGWBG_V_EXT_OAGCE_BANK_ACCOUNT_V` | BCC_GIVER | `BCC_GIVER.BANK_ACCOUNT_ID = BRB.BANKACCOUNTGIVER` |
| VIEW | `OAGWBG_V_EXT_OAGCE_BANK_ACCOUNT_V` | BCC_RECEIVER | `BCC_RECEIVER.BANK_ACCOUNT_ID = BRB.BANKACCOUNTRECEIVER` |
| TABLE | `OAGWBG_SYSTEMCONFIG` | SC | `SC.CONFIG_KEY = 'Ledger'` |
| TABLE | `OAGWBG_RECEIVE_BATCH_NO` | RBN | LEFT JOIN ตาม RECEIVEID + ROUNDNO + INTERFACETYPE |
| SYNONYM | `DUAL` | — | ใน TYPE_MAP CTE |

> **ตัดออกจาก View เดิม:** `OAGWBG_BUDGETRESERVED_CATEGORY`, `OAGWBG_V_EXT_OAGPO_EXPENSE_ACCOUNT_RULE_V`, `OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V`

---

## 6. หมายเหตุ / ข้อควรระวัง

> [!NOTE]
> `OAGWBG_BUDGETRESERVEDITEM.ACCOUNTCODE` มี 13 segments คั่นด้วย `.` ตรงกับ SEGMENT1-13 ของ GL Interface ไม่ต้องคำนวณ logic เพิ่ม

> [!WARNING]
> ข้อมูล REGION=P ปัจจุบัน `ROUNDINTERFACE IS NULL` ทั้งหมด — View จะไม่คืนผลจนกว่าจะมีการ set `ROUNDINTERFACE` บนข้อมูล Province

> [!IMPORTANT]
> `ENTERED_DR` / `ACCOUNTED_DR` ใช้ `TOTALBALANCEAMOUNT` (ยอดคงเหลือ PR/PO) แทน `TOTALRESERVEDAMOUNT` เพราะ BUDGETRESERVEDITEM ไม่มี field `TOTALRESERVEDAMOUNT` ตรงๆ — **ตรวจสอบกับทีม Business ว่าต้องการใช้ TOTALBALANCEAMOUNT, TOTALHASPOAMOUNT, หรือ TOTALHASPRAMOUNT**

---

*สร้างโดย Antigravity AI — 2026-04-22*
