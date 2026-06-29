# ER Diagram Results — ระบบ OAGWBG

**วันที่:** 2026-06-29
**เครื่องมือ:** DBeaver 26.0.1 / Schema: OAGWBG (Pre-PROD)
**อ้างอิง roadmap:** [roadmap_erdiagram.md](roadmap_erdiagram.md)

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
**สถานะ:** ⬜ ยังไม่ได้ทำ

## M3 — คำของบประมาณ
**สถานะ:** ⬜ ยังไม่ได้ทำ

## M4 — รับงบ/รอบงบ (Receive Period)
**สถานะ:** ⬜ ยังไม่ได้ทำ

## M5 — แผนเบิกจ่าย
**สถานะ:** ⬜ ยังไม่ได้ทำ

## M6 — กันเงิน / คืนงบ
**สถานะ:** ⬜ ยังไม่ได้ทำ

## M7 — สินทรัพย์ (Asset)
**สถานะ:** ⬜ ยังไม่ได้ทำ

## M8 — Master data
**สถานะ:** ⬜ ยังไม่ได้ทำ

## M9 — ผู้ใช้ / สิทธิ์ / ระบบ
**สถานะ:** ⬜ ยังไม่ได้ทำ
