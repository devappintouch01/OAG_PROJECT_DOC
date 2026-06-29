# ER Diagram Results — ระบบ OAGWBG

**วันที่:** 2026-06-29
**เครื่องมือ:** DBeaver 26.0.1 / Schema: OAGWBG (Pre-PROD)
**อ้างอิง roadmap:** [roadmap_erdiagram.md](roadmap_erdiagram.md)

---

## สรุปความคืบหน้า

| สถานะ | โมดูล | ชื่อ | ตาราง | Virtual FK |
|:---:|:---:|---|---|---|
| ✅ | M1 | โอน/รับโอนงบ | 5 | 6 เส้น |
| ✅ | M2 | จัดสรร/โอนจัดสรร | 6 | 4 เส้น |
| ✅ | M3 | คำของบประมาณ | 6 | 5 เส้น |
| ✅ | M4 | รับงบ/รอบงบ | 5 | 3 เส้น |
| ✅ | M5 | แผนเบิกจ่าย | 8 | 6 เส้น |
| ✅ | M6 | กันเงิน/คืนงบ | 6 | 3 เส้น |
| ⬜ | M7a | สินทรัพย์ (ทะเบียน+ยืม+โอน) | 10 | 9 เส้น |
| ⬜ | M7b | สินทรัพย์ (ขอซื้อ+คืน+ตัด+ซ่อม) | 11 | 9 เส้น |
| ⬜ | M8 | Master data | ~45 | 2 เส้น |
| ✅ | M9 | ผู้ใช้/สิทธิ์ | 9 | 6 เส้น |

---

## M1 — โอน/รับโอนงบประมาณ

**สถานะ:** ✅ เสร็จแล้ว (2026-06-29)
**ไฟล์:** [`ERDiagram/M1_โอน-รับโอน.png`](ERDiagram/M1_โอน-รับโอน.png) | [`ERDiagram/M1.erd`](ERDiagram/M1.erd)

<img src="ERDiagram/M1_โอน-รับโอน.png" style="border: 1px solid black;" width="100%">

### ตารางในรูป (5 ตาราง)

| ตาราง | บทบาท |
|---|---|
| `OAGWBG_BUDGETTRANSFER` | Header หลัก — 1 row ต่อ 1 รายการโอน |
| `OAGWBG_BUDGETADJUST` | Detail ของ TransferOut |
| `OAGWBG_BUDGETRECEIVE` | TransferIn (รับโอน) |
| `OAGWBG_BUDGETRECEIVEREFUND` | เชื่อม TransferIn → รหัสงบ |
| `OAGWBG_BUDGETRECEIVEREFUND_COSTCENTER` | บัญชีธนาคารต่อ Cost Center |

### Virtual FK ในรูป (6 เส้น — Logical ไม่มีใน DB จริง)

| เส้น | Child.Column | → Parent.Column |
|---|---|---|
| 1 | BUDGETADJUST.`BUDGETTRANSFERID` | → BUDGETTRANSFER.`ID` |
| 2 | BUDGETRECEIVE.`BUDGETTRANSFERID` | → BUDGETTRANSFER.`ID` |
| 3 | BUDGETRECEIVE.`BUDGETADJUSTID` | → BUDGETADJUST.`ID` |
| 4 | BUDGETRECEIVEREFUND.`TRANSFERID` | → BUDGETTRANSFER.`ID` |
| 5 | BUDGETRECEIVEREFUND.`RECEIVEID` | → BUDGETRECEIVE.`ID` |
| 6 | BUDGETRECEIVEREFUND_COSTCENTER.`TRANSFERID` | → BUDGETTRANSFER.`ID` |

### ข้อสังเกตสำหรับ SA
- ตาราง `OAGWBG_BUDGETTRANSFER_CATEGORY`, `BUDGETTRANSFERHISTORY`, `BUDGETTRANSFERSOURCEITEM`, `BUDGETTRANSFERTARGETITEM` — **มีใน C# model แต่ไม่มีใน DB** (ทั้ง PROD และ Pre-PROD) — ขอให้ SA ยืนยันว่า feature ถูก cancel หรือยังวางแผนสร้างอยู่
- FK ทั้ง 6 เส้นเป็น **Virtual/Logical** ใน DBeaver เท่านั้น ไม่มี Constraint จริงใน Oracle — ถ้าต้องการเพิ่ม FK จริงต้องประเมินความเสี่ยง orphan row แยกต่างหาก

