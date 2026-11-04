# Requirement & Design: คู่มือการใช้งานระบบ — เก็บ Path ใน DB + Upload + CRUD

> วันที่: 2026-09-15 · สถานะ: **🛠️ v6 — เขียนโค้ดแล้ว build ผ่าน (ยังไม่ checkin) · รอผู้ใช้รัน SQL `create_table_usermanual.sql` เอง · ความเสี่ยงหลายเครื่อง (10.2) ยังเปิดอยู่ ผู้ใช้ให้ดำเนินการต่อ**
> หน้าเกี่ยวข้อง: `/Document/UserManual`

## ประวัติการแก้ไข

| เวอร์ชัน | วันที่ | การเปลี่ยนแปลง |
|---|---|---|
| v1 | 2026-09-15 | Draft แรก + คำถาม Q1–Q10 |
| v2 | 2026-09-15 | อัปเดตตามคำตอบ: ต้อง upload, แก้ไข = แทนที่ไฟล์ที่ ID เดิม, hard delete, ปุ่มจัดการอยู่ในหน้า UserManual เฉพาะ Role 41 |
| v3 | 2026-09-15 | ยืนยัน Q11–Q16 · พบว่า publish profile เป็น `DeleteExistingFiles=true` → ไฟล์ที่อัปโหลดใน `wwwroot/documents` จะหายทุกครั้งที่ deploy → เพิ่ม Q17–Q18 |
| v4 | 2026-09-15 | Q17: **เก็บไฟล์ที่ `wwwroot/documents` เดิม** (ไม่ย้าย root ออกนอกโปรเจกต์ · ตัดทางเลือก A) · เพิ่ม Q19 เลือกวิธีกันไฟล์หายตอน deploy |
| v5 | 2026-09-15 | Q19 = (C) publish ไม่ลบไฟล์ปลายทาง · Q18 = MVC มากกว่า 1 เครื่อง → ไฟล์ไม่ sync ระหว่างเครื่อง → เพิ่ม blocker Q20–Q21 |
| v6 | 2026-09-15 | ผู้ใช้สั่ง "บน server ไม่เป็นไร ทำเลย" → implement ตามหัวข้อ 5–6 · Q20/Q21 ยังไม่ได้คำตอบ (ความเสี่ยงยังอยู่) · ผู้ใช้รัน SQL เอง · ดูสรุปงานที่หัวข้อ 13 |

---

## 1. สภาพปัจจุบัน (As-Is)

| รายการ | รายละเอียด |
|---|---|
| Controller | `OAGBudget/Controllers/DocumentController.cs` → `UserManual()` |
| วิธีดึงข้อมูล | `Directory.GetFiles(wwwroot/documents, "*.pdf")` — สแกนโฟลเดอร์ตรง ไม่มี DB |
| ViewModel | `OAGBudget.Models/ViewModel/DocumentFileViewModel.cs` (`FileName`, `FileSizeFormatted`, `Url`) |
| View | `OAGBudget/Views/Document/UserManual.cshtml` — ตาราง ชื่อเอกสาร / ขนาด / ดาวน์โหลด |
| ลิงก์ดาวน์โหลด | `~/documents/{FileName}` (static file ของ wwwroot) |
| ทางเข้า | ปุ่ม "เอกสาร & คู่มือการใช้งาน" ใน `Views/Shared/_LayoutSideMenu.cshtml:59` (hard-code ไม่ได้ผ่าน SYSTEMMENU) |

ไฟล์ที่มีอยู่ตอนนี้ใน `OAGBudget/wwwroot/documents/`:

| ไฟล์ | ขนาด | อยู่ใน publish? (`OAGBudget.csproj`) |
|---|---|---|
| `00.OAG_User_Manual_BGT_[ตัวอย่าง] การจัดการงบประมาณ.pdf` | 0.06 MB | ❌ `Content Remove` (บรรทัด 39) |
| `02.OAG_User_Manual_BGT_[ตัวอย่าง] การจัดการข้อมูลต่างๆ.pdf` | 0.06 MB | ❌ `Content Remove` (บรรทัด 40) |
| `02.OAG_User_Manual_BG_ระบบงบประมาณ_V2.2.pdf` | **19.71 MB** | ✅ ถูก publish ไปด้วย |

**ปัญหาของวิธีเดิม**
- ชื่อที่แสดง = ชื่อไฟล์ แก้ชื่อที่แสดงไม่ได้ถ้าไม่ rename ไฟล์
- ลำดับการแสดงผลขึ้นกับการเรียงชื่อไฟล์
- เพิ่ม/เปลี่ยนคู่มือต้อง remote เข้าเซิร์ฟเวอร์ไปวางไฟล์เอง
- ไม่มี audit ว่าใครเพิ่ม/แก้เมื่อไร

---

## 2. เป้าหมาย (To-Be)

1. หน้า `UserManual` ดึงรายการคู่มือจาก **ตาราง `OAGWBG_USERMANUAL`** แล้วเปิดไฟล์ตาม **path** ที่เก็บไว้
2. ผู้ใช้ **Role 41** **อัปโหลดไฟล์** ผ่านหน้าเว็บ → ระบบบันทึกไฟล์ลง `wwwroot/documents` แล้วเก็บ path ลง DB ให้อัตโนมัติ
3. ผู้ใช้ Role 41 ทำ **C R U D** ได้ทีละรายการ **บนหน้า UserManual เดิม** (ปุ่มเพิ่ม/แก้/ลบ แสดงเฉพาะ Role 41)
4. **แก้ไข** = แทนที่ไฟล์เก่าด้วยไฟล์ใหม่ โดยใช้ **ID เดิม**
5. **ลบ** = hard delete แถวใน DB + ลบไฟล์จริง

### Out of scope
- หน้า Master แยก / เมนูใหม่ใน `OAGWBG_SYSTEMMENU`
- เก็บไฟล์เป็น BLOB ใน DB (แบบ `OAGWBG_ATTACHFILE`)
- เก็บประวัติเวอร์ชันของคู่มือ / เก็บไฟล์เก่าไว้
- คอลัมน์ `VERSIONNO`, `CATEGORY`, `EXTENSION` (Q9 — ยังไม่ต้อง)
- รองรับไฟล์อื่นนอกจาก PDF

---

## 3. สมมติฐานที่ใช้ในการออกแบบ

