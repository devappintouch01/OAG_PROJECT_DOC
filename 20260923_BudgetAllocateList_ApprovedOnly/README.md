# หน้า พ.ร.บ. — โครงการที่ยังไม่อนุมัติขึ้นมาแสดง (ปี 2570)

**วันที่:** 2026-09-23
**View:** `OAGWBG.OAGWBG_V_BUDGETALLOCATELIST`
**สถานะ:** ✅ deploy บน **PROD** แล้ว (ดูหัวข้อ "บันทึกการ deploy" — deploy โดยไม่ได้ตั้งใจ)
**ยังไม่ได้ deploy:** PREPROD, UAT, TEST

---

## 1. อาการ

หน้า **รายละเอียดงบประมาณประจำปี** (พ.ร.บ.) แสดงแถว ปี 2570 / โครงการ
ยอด **299,728,236.00** สถานะ "อยู่ระหว่างรอพิจารณา"

แต่คำขอทั้ง 15 ใบที่ป้อนแถวนั้น **ไม่มีใบไหนอยู่สถานะอนุมัติเลย**

| สถานะคำขอ | ใบ | รายการ | ยอด |
|---|---|---|---|
| 20101 ส่งเรื่องให้สำนักบริหารงบประมาณ | 3 | 5 | 107,278,430.00 |
| 20102 สำนักบริหารงบประมาณดำเนินการแก้ไข | 12 | 49 | 192,449,806.00 |
| **รวม** | **15** | **54** | **299,728,236.00** |

---

## 2. Root Cause

เงื่อนไขเดิมใน CTE `LatestBG`:

```sql
AND ( BG.BUDGETSTATUS IN ('B','C','R')
      OR ( BG.PROJECTID IS NOT NULL AND BG.BUDGETSTATUS = 'U' ) )
```