---

## M2 — จัดสรร/โอนจัดสรร

**สถานะ:** ✅ เสร็จแล้ว (2026-06-29)
**ไฟล์:** [`ERDiagram/M2_จัดสรร-โอนจัดสรร.png`](ERDiagram/M2_จัดสรร-โอนจัดสรร.png) | [`ERDiagram/M2_จัดสรร-โอนจัดสรร.erd`](ERDiagram/M2_จัดสรร-โอนจัดสรร.erd)

<img src="ERDiagram/M2_จัดสรร-โอนจัดสรร.png" style="border: 1px solid black;" width="100%">

### ตารางในรูป (6 ตาราง)

| ตาราง | บทบาท |
|---|---|
| `OAGWBG_BUDGETALLOCATETRANSFER` | Header โอนจัดสรร |
| `OAGWBG_BUDGETALLOCATETRANSFER_CATEGORY` | หมวดงบของโอนจัดสรร |
| `OAGWBG_BUDGETALLOCATETRANSFER_COSTCENTER` | Cost center ของโอนจัดสรร |
| `OAGWBG_BUDGETALLOCATETRANSFER_COSTCENTER_NOTE` | หมายเหตุ cost center |
| `OAGWBG_BUDGETALLOCATETRANSFERMORE` | รายการเพิ่มเติม |
| `OAGWBG_BUDGETALLOCATETRANSFERMORE_CATEGORY` | หมวดของรายการเพิ่มเติม |

### Virtual FK (4 เส้น)

| # | สถานะ | Child Table (ลาก**จาก**) | Column | Parent Table (ลากไป) | Ref Col |
|---|---|---|---|---|---|
| 1 | ✅ | BUDGETALLOCATETRANSFER_CATEGORY | `BUDGETALLOCATETRANSFERID` | BUDGETALLOCATETRANSFER | `ID` |
| 2 | ✅ | BUDGETALLOCATETRANSFER_COSTCENTER | `BUDGETALLOCATETRANSFERID` | BUDGETALLOCATETRANSFER | `ID` |
| 3 | ✅ | BUDGETALLOCATETRANSFER_COSTCENTER_NOTE | `RECEIVEID` | BUDGETALLOCATETRANSFER | `ID` |
| 4 | ✅ | BUDGETALLOCATETRANSFERMORE_CATEGORY | `BUDGETALLOCATETRANSFERMOREID` | BUDGETALLOCATETRANSFERMORE | `ID` |

---

## M3 — คำของบประมาณ

**สถานะ:** ✅ เสร็จแล้ว (2026-06-29)
**ไฟล์:** [`ERDiagram/M3_คำของบประมาณ.png`](ERDiagram/M3_คำของบประมาณ.png) | [`ERDiagram/M3_คำของบประมาณ.erd`](ERDiagram/M3_คำของบประมาณ.erd)
**หมายเหตุ:** SA ถามถึง `BUDGETREQUESTOUTSIDE` — อยู่ใน M3 นี้

<img src="ERDiagram/M3_คำของบประมาณ.png" style="border: 1px solid black;" width="100%">

### ตารางที่ต้องเลือกใน DBeaver (6 ตาราง)

| ตาราง | บทบาท |
|---|---|
| `OAGWBG_BUDGETREQUEST` | คำของบประมาณหลัก |
| `OAGWBG_BUDGETREQUESTOUTSIDE` | คำของบประมาณนอกแผน |
| `OAGWBG_BUDGETREQUISITION` | ใบเบิก/ขอซื้อ |
| `OAGWBG_BUDGETGOVERNMENT` | งบรัฐบาล |
| `OAGWBG_BUDGETGOVERNMENTITEM` | รายการงบรัฐบาล |
| `OAGWBG_BUDGETGOVERNMENTASSETITEM` | รายการสินทรัพย์ในงบรัฐบาล |

### Virtual FK (5 เส้น)

