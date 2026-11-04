# รายงานการเปลี่ยนแปลงงบประมาณประจำปี — รองรับการโอนครบทุกประเภท

**วันที่:** 2026-09-04
**อาการที่แจ้ง:** PROD — รายงานการเปลี่ยนแปลงงบประมาณประจำปี ไม่มีใบโอนให้เลือก
**ตรวจสอบบน:** PREPROD (ebs_PRE, 172.16.11.19:1541)

---

## สาเหตุ

View `OAGWBG_R_BUDGETADJUST` (แหล่งข้อมูลของรายงาน) join receive ผ่านคอลัมน์บน header
คือ `BUDGETRECEIVEIDSOURCE` / `BUDGETRECEIVEIDTARGET` แต่ข้อมูลจริงมีแต่ `TRANSFERTYPE = '1'`
เท่านั้นที่ set 2 คอลัมน์นี้:

| TRANSFERTYPE | จำนวนใบ | SOURCE ไม่ null | TARGET ไม่ null |
|---|---|---|---|
| 1 | 29 | 29 | 2 |
| 2 | 308 | **0** | **0** |
| 3 | 17 | **0** | **0** |
| 4 | 42 | **0** | **0** |

→ INNER JOIN ตัดประเภท 2/3/4 ทิ้งทั้งหมด รายงาน export ได้เฉพาะประเภท 1

ยืนยันจากฝั่งโค้ดตรงกัน — `SaveBudgetTransferReturn*` / `SaveBudgetTransferReserve*` ไม่เคย set
2 คอลัมน์นี้ มีแต่ path ของโอนเปลี่ยนแปลงที่ set (`BudgetService.cs:19089`)

**ข้อมูลไม่ได้หาย** — ลูกทั้งหมดผูกด้วย `OAGWBG_BUDGETRECEIVE.BUDGETTRANSFERID` ครบ
และอยู่ใน `OAGWBG_V_BUDGETRECEIVE` ทั้งหมด (type 2 = 141, type 3 = 26, type 4 = 46)

### ปัญหารอง

1. branch เบิกแทน join `OAGWBG_ACCOUNT_SEGMENT` โดยไม่กรอง `REFERENCETABLE`
   → ลากแถวของ `BudgetRequestOutside` / `Project` ติดมา (**184 แถวปลอม จาก 15 แถวจริง**)
2. dropdown ใบโอนดึงจาก `OAGWBG_V_BUDGETTRANSFER` ยกกอง ไม่กรองปี/ประเภท
   → 227 ตัวเลือก แต่รายงานมีข้อมูลจริงแค่ 27 ใบ = กว่า 200 ตัวเลือกกดแล้วได้ไฟล์เปล่า
3. `TRANSFERNO` เป็น running เปล่า ๆ ไม่ unique — เลข `"1"` ซ้ำ **153 ใบ** ข้ามปีข้ามประเภท
   แถมรายงานกรองด้วย `LIKE '%..%'` → เลือก "1" ได้ 1, 10, 11, 1929, 21 ติดมาหมด
4. หัวคอลัมน์ Excel "จำนวนเงินรับโอน" / "จำนวนเงินโอนออก" ผูกค่าสลับกัน

---

## การแก้ — แยก join ตามเส้นทางจริงของแต่ละประเภท

| # | ประเภท | เส้นทาง | เลขที่ใบโอน |
|---|---|---|---|
| 1 | โอนเปลี่ยนแปลงงบประมาณ | `BUDGETTRANSFER('1')` → `BUDGETADJUST` → `BUDGETRECEIVE.BUDGETADJUSTID` | `ROUNDNO` |
| 2 | โอนเงินกลับ | `BUDGETTRANSFER('2')` → `BUDGETRECEIVE.BUDGETTRANSFERID` type `T` | `ROUNDNO` |
| 3 | โอนปรับเงินเหลือจ่าย | `BUDGETTRANSFER('3')` → `BUDGETRECEIVE.BUDGETTRANSFERID` type `R` | `ROUNDNO` |
| 4 | เบิกแทนกัน | `BUDGETREQUISITION` + `ACCOUNT_SEGMENT` (`'O'`=โอนออก / `'I'`=โอนเข้า) | `RUNNING` |
| 5 | โอนเงินกลับหลายปี | `BUDGETTRANSFER('4')` → `BUDGETRECEIVE.BUDGETTRANSFERID` type `T` | `ROUNDNO` |

> **รหัสประเภท:** `TRANSFERTYPE` ในตารางค่า `'4'` คือ *โอนกลับหลายปี*
> (`SaveBudgetTransferReturnMoreYearsDetail`) ไม่ใช่เบิกแทน — view จึง map เป็น `'5'`
> และสงวน `'4'` ไว้ให้เบิกแทน (requisition) ตามความหมายเดิมของ dropdown บนหน้าจอ

### เลขที่ใบโอน: ใช้ ROUNDNO แทน TRANSFERNO

| | unique | ตัวอย่าง |
|---|---|---|
| `BUDGETTRANSFER.ROUNDNO` | **396/396** | `6912556` = ปี 69 + orgtype 1 + running 2556 |
| `BUDGETREQUISITION.RUNNING` | **14/14** | `6900001` |
| `BUDGETTRANSFER.TRANSFERNO` (เดิม) | 227/396 | `"1"` ซ้ำ 153 ใบ |

view เพิ่มคอลัมน์ `ROUNDNO` ต่อท้าย และ **คงคอลัมน์เดิมครบทั้ง 19 ตัว** เพื่อไม่ให้ EF พัง

---

## ผลลัพธ์หลังแก้ (PREPROD)

