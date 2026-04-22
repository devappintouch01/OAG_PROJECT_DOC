Add-Type -Path 'D:\TFS\OAG Budget\OAGBudget.API\bin\Debug\net9.0\Oracle.ManagedDataAccess.dll'

$connStr = 'DATA SOURCE=(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(HOST=172.16.11.19)(PORT=1541)))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=ebs_PRE)));User Id=OAGWBG;Password=Oag#2025;'

try {
    $conn = New-Object Oracle.ManagedDataAccess.Client.OracleConnection($connStr)
    $conn.Open()
    Write-Host '=== Connection OK ==='

    # 1. Get view definition
    $sql1 = @"
SELECT DBMS_METADATA.GET_DDL('VIEW','OAGWBG_V_BUDGET_OVERLAPYEAR_CENTRAL_DETAIL_INTERFACE','OAGWBG') AS VIEW_DDL FROM DUAL
"@
    $cmd1 = New-Object Oracle.ManagedDataAccess.Client.OracleCommand($sql1, $conn)
    $cmd1.InitialLOBFetchSize = -1
    try {
        $reader1 = $cmd1.ExecuteReader()
        if ($reader1.Read()) {
            Write-Host '=== VIEW DDL ==='
            Write-Host $reader1[0].ToString()
        } else {
            Write-Host 'DDL not found'
        }
        $reader1.Close()
    } catch {
        Write-Host "DDL Error: $_"
        
        # Try alternate: query ALL_VIEWS
        $sql2 = @"
SELECT TEXT FROM ALL_VIEWS 
WHERE UPPER(VIEW_NAME) = 'OAGWBG_V_BUDGET_OVERLAPYEAR_CENTRAL_DETAIL_INTERFACE'
"@
        $cmd2 = New-Object Oracle.ManagedDataAccess.Client.OracleCommand($sql2, $conn)
        $reader2 = $cmd2.ExecuteReader()
        if ($reader2.Read()) {
            Write-Host '=== VIEW TEXT (ALL_VIEWS) ==='
            Write-Host $reader2['TEXT'].ToString()
        } else {
            Write-Host 'View not found in ALL_VIEWS'
        }
        $reader2.Close()
    }

    # 2. Get column list
    Write-Host ''
    Write-Host '=== COLUMNS ==='
    $sql3 = @"
SELECT COLUMN_ID, COLUMN_NAME, DATA_TYPE, DATA_LENGTH, NULLABLE
FROM ALL_TAB_COLUMNS
WHERE UPPER(TABLE_NAME) = 'OAGWBG_V_BUDGET_OVERLAPYEAR_CENTRAL_DETAIL_INTERFACE'
ORDER BY COLUMN_ID
"@
    $cmd3 = New-Object Oracle.ManagedDataAccess.Client.OracleCommand($sql3, $conn)
    $reader3 = $cmd3.ExecuteReader()
    while ($reader3.Read()) {
        Write-Host "$($reader3['COLUMN_ID']). $($reader3['COLUMN_NAME']) [$($reader3['DATA_TYPE'])($($reader3['DATA_LENGTH']))] NULL=$($reader3['NULLABLE'])"
    }
    $reader3.Close()

    $conn.Close()
    Write-Host '=== Done ==='
} catch {
    Write-Host "Connection Error: $_"
}