| # | สถานะ | Child Table (ลาก**จาก**) | Column | Parent Table (ลากไป) | Ref Col |
|---|---|---|---|---|---|
| 1 | ✅ | BUDGETGOVERNMENT | `BUDGETREQUESTID` | BUDGETREQUEST | `ID` |
| 2 | ⏭️ | BUDGETGOVERNMENT | `REF_BUDGETGOVERNMENTID` | BUDGETGOVERNMENT | `ID` (self) |
| 3 | ✅ | BUDGETGOVERNMENTITEM | `BUDGETGOVERNMENTID` | BUDGETGOVERNMENT | `ID` |
| 4 | ✅ | BUDGETGOVERNMENTASSETITEM | `BUDGETGOVERNMENTID` | BUDGETGOVERNMENT | `ID` |
| 5 | ⏭️ | BUDGETREQUEST | `PARENTID` | BUDGETREQUEST | `ID` (self) |

> `BUDGETREQUESTOUTSIDE` และ `BUDGETREQUISITION` ไม่มี FK ชัดเจนไปตารางอื่นใน M3 — แสดงเป็นกล่องลอยในรูป

---

## M4 — รับงบ/รอบงบ (Receive Period)

**สถานะ:** ✅ เสร็จแล้ว (2026-06-29)
**ไฟล์:** [`ERDiagram/M4_รับงบ-รอบงบ.png`](ERDiagram/M4_รับงบ-รอบงบ.png) | [`ERDiagram/M4_รับงบ-รอบงบ.erd`](ERDiagram/M4_รับงบ-รอบงบ.erd)

<img src="ERDiagram/M4_รับงบ-รอบงบ.png" style="border: 1px solid black;" width="100%">

### ตารางในรูป (5 ตาราง)

| ตาราง | บทบาท |
|---|---|
| `OAGWBG_BUDGETRECEIVE` | รับงบ (ใช้ร่วมกับ M1) |
| `OAGWBG_BUDGETRECEIVEPERIOD` | รอบการรับงบ |
| `OAGWBG_BUDGETRECEIVEPERIODALLOCATION` | การจัดสรรในรอบ |
| `OAGWBG_BUDGETRECEIVEPERIODCATEGORY` | หมวดในรอบ |
| `OAGWBG_BUDGETRECEIVEPERIODREQUEST` | คำขอในรอบ |

### Virtual FK (3 เส้น)

| # | สถานะ | Child Table (ลาก**จาก**) | Column | Parent Table (ลากไป) | Ref Col |
|---|---|---|---|---|---|
| 1 | ✅ | BUDGETRECEIVEPERIODALLOCATION | `BUDGETRECEIVEPERIODID` | BUDGETRECEIVEPERIOD | `ID` |
| 2 | ✅ | BUDGETRECEIVEPERIODCATEGORY | `BUDGETRECEIVEPERIODID` | BUDGETRECEIVEPERIOD | `ID` |
| 3 | ⏭️ | BUDGETRECEIVEPERIOD | `BUDGETGOVERNMENTID` | BUDGETGOVERNMENT (M3) | `ID` |

> เส้นที่ 3 ข้ามโมดูล M4→M3 — ข้าม / `BUDGETRECEIVE` และ `BUDGETRECEIVEPERIODREQUEST` แสดงเป็นกล่องลอย

---

## M5 — แผนเบิกจ่าย

**สถานะ:** ✅ เสร็จแล้ว (2026-06-29)
**ไฟล์:** [`ERDiagram/M5_แผนเบิกจ่าย.png`](ERDiagram/M5_แผนเบิกจ่าย.png) | [`ERDiagram/M5_แผนเบิกจ่าย.erd`](ERDiagram/M5_แผนเบิกจ่าย.erd)

<img src="ERDiagram/M5_แผนเบิกจ่าย.png" style="border: 1px solid black;" width="100%">

### ตารางในรูป (8 ตาราง)

