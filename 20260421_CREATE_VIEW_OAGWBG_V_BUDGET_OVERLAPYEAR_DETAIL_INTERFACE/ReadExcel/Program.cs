using OfficeOpenXml;

ExcelPackage.LicenseContext = OfficeOpenXml.LicenseContext.NonCommercial;

var filePath = @"D:\TFS\OAG Budget\brain_OAGBUDGET\20260421_CREATE_VIEW_OAGWBG_V_BUDGET_OVERLAPYEAR_DETAIL_INTERFACE\OAGWBG_V_BUDGET_OVERLAPYEAR_DETAIL_INTERFACE.xlsx";

using var package = new ExcelPackage(new FileInfo(filePath));

foreach (var sheet in package.Workbook.Worksheets)
{
    Console.WriteLine($"\n=== Sheet: {sheet.Name} ===");
    
    var maxRow = sheet.Dimension?.End.Row ?? 0;
    var maxCol = sheet.Dimension?.End.Column ?? 0;
    
    Console.WriteLine($"Rows: {maxRow}, Cols: {maxCol}");
    
    // Print all rows - first 50 only
    int limit = Math.Min(maxRow, 50);
    for (int row = 1; row <= limit; row++)
    {
        var rowData = new List<string>();
        bool hasContent = false;
        for (int col = 1; col <= maxCol; col++)
        {
            var cell = sheet.Cells[row, col];
            var txt = cell.Text?.Trim() ?? "";
            rowData.Add($"[{col}]{txt}");
            if (!string.IsNullOrEmpty(txt)) hasContent = true;
        }
        if (hasContent)
            Console.WriteLine($"Row {row}: {string.Join(" | ", rowData)}");
    }
}

Console.WriteLine("\n=== Done ===");