| # | สมมติฐาน | ที่มา |
|---|---|---|
| A1 | `FILEPATH` = **relative path ใต้ root folder** (`wwwroot/documents`) เช่น `9f3c1e2a....pdf` | ✅ Q1 (a) |
| A2 | ผู้ใช้ **อัปโหลดไฟล์ผ่านหน้าเว็บ** ระบบเขียนไฟล์ลง root folder เอง → **App Pool ของ IIS ต้องมีสิทธิ์ Write ที่ `wwwroot/documents`** | ✅ Q2 (b) |
| A3 | Root folder = `wwwroot/documents` เดิม บน **เครื่อง MVC (OAGBudget)** → MVC เป็นคนเขียน/ลบ/อ่านไฟล์ ส่วน API จัดการเฉพาะข้อมูลใน DB | ✅ Q3 |
| A4 | ปุ่มจัดการแสดง **เฉพาะ `CurrentSignInUser.UserRole.Id == 41`** และ action ฝั่ง server ต้องเช็ค role ซ้ำ (กันยิง POST ตรง) | ✅ Q4, Q5 (b) |
| A5 | ผู้ใช้ทุกคนที่ login เห็นหน้า UserManual เหมือนเดิม แสดงเฉพาะ `ACTIVE = '1'` · Role 41 เห็นทุกรายการ รวมที่ `ACTIVE = '0'` | ✅ Q11 |
| A6 | **แก้ไข**: เลือกไฟล์ใหม่หรือไม่ก็ได้ — ถ้าเลือก → ไฟล์ใหม่แทนที่ไฟล์เก่า (ID เดิม, ลบไฟล์เก่า) · ถ้าไม่เลือก → แก้แค่ชื่อ/คำอธิบาย/ลำดับ/สถานะ ไฟล์เดิมคงอยู่ | ✅ Q7 + Q12 |
| A7 | **ลบ**: hard delete แถว **และลบไฟล์จริง** ออกจาก root folder | ✅ Q7 (a) + Q13 |
| A10 | ขนาดไฟล์สูงสุด 50 MB | ✅ Q14 |
| A11 | จัดการได้ **เฉพาะ Role 41** (Role 1 ผู้ดูแลระบบก็ทำไม่ได้) | ✅ Q16 |
| A12 | เก็บไฟล์ที่ `wwwroot/documents` เดิม · publish เปลี่ยนเป็น **ไม่ลบไฟล์ปลายทาง** (`DeleteExistingFiles=false`) | ✅ Q3 + Q17 + Q19 (C) |
| A13 | 🔴 MVC **มากกว่า 1 เครื่อง** → `wwwroot/documents` ของแต่ละเครื่องแยกกัน ต้องทำให้ทุกเครื่องเห็นไฟล์ชุดเดียวกัน (Q20) | ✅ Q18 → ขัดกับ A3 |
| A8 | รองรับเฉพาะ `.pdf` | ✅ Q9 |
| A9 | Q6 "block ไม่ให้บันทึก" → เมื่อ path สร้างอัตโนมัติจากการ upload จึงตีความเป็น: **block ถ้า** สร้างใหม่แต่ไม่ได้แนบไฟล์ / ไฟล์ไม่ใช่ PDF / ไฟล์ใหญ่เกินกำหนด / เขียนไฟล์ลง folder ไม่สำเร็จ | ✅ Q6 (a) ตีความใหม่ |

---

## 4. ออกแบบตาราง

### 4.1 `OAGWBG_USERMANUAL`

| Column | Type | Null | Default | คำอธิบาย |
|---|---|---|---|---|
| `ID` | `NUMBER(10)` IDENTITY | N | — | PK |
| `MANUALNAME` | `VARCHAR2(500)` | N | — | ชื่อคู่มือที่แสดงบนหน้าจอ |
| `DESCRIPTION` | `VARCHAR2(2000)` | Y | — | คำอธิบาย (แสดงในหน้า UserManual) |
| `FILEPATH` | `VARCHAR2(1000)` | N | — | path ของไฟล์ relative จาก root — **ระบบสร้างเอง ผู้ใช้แก้ไม่ได้** |
| `SEQUENCE` | `NUMBER(10)` | Y | — | ลำดับการแสดงผล |
| `ACTIVE` | `CHAR(1)` | N | `'1'` | `'1'` แสดง / `'0'` ซ่อน |
| `CREATEBY` | `NUMBER(10)` | N | `-1` | ผู้สร้าง อ้างอิง `OAGWBG_SYSTEMUSER.ID` |
| `CREATEON` | `TIMESTAMP(6)` | N | `SYSTIMESTAMP` | วันที่สร้าง |
| `UPDATEBY` | `NUMBER(10)` | Y | — | ผู้แก้ไข อ้างอิง `OAGWBG_SYSTEMUSER.ID` |
| `UPDATEON` | `TIMESTAMP(6)` | Y | — | วันที่แก้ไข |

> ชื่อคอลัมน์ audit ใช้ `CREATEON` / `UPDATEON` ตาม convention ทั้งระบบ

> ⚠️ ต้องเช็ค NLS ของ DB ก่อน: ถ้า charset เป็น `AL32UTF8` ภาษาไทย 1 ตัว = 3 byte → `VARCHAR2(500)` เก็บไทยได้ ~166 ตัว ควรใช้ `VARCHAR2(500 CHAR)` แทน
> `SELECT value FROM nls_database_parameters WHERE parameter = 'NLS_CHARACTERSET';`

### 4.2 DDL (draft)

