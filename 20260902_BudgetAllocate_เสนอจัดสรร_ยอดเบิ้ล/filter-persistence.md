# หน้าพิจารณาคำขอ — จำเงื่อนไขค้นหาเมื่อกด "กลับหน้าหลัก"

**วันที่:** 2026-09-02
**สถานะ:** ✅ แก้แล้ว build ผ่าน — ยังไม่ได้ checkin

## อาการ

หน้า **พิจารณาคำของบประมาณรายจ่ายประจำปี** (`BudgetRequestConsiderList`)
ค้นหา → เข้าดูรายละเอียด → กด **กลับหน้าหลัก** → เงื่อนไขค้นหาหายหมด ต้องเลือกใหม่ทุกครั้ง

## สาเหตุ

ปุ่ม "กลับหน้าหลัก" เป็น `<a href>` ธรรมดา ไม่ได้ส่ง state กลับมา
— [`BudgetRequestDetail.cshtml:284`](../../OAGBudget/Views/Budget/BudgetRequestDetail.cshtml#L284)
— [`BudgetRequestProjectList.cshtml:235`](../../OAGBudget/Views/Budget/BudgetRequestProjectList.cshtml#L235)

และ DataTable อ่านเงื่อนไขจาก DOM (`#divFilter [name=...]`) สด ๆ ทุกครั้งที่ยิง ajax
— [`_tableBudgetRequestConsider.cshtml`](../../OAGBudget/Views/Budget/_partialView/_tableBudgetRequestConsider.cshtml)
พอโหลดหน้าใหม่ ฟอร์มก็ว่างเปล่า เงื่อนไขเลยหาย

## วิธีแก้

เก็บเงื่อนไขไว้ใน `sessionStorage` (key `BudgetRequestConsiderList.filter`) แล้วคืนค่าตอนโหลดหน้า
ไม่ต้องแก้ปุ่ม "กลับหน้าหลัก" หรือ controller เลย

**ไฟล์ที่แก้:** `OAGBudget/Views/Budget/_partialView/_tableBudgetRequestConsider.cshtml`

| ฟังก์ชัน | หน้าที่ |
|---|---|
| `saveFilter()` | เรียกทุกครั้งที่ DataTable ยิง ajax → เก็บค่าปัจจุบันทั้ง 5 ช่อง |
| `restoreFilter()` | เรียก**ก่อน** `DataTable()` init → set ค่ากลับเข้าฟอร์ม + กางแผงค้นหาให้เห็น |
| `clearFilter()` | ผูกกับปุ่ม "ล้างเงื่อนไข" ใน `BudgetRequestConsiderList.cshtml` |

ช่องที่จำ: `BudgetYear`, `DepartmentId`, `Region`, `StatusId`, `BudgetFormTypeId`

### จุดที่ต้องระวัง — ปีงบประมาณ

dropdown **ปีงบประมาณ** ไม่ได้ render จาก server แต่ถูกเติมจาก `response.budgetYearList`
หลัง ajax รอบแรกสำเร็จ (บล็อก `isFirstLoad`) ตอน `restoreFilter()` ทำงานจึงยังไม่มี `<option>` ให้เลือก

แก้โดย:
1. `restoreFilter()` พักค่าปีไว้ใน `pendingBudgetYear` แทนการ `.val()` ทันที
2. ในบล็อก `isFirstLoad` หลังเติม option แล้ว ค่อย set ค่าจาก `pendingBudgetYear`
3. ถ้า set สำเร็จ → ตั้ง `reloadForBudgetYear = true` แล้ว `table.ajax.reload()` อีกรอบ
   (เพราะ ajax รอบแรกยิงไปโดยยังไม่มีปี) — `isFirstLoad` เป็น `false` แล้วจึงไม่วนซ้ำ
4. `saveFilter()` ไม่เขียนทับค่าปีตราบใดที่ `pendingBudgetYear` ยังค้างอยู่

ผลข้างเคียง: ถ้ามีเงื่อนไข "ปี" ค้างไว้ จะยิง ajax 2 ครั้งตอนเข้าหน้า (ครั้งเดียวถ้าไม่มี)

## พฤติกรรมหลังแก้

| การกระทำ | ผล |
|---|---|
| ค้นหา → เข้ารายละเอียด → กลับหน้าหลัก | ได้เงื่อนไขเดิม + แผงค้นหากางให้เห็นว่ากรองด้วยอะไร |
| กด "ล้างเงื่อนไข" | ล้างทั้งฟอร์มและที่จำไว้ |
| ปิด browser tab | ลืมทั้งหมด (`sessionStorage` ไม่ใช่ `localStorage`) |
| ปีที่จำไว้ไม่มีในลิสต์แล้ว | ตกกลับเป็น "ทั้งหมด" ไม่ค้าง ไม่ error |
| browser ปิด sessionStorage | `try/catch` ครอบไว้ ใช้งานได้ปกติแค่ไม่จำ |

## ยังไม่ได้ทำ

หน้า **พิจารณาขอรับจัดสรรเพิ่มเติม** (`BudgetRequestConsiderMoreList` +
`_tableBudgetRequestConsiderMore.cshtml`) เป็นโครงเดียวกันและน่าจะมีอาการเดียวกัน
— ยังไม่ได้แก้ เพราะอยู่นอกขอบเขตที่สั่ง
