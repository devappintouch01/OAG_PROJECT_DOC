```SQL
SELECT * FROM OAGWBG.OAGWBG_SYSTEMMENU
WHERE 1=1
AND ID IN (1, 27, 202, 163, 150, 44, 214, 212, 137, 135, 213, 162, 153, 69)
ORDER BY SEQUENCE
```

```json
"ConnectionStrings": {
    "DBContext": "DATA SOURCE=(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(HOST=172.16.11.19)(PORT=1541)))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=ebs_PRE)));User Id=OAGWBG;Password=Oag#2025;"
}
```

| ID  | MENUNAME  | SEQUENCE | ICONCSS  |
|-----|-----------|----------|----------|
| 1   | หน้าหลัก  | 1        |          |
| 27  | คำของบประมาณประจำปี | 2        |          |
| 202 | พิจารณาคำของบประมาณ | 3        |          |
| 163 | คำของบประมาณภาพรวม | 4        |          |
| 150 | รายละเอียดงบประมาณประจำปี (พ.ร.บ) | 5        | caret-right |
| 44  | แผนการใช้จ่ายงบประมาณ | 6        |          |
| 214 | คำของบประมาณเพิ่มเติม / งบกลาง | 7        |          |
| 212 | บันทึกรับเงินจากสำนักการคลัง | 8        |          |
| 137 | โอนเงินจัดสรรงบประมาณ | 9        |          |
| 135 | โอนเงินกลับ | 10       |          |
| 213 | กันเงินเหลื่อมปี | 12       |          |
| 162 | บันทึกรับเงินนอกงบประมาณ | 13       |          |
| 153 | รายงาน    | 14       |          |
| 69  | ตั้งค่า   | 15       | ki-outline ki-setting-2 fs-3 |