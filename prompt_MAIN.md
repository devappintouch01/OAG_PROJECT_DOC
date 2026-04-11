```
public async Task<IActionResult> AddAttachFile([FromBody] OagwbgAttachfile data)
{
    var res = new ApiResultsModel();

    try
    {
        var add = new OagwbgAttachfile();
        add.Rowguid = data.Rowguid;
        add.Referencetable = data.Referencetable;
        add.Referencegroup = data.Referencegroup;
        add.Referenceid = data.Referenceid;

        if (add.Referenceid != 0)
        {
            var max = _contextDoc.OagwbgAttachfiles.Where(x => x.Referenceid == add.Referenceid && x.Referencetable == add.Referencetable).OrderBy(x => x.Sequence).FirstOrDefault();
            if (max != null)
                add.Sequence = max.Sequence + 1;
            else
                add.Sequence = 1;
        }

        add.Filename = data.Filename;
        add.Extension = data.Extension;
        add.Filedata = data.Filedata;
        add.Filesize = data.Filesize;
        add.Createby = data.Createby;
        add.Createon = DateTime.Now;

        _contextDoc.OagwbgAttachfiles.Add(add);
        await _contextDoc.SaveChangesAsync();
        res.Type = ApiResultsType.success.ToString();

        add.Filedata = null;
        res.Data = add;
    }
    catch (Exception ex)
    {
        var e = ex.InnerException.Message;
        res.Message = ex.Message;
        res.Type = ApiResultsType.error.ToString();
    }
    return Ok(res);
}

Prompt: 
อัปโหลดไฟล์ขนาดเกิน 20 MB ที่ server ไม่ได้ครับ แต่ดีบัคที่เครื่อง Dev ได้ปกติครับ เลยไม่มั่นใจว่าปัญหามาจากอะไร

<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <location path="." inheritInChildApplications="false">
    <system.webServer>
      <handlers>
        <add name="aspNetCore" path="*" verb="*" modules="AspNetCoreModuleV2" resourceType="Unspecified" />
      </handlers>
      <aspNetCore processPath="dotnet" arguments=".\OAGBudget.dll" stdoutLogEnabled="false" stdoutLogFile=".\logs\stdout" hostingModel="inprocess" />
    </system.webServer>
  </location>
</configuration>
<!--ProjectGuid: 70ae056c-3cd7-49bf-8f62-5e6d727a9f59 OAGWBG web-->

<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <location path="." inheritInChildApplications="false">
    <system.webServer>
      <handlers>
        <add name="aspNetCore" path="*" verb="*" modules="AspNetCoreModuleV2" resourceType="Unspecified" />
      </handlers>
      <aspNetCore processPath="dotnet" arguments=".\OAGBudget.API.dll" stdoutLogEnabled="true" stdoutLogFile=".\logs\stdout" hostingModel="inprocess" />
    </system.webServer>
  </location>
</configuration>
<!--ProjectGuid: 52cc76b8-4948-4d57-a82f-5ba71380bcf5 OAGWBG webApi-->
```