```sql
CREATE TABLE OAGWBG_USERMANUAL (
    ID          NUMBER(10) GENERATED BY DEFAULT AS IDENTITY NOT NULL,
    MANUALNAME  VARCHAR2(500)  NOT NULL,
    DESCRIPTION VARCHAR2(2000),
    FILEPATH    VARCHAR2(1000) NOT NULL,
    SEQUENCE    NUMBER(10),
    ACTIVE      CHAR(1)        DEFAULT '1' NOT NULL,
    CREATEBY    NUMBER(10)     DEFAULT -1 NOT NULL,
    CREATEON    TIMESTAMP(6)   DEFAULT SYSTIMESTAMP NOT NULL,
    UPDATEBY    NUMBER(10),
    UPDATEON    TIMESTAMP(6),
    CONSTRAINT PK_OAGWBG_USERMANUAL PRIMARY KEY (ID)
);

COMMENT ON TABLE  OAGWBG_USERMANUAL             IS 'คู่มือการใช้งานระบบ';
COMMENT ON COLUMN OAGWBG_USERMANUAL.ID          IS 'รหัสอ้างอิงที่ใช้ในระบบ';
COMMENT ON COLUMN OAGWBG_USERMANUAL.MANUALNAME  IS 'ชื่อคู่มือ';
COMMENT ON COLUMN OAGWBG_USERMANUAL.DESCRIPTION IS 'คำอธิบาย';
COMMENT ON COLUMN OAGWBG_USERMANUAL.FILEPATH    IS 'path ของไฟล์คู่มือ (relative จาก wwwroot/documents)';
COMMENT ON COLUMN OAGWBG_USERMANUAL.SEQUENCE    IS 'ลำดับการแสดงผล';
COMMENT ON COLUMN OAGWBG_USERMANUAL.ACTIVE      IS 'สถานะการใช้งาน (1=ใช้งาน, 0=ไม่ใช้งาน)';
COMMENT ON COLUMN OAGWBG_USERMANUAL.CREATEBY    IS 'ผู้สร้าง อ้างอิง OAGWBG_SYSTEMUSER.ID';
COMMENT ON COLUMN OAGWBG_USERMANUAL.CREATEON    IS 'วันที่สร้าง';
COMMENT ON COLUMN OAGWBG_USERMANUAL.UPDATEBY    IS 'ผู้แก้ไข อ้างอิง OAGWBG_SYSTEMUSER.ID';
COMMENT ON COLUMN OAGWBG_USERMANUAL.UPDATEON    IS 'วันที่แก้ไข';
```

### 4.3 Seed ข้อมูลเดิม 3 ไฟล์ (✅ Q10 ยืนยันแล้ว)

ไฟล์เดิมคงชื่อไฟล์เดิมไว้ ไม่ rename — ไฟล์ที่อัปโหลดใหม่หลังจากนี้ถึงจะใช้ชื่อแบบ GUID (ข้อ 6.2)

```sql
INSERT INTO OAGWBG_USERMANUAL (MANUALNAME, FILEPATH, SEQUENCE, ACTIVE, CREATEBY)
VALUES ('[ตัวอย่าง] การจัดการงบประมาณ',
        '00.OAG_User_Manual_BGT_[ตัวอย่าง] การจัดการงบประมาณ.pdf', 1, '1', -1);
INSERT INTO OAGWBG_USERMANUAL (MANUALNAME, FILEPATH, SEQUENCE, ACTIVE, CREATEBY)
VALUES ('[ตัวอย่าง] การจัดการข้อมูลต่างๆ',
        '02.OAG_User_Manual_BGT_[ตัวอย่าง] การจัดการข้อมูลต่างๆ.pdf', 2, '1', -1);
INSERT INTO OAGWBG_USERMANUAL (MANUALNAME, FILEPATH, SEQUENCE, ACTIVE, CREATEBY)
VALUES ('คู่มือระบบงบประมาณ V2.2',
        '02.OAG_User_Manual_BG_ระบบงบประมาณ_V2.2.pdf', 3, '1', -1);
COMMIT;
```

### 4.4 Rollback

```sql
DROP TABLE OAGWBG_USERMANUAL PURGE;
```
> ไฟล์ที่อัปโหลดเข้า `wwwroot/documents` ระหว่างใช้งาน **ไม่ถูกลบตาม** ต้อง backup/ลบเองถ้าต้องการ

---

## 5. Architecture & ไฟล์ที่ต้องแก้

```
[Browser] หน้า UserManual
   │  multipart/form-data (ไฟล์ + ข้อมูล)
   ▼
[MVC  OAGBudget]  DocumentController
   │  ├─ เช็ค Role 41
   │  ├─ validate ไฟล์ + เขียน/ลบไฟล์ใน wwwroot/documents   ← ไฟล์อยู่ฝั่ง MVC เท่านั้น
   │  └─ HTTP (JSON ไม่มีไฟล์) ──►
   ▼
[API  OAGBudget.API]  MasterController → MasterService → EF → OAGWBG_USERMANUAL
```

### 5.1 DAL / Models

| ไฟล์ | การเปลี่ยนแปลง |
|---|---|
| `OAGBudget.DAL/Models/OagwbgUsermanual.cs` | **ใหม่** — entity |
| `OAGBudget.DAL/Models/OAGDBContextBase.cs` | เพิ่ม `DbSet<OagwbgUsermanual>` + `modelBuilder.Entity<...>` (`HasKey`, `ValueGeneratedOnAdd` ที่ ID) |
| `OAGBudget.Models/ViewModel/DocumentFileViewModel.cs` | เพิ่ม `Id`, `Description`, `Sequence`, `Active`, `UpdatedOn`, `FileExists` |
| `OAGBudget.Models/ViewModel/SaveUserManualViewModel.cs` | **ใหม่** — `Id`, `ManualName`, `Description`, `Sequence`, `Active`, `IFormFile? File` (มีตัวอย่างการใช้ `IFormFile` ใน Models แล้ว เช่น `SaveBudgetRequestOutsideViewModel.cs:34`) |

### 5.2 API (`OAGBudget.API`)

| ไฟล์ | การเปลี่ยนแปลง |
|---|---|
| `Controllers/MasterController.cs` | เพิ่ม `#region UserManual`: `GetListUserManual(bool includeInactive)`, `GetUserManualById`, `SaveUserManual`, `DeleteUserManual` |
| `Services/Repository/MasterService.cs` | interface + impl 4 methods — **Save ต้อง set `Updateby/Updateon` ตอน edit และไม่ override `Createby`** (อย่าซ้ำ bug ที่พบใน `SaveMasterUnit` ที่ hard-code `Createby`) · Save ต้องคืน `Id` ของรายการที่บันทึก |

### 5.3 Frontend MVC (`OAGBudget`)

| ไฟล์ | การเปลี่ยนแปลง |
|---|---|
| `Services/Repository/MasterService.cs` | เพิ่ม 4 methods เรียก API |
| `Controllers/DocumentController.cs` | inject `IMasterService` · `UserManual()` ดึงจาก DB แทน `Directory.GetFiles` · เพิ่ม `UserManualDetail(id, mode)` (modal), `SaveUserManual(SaveUserManualViewModel)`, `DeleteUserManual(id)`, `DownloadManual(id)` |
| `Views/Document/UserManual.cshtml` | เพิ่มคอลัมน์ คำอธิบาย / วันที่อัพเดทล่าสุด · ปุ่ม "เพิ่มคู่มือ" + ปุ่มแก้ไข/ลบ รายแถว แสดงเฉพาะ Role 41 · ลิงก์ดาวน์โหลดใช้ `id` |
| `Views/Document/_partialView/_modalUserManual.cshtml` | **ใหม่** — Modal เพิ่ม/แก้ไข: ชื่อ, คำอธิบาย, ลำดับ, สถานะ, เลือกไฟล์ (แสดงชื่อไฟล์ปัจจุบันตอนแก้ไข) |
| `Program.cs` | ⚠️ อาจต้องปรับ upload limit (ข้อ 8) |

