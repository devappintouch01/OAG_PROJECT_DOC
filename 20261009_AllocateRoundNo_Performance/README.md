# dropdown เลขที่โอน / รายงานโอนเงินจัดสรร ช้า (2026-10-09)

## อาการ
หน้า "รายงานโอนเงินจัดสรรฯ" และ "รายละเอียดการโอนเงินจัดสรรฯ": เมื่อเลือก**หน่วยงาน**หรือ**ศูนย์ต้นทุน**
dropdown เลขที่โอน (`MasterService.GetAllocateRoundNoWithFilter`) ใช้เวลาราว 2 นาทีจึงจะโหลดเสร็จ

## สาเหตุ
- กรณีมีตัวกรองระดับรายการ เมธอดนี้ query `SELECT DISTINCT ROUNDNO` จาก view รายงาน `OAGWBG_R_BUDGETALLOCATETRANSFER`
  ซึ่งใช้ราว 130 วินาทีต่อครั้ง (PREPROD ปี 2569 มี 54,722 แถว)
- ตัวหลักใน view คือ join ศูนย์ต้นทุนแบบ `OR`:
  `CC.ID = BR.COSTCENTERID OR (BR.COSTCENTERID IS NULL AND BATC.REF IS NOT NULL AND CC.ID = BATC.COSTCENTERID)`
  - Oracle hash join เงื่อนไข OR ไม่ได้ จึงวนเทียบกับ view ศูนย์ต้นทุนทีละแถว
  - เมื่อแยกวัด join นี้ตัวเดียว: 1.2 วินาที → 22.5 วินาที

## สิ่งที่แก้

### 1. โค้ด: slow path ของ dropdown (โอนจัดสรร) — `MasterService.GetAllocateTransferRoundNoByCategoryAsync`
กรองหัวใบด้วย `ID IN (รายการ LEFT JOIN OAGWBG_BUDGETRECEIVE)` แทนการอ่าน view รายงาน
เงื่อนไขแต่ละตัวเขียนให้ตรงกับคอลัมน์ของ view เดิม:

| ตัวกรอง | view เดิม | แบบใหม่ |
|---|---|---|
| แผนงาน / ผลผลิต / กิจกรรม / รหัสงบ / แหล่งเงิน | คอลัมน์ของ BATC | เหมือนกัน |
| หน่วยงาน | `COALESCE(BATC.DEPARTMENTID, BR.DEPARTMENTID)` | เหมือนกัน (BR = ตาราง BUDGETRECEIVE) |
| ศูนย์ต้นทุน | `CC.ID` จาก join แบบ OR | `r.COSTCENTERID = :cc OR (r.COSTCENTERID IS NULL AND c.REF IS NOT NULL AND c.COSTCENTERID = :cc)` |

ข้อสมมติ: ศูนย์ต้นทุนที่ส่งมามีอยู่ใน `OAGWBG_V_EXT_OAGGL_COST_CENTER_V` เพราะ dropdown ดึงมาจาก view นี้

โอนจัดสรรเพิ่มเติมยังอ่าน view รายงานเหมือนเดิม (ใช้ราว 1.8 วินาที) แค่แยกออกเป็น `GetAllocateTransferMoreRoundNoFromReportAsync`

### 3. โค้ด: fast path (ไม่มีตัวกรองระดับรายการ) — `FilterAllocateTransferHeaders`
อ่าน `OAGWBG_BUDGETALLOCATETRANSFER` ตรง ๆ แทน `OAGWBG_V_BUDGETALLOCATETRANSFER`
view นั้นไม่มี WHERE มีแค่ GROUP BY รวมยอด BUDGETRECEIVE จึงได้ ROUNDNO ชุดเดียวกัน (เร็วขึ้นเล็กน้อย ราว 25 → 11 ms)

### 2. DB: `OAGWBG_R_BUDGETALLOCATETRANSFER` — **ยังไม่ได้ deploy รอ DBA**
- `deploy_OAGWBG_R_BUDGETALLOCATETRANSFER.sql`: เปลี่ยน join CC จาก OR เป็น
  `CC.ID = CASE WHEN BR.COSTCENTERID IS NOT NULL THEN BR.COSTCENTERID WHEN BATC.REF IS NOT NULL THEN BATC.COSTCENTERID END`
  ส่วนอื่นเหมือนเดิมทุกตัวอักษร
