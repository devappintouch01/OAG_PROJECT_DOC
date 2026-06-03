# 🗺️ Roadmap #313 — รายงานรายละเอียดงบประมาณ: จำกัดสิทธิ์ศูนย์ต้นทุนให้เรียกรายงานได้เฉพาะระดับหน่วยงาน

## 🐛 สรุปปัญหา

รายงานรายละเอียดงบประมาณ (`ReportBudgetRequest`) มีตัวเลือกระดับรายงาน 3 ระดับ:
- 🏢 **ระดับ 1** = ระดับหน่วยงาน (Department)
- 🗺️ **ระดับ 2** = ระดับภาค (Region)
- 📊 **ระดับ 3** = ระดับภาพรวม (Summary)

ปัจจุบัน ผู้ใช้ทุกคนสามารถเลือกระดับรายงานได้ทั้ง 3 ระดับ แต่ตามความต้องการ ผู้ใช้ที่มีสิทธิ์ระดับ **ศูนย์ต้นทุน** (`ViewScope = "Costcenter"`) ควรเรียกรายงานได้เฉพาะ 🏢 **ระดับหน่วยงาน (ระดับ 1)** เท่านั้น

---

## 🔍 การวิเคราะห์โค้ดปัจจุบัน

### 📂 ไฟล์ที่เกี่ยวข้อง

| ไฟล์ | บทบาท | ❌ ปัญหา |
|---|---|---|
| `OAGBudget\Controllers\ReportController.cs` บรรทัด 31–48 | GET action โหลด view พร้อม dropdown | ไม่มีการตรวจสอบ permission scope ของผู้ใช้ |
| `OAGBudget\Views\Report\ReportBudgetRequest.cshtml` | UI สำหรับเลือกเงื่อนไขรายงาน | แสดงตัวเลือกระดับรายงานครบ 3 ระดับแก่ทุกคน |
| `OAGBudget\Services\Dropdown.cs` บรรทัด 242–249 | `DropdownReportLevel()` | คืนค่า hardcoded 3 ระดับ ไม่กรองตาม permission |
| `OAGBudget.DAL\Models\BudgetRequest.cs` | Model คำขอรายงาน | มี `LevelReport`, `DepartmentID`, `CostcenterID` |
| `OAGBudget.DAL\Models\OagwbgSystempermission.cs` | Permission model | มี `ViewScope` (All / Department / Costcenter / Owner / Custom) ต่อ Role ต่อ MenuID |
| `OAGBudget.Models\Common\AccountModel.cs` | Session user model | มี `UserRole` (OagwbgSystemrole) แต่ไม่มี ViewScope ระดับ menu |

### ⚠️ จุดที่ขาดหายอยู่

1. **Controller GET** (`ReportBudgetRequest`) ไม่ได้ดึง `ViewScope` ของผู้ใช้สำหรับเมนูนี้มาตรวจสอบ
2. **`DropdownReportLevel()`** คืนค่าทั้ง 3 ระดับเสมอ ไม่มี variant ที่รองรับการกรองตาม scope
3. **View** ไม่มี logic ปิดหรือซ่อนตัวเลือกระดับรายงานตาม permission
4. **Controller POST** (`ReportBudgetRequestExport`) ไม่มีการตรวจสอบ server-side ว่า user ที่มี scope = Costcenter พยายามเรียก level 2 หรือ 3

---

## 🛣️ ขั้นตอนการแก้ไข (Roadmap)

### 🔧 Phase 0 — เตรียมข้อมูล (Pre-requisite)

**0.1** ตรวจสอบ `SYSTEMWEBMENID` ของหน้า "รายงานรายละเอียดงบประมาณ" ในตาราง `OAGWBG_SYSTEMWEBMEN`  
→ จำเป็นต้องทราบ MenuID เพื่อ query `OagwbgSystempermission` ให้ถูกต้อง

```sql
SELECT * FROM OAGWBG_SYSTEMWEBMEN WHERE URL LIKE '%ReportBudgetRequest%';
```

**0.2** ตรวจสอบว่า role ที่มี `ViewScope = 'Costcenter'` สำหรับ menu นี้มีอยู่จริงในระบบ

```sql
SELECT sp.*, sr.ROLENAME
FROM OAGWBG_SYSTEMPERMISSION sp
JOIN OAGWBG_SYSTEMROLE sr ON sp.SYSTEMROLEID = sr.ID
WHERE sp.SYSTEMWEBMENID = <menu_id>
  AND sp.VIEWSCOPE = 'Costcenter';
```

---

### 🔧 Phase 1 — เพิ่ม Helper ดึง Permission Scope ของผู้ใช้

