# การจัดการสิทธิ — โอนงปม. เข้าบัญชีเงินกัน (BudgetOverlapYearCentral)

วันที่วิเคราะห์ : 2026-09-24
DB ที่ตรวจ : **PREPROD** `172.16.11.19:1541 / ebs_PRE / OAGWBG` (ต่อผ่าน F5 BIG-IP Edge Client)
ไฟล์ประกอบ : [`ddl_permission_objects.sql`](ddl_permission_objects.sql) · [`deploy_grant_menu201_role11.sql`](deploy_grant_menu201_role11.sql)

---

## สถานะปัจจุบัน (2026-09-24)

| เรื่อง | สถานะ |
|---|---|
| แก้โค้ด `IsEdit` (ข้อ 1) | ✅ แก้ + compile ผ่านแล้ว · **ยังไม่ checkin** (TFS server ติดต่อไม่ได้ขณะต่อ F5 VPN) |
| แยก `IsEdit` / `IsConsider` ตามคำตอบ Q3 (§4) | ✅ แก้ + compile ผ่านแล้ว · **ยังไม่ checkin** |
| สิทธิเมนู 201 ให้ role 11 (ข้อ 2) | ⏸️ เคย INSERT แล้ว (ID 307, 11:31:08) และ **rollback ออกแล้ว** — ดู §Deployment log |
| โค้ดกรองตามศูนย์ต้นทุน | ⏸️ ยังไม่ทำ รอคำตอบ Q1/Q2 จาก BA |
| guard ฝั่ง API | ⏸️ ยังไม่ทำ รอสั่ง — ดู §4 |

### Deployment log

| เวลา | การกระทำ | ผล |
|---|---|---|
| 11:31:08 | `INSERT (11, 201)` → ID 307 | role 11: 25→26 แถว · รวม 300→301 · verify ผ่านครบ 4 ข้อ |
| หลังจากนั้น | `DELETE ID=307` + COMMIT (มี guard `SQL%ROWCOUNT=1` ไม่งั้น rollback) | role 11: 26→**25** · รวม 301→**300** · `MAX(ID)` 307→**306** · `OAGWBG_FN_BOOKINGSYSTEMMENU(371,2)` กลับมาได้ 2 แถว (35, 213) |

**เหตุผลที่ rollback:** ระหว่างตรวจหลัง INSERT พบว่าการเปิดเมนูไม่ได้เปิดแค่สิทธิ "ดู" แต่เปิดสิทธิ **"แก้ไข"** ไปด้วย (ดู §3) จึงถอยกลับไปทำโค้ดกรองให้เสร็จก่อน

---

## สรุป 2 ประเด็นจาก UAT

| # | อาการที่แจ้ง | สาเหตุจริง | แก้ที่ไหน | สถานะ |
|---|---|---|---|---|
| 1 | สำนักบริหารงบประมาณ **ยังกดอนุมัติได้** ทั้งที่ควรดูอย่างเดียว | โค้ดเทียบ `Rolelevel != 31` แต่ 31 คือ **role ID** ไม่ใช่ ROLELEVEL → ไม่มี role ใดเข้าเงื่อนไข → `IsEdit` เป็น true ตลอด | โค้ด C# (2 บรรทัด) | ✅ แก้แล้ว รอ checkin |
| 2 | ศูนย์ต้นทุน **เมนูไม่ขึ้น** | ไม่มีแถว `(SYSTEMROLEID=11, SYSTEMMENUID=201)` ใน `OAGWBG_SYSTEMMENUROLEASSIGN` | **ข้อมูลบน DB** ไม่ใช่โค้ด | 🟡 มีสคริปต์ รอสั่งรัน |

---

## 1. สำนักบริหารงบประมาณยังกดอนุมัติได้

### หลักฐานจาก DB (ไม่ใช่การเดา)

`SELECT ID, ROLENAME, ROLELEVEL FROM OAGWBG_SYSTEMROLE` บน PREPROD:

| ID | ROLENAME | ROLELEVEL | ACTIVE |
|---|---|---|---|
| 11 | ศูนย์ต้นทุน | 10 | 1 |
| 31 | **สำนักบริหารงบประมาณ** | **20** | 1 |
| 41 | ผู้ดูแลระบบ | 30 | 1 |
| 51 | สำนักยุทธศาสตร์ นโยบาย และแผน | 40 | 1 |
| 61 | **สำนักการคลัง** | **50** | 1 |
| 21 | สนง.บริหารเงินนอกงบประมาณฯ | 100 | 1 |
| 1 | ผู้ดูแลระบบ1 | 200 | 0 |

**ไม่มี role ใดที่ `ROLELEVEL = 31`** — ค่า 31 คือ `ID` ของสำนักบริหารงบประมาณ

### จุดบั๊ก

`OAGBudget/Controllers/BudgetController.cs` — 2 ที่ (บรรทัด 3305 และ 3362 ของเดิม)

```csharp
data.IsEdit = userCur?.UserRole?.Rolelevel != 31;   // ❌ เทียบผิดคอลัมน์ → true เสมอ
```

`IsEdit` ไปคุมปุ่ม 3 ปุ่มใน `BudgetOverlapYearCentralDetail.cshtml` (บรรทัด 447 / 477 / 492)
ตอน `pageType == "2"` (หน้าพิจารณา) คือ **ส่งเรื่องกลับ / ยืนยัน / ยกเลิกการยืนยัน**
→ เมื่อ `IsEdit` เป็น true ตลอด สำนักบริหารงบประมาณจึงเห็นและกดปุ่มยืนยันได้

### การแก้

```csharp
data.IsEdit = userCur?.UserRole?.Id != 31;          // ✅ ตรงตาม convention ของระบบ
```

เทียบด้วย `UserRole?.Id` เป็นรูปแบบที่ระบบใช้อยู่แล้วทุกที่ เช่น
`BudgetTransferDetail.cshtml:13`, `_tableBudgetAllocate.cshtml:6`, `BudgetController.cs:2861`

แก้ทั้ง **2 จุด** เพราะหน้าพิจารณา (`_tableBudgetOverlapYearConsider.cshtml:150`) ส่งผู้ใช้ไป
`BudgetOverlapYearCentralDetail` (region "C") หรือ `BudgetOverlapYearPO` (region "P") ด้วย
`pageType=2` เหมือนกัน — เป็น flow อนุมัติเดียวกัน กติกาสิทธิจึงต้องตรงกัน

### ผลหลังแก้ (ตรงตาม requirement พอดี)

เมนู 215 "พิจารณากันเงินเหลื่อมปี" ผูกกับ role 1 / 31 / 61 เท่านั้น
เมื่อตัด 31 ออกจากสิทธิแก้ไข → เหลือ **สำนักการคลัง (61)** กดอนุมัติได้
ส่วนสำนักบริหารงบประมาณ (31) ยังเข้าหน้าดูได้แต่ไม่มีปุ่ม

### ⚠️ ข้อจำกัดที่ยังเหลือ — ต้องตัดสินใจ

`ConfirmBudgetReserved` ใน `OAGBudget.API/Services/Repository/BudgetService.cs:29275`
**ไม่มีการตรวจ role ฝั่ง server เลย** — การแก้ครั้งนี้แค่ซ่อนปุ่มบนหน้าจอ
ถ้ายิง API ตรงยังยืนยันได้อยู่ ถ้าต้องการปิดจริงต้องเพิ่ม guard ใน service ด้วย (งานแยก)

---

## 2. ศูนย์ต้นทุน — เมนู "โอนงปม. เข้าบัญชีเงินกัน" ไม่ขึ้น

### หลักฐาน

