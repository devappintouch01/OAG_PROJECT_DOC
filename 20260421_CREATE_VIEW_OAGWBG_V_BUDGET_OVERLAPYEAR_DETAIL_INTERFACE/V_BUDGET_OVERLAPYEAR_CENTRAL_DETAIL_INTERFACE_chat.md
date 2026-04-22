# V_BUDGET_OVERLAPYEAR_CENTRAL_DETAIL_INTERFACE

อ้างอิงจาก view จริงในฐานข้อมูล `OAGWBG.OAGWBG_V_BUDGET_OVERLAPYEAR_CENTRAL_DETAIL_INTERFACE` ที่ตรวจสอบเมื่อวันที่ `2026-04-22`

## 1. สรุปการทำงานของ view

view นี้สร้างข้อมูล interface สำหรับรายการเงินกันเหลื่อมปี โดยมี logic หลักดังนี้

- เริ่มจาก CTE `BASE`
  - ใช้ `OAGWBG_BUDGETRESERVED_CATEGORY` เป็นฐานหลัก (`BRSC.*`)
  - join ไปที่ `OAGWBG_BUDGETRESERVED` เพื่อดึงข้อมูลหัวรายการเงินกัน เช่น `DEPARTMENTID`, `COSTCENTERID`, `BUDGETSOURCEID`, `TRANSFERNO`, `TRANSFERDATE`
  - join ไปที่ `OAGWBG_V_EXT_OAGPO_EXPENSE_ACCOUNT_RULE_V` เพื่อดึง `BUDGETTYPEID`, `ACCOUNTNO`, `SUBACCOUNTNO`
  - join ไปที่ `OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V` เพื่อดึงชื่อหมวดรายจ่าย `CATEGORY_NAME`
  - join ไปที่ `OAGWBG_BUDGETRESERVED_BANKACCOUNT` และ `OAGWBG_V_EXT_OAGCE_BANK_ACCOUNT_V` เพื่อดึงบัญชีธนาคารผู้ให้/ผู้รับ
  - join ไปที่ `OAGWBG_SYSTEMCONFIG` เพื่อดึง `LEDGER_ID`
  - filter เฉพาะรายการที่ `BRS.ROUNDINTERFACE IS NOT NULL`
- ใช้ CTE `TYPE_MAP` สร้าง 2 กรณีต่อ 1 รายการ
  - `DOC_TYPE = 'ENC'`, `ACTUAL_FLAG = 'E'`, `DRCR_FLAG = 'C'`
  - `DOC_TYPE = 'BG'`, `ACTUAL_FLAG = 'B'`, `DRCR_FLAG = 'D'`
- ชุดข้อมูลสุดท้ายจึงออกมาเป็น 2 แถวต่อ 1 รายการฐาน
  - แถวฝั่ง Encumbrance
  - แถวฝั่ง Budget

## 2. ตารางและ object ที่เกี่ยวข้อง

### 2.1 Direct dependencies ของ view

ตารางโดยตรงที่อ้างถึงใน SQL

1. `OAGWBG.OAGWBG_BUDGETRESERVED_CATEGORY`
2. `OAGWBG.OAGWBG_BUDGETRESERVED`
3. `OAGWBG.OAGWBG_BUDGETRESERVED_BANKACCOUNT`
4. `OAGWBG.OAGWBG_SYSTEMCONFIG`
5. `OAGWBG.OAGWBG_BUDGETRECEIVE`
6. `OAGWBG.OAGWBG_RECEIVE_BATCH_NO`

view / synonym ที่อ้างถึงโดยตรง

1. `OAGWBG.OAGWBG_V_EXT_OAGPO_EXPENSE_ACCOUNT_RULE_V`
2. `OAGWBG.OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V`
3. `OAGWBG.OAGWBG_V_EXT_OAGCE_BANK_ACCOUNT_V`
4. `PUBLIC.DUAL`

### 2.2 Indirect dependencies ผ่าน lookup views