| ตาราง | บทบาท |
|---|---|
| `OAGWBG_BUDGETDISBURSEMENTPLAN` | แผนเบิกจ่าย (header) |
| `OAGWBG_BUDGETDISBURSEMENTPLANITEM` | รายการในแผน |
| `OAGWBG_BUDGETDISBURSEMENTPLANRECEIVE` | การรับตามแผน |
| `OAGWBG_BUDGETDISBURSEMENTESTIMATED` | ประมาณการเบิก |
| `OAGWBG_BUDGETDISBURSEMENT` | การเบิกจ่าย (header) |
| `OAGWBG_BUDGETDISBURSEMENTITEM` | รายการเบิกจ่าย |
| `OAGWBG_BUDGETDISBURSEMENTAVERAGE` | ค่าเฉลี่ยเบิก |
| `OAGWBG_BUDGETDISBURSEMENTOUTSIDEITEM` | รายการเบิกนอกแผน |

### Virtual FK (7 เส้น)

| # | สถานะ | Child Table (ลาก**จาก**) | Column | Parent Table (ลากไป) | Ref Col |
|---|---|---|---|---|---|
| 1 | ✅ | BUDGETDISBURSEMENTPLANITEM | `BUDGETDISBURSEMENTPLANID` | BUDGETDISBURSEMENTPLAN | `ID` |
| 2 | ✅ | BUDGETDISBURSEMENTPLANRECEIVE | `BUDGETDISBURSEMENTPLANID` | BUDGETDISBURSEMENTPLAN | `ID` |
| 3 | ✅ | BUDGETDISBURSEMENTESTIMATED | `BUDGETDISBURSEMENTPLANID` | BUDGETDISBURSEMENTPLAN | `ID` |
| 4 | ⏭️ | BUDGETDISBURSEMENT | `BUDGETDISBURSEMENTPARENTID` | BUDGETDISBURSEMENT | `ID` (self) |
| 5 | ✅ | BUDGETDISBURSEMENTITEM | `BUDGETDISBURSEMENTID` | BUDGETDISBURSEMENT | `ID` |
| 6 | ✅ | BUDGETDISBURSEMENTAVERAGE | `BUDGETDISBURSEMENTID` | BUDGETDISBURSEMENT | `ID` |
| 7 | ✅ | BUDGETDISBURSEMENTOUTSIDEITEM | `BUDGETDISBURSEMENTID` | BUDGETDISBURSEMENT | `ID` |

---

## M6 — กันเงิน / คืนงบ

**สถานะ:** ✅ เสร็จแล้ว (2026-06-29)
**ไฟล์:** [`ERDiagram/M6_กันเงิน-คืนงบ.png`](ERDiagram/M6_กันเงิน-คืนงบ.png) | [`ERDiagram/M6_กันเงิน-คืนงบ.erd`](ERDiagram/M6_กันเงิน-คืนงบ.erd)

<img src="ERDiagram/M6_กันเงิน-คืนงบ.png" style="border: 1px solid black;" width="100%">

### ตารางในรูป (6 ตาราง)

| ตาราง | บทบาท |
|---|---|
| `OAGWBG_BUDGETRESERVED` | กันเงิน (header) |
| `OAGWBG_BUDGETRESERVEDITEM` | รายการกันเงิน |
| `OAGWBG_BUDGETRESERVED_CATEGORY` | หมวดกันเงิน |
| `OAGWBG_BUDGETRESERVED_BANKACCOUNT` | บัญชีธนาคารที่กันเงิน |
| `OAGWBG_BUDGETREFUND` | คืนงบ (header) |
| `OAGWBG_BUDGETREFUNDHISTORY` | ประวัติการคืนงบ |

### Virtual FK (5 เส้น)

| # | สถานะ | Child Table (ลาก**จาก**) | Column | Parent Table (ลากไป) | Ref Col |
|---|---|---|---|---|---|
| 1 | ✅ | BUDGETRESERVEDITEM | `BUDGETREVERSEDID` | BUDGETRESERVED | `ID` |
| 2 | ✅ | BUDGETRESERVED_CATEGORY | `BUDGETRESERVEDID` | BUDGETRESERVED | `ID` |
| 3 | ✅ | BUDGETRESERVED_BANKACCOUNT | `RESERVEDID` | BUDGETRESERVED | `ID` |
| 4 | ⏭️ | BUDGETRESERVEDITEM | `PARENTID` | BUDGETRESERVEDITEM | `ID` (self) |
| 5 | ❌ | BUDGETREFUNDHISTORY | `TARGETBUDGETREFUNDID` | BUDGETREFUND | `ID` |

