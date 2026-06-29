# Roadmap: หน้าจัดการ Master หน่วยนับ (OAGWBG_MASTERUNIT)

> โมเดล: Opus (วิเคราะห์) + Sonnet (ลงมือทำ) · วันที่: 2026-06-29
> **สถานะ: ✅ DONE — Changeset #19148 + DB insert สำเร็จ**

---

## สถานะงาน

| Layer | สถานะ | หมายเหตุ |
|---|---|---|
| DAL Model `OagwbgMasterunit` | ✅ มีแล้ว | ตาราง `OAGWBG_MASTERUNIT` |
| DAL View `OagwbgVMasterunit` | ✅ มีแล้ว | View `OAGWBG_V_MASTERUNIT` (มี `Activenname`) |
| DbContext (DbSet ทั้ง 2 ตัว) | ✅ มีแล้ว | `OAGDBContextBase.cs:208, 490` |
| Search model `SearchMasterUnit` | ✅ มีแล้ว | `nameTh`, `Active` + สืบทอด `CriteriaBase` |
| **API** Controller `#region 8.MasterUnit` | ✅ มีแล้ว | `OAGBudget.API/Controllers/MasterController.cs:609-699` |
| **API** Service (interface + impl) | ✅ มีแล้ว | `OAGBudget.API/Services/Repository/MasterService.cs:1377-1473` |
| **Frontend** MasterController (5 actions) | ✅ **เพิ่มแล้ว** | Changeset #19148 |
| **Frontend** MasterService (6 CRUD methods) | ✅ **เพิ่มแล้ว** | Changeset #19148 |
| **Frontend** Views (3 ไฟล์) | ✅ **สร้างแล้ว** | Changeset #19148 |
| Menu `OAGWBG_SYSTEMMENU` (ID=225) | ✅ **insert แล้ว** | 2026-06-29 |
| RoleAssign `OAGWBG_SYSTEMMENUROLEASSIGN` (ID=300) | ✅ **insert แล้ว** | Role ID=1 (ผู้ดูแลระบบ1) |

---

## สิ่งที่ทำใน Changeset #19148

### ไฟล์ที่แก้ไข

| ไฟล์ | การเปลี่ยนแปลง |
|---|---|
| `OAGBudget/Controllers/MasterController.cs` | เพิ่ม `#region MasterUnit` — 5 actions: `MasterUnit()` GET, `SearchMasterUnit()` POST, `MasterUnitDetail()`, `SaveMasterUnit()`, `DeleteMasterUnit()` (มี in-use validation) |
| `OAGBudget/Services/Repository/MasterService.cs` | เพิ่ม interface + impl 6 methods: `GetListVMasterUnit`, `GetMasterUnitById`, `SaveMasterUnit`, `DeleteMasterUnit`, `GetAssetByUnitId`, `GetBudgetGovernmentItemByUnitId` |

### ไฟล์ที่สร้างใหม่

| ไฟล์ | บทบาท |
|---|---|
| `OAGBudget/Views/Master/MasterUnit.cshtml` | หน้า List + filter (ค้นหาชื่อ, สถานะ) + ปุ่มสร้างใหม่ |
| `OAGBudget/Views/Master/_partialView/_tableMasterUnit.cshtml` | DataTable serverSide — คอลัมน์ ดำเนินการ / ลำดับ / ชื่อหน่วยนับ / สถานะ |
| `OAGBudget/Views/Master/_partialView/_modalMasterUnit.cshtml` | Modal เพิ่ม/แก้ไข/ดู — field: Namethai + Active (select "1"/"0") |

---

## DB ที่ insert ลง PREPROD

```sql
-- เมนู
INSERT INTO OAGWBG_SYSTEMMENU (ID=225, MENUNAME='หน่วยนับ', URL='/Master/MasterUnit',
  ACTIONNAME='MasterUnit', CONTROLLERNAME='Master', SEQUENCE=16, PARENTMENUID=69,
  SYSTEMMENUGROUPID=2, SYSTEMNAMEID=2, ACTIVE='1', ISSHOWINSITEMENU='1')

-- สิทธิ์
INSERT INTO OAGWBG_SYSTEMMENUROLEASSIGN (ID=300, SYSTEMROLEID=1, SYSTEMMENUID=225)
-- SYSTEMROLEID=1 = ผู้ดูแลระบบ1 (Rolelevel=200)
```