- จาก `OAGWBG_V_EXT_OAGPO_EXPENSE_ACCOUNT_RULE_V`
  - `OAGWBG.OAGWBG_BUDGETCODE_YEAR`
  - `APPS.OAGPO_EXPENSE_ACCOUNT_RULE_V`
- จาก `OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V`
  - `APPS.OAGINV_CATEGORY_CODES_V`
- จาก `OAGWBG_V_EXT_OAGCE_BANK_ACCOUNT_V`
  - `APPS.OAGCE_BANK_ACCOUNT_V`

ตัว APPS views ด้านบนยังอ้างถึง object กลุ่ม Oracle EBS เพิ่มเติม เช่น `PO_RULE_EXPENSE_ACCOUNTS`, `MTL_CATEGORIES_V`, `FND_FLEX_VALUES_VL`, `FND_ID_FLEX_SEGMENTS_VL`, `FND_ID_FLEX_STRUCTURES_VL` เป็นต้น แต่สำหรับการออกแบบ view ใหม่นี้ ชุด object ในหัวข้อ 2.1 คือชุดที่ต้องสนใจเป็นหลักก่อน

## 3. ผลตรวจสอบ field ใน Excel

ตรวจสอบเทียบระหว่าง Excel `OAGWBG_V_BUDGET_OVERLAPYEAR_DETAIL_INTERFACE.xlsx` กับ column ของ view จริงแล้วได้ผลดังนี้

- จำนวน field ใน view จริง: `43`
- จำนวน field ใน Excel: `43`
- ลำดับ field: ตรงกันทั้งหมด
- field ที่ขาดจาก Excel: ไม่มี
- field ที่เกินจาก view: ไม่มี

สรุปข้อ 1.2: รายการ field ใน Excel ครบและเรียงตรงกับ view `OAGWBG_V_BUDGET_OVERLAPYEAR_CENTRAL_DETAIL_INTERFACE`

## 4. จุดที่ควรแก้ไขหรือระวังใน Excel เดิม

แม้ field จะครบ แต่ตัวอย่างข้อมูลและคำอธิบายบางจุดใน Excel เดิมยังไม่ตรงกับ SQL จริง

1. `WEB_BATCH_NO`
   ค่า fallback ใน SQL คือ `BG_CARRY_FORWARD_<BUDGETYEAR>_<YYMMDDHH24MISS>` หรือ `ENC_CARRY_FORWARD_<BUDGETYEAR>_<YYMMDDHH24MISS>` ไม่ได้ต่อ `TRANSFERNO` เองโดยตรง
2. `REFERENCE4` และ `REFERENCE5`
   SQL จริงต่อข้อความเป็น `เงินกันเหลื่อมปี <BUDGETYEAR>-<DEPARTMENTID> เลขที่เงินกัน <TRANSFERNO>` ไม่ใช่แค่ ปีงบประมาณ + เลขที่เงินกัน
3. `USER_JE_CATEGORY_NAME`
   ไม่ใช่ fixed ค่าเดียว แต่ขึ้นกับ `DOC_TYPE`
4. `DEFAULT_EFFECTIVE_DATE`
   SQL จริงใช้ปีจาก `BRS_BUDGETYEAR - 543`
   - `ENC` = `YYYY-SEP-30`
   - `BG` = `YYYY-OCT-01`
5. `SEGMENT4`
   - `BG` = fixed `'400'`
   - `ENC` = `B.BUDGETSOURCEID`
   จึงไม่ควรอธิบายว่าเป็นค่าเดียวกันทั้งสองฝั่ง
6. `TYPE`
   - `ENC` = `'O'`
   - `BG` = `'I'`
   ใน Excel เดิมตัวอย่างเป็น `I` ทั้งสองฝั่ง ซึ่งไม่ตรงกับ SQL
7. `TRANSFERTYPE`
   SQL จริงเป็น `CARRYFWD` ไม่ใช่ `CARRYPRPO`
8. `ENCUMBRANCE_TYPE`
   มีค่าเฉพาะฝั่ง `ENC` เท่านั้น โดยเป็น `Web Encumbrance`