> เส้นที่ 5 ลากไม่ได้ — `BUDGETREFUND` ไม่มี Primary Key ใน DB ทำให้ DBeaver ไม่ยอม create virtual FK

## M7a — สินทรัพย์ ทะเบียน+ยืม+โอน

**สถานะ:** ⬜ ยังไม่ได้ทำ

### ตารางใน DBeaver (10 ตาราง)

| ตาราง | บทบาท |
|---|---|
| `OAGWBG_ASSET` | ทะเบียนสินทรัพย์หลัก |
| `OAGWBG_ASSETIMAGE` | รูปภาพสินทรัพย์ |
| `OAGWBG_ASSETTRACKIMAGE` | รูปติดตามสินทรัพย์ |
| `OAGWBG_ASSETRELATION` | ความสัมพันธ์ระหว่างสินทรัพย์ |
| `OAGWBG_ASSETCHANGE` | บันทึกการเปลี่ยนแปลง |
| `OAGWBG_ASSETDEPRECIATION` | ค่าเสื่อมราคา |
| `OAGWBG_ASSETBORROW` | การยืมสินทรัพย์ (header) |
| `OAGWBG_ASSETBORROWITEM` | รายการยืม |
| `OAGWBG_ASSETTRANSFER` | การโอนสินทรัพย์ (header) |
| `OAGWBG_ASSETTRANSFERITEM` | รายการโอน |

### Virtual FK (9 เส้น)

| # | สถานะ | Child Table (ลาก**จาก**) | Column | Parent Table (ลากไป) | Ref Col |
|---|---|---|---|---|---|
| 1 | ⬜ | ASSETIMAGE | `ASSETID` | ASSET | `ID` |
| 2 | ⬜ | ASSETTRACKIMAGE | `ASSETID` | ASSET | `ID` |
| 3 | ⬜ | ASSETRELATION | `ASSETID` | ASSET | `ID` |
| 4 | ⬜ | ASSETCHANGE | `ASSETID` | ASSET | `ID` |
| 5 | ⬜ | ASSETDEPRECIATION | `ASSETID` | ASSET | `ID` |
| 6 | ⬜ | ASSETBORROWITEM | `ASSETBORROWID` | ASSETBORROW | `ID` |
| 7 | ⬜ | ASSETBORROWITEM | `ASSETID` | ASSET | `ID` |
| 8 | ⬜ | ASSETTRANSFERITEM | `ASSETTRANSFERID` | ASSETTRANSFER | `ID` |
| 9 | ⬜ | ASSETTRANSFERITEM | `ASSETID` | ASSET | `ID` |

---

## M7b — สินทรัพย์ ขอซื้อ+คืน+ตัดจำหน่าย+ซ่อมบำรุง

**สถานะ:** ⬜ ยังไม่ได้ทำ

### ตารางใน DBeaver (11 ตาราง)

| ตาราง | บทบาท |
|---|---|
| `OAGWBG_ASSET` | ทะเบียนสินทรัพย์ (ref จาก M7a) |
| `OAGWBG_ASSETREQUISITION` | ใบขอซื้อสินทรัพย์ (header) |
| `OAGWBG_ASSETREQUISITIONITEM` | รายการขอซื้อ |
| `OAGWBG_ASSETRETURN` | การส่งคืนสินทรัพย์ (header) |
| `OAGWBG_ASSETRETURNITEM` | รายการส่งคืน |
| `OAGWBG_ASSETWRITEOFF` | การตัดจำหน่าย (header) |
| `OAGWBG_ASSETWRITEOFFITEM` | รายการตัดจำหน่าย |
| `OAGWBG_ASSETMAINTENANCE` | การซ่อมบำรุง (header) |
| `OAGWBG_ASSETMAINTENANCEFORM` | แบบฟอร์มซ่อมบำรุง |
| `OAGWBG_ASSETMAINTENANCEFORMITEM` | รายการซ่อมบำรุง |
| `OAGWBG_ASSETMAINTENANCEFORMITEMLIST` | รายละเอียดซ่อมบำรุง |

### Virtual FK (9 เส้น)

