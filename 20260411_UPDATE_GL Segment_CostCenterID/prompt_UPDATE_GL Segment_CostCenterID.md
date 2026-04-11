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

```
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <location path="." inheritInChildApplications="false">
    <system.webServer>
      <handlers>
        <add name="aspNetCore" path="*" verb="*" modules="AspNetCoreModuleV2" resourceType="Unspecified" />
      </handlers>
      <aspNetCore processPath="dotnet" arguments=".\OAGBudget.dll" stdoutLogEnabled="true" stdoutLogFile=".\logs\stdout" hostingModel="inprocess" />
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
<!--ProjectGuid: 52cc76b8-4948-4d57-a82f-5ba71380bcf5 OAGBudget.API-->
```

```
Context:
- D:\TFS\OAG Budget\*
- D:\TFS\OAG Budget\OAGBudget\*
- D:\TFS\OAG Budget\OAGBudget.API\*

Observation:
จากไฟล์ D:\TFS\OAG Budget\OAGBudget\Views\Budget\BudgetAllocateDetail.cshtml
ที่ปุ่ม "ยืนยัน" id="btn-ConfirmBudgetCode" เมื่อกดแล้ว ทำงานอย่างไรบ้าง จาก jQuery ทำงานอย่างไร
และเรียก Controller ใน C# แล้วทำอะไร มีการส่ง interface อย่างไร
สรุปลงใน D:\TFS\OAG Budget\brain_OAGBUDGET\budgetalloatedetail\budgetallocatedetail_1.md
``` 

```
Context:
- D:\TFS\OAG Budget\*
- D:\TFS\OAG Budget\OAGBudget\*
- D:\TFS\OAG Budget\OAGBudget.API\*

Observation:
จากไฟล์ D:\TFS\OAG Budget\OAGBudget\Views\Budget\BudgetAllocateDetail.cshtml
ที่ปุ่ม "ยืนยัน" id="btn-Confirm" เมื่อกดแล้ว ทำงานอย่างไรบ้าง จาก jQuery ทำงานอย่างไร
และเรียก Controller ใน C# แล้วทำอะไร มีการส่ง interface อย่างไร
สรุปลงใน D:\TFS\OAG Budget\brain_OAGBUDGET\budgetalloatedetail\budgetallocatedetail_2.md
```

```
Context:
- D:\TFS\OAG Budget\*
- D:\TFS\OAG Budget\OAGBudget\*
- D:\TFS\OAG Budget\OAGBudget.API\*

Observation:
จากไฟล์ D:\TFS\OAG Budget\OAGBudget\Views\Budget\BudgetAllocateDetail.cshtml
ที่ปุ่ม "ยืนยัน" id="btn-Confirm" เมื่อกดแล้ว ทำงานอย่างไรบ้าง จาก jQuery ทำงานอย่างไร
และเรียก Controller ใน C# แล้วทำอะไร มีการส่ง interface อย่างไร
สรุปลงใน D:\TFS\OAG Budget\brain_OAGBUDGET\budgetalloatedetail\budgetallocatedetail_2.md
```

```
Context:
- D:\TFS\OAG Budget\*
- D:\TFS\OAG Budget\OAGBudget\*
- D:\TFS\OAG Budget\OAGBudget.API\*

Observation:
จากไฟล์ D:\TFS\OAG Budget\OAGBudget\Views\Budget\BudgetPaymentGfDetail.cshtml
ที่ปุ่ม "ยืนยัน" id="btn-Confirm" เมื่อกดแล้ว ทำงานอย่างไรบ้าง จาก jQuery ทำงานอย่างไร
และเรียก Controller ใน C# แล้วทำอะไร มีการส่ง interface อย่างไร
สรุปลงใน D:\TFS\OAG Budget\brain_OAGBUDGET\budgetpaymentgfdetail\budgetpaymentgfdetail_1.md
```

```
จากไฟล์ budgetpaymentgfdetail_1.md ฟังก์ชัน `SaveBudgetPaymentGf` ใน BudgetService.cs อยู่บรรทัดไหน
```

