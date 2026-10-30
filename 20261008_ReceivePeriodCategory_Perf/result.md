# BudgetPaymentGfItemDetail spins until it returns 500 — OAGWBG_FN_GETBUDGET_RECEIVE_PERIOD_CATEGORY is slow

Date: 2026-10-08 · Investigated on PREPROD (172.16.11.19 / ebs_PRE) · **Not yet deployed**

## Symptom

Opening BudgetPaymentGfDetail → BudgetPaymentGfItemDetail spins for a long time, then returns 500.

- The API `GetBudgetPaymentGfItemDetail` (`OAGBudget.API\Services\Repository\BudgetService.cs`) calls
  `OAGWBG_FN_GETBUDGET_RECEIVE_PERIOD_CATEGORY(id)`
- The frontend waits with an `HttpClient` that has the default 100-second timeout. The function takes ~8 minutes, so the request is cut off and becomes a 500.

## Measurements (ID 52, year 2569, 61 rows)

| How it was run | Time |
|---|---|
| `SELECT * FROM TABLE(fn(52))` (2 runs) | **480 s / 483 s** |
| The function's SQL as a plain query (literals / binds) | 2.7–2.8 s |
| PL/SQL block, text identical to the function (shares its cached cursor) | **490 s** |
| PL/SQL block, with only one inert `QB_NAME` hint added (fresh parse) | 2.7 s |

→ The SQL itself is fine, but the plan cached in the shared pool is bad. A small year (ID 53, year 2571) takes 2.4 s, so pages with little data look normal.

## Which part is slow

Each CTE run on its own (normal plan): BA_SUM 0.6 s, **BDPI 1.1 s**, CAT_BASE/RCV_* ~0.5 s, **CAL 1.3 s**, GG 1.7 s, CC 1.6 s, up to BP 2.5 s, everything 2.7 s.

The bad plan **runs BDPI (`OAGWBG_V_BUDGETDISBURSEMENTPLANITEMPIVOT`) once per row** of BUDGETGOVERNMENT inside CAL (nested loop + push predicate):

- Forcing that plan shape with `LEADING(BG) USE_NL(BDPI) PUSH_PRED(BDPI)` makes **CAL alone take 238 s**
- CAL is used twice (GG and CC) → ~476 s, which matches the 480 s measured

Why BDPI is expensive per call:
- It scans `OAGWBG_BUDGETDISBURSEMENTPLANITEM` (280,499 rows), joins BUDGETGOVERNMENT, aggregates BUDGETGOVERNMENT twice more (BG5_SUM/BG6_SUM), then window functions + PIVOT
- Filtering on a single category takes 2.0 s, slower than a full read (0.7 s)
- `PRODUCT_ID`/`ACTIVITY_ID` are `TO_CHAR` (VARCHAR2) but are joined to NUMBER → implicit conversion

Things that make the plan unstable: BUDGETRECEIVEPERIOD, BUDGETRECEIVEPERIODCATEGORY, BUDGETCODE_YEAR and BUDGETDISBURSEMENTPLANRECEIVE have no statistics; BUDGETGOVERNMENT's are stale (2025-12-08). The plan therefore depends on dynamic sampling at the moment of parse.
Parsing first with a small year (2571) and then reusing the cursor for 2569 **did not** bring the bad plan back, so this is not ordinary bind peeking.

Other waste: BA_SUM, RCV_BASE and SUM_RCV compute every year although only `v_budgetyear` is used; BA_SUM has a useless ORDER BY.

## Fix (`deploy_fn_receive_period_category_perf.sql`)

1. BDPI: `/*+ MATERIALIZE */` + `WHERE BDPI.BUDGETYEAR = v_budgetyear`
2. CAL: `/*+ MATERIALIZE */`
3. BA_SUM: filter by year, drop ORDER BY
4. RCV_BASE: `AND BRP.BUDGETYEAR = v_budgetyear`
5. SUM_RCV: `WHERE BUDGETYEAR = v_budgetyear`

Verification (PREPROD, query run directly, not yet deployed):
- **Identical results on all 42/42 IDs**: COUNT + SUM(ORA_HASH(every column)) match exactly
- In a PL/SQL loop with binds (same as the real function): 2.7 s
- The plan shows `TEMP TABLE TRANSFORMATION` → materialized as intended
- ⚠️ With the bad-plan hints forced in deliberately: 56 s (original: 480 s). Under the 100-second timeout but not 100% immune; where the 56 s comes from has not been traced yet

Deploying a new function also forces a fresh parse, so the bad plan currently cached disappears as well.

## Not done yet / needs a decision

- [ ] Deploy to PREPROD → run `verify_after_deploy.sql`
- [ ] PROD: not checked yet (no permission to read PROD in that session). Pull the PROD DDL and diff against `rollback_*.sql` before deploying
- [ ] Gather stats on the tables with no stats (affects every query using these tables, so try PREPROD first)
- [ ] Longer term: make the BDPI view lighter (affects every place that uses the view, so treat it as separate work)
- Side note: `OAGBudget.API\appsettings.Development.json` currently points to **PROD**

## Files

| File | Purpose |
|---|---|
| `deploy_fn_receive_period_category_perf.sql` | CREATE OR REPLACE of the fixed function |
| `rollback_fn_receive_period_category_perf.sql` | Original DDL from PREPROD (2026-09-29) |
| `verify_after_deploy.sql` | Check status, timing, and row count per ID against the baseline |
