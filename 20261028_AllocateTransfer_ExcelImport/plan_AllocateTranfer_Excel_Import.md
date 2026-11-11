# นำเข้า Excel หน้าโอนเงินจัดสรร (BudgetAllocateTransferDetail) — plan (2026-10-28)

> สถานะ: **เริ่มทำ** — เฟส A, B, B2, C, D เขียนโค้ดครบแล้ว 2026-10-29 (หัวข้อ 10) build ผ่าน ยังไม่ทดสอบบันทึกจริงบนหน้าเว็บ หัวข้อ 9 เหลือข้อ 6
> ไฟล์ตัวอย่าง (โฟลเดอร์เดียวกัน):
> - `AllocateTransfer_Import_template01.xlsx` — **template เปล่า** + sheet master ครบ ไม่มีแถวข้อมูล (หัวใบชี้ 2586) ⚠️ ไฟล์ในโฟลเดอร์ยังมีคอลัมน์คงเหลือ (O) เพราะเปิดอยู่ใน Excel ตอนสร้างใหม่ ตัวใหม่ 19 คอลัมน์รอคัดลอกทับ
> - `sample_AllocateTransfer_Import_Template_20items.xlsx` — 20 บรรทัดงบ / 37 แถว แบบกรอกซ้ำทุกแถว **layout เก่า** มีคอลัมน์คงเหลือ (O) ตัวอักษรคอลัมน์ตั้งแต่ O จึงเลื่อนไป 1 ช่องจากตารางด้านล่าง
> - `sample_AllocateTransfer_Import_Template.xlsx` — ชุดแรก 9 แถว **layout เก่า** มีทั้งคอลัมน์รหัส EXP (M) และคงเหลือ

## Requirement

1. สร้างหัวใบโอน (header) ก่อน แล้วจึง import
2. Export template ของใบนั้นให้ผู้ใช้ไปกรอก
3. Import Excel แล้วแสดงบนแท็บ "โอนเงินจัดสรร"
   - 3.1 ข้อมูลที่ได้มีทั้งระดับแท็บโอนจัดสรรและระดับศูนย์ต้นทุน
   - 3.2 ปรับการแสดงผลเมื่อข้อมูลที่ import มีระดับหมายเหตุ (note)
4. กดบันทึก

## ข้อตกลงกับผู้ใช้

| # | เรื่อง | ข้อสรุป |
|---|---|---|
| 1 | บัญชีรับโอน (REF, แหล่งเงิน 200/300/400) | **รวม**ในรอบนี้ |
| 2 | ใบที่มีรายการอยู่แล้ว | **เพิ่มต่อท้าย** รายการเดิมไม่ถูกแก้ไขหรือลบ |
| 3 | การแสดงระดับศูนย์ต้นทุน/หมายเหตุ | **ทาง ก: modal อ่านอย่างเดียว** ต่อแถว |
| 4 | บรรทัดงบที่ไม่มีใน fn | **ยอมให้ import** โดยทำแบบเดียวกับปุ่ม "เพิ่มรายการใหม่" |
| – | ความละเอียดของ Excel | 1 แถว = 1 บรรทัดหมายเหตุ ระบบรวมกลุ่มเป็น 3 ระดับเอง |
| – | รูปแบบการกรอก (ตกลง 2026-10-28) | **ไม่ต้องกรอกซ้ำ**: ระดับบรรทัดงบกรอกแถวแรกแถวเดียว ศูนย์ต้นทุนกรอกแถวแรกของศูนย์นั้น แถวถัดไปเว้นว่างได้ ระบบเติมค่าลง (fill-down) เอง **และยังรับไฟล์แบบกรอกซ้ำทุกแถว** ดูหัวข้อ 1 "รูปแบบการกรอก" |
| – | หน่วยเบิกจ่าย | ไม่ต้องกรอก ระบบหาจากศูนย์ต้นทุน |
| – | มีแถวผิด | ปฏิเสธทั้งไฟล์ และแสดงรายงานเลขแถว/คอลัมน์/เหตุผล |

## ข้อเท็จจริงที่ตรวจแล้ว (code + PREPROD)

**ฝั่งการบันทึก**
- ปุ่มบันทึกเดิม (`SaveBudgetAllocateTransferDetail`, API `BudgetService.cs:13178`) เขียนแค่ 3 ตาราง คือ หัวใบโอน, `_CATEGORY` และ `_COSTCENTER` **ไม่เขียน** `BUDGETRECEIVE` และ `NOTE`
- ตาราง CATEGORY ถูกบันทึกใน `SaveChangesAsync` ครั้งเดียว (`:13424`) ทำให้แถวลูกอ้าง id ของแม่ที่เพิ่งสร้างในรอบเดียวกันไม่ได้
- ยอดจัดสรรถูกบันทึกที่ `SaveBudgetAllocateTransferCostCenter` (public, `:14022`)
  - สร้าง `BUDGETRECEIVE` type `A` 1 แถวต่อ (หน่วยเบิกจ่าย, ศูนย์ต้นทุน)
  - สร้าง `COSTCENTER_NOTE` 1 แถวต่อบรรทัดหมายเหตุ
  - ตั้ง `TOTAL*` ทุกคอลัมน์ของ receive = ผลรวมหมายเหตุ และ `CATEGORY.TOTALALLOCATEAMOUNT` = ผลรวม receive (`:14250-14260`)
  - จับคู่ note กับ receive ใหม่ด้วย (Departmentid, Costcenterid) (`:14161`) ดังนั้นภายใน 1 CATEGORY คู่นี้ต้องไม่ซ้ำ

**ฝั่งการจองงบ**
- `ConfirmBudgetAllocateTransfer` (`:24929`) หักงบด้วย `CATEGORY.TOTALALLOCATEAMOUNT`
- แถวที่เป็นแม่ (มีลูกอ้างถึง) ถูก**ข้าม** (`:25062`) ยอดของลูกไปหักจากถังของแม่ โดยหาถังจาก `DEPARTMENTID`, `COSTCENTERID`, `TRANSFERNO` ของแม่ (`:25081-25089`)
  - แปลว่าแถวแม่ต้องไม่มียอดศูนย์ต้นทุนของตัวเอง ถ้ามีจะไม่ถูกหักงบ

**ฝั่งหน้าจอ**
- แท็บศูนย์ต้นทุน: view `OAGWBG_V_BUDGETALLOCATETRANSFER_COSTCENTER` (อ่าน DDL จาก PREPROD แล้ว)
  - สร้างแถวจาก `BUDGETRECEIVE` type `A` แล้ว LEFT JOIN `_COSTCENTER` ด้วย (ใบ, ศูนย์ต้นทุน, แผน, ประเภทค่าใช้จ่าย, แหล่งเงิน)
  - หน่วยเบิกจ่ายมาจาก `OAGWBG_V_EXT_OAGGL_COST_CENTER_V`
  - ผลคือหลัง import บันทึกแล้ว แท็บ 2 จะมีแถวขึ้นเอง (BAC.ID ว่าง) ผู้ใช้เลือกบัญชีผู้โอน/ผู้รับโอน แล้วกดบันทึกเหมือนเดิม
- บัญชีรับโอนเปิดจากแถวแม่ที่บันทึกแล้วเท่านั้น (`cshtml:1709`) และล็อกแหล่งเงินให้ตรงกับแม่ (`openTransferAccountModal(true)`, `cshtml:3935`)
- แหล่ง 400 มีฟิลด์ "เลขที่" (`TRANSFERNO`)
- กฎตรวจรายการซ้ำบนหน้าจอ:
  - เลือกจากโมดอล: คีย์ 6 ตัว + เลขที่ (`cshtml:2456`)
  - เพิ่มรายการใหม่: `sameSixInPeriodData` ใช้ (แหล่งเงิน, แผน, ผลผลิต, กิจกรรม, รายการ, รหัสงบ) (`cshtml:2575`)
- กฎเพดานของลูก: ผลรวมลูก ≤ `TOTALRECEIVEAMOUNT` ของแม่ (`getChildrenOverAllocatedParents`, `cshtml:1511`)
- เพิ่มรายการใหม่ที่ไม่มีใน fn (`addSingleItemByFilters`, `cshtml:2505`):
  - เรียก `CheckTotalBudget` ด้วย `DepartmentidGiver = CostcenteridGiver = '2900600000'` และ `IsBudgetTransfer = true` (`cshtml:3063`)
  - ตั้ง `totalreceiveamount = 0`, `availablebudget = totalBudget`
  - ถ้าไม่มี template ให้ `templateId = '__NO_TEMPLATE__'`
  - ไม่ได้ส่ง department/costcenter ต้นทางกลับมา
- ⚠️ **`CheckTotalBudget` ไม่ใช่ read-only:** ถ้าหา account ไม่เจอ จะเรียก `TryAutoCombineAccountAsync` ซึ่งสร้าง GL code combination จริงใน EBS (`API BudgetService.cs:20670-20716`) หน้าจอเดิมก็ทำแบบนี้ตั้งแต่ตอนเลือก dropdown ครบ

**ข้อมูลอ้างอิง**
- แหล่งบรรทัดงบ: `GetBudgetTransferCategory` (`:12647`) เรียก `OAGWBG_FN_GETBUDGET_ALLOCATE_TRANSFER_CATEGORY(ปี, หน่วยงานที่โอน, แหล่งเงิน)` และคำนวณ `AvailableBudget` (GetBulkTotalBudget) ใช้ตัวเดียวกับโมดอล
  - fn นี้ตัวที่ปรับแล้ว (เดิม 33 วิ ตัวใหม่ 1.2 วิ) PREPROD เรียก (2569, '1', NULL) ได้ 1.7 วิ เมื่อ 2026-10-28 และผู้ใช้ยืนยัน 2026-10-29 ว่า DBA deploy บน PROD แล้ว
- รายการศูนย์ต้นทุนตามภาค: `GetCostCenterList(regionId)` (`MasterService.cs:2812`) ภาค `99` หรือ `ALL` = ทุกภาค, STATUS = 'Y'
  - PREPROD มี 395 แถว ID ไม่ซ้ำ มี 4 แถวที่ไม่มีหน่วยเบิกจ่าย (แถวสรุป) ซึ่งต้องไม่ยอมให้ import
- แพทเทิร์น Excel ที่มีอยู่:
  - API สร้างไฟล์ด้วย ClosedXML 0.105 (ฟอนต์ TH Sarabun New 14) แล้วคืน `byte[]` (`ExportConfirmBudgetAllocatePlanPreview`, API `:7124`)
  - MVC คืนไฟล์ด้วย `File(bytes, xlsx, name)` (`OAGBudget/Controllers/BudgetController.cs:3050`)
  - การอัปโหลด: MVC อ่าน `Request.Form.Files[0]` เป็น `byte[]` (`AttachFileController.cs:79-93`)
- มี transaction ใช้อยู่แล้ว: `_context.Database.BeginTransactionAsync()` (`:20775`)

## 1. Template (ดูไฟล์ตัวอย่าง)

| Sheet | หน้าที่ |
|---|---|
| อ่านก่อน | วิธีกรอก ชนิดแถว และกติกา |
| **นำเข้า** | ข้อมูลที่ import แถว 1 = กลุ่มระดับ, แถว 2 = หัวคอลัมน์, ข้อมูลเริ่มแถว 3 |
| ข้อมูลใบโอน | `TemplateVersion`, `BudgetAllocateTransferId`, ROUNDNO, ปี, หน่วยงานที่โอน, ภาค, วันที่ export (protect) ระบบใช้ตรวจว่าไฟล์เป็นของใบนี้ |
| แผนงาน | master รหัส/ชื่อแผนงาน ใช้เป็น dropdown คอลัมน์ F และ VLOOKUP ชื่อ (G) |
| ผลผลิต | master รหัส/ชื่อผลผลิต + รหัสแผนงาน ใช้เป็น dropdown คอลัมน์ H และ VLOOKUP ชื่อ (I) |
| กิจกรรม | master รหัส/ชื่อกิจกรรม + รหัสแผนงาน ใช้เป็น dropdown คอลัมน์ J และ VLOOKUP ชื่อ (K) |
| รายการ | master Category ID/ชื่อรายการ + แผนงาน + ประเภทงบ ใช้เป็น dropdown คอลัมน์ L และ VLOOKUP ชื่อ (M) |
| รหัสงบประมาณ | master รหัสงบประมาณ 20 หลัก/ชื่อ ใช้เป็น dropdown คอลัมน์ N (ไม่มีคอลัมน์ชื่อใน sheet นำเข้า เพราะ 40 จาก 141 รหัสไม่มีชื่อ และจะทำให้ตัวอักษรคอลัมน์เลื่อนอีกรอบ) |
| ศูนย์ต้นทุน | lookup ศูนย์ต้นทุน/หน่วยเบิกจ่ายของภาคในหัวใบ ใช้เป็น dropdown และสูตรชื่อ |
| แหล่งเงิน | dropdown 100/200/300/400 |

ทุก sheet master มีรหัสอยู่คอลัมน์ A และชื่ออยู่คอลัมน์ B สูตรใน sheet นำเข้าจึงเป็นรูปแบบเดียวกันหมด เช่น
`=IF($F3="","",IFERROR(VLOOKUP($F3,'แผนงาน'!$A:$B,2,FALSE),"ไม่พบรหัสแผนงาน"))`