| # | สถานะ | Child Table (ลาก**จาก**) | Column | Parent Table (ลากไป) | Ref Col |
|---|---|---|---|---|---|
| 1 | ⬜ | ASSETREQUISITIONITEM | `ASSETREQUISITIONID` | ASSETREQUISITION | `ID` |
| 2 | ⬜ | ASSETREQUISITIONITEM | `ASSETID` | ASSET | `ID` |
| 3 | ⬜ | ASSETRETURNITEM | `ASSETRETURNID` | ASSETRETURN | `ID` |
| 4 | ⬜ | ASSETRETURNITEM | `ASSETID` | ASSET | `ID` |
| 5 | ⬜ | ASSETWRITEOFFITEM | `ASSETWRITEOFFID` | ASSETWRITEOFF | `ID` |
| 6 | ⬜ | ASSETWRITEOFFITEM | `ASSETID` | ASSET | `ID` |
| 7 | ⬜ | ASSETMAINTENANCE | `ASSETID` | ASSET | `ID` |
| 8 | ⬜ | ASSETMAINTENANCEFORMITEM | `ASSETMAINTENANCEFORMID` | ASSETMAINTENANCEFORM | `ID` |
| 9 | ⬜ | ASSETMAINTENANCEFORMITEM | `ASSETID` | ASSET | `ID` |

> `ASSETMAINTENANCEFORMITEMLIST` ลอย — ไม่มี FK ชัดเจนใน plan

---

## M8 — Master data

**สถานะ:** ⬜ ยังไม่ได้ทำ

### ตารางที่ต้องเลือกใน DBeaver (~45 ตาราง — เลือกเฉพาะที่มี FK ระหว่างกัน)

| ตาราง | บทบาท |
|---|---|
| `OAGWBG_MASTERASSETCLASS` | หมวดสินทรัพย์ |
| `OAGWBG_MASTERASSETTYPE` | ประเภทสินทรัพย์ |
| `OAGWBG_MASTERASSETTYPESUB` | ประเภทย่อยสินทรัพย์ |
| `OAGWBG_MASTERBUDGETEXPENSETYPE` | ประเภทรายจ่าย |
| `OAGWBG_MASTERBUDGETTYPE` | ประเภทงบประมาณ |
| `OAGWBG_MASTERBUDGETFORMTYPE` | ประเภทแบบฟอร์มงบ |
| `OAGWBG_MASTERBANK` | ธนาคาร |
| `OAGWBG_MASTERCOSTCENTER` | ศูนย์ต้นทุน |
| `OAGWBG_MASTERORGANIZATION` | หน่วยงาน |
| `OAGWBG_MASTERUNIT` | หน่วยนับ |
| `OAGWBG_MASTERSTATUS` | สถานะ (ใช้ร่วมกันหลายโมดูล) |
| `OAGWBG_MASTERFUND` | แหล่งเงิน |
| `OAGWBG_MASTERMATERIAL` | วัสดุ |
| `OAGWBG_MASTERMATERIALGROUP` | กลุ่มวัสดุ |
| `OAGWBG_MASTERPROCUREMENTMETHOD` | วิธีจัดซื้อ |
| `OAGWBG_MASTERPROCUREMENTMETHODSTEP` | ขั้นตอนวิธีจัดซื้อ |
| `OAGWBG_MASTERWAREHOUSE` | คลังพัสดุ |
| `OAGWBG_MASTERSTANDARDPRICE` | ราคามาตรฐาน |
| `OAGWBG_MASTERAMPHUR` / `MASTERPROVINCE` / `MASTERTAMBON` | ที่อยู่ |
| ฯลฯ (ตาราง MASTER อื่นๆ อีก ~25 ตาราง) | lookup ต่างๆ |

### Virtual FK (ที่มีความสัมพันธ์ชัดเจน)

| # | สถานะ | Child Table | Column | Parent Table | Ref Col |
|---|---|---|---|---|---|
| 1 | ⬜ | MASTERASSETTYPESUB | `ASSETTYPEID` | MASTERASSETTYPE | `ID` |
| 2 | ⬜ | MASTERPROCUREMENTMETHODSTEP | `PROCUREMENTMETHODID` | MASTERPROCUREMENTMETHOD | `ID` |

