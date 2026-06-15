# Build Optimization — OAGBudget Solution

**Date:** 2026-06-15  
**TFS Changeset:** #19040  
**Status:** ✅ Done (ข้อ 1, 2, 4, 5, 6) | ⏳ Pending (ข้อ 3 — ต้องทดสอบ runtime)

---

## Measurement

| Build type | Before | After | ลดลง |
|---|---|---|---|
| VS Rebuild All | 60.1s | **52.3s** | **~8s (13%)** |
| `dotnet build --no-incremental` | — | **33.1s** | reference only |

> หมายเหตุ: `dotnet build --no-incremental` เร็วกว่า VS เพราะข้าม Razor compilation และ output file copying ที่ VS ทำเพิ่ม

---

## สิ่งที่แก้แล้ว

### ✅ ข้อ 1 — ลบ Microsoft.CodeAnalysis.* ออกจาก build graph

**ไฟล์:** `OAGBudget\OAGBudget.csproj`, `Controllers\BudgetController.cs`, `Services\Repository\BudgetService.cs`

ลบ `Microsoft.CodeAnalysis.CSharp.Features 4.8.0` ออก — เป็น Roslyn IDE package ที่ load analyzer assemblies จำนวนมากระหว่าง build โดยไม่มีการเรียก CodeAnalysis API จริงในโค้ด (เป็นแค่ unused `using`)

**ปัญหาที่เกิดขึ้นระหว่างแก้ (NU1107):**  
การลบ 3 packages ออกทำให้เกิด version conflict เพราะ `Microsoft.VisualStudio.Web.CodeGeneration.Design 6.0.18` ดึง `Microsoft.CodeAnalysis.Common 4.0.0` และ `Workspaces.Common 4.0.0` มาผ่าน transitive แต่ EF Tools 9.0.4 ต้องการ `4.8.0`

**วิธีแก้ conflict:** เพิ่ม pin version กลับมาเฉพาะ 2 ตัวที่จำเป็น พร้อม `PrivateAssets=all`:

```xml
<PackageReference Include="Microsoft.CodeAnalysis.Common" Version="4.8.0">
  <PrivateAssets>all</PrivateAssets>
</PackageReference>
<PackageReference Include="Microsoft.CodeAnalysis.Workspaces.Common" Version="4.8.0">
  <PrivateAssets>all</PrivateAssets>
</PackageReference>
```

ผลสุดท้าย: ลบ `CSharp.Features` ออกได้สำเร็จ — ตัวที่หนักที่สุดหายไปแล้ว

---

### ✅ ข้อ 2 — สร้าง `Directory.Build.props` ปิด analyzers ใน Debug mode

**ไฟล์ใหม่:** `Directory.Build.props` (root)

```xml
<Project>
  <PropertyGroup Condition="'$(Configuration)' == 'Debug'">
    <RunAnalyzersDuringBuild>false</RunAnalyzersDuringBuild>
    <EnforceCodeStyleInBuild>false</EnforceCodeStyleInBuild>
  </PropertyGroup>
</Project>
```

Warning ลดจาก **1,645** → **647** รายการ ใน Debug build

---

### ✅ ข้อ 4 — EF Core Tools 9.0.3 → 9.0.4

**ไฟล์:** `OAGBudget\OAGBudget.csproj`

Align กับ OAGBudget.DAL และ OAGBudget.API ที่ใช้ 9.0.4 อยู่แล้ว — ลด MSB3277 assembly binding conflict

---

### ✅ ข้อ 5 — ลบ duplicate LinqKit.Core

**ไฟล์:** `OAGBudget.Global\OAGBudget.Global.csproj`

ลบ `<PackageReference Include="LinqKit.Core" Version="1.2.4" />` ที่ซ้ำกันออก 1 บรรทัด

---

### ✅ ข้อ 6 — เพิ่ม PrivateAssets=all ให้ CodeGeneration.Design

**ไฟล์:** `OAGBudget\OAGBudget.csproj`

```xml
<PackageReference Include="Microsoft.VisualStudio.Web.CodeGeneration.Design" Version="6.0.18">
  <PrivateAssets>all</PrivateAssets>
  <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
</PackageReference>
```

ป้องกัน transitive dependencies ของ package นี้ (รวมถึง CodeAnalysis เก่า) ไม่ให้ leak เข้า build graph ของ projects อื่น

---

## ที่ยังค้างไว้

### ⏳ ข้อ 3 — OAGBudget.Utilities `net6.0` → `net9.0`

**Estimated saving:** ~3–5s  
**ทำไมยังไม่ทำ:** `iTextSharp 5.5.13.3` และ `BouncyCastle 1.8.9` เป็น legacy packages ที่ไม่ได้ support net9.0 อย่างเป็นทางการ — build ผ่านไม่ได้แปลว่า runtime ไม่พัง ต้องทดสอบ runtime ก่อน

---

## โครงสร้าง Project Dependencies

```
OAGBudget (MVC, net9.0)
├── OAGBudget.DAL (net9.0)         ← 553 .cs files (ใหญ่สุด)
├── OAGBudget.Global (net9.0)      ← 12 .cs files
├── OAGBudget.Models (net9.0)      ← 393 .cs files
├── OAGBudget.Reports (net9.0)     ← 44 .cs files
└── OAGBudget.Utilities (net6.0)   ← 9 .cs files ← ⚠️ TFM mismatch (ข้อ 3)

OAGBudget.API (net9.0)
├── OAGBudget.DAL
├── OAGBudget.Global
└── OAGBudget.Models
```

**Total source files:** 1,086 .cs files across 7 projects
