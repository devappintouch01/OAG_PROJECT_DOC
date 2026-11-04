# เพิ่มรายการใหม่ในหน้าคำของบประมาณภาพรวม (formtype 1)

## แนวคิด
รายการในหน้าคำขอภาพรวม (BUDGETGOVERNMENT type '4') ต้องผูก REF กับ "แถวคำขอ" เสมอ
→ สร้าง **ใบคำขอส่วนกลาง** 1 ใบต่อปี ให้เป็นต้นทางของรายการใหม่ แล้วปล่อยให้ view / ปุ่มยืนยัน / หน้า พ.ร.บ. ทำงานตามเดิม

| ระดับ | ค่า |
|---|---|
| ใบคำขอ `OAGWBG_BUDGETREQUEST` | COSTCENTERID `2906999999` (สำนักงานอัยการสูงสุด - งบประมาณ), DEPARTMENTID `2900600000`, BUDGETTYPEID 1, BUDGETFORMTYPEID 1, STATUSID 20201, PARENTID NULL, TOTALREQUESTAMOUNT 0, **IS_SUMMARY_DUMMY_ITEM 1**, CODE/RUNNING ต่อจากใบจริง |
| แถวคำขอ `OAGWBG_BUDGETGOVERNMENT` | BUDGETREQUESTID = ใบส่วนกลาง, BUDGETSTATUS 'U', type NULL, TOTALREQUESTAMOUNT 0, Category/ผลผลิต/กิจกรรม/BUDGETPLANID/ประเภท จาก Category |
| แถวภาพรวม type '4' | REF_BUDGETGOVERNMENTID = แถวคำขอ, KEPTCENTRAL = ยอดที่กรอก |

## เงื่อนไขจาก view (DDL สด PREPROD 2026-10-16)
- `OAGWBG_V_BUDGETREQUESTSUMMARY`: BR.BUDGETTYPEID = 1, BG.BUDGETSTATUS NOT IN ('A','X'), type NULL/'7', ไม่มีใบลูก — ไม่กรอง BR.STATUSID
- `ConfirmBudgetRequestSummary`: ใบ STATUSID 20201 → แถว U → B
- `OAGWBG_V_BUDGETALLOCATEITEM` / `OAGWBG_V_BUDGETALLOCATELIST` (หน้า พ.ร.บ.): BG.BUDGETSTATUS IN ('B','C'[,'R'])
- ศูนย์ 2906999999 ยังไม่เคยมีคำขอ (BR 0 / BG 0)

## การตัดสินใจ (ผู้ใช้ 2026-10-16)
- ลบรายการใหม่ไม่ได้ / ใช้กับ formtype 1 เท่านั้น
- รายงานคำของบประมาณ (`R_BUDGETREQUEST`): **กรองใบส่วนกลางออก** แต่เขียนโค้ดแสดงไว้แล้ว comment ไว้ เผื่อเปิดใช้ภายหลัง
- เลขที่ใบใช้ Running ต่อจากใบจริง
- หลัง พ.ร.บ. โอนเงินจากศูนย์ 2906999999 ให้ศูนย์จริงด้วยหน้าโอนจัดสรรเดิม
- dropdown รายการงบประมาณใน modal แสดงทั้งรายการปกติและรายการ dummy (DUMMY_FLAG = YES "อื่นๆ โปรดระบุ") เพื่อไปเลือกรายการจริงที่หน้า พ.ร.บ. (ReqCategoryId)
  - ผู้ใช้เรียกว่า "summary flag Y/N" — ตรวจแล้ว SUMMARY_FLAG ใน EBS (MTL_CATEGORIES_B_KFV) เป็น N ทั้งหมด 785 รายการ ตัวที่แยกได้จริงคือ DUMMY_FLAG (16 รายการ)
  - ~~ช่องรายละเอียด (โปรดระบุ) สำหรับรายการ dummy~~ ผู้ใช้สั่งตัดออก (2026-10-16)
  - รายการ dummy **เพิ่มซ้ำได้หลายแถว** (ผู้ใช้ต้องการ) — หน้าภาพรวม/พ.ร.บ. แยกแถวละรายการ แยกกันด้วยช่อง "คำอธิบาย" หน้าภาพรวม
  - รายการปกติยังกันซ้ำ (Category + ผลผลิต + กิจกรรม + แผนงาน) เพราะ GetGroupBudgetSummaryPlan รวมเป็นแถวเดียวและบันทึกยอดลง type 4 ตัวแรกเท่านั้น