9. `RECEIPIENT_ACCOUNT` และ `SENDER_ACCOUNT`
   SQL แยกใช้คนละฝั่ง
   - `RECEIPIENT_ACCOUNT` ใช้เฉพาะ `ENC`
   - `SENDER_ACCOUNT` ใช้เฉพาะ `BG`

## 5. ตัวอย่างค่าจากข้อมูลจริงที่ query ได้

ตัวอย่างจาก view จริงเมื่อวันที่ `2026-04-22`

| Field | ฝั่ง ENC | ฝั่ง BG |
| --- | --- | --- |
| `USER_JE_CATEGORY_NAME` | `Web Encumbrance` | `Budget - เงินกัน` |
| `ACTUAL_FLAG` | `E` | `B` |
| `BUDGET_ENCUMBRANCE_NAME` | ว่าง | `OAG_BG_FINAL` |
| `SEGMENT4` | ตัวอย่าง `200` | `400` |
| `ENCUMBRANCE_TYPE` | `Web Encumbrance` | ว่าง |
| `TYPE` | `O` | `I` |
| `TRANSFERTYPE` | `CARRYFWD` | `CARRYFWD` |
| `DEFAULT_EFFECTIVE_DATE` | ตัวอย่าง `2025-SEP-30` | ตัวอย่าง `2025-OCT-01` |

## 6. Field mapping สำหรับใส่ใน Excel

ตารางนี้เป็นสรุป logic ที่ใช้เติมลงคอลัมน์ `Lookup` และ `Condition`

