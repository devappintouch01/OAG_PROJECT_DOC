-- =============================================================================
-- OAGWBG_R_BUDGETALLOCATETRANSFERMORE
-- view รายงานของ "โอนจัดสรรเพิ่มเติม" — คอลัมน์ชุดเดียวกับ OAGWBG_R_BUDGETALLOCATETRANSFER ทุกตัว
-- เพื่อให้รายงาน 3 ตัวใช้ตรรกะเดิมได้:
--   1) รายงานการจัดสรรงบประมาณรายจ่ายประจำปีงบประมาณ
--   2) รายละเอียดการโอนเงินจัดสรรงบประมาณรายจ่ายประจำปี
--   3) รายงานโอนเงินจัดสรรงบประมาณรายจ่ายประจำปี
--
-- ปัญหา: ค้นหาเลขใบโอนของโอนจัดสรรเพิ่มเติม (เช่น 6912572) ในรายงานไม่เจอ
--        เพราะรายงานอ่านเฉพาะ OAGWBG_BUDGETALLOCATETRANSFER*
--
-- 1 แถว = 1 รายการโอนออก (ROWTYPE = 'O') ของใบโอนจัดสรรเพิ่มเติม
--   ยอดเงิน       = c.TOTALALLOCATEAMOUNT ของแถวโอนออก (ผลรวมเท่ากับ TOTALRECEIVEAMOUNT ของหัวใบ)
--   ผู้รับโอน      = แถวแม่ p (ROWTYPE = 'R', ผูกด้วย c.PARENTID) — ศูนย์ต้นทุน / รายการ / ผลผลิต / กิจกรรม
--                   ตรงกับแถว BUDGETRECEIVE "A" ที่ ReserveBudgetAllocateTransferMore สร้างให้ผู้รับ
--   แหล่งเงิน      = ของแถวโอนออก c (ตาม BUDGETRECEIVE "A")
--   บัญชีธนาคาร    = OAGWBG_BUDGETALLOCATETRANSFERMORE_COSTCENTER ตามคีย์ที่ GenerateCostCenterRowsFromCategory ใช้
--                   (ผู้รับ dept/cc + ผู้โอน dept/cc + แหล่งเงิน/แผนงาน/ประเภทค่าใช้จ่ายของแถวโอนออก)
--   แผนงาน        = CATC.PLANID ของรายการผู้รับ — p.BUDGETPLANID บางแถวเก็บเป็น id ของ config
--                   (3123/3124 ...) ซึ่งต่างกันแต่ละ environment จึงไม่ใช้ตรง ๆ
--   BUDGETALLOCATETRANSFERID = ID ของ OAGWBG_BUDGETALLOCATETRANSFERMORE (คงชื่อคอลัมน์ไว้ให้ตรง view เดิม)
--   ไม่มีแถวยอด 0 ของแถวแม่ (แบบ view เดิม) และไม่แสดงยอดคำขอของแถวแม่
-- =============================================================================
CREATE OR REPLACE FORCE EDITIONABLE VIEW "OAGWBG"."OAGWBG_R_BUDGETALLOCATETRANSFERMORE" ("BUDGETYEAR", "REGIONID", "REGIONNAME", "PLANID", "PLANNAME", "PRODUCTID", "PRODUCTNAME", "ACTIVITYID", "ACTIVITYNAME", "BOOKNO", "BOOKDATE", "ROUNDNO", "BANKACCOUNTNUMBERGIVER", "BANKACCOUNTNAMEGIVER", "TRANFEERDATE", "EXPENSETYPEID", "EXPENSETYPENAME", "BUDGET_TYPE_ID", "BUDGET_TYPE_NAME", "BUDGET_TYPE_CODE", "COSTCENTERID", "COSTCENTERNAME", "TOTALTRANSFERAMOUNT", "BANKACCOUNTNAME", "BANKACCOUNTNUMBER", "NOTE", "NOTE_SEQ", "BUDGETALLOCATETRANSFERID", "CODE", "CATEGORYNAME", "DEPARTMENTID", "DEPARTMENTNAME", "RECEIVENOTE", "BUDGETCODEID", "BUDGETSOURCEID", "BUDGETSOURCENAME", "BFR_YEAR", "CATEGORYID", "SUMMARYACCOUNTCODE") AS
SELECT
      h.BUDGETYEAR                              AS BUDGETYEAR,
      h.REGIONID                                AS REGIONID,
      VR.NAME                                   AS REGIONNAME,
      PLAN.ID                                   AS PLANID,
      PLAN.NAME                                 AS PLANNAME,
      p.PRODUCTID                               AS PRODUCTID,
      VEOBPV.NAME                               AS PRODUCTNAME,
      p.ACTIVITYID                              AS ACTIVITYID,
      VEOBAV.ACTIVITY_NAME                      AS ACTIVITYNAME,
      h.BOOKNO                                  AS BOOKNO,
      h.BOOKDATE                                AS BOOKDATE,
      h.ROUNDNO                                 AS ROUNDNO,
      EOBAVG.BANK_ACCOUNT_NUM                   AS BANKACCOUNTNUMBERGIVER,
      EOBAVG.BANK_ACCOUNT_NAME                  AS BANKACCOUNTNAMEGIVER,
      h.TRANSFERDATE                            AS TRANFEERDATE,
      CATC.EXPENSE_TYPE_ID                      AS EXPENSETYPEID,
      CATC.EXPENSE_TYPE_NAME                    AS EXPENSETYPENAME,
      CATC.BUDGET_TYPE_ID                       AS BUDGET_TYPE_ID,
      CATC.BUDGET_TYPE_NAME                     AS BUDGET_TYPE_NAME,
      CATC.BUDGET_TYPE_CODE                     AS BUDGET_TYPE_CODE,
      CC.ID                                     AS COSTCENTERID,
      CC.NAME                                   AS COSTCENTERNAME,
      NVL(c.TOTALALLOCATEAMOUNT, 0)             AS TOTALTRANSFERAMOUNT,
      EOBAV.BANK_ACCOUNT_NAME                   AS BANKACCOUNTNAME,
      EOBAV.BANK_ACCOUNT_NUM                    AS BANKACCOUNTNUMBER,
      NVL(BAC.NOTE, BAC2.NOTE)                  AS NOTE,
      1                                         AS NOTE_SEQ,
      h.ID                                      AS BUDGETALLOCATETRANSFERID,
      CATC.CODE                                 AS CODE,
      CATC.NAME                                 AS CATEGORYNAME,
      p.DEPARTMENTID                            AS DEPARTMENTID,
      CC.DEPARTMENTNAME                         AS DEPARTMENTNAME,
      NVL(BAC.NOTE, BAC2.NOTE)                  AS RECEIVENOTE,
      COALESCE(p.BUDGETCODEID, c.BUDGETCODEID)  AS BUDGETCODEID,
      c.BUDGETSOURCEID                          AS BUDGETSOURCEID,
      BSOURCE.NAME                              AS BUDGETSOURCENAME,
      p.BUDGETYEAR                              AS BFR_YEAR,
      p.CATEGORYID                              AS CATEGORYID,
      p.SUMMARYACCOUNTCODE                      AS SUMMARYACCOUNTCODE
  FROM OAGWBG_BUDGETALLOCATETRANSFERMORE h
  INNER JOIN OAGWBG_BUDGETALLOCATETRANSFERMORE_CATEGORY c
      ON  c.BUDGETALLOCATETRANSFERMOREID = h.ID
      AND c.ROWTYPE = 'O'
  INNER JOIN OAGWBG_BUDGETALLOCATETRANSFERMORE_CATEGORY p
      ON  p.ID = c.PARENTID
  -- รายการของผู้รับโอน (แถวแม่)
  LEFT JOIN OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V CATC
      ON  CATC.ID = p.CATEGORYID
  -- รายการของแถวโอนออก — ใช้หาประเภทค่าใช้จ่ายสำหรับผูกบัญชีธนาคาร
  LEFT JOIN OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V CATO
      ON  CATO.ID = c.CATEGORYID
  LEFT JOIN OAGWBG_V_EXT_OAGGL_BUDGET_PLAN_V PLAN
      ON  PLAN.ID = NVL(CATC.PLANID, p.BUDGETPLANID)
  LEFT JOIN OAGWBG_V_EXT_OAGGL_BUDGET_PRODUCT_V VEOBPV
      ON  VEOBPV.ID = p.PRODUCTID
      AND VEOBPV.BUDGETPLANCODE_ID = NVL(CATC.PLANID, p.BUDGETPLANID)
  LEFT JOIN OAGWBG_V_EXT_OAGGL_BUDGET_ACTIVITY_V VEOBAV
      ON  VEOBAV.ACTIVITY_ID = p.ACTIVITYID
      AND VEOBAV.PLAN_ID = NVL(CATC.PLANID, p.BUDGETPLANID)
  LEFT JOIN OAGWBG_BUDGETALLOCATETRANSFERMORE_COSTCENTER BAC
      ON  BAC.BUDGETALLOCATETRANSFERMOREID = h.ID
      AND BAC.DEPARTMENTID      = p.DEPARTMENTID
      AND BAC.COSTCENTERID      = p.COSTCENTERID
      AND BAC.GIVERDEPARTMENTID = c.DEPARTMENTID
      AND BAC.GIVERCOSTCENTERID = c.COSTCENTERID
      AND BAC.BUDGETSOURCEID    = c.BUDGETSOURCEID
      AND BAC.PLANID            = c.BUDGETPLANID
      -- รายการบางตัว (เช่น 31124) ไม่มีประเภทค่าใช้จ่าย ทั้งสองฝั่งเป็น NULL — ต้องเทียบแบบ NVL
      AND NVL(BAC.EXPENSETYPEID, '~') = NVL(CATO.EXPENSE_TYPE_ID, '~')
  -- สำรอง: ใบเก่าที่แถวศูนย์ต้นทุนถูกสร้างด้วยคีย์รูปแบบเดิม (PLANID = id ของ config, EXPENSETYPEID = BUDGETTYPEID)
  -- ใช้เมื่อหาแบบคีย์เต็มไม่เจอ และผู้รับ + ผู้โอน + แหล่งเงิน ตรงกันเพียงแถวเดียว (กันเลือกบัญชีผิดแถว)
  LEFT JOIN (
      SELECT B.*,
             COUNT(*) OVER (PARTITION BY B.BUDGETALLOCATETRANSFERMOREID, B.DEPARTMENTID, B.COSTCENTERID,
                                         B.GIVERDEPARTMENTID, B.GIVERCOSTCENTERID, B.BUDGETSOURCEID) AS CNT
        FROM OAGWBG_BUDGETALLOCATETRANSFERMORE_COSTCENTER B
  ) BAC2
      ON  BAC.ID IS NULL
      AND BAC2.CNT = 1
      AND BAC2.BUDGETALLOCATETRANSFERMOREID = h.ID
      AND BAC2.DEPARTMENTID      = p.DEPARTMENTID
      AND BAC2.COSTCENTERID      = p.COSTCENTERID
      AND BAC2.GIVERDEPARTMENTID = c.DEPARTMENTID
      AND BAC2.GIVERCOSTCENTERID = c.COSTCENTERID
      AND BAC2.BUDGETSOURCEID    = c.BUDGETSOURCEID
  LEFT JOIN OAGWBG_V_EXT_OAGGL_COST_CENTER_V CC
      ON  CC.ID = p.COSTCENTERID
  LEFT JOIN OAGWBG_V_EXT_OAGCE_BANK_ACCOUNT_V EOBAV
      ON  EOBAV.BANK_ACCOUNT_ID = NVL(BAC.BANKACCOUNTID, BAC2.BANKACCOUNTID)
  LEFT JOIN OAGWBG_V_EXT_OAGCE_BANK_ACCOUNT_V EOBAVG
      ON  EOBAVG.BANK_ACCOUNT_ID = NVL(BAC.BANKACCOUNTGIVERID, BAC2.BANKACCOUNTGIVERID)
  LEFT JOIN OAGWBG_V_REGION VR
      ON  VR.ID = h.REGIONID
  LEFT JOIN OAGWBG.OAGWBG_V_EXT_BUDGET_SOURCE_V BSOURCE
      ON  BSOURCE.ID = c.BUDGETSOURCEID
