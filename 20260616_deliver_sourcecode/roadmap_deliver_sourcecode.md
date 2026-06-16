# Roadmap: Warranty Remark หลังส่งมอบ Source Code

**วันที่วิเคราะห์:** 2026-06-16  
**จัดทำโดย:** Claude Sonnet 4.6

---

## สรุปสถานการณ์

ส่ง ZIP source code ให้ Owner ไปแล้ว **โดยยังไม่มี warranty marker ใดๆ อยู่ใน ZIP นั้น**

Strategy ที่ตัดสินใจแล้ว: เพิ่ม HTTP Response Header middleware เข้าไปใน **TFS ของเรา** (หลังส่ง ZIP) เพื่อใช้เป็น marker สำหรับตรวจสอบว่า Owner deploy จาก source code เองหรือไม่

---

## Logic หลัก (Canary Header Strategy)

| ระบบ | มี X-License Header? | หมายความว่า |
|---|---|---|
| **ระบบของเรา** (deploy จาก TFS หลังส่ง ZIP) | **มี** ✓ | build มาจาก codebase ที่เราดูแล |
| **ระบบ Owner** (deploy จาก ZIP ที่ได้รับ) | **ไม่มี** ✗ | deploy จาก source เอง → out of warranty |

**วิธีตรวจสอบ:**  
ไปดู response header ของระบบที่ Owner deploy → ถ้าไม่มี `X-License` = พิสูจน์ว่าเขา deploy จาก ZIP เอง ไม่ได้ใช้ระบบของเรา

---

## แนวทางที่วิเคราะห์ (5 วิธี)

### วิธีที่ 1: HTTP Response Header — Canary Strategy (★★★★★ แนะนำสูงสุด)

**หลักการ:** เพิ่ม middleware ใน TFS ของเราหลังส่ง ZIP → ZIP ที่ Owner ได้รับไม่มี middleware นี้ → header จึงไม่ปรากฏบนระบบที่ Owner deploy เอง

**ความสามารถในการตรวจสอบ:**  
DevTools → Network tab → เลือก request ใดก็ได้ → Response Headers

**ตัวอย่าง Code — `OAGBudget\Program.cs` (เพิ่มก่อน `app.UseEndpoints`):**
```csharp
// Warranty marker — do not remove
app.Use(async (context, next) =>
{
    context.Response.OnStarting(() =>
    {
        context.Response.Headers.TryAdd("X-App-Build", "OAGBudget-20260616");
        context.Response.Headers.TryAdd("X-License", "Licensed to OAG. Source modification voids warranty. Ref:CONTRACT-OAG-2568");
        return Task.CompletedTask;
    });
    await next();
});
```

**ตัวอย่าง Code — `OAGBudget.API\Program.cs` (เพิ่มก่อน `app.MapControllers()`):**
```csharp
// Warranty marker — do not remove
app.Use(async (context, next) =>
{
    context.Response.OnStarting(() =>
    {
        context.Response.Headers.TryAdd("X-App-Build", "OAGBudget-API-20260616");
        context.Response.Headers.TryAdd("X-License", "Licensed to OAG. Source modification voids warranty. Ref:CONTRACT-OAG-2568");
        return Task.CompletedTask;
    });
    await next();
});
```

**ข้อดี:**
- ทุก HTTP request (ทั้ง page load และ API call) ส่ง header นี้ไปโดยอัตโนมัติ
- Owner ตรวจสอบได้ง่ายผ่าน DevTools Network tab ว่าระบบของเรามี header
- ZIP ที่ส่งไปแล้วไม่มี middleware นี้ → Owner deploy เองไม่มีทางมี header
- ง่ายต่อการพิสูจน์ในกรณีพิพาท: "ระบบของเราแสดง header นี้ — ระบบของคุณไม่แสดง"

**ข้อเสีย:**
- Header อาจถูก reverse proxy (nginx/IIS) ของเรา filter ออกได้ — ต้องตรวจสอบว่า header ผ่านออกมาจริง

---

### วิธีที่ 2: HTML Meta Tag ใน Layout (★★★★)