---

## Flow ที่ implement แล้ว

```
[Browser] /Master/MasterUnit
   │ DataTable serverSide → POST SearchMasterUnit(SearchMasterUnit)
   ▼
[MVC] MasterController.SearchMasterUnit → _masterService.GetListVMasterUnit()
   │ ──HTTP GET──► [API] /api/Master/GetListVMasterUnit → EF → OAGWBG_V_MASTERUNIT
   ▼ return JSON {draw, recordsTotal, data}

[Browser] กดปุ่ม edit/view → editUnit(id)/viewUnit(id)
   │ POST MasterUnitDetail {Id, Mode}
   ▼
[MVC] MasterController.MasterUnitDetail → _masterService.GetMasterUnitById()
   │ ──HTTP GET──► [API] /api/Master/GetMasterUnitById → EF → OAGWBG_MASTERUNIT
   ▼ PartialView _modalMasterUnit

[Browser] กดบันทึก (AjaxBeginForm → OnSuccess=onSaveMasterUnitSuccess)
   │ POST SaveMasterUnit(OagwbgMasterunit)
   ▼
[MVC] set Createby/Updateby = user.User.Id → _masterService.SaveMasterUnit()
   │ ──HTTP POST──► [API] /api/Master/SaveMasterUnit → EF Add/Update OAGWBG_MASTERUNIT
   ▼ JSON {success, message} → hide modal + reload DataTable

[Browser] กดลบ → Swal confirm → POST DeleteMasterUnit {Id}
   ▼
[MVC] ตรวจ GetAssetByUnitId + GetBudgetGovernmentItemByUnitId
   ├─ พบการใช้งาน → {success:false, "ไม่สามารถลบรายการได้เนื่องจาก รายการนี้ถูกนำไปใช้แล้ว"}
   └─ ไม่พบ → _masterService.DeleteMasterUnit() ──HTTP──► [API] /api/Master/DeleteMasterUnit
```

---

## ข้อสังเกต / จุดที่ต้องระวัง

1. **API `SaveMasterUnit` มี bug ตอนแก้ไข** (คงสภาพไว้ตามที่ยืนยัน):
   - ไม่ set `Updateby`/`Updateon` ตอน edit — MVC set ให้แล้วฝั่ง MVC ก่อนส่ง API
   - ตอน Add hard-code `Createby = 12345679` ใน API → MVC ส่ง Createby มาด้วยแล้ว แต่ API override ค่านี้ทิ้ง → audit field Createby จะไม่ถูกต้อง (ยอมรับได้ตามที่ตกลง)

2. **`Active` เป็น string** "1"/"0" — modal ใช้ `<select>` value="1"/"0", table แสดงจาก `activenname` ของ View

3. **Delete validation เช็ค 2 ตาราง** เท่านั้น (Asset + BudgetGovernmentItem) ตามที่ยืนยันว่าระบบ OAGBudget ไม่มีโมดูลวัสดุ

4. **ฟิลด์ e-GP** (`Egpactive`, `Egpid`) ไม่แสดงใน modal ตามที่ยืนยัน

---

## Oracle Table / View ที่เกี่ยวข้อง

| Object | ชนิด | บทบาท |
|---|---|---|
| `OAGWBG_MASTERUNIT` | Table | ตารางหลัก — Id, Namethai, Active, Egpactive, Egpid, audit |
| `OAGWBG_V_MASTERUNIT` | View | ใช้แสดง List — มี `Activenname` ("ใช้งาน"/"ไม่ใช้งาน") |
| `OAGWBG_ASSET` | Table | ตรวจ in-use ก่อนลบ (UnitId) |
| `OAGWBG_BUDGETGOVERNMENTITEM` | Table | ตรวจ in-use ก่อนลบ (Quantityunitid) |
| `OAGWBG_SYSTEMMENU` | Table | เมนู ID=225 |
| `OAGWBG_SYSTEMMENUROLEASSIGN` | Table | สิทธิ์ ID=300 → Role ID=1 |