```
Context:
- D:\TFS\OAG Budget\*
- D:\TFS\OAG Budget\OAGBudget\*
- D:\TFS\OAG Budget\OAGBudget.API\*

Observation:
จากไฟล์ D:\TFS\OAG Budget\OAGBudget\Views\Budget\BudgetPaymentGfDetail.cshtml
ที่ปุ่ม "บันทึก" id="btn-save" เมื่อกดแล้ว ทำงานอย่างไรบ้าง จาก jQuery ทำงานอย่างไร
และเรียก Controller ใน C# แล้วทำอะไร มีการคำนวณ GL Segments ทั้ง 13 ตัว อย่างไร
สรุปลงใน D:\TFS\OAG Budget\brain_OAGBUDGET\budgetpaymentgfdetail\budgetpaymentgfdetail_2.md
```


```
Context:
- D:\TFS\OAG Budget\*
- D:\TFS\OAG Budget\OAGBudget\*
- D:\TFS\OAG Budget\OAGBudget.API\*

Observation:
จากไฟล์ D:\TFS\OAG Budget\OAGBudget\Views\Budget\BudgetPaymentGfItemDetail.cshtml
ที่ปุ่ม "บันทึก" id="btn-save" เมื่อกดแล้ว ทำงานอย่างไรบ้าง จาก jQuery ทำงานอย่างไร
และเรียก Controller ใน C# แล้วทำอะไร เรียก method อะไร line ที่เท่าไหร่ มีการคำนวณ GL Segments ทั้ง 13 ตัว อย่างไร
สรุปลงใน D:\TFS\OAG Budget\brain_OAGBUDGET\budgetpaymentgfitemdetail\budgetpaymentgfitemdetail_1.md
```

```
จากไฟล์ budgetpaymentgfitemdetail_1.md ฟังก์ชัน `SaveBudgetPaymentGf` ใน BudgetService.cs อยู่บรรทัดไหน แล้วทำงานอย่างไรบ้าง save ลงที่ไหน
```

```
Context:
- D:\TFS\OAG Budget\*
- D:\TFS\OAG Budget\OAGBudget\*
- D:\TFS\OAG Budget\OAGBudget.API\*

Observation:
จากไฟล์ D:\TFS\OAG Budget\OAGBudget\Views\Budget\BudgetPaymentGfItemDetail.cshtml
ที่ปุ่ม "บันทึก" id="btn-save" เมื่อกดแล้ว จะบันทึกข้อมูลลง ตาราง OAGWBG_BUDGETRECEIVE อย่างไร
ด้วย method อะไร และทำงานอย่างไรบ้าง
สรุปลงใน D:\TFS\OAG Budget\brain_OAGBUDGET\budgetpaymentgfitemdetail\budgetpaymentgfitemdetail_2.md
```

```
Context:
- D:\TFS\OAG Budget\*
- D:\TFS\OAG Budget\OAGBudget\*
- D:\TFS\OAG Budget\OAGBudget.API\*

Observation:
จากไฟล์ D:\TFS\OAG Budget\OAGBudget\Views\Budget\BudgetPaymentGfMoreDetail.cshtml
ที่ปุ่ม "ยืนยัน" id="btn-Confirm" เมื่อกดแล้ว ทำงานอย่างไรบ้าง จาก jQuery ทำงานอย่างไร
และเรียก Controller ใน C# แล้วทำอะไร เรียก method อะไร line ที่เท่าไหร่ มีการคำนวณ GL Segments ทั้ง 13 ตัว อย่างไร
สรุปลงใน D:\TFS\OAG Budget\brain_OAGBUDGET\budgetpaymentgfmoredetail\budgetpaymentgfmoredetail_1.md
```

