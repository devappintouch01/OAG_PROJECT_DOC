# รายงานการโอนเปลี่ยนแปลงงบประมาณประจำปี โหลดช้า — `OAGWBG_R_BUDGETADJUST` (2026-11-03)

## อาการ / สาเหตุ
- `ReportService.ReportBudgetAdjust` อ่าน view `OAGWBG_R_BUDGETADJUST` ครั้งแรกใช้เวลา ~53 วินาที แต่ครั้งต่อมาใช้ ~2 วินาที
- เวลาเกือบทั้งหมดหมดไปกับ **hard parse** (EXPLAIN PLAN อย่างเดียวใช้ 56 วินาที) ข้อมูลมีแค่ 567 แถว
- view เป็น UNION ALL 10 branch แต่ละ branch join `V_EXT_*` เอง และอ้าง `V_BUDGETRECEIVE` 6 ครั้ง
  รวมแล้วอ้าง view อื่นราว 45 ครั้ง ทุกครั้งที่ cursor หลุดจาก shared pool ต้องวางแผนใหม่หมด
- dropdown เลขที่โอน (`MasterService.GetTransferNoFromBudgetAdjust`) หลบไปอ่านตารางหลักแล้วตั้งแต่ 2026-10-09 แต่ตัว export รายงานยังอ่าน view นี้อยู่

## สิ่งที่แก้ (`deploy_OAGWBG_R_BUDGETADJUST.sql`)
1. **ย้าย lookup ชื่อออกไปไว้นอก UNION** — ศูนย์ต้นทุน / แหล่งเงิน / แผนงาน / กิจกรรม / ผลผลิต / หมวด join แค่ครั้งเดียว
   - branch ส่ง key มาใน `L_*` และส่งชื่อที่ได้มากับแถว (จาก R / G / BTV / BCV) มาใน `F_*`
   - ชั้นนอกเลือกค่าตามลำดับเดิมของแต่ละ branch (ดูหัวไฟล์ deploy) — branch ที่เดิมใช้ชื่อจากแถวอย่างเดียวจะส่ง `L_* = NULL`
2. **รวม branch ที่อ่าน source เดียวกัน** จาก 10 เหลือ 5
   - 2/3/5 ฝั่งรับโอนรวมกัน: `BUDGETRECEIVETYPE = DECODE(T.TRANSFERTYPE, '3', 'R', 'T')`
   - 2/3/5 ฝั่งโอนออกรวมกัน: ประเภท 3 ยังบังคับให้มี G (`G.ID IS NOT NULL`) และประเภท 4 ไม่ join G เหมือนเดิม
   - เบิกแทนกัน O กับ I รวมกัน
- อ้าง view อื่นเหลือ 13 ครั้ง ส่วน RL / AV ไม่ได้แตะ
- `TRANSFERTYPE` ที่มาจาก DECODE ครอบด้วย `CAST AS CHAR(1)` ให้ type ยังเป็นแบบเดิม

## ผลตรวจบน PREPROD (2026-11-03)
| ตรวจ | ผล |
|---|---|
| DDL ปัจจุบันบน PREPROD = `rollback_*.sql` | ตรง (ไม่นับช่องว่าง) |
| type / ขนาดคอลัมน์ 28 คอลัมน์ | ตรงทุกคอลัมน์ |
| Q1 จำนวนแถว + hash แยกตามประเภท/ฝั่ง (10 กลุ่ม, 567 แถว) | MATCH ทุกกลุ่ม |
| Q2 multiset diff ทุกคอลัมน์ | 0 แถว |

| เวลา (ปี 69, `ROUNDNO LIKE '69%'`, 499 แถว) | เดิม | ใหม่ |
|---|---|---|
| EXPLAIN PLAN (hard parse อย่างเดียว) รอบ 1 / 2 | 56.3 / 56.4 วิ | 6.8 / 7.4 วิ |
| query ครั้งแรก (parse + execute) | 53.0 วิ | 8.9 วิ |
| query ซ้ำ (cursor ยังอยู่) | 2.1 วิ | 2.0 วิ |

ข้อจำกัด: ผลที่เทียบได้ตรงกันเป็นของข้อมูลบน PREPROD ณ วันนี้เท่านั้น เคสที่ข้อมูลยังไม่มี
(เช่น โอนเงินกลับหลายปีที่มี GIVERID) ยืนยันได้ด้วยการไล่ logic ในหัวไฟล์ deploy เท่านั้น

## ไฟล์
- `deploy_OAGWBG_R_BUDGETADJUST.sql` — view ใหม่
- `rollback_OAGWBG_R_BUDGETADJUST.sql` — DDL เดิม (ตรงกับ PREPROD 2026-11-03)
- `compare_OAGWBG_R_BUDGETADJUST.sql` — Q1/Q2 ซึ่ง SELECT ใหม่ฝังอยู่ใน `WITH N AS (...)` แล้ว **ต้องรันก่อน deploy**
  สร้างจากไฟล์ deploy ถ้าแก้ไฟล์ deploy ต้องสร้างไฟล์นี้ใหม่ (Q1/Q2 ใช้เวลา ~105 วิต่อตัว เพราะต้อง parse view เดิม)

## ยังไม่ได้ทำ
- deploy view บน PREPROD / PROD — ให้ DBA รัน `deploy_*.sql` แล้วเช็ค `USER_OBJECTS.STATUS = 'VALID'`
  - ก่อน deploy PROD ให้รัน compare บน PROD ก่อน และเทียบ DDL ปัจจุบันบน PROD กับไฟล์ rollback ด้วย
- ไม่มีการแก้ C# (entity / LINQ ใช้ได้เหมือนเดิม เพราะชื่อและ type ของคอลัมน์ไม่เปลี่ยน)
