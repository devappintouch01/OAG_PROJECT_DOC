# โอนเงินปรับเงินเหลือจ่าย — ยอดเงินดึงมาจากไหน / ไม่ตรง Oracle / ก้อนถัวเฉลี่ยแสดงไม่ครบ

> วันที่วิเคราะห์: 2026-10-02 · วิเคราะห์อย่างเดียว **ยังไม่แก้โค้ด ยังไม่แก้ DB**
> DB: PREPROD `172.16.11.19:1541/ebs_PRE` (ตรวจแล้วว่า `appsettings.Development.json` ชี้ PREPROD)
> หลักฐาน: ยิง API จริง `GET https://localhost:7068/api/Budget/SearchBudgetTransferDetail` (โค้ดใน workspace ปัจจุบัน)
> แล้วเทียบกับ `APPS.GL_BALANCES` (BUDGET_VERSION_ID 1001, ปิดงวด SEP) ตรง ๆ

| อาการที่แจ้ง | สถานะ |
|---|---|
| 1. ยอดไม่ตรงกับ Oracle | ✅ หาสาเหตุเจอ — ข้อ 2 (A) + (B) |
| 2. ยอดคงเหลือแสดงเยอะกว่ายอดจัดสรรตั้งต้น | ✅ หาสาเหตุเจอ — ข้อ 2 (A) + (C) |
| 17/09 กดค้นหาแล้วไม่มีจำนวนเงิน | แก้ไปแล้ว (ยืนยัน: ค้นหาได้ยอดครบทุกแถว `fundsAvailableError=false`) |
| 25/09 ยอดเงินแสดงไม่ครบ ก้อนถัวเฉลี่ย | ✅ หาสาเหตุเจอ — ข้อ 2 (A) + (B) |

---

## 1. ยอดเงินบนหน้าจอดึงมาจากไหน

```
[ค้นหา] BudgetReserveTransferDetail.cshtml loadRowsFromSearch()
  → MVC BudgetController.SearchBudgetTransferDetail
  → API BudgetService.SearchBudgetTransferDetail (BudgetService.cs:18812)
      ① แถว   = OAGWBG_V_BUDGETRECEIVESUMMARY_REFUND (ถังเว็บ) WHERE TOTALBALANCEAMOUNT <> 0   (:18862)
      ② ยอด 4 ช่อง (จัดสรร/กันไว้เบิก/เบิกจ่าย/คงเหลือ)
         - แถวเงินกัน (RESERVEDNO / แหล่ง 400) → ยอดถังเว็บ (:19025)
         - แถวอื่น → ประกอบบัญชี 13 segment "ระดับรายการ (detail)" ต่อ 1 แถว
             seg5/8/10/11 จาก OAGWBG_V_EXT_OAGPO_EXPENSE_ACCOUNT_RULE_V (ตาม CATEGORYID)
             แล้วรวมยอดพี่น้องข้าม seg10/12/13 (:19116)
             ดึงยอดผ่าน APPS.OAG_GL_FUNDS_AVAILABLE_PKG_BYPASS, P_TEMPLATE_ID = NULL (:19398)
      ③ คงเหลือที่ปรับได้ = ยอด GL − ใบโอนปรับเหลือจ่าย 80101/80201 ที่ GL ยังไม่รับรู้ (:19187)
```

**ใจความ:** หน้าจอคิดยอด **ทีละรายการ (detail account)** แต่ EBS คุมงบ **ระดับก้อนถัวจ่าย (summary account)**

---

## 2. สาเหตุ

### (A) หลัก — EBS คุมงบระดับ "ก้อนถัวเฉลี่ย" แต่หน้าจอคิดทีละรายการ

EBS มี Summary Template ต่อหน่วยงาน (`APPS.GL_SUMMARY_TEMPLATES`) เช่นของส่วนกลาง:

| TEMPLATE_ID | ชื่อ | โครงสร้าง |
|---|---|---|
| 3023 | 000-ค่าใช้จ่ายดำเนินงาน (ตอบแทน ใช้สอย วัสดุ สาธา) | `สนง.อัยการสูงสุด.สนง.อัยการสูงสุด.D.D.D.D.D.210.D.รหัสบัญชีค่าใช้จ่าย.T.T.T` |
| 3021 / 3022 / 3025 … | บุคลากร / ดำเนินงาน(บุคลากร) / ครุภัณฑ์ ฯลฯ | แบบเดียวกัน |

→ งบประเภท ตอบแทน (211001) + ใช้สอย (212001) + วัสดุ (213001) + สาธา (214001) **ทุกบัญชีย่อย (seg11 = T)**
และ **ทุกศูนย์ต้นทุนในกรม (seg1/seg2 = T290060000)** รวมเป็นก้อนเดียว = ก้อนถัวเฉลี่ย
GL จึงยอมให้บางบัญชีย่อย "ติดลบ" ได้ ตราบที่ทั้งก้อนยังเป็นบวก

**หลักฐาน (cc 2906999999 · ปี 2569 · แหล่ง 100 · 21000.21100 · รหัสงบ …280):**

| | ยอด |
|---|---|
| ก้อนจริงใน GL — CCID 67047 `T290060000.T290060000.69.100.20000.21000.21100.210000.29006630001004100280.5999999999.T` | งบ **802,769,788.05** · ผูกพัน 5,247,435.28 · **คงเหลือ 797,522,352.77** |
| ผลรวม "จำนวนเงินจัดสรร" 4 ประเภทงบบนหน้าจอ | 802,769,788.05 (ตรงกับก้อนพอดี → แหล่งข้อมูลถูก) |
| ผลรวม "คงเหลือที่ปรับได้" ที่หน้าจอให้กรอก | **986,886,642.16** ← **เกินก้อนจริง ~189.36 ล้าน** |
| แถวที่ติดลบ (หน้าจอปัดเป็น 0 / กรอกไม่ได้) | −189,364,289.39 รวม เช่น วัสดุงานบ้านงานครัว −5,251,100, ค่าอื่นๆ −24,894,928.48 |

ผลต่อผู้ใช้:
- แถวที่ติดลบ → เห็น 0 / ห้ามกรอก ทั้งที่ก้อนยังมีเงิน = **"ก้อนถัวเฉลี่ยแสดงไม่ครบ"**
- แถวที่เป็นบวก → ปรับได้เต็มยอดรายการ ไม่หักส่วนที่ถัวไปจ่ายรายการอื่น = **"คงเหลือเยอะกว่ายอดจัดสรร" / "ไม่ตรง Oracle"**
- (ถ้าปรับตามที่หน้าจอให้ จะเกินก้อนจริงได้ ~189 ล้าน — ด่าน `find_budget` ถูกปิดไว้ตั้งแต่ 2026-09-02)

### (B) แถว "ยอดยกมา" (ก้อนเหมา) ปี 2568 แหล่ง 200 ชี้ผิดบัญชี → โชว์ 0

| | |
|---|---|
| แถว | BUDGETRECEIVE 22168 · หมวด 16125 "ยอดยกมา เงินรายได้สะสมที่เหลือจ่าย…" · ถังเว็บคงเหลือ 82,815,186.73 |
| บัญชีที่หน้าจอประกอบ (rule หมวด 16125 → แผนงาน 90000) | CCID 129486 `…68.200.`**`90000`**`.00000.00000.000000.29006500000000000000.5900000001.000000` → งบ **0** |
| บัญชีที่งบอยู่จริงใน GL | CCID 67785 `…68.200.`**`00000`**`.00000.00000.000000.29006500000000000000.5900000001.000000` → งบ **82,919,186.73** |

ปี 2569 หมวดเดียวกันตั้งงบไว้ที่แผนงาน 90000 (แถว 52146 แสดง 5,000,000 ถูก) → **GL ปี 68 ตั้งงบยอดยกมาไว้คนละแผนงานกับ rule**
เป็นปัญหาข้อมูล/rule มากกว่าโค้ด ต้องให้ฝ่ายการเงินยืนยันว่าตัวไหนถูก

### (C) GL กับเว็บตั้งงบไม่เท่ากัน (ไม่ใช่บั๊กการคำนวณ)

