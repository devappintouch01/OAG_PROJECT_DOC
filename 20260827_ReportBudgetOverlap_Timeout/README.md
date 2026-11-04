# รายงานกันเงินงบประมาณ timeout — ชุดไฟล์แก้ปัญหา (2026-08-27)

สถานะ: **deploy ครบทั้ง 5 view บน PREPROD แล้ว** (`172.16.11.19:1541 / ebs_PRE`) — ยังไม่ขึ้น PROD

---

## ผลลัพธ์ (วัดจริงบน PREPROD)

| Template | View | ก่อน | หลัง |
|---|---|---|---|
| 1 — เงินไว้เบิกเหลื่อมปี | `OAGWBG_R_BUDGETOVERLAP_CATEGORY` | **TIMEOUT > 300 วิ** | **13.3 วิ** ✅ |
| 2 — ขอขยายเวลาเบิกจ่าย | `OAGWBG_R_BUDGETOVERLAP_EXPAND` | 76.4 วิ | **13.1 วิ** ✅ |
| 3 — ผลการเบิกจ่าย | `OAGWBG_R_BUDGETOVERLAP` | 31.6 วิ | **12.1 วิ** ✅ |
| 4 — รายละเอียดเงินกัน | `OAGWBG_R_BUDGETOVERLAP_RESERVED` | 15.7 วิ | **11.9 วิ** ✅ |
| (view กลาง) | `OAGWBG_V_BUDGETRESERVEDITEM` | 14.6 วิ | **11.0 วิ** |

ทุกตัวข้อมูลตรงกับของเดิม **ทุกแถวทุกคอลัมน์** (ตรวจด้วย `MINUS` สองทาง = 0)
จำนวนคอลัมน์เท่าเดิมทุกตัว: 41 / 50 / 45 / 50 / 37

---

## แนวคิดการแก้ (เหมือนกันทั้ง 5 ตัว)

`APPS.OAGPO_TRANSACTION_STATUS_V` (18,507 แถว / ~10 วิ) **push predicate เข้าไปข้างในไม่ได้**
กรอง `PO_NUMBER` เดียวก็ยังใช้ 9.2 วิ เท่ากับ scan ทั้งก้อน — ทุกครั้งที่อ้างถึง = จ่าย 10 วิเต็ม

ของเดิมอ้างมันซ้ำหลายรอบ (สูงสุด 5 รอบใน `_CATEGORY`) และการอ้างซ้ำทำให้ optimizer
ระเบิด plan ไปถึง **54 ล้านแถว / cost 502 ล้าน**

**ทางแก้ 2 ข้อ:**
1. ยก EBS view ไปเป็น CTE `TSV_RAW` → Oracle materialize ลง temp ครั้งเดียว + เป็น optimizer barrier
2. อ่านตาราง `OAGWBG_BUDGETRESERVEDITEM` ตรง ๆ (11 ms) แทน view ที่แพง แล้วคำนวณเฉพาะคอลัมน์ที่ใช้จริง

> ⚠️ **การทำเป็น inline subquery เฉย ๆ ไม่ช่วยเลย — ยัง timeout** เพราะ Oracle merge กลับเข้าคิวรีหลัก
> ต้องเป็น `WITH` CTE เท่านั้น (รายละเอียดในเอกสารวิเคราะห์ ข้อ 5.2 และ 6)

---

## ไฟล์ในโฟลเดอร์นี้

### 🚀 สคริปต์สำหรับรัน (แนะนำใช้ 2 ตัวนี้)

| ไฟล์ | ใช้เมื่อ | ทดสอบแล้ว |
|---|---|---|
| **`deploy_all.sql`** | deploy ทั้ง 5 view ทีเดียว (เรียงลำดับ dependency ให้แล้ว) | ✅ รันจริง **7/7 สำเร็จ** |
| **`rollback_all.sql`** | ย้อนกลับทั้งหมด | ✅ รันจริง **6/6 สำเร็จ** |

> ทั้งคู่ผ่าน **round-trip test จริงบน PREPROD**: deploy → rollback → deploy กลับ
> ไม่ใช่แค่เขียนไว้เฉย ๆ ปิดท้ายด้วย query ตรวจ `STATUS` + จำนวนคอลัมน์ให้อัตโนมัติ

### 📦 ไฟล์แยกรายตัว

| View | DDL ใหม่ | DDL เดิม (rollback) |
|---|---|---|
| `OAGWBG_V_BUDGETRESERVEDITEM` | `create_view_budgetreserveditem_v2.sql` | `rollback_view_budgetreserveditem.sql` |
| `OAGWBG_R_BUDGETOVERLAP_CATEGORY` | `create_view_budgetoverlap_category_v2.sql` | `rollback_view_budgetoverlap_category.sql` |
| `OAGWBG_R_BUDGETOVERLAP_EXPAND` | `create_view_budgetoverlap_expand_v2.sql` | `rollback_view_budgetoverlap_expand.sql` |
| `OAGWBG_R_BUDGETOVERLAP` | `create_view_budgetoverlap_v2.sql` | `rollback_view_budgetoverlap.sql` |
| `OAGWBG_R_BUDGETOVERLAP_RESERVED` | `create_view_budgetoverlap_reserved_v2.sql` | `rollback_view_budgetoverlap_reserved.sql` |

`create_view_budgetoverlap_category_v1_original.sql` = สำเนาไฟล์เดิมที่อยู่ใน solution ก่อนถูกเขียนทับ

### 📄 เอกสาร