แหล่งข้อมูล master (ใช้เงื่อนไขเดียวกับ dropdown ใน modal "เพิ่มรายการใหม่" เพื่อให้รหัสที่เลือกได้ตรงกับหน้าจอ)

| Sheet | View | เงื่อนไข | อ้างอิงโค้ด | PREPROD 2026-10-28 |
|---|---|---|---|---|
| แผนงาน | `OAGWBG_V_EXT_OAGGL_BUDGET_PLAN_V` | `STATUS='Y' AND SUMMARYFLAG='N'` | `MasterService.GetBudgetPlanCode` | 6 แถว |
| ผลผลิต | `OAGWBG_V_EXT_OAGGL_BUDGET_PRODUCT_V` | `SUMMARYFLAG='N'` | `MasterService.GetProductByPlanId` | 15 รหัส |
| กิจกรรม | `OAGWBG_V_EXT_OAGGL_BUDGET_ACTIVITY_V` | `SUMMARYFLAG='N' AND ENABLED_FLAG='Y'` | `MasterService.GetActivityByPlanId` | 9 รหัส |
| รายการ | `OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V` | `STATUS='Y' AND (INACTIVE_DATE > SYSDATE OR INACTIVE_DATE IS NULL)` | เงื่อนไข InactiveDate เดียวกับ `BudgetService.GetCategory` | 776 แถว |
| รหัสงบประมาณ | `OAGWBG_V_EXT_OAGGL_BUDGET_CODE_V` | `SUMMARYFLAG='N' AND ID<>'T'` | `MasterService.GetBudgetCode` (ตัดแถว `T` = Total ออก) | 141 แถว |

- รหัสผลผลิต/กิจกรรมไม่ซ้ำข้ามแผนงาน ยกเว้น `00000` (ไม่ระบุ) ที่มี 1 แถวต่อแผนงานและชื่อเหมือนกัน ตอน export ให้ยุบเหลือ 1 แถว (คอลัมน์แผนงาน = "ทุกแผนงาน") แล้ว VLOOKUP ด้วยรหัสอย่างเดียวได้ ไม่ต้องใช้ key ผสม
- view กิจกรรมคอลัมน์ `PRODUCT_ID` เก็บรหัสแผนงาน (เช่น `10000`) ไม่ใช่รหัสผลผลิต จึงไม่ได้ใส่ลง sheet
- sheet รายการใช้ `STATUS='Y'` + กรอง InactiveDate (776 แถว) ไม่ใช้เงื่อนไขอื่นของ `GetCategory` (plan/type/expense type → 673 แถว) เพราะต้องครอบบรรทัดงบที่มาจาก fn
- ⚠️ ผลของการกรอง InactiveDate: fn (2569, '1') คืน Category ID 301 รหัส มี **2 รหัสที่ไม่อยู่ใน sheet** เพราะยกเลิกแล้ว แต่ fn ยังคืนมา
  - `2229` ค่าใช้จ่ายในการสัมมนาและฝึกอบรมในประเทศ (inactive 16/07/2026) แหล่ง 100 คงเหลือ 17,720,500
  - `10124` ค่าพาหนะชันสูตรพลิกศพ/สอบปากคำเด็กฯ/อื่นๆ (inactive 06/07/2026) แหล่ง 100 คงเหลือ -190,000
  - ถ้า export บรรทัดงบเหล่านี้ลง template ชื่อรายการจะขึ้น "ไม่พบรหัสรายการ" และ dropdown ไม่รับค่าเมื่อแก้ไข ต้องตัดสินใจว่าตอน export จะตัดบรรทัดที่รายการยกเลิกแล้วออก หรือยอมให้โอนได้ (ดูหัวข้อ 9)
- รหัสงบประมาณที่ fn คืนมา 98 รหัส มีใน sheet ครบ (ตรวจด้วยการแยก segment 9 แบบไม่ข้ามช่องว่าง เพราะบางบรรทัดมีแผนงานว่าง `...69.200..00000...` ถ้าใช้ `REGEXP_SUBSTR(x,'[^.]+',1,9)` จะได้ segment ที่เลื่อนไป)
- dropdown ของคอลัมน์รหัสเป็นแบบ Stop ถ้าพิมพ์รหัสที่ไม่มีใน master Excel จะไม่รับค่า แต่ผู้ใช้ยังวางค่า (paste) ทับได้ ฝั่ง server จึงยังต้องตรวจรหัสกับ master เอง (กฎ R03, R03b)

### คอลัมน์ sheet "นำเข้า"

| Col | คอลัมน์ | กรอกโดย | ระดับ | บันทึกลง |
|---|---|---|---|---|
หัวคอลัมน์ใน template: `*` = ต้องกรอกทุกแถว, `* (เงื่อนไข)` = ต้องกรอกตามเงื่อนไขในวงเล็บ, ไม่มี `*` = ไม่บังคับ

| Col | หัวคอลัมน์ใน template | กรอกโดย | ระดับ | บันทึกลง |
|---|---|---|---|---|
| A | ลำดับ | export | – | – |
| B | รหัสกลุ่มแม่ | ผู้ใช้ | REF | ใช้จับคู่เท่านั้น (เช่น `P1`) |
| C | อ้างอิงกลุ่มแม่ | ผู้ใช้ | REF | `CATEGORY.REF` = id ใหม่ของแม่ |
| D | แหล่งเงิน * | export / ผู้ใช้ | 1 | `CATEGORY.BUDGETSOURCEID` |
| E | เลขที่ * (แหล่ง 400) | export / ผู้ใช้ | 1 | `CATEGORY.TRANSFERNO` |
| F | รหัสแผนงาน * | export / ผู้ใช้ | 1 | `CATEGORY.BUDGETPLANID` |
| H | รหัสผลผลิต * | export / ผู้ใช้ | 1 | `CATEGORY.PRODUCTID` |
| J | รหัสกิจกรรม * | export / ผู้ใช้ | 1 | `CATEGORY.ACTIVITYID` |
| L | รหัสรายการ (Category ID) * | export / ผู้ใช้ | 1 | `CATEGORY.CATEGORYID` |
| N | รหัสงบประมาณ * | export / ผู้ใช้ | 1 | `CATEGORY.BUDGETCODEID` (segment 9 ของ AccountCode) |
| G I K M | ชื่อแผน / ผลผลิต / กิจกรรม / รายการ | สูตร VLOOKUP จาก sheet master | – | ไม่อ่าน |
| O | รหัสศูนย์ต้นทุน * (ยกเว้นแถวแม่) | ผู้ใช้ | 2 | `BUDGETRECEIVE.COSTCENTERID` |
| P Q | ชื่อศูนย์ต้นทุน / หน่วยเบิกจ่าย | สูตร VLOOKUP | – | ไม่อ่าน (`DEPARTMENTID` หาจาก view) |
| R | จำนวนเงินจัดสรร * (ยกเว้นแถวแม่) | ผู้ใช้ | 3 | `COSTCENTER_NOTE.TOTALALLOCATEAMOUNT` |
| S | หมายเหตุ | ผู้ใช้ | 3 | `COSTCENTER_NOTE.NOTE` (SEQUENCE = ลำดับแถว) |

- ไม่มีคอลัมน์รหัส EXP (ตัดออกเมื่อ 2026-10-28) เพราะตอน import ไม่ได้ใช้ และตาราง `_CATEGORY` ไม่มีคอลัมน์เก็บค่านี้
- คอลัมน์รหัสทั้งหมดตั้งรูปแบบเป็นข้อความ (`@`) เพื่อกันเลข 0 นำหน้าหาย เช่น `00000`
- ตอน import ถ้าเจอ cell ที่เป็นตัวเลข ต้องแปลงเป็นข้อความโดยไม่มีทศนิยม แล้วตรวจความยาว: ผลผลิต/กิจกรรม 5 หลัก, รหัสงบ 20 หลัก

### ชนิดแถว

| ชนิด | B | C | O/R | หมายเหตุ |
|---|---|---|---|---|
| อิสระ (แหล่ง 100 หรือแหล่งอื่นที่ไม่มีลูก) | ว่าง | ว่าง | ต้องมี | |
| แม่ (200/300/400) | `P1` | ว่าง | **ห้ามมี** | 1 แถวพอ ถ้าซ้ำ คีย์บรรทัดงบต้องตรงกัน |
| ลูก / บัญชีรับโอน | ว่าง | `P1` | ต้องมี | แหล่งเงินต้องตรงกับแม่ ถ้าแหล่ง 400 เลขที่ต้องตรงด้วย |
| ต่อเนื่อง: ศูนย์ต้นทุนใหม่ | ว่าง | ว่าง | O + R | ระดับ 1 (D–N) ว่าง ใช้บรรทัดงบของแถวบน |
| ต่อเนื่อง: หมายเหตุเพิ่ม | ว่าง | ว่าง | R เท่านั้น | ระดับ 1 และ O ว่าง ใช้บรรทัดงบและศูนย์ต้นทุนของแถวบน |

### รูปแบบการกรอก (ไม่ต้องกรอกซ้ำ)

ตัวอย่าง (คอลัมน์ที่ไม่เกี่ยวตัดออก)

| แถว | A | B | C | D | E | F … N | O | R | S | ความหมาย |
|---|---|---|---|---|---|---|---|---|---|---|
| 3 | 1 | | | 100 | | 10000 … 2125 … | 2900600001 | 2,000 | ข้าวผัด | บรรทัดงบใหม่ + ศูนย์ต้นทุนใหม่ + หมายเหตุ 1 |
| 4 | | | | | | | | 2,000 | กะเพรา | หมายเหตุ 2 ของ 2900600001 |
| 5 | 2 | | | 100 | | 10000 … 2127 … | 2900600001 | 6,000 | ไก่ย่าง | บรรทัดงบใหม่ |
| 6 | | | | | | | 2900600002 | 4,000 | เป็ดพะโล้ | ศูนย์ต้นทุนที่ 2 ของบรรทัดงบแถว 5 |
| 7 | 3 | t1 | | 400 | 68030002 | 20000 … 2291 … | | | | แถวแม่ |
| 8 | | | t1 | 400 | 68030002 | 20000 … 2228 … | 2900600001 | 2,000 | | ลูก (บรรทัดงบใหม่) |
| 9 | | | | | | | 2900600030 | 2,000 | | ศูนย์ต้นทุนที่ 2 ของลูกแถว 8 |

กติกาการอ่าน (ทำเป็นขั้น "เติมค่าลง" ก่อนจัดกลุ่ม หลังขั้นนี้ข้อมูลจะเหมือนแบบกรอกซ้ำ แล้วใช้ขั้นตอนเดิมต่อได้ทั้งหมด)
1. แถวที่มีค่าในคอลัมน์ระดับ 1 อย่างน้อย 1 ช่อง (D, E, F, H, J, L, N) = **เริ่มบรรทัดงบใหม่** ต้องกรอกระดับ 1 ครบชุด (กฎ L02)
2. แถวที่ระดับ 1 ว่างทั้งหมด = **แถวต่อเนื่อง** ใช้ D–N ของบรรทัดงบล่าสุดด้านบน
3. B/C เป็นค่าของบรรทัดงบ กรอกได้เฉพาะแถวเริ่มบรรทัดงบ (กฎ L03)
4. แถวที่มี O = เริ่มศูนย์ต้นทุนใหม่ในบรรทัดงบปัจจุบัน แถวที่ O ว่างแต่มี R = หมายเหตุเพิ่มของศูนย์ต้นทุนล่าสุดด้านบน **ไม่ข้ามบรรทัดงบ** (แถวเริ่มบรรทัดงบใหม่ต้องมี O เอง กฎ L05)
5. แบบกรอกซ้ำทุกแถว (ไฟล์ตัวอย่างเดิม) ยังใช้ได้: แถวที่คีย์บรรทัดงบเดียวกันและ**อยู่ติดกัน**จะรวมเป็นบรรทัดงบเดียว ศูนย์ต้นทุนเดียวกันที่อยู่ติดกันรวมเป็น receive เดียว
6. คีย์บรรทัดงบเดียวกันที่โผล่ **2 ช่วงไม่ติดกัน** = error (กฎ L06) กันการพิมพ์ซ้ำโดยไม่ตั้งใจ ซึ่งแผนเดิมจะรวมให้เงียบๆ ศูนย์ต้นทุนเดียวกันภายในบรรทัดงบเดียวที่โผล่ 2 ช่วงไม่ติดกันก็ error เช่นกัน (กฎ L07) เพราะ `SaveBudgetAllocateTransferCostCenter` จับคู่ note ด้วย (Departmentid, Costcenterid)
7. คอลัมน์ A (ลำดับ) ไม่ถูกอ่าน export ใส่เลขให้เฉพาะแถวบรรทัดงบ

ข้อควรระวังของรูปแบบนี้ (เขียนไว้ใน sheet "อ่านก่อน")
- **ห้าม sort / filter แล้วจัดเรียงใหม่** แถวต่อเนื่องจะไปอยู่ใต้บรรทัดงบอื่นโดยไม่มี error
- แทรกแถวกลางตารางแล้วคอลัมน์สูตรชื่อ (G, I, K, M, P, Q) ของแถวนั้นจะว่าง ไม่กระทบการ import (ถ้าต้องการให้สูตรตามอัตโนมัติ ทำ sheet นำเข้าเป็น Excel Table ภายหลังได้)

