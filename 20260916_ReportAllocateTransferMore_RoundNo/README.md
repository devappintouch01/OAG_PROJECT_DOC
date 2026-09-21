# รายงานโอนเงินจัดสรร — ค้นหาเลขใบโอน "โอนจัดสรรเพิ่มเติม" ไม่เจอ (2026-09-16)

## อาการ
ค้นหาเลขใบโอนของโอนจัดสรรเพิ่มเติม (ตัวอย่าง 6912572) ไม่เจอใน 3 รายงาน
1. รายงานการจัดสรรงบประมาณรายจ่ายประจำปีงบประมาณ (`ReportBudgetAnnualAllocationSummary`)
2. รายละเอียดการโอนเงินจัดสรรงบประมาณรายจ่ายประจำปี (`ReportBudgetAllocateTransferDetail`)
3. รายงานโอนเงินจัดสรรงบประมาณรายจ่ายประจำปี (`ReportBudgetAllocateTransfer`)

## สาเหตุ
ไม่ใช่ตัวกรองผิด — รายงานกลุ่มนี้ไม่เคยรองรับโอนจัดสรรเพิ่มเติมเลย

| ที่เก็บ | ใบ 6912572 |
|---|---|
| `OAGWBG_BUDGETALLOCATETRANSFERMORE` | มี (ID 130, ปี 2569, สถานะ 80401, ยอด 103,715.28) |
| `OAGWBG_BUDGETALLOCATETRANSFER` / `OAGWBG_V_BUDGETALLOCATETRANSFER` / `OAGWBG_R_BUDGETALLOCATETRANSFER` | ไม่มี |

dropdown เลขใบโอน (`MasterService.GetAllocateRoundNoWithFilter`), ตัวรายงาน, dropdown แผนงาน/รหัสงบประมาณ และสถานะหัวรายงาน
อ่านเฉพาะชุด `OAGWBG_*BUDGETALLOCATETRANSFER*` ของโอนจัดสรรปกติ

## แนวทางที่เลือก (ข) — view แยก + ตัวเลือกประเภทการโอน
ไม่แตะ view เดิม `OAGWBG_R_BUDGETALLOCATETRANSFER`

### DB (PREPROD — deploy แล้ว 2026-09-16, status VALID)
- `deploy_OAGWBG_R_BUDGETALLOCATETRANSFERMORE.sql` / `rollback_OAGWBG_R_BUDGETALLOCATETRANSFERMORE.sql`
- คอลัมน์ชุดเดียวกับ `OAGWBG_R_BUDGETALLOCATETRANSFER` ทุกตัว
- 1 แถว = 1 รายการโอนออก (`ROWTYPE='O'`)
  - ยอด = `c.TOTALALLOCATEAMOUNT` (ไม่ใช้ยอดคำขอของแถวแม่)
  - ผู้รับโอน/รายการ/ผลผลิต/กิจกรรม = แถวแม่ (`c.PARENTID`) — ตรงกับแถว BUDGETRECEIVE "A" ที่ตอนจองงบสร้าง
  - แหล่งเงิน = ของแถวโอนออก
  - แผนงาน = `CATC.PLANID` (p.BUDGETPLANID บางแถวเป็น id config 3123/3124 ซึ่งต่างกันแต่ละ environment)
  - บัญชี = `_MORE_COSTCENTER` ตามคีย์ของ `GenerateCostCenterRowsFromCategory` + NVL expense type (บางรายการไม่มี)
    + สำรองสำหรับใบเก่าที่คีย์รูปแบบเดิม (ใช้เมื่อผู้รับ+ผู้โอน+แหล่งเงินตรงกันแถวเดียว)

ผลตรวจบน PREPROD
- 91 แถว / 8,613,662.28 = จำนวนและยอดของแถว O ทั้งหมดพอดี (join ไม่ทำให้แถวซ้ำ)
- 6912572 = 5 แถว / 103,715.28 = ยอดหัวใบ
- ไม่มี PLANID/PRODUCTNAME/ACTIVITYNAME/BUDGETCODEID/EXPENSETYPEID ว่าง
- ไม่มีบัญชีเฉพาะใบร่าง (80101) ที่ยังไม่ได้เลือกบัญชี 29 แถว — สถานะอื่นมีบัญชีครบ
- เลขใบโอนของ 2 ตารางไม่ซ้ำกันเลย (0 ใบ)

### โค้ด
ค่า `TransferType = "4"` = โอนจัดสรรเพิ่มเติม (`AllocateTransferReportType`) — ค่าว่าง/"1" = โอนจัดสรรเหมือนเดิม
- DAL: `AllocateTransferReportType` (ใหม่), `OAGDBContextBase.ReportAllocateTransfers(bool)` อ่าน view ใหม่ผ่าน entity เดิมด้วย `FromSqlRaw`,
  เพิ่ม `TransferType` + `IsTransferMore()` ใน `BudgetAllocateTransfer`, `ReportBudgetAnnualAllocationSummaryModel`, `ReportBudgetAllocateTransferDetailModel`
- API `ReportService`: รายงาน 3 ตัวสลับแหล่งข้อมูล + สถานะจาก `OAGWBG_V_BUDGETALLOCATETRANSFERMORE` + ข้ามชื่อรายการแม่
- API `ReportController`: รายละเอียดการโอนรับ `TransferType = "4"`
- API `MasterService`/`MasterController`: `GetAllocateRoundNoWithFilter`, `GetPlanByRoundAllocate`, `GetBudgetCodeByRoundNo` รับ `transferType` (optional)
  - fast path เลขใบโอน: หัวใบไม่มี BUDGETSOURCEID → กรองแหล่งเงินผ่านแถวโอนออก
  - แผนงาน: แปลงรหัส 10000/… กลับเป็น id config ให้ตรงกับ dropdown เดิม
- Web: service/controller/dropdown ส่ง `transferType` ต่อ, 3 หน้าเพิ่มตัวเลือก "โอนจัดสรรเพิ่มเติม"

### แก้เพิ่ม — หน้ารายละเอียดการโอน dropdown โอนครั้งที่ค้างตามภาคเริ่มต้น
- เดิมเปลี่ยน "ภาค" แล้วไม่โหลดโอนครั้งที่ใหม่ รายการค้างตามภาค/หน่วยเบิกจ่าย preset ของผู้ใช้
  (ทดสอบ: ผู้ใช้ภาค 00 เปลี่ยนเป็น "ทั้งหมด" ค้นหา 6912572 (ภาค 04) → No results found; API เองตอบถูก)
- แก้: ภาคเปลี่ยน → `loadRoundNo()`, หน่วยเบิกจ่ายเปลี่ยน → เรียกหลังล้างศูนย์ต้นทุน,
  ใช้เฉพาะคำตอบของคำขอล่าสุด (`roundNoRequestSeq`)
- หน้า 6/13 ผูก change ของภาคกับ loadRoundNo อยู่แล้ว ไม่ต้องแก้

### ยังไม่ได้ทำ
- checkin TFS (เครื่องนี้ไม่มี `tf.exe`) — ไฟล์ใหม่ `OAGBudget.DAL\Models\AllocateTransferReportType.cs` ต้อง `tf add`
- deploy view ขึ้น PROD