**หลักการ:** เพิ่ม `<meta>` tag ใน `<head>` ของ layout หลัก (เพิ่มใน TFS หลังส่ง ZIP)

**ความสามารถในการตรวจสอบ:**  
`Ctrl+U` (View Page Source) หรือ DevTools → Elements → `<head>`

**ตัวอย่าง Code — `OAGBudget\Views\Shared\_Layout.cshtml`:**
เพิ่มหลัง `<meta name="keywords" content="" />` (บรรทัดที่ 33):
```html
<meta name="x-app-build" content="OAGBudget-20260616" />
<meta name="x-license" content="Licensed to OAG. Source modification voids warranty. Ref:CONTRACT-OAG-2568" />
```

**ข้อดี:** เห็นได้ใน View Source ทันที — ง่ายต่อการแสดงให้ฝ่ายบริหารเห็นภาพ  
**ข้อเสีย:** ใช้เฉพาะ MVC frontend เท่านั้น ไม่ครอบคลุม API

---

### วิธีที่ 3: HTML Comment ใน Layout (★★★)

**หลักการ:** เพิ่ม HTML comment ในตำแหน่งที่ไม่ชัดเจน

**ตัวอย่าง Code — `OAGBudget\Views\Shared\_Layout.cshtml`:**
```html
<!-- build:OAGBudget-20260616 | (c)2568 Licensed to OAG Thailand. Modification of source code voids warranty. Ref:CONTRACT-OAG-2568 -->
```

**ข้อดี:** ง่ายมาก  
**ข้อเสีย:** ไม่ครอบคลุม API

---

### วิธีที่ 4: Assembly Attribute ใน C# (★★★)

**หลักการ:** ฝังลงใน AssemblyInfo ให้อยู่ใน compiled DLL

**ตัวอย่าง Code — สร้างหรือแก้ไข `AssemblyInfo.cs`:**
```csharp
[assembly: System.Reflection.AssemblyTitle("OAGBudget - Licensed to OAG Thailand")]
[assembly: System.Reflection.AssemblyDescription("Ref:CONTRACT-OAG-2568. Modification voids warranty.")]
[assembly: System.Reflection.AssemblyProduct("OAGBudget-20260616")]
```

**ข้อดี:** ฝังอยู่ใน DLL binary — ต้อง decompile จึงจะเห็น  
**ข้อเสีย:** Owner ตรวจสอบจาก browser ไม่ได้

---

### วิธีที่ 5: JavaScript Variable ใน Layout (★★★)

**หลักการ:** เพิ่ม global variable ซ่อนไว้ใน script block

**ตัวอย่าง Code — `OAGBudget\Views\Shared\_Layout.cshtml`:**
เพิ่มใน script block ที่มีอยู่แล้ว (บรรทัดที่ 52-55):
```html
<script>
    const baseURL = '@MyHttpContext.AppBaseUrl';
    // build:OAGBudget-20260616
    const __lic = 'Licensed to OAG. Modification voids warranty. Ref:CONTRACT-OAG-2568';
</script>
```

**ข้อดี:** เห็นได้ใน View Source และ DevTools Console (`__lic`)  
**ข้อเสีย:** ไม่ครอบคลุม API

---

## แนวทางที่แนะนำ: วิธีที่ 1 + วิธีที่ 2

### เหตุผล
- **วิธีที่ 1 (HTTP Header)** เป็น marker หลัก — ครอบคลุมทั้ง frontend และ API ทุก request
- **วิธีที่ 2 (Meta Tag)** เป็น backup — ใช้แสดงให้ฝ่ายบริหารเห็นภาพได้ง่ายจาก View Source

### Timeline
```
[ผ่านมาแล้ว] ส่ง ZIP → Owner ได้รับ source code ที่ไม่มี marker
[ปัจจุบัน]   เพิ่ม middleware + meta tag เข้า TFS ของเรา → checkin
[อนาคต]      ถ้ามีกรณีพิพาท → เปิด 2 ระบบเทียบกัน → ระบบของเรามี header, ของ Owner ไม่มี
```