เมนูซ้ายมือ render จาก `OAGWBG_FN_BOOKINGSYSTEMMENU(userId, 2)`
(`OAGBudget/Components/CategoryMenu.cs:37` → `RawDataService.cs:77`)
ซึ่ง join `SYSTEMUSERROLEASSIGN` → `SYSTEMMENUROLEASSIGN` → `SYSTEMMENU`

สิทธิเมนูใต้หัวข้อ "กันเงินเหลื่อมปี" (menu 213) ณ ปัจจุบัน:

| menu | ชื่อ | role ที่มีสิทธิ |
|---|---|---|
| 213 | กันเงินเหลื่อมปี (หัวข้อ) | 1, 11, 31, 61 |
| 35 | กันเงิน/ขยายระยะเวลา | 1, 11, 31, 61 |
| **201** | **โอนงปม. เข้าบัญชีเงินกัน** | **1, 31, 61 — ไม่มี 11** |
| 215 | พิจารณากันเงินเหลื่อมปี | 1, 31, 61 |

ทดสอบด้วย user จริงที่ถือ role 11 อย่างเดียว (user id 371 / username 58011):

```sql
SELECT ID, MENUNAME FROM OAGWBG_FN_BOOKINGSYSTEMMENU(371, 2)
WHERE PARENTMENUID = 213 OR ID = 213;
```
ได้ **2 แถว: 35, 213** — ไม่มี 201 ตามที่ผู้ใช้แจ้ง

**ขอบเขตผลกระทบ:** user ที่ถือ role 11 อย่างเดียวมี **822 คน** (จาก 862 คนที่มี role 11)

> **หมายเหตุสำคัญ** — ฟังก์ชันรับ `P_SYSTEMUSERID` ไม่ใช่ role id
> คนที่ถือหลาย role จะได้เมนูเป็น **union ของทุก role** ตอนทดสอบต้องเลือก user
> ที่ถือ role 11 ตัวเดียว ไม่งั้นจะเห็นเมนู 201 ขึ้นแล้วเข้าใจผิดว่าไม่มีปัญหา

### วิธีแก้

เป็น **ข้อมูล ไม่ใช่โค้ด** → รัน [`deploy_grant_menu201_role11.sql`](deploy_grant_menu201_role11.sql)
(มี BEFORE / INSERT / VERIFY 4 ข้อ / ROLLBACK ครบ)

หรือจะให้ admin ติ๊กผ่านหน้า `System/PermissionDetail` ก็ได้ — **แต่ดูข้อควรระวังด้านล่างก่อน**

---

## 3. ⛔ การเปิดเมนู 201 ให้ role 11 = เปิดสิทธิ "แก้ไข" ไปด้วย ไม่ใช่แค่ "ดู"

**นี่คือเหตุผลที่ต้อง rollback** — พบระหว่างตรวจสอบหลัง INSERT

ปุ่ม "บันทึก" ใน `BudgetOverlapYearCentralDetail.cshtml` **ไม่ได้ถูกคุมด้วย `IsEdit` เลย**:

```razor
bool isLocked = Model.Statusid == 20101 || Model.Statusid == 10197;          // บรรทัด 30
...
@if (!isLocked && Model.pageType != "2")                                     // บรรทัด 440
{
    <button type="button" id="btnSave" ...> บันทึก </button>
}
```

ศูนย์ต้นทุนที่เข้าจากเมนู List จะได้ `pageType = "1"` และใบ region "C" ส่วนใหญ่มีสถานะ
20202 / 90201 / 90102 ซึ่ง **ไม่เข้าเงื่อนไข `isLocked`** → ปุ่มบันทึกแสดง

ฝั่ง API ก็ไม่มีด่านตรวจ: `SaveBudgetReservedCentrall`
(`OAGBudget.API/Services/Repository/BudgetService.cs:33400`) อ่าน `userInfo` มาใช้แค่เก็บ
`userId` ลง audit field — **ไม่มี guard เรื่อง role หรือศูนย์ต้นทุน**