**1.1** เพิ่ม method ใน service หรือ helper class สำหรับดึง `ViewScope` ของผู้ใช้ปัจจุบันสำหรับเมนูที่กำหนด

```csharp
// OAGBudget\Services\Account.cs หรือ PermissionHelper.cs (ใหม่)
public async Task<string?> GetViewScope(int roleId, int menuId)
{
    // Query OAGWBG_SYSTEMPERMISSION
    // WHERE SYSTEMROLEID = roleId AND SYSTEMWEBMENID = menuId
    // RETURN ViewScope
}
```

**📝 ไฟล์ที่แก้ไข:**
- `OAGBudget\Services\Account.cs` (เพิ่ม method) หรือสร้างไฟล์ helper ใหม่

---

### 🔧 Phase 2 — แก้ไข Dropdown Service

**2.1** เพิ่ม overload ใน `DropdownReportLevel` ที่รับ `viewScope` เป็น parameter และกรองระดับตาม scope

```csharp
// OAGBudget\Services\Dropdown.cs
public async Task<List<SelectListItem>> DropdownReportLevel(string? viewScope = null)
{
    var all = new List<SelectListItem>
    {
        new SelectListItem { Value = "1", Text = "ระดับหน่วยงาน" },
        new SelectListItem { Value = "2", Text = "ระดับภาค" },
        new SelectListItem { Value = "3", Text = "ระดับภาพรวม" }
    };

    if (viewScope == "Costcenter")
        return all.Where(x => x.Value == "1").ToList();

    return all;
}
```

**📝 ไฟล์ที่แก้ไข:**
- `OAGBudget\Services\Dropdown.cs` บรรทัด 242–249
- `OAGBudget\Services\Dropdown.cs` (interface `IDropdowns` บรรทัด 81) — อัปเดต signature

---

### 🔧 Phase 3 — แก้ไข Controller GET

**3.1** ใน `ReportController.ReportBudgetRequest()` ดึง `ViewScope` แล้วส่งไปยัง View และกรอง dropdown

```csharp
// OAGBudget\Controllers\ReportController.cs บรรทัด 31–48
[HttpGet]
public async Task<IActionResult> ReportBudgetRequest(string PlanID)
{
    var userCur = new Appz(HttpContext)?.CurrentSignInUser;
    var roleId = userCur?.UserRole?.Id;

    // ดึง ViewScope ของผู้ใช้สำหรับเมนูนี้
    var viewScope = roleId.HasValue
        ? await _accountService.GetViewScope(roleId.Value, MENU_ID_REPORT_BUDGET_REQUEST)
        : null;

    ViewBag.ViewScope = viewScope; // ส่งไปให้ View ใช้งาน
    ViewBag.DropdownReportLevel = await _dropdowns.DropdownReportLevel(viewScope); // กรองตาม scope

    var deptId = userCur?.Officer?.Departmentid;

    // ถ้า Costcenter scope: lock department ให้เป็น dept ของผู้ใช้เท่านั้น
    if (viewScope == "Costcenter")
    {
        ViewBag.DropdownDepartment = (await _dropdowns.DropdownDepartment())
            .Where(x => x.Value == deptId).ToList();
    }
    else
    {
        ViewBag.DropdownDepartment = await _dropdowns.DropdownDepartment();
    }
    // ...
}
```

**📝 ไฟล์ที่แก้ไข:**
- `OAGBudget\Controllers\ReportController.cs` บรรทัด 31–48

---

### 🔧 Phase 4 — แก้ไข View (Frontend UX)

**4.1** ใน `ReportBudgetRequest.cshtml` ถ้า `ViewScope = "Costcenter"`:
- 🔒 ปิดการแก้ไข dropdown "ระดับรายงาน" (disabled) เหลือเฉพาะระดับหน่วยงาน
- 🙈 ซ่อนหรือ disable ตัวเลือก "ภาค" (RegionID)
- 📌 Pre-select DepartmentID เป็นหน่วยงานของผู้ใช้ และ disable ไม่ให้เปลี่ยน

```cshtml
@{
    var viewScope = ViewBag.ViewScope as string;
    var isCostcenterScope = viewScope == "Costcenter";
}

<select asp-for="LevelReport" class="form-select form-select-sm" id="LevelReport"
        data-control="select2" required @(isCostcenterScope ? "disabled" : "")>
    ...
</select>

@if (isCostcenterScope)
{
    <input type="hidden" name="LevelReport" value="1" />
}
```

**📝 ไฟล์ที่แก้ไข:**
- `OAGBudget\Views\Report\ReportBudgetRequest.cshtml`

---

### 🔧 Phase 5 — Server-Side Validation (POST)