### วิธีตรวจสอบเมื่อเกิดกรณีพิพาท
1. เปิด browser ไปที่ **ระบบของ Owner**
2. DevTools → Network → refresh → เลือก request ใดก็ได้ → Response Headers
3. ถ้าไม่มี `X-License` → Owner deploy จาก source เอง → out of warranty

---

## ไฟล์ที่ต้องแก้ไข (เพิ่มใน TFS หลังส่ง ZIP)

| # | ไฟล์ | สิ่งที่เพิ่ม | วิธี |
|---|------|-------------|------|
| 1 | `OAGBudget\Program.cs` | Middleware สำหรับ Response Header | วิธีที่ 1 |
| 2 | `OAGBudget.API\Program.cs` | Middleware สำหรับ Response Header (API) | วิธีที่ 1 |
| 3 | `OAGBudget\Views\Shared\_Layout.cshtml` | Meta tag `x-app-build` และ `x-license` | วิธีที่ 2 |

---

## สิ่งที่ต้องเตรียมก่อนแก้ไข

1. **กำหนด Reference Number** ของสัญญา เช่น `CONTRACT-OAG-2568` หรือเลขสัญญาจริง
2. **ยืนยันวันที่ส่งมอบ** — เพื่อใส่ใน `X-App-Build` ให้ตรงกับ ZIP ที่ส่งออกไป

---

## สถานะปัจจุบัน