### ตัวอย่างการรวมกลุ่ม (ไฟล์ตัวอย่าง 9 แถว)

| แถว Excel | ผลลัพธ์ |
|---|---|
| 3–6 (100, รายการ 2165) | CATEGORY 1 แถว → RECEIVE 3 แถว (2900600001, 2900600013, 2900600027) → NOTE 4 แถว (2900600001 มี 2 งวด) ยอดรวม 2,000 |
| 7 (P1, 200, รายการ 16125) | CATEGORY แม่ 1 แถว ไม่มี receive |
| 8–9 (→P1, รายการ 2192) | CATEGORY ลูก (REF=แม่) → RECEIVE 1 แถว → NOTE 2 แถว ยอดรวม 4,000 |
| 10 (P2, 400/681203, รายการ 27125) | CATEGORY แม่ 1 แถว |
| 11 (→P2, รายการ 5124 ไม่มีใน template) | CATEGORY ลูก แบบเพิ่มรายการใหม่ (CheckTotalBudget) → RECEIVE 1 → NOTE 1 ยอด 7,000 |
| **รวม** | CATEGORY 5, RECEIVE 5, NOTE 7 |

รหัสบรรทัดงบ ศูนย์ต้นทุน และคงเหลือในไฟล์ตัวอย่าง อ้างอิงใบ **2586** (PREPROD ปี 2569 หน่วยงานที่โอน 1 ภาค 99) ส่วนการแบ่งงวด ยอดย่อย และข้อความหมายเหตุเป็นตัวอย่างประกอบ ถ้านำไฟล์นี้เข้าใบ 2586 จริงจะติดรายการซ้ำ ซึ่งใช้เป็น test case ได้

### ไฟล์ตัวอย่าง 20 บรรทัดงบ (`..._20items.xlsx`)

บรรทัดงบและคงเหลือดึงจาก fn ใน PREPROD (ปี 2569 หน่วยงานที่โอน 1) เลือกเฉพาะบรรทัดที่**ยังไม่มีในใบ 2586** ไฟล์นี้จึงใช้ทดสอบ import เข้าใบ 2586 แบบเพิ่มต่อท้ายได้ ศูนย์ต้นทุนเป็นรหัสจริงจาก 9 ภาค (00–08) ส่วนยอดเงินและข้อความหมายเหตุเป็นตัวอย่าง

| กลุ่ม | บรรทัดงบ | หมายเหตุ |
|---|---|---|
| แหล่ง 100 รายการอิสระ | 10 | รายการ 2188, 2209, 2299, 2343, 2390, 2476, 2217, 2201, 2235, 2727 แต่ละรายการมี 1–4 ศูนย์ต้นทุน |
| P1 แหล่ง 200 | แม่ 31124 + ลูก 2 | ลูกเป็นรายการเพิ่มใหม่ (ชุดรหัสของรายการ 2228, 2567) |
| P2 แหล่ง 300 | แม่ 2304 + ลูก 1 | ลูกเป็นรายการเพิ่มใหม่ (2358) |
| P3 แหล่ง 400 เลขที่ 68030002 | แม่ 2291 + ลูก 2 | ลูกเป็นรายการเพิ่มใหม่ (2608, 2631) |
| P4 แหล่ง 400 เลขที่ 68030008 | แม่ 15131 + ลูก 1 | ลูกเป็นรายการเพิ่มใหม่ (2593) |

อ่านกลับด้วย ClosedXML แล้วจัดกลุ่มแบบเดียวกับ import ได้ผลดังนี้
- **CATEGORY 20 แถว** (แม่ 4, ลูก 6, อิสระ 10), **RECEIVE 27 แถว**, **NOTE 33 แถว**
- ศูนย์ต้นทุนที่มีหลายหมายเหตุ 5 จุด เช่น 2299 → 2900600001 มี 3 ไตรมาส
- ทุกกลุ่ม REF: ยอดลูก ≤ คงเหลือแม่, แหล่งเงิน/เลขที่ตรงกับแม่, แม่ไม่มีศูนย์ต้นทุน
- รายการอิสระไม่มีบรรทัดไหนยอดเกินคงเหลือ
- รหัสเก็บเป็นข้อความทุก cell

สีพื้นของแถว: รายการอิสระสลับสีทีละบรรทัดงบ ส่วนแม่กับลูกในกลุ่ม REF เดียวกันใช้สีเดียวกัน

ลูกทุกตัวเป็นรายการเพิ่มใหม่ เพราะ fn ของแหล่ง 200/300/400 มีแต่บรรทัดถังเงิน (แหล่ง 400 มี 1 บรรทัดต่อเลขที่) ตรงกับข้อมูลจริงในใบ 2586 ที่ลูกทั้งสองตัวก็เป็นรายการเพิ่มใหม่ ผลคือไฟล์นี้จะเรียก CheckTotalBudget 6 คีย์ ซึ่งอาจสร้าง CCID ใหม่ใน PREPROD

## 2. Flow ทีละขั้น

### ขั้น 1 — สร้างหัวใบโอน
ใช้ของเดิม ไม่ต้องแก้ แท็บโอนจัดสรรจะแสดงเมื่อบันทึกหัวแล้ว (`isEdit`) ปุ่มใหม่ทั้งสองแสดงเฉพาะสถานะ `80101` วางข้างปุ่ม "เลือกรายการงบประมาณ"
- `นำออก Template`
- `นำเข้า Excel`

### ขั้น 2 — Export template
`GET ExportBudgetAllocateTransferImportTemplate(id)`
1. โหลดหัวใบ ถ้าสถานะไม่ใช่ `80101` ให้ปฏิเสธ
2. ดึงบรรทัดงบจาก `GetBudgetTransferCategory(new SearchBudgetAllocateTransfer { Id = id })` (ตัวเดียวกับโมดอล)
3. ตัดบรรทัดที่ใบนี้มีอยู่แล้วออก (คีย์ 7 ตัว) เพราะเป็นโหมดเพิ่มต่อท้าย
4. เขียน 1 แถวต่อ 1 บรรทัดงบ ใส่รหัสในคอลัมน์ D, E, F, H, J, L, N ส่วน B, C, O, R, S เว้นว่าง คอลัมน์ชื่อ (G, I, K, M, P, Q) เป็นสูตร VLOOKUP ใส่ไว้ล่วงหน้าทุกแถว (ถึงแถว max(1000, จำนวนบรรทัด + 500)) **ไม่มีคอลัมน์คงเหลือ** (ตัดออก 2026-10-28)
5. เติม sheet ศูนย์ต้นทุนด้วย `GetCostCenterList(header.Regionid)` เฉพาะแถวที่มี DEPARTMENTID
5.1 เติม sheet แผนงาน / ผลผลิต / กิจกรรม / รายการ / รหัสงบประมาณ จาก view ในตาราง master หัวข้อ 1 (ยุบรหัส `00000` เหลือ 1 แถว)
6. ชื่อไฟล์: `โอนจัดสรร_นำเข้า_{ROUNDNO}_{yyyyMMdd}.xlsx`

### ขั้น 3 — Import แล้วแสดงในแท็บ
`POST ParseBudgetAllocateTransferImport(id, file)` **ขั้นนี้ไม่เขียน DB** (ยกเว้นผลข้างเคียงของ CheckTotalBudget ดูหัวข้อความเสี่ยง)

ฝั่ง client ก่อนส่งไฟล์:
- ถ้ามีรายการที่ยังไม่บันทึก (`hasUnsavedTableChanges` หรือ `hasUnsavedCostCenterChanges`) ให้แจ้ง "กรุณาบันทึกก่อนนำเข้า" แล้วหยุด เพื่อให้ข้อมูลใน DB ตรงกับ `periodData` และตรวจซ้ำฝั่ง server ได้ครบ
- จำกัดขนาดไฟล์ 5 MB และ 3,000 แถว

ฝั่ง server:
1. ตรวจหัวใบ (มีอยู่จริง และเป็นสถานะ `80101`) แล้วตรวจ sheet `ข้อมูลใบโอน` (`TemplateVersion` และ `BudgetAllocateTransferId` = id)
2. อ่านจากแถว 3 จนถึงแถวสุดท้ายที่มีข้อมูล trim ทุก cell ข้ามแถวที่ B–S ว่างทั้งหมด
2.1 **เติมค่าลง** ตามกติกาในหัวข้อ 1 "รูปแบบการกรอก" ตรวจกฎ L01–L07 ในขั้นนี้ แต่ละแถวเก็บ `lineStartRow` (แถวเริ่มบรรทัดงบ) ไว้ใช้ในข้อความ error
2.2 ข้ามบรรทัดงบ (แถวเริ่ม + แถวต่อเนื่อง) ที่ไม่มี B, C, O, R เลยสักแถว (บรรทัดที่ export มาแต่ไม่ได้ใช้)
3. ตรวจทีละแถวตามกฎในหัวข้อ 4 แล้วเก็บ error ทั้งหมดไว้ (ไม่หยุดที่ error แรก) ข้อความ error ของแถวต่อเนื่องให้บอกแถวเริ่มบรรทัดงบด้วย เช่น "แถว 9 (บรรทัดงบแถว 8)"
4. จัดกลุ่ม: บรรทัดงบ (ช่วงแถวติดกัน) → ศูนย์ต้นทุน → note ตามลำดับแถว
5. หาข้อมูลระดับ 1 ของแต่ละบรรทัดงบ
   - **มีใน fn:** ใช้ค่าจาก fn คือ `TotalBalanceAmount` → totalreceiveamount, `AvailableBudget`, template, summary, code, ชื่อ, `Costcenter/Department` (ต้นทาง)
   - **ไม่มีใน fn:** เรียก `CheckTotalBudget` ด้วยพารามิเตอร์ชุดเดียวกับหน้าจอ (`cshtml:3063`) 1 ครั้งต่อคีย์ ได้ totalreceiveamount = 0, template (ถ้าไม่มีใช้ `__NO_TEMPLATE__`), summary = AccountSegment, availablebudget = TotalBudget และ code ส่วนชื่อดึงจาก view รายการ/ผลผลิต/กิจกรรม
6. ถ้ามี error ให้คืน `{ success:false, errors:[{row, column, message}] }` ไม่คืน items
7. ถ้าผ่าน ให้คืน items ในรูปเดียวกับ `periodData` และแนบ `receives`

**3.1 ข้อมูล 2 ระดับฝั่ง client**
- push items ลง `periodData` ด้วย field เดิมทุกตัว และเพิ่ม field ใหม่:
  ```js
  {
    id: <negative temp id>,  // แม่ -1, -2, ... ส่วนแถวอิสระ/ลูก ก็ใช้ temp id ติดลบเช่นกัน
    ref: <temp id ของแม่ | null>,
    isImported: true,
    importRows: [3,4,5,6],   // เลขแถว Excel สำหรับแจ้ง error ตอนบันทึก
    totalallocateamount: <ผลรวมหมายเหตุ>,
    receives: [{ departmentid, departmentname, costcenterid, costcentername,
                 notes: [{ note, totalallocateamount }] }]
  }
  ```
- ใช้ **temp id ติดลบ** เพราะ render จับลูกด้วย `String(c.ref) === String(item.id)` ถ้าแม่ที่ยังไม่บันทึกทุกตัวมี `id = 0` ลูกจะไปติดกับแม่ทุกตัว
- จุดที่ต้องเปลี่ยนเงื่อนไข "บันทึกแล้ว" จาก `id !== 0` เป็น `id > 0` (ไม่งั้นแถว temp จะได้ลิงก์ไปหน้าศูนย์ต้นทุนและปุ่มบัญชีรับโอน):
  - `cshtml:755` `newPeriodDataIndexKey`
  - `cshtml:1258` `isNewItem` ตอนบันทึก (แถว import ถูกแยกออกจาก list นี้อยู่แล้ว แต่ควรแก้ให้สอดคล้อง)
  - `cshtml:1693` `isSavedItem`
  - `cshtml:1790` `isChildSavedItem`
  - `cshtml:2766`, `cshtml:2861`
  - `cshtml:3232` `hasDeletedSavedItem`
- ตั้ง `hasUnsavedTableChanges = true` (ปุ่มจองงบจะบล็อกจนกว่าจะบันทึก) แล้วเรียก `renderSelectedPeriodsTable()`
- ยอดในคอลัมน์ "งบประมาณจัดสรร" และยอดรวมกลุ่ม render เดิมคำนวณให้อยู่แล้ว (`getParentTotalAllocate`)
- ลบแถว import ด้วยปุ่ม "ลบรายการ" เดิมได้ ติ๊กแม่แล้วลูกจะถูกติ๊กตาม (`cshtml:1469`)

**3.2 การแสดงระดับหมายเหตุ (modal)**
- แถวที่ `isImported && receives.length > 0` จะมี:
  - ปุ่ม `fa-list` "ดูศูนย์ต้นทุน" ในคอลัมน์ปุ่ม (ตำแหน่งเดียวกับปุ่มแก้ไขของแถวที่บันทึกแล้ว)
  - badge `นำเข้า (ยังไม่บันทึก)` ต่อท้ายชื่อรายการ