รวม 297 แถว — ครบทุกประเภท ทุกแถวมีเลขที่ใบโอน

```
TYPE | ROLETYPE | ปี   | แถว | จำนวนใบ
1    | SENDER   | 2568 |   2 |  2
1    | SENDER   | 2569 |  29 | 27
1    | RECEIVER | 2569 |  38 | 25
2    | RECEIVER | 2568 |  30 | 26
2    | RECEIVER | 2569 | 111 | 79
3    | RECEIVER | 2568 |   2 |  2
3    | RECEIVER | 2569 |  20 | 11
3    | RECEIVER | 2570 |   4 |  3
4    | SENDER   | 2569 |   3 |  3
4    | RECEIVER | 2569 |  12 | 11
5    | RECEIVER | 2569 |  46 | 41
```

เดิม: type 2/3/5 = 0 แถว, type 4 = 184 แถวปลอม

---

## ลำดับ deploy

**ต้องลง DB ก่อน แล้วค่อยลง app** — ไม่งั้น `ROUNDNO` จะได้ `ORA-00904 invalid identifier`

1. รัน `OAGWBG_R_BUDGETADJUST_deploy.sql`
2. deploy source code (TFS)

ย้อนกลับ: รัน `OAGWBG_R_BUDGETADJUST_rollback.sql` (DDL เดิมที่ดึงจาก PREPROD ก่อนแก้)
แล้ว rollback source code — ต้องทำคู่กัน

---

## ไฟล์ที่แก้ (source code)

| ไฟล์ | แก้อะไร |
|---|---|
| `OAGBudget.DAL/Models/OagwbgRBudgetadjust.cs` | เพิ่ม property `Roundno` |
| `OAGBudget.DAL/Models/OAGDBContextBase.cs` | map คอลัมน์ `ROUNDNO` |
| `OAGBudget.API/Services/Repository/MasterService.cs` | เพิ่ม `GetTransferNoFromBudgetAdjust(budgetYear, transferType)` |
| `OAGBudget.API/Controllers/MasterController.cs` | endpoint `GET /Master/GetTransferNoFromBudgetAdjust` |
| `OAGBudget/Services/Repository/MasterService.cs` | client เรียก API ตัวใหม่ |
| `OAGBudget/Services/Dropdown.cs` | `DropdownTransfersNoFromBudgetAdjust` + เพิ่มประเภท `5 : โอนเงินกลับหลายปี` |
| `OAGBudget/Controllers/ReportController.cs` | action AJAX `GetTransferNoFromBudgetAdjust`, ไม่โหลดเลขที่โอนตอนเปิดหน้า |
| `OAGBudget.API/Services/Repository/ReportService.cs` | กรอง `Roundno` แบบ exact แทน `LIKE` บน `Transferno`, เพิ่มคอลัมน์ "เลขที่โอน" ใน Excel, แก้คอลัมน์เงินที่สลับ |
| `OAGBudget/Views/Report/ReportBudgetAdjust.cshtml` | label "เลขที่คำขอ" → "เลขที่โอน", cascade dropdown ตามปี+ประเภท |

### หัวตาราง Excel (12 คอลัมน์ A–L)

```
ลำดับ | เลขที่โอน | หน่วยเบิกจ่าย | ศูนย์ต้นทุน | ปีงบประมาณ | รหัสแหล่งเงิน |
แหล่งเงิน | แผนงาน | ผลผลิต | กิจกรรม | จำนวนเงินรับโอน | จำนวนเงินโอนออก
```

เดิม 11 คอลัมน์ (A–K) ไม่มีเลขที่โอน — เพิ่มเป็นคอลัมน์ที่ 2 (ค่าจาก `ROUNDNO`)

### การแยกชีต

| เลือกประเภทรายการ | ผลลัพธ์ |
|---|---|
| เลือก | ชีตเดียว ชื่อ `การเปลี่ยนแปลงงบประมาณ` |
| ไม่เลือก (ทุกประเภท) | **แยกชีตตามประเภท** เรียงตามรหัส — `1 โอนเปลี่ยนแปลงงบประมาณ`, `2 โอนเงินกลับ`, `3 โอนปรับเงินเหลือจ่าย`, `4 เบิกแทน`, `5 โอนเงินกลับหลายปี` |

- สร้างชีตเฉพาะประเภทที่มีข้อมูลจริง ประเภทที่ไม่มีข้อมูลจะไม่มีชีต
- แต่ละชีตมีหัวรายงาน หัวตาราง และแถวผลรวมของตัวเอง (ผลรวมแยกต่อชีต ไม่ใช่ยอดรวมทั้งไฟล์)
- ไม่มีข้อมูลเลย → ได้ชีตเปล่า 1 ชีต (ไฟล์ Excel ต้องมีอย่างน้อย 1 ชีต)
- ชื่อประเภทอยู่ที่ `ReportService.TransferTypeName()` ต้องแก้คู่กับ `Dropdown.DropdownTypeTransfer()`

### หมายเหตุ

- เลขที่โอนเปลี่ยนจาก **required** เป็น **optional** (`-- ทั้งหมด --`) เพื่อไม่ให้ตัน
  เมื่อปี+ประเภทที่เลือกยังไม่มีใบโอน (เดิมประเภท 4 ถูก disable ทิ้งอยู่แล้ว)
- `GetTransferNo()` / `DropdownTransfersNo()` ตัวเดิมไม่มีใครเรียกแล้ว แต่ยังคงไว้
  (เป็น public API endpoint) — ถ้าจะลบให้ตรวจ consumer ภายนอกก่อน
