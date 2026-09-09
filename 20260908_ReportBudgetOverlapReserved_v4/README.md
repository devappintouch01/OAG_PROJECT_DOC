# OAGWBG_R_BUDGETOVERLAP_RESERVED v4 — รายงานรายละเอียดเงินกัน (ReportTypeID = 4)

วันที่: 2026-09-08
DB: PREPROD `172.16.11.19:1541 / ebs_PRE / OAGWBG`
ต่อจาก [20260831_ReportBudgetOverlapReserved_v3](../20260831_ReportBudgetOverlapReserved_v3/README.md)

## ข้อร้องเรียนรอบนี้ (ข้อ 1 และ 5 ที่ยังค้าง)

> 1. ตัวเลือกปีงบประมาณ และเลขที่เงินกันมีไม่ครบ ตามรายการหน้าโอนงปม. เข้าบัญชีเงินกัน
> 5. หน้าจอ รายการโอนจัดสรร สรุปรายการเงินกัน และรายงาน ออกไม่สัมพันธ์กัน

## สถานะที่ตรวจพบจริงบน PREPROD (2026-09-08)

view v3 deploy แล้ว (37 คอลัมน์ มี `ROWKIND`) — ยืนยันจาก `ALL_TAB_COLUMNS` และ `ALL_VIEWS.TEXT_VC`

### ข้อ 1 — ตัวเลือกไม่ตรงกัน เพราะ "ปีงบประมาณ" ใช้คนละกติกา 2 แบบ

| ที่มา | กติกาปีงบประมาณ (ก่อนแก้) | โค้ด |
|---|---|---|
| รายงาน (reportType 1-4) | `BUDGETYEAR` ของหัวใบ | `MasterService.GetReportOverlapDomain` + `FilterReportDomain` |
| หน้า "โอนงปม. เข้าบัญชีเงินกัน" — **ตาราง** | `BUDGETYEAR` ของหัวใบ | `BudgetService.GetBudgetReservedList` |
| หน้า "โอนงปม. เข้าบัญชีเงินกัน" — **dropdown เลขที่เงินกัน** | **2 หลักแรกของเลขที่เงินกัน** | `MasterService.GetTransferNoFromReserved` (path เมื่อ `reportType` เป็น null) |

`OAGWBG_BUDGETRESERVED.BUDGETYEAR` ถูกเขียนทับเป็น "ปีที่เดินรอบล่าสุด" ทุกครั้งที่ `ROUNDINTERFACE` เพิ่ม
สองกติกาจึงชี้คนละปี เช่น `68030001` → prefix = 2568 แต่ `BUDGETYEAR` = 2570 (`ROUNDINTERFACE` = 3)

ข้อมูลจริง ณ วันตรวจ: หัวใบกันเงินทั้งระบบ 39 ใบ (region C 12 / region P 27) ขึ้นต้นด้วยตัวเลข 2 หลักครบทุกใบ
แต่มีเพียง **3/39 ใบ** ที่ `BUDGETYEAR` ตรงกับ prefix

ก่อนแก้ (region C 12 ใบ):

| ปีที่เลือก | รายงาน | ตารางหน้าโอนฯ | dropdown หน้าโอนฯ |
|---|---|---|---|
| 2568 | 1 ใบ | 1 ใบ | **9 ใบ** |
| 2569 | 8 ใบ | 8 ใบ | **3 ใบ** |
| 2570 | 3 ใบ | 3 ใบ | **0 ใบ** |

**ผู้ใช้ตัดสินใจ (2026-09-08): ยึด prefix ของเลขที่เงินกันเป็นหลัก**

หลังแก้ ทั้ง 3 ที่ให้ผลตรงกัน:

| ปี | เลขที่เงินกัน |
|---|---|
| 2568 | 68030001-68030008, 681203 (9 ใบ) |
| 2569 | 69030001-69030003 (3 ใบ) |

### ข้อ 5 — เหตุ 3 ข้อ

| # | เหตุ | หลักฐาน | สถานะ |
|---|---|---|---|
| 5.1 | view นับใบโอนจัดสรร **สถานะร่าง (80101)** ด้วย แต่แท็บ "รายการโอนจัดสรร" ตัดออก | ตารางส่วนต่างด้านล่าง | **แก้ใน v4** |
| 5.2 | ใบกันเงิน 11/12 ใบ **ยังไม่บันทึกรายการขยาย/ส่งคืน** ลง `OAGWBG_BUDGETRESERVEDITEM` — หน้าจอแสดงข้อมูลสด PR/PO จาก EBS แต่รายงานอ่านจากตารางที่ยังว่าง | มีเฉพาะ `68030001` ที่มี item (8 แถว) | ยังไม่แก้ (เชิงออกแบบ) |
| 5.3 | ยอด `EXPAND_LUMP` / `CANCEL_LUMP` ไม่ขึ้นในรายงาน | `68030001` มี EXPAND_LUMP 980,000 / CANCEL_LUMP 80,000 | **ผู้ใช้ยืนยันว่าไม่ต้องขึ้น — คงพฤติกรรมเดิม** |

ส่วนต่างของ 5.1 (ยอด "จำนวนเงินจัดสรร" ต่อใบกันเงิน):

