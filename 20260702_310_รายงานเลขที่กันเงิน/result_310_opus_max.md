# ผลวิเคราะห์ 310 — รายงานเลขที่กันเงิน (VIEW `OAGWBG_R_BUDGETOVERLAP_RESERVED`)

> เอกสารวิเคราะห์อย่างเดียว (analysis only) — **ไม่แก้โค้ดโปรดักชัน** ตาม prompt ข้อ 2
> วันที่: 2026-07-02 · โมเดล: Opus 4.8 (max) · Source: `prompt_310.md`
> ✅ ตรวจสอบกับ **Oracle PREPROD จริง** แล้ว (ต่อ VPN F5 สำเร็จ, host 172.16.11.19:1541)

---

## 0. บทสรุปผู้บริหาร (Executive Summary)

- Report "รายงานเลขที่กันเงิน" ต้องการ VIEW ใหม่ชื่อ **`OAGWBG_R_BUDGETOVERLAP_RESERVED`** โดยยึดโครงสร้างจากวิวที่มีอยู่ **`OAGWBG_R_BUDGETOVERLAP`** และ **`OAGWBG_R_BUDGETOVERLAP_EXPAND`**
- ทุกฟิลด์ที่ prompt ต้องการ **มีอยู่จริงในฐานข้อมูลแล้ว** — ไม่ต้อง ALTER TABLE เพิ่ม column ใด ๆ:
  - `TOTALBALANCEAMOUNT`, `BOOKNUMBER`, `USAGEAMOUNT`, `BUDGETRESERVEDTYPE`, `NOTE`, `RESERVEDNO_ADD` → อยู่ครบทั้งตาราง `OAGWBG_BUDGETRESERVEDITEM` และวิว `OAGWBG_V_BUDGETRESERVEDITEM`
  - `REGIONNAME` → มีในวิว `OAGWBG_V_EXT_OAGGL_COST_CENTER_V` (ซึ่งวิวเดิม join อยู่แล้วในชื่อ alias `COSTV`)
  - `CATEGORYNAME` → มีในวิว `OAGWBG_V_BUDGETRESERVED_CATEGORY`
- **ข้อค้นพบสำคัญเรื่อง data model:** รายการที่เข้าสู่รอบขยายเวลา/ส่งคืน จะถูกเก็บเป็น row ที่ `BUDGETRESERVEDTYPE` = `EXPAND_PO/EXPAND_PR/CANCEL_PO/CANCEL_PR` โดยตรง — **row เดียวกันมีทั้ง `TOTALBALANCEAMOUNT` (จำนวนเงินจัดสรร) และ `USAGEAMOUNT` (ยอดขยาย/ดำเนินการ)** จึงทำเป็น VIEW แบบ 1 row ต่อ 1 รายการ (flat) แล้ว pivot ด้วย `CASE` ได้เลย เหมือน `OAGWBG_R_BUDGETOVERLAP_EXPAND`
- ทดสอบกับข้อมูลจริงพบว่า **หัวกันเงิน `ID=34` (TRANSFERNO=68030001) = ตัวอย่างในหน้าแรกของ PDF พอดี** (3 รายการ: 26900145 "ค่าปรับปรุงอาคาร A" bal 3,000 / 16900360 "รายการก่อสร้าง" bal 1,000 / 16900361 "ปรับปรุง B" bal 2,000) → ยืนยัน mapping ถูกต้อง
- มี **3 จุดที่ต้องขอ BA/ผู้ใช้ยืนยัน** ก่อน finalize (ดูข้อ 7): (1) นิยาม "เลขที่โอนจัดสรร", (2) จะรวม row ฐาน `O/R` เข้าวิวด้วยไหม, (3) key การยุบรวมบรรทัด EXPAND+CANCEL

---

## 1. Requirement + Mapping ตาม prompt

รายงานอยู่ภายใต้ endpoint เดิม `GET /Report/ReportBudgetOverlap` (ClosedXML → Excel) ซึ่งปัจจุบันมี 3 template (ReportTypeID = `1`,`2`,default) — รายงานใหม่นี้คือ **template เพิ่มอีก 1 แบบ** ที่ดึงจากวิวใหม่

