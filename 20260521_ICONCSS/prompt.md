```SQL
SELECT * FROM OAGWBG.OAGWBG_SYSTEMMENU
WHERE 1=1
AND ID IN (1, 27, 202, 163, 150, 44, 214, 212, 137, 135, 133,213, 162, 153, 69)
ORDER BY SEQUENCE
```

```json
"ConnectionStrings": {
    "DBContext": "DATA SOURCE=(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(HOST=172.16.11.19)(PORT=1541)))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=ebs_PRE)));User Id=OAGWBG;Password=Oag#2025;"
}
```

| ID  | MENUNAME  | SEQUENCE | ICONCSS  |
|-----|-----------|----------|----------|
| 1   | หน้าหลัก  | 1        | fas fa-home fs-3 |
| 27  | คำของบประมาณประจำปี | 2        | fas fa-file-invoice-dollar fs-3 |
| 202 | พิจารณาคำของบประมาณ | 3        | fas fa-file-signature fs-3 |
| 163 | คำของบประมาณภาพรวม | 4        | fas fa-chart-pie fs-3 |
| 150 | รายละเอียดงบประมาณประจำปี (พ.ร.บ) | 5        | fas fa-book fs-3 |
| 44  | แผนการใช้จ่ายงบประมาณ | 6        | fas fa-calendar-alt fs-3 |
| 214 | คำของบประมาณเพิ่มเติม / งบกลาง | 7        | fas fa-plus-circle fs-3 |
| 212 | บันทึกรับเงินจากสำนักการคลัง | 8        | fas fa-university fs-3 |
| 137 | โอนเงินจัดสรรงบประมาณ | 9        | fas fa-exchange-alt fs-3 |
| 135 | โอนเงินกลับ | 10       | fas fa-undo fs-3 |
| 133 | การติดตามการใช้จ่ายและบริหารงบประมาณ | 11       | fas fa-chart-line fs-3 |
| 213 | กันเงินเหลื่อมปี | 12       | fas fa-clock fs-3 |
| 162 | บันทึกรับเงินนอกงบประมาณ | 13       | fas fa-wallet fs-3 |
| 153 | รายงาน    | 14       | fas fa-chart-bar fs-3 |
| 69  | ตั้งค่า   | 15       | fas fa-cog fs-3 |

### ทางเลือกเพิ่มเติม: Metronic KeenIcons (ตรงตามตัวอย่างของเมนู 'ตั้งค่า')

หากคุณต้องการใช้งาน KeenIcons (เนื่องจากตัวอย่าง `ki-outline ki-setting-2 fs-3` เป็นไอคอนจากไลบรารี KeenIcons ของ Metronic) ด้านล่างนี้คือรูปแบบโครงสร้างที่เทียบเคียงกันครับ:

| ID  | MENUNAME  | SEQUENCE | ICONCSS  |
|-----|-----------|----------|----------|
| 1   | หน้าหลัก  | 1        | ki-outline ki-home fs-3 |
| 27  | คำของบประมาณประจำปี | 2        | ki-outline ki-file-sheet fs-3 |
| 202 | พิจารณาคำของบประมาณ | 3        | ki-outline ki-badge fs-3 |
| 163 | คำของบประมาณภาพรวม | 4        | ki-outline ki-chart-pie-simple fs-3 |
| 150 | รายละเอียดงบประมาณประจำปี (พ.ร.บ) | 5        | ki-outline ki-book-open fs-3 |
| 44  | แผนการใช้จ่ายงบประมาณ | 6        | ki-outline ki-calendar-8 fs-3 |
| 214 | คำของบประมาณเพิ่มเติม / งบกลาง | 7        | ki-outline ki-add-item fs-3 |
| 212 | บันทึกรับเงินจากสำนักการคลัง | 8        | ki-outline ki-bank fs-3 |
| 137 | โอนเงินจัดสรรงบประมาณ | 9        | ki-outline ki-arrows-loop fs-3 |
| 135 | โอนเงินกลับ | 10       | ki-outline ki-arrow-right-left fs-3 |
| 133 | การติดตามการใช้จ่ายและบริหารงบประมาณ | 11       | ki-outline ki-chart-line fs-3 |
| 213 | กันเงินเหลื่อมปี | 12       | ki-outline ki-time fs-3 |
| 162 | บันทึกรับเงินนอกงบประมาณ | 13       | ki-outline ki-wallet fs-3 |
| 153 | รายงาน    | 14       | ki-outline ki-chart-line-down fs-3 |
| 69  | ตั้งค่า   | 15       | ki-outline ki-setting-2 fs-3 |

