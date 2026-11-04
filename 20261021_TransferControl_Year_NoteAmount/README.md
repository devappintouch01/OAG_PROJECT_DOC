# รายงานทะเบียนคุมการโอน — กรองตามปีของเลขที่โอน + ยอดเงินซ้ำเมื่อมีหมายเหตุหลายข้อ (2026-10-21)

## ปัญหาที่ผู้ใช้แจ้ง

1. รายงานต้องกรองตามปีงบประมาณ โดยเลขที่โอนต้องตรงกับปีงบประมาณ
2. จำนวนเงินไม่ถูกต้องเมื่อรายการมีหมายเหตุมากกว่า 1 ข้อ — ตัวอย่างเลขที่โอน 6911272

## สาเหตุ

### 1. ปีงบประมาณ
`ReportService.ReportBudgetTransferControl` กรองด้วย `BUDGETYEAR` ของ view `OAGWBG_R_BUDGETTRANSFERCONTROL`
ซึ่งมาจาก `OAGWBG_V_BUDGETRECEIVE.BUDGETYEAR` (= ปีของตัวเงิน) ไม่ใช่ปีของเลขที่โอน

PREPROD 2026-10-21 มี 58 แถวที่ปีไม่ตรงกับเลขที่โอน:

| BUDGETYEAR | ปีในเลขที่โอน | ประเภท | แถว |
|---|---|---|---|
| 2568 | 2569 | โอนกลับ / บันทึกรับเงินจากกรมบัญชีกลาง | 31 |
| 2569 | 2568 | โอนปรับเงินเหลือจ่าย | 19 |
| 2569 | 2570 | โอนกลับ | 3 |
| 2570 | 2568, 2569 | โอนปรับเงินเหลือจ่าย | 5 |

ส่วน dropdown "โอนครั้งที่" (`MasterService.GetRoundNo`) ใช้ BUDGETYEAR ของ header
(`OAGWBG_BUDGETTRANSFER`, `OAGWBG_V_BUDGETALLOCATETRANSFER`) ซึ่งตรงกับเลขที่โอน 100% (เช็คแล้ว 0 แถวไม่ตรง)
ทำให้ dropdown กับรายงานขัดกัน เช่น เลือก 2568 + 6810028 แล้วรายงานว่าง

### 2. ยอดเงินซ้ำ
view `LEFT JOIN OAGWBG_BUDGETALLOCATETRANSFER_COSTCENTER_NOTE BACN ON BACN.RECEIVEID = RC.ID`
→ รายการรับเงินที่มีหมายเหตุ N ข้อ แตกเป็น N แถว และทุกแถวมี `TOTALBALANCEAMOUNT` เต็มจำนวน

6911272 (RECEIVE ID 37464, ยอด 100,100) มีหมายเหตุ 3 ข้อ → รายงานแสดง 100,100 × 3 = 300,300
ยอดต่อหมายเหตุใน `BACN.TOTALALLOCATEAMOUNT` = 31,200 + 7,000 + 61,900 = 100,100 (ตรงกับหน้าโอนเงินจัดสรร)

ข้อมูลทั้งระบบ (PREPROD): 237 รายการมีหมายเหตุ > 1 ข้อ — 235 รายการผลรวมหมายเหตุ = ยอดรับเงิน, 2 รายการไม่ตรง
(6911089: ยอดรับ 0 / หมายเหตุรวม 348,900; 6911787: ต่าง 2,900)

## สิ่งที่ผู้ใช้ตัดสินใจ (2026-10-21)

1. ยอดเงิน: **แยกยอดตามหมายเหตุ** (ใช้ `BACN.TOTALALLOCATEAMOUNT`)
2. คอลัมน์ "ปีงบประมาณ" ใน Excel: **แสดงตามปีงบประมาณ** — ตีความว่า = ปีจากเลขที่โอน (YYxxxxx → 25YY) ให้ตรงกับที่กรอง
3. ใบที่ยอดหมายเหตุไม่ตรงยอดรับเงิน: **ให้รายงานรองรับ** (แสดงตามยอดหมายเหตุ ไม่แก้ข้อมูล)

## การแก้

### View `OAGWBG_R_BUDGETTRANSFERCONTROL`
- `OAGWBG_R_BUDGETTRANSFERCONTROL_rollback.sql` = DDL สดจาก PREPROD ก่อนแก้
- `OAGWBG_R_BUDGETTRANSFERCONTROL_deploy.sql` = patch จาก DDL สด เปลี่ยนบรรทัดเดียว `RC.TOTALBALANCEAMOUNT` เป็น

```sql
CASE
  WHEN COUNT(BACN.ID) OVER (PARTITION BY RC.ID) > 1
    THEN NVL(BACN.TOTALALLOCATEAMOUNT, 0)
  ELSE RC.TOTALBALANCEAMOUNT
END AS TOTALBALANCEAMOUNT
```

ใช้ยอดหมายเหตุ **เฉพาะเมื่อมีหมายเหตุ > 1 ข้อ** เพราะรายการที่มีหมายเหตุ 1 ข้อแต่ยอดไม่ตรง (22 รายการ)
ยอดรับเงินเป็นยอดปัจจุบันหลังปรับแล้ว (บางรายการติดลบ) ส่วนยอดหมายเหตุเป็นยอดตอนจัดสรร — แถวกลุ่มนี้ไม่ได้ผิด จึงไม่แตะ

`RC.ID` ใน `OAGWBG_V_BUDGETRECEIVE` (ROUNDNO IS NOT NULL) unique — 54,502 แถว = 54,502 ID

### C# `OAGBudget.API\Services\Repository\ReportService.cs` (region 12)
- กรองปีด้วยช่วงเลขที่โอน `ROUNDNO >= (ปี-2500)*100000 AND ROUNDNO < (ปี-2499)*100000` แทน `BUDGETYEAR`
- คอลัมน์ 1 "ปีงบประมาณ" แสดง `ROUNDNO / 100000 + 2500`

## สถานะ

- [ ] view deploy PREPROD
- [ ] view deploy PROD (ต้องดึง DDL สด PROD ก่อน)
- [ ] TFS checkin ReportService.cs
