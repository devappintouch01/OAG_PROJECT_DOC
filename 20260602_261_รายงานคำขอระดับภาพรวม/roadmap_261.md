# Roadmap การแก้ไข: รายงานคำขอ ระดับภาพรวม — เพิ่มช่องรหัส E-Budgeting / รายจ่ายย่อย

## สรุปปัญหา

หน้า **รายงานคำขอ ระดับภาพรวม** (`BudgetRequestSummaryDetail`) แสดงตารางลำดับชั้น 5 ระดับ แต่ยังไม่มีช่องแสดง **รหัส E-Budgeting / รายจ่ายย่อย** (`CODE`) ในระดับที่ 5 (GrandChild / รายละเอียด)

---

## วิเคราะห์สาเหตุ (Root Cause)

### ข้อมูลในฐานข้อมูล — มีอยู่แล้ว
- Database View `OAGWBG_V_BUDGETREQUESTSUMMARY` มีคอลัมน์ `CODE` อยู่แล้ว
- DAL Model `OagwbgVBudgetrequestsummary.cs` มี property `Code` แล้ว (line 52)

### สาเหตุที่ 1: Service Layer — ข้อมูล Code หายไประหว่าง Transform

**ไฟล์:** `OAGBudget.API\Services\Repository\BudgetService.cs`  
**Method:** `GetGroupBudgetSummaryPlan()`

ขั้นตอนการ Transform ข้อมูล:
1. `groupedNormal` → **มี** `Code = g.Any() ? g.Min(x => x.Code) : null` (line 6266) ✅
2. `budgetRequestSummaryGrandChildList` → **ไม่มี** `Code = x.Code` (lines 6296–6319) ❌

ผลลัพธ์: ข้อมูล `Code` ถูกตัดออกในขั้นตอนที่ 2 ก่อนส่งไปแสดงผล

### สาเหตุที่ 2: View — ไม่มีคอลัมน์แสดงผล

**ไฟล์:** `OAGBudget\Views\Budget\_partialView\_tabBudgetRequestSummaryDetail.cshtml`

- Header ของตาราง (lines 21–27): มีคอลัมน์ว่าง (`<th class="text-center"></th>`) ที่ยังไม่ได้ระบุชื่อ
- แถว GrandChild (line 187): มี `<td class="text-center"></td>` ว่างที่ตรงกับคอลัมน์นั้น
- ทุกระดับ (1–4) ก็มีเซลล์ว่างในตำแหน่งเดียวกัน

> **สรุป:** คอลัมน์ว่างที่มีอยู่ใน View ดูเหมือนถูก Placeholder ไว้สำหรับฟีเจอร์นี้อยู่แล้ว เพียงแต่ยังไม่ได้เชื่อมข้อมูลและใส่หัวคอลัมน์

---

## แผนการแก้ไข (Roadmap)

### ขั้นตอนที่ 1 — แก้ไข Service Layer

**ไฟล์:** `OAGBudget.API\Services\Repository\BudgetService.cs`  
**บรรทัดประมาณ:** 6295–6320 (ใน Method `GetGroupBudgetSummaryPlan`)

**การเปลี่ยนแปลง:** เพิ่ม `Code = x.Code` ใน Select ของ `budgetRequestSummaryGrandChildList`

```csharp
// เพิ่มบรรทัดนี้ใน Select ของ budgetRequestSummaryGrandChildList
Code = x.Code,
```

ตำแหน่งที่แนะนำ: เพิ่มหลัง `RefGovernmentid = x.RefGovernmentid` หรือต่อจาก `Description = x.Description`

---

### ขั้นตอนที่ 2 — แก้ไข View (ตารางแสดงผล)

**ไฟล์:** `OAGBudget\Views\Budget\_partialView\_tabBudgetRequestSummaryDetail.cshtml`

#### 2.1 เพิ่มชื่อหัวคอลัมน์ (บรรทัด 22)
เปลี่ยนจาก:
```html
<th class="text-center"></th>
```
เป็น:
```html
<th class="text-center">รหัส E-Budgeting / รายจ่ายย่อย</th>
```

#### 2.2 แสดงข้อมูล Code ในแถว GrandChild (ระดับที่ 5)
เปลี่ยนจาก (บรรทัด 187):
```html
<td class="text-center"></td>
```
เป็น:
```html
<td class="text-center">@detail?.Code</td>
```

**หมายเหตุ:** แถวระดับ 1–4 (Product, Activity, ExpenseType, Category) คงเซลล์ว่างไว้เหมือนเดิม เนื่องจาก Code เป็นข้อมูลในระดับ GrandChild เท่านั้น

---

## ลำดับไฟล์ที่ต้องแก้ไข

| ลำดับ | ไฟล์ | การเปลี่ยนแปลง |
|-------|------|----------------|
| 1 | `OAGBudget.API\Services\Repository\BudgetService.cs` | เพิ่ม `Code = x.Code` ใน GrandChild Select (~line 6318) |
| 2 | `OAGBudget\Views\Budget\_partialView\_tabBudgetRequestSummaryDetail.cshtml` | แก้ header + GrandChild cell |

---

## Verify แนวทาง

1. เปิดหน้า BudgetRequestSummaryDetail
2. ขยายแถวจนถึงระดับที่ 5 (GrandChild)
3. ตรวจสอบว่าคอลัมน์ "รหัส E-Budgeting / รายจ่ายย่อย" แสดงค่าจาก Database View `CODE`
4. ตรวจสอบว่าระดับ 1–4 ไม่มีข้อมูลในคอลัมน์นั้น (แสดงว่าง)
