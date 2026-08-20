# OAGWBG_FN_GETMENU_PERMISSION — การประเมินและ reconstruct ฟังก์ชันที่หายไป

วันที่วิเคราะห์ : 2026-08-20
DB ที่ใช้ตรวจ : **PREPROD** `172.16.11.19:1541 / ebs_PRE / OAGWBG` (Oracle 19c 19.25) — ต่อผ่าน F5 VPN
ไฟล์ที่ได้ : [`_brain/OAGWBG_FN_GETMENU_PERMISSION.sql`](OAGWBG_FN_GETMENU_PERMISSION.sql)

---

## 1. ยืนยันอาการ (ไม่ใช่การเดา)

| ตรวจอะไร | ผลลัพธ์จริง |
|---|---|
| `ALL_OBJECTS` ที่ `OWNER='OAGWBG'` และชื่อมี `MENU`/`PERMISSION` | **ไม่มี** `OAGWBG_FN_GETMENU_PERMISSION` เลย — มีแต่ `OAGWBG_FN_BOOKINGSYSTEMMENU`, `OAGWBG_FN_GETSYSTEMMENUROLEASSIGN` (VALID ทั้งคู่) |
| `ALL_SOURCE` ทั้ง instance หาคำว่า `ISPERMISSION` / `NODEID` / `GETMENU_PERMISSION` | ไม่พบใน schema `OAGWBG` เลย (เจอแต่ของ Oracle/APPS) → **ไม่มีต้นฉบับให้ลอก** |
| ตาราง `OAGWBG_SYSTEMMENU`, `OAGWBG_SYSTEMMENUROLEASSIGN` | มีครบ ปกติดี (66 และ 294 แถว — ใน 294 นั้นเป็นแถวที่ชี้ไปยังเมนูที่ถูกลบไปแล้ว 133 แถว ดู §5.2 ข้อ 6) |

---

## 2. สัญญา (contract) ที่บังคับจากโค้ด — ส่วนนี้ **แน่ชัด 100%**

