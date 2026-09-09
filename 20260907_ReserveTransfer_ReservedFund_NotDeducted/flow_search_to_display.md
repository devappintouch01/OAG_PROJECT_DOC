# ลำดับการทำงาน: กดปุ่ม "ค้นหา" → ตารางที่ 1 มีข้อมูลแสดง

หน้า **โอนปรับเงินเหลือจ่าย** (`BudgetReserveTransferDetail.cshtml`)
ตรวจสอบกับ PREPROD เมื่อ 2026-09-08 (DDL ของ view + ข้อมูลจริง)

> **ใจความ:** 4 คอลัมน์ยอด (จัดสรร / กันไว้เบิก / เบิกจ่าย / คงเหลือ) **ไม่ได้มาจากถังเว็บ**
> แต่มาจาก EBS GL ต่อ "ชุดบัญชี 13 segment" ที่ประกอบขึ้นใหม่ทุกครั้งที่กดค้นหา
> ถ้าประกอบชุดบัญชีแล้วหาไม่เจอ → โค้ดข้ามแถวนั้น → หน้าจอโชว์ 0.00

---

## แผนภาพ

```mermaid
flowchart TD
    A["<b>1 · เบราว์เซอร์</b> — กดปุ่มค้นหา<br/><code>loadRowsFromSearch()</code> :2158<br/>ส่ง หน่วยเบิกจ่าย / ศูนย์ต้นทุน / ปีงบ / แหล่งเงิน"]
    B["<b>2 · Web MVC</b><br/><code>BudgetController.SearchBudgetTransferDetail</code> :2723<br/>→ HTTP GET ไป API พร้อม Bearer token"]
    C["<b>3 · API</b> — อ่านแถวงบประมาณ<br/><code>BudgetService.SearchBudgetTransferDetail</code> :18006<br/>SELECT จาก <code>OAGWBG_V_BUDGETRECEIVESUMMARY_REFUND</code>"]
    C1["<b>view นี้ประกอบจาก</b><br/><code>OAGWBG_V_BUDGETRECEIVE</code> (ตัด type T/R)<br/>+ รหัสงบ 4 ทาง: <code>BUDGETALLOCATETRANSFER_CATEGORY</code> (A/G),<br/><code>BUDGETCODE_YEAR</code> / <code>BUDGETCODEMORE_YEAR</code> (ผ่าน <code>BUDGETRECEIVEPERIOD</code>)<br/>+ ใบเงินกัน: <code>BUDGETRESERVED_CATEGORY</code> → <code>BUDGETRESERVED</code>"]
    D["<b>4 · API</b> — map เป็น DTO :18124<br/><code>Budgetcodeid ?? '00000000000000000000'</code>"]
    E["<b>5 · Oracle APPS</b> — งวดบัญชี + ledger<br/><code>APPS.OAGGL_CALENDAR_V</code> :18313<br/><code>APPS.GL_LEDGERS</code> :18345"]
    F["<b>6 · API</b> — ประกอบชุดบัญชี 13 segment :18357<br/>rule จาก <code>OAGWBG_V_EXT_OAGPO_EXPENSE_ACCOUNT_RULE_V</code><br/>SEG3=ปี · SEG4=แหล่งเงิน · <b>SEG9=รหัสงบ</b>"]
    G["<b>7 · Oracle APPS</b> — หาเลขบัญชี<br/><code>APPS.OAGGL_ACCOUNT_HIERARCHIES_V</code> :18394<br/>ไม่เจอ → <code>APPS.GL_CODE_COMBINATIONS_KFV</code> :18405"]
    H["<b>8 · Oracle APPS</b> — ดึงยอดจาก GL :18470-18532<br/>DELETE + INSERT <code>APPS.OAG_GL_FUNDS_AVAILABLE_PKG_BYPASS</code><br/>แล้ว SELECT กลับ P_BUDGET / P_ENCUMBRANCE / P_ACTUAL / P_FUNDS_AVAILABLE"]
    I["<b>9 · เบราว์เซอร์</b> — <code>renderRows()</code> :1874<br/>จัดสรร=budget · กันไว้เบิก=encumbrance<br/>เบิกจ่าย=actual · <b>คงเหลือ=fundsAvailable</b> :1901"]

    X1["⚠ จุดพัง 1 — แถวเงินกัน (type O)<br/>view คืน BUDGETCODEID = NULL<br/>จึงกลายเป็นเลขศูนย์ 20 หลัก"]
    X2["⚠ จุดพัง 2 — หาบัญชีไม่เจอ<br/><code>if (codeCombinationId == 0) continue;</code> :18422<br/>ยอดทั้ง 4 ช่องค้างเป็น null → จอโชว์ 0.00"]

    A --> B --> C
    C -.- C1
    C -->|"แถวสรุปงบ (1 แถว = 1 ใบเงินกัน)"| D
    D --> E --> F
    D -.-> X1
    F -->|"account_code 13 segment"| G
    G -->|"CODE_COMBINATION_ID"| H
    G -.->|"CCID = 0"| X2
    H -->|"4 ตัวเลขจาก GL"| I
    X2 -.-> I

    classDef warn stroke-dasharray: 4 3;
    class X1,X2 warn;
```

