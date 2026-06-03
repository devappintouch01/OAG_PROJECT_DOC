# Roadmap #313 — รายงานรายละเอียดงบประมาณ: จำกัดสิทธิ์ศูนย์ต้นทุนให้เรียกรายงานได้เฉพาะระดับหน่วยงาน

## สรุปปัญหา

รายงานรายละเอียดงบประมาณ (`ReportBudgetRequest`) มีตัวเลือกระดับรายงาน 3 ระดับ:
- **ระดับ 1** = ระดับหน่วยงาน (Department)
- **ระดับ 2** = ระดับภาค (Region)
- **ระดับ 3** = ระดับภาพรวม (Summary)

ปัจจุบัน ผู้ใช้ทุกคนสามารถเลือกระดับรายงานได้ทั้ง 3 ระดับ แต่ตามความต้องการ ผู้ใช้ที่มีสิทธิ์ระดับ **ศูนย์ต้นทุน** (`ViewScope = "Costcenter"`) ควรเรียกรายงานได้เฉพาะ **ระดับหน่วยงาน (ระดับ 1)** เท่านั้น

---

## การวิเคราะห์โค้ดปัจจุบัน

### ไฟล์ที่เกี่ยวข้อง

| ไฟล์ | บทบาท | ปัญหา |
|---|---|---|
| `OAGBudget\Controllers\ReportController.cs` บรรทัด 31–48 | GET action โหลด view พร้อม dropdown | ไม่มีการตรวจสอบ permission scope ของผู้ใช้ |
| `OAGBudget\Views\Report\ReportBudgetRequest.cshtml` | UI สำหรับเลือกเงื่อนไขรายงาน | แสดงตัวเลือกระดับรายงานครบ 3 ระดับแก่ทุกคน |
| `OAGBudget\Services\Dropdown.cs` บรรทัด 242–249 | `DropdownReportLevel()` | คืนค่า hardcoded 3 ระดับ ไม่กรองตาม permission |
| `OAGBudget.DAL\Models\BudgetRequest.cs` | Model คำขอรายงาน | มี `LevelReport`, `DepartmentID`, `CostcenterID` |
| `OAGBudget.DAL\Models\OagwbgSystempermission.cs` | Permission model | มี `ViewScope` (All / Department / Costcenter / Owner / Custom) ต่อ Role ต่อ MenuID |
| `OAGBudget.Models\Common\AccountModel.cs` | Session user model | มี `UserRole` (OagwbgSystemrole) แต่ไม่มี ViewScope ระดับ menu |

### จุดที่ขาดหายอยู่

1. **Controller GET** (`ReportBudgetRequest`) ไม่ได้ดึง `ViewScope` ของผู้ใช้สำหรับเมนูนี้มาตรวจสอบ
2. **`DropdownReportLevel()`** คืนค่าทั้ง 3 ระดับเสมอ ไม่มี variant ที่รองรับการกรองตาม scope
3. **View** ไม่มี logic ปิดหรือซ่อนตัวเลือกระดับรายงานตาม permission
4. **Controller POST** (`ReportBudgetRequestExport`) ไม่มีการตรวจสอบ server-side ว่า user ที่มี scope = Costcenter พยายามเรียก level 2 หรือ 3

---

## ขั้นตอนการแก้ไข (Roadmap)

### Phase 0 — เตรียมข้อมูล (Pre-requisite)

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

### Phase 1 — เพิ่ม Helper ดึง Permission Scope ของผู้ใช้

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

**ไฟล์ที่แก้ไข:**
- `OAGBudget\Services\Account.cs` (เพิ่ม method) หรือสร้างไฟล์ helper ใหม่

---

### Phase 2 — แก้ไข Dropdown Service

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

**ไฟล์ที่แก้ไข:**
- `OAGBudget\Services\Dropdown.cs` บรรทัด 242–249
- `OAGBudget\Services\Dropdown.cs` (interface `IDropdowns` บรรทัด 81) — อัปเดต signature

---

### Phase 3 — แก้ไข Controller GET

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
    
    // ... โค้ดเดิม
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

**ไฟล์ที่แก้ไข:**
- `OAGBudget\Controllers\ReportController.cs` บรรทัด 31–48

---

### Phase 4 — แก้ไข View (Frontend UX)

**4.1** ใน `ReportBudgetRequest.cshtml` ถ้า `ViewScope = "Costcenter"`:
- ปิดการแก้ไข dropdown "ระดับรายงาน" (disabled / readonly) เหลือเฉพาะ ระดับหน่วยงาน
- ซ่อนหรือ disable ตัวเลือก "ภาค" (RegionID)
- Pre-select DepartmentID เป็นหน่วยงานของผู้ใช้ และ disable ไม่ให้เปลี่ยน

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

**ไฟล์ที่แก้ไข:**
- `OAGBudget\Views\Report\ReportBudgetRequest.cshtml`

---

### Phase 5 — Server-Side Validation (POST)

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

        // Enforce scope restriction
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

**ไฟล์ที่แก้ไข:**
- `OAGBudget\Controllers\ReportController.cs` บรรทัด 49–65

---

## สรุปไฟล์ที่ต้องแก้ไขทั้งหมด

| ลำดับ | ไฟล์ | การเปลี่ยนแปลง |
|---|---|---|
| 1 | `OAGBudget\Services\Dropdown.cs` | เพิ่ม parameter `viewScope` ใน `DropdownReportLevel()` |
| 2 | `OAGBudget\Controllers\ReportController.cs` | GET: ดึง ViewScope + กรอง dropdown / POST: validate scope |
| 3 | `OAGBudget\Views\Report\ReportBudgetRequest.cshtml` | ปิด/lock dropdown ระดับรายงานสำหรับ Costcenter scope |
| 4 | `OAGBudget\Services\Account.cs` (หรือ helper ใหม่) | เพิ่ม `GetViewScope(roleId, menuId)` |

---

## ประเด็นที่ต้องยืนยันก่อนแก้ไขจริง

1. **MenuID** ของหน้า "รายงานรายละเอียดงบประมาณ" ในตาราง `OAGWBG_SYSTEMWEBMEN` คือค่าใด?
2. ต้องการให้ผู้ใช้ที่มีสิทธิ์ Costcenter เห็น dropdown "ระดับรายงาน" เป็น disabled (เห็นแต่ไม่เปลี่ยนได้) หรือซ่อนไปเลย?
3. สำหรับ DepartmentID — ถ้า ViewScope = Costcenter ต้องการให้ auto-fill department ของผู้ใช้และ lock หรือให้ผู้ใช้เลือกเองได้?
4. รายงานอื่นที่ใช้ `DropdownReportLevel()` เช่นกัน ได้แก่ `ReportBudgetRequestMore` และ `ReportBudgetRequestAsset` — ต้องการบังคับใช้เงื่อนไขเดียวกันกับรายงานเหล่านั้นด้วยหรือไม่?

---

*วันที่วิเคราะห์: 2026-06-03*