> Role 41 ใช้ค่าคงที่เดียวใน `DocumentController` (เช่น `private const int UserManualAdminRoleId = 41;`) และส่งผลลัพธ์ `ViewBag.CanManage` ให้ view — ไม่ hard-code `41` กระจายหลายที่
> วิธีอ่าน role ใช้แบบเดียวกับที่ระบบใช้อยู่: `new Appz(HttpContext).CurrentSignInUser?.UserRole?.Id` (ตัวอย่าง `Views/Budget/BudgetReserveTransferDetail.cshtml:85-87`)

---

## 6. Business Rules

### 6.1 หน้า UserManual — แสดงผล

| คอลัมน์ | ที่มา | หมายเหตุ |
|---|---|---|
| ชื่อเอกสาร | `MANUALNAME` | |
| คำอธิบาย | `DESCRIPTION` | ✅ Q8 — ว่างแสดง `-` |
| ขนาด | คำนวณจากไฟล์จริงตอน render | หาไฟล์ไม่เจอแสดง `-` และปิดปุ่มดาวน์โหลด |
| วันที่อัพเดทล่าสุด | `UPDATEON ?? CREATEON` | ✅ Q8 — รูปแบบ `dd/MM/yyyy HH:mm` (พ.ศ. ตาม culture `th-TH` ของระบบ) |
| ดาวน์โหลด | `Url.Action("DownloadManual", "Document", new { id })` | **ห้ามส่ง FILEPATH ไป browser** |
| สถานะ | `ACTIVE` | แสดงเฉพาะ Role 41 |
| จัดการ | ปุ่ม แก้ไข / ลบ | แสดงเฉพาะ Role 41 |

- เรียงตาม `SEQUENCE` แล้วตาม `MANUALNAME`
- ผู้ใช้ทั่วไปเห็นเฉพาะ `ACTIVE = '1'` · Role 41 เห็นทุกรายการ (Q11)

### 6.2 Create (เพิ่มคู่มือ)

**Validation — ไม่ผ่านข้อใด → block ไม่บันทึก (Q6)**

| Field | Rule | ข้อความ |
|---|---|---|
| (สิทธิ์) | `UserRole.Id == 41` | ไม่มีสิทธิ์ดำเนินการ |
| ชื่อคู่มือ | บังคับ, ≤ 500, ห้ามซ้ำ (trim + ignore case) | กรุณาระบุชื่อคู่มือ / ชื่อคู่มือนี้มีอยู่ในระบบแล้ว |
| ไฟล์ | **บังคับ** | กรุณาเลือกไฟล์คู่มือ |
| ไฟล์ | นามสกุล `.pdf` **และ** 5 byte แรกเป็น `%PDF-` (กันเปลี่ยนนามสกุลไฟล์อื่น) | รองรับเฉพาะไฟล์ PDF |
| ไฟล์ | ขนาด ≤ 50 MB (Q14) | ไฟล์มีขนาดเกิน 50 MB |
| ลำดับ | ตัวเลข ≥ 0 ไม่บังคับ | |
| สถานะ | `1` / `0` default `1` | |
| คำอธิบาย | ไม่บังคับ, ≤ 2000 | |

**การตั้งชื่อไฟล์บน server:** `{Guid:N}.pdf` (เช่น `9f3c1e2a4b5d4e6f8a7b9c0d1e2f3a4b.pdf`)
- ไม่ใช้ชื่อไฟล์ที่ผู้ใช้อัปโหลด → กันชื่อซ้ำ, กันอักขระพิเศษ/path traversal, เดา URL ไม่ได้
- ชื่อที่ผู้ใช้เห็นตอนเปิดไฟล์ = `MANUALNAME.pdf` (ส่งผ่าน `Content-Disposition`)

**ลำดับการทำงาน**
```
1. เช็คสิทธิ์ + validate ทั้งหมด
2. เขียนไฟล์ → wwwroot/documents/{guid}.pdf
      └─ ล้มเหลว → return error (ยังไม่แตะ DB)
3. เรียก API SaveUserManual (FILEPATH = {guid}.pdf, CREATEBY = user.User.Id, CREATEON = now)
      └─ ล้มเหลว → ลบไฟล์ {guid}.pdf ที่เพิ่งเขียน → return error
4. return success → reload ตาราง
```

### 6.3 Update (แก้ไข — ID เดิม)

Validation เหมือน 6.2 ยกเว้น **ไฟล์ไม่บังคับ** (Q12) และเช็คชื่อซ้ำไม่นับตัวเอง

**กรณีไม่ได้เลือกไฟล์ใหม่**
```
1. เรียก API SaveUserManual (FILEPATH เดิม, UPDATEBY/UPDATEON)
```

**กรณีเลือกไฟล์ใหม่ — แทนที่ไฟล์เก่าที่ ID เดิม**
```
1. ดึง record เดิม → oldPath
2. เขียนไฟล์ใหม่ → wwwroot/documents/{newGuid}.pdf
      └─ ล้มเหลว → return error (ไฟล์เก่า + DB ไม่เปลี่ยน)
3. เรียก API SaveUserManual (ID เดิม, FILEPATH = {newGuid}.pdf, UPDATEBY/UPDATEON)
      └─ ล้มเหลว → ลบไฟล์ใหม่ → return error (ไฟล์เก่า + DB ไม่เปลี่ยน)
4. ลบไฟล์เก่า oldPath
      └─ ล้มเหลว → log ไว้ แต่ยังถือว่าสำเร็จ (ผู้ใช้ได้ไฟล์ใหม่แล้ว เหลือแค่ไฟล์ขยะ)
5. return success
```

> **ทำไม "เขียนใหม่ก่อน ลบเก่าทีหลัง"** แทน "ลบเก่าก่อน":
> ถ้าลบไฟล์เก่าก่อนแล้วเขียนไฟล์ใหม่หรือบันทึก DB ไม่สำเร็จ คู่มือรายการนั้นจะหายทันที (DB ชี้ไปไฟล์ที่ไม่มีแล้ว)
> ผลลัพธ์สุดท้ายเหมือนกัน คือ ID เดิม + ไฟล์ใหม่ + ไฟล์เก่าถูกลบ