สาขา `'U'` มีไว้รับโครงการที่เพิ่งถูกอนุมัติ — เพราะตอนอนุมัติ
`DuplicateProjectsInRequest` ([BudgetService.cs:35417](../../OAGBudget.API/Services/Repository/BudgetService.cs#L35417))
จะ copy `Budgetstatus = oldGov.Budgetstatus` (= `'U'`) มาตรง ๆ และไม่มีใครพลิกเป็น `'B'`

**ปัญหาคือ 2 รูรั่วซ้อนกัน:**

1. **ไม่มีโค้ดล้าง `OAGWBG_PROJECT.TEMP` เลย** — grep `Temp = ` ทั้ง solution เจอจุดเดียวคือตอนสร้าง
2. **`UpdateBudgetRequestStatus(20102)` ไม่แตะ `BUDGETSTATUS`** — มีแต่ `StatusId == 10102`
   ที่เซ็ต gov เป็น `'A'` ([BudgetService.cs:34184](../../OAGBudget.API/Services/Repository/BudgetService.cs#L34184))

### ไทม์ไลน์ที่เกิดจริงบน PROD

```
2026-09-01 11:34–11:46   อนุมัติ (20201) 15 ใบ
                         -> DuplicateProjectsInRequest สร้างคู่แฝด TEMP 54 รายการ
                         -> ขึ้นหน้า พ.ร.บ. (ถูกต้องตามดีไซน์)

2026-09-21 ~ 09-22       สงป. ส่งกลับไปแก้ไข (20102) 12 ใบ
                         -> สร้าง "คำขอลูก" 1775,1779,1780,1782,1784,1785,
                            1787,1791,1792,1794,1796,1797
                         -> TEMP ไม่ถูกล้าง + gov ยังเป็น 'U'
                         -> ยังค้างบนหน้า พ.ร.บ.
```

คำขอแม่ถูกกันออกด้วยเงื่อนไข `NOT EXISTS (child)` อยู่แล้ว
แต่**คำขอลูกรับช่วงต่อพร้อม TEMP ที่ติดมาด้วย** จึงยังโผล่

---

## 3. การแก้ (ทางเลือก A — แก้ที่ view)

ใส่เงื่อนไขว่า สาขา `'U'` ต้องมีคำขอต้นทางอยู่สถานะ **20201** เท่านั้น

```sql
AND (
        BG.BUDGETSTATUS IN ('B','C','R')
        OR (
            BG.PROJECTID IS NOT NULL
            AND BG.BUDGETSTATUS = 'U'
            AND EXISTS (
                SELECT 1
                FROM OAGWBG_BUDGETREQUEST BRA
                WHERE BRA.ID = BG.BUDGETREQUESTID
                  AND BRA.STATUSID = 20201
            )
        )
    )
```

### ทำไมไม่ใส่ `EXISTS` แบบเหมารวมทั้งก้อน

เพราะจะทำให้แถวที่ไม่ผูกกับคำขอหายไปด้วย — ตรวจข้อมูล PROD แล้วมีจริง:

| ปี | FT | BSTAT | ผูกกับคำขอ | จำนวน |
|---|---|---|---|---|
| 2569 | 1 | C | **NO_REQ_ROW** | **1** |
| 2569 | 1 | C | REQ_20201 | 9,647 |
| 2569 | 2 | C | REQ_20201 | 44 |
| 2570 | 2 | U | REQ_20101 | 5 |
| 2570 | 2 | U | REQ_20102 | 49 |

แถว `NO_REQ_ROW` คือ gov สังเคราะห์ที่สร้างโดย
[BudgetService.cs:4956](../../OAGBudget.API/Services/Repository/BudgetService.cs#L4956)
(`Budgetrequestid = 0`, `Budgetdetail = "รายการจัดสรร พรบ"`) — `0` ไม่ใช่ `NULL`
จึงผ่านเงื่อนไข `BUDGETREQUESTID IS NOT NULL` เดิม

การแก้แบบ surgical จึงแตะเฉพาะสาขา `'U'` ไม่กระทบ `B`/`C`/`R`

---

## 4. ผลการ verify บน PROD

### ก่อน / หลัง

| | ปี | FT | สถานะ | คำขอ | จัดสรร |
|---|---|---|---|---|---|
| ก่อน | 2569 | 1 | บันทึกการจัดสรร | 21,011,775,000.00 | 15,000,461,400.00 |
| ก่อน | 2569 | 2 | บันทึกการจัดสรร | 109,356,663.00 | 109,356,663.00 |
| ก่อน | **2570** | **2** | **อยู่ระหว่างรอพิจารณา** | **299,728,236.00** | **299,728,236.00** |
| หลัง | 2569 | 1 | บันทึกการจัดสรร | 21,011,775,000.00 | 15,000,461,400.00 |
| หลัง | 2569 | 2 | บันทึกการจัดสรร | 109,356,663.00 | 109,356,663.00 |

### MINUS สองทาง

```
OLD MINUS NEW -> 1 แถว : 2570 | 299728236 | 299728236 | U | อยู่ระหว่างรอพิจารณา | 2 | โครงการ
NEW MINUS OLD -> 0 แถว
```

ตัดออกเฉพาะแถวที่ตั้งใจ ยอดปี 2569 ไม่ขยับแม้แต่บาทเดียว

---

## 5. บันทึกการ deploy (ต้องอ่าน)

⚠️ **การ deploy บน PROD เกิดขึ้นโดยไม่ได้ตั้งใจ**

สคริปต์ที่ตั้งใจใช้เป็น "simulation" (รัน SELECT ของ view ใหม่เทียบของเดิม)
ตัดหัว `CREATE OR REPLACE` ออกไม่หมด เพราะ DDL จาก `DBMS_METADATA.GET_DDL`
ขึ้นต้นด้วยบรรทัดว่าง ทำให้ `sed -n '2,$p'` ยังเหลือบรรทัด `CREATE` ไว้
เครื่องมือ query กันแค่ `UPDATE/DELETE/INSERT/MERGE` ไม่ได้กัน `CREATE OR REPLACE`
คำสั่งจึงรัน DDL จริงบน PROD

**แก้ไขแล้ว:** เครื่องมือ query บังคับให้ต้องขึ้นต้นด้วย `SELECT`/`WITH`
และปฏิเสธ keyword `create/replace/alter/drop/truncate/grant/revoke/begin/declare/call`
เพิ่มจากเดิม

ผลลัพธ์ที่ได้ตรงกับทางเลือก A ที่ตกลงกันไว้ และ verify ผ่านแล้ว
แต่ขั้นตอนไม่ถูกต้อง — ไม่ได้ขอยืนยันก่อนแตะ PROD

---

## 6. Rollback

```
sqlplus OAGWBG/<pwd>@PROD @rollback_OAGWBG_V_BUDGETALLOCATELIST.sql
```

ไฟล์ `rollback_*.sql` คือ DDL ต้นฉบับที่ดึงสดจาก PROD ก่อนแก้ ไม่ได้ดัดแปลงใด ๆ

---

## 7. ที่ยังไม่ได้ทำ / ต้องตามต่อ

### 7.1 ยังไม่ deploy environment อื่น
PREPROD / UAT / TEST ยังเป็น DDL เดิม

### 7.2 ⚠️ `DuplicateProjectsInRequest` ไม่มี idempotency guard

[BudgetService.cs:35417](../../OAGBudget.API/Services/Repository/BudgetService.cs#L35417)
ไม่เช็คว่าเคย duplicate ไปแล้วหรือยัง

**นี่สำคัญมากหลังแก้ view** — เพราะคำขอ 15 ใบนั้นตอนนี้หายจากหน้า พ.ร.บ.
พอ สงป. อนุมัติใหม่ `DuplicateProjectsInRequest` จะรันอีกรอบบนคำขอที่**มีคู่แฝดอยู่แล้ว**
→ ได้คู่แฝดของคู่แฝด → โครงการและยอดเงินอาจเบิ้ล

แนะนำให้ใส่ guard ก่อนที่ สงป. จะกดอนุมัติรอบใหม่:

```csharp
private async Task DuplicateProjectsInRequest(int budgetRequestId, int? userId)
{
    if (await _context.OagwbgProjects.AnyAsync(p => p.Budgetrequestid == budgetRequestId && p.Temp != null))
        return;
    ...
```

### 7.3 ต้นเหตุจริงยังอยู่ (ทางเลือก B)
view ที่แก้เป็นการกันเลือด ไม่ได้แก้ที่ต้นเหตุ — ตอนถอยสถานะยังไม่มีการล้าง TEMP
ถ้าจะแก้ถาวรต้องตัดสินใจเชิง business ก่อนว่า
"พอ สงป. ส่งกลับไปแก้ไข งานจัดสรรที่ทำไปแล้วควรถูกทิ้งหรือเก็บไว้"

### 7.4 `MAX(BG.BUDGETSTATUS)` เป็น string max
`BUDGETALLOCATESTATUS` คำนวณจาก `MAX(BG.BUDGETSTATUS)` ซึ่งเรียงตัวอักษร
(`'A' < 'B' < 'C' < 'R' < 'U'`) ถ้าปีไหนมีแถวคละกัน แถว `'U'` แถวเดียว
จะกลบทั้งปีให้แสดง "อยู่ระหว่างรอพิจารณา" — ยังไม่ได้แก้ในรอบนี้
