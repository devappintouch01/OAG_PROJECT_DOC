# แผนการแก้ไข: เปลี่ยน Dropdown ให้เป็น Server-side Dropdown (Select2 AJAX)

ปัญหาก่อนหน้านี้เกิดจากการโหลดข้อมูล `Asset` ทั้งหมด 39,000+ รายการจาก View มหึมาผ่านคำสั่ง `PageLength: -1` มาไว้ที่เบราว์เซอร์ เพื่อทำ Cascading Dropdown ด้วย JavaScript

## แนวทางการแก้ไข (Proposed Changes)

เพื่อให้ระบบทำงานได้รวดเร็ว ไม่กิน Memory ของเซิร์ฟเวอร์ และไม่ Timeout เราจะปรับโครงสร้างการโหลดข้อมูลใน Modal ใหม่ ดังนี้:

### 1. การปรับ Backend (C# - BudgetController)
- **โหลดเฉพาะข้อมูล Master:** ในเมธอด `OpenAssetReplace` แทนที่จะโหลดข้อมูลทุกอย่าง เราจะดึงแค่ **ข้อมูลพื้นฐาน (Master Data)** ของ 4 Dropdown แรก (หมวด, ประเภท, ชนิด, คุณลักษณะ) ซึ่งมีจำนวนรายการไม่เยอะ (หลักสิบถึงหลักร้อย) ส่งไปพร้อมกับ Modal
- ไม่มีการดึงข้อมูลตาราง `Asset` (ที่มี 39,000 รายการ) ส่งไปเด็ดขาด

#### [MODIFY] [BudgetController.cs](file:///D:/TFS/OAG%20Budget/OAGBudget/Controllers/BudgetController.cs)
- เปิดการทำงาน (Uncomment) ของ `DropdownAssetType()`, `DropdownAssetTypeSub()`, `DropdownAssetClass()`, `DropdownAssetDetail()` ที่ถูก Comment เอาไว้
- ปล่อยให้ `DropdownAsset()` ถูก Comment ไว้ตามเดิม

### 2. การปรับ Frontend (JavaScript - Modal View)
- **ลบ API โหลดข้อมูลมหาศาล:** ลบฟังก์ชัน `loadDropdownDataFromAPI()` และ AJAX Call ที่ส่งค่า `PageLength: -1` ออกไป
- **ทำ Client-side Cascading สำหรับ 4 Dropdown แรก:**
  - นำข้อมูล Master 4 ตัวแรกที่ได้จาก Backend แปลงเป็นตัวแปร JavaScript (JSON) ตั้งแต่จังหวะเปิด Modal
  - เมื่อผู้ใช้เลือก **หมวด** -> ให้ JS Filter เฉพาะ **ประเภท** ที่สัมพันธ์กัน ฯลฯ
- **เปลี่ยน Dropdown รายการครุภัณฑ์ (AssetId) เป็น Select2 AJAX:**
  - เปิดใช้งาน `$('#AssetId').select2({ ajax: ... })`
  - ให้ยิง API ไปที่ `/Budget/SearchAssetReplace` **เฉพาะตอนที่ผู้ใช้พิมพ์ค้นหา (พิมพ์ปุ๊บ ค้นปั๊บ)**
  - แนบค่าที่เลือกจาก 4 Dropdown แรก (หมวด, ประเภท, ฯลฯ) ส่งไปเป็น Parameter กรองข้อมูลร่วมกับคำที่พิมพ์
  - ให้ API จำกัดผลลัพธ์แค่ 20 รายการต่อหน้า (`PageLength: 20`) เพื่อให้โหลดเร็วปานสายฟ้า
- **Auto-fill ข้อมูลหลังเลือก:**
  - เมื่อผู้ใช้คลิกเลือกครุภัณฑ์ใน Select2 จะให้เก็บข้อมูลแบบเต็มรูปแบบ (Full Data) เอาไว้ใน Option
  - อ่านค่าจาก Option มาเติมลงฟิลด์ `Details` (รายละเอียด/คุณลักษณะ) และ `Price` (ราคาต่อหน่วย) ให้โดยอัตโนมัติ

#### [MODIFY] [_modalProjectAssetReplace.cshtml](file:///D:/TFS/OAG%20Budget/OAGBudget/Views/Budget/_partialView/_modalProjectAssetReplace.cshtml)
- รับค่าจาก ViewBag / Model เพื่อตั้งค่าตัวแปร Master Data
- ปรับปรุงฟังก์ชัน `updateDropdowns()` สำหรับ 4 Dropdown แรก
- เขียน Setup โค้ดสำหรับ Select2 AJAX ของตัวแปร `AssetId`

## ⚠️ สิ่งที่ต้องให้ User Review ก่อนดำเนินการ (User Review Required)

> [!IMPORTANT]
> ด้วยวิธีนี้ **Dropdown ที่ 5 (รายการครุภัณฑ์) จะว่างเปล่าในตอนแรก** จนกว่าผู้ใช้จะกดพิมพ์ค้นหาชื่อ หรือกดปุ่มลูกศรเพื่อโหลดข้อมูล 20 รายการแรก 
> 
> ซึ่งนี่เป็นพฤติกรรมมาตรฐานของ Select2 AJAX และเป็นวิธีที่ถูกต้องที่สุดสำหรับการจัดการข้อมูลปริมาณ 39,000+ รายการ

> [!NOTE]
> ระบบค้นหาหลักจะค้นหาได้จาก "ชื่อครุภัณฑ์" ตามที่ API เดิม (`SearchAssetReplace`) ถูกออกแบบมา หากเห็นชอบในแนวทางนี้ สามารถ **Approve** เพื่อเริ่มลงมือเขียนโค้ดได้เลยครับ
