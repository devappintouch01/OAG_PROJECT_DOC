import oracledb
import re, os

# อ่าน connection string ตรงจาก appsettings ด้วย regex (ไม่ parse JSON)
settings_path = os.path.join(os.path.dirname(__file__), '..', 'OAGBudget.API', 'appsettings.Development.json')
with open(settings_path, encoding='utf-8-sig') as f:
    raw = f.read()

# หา OAGDBContext ที่ไม่ได้ comment ออก
# กรอง line ที่มี comment ออกก่อน แล้วค่อย search
lines = [l for l in raw.splitlines() if not l.strip().startswith('//')]
clean = '\n'.join(lines)
m = re.search(r'"OAGDBContext"\s*:\s*"([^"]+)"', clean)
if not m:
    raise ValueError("OAGDBContext not found in appsettings")
cs = m.group(1)

host = re.search(r'HOST=([^)]+)', cs).group(1)
port = re.search(r'PORT=([^)]+)', cs).group(1)
svc  = re.search(r'SERVICE_NAME=([^)]+)', cs).group(1)
user = re.search(r'User Id=([^;]+)', cs, re.IGNORECASE).group(1)
pwd  = re.search(r'Password=([^;]+)', cs, re.IGNORECASE).group(1)

dsn = f"{host}:{port}/{svc}"
print(f"Connecting to {dsn} as {user} ...")
oracledb.init_oracle_client(lib_dir=r"C:\ORACLE\instantclient_19_22")

conn = oracledb.connect(user=user, password=pwd, dsn=dsn)
cur  = conn.cursor()

views = [
    'OAGWBG_V_BUDGETRECEIVE',
    'OAGWBG_V_BUDGETTRANSFER_CHANGES',
]

for vname in views:
    print(f"\n{'='*60}")
    print(f"VIEW: {vname}")
    print('='*60)
    cur.execute("SELECT TEXT FROM ALL_VIEWS WHERE VIEW_NAME = :v", v=vname)
    row = cur.fetchone()
    if row:
        print(row[0])
    else:
        print("NOT FOUND")

cur.close()
conn.close()
print("\nDone.")
