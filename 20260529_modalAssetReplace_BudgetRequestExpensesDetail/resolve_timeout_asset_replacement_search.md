# fix: resolve 100s timeout in asset replacement search (SearchAssetReplace) on PROD

# สาเหตุและคำอธิบายของปัญหา

## 1. สาเหตุของปัญหา (Root Cause)
เกิดจากปัญหาทางด้านประสิทธิภาพ (Performance Issue) ภายในโปรเจกต์ `OAGBudget.API` ไฟล์ `Services/Repository/BudgetService.cs` ในเมธอด `GetAssetList(SearchAsset data)` (ประมาณบรรทัดที่ 6092) ซึ่งมีการเขียนโค้ดเพื่อคิวรีข้อมูลที่ไม่มีประสิทธิภาพสำหรับการทำงานกับข้อมูลปริมาณมาก ดังนี้:

```csharp
var itemAssetList = await _context.OagwbgVBudgetgovernmentassetitems
    .Where(x => x.Budgetyear == data.BudgetYear)
    .ToListAsync();
// ...
var assetIdsToExclude = itemAssetList.Select(i => i.AssetId).ToList();
if (assetIdsToExclude.Any())
{
    query = query.Where(x => !assetIdsToExclude.Contains(x.Id));
}
```

1. มีการดึงข้อมูล `OagwbgVBudgetgovernmentassetitems` ทั้งหมดของปีงบประมาณนั้นๆ เข้ามาไว้ในหน่วยความจำของแอปพลิเคชัน (ผ่าน `.ToListAsync()`) โดยไม่ได้มีเงื่อนไขกรองเพิ่มเติม (เช่น กรองตามหน่วยงาน `Departmentid` หรือ `BudgetRequestId`)
2. นำข้อมูล `AssetId` ที่ดึงมาได้ทั้งหมดไปใช้ในเงื่อนไข `.Contains(x.Id)` ซึ่ง Entity Framework (EF Core) จะแปลงเป็นคำสั่ง SQL ให้อยู่ในรูป `WHERE Id NOT IN (1, 2, 3, ...)` 

## 2. อธิบายปัญหา (Problem Description)
- ในฐานข้อมูล **PREPROD** ข้อมูลจำลองอาจจะยังมีจำนวนไม่มากพอที่จะทำให้ระบบล่ม (เพียงแค่รู้สึกว่าดึงข้อมูลช้า) 
- แต่ในฐานข้อมูล **PROD** ข้อมูลรายการครุภัณฑ์ของทั้งปีมีปริมาณมหาศาล (หลักหมื่นหรือมากกว่า)
- การคิวรีข้อมูลทั้งหมดมาเก็บใน Memory แล้วส่ง `NOT IN (...)` ที่มีขนาดใหญ่มากกลับไปให้ฐานข้อมูล Oracle ประมวลผล ทำให้ฐานข้อมูลต้องใช้เวลาจัดการและค้นหา (Full Table Scan / Parsing Time) นานมากๆ
- เนื่องจากฝั่ง Web App (`OAGBudget`) มีการใช้ `HttpClient` เพื่อเรียก API (`OAGBudget.API`) และมี Timeout เริ่มต้นอยู่ที่ 100 วินาที เมื่อฝั่ง API ใช้เวลาประมวลผลฐานข้อมูลนานเกิน 100 วินาที ฝั่ง Web App จึงเกิด `TaskCanceledException` / `TimeoutException` และคืนค่าเป็น 500 Internal Server Error กลับไปยังหน้าเว็บตามที่เห็นใน DevTools

## 3. การ Verify ปัญหา
- ยืนยันจาก Stack Trace `System.Threading.Tasks.TaskCanceledException: The request was canceled due to the configured HttpClient.Timeout of 100 seconds elapsing.` ซึ่งเกิดขึ้นในจังหวะ `HttpClient.SendAsync` ที่เรียกจาก Web App (`OAGBudget.Services.Repository.BudgetService.GetAssetList`) 
- ตรวจสอบโค้ดฝั่ง API (`OAGBudget.API/Services/Repository/BudgetService.cs`) เมธอด `GetAssetList` พบสาเหตุตรงจุดดึง `OagwbgVBudgetgovernmentassetitems` ดังที่วิเคราะห์ไว้ ซึ่งเป็นคอขวดที่ชัดเจนเมื่อต้องรองรับข้อมูลปริมาณระดับ Production

## 4. แนวทางการแก้ไข (Proposed Code Fix)

**ปัญหาหลัก 2 จุด:**
1. โค้ดเดิมใช้ **View** (`OagwbgVBudgetgovernmentassetitems`) เพื่อดึงรายการที่ต้องตัดออก — View บน Oracle PROD มีข้อมูลมหาศาลและไม่มี Index จึงช้ามาก
2. การส่ง `NOT IN (...)` ขนาดใหญ่กลับไปฐานข้อมูลทำให้ Oracle parse SQL นานเกิน 100 วินาที

**แก้ไข:** เปลี่ยนจาก View เป็น **Table จริง** (`OagwbgBudgetgovernmentassetitems`) ซึ่งมี Index → ดึง excluded IDs ขึ้น Memory ได้เร็วมาก

**โค้ดที่แก้ไขแล้ว (ในไฟล์ `OAGBudget.API/Services/Repository/BudgetService.cs`):**
```csharp
// 1. ดึง AssetId ที่ถูกใช้ไปแล้ว จาก TABLE จริง (ไม่ใช่ View) — มี Index, เร็วมาก
var excludedIdsQuery = _context.OagwbgBudgetgovernmentassetitems
    .Where(x => x.Budgetyear == data.BudgetYear && x.Assetid.HasValue);
if (userInfo.User.Id != 1 && budgetRequest != null)
{
    excludedIdsQuery = excludedIdsQuery.Where(x => x.Departmentid == budgetRequest.Departmentid);
}
var excludedIds = await excludedIdsQuery
    .Select(x => (long)x.Assetid!.Value)
    .Distinct()
    .ToListAsync();

// 2. ตั้งต้น Query หลัก (ใช้ View สำหรับแสดงผล)
var query = _context.OagwbgVExtOagfaAssetVs.AsQueryable();
if (userInfo.User.Id != 1 && budgetRequest != null)
{
    query = query.Where(x => x.Departmentid == budgetRequest.Departmentid);
}

if (!string.IsNullOrEmpty(data.AssettypeId)) query = query.Where(x => x.AssettypeId == data.AssettypeId);
if (!string.IsNullOrEmpty(data.AssettypesubId)) query = query.Where(x => x.AssettypesubId == data.AssettypesubId);
if (!string.IsNullOrEmpty(data.AssetclassId)) query = query.Where(x => x.AssetclassId == data.AssetclassId);
if (!string.IsNullOrEmpty(data.AssetdetailId)) query = query.Where(x => x.AssetdetailId == data.AssetdetailId);
if (data.AssetId != null && data.AssetId != 0) query = query.Where(x => x.Id == data.AssetId);

// 3. ตัดรายการที่ถูกใช้แล้วออก — excludedIds มาจาก Table จริง จึงเป็น List ขนาดเล็ก
if (excludedIds.Count > 0)
{
    var ids = excludedIds;
    query = query.Where(x => !ids.Contains(x.Id));
}

var result = new SearchResult<OagwbgVExtOagfaAssetV>();
result.ItemCount = await query.CountAsync();

query = query.Sort(data.Sorting).Page(data.Paging);
result.ResultData = await query.ToListAsync();

return result;
```