| # | คอลัมน์ในรายงาน (PDF หน้า 1) | prompt สั่งให้ใช้ | คอลัมน์ในวิวที่เสนอ | แหล่งข้อมูลจริง |
|---|---|---|---|---|
| 1 | ลำดับ | รันเลขไปเรื่อย ๆ | *(สร้างที่ชั้น report `index++` หรือ `ROW_NUMBER()`)* | — |
| 2 | เลขที่โอนจัดสรร | `transferno` | `ALLOCATE_TRANSFERNO` ⚠️ | `PO_TRANSFER_NO` / `PR_TRANSFER_NO` (ดูข้อ 7.1) |
| 3 | พื้นที่ ภาค | `REGIONNAME` ตาม `REGIONID` | `REGIONNAME` | `COSTV.REGIONNAME` |
| 4 | สำนักงาน | หยิบจากศูนย์ต้นทุน | `COSTCENTERNAME` | `COSTV.NAME` |
| 5 | รายการ | `CATEGORYNAME` | `CATEGORYNAME` (+ `DESCRIPTION`) | `CAT.CATEGORYNAME` |
| 6 | จำนวนเงินจัดสรร | `TOTALBALANCEAMOUNT` จาก RESERVEDITEM | `TOTALBALANCEAMOUNT` | `BRSI.TOTALBALANCEAMOUNT` |
| 7 | เลขที่เอกสาร | `BOOKNUMBER` จาก RESERVEDITEM | `BOOKNUMBER` | `BRSI.BOOKNUMBER` |
| 8 | อนุมัติขยาย — มีหนี้ | `USAGEAMOUNT` ที่ `BUDGETRESERVEDTYPE=EXPAND_PO` | `APPROVE_EXPAND_HASOBLIGATION` | `CASE … EXPAND_PO` |
| 9 | อนุมัติขยาย — ไม่มีหนี้ | `USAGEAMOUNT` ที่ `EXPAND_PR` | `APPROVE_EXPAND_NOOBLIGATION` | `CASE … EXPAND_PR` |
| 10 | ดำเนินการ มีหนี้ | `USAGEAMOUNT` ที่ `CANCEL_PO` | `PROCESS_HASOBLIGATION` | `CASE … CANCEL_PO` |
| 11 | ดำเนินการ ไม่มีหนี้ | `USAGEAMOUNT` ที่ `CANCEL_PR` | `PROCESS_NOOBLIGATION` | `CASE … CANCEL_PR` |
| 12 | หมายเหตุ | `NOTE` จาก RESERVEDITEM | `NOTE` | `BRSI.NOTE` |
| 13 | *(เพิ่มเข้าวิว)* | `RESERVEDNO_ADD` จาก RESERVEDITEM | `RESERVEDNO_ADD` | `BRSI.RESERVEDNO_ADD` |
| — | *(หัวกลุ่ม)* เลขที่กันเงิน / ยอดกันรวม | — | `TRANSFERNO`, `TOTALRESERVEDAMOUNT` | `BRS.TRANSFERNO`, `CAT.TOTALRESERVEDAMOUNT` |

> **หมายเหตุ PDF vs prompt:** ในหน้า PDF ช่อง "ดำเนินการ มีหนี้" ยังซอยย่อยเป็น *จำนวนเงินเบิกจ่ายแล้วเสร็จ* กับ *จำนวนเงินเหลือจ่าย/ส่งคืน* แต่ **prompt ระบุให้ใช้ `USAGEAMOUNT` ค่าเดียว** ต่อช่อง → เอกสารนี้ยึดตาม prompt (1 ค่า/ช่อง) และตั้งเป็นข้อสังเกตไว้เผื่อขยายภายหลัง

---

## 2. หลักฐานจากฐานข้อมูลจริง (ยืนยันแล้ว)