- **HTTP Response Header middleware** — ยังไม่ implement (รอ zip ส่งมอบให้เสร็จก่อน — จะเพิ่มหลังส่ง ZIP)
- **ลบ `console.log` ทั้งหมดแล้ว** ✅ — 2026-06-16 (Changeset ดูใน TFS history)
- **Rename MOEN → OAG DbContext** ✅ — 2026-06-16 (Changeset ดูใน TFS history)
- **ลบ Keycloak dead code** ✅ — 2026-06-16 (Changeset #19044)
- **ลบ OPM-BackOffice.Reports** ✅ — 2026-06-16 (Changeset #19044)
- **FlowService.cs hardcoded MOENDB credentials** — ✅ ลบแล้ว (ลบ connectionString 2 บรรทัด)
- **Program.cs route `moenerp/`** — ✅ ลบแล้ว (ลบ projecttracking route block ทั้งหมด)
- **PublishProfiles MOENERP path** — ✅ แก้แล้ว (เปลี่ยนเป็น OAGBudget)
- **AuthenService.cs GetAuthTokenAsync / AuthenController.cs AuthEnergySignIn** — ✅ ลบแล้ว (Changeset #19045)
- **Cookie.Name DTNBOOKINGCookieAuth** — ✅ แก้แล้ว → `OAGBUDGETCookieAuth` (Changeset #19049)
- **JwtConfig.Issuer mone.com** — ✅ แก้แล้ว → `oagbudget.com` (Changeset #19049)
- **BaseUrl/BaseUrlApi/BaseUrlERP DTNBOOKING/DTNERP** — ✅ แก้แล้ว → placeholder `YOUR_SERVER` (Changeset #19049)
- **MailSettings DTN** — ✅ ลบแล้ว (Changeset #19048)
- **IntranetUrl dtn.go.th** — ✅ ลบแล้ว (Changeset #19048)
- **OAGLOGSContext DI + connection string** — ✅ ลบแล้ว ไม่มีใช้จริง (Changeset #19049)
- **eKey DTN-ERP.2020** — ✅ แก้แล้ว → `OAGWBG.2025` (Changeset #19050) ตรวจสอบแล้วว่าไม่มี password ใน DB
- **OAGDBContextBase.cs hardcoded connection string** — ✅ ลบแล้ว (Changeset #19051)
- **OAGDOCSContext connection string dev.softsuite.co.th** — ✅ แก้แล้ว → placeholder `YOUR_SERVER` (Changeset #19051)

---

## สิ่งที่ทำแล้ว

### 2026-06-16 — Rename MOEN → OAG DbContext classes

✅ **Checkin เรียบร้อย** (ดู Changeset ใน TFS history)

เปลี่ยนชื่อ DbContext ที่ copy มาจาก MOEN (กระทรวงพลังงาน) ให้เป็นชื่อของ OAGBudget

**Class rename (22 ไฟล์):**

| เดิม | ใหม่ |
|---|---|
| `MOENDBContext` | `OAGDBContext` |
| `MOENDOCSContext` | `OAGDOCSContext` |
| `MOENLOGSContext` | `OAGLOGSContext` |
| `MOENDBContextBase` | `OAGDBContextBase` |
| `MOENDOCSContextBase` | `OAGDOCSContextBase` |
| `MOENLOGSContextBase` | `OAGLOGSContextBase` |

**File rename (6 ไฟล์, ใช้ `tf rename`):**
- `MOENDBContext.cs` → `OAGDBContext.cs`
- `MOENDOCSContext.cs` → `OAGDOCSContext.cs`
- `MOENLOGSContext.cs` → `OAGLOGSContext.cs`
- `MOENDBContextBase.cs` → `OAGDBContextBase.cs`
- `MOENDOCSContextBase.cs` → `OAGDOCSContextBase.cs`
- `MOENLOGSContextBase.cs` → `OAGLOGSContextBase.cs`

**Connection string keys ใน appsettings (2 ไฟล์):**
- `"MOENDBContext"` → `"OAGDBContext"`
- `"MOENDOCSContext"` → `"OAGDOCSContext"`
- `"MOENLOGSContext"` → `"OAGLOGSContext"`

**Comments (4 ไฟล์):**
- `MOENDB.dbo.` → `OAGBudget DB.` ใน XML doc comments

**MOEN ที่ยังเหลือ (ต้องการข้อมูลจาก OAG ก่อนแก้):**

| ไฟล์ | รายละเอียด | สถานะ |
|---|---|---|
| ~~`AuthenController.cs:293`~~ | ~~`KEYCLOAK_CLIENT_ID = "MOEN-ERP"` (constant)~~ | ✅ ลบแล้ว — Changeset #19044 |
| ~~`AuthenController.cs:297`~~ | ~~`REDIRECT_URI` ชี้ไป `164.115.26.147/moenerp` (constant)~~ | ✅ ลบแล้ว — Changeset #19044 |
| ~~`AuthenService.cs:186`~~ | ~~`KeyCloakSignInAsync` method + `redirect_uri MOENERP`~~ | ✅ ลบแล้ว — Changeset #19044 |
| ~~`AuthenController.cs:45`~~ | ~~`AuthEnergySignIn` action เรียก `GetAuthTokenAsync`~~ | ✅ ลบแล้ว — Changeset #19045 |
| ~~`AuthenService.cs:127`~~ | ~~`GetAuthTokenAsync` ชี้ไป `auth.energy.go.th` + client_secret~~ | ✅ ลบแล้ว — Changeset #19045 |
| ~~`Program.cs:212`~~ | ~~Route pattern `moenerp/{controller=...}`~~ | ✅ ลบแล้ว — ลบทั้ง block (ใช้ default route แทน) |
| ~~`FlowService.cs:28,125`~~ | ~~Hardcoded credentials `MOENDB`~~ | ✅ ลบแล้ว — ลบ 2 บรรทัด connectionString |
| ~~`OAGDOCSContextBase.cs`~~ | ~~Hardcoded `MOENDOCS` + password~~ | ✅ แก้แล้ว — ลบ `OnConfiguring` ออก |
| ~~`OAGLOGSContextBase.cs`~~ | ~~Hardcoded `MOENLOGS` + password~~ | ✅ แก้แล้ว — ลบ `OnConfiguring` ออก |

---

### 2026-06-16 — ลบ `console.log` ออกจาก source code

Audit พบ active `console.log` จำนวน **67 บรรทัด** ใน **31 ไฟล์** — ลบออกทั้งหมดก่อน zip ส่งมอบ

**ไฟล์ที่แก้ไข:**

| กลุ่ม | ไฟล์ | จำนวนที่ลบ |
|---|---|---|
| Budget Views | BudgetAdjustDetail.cshtml | 10 |
| Budget Views | BudgetAdjustDetail_TransferIn_Edit.cshtml | 4 |
| Budget Views | BudgetOverlapYearCentralDetail.cshtml | 1 |
| Dashboard Views | DashboardBudgetResult.cshtml | 1 |
| Dashboard Views | DashboardProjectTrackingResult.cshtml | 2 |
| Dashboard Views | DashboardAssetResult.cshtml | 1 |
| Master Views | MasterStrategyManageDetail.cshtml | 2 |
| Master Views | MasterStrategyManageDetailYear.cshtml | 1 |
| Master Views | _tableMasterStrategy.cshtml | 1 |
| Master Views | _tableMasterOutputCode.cshtml | 1 |
| Master Views | _tableMasterBudgetExpenseType.cshtml | 1 |
| Master Views | _tableMasterActivityCode.cshtml | 1 |
| Master Views | _tabListVGovernmentoperationalPlan.cshtml | 3 |
| Master Views | _tabListVAnnualPlan.cshtml | 2 |
| Master Views | _tabListVSecondaryNationalStrategy.cshtml | 1 |
| Master Views | _tabListVPolicyCompliance.cshtml | 1 |
| Master Views | _tabListVNationalSecurityStrategy.cshtml | 1 |
| Master Views | _tabListVMasterStrategy.cshtml | 1 |
| Master Views | _tabListVMasterPlanunderNationalStrategy.cshtml | 1 |
| Master Views | _tabListVGovernmentPolicies.cshtml | 1 |
| Master Views | _tabListVMasterNationalEconomicandSocialDevelopmentPlan.cshtml | 1 |
| System Views | _tableUserManage.cshtml | 7 |
| System Views | _tablePermission.cshtml | 7 |
| Authen Views | SignIn.cshtml | 2 |
| Report Views | ReportBudgetAllocateTransfer.cshtml | 2 |
| Report Views | ReportBudgetAnnualAllocationSummary.cshtml | 1 |
| Report Views | ReportBudgetAllocateTransferDetail.cshtml | 2 |
| Shared Views | _tableBudgetAllocateDetailPersonal.cshtml | 1 |
| JS | site.js | 4 |
| JS | number-utils.js | 2 |
| JS | manage-vehicle-model-list.js | 1 |
| **รวม** | **31 ไฟล์** | **67 บรรทัด** |

หมายเหตุ: `// console.log` (commented-out) ยังคงอยู่ในไฟล์ — ไม่ทำงาน ไม่กระทบ

---

### 2026-06-16 — ลบ Hardcoded Credentials ออกจาก EF Core ContextBase

✅ **Checkin เรียบร้อย** (ดู Changeset ใน TFS history)

ลบ `OnConfiguring` block ทั้งหมดออกจาก EF Core ContextBase classes เพื่อกำจัด hardcoded credentials ของ MOEN server

**ไฟล์ที่แก้:**
- `OAGBudget.DAL\Models\OAGDOCSContextBase.cs` — ลบ `OnConfiguring` + hardcoded `Server=dev.softsuite.co.th;Database=MOENDOCS;User Id=energyerpadmin;Password=!energy2024!`
- `OAGBudget.DAL\Models\OAGLOGSContextBase.cs` — ลบ `OnConfiguring` + hardcoded `Server=dev.softsuite.co.th;Database=MOENLOGS;User Id=energyerpadmin;Password=!energy2024!`

**เหตุผล:** derived classes override `OnConfiguring` ผ่าน `IConfiguration` เสมอ — base class fallback ไม่ถูกเรียกใช้งาน จึงลบออกได้อย่างปลอดภัย

---

### 2026-06-16 — ลบ Keycloak Dead Code (Changeset #19044)

✅ **Checkin เรียบร้อย** — Changeset #19044

ลบ Keycloak authentication code ที่ไม่ได้ใช้งาน (ชี้ไปที่ server ของกระทรวงพลังงาน, ไม่มี link ใน UI)

**ไฟล์ที่แก้ไข:**

| ไฟล์ | สิ่งที่ลบ |
|---|---|
| `OAGBudget\Controllers\AuthenController.cs` | 5 Keycloak constants (`KEYCLOAK_CLIENT_ID="MOEN-ERP"`, `KEYCLOAK_CLIENT_SECRET`, `KEYCLOAK_REALM="gdcc"`, `KEYCLOAK_SERVER_URL="https://auth.energy.go.th"`, `REDIRECT_URI`) + `Login()` action + `Callback()` action + `TokenResponse` class + `UserInfoResponse` class (~170 บรรทัด) |
| `OAGBudget\Services\Repository\AuthenService.cs` | `KeyCloakSignInAsync` จาก interface declaration + full implementation (~50 บรรทัด) |
| `OAGBudget.Models\Common\SignInModel.cs` | `KeycloakSignInModel` class (lines 22-30) |

**ไฟล์ที่ลบออกจาก TFS (`tf delete`):**

| ไฟล์ | เหตุผล |
|---|---|
| `OAGBudget.Models\Common\Keycloak.cs` | Keycloak model class ที่ไม่ได้ใช้ |
| `OAGBudget\Views\Authen\Callback.cshtml` | View สำหรับ Keycloak callback ที่ไม่ได้ link ใน UI |

**Keycloak ที่ยังเหลือ (ไม่ได้ลบใน round นี้):**
- `AuthenController.cs` — `AuthEnergySignIn` action (line 45)
- `AuthenService.cs` — `GetAuthTokenAsync` method (line 122) ชี้ไปที่ `auth.energy.go.th` + credential เดิม

---

### 2026-06-16 — ลบ OPM-BackOffice.Reports Folder (Changeset #19044)

✅ **Checkin เรียบร้อย** — Changeset #19044

ลบ folder `OPM-BackOffice.Reports\` ทั้งหมดออกจาก TFS

**เหตุผล:**
- Copy มาจาก MOEN project (ชื่อ project file: `MOEN-ERP.Reports.csproj`)
- ไม่ได้อยู่ใน `OAGBudget.sln` — ไม่ถูก build
- เนื้อหาไม่เกี่ยวข้องกับ OAGBudget

**วิธีที่ใช้:** `tf delete "D:\TFS\OAG Budget\OPM-BackOffice.Reports" /recursive`

---

### 2026-06-16 — กำจัด MOEN references ที่เหลือ (Changeset #19047)

✅ **Build ผ่าน 0 Error** — รอ checkin

**Program.cs — ลบ `projecttracking` route:**
- ลบ `MapControllerRoute` block ที่มี pattern `moenerp/{controller=ProjectTracking}/...` ออกทั้ง block
- เหตุผล: ไม่มี view ใด hardcode URL `/moenerp/...` — `ProjectTracking` controller ยังเข้าถึงได้ผ่าน default route

**FlowService.cs — ลบ hardcoded connectionString:**
- ลบ `string connectionString = "Data Source=dev.softsuite.co.th; Initial Catalog=MOENDB; ..."` 2 บรรทัด (lines 28 และ 125)
- ตัวแปรนี้ไม่ได้ถูกใช้ (SQL code ข้างล่างถูก comment ออกทั้งหมด, DI ก็ comment ออก)

**PublishProfiles — เปลี่ยน MOENERP → OAGBudget:**
- `FolderProfile1.pubxml`: `D:\Publish\MOENERP\web` → `D:\Publish\OAGBudget\web`
- `Deploay_Jaida.pubxml`: `\\jaida\Web Application\MOENERP\_web` → `\\jaida\Web Application\OAGBudget\_web`

---

### 2026-06-16 — กำจัด DTN references (Changeset #19048, #19049, #19050)

✅ **Checkin เรียบร้อย**

| สิ่งที่แก้ | ไฟล์ | Changeset |
|---|---|---|
| ลบ MailSettings (mail.dtn.go.th) | appsettings.json + appsettings.Development.json (API) | #19048 |
| ลบ IntranetUrl (intranet.dtn.go.th) | appsettings.json, appsettings.Development.json (MVC), SettingsModel.cs | #19048 |
| ลบ commented DTNERP connection strings | appsettings.Development.json (API) | #19048 |
| ลบ MOEN-ERP - Backup.Global.csproj | OAGBudget.Global | #19048 |
| Cookie.Name → `OAGBUDGETCookieAuth` | OAGBudget\Program.cs | #19049 |
| JwtConfig.Issuer → `https://www.oagbudget.com` | appsettings.json + Development (API) | #19049 |
| BaseUrl/BaseUrlApi/BaseUrlERP → `YOUR_SERVER` placeholder | OAGBudget\appsettings.json | #19049 |
| ลบ OAGLOGSContext DI registration | OAGBudget.API\Program.cs | #19049 |
| ลบ OAGLOGSContext connection string | OAGBudget.API\appsettings.json | #19049 |
| eKey → `OAGWBG.2025` | OAGBudget.API\Services\Repository\AuthenService.cs | #19050 |

**หมายเหตุ eKey:** ตรวจสอบ PREPROD DB แล้ว — มี user 719 คน แต่ไม่มี password ใน DB (login ผ่าน SSO ทั้งหมด) จึงเปลี่ยน eKey ได้อย่างปลอดภัย

---

### 2026-06-16 — กำจัด softsuite dev server references (Changeset #19051)

✅ **Checkin เรียบร้อย**

| สิ่งที่แก้ | ไฟล์ |
|---|---|
| ลบ `OnConfiguring` block + hardcoded `dev.softsuite.co.th` connection string | `OAGBudget.DAL\Models\OAGDBContextBase.cs` |
| เปลี่ยน `OAGDOCSContext` → placeholder `YOUR_SERVER` | `OAGBudget.API\appsettings.json` |

---

### หมายเหตุ PublishProfiles

ไม่ควร zip ไฟล์ใน `Properties\PublishProfiles\` ของทั้ง 2 project:
- `OAGBudget\Properties\PublishProfiles\` — deploy config ส่วนตัว
- `OAGBudget.API\Properties\PublishProfiles\` — deploy config ส่วนตัว (ยังมี MOENERP path อยู่)

---

### 2026-06-16 — เตรียมไฟล์สำหรับ ZIP

✅ **Copy เรียบร้อย** — `D:\TFS\deliver OAG Budget`

**robocopy command ที่ใช้:**
```
robocopy "D:\TFS\OAG Budget" "D:\TFS\deliver OAG Budget" /E
  /XD bin obj .vs _brain_OAGBUDGET PublishProfiles
  /XF *.user *.suo .gitignore
```

**สถิติ:** 4,953 ไฟล์, 352 MB

**ไฟล์/โฟลเดอร์ที่ excluded:**

| สิ่งที่ exclude | เหตุผล |
|---|---|
| `bin\`, `obj\` | Build output — ไม่ใช่ source |
| `_brain_OAGBUDGET\` | Git docs ภายใน ไม่เกี่ยวกับ source |
| `PublishProfiles\` | Deploy config ส่วนตัว ยังมี server path ภายใน |
| `.vs\` | Visual Studio local settings |
| `*.user`, `*.suo` | VS personal settings |
| `CLAUDE.md`, `GEMINI.md` | AI config ภายใน ลบ manual หลัง copy |
| `*.vspscc` (7 ไฟล์) | TFS source control binding — Owner ไม่ต้องการ |

**พร้อม ZIP:** `D:\TFS\deliver OAG Budget` → zip ได้เลย

---

## ข้อสังเกตเพิ่มเติม

- ไฟล์ `_LayoutSignIn.cshtml`, `_LayoutBlank.cshtml`, `_LayoutEmpty.cshtml` เป็น layout อื่นที่อาจต้องเพิ่ม meta tag ด้วยถ้าต้องการครอบคลุมทุกหน้า
- **วิธีที่ 1 (HTTP Header)** ครอบคลุมทุก layout โดยอัตโนมัติ จึงเป็นวิธีที่ robust ที่สุด และเพียงพอโดยไม่ต้องแตะทุก layout