> Master ส่วนใหญ่เป็น lookup อิสระ — FK น้อยมาก พิจารณาทำเป็นรูปรายชื่อตาราง (index) แทน diagram เส้นก็ได้

---

## M9 — ผู้ใช้ / สิทธิ์ / ระบบ

**สถานะ:** ✅ เสร็จแล้ว (2026-06-29)
**ไฟล์:** [`ERDiagram/M9_ผู้ใช้-สิทธิ์.png`](ERDiagram/M9_ผู้ใช้-สิทธิ์.png) | [`ERDiagram/M9_ผู้ใช้-สิทธิ์.erd`](ERDiagram/M9_ผู้ใช้-สิทธิ์.erd)

<img src="ERDiagram/M9_ผู้ใช้-สิทธิ์.png" style="border: 1px solid black;" width="100%">

### ตารางในรูป (9 ตาราง — จาก 13 ที่วางแผน)

| ตาราง | บทบาท | หมายเหตุ |
|---|---|---|
| `OAGWBG_SYSTEMUSER` | ผู้ใช้งาน | ✅ มีใน DB |
| `OAGWBG_SYSTEMROLE` | Role/กลุ่มสิทธิ์ | ✅ มีใน DB |
| `OAGWBG_SYSTEMUSERROLEASSIGN` | มอบหมาย Role → User | ✅ มีใน DB |
| `OAGWBG_SYSTEMMENU` | เมนูระบบ | ✅ มีใน DB |
| `OAGWBG_SYSTEMMENUGROUP` | กลุ่มเมนู | ✅ มีใน DB |
| `OAGWBG_SYSTEMMENUROLEASSIGN` | มอบหมาย Menu → Role | ✅ มีใน DB |
| `OAGWBG_WORKFLOWJOBLOG` | Log workflow | ✅ มีใน DB |
| `OAGWBG_CANCELREASONLOG` | Log เหตุผลยกเลิก | ✅ มีใน DB |
| `OAGWBG_LOG_INTERFACE` | Log ส่ง interface ไป Oracle EBS | ✅ มีใน DB |

### ตารางที่ไม่มีใน DB (code-only)

| ตาราง | บทบาท |
|---|---|
| `OAGWBG_SYSTEMUSERLINE` | LINE account ของผู้ใช้ — **ไม่มีใน PREPROD** |
| `OAGWBG_SYSTEMPERMISSION` | Permission ย่อย — **ไม่มีใน PREPROD** |
| `OAGWBG_SYSTEMWEBMENU` | Web menu — **ไม่มีใน PREPROD** |
| `OAGWBG_WORKFLOWJOB` | งาน Workflow — **ไม่มีใน PREPROD** (มีแค่ WORKFLOWJOBLOG) |

> ขอให้ SA ยืนยันว่า feature ถูก cancel หรือยังวางแผนสร้างอยู่

### Virtual FK (8 เส้น)

| # | สถานะ | Child Table (ลาก**จาก**) | Column | Parent Table (ลากไป) | Ref Col |
|---|---|---|---|---|---|
| 1 | ⏭️ | SYSTEMUSERLINE | `SYSTEMUSERID` | SYSTEMUSER | `ID` |
| 2 | ✅ | SYSTEMUSERROLEASSIGN | `SYSTEMUSERID` | SYSTEMUSER | `ID` |
| 3 | ✅ | SYSTEMUSERROLEASSIGN | `SYSTEMROLEID` | SYSTEMROLE | `ID` |
| 4 | ✅ | SYSTEMUSERROLEASSIGN | `SYSTEMMENUGROUPID` | SYSTEMMENUGROUP | `ID` |
| 5 | ⬜ | SYSTEMMENUROLEASSIGN | `SYSTEMROLEID` | SYSTEMROLE | `ID` |
| 6 | ⬜ | SYSTEMMENUROLEASSIGN | `SYSTEMMENUID` | SYSTEMMENU | `ID` |
| 7 | ⏭️ | SYSTEMMENU | `PARENTMENUID` | SYSTEMMENU | `ID` (self) |
| 8 | ✅ | SYSTEMMENU | `SYSTEMMENUGROUPID` | SYSTEMMENUGROUP | `ID` |