### 6.4 Delete (hard delete)
```
1. เช็คสิทธิ์ → Swal confirm ฝั่ง browser
2. ดึง record → oldPath
3. เรียก API DeleteUserManual(id)
      └─ ล้มเหลว → return error (ไฟล์ยังอยู่)
4. ลบไฟล์ oldPath (ไม่มีไฟล์อยู่แล้ว = ข้าม)
      └─ ล้มเหลว → log ไว้ แต่ยังถือว่าสำเร็จ
5. return success
```

### 6.5 `DownloadManual(int id)` + การ resolve path (ใช้ร่วมกันทุกที่ที่แตะไฟล์)
```
1. ดึง record → ไม่พบ → 404
   ACTIVE='0' และผู้ใช้ไม่ใช่ Role 41 → 404
2. root     = Path.GetFullPath(Path.Combine(WebRootPath, "documents")) + separator
3. fullPath = Path.GetFullPath(Path.Combine(root, FILEPATH))
4. fullPath ต้องขึ้นต้นด้วย root → ไม่ใช่ → 400   (กัน FILEPATH เช่น ..\..\appsettings.json)
5. !File.Exists(fullPath) → แจ้ง "ไม่พบไฟล์คู่มือ"
6. PhysicalFile(fullPath, "application/pdf") + Content-Disposition: inline; filename*=UTF-8''{MANUALNAME}.pdf
   → เปิดใน tab ใหม่เหมือนเดิม
```
> ข้อ 2–4 ใช้ใน helper เดียวกันตอนลบไฟล์ (6.3, 6.4) ด้วย กันการลบไฟล์นอก folder

---

## 7. เมนู & สิทธิ์

- **ไม่ต้อง insert `OAGWBG_SYSTEMMENU` / `OAGWBG_SYSTEMMENUROLEASSIGN`** (Q5 = ปุ่มอยู่ในหน้าเดิม)
- ปุ่ม "เอกสาร & คู่มือการใช้งาน" ใน sidebar คงเดิม ทุก role เข้าได้
- สิทธิ์จัดการเช็คจาก `UserRole.Id == 41` **ทั้งใน view (ซ่อนปุ่ม) และใน action ฝั่ง server** (`UserManualDetail`, `SaveUserManual`, `DeleteUserManual`)

---

## 8. ความเสี่ยง / สิ่งที่ต้องเตรียมบน server

| # | ประเด็น | ระดับ | รายละเอียด / ทางแก้ |
|---|---|---|---|
| R1 | **สิทธิ์ Write ของ IIS App Pool** ที่ `wwwroot/documents` | ต้องทำก่อน go-live | ถ้าไม่ให้สิทธิ์ → upload/แก้/ลบ error ทุกครั้ง · ต้องขอทีม infra ให้ identity ของ App Pool มีสิทธิ์ Modify เฉพาะ folder นี้ |
| R2 | **Deploy ลบไฟล์ที่อัปโหลด** | 🔴 **ยืนยันแล้วว่าเกิด** | Q15 = deploy แบบลบไฟล์ปลายทาง · publish profile ทั้งหมดเป็น `WebPublishMethod=FileSystem` + `DeleteExistingFiles=true` (`FolderProfile1.pubxml:7` → `D:\Publish\OAGBudget\web`) → **ทุกครั้งที่ deploy ไฟล์ที่ผู้ใช้อัปโหลดใน `wwwroot/documents` หายหมด แต่แถวใน DB ยังอยู่ → หน้า UserManual ขึ้น `-` ทุกรายการ** · Q17 = เก็บที่ `wwwroot/documents` เดิม · **Q19 = (C)** เปลี่ยน publish profile ที่ใช้ deploy จริงเป็น `DeleteExistingFiles=false` · ⚠️ ครอบคลุมเฉพาะขั้น publish — ถ้าขั้น copy จาก publish folder ขึ้นแต่ละเครื่องลบ folder ปลายทางเอง ไฟล์ยังหาย (Q21) |
| R3 | ไฟล์ V2.2 ถูก publish ไปด้วย (csproj) | ต่ำ | ถ้าผู้ใช้แทนที่/ลบ V2.2 ผ่านหน้าเว็บ แล้ว deploy รอบถัดไป ไฟล์ V2.2 เดิมจะถูก copy กลับมา (เป็นไฟล์ขยะ ไม่แสดงเพราะไม่มีแถวใน DB) · แนะนำเพิ่ม `Content Remove` ให้ V2.2 เหมือนอีก 2 ไฟล์ |
| R4 | **ขนาดไฟล์ upload** | ⚠️ กลาง | `Program.cs:70` ตั้ง `MultipartBodyLengthLimit = 50 MB` แต่ **IIS default `maxAllowedContentLength` ≈ 28.6 MB** (ไม่พบ `web.config` ในโปรเจกต์ ต้องเช็คบน server) · V2.2 ขนาด 19.71 MB แล้ว เวอร์ชันถัดไปอาจเกิน · ต้องตั้ง `maxAllowedContentLength` บน server ให้ ≥ 50 MB + ใส่ `[RequestSizeLimit]` ที่ `SaveUserManual` |
| R5 | ไฟล์ใน `wwwroot` เปิดได้โดยไม่ต้อง login | ต่ำ | `Program.cs:139` `UseStaticFiles()` อยู่ก่อน `UseAuthentication()` → ใครรู้ URL `/documents/xxx.pdf` ก็เปิดได้ (เหมือนปัจจุบัน) · ไฟล์ใหม่ใช้ชื่อ GUID เดาไม่ได้ · ถ้าต้องการปิดจริงต้องย้าย root ออกนอก wwwroot (นอก scope) |
| R6 | MVC หลาย node / load balance | 🔴 **ยืนยันแล้วว่าเกิด** | Q18 = มากกว่า 1 เครื่อง → ไฟล์อยู่แค่เครื่องที่รับ request ตอน upload · ผู้ใช้ที่ถูก load balance ไปเครื่องอื่นเปิดไม่ได้ · แก้ไข/ลบ ลบไฟล์ได้แค่เครื่องเดียว → ทางแก้ดู Q20 (หัวข้อ 10.2) |
| R7 | สร้างตารางใหม่ใน PREPROD | R1 (reversible) | rollback = `DROP TABLE` |
| R8 | ลำดับ deploy | — | **ต้องสร้างตาราง + seed ก่อน deploy code** ไม่งั้นหน้า UserManual จะว่าง |
| R9 | ไฟล์ขยะ (orphan) | ต่ำ | เกิดเมื่อลบไฟล์เก่าไม่สำเร็จ (6.3 ข้อ 4, 6.4 ข้อ 4) · มี log ไว้ ลบเองภายหลังได้ |