---

## ตารางที่เกี่ยวข้อง (เรียงตามลำดับที่ถูกอ่าน)

| # | ตาราง / view | ฝั่ง | บทบาทในขั้นตอนนี้ |
|---|---|---|---|
| 1 | `OAGWBG_V_BUDGETRECEIVESUMMARY_REFUND` | OAGWBG | แหล่งแถวหลักของตารางที่ 1 — group ระดับ **ใบเงินกัน** |
| 2 | `OAGWBG_V_BUDGETRECEIVE` → `OAGWBG_BUDGETRECEIVE` | OAGWBG | ถังงบจริง (ตัด type `T`/`R` ออก) — `TOTALBALANCEAMOUNT` **ไม่ได้ถูกแสดงบนจอ** |
| 3 | `OAGWBG_BUDGETALLOCATETRANSFER_CATEGORY` | OAGWBG | รหัสงบของแถว type `A` / `G` |
| 4 | `OAGWBG_BUDGETRECEIVEPERIOD` + `OAGWBG_BUDGETCODE_YEAR` / `OAGWBG_BUDGETCODEMORE_YEAR` | OAGWBG | รหัสงบของแถวอื่น — **แถว type `O` (เงินกัน) เข้าไม่ถึงทั้ง 2 ทาง** |
| 5 | `OAGWBG_BUDGETRESERVED_CATEGORY` → `OAGWBG_BUDGETRESERVED` | OAGWBG | เลขที่ใบเงินกัน + ปีของใบ (มี `BUDGETCODEID` ที่ถูกต้องอยู่ แต่ view ไม่ได้หยิบมาใช้) |
| 6 | `OAGWBG_V_EXT_OAGPO_EXPENSE_ACCOUNT_RULE_V` | OAGWBG | rule ของ SEGMENT 5/8/10/11 (แผนงาน/ประเภทงบ/บัญชี/บัญชีย่อย) |
| 7 | `APPS.OAGGL_CALENDAR_V` | EBS | งวดบัญชีล่าสุดของปีที่ค้น (ตัด ADJ1–ADJ4) |
| 8 | `APPS.GL_LEDGERS` | EBS | LEDGER_ID |
| 9 | `APPS.OAGGL_ACCOUNT_HIERARCHIES_V` / `APPS.GL_CODE_COMBINATIONS_KFV` | EBS | แปลงชุดบัญชี 13 segment → `CODE_COMBINATION_ID` |
| 10 | `APPS.OAG_GL_FUNDS_AVAILABLE_PKG_BYPASS` | EBS | เขียนแล้วอ่านกลับ — ที่มาของยอดทั้ง 4 คอลัมน์ |

---

## ผลจริงกับแหล่งเงิน 400 (จำลองขั้นที่ 6-7 กับข้อมูล PREPROD)

| ผลการหาเลขบัญชี | จำนวนแถว | หน้าจอแสดง |
|---|---|---|
| เจอ `CODE_COMBINATION_ID` | **8** | ตัวเลขจริงจาก GL |
| ไม่เจอ → `continue` | **20** | 0.00 ทั้ง 4 ช่อง |

ชุดบัญชีของแถวเงินกันที่หาไม่เจอ (SEG9 เป็นศูนย์):

```
2900600000.2906999999.68.400.20000.21000.21100.212001.00000000000000000000.5104010107.230003.00.000
                                                      ^^^^^^^^^^^^^^^^^^^^ ← ควรเป็น 29006630001004100280
```

บัญชี `...68.400.*` ที่มีอยู่จริงใน GL มี 7 บัญชี — **ไม่มีสักบัญชีที่ SEGMENT9 เป็นเลขศูนย์**

---

## สิ่งที่แผนภาพนี้อธิบายได้

- **ทำรายการบนเว็บแล้วยอด 4 ช่องไม่ขยับ** — ถูกต้องตามกลไก เพราะ 4 ช่องอ่านจาก GL ไม่ได้อ่านถังเว็บ
  และหน้านี้ไม่ได้ส่ง journal เข้า GL เอง (ดู §5 ของ `analysis_root_cause.md`)
- **แถวเงินกันโชว์ 0.00** — ตกที่จุดพัง 1 → 2 (รหัสงบเป็นศูนย์ → หาบัญชีไม่เจอ → ข้ามแถว)
- **แถวที่ยังมียอดแสดง** — คือแถวที่รหัสงบมาจากทาง `A`/`G` ซึ่งประกอบชุดบัญชีได้สำเร็จ
