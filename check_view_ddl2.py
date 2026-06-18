import oracledb, re, os

settings = open(r'D:\TFS\OAG Budget\OAGBudget.API\appsettings.Development.json', encoding='utf-8-sig').read()
lines = [l for l in settings.splitlines() if not l.strip().startswith('//')]
cs = re.search(r'"OAGDBContext"\s*:\s*"([^"]+)"', '\n'.join(lines)).group(1)
host = re.search(r'HOST=([^)]+)', cs).group(1)
port = re.search(r'PORT=([^)]+)', cs).group(1)
svc  = re.search(r'SERVICE_NAME=([^)]+)', cs).group(1)
user = re.search(r'User Id=([^;]+)', cs, re.IGNORECASE).group(1)
pwd  = re.search(r'Password=([^;]+)', cs, re.IGNORECASE).group(1)

oracledb.init_oracle_client(lib_dir=r'C:\ORACLE\instantclient_19_22')
conn = oracledb.connect(user=user, password=pwd, dsn=f'{host}:{port}/{svc}')
cur  = conn.cursor()

# 1. หา View ที่ชื่อคล้าย BUDGETTRANSFER_CHANGE หรือ BUDGETADJUST
cur.execute("""
    SELECT VIEW_NAME FROM ALL_VIEWS
    WHERE VIEW_NAME LIKE '%BUDGETTRANSFER%CHANGE%'
       OR VIEW_NAME LIKE '%BUDGETADJUST%'
    ORDER BY VIEW_NAME
""")
print("=== Views BUDGETTRANSFER_CHANGE / BUDGETADJUST ===")
for r in cur.fetchall():
    print(" ", r[0])

# 2. ตรวจสอบว่า J-type record มี CATEGORYID, PRODUCTID ไหม
cur.execute("""
    SELECT COUNT(*), COUNT(CATEGORYID), COUNT(PRODUCTID), COUNT(ACTIVITYID)
    FROM OAGWBG_BUDGETRECEIVE
    WHERE BUDGETRECEIVETYPE = 'J'
    AND ROWNUM <= 1000
""")
row = cur.fetchone()
print(f"\n=== J-type records (sample 1000) ===")
print(f"  total          = {row[0]}")
print(f"  with CATEGORYID  = {row[1]}")
print(f"  with PRODUCTID   = {row[2]}")
print(f"  with ACTIVITYID  = {row[3]}")

# 3. ดู sample J-type record ล่าสุด
cur.execute("""
    SELECT ID, BUDGETADJUSTID, CATEGORYID, PRODUCTID, ACTIVITYID,
           BUDGETRECEIVESTATUS, TOTALRECEIVEAMOUNT, TOTALBALANCEAMOUNT
    FROM OAGWBG_BUDGETRECEIVE
    WHERE BUDGETRECEIVETYPE = 'J'
    ORDER BY ID DESC
    FETCH FIRST 5 ROWS ONLY
""")
print(f"\n=== J-type records (latest 5) ===")
print(f"  {'ID':>8} | {'ADJID':>6} | {'CATID':>6} | {'PROD':>6} | {'ACT':>6} | STATUS   | RCV_AMT     | BAL_AMT")
for r in cur.fetchall():
    print(f"  {str(r[0]):>8} | {str(r[1] or ''):>6} | {str(r[2] or ''):>6} | {str(r[3] or ''):>6} | {str(r[4] or ''):>6} | {str(r[5] or ''):8} | {str(r[6] or ''):11} | {str(r[7] or '')}")

cur.close()
conn.close()
print("\nDone.")
