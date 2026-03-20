-- =============================================================
--   🏦 BANKING ANALYTICS — Phase 3
--   Power BI MySQL Connection + Power Query Transformations
-- =============================================================
--   This file contains:
--   PART A → MySQL Connector setup instructions
--   PART B → Power Query M Code for each table/view
--   PART C → Data Model relationships
-- =============================================================


-- =============================================================
-- PART A — MYSQL CONNECTOR SETUP
-- =============================================================

/*
STEP 1 — Install MySQL ODBC Connector
---------------------------------------
1. Go to: https://dev.mysql.com/downloads/connector/odbc/
2. Download "MySQL Connector/ODBC 8.x" — Windows (x86, 64-bit)
3. Install it (next > next > finish)
4. Restart your PC after install


STEP 2 — Connect Power BI to MySQL
---------------------------------------
1. Open Power BI Desktop
2. Click "Get Data" → Search "MySQL" → Select "MySQL database"
3. Fill in:
      Server   : localhost          (or 127.0.0.1)
      Database : banking_analytics
4. Click OK
5. Authentication: Select "Database"
      Username : root               (your MySQL username)
      Password : ****               (your MySQL password)
6. Click Connect


STEP 3 — Select Tables & Views to Load
---------------------------------------
In the Navigator window, SELECT these (tick all):
   ✅ branches
   ✅ customers
   ✅ accounts
   ✅ loans
   ✅ transactions
   ✅ vw_monthly_transactions
   ✅ vw_branch_performance
   ✅ vw_npa_analysis
   ✅ vw_fraud_analysis
   ✅ vw_customer_360
   ✅ vw_kpi_summary

7. Click "Transform Data" (NOT Load — we need Power Query first)
*/


-- =============================================================
-- PART B — POWER QUERY M CODE
-- =============================================================
-- Copy-paste each block into Power Query Advanced Editor
-- Home → Advanced Editor → paste → Done
-- =============================================================


-- ─────────────────────────────────────────────────────────────
-- B1. CUSTOMERS TABLE — Clean + Add columns
-- ─────────────────────────────────────────────────────────────

let
    Source           = MySQL.Database("localhost", "banking_analytics"),
    customers_table  = Source{[Schema="banking_analytics", Item="customers"]}[Data],

    // 1. Remove unnecessary columns
    remove_cols      = Table.RemoveColumns(customers_table,
                         {"address", "pan_number", "phone_number"}),

    // 2. Fix data types
    fix_types        = Table.TransformColumnTypes(remove_cols, {
                         {"customer_id",    Int64.Type},
                         {"monthly_income", type number},
                         {"credit_score",   Int64.Type},
                         {"date_of_birth",  type date},
                         {"joining_date",   type date}
                       }),

    // 3. Add Age Group column
    add_age_group    = Table.AddColumn(fix_types, "age_group", each
                         if [age] < 25 then "18-24"
                         else if [age] < 35 then "25-34"
                         else if [age] < 45 then "35-44"
                         else if [age] < 55 then "45-54"
                         else "55+", type text),

    // 4. Add Income Segment column
    add_income_seg   = Table.AddColumn(add_age_group, "income_segment", each
                         if [monthly_income] < 25000  then "Low Income"
                         else if [monthly_income] < 75000  then "Middle Income"
                         else if [monthly_income] < 150000 then "Upper Middle"
                         else "High Income", type text),

    // 5. Add Credit Rating column
    add_credit_rating = Table.AddColumn(add_income_seg, "credit_rating", each
                         if [credit_score] >= 750 then "Excellent"
                         else if [credit_score] >= 650 then "Good"
                         else if [credit_score] >= 550 then "Fair"
                         else "Poor", type text),

    // 6. Capitalize KYC status
    fix_kyc           = Table.TransformColumns(add_credit_rating,
                         {{"kyc_status", Text.Proper, type text}})
in
    fix_kyc


-- ─────────────────────────────────────────────────────────────
-- B2. ACCOUNTS TABLE — Clean + Add columns
-- ─────────────────────────────────────────────────────────────


let
    Source           = MySQL.Database("localhost", "banking_analytics"),
    accounts_table   = Source{[Schema="banking_analytics", Item="accounts"]}[Data],

    // 1. Fix data types
    fix_types        = Table.TransformColumnTypes(accounts_table, {
                         {"account_id",    Int64.Type},
                         {"customer_id",   Int64.Type},
                         {"balance",       type number},
                         {"interest_rate", type number},
                         {"opening_date",  type date}
                       }),

    // 2. Add Balance Tier column
    add_balance_tier = Table.AddColumn(fix_types, "balance_tier", each
                         if [balance] < 10000  then "Low (<10K)"
                         else if [balance] < 100000 then "Mid (10K-1L)"
                         else if [balance] < 500000 then "High (1L-5L)"
                         else "Premium (5L+)", type text),

    // 3. Add Account Age (in years)
    add_acc_age      = Table.AddColumn(add_balance_tier, "account_age_years", each
                         Number.Round(
                             Duration.TotalDays(
                                 Date.From(DateTime.LocalNow()) - [opening_date]
                             ) / 365,
                         1), type number),

    // 4. Remove now-redundant rounding step (already done above)
    round_age        = Table.TransformColumns(add_acc_age,
                         {{"account_age_years", each Number.Round(_, 1), type number}})
in
    round_age

-- ─────────────────────────────────────────────────────────────
-- B3. LOANS TABLE — Clean + Add columns
-- ─────────────────────────────────────────────────────────────