- แถวแม่ที่ import ไม่มีปุ่ม แสดงแค่ badge
- modal `#importCostCenterModal` (อ่านอย่างเดียว):
  - ส่วนหัว: แผนงาน / ผลผลิต / กิจกรรม / รายการ / รหัสงบ / คงเหลือ
  - ตาราง: ลำดับ | หน่วยเบิกจ่าย | ศูนย์ต้นทุน | งบประมาณจัดสรร | หมายเหตุ
    - ศูนย์ต้นทุนที่มีหลายหมายเหตุ แสดงหลายบรรทัดในเซลล์เดียว แต่ละบรรทัดมี "ข้อความ — ยอด" จัดแบบเดียวกับ `receive-row-notes-multi` ในหน้า `BudgetAllocateTransferCostCenter`
    - footer แสดงยอดรวม
    - ถ้าเป็นแถวลูก แสดงเพดาน = คงเหลือแม่ − ลูกตัวอื่น (สูตรเดียวกับ `RefAllocateLimit`, API `:13997-14011`)
- ไม่มีการแก้ไขใน modal ถ้าต้องแก้ ให้ลบรายการแล้ว import ใหม่ หรือบันทึกก่อนแล้วไปแก้ที่หน้าศูนย์ต้นทุนตามปกติ

### ขั้น 4 — กดบันทึก
**ฝั่ง client** (`#btn-save`): ตรวจแบบเดิมทั้งหมด แล้ว
- ถ้าไม่มีแถว `isImported` ให้เรียก `SaveBudgetAllocateTransferDetail` เหมือนเดิม
- ถ้ามี ให้แยก payload:
  - `detail` = `dataToSave` เดิม แต่ตัดแถว `isImported` ออกจาก `budgetAllocateTransferCategoryList`
  - `importItems` = แถว `isImported` พร้อม `ref` (temp id), `receives` และ `importRows`
  - เรียก `SaveBudgetAllocateTransferImport` แทน
- หลังสำเร็จ ทำเหมือนเดิม: ตั้ง flag auto-update แล้ว reload

**ฝั่ง server** `SaveBudgetAllocateTransferImport(model)` ทั้งหมดอยู่ใน **transaction เดียว**:
1. `BeginTransactionAsync()`
2. `await SaveBudgetAllocateTransferDetail(model.Detail)` ตัวเดิม ไม่แก้ บันทึกหัวใบ รายการเดิม และแท็บ 2
3. **ตรวจ importItems ซ้ำอีกรอบ** เพราะไม่ไว้ใจค่าจาก client:
   - สถานะหัวใบ
   - รายการซ้ำกับ DB
   - ศูนย์ต้นทุน
   - กฎ REF: เพดานคิดจาก TotalBalanceAmount ของแม่ ณ ตอนนี้ จาก fn รอบใหม่
   - ห้ามมียอดที่แม่
   - ค่าระดับ 1 ใช้ที่ server หาเองใหม่ ไม่ใช้ template/summary ที่ client ส่งมา
4. Insert CATEGORY แถวแม่และแถวอิสระ ใช้ mapping เดียวกับ `addFuncAsync` (`:13330-13354`) → `SaveChangesAsync` แล้วเก็บ map tempId → id จริง
5. Insert CATEGORY แถวลูก ตั้ง `REF = map[tempRef]` → `SaveChangesAsync`
6. แต่ละ CATEGORY ใหม่ที่มี receives: เรียก **`SaveBudgetAllocateTransferCostCenter`** ตัวเดิม
   ```csharp
   new BudgetAllocateTransferCostCenterModel {
     BudgetAllocateTransferCategory = { Id = newCatId },
     BudgetReceiveList = receives.Select(x => new BudgetAllocateTransferCostCenterReceiveModel {
        Id = 0, Departmentid, Costcenterid,
        Totalallocateamount = sum, (Totaltransfer/receive/payment/obligation/balance = sum),
        Notes = notes.Select((n,i) => new BudgetAllocateTransferCostCenterNoteModel { Note, Totalallocateamount, Sequence = i+1 })
     })
   }
   ```
   ถ้าคืน `0` (สถานะไม่ใช่ร่าง) ให้ throw → rollback
7. `CommitAsync()` ถ้า throw ที่ไหนให้ rollback ทั้งหมด แล้วคืน error พร้อม `importRows`

ไม่สร้างแถว `_COSTCENTER` ในขั้นนี้ เพราะแท็บ 2 ดึงแถวจาก receive ผ่าน view อยู่แล้ว และบัญชีผู้โอน/ผู้รับโอนยังว่าง ผู้ใช้ไปเลือกแล้วกดบันทึกตาม flow เดิม (การจองงบบังคับให้เลือกบัญชีครบ `cshtml:997`)

## 3. การ map ลงตาราง

| ตาราง | คอลัมน์ | ที่มา |
|---|---|---|
| `_CATEGORY` | BUDGETALLOCATETRANSFERID | id หัวใบ |
| | CATEGORYID, PRODUCTID, ACTIVITYID, BUDGETPLANID, BUDGETSOURCEID, BUDGETCODEID, TRANSFERNO | Excel (D–N) |
| | BUDGETTYPEID, BUDGETYEAR | fn ที่ match (`matched?.BudgetTypeId`, `matched?.BudgetYear ?? header.Budgetyear`) ตาม addFuncAsync |
| | TEMPLATEID, TEMPLATENAME, SUMMARYACCOUNTCODE | fn หรือ CheckTotalBudget |
| | TOTALRECEIVEAMOUNT | fn.TotalBalanceAmount (ถ้าไม่มีใน fn = 0) |
| | TOTALTEMPLATEAMOUNT | displayRemain ของกลุ่ม (template+summary) แบบเดียวกับ client `cshtml:1243-1272` จะถูก auto-update เขียนทับหลัง reload อยู่แล้ว |
| | TOTALALLOCATEAMOUNT | `SaveBudgetAllocateTransferCostCenter` ตั้งให้ (แถวแม่ = 0) |
| | DEPARTMENTID, COSTCENTERID | fn (ต้นทาง ใช้หาถังแม่ตอนจองงบ) ถ้าไม่มีใน fn เว้นว่างเหมือนหน้าจอเดิม |
| | REF | id จริงของแม่ |
| | TRANSFERSTATUS, CREATEBY, CREATEON | `80101`, user, now |
| `BUDGETRECEIVE` (A) | ทุกคอลัมน์ | `SaveBudgetAllocateTransferCostCenter` (`:14058-14078` + `:14250-14256`) DEPARTMENTID มาจาก view ศูนย์ต้นทุน |
| `_COSTCENTER_NOTE` | RECEIVEID, NOTE, TOTALALLOCATEAMOUNT, SEQUENCE | `SaveBudgetAllocateTransferCostCenter` (`:14192-14206`) |

## 4. กฎตรวจสอบ (ตอน parse และตรวจซ้ำตอนบันทึก)

| รหัส | กฎ | ข้อความ |
|---|---|---|
| H01 | sheet `ข้อมูลใบโอน` มีอยู่, `TemplateVersion = AT-IMPORT-1`, `BudgetAllocateTransferId` = ใบนี้ | ไฟล์ไม่ใช่ template ของใบโอนนี้ |
| H02 | หัวใบมีสถานะ `80101` | ใบโอนไม่อยู่ในสถานะร่าง |
| R01 | ต้องมี D, F, H, J, L, N | กรุณาระบุ {คอลัมน์} |
| R02 | D ∈ {100, 200, 300, 400}; ถ้า D = 400 ต้องมี E; ถ้า D ≠ 400 ต้องไม่มี E | แหล่งเงิน/เลขที่ไม่ถูกต้อง |
| R03 | L มีอยู่ใน `V_EXT_OAGINV_CATEGORY_CODES_V` และอยู่ในแผน F (ใช้ชุดเดียวกับ dropdown รายการตามแผน) | ไม่พบรายการ หรือรายการไม่อยู่ในแผนงานนี้ |
| R03b | F, H, J, N มีอยู่ใน view master ตามเงื่อนไขในหัวข้อ 1 (ชุดเดียวกับ sheet แผนงาน / ผลผลิต / กิจกรรม / รหัสงบประมาณ) | ไม่พบรหัสแผนงาน / ผลผลิต / กิจกรรม / รหัสงบประมาณ |
| R04 | ผลผลิต/กิจกรรมเป็น 5 หลัก, รหัสงบเป็น 20 หลัก (ตัวเลขล้วน) | รูปแบบรหัสไม่ถูกต้อง (อาจโดน Excel ตัดเลข 0 นำหน้า) |
| R05 | คีย์ 7 ตัวไม่ซ้ำกับรายการที่ใบนี้มีอยู่แล้วใน DB | รายการนี้มีอยู่แล้วในใบโอน |
| R06 | บรรทัดงบที่ไม่มีใน fn (ยกเว้นแถวแม่ ดู F07): `CheckTotalBudget` ต้องสำเร็จ | ตรวจสอบรหัสงบประมาณไม่ผ่าน |
| R07 | บรรทัดงบที่ไม่มีใน fn (ต้องเรียก CheckTotalBudget) ไม่เกิน **50 คีย์ต่อไฟล์** (ยืนยัน 2026-10-29) นับหลังผ่าน R01–R05 ถ้าเกิน ให้ปฏิเสธทั้งไฟล์**ก่อน**เรียก CheckTotalBudget ตัวแรก | บรรทัดงบใหม่เกิน 50 รายการ กรุณาแบ่งไฟล์ |
| L01 | แถวข้อมูลแรกต้องเป็นแถวเริ่มบรรทัดงบ (มีระดับ 1) | แถวแรกต้องระบุบรรทัดงบ |
| L02 | แถวเริ่มบรรทัดงบต้องกรอกระดับ 1 ครบ (D, F, H, J, L, N และ E เมื่อแหล่ง 400) ไม่เติมค่าลงทีละคอลัมน์ | กรอกบรรทัดงบไม่ครบ |
| L03 | แถวต่อเนื่องห้ามมี B/C | รหัสกลุ่มแม่/อ้างอิงต้องอยู่แถวแรกของบรรทัดงบ |
| L04 | แถวแม่ห้ามมีแถวต่อเนื่อง | แถวแม่ห้ามมีศูนย์ต้นทุน/ยอด |
| L05 | แถวเริ่มบรรทัดงบที่ไม่ใช่แม่ต้องมี O (หมายเหตุไม่ข้ามบรรทัดงบ) | ระบุศูนย์ต้นทุน |
| L06 | คีย์บรรทัดงบเดียวกันต้องอยู่ช่วงแถวเดียวกัน (ติดกัน) | บรรทัดงบซ้ำ แถว x และ y |
| L07 | ภายในบรรทัดงบเดียว ศูนย์ต้นทุนเดียวกันต้องอยู่ช่วงแถวเดียวกัน | ศูนย์ต้นทุนซ้ำในบรรทัดงบเดียวกัน แถว x และ y |
| C01 | O มีอยู่ใน view ศูนย์ต้นทุน (STATUS = 'Y', มี DEPARTMENTID) และอยู่ในภาคของหัวใบ (ภาค 99/ALL ข้ามข้อนี้) | ไม่พบศูนย์ต้นทุน หรือไม่อยู่ในภาค |
| C02 | แถวที่ไม่ใช่แถวแม่ ต้องมีทั้ง O และ R | ระบุศูนย์ต้นทุนและจำนวนเงินให้ครบ |
| A01 | R เป็นตัวเลข > 0 ทศนิยมไม่เกิน 2 ตำแหน่ง | จำนวนเงินไม่ถูกต้อง |
| F01 | B ไม่ว่าง → ต้องไม่มี O/R, D ≠ 100, และ C ต้องว่าง | แถวแม่ห้ามมีศูนย์ต้นทุน/ยอด |
| F02 | รหัสกลุ่มแม่ 1 ตัว = 1 คีย์บรรทัดงบ | รหัสกลุ่มแม่ซ้ำกับบรรทัดงบอื่น |
| F03 | C ไม่ว่าง → ต้องมีแม่ที่ B ตรงกันในไฟล์ แหล่งเงินตรงกับแม่ และถ้าแหล่ง 400 เลขที่ต้องตรงด้วย | ไม่พบกลุ่มแม่ / แหล่งเงินไม่ตรงกับแม่ |
| F04 | ผลรวม R ของลูกทุกตัวในกลุ่ม ≤ คงเหลือของแม่ (fn.TotalBalanceAmount) | ยอดบัญชีรับโอนเกินคงเหลือของแม่ |
| W02 (เดิม F05) | (เตือน ไม่บล็อก ยืนยัน 2026-10-29) แม่ไม่มีลูกในไฟล์ | แถวแม่ไม่มีบัญชีรับโอน |
| F06 | คีย์บรรทัดงบเดียวกันต้องมี B/C ตรงกันทุกแถว | ข้อมูลกลุ่มไม่สอดคล้องกัน |
| F07 | แถวแม่ต้องตรงกับบรรทัดงบใน fn (คีย์ 7 ตัว) **ห้ามเรียก CheckTotalBudget กับแถวแม่** เพราะแม่คือถังเงินที่ต้องมีอยู่จริง ถ้าปล่อยให้เป็นรายการเพิ่มใหม่ จะสร้าง CCID เปล่าๆ แล้วไปตก F04 (คงเหลือ 0) | ไม่พบบรรทัดงบของแถวแม่ (ถังเงิน) |
| W01 | (เตือน ไม่บล็อก ยืนยัน 2026-10-29) แถวอิสระที่ยอดรวม > คงเหลือ | ยอดจัดสรรเกินคงเหลือ หน้าจอเดิมไม่บล็อก แต่จะไปตรวจตอนจองงบ |