### 2.1 วิธีเรียก
[`SystemService.cs:167`](../OAGBudget.API/Services/Repository/SystemService.cs#L167) และ [`SystemController.cs:209`](../OAGBudget.API/Controllers/SystemController.cs#L209)

```csharp
_context.Database.SqlQuery<OagwbgFnGetMenuPermission>(
    $"Select * from OAGWBG_FN_GETMENU_PERMISSION({id})")
```

→ ต้องเป็น **pipelined table function รับ 1 พารามิเตอร์** (`SystemRoleId`, `int?` — อาจเป็น `null` ได้ในทางทฤษฎี
แม้ service จะ short-circuit คืน list ว่างไปก่อนแล้วเมื่อ `id == null`)
Oracle 19c เรียก `SELECT * FROM fn(x)` ได้โดยไม่ต้องใส่ `TABLE()` — ยืนยันแล้วด้วย `SELECT COUNT(*) FROM OAGWBG_FN_GETSYSTEMMENUROLEASSIGN(41)` → 65

### 2.2 ชื่อคอลัมน์ต้องตรงกับ property ทุกตัว
EF Core 9 map raw-SQL ลง unmapped type ด้วย**ชื่อ** ([`OagwbgFnGetMenuPermission.cs`](../OAGBudget.Models/RawData/OagwbgFnGetMenuPermission.cs)) — ฟังก์ชันจึงต้อง pipe ออกมาครบ **12 คอลัมน์**
`Id, MenuId, MenuName, ControllerName, ActionName, Sequence, Active, IsshowInsiteMenu, NodeId, ParentId, Code, IsPermission`

### 2.3 ความหมายของ `Id` — ล็อกตายตัวจากโค้ด save
[`SystemController.cs:182-190`](../OAGBudget.API/Controllers/SystemController.cs#L182-L190) เอา `item.Id` ไปเขียนลง `OAGWBG_SYSTEMMENUROLEASSIGN.SYSTEMMENUID` ตรง ๆ
→ **`ID` = `OAGWBG_SYSTEMMENU.ID` เท่านั้น** ห้ามเป็น running number หรือ id ของตาราง roleassign

### 2.4 ความหมายของ `ParentId` — ล็อกจาก view
[`_tableSystemMenuRoleAssignManage.cshtml:5,32`](../OAGBudget/Views/System/_tableSystemMenuRoleAssignManage.cshtml#L5)
```csharp
var listParent = Model.Where(x => x.ParentId == null).ToList();
var sub        = Model.Where(x => x.ParentId == item.Id).ToList();
```
→ `PARENTID` อยู่ใน "โดเมนเดียวกับ `ID`" คือ `PARENTMENUID`, และ **root ต้องเป็น NULL** (ไม่ใช่ 0)
→ view รองรับ **แค่ 2 ระดับ** เท่านั้น (ข้อมูลจริงลึกสุด 2 ระดับพอดี)

### 2.5 ความหมายของ `IsPermission`
- view: `@(item.IsPermission == 1 ? "checked" : "")`
- save: `IsPermission == 1 && ไม่มีแถว` → INSERT ; `IsPermission == null && มีแถว` → DELETE
→ ตอนอ่านต้องคืน **1 = role นี้มีแถวใน `OAGWBG_SYSTEMMENUROLEASSIGN`, 0 = ไม่มี**
(คืน 0 หรือ NULL ตอนอ่านให้ผลหน้าจอเหมือนกัน — เลือก `0` ตามสไตล์ `RoleActive` ของฟังก์ชันพี่น้อง)

---

## 3. ต้นแบบที่ใช้อ้างอิง — ฟังก์ชันพี่น้องที่ยังอยู่บน DB

หน้าจอนี้เคยใช้ฟังก์ชันชื่อ **`OAGWBG_FN_GETSYSTEMMENUROLEASSIGN`** (คู่กับ ViewModel [`FNGetSystemMenuRoleAssign.cs`](../OAGBudget.Models/ViewModel/FNGetSystemMenuRoleAssign.cs) ที่ยังค้างอยู่ในโปรเจกต์) — dump source จาก DB จริงได้ว่า:

```sql
SELECT SM.Id, SM.MenuName, SM.ParentMenuId, SM.SystemNameId, SN.Name AS SystemName,
       SM.Sequence, 0 AS IsHvChild,
       CASE WHEN EXISTS (SELECT 1 FROM OAGWBG_SYSTEMMENUROLEASSIGN SA
                         WHERE SA.SystemRoleId = p_SystemRoleId AND SA.SystemMenuId = SM.Id)
            THEN 1 ELSE 0 END AS RoleActive
FROM OAGWBG_SYSTEMMENU SM
LEFT JOIN OAGWBG_MASTERSYSTEMNAME SN ON SM.SystemNameId = SN.Id
WHERE SM.Active = 1 AND SM.IsShowInSiteMenu = 1
ORDER BY SM.SystemNameId, SM.Sequence
```

→ **`OAGWBG_FN_GETMENU_PERMISSION` คือรุ่นใหม่ของอันนี้** : เปลี่ยน `RoleActive` → `IsPermission`,
ตัด `SystemName/IsHvChild` ทิ้ง (view ใหม่ hardcode คำว่า "ระบบงบประมาณ"), เพิ่ม `ControllerName/ActionName/Active/IsshowInsiteMenu/NodeId/Code`
ฟังก์ชันที่ผมเขียนจึงยึดโครงนี้เป็นหลัก แล้วเติมคอลัมน์ที่ขาด

---

## 4. คอลัมน์ไหนแน่ชัด / ไม่แน่ชัด

### 4.1 ตารางสรุป

| คอลัมน์ | ค่าที่ให้ | ความมั่นใจ | เหตุผล |
|---|---|---|---|
| `ID` | `SYSTEMMENU.ID` | 🟢 แน่ชัด | §2.3 — save เอาไปลง `SYSTEMMENUID` |
| `PARENTID` | `PARENTMENUID` (root = NULL) | 🟢 แน่ชัด | §2.4 — view เทียบกับ `ID` ตรง ๆ |
| `ISPERMISSION` | `EXISTS(...)` → 1/0 | 🟢 แน่ชัด | §2.5 + ลอกจากฟังก์ชันพี่น้อง |
| `MENUNAME` | `SYSTEMMENU.MENUNAME` | 🟢 แน่ชัด | view แสดงคอลัมน์ "เมนู" |
| `SEQUENCE` | `SYSTEMMENU.SEQUENCE` | 🟢 แน่ชัด | ชื่อ + ใช้จัดลำดับ |
| `CONTROLLERNAME` / `ACTIONNAME` | ตรงชื่อคอลัมน์ในตาราง | 🟢 แน่ชัด | ชื่อตรงกัน 1:1 |
| `ACTIVE` / `ISSHOWINSITEMENU` | ตรงชื่อคอลัมน์ในตาราง | 🟢 แน่ชัด | ชื่อตรงกัน 1:1 |
| `NODEID` | `= ID` | 🟡 **เดา** | ไม่มีคอลัมน์ `NODEID` ที่ไหนใน schema เลย, view ไม่ได้ใช้ ใช้แต่ `data-node-id="@item.Id"` ของ plugin `simpleTreeTable` → สรุปว่าเป็น node id ของ tree = menu id |
| `MENUID` | `= ID` | 🟡 **เดา** | class มี `Id` อยู่แล้ว, ไม่มีใครอ่าน `MenuId` เลยทั้งระบบ ให้ค่าเดียวกับ `ID` ปลอดภัยที่สุด (ผู้ใช้ property นี้ในอนาคตจะได้ menu id ตามที่ชื่อบอก) |
| `CODE` | `CONTROLLERNAME || '/' || ACTIONNAME` | 🔴 **เดามากที่สุด** | `OAGWBG_SYSTEMMENU` **ไม่มี**คอลัมน์ `CODE`, ไม่มีใครอ่านค่านี้ในโค้ดเลย เลือกให้เป็น "รหัสหน้าจอ" เพราะระบบระบุเมนูด้วย Controller+Action อยู่แล้ว (`CategoryMenu.cs`) — **ถ้ามีสเปกจริงว่า `Code` คืออะไร ให้แก้บรรทัดเดียวในไฟล์ .sql** |

### 4.2 เงื่อนไขการกรอง — จุดที่ต้องตัดสินใจ

| เงื่อนไข | ที่เลือก | หมายเหตุ |
|---|---|---|
| `ACTIVE = '1'` | ✅ กรอง | ฟังก์ชันพี่น้องทั้งสองตัวกรองเหมือนกัน · ปัจจุบันตัดออก 1 แถว = ID 170 `Budget/ReportBudgetAdjust` |
| `ISSHOWINSITEMENU = '1'` | ❌ ไม่กรอง (มีบรรทัด comment ให้เปิดได้) | ฟังก์ชันเดิมกรอง **แต่** ฟังก์ชันใหม่ส่งคอลัมน์นี้กลับไปเป็นข้อมูล → เจตนาน่าจะให้ client ตัดสินใจ · **ข้อมูลจริงตอนนี้ทุกแถวเป็น `'1'` หมด จึงให้ผลเท่ากันเป๊ะ (65 แถวเท่ากัน)** ความเสี่ยง = 0 ณ วันนี้ |
| `SYSTEMMENUGROUPID` / `SYSTEMNAMEID` | ❌ ไม่กรอง | ข้อมูลจริงทุกแถว = 2/2 · หน้าจอนี้ก็ไม่มี dropdown ให้เลือกกลุ่ม |
| ลำดับ | root ตาม `SEQUENCE` → ลูกจัดกลุ่มตามแม่ ตาม `SEQUENCE` | view กรองซ้ำเองอยู่แล้ว ต้องการแค่ลำดับภายในกลุ่มถูก |

### 4.3 การตัดสินใจที่สำคัญที่สุด : เมนูกำพร้า (orphan)

ข้อมูลจริงมี **8 แถวที่ `PARENTMENUID = 999` แต่เมนู id 999 ไม่มีอยู่จริง** (น่าจะเป็นเมนู "รายงาน" ตัวเก่าที่ถูกลบแล้วสร้างใหม่เป็น id 153):

```
164 คำของบประมาณ (ใน/นอก)      167 แผนการใช้จ่าย       171 โอนเงินกลับ
165 คำของบประมาณโครงการ        168 โอนจัดสรร           172 เบิกแทนกัน
170 โอนเปลี่ยนแปลงงบประมาณ (ACTIVE=0)                  173 โอนเงินสะสมเหลือจ่าย
```

ถ้าคืน `PARENTID = PARENTMENUID` ตรง ๆ → 7 แถวนี้ (170 ถูกตัดด้วย ACTIVE อยู่แล้ว) จะ **ไม่ถูก render เลย**
เพราะไม่เข้าเงื่อนไข `ParentId == null` และไม่มีแถวแม่ให้จับคู่ → **admin แก้สิทธิ์เมนูเหล่านี้ไม่ได้ตลอดกาล**
ทั้งที่ role 1 / 11 / 31 มีสิทธิ์บางตัวอยู่จริงในฐานข้อมูลแล้ว

**ที่เลือก : orphan-safe** — ถ้าหาแถวแม่ในชุดผลลัพธ์ไม่เจอ ให้ `PARENTID = NULL` (ดันขึ้นเป็นเมนูระดับบน)
ผลกับ role 11 : 65 แถว = **22 root** (15 เดิม + 7 ที่ถูกดันขึ้น) + 43 ลูก
ครอบคลุมกรณีแม่ถูกตัดด้วย `ACTIVE='0'` ไปในตัวด้วย

> ไฟล์ .sql มี comment บอกวิธีเปลี่ยนกลับเป็นแบบ "ตรงตามข้อมูลดิบ" ด้วยการแก้บรรทัดเดียว
> ทางแก้ที่ถูกต้องจริง ๆ คือ**ซ่อมข้อมูล**: `UPDATE OAGWBG_SYSTEMMENU SET PARENTMENUID = 153 WHERE PARENTMENUID = 999;`
> — อันนี้ต้องให้เจ้าของระบบตัดสินใจ ผมไม่ได้ทำให้ และไม่ควรทำพร้อมกับ deploy ฟังก์ชัน

---

## 5. ⚠️ บั๊กที่เจอระหว่างทาง — ฟังก์ชันอย่างเดียวยัง **ไม่พอ** ให้หน้าจอทำงานถูก

### 5.1 [BLOCKER] checkbox ของเมนูลูก ผูกกับ `IsPermission` ของ**แม่**

[`_tableSystemMenuRoleAssignManage.cshtml:78`](../OAGBudget/Views/System/_tableSystemMenuRoleAssignManage.cshtml#L78)
```razor
@foreach (var sb in sub) {
    <input type="checkbox" name="model[@row].IsPermission" value="1"
           @(item.IsPermission == 1 ? "checked" : "")   ← ใช้ item (แม่) ไม่ใช่ sb (ลูก)
```

**ผลกระทบจริง (blast radius) — ข้อมูลบน PREPROD ตอนนี้ :**

| role | เมนูแม่ | ลูกทั้งหมด | ลูกที่มีสิทธิ์ | จะเกิดอะไรถ้ากด "บันทึก" |
|---|---|---|---|---|
| 11 | 153 รายงาน | 18 | 12 | แม่มีสิทธิ์ → ลูกติ๊กครบ → **เพิ่มสิทธิ์เกินมา 6 เมนู** |
| 11 | 133 การติดตามฯ | 4 | 1 | **เพิ่มเกิน 3** |
| 11 | 213 กันเงินเหลื่อมปี | 3 | 1 | **เพิ่มเกิน 2** |
| 31 | 153 รายงาน | 18 | 15 | **เพิ่มเกิน 3** |
| 51 | 69 ตั้งค่า | 9 | 1 | **เพิ่มเกิน 8** (เมนู admin ทั้งหมด!) |
| 91 | 212 บันทึกรับเงินฯ | 2 | 0 | แม่มีสิทธิ์แต่ลูกไม่มี → ติ๊กครบ → **เพิ่มเกิน 2** |
| 11 | 212 (ลูก 211 มีสิทธิ์ แต่แม่ไม่มี) | 2 | 1 | แม่ไม่มีสิทธิ์ → ลูกไม่ติ๊ก → **สิทธิ์ที่มีอยู่ถูกลบทิ้ง** |

→ แค่เปิดหน้าแล้วกดบันทึกโดยไม่แตะอะไรเลย สิทธิ์ก็เพี้ยนทันที **ต้องแก้ก่อน หรือพร้อมกับ deploy ฟังก์ชัน**

**แก้ 1 บรรทัด :** `@(item.IsPermission == 1 ? ...)` → `@(sb.IsPermission == 1 ? ...)`
(ผมยังไม่ได้แก้ให้ เพราะอยู่นอกขอบเขตที่สั่ง — บอกมาได้ครับถ้าให้แก้)

### 5.2 [รอง] ปัญหาอื่นที่เห็นในหน้าจอเดียวกัน

| # | เรื่อง | ที่อยู่ | ผล |
|---|---|---|---|
| 1 | `SaveChangesAsync()` เรียกใน loop + `Max(Id)+1` gen id เอง | [`SystemController.cs:185-200`](../OAGBudget.API/Controllers/SystemController.cs#L185-L200) | ช้า (65 round-trip) + ชนกันได้ถ้ามี 2 คนบันทึกพร้อมกัน ทั้งที่มี `SEQ_SYSTEMMENUROLEASSIGN_ID` อยู่แล้ว |
| 2 | `PermissionDetail.cshtml` มี `<select name="SystemRoleId">` ซ้ำกับ `<input type="hidden" name="SystemRoleId">` ใน form เดียวกัน | [`PermissionDetail.cshtml:23,30`](../OAGBudget/Views/System/PermissionDetail.cshtml#L23) | model binding ได้ค่าเป็น `"11,11"` เสี่ยง bind ไม่ติด (แต่ตอนนี้ divFilter ถูกซ่อนและ auto-click อยู่ จึงไม่โผล่) |
| 3 | มี `debugger;` ค้างในโค้ด JS | [`_tableSystemMenuRoleAssignManage.cshtml:110`](../OAGBudget/Views/System/_tableSystemMenuRoleAssignManage.cshtml#L110) | เบรกให้ dev tool ทุกครั้งที่ติ๊ก |
| 4 | `OAGWBG_SYSTEMMENUROLEASSIGN` มี `SYSTEMROLEID` 91 และ 9931 ที่ไม่มีใน `OAGWBG_SYSTEMROLE` | data | ขยะค้าง ไม่กระทบหน้าจอนี้ |
| 5 | `SYSTEMMENU.ID=224` มี `ISPARENT='N'` (ค่าที่เหลือใช้ `'0'/'1'`) | data | ไม่กระทบ เพราะฟังก์ชันไม่ได้ใช้ `ISPARENT` |
| 6 | `OAGWBG_SYSTEMMENUROLEASSIGN` 294 แถว แต่ **133 แถวชี้ไปยัง `SYSTEMMENUID` ที่ไม่มีในตารางเมนูแล้ว** | data | ไม่กระทบฟังก์ชัน (join จากฝั่งเมนูออกไป) แต่หน้าจอนี้จะแก้/ลบมันไม่ได้เลย — ควร cleanup แยกต่างหาก |

---

## 6. สิ่งที่ยังไม่ได้พิสูจน์ (ต้องทดสอบตอน deploy)

1. **ยังไม่ได้ CREATE ลง PREPROD** — ทำแค่รัน `SELECT` ตัวเดียวกับ body ของฟังก์ชัน (read-only) แล้วได้ผลถูกต้อง 65 แถว
   การสร้าง TYPE/FUNCTION เป็นการแก้ schema (R1) ผมไม่ทำเองโดยไม่ขอ
2. **ยังไม่ได้ทดสอบ EF map จริง** — มั่นใจว่าชื่อคอลัมน์แบบ Oracle (ตัวพิมพ์ใหญ่ล้วน) map เข้า property PascalCase ได้
   เพราะทั้งระบบใช้ pattern นี้อยู่แล้ว (`OAGWBG_FN_BOOKINGSYSTEMMENU` → `OagwbgSystemmenu`) แต่ยังไม่ได้รันของจริง
3. `MenuId` / `NodeId` / `Code` **ไม่มีใครอ่าน** — ถ้าสเปกจริงต่างจากที่เดา จะไม่มีอาการให้เห็นทันที (silent)
4. ฟังก์ชันรองรับ**แค่ 2 ระดับ** เท่ากับที่ view รองรับ ถ้าอนาคตมีเมนู 3 ระดับ หลานจะหายไปจากหน้าจอ

---

## 7. ขั้นตอน deploy ที่แนะนำ

```
1. (ถ้าทำได้) เช็ค TEST/PROD ก่อนว่ามีต้นฉบับเหลืออยู่ไหม — ถ้ามี ใช้ต้นฉบับแทนไฟล์นี้
2. รัน _brain/OAGWBG_FN_GETMENU_PERMISSION.sql บน PREPROD  (TYPE 2 ตัว + FUNCTION 1 ตัว)
3. รัน §3 VERIFY ในไฟล์ .sql ทั้ง 5 ข้อ
4. แก้บั๊ก §5.1 ในไฟล์ .cshtml  ← ควรทำก่อนเปิดให้ผู้ใช้กดบันทึก
5. เปิดหน้า System/PermissionDetail?roleId=11 ตรวจว่า:
   - ขึ้นครบ 22 หัวข้อหลัก / 43 เมนูย่อย
   - ติ๊กถูกตรงกับ SELECT ... FROM OAGWBG_SYSTEMMENUROLEASSIGN WHERE SYSTEMROLEID=11  (25 แถว)
6. ทดสอบบันทึกกับ role ที่ไม่ได้ใช้จริงก่อน (เช่น role 61 ที่ยังไม่มีสิทธิ์อะไรเลย)
```

**Reversibility = R1** : สร้าง object ใหม่ 3 ตัว ไม่แตะข้อมูลและไม่แตะ object เดิม
rollback = `DROP FUNCTION` + `DROP TYPE` ×2 (มีให้ท้ายไฟล์ .sql)
ความเสี่ยงจริงอยู่ที่ **§5.1** ไม่ใช่ที่ตัวฟังก์ชัน — ฟังก์ชันแค่ทำให้หน้าจอกลับมาแสดงผลได้

---

## 8. ไฟล์/บรรทัดที่เกี่ยวข้อง

| ไฟล์ | บทบาท |
|---|---|
| [OAGBudget/Views/System/PermissionDetail.cshtml](../OAGBudget/Views/System/PermissionDetail.cshtml) | หน้าหลัก · auto-click `#btnSearch` ตอนโหลด |
| [OAGBudget/Views/System/_tableSystemMenuRoleAssignManage.cshtml](../OAGBudget/Views/System/_tableSystemMenuRoleAssignManage.cshtml) | ตาราง tree + checkbox (**บั๊ก §5.1 อยู่ที่นี่**) |
| [OAGBudget/Controllers/SystemController.cs:300-345](../OAGBudget/Controllers/SystemController.cs#L300) | MVC เรียก API |
| [OAGBudget.API/Controllers/SystemController.cs:144,174](../OAGBudget.API/Controllers/SystemController.cs#L144) | endpoint `GetRolePermission` / `SaveSystemMenuRoleAssignManage` |
| [OAGBudget.API/Services/Repository/SystemService.cs:161](../OAGBudget.API/Services/Repository/SystemService.cs#L161) | จุดที่เรียกฟังก์ชันที่หายไป |
| [OAGBudget.Models/RawData/OagwbgFnGetMenuPermission.cs](../OAGBudget.Models/RawData/OagwbgFnGetMenuPermission.cs) | สัญญาคอลัมน์ 12 ตัว |