**5.1** เพิ่มการตรวจสอบใน `ReportBudgetRequestExport` (POST) เพื่อป้องกัน bypass จาก client

```csharp
// OAGBudget\Controllers\ReportController.cs บรรทัด 49–65
[HttpPost]
public async Task<IActionResult> ReportBudgetRequestExport(BudgetRequest model)
{
    try
    {
        var userCur = new Appz(HttpContext)?.CurrentSignInUser;
        var roleId = userCur?.UserRole?.Id;
        var viewScope = roleId.HasValue
            ? await _accountService.GetViewScope(roleId.Value, MENU_ID_REPORT_BUDGET_REQUEST)
            : null;

        // 🛡️ Enforce scope restriction
        if (viewScope == "Costcenter" && model.LevelReport != 1)
        {
            return Json(new { success = false, message = "คุณมีสิทธิ์เรียกรายงานได้เฉพาะระดับหน่วยงานเท่านั้น" });
        }

        var result = await _reportService.GetReportFile(
            model,
            "/Report/ReportBudgetRequest",
            "รายงานรายละเอียดงบประมาณ.xlsx"
        );
        return result;
    }
    catch (Exception ex)
    {
        return Json(new { success = false, message = ex.Message });
    }
}
```

**📝 ไฟล์ที่แก้ไข:**
- `OAGBudget\Controllers\ReportController.cs` บรรทัด 49–65

---

## 📋 สรุปไฟล์ที่ต้องแก้ไขทั้งหมด

| ลำดับ | 📄 ไฟล์ | การเปลี่ยนแปลง |
|---|---|---|
| 1 | `OAGBudget\Services\Dropdown.cs` | เพิ่ม parameter `viewScope` ใน `DropdownReportLevel()` |
| 2 | `OAGBudget\Controllers\ReportController.cs` | GET: ดึง ViewScope + กรอง dropdown / POST: validate scope |
| 3 | `OAGBudget\Views\Report\ReportBudgetRequest.cshtml` | ปิด/lock dropdown ระดับรายงานสำหรับ Costcenter scope |
| 4 | `OAGBudget\Services\Account.cs` (หรือ helper ใหม่) | เพิ่ม `GetViewScope(roleId, menuId)` |

---

## ❓ คำถามสำหรับ SA (System Analyst)

> 📌 **SA กรุณาตอบคำถามด้านล่างนี้ให้ครบก่อนส่งกลับให้ทีม Dev**  
> วิธีตอบ: กรอกคำตอบในช่อง `💬 คำตอบ SA:` ใต้แต่ละข้อ และทำเครื่องหมาย `[x]` ในตัวเลือก checkbox (ถ้ามี)

---

### 🔑 กลุ่มที่ 1 — ด้านข้อมูล Permission

---

**Q1.1** `SYSTEMWEBMENID` ของหน้า "รายงานรายละเอียดงบประมาณ" (`/Report/ReportBudgetRequest`) ใน DB คือค่าใด?
> ต้องใช้เพื่อ query `OAGWBG_SYSTEMPERMISSION` ให้ถูกต้อง

💬 **คำตอบ SA:**
```
SYSTEMWEBMENID = _______________
```

---

**Q1.2** ขณะนี้มี Role ที่กำหนด `ViewScope = 'Costcenter'` สำหรับเมนูนี้อยู่แล้วหรือยัง?  
ถ้ายังไม่มี — ต้องการให้ทีม Dev เพิ่มข้อมูลใน DB หรือ SA จะกำหนดค่าผ่านหน้า Admin ของระบบ?

💬 **คำตอบ SA:**
- [ ] ✅ มีอยู่แล้ว — Role ที่มี Costcenter scope สำหรับเมนูนี้คือ: `_______________`
- [ ] ❌ ยังไม่มี — วิธีเพิ่มข้อมูล:
  - [ ] 🛠️ ให้ทีม Dev เพิ่มโดยตรงใน DB (Script SQL)
  - [ ] 🖥️ SA จะกำหนดเองผ่านหน้า Admin

---

**Q1.3** ผู้ใช้ที่เป็น "ศูนย์ต้นทุน" ใน session ปัจจุบันมี `Officer.Departmentid` ที่ถูกต้องเสมอหรือไม่?
> ใช้สำหรับ auto-fill DepartmentID ในหน้ารายงาน

💬 **คำตอบ SA:**
- [ ] ✅ ถูกต้องเสมอ — ใช้ได้เลย
- [ ] ⚠️ อาจไม่ถูกต้อง — มีข้อยกเว้น: `_______________`
- [ ] ❌ ไม่มีข้อมูลนี้ใน session — ต้องดึงจาก: `_______________`

---