| เลขที่เงินกัน | หน้าจอ รายการโอนจัดสรร | รายงาน v3 | รายงาน v4 |
|---|---|---|---|
| 68030001 | 930,950 (16 แถว) | 930,950 (16) | 930,950 (16) |
| 68030004 | 0 (0 แถว) | **100 (1)** | 0 (0) |
| 68030008 | 1,000 (1 แถว) | 1,000 (1) | 1,000 (1) |
| 681203 | 20 (1 แถว) | **7,020 (2)** | 20 (1) |
| 69030001 | 0 (0 แถว) | **100.99 (2)** | 0 (0) |
| 69030002 | 0 (0 แถว) | **20 (1)** | 0 (0) |

## สิ่งที่เปลี่ยนใน v4

### 1. CTE `HEAD` — ปีงบประมาณจาก prefix ของเลขที่เงินกัน (แก้ข้อ 1)

```sql
CASE WHEN REGEXP_LIKE(BRS.TRANSFERNO, '^[0-9]{2}')
     THEN TO_NUMBER(SUBSTR(BRS.TRANSFERNO, 1, 2)) + 2500
     ELSE BRS.BUDGETYEAR
END AS BUDGETYEAR
```

### 2. CTE `ALLOC` — ตัดใบร่างออก (แก้ข้อ 5.1)

```sql
WHERE  P.TRANSFERNO IS NOT NULL
AND    C.TRANSFERSTATUS <> '80101'
```

ให้ตรงกับ `BudgetService.GetBudgetReservedById` ที่กรอง `x.Transferstatus != "80101"` ตอนสร้าง
`AllocateTransferList` (แท็บ "รายการโอนจัดสรร") — ใบร่างยังไม่ตัดถังเงินจริง

โครงสร้างคอลัมน์ **ไม่เปลี่ยน** (37 คอลัมน์เท่าเดิม) → ไม่ต้องแก้ model / DbContext

## โค้ดที่แก้ตาม (TFS — ยังไม่ checkin)

`OAGBudget.API/Services/Repository/BudgetService.cs` → `GetBudgetReservedList`
(ใช้เฉพาะหน้า "โอนงปม. เข้าบัญชีเงินกัน" — region P ใช้ `GetVBudgetOverlapYearList` คนละเมธอด)

- เพิ่ม helper `BudgetYearFromTransferNo(transferNo)` → `2500 + SUBSTR(transferNo,1,2)`
- ฟิลเตอร์ปีงบประมาณ: `x.Budgetyear == data.BudgetYear` → `x.Transferno.StartsWith(yearPrefix)`
- เรียงลำดับที่ระดับ DB: `OrderByDescending(Budgetyear).ThenByDescending(Transferno)` →
  `OrderByDescending(Transferno)` อย่างเดียว (ให้ผลเท่ากัน เพราะปีคือ 2 หลักแรกของเลขที่เงินกัน)
- ทับค่า `Budgetyear` ของแถวที่คืนกลับด้วยปีจาก prefix → ตารางและ dropdown ปีงบประมาณบนหน้าจอตรงกับตัวกรอง

build ผ่าน 0 Error (build ลง output แยก เพราะ VS กำลัง debug อยู่ ไฟล์ bin ถูกล็อก)

## ผลทดสอบ (รัน SELECT body บน PREPROD ก่อน deploy — **ยังไม่ deploy**)

- ใบกันเงินยังครบ 12 ใบ (LEFT JOIN คงแถวว่างไว้) → dropdown ไม่ตกหล่น
- ปี 2568 = 9 ใบ / ปี 2569 = 3 ใบ (2570 หายไปตามที่ควร เพราะยังไม่มีเลขที่เงินกันขึ้นต้น 70)
- ยอด "จำนวนเงินจัดสรร" ตรงกับหน้าจอทุกใบตามตารางด้านบน
- เวลา 15.7 วิ (v3 = 15.7 วิ)

## Deploy

```
create_view_budgetoverlap_reserved_v4.sql
```

หลัง deploy dropdown ของรายงานจะอัปเดตภายใน 10 นาที (TTL ของ `MasterService.ReportDropdownCacheTtl`)
หรือทันทีถ้า restart API

## Rollback

```
rollback_view_budgetoverlap_reserved_v3.sql
```
(คือ v3 เดิมทั้งไฟล์ — คอลัมน์เหมือนกัน ถ้า rollback view ต้อง revert `GetBudgetReservedList` ด้วย
ไม่งั้นตารางหน้าโอนฯ กับรายงานจะกลับไปใช้คนละกติกาปีอีก)

## เรื่องที่ยังไม่แตะ (คนละหน้าจอ / คนละรายงาน)

- **รายงาน type 1, 2, 3** ยังใช้ `BUDGETYEAR` ของหัวใบ เพราะอ่านจาก view คนละตัว
  (`OAGWBG_R_BUDGETOVERLAP_CATEGORIES` / `_EXPANDS` / `OAGWBG_R_BUDGETOVERLAP`)
  ถ้าจะให้ยึด prefix ทั้งระบบต้องแก้ view เหล่านี้ด้วย
- **`MasterService.GetReservedRoundNo`** (dropdown เลขที่รอบ) ยังกรองด้วย `x.Budgetyear` ของหัวใบ — ปัญหาชนิดเดียวกัน
- **ข้อ 5.2** — ต้องออกแบบว่ารายงานควรอ่านข้อมูลสดจาก EBS เหมือนหน้าจอ หรือให้ผู้ใช้กดบันทึกก่อนจึงจะมีข้อมูลในรายงาน