| ไฟล์ | เนื้อหา |
|---|---|
| `analysis_view_budgetoverlap_category.md` | วิเคราะห์เต็ม — สาเหตุ, execution plan, ผลวัดจริง, สิ่งที่ลองแล้วไม่ได้ผล, บันทึกการ deploy |

---

## ไฟล์ในโปรเจกต์ (TFS) — **ยังไม่ได้ checkin**

| ไฟล์ | สถานะ | คำสั่ง |
|---|---|---|
| `..\..\create_view_budgetoverlap_category.sql` | แก้ไข | `tf edit` + `tf checkin` |
| `..\..\create_view_budgetoverlap_expand.sql` | **ไฟล์ใหม่** | `tf add` + `tf checkin` |
| `..\..\create_view_budgetreserveditem.sql` | **ไฟล์ใหม่** | `tf add` + `tf checkin` |
| `..\..\create_view_budgetoverlap.sql` | **ไฟล์ใหม่** | `tf add` + `tf checkin` |
| `..\..\create_view_budgetoverlap_reserved.sql` | **ไฟล์ใหม่** | `tf add` + `tf checkin` |

`TF.exe` ไม่มีบนเครื่องที่รันงานนี้ (CLAUDE.md ชี้ `D:\TFS\OAG Budget` แต่ workspace จริงคือ
`C:\Users\thiha\Documents\TFS\OAG Budget`) จึง checkin ให้ไม่ได้

commit message ที่แนะนำ:

```
perf(db): rewrite budget overlap views to fix report timeout

Move APPS.OAGPO_TRANSACTION_STATUS_V into a materialized CTE and read
OAGWBG_BUDGETRESERVEDITEM directly instead of the expensive view.
The EBS view cannot push predicates, so each reference costs ~10s and
the repeated scans blew the optimizer plan up to 54M estimated rows.

Verified with two-way MINUS on every view: 0 rows differ.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```

---

## ⚠️ ก่อนขึ้น PROD ต้องทำ

1. **แก้ N+1 ที่ `ReportService.cs:3924`** — ยิง query ต่อทุกแถวที่ไม่ใช่ Region `'C'` ต้นทุน **4.6 วิ/แถว**
   บน PREPROD ไม่มีแถวแบบนี้เลยยังไม่เจอปัญหา แต่ถ้า PROD มีข้อมูลภูมิภาค →
   `13 + N x 4.6` เกิน 100 วิ ตั้งแต่ **N = 19 แถว**
   → แก้เป็น batch dictionary แบบ Template 3 (`ReportService.cs:4244-4258`)

2. **ตั้ง `client.Timeout` ใน `GetReportFile`** (`OAGBudget\Services\Repository\ReportService.cs:56`)
   ตอนนี้ใช้ default 100 วิ ขณะที่ `BudgetService.cs` ตั้ง 5-30 นาทีไว้กว่า 20 จุด

3. **ตั้ง `CommandTimeout` ฝั่ง API** (`OAGBudget.API\Program.cs:40`)
   ไม่งั้นเมื่อ MVC ตัดที่ 100 วิ Oracle ยังรันต่อ กิน session ทิ้งไว้

4. **verify ค่า `CONTRACT_CARRY_FORWARD_PO` บนข้อมูลจริง**
   บน PREPROD คอลัมน์นี้เป็น `NULL` ทั้ง 60 แถว การเทียบ `MINUS` จึงยืนยันได้แค่ว่า
   "ไม่ต่างกันบนข้อมูลชุดนี้" — น่าสังเกตว่า join ที่แพงที่สุดกลับให้ `NULL` ทุกแถว
   ควรถาม business ว่ายังจำเป็นไหม ถ้าไม่ ตัดทิ้งได้เลย จะเร็วกว่านี้อีก

5. **เก็บ DDL เดิมของ PROD ก่อนรัน** — `rollback_all.sql` เป็น DDL ของ PREPROD ไม่ใช่ของ PROD
   ```sql
   SELECT TEXT FROM USER_VIEWS WHERE VIEW_NAME = '<ชื่อ view>';
   ```

6. **ยังไม่ได้ทดสอบ export จริงผ่านหน้าจอ** — verify ถึงระดับ SQL เท่านั้น

---

## งานที่ยังเหลือ (เรียงตามความคุ้ม)

| # | งาน | ผลที่คาด |
|---|---|---|
| 1 | Materialized view ของ `APPS.OAGPO_TRANSACTION_STATUS_V` refresh รายวัน | **ปลดเพดาน ~10 วิ ที่ทั้ง 5 view ชนอยู่ตอนนี้** — น่าจะเหลือหลักวินาที |
| 2 | แก้ N+1 ทั้ง 5 จุดใน `ReportService.cs` | กันรายงานกลับมา timeout บน PROD |
| 3 | `GATHER_SCHEMA_STATS('OAGWBG')` — **121 จาก 125 ตารางไม่มี stats เลย** | optimizer เลิกเดามั่ว |
| 4 | index บน `BUDGETRESERVEDITEM(BUDGETREVERSEDID)`, `(BOOKNUMBER)`, `(PARENTID)` | ตอนนี้มีแค่ PK |

> ทั้ง 5 view ตอนนี้อยู่ที่ 11-13 วินาทีเกือบเท่ากันหมด เพราะชนเพดานเดียวกัน
> คือเวลา scan `APPS.OAGPO_TRANSACTION_STATUS_V` หนึ่งรอบ — ข้อ 1 จึงเป็นทางเดียวที่จะลดต่อได้อีก