### 🖥️ กลุ่มที่ 2 — ด้าน UX / พฤติกรรมที่ต้องการ

---

**Q2.1** เมื่อผู้ใช้ที่มีสิทธิ์ศูนย์ต้นทุนเปิดหน้ารายงาน ต้องการให้ dropdown "ระดับรายงาน" เป็นอย่างไร?

💬 **คำตอบ SA:** (เลือก 1 ข้อ)
- [ ] 👁️ แสดงแต่ **ระดับหน่วยงาน** เพียงตัวเดียว และ disabled (ผู้ใช้เห็นแต่ไม่สามารถเปลี่ยนได้)
- [ ] 🙈 ซ่อน dropdown ทั้งหมด แล้ว pre-set ค่าเป็น 1 แบบ hidden field (ผู้ใช้ไม่เห็น)

หมายเหตุเพิ่มเติม: `_______________`

---

**Q2.2** สำหรับ dropdown "หน่วยเบิกจ่าย" (DepartmentID) — ถ้า ViewScope = Costcenter ต้องการให้เป็นอย่างไร?

💬 **คำตอบ SA:** (เลือก 1 ข้อ)
- [ ] 📌 Auto-fill หน่วยงานของผู้ใช้ที่ล็อกอินอยู่ + disabled (ผู้ใช้ไม่ต้องเลือกเอง)
- [ ] 📋 แสดง dropdown แต่กรองเฉพาะหน่วยงานของผู้ใช้ (เลือกได้แต่มีแค่ option เดียว)
- [ ] 📝 ให้ผู้ใช้เลือก DepartmentID เองได้อิสระ (ไม่ lock)

หมายเหตุเพิ่มเติม: `_______________`

---

**Q2.3** สำหรับ dropdown "ศูนย์ต้นทุน" (CostcenterID) — ต้องการให้กรองเฉพาะศูนย์ต้นทุนที่ผู้ใช้สังกัดอยู่ด้วยหรือไม่?

💬 **คำตอบ SA:** (เลือก 1 ข้อ)
- [ ] ✅ ใช่ — กรองเฉพาะศูนย์ต้นทุนของผู้ใช้เท่านั้น
- [ ] ❌ ไม่ — แสดงทุกศูนย์ต้นทุนที่อยู่ใน DepartmentID ที่เลือก
- [ ] ➕ อื่น ๆ: `_______________`

---

### 📦 กลุ่มที่ 3 — ขอบเขตของการแก้ไข

---

**Q3.1** เงื่อนไขนี้ครอบคลุมเฉพาะ **รายงานรายละเอียดงบประมาณ** หรือรวมถึงรายงานอื่นด้วย?

💬 **คำตอบ SA:** (เลือกได้หลายข้อ)
- [ ] 📄 `ReportBudgetRequest` — รายงานรายละเอียดงบประมาณ *(รายงานหลักของ issue นี้)*
- [ ] 📄 `ReportBudgetRequestMore` — รายงานรายละเอียดงบประมาณเพิ่มเติม
- [ ] 📄 `ReportBudgetRequestAsset` — รายงานรายละเอียดงบประมาณครุภัณฑ์
- [ ] ➕ รายงานอื่น ๆ ระบุ: `_______________`

---

**Q3.2** ถ้าผู้ใช้ที่มีสิทธิ์ศูนย์ต้นทุนพยายาม bypass ผ่าน API (POST) โดยตรง ต้องการให้ระบบทำอย่างไร?

💬 **คำตอบ SA:** (เลือก 1 ข้อ)
- [ ] 🚫 ปฏิเสธคำขอ และแสดง error message ว่า "ไม่มีสิทธิ์เรียกระดับรายงานนี้"
- [ ] 🔄 บังคับ override `LevelReport = 1` แล้วดำเนินการต่อโดยไม่แจ้ง error

หมายเหตุเพิ่มเติม: `_______________`

---

**Q3.3** มีแผนในอนาคตที่จะขยาย scope logic นี้ไปยัง `ViewScope = "Department"` (หน่วยเบิกจ่าย) ด้วยหรือไม่?
> ถ้ามี ควรออกแบบ architecture ให้รองรับตั้งแต่ต้น

💬 **คำตอบ SA:** (เลือก 1 ข้อ)
- [ ] ✅ มีแผน — ให้ออกแบบให้รองรับหลาย scope ตั้งแต่ต้น
- [ ] ❌ ไม่มีแผน — แก้ไขเฉพาะ Costcenter scope ก่อน
- [ ] 🤔 ยังไม่แน่ใจ — ระบุเพิ่มเติม: `_______________`

---

*📅 วันที่วิเคราะห์: 2026-06-03*