### 2.1 DDL ของวิวต้นแบบ `OAGWBG_R_BUDGETOVERLAP` (ตัดเฉพาะโครง join)
```sql
FROM      OAGWBG_V_BUDGETRESERVED           BRS
LEFT JOIN OAGWBG_V_BUDGETRESERVEDITEM       BRSI  ON BRS.ID = BRSI.BUDGETREVERSEDID
LEFT JOIN OAGWBG_V_BUDGETRESERVED_CATEGORY  CAT   ON BRS.ID = CAT.BUDGETRESERVEDID
LEFT JOIN OAGWBG_V_EXT_OAGGL_DEPARTMENT_V   DEPTV ON BRS.DEPARTMENTID = DEPTV.ID
LEFT JOIN OAGWBG_V_EXT_OAGGL_COST_CENTER_V  COSTV ON BRS.COSTCENTERID = COSTV.ID   -- มี REGIONID + REGIONNAME
LEFT JOIN OAGWBG_V_EXT_OAGPO_TRANSACTION_STATUS_V TSV ON …
WHERE  (CASE WHEN BRS.BUDGETRESERVEDREGION='C' THEN BRS.STATUSID ELSE BRSI.STATUSID END) NOT IN (90102, 90202)
```
- วิวเดิมเลือก `COSTV.REGIONID` แต่ **ไม่ได้เลือก `REGIONNAME`** → วิวใหม่แค่เพิ่ม `COSTV.REGIONNAME` ก็ได้ตามที่ prompt ต้องการ
- `OAGWBG_R_BUDGETOVERLAP_EXPAND` เป็นตัวอย่างการ pivot `BUDGETRESERVEDTYPE` (รวม `EXPAND_PO/EXPAND_PR`) และกรอง `WHERE BRSI.STATUSID = 90102` → วิวใหม่ต่อยอดจากแนวนี้

### 2.2 โครงสร้าง `OAGWBG_BUDGETRESERVEDITEM` (ฟิลด์ที่ใช้ — มีครบ)
| Column | Type | ใช้เป็น |
|---|---|---|
| `TOTALBALANCEAMOUNT` | NUMBER | จำนวนเงินจัดสรร |
| `BOOKNUMBER` | VARCHAR2(20) | เลขที่เอกสาร (PR/PO) |
| `USAGEAMOUNT` | NUMBER(18,2) | ยอดอนุมัติขยาย / ดำเนินการ |
| `BUDGETRESERVEDTYPE` | VARCHAR2(255) | `O`/`R`/`EXPAND_PO`/`EXPAND_PR`/`CANCEL_PO`/`CANCEL_PR` |
| `NOTE` | NVARCHAR2(1000) | หมายเหตุ |
| `RESERVEDNO_ADD` | VARCHAR2(250) | เลขที่เงินกันเพิ่ม `<เลขที่กันเงิน>.n` |
| `TRANSFERNO` | VARCHAR2(255) | (ระดับ item — ข้อมูลจริงว่างเปล่า) |

> วิว `OAGWBG_V_BUDGETRESERVEDITEM` expose ครบทุกฟิลด์ข้างบน **และ** เพิ่ม `PR_TRANSFER_NO`, `PO_TRANSFER_NO`, `COSTCENTERID`, `DEPARTMENTID`, `STATUSNAME` ให้ด้วย

### 2.3 ข้อมูลตัวอย่างจริง = ตรงกับ PDF หน้า 1 (หัวกันเงิน `ID=34`)
```
HDR=34  TRANSFERNO=68030001  region=C  costcenter=2900600001
CATEGORY: catCode=241001  TOTALRESERVEDAMOUNT=10,000  name=ค่าควบคุมงานปรับปรุงอาคารที่ทำการและสิ่งก่อสร้างประกอบ
costcenter 2900600001 → REGIONID=00  REGIONNAME=ส่วนกลาง  NAME=สำนักงานเลขาธิการสำนักงานอัยการสูงสุด และหน่วยงานในสังกัด 13 หน่วยงาน

items:
  ID=151 EXPAND_PO book=26900145 bal=3000 usage=10   desc=ค่าปรับปรุงอาคาร A
  ID=152 EXPAND_PR book=16900360 bal=1000 usage=1    desc=รายการก่อสร้าง
  ID=153 EXPAND_PR book=16900361 bal=2000 usage=1.1  desc=ปรับปรุง B
```
เทียบกับ PDF: `จำนวนเงิน 10,000` = `CAT.TOTALRESERVEDAMOUNT`, "ส่วนกลาง" = `REGIONNAME`, สำนักงาน = `COSTV.NAME`, และ `จำนวนเงินจัดสรร` 3,000/1,000/2,000 = `TOTALBALANCEAMOUNT` ของ 3 รายการ ✅
(ค่า `usage` ใน DB ปัจจุบัน = 10/1/1.1 เป็นข้อมูลทดสอบที่แก้ทีหลัง ส่วน PDF จับภาพตอน usage=balance)

