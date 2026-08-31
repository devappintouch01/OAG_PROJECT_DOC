# OAGWBG_R_BUDGETOVERLAP_RESERVED v3 — รายงานรายละเอียดเงินกัน (ReportTypeID = 4)

วันที่: 2026-08-31
DB: PREPROD `172.16.11.19:1541 / ebs_PRE / OAGWBG`

## ปัญหาที่แก้ (จากผู้ใช้ 5 ข้อ)

| # | อาการ | สาเหตุใน view v2 |
|---|---|---|
| 1 | ตัวเลือกปีงบประมาณ/เลขที่เงินกันไม่ครบ | view ไล่จาก item + `WHERE BUDGETRESERVEDTYPE IN (EXPAND/CANCEL)` และ join condition `PO/PR_TRANSFER_NO IS NOT NULL` → ใบที่ยังไม่มี PR/PO หายทั้งใบ (เหลือ 1 ใบ 1 ปี จากของจริง 12 ใบ 3 ปี) และ `BUDGETYEAR` ใช้ของ item ไม่ใช่ของหัวใบ |
| 2 | ใบโอนออกไม่ครบ (68030001 ขึ้นเลขเดียว) | `ALLOCATE_TRANSFERNO` มาจาก `OAGPO_TRANSACTION_STATUS_V` = "เลขโอนที่ PR/PO ไปตัดงบ" ไม่ใช่รายการใบโอนเข้าบัญชีเงินกัน |
| 3 | ยอดจำนวนเงินจัดสรรผิด | โชว์ `CAT.TOTALRESERVEDAMOUNT` (ยอดทั้งใบ 1,000,000) แทนยอดของแต่ละใบโอน (20,000) |
| 4 | รายการเบิ้ล/แยกบรรทัด | ไม่ยุบ `OVERLAPROUND` และไม่ยุบเอกสารใบเดียวกัน |
| 5 | หน้าจอ 3 ที่ไม่สัมพันธ์กัน | ผลรวมของ 1-4 |

## สิ่งที่เปลี่ยนใน v3

view รวม **2 ระดับ** ไว้ด้วยกัน แยกด้วยคอลัมน์ใหม่ `ROWKIND` :

- `ROWKIND = 'A'` — บรรทัดใบโอนจัดสรรเข้าบัญชีเงินกัน
  `HEAD LEFT JOIN ALLOC` (หมวดใบกันเงิน → หมวดลูก → `OAGWBG_V_BUDGETRECEIVE`)
  เส้นทางเดียวกับแท็บ "รายการโอนจัดสรร" ใน `BudgetOverlapYearCentralDetail`
  **LEFT JOIN** เพื่อให้ใบกันเงินที่ยังไม่มีการโอนเข้ายังมี 1 แถว (แก้ข้อ 1)
  → `ALLOCATE_TRANSFERNO` = `TO_CHAR(RCV.ROUNDNO)`, `ALLOCATEAMOUNT` = `RCV.TOTALRECEIVEAMOUNT` (แก้ข้อ 2, 3)

- `ROWKIND = 'I'` — บรรทัดรายการขยายเวลา/ส่งคืน (คง filter ตัด `EXPAND_LUMP` / `CANCEL_LUMP` ไว้เหมือนเดิม)
  → คงคอลัมน์ `ACCOUNTCODE` / `OVERLAPROUND` / `RESERVEDNO_ADD` / `ITEMRESERVEDTYPE` / `USAGEAMOUNT`
  ให้ฝั่ง C# ยุบรอบและยุบเอกสารได้ (แก้ข้อ 4)

อื่น ๆ:

- `BUDGETYEAR` เปลี่ยนเป็นปีของ **หัวใบ** (`OAGWBG_V_BUDGETRESERVED.BUDGETYEAR`) ให้ตรงกับหน้าโอนงบประมาณเข้าบัญชีเงินกัน
- `CATEGORYNAME` เปลี่ยนเป็น `LISTAGG` ของหมวดในใบกันเงิน (เดิม join รายแถวทำให้ข้อมูลซ้ำ)
- ตัด pivot `APPROVE_EXPAND_*` / `PROCESS_*` ออก — ย้ายไปทำใน C# ตอน merge เอกสาร
- จำกัด `BUDGETRESERVEDREGION = 'C'` ที่ตัว view (รายงานนี้ใช้กับบัญชีเงินกันส่วนกลางเท่านั้น)

## โค้ดที่แก้ตาม (TFS)

- `OAGBudget.DAL/Models/OagwbgRBudgetoverlapReserved.cs` — model ตามคอลัมน์ใหม่
- `OAGBudget.DAL/OAGDBContext.cs` — column mapping
- `OAGBudget.API/Services/Repository/ReportService.cs` — `ReportBudgetOverlap` case `"4"` +
  helper `KeepLatestRoundItems` / `MergeReservedDetailRows` / `WriteReservedDetailRow`
- `OAGBudget.API/Services/Repository/MasterService.cs` — `GetReportOverlapDomain` case `"4"`

## Deploy

```
create_view_budgetoverlap_reserved_v3.sql
```

## Rollback

```
rollback_view_budgetoverlap_reserved_v2.sql
```
(DDL ที่ dump จาก PREPROD ก่อนแก้ — ถ้า rollback view ต้อง rollback โค้ดฝั่ง C# ด้วย เพราะคอลัมน์ไม่เหมือนกัน)

## ผลทดสอบ (SELECT body ก่อน deploy)

- 35 แถว รวมทั้ง 12 ใบกันเงิน / 3 ปีงบ (2568, 2569, 2570)
- 68030001 → `A` 16 แถว (12 เลขที่โอน) + `I` 7 แถว
- เวลา 15.7 วิ (v2 เดิม ~14 วิ)
