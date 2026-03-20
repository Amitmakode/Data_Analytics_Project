

-- =============================================================
-- PART C — DATA MODEL RELATIONSHIPS
-- =============================================================

After loading all tables in Power BI, go to:
Model View (left sidebar — the 3-box icon)

Set these relationships (drag & drop):

┌─────────────────────────────────────────────────────┐
│  TABLE A          KEY           TABLE B             │
│─────────────────────────────────────────────────────│
│  branches       branch_id    → customers            │
│  branches       branch_id    → accounts             │
│  branches       branch_id    → loans                │
│  branches       branch_id    → transactions         │
│  customers      customer_id  → accounts             │
│  customers      customer_id  → loans                │
│  accounts       account_id   → transactions         │
│  date_table     Date         → transactions         │
│                               (transaction_date)    │
└─────────────────────────────────────────────────────┘

Relationship Settings (for each):
   Cardinality    : Many to One (*:1)
   Cross filter   : Single
   Active         : ✅ Yes

IMPORTANT: Mark Date Table as official date table
   Right-click date_table → Mark as Date Table → Date column



-- =============================================================
-- PART D — QUICK SETTINGS BEFORE BUILDING VISUALS
-- =============================================================

1. Hide FK columns from report view (they clutter slicers):
   In Model view → right-click column → Hide in report view
   Hide: branch_id, customer_id, account_id (in child tables)

2. Set column categories for maps:
   customers[city]  → Data Category → City
   branches[city]   → Data Category → City

3. Format currency columns:
   Select column → Column tools → Format → Currency → ₹ Indian Rupee

4. Sort Month Name by Month Number:
   Select Month Name column → Column tools
   → Sort by Column → Month Number


---------------------------------------------------------------------------------------------------



-- =============================================================
--   🏦 BANKING ANALYTICS — Phase 4
--   DAX Measures + KPI Dashboard Layout
-- =============================================================
--   PART A → DAX Measures (copy into Power BI)
--   PART B → Dashboard Layout & Visual Guide
--   PART C → Auto-Refresh Setup
-- =============================================================


-- =============================================================
-- PART A — DAX MEASURES
-- =============================================================
-- In Power BI: Home → New Measure → paste each formula
-- Tip: Create a separate "Measures" table to keep things clean
--   Modeling → New Table → Measures = ROW("x",1)
--   Then add all measures inside this table
-- =============================================================


-- ─────────────────────────────────────────────────────────────
-- A1. CUSTOMER METRICS
-- ─────────────────────────────────────────────────────────────

/*
Total Customers =
COUNTROWS(customers)

Verified Customers =
CALCULATE(
    COUNTROWS(customers),
    customers[kyc_status] = "Verified"
)

KYC Verification Rate =
DIVIDE(
    [Verified Customers],
    [Total Customers],
    0
)

New Customers This Month =
CALCULATE(
    COUNTROWS(customers),
    DATESMTD(date_table[Date])
)

Avg Customer Age =
AVERAGE(customers[age])

Avg Credit Score =
AVERAGE(customers[credit_score])
*/


-- ─────────────────────────────────────────────────────────────
-- A2. ACCOUNT & DEPOSIT METRICS
-- ─────────────────────────────────────────────────────────────

/*
Total Active Accounts =
CALCULATE(
    COUNTROWS(accounts),
    accounts[status] = "Active"
)

Total Deposits =
CALCULATE(
    SUM(accounts[balance]),
    accounts[status] = "Active"
)

Avg Account Balance =
DIVIDE(
    [Total Deposits],
    [Total Active Accounts],
    0
)

Total Deposits LM =
CALCULATE(
    [Total Deposits],
    DATEADD(date_table[Date], -1, MONTH)
)

Deposit Growth MoM % =
DIVIDE(
    [Total Deposits] - [Total Deposits LM],
    [Total Deposits LM],
    0
) * 100
*/


-- ─────────────────────────────────────────────────────────────
-- A3. LOAN & NPA METRICS
-- ─────────────────────────────────────────────────────────────

/*
Total Loans Disbursed =
SUM(loans[principal_amount])

Total Outstanding =
SUM(loans[outstanding_amount])

Total Active Loans =
CALCULATE(
    COUNTROWS(loans),
    loans[loan_status] = "Active"
)

NPA Count =
CALCULATE(
    COUNTROWS(loans),
    loans[loan_status] = "NPA"
)

NPA Amount =
CALCULATE(
    SUM(loans[outstanding_amount]),
    loans[loan_status] = "NPA"
)

NPA Ratio % =
DIVIDE(
    [NPA Count],
    COUNTROWS(loans),
    0
) * 100

Gross NPA % =
DIVIDE(
    [NPA Amount],
    [Total Outstanding],
    0
) * 100

Avg Loan Amount =
DIVIDE(
    [Total Loans Disbursed],
    COUNTROWS(loans),
    0
)

Avg Overdue Days (NPA) =
CALCULATE(
    AVERAGE(loans[overdue_days]),
    loans[loan_status] = "NPA"
)

Total Overdue Amount =
CALCULATE(
    SUM(loans[overdue_amount]),
    loans[loan_status] IN {"NPA", "Restructured"}
)
*/