### 2.4 พฤติกรรม EXPAND / CANCEL (จากหัว `ID=60`)
```
book 26900217  EXPAND_PO  usage=15000  RESERVEDNO_ADD=68030011.1  note=ขยายต่อ   (รอบ 1)
book 26900217  CANCEL_PO  usage=0      RESERVEDNO_ADD=68030011.1                (ดำเนินการ รอบ 1)
book 26900217  EXPAND_PO  usage=10     RESERVEDNO_ADD=68030011.2  note=         (รอบ 2)
book 16900368  EXPAND_PR  usage=20000  note=ขยายต่อ
book 16900368  CANCEL_PR  usage=10000  note=ส่งคืน
```
- `RESERVEDNO_ADD` = `<เลขที่กันเงิน>.<รอบ>` → ยืนยันว่าเป็น "เลขที่เงินกันเพิ่ม" (ตรงกับงาน 308)
- `NOTE` มีค่า "ขยายต่อ"/"ส่งคืน" จริง
- `PO_TRANSFER_NO`/`PR_TRANSFER_NO` มีค่า เช่น `6911481`, `6911480` = เลขที่โอนจัดสรรต้นทาง (คนละตัวกับ `TRANSFERNO`=เลขที่กันเงิน)
- คู่ EXPAND+CANCEL ของ book+`RESERVEDNO_ADD` เดียวกัน = 1 บรรทัดในรายงาน (มีทั้ง "อนุมัติขยาย" และ "ดำเนินการ")

---

## 3. VIEW ที่เสนอ — `OAGWBG_R_BUDGETOVERLAP_RESERVED`

> เป็นวิวแบบ **flat 1 row / 1 รายการกันเงิน** (เหมือน `..._EXPAND`) แล้ว pivot ยอดด้วย `CASE`
> ชั้น report (`ReportService`) ทำหน้าที่ รันลำดับ + ยุบรวมบรรทัด (group) + ทำ subtotal ตามหมวด