**Blast radius:** 1 หน้า (UserManual) + ตารางใหม่ 1 ตาราง · ไม่กระทบโมดูลงบประมาณ

---

## 9. ✅ คำตอบรอบแรก (ยืนยันแล้ว 2026-09-15)

| # | คำถาม | คำตอบ |
|---|---|---|
| Q1 | "path" หมายถึงอะไร | (a) relative path ใต้ root folder บนเซิร์ฟเวอร์ |
| Q2 | ต้องอัปโหลดไฟล์ไหม | (b) อัปโหลด → ระบบบันทึกไฟล์ลง root แล้วเก็บ path ให้อัตโนมัติ |
| Q3 | ไฟล์เก็บที่ไหน | `wwwroot/documents` เดิม |
| Q4 | ใครจัดการได้ | `UserRole.Id = 41` |
| Q5 | หน้าจัดการอยู่ที่ไหน | (b) ปุ่มเพิ่ม/แก้/ลบ ในหน้า UserManual เดิม |
| Q6 | ไฟล์ไม่ถูกต้อง | (a) block ไม่ให้บันทึก (ตีความตาม A9) |
| Q7 | ลบแบบไหน | (a) hard delete · แก้ไข = ลบไฟล์เก่า อัปไฟล์ใหม่ ที่ ID เดิม |
| Q8 | คอลัมน์หน้าผู้ใช้ | คงเดิม (ชื่อ, ขนาด, ดาวน์โหลด) + คำอธิบาย + วันที่อัพเดทล่าสุด |
| Q9 | คอลัมน์เพิ่ม | ยังไม่ต้อง |
| Q10 | ชื่อตาราง + ชื่อ seed | โอเค |

---

## 10. ✅ คำตอบรอบ 2 (ยืนยันแล้ว 2026-09-15)

| # | คำถาม | คำตอบ |
|---|---|---|
| Q11 | Role 41 เห็นรายการ `ACTIVE = '0'` ไหม | เห็น |
| Q12 | แก้ไขโดยไม่เลือกไฟล์ใหม่ได้ไหม | ได้ — แก้รายละเอียดอย่างเดียว ไฟล์ไม่เปลี่ยน |
| Q13 | ลบรายการ → ลบไฟล์จริงด้วยไหม | ลบ |
| Q14 | ขนาดไฟล์สูงสุด | 50 MB |
| Q15 | วิธี deploy | แบบลบไฟล์ปลายทาง → **ทำให้เกิด blocker 10.1** |
| Q16 | Role 1 จัดการได้ด้วยไหม | ไม่ — Role 41 เท่านั้น |

### 10.1 🔴 BLOCKER — Q3 (`wwwroot/documents`) ขัดกับ Q15 (deploy ลบไฟล์ปลายทาง)

**สิ่งที่จะเกิดถ้าทำตาม Q3 + Q15 ตรงๆ**
```
วันที่ 1  Role 41 อัปโหลด คู่มือ A → wwwroot/documents/{guid}.pdf  + แถวใน DB
วันที่ 5  deploy เวอร์ชันใหม่ (DeleteExistingFiles=true) → ลบ folder ปลายทางทั้งหมด → copy ของใหม่
          → {guid}.pdf หาย (ไม่อยู่ใน TFS) · แถวใน DB ยังอยู่
ผลลัพธ์   หน้า UserManual: คู่มือ A ขนาด "-" ดาวน์โหลดไม่ได้ · ต้องอัปโหลดใหม่ทุกรายการหลัง deploy ทุกครั้ง
```
> เหลือรอดเฉพาะ V2.2 ที่อยู่ใน publish (R3) · อีก 2 ไฟล์ seed เป็น `Content Remove` → **หายตั้งแต่ deploy แรกด้วย**

**Q17 — ✅ ตัดสินใจแล้ว: เก็บไฟล์ที่ `OAGBudget/wwwroot/documents` เดิม**
- path ในโค้ด: `Path.Combine(IWebHostEnvironment.WebRootPath, "documents")` (ตัวเดียวกับที่ `DocumentController.cs:18` ใช้อยู่ตอนนี้)
- `FILEPATH` ใน DB = ชื่อไฟล์ relative จาก folder นี้
- ไม่ย้าย root ออกนอกโปรเจกต์ (ตัดทางเลือก A ที่เสนอใน v3)
- ข้อ 3 A1/A3, 4.2, 5, 6.5, R1, R3, R5 **ใช้ตามเดิม ไม่ต้องแก้**

**Q19 — ✅ (C) publish ไม่ลบไฟล์ปลายทาง**
- เปลี่ยน `DeleteExistingFiles` → `false` ใน publish profile ที่ใช้ deploy จริง (ต้องระบุว่าตัวไหน — Q21)
- ผลข้างเคียงที่ยอมรับ: ไฟล์ที่ลบออกจากโปรเจกต์ (เช่น .js/.css เก่า) จะค้างใน publish folder / server ต้องลบเองเป็นครั้งคราว
- ⚠️ ครอบคลุมเฉพาะขั้น publish — ถ้ามีขั้น copy จาก publish folder ขึ้นแต่ละเครื่องที่ลบ folder ปลายทาง ต้องแก้ขั้นนั้นด้วย (Q21)

**Q18 — ✅ MVC รันมากกว่า 1 เครื่อง** → เกิด blocker 10.2

### 10.2 🔴 BLOCKER — MVC มากกว่า 1 เครื่อง แต่ไฟล์เก็บใน `wwwroot/documents` ของแต่ละเครื่อง

**สิ่งที่จะเกิดถ้าทำตามเดิม**
```
Role 41 อัปโหลด คู่มือ A  → load balancer ส่งไป  WEB1 → เขียน WEB1\wwwroot\documents\{guid}.pdf + แถวใน DB
ผู้ใช้ X เปิดคู่มือ A      → load balancer ส่งไป  WEB2 → WEB2 ไม่มีไฟล์ → ขนาด "-" เปิดไม่ได้
Role 41 แทนที่ไฟล์ คู่มือ A → ไป WEB2            → WEB2 เขียนไฟล์ใหม่ + ลบไฟล์เก่า (ไม่มีอยู่แล้ว) · WEB1 ยังมีไฟล์เก่าค้าง
ผลลัพธ์                    → หน้าเดียวกัน refresh แล้วบางครั้งเปิดได้ บางครั้งไม่ได้ ขึ้นกับเครื่องที่ถูกส่งไป
```