---

## 🛠️ SQL Bulk Update Scripts

Below are the Oracle SQL scripts to bulk update the `OAGWBG_SYSTEMMENU` table for each version.

### 1. Font Awesome 5 Bulk Update Script

```sql
-- Update ICONCSS to Font Awesome 5 version
UPDATE OAGWBG.OAGWBG_SYSTEMMENU
SET ICONCSS = CASE ID
    WHEN 1   THEN 'fas fa-home fs-3'
    WHEN 27  THEN 'fas fa-file-invoice-dollar fs-3'
    WHEN 202 THEN 'fas fa-file-signature fs-3'
    WHEN 163 THEN 'fas fa-chart-pie fs-3'
    WHEN 150 THEN 'fas fa-book fs-3'
    WHEN 44  THEN 'fas fa-calendar-alt fs-3'
    WHEN 214 THEN 'fas fa-plus-circle fs-3'
    WHEN 212 THEN 'fas fa-university fs-3'
    WHEN 137 THEN 'fas fa-exchange-alt fs-3'
    WHEN 135 THEN 'fas fa-undo fs-3'
    WHEN 133 THEN 'fas fa-chart-line fs-3'
    WHEN 213 THEN 'fas fa-clock fs-3'
    WHEN 162 THEN 'fas fa-wallet fs-3'
    WHEN 153 THEN 'fas fa-chart-bar fs-3'
    WHEN 69  THEN 'fas fa-cog fs-3'
    ELSE ICONCSS
END
WHERE ID IN (1, 27, 202, 163, 150, 44, 214, 212, 137, 135, 133, 213, 162, 153, 69);

COMMIT;
```

### 2. Metronic KeenIcons Bulk Update Script

```sql
-- Update ICONCSS to Metronic KeenIcons version
UPDATE OAGWBG.OAGWBG_SYSTEMMENU
SET ICONCSS = CASE ID
    WHEN 1   THEN 'ki-outline ki-home fs-3'
    WHEN 27  THEN 'ki-outline ki-file-sheet fs-3'
    WHEN 202 THEN 'ki-outline ki-badge fs-3'
    WHEN 163 THEN 'ki-outline ki-chart-pie-simple fs-3'
    WHEN 150 THEN 'ki-outline ki-book-open fs-3'
    WHEN 44  THEN 'ki-outline ki-calendar-8 fs-3'
    WHEN 214 THEN 'ki-outline ki-add-item fs-3'
    WHEN 212 THEN 'ki-outline ki-bank fs-3'
    WHEN 137 THEN 'ki-outline ki-arrows-loop fs-3'
    WHEN 135 THEN 'ki-outline ki-arrow-right-left fs-3'
    WHEN 133 THEN 'ki-outline ki-chart-line fs-3'
    WHEN 213 THEN 'ki-outline ki-time fs-3'
    WHEN 162 THEN 'ki-outline ki-wallet fs-3'
    WHEN 153 THEN 'ki-outline ki-chart-line-down fs-3'
    WHEN 69  THEN 'ki-outline ki-setting-2 fs-3'
    ELSE ICONCSS
END
WHERE ID IN (1, 27, 202, 163, 150, 44, 214, 212, 137, 135, 133, 213, 162, 153, 69);

COMMIT;
```