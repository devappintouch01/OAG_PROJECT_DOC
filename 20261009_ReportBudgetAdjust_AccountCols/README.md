# รายงานการเปลี่ยนแปลงงบประมาณประจำปี — v6 (2026-10-09)

## โจทย์

เพิ่ม 4 คอลัมน์ต่อจาก "ประเภทรายจ่าย"

1. รหัสงบประมาณ
2. รหัสบัญชีหลัก
3. ชื่อบัญชีหลัก
4. รหัสรายจ่ายย่อย

ลำดับคอลัมน์ใหม่บนรายงาน

```
... กิจกรรม | ประเภทรายจ่าย | รหัสงบประมาณ | รหัสบัญชีหลัก | ชื่อบัญชีหลัก | รหัสรายจ่ายย่อย | รายการงบประมาณ | จำนวนเงินรับโอน | จำนวนเงินโอนออก
```

---

## แหล่งข้อมูล (view `OAGWBG_R_BUDGETADJUST` v6)

| คอลัมน์ view | ประเภท 1/2/3/5 | ประเภท 4 เบิกแทนกัน |
|---|---|---|
| `BUDGETCODE` | `BUDGETADJUST.BUDGETCODE` (1 โอนออก) / `V_BUDGETRECEIVE.BUDGETCODEID` (รับโอน, 3 โอนออก) / `BUDGETRECEIVEREFUND.BUDGETCODEID` (2/5 โอนออก) | `ACCOUNT_SEGMENT.BUDGETCODENAME` |
| `CATEGORYID` | ตัวเดียวกับที่แต่ละ branch ใช้ join `CAT` อยู่แล้ว | NULL (`'0000'` ไม่มีใน master) |
| `ACCOUNTNO` | `EXPENSE_ACCOUNT_RULE_V.ACCOUNTNO` join ด้วย `CATEGORYID` | `ACCOUNT_SEGMENT.ACCOUNT` |
| `SUBACCOUNTNO` | `EXPENSE_ACCOUNT_RULE_V.SUBACCOUNTNO` join ด้วย `CATEGORYID` | `ACCOUNT_SEGMENT.SUBACCOUNT` |
| `ACCOUNTNAME` | `OAGWBG_V_EXT_OAGGL_ACCOUNT_V.NAME` ด้วย `ACCOUNTNO` | เหมือนกัน |

### join rule ด้วย CATEGORYID โดยไม่ทำแถวบาน

`OAGWBG_V_EXT_OAGPO_EXPENSE_ACCOUNT_RULE_V` มี 1,443 แถว / 738 category (แยกตามปี 69–72
ผลผลิต กิจกรรม) join ตรง ๆ แถวรายงานจะบานและยอดเงินถูกบวกซ้ำ

จึงยุบ rule เหลือ 1 แถวต่อ `CATEGORYID` ก่อน join (subquery `RL`) — ตรวจ PREPROD
2026-10-09 **ไม่มี category ไหนมีคู่ บัญชีหลัก+รายจ่ายย่อย เกิน 1 คู่** การยุบจึงไม่ทิ้งข้อมูล
และให้ค่าเดียวกับ `BudgetService.FindRule` ที่ใช้ตอนส่ง journal เข้า GL
(`KEEP DENSE_RANK FIRST` บังคับให้บัญชีหลักกับรายจ่ายย่อยมาจากแถวเดียวกัน)

join ครั้งเดียวที่ชั้นนอกของ `UNION ALL` ไม่ได้ใส่ซ้ำ 10 branch

> ถ้าวันหนึ่ง verify ข้อ 3 ไม่เป็น 0 (category เดียวมีบัญชีต่างกันตามปี) ต้องเปลี่ยนไป
> match ด้วย ปี/ผลผลิต/กิจกรรม ก่อน แบบ `FindRule`

---

## ผล probe บน PREPROD 2026-10-09 (รัน SELECT ของ v6 ตรง ๆ ยังไม่ deploy)

- DDL สดของ v5 ตรงกับไฟล์ `20260909_.../OAGWBG_R_BUDGETADJUST_deploy.sql` (เทียบหลังตัด whitespace/comment/alias)
- จำนวนแถวรวม **536 เท่าเดิม**
- กรองแบบรายงาน (`ROUNDNO LIKE '69%' AND TRANSFERTYPE='1'`) ได้ 68 แถวเท่ากันทั้ง v5/v6
  เวลา ~43 วิ (v5) / ~49 วิ (v6) — view ช้าอยู่แล้วตั้งแต่ v5

| TRANSFERTYPE | ROLETYPE | CNT | รหัสงบ | บัญชีหลัก | ชื่อบัญชี | รายจ่ายย่อย |
|---|---|---|---|---|---|---|
| 1 | RECEIVER | 38 | 38 | 38 | 38 | 38 |
| 1 | SENDER | 32 | 32 | 32 | 32 | 32 |
| 2 | RECEIVER | 143 | 143 | 143 | 143 | 143 |
| 2 | SENDER | 148 | 148 | 148 | 148 | 148 |
| 3 | RECEIVER | 27 | 27 | 27 | 27 | 27 |
| 3 | SENDER | 29 | 29 | 29 | 29 | 29 |
| 4 | RECEIVER | 13 | 11 | 11 | 11 | 11 |
| 4 | SENDER | 4 | 3 | 3 | 3 | 3 |
| 5 | RECEIVER | 51 | 51 | 51 | 51 | 51 |
| 5 | SENDER | 51 | 51 | 51 | 51 | 51 |

ที่ว่าง 3 แถวคือใบเบิกแทน 6900012 / 6900013 / 6900014 ที่ไม่มี `ACCOUNT_SEGMENT` เลย
(ข้อมูลค้างเดิม บันทึกไว้ตั้งแต่ v5)

ตัวอย่าง

```
6912556 | 29006630001004100280 | 1206010102 | พักครุภัณฑ์สํานักงาน         | 920001
6912564 | 29006140002004100026 | 5101010101 | เงินเดือน                    | 110001
6900016 | 29006140002004100027 | 5101020108 | ค่าเช่าบ้าน                  | 120001
```

---

## ลำดับการ deploy

v6 **เพิ่มคอลัมน์** — ต้อง deploy view ก่อนโค้ด

```
1. รัน OAGWBG_R_BUDGETADJUST_deploy.sql
2. รัน verify.sql
3. deploy โค้ด
```

- โค้ดเดิมอ่าน view v6 ได้ปกติ (EF select เฉพาะคอลัมน์ที่ map)
- โค้ดใหม่บน view v5 → ORA-00904

Rollback: รัน `OAGWBG_R_BUDGETADJUST_rollback.sql` (คืนเป็น v5) — ต้อง rollback โค้ดก่อน

---

## ฝั่งโค้ด

| ไฟล์ | แก้อะไร |
|---|---|
| `OAGBudget.DAL/Models/OagwbgRBudgetadjust.cs` | เพิ่ม `Budgetcode`, `Categoryid`, `Accountno`, `Accountname`, `Subaccountno` |
| `OAGBudget.DAL/Models/OAGDBContextBase.cs` | map 5 คอลัมน์ใหม่ |
| `OAGBudget.API/Services/Repository/ReportService.cs` | `ReportBudgetAdjust` เพิ่ม 4 หัวคอลัมน์ + 4 ช่องต่อจากประเภทรายจ่าย (ลงเป็น string ไม่ให้ Excel แปลงรหัส 20 หลักเป็น 2.9E+19) |

ไม่ได้แตะลำดับการเรียง (`SortSheetRows`) — คีย์ที่ผู้ใช้กำหนดไว้ไม่มีคอลัมน์ใหม่
