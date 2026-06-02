# Roadmap: Issue #279 - Interface Encumbrance เงินกัน STEP2
**วันที่**: 2026-06-02  
**ประเด็น**: ปรับช่อง `USER_JE_CATEGORY_NAME = Budget - เงินกัน`

---

## 1. สรุปปัญหา (Root Cause)

### ไฟล์อ้างอิง (SQL Spec)
ใน SQL View ทั้งสองไฟล์กำหนดค่า `USER_JE_CATEGORY_NAME` ไว้ชัดเจน:

**`OAGWBG_V_BUDGET_OVERLAPYEAR_DETAIL_INTERFACE.sql`** (Region P)  
**`OAGWBG_V_BUDGET_OVERLAPYEAR_CENTRAL_DETAIL_INTERFACE.sql`** (Region C)
```sql
CASE
    WHEN T.DOC_TYPE = 'ENC' THEN 'Web Encumbrance'
    ELSE 'Budget - เงินกัน'
END AS USER_JE_CATEGORY_NAME
```

กล่าวคือ:
| DOC_TYPE | ACTUAL_FLAG | USER_JE_CATEGORY_NAME |
|----------|-------------|----------------------|
| ENC      | E           | `Web Encumbrance`    |
| BG       | B           | `Budget - เงินกัน`  |

---

### สถานะปัจจุบันใน C# Code (`BudgetService.cs`)

#### ปัญหาที่พบ:

**จุดที่ 1 — Region P, Step 1 (BG batch)**
- **ไฟล์**: `OAGBudget.API/Services/Repository/BudgetService.cs`
- **บรรทัด**: ~10084
- **code ปัจจุบัน**:
  ```csharp
  const string userJeCategoryName = "Budget";
  ```
- **บรรทัดที่ใช้งาน**: ~10159
  ```csharp
  UserJeCategoryName = userJeCategoryName,   // ได้ค่า "Budget"
  ```
- **ปัญหา**: ค่า `"Budget"` ไม่ตรงกับ spec ที่กำหนดว่าควรเป็น `"Budget - เงินกัน"`

**จุดที่ 2 — Region C, Part 1 ขาด Step 2 (BG batch)**
- **บรรทัด**: ~10338
  ```csharp
  string batchName2 = $"BG_CARRY_FORWARD_{header.Budgetyear}_{ts2}";
  ```
- **ปัญหา**: `batchName2` ถูก declare ไว้ แต่ใน Part 1 Standard Processing ของ Region C ไม่มีโค้ดที่ใช้ `batchName2` เลย — **Step 2 (BG batch) ขาดหายไปทั้ง block**
- SQL view กำหนดให้มีทั้ง ENC row และ BG row แต่โค้ด C# ใน Part 1 ส่งเฉพาะ ENC row (Step 1 เท่านั้น)

#### สรุปสถานะ 4 จุดใน code:
| Region | Step | Batch | ActualFlag | UserJeCategoryName (ปัจจุบัน) | ถูกต้อง? |
|--------|------|-------|------------|-------------------------------|----------|
| P | Step 1 (B) | `BG_CARRY_FORWARD_...` | B | `"Budget"` (ผ่าน constant) | **ผิด** — ควรเป็น `"Budget - เงินกัน"` |
| P | Step 2 (E) | `ENC_CARRY_FORWARD_...` | E | `"Web Encumbrance"` | ถูก |
| C | Step 1 (E) | `ENC_CARRY_FORWARD_...` | E | `"Web Encumbrance"` | ถูก |
| C | Step 2 (B) | `BG_CARRY_FORWARD_...` | B | **ขาดหาย (ไม่มี code)** | **ผิด** — ควรมี `"Budget - เงินกัน"` |
| C | Step 3 (E) Reversal | `REVERSE_ENC_...` | E | `"Budget - เงินกัน"` | ตรวจสอบเพิ่ม |
| C | Step 4 (B) Reversal | `REVERSE_ENC_...` | B | `"Budget - เงินกัน"` | ถูก |

---

## 2. แผนการแก้ไข (Fix Plan)