cc 2900600001 · ปี 2569 · หมวด 2380 "ชุดโต๊ะประชุม ขนาด 15 ที่นั่ง":
เว็บจัดสรร 150,000,000 แต่ GL CCID 139480 มีงบ **250,000,000** → หน้าจอโชว์คงเหลือ 247,089,276.58
หน้าจอแสดงตาม Oracle ถูกแล้ว แต่ข้อมูล 2 ฝั่งไม่ตรงกัน (น่าจะตั้งงบ/โอนใน GL ตรง ๆ หรือเป็นข้อมูลทดสอบ)

### ไม่ใช่ปัญหา (ตรวจแล้ว)

แถว "ยอดยกมา" ปี 68 แหล่ง 100 (BUDGETRECEIVE 54497–54503) **ไม่ขึ้นในผลค้นหา** เพราะถูกใช้หมดแล้วจริง
โดยใบ 6810028 (ID 2376, สถานะ 80201) `REFUNDAMOUNT = TOTALRECEIVEAMOUNT` → `TOTALBALANCEAMOUNT = 0` → ถูกกรองที่ ①
GL ยังเห็นยอดเต็มเพราะการยืนยันหน้านี้ไม่ส่ง GL (`//ไม่ต้อง interface`) — ถูกต้องตาม design

---

## 3. แนวทางแก้ (ต้องให้ BA/ผู้ใช้ตัดสินใจก่อน)

| # | แนวทาง | ปิดอาการ | ระดับ |
|---|---|---|---|
| A1 | แสดง "คงเหลือของก้อนถัวเฉลี่ย" เป็นแถวหัวกลุ่ม (ดึงจาก summary CCID ตาม template: segment ที่เป็น `T` ใช้ค่า rollup, segment `D` ใช้ค่าจริง) และให้ **เพดานการกรอก = คงเหลือของก้อน − ยอดที่กรอกไปแล้วในก้อนเดียวกัน** แทนเพดานรายแถว | A ทั้งหมด | R1 — เปลี่ยน logic เพดาน |
| A2 | (ทางสั้น) คงหน้าจอเดิม แต่เพิ่มด่านตอนบันทึก: ผลรวมที่ปรับในก้อน ≤ คงเหลือของ summary CCID | กันปรับเกินก้อน (ยังโชว์แถวติดลบเป็น 0) | R1 |
| B1 | ฝ่ายการเงินยืนยันว่ายอดยกมาปี 68 ต้องอยู่แผนงาน 00000 หรือ 90000 แล้วแก้ข้อมูล GL **หรือ** rule หมวด 16125 | B | R1 — แก้ข้อมูล |
| C1 | ตัดสินใจว่า "คงเหลือที่ปรับได้" ควรเป็น `MIN(ยอด GL, ยอดถังเว็บ)` หรือยึด GL อย่างเดียว | C | R1 |

**คำถามที่ต้องตอบก่อนลงมือ:**
1. หน้าจอควรแสดง/คุมยอดระดับก้อนถัวเฉลี่ย (A1) หรือแค่กันตอนบันทึก (A2)?
2. ก้อนถัวเฉลี่ยของส่วนกลางรวมทุกศูนย์ต้นทุนในกรม (seg1/seg2 = T) — ถ้าเลือกศูนย์ต้นทุนเดียว ควรเห็นคงเหลือของทั้งกรมหรือไม่?
3. ยอดยกมาปี 68 (หมวด 16125) ที่ถูกต้องคือแผนงาน 00000 หรือ 90000?

---

## 4. ข้อสังเกตเพิ่ม

- การกดค้นหา **เขียนลง EBS** ทุกครั้ง: DELETE/INSERT/COMMIT `APPS.OAG_GL_FUNDS_AVAILABLE_PKG_BYPASS` และ `TryAutoCombineAccountAsync`
  สร้าง code combination ใหม่ให้แถวที่ไม่มีรหัสงบ (พบ combination รหัสงบ `00000000000000000000` ที่น่าจะเกิดจากการค้นหา เช่น CCID 181083–181086, 187513–187518)