-- ─────────────────────────────────────────────────────────────
-- A4. TRANSACTION METRICS
-- ─────────────────────────────────────────────────────────────

/*
Total Transactions =
COUNTROWS(transactions)

Successful Transactions =
CALCULATE(
    COUNTROWS(transactions),
    transactions[status] = "Success"
)

Transaction Success Rate % =
DIVIDE(
    [Successful Transactions],
    [Total Transactions],
    0
) * 100

Total Credits =
CALCULATE(
    SUM(transactions[amount]),
    transactions[transaction_type] = "Credit",
    transactions[status] = "Success"
)

Total Debits =
CALCULATE(
    SUM(transactions[amount]),
    transactions[transaction_type] = "Debit",
    transactions[status] = "Success"
)

Net Cash Flow =
[Total Credits] - [Total Debits]

Avg Transaction Amount =
DIVIDE(
    SUM(transactions[amount]),
    [Total Transactions],
    0
)

Transactions This Month =
CALCULATE(
    [Total Transactions],
    DATESMTD(date_table[Date])
)

Transactions Last Month =
CALCULATE(
    [Total Transactions],
    DATEADD(date_table[Date], -1, MONTH)
)

Transaction Growth MoM % =
DIVIDE(
    [Transactions This Month] - [Transactions Last Month],
    [Transactions Last Month],
    0
) * 100
*/


-- ─────────────────────────────────────────────────────────────
-- A5. FRAUD METRICS
-- ─────────────────────────────────────────────────────────────

/*
Fraud Transactions =
CALCULATE(
    COUNTROWS(transactions),
    transactions[is_fraud] = TRUE()
)

Fraud Amount =
CALCULATE(
    SUM(transactions[amount]),
    transactions[is_fraud] = TRUE()
)

Fraud Rate % =
DIVIDE(
    [Fraud Transactions],
    [Total Transactions],
    0
) * 100

Fraud Amount % of Total =
DIVIDE(
    [Fraud Amount],
    SUM(transactions[amount]),
    0
) * 100

UPI Fraud Count =
CALCULATE(
    [Fraud Transactions],
    transactions[transaction_mode] = "UPI"
)

ATM Fraud Count =
CALCULATE(
    [Fraud Transactions],
    transactions[transaction_mode] = "ATM"
)
*/


-- ─────────────────────────────────────────────────────────────
-- A6. TIME INTELLIGENCE MEASURES
-- ─────────────────────────────────────────────────────────────

/*
YTD Total Credits =
TOTALYTD(
    [Total Credits],
    date_table[Date]
)

YTD Total Debits =
TOTALYTD(
    [Total Debits],
    date_table[Date]
)

MTD Transactions =
TOTALMTD(
    [Total Transactions],
    date_table[Date]
)

QTD Loans Disbursed =
TOTALQTD(
    [Total Loans Disbursed],
    date_table[Date]
)

Rolling 3M Transactions =
CALCULATE(
    [Total Transactions],
    DATESINPERIOD(
        date_table[Date],
        LASTDATE(date_table[Date]),
        -3, MONTH
    )
)
*/


-- ─────────────────────────────────────────────────────────────
-- A7. BRANCH METRICS
-- ─────────────────────────────────────────────────────────────

/*
Top Branch by Deposits =
TOPN(
    1,
    VALUES(branches[branch_name]),
    [Total Deposits]
)

Branch Deposit Rank =
RANKX(
    ALL(branches[branch_name]),
    [Total Deposits],
    ,
    DESC,
    DENSE
)

Branch NPA Rank =
RANKX(
    ALL(branches[branch_name]),
    [NPA Ratio %],
    ,
    DESC,
    DENSE
)
*/