```sql
CREATE OR REPLACE VIEW OAGWBG_R_BUDGETOVERLAP_RESERVED AS
SELECT
    -- ===== ระดับหัวกันเงิน (group) =====
    BRS.ID                                   AS BUDGETRESERVEDID,
    BRS.BUDGETYEAR                           AS BUDGETYEAR,
    BRS.TRANSFERNO                           AS TRANSFERNO,            -- เลขที่กันเงิน (หัวกลุ่มรายงาน)
    BRS.RESERVATIONNAME                      AS RESERVATIONNAME,
    BRS.RESERVATIONTYPE                      AS RESERVATIONTYPE,
    BRS.BUDGETRESERVEDREGION                 AS BUDGETRESERVEDREGION,

    -- ===== เลขที่โอนจัดสรร (⚠️ ดูข้อ 7.1) =====
    COALESCE(BRSI.PO_TRANSFER_NO, BRSI.PR_TRANSFER_NO, BRSI.TRANSFERNO) AS ALLOCATE_TRANSFERNO,

    -- ===== พื้นที่ภาค / สำนักงาน (จากศูนย์ต้นทุน) =====
    COSTV.REGIONID                           AS REGIONID,
    COSTV.REGIONNAME                         AS REGIONNAME,            -- พื้นที่ ภาค
    BRS.COSTCENTERID                         AS COSTCENTERID,
    COSTV.NAME                               AS COSTCENTERNAME,        -- สำนักงาน
    BRS.DEPARTMENTID                         AS DEPARTMENTID,
    DEPTV.NAME                               AS DEPARTMENTNAME,

    -- ===== รายการ (หมวด) =====
    CAT.CATEGORYID                           AS CATEGORYID,
    CAT.CATEGORYNAME                         AS CATEGORYNAME,          -- รายการ (ตาม prompt)
    CAT.CATEGORY_CODE                        AS CATEGORY_CODE,
    CAT.TOTALRESERVEDAMOUNT                  AS TOTALRESERVEDAMOUNT,   -- ยอดกันเงินรวมของหมวด

    -- ===== ระดับรายการ (item) =====
    BRSI.ID                                  AS ITEMID,
    BRSI.DESCRIPTION                         AS DESCRIPTION,           -- ชื่อรายการระดับ item (ที่ PDF โชว์ในบรรทัดย่อย)
    BRSI.SUPPLIER                            AS SUPPLIER,
    BRSI.BOOKNUMBER                          AS BOOKNUMBER,            -- เลขที่เอกสาร
    BRSI.ACCOUNTCODE                         AS ACCOUNTCODE,
    BRSI.BUDGETRESERVEDTYPE                  AS ITEMRESERVEDTYPE,      -- O/R/EXPAND_*/CANCEL_*
    BRSI.TOTALBALANCEAMOUNT                  AS TOTALBALANCEAMOUNT,    -- จำนวนเงินจัดสรร
    BRSI.USAGEAMOUNT                         AS USAGEAMOUNT,           -- ยอดที่ใช้ (raw)
    BRSI.RESERVEDNO_ADD                      AS RESERVEDNO_ADD,        -- เลขที่เงินกันเพิ่ม .n
    BRSI.NOTE                                AS NOTE,                  -- หมายเหตุ
    BRSI.OVERLAPYEAR                         AS OVERLAPYEAR,
    BRSI.OVERLAPROUND                        AS OVERLAPROUND,
    BRSI.CREATEON                            AS RESERVEDITEMDATE,

    -- ===== pivot ยอดตามประเภท (คอลัมน์รายงานตรง ๆ) =====
    CASE WHEN BRSI.BUDGETRESERVEDTYPE = 'EXPAND_PO' THEN BRSI.USAGEAMOUNT END AS APPROVE_EXPAND_HASOBLIGATION,  -- อนุมัติขยาย: มีหนี้
    CASE WHEN BRSI.BUDGETRESERVEDTYPE = 'EXPAND_PR' THEN BRSI.USAGEAMOUNT END AS APPROVE_EXPAND_NOOBLIGATION,   -- อนุมัติขยาย: ไม่มีหนี้
    CASE WHEN BRSI.BUDGETRESERVEDTYPE = 'CANCEL_PO' THEN BRSI.USAGEAMOUNT END AS PROCESS_HASOBLIGATION,         -- ดำเนินการ: มีหนี้
    CASE WHEN BRSI.BUDGETRESERVEDTYPE = 'CANCEL_PR' THEN BRSI.USAGEAMOUNT END AS PROCESS_NOOBLIGATION,          -- ดำเนินการ: ไม่มีหนี้

    -- ===== แปลประเภท / สถานะ (สไตล์เดียวกับวิวเดิม) =====
    CASE
        WHEN BRSI.BUDGETRESERVEDTYPE IN ('O','EXPAND_PO','CANCEL_PO') THEN 'มีหนี้'
        WHEN BRSI.BUDGETRESERVEDTYPE IN ('R','EXPAND_PR','CANCEL_PR') THEN 'ไม่มีหนี้'
        ELSE 'ไม่ระบุ'
    END                                      AS RESERVEDTYPENAME,
    CASE WHEN BRS.BUDGETRESERVEDREGION = 'C' THEN BRS.STATUSID   ELSE BRSI.STATUSID   END AS STATUSID,
    CASE WHEN BRS.BUDGETRESERVEDREGION = 'C' THEN BRS.STATUSNAME ELSE BRSI.STATUSNAME END AS STATUSNAME
FROM       OAGWBG_V_BUDGETRESERVED           BRS
LEFT JOIN  OAGWBG_V_BUDGETRESERVEDITEM       BRSI  ON BRS.ID = BRSI.BUDGETREVERSEDID
LEFT JOIN  OAGWBG_V_BUDGETRESERVED_CATEGORY  CAT   ON BRS.ID = CAT.BUDGETRESERVEDID   -- ⚠️ ดูข้อ 7.2 (1 หมวด/หัว)
LEFT JOIN  OAGWBG_V_EXT_OAGGL_DEPARTMENT_V   DEPTV ON BRS.DEPARTMENTID = DEPTV.ID
LEFT JOIN  OAGWBG_V_EXT_OAGGL_COST_CENTER_V  COSTV ON BRS.COSTCENTERID = COSTV.ID
WHERE  BRSI.BUDGETRESERVEDTYPE IN ('EXPAND_PO','EXPAND_PR','CANCEL_PO','CANCEL_PR');   -- ⚠️ ดูข้อ 7.3
```