**Q20 — เลือกวิธีให้ทุกเครื่องเห็นไฟล์ชุดเดียวกัน** (ทุกทางเลือกยังใช้ `FILEPATH` แบบ relative ตาม Q1)

| ทางเลือก | วิธี | ข้อดี | ข้อเสีย |
|---|---|---|---|
| **(E) `wwwroot\documents` ของทุกเครื่องเป็น symbolic link ไป shared folder** ⭐ แนะนำ | infra สร้าง shared folder เช่น `\\fileserver\OAGBudget\documents` → ในแต่ละเครื่องแทน folder `wwwroot\documents` ด้วย `mklink /D` ชี้ไป share · copy ไฟล์ seed 3 ไฟล์ขึ้น share | **โค้ดใช้ path เดิม** (`WebRootPath\documents`) ตรงกับ Q3/Q17 · ทุกเครื่องเห็นไฟล์เดียวกันทันที · deploy ไม่แตะไฟล์ใน share | ต้องพึ่ง infra: สร้าง share, ให้สิทธิ์ Modify กับ App Pool identity ของทุกเครื่อง (ถ้าเป็น `ApplicationPoolIdentity` ต้องให้สิทธิ์ computer account `DOMAIN\WEB1$` หรือเปลี่ยนเป็น domain service account) · ต้องเปิด symlink ไป remote (`fsutil behavior set SymlinkEvaluation R2R:1 L2R:1`) · ถ้า share ล่ม หน้าคู่มือเปิดไม่ได้ · **ต้องเช็คว่าขั้น deploy ไม่ลบ/ทับ link** (Q21) |
| (F) เก็บไฟล์ใน DB (BLOB) | เพิ่มคอลัมน์ `FILEDATA BLOB` ใน `OAGWBG_USERMANUAL` หรือใช้ `OAGWBG_ATTACHFILE` ที่มีอยู่ · `FILEPATH` เหลือไว้เป็นชื่อไฟล์เดิม | ไม่พึ่ง infra · ทุกเครื่องเห็นเหมือนกัน · deploy ไม่กระทบ · backup ไปกับ DB | **ขัดกับ Q1–Q3** (ไม่ได้เก็บไฟล์ใน folder แล้ว) · DB โตขึ้น (V2.2 = 20 MB ต่อไฟล์) · ส่งไฟล์ผ่าน API ต้องขยาย request limit ฝั่ง API ด้วย · แก้ design ข้อ 5–6 เยอะ |
| (G) sync folder ระหว่างเครื่อง | infra ตั้ง DFS Replication / robocopy ตามรอบเวลา ระหว่าง `wwwroot\documents` ของทุกเครื่อง | โค้ดไม่เปลี่ยน · ไม่มี single point of failure | มีช่วงเวลาที่ไฟล์ยังไม่ sync (เปิดไม่ได้ชั่วคราว) · ลบไฟล์แล้วอาจถูก sync กลับมา · ตั้งค่าและดูแลยากที่สุด |
| ~~sticky session~~ | ~~ให้ load balancer ส่ง user เดิมไปเครื่องเดิม~~ | — | ❌ ไม่แก้ปัญหา: คนอัปโหลดกับคนเปิดเป็นคนละคน ไปคนละเครื่องได้ |

**Q21 — ❓ ขั้นตอน deploy จริง**
1. publish profile ตัวไหนที่ใช้ deploy จริง? (มี 6 ตัวใน `OAGBudget/Properties/PublishProfiles/` — `FolderProfile1.pubxml` → `D:\Publish\OAGBudget\web` เป็นตัวเดียวที่ชี้ path ของ OAGBudget, อีกหลายตัวยังชี้ `DTNBooking`)
2. จาก publish folder ขึ้นแต่ละเครื่องทำอย่างไร (copy มือ / robocopy `/MIR` / script)? — ถ้าใช้ `/MIR` หรือลบ folder ก่อน copy → ไฟล์ใน `wwwroot\documents` หาย (หรือ link ถูกลบ ถ้าเลือก E) แม้ตั้ง Q19 (C) แล้ว
3. หมายเหตุ (นอก scope): มี publish profile ซ้ำอยู่ใน `OAGBudget/wwwroot/Properties/PublishProfiles/` → น่าจะถูก publish ขึ้น server ไปด้วย (static file ไม่ serve `.pubxml` โดย default จึงไม่ถูกเปิดผ่าน URL) · ควรลบทิ้งภายหลังเพื่อไม่ให้สับสนว่าตัวไหนใช้จริง

---

## 11. ลำดับการทำงาน (หลังได้คำตอบ Q20–Q21)

0. ปรับเอกสารตาม Q20 · แก้ publish profile ที่ใช้จริง `DeleteExistingFiles=false` (Q19, Q21) · ถ้าเลือก (E) → ขอ infra สร้าง share + สิทธิ์ + symlink ทุกเครื่อง + copy ไฟล์ seed
1. ต่อ VPN → เช็ค `NLS_CHARACTERSET` → ปรับ DDL
2. รัน DDL + seed ใน PREPROD → verify `SELECT * FROM OAGWBG_USERMANUAL`
3. DAL entity + DbContext → `dotnet build`
4. API service + controller → `dotnet build`
5. MVC: ViewModels + MasterService (frontend) → `dotnet build`
6. MVC: `DocumentController.UserManual()` + `DownloadManual` (อ่านอย่างเดียว) → `dotnet build` → ทดสอบหน้า UserManual แสดง 3 รายการเดิม
7. MVC: Save/Delete + modal + ปุ่ม Role 41 → `dotnet build`
8. เตรียม server: สิทธิ์ Write (R1), `maxAllowedContentLength` (R4), ตรวจวิธี deploy (R2)
9. ทดสอบตาม checklist หัวข้อ 12
10. `tf get` → ไม่มี conflict → `tf checkin`

---

## 12. Test Checklist

**แสดงผล / ดาวน์โหลด**
- [ ] ผู้ใช้ทั่วไป: เห็น 3 รายการเดิม เรียงตาม SEQUENCE · มีคอลัมน์ คำอธิบาย / วันที่อัพเดทล่าสุด · ไม่เห็นปุ่มจัดการ
- [ ] Role 41: เห็นปุ่ม เพิ่ม / แก้ไข / ลบ
- [ ] เปิด PDF ได้ใน tab ใหม่ ชื่อไฟล์ที่ browser แสดง = ชื่อคู่มือ
- [ ] ACTIVE='0' → ผู้ใช้ทั่วไปไม่เห็น + เรียก `DownloadManual?id=` ตรงได้ 404
- [ ] ไฟล์หายจาก folder → หน้าไม่ error, ขนาดแสดง `-`, ปุ่มดาวน์โหลดปิด
- [ ] แก้ FILEPATH ใน DB เป็น `..\..\appsettings.json` → `DownloadManual` ถูกปฏิเสธ