- `rollback_OAGWBG_R_BUDGETALLOCATETRANSFER.sql`: DDL ก่อนแก้ ดึงจาก `DBMS_METADATA.GET_DDL` บน PREPROD วันที่ 2026-10-09
- ช่วยรายงานทั้ง 3 ตัวที่อ่าน view นี้ด้วย
- ข้อจำกัด: แม้แก้ view แล้ว query แบบ "กรองหน่วยงาน + DISTINCT ROUNDNO" ผ่าน view ยังใช้ 108 วินาที
  เพราะ Oracle เลือก plan ไม่ดี จึงต้องแก้ข้อ 1 ในโค้ดด้วย

## ผลตรวจบน PREPROD

### dropdown — เรียก `MasterService.GetAllocateRoundNoWithFilter` จริง (harness) ปี 2569

| เคส | เดิม | ใหม่ | ผล |
|---|---|---|---|
| ไม่กรองเพิ่ม (fast) | 25 ms | 43 ms* | ROUNDNO ตรงกันทุกตัว (2,383) |
| ภาค 01 (fast) | 13 ms | 59 ms* | ตรงทุกตัว (161) |
| วันที่โอน 17/08/2569 (fast) | – | 38 ms | ตรงทุกตัว (112) |
| หน่วยงาน 2900600000 | 111 วินาที | 109 ms | count/sum ตรง (607) |
| ภาค 01 + ศูนย์ต้นทุน 2906999999 | 4.2 วินาที | 65 ms | ตรง (5) |
| ผลผลิต 21000 | 131 วินาที | 65 ms | ตรง (1,199) |
| ภาค 99 + หน่วยงาน | 111 วินาที | 36 ms | ตรง (607) |
| โอนจัดสรรเพิ่มเติม + ผลผลิต 21000 | 1.8 วินาที | 1.85 วินาที | ตรง (29) — ไม่ได้แก้ |

\* เวลาของ fast path ในตารางนี้รวม overhead ของ EF แล้ว ส่วน "เดิม" เป็น SQL ล้วน จึงเทียบกันตรง ๆ ไม่ได้
  เมื่อวัด SQL ล้วนทั้งคู่: view 25 ms กับตาราง 11 ms

### view — SELECT ของไฟล์ deploy เทียบกับ view ปัจจุบัน
เทียบด้วย SUM(ORA_HASH(ทุกคอลัมน์ต่อกัน)) + COUNT

| ขอบเขต | แถว | hash | เดิม | ใหม่ |
|---|---|---|---|---|
| ทั้งหมด | 54,742 | ตรง | 134.7 วินาที | 3.8 วินาที |
| ปี 2569 ภาค 01 | 4,822 | ตรง | 95.8 วินาที | 3.3 วินาที |
| ปี 2569 เลขที่โอน 6910001 | 1,009 | ตรง | 3.8 วินาที | 3.3 วินาที |

## ข้อสังเกต (ยังไม่แก้)
- planId mapping ใน `GetAllocateRoundNoWithFilter` แปลง "20000" เป็น id config (3124)
  แต่ `PLANID` ใน view / `BATC.BUDGETPLANID` เป็น 10000/20000/30000/90000 ถ้าส่ง planId มาจะได้ผลว่างเสมอ
  - ตอนนี้ไม่มีหน้าไหนส่ง planId มา โค้ดใหม่จึงคงพฤติกรรมเดิมไว้
- ข้อความใน dropdown: fast path แสดง "เลขที่โอน" ส่วน slow path แสดง "ครั้งที่" (คงไว้เหมือนเดิม)
- ไม่มี index ที่ `OAGWBG_BUDGETALLOCATETRANSFER_CATEGORY.BUDGETALLOCATETRANSFERID` และ
  `OAGWBG_BUDGETRECEIVE.BUDGETALLOCATETRANSFERCATEGORYID` ตอนนี้ข้อมูลยังน้อย (4.6k / 56k แถว) จึงยังไม่ใช่ปัญหา

## ยังไม่ได้ทำ
- deploy view (ข้อ 2) — ให้ DBA รัน `deploy_*.sql` แล้วเช็คว่า `USER_OBJECTS.STATUS = 'VALID'`
- checkin TFS: `OAGBudget.API\Services\Repository\MasterService.cs`