### 3.1 เหตุผลการออกแบบ
1. **ยึด join เดิมจาก `OAGWBG_R_BUDGETOVERLAP` ทั้งหมด** เพื่อความสอดคล้อง (ลด TSV ที่รายงานนี้ไม่ใช้ออก)
2. **เพิ่ม `COSTV.REGIONNAME`** — จุดเดียวที่วิวเดิมขาด แต่ prompt ต้องการ (พื้นที่ภาค)
3. **4 คอลัมน์ pivot** ทำใน SQL ให้เลย เพื่อให้ report map 1:1 กับหน้าตารางโดยไม่ต้องเขียน logic แยกประเภทซ้ำใน C#
4. **คง `USAGEAMOUNT` ดิบ + `ITEMRESERVEDTYPE`** ไว้ด้วย เผื่อ report ต้องการ group/sum เอง
5. **`DESCRIPTION` เก็บไว้คู่ `CATEGORYNAME`** เพราะ PDF บรรทัดย่อยโชว์ description ระดับ item ส่วนหัวกลุ่มโชว์ category — ให้ report เลือกใช้

### 3.2 การนำไปใช้ที่ชั้น Report (ยุบรวมบรรทัด)
- **ลำดับ:** สร้างที่ `ReportService` (`index++`) เหมือน template 1/2 เดิม
- **ยุบรวม EXPAND+CANCEL เป็นบรรทัดเดียว:** group ด้วย key `(BUDGETRESERVEDID, BOOKNUMBER, RESERVEDNO_ADD)` แล้ว `SUM` 4 คอลัมน์ pivot + `MAX(TOTALBALANCEAMOUNT)` (คล้าย `GroupByBooknumberWithSumPo` ที่มีอยู่แล้ว)
- **หัวกลุ่มต่อเลขที่กันเงิน:** ใช้ `TRANSFERNO` + `CATEGORYNAME` + `TOTALRESERVEDAMOUNT`

---

## 4. งานฝั่งโค้ด (ถ้าจะต่อยอด — *ยังไม่ทำในรอบนี้*)

> ทั้งหมดเป็น R1/R2 (ย้อนกลับได้) — ระบุไว้เพื่อความครบถ้วน ไม่ได้ลงมือตาม prompt ข้อ 2

1. **DB:** `CREATE OR REPLACE VIEW OAGWBG_R_BUDGETOVERLAP_RESERVED` (R1 บน PREPROD — วิวใหม่ ไม่กระทบของเดิม, rollback = `DROP VIEW`)
2. **DAL:** เพิ่มโมเดล `OagwbgRBudgetoverlapReserved.cs` + `DbSet` + `modelBuilder.Entity<…>().HasNoKey().ToView("OAGWBG_R_BUDGETOVERLAP_RESERVED")` ใน `OAGDBContextBase.cs` (pattern เดียวกับ `OagwbgRBudgetoverlapExpand` บรรทัด ~10389)
3. **API:** เพิ่ม `case` ใหม่ใน `ReportService.ReportBudgetOverlap()` (switch `model.ReportTypeID`) วาง header/merge cell + map 13 คอลัมน์
4. **Frontend:** เพิ่มตัวเลือกประเภทรายงานใน dropdown ที่เรียก `GET /Report/ReportBudgetOverlap?ReportTypeID=<ใหม่>`