คำเตือน (W01, W02) ไม่ทำให้ไฟล์ตก parse คืน `success:true` พร้อม `warnings` ฝั่ง client แสดงรายการเตือนแล้วให้ผู้ใช้กด "ยืนยันนำเข้า" ก่อน merge ลงตาราง ถ้ามีทั้ง error และ warning แสดงทั้งคู่แต่ไม่ให้นำเข้า

แหล่ง 400 (ยืนยัน 2026-10-29, หัวข้อ 9 ข้อ 7 ทาง ข): template ไม่มีบรรทัด 400 ให้ แต่ sheet แหล่งเงิน/dropdown ยังมี 400 ผู้ใช้พิมพ์แถวแม่/ลูก 400 เองได้ แม่ต้องผ่าน F07 โดย**จับคู่กับ fn ทั้งชุด** (ก่อนตัด 400 แบบตอน export) ลูกที่ไม่มีใน fn ไปทาง R06/R07

รายการยกเลิกแล้ว (ยืนยัน 2026-10-29, หัวข้อ 9 ข้อ 5): export ตัดบรรทัดงบที่ Category ไม่อยู่ใน sheet รายการ (inactive) ออก ฝั่ง import กฎ R03 ใช้ชุดเดียวกัน จึงปฏิเสธรายการ inactive ทุกแถว รวมแถวแม่ (ผู้ใช้แจ้งว่า "อาจมีปรับ" ถ้าเปลี่ยนให้แก้ทั้ง 2 จุดพร้อมกัน)

## 5. งานที่ต้องแก้

| โปรเจกต์ / ไฟล์ | งาน |
|---|---|
| `OAGBudget.Models/Data/` (ใหม่ `BudgetAllocateTransferImportModel.cs`) | `ImportParseRequest { Id, FileName, FileData }`, `ImportParseResult { Success, Errors, Warnings, Items }`, `ImportError { Row, Column, Message }`, `ImportItem` (field ตาม periodData + TempId/TempRef/ImportRows/Receives), `ImportReceive`, `ImportNote`, `ImportSaveModel { Detail: BudgetAllocateTransferDetailModel, ImportItems }` |
| `OAGBudget.API/Services/Repository/BudgetService.cs` | `ExportBudgetAllocateTransferImportTemplate(int id): byte[]`<br>`ParseBudgetAllocateTransferImport(ImportParseRequest)`<br>`SaveBudgetAllocateTransferImport(ImportSaveModel)`<br>helper ใช้ร่วม: `ValidateImportItemsAsync` (ใช้ทั้ง parse และ save), `BuildAllocateTransferCategory(...)` แยก mapping ออกจาก `addFuncAsync` ให้ทั้งสองทางใช้ตัวเดียวกัน (refactor ที่ไม่เปลี่ยน behavior), `ResolveCheckTotalBudgetAsync` (เรียก CheckTotalBudget แบบ cache ต่อคีย์) |
| `OAGBudget.API/Controllers/BudgetController.cs` | 3 endpoint: `[HttpGet] ExportBudgetAllocateTransferImportTemplate`, `[HttpPost] ParseBudgetAllocateTransferImport`, `[HttpPost] SaveBudgetAllocateTransferImport` |
| `OAGBudget/Services/Repository/BudgetService.cs` | 3 method เรียก API ตามแพทเทิร์น `ExportConfirmBudgetAllocatePlanPreview` (`:5854`) และ `SaveBudgetAllocateTransferDetail` (`:4692`) |
| `OAGBudget/Controllers/BudgetController.cs` | `ExportBudgetAllocateTransferImportTemplate(id)` → `File(...)`<br>`ImportBudgetAllocateTransferExcel()` อ่าน `Request.Form.Files[0]` → byte[] (แพทเทิร์น `AttachFileController.cs:79`)<br>`SaveBudgetAllocateTransferImport([FromBody])` |
| `OAGBudget/Views/Budget/BudgetAllocateTransferDetail.cshtml` | ปุ่ม export/import + input file<br>dialog แสดงรายงาน error (ตาราง แถว/คอลัมน์/ข้อความ)<br>merge items ลง periodData + temp id<br>แก้ `id !== 0` → `id > 0` 7 จุด<br>ปุ่ม/badge ในแถว + modal `#importCostCenterModal`<br>แยก payload ใน `#btn-save` |

ไม่มี DDL ไม่มีตารางใหม่ ไม่เปลี่ยน API เดิม (`SaveBudgetAllocateTransferDetail` และ `SaveBudgetAllocateTransferCostCenter` ใช้ตามเดิม)

## 6. ความเสี่ยงและข้อควรระวัง

| เรื่อง | ระดับ | รายละเอียด / ทางลด |
|---|---|---|
| CheckTotalBudget สร้าง CCID จริงใน EBS | R0 ต่อรายการ (สร้างแล้วถาวร) | หน้าจอเดิมก็ทำแบบนี้อยู่แล้ว แต่ import ทำได้ทีละหลายรายการ และ**ไฟล์ที่ parse แล้วไม่ได้บันทึกก็สร้างไปแล้ว** ทางลด: เรียกเฉพาะคีย์ที่ผ่านกฎ R01–R05 แล้ว, cache ต่อคีย์, จำกัดจำนวนคีย์ใหม่ต่อไฟล์ (เสนอ 50) และ log จำนวนที่เรียก มี kill switch ใน `TryAutoCombineAccountAsync` อยู่แล้ว |
| fn ช้า | ประสิทธิภาพ (ลดลงแล้ว) | export, parse และ save เรียก fn อย่างละ 1 ครั้ง (save เรียก 2 ครั้ง: ใน `SaveBudgetAllocateTransferCategory` + ตรวจซ้ำ) ผู้ใช้ยืนยัน 2026-10-29 ว่า DBA deploy ตัวที่ปรับแล้วบน PROD แล้ว |
| แก้ `id !== 0` → `id > 0` | R1 | กระทบ logic แถวที่ยังไม่บันทึกทั้งหน้า ต้องทดสอบทั้งการเพิ่มรายการแบบเดิม (เลือกจากโมดอล, เพิ่มรายการใหม่, บัญชีรับโอน) |
| transaction ข้ามหลายเมธอด | R1 | `SaveBudgetAllocateTransferDetail` และ `SaveBudgetAllocateTransferCostCenter` เรียก `SaveChangesAsync` ข้างใน ซึ่งทำงานใน transaction ของ context เดียวกันได้ ต้องไม่มี connection อื่นเขียนตาราง OAGWBG ระหว่างนั้น (`ResolveRoundNoAsync` ใช้ connection ของ context แต่ถูกเรียกเฉพาะตอนสร้างหัวใหม่ ใน flow นี้หัวมีอยู่แล้ว) |
| auto-update หลัง reload | – | เขียนทับ Totalreceiveamount, Totaltemplateamount, SummaryAccountCode, Template*, BudgetCodeId แต่ไม่แตะยอดจัดสรร พฤติกรรมเดียวกับการเพิ่มรายการเดิม |
| NOTE ค้าง | มีอยู่แล้วในระบบ | ลบ CATEGORY ผ่านปุ่มบันทึกเดิมจะลบ receive แต่ไม่ลบ NOTE (`:13420`) ไม่ได้เกิดจากงานนี้ ควรแยกเป็น ticket |
| ข้อมูลผู้ใช้กรอกผิดภาค | – | กฎ C01 + dropdown ใน template |

**ทางย้อนกลับ:** ซ่อนปุ่ม export/import ได้ทันที ข้อมูลที่ import แล้วเป็น record ปกติ ลบได้ด้วยปุ่ม "ลบรายการ" เดิม (CCID ที่สร้างแล้วย้อนไม่ได้)

## 7. Test cases

| # | กรณี | ผลที่คาด |
|---|---|---|
| T01 | ไฟล์ตัวอย่างเข้าใบใหม่ (ปี 2569, หน่วยงาน 1, ภาค 99) ที่ยังว่าง | CATEGORY 5, RECEIVE 5, NOTE 7, ลูก 2 ตัวมี REF ถูกต้อง, แท็บ 2 มีแถว 2900600001/13/27 |
| T02 | ไฟล์ตัวอย่างเข้าใบ 2586 | R05 ทุกบรรทัดงบ ไม่มีการเขียน DB |
| T02b | ไฟล์ 20 บรรทัดงบเข้าใบ 2586 | ผ่าน ได้ CATEGORY +20, RECEIVE +27, NOTE +33 รายการเดิม 5 แถวของใบไม่เปลี่ยน CheckTotalBudget ถูกเรียก 6 คีย์ (ลูกทั้ง 6) |
| T03 | ไฟล์ของใบ A เข้าใบ B | H01 |
| T04 | ผลผลิต `00000` ถูก Excel แปลงเป็นเลข 0 | R04 |
| T05 | แถวแม่มีศูนย์ต้นทุน | F01 |
| T06 | ลูกอ้าง `P9` ที่ไม่มีในไฟล์ / ลูกแหล่งเงินไม่ตรงกับแม่ | F03 |
| T07 | ยอดลูกรวมเกินคงเหลือแม่ | F04 |
| T08 | ศูนย์ต้นทุนภาค 02 เข้าใบภาค 01 | C01 |
| T09 | บรรทัดงบไม่มีใน fn (เช่น รายการ 5124 แหล่ง 400) | ผ่าน totalreceiveamount = 0 มี template/summary จาก CheckTotalBudget |
| T10 | import แล้วลบแถวแม่ก่อนบันทึก | ลูกถูกลบตาม บันทึกแล้วไม่มีแถวค้าง |
| T11 | import + เพิ่มรายการจากโมดอลเองในรอบเดียวกัน แล้วบันทึก | ทั้งสองชุดถูกบันทึก ไม่ซ้ำกัน |
| T12 | บังคับให้ `SaveBudgetAllocateTransferCostCenter` คืน 0 กลางทาง (สถานะเปลี่ยนเป็น 80401 ระหว่างนั้น) | rollback ทั้งหมด รายการเดิมไม่เปลี่ยน |
| T13 | บันทึกแล้วกดจองงบ | หักถังแม่ด้วยยอดลูก ยอดอิสระหักตาม TOTALALLOCATEAMOUNT ตรงกับการกรอกผ่านหน้าศูนย์ต้นทุนแบบเดิม |
| T14 | หน้าจอเดิมไม่มี import: เลือกจากโมดอล / เพิ่มรายการใหม่ / บัญชีรับโอน / ลบ | ทำงานเหมือนเดิม (regression ของ `id > 0`) |
| T15 | ไฟล์แบบไม่กรอกซ้ำ (ตัวอย่างหัวข้อ 1) | ผลเท่ากับไฟล์เดียวกันที่กรอกซ้ำทุกแถว |
| T16 | แถวต่อเนื่องเป็นแถวแรกของไฟล์ / แถวต่อเนื่องมี B หรือ C / ระดับ 1 กรอกไม่ครบ | L01 / L03 / L02 |
| T17 | แถวต่อเนื่องใต้แถวแม่ | L04 |
| T18 | บรรทัดงบเดียวกันอยู่ 2 ช่วงไม่ติดกัน / ศูนย์ต้นทุนเดียวกัน 2 ช่วงในบรรทัดงบเดียว | L06 / L07 |
| T19 | แถวแม่ที่ไม่มีใน fn (เช่น รายการ 31124 แหล่ง 400 เลขที่ 68030002) | F07 และไม่มีการเรียก CheckTotalBudget |
| T20 | กดปุ่ม "นำออก Template" ใบ 2586 | ได้ไฟล์ บรรทัดงบไม่ซ้ำกับรายการเดิมของใบ master ครบ 6 sheet + แหล่งเงิน ชื่อไฟล์ตาม ROUNDNO |

## 8. นอกขอบเขตรอบนี้

- แก้ไขหรือลบรายการเดิมผ่าน Excel (โหมดแทนที่)
- บัญชีผู้โอน/ผู้รับโอนของแท็บ 2 ใน Excel
- แก้ไขข้อมูลใน modal 3.2
- เติมศูนย์ต้นทุนให้รายการที่บันทึกแล้วผ่าน Excel (ทำที่หน้าศูนย์ต้นทุนเดิม)

## 9. ต้องยืนยันก่อนลงมือ

ผู้ใช้ตอบ 2026-10-29 (ข้อ 1–5, 7 ปิดแล้ว เหลือข้อ 6)

1. ~~กฎ F05 และ W01~~ **เตือนทั้งคู่** ไม่บล็อก (F05 เปลี่ยนเป็น W02 ในหัวข้อ 4)
2. ~~จำนวนบรรทัดงบใหม่สูงสุดต่อไฟล์~~ **50** (กฎ R07)
3. ~~DBA deploy fn บน PROD หรือยัง~~ **deploy แล้ว** ความเสี่ยง timeout ของ fn ในหัวข้อ 6 ลดลง
4. ~~ชื่อปุ่มและตำแหน่งบนหน้าจอ~~ ผู้ใช้กำหนดแล้ว 2026-10-29: ปุ่ม "นำเข้าข้อมูลด้วย Excel" หน้าปุ่มอัพเดทงบประมาณ → modal วางไฟล์ + ปุ่มนำออก Template มุมขวาบน (หัวข้อ 10)
5. ~~บรรทัดงบใน fn ที่รายการยกเลิกแล้ว (เช่น 2229, 10124)~~ **ตัดออกตอน export** (ผู้ใช้: "อาจมีปรับ แต่ทำแบบนี้ไปก่อน") R03 ปฏิเสธรายการ inactive ด้วย ดูท้ายหัวข้อ 4
6. ⏳ **รอผู้ใช้ตรวจสอบ** — fn คืน `BUDGETPLANID` ว่างสำหรับแถวแม่แหล่ง 200 (รายการ 31124) แต่ข้อมูลที่บันทึกแล้วในใบ 2586 แถวแม่แหล่ง 200 ใช้ `90000` ต้องดูว่าหน้าจอเติม 90000 ให้ตรงไหน แล้วให้ export / การจับคู่คีย์ 7 ตัวใช้ค่าเดียวกัน (ไฟล์ตัวอย่างใส่ 90000)
7. ~~แหล่ง 400 ตอน import~~ **ทาง ข: ยอมให้พิมพ์แถวแม่/ลูกแหล่ง 400 เอง** แม่ต้องผ่าน F07 (จับคู่กับ fn ทั้งชุด) ดูท้ายหัวข้อ 4

## 10. สิ่งที่ทำแล้ว

### 2026-10-28 — ขั้น 2 Export template (ปุ่ม "นำออก Template")

| ไฟล์ | สิ่งที่เพิ่ม |
|---|---|
| `OAGBudget.API/Services/Repository/BudgetService.cs:12747` | `ExportBudgetAllocateTransferImportTemplate(int id)` คืน `(byte[], fileName)` + ประกาศใน interface (`:184`) |
| `OAGBudget.API/Controllers/BudgetController.cs:1571` | `[HttpGet("ExportBudgetAllocateTransferImportTemplate")]` |
| `OAGBudget/Services/Repository/BudgetService.cs:4992` | เรียก API แล้วอ่านชื่อไฟล์จาก `Content-Disposition` + interface (`:209`) |
| `OAGBudget/Controllers/BudgetController.cs:4171` | `[HttpGet] ExportBudgetAllocateTransferImportTemplate(id)` → `File(...)` ถ้า error คืน `{ success:false, message }` |
| `OAGBudget/Views/Budget/BudgetAllocateTransferDetail.cshtml:693` | ปุ่ม `#btnExportImportTemplate` (ย้ายไปมุมขวาบนของ modal นำเข้า เมื่อ 2026-10-29 ดูด้านล่าง) |
| `OAGBudget/Views/Budget/BudgetAllocateTransferDetail.cshtml:1245` | `exportImportTemplate()` fetch → blob → ดาวน์โหลด ชื่อไฟล์จาก `filename*` (UTF-8) |

พฤติกรรม
- ปฏิเสธถ้าไม่พบใบ ("ไม่พบใบโอนจัดสรร") หรือสถานะไม่ใช่ 80101
- บรรทัดงบ = `GetBudgetTransferCategory(new SearchBudgetAllocateTransfer { Id = id })` ตัดบรรทัดที่ใบมีแล้ว (คีย์ 7 ตัว แผนงาน 0/ว่างถือว่าเท่ากัน) และ distinct ตามคีย์
- **ไม่ใส่บรรทัดแหล่งเงิน 400** (ผู้ใช้กำหนด 2026-10-28) ใบ 2586 เหลือ 348 บรรทัด (100: 344, 200: 3, 300: 1) ส่วน sheet แหล่งเงินและ dropdown ยังมี 400 อยู่ ดูหัวข้อ 9 ข้อ 7
- รหัสงบ = segment 9 ของ AccountCode แบบ `Split('.')` (ไม่ข้ามช่องว่าง) ตรงกับ `accountCode.split('.')[8]` ฝั่ง JS
- แผนงานเขียนเป็น 5 หลัก (`BudgetPlanId.ToString("D5")`) ถ้า fn คืนว่าง (31124 แหล่ง 200) ช่องจะว่าง ดูหัวข้อ 9 ข้อ 6
- **ไม่มีคอลัมน์คงเหลือ** (ผู้ใช้สั่งตัดออก 2026-10-28) คอลัมน์หลังรหัสงบประมาณเลื่อนซ้าย 1 ช่อง (ศูนย์ต้นทุน O, ชื่อ P, หน่วยเบิกจ่าย Q, จำนวนเงิน R, หมายเหตุ S รวม 19 คอลัมน์) ตอน import ใช้ TotalBalanceAmount จาก fn ตามเดิม
- sheet ครบ 10 sheet, สูตร/dropdown ใส่ถึงแถว `max(1000, จำนวนบรรทัด + 500)`, "อ่านก่อน" อธิบายรูปแบบไม่กรอกซ้ำ
- ชื่อไฟล์ `โอนจัดสรร_นำเข้า_{ROUNDNO}_{yyyyMMdd}.xlsx` (ปี ค.ศ.)

ผลตรวจ (PREPROD, ใบ 2586)
- `dotnet build` ทั้ง solution ไม่ผ่านเพราะ VS/แอปที่รันอยู่ล็อก dll (MSB3027) ไม่ใช่ compile error → build API และ MVC แยก output ไป scratchpad: **0 Error ทั้งสองโปรเจกต์**
- รัน API ตัวที่ build ใหม่บน port 5999 แล้วเรียก endpoint: 200, 183 KB, 11.6 วินาที (รวม warmup) id ที่ไม่มีได้ "ไม่พบใบโอนจัดสรร"
- fn คืน 360 คีย์ ใบ 2586 มี 3 บรรทัดที่อยู่ใน fn (5029, 5030, 5032) → ไฟล์ได้ **357 บรรทัด ตรงกัน** (5031, 5034 เป็นรายการเพิ่มใหม่ ไม่อยู่ใน fn) หลังตัดแหล่ง 400 (9 บรรทัด) เหลือ **348** ตรวจซ้ำแล้ว ไม่มีแหล่ง 400 ในไฟล์
- รหัสเก็บเป็นข้อความทุก cell, master ไม่มีรหัสซ้ำ, สูตร VLOOKUP ชี้ถูกทุกแถว, รหัสที่ใช้มีใน master ครบ **ยกเว้นรายการ 2229, 10124** (inactive แล้ว หัวข้อ 9 ข้อ 5)
- ไฟล์มี 26 บรรทัดที่คงเหลือติดลบ (โมดอลก็แสดง)
- ยังไม่ได้ทดสอบผ่านหน้าเว็บจริง (ต้อง restart แอปใน VS ก่อน)

### 2026-10-29 — ปุ่มและ modal "นำเข้าข้อมูลด้วย Excel" (ผู้ใช้กำหนดตำแหน่ง ตอบหัวข้อ 9 ข้อ 4)

| ไฟล์ | สิ่งที่เพิ่ม |
|---|---|
| `BudgetAllocateTransferDetail.cshtml:280` | ปุ่ม `#btnOpenImportExcelModal` (เขียว) วาง**หน้า**ปุ่ม "อัพเดทงบประมาณ" แสดงเฉพาะสถานะ 80101 |
| `BudgetAllocateTransferDetail.cshtml:687` | modal `#importExcelModal` (render เฉพาะ 80101): หัวมีปุ่ม "นำออก Template" มุมขวาบน ข้างปุ่มปิด, body เป็นพื้นที่วางไฟล์ (ลากวาง/คลิกเลือก รับ `.xlsx` ไฟล์เดียว) แสดงชื่อ+ขนาด และปุ่มลบไฟล์, footer ปุ่ม "ปิด" + "ตรวจสอบไฟล์" (ปิดไว้จนกว่าจะเลือกไฟล์) |
| `BudgetAllocateTransferDetail.cshtml:1190` | `openImportExcelModal()`, `setImportExcelFile()`, `clearImportExcelFile()`, handler drag/drop, `checkImportExcel()` |
| `BudgetAllocateTransferDetail.cshtml` `<style>` | `.import-excel-dropzone` (กรอบเส้นประ, สีเปลี่ยนตอนลากผ่าน) |

- **"ตรวจสอบไฟล์" ยังเป็น placeholder** แสดง "ยังไม่เปิดใช้งาน" ไม่ส่งไฟล์ไป server (endpoint parse ขั้น 3 ยังไม่ทำ) เปิดใช้เมื่อเขียน parse แล้วให้แทนตัว `checkImportExcel()`
- ปุ่ม "นำออก Template" เดิมข้าง "เลือกรายการงบประมาณ" ถูกย้ายออก (ไม่มีปุ่มซ้ำ) ฟังก์ชัน `exportImportTemplate()` ใช้ตัวเดิม loading เป็น Swal จึงแสดงทับ modal ได้
- ผลตรวจ: build MVC แยก output ไป scratchpad **0 Error** (Razor view compile ผ่าน) ยังไม่ได้ทดสอบบนหน้าเว็บจริง

## 11. แผนลงมือ (2026-10-29)

### ความพร้อม

| เรื่อง | สถานะ |
|---|---|
| คำตอบหัวข้อ 9 | ครบ ยกเว้นข้อ 6 |
| ข้อ 6 กระทบอะไร | เฉพาะ**แถวแม่แหล่ง 200 ที่ fn คืนแผนงานว่าง** (เช่น 31124): ถ้าเว้น F ว่างจะตก R01 ถ้าใส่ 90000 จะตก F07 (คีย์ไม่ตรง fn) กลุ่ม REF แบบนี้จึง import ไม่ได้จนกว่าข้อ 6 จะได้ข้อสรุป ส่วนอื่นทำต่อได้ การเทียบแผนงานรวมไว้ใน helper `PlanKey` ตัวเดียว (ตัวเดียวกับ export) ถ้าตัดสินแล้วแก้จุดเดียว |
| transaction ตอน save | ตรวจแล้ว `SaveBudgetAllocateTransferDetail` (`:13523`) และ `SaveBudgetAllocateTransferCostCenter` (`:14367`) **ไม่เปิด transaction เอง** และ throw ต่อ (ไม่กลืน error) ครอบด้วย transaction ชั้นนอกได้ตามแผนขั้น 4 |
| `SaveBudgetAllocateTransferDetail` | ตั้งสถานะหัวเป็น `80101` ทุกครั้ง และ `SaveBudgetAllocateTransferCategory` sync รายการตาม list (รายการใน DB ที่ไม่อยู่ใน list ถูกลบ) จึงต้องบันทึก detail **ก่อน** insert แถว import ตามลำดับในขั้น 4 |
| จุด `id !== 0` ใน cshtml | เลขบรรทัดในหัวข้อ 3.1 เลื่อนแล้ว grep ปัจจุบันพบ `:815`, `:1409`, `:1844`, `:1941`, `:3012`, `:3383` (ต้องไล่ใหม่ตอนทำเฟส C) |
| ไฟล์ทดสอบ | template01 / 20items ในโฟลเดอร์ยังเป็น layout เก่า ต้องสร้างไฟล์ทดสอบชุดใหม่ (19 คอลัมน์ แบบไม่กรอกซ้ำ) ด้วยโปรแกรม gen ใน scratchpad |

### เฟส (แต่ละเฟส build ผ่าน + ทดสอบก่อนไปเฟสถัดไป ผู้ใช้ checkin เอง)

| เฟส | งาน | เขียน DB? | ทดสอบ |
|---|---|---|---|
| **A** export ตัด inactive | `ExportBudgetAllocateTransferImportTemplate` กรองบรรทัดงบที่ CategoryId ไม่อยู่ใน master รายการ (ชุดเดียวกับ sheet) | ไม่ | export ใบ 2586 ต้องไม่มี 2229, 10124 จำนวนบรรทัด = 348 − บรรทัดของ 2 รายการนี้ |
| **B** parse (server) | model ใหม่ใน `OAGBudget.Models`, `ParseBudgetAllocateTransferImport` อ่านไฟล์ → fill-down → กฎ H/R/L/C/A/F/W → จัดกลุ่ม → หาข้อมูลระดับ 1 (fn / CheckTotalBudget), endpoint API + MVC (`Request.Form.Files[0]`) | ไม่ (ยกเว้น CheckTotalBudget อาจสร้าง CCID) | ไฟล์ทดสอบ T03–T08, T15–T19 ผ่าน API port แยก ไฟล์ที่มี error ต้องไม่เรียก CheckTotalBudget เลย |
| **B2** modal แสดงผล parse | แทน placeholder `checkImportExcel()`: ส่งไฟล์, แสดงตาราง error (แถว/คอลัมน์/ข้อความ) และ warning ใน modal, ตรวจ "มีรายการยังไม่บันทึก" ก่อนส่ง, จำกัด 5 MB | ไม่ | ผู้ใช้ลองบนหน้าเว็บ |
| **C** merge ลงตาราง | temp id ติดลบ, `id !== 0` → `id > 0`, badge "นำเข้า (ยังไม่บันทึก)", modal `#importCostCenterModal` อ่านอย่างเดียว | ไม่ | T10, T14 (regression หน้าจอเดิม) |
| **D** save | `SaveBudgetAllocateTransferImport` ใน transaction เดียว ตรวจซ้ำ (`ValidateImportItemsAsync` ตัวเดียวกับ parse) → insert แม่/อิสระ → ลูก → `SaveBudgetAllocateTransferCostCenter` ต่อ CATEGORY, แยก payload ใน `#btn-save` | **ใช่** | T01, T02b, T11, T12, T13 บน PREPROD (ต้องขออนุญาตก่อนเขียนข้อมูลลงใบจริง หรือสร้างใบทดสอบใหม่) |

