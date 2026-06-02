# Roadmap 266 – ตรวจสอบงบประมาณ: เพิ่ม Sort และแก้ลำดับ

## สรุปปัญหา

ตาราง Level 3 (รายละเอียดธุรกรรม) ในหน้าตรวจสอบงบประมาณมีปัญหา 2 จุด:

1. **คอลัมน์ คำอธิบาย ยังไม่สามารถ sort ได้** – ถูก set เป็น `orderable: false` อยู่ในปัจจุบัน
2. **เลข #ลำดับ สลับเมื่อ sort** – ตัวเลขถูก render ฝั่ง server (Razor: `var no = 1; no++`) ทำให้ค่าถูกฝังใน HTML แล้วไม่เปลี่ยนเมื่อ DataTables เรียงแถวใหม่

---

## ไฟล์ที่เกี่ยวข้อง

| ไฟล์ | บทบาท |
|------|--------|
| `OAGBudget\Views\Budget\_partialView\_tableBudgetCheckPeriodCategory.cshtml` | ตาราง Level 3 – จุดที่ต้องแก้ทั้งหมด |

ไม่ต้องแก้ Backend, Model, หรือ Controller ใดๆ เป็นการแก้ **Frontend เท่านั้น**

---

## สาเหตุรากเหง้า

### ปัญหาที่ 1 – คำอธิบาย ไม่สามารถ sort ได้

ใน `columnDefs` ปัจจุบัน (บรรทัด 88):
```js
{ targets: 4, orderable: false, className: 'text-start' },  // คำอธิบาย
```
ค่า `orderable: false` ทำให้ DataTables ปิด sort ของคอลัมน์นั้น ทั้งที่ข้อมูล `DESCRIPTION` ในโมเดล `OagwbgOagglBgDetailV` พร้อมอยู่แล้ว

### ปัญหาที่ 2 – เลข #ลำดับ สลับหลัง sort

```razor
@{
    var no = 1;
}
@foreach (var item in Model)
{
    <tr>
        <td class="text-center">@no</td>   ← ถูกฝังเป็น 1, 2, 3... ใน HTML
        ...
    </tr>
    no++;
}
```
เมื่อ DataTables เรียงแถวใหม่ฝั่ง Client เลขที่ฝังไว้ก็ตามแถวไปด้วย ทำให้ลำดับไม่ตรงกับ visual order

### ปัญหาเสริม – คอลัมน์ วันที่ผ่านรายการ ซ้ำ 2 คอลัมน์

ตารางมีหัวคอลัมน์ "วันที่ผ่านรายการ" 2 ครั้ง (index 5 และ 8) แสดงข้อมูล `GL_DATE` เดียวกัน เป็น code ที่เหลือค้างมาจากการ comment/uncomment ควรลบออก

---

## แผนการแก้ไข

### ขั้นตอนที่ 1 – เปิด sort ให้คอลัมน์ คำอธิบาย

**ไฟล์:** `_tableBudgetCheckPeriodCategory.cshtml` บรรทัด 88

เปลี่ยน:
```js
{ targets: 4, orderable: false, className: 'text-start' },
```
เป็น:
```js
{ targets: 4, orderable: true, className: 'text-start' },
```

### ขั้นตอนที่ 2 – แก้คอลัมน์ #ลำดับ

**ทางเลือก A (แนะนำ) – ใช้ DataTables row counter แทนค่าจาก Razor**

เปลี่ยน Razor template จาก:
```razor
@{
    var no = 1;
}
@foreach (var item in Model)
{
    <td class="text-center">@no</td>
    ...
    no++;
}
```
เป็น (ลบ `no` ออกจาก Razor ให้คอลัมน์เป็นค่าว่างหรือ placeholder):
```razor
@foreach (var item in Model)
{
    <td class="text-center"></td>
    ...
}
```
แล้วเพิ่ม `render` ใน `columnDefs` (index 0):
```js
{
    targets: 0,
    orderable: false,
    className: 'text-center',
    render: function (data, type, row, meta) {
        return meta.row + 1;
    }
},
```
DataTables จะคำนวณเลขลำดับตาม visual row position ทุกครั้งที่ sort

**ทางเลือก B – ลบคอลัมน์ #ลำดับ ออก**

ลบ `<th>#</th>` และ `<td>@no</td>` ออกจาก HTML และลบ `targets: 0` ออกจาก `columnDefs`
พร้อมปรับ index ของ `columnDefs` และ `order` ทุกตัวลดลง 1

> ทางเลือก A ดีกว่าเพราะยังคงแสดงลำดับให้ผู้ใช้เห็น และไม่ต้องปรับ index ทั้งหมด

### ขั้นตอนที่ 3 – ลบคอลัมน์ วันที่ผ่านรายการ ที่ซ้ำออก

ลบ `<th>` และ `<td>` ของคอลัมน์ index 8 ออก (บรรทัด 16 และ 53)  
ลบ `targets: [6, 7, 8]` และปรับเป็น `targets: [6, 7]` ใน `columnDefs`

---

## ลำดับ Priority

| # | งาน | ความเร่งด่วน |
|---|-----|--------------|
| 1 | เปิด orderable ให้คอลัมน์ คำอธิบาย | สูง (ตรงกับ requirement) |
| 2 | แก้ #ลำดับ ด้วย DataTables render | สูง (ตรงกับ requirement) |
| 3 | ลบคอลัมน์ วันที่ ซ้ำออก | กลาง (cleanup) |

---

## คำถามที่ยังต้องการคำตอบ (ถ้ามี)

1. ต้องการให้คอลัมน์ #ลำดับ ยังคงอยู่ (ทางเลือก A) หรือลบออกเลย (ทางเลือก B)?
2. ต้องการ sort default เริ่มต้นเปลี่ยนไหม (ปัจจุบัน: GL_DATE desc → ENCUMBRANCE_TYPE asc → TRANSACTION_NUMBER asc)?
