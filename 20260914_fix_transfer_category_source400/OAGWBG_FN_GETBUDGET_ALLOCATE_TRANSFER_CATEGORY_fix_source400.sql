CREATE OR REPLACE FUNCTION OAGWBG.OAGWBG_FN_GETBUDGET_ALLOCATE_TRANSFER_CATEGORY (
  p_BudgetYear     IN NUMBER,
  p_BudgetFormType IN NUMBER,
  p_BudgetSource   IN NUMBER DEFAULT NULL
)
RETURN OAGWBG.TABLE_BUDGETTRANSFER_CATEGORY PIPELINED
AS
BEGIN
  FOR R IN (
    /* ===== OPTIMIZE 2026-08-17 : บังคับให้ 3 บล็อกหนักคำนวณครั้งเดียวลง temp table =====
       เดิม OUTER APPLY (lateral) ทำให้ optimizer เลือก nested-loop แล้วประเมิน BRC/BATC ซ้ำต่อแถว
       -> 33 วินาที.  ย้ายเป็น CTE + MATERIALIZE -> ~1.2 วินาที
       *** logic / predicate / GROUP BY ทุกบรรทัดคงเดิมทั้งหมด ไม่มีการแก้เงื่อนไขใดๆ *** */
    WITH EAR_CACHE AS (
      SELECT /*+ MATERIALIZE */ * FROM OAGWBG.OAGWBG_V_EXT_OAGPO_EXPENSE_ACCOUNT_RULE_V
    ),
    BRC AS ( SELECT /*+ MATERIALIZE */ * FROM (
        /* --- แก้ไขจุดที่ 7: เพิ่ม ROW_NUMBER() เพื่อตรวจสอบ TRANSFERNO ไม่ให้ซ้ำ
               เฉพาะกรณี BUDGETSOURCEID = 400 (แหล่งงบอื่นจะได้ RN_TRANSFERNO = 1 เสมอ ไม่ถูกกรอง) --- */
        SELECT
            BRC_BASE.*,
            CASE
                WHEN BRC_BASE.BUDGETSOURCEID = 400 THEN
                    ROW_NUMBER() OVER (
                        PARTITION BY BRC_BASE.TRANSFERNO
                        ORDER BY BRC_BASE.BUDGETYEAR DESC, BRC_BASE.REF DESC
                    )
                ELSE 1
            END AS RN_TRANSFERNO
        FROM (
                SELECT
                        ob.BUDGETYEAR,
                        BCP.BUDGETPLAN_ID AS BUDGETPLANID,
                        BCP.NAME          AS BUDGETPLANNAME,
                        BCC.BUDGETTYPEID,
                        ob.CATEGORYID,
                        ob.PRODUCTID,
                        ob.ACTIVITYID,
                        ob.BUDGETSOURCEID,
                        COALESCE(BRSC.BUDGETCODEID,
                        obc.BUDGETCODEID,BRRF.BUDGETCODEID,
                        CASE
                                WHEN BRP.PERIOD_TYPE = '1' THEN BCY.BUDGETCODEID
                                ELSE BCMY.BUDGETCODEID
                        END
                        ,'00000000000000000000') AS BUDGETCODEID,
                        ob.BUDGETRESERVEDID AS  BUDGETRESERVED,
                        obc.ID AS REF,
                        BRS.TRANSFERNO,
                        ob.DEPARTMENTID,
                        ob.COSTCENTERID
                FROM OAGWBG.OAGWBG_BUDGETRECEIVE ob
                LEFT JOIN OAGWBG_BUDGETALLOCATETRANSFER_CATEGORY obc 
                        ON ob.BUDGETALLOCATETRANSFERCATEGORYID = obc.ID 
                LEFT JOIN OAGWBG.OAGWBG_BUDGETCODE_YEAR BCY
                        ON BCY.PRODUCTID = ob.PRODUCTID 
                        AND BCY.ACTIVITYCODEID  = ob.ACTIVITYID 
                        AND BCY.CATEGORYID = ob.CATEGORYID 
                LEFT JOIN OAGWBG_BUDGETCODEMORE_YEAR BCMY
                        ON BCMY.PRODUCTID = ob.PRODUCTID
                        AND BCMY.ACTIVITYCODEID = ob.ACTIVITYID
                        AND BCMY.CATEGORYID = ob.CATEGORYID
                        AND BCMY.BUDGETYEAR = ob.BUDGETYEAR
                        AND BCMY.BUDGETSOURCEID = ob.BUDGETSOURCEID
                LEFT JOIN OAGWBG_BUDGETRECEIVEPERIODCATEGORY BCC 
                        ON BCC.BUDGETRECEIVEPERIODID = ob.BUDGETRECEIVEPERIODID 
                        AND BCC.CATEGORYID = ob.CATEGORYID 
                        AND BCC.ACTIVITYID = ob.ACTIVITYID 
                        AND BCC.PRODUCTID = ob.PRODUCTID 
                LEFT JOIN OAGWBG.OAGWBG_V_EXT_OAGGL_BUDGET_CATEGORY_PLAN BCP
                    ON BCP.BUDGETPLAN_ID = ob.BUDGETPLANID
                LEFT JOIN OAGWBG.OAGWBG_BUDGETGOVERNMENT BG
                        ON BG.ID = BCC.BUDGETGOVERNMENTID
                LEFT JOIN OAGWBG.OAGWBG_BUDGETRECEIVEPERIOD BRP
                        ON BRP.ID = ob.BUDGETRECEIVEPERIODID
                LEFT JOIN OAGWBG.OAGWBG_BUDGETRESERVED BRS
                                                ON BRS.ID = ob.BUDGETRESERVEDID
                LEFT JOIN OAGWBG.OAGWBG_BUDGETRESERVED_CATEGORY BRSC
                        ON BRS.ID = BRSC.BUDGETRESERVEDID
                       AND ob.CATEGORYID = BRSC.CATEGORYID
                       AND ob.PRODUCTID = BRSC.PRODUCTID
                       AND ob.ACTIVITYID = BRSC.ACTIVITYID
                LEFT JOIN OAGWBG_BUDGETRECEIVEREFUND BRRF 
                	  ON BRRF.RECEIVEID = ob.ID
               WHERE (p_BudgetSource = 400 OR ob.BUDGETSOURCEID = 400  OR ob.BUDGETYEAR = p_BudgetYear )
                        AND (
                (
                    p_BudgetSource IS NULL
                    AND (
				        /* --- FIX 2026-09-14 : เงิน 400 ต้องใช้เงื่อนไขชุดเดียวกับตอนเรียก p_BudgetSource = 400 ---
				           เดิม: ob.BUDGETSOURCEID = 400 (ดึงมาหมด) ทำให้ได้แถวเงิน 400 ที่ไม่ใช่ RECEIVETYPE='O'
				           และแถวที่ไม่มี BUDGETRESERVEDID (TRANSFERNO = NULL) ติดมาด้วย ส่งผลให้
				             1. ROW_NUMBER() PARTITION BY TRANSFERNO ยุบแถว TRANSFERNO=NULL เหลือแถวเดียว
				             2. BATC แถว TRANSFERNO=NULL ไป join ซ้ำกับทุกแถว BRC → ยอดเงินบวกซ้ำ
				           จึงทำให้ผลลัพธ์ของเงิน 400 ไม่ตรงกับตอนส่ง p_BudgetSource = 400 */
				        -- เคสที่ 1: เงิน 400
				        (
				            ob.BUDGETSOURCEID = 400
				            AND ob.BUDGETRECEIVETYPE = 'O'
				            AND ob.BUDGETRESERVEDID IS NOT NULL
				        )
				        OR
				        -- เคสที่ 2: เงื่อนไขเดิม (เช็กคลัง, แผนก, สถานะ) — เฉพาะแหล่งงบที่ไม่ใช่ 400
				        (
				            (ob.BUDGETSOURCEID IS NULL OR ob.BUDGETSOURCEID <> 400)
				            AND (
				                ob.BUDGETRESERVEDID IS NOT NULL AND ob.BUDGETYEAR = p_BudgetYear
				                OR (
				                    ob.DEPARTMENTID = '2900600000'
				                    AND ob.COSTCENTERID = '2906999999'
				                    AND (BG.BUDGETSTATUS = 'C' OR (BG.BUDGETSTATUS IS NULL AND ob.BUDGETRECEIVETYPE = 'G'))
				                )
				            )
				        )
				    )
                )
                OR (
                    p_BudgetSource = 100 AND ob.BUDGETYEAR = p_BudgetYear
                    AND ob.BUDGETSOURCEID = p_BudgetSource
                    AND (
                        ob.BUDGETRESERVEDID IS NOT NULL
                        OR (
                            ob.DEPARTMENTID = '2900600000'
                            AND ob.COSTCENTERID = '2906999999'
                        )
                            AND ( BG.BUDGETSTATUS = 'C' OR (BG.BUDGETSTATUS IS NULL AND ob.BUDGETRECEIVETYPE = 'G'))
                    )
                )
                OR (
                    p_BudgetSource = 200 AND ob.BUDGETYEAR = p_BudgetYear
                    AND ob.BUDGETSOURCEID = p_BudgetSource
                    --AND BRS.TRANSFERNO IS NOT NULL
                )
                OR (
                    p_BudgetSource = 300 AND ob.BUDGETYEAR = p_BudgetYear
                    AND ob.BUDGETSOURCEID = p_BudgetSource
                    AND (
                        ob.BUDGETRESERVEDID IS NOT NULL
                        OR (
                            ob.DEPARTMENTID = '2900600000'
                            AND ob.COSTCENTERID = '2906999999'
                        )
                            AND ( BG.BUDGETSTATUS = 'C' OR (BG.BUDGETSTATUS IS NULL AND ob.BUDGETRECEIVETYPE = 'G'))
                    )
                )
                OR (
                    p_BudgetSource = 400
                    AND ob.BUDGETSOURCEID = p_BudgetSource
                    AND ob.BUDGETRECEIVETYPE = 'O'
                    AND ob.BUDGETRESERVEDID IS NOT NULL
                )
            )
                GROUP BY
                    ob.BUDGETYEAR, BCP.BUDGETPLAN_ID, BCP.NAME, ob.BUDGETSOURCEID,
                    BCC.BUDGETTYPEID, ob.CATEGORYID, ob.PRODUCTID, ob.ACTIVITYID, 
                    COALESCE(BRSC.BUDGETCODEID,
                        obc.BUDGETCODEID,BRRF.BUDGETCODEID,
                        CASE
                                WHEN BRP.PERIOD_TYPE = '1' THEN BCY.BUDGETCODEID
                                ELSE BCMY.BUDGETCODEID
                        END
                        ,'00000000000000000000'),ob.BUDGETRESERVEDID ,obc.ID,BRS.TRANSFERNO,ob.DEPARTMENTID, ob.COSTCENTERID
        ) BRC_BASE
    ) ),
    BATC AS ( SELECT /*+ MATERIALIZE */ * FROM (
                SELECT
                        ob.BUDGETYEAR, 
                        ob.CATEGORYID, 
                        ob.BUDGETSOURCEID,
                        ob.BUDGETPLANID, 
                        ob.PRODUCTID, 
                        ob.ACTIVITYID,
                        /* ปรับ COALESCE ของ BATC ให้ดึง BRSC.BUDGETCODEID มาเช็คเหมือนฝั่งหลัก */
                        COALESCE(BRSC.BUDGETCODEID,
                        obc.BUDGETCODEID,BRRF.BUDGETCODEID,
                        CASE
                                WHEN BRP.PERIOD_TYPE = '1' THEN BCY.BUDGETCODEID
                                ELSE BCMY.BUDGETCODEID
                        END
                        ,'00000000000000000000') AS BUDGETCODEID,
                        SUM(NVL(ob.TOTALTRANSFERAMOUNT, 0)) AS TOTALTRANSFERAMOUNT,
                        SUM(NVL(ob.TOTALALLOCATEAMOUNT, 0)) AS TOTALRECEIVEAMOUNT,
                        SUM(NVL(ob.TOTALBALANCEAMOUNT, 0)) AS TOTALBALANCEAMOUNT,
                        BRS.TRANSFERNO AS TRANSFERNO
                FROM OAGWBG.OAGWBG_BUDGETRECEIVE ob
                LEFT JOIN OAGWBG_BUDGETALLOCATETRANSFER_CATEGORY obc 
                        ON ob.BUDGETALLOCATETRANSFERCATEGORYID = obc.ID 
                LEFT JOIN OAGWBG.OAGWBG_BUDGETCODE_YEAR BCY
                        ON BCY.PRODUCTID = ob.PRODUCTID 
                        AND BCY.ACTIVITYCODEID = ob.ACTIVITYID 
                        AND BCY.CATEGORYID = ob.CATEGORYID 
                LEFT JOIN OAGWBG_BUDGETRECEIVEPERIODCATEGORY BCC 
                        ON BCC.BUDGETRECEIVEPERIODID = ob.BUDGETRECEIVEPERIODID 
                        AND BCC.CATEGORYID = ob.CATEGORYID 
                        AND BCC.ACTIVITYID = ob.ACTIVITYID 
                        AND BCC.PRODUCTID = ob.PRODUCTID 
                LEFT JOIN OAGWBG.OAGWBG_BUDGETCODEMORE_YEAR BCMY
                        ON BCMY.PRODUCTID = ob.PRODUCTID
                        AND BCMY.ACTIVITYCODEID = ob.ACTIVITYID
                        AND BCMY.CATEGORYID = ob.CATEGORYID
                        AND BCMY.BUDGETYEAR = ob.BUDGETYEAR
                        AND BCMY.BUDGETSOURCEID = ob.BUDGETSOURCEID
                        AND BCMY.BUDGETGOVERNMENTID = BCC.BUDGETGOVERNMENTID
                LEFT JOIN OAGWBG.OAGWBG_BUDGETGOVERNMENT BG
                        ON BG.ID = BCC.BUDGETGOVERNMENTID
                LEFT JOIN OAGWBG.OAGWBG_BUDGETRECEIVEPERIOD BRP
                        ON BRP.ID = ob.BUDGETRECEIVEPERIODID
                /* Join BRS และ BRSC เข้ามาในฝั่ง BATC เพื่อให้ดึงข้อมูลชุดเดียวกันมาจับคู่ */
                LEFT JOIN OAGWBG.OAGWBG_BUDGETRESERVED BRS
                        ON BRS.ID = ob.BUDGETRESERVEDID
                LEFT JOIN OAGWBG.OAGWBG_BUDGETRESERVED_CATEGORY BRSC
                        ON BRS.ID = BRSC.BUDGETRESERVEDID
                       AND ob.CATEGORYID = BRSC.CATEGORYID
                       AND ob.PRODUCTID = BRSC.PRODUCTID
                       AND ob.ACTIVITYID = BRSC.ACTIVITYID
                LEFT JOIN OAGWBG_BUDGETRECEIVEREFUND BRRF 
                	  ON BRRF.RECEIVEID = ob.ID
                /* เปลี่ยนมาใช้เงื่อนไข WHERE แบบไดนามิกตาม p_BudgetSource เหมือนฝั่ง BRC */
                WHERE (p_BudgetSource = 400 OR ob.BUDGETSOURCEID = 400 OR ob.BUDGETYEAR = p_BudgetYear  )
                        AND (
                        (
                            p_BudgetSource IS NULL
                            AND (
						        /* --- FIX 2026-09-14 : ต้องตรงกับฝั่ง BRC (ดูคำอธิบายด้านบน) --- */
						        -- เคสที่ 1: เงิน 400
						        (
						            ob.BUDGETSOURCEID = 400
						            AND ob.BUDGETRECEIVETYPE = 'O'
						            AND ob.BUDGETRESERVEDID IS NOT NULL
						        )
						        OR
						        -- เคสที่ 2: เงื่อนไขเดิม (เช็กคลัง, แผนก, สถานะ) — เฉพาะแหล่งงบที่ไม่ใช่ 400
						        (
						            (ob.BUDGETSOURCEID IS NULL OR ob.BUDGETSOURCEID <> 400)
						            AND (
						                ob.BUDGETRESERVEDID IS NOT NULL AND ob.BUDGETYEAR = p_BudgetYear
						                OR (
						                    ob.DEPARTMENTID = '2900600000'
						                    AND ob.COSTCENTERID = '2906999999'
						                    AND (BG.BUDGETSTATUS = 'C' OR (BG.BUDGETSTATUS IS NULL AND ob.BUDGETRECEIVETYPE = 'G'))
						                )
						            )
						        )
						    )
                        )
                        OR (
                            p_BudgetSource = 100 AND ob.BUDGETYEAR = p_BudgetYear
                            AND ob.BUDGETSOURCEID = p_BudgetSource
                            AND (
                                ob.BUDGETRESERVEDID IS NOT NULL
                                OR (
                                    ob.DEPARTMENTID = '2900600000'
                                    AND ob.COSTCENTERID = '2906999999'
                                )
                                AND ( BG.BUDGETSTATUS = 'C' OR (BG.BUDGETSTATUS IS NULL AND ob.BUDGETRECEIVETYPE = 'G'))
                            )
                        )
                        OR (
                            p_BudgetSource = 200 AND ob.BUDGETYEAR = p_BudgetYear
                            AND ob.BUDGETSOURCEID = p_BudgetSource
                            --AND BRS.TRANSFERNO IS NOT NULL
                        )
                        OR (
                            p_BudgetSource = 300 AND ob.BUDGETYEAR = p_BudgetYear
                            AND ob.BUDGETSOURCEID = p_BudgetSource
                            AND (
                                ob.BUDGETRESERVEDID IS NOT NULL
                                OR (
                                    ob.DEPARTMENTID = '2900600000'
                                    AND ob.COSTCENTERID = '2906999999'
                                )
                                AND ( BG.BUDGETSTATUS = 'C' OR (BG.BUDGETSTATUS IS NULL AND ob.BUDGETRECEIVETYPE = 'G'))
                            )
                        )
                        OR (
                            p_BudgetSource = 400
                            AND ob.BUDGETSOURCEID = p_BudgetSource
                            AND ob.BUDGETRECEIVETYPE = 'O'
                            AND ob.BUDGETRESERVEDID IS NOT NULL
                        )
                    )
                GROUP BY ob.CATEGORYID, ob.BUDGETYEAR, ob.BUDGETPLANID, ob.PRODUCTID, ob.ACTIVITYID, ob.BUDGETSOURCEID, BRS.TRANSFERNO,
                        COALESCE(BRSC.BUDGETCODEID,
                        obc.BUDGETCODEID,BRRF.BUDGETCODEID,
                        CASE
                                WHEN BRP.PERIOD_TYPE = '1' THEN BCY.BUDGETCODEID
                                ELSE BCMY.BUDGETCODEID
                        END
                        ,'00000000000000000000') 
    ) )
    SELECT
      BRC.BUDGETYEAR,
      BRC.BUDGETSOURCEID, /* --- แก้ไขจุดที่ 1: เปลี่ยนจาก BATC เป็น BRC --- */
      BRC.BUDGETPLANID,
      BRC.BUDGETPLANNAME,
      BRC.BUDGETTYPEID,
      BRC.CATEGORYID,
      CC.CODE,
      CC.NAME AS CATEGORYNAME,
      NVL(BRC.PRODUCTID, '')     AS PRODUCTID,
      NVL(BP.FV_DESCRIPTION, '') AS PRODUCTNAME,
      NVL(BRC.ACTIVITYID, '')    AS ACTIVITYID,
      NVL(BA.FV_DESCRIPTION, '') AS ACTIVITYNAME,
      NVL(SUM(BATC.TOTALRECEIVEAMOUNT), 0)   AS TOTALALLOCATEAMOUNT,
      NVL(SUM(BATC.TOTALBALANCEAMOUNT), 0)   AS TOTALBALANCEAMOUNT,
      NVL(SUM(BATC.TOTALRECEIVEAMOUNT), 0)   AS TOTALRECEIVEAMOUNT,
      NVL(SUM(BATC.TOTALTRANSFERAMOUNT), 0)  AS TOTALTRANSFERAMOUNT,
      (
        '2900600000.2906999999.' || SUBSTR(TO_CHAR(BRC.BUDGETYEAR), -2) || '.' || NVL(BRC.BUDGETSOURCEID, '100') || '.' ||
        BRC.BUDGETPLANID || '.' || NVL(BRC.PRODUCTID,'') || '.' || NVL(BRC.ACTIVITYID,'') || '.' ||
        NVL(eoearv.BUDGETTYPEID,'') || '.' || NVL(BRC.BUDGETCODEID, eoearv.BUDGETCODE) || '.' ||
        NVL(eoearv.ACCOUNTNO,'') || '.' || NVL(eoearv.SUBACCOUNTNO,'') || '.00.000'
      ) AS ACCOUNTCODE, /* --- แก้ไขจุดที่ 2: ใช้ BRC.BUDGETSOURCEID ในการเจน ACCOUNTCODE --- */
      NVL(ah.SUMMARY_ACCOUNT_CODE, 
        '2900600000.2906999999.' || SUBSTR(TO_CHAR(BRC.BUDGETYEAR), -2) || '.' || NVL(BRC.BUDGETSOURCEID, '100') || '.' ||
        BRC.BUDGETPLANID || '.' || NVL(BRC.PRODUCTID,'') || '.' || NVL(BRC.ACTIVITYID,'') || '.' ||
        NVL(eoearv.BUDGETTYPEID,'') || '.' || NVL(BRC.BUDGETCODEID, eoearv.BUDGETCODE) || '.' ||
        NVL(eoearv.ACCOUNTNO,'') || '.' || NVL(eoearv.SUBACCOUNTNO,'') || '.00.000'
      ) AS SUMMARYACCOUNTCODE, /* --- แก้ไขจุดที่ 3: ใช้ BRC.BUDGETSOURCEID ในการเจน SUMMARYACCOUNTCODE --- */
      NVL(ah.TEMPLATE_ID, 0)   AS TEMPLATEID,
      SUBSTR(ah.TEMPLATE_NAME, 5) AS TEMPLATENAME,
      BRC.BUDGETRESERVED,
      BRC.REF,
      BRC.TRANSFERNO,
      BRC.COSTCENTERID,
      BRC.DEPARTMENTID
    FROM BRC
    LEFT JOIN OAGWBG.OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V CC
      ON CC.ID = BRC.CATEGORYID
    LEFT JOIN APPS.OAGGL_BUDGET_PRODUCT_V BP
      ON BP.FLEX_VALUE     = BRC.PRODUCTID
     AND BP.DEP_FLEX_VALUE = BRC.BUDGETPLANID
    LEFT JOIN APPS.OAGGL_BUDGET_ACTIVITY_V BA
      ON BA.FLEX_VALUE     = BRC.ACTIVITYID
     AND BA.DEP_FLEX_VALUE = BRC.BUDGETPLANID
    OUTER APPLY (
            SELECT *
            FROM EAR_CACHE EAR
            WHERE EAR.CATEGORYID = BRC.CATEGORYID
            ORDER BY 
                CASE 
                    WHEN EAR.BUDGETYEAR = MOD(BRC.BUDGETYEAR,100)
                     AND EAR.PRODUCTID = BRC.PRODUCTID
                     AND EAR.ACTIVITYCODEID = BRC.ACTIVITYID
                    THEN 1
                    ELSE 2
                END
            FETCH FIRST 1 ROW ONLY
        ) eoearv
    LEFT JOIN BATC
      ON BATC.CATEGORYID   = BRC.CATEGORYID
     AND BATC.BUDGETPLANID = BRC.BUDGETPLANID
     AND BATC.PRODUCTID    = BRC.PRODUCTID
     AND BATC.ACTIVITYID   = BRC.ACTIVITYID
     AND BATC.BUDGETSOURCEID = BRC.BUDGETSOURCEID
     AND (BATC.TRANSFERNO = BRC.TRANSFERNO OR BATC.TRANSFERNO IS NULL)
     AND ( BATC.BUDGETCODEID IS NULL OR ( BATC.BUDGETCODEID IS NOT NULL AND BRC.BUDGETCODEID IS NOT NULL AND BATC.BUDGETCODEID = BRC.BUDGETCODEID ))
    LEFT JOIN OAGWBG.OAGWBG_V_EXT_OAGGL_ACCOUNT_HIERACHIES_V ah
      ON ah.ACCOUNT_CODE =
        '2900600000.2906999999.' || SUBSTR(TO_CHAR(BRC.BUDGETYEAR), -2) || '.' || NVL(BRC.BUDGETSOURCEID, '100') || '.' ||
        BRC.BUDGETPLANID || '.' || NVL(BRC.PRODUCTID,'') || '.' || NVL(BRC.ACTIVITYID,'') || '.' ||
        NVL(eoearv.BUDGETTYPEID,'') || '.' || NVL(BRC.BUDGETCODEID, eoearv.BUDGETCODE) || '.' ||
        NVL(eoearv.ACCOUNTNO,'') || '.' || NVL(eoearv.SUBACCOUNTNO,'') || '.00.000'
    WHERE (p_BudgetSource = 400 OR  BRC.BUDGETSOURCEID = 400 OR  BRC.BUDGETYEAR = p_BudgetYear)
      AND BRC.RN_TRANSFERNO = 1 /* --- แก้ไขจุดที่ 8: กรองให้เหลือ TRANSFERNO ไม่ซ้ำ เฉพาะ BUDGETSOURCEID = 400 --- */
    GROUP BY
      BRC.BUDGETYEAR,
      BRC.BUDGETSOURCEID, /* --- แก้ไขจุดที่ 5: เปลี่ยนจาก BATC เป็น BRC ใน GROUP BY ชุดนอก --- */
      BRC.BUDGETPLANID,
      BRC.BUDGETPLANNAME,
      BRC.BUDGETTYPEID,
      BRC.CATEGORYID,
      CC.NAME,
      CC.CODE,
      BRC.PRODUCTID,
      BRC.ACTIVITYID,
      BP.FV_DESCRIPTION,
      BA.FV_DESCRIPTION,
      (
        '2900600000.2906999999.' || SUBSTR(TO_CHAR(BRC.BUDGETYEAR), -2) || '.' || NVL(BRC.BUDGETSOURCEID, '100') || '.' ||
        BRC.BUDGETPLANID || '.' || NVL(BRC.PRODUCTID,'') || '.' || NVL(BRC.ACTIVITYID,'') || '.' ||
        NVL(eoearv.BUDGETTYPEID,'') || '.' || NVL(BRC.BUDGETCODEID, eoearv.BUDGETCODE) || '.' ||
        NVL(eoearv.ACCOUNTNO,'') || '.' || NVL(eoearv.SUBACCOUNTNO,'') || '.00.000'
      ), /* --- แก้ไขจุดที่ 6: ใช้ BRC.BUDGETSOURCEID ใน GROUP BY ของ ACCOUNTCODE string --- */
      ah.SUMMARY_ACCOUNT_CODE,
      ah.TEMPLATE_ID, 
      SUBSTR(ah.TEMPLATE_NAME, 5),
      BRC.BUDGETRESERVED,
      BRC.REF,
      BRC.TRANSFERNO,
      BRC.COSTCENTERID,
      BRC.DEPARTMENTID
      ORDER BY CC.CODE
  ) LOOP
    PIPE ROW (
      OAGWBG.OBJ_BUDGETTRANSFER_CATEGORY(
        R.CODE,
        R.BUDGETYEAR,
        R.BUDGETSOURCEID,
        R.BUDGETPLANID,
        R.BUDGETPLANNAME,
        R.BUDGETTYPEID,
        R.CATEGORYID,
        R.CATEGORYNAME,
        R.PRODUCTID,
        R.PRODUCTNAME,
        R.ACTIVITYID,
        R.ACTIVITYNAME,
        R.TOTALALLOCATEAMOUNT,
        R.TOTALBALANCEAMOUNT,
        R.TOTALRECEIVEAMOUNT,
        R.TOTALTRANSFERAMOUNT,
        R.ACCOUNTCODE,
        R.SUMMARYACCOUNTCODE,
        R.TEMPLATEID,
        R.TEMPLATENAME,
        R.BUDGETRESERVED,
        R.REF,
        R.TRANSFERNO,
        R.COSTCENTERID,
        R.DEPARTMENTID 
      )
    );
  END LOOP;
  RETURN;
END;
/