**ไม่ต้อง ALTER TABLE / ไม่ต้องเพิ่ม column** — ข้อมูลครบแล้ว (ดูข้อ 2.2)

---

## 5. Data Model ที่ค้นพบ (สรุปให้ทีม)

- `OAGWBG_BUDGETRESERVED` = หัว (1 เลขที่กันเงิน = 1 `TRANSFERNO`, มี `BUDGETRESERVEDREGION`, `COSTCENTERID`, `STATUSID`)
- `OAGWBG_BUDGETRESERVED_CATEGORY` = หมวดงบของหัว (`CATEGORYNAME`, `TOTALRESERVEDAMOUNT`) — ตัวอย่างจริง **1 หมวด/หัว**
- `OAGWBG_BUDGETRESERVEDITEM` = รายการ; ประเภทที่พบจริง (ทั้งระบบ):
  | type | จำนวน row | `USAGEAMOUNT` | ความหมาย |
  |---|---|---|---|
  | `O` | 40 | null | มีหนี้ (กันปกติ ยังไม่ขยาย) |
  | `R` | 41 | null | ไม่มีหนี้ (กันปกติ ยังไม่ขยาย) |
  | `EXPAND_PO` | 4 | มีค่า | อนุมัติขยาย-มีหนี้ |
  | `EXPAND_PR` | 4 | มีค่า | อนุมัติขยาย-ไม่มีหนี้ |
  | `CANCEL_PO` | 1 | มีค่า | ดำเนินการ-มีหนี้ |
  | `CANCEL_PR` | 2 | มีค่า | ดำเนินการ-ไม่มีหนี้ |
- **สำคัญ:** `USAGEAMOUNT` มีค่าเฉพาะ row `EXPAND_*`/`CANCEL_*` เท่านั้น (row `O/R` เป็น null) → การ pivot ด้วย `CASE` จึงถูกต้องเสมอ
- EXPAND/CANCEL row **ไม่มี** `TRANSFERNO`/`PARENTID` (ว่าง) → เชื่อมกลับหัวผ่าน `BUDGETREVERSEDID` และผูกคู่ EXPAND↔CANCEL ผ่าน `BOOKNUMBER` + `RESERVEDNO_ADD`

---

## 6. ความเสี่ยง / Reversibility

| รายการ | ระดับ | หมายเหตุ |
|---|---|---|
| `CREATE VIEW` ใหม่บน PREPROD | **R1** | ไม่กระทบวิว/รายงานเดิม; rollback = `DROP VIEW` |
| join `CAT` ระดับหัว | **R1** | ถ้ามี >1 หมวด/หัว จะเกิด fan-out (ดู 7.2) |
| ไม่มี ALTER TABLE | R2 | ข้อมูลครบแล้ว ไม่แตะ schema ตาราง |
| โค้ด C#/DAL (ถ้าทำต่อ) | R2 | อยู่ใน TFS, revert ได้ |

---

## 7. ข้อสมมติ + คำถามที่ต้องยืนยันก่อน finalize

### 7.1 "เลขที่โอนจัดสรร" มาจากไหน? ⚠️ (สำคัญสุด)
- prompt เขียนแค่ "ใช้ `transferno`" แต่ในข้อมูลจริง **`TRANSFERNO` ของหัว = เลขที่กันเงิน (68030001)** ซึ่งเป็น "หัวกลุ่ม" อยู่แล้ว ส่วนคอลัมน์ "เลขที่โอนจัดสรร" ใน PDF = `69100010` (คนละค่า)
- ผู้ช่วยเดาว่า = `PO_TRANSFER_NO`/`PR_TRANSFER_NO` (เลขที่โอนจัดสรรต้นทาง เช่น `6911481`) จึงตั้ง default เป็น `COALESCE(PO_TRANSFER_NO, PR_TRANSFER_NO, item.TRANSFERNO)`
- **ขอยืนยัน:** เลขที่โอนจัดสรร = (ก) `PO/PR_TRANSFER_NO`  (ข) `TRANSFERNO` ของหัว  หรือ (ค) ฟิลด์อื่น?