### แก้ไขจุดที่ 1: Region P — ปรับค่า constant `userJeCategoryName`
- **ไฟล์**: `OAGBudget.API/Services/Repository/BudgetService.cs`
- **บรรทัด**: ~10084
- **การเปลี่ยนแปลง**:
  ```csharp
  // เดิม
  const string userJeCategoryName = "Budget";
  
  // แก้เป็น
  const string userJeCategoryName = "Budget - เงินกัน";
  ```
- **ผลลัพธ์**: Region P Step 1 (BG batch) จะส่ง `USER_JE_CATEGORY_NAME = "Budget - เงินกัน"` ตรงตาม SQL spec

### แก้ไขจุดที่ 2: Region C Part 1 — เพิ่ม Step 2 (BG batch)
- **ไฟล์**: `OAGBudget.API/Services/Repository/BudgetService.cs`
- **บรรทัด**: หลัง `#endregion` ของ Step 1 (E) (ประมาณบรรทัด ~10410)
- **การเปลี่ยนแปลง**: เพิ่ม `#region Step 2 (B): Create Budget Journal (DR)` สำหรับ Region C Part 1 โดยใช้ `batchName2` ที่ declare ไว้แล้ว:
  - `UserJeCategoryName = "Budget - เงินกัน"`
  - `ActualFlag = "B"`
  - `BudgetEncumbranceName = "OAG_BG_FINAL"`
  - `DefaultEffectiveDate = B_EffectiveDate` (2026-10-01 ตาม spec)
  - Segment4 = `"400"` (ตาม SQL view: `WHEN T.DOC_TYPE = 'BG' THEN '400'`)
  - ลบ segment values จาก category เหมือน Step 1 แต่เปลี่ยน seg4 เป็น `"400"`

---

## 3. Verify แนวทาง

### ตรวจสอบจุดที่ 1 (Region P, constant):
1. หลังแก้ไข ทดสอบ save interface สำหรับ region P
2. ตรวจสอบ `OAGWBG_LOG_INTERFACE` table ว่า row ที่ `ACTUAL_FLAG = 'B'` มี `USER_JE_CATEGORY_NAME = 'Budget - เงินกัน'`

### ตรวจสอบจุดที่ 2 (Region C, Step 2):
1. หลังเพิ่มโค้ด Step 2 ทดสอบ save interface สำหรับ region C
2. ตรวจสอบ `OAGWBG_LOG_INTERFACE` table ว่ามีทั้ง:
   - Row `ACTUAL_FLAG = 'E'` พร้อม `WEB_BATCH_NO LIKE 'ENC_CARRY_FORWARD_%'` และ `USER_JE_CATEGORY_NAME = 'Web Encumbrance'`
   - Row `ACTUAL_FLAG = 'B'` พร้อม `WEB_BATCH_NO LIKE 'BG_CARRY_FORWARD_%'` และ `USER_JE_CATEGORY_NAME = 'Budget - เงินกัน'`

---

## 4. ไฟล์ที่ต้องแก้ไข

| ไฟล์ | บรรทัด | การเปลี่ยนแปลง |
|------|--------|----------------|
| `OAGBudget.API/Services/Repository/BudgetService.cs` | ~10084 | เปลี่ยน `"Budget"` → `"Budget - เงินกัน"` |
| `OAGBudget.API/Services/Repository/BudgetService.cs` | ~10411 | เพิ่ม Step 2 (B) block สำหรับ Region C Part 1 |

---

## 5. ข้อสังเกตเพิ่มเติม

- **Region C Step 3 (Reversal)**: ใช้ `ActualFlag = "E"` แต่ `UserJeCategoryName = "Budget - เงินกัน"` — ซึ่งขัดแย้งกับ SQL spec ที่ ENC → 'Web Encumbrance' ควรตรวจสอบเพิ่มว่า reversal step ใช้ logic ต่างออกไปโดยเจตนาหรือไม่
- การแก้ไข constant `userJeCategoryName` ที่บรรทัด 10084 จะกระทบเฉพาะ Region P Step 1 เท่านั้น (region C ใช้ hardcoded string โดยตรง)