```
Context:
- D:\TFS\OAG Budget\*
- D:\TFS\OAG Budget\OAGBudget\*
- D:\TFS\OAG Budget\OAGBudget.API\*

Observation:
จากไฟล์ D:\TFS\OAG Budget\OAGBudget\Views\Budget\BudgetAllocateTransferDetail.cshtml
ที่ปุ่ม "บันทึก" id="btn-save" เมื่อกดแล้ว ทำงานอย่างไรบ้าง จาก jQuery ทำงานอย่างไร
และเรียก Controller ใน C# แล้วทำอะไร เรียก method อะไร line ที่เท่าไหร่ มีการคำนวณ GL Segments ทั้ง 13 ตัว อย่างไร
สรุปลงใน D:\TFS\OAG Budget\brain_OAGBUDGET\budgetalloctransferdetail\budgetalloctransferdetail_1.md
```

```
Context:
- D:\TFS\OAG Budget\*
- D:\TFS\OAG Budget\OAGBudget\*
- D:\TFS\OAG Budget\OAGBudget.API\*

Observation:
จากไฟล์ D:\TFS\OAG Budget\OAGBudget\Views\Budget\BudgetAllocateTransferDetail.cshtml
ที่ปุ่ม "ยืนยัน" id="btn-Confirm" เมื่อกดแล้ว ทำงานอย่างไรบ้าง จาก jQuery ทำงานอย่างไร
และเรียก Controller ใน C# แล้วทำอะไร เรียก method อะไร line ที่เท่าไหร่ มีการคำนวณ GL Segments ทั้ง 13 ตัว อย่างไร
สรุปลงใน D:\TFS\OAG Budget\brain_OAGBUDGET\budgetalloctransferdetail\budgetalloctransferdetail_2.md
```

```
Context:
- D:\TFS\OAG Budget\*
- D:\TFS\OAG Budget\OAGBudget\*
- D:\TFS\OAG Budget\OAGBudget.API\*

Observation:
ถ้าต้องการจะตัดยอดเงินของรายการที่จะโอนเงินออก ในตาราง OAGWBG_BUDGETRECEIVE โปรแกรมมีถูกเขียน Logic เงื่อนไขการตัดยอดเงินไว้ที่ไหนบ้าง
สรุปลงใน D:\TFS\OAG Budget\brain_OAGBUDGET\OAGWBG_BUDGETRECEIVE\OAGWBG_BUDGETRECEIVE_1.md
```

```
Context:
- D:\TFS\OAG Budget\*
- D:\TFS\OAG Budget\OAGBudget\*
- D:\TFS\OAG Budget\OAGBudget.API\*

Observation:
จากไฟล์ D:\TFS\OAG Budget\OAGBudget\Views\Budget\BudgetTransferDetail.cshtml
ที่ปุ่ม "ยืนยัน" id="btn-Confirm" เมื่อกดแล้ว ทำงานอย่างไรบ้าง จาก jQuery ทำงานอย่างไร
และเรียก Controller ใน C# แล้วทำอะไร เรียก method อะไร line ที่เท่าไหร่ มีการคำนวณ GL Segments ทั้ง 13 ตัว อย่างไร
สรุปลงใน D:\TFS\OAG Budget\brain_OAGBUDGET\budgettransferdetail\budgettransferdetail_1.md
```

```
Context:
- D:\TFS\OAG Budget\*
- D:\TFS\OAG Budget\OAGBudget\*
- D:\TFS\OAG Budget\OAGBudget.API\*

Observation:
จากไฟล์ D:\TFS\OAG Budget\OAGBudget\Views\Budget\BudgetTransferDetail.cshtml
ที่ปุ่ม "บันทึก" id="btn-save" เมื่อกดแล้ว จะบันทึกข้อมูลลง ตาราง OAGWBG_BUDGETRECEIVE อย่างไร
ด้วย method อะไร และทำงานอย่างไรบ้าง
สรุปลงใน D:\TFS\OAG Budget\brain_OAGBUDGET\budgettransferdetail\budgettransferdetail_2.md
```

```
จากไฟล์ D:\TFS\OAG Budget\brain_OAGBUDGET\budgettransferdetail\budgettransferdetail_2.md ข้อ 5 บรรทัดที่ 14064 คืออยู่ในไฟล์อะไร method อะไร
```