### 7.2 หมวด (Category) ต่อหัวมีได้กี่รายการ?
- ข้อมูลตัวอย่าง (หัว 34/58/60) = **1 หมวด/หัว** และ `item.CATEGORYCODE` **ว่าง** → เลย join `CAT` ที่ระดับหัวได้ (เหมือนวิวเดิม)
- **ขอยืนยัน:** ถ้า 1 เลขที่กันเงินมีได้หลายหมวด ต้องเปลี่ยนไป join ด้วย `categorycode` หรือให้รายงาน dedupe (กัน fan-out)

### 7.3 ต้องรวม row ฐาน `O`/`R` เข้าวิวด้วยไหม?
- default ของเอกสารนี้ = กรองเฉพาะ `EXPAND_*`/`CANCEL_*` (ตรงกับคอลัมน์ที่ prompt สั่ง)
- ถ้าต้องการให้รายงานโชว์ "เลขที่กันเงินที่กันไว้แต่ยังไม่ขยาย" (มีแค่ จำนวนเงินจัดสรร) ด้วย → เอา `WHERE` ประเภทออก แล้วให้ report กรองเอง
- **ขอยืนยัน:** รายงานนี้แสดงเฉพาะรายการที่เข้ารอบขยาย/ส่งคืน หรือแสดงทุกเลขที่กันเงิน?

### 7.4 การยุบรวมบรรทัด EXPAND+CANCEL
- default = group `(BUDGETRESERVEDID, BOOKNUMBER, RESERVEDNO_ADD)` (รอบ `.1`,`.2` แยกบรรทัด)
- **ขอยืนยัน:** ถ้ารายการเดียวกันขยายหลายรอบ ต้องการแยกบรรทัดตามรอบ หรือรวมยอดทุกกรอบเป็นบรรทัดเดียว?

### 7.5 ช่องย่อยของ "ดำเนินการ" ใน PDF
- PDF ซอย "ดำเนินการ-มีหนี้" เป็น *เบิกจ่ายแล้วเสร็จ* / *เหลือจ่าย-ส่งคืน* แต่ prompt ให้ใช้ `USAGEAMOUNT` ค่าเดียว → เอกสารนี้ทำตาม prompt; ถ้าต้องซอยจริงต้องระบุแหล่งข้อมูลเพิ่ม

---

## 8. ภาคผนวก — เครื่องมือ/หลักฐาน

- เครื่องมือ query (read-only, DDL/metadata inspector): `QueryDB/` ในโฟลเดอร์งานนี้
  - **ไม่ฝัง password** ในไฟล์ — อ่าน connection string จาก env `OAG_CONNSTR` ตอน run เท่านั้น
  - รัน: `$env:OAG_CONNSTR="…"; dotnet run --project QueryDB` (ต้องต่อ VPN F5 ก่อน)
- ทดสอบการเชื่อมต่อ: `Test-NetConnection 172.16.11.19 -Port 1541` → `TcpTestSucceeded = True`
- วิวที่ตรวจสอบ: `OAGWBG_R_BUDGETOVERLAP`, `OAGWBG_R_BUDGETOVERLAP_EXPAND`, `OAGWBG_V_BUDGETRESERVEDITEM`, `OAGWBG_V_BUDGETRESERVED_CATEGORY`, `OAGWBG_V_EXT_OAGGL_COST_CENTER_V`
- ยืนยันแล้วว่า **`OAGWBG_R_BUDGETOVERLAP_RESERVED` ยังไม่มีในฐานข้อมูล** (view NOT FOUND) → เป็นวิวสร้างใหม่จริง