→ ถ้าเปิดเมนูโดยไม่แก้โค้ดก่อน user role 11 (822 คน) จะเปิดใบใหญ่ของศูนย์ต้นทุนไหนก็ได้
แล้ว**กดบันทึกทับ**ได้ ไม่ใช่แค่เห็นข้อมูล

> บน PREPROD ผลจำกัด (1 หน่วยเบิกจ่าย · 2 ศูนย์ต้นทุน · 12 ใบ region "C")
> แต่บน PROD ขอบเขตจะกว้างกว่ามาก

---

## 4. แยก "สิทธิแก้ไข" ออกจาก "สิทธิพิจารณา" (ตามคำตอบ Q3)

### ตารางสิทธิเป้าหมาย

| role | ดู | เพิ่ม/แก้ไข | พิจารณา |
|---|---|---|---|
| 11 ศูนย์ต้นทุน | ✅ | ✅ | ❌ |
| 31 สำนักบริหารงบประมาณ | ✅ | ❌ | ❌ |
| 61 สำนักการคลัง | ✅ | ✅ | ✅ |

`IsEdit` ตัวเดียวคุมไม่พอ เพราะศูนย์ต้นทุนกับสำนักการคลังต่างกันแค่มิติ "พิจารณา"
จึงแยกเป็น 2 flag:

```csharp
data.IsEdit     = userCur?.UserRole?.Id != 31;   // เพิ่ม/แก้ไข/ส่งเรื่อง
data.IsConsider = userCur?.UserRole?.Id == 61;   // ยืนยัน/ส่งเรื่องกลับ/ยกเลิกการยืนยัน
```

### ไฟล์ที่แก้

| ไฟล์ | สิ่งที่แก้ |
|---|---|
| `OAGBudget.Models/ViewModel/BudgetReservedCentralViewModel.cs` | เพิ่ม property `IsConsider` |
| `OAGBudget.Models/ViewModel/BudgetReservedViewModel.cs` | เพิ่ม property `IsConsider` |
| `OAGBudget/Controllers/BudgetController.cs` (2 action) | เซ็ตทั้ง `IsEdit` + `IsConsider` |
| `OAGBudget/Views/Budget/BudgetOverlapYearCentralDetail.cshtml` | ปุ่มบันทึก/ส่งเรื่อง → `IsEdit` · ยืนยัน/ส่งเรื่องกลับ/ยกเลิกการยืนยัน → `IsConsider` |
| `OAGBudget/Views/Budget/BudgetOverlapYearPO.cshtml` | เหมือนกัน (หน้าพิจารณาใช้ flow เดียวกัน region "P") |

### ทำไมต้องแยก — ช่องโหว่ที่ปิดไปด้วย

`pageType` เก็บใน Session และรับจาก query string ได้:

```csharp
if (pagetype != null || id == null)
    HttpContext.Session.SetString("BudgetOverlapYearCentralDetail", pagetype ?? "1");
```

ศูนย์ต้นทุนที่ได้สิทธิเมนู 201 สามารถต่อ `?pageType=2` ที่ URL เองเพื่อเข้าหน้าพิจารณาได้
ถ้ายังใช้ `IsEdit` ตัวเดียว (ซึ่งเป็น true สำหรับ role 11) ปุ่มยืนยันจะโผล่ทันที
หลังแยก flag แล้ว role 11 ต่อ `?pageType=2` ก็ไม่เห็นปุ่มพิจารณา

### ⚠️ `UserRole` = role ID **สูงสุด** ที่ user คนนั้นถืออยู่

`AuthenService.cs:254, 361` — `res.UserRole = res.AllUserRole.OrderByDescending(x => x.Id).FirstOrDefault()`
(ทั้งฝั่ง MVC login และฝั่ง validate token ใช้กติกาเดียวกัน จึงไม่ขัดกัน)

ผลกับ user จริงที่ถือ role 31 หรือ 61 บน PREPROD:

| user id | username | roles ที่ถือ | role ที่มีผลจริง | หลังแก้ |
|---|---|---|---|---|
| 507 | 62005 | 11, 31 | **31** | ดูอย่างเดียว ✅ |
| 707 | 62008 | 11, 31 | **31** | ดูอย่างเดียว ✅ |
| 61 | MERCURY | 11, 21, 31, 41, 61 | **61** | แก้ไข + พิจารณาได้ |
| 705 | 62006 | 11, 21, 61 | **61** | แก้ไข + พิจารณาได้ |
| 8259 | 99999 | 11, 21, 31, 41, 51, 61 | **61** | แก้ไข + พิจารณาได้ |

**ข้อสังเกตสำหรับ admin:** user `MERCURY` และ `99999` ถือ role 31 อยู่ด้วย แต่เพราะถือ 61 ด้วย
จึงยัง**พิจารณาได้** — ถ้าเจตนาคือ "คนของสำนักบริหารงบประมาณต้องพิจารณาไม่ได้" ต้องไปจัดการที่
**การ assign role ของ user** ไม่ใช่ที่โค้ด (2 account นี้น่าจะเป็น account ทดสอบ/admin)

### ยังเหลือ — guard ฝั่ง server

ยังไม่ได้ทำ เพราะเป็นการเปลี่ยนพฤติกรรม API (R1) และมีความเสี่ยงบล็อกผู้ใช้ที่ถูกต้องถ้ากติกา
resolve role ไม่ตรงกัน — **รอสั่ง**

| endpoint | ไฟล์ | สภาพ |
|---|---|---|
| `ConfirmBudgetReserved` | `OAGBudget.API/.../BudgetService.cs:29275` | ไม่มี role check |
| `CancelConfirmBudgetReserved` | `OAGBudget.API/.../BudgetService.cs:30280` | ไม่มี role check |
| `SaveBudgetReservedCentrall` | `OAGBudget.API/.../BudgetService.cs:33400` | ไม่มี role/costcenter check |

`_auth.ValidateTokenAndGetUserInfo()` คืน `AccountModel` ที่มี `UserRole.Id` อยู่แล้ว
การเพิ่ม guard จึงเป็นงานเล็ก (เช็ค `userInfo?.UserRole?.Id != 61` แล้ว return ApiResultsModel)

---

## ⚠️ ข้อควรระวังก่อน deploy

### ก. หน้าจอจัดการสิทธิยังมีบั๊กค้างอยู่ — อย่าเพิ่งใช้ติ๊กเอง

`OAGBudget/Views/System/_tableSystemMenuRoleAssignManage.cshtml:78` ใช้ `item.IsPermission`
(ของ**เมนูแม่**) มา checked ให้ checkbox ของ**เมนูลูก**
→ แค่เปิดหน้าแล้วกดบันทึกโดยไม่แตะอะไร สิทธิของ role นั้นก็เพี้ยนทั้งชุด
รายละเอียดเต็มอยู่ที่ [`../20260820_OAGWBG_FN_GETMENU_PERMISSION/_menuPermission.md`](../20260820_OAGWBG_FN_GETMENU_PERMISSION/_menuPermission.md) §5.1

**สรุป: ให้รันสคริปต์ SQL แทนการติ๊กหน้าจอ จนกว่าบั๊กนี้จะถูกแก้**

### ข. "เห็นเมนู" ยังไม่เท่ากับ "เห็นเฉพาะรายการตัวเอง"

Requirement เขียนว่า *"ต้องเห็นรายการตัวเองภายใต้ใบใหญ่"* — แต่โค้ดตอนนี้ยัง**ไม่กรองตามศูนย์ต้นทุน**:

| จุด | สภาพปัจจุบัน |
|---|---|
| `GetBudgetReservedList` (`OAGBudget.API/.../BudgetService.cs:32615`) | กรองแค่ region / department / ปี / สถานะ / เลขที่ — **ไม่มีเงื่อนไขศูนย์ต้นทุนเลย** |
| `BudgetOverlapYearCentralDetail` (`OAGBudget/Controllers/BudgetController.cs:3283`) | ใส่ `CostCenterId = userCur?.Officer?.Id` ลง model แล้ว แต่ `GetBudgetOverlapYearCentralList` **ไม่เคยอ่านค่านี้** |

→ ถ้ารันสคริปต์อย่างเดียวโดยไม่แก้โค้ด ศูนย์ต้นทุนจะเห็น **ทุกใบและทุกบรรทัดของทุกศูนย์ต้นทุน**
ซึ่งเปิดกว้างเกินกว่าที่ requirement ขอ

---

## คำถามที่ต้องให้ผู้ใช้งานตอบ (ก่อนเขียนโค้ดกรอง)

Requirement เขียนไว้แค่ *"ต้องเห็นรายการตัวเองภายใต้ใบใหญ่"* ซึ่งยังตีความได้หลายแบบ

**Q1 — หน้า List ศูนย์ต้นทุนควรเห็นใบใหญ่แบบไหน** 🔴 ยังไม่ได้คำตอบ
- (ก) เฉพาะใบที่มีบรรทัดของศูนย์ต้นทุนตัวเอง
- (ข) เห็นทุกใบ แล้วไปกรองเอาที่หน้า Detail

**Q2 — หน้า Detail แสดงบรรทัดของศูนย์ต้นทุนอื่นหรือไม่** 🔴 ยังไม่ได้คำตอบ
- (ก) ซ่อนทั้งหมด เห็นเฉพาะของตัวเอง
- (ข) แสดงทั้งใบเพื่อให้เห็นภาพรวม แต่ highlight ของตัวเอง
- (ค) แสดงยอดรวมระดับใบได้ แต่ลงรายละเอียดได้เฉพาะของตัวเอง

**Q3 — ศูนย์ต้นทุนเป็น read-only ล้วนใช่หรือไม่** ✅ **ตอบแล้ว 2026-09-24**
> *"สิทธิ ศูนย์ต้นทุน เพิ่ม แก้ไขได้ แต่ พิจารณาไม่ได้"*

→ implement แล้ว ดู §4

> **ข้อจำกัดในการทดสอบ:** ใบ region "C" บน PREPROD มี 12 ใบ และทุกใบมีบรรทัดของ
> ศูนย์ต้นทุนเดียว (2900600001) จึง**พิสูจน์พฤติกรรมหลายศูนย์ต้นทุนด้วยข้อมูลจริงไม่ได้**
> ต้องสร้าง test data ที่มีหลายศูนย์ต้นทุนในใบเดียวกันก่อนทดสอบ

---

## ลำดับที่ต้องทำ

```
1. checkin โค้ด §1 + §4 (IsEdit / IsConsider)  ← ทำได้ทันที รอแค่ VPN หลุดเพื่อ tf get
2. ให้ BA ตอบ Q1 / Q2 (ขอบเขตการมองเห็นตามศูนย์ต้นทุน)
3. แก้โค้ดกรองตามศูนย์ต้นทุนตามคำตอบข้อ 2 (+ guard ฝั่ง API ถ้าสั่ง)
4. สร้าง test data หลายศูนย์ต้นทุนในใบเดียว
5. รัน deploy_grant_menu201_role11.sql
6. ทดสอบด้วย user ที่ถือ role 11 ตัวเดียว (เช่น user id 371 / 58011)
```

**⛔ ห้ามสลับ 5 มาก่อน 3** — เคยลองแล้ววันนี้ (ดู §Deployment log) และต้อง rollback
เพราะเปิดให้ศูนย์ต้นทุน 822 คน **แก้ไข**ใบของศูนย์ต้นทุนอื่นได้ ไม่ใช่แค่เห็น