-- =============================================================
-- PART B — DASHBOARD LAYOUT & VISUAL GUIDE
-- =============================================================
/*
RECOMMENDED: 3 Report Pages

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PAGE 1 — EXECUTIVE SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ROW 1 — KPI Cards (6 cards across the top):
┌──────────┬──────────┬──────────┬──────────┬──────────┬──────────┐
│  Total   │  Total   │  Total   │  NPA     │  Fraud   │  Net     │
│ Customers│ Deposits │  Loans   │ Ratio %  │ Rate %   │ Cash Flow│
└──────────┴──────────┴──────────┴──────────┴──────────┴──────────┘
   Visual: Card      Card       Card       Card       Card      Card

ROW 2 — Trend Charts:
┌────────────────────────────┬─────────────────────────────┐
│  Monthly Transaction       │  Credit vs Debit            │
│  Volume (Line Chart)       │  Monthly (Clustered Bar)    │
│  X: month_year             │  X: month_year              │
│  Y: Total Transactions     │  Y: Credits + Debits        │
└────────────────────────────┴─────────────────────────────┘

ROW 3 — Distribution:
┌───────────────────┬───────────────────┬───────────────────┐
│  Account Type     │  Loan Type        │  Transaction      │
│  Distribution     │  Distribution     │  Mode Split       │
│  (Donut Chart)    │  (Donut Chart)    │  (Donut Chart)    │
│  Legend: acc_type │  Legend: loan_type│  Legend: txn_mode │
└───────────────────┴───────────────────┴───────────────────┘

SLICERS (right side panel):
  - Year slicer         (date_table[Year])
  - City slicer         (branches[city])
  - Account Type slicer (accounts[account_type])


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PAGE 2 — LOAN & NPA ANALYSIS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ROW 1 — KPI Cards:
┌──────────┬──────────┬──────────┬──────────┬──────────┐
│  Total   │  Active  │  NPA     │  Gross   │  Total   │
│  Loans   │  Loans   │  Count   │  NPA %   │ Overdue  │
└──────────┴──────────┴──────────┴──────────┴──────────┘

ROW 2:
┌────────────────────────────┬─────────────────────────────┐
│  NPA by Loan Type          │  Loan Disbursement Trend    │
│  (Stacked Bar Chart)       │  (Line + Bar Combo)         │
│  X: loan_type              │  X: month_year              │
│  Y: NPA Count + NPA Amount │  Y: Loans + Outstanding     │
└────────────────────────────┴─────────────────────────────┘

ROW 3:
┌────────────────────────────┬─────────────────────────────┐
│  NPA by Branch/City        │  NPA Detail Table           │
│  (Clustered Bar Chart)     │  Columns:                   │
│  X: city                   │  customer_name, loan_type,  │
│  Y: NPA Ratio %            │  principal, overdue_days,   │
│                            │  npa_classification         │
└────────────────────────────┴─────────────────────────────┘

SLICERS: Year, City, Loan Type, Loan Status


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PAGE 3 — FRAUD & BRANCH ANALYSIS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ROW 1 — KPI Cards:
┌──────────┬──────────┬──────────┬──────────┬──────────┐
│  Fraud   │  Fraud   │  Fraud   │  UPI     │  ATM     │
│  Count   │  Amount  │  Rate %  │  Fraud   │  Fraud   │
└──────────┴──────────┴──────────┴──────────┴──────────┘

ROW 2:
┌────────────────────────────┬─────────────────────────────┐
│  Fraud by Category         │  Branch Performance Map     │
│  (Treemap or Bar)          │  (Filled Map / Bubble Map)  │
│  Category: fraud_category  │  Location: city             │
│  Value: Fraud Amount       │  Size: Total Deposits       │
│                            │  Color: NPA Ratio %         │
└────────────────────────────┴─────────────────────────────┘

ROW 3:
┌────────────────────────────┬─────────────────────────────┐
│  Fraud Trend (Line Chart)  │  Branch KPI Table           │
│  X: month_year             │  Columns:                   │
│  Y: Fraud Count +          │  branch_name, city,         │
│     Fraud Amount           │  total_deposits, NPA Ratio, │
│                            │  Deposit Rank               │
└────────────────────────────┴─────────────────────────────┘

SLICERS: Year, City, Transaction Mode, Fraud Category
*/


-- =============================================================
-- PART C — AUTO REFRESH SETUP
-- =============================================================
/*
GOAL: Jab bhi MySQL mein new data insert ho,
      Power BI dashboard automatically update ho.

LOCAL SETUP (Free — no Power BI Pro needed):
────────────────────────────────────────────
1. Power BI Desktop mein:
   Home → Transform Data → Data Source Settings
   → Edit Permissions → check "Skip test connection"

2. Scheduled Refresh via Power BI Desktop:
   File → Options → Data Load
   → Tick "Background Data" → set refresh interval

3. For auto-refresh on dashboard VIEW:
   Install: "Power BI Refresh" browser extension
   OR use: View → Auto Page Refresh (set to 30 sec)
   NOTE: Auto page refresh works with DirectQuery mode


DIRECTQUERY MODE (Best for live data):
────────────────────────────────────────────
When connecting MySQL in Power BI:
→ Instead of "Import", select "DirectQuery"

Benefits:
   ✅ Every visual query hits MySQL live
   ✅ No manual refresh needed
   ✅ New transactions show instantly

Tradeoff:
   ⚠️  Slightly slower visuals
   ⚠️  Some DAX functions not supported in DQ mode


TESTING AUTO-REFRESH:
────────────────────────────────────────────
Run this in MySQL to insert a test transaction:

CALL sp_insert_transaction(
    1,           -- account_id
    'Credit',    -- transaction_type
    'UPI',       -- mode
    5000.00,     -- amount
    'Test Auto Refresh'
);

Then check Power BI — the KPI cards and charts
should update automatically (in DirectQuery mode)
or after next refresh cycle (in Import mode).
*/

---------------------------------------------------------------------------------------------