### จุดที่ต้องขออนุญาตระหว่างทาง (R0)

- ทดสอบ parse ไฟล์ที่มีบรรทัดงบใหม่ (ไม่อยู่ใน fn): CheckTotalBudget อาจสร้าง CCID ถาวรใน EBS PREPROD จะเช็ค KFV ก่อนว่าชุดบัญชีมีอยู่แล้วหรือไม่ แล้วแจ้งผู้ใช้ก่อนยิง ([[find_budget สร้าง CCID]])
- ทดสอบเฟส D: insert CATEGORY / RECEIVE / NOTE ลงใบใน PREPROD

### 2026-10-29 — เฟส A (export ตัด inactive) + เฟส B (parse) + เฟส B2 (แสดงผลใน modal)

| ไฟล์ | สิ่งที่เพิ่ม/แก้ |
|---|---|
| `OAGBudget.Models/Data/BudgetAllocateTransferImportModel.cs` (ใหม่) | `ParseRequest { Id, FileName, FileData }`, `ParseResult { Success, Message, Errors, Warnings, Items, NewLineCount }`, `Message { Row, Column, Code, Message }`, `Item` (ชื่อ property = field ของ periodData เมื่อเป็น camelCase + `TempId/TempRef/GroupCode/IsParent/InFn/ImportRows/Receives`), `Receive`, `Note` |
| `OAGBudget.API/Services/Repository/BudgetService.cs:13044` | `#region` ใช้ร่วม export/parse: `ImportPlanKey`, `ImportBudgetCodeOf`, `ImportLineKey`, `ImportFnLineKey`, `GetAllocateTransferImportExistingKeysAsync`, `LoadAllocateTransferImportMastersAsync` (ย้าย query master ออกจาก export ให้ 2 ทางใช้ชุดเดียวกัน ไม่เปลี่ยนผล) |
| `OAGBudget.API/Services/Repository/BudgetService.cs:13164` | `ParseBudgetAllocateTransferImport` + interface |
| `OAGBudget.API/Controllers/BudgetController.cs:1585` | `[HttpPost("ParseBudgetAllocateTransferImport")]` รับ JSON (ไฟล์เป็น base64) |
| `OAGBudget/Services/Repository/BudgetService.cs:5015` | เรียก API (timeout 10 นาที) + interface |
| `OAGBudget/Controllers/BudgetController.cs:4189` | `[HttpPost] ParseBudgetAllocateTransferImport(id)` อ่าน `Request.Form.Files` ตรวจ .xlsx / ≤ 5 MB |
| `BudgetAllocateTransferDetail.cshtml:1230` | `checkImportExcel()` (บล็อกถ้ามีรายการยังไม่บันทึก) → `renderImportExcelResult()` ตาราง error/คำเตือน หรือสรุป + ตารางบรรทัดงบที่จะนำเข้า; ปุ่ม "นำเข้าลงตาราง" (`confirmImportExcel`) ยังเป็น placeholder รอเฟส C; modal ขยายเป็น `modal-xl` |

การตัดสินใจระหว่างเขียน (ต่างจาก/เพิ่มจากแผนเดิม)
- **บรรทัดงบใหม่ที่เป็นแถวลูก** ใช้ `totalreceiveamount = CheckTotalBudget.totalBudget` ตามปุ่ม "เพิ่มบัญชีรับโอน" (`addSingleTransferItemByFilters`) ส่วนรายการอิสระใหม่ใช้ 0 ตามปุ่ม "เพิ่มรายการใหม่" (แผนเดิมเขียนว่า 0 ทั้งคู่)
- **R03 ยังไม่ตรวจว่ารายการอยู่ในแผนงาน F** ตรวจแค่ active (ชุดเดียวกับ sheet รายการ) เพราะ dropdown หน้าจอกรองผ่าน `GetTypeCategoryByPlan` และกรณีพิเศษ 90000/00000 ต้องยกมาทั้งชุด — ยังเป็นข้อค้าง
- **W01 เตือนเฉพาะรายการอิสระที่อยู่ใน fn** บรรทัดใหม่คงเหลือเป็น 0 ตามหน้าจอเดิม ถ้าเตือนจะขึ้นทุกบรรทัด
- **L06 ใช้เฉพาะบรรทัดงบที่ใช้จริง** บรรทัดที่ export มาแต่ไม่ได้กรอก ไม่นับ (ผู้ใช้พิมพ์บรรทัดเดิมเพิ่มท้ายไฟล์ได้ ถ้าไม่ได้กรอกบรรทัดที่ export มา)
- แถวแม่ที่มี error ก็ยังได้ W02 ถ้าไม่มีลูก (ไม่กระทบเพราะมี error อยู่แล้ว)
- CheckTotalBudget ถูกเรียก**เฉพาะเมื่อไม่มี error อื่นเลย** (รวม R07) ทีละคีย์ ถ้า throw/ไม่สำเร็จ = R06

ข้อมูลประกอบหัวข้อ 9 ข้อ 6 (พบระหว่างทดสอบ ยังไม่ตัดสิน): fn (2569,'1') คืน 31124 แหล่ง 200 **2 บรรทัด** — แผนงานว่าง คงเหลือ 0 และแผนงาน 90000 คงเหลือ 70,038,000 ทั้งสองบรรทัดอยู่ใน template (แหล่ง 200 = 3 บรรทัดคือ 2 บรรทัดนี้ + 2194) แถวแม่ 31124/90000 import ได้ (ผ่าน F07 ใน V1) ส่วนบรรทัดแผนงานว่างกรอกแล้วจะตก L02

ผลตรวจ (PREPROD ใบ 2586, API ที่ build ใหม่ port 5999; ไฟล์ทดสอบอยู่ `test_parse_2586/`)
- build API / MVC แยก output: **0 Error** ทั้งสอง (Models build ผ่านเป็น dependency)
- เฟส A: export 200 (10.6 วิ) **346 บรรทัด** (เดิม 348 ตัด 2229, 10124) ไม่มีแหล่ง 400, 19 คอลัมน์, "อ่านก่อน" บอกว่าไม่รวมรายการยกเลิก
- `V1_valid.xlsx` (fill-down + กรอกซ้ำ + บรรทัดไม่ใช้ + แม่ 300/200/400 ไม่มีลูก): success, 5 บรรทัดงบ / 4 ศูนย์ต้นทุน / 6 หมายเหตุ, W02 × 3, `newLineCount = 0` ค่า totalreceiveamount/template/summary/code ตรงกับ fn, แม่ 400 พิมพ์เอง (68030002/2291) ผ่าน F07
- `E1_errors.xlsx`: 19 error ตรงตามที่ออกแบบ (L01 C01 A01 C02 L07 L02 L06 R02 R04 R05 F01 L04 F03 F07 L03 F04 F03 R03) เรียงตามแถว ไม่เรียก CheckTotalBudget
- `E2_r07.xlsx` (บรรทัดใหม่ 55 + C01 กันไว้): R07 + C01 ไม่เรียก CheckTotalBudget
- `H01_otherid.xlsx`: H01 "ไฟล์นี้ไม่ใช่ของใบโอนนี้" / ใบ id 42 (80201): H02
- **ยังไม่ได้ทดสอบ**: ไฟล์ที่ผ่านแล้วมีบรรทัดงบใหม่ (ต้องเรียก CheckTotalBudget จริง → อาจสร้าง CCID ใน PREPROD ต้องขออนุญาตก่อน), หน้าเว็บจริง (ต้อง restart แอปใน VS)

### 2026-10-29 — เฟส C (นำลงตาราง) + เฟส D (บันทึก API ใหม่)

| ไฟล์ | สิ่งที่เพิ่ม/แก้ |
|---|---|
| `OAGBudget.Models/Data/BudgetAllocateTransferImportModel.cs` | `SaveModel { Detail, ImportItems }`, `SaveResult { Success, Id, Message, Errors }`, `Item.Totaltemplateamount` |
| `OAGBudget.API/Services/Repository/BudgetService.cs:13386` | แยกส่วนตรวจกับ master/fn/DB + สร้าง items ของ parse เป็น `ResolveAllocateTransferImportLinesAsync` ให้ save ใช้กฎชุดเดียวกัน (refactor: ผล parse V1 เหมือนเดิมทุก field ยกเว้น field ใหม่ `totaltemplateamount`) + บรรทัดใหม่ได้ `Budgettypeid/Budgetyear` จาก fn บรรทัดที่ตรง (รายการ, ผลผลิต, กิจกรรม, แผน, แหล่ง) แบบ `addFuncAsync` |
| `OAGBudget.API/Services/Repository/BudgetService.cs:13616` | `SaveBudgetAllocateTransferImport` + interface |
| `OAGBudget.API/Controllers/BudgetController.cs:1601` / `OAGBudget/Controllers/BudgetController.cs:4219` / `OAGBudget/Services/Repository/BudgetService.cs:5035` | endpoint + MVC service (timeout 10 นาที) |
| `BudgetAllocateTransferDetail.cshtml:1328` | `confirmImportExcel()` push items ลง `periodData` (`id` = temp id ติดลบ, `ref` = temp id แม่, `isImported`, `receives`, `importRows`) แล้ว render |
| `BudgetAllocateTransferDetail.cshtml:732`, `:1388` | modal `#importCostCenterModal` + `openImportCostCenterModal()` อ่านอย่างเดียว (หัว: แหล่ง/แผน/ผลผลิต/กิจกรรม/รายการ/รหัสงบ/คงเหลือ/เพดานลูก/แถว Excel, ตาราง หน่วยเบิกจ่าย/ศูนย์ต้นทุน/ยอด/หมายเหตุหลายบรรทัด) |
| `BudgetAllocateTransferDetail.cshtml` render | badge "นำเข้า (ยังไม่บันทึก)" ท้ายชื่อรายการ + ปุ่ม `fa-list` ดูศูนย์ต้นทุน (แถวแม่ไม่มีปุ่มเพราะไม่มีศูนย์ต้นทุน) |
| `BudgetAllocateTransferDetail.cshtml:1616`, `:1728` | ปุ่มบันทึก: แถว `isImported` ไม่เข้า `budgetAllocateTransferCategoryList` แยกเป็น `importItems` (ส่งแค่รหัส, temp id, ศูนย์ต้นทุน, ยอด, หมายเหตุ, `totaltemplateamount` ของกลุ่ม) ถ้ามี → `SaveBudgetAllocateTransferImport` ไม่มี → `SaveBudgetAllocateTransferDetail` เหมือนเดิม; บันทึกไม่ผ่านแสดงรายการ error (ไม่เกิน 30) |
| `BudgetAllocateTransferDetail.cshtml:2092`, `:2192`, `:3169`, `:3635` | `id !== 0` / `id === 0` → `id > 0` (ปุ่มแก้ไข/บัญชีรับโอน, หา budget code ของรายการบันทึกแล้ว, ตรวจลบรายการบันทึกแล้ว) ต่างจากเดิมเฉพาะ id ติดลบ แถวเดิม (0 / บวก) ทำงานเหมือนเดิม; `findExistingNewItemInPeriodData` คง `id === 0` ไว้ (ไม่รวมแถวนำเข้า) |

ลำดับใน `SaveBudgetAllocateTransferImport`
1. ตรวจก่อนเปิด transaction: มี id หัวใบ, มี importItems, หัวใบสถานะ 80101 (ต้องตรวจก่อน เพราะ `SaveBudgetAllocateTransferDetail` ตั้งสถานะเป็น 80101 เสมอ), temp id ติดลบและไม่ซ้ำ
2. แปลง importItems เป็นบรรทัดงบ (รหัสกลุ่มแม่ = groupCode, ลูกที่แม่ถูกลบจากตาราง → F03) ตรวจ L02 / L07 / C02 / A01 ระดับ item
3. `BeginTransaction` → `SaveBudgetAllocateTransferDetail(Detail)` ตัวเดิม → `ResolveAllocateTransferImportLinesAsync` (R05 เห็นรายการที่เพิ่งบันทึกในข้อนี้ด้วย, fn/คงเหลือ ณ ตอนบันทึก, CheckTotalBudget บรรทัดใหม่อีกรอบ) ไม่ผ่าน → rollback คืน errors
4. insert CATEGORY แม่/อิสระ → SaveChanges → ลูก (REF = id จริงของแม่) → SaveChanges; ค่าระดับ 1 ใช้ที่ server หาเอง ใช้จาก client แค่ `totaltemplateamount` (auto-update หลัง reload เขียนทับอยู่แล้ว)
5. `SaveBudgetAllocateTransferCostCenter` ตัวเดิมต่อ CATEGORY ที่มีศูนย์ต้นทุน คืน 0 → throw → rollback
6. Commit คืน id หัวใบ → หน้าจอตั้ง flag auto-update แล้ว reload เหมือนบันทึกปกติ

