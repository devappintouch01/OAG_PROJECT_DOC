# แยก running เลขที่โอน: โอนเปลี่ยนแปลง + โอนปรับเงินเหลือจ่าย → 693/694

วันที่: 2026-10-16

## ความต้องการ

- โอนเปลี่ยนแปลงงบประมาณ (TRANSFERTYPE 1, ผู้ใช้เรียก "โอนปรับเปลี่ยนรายการ") และโอนปรับเงินเหลือจ่าย (TRANSFERTYPE 3)
  ใช้ running **ชุดเดียวกัน** แยกจากโอนจัดสรร / โอนเงินกลับ / โอนเงินกลับหลายปี
- รูปแบบ `YY + หลักหน่วยงาน + NNNN`: สบง. → `YY3NNNN` (เช่น 6930001), สบอ. → `YY4NNNN` (เช่น 6940001)
- ใบเก่าที่มีเลข 691/692 คงเลขเดิม ใบที่สร้างใหม่ทุกใบใช้เลขใหม่ทันที รวมปีงบ 2569
- รายงานทะเบียนคุมการโอน: เลือก สบง. ต้องได้หลัก 1 และ 3, เลือก สบอ. ต้องได้หลัก 2 และ 4

## การออกแบบ

- คอลัมน์ `TRANSFERORGTYPE` ของใบโอนยังเก็บ `1`/`2` เหมือนเดิม เพราะหน้าจอและรายงานใช้แสดงป้าย สบง./สบอ.
  เปลี่ยนเฉพาะหลักที่ 3 ของ `ROUNDNO`
- ตัวนับใช้ `OAGWBG_TRANSFER_RUNNING` เดิมด้วย `ORG_TYPE` = `'3'`/`'4'` (คอลัมน์เป็น VARCHAR2(10) ไม่มี check constraint
  และ MERGE สร้างแถวให้เองตอนออกเลขครั้งแรก จึงไม่ต้องแก้ DB)
- โอนปรับเงินเหลือจ่ายเลิกออกเลขด้วย `MAX(ROUNDNO)+1` เพราะวิธีนั้นเห็นแค่ `OAGWBG_BUDGETTRANSFER`
  จึงเคยได้เลขชนกับโอนจัดสรรมาแล้ว 4 ใบ และไม่กันกรณีบันทึกพร้อมกัน (ผู้ใช้ให้ปล่อย 4 ใบนี้ไว้):

  | ROUNDNO | BUDGETTRANSFER.ID (type 3) | BUDGETALLOCATETRANSFER.ID |
  |---|---|---|
  | 6810029 | 2657 | 2269 |
  | 6810030 | 2678 | 2276 |
  | 6810031 | 2737 | 2569 |
  | 6912021 | 2116 (80501) | 2259 |

## สิ่งที่แก้

### Code (TFS)

`OAGBudget.API/Services/Repository/BudgetService.cs`
- เพิ่ม `ResolveTransferAdjustRoundNoAsync` — แปลง 1→"3", 2→"4" แล้วเรียก `ResolveRoundNoAsync`
- ลบ `ResolveReserveTransferRoundNoAsync` + `SyncTransferRunningAsync` (MAX+1 ของ type 3)
- จุดเรียกที่เปลี่ยน: `SaveBudgetAdjust`, `SaveBudgetReceiveTransferIn`, `SaveTransferModifyItem` (type 1),
  `ExecuteBudgetReservedTransferCoreAsync` (type 3)
- ไม่แตะ: โอนจัดสรร, copy โอนจัดสรร, โอนจัดสรรเพิ่มเติม, โอนเงินกลับ (V1/V2), โอนเงินกลับหลายปี — ยังใช้ 691/692

`OAGBudget.API/Services/Repository/ReportService.cs` — `ReportBudgetTransferControl`
- ตัวกรองหน่วยงาน: `"1"` → หลัก 1/3, `"2"` → หลัก 2/4

### DB view

`OAGWBG_R_BUDGETTRANSFERCONTROL` — คอลัมน์ `TRANSFERDEPT`: `IN ('1','3')` → สบง., `IN ('2','4')` → สบอ.
(เป็น DB object ตัวเดียวจาก 27 ตัวที่ใช้ ROUNDNO ที่แยกหลักของเลข — scan ด้วย DBMS_METADATA.GET_DDL)

- `OAGWBG_R_BUDGETTRANSFERCONTROL_deploy.sql` — ⚠ บรรทัด 1 ชื่อ view ถูกแก้เป็น `" "` เมื่อ 11:27 (หลัง deploy) ต้องแก้กลับเป็น
  `"OAGWBG_R_BUDGETTRANSFERCONTROL"` ก่อนนำไปรันที่ PROD
- `OAGWBG_R_BUDGETTRANSFERCONTROL_rollback.sql` — DDL สดของ PREPROD ก่อนแก้
- `verify_before_deploy.sql` — ตรวจความเท่ากันของ view ใหม่กับของเดิม

## การตรวจสอบ (PREPROD `ebs_PRE`)

| ตรวจ | ผล |
|---|---|
| Build `OAGBudget.API` (output แยกเพราะแอปรันอยู่) | 0 Error |
| view ใหม่ vs เดิม ก่อน deploy | COUNT 54,789 = 54,789, MINUS สองทาง = 0 |
| mapping 6910001/6920001/6930001/6940001/6950001 | สบง./สบอ./สบง./สบอ./NULL |
| deploy view 11:18:08 | VALID, 54,789 แถว, ไม่มี TRANSFERDEPT เป็น NULL |
| EF translate ตัวกรองรายงาน | `SUBSTR(CAST(ROUNDNO AS VARCHAR2(11)), 3, 1) IN (N'1', N'3')` |
| ใบที่สร้างจากแอปหลังแก้ (11:11-11:19) | 6930001 (type 1 สบง.), 6940001 (type 1 สบอ.), 6930002 (type 3 สบง.), 6940002 (type 3 สบอ.) — ใช้ running ร่วมกัน, TRANSFERORGTYPE ยังเป็น 1/2 |

## ยังค้าง

- [ ] PROD: ดึง DDL สดของ view บน PROD มาเทียบก่อน (โครงสร้างอาจต่างจาก PREPROD) แล้ว deploy + ตรวจ COUNT/MINUS
- [ ] TFS checkin ของ BudgetService.cs + ReportService.cs (ต้องตัด VPN ก่อน `tf get`)