| # | Field | Lookup | Condition |
| --- | --- | --- | --- |
| 1 | `WEB_BATCH_NO` | `RBN.BATCHNAME` จาก `OAGWBG_RECEIVE_BATCH_NO`; ถ้าไม่พบให้ประกอบชื่อจาก `B.BUDGETYEAR + NVL(B.TRANSFERDATE,SYSDATE)` | `LEFT JOIN RBN` ด้วย `BR.ID = RBN.RECEIVEID`, `RBN.ROUNDNO = B.TRANSFERNO`, `RBN.INTERFACETYPE = 'O'` และ prefix ตาม `DOC_TYPE` (`ENC%`/`BG%`) |
| 2 | `USER_JE_SOURCE_NAME` | Fixed = `Web Budget` | ใช้ค่าคงที่ทุกกรณี |
| 3 | `REFERENCE4` | ประกอบข้อความจาก `B.BUDGETYEAR`, `B.DEPARTMENTID`, `B.TRANSFERNO` | `'เงินกันเหลื่อมปี ' || B.BUDGETYEAR || '-' || B.DEPARTMENTID || ' เลขที่เงินกัน ' || B.TRANSFERNO` |
| 4 | `REFERENCE5` | ประกอบข้อความจาก `B.BUDGETYEAR`, `B.DEPARTMENTID`, `B.TRANSFERNO` | ใช้สูตรเดียวกับ `REFERENCE4` |
| 5 | `LEDGER_ID` | `SC.CONFIG_VALUE` จาก `OAGWBG_SYSTEMCONFIG` | `SC.CONFIG_KEY = 'Ledger'` |
| 6 | `USER_JE_CATEGORY_NAME` | กำหนดจาก `TYPE_MAP.DOC_TYPE` | `ENC => Web Encumbrance`, `BG => Budget - เงินกัน` |
| 7 | `TRANSFER_DATE` | `B.TRANSFERDATE` จาก `OAGWBG_BUDGETRESERVED` | `TO_CHAR(B.TRANSFERDATE,'YYYY-MM-DD')` |
| 8 | `DEFAULT_EFFECTIVE_DATE` | คำนวณจาก `B.BRS_BUDGETYEAR` | `ENC => (BRS_BUDGETYEAR - 543) || '-SEP-30'`, `BG => (BRS_BUDGETYEAR - 543) || '-OCT-01'` |
| 9 | `ACTUAL_FLAG` | มาจาก `TYPE_MAP` | `ENC => 'E'`, `BG => 'B'` |
| 10 | `BUDGET_ENCUMBRANCE_NAME` | ค่าคงที่สำหรับฝั่ง Budget | `BG => 'OAG_BG_FINAL'`, `ENC => ''` |
| 11 | `CURRENCY_CODE` | Fixed = `THB` | ใช้ค่าคงที่ทุกกรณี |
| 12 | `ATTRIBUTE3` | Fixed = ค่าว่าง | ใช้ค่าว่างทุกกรณี |
| 13 | `ATTRIBUTE4` | `B.TRANSFERNO` จาก `OAGWBG_BUDGETRESERVED` | ใช้เลขที่เงินกันทุกกรณี |
| 14 | `LINE_NUMBER` | `ROW_NUMBER()` ตามลำดับรายการ | `PARTITION BY B.BUDGETRESERVEDID, T.DOC_TYPE ORDER BY B.CATEGORYID, B.BUDGETPLANID` |
| 15 | `SEGMENT1` | `B.DEPARTMENTID` จาก `OAGWBG_BUDGETRESERVED` | หน่วยเบิกจ่ายของรายการเงินกัน |
| 16 | `SEGMENT2` | `B.COSTCENTERID` จาก `OAGWBG_BUDGETRESERVED` | ศูนย์ต้นทุนของรายการเงินกัน |
| 17 | `SEGMENT3` | `B.BUDGETYEAR` จาก `OAGWBG_BUDGETRESERVED_CATEGORY` | ใช้ `MOD(B.BUDGETYEAR,100)` |
| 18 | `SEGMENT4` | ฝั่ง `BG` ใช้ fixed `400`; ฝั่ง `ENC` ใช้ `B.BUDGETSOURCEID` | `BG => '400'`, `ENC => B.BUDGETSOURCEID` |
| 19 | `SEGMENT5` | `B.BUDGETPLANID` จาก `OAGWBG_BUDGETRESERVED_CATEGORY` | ถ้า `BUDGETPLANID = 90000` ให้ใช้ `0` แล้ว `LPAD` เป็น 5 หลัก; ถ้า null ให้เป็น `00000` |
| 20 | `SEGMENT6` | `B.PRODUCTID` จาก `OAGWBG_BUDGETRESERVED_CATEGORY` | `LPAD(NVL(TO_CHAR(B.PRODUCTID),'0'),5,'0')` |
| 21 | `SEGMENT7` | `B.ACTIVITYID` จาก `OAGWBG_BUDGETRESERVED_CATEGORY` | ใช้ค่ากิจกรรมตรงจากรายการเงินกัน |
| 22 | `SEGMENT8` | `EAR.BUDGETTYPEID` จาก `OAGWBG_V_EXT_OAGPO_EXPENSE_ACCOUNT_RULE_V` | `JOIN BRSC.CATEGORYID = EAR.CATEGORYID` |
| 23 | `SEGMENT9` | `B.BUDGETCODEID` จาก `OAGWBG_BUDGETRESERVED_CATEGORY` | ถ้า null ใช้ `00000000000000000000` |
| 24 | `SEGMENT10` | `EAR.ACCOUNTNO` จาก `OAGWBG_V_EXT_OAGPO_EXPENSE_ACCOUNT_RULE_V` | `JOIN BRSC.CATEGORYID = EAR.CATEGORYID` |
| 25 | `SEGMENT11` | `EAR.SUBACCOUNTNO` จาก `OAGWBG_V_EXT_OAGPO_EXPENSE_ACCOUNT_RULE_V` | `JOIN BRSC.CATEGORYID = EAR.CATEGORYID` |
| 26 | `SEGMENT12` | Fixed = `00` | ใช้ค่าคงที่ทุกกรณี |
| 27 | `SEGMENT13` | Fixed = `000` | ใช้ค่าคงที่ทุกกรณี |
| 28 | `ENTERED_DR` | `B.TOTALRESERVEDAMOUNT` จาก `OAGWBG_BUDGETRESERVED_CATEGORY` | ใช้ยอดเดียวกันทั้ง BG และ ENC |
| 29 | `ACCOUNTED_DR` | `B.TOTALRESERVEDAMOUNT` จาก `OAGWBG_BUDGETRESERVED_CATEGORY` | ใช้ยอดเดียวกับ `ENTERED_DR` |
| 30 | `ENTERED_CR` | Fixed = `NULL` | ใช้ `NULL` ทุกกรณี |
| 31 | `ACCOUNTED_CR` | Fixed = `NULL` | ใช้ `NULL` ทุกกรณี |
| 32 | `REFERENCE1` | ใช้ logic เดียวกับ `WEB_BATCH_NO` | `NVL(RBN.BATCHNAME, ชื่อที่ประกอบจาก BUDGETYEAR + TRANSFERDATE/SYSDATE)` |
| 33 | `CREATED_BY` | `B.CREATEBY` จาก `OAGWBG_BUDGETRESERVED_CATEGORY` | ใช้ค่าผู้สร้างของรายการระดับ category |
| 34 | `LAST_UPDATED_BY` | `B.UPDATEBY` จาก `OAGWBG_BUDGETRESERVED_CATEGORY` | ใช้ค่าผู้แก้ไขล่าสุดของรายการระดับ category |
| 35 | `CREATION_DATE` | `B.CREATEON` จาก `OAGWBG_BUDGETRESERVED_CATEGORY` | ใช้วันเวลาสร้างของรายการระดับ category |
| 36 | `LAST_UPDATE_DATE` | `B.UPDATEON` จาก `OAGWBG_BUDGETRESERVED_CATEGORY` | ใช้วันเวลาแก้ไขล่าสุดของรายการระดับ category |
| 37 | `REFERENCE10` | `CC.NAME` จาก `OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V` | `JOIN CC.ID = BRSC.CATEGORYID` |
| 38 | `ENCUMBRANCE_TYPE` | ค่าคงที่สำหรับฝั่ง Encumbrance | `ENC => 'Web Encumbrance'`, `BG => ''` |
| 39 | `TRANSFERNO` | `B.TRANSFERNO` จาก `OAGWBG_BUDGETRESERVED` | ใช้เลขที่เงินกันทุกกรณี |
| 40 | `RECEIPIENT_ACCOUNT` | `BCC_RECEIVER.CASH_ACC` ผ่าน `OAGWBG_BUDGETRESERVED_BANKACCOUNT` และ `OAGWBG_V_EXT_OAGCE_BANK_ACCOUNT_V` | ใช้เฉพาะฝั่ง `ENC`; `JOIN BCC_RECEIVER.BANK_ACCOUNT_ID = BRB.BANKACCOUNTRECEIVER` |
| 41 | `SENDER_ACCOUNT` | `BCC_GIVER.CASH_ACC` ผ่าน `OAGWBG_BUDGETRESERVED_BANKACCOUNT` และ `OAGWBG_V_EXT_OAGCE_BANK_ACCOUNT_V` | ใช้เฉพาะฝั่ง `BG`; `JOIN BCC_GIVER.BANK_ACCOUNT_ID = BRB.BANKACCOUNTGIVER` |
| 42 | `TYPE` | กำหนดจาก `TYPE_MAP.DOC_TYPE` | `ENC => 'O'`, `BG => 'I'` |
| 43 | `TRANSFERTYPE` | Fixed = `CARRYFWD` | ใช้ค่าคงที่ทุกกรณี |

## 7. สิ่งที่อัปเดตแล้ว

- เติมคอลัมน์ `Lookup` และ `Condition` ในไฟล์ `OAGWBG_V_BUDGET_OVERLAPYEAR_DETAIL_INTERFACE.xlsx` แล้ว
- สร้างไฟล์สรุปฉบับนี้ไว้สำหรับอ้างอิงก่อนสร้าง view ใหม่ `OAGWBG_V_BUDGET_OVERLAPYEAR_DETAIL_INTERFACE`