- ห้ามใช้ `AnyAsync` — EF Oracle 9.23 สร้าง `TRUE/FALSE` แบบ Oracle 23 แต่ DB 19c → ORA-00904 "FALSE" (เจอตอนทดสอบรายการที่ 2)

## ลำดับ deploy
1. `01_alter_OAGWBG_BUDGETREQUEST.sql`
2. `02_view_OAGWBG_V_BUDGETREQUEST.sql` (patch จาก DDL สดด้วย script: เพิ่ม IS_SUMMARY_DUMMY_ITEM 3 จุด)
3. `03_verify.sql` — เทียบ baseline
4. deploy API/MVC ที่ map คอลัมน์ใหม่ (ห้าม deploy ก่อนข้อ 1 → ORA-00904 ทุก query คำขอ)
- ALTER TABLE ทำให้ view ที่อ้างตารางนี้ INVALID ทันที (Oracle ปกติ) → หลังข้อ 2 ให้ `ALTER VIEW ... COMPILE` ทีละตัว แล้วรัน 03 ข้อ 3 ให้เหลือแค่ 3 ตัวที่ INVALID อยู่ก่อนแล้ว
- PROD: ต้องดึง DDL สดของ PROD แล้ว patch ใหม่ — PROD กับ PREPROD เป็นคนละเวอร์ชันได้

## บันทึก deploy
| วันที่ | DB | ขั้น | ผล |
|---|---|---|---|
| 2026-10-16 | PREPROD | 01 ALTER (ผู้ใช้รันเอง ชื่อ `IS_SUMMARY_DUMMY_ITEM`) | คอลัมน์ NUMBER(1) nullable — COMMENT ยังไม่ได้รัน |
| 2026-10-16 | PREPROD | 02 view (comment ภาษาไทย) | view 1345 แถว hash 2889347582920 เท่าก่อนแก้, IS_SUMMARY_DUMMY_ITEM เป็น NULL ทั้งหมด, BR 1370 แถว |
| 2026-10-16 | PREPROD | compile 10 view ที่ INVALID จาก ALTER | VALID ทั้งหมด — เหลือ INVALID 3 ตัวเดิม (FN_GETMOREBUDGET_RECEIVE_PERIOD_CATEGORY, R_BQMORE_EXP_TMP, R_BUDGETTRANSFERMORE_CONTROL) |
- ถอยกลับ: `99_rollback.sql`

## โค้ดที่แก้ (2026-10-16 — ยังไม่ checkin) ค้นด้วย `SUMMARY-NEW-ITEM`
| ไฟล์ | สิ่งที่แก้ |
|---|---|
| `OAGBudget.DAL/Models/OagwbgBudgetrequest.cs`, `OagwbgVBudgetrequest.cs`, `OAGDBContextBase.cs` | property `IsSummaryDummyItem` → `IS_SUMMARY_DUMMY_ITEM` |
| `OAGBudget.Models/Data/BudgetRequestSummaryFilter.cs` | `BudgetRequestSummaryNewItemModel` |
| `OAGBudget.API/Services/Repository/BudgetService.cs` | `CreateBudgetRequestSummaryItem` (transaction: ใบส่วนกลาง → แถวคำขอ U → type 4), `IsSummaryDummyRequestAsync`, guard 8 จุด, filter 4 จุด |
| `OAGBudget.API/Services/Repository/ReportService.cs` | `ReportBudgetRequest` ซ่อนศูนย์ 2906999999 (comment 2 บรรทัดออกเพื่อแสดง) |
| `OAGBudget.API/Controllers/BudgetController.cs` | `POST CreateBudgetRequestSummaryItem` |
| `OAGBudget/Services/Repository/BudgetService.cs`, `OAGBudget/Controllers/BudgetController.cs` | เรียก API + `ViewBag.DropdownPlanCode` |
| `OAGBudget/Views/Budget/BudgetRequestSummaryDetail.cshtml` | ปุ่ม + modal (แสดงเมื่อ formtype 1 และสถานะ U) |

## จุดที่ต้องกันใบส่วนกลาง (โค้ด)
- กรองออก: GetVBudgetRequestList, GetVRequestConsiderlist, GetDashboardCostCenterSummary, รายงาน R_BUDGETREQUEST (comment เปิดได้)
- ปฏิเสธ: ลบใบคำขอ, เปลี่ยนสถานะ/ส่งกลับแก้ไข, บันทึกรายละเอียดคำขอ
- ทดสอบเพิ่ม: หน้าแผนการใช้จ่าย (`V_BUDGETDISBURSEMENTPLAN*`) กับแถวที่ไม่มีแผนรายเดือน