let
    Source             = MySQL.Database("localhost", "banking_analytics"),
    loans_table        = Source{[Schema="banking_analytics", Item="loans"]}[Data],

    // 1. Fix data types
    fix_types          = Table.TransformColumnTypes(loans_table, {
                           {"loan_id",            Int64.Type},
                           {"customer_id",        Int64.Type},
                           {"principal_amount",   type number},
                           {"emi_amount",         type number},
                           {"outstanding_amount", type number},
                           {"overdue_amount",     type number},
                           {"interest_rate",      type number},
                           {"disbursed_date",     type date},
                           {"maturity_date",      type date}
                         }),

    // 2. Add Loan Health column
    add_health         = Table.AddColumn(fix_types, "loan_health", each
                           if [loan_status] = "NPA"           then "Defaulted"
                           else if [loan_status] = "Restructured" then "At Risk"
                           else if [loan_status] = "Active"       then "Active"
                           else "Closed", type text),

    // 3. Add Repayment % column
    add_repayment      = Table.AddColumn(add_health, "repayment_pct", each
                           if [principal_amount] = 0 then 0
                           else Number.Round(
                               ([principal_amount] - [outstanding_amount])
                               / [principal_amount] * 100, 1
                           ), type number),

    // 4. Add NPA flag (boolean — useful for DAX)
    add_npa_flag       = Table.AddColumn(add_repayment, "is_npa",
                           each [loan_status] = "NPA", type logical)
in
    add_npa_flag


-- ─────────────────────────────────────────────────────────────
-- B4. TRANSACTIONS TABLE — Clean + Add columns
-- ─────────────────────────────────────────────────────────────

let
    Source          = MySQL.Database("localhost", "banking_analytics"),
    txn_table       = Source{[Schema="banking_analytics", Item="transactions"]}[Data],

    // 1. Fix data types
    fix_types       = Table.TransformColumnTypes(txn_table, {
                        {"transaction_id",   Int64.Type},
                        {"account_id",       Int64.Type},
                        {"amount",           type number},
                        {"transaction_date", type date},
                        {"is_fraud",         type logical}
                      }),

    // 2. Remove internal columns not needed in Power BI
    remove_cols     = Table.RemoveColumns(fix_types,
                        {"counterparty_account", "transaction_time"}),

    // 3. Add Month-Year column (for time intelligence)
    add_month_year  = Table.AddColumn(remove_cols, "month_year", each
                        Date.ToText([transaction_date],
                            [Format="MMM yyyy", Culture="en-IN"]),
                        type text),

    // 4. Add Month Number (for correct sort order in Power BI)
    add_month_num   = Table.AddColumn(add_month_year, "month_num", each
                        Date.Month([transaction_date]),
                        Int64.Type),

    // 5. Add Year column
    add_year        = Table.AddColumn(add_month_num, "year", each
                        Date.Year([transaction_date]),
                        Int64.Type),

    // 6. Add Amount Bucket
    add_bucket      = Table.AddColumn(add_year, "amount_bucket", each
                        if [amount] < 1000   then "Micro (<1K)"
                        else if [amount] < 10000  then "Small (1K-10K)"
                        else if [amount] < 100000 then "Medium (10K-1L)"
                        else "Large (1L+)", type text),

    // 7. Add Signed Amount (negative for debits — useful for net flow)
    add_signed      = Table.AddColumn(add_bucket, "signed_amount", each
                        if [transaction_type] = "Debit"
                        then -[amount] else [amount],
                        type number)
in
    add_signed


-- ─────────────────────────────────────────────────────────────
-- B5. DATE TABLE — Always needed for Time Intelligence in DAX
-- ─────────────────────────────────────────────────────────────

-- In Power BI: Home → New Source → Blank Query → Advanced Editor
-- Paste this:

let
    StartDate    = #date(2022, 1, 1),
    EndDate      = Date.From(DateTime.LocalNow()),
    NumDays      = Duration.Days(EndDate - StartDate) + 1,
    DateList     = List.Dates(StartDate, NumDays, #duration(1,0,0,0)),
    DateTable    = Table.FromList(DateList, Splitter.SplitByNothing(),
                     type table [Date = date]),

    add_year     = Table.AddColumn(DateTable,   "Year",
                     each Date.Year([Date]),    Int64.Type),

    add_quarter  = Table.AddColumn(add_year,    "Quarter",
                     each "Q" & Text.From(Date.QuarterOfYear([Date])), type text),

    add_month    = Table.AddColumn(add_quarter, "Month",
                     each Date.Month([Date]),   Int64.Type),

    add_month_nm = Table.AddColumn(add_month,   "Month Name",
                     each Date.ToText([Date],
                       [Format="MMMM", Culture="en-IN"]), type text),

    add_month_sh = Table.AddColumn(add_month_nm, "Month Short",
                     each Date.ToText([Date],
                       [Format="MMM", Culture="en-IN"]), type text),

    add_week     = Table.AddColumn(add_month_sh, "Week Number",
                     each Date.WeekOfYear([Date],
                       Day.Monday),              Int64.Type),

    add_day      = Table.AddColumn(add_week,     "Day",
                     each Date.Day([Date]),      Int64.Type),

    add_day_name = Table.AddColumn(add_day,      "Day Name",
                     each Date.ToText([Date],
                       [Format="dddd", Culture="en-IN"]), type text),

    add_fy       = Table.AddColumn(add_day_name, "Financial Year",
                     each if Date.Month([Date]) >= 4
                          then "FY" & Text.From(Date.Year([Date]))
                               & "-" & Text.From(Date.Year([Date]) + 1)
                          else "FY" & Text.From(Date.Year([Date]) - 1)
                               & "-" & Text.From(Date.Year([Date])),
                     type text)
in
    add_fy
