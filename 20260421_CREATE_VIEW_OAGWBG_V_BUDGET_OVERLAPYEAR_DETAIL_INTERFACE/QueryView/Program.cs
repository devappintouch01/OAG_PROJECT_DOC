using Oracle.ManagedDataAccess.Client;

var connStr = "DATA SOURCE=(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(HOST=172.16.11.19)(PORT=1541)))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=ebs_PRE)));User Id=OAGWBG;Password=Oag#2025;";

try
{
    using var conn = new OracleConnection(connStr);
    conn.Open();
    Console.WriteLine("=== Connection OK ===");

    // 1. Sample rows REGION=P (without ROUNDINTERFACE constraint to see data)
    Console.WriteLine("\n=== SAMPLE ROWS (REGION=P) — all fields ===");
    var sql1 = @"
SELECT 
    I.ID, I.BUDGETYEAR AS I_BUDGETYEAR, I.BUDGETREVERSEDID,
    I.BOOKNUMBER, I.ACCOUNTCODE, I.CATEGORYCODE,
    I.ACTIVITYID, I.PRODUCTID, I.BUDGETPLANID,
    I.TOTALHASPOAMOUNT, I.TOTALHASPRAMOUNT, I.TOTALBALANCEAMOUNT,
    I.STATUSID, I.BUDGETRESERVEDTYPE,
    I.TRANSFERNO AS I_TRANSFERNO,
    I.CREATEBY, I.UPDATEBY, I.CREATEON, I.UPDATEON,
    BRS.ID AS BRS_ID,
    BRS.BUDGETYEAR AS BRS_BUDGETYEAR,
    BRS.DEPARTMENTID, BRS.COSTCENTERID, BRS.BUDGETSOURCEID,
    BRS.TRANSFERNO AS BRS_TRANSFERNO,
    BRS.TRANSFERDATE, BRS.BUDGETRESERVEDREGION, BRS.ROUNDINTERFACE,
    BRS.BUDGETRESERVEDTYPE AS BRS_RESERVEDTYPE
FROM OAGWBG_BUDGETRESERVEDITEM I
JOIN OAGWBG_BUDGETRESERVED BRS ON I.BUDGETREVERSEDID = BRS.ID
WHERE BRS.BUDGETRESERVEDREGION = 'P'
  AND ROWNUM <= 3";
    using (var cmd1 = new OracleCommand(sql1, conn))
    using (var rdr1 = cmd1.ExecuteReader())
    {
        int rowNum = 0;
        while (rdr1.Read())
        {
            rowNum++;
            Console.WriteLine($"\n--- Row {rowNum} ---");
            for (int i = 0; i < rdr1.FieldCount; i++)
                Console.WriteLine($"  {rdr1.GetName(i),-40} = {rdr1[i]}");
        }
        if (rowNum == 0) Console.WriteLine("No rows found REGION=P");
    }

    // 2. Check ACCOUNTCODE format — does it contain 13 segments?
    Console.WriteLine("\n=== ACCOUNTCODE SAMPLES (REGION=P) ===");
    var sql2 = @"
SELECT DISTINCT I.ACCOUNTCODE
FROM OAGWBG_BUDGETRESERVEDITEM I
JOIN OAGWBG_BUDGETRESERVED BRS ON I.BUDGETREVERSEDID = BRS.ID
WHERE BRS.BUDGETRESERVEDREGION = 'P'
  AND I.ACCOUNTCODE IS NOT NULL
  AND ROWNUM <= 5";
    using (var cmd2 = new OracleCommand(sql2, conn))
    using (var rdr2 = cmd2.ExecuteReader())
        while (rdr2.Read())
            Console.WriteLine($"  {rdr2["ACCOUNTCODE"]}");

    // 3. Check if OAGWBG_BUDGETRESERVED_BANKACCOUNT has REGION=P rows
    Console.WriteLine("\n=== BANKACCOUNT for REGION=P ===");
    var sql3 = @"
SELECT BRB.*, BRS.BUDGETRESERVEDREGION
FROM OAGWBG_BUDGETRESERVED_BANKACCOUNT BRB
JOIN OAGWBG_BUDGETRESERVED BRS ON BRB.RESERVEDID = BRS.ID
WHERE BRS.BUDGETRESERVEDREGION = 'P'
  AND ROWNUM <= 3";
    try
    {
        using var cmd3 = new OracleCommand(sql3, conn);
        using var rdr3 = cmd3.ExecuteReader();
        int r3 = 0;
        while (rdr3.Read())
        {
            r3++;
            Console.WriteLine($"  RESERVEDID={rdr3["RESERVEDID"]} BANKACCOUNTGIVER={rdr3["BANKACCOUNTGIVER"]} BANKACCOUNTRECEIVER={rdr3["BANKACCOUNTRECEIVER"]}");
        }
        if (r3 == 0) Console.WriteLine("  No bankaccount rows for REGION=P");
    }
    catch (Exception ex3) { Console.WriteLine($"  BankAccount error: {ex3.Message}"); }

    // 4. Check OAGWBG_BUDGETRESERVED columns relevant to item
    Console.WriteLine("\n=== OAGWBG_BUDGETRESERVED key columns ===");
    var sql4 = @"
SELECT COLUMN_NAME, DATA_TYPE, DATA_LENGTH
FROM ALL_TAB_COLUMNS
WHERE OWNER = 'OAGWBG' AND TABLE_NAME = 'OAGWBG_BUDGETRESERVED'
  AND COLUMN_NAME IN ('ID','BUDGETYEAR','DEPARTMENTID','COSTCENTERID','BUDGETSOURCEID',
                      'TRANSFERNO','TRANSFERDATE','BUDGETRESERVEDREGION','ROUNDINTERFACE',
                      'BUDGETRESERVEDTYPE','BUDGETRESERVEDID')
ORDER BY COLUMN_ID";
    using (var cmd4 = new OracleCommand(sql4, conn))
    using (var rdr4 = cmd4.ExecuteReader())
        while (rdr4.Read())
            Console.WriteLine($"  {rdr4["COLUMN_NAME"],-40} {rdr4["DATA_TYPE"]}({rdr4["DATA_LENGTH"]})");

    Console.WriteLine("\n=== Done ===");
}
catch (Exception ex) { Console.WriteLine($"Error: {ex.Message}\n{ex.StackTrace}"); }