**สิทธิ์**
- [ ] ผู้ใช้ไม่ใช่ Role 41 ยิง POST `SaveUserManual` / `DeleteUserManual` ตรง → ถูกปฏิเสธ ไม่มีไฟล์/แถวเปลี่ยน

**Create**
- [ ] ไม่แนบไฟล์ / ชื่อว่าง / ชื่อซ้ำ → block
- [ ] แนบ `.docx` → block · เปลี่ยนนามสกุล `.exe` เป็น `.pdf` → block (เช็ค `%PDF-`)
- [ ] แนบไฟล์ > 50 MB → block พร้อมข้อความ (ไม่ใช่หน้า error ของ IIS)
- [ ] สำเร็จ → มีไฟล์ `{guid}.pdf` ใน folder · `CREATEBY` = user ที่ login จริง

**Update**
- [ ] แก้แค่ชื่อ (ไม่เลือกไฟล์) → ไฟล์เดิมคงอยู่ · `UPDATEBY/UPDATEON` ถูก set · `CREATEBY/CREATEON` ไม่เปลี่ยน
- [ ] เลือกไฟล์ใหม่ → ID เดิม · FILEPATH เปลี่ยน · ไฟล์ใหม่อยู่ใน folder · **ไฟล์เก่าถูกลบ**
- [ ] จำลอง API ล้มเหลวตอนแทนที่ไฟล์ → ไฟล์เก่ายังอยู่ · DB ไม่เปลี่ยน · ไฟล์ใหม่ถูกลบ ไม่ค้าง
- [ ] แทนที่ไฟล์ seed เดิม (ชื่อไทย) → ทำงานได้ ไฟล์เก่าถูกลบ

**Delete**
- [ ] ลบ → แถวหาย · ไฟล์ถูกลบ
- [ ] ลบรายการที่ไฟล์ไม่มีอยู่แล้ว → สำเร็จ ไม่ error

**Deploy (R2)**
- [ ] อัปโหลดคู่มือ 1 รายการ → deploy ด้วย publish profile + ขั้น copy จริง → คู่มือยังเปิดได้ ขนาดไม่เป็น `-`

**หลายเครื่อง (R6)**
- [ ] อัปโหลดผ่าน WEB1 (เข้า URL ตรงของเครื่อง) → เปิดผ่าน WEB2 ได้
- [ ] แทนที่ไฟล์ผ่าน WEB2 → WEB1 เห็นไฟล์ใหม่ · ไฟล์เก่าไม่ค้างในเครื่องใด
- [ ] ลบผ่าน WEB1 → ไฟล์ไม่เหลือในเครื่องใด

**Build**
- [x] `dotnet build` 0 Error (2026-09-15 · ไม่มี warning จากไฟล์ใหม่)

---

## 13. สรุปงานที่ทำ (v6 — 2026-09-15, ยังไม่ checkin)

### ไฟล์ที่สร้างใหม่
| ไฟล์ | บทบาท |
|---|---|
| `OAGBudget.DAL/Models/OagwbgUsermanual.cs` | Entity |
| `OAGBudget.Models/ViewModel/SaveUserManualViewModel.cs` | Form model + `IFormFile File` |
| `OAGBudget/Views/Document/_partialView/_modalUserManual.cshtml` | Modal เพิ่ม/แก้ไข ส่งด้วย `FormData` (unobtrusive ajax ส่งไฟล์ไม่ได้) |
| `_brain_OAGBUDGET/20260915_UserManual_Path_CRUD/create_table_usermanual.sql` | DDL + seed + rollback — **ผู้ใช้รันเอง** |

### ไฟล์ที่แก้ไข
| ไฟล์ | การเปลี่ยนแปลง |
|---|---|
| `OAGBudget.DAL/OAGDBContext.cs` | `DbSet<OagwbgUsermanual>` + mapping (ใส่ใน partial ไม่แตะ `OAGDBContextBase.cs`) |
| `OAGBudget.Models/ViewModel/DocumentFileViewModel.cs` | เพิ่ม `Id`, `Description`, `FileExists`, `Active`, `Sequence`, `LastUpdatedOn` |
| `OAGBudget.API/Services/Repository/MasterService.cs` | `#region 8.1.UserManual` — Get list / by id / Save (ไม่ override `Createby`) / Delete |
| `OAGBudget.API/Controllers/MasterController.cs` | `#region 8.1.UserManual` — 4 endpoints |
| `OAGBudget/Services/Repository/MasterService.cs` | `#region UserManual` — 4 methods เรียก API |
| `OAGBudget/Controllers/DocumentController.cs` | `UserManual` (อ่านจาก DB), `DownloadManual`, `UserManualDetail`, `SaveUserManual`, `DeleteUserManual` + เช็ค Role 41 ฝั่ง server + กัน path traversal |
| `OAGBudget/Views/Document/UserManual.cshtml` | คอลัมน์ คำอธิบาย / วันที่อัพเดทล่าสุด · ปุ่ม เพิ่ม/แก้ไข/ลบ + คอลัมน์สถานะ เฉพาะ Role 41 |
| `OAGBudget/Properties/PublishProfiles/FolderProfile1.pubxml` | `DeleteExistingFiles` → `false` (Q19) · ⚠️ profile นี้ยังเป็น `TargetFramework=net6.0` ขณะที่โปรเจกต์เป็น net9.0 → อาจไม่ใช่ profile ที่ใช้ deploy จริง ต้องยืนยัน (Q21) |

### ยังไม่ได้ทำ / ต้องทำต่อ
- [ ] ผู้ใช้รัน `create_table_usermanual.sql` ใน PREPROD
- [ ] ทดสอบใน browser ตาม checklist หัวข้อ 12 (ยังไม่ได้ทดสอบ runtime — ต้องมีตารางก่อน)
- [ ] Server: สิทธิ์ Write `wwwroot\documents` (R1), `maxAllowedContentLength` ≥ 55 MB (R4)
- [ ] Q20 (หลายเครื่อง) / Q21 (ขั้นตอน deploy จริง) ยังไม่ได้คำตอบ
- [ ] `tf get` → `tf checkin`