ผลตรวจ
- build API / MVC แยก output: **0 Error**; สคริปต์ใน view ผ่าน `node --check` (แทน Razor expression ด้วยค่าหลอกก่อนตรวจ)
- parse ไฟล์ทดสอบ 4 ไฟล์หลัง refactor: ผลเท่าเดิม (V1 items เหมือนเดิมทุก field ยกเว้น `totaltemplateamount` ที่เพิ่มใหม่)
- save ด้วย payload ไม่มีหัวใบ → "นำเข้าได้เฉพาะใบโอนที่บันทึกหัวใบแล้ว", ใบ id 42 (80201) → "ใบโอนไม่อยู่ในสถานะร่าง" ทั้งสองกรณีไม่แตะ DB
- **ยังไม่ได้ทดสอบ**: บันทึกจริง (เขียน PREPROD และ `SaveBudgetAllocateTransferDetail` ต้องใช้ token ผู้ใช้ จึงต้องทดสอบผ่านหน้าเว็บ), CheckTotalBudget ของบรรทัดใหม่, regression หน้าจอเดิม (T14), การลบแถวนำเข้าก่อนบันทึก (T10), การจองงบหลังบันทึก (T13)

### 2026-10-29 — เก็บไฟล์ Excel ที่นำเข้าลง `OAGWBG_BUDGETALLOCATETRANSFER_IMPORT_EXCEL` (ผู้ใช้สั่ง)

ตาราง (มีอยู่แล้วบน PREPROD, 0 แถว ณ วันที่เพิ่มโค้ด): ID identity, BUDGETYEAR, BUDGETALLOCATETRANSFERID (ไม่มี FK), ROUNDNO, FILENAME (500, NOT NULL), CONTENTTYPE, FILESIZE, FILEHASH (SHA-256 hex), FILECONTENT BLOB NOT NULL, TOTALROWS, ERRORROWS, IMPORTSTATUS (CHECK 40101/40201/40301/40401/40501 ตาม OAGWBG_MASTERSTATUS: อัปโหลดแล้ว/ตรวจผ่านรอยืนยัน/นำเข้าแล้ว/ตีกลับ/ยกเลิก), ERRORMESSAGE CLOB, NOTE, CREATEBY/ON, UPDATEBY/ON

| ไฟล์ | สิ่งที่เพิ่ม |
|---|---|
| `OAGBudget.DAL/Models/OagwbgBudgetallocatetransferImportExcel.cs` (ใหม่) | entity |
| `OAGBudget.DAL/Models/OAGDBContextBase.cs:2098` | `DbSet` + mapping (แบบเดียวกับ COSTCENTER_NOTE ที่ ID เป็น identity เหมือนกัน) |
| `OAGBudget.Models/Data/BudgetAllocateTransferImportModel.cs` | `ParseResult.TotalRows`, `SaveModel.ImportFile { FileName, ContentType, FileData, TotalRows }` |
| `OAGBudget.API/Services/Repository/BudgetService.cs:13637` | save ตรวจไฟล์ก่อนเปิด transaction: ต้องมี, ≤ 5 MB, เปิดได้, sheet ข้อมูลใบโอนเป็นของใบนี้ |
| `OAGBudget.API/Services/Repository/BudgetService.cs:13824` | ขั้น 5 insert 1 แถว สถานะ **40301** (ERRORROWS 0, NOTE = จำนวนบรรทัดงบ/ศูนย์ต้นทุน/หมายเหตุที่บันทึกจริง) ก่อน Commit ใน transaction เดียวกัน |
| `BudgetAllocateTransferDetail.cshtml:1373`, `:1381`, `:1742` | ตอนกด "นำเข้าลงตาราง" เก็บไฟล์ไว้ใน `importedExcel` (แยกจาก `importExcelFile` ที่ล้างเมื่อเปิด modal ใหม่) ตอนบันทึกอ่านเป็น base64 ส่งใน `importFile` |

- เก็บ**เฉพาะไฟล์ที่ตรวจผ่านและบันทึกสำเร็จ** (40301) ตามที่สั่ง ไฟล์ที่ตีกลับ (40401) / ตรวจผ่านแต่ไม่ได้บันทึก (40201) ยังไม่ได้เก็บ
- ถ้าผู้ใช้ลบแถวนำเข้าบางแถวก่อนบันทึก ไฟล์ที่เก็บยังเป็นไฟล์เต็ม NOTE บอกจำนวนที่บันทึกจริง
- ผลตรวจ: build API / MVC **0 Error**, `node --check` ผ่าน; **ยังไม่ได้รันจริง** (mapping EF ของตารางใหม่จะถูกใช้ครั้งแรกตอนบันทึกผ่านหน้าเว็บ)
- TFS: ไฟล์ใหม่ 2 ไฟล์ (`OagwbgBudgetallocatetransferImportExcel.cs`, `BudgetAllocateTransferImportModel.cs`) ต้อง `tf add` ก่อน checkin

### 2026-10-29 — Template รายไตรมาส + ยอด 0

**ข้อตกลง (ผู้ใช้ตอบ 2026-10-29)**
- ยอด "ไตรมาสนั้นจัดสรรได้" = ผลรวม **PLANAMOUNT** ของ `OAGWBG_V_BUDGETDISBURSEMENTPLANITEM` (ALLOCATEAMOUNT ปี 2569 มีค่าเฉพาะภาค 00)
- ช่องจำนวนเงินในไฟล์**เว้นว่าง** + คอลัมน์ T "แผนการใช้จ่าย ไตรมาส n" (อ้างอิง ไม่ถูกอ่าน)
- **ยอด 0 = เตือน (W03) แล้วไม่บันทึกแถวนั้น ทุก template** / ยอดว่างที่มีศูนย์ต้นทุน = error C02 เหมือนเดิม → template รายไตรมาสต้องกรอกทุกแถว (ไม่จัดสรรกรอก 0 หรือลบแถว)
- หน้าจอเป็น modal ใหม่ เปิดจากปุ่ม "นำออก Template รายไตรมาส" ข้างปุ่ม "นำออก Template" ใน modal นำเข้า

**ข้อมูล view (ตรวจ PREPROD)**
- แถวรายเดือนต่อ (BUDGETGOVERNMENT, ศูนย์ต้นทุน) — 1 ศูนย์มีหลายแถวต่อเดือนได้ (คนละคำขอ/โครงการ) ต้องรวม; ไม่มีแผนงาน/รหัสงบ/แหล่งเงิน จับคู่บรรทัดงบได้ด้วย (รายการ, ผลผลิต, กิจกรรม) เท่านั้น
- ไตรมาสจาก MONTH: Q1 = 10–12, Q2 = 1–3, Q3 = 4–6, Q4 = 7–9 (`OAGWBG_V_MONTHLIST.BUDGETSEQUENCE`)
- เงื่อนไข `BUDGETSTATUS <> 'A'` แบบ `GetBudgetDisbursementPlanByRegion` (EF แปลรวม NULL ด้วย); VERSION 2 มี 29 BUDGETGOVERNMENT ที่มีแถว version ว่างคู่กัน แต่แถว version ว่างเป็น 0 ทั้งหมด รวมกันไม่ซ้ำ
- ตรวจกับ SQL ตรง: 2216/21000/21300 ภาค 01 Q1 = **927,000 (8 ศูนย์)**, 2186/11000/11100 = **5,216,580** ตรงกับ API

**โค้ด**

| ไฟล์ | สิ่งที่เพิ่ม/แก้ |
|---|---|
| `OAGBudget.API/Services/Repository/BudgetService.cs:12833` | แยก workbook ของ export เป็น `BuildAllocateTransferImportWorkbook(header, masters, dataRows, now, quarter?)` + `GetAllocateTransferImportTemplateLinesAsync` (template ปกติผลเหมือนเดิม) แถวข้อมูลรองรับแถวต่อเนื่อง + ศูนย์ต้นทุนที่เติมไว้ + คอลัมน์ T; validation ยอดเปลี่ยนเป็น ≥ 0; "อ่านก่อน" เพิ่มเรื่องยอด 0 และหัวข้อรายไตรมาส; ข้อมูลใบโอนเพิ่ม ชนิด/ไตรมาส/ภาค (parse ไม่ใช้) |
| `BudgetService.cs:13214` | `GetBudgetAllocateTransferQuarterLines(id, regionId, quarter)` บรรทัดงบ**แหล่ง 100** ของใบ (ชุดเดียวกับ template ปกติ) + แผนไตรมาสรวมทุกศูนย์ในภาค + จำนวนศูนย์ที่มีแผน |
| `BudgetService.cs:13254` | `ExportBudgetAllocateTransferQuarterTemplate({ Id, RegionId, Quarter, LineKeys })` รายการ × ศูนย์ต้นทุนทุกศูนย์ในภาค (STATUS Y + มีหน่วยเบิกจ่าย) แถวแรกมีรหัสบรรทัดงบ แถวถัดไปเป็นแถวต่อเนื่อง; เกิน 3,000 แถว → error; ชื่อไฟล์ `..._{ROUNDNO}_Q{n}_ภาค{xx}_{yyyyMMdd}.xlsx` |
| `BudgetService.cs:13608` | parse: ยอด 0 → `ZeroRows` ไม่สร้าง note, ศูนย์ที่มีแต่ 0 ถูกตัด, บรรทัดงบ (ไม่ใช่แม่) ที่เหลือแต่ 0 ไม่นำเข้า + W03; ยอดติดลบยังเป็น A01 |
| API / MVC controller + service | `GetBudgetAllocateTransferQuarterLines` (GET), `ExportBudgetAllocateTransferQuarterTemplate` (POST JSON → ไฟล์) |
| `OAGBudget.Models/Data/BudgetAllocateTransferImportModel.cs` | `QuarterRequest`, `QuarterLinesResult`, `QuarterLine` |
| `BudgetAllocateTransferDetail.cshtml:693`, `:737`, `:1578` | ปุ่มใน modal นำเข้า, modal `#quarterTemplateModal` (ภาค: ใบที่ระบุภาคล็อกเป็นภาคของใบ / ไตรมาส / ค้นหา / ติ๊ก "เฉพาะรายการที่มีแผน" / ตารางคอลัมน์สุดท้าย = แผนไตรมาส + จำนวนศูนย์ / footer จำนวนแถวที่จะได้) + `downloadExcelResponse()` ใช้ร่วมกับ export ปกติ |

ภาค: ใบภาค 99/ALL เลือกภาคไหนก็ได้ (เลือก 99 = ทุกศูนย์ ~391 ศูนย์ จึงเลือกได้ไม่เกิน 7 รายการ) ใบที่ระบุภาคเลือกได้แค่ภาคของใบ (ศูนย์ภาคอื่นจะตก C01)

ข้อควรระวัง (ยังไม่ได้แก้)
- แผนจับคู่ด้วย (รายการ, ผลผลิต, กิจกรรม) ถ้า fn มีหลายบรรทัดงบที่ 3 ค่านี้เหมือนกัน (ต่างรหัสงบ/เลขที่ เช่น 2216/21200 มีทั้งเลขที่ว่างและ 69220001) ทุกบรรทัดจะแสดงแผนก้อนเดียวกัน — ถ้าเลือกทั้งคู่แล้วกรอกตามแผน จะจัดสรรซ้ำ 2 เท่า
- แหล่ง 200/300/400 ไม่แสดงใน modal (แผนการใช้จ่ายเป็นงบประมาณแผ่นดิน)

ผลตรวจ (PREPROD ใบ 2586 ไฟล์อยู่ `test_parse_2586/quarter_*`)
- build API / MVC **0 Error**, `node --check` ผ่าน
- รายการภาค 01 Q1: 332 บรรทัดงบ (มีแผน 78) 39 ศูนย์ 13 วิ; ภาค 05 ใบภาค 99 ได้; ไตรมาส 5 → "ไตรมาสต้องเป็น 1–4"; ใบ 42 → สถานะร่างเท่านั้น
- export 2 รายการ (2186, 2216/21300) ภาค 01 Q1: 200, 78 แถว (2 × 39), คอลัมน์ T รวม 5,216,580 / 927,000 ตรงกับรายการ; ภาค 99 × 20 รายการ → "ได้ 7,820 แถว … เกิน 3,000"
- กรอกยอด = แผน (ที่ไม่มีแผนกรอก 0) แล้ว parse: success 2 บรรทัดงบ / 43 ศูนย์ (35 + 8 = ศูนย์ที่มีแผน) ยอด 5,216,580 / 927,000, W03 2 ข้อ, W01 (บรรทัด 2186 รหัสงบ 0000 คงเหลือ −120,000 จริง); เว้นว่าง 1 แถว → C02
- พบระหว่างทดสอบ: ใบ 2586 มีรายการจาก `sample_source100_2586.xlsx` ถูกบันทึกแล้ว 13:35 (CATEGORY 5055–5064, จำนวน receive/note ตรงกับไฟล์ทุกบรรทัด) → ไฟล์ทดสอบเดิม (V1/E1/E2) ตอนนี้ติด R05 เพิ่ม; ตาราง IMPORT_EXCEL ยังว่างเพราะบันทึกนั้นใช้โค้ดก่อนเพิ่มการเก็บไฟล์