- `pendingRefundAmount` ของ 54496 = 262,989,602 (ปัดเป็นจำนวนเต็ม) เทียบงบ GL 262,989,601.57 — `REFUNDAMOUNT` ถูกเก็บแบบปัดเศษ

---

## 5. SQL ที่ใช้ยืนยัน (rerun ได้)

```sql
-- 5.1 ยอดก้อนถัวเฉลี่ยจริง (summary account)
SELECT C.TEMPLATE_ID, C.CODE_COMBINATION_ID,
       SUM(CASE WHEN B.ACTUAL_FLAG='B' THEN B.BEGIN_BALANCE_DR-B.BEGIN_BALANCE_CR+B.PERIOD_NET_DR-B.PERIOD_NET_CR END) BUD,
       SUM(CASE WHEN B.ACTUAL_FLAG='E' THEN B.BEGIN_BALANCE_DR-B.BEGIN_BALANCE_CR+B.PERIOD_NET_DR-B.PERIOD_NET_CR END) ENC
  FROM APPS.GL_CODE_COMBINATIONS C
  LEFT JOIN APPS.GL_BALANCES B ON B.CODE_COMBINATION_ID = C.CODE_COMBINATION_ID
       AND B.PERIOD_NAME = 'SEP-26' AND B.CURRENCY_CODE = 'THB' AND (B.ACTUAL_FLAG <> 'B' OR B.BUDGET_VERSION_ID = 1001)
 WHERE C.TEMPLATE_ID = 3023 AND C.SEGMENT3 = '69' AND C.SEGMENT4 = '100'
   AND C.SEGMENT6 = '21000' AND C.SEGMENT7 = '21100' AND C.SEGMENT9 = '29006630001004100280'
 GROUP BY C.TEMPLATE_ID, C.CODE_COMBINATION_ID;

-- 5.2 ยอดรายบัญชี (detail) ในก้อนเดียวกัน — ดูบัญชีที่ติดลบ
SELECT C.SEGMENT8, C.SEGMENT10, C.SEGMENT11, C.CODE_COMBINATION_ID,
       SUM(CASE WHEN B.ACTUAL_FLAG='B' THEN B.BEGIN_BALANCE_DR-B.BEGIN_BALANCE_CR+B.PERIOD_NET_DR-B.PERIOD_NET_CR END) BUD
  FROM APPS.GL_BALANCES B JOIN APPS.GL_CODE_COMBINATIONS C ON C.CODE_COMBINATION_ID = B.CODE_COMBINATION_ID
 WHERE C.SEGMENT2 = '2906999999' AND C.SEGMENT3 = '69' AND C.SEGMENT4 = '100'
   AND C.SEGMENT6 = '21000' AND C.SEGMENT7 = '21100' AND C.SEGMENT9 = '29006630001004100280'
   AND C.SEGMENT8 IN ('211001','212001','213001','214001')
   AND B.PERIOD_NAME = 'SEP-26' AND B.ACTUAL_FLAG = 'B' AND B.BUDGET_VERSION_ID = 1001
 GROUP BY C.SEGMENT8, C.SEGMENT10, C.SEGMENT11, C.CODE_COMBINATION_ID
 ORDER BY BUD;

-- 5.3 ยอดยกมาปี 68 แหล่ง 200: แผนงาน 00000 vs 90000
SELECT C.CODE_COMBINATION_ID, C.SEGMENT5,
       SUM(B.BEGIN_BALANCE_DR-B.BEGIN_BALANCE_CR+B.PERIOD_NET_DR-B.PERIOD_NET_CR) BUD
  FROM APPS.GL_CODE_COMBINATIONS C
  LEFT JOIN APPS.GL_BALANCES B ON B.CODE_COMBINATION_ID = C.CODE_COMBINATION_ID
       AND B.PERIOD_NAME = 'SEP-25' AND B.ACTUAL_FLAG = 'B' AND B.BUDGET_VERSION_ID = 1001
 WHERE C.CODE_COMBINATION_ID IN (67785, 129486)
 GROUP BY C.CODE_COMBINATION_ID, C.SEGMENT5;
```
