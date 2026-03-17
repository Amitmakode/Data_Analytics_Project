-- =============================================================
--   🏦 BANKING ANALYTICS — MySQL Schema Script
-- =============================================================
--   Run this BEFORE importing CSVs
--   Order: branches → customers → accounts → loans → transactions
-- =============================================================

-- Step 1: Create & use the database
CREATE DATABASE IF NOT EXISTS banking_analytics
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE banking_analytics;

-- =============================================================
-- TABLE 1 — BRANCHES
-- =============================================================

drop table branches ;

CREATE TABLE IF NOT EXISTS branches (
    branch_id        INT             NOT NULL AUTO_INCREMENT,
    branch_name      VARCHAR(100)    NOT NULL,
    city             VARCHAR(50)     NOT NULL,
    state            VARCHAR(50)     NOT NULL,
    ifsc_code        VARCHAR(15)     NOT NULL UNIQUE,
    contact_number   VARCHAR(20),
    manager_name     VARCHAR(100),
    opened_date      DATE,

    PRIMARY KEY (branch_id),
    INDEX idx_city (city)
);

-- =============================================================
-- TABLE 2 — CUSTOMERS
-- =============================================================

drop table customers ;

CREATE TABLE IF NOT EXISTS customers (
    customer_id      INT             NOT NULL AUTO_INCREMENT,
    first_name       VARCHAR(50)     NOT NULL,
    last_name        VARCHAR(50)     NOT NULL,
    gender           ENUM('Male','Female','Other') NOT NULL,
    date_of_birth    DATE,
    age              TINYINT UNSIGNED,
    occupation       VARCHAR(50),
    monthly_income   DECIMAL(12,2),
    email            VARCHAR(100)    UNIQUE,
    phone_number     VARCHAR(20),
    address          VARCHAR(255),
    city             VARCHAR(50),
    pan_number       VARCHAR(10)     UNIQUE,
    kyc_status       ENUM('Verified','Pending','Rejected') DEFAULT 'Pending',
    branch_id        INT             NOT NULL,
    joining_date     DATE,
    credit_score     SMALLINT,      

    PRIMARY KEY (customer_id),
    FOREIGN KEY (branch_id) REFERENCES branches(branch_id),
    INDEX idx_city        (city),
    INDEX idx_kyc         (kyc_status),
    INDEX idx_credit      (credit_score),
    INDEX idx_branch      (branch_id)
);

-- =============================================================
-- TABLE 3 — ACCOUNTS
-- =============================================================

drop table accounts ;

CREATE TABLE IF NOT EXISTS accounts (
    account_id       INT             NOT NULL AUTO_INCREMENT,
    account_number   VARCHAR(15)     NOT NULL UNIQUE,
    customer_id      INT             NOT NULL,
    account_type     ENUM('Savings','Current','Fixed Deposit','Recurring Deposit') NOT NULL,
    balance          DECIMAL(15,2)   DEFAULT 0.00,
    opening_date     DATE,
    status           ENUM('Active','Dormant','Closed') DEFAULT 'Active',
    branch_id        INT             NOT NULL,
    interest_rate    DECIMAL(5,2),

    PRIMARY KEY (account_id),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (branch_id)   REFERENCES branches(branch_id),
    INDEX idx_customer    (customer_id),
    INDEX idx_status      (status),
    INDEX idx_acc_type    (account_type)
);

-- =============================================================
-- TABLE 4 — LOANS  (NPA / Defaulters)
-- =============================================================
drop table loans ;

CREATE TABLE IF NOT EXISTS loans (
    loan_id                         INT             NOT NULL AUTO_INCREMENT,
    loan_number                     VARCHAR(12)     NOT NULL UNIQUE,
    customer_id                     INT             NOT NULL,
    loan_type                       ENUM('Home Loan','Personal Loan','Car Loan',
                                         'Education Loan','Business Loan') NOT NULL,
    principal_amount                DECIMAL(15,2)   NOT NULL,
    interest_rate                   DECIMAL(5,2)    NOT NULL,
    tenure_months                   SMALLINT        NOT NULL,
    emi_amount                      DECIMAL(12,2),
    disbursed_date                  DATE,
    maturity_date                   DATE,
    loan_status                     ENUM('Active','Closed','NPA','Restructured') DEFAULT 'Active',
    outstanding_amount              DECIMAL(15,2)   DEFAULT 0.00,
    overdue_days                    INT             DEFAULT 0,
    overdue_amount                  DECIMAL(12,2)   DEFAULT 0.00,
    collateral_type                 VARCHAR(50),
    branch_id                       INT             NOT NULL,
    credit_score_at_disbursement    SMALLINT,

    PRIMARY KEY (loan_id),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (branch_id)   REFERENCES branches(branch_id),
    INDEX idx_loan_status     (loan_status),
    INDEX idx_loan_type       (loan_type),
    INDEX idx_overdue         (overdue_days),
    INDEX idx_loan_customer   (customer_id)
);

-- =============================================================
-- TABLE 5 — TRANSACTIONS  (with Fraud flags)
-- =============================================================

drop table transactions ;

CREATE TABLE IF NOT EXISTS transactions (
    transaction_id          INT             NOT NULL AUTO_INCREMENT,
    transaction_ref         VARCHAR(15)     NOT NULL UNIQUE,
    account_id              INT             NOT NULL,
    account_number          VARCHAR(15)     NOT NULL,
    transaction_date        DATE            NOT NULL,
    transaction_time        TIME            NOT NULL,
    transaction_type        ENUM('Credit','Debit') NOT NULL,
    transaction_mode        ENUM('NEFT','IMPS','UPI','ATM','Cheque','RTGS','Online Transfer') NOT NULL,
    amount                  DECIMAL(15,2)   NOT NULL,
    counterparty_account    VARCHAR(15),
    description             VARCHAR(100),
    is_fraud                TINYINT(1)      DEFAULT 0,
    fraud_category          VARCHAR(50),
    status                  ENUM('Success','Failed','Pending') DEFAULT 'Success',
    branch_id               INT             NOT NULL,

    PRIMARY KEY (transaction_id),
    FOREIGN KEY (account_id)  REFERENCES accounts(account_id),
    FOREIGN KEY (branch_id)   REFERENCES branches(branch_id),
    INDEX idx_txn_date        (transaction_date),
    INDEX idx_txn_type        (transaction_type),
    INDEX idx_fraud           (is_fraud),
    INDEX idx_status          (status),
    INDEX idx_account         (account_id)
);

-- =============================================================
-- VERIFY — Check all tables created
-- =============================================================
SHOW TABLES;

-- =============================================================
-- IMPORT CSVs  (run these after schema is created)
-- Update the file path to where your CSVs are stored
-- =============================================================

select * from customers ;

-- NOTE: Set this once to allow local file imports
SET GLOBAL local_infile = 0;

SET SESSION sql_mode = '';

-- 1. Branches
LOAD DATA LOCAL INFILE '/your/path/banking_csvs/branches.csv'
INTO TABLE branches
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(branch_id, branch_name, city, state, ifsc_code,
 contact_number, manager_name, opened_date);
 
 
-- 2. Branches

LOAD DATA  INFILE "F:\\End to End Project\\New folder\\branches.xls"
INTO TABLE branches
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS ;

(branch_id, branch_name, city, state, ifsc_code,
 contact_number, manager_name, opened_date);
 

-- 2. Customers
LOAD DATA INFILE "F:\\End to End Project\\New folder\\customers.xls"
INTO TABLE customers
FIELDS TERMINATED BY ','                     
LINES TERMINATED BY '\n'
IGNORE 1 ROWS ;

truncate table customers ;

(customer_id, first_name, last_name, gender, date_of_birth, age,
 occupation, monthly_income, email, phone_number, address, city,
 pan_number, kyc_status, branch_id, joining_date, credit_score);

-- 3. Accounts
LOAD DATA INFILE "F:\\End to End Project\\New folder\\accounts.xls"
INTO TABLE accounts
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS ; 


(account_id, account_number, customer_id, account_type,
 balance, opening_date, status, branch_id, interest_rate);

-- 4. Loans
LOAD DATA LOCAL INFILE '/your/path/banking_csvs/loans.csv'
INTO TABLE loans
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(loan_id, loan_number, customer_id, loan_type, principal_amount,
 interest_rate, tenure_months, emi_amount, disbursed_date, maturity_date,
 loan_status, outstanding_amount, overdue_days, overdue_amount,
 collateral_type, branch_id, credit_score_at_disbursement);

-- 5. Transactions
LOAD DATA LOCAL INFILE '/your/path/banking_csvs/transactions.csv'
INTO TABLE transactions
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(transaction_id, transaction_ref, account_id, account_number,
 transaction_date, transaction_time, transaction_type, transaction_mode,
 amount, counterparty_account, description, is_fraud,
 fraud_category, status, branch_id);


-- =============================================================
-- QUICK SANITY CHECK — Run after import
-- =============================================================

SELECT 'branches'    AS tbl, COUNT(*) AS total FROM branches    UNION ALL
SELECT 'customers',           COUNT(*)          FROM customers   UNION ALL
SELECT 'accounts',            COUNT(*)          FROM accounts    UNION ALL
SELECT 'loans',               COUNT(*)          FROM loans       UNION ALL
SELECT 'transactions',        COUNT(*)          FROM transactions;


---------------------------------------------------


-- =============================================================
--   🏦 BANKING ANALYTICS — Phase 2
--   Data Cleaning + Views + Stored Procedures + Triggers
-- =============================================================

USE banking_analytics;

-- =============================================================
-- SECTION 1 — DATA CLEANING
-- =============================================================

-- -------------------------------------------------------------
-- 1.1  Standardize text columns (trim spaces, fix casing)
-- -------------------------------------------------------------
UPDATE customers SET
    first_name   = TRIM(INITCAP(first_name)),
    last_name    = TRIM(INITCAP(last_name)),
    city         = TRIM(INITCAP(city)),
    occupation   = TRIM(occupation);

UPDATE branches SET
    branch_name  = TRIM(branch_name),
    city         = TRIM(INITCAP(city));

-- -------------------------------------------------------------
-- 1.2  Fix NULL emails — replace with a placeholder
-- -------------------------------------------------------------
UPDATE customers
SET email = CONCAT('unknown_', customer_id, '@bank.com')
WHERE email IS NULL OR email = '';

-- -------------------------------------------------------------
-- 1.3  Fix invalid credit scores (must be 300–900)
-- -------------------------------------------------------------
UPDATE customers
SET credit_score = 300
WHERE credit_score < 300;

UPDATE customers
SET credit_score = 900
WHERE credit_score > 900;

-- -------------------------------------------------------------
-- 1.4  Fix negative balances in accounts
-- -------------------------------------------------------------
UPDATE accounts
SET balance = 0.00
WHERE balance < 0;

-- -------------------------------------------------------------
-- 1.5  Fix negative amounts in transactions
-- -------------------------------------------------------------
UPDATE transactions
SET amount = ABS(amount)
WHERE amount < 0;

-- -------------------------------------------------------------
-- 1.6  Set fraud_category = 'None' where is_fraud = 0
-- -------------------------------------------------------------
UPDATE transactions
SET fraud_category = 'None'
WHERE is_fraud = 0 AND (fraud_category IS NULL OR fraud_category = '');

-- -------------------------------------------------------------
-- 1.7  Remove duplicate transactions (same ref, keep lowest id)
-- -------------------------------------------------------------
DELETE t1 FROM transactions t1
INNER JOIN transactions t2
    ON t1.transaction_ref = t2.transaction_ref
    AND t1.transaction_id > t2.transaction_id;

-- -------------------------------------------------------------
-- 1.8  Flag dormant accounts (no transaction in last 365 days)
-- -------------------------------------------------------------
UPDATE accounts a
SET a.status = 'Dormant'
WHERE a.status = 'Active'
  AND a.account_id NOT IN (
      SELECT DISTINCT account_id
      FROM transactions
      WHERE transaction_date >= DATE_SUB(CURDATE(), INTERVAL 365 DAY)
  );

-- -------------------------------------------------------------
-- 1.9  Verify cleaning results
-- -------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM customers WHERE email LIKE 'unknown_%') AS missing_emails_fixed,
    (SELECT COUNT(*) FROM accounts  WHERE balance = 0)            AS zero_balance_accounts,
    (SELECT COUNT(*) FROM transactions WHERE amount <= 0)         AS invalid_amount_txns,
    (SELECT COUNT(*) FROM transactions WHERE is_fraud = 1)        AS fraud_transactions,
    (SELECT COUNT(*) FROM loans WHERE loan_status = 'NPA')        AS npa_loans;


-- =============================================================
-- SECTION 2 — VIEWS  (used directly in Power BI)
-- =============================================================

-- -------------------------------------------------------------
-- 2.1  Monthly Transaction Summary  → Line chart in Power BI
-- -------------------------------------------------------------
CREATE OR REPLACE VIEW vw_monthly_transactions AS
SELECT
    DATE_FORMAT(transaction_date, '%Y-%m')  AS txn_month,
    transaction_type,
    COUNT(*)                                AS total_transactions,
    SUM(amount)                             AS total_amount,
    AVG(amount)                             AS avg_amount,
    SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) AS fraud_count,
    SUM(CASE WHEN status = 'Failed' THEN 1 ELSE 0 END) AS failed_count
FROM transactions
GROUP BY txn_month, transaction_type
ORDER BY txn_month;

-- -------------------------------------------------------------
-- 2.2  Branch Performance KPIs  → Map / Bar chart in Power BI
-- -------------------------------------------------------------
CREATE OR REPLACE VIEW vw_branch_performance AS
SELECT
    b.branch_id,
    b.branch_name,
    b.city,
    COUNT(DISTINCT c.customer_id)               AS total_customers,
    COUNT(DISTINCT a.account_id)                AS total_accounts,
    COALESCE(SUM(a.balance), 0)                 AS total_deposits,
    COUNT(DISTINCT l.loan_id)                   AS total_loans,
    COALESCE(SUM(l.principal_amount), 0)        AS total_loan_amount,
    COUNT(DISTINCT CASE WHEN l.loan_status = 'NPA'
          THEN l.loan_id END)                   AS npa_loans,
    COALESCE(SUM(CASE WHEN l.loan_status = 'NPA'
          THEN l.outstanding_amount END), 0)    AS npa_amount
FROM branches b
LEFT JOIN customers   c ON b.branch_id = c.branch_id
LEFT JOIN accounts    a ON b.branch_id = a.branch_id AND a.status = 'Active'
LEFT JOIN loans       l ON b.branch_id = l.branch_id
GROUP BY b.branch_id, b.branch_name, b.city;

-- -------------------------------------------------------------
-- 2.3  NPA / Loan Default Analysis  → KPI card + table
-- -------------------------------------------------------------
CREATE OR REPLACE VIEW vw_npa_analysis AS
SELECT
    l.loan_id,
    l.loan_number,
    CONCAT(c.first_name, ' ', c.last_name)  AS customer_name,
    c.credit_score,
    c.monthly_income,
    l.loan_type,
    l.principal_amount,
    l.outstanding_amount,
    l.overdue_days,
    l.overdue_amount,
    l.loan_status,
    b.branch_name,
    b.city,
    CASE
        WHEN l.overdue_days BETWEEN 91  AND 180 THEN 'Sub-Standard'
        WHEN l.overdue_days BETWEEN 181 AND 365 THEN 'Doubtful'
        WHEN l.overdue_days > 365               THEN 'Loss Asset'
        ELSE 'Standard'
    END AS npa_classification
FROM loans l
JOIN customers c ON l.customer_id = c.customer_id
JOIN branches  b ON l.branch_id   = b.branch_id
WHERE l.loan_status IN ('NPA', 'Restructured');

-- -------------------------------------------------------------
-- 2.4  Fraud Transaction Analysis  → KPI card + table
-- -------------------------------------------------------------
CREATE OR REPLACE VIEW vw_fraud_analysis AS
SELECT
    t.transaction_id,
    t.transaction_ref,
    t.transaction_date,
    t.transaction_mode,
    t.amount,
    t.fraud_category,
    t.status,
    a.account_number,
    a.account_type,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    c.city,
    b.branch_name
FROM transactions t
JOIN accounts  a ON t.account_id  = a.account_id
JOIN customers c ON a.customer_id = c.customer_id
JOIN branches  b ON t.branch_id   = b.branch_id
WHERE t.is_fraud = 1;

-- -------------------------------------------------------------
-- 2.5  Customer 360 View  → Slicer/filter in Power BI
-- -------------------------------------------------------------
CREATE OR REPLACE VIEW vw_customer_360 AS
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name)  AS customer_name,
    c.gender,
    c.age,
    c.occupation,
    c.monthly_income,
    c.credit_score,
    c.kyc_status,
    c.city,
    b.branch_name,
    COUNT(DISTINCT a.account_id)            AS total_accounts,
    COALESCE(SUM(a.balance), 0)             AS total_balance,
    COUNT(DISTINCT l.loan_id)               AS total_loans,
    COALESCE(SUM(l.outstanding_amount), 0)  AS total_outstanding,
    COUNT(DISTINCT t.transaction_id)        AS total_transactions,
    MAX(t.transaction_date)                 AS last_transaction_date
FROM customers c
JOIN branches  b ON c.branch_id   = b.branch_id
LEFT JOIN accounts    a ON c.customer_id = a.customer_id
LEFT JOIN loans       l ON c.customer_id = l.customer_id
LEFT JOIN transactions t ON a.account_id = t.account_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.gender,
         c.age, c.occupation, c.monthly_income, c.credit_score,
         c.kyc_status, c.city, b.branch_name;

-- -------------------------------------------------------------
-- 2.6  KPI Summary View  → All KPI cards in Power BI
-- -------------------------------------------------------------
CREATE OR REPLACE VIEW vw_kpi_summary AS
SELECT
    -- Customer KPIs
    (SELECT COUNT(*)  FROM customers)                                           AS total_customers,
    (SELECT COUNT(*)  FROM customers WHERE kyc_status = 'Verified')             AS verified_customers,

    -- Account KPIs
    (SELECT COUNT(*)  FROM accounts  WHERE status = 'Active')                   AS active_accounts,
    (SELECT COALESCE(SUM(balance),0) FROM accounts WHERE status = 'Active')     AS total_deposits,

    -- Loan KPIs
    (SELECT COUNT(*)  FROM loans)                                               AS total_loans,
    (SELECT COALESCE(SUM(principal_amount),0) FROM loans)                       AS total_loan_disbursed,
    (SELECT COUNT(*)  FROM loans WHERE loan_status = 'NPA')                     AS npa_count,
    (SELECT ROUND(COUNT(*) * 100.0 /
        NULLIF((SELECT COUNT(*) FROM loans), 0), 2)
     FROM loans WHERE loan_status = 'NPA')                                      AS npa_ratio_pct,

    -- Transaction KPIs
    (SELECT COUNT(*)  FROM transactions WHERE status  = 'Success')              AS successful_transactions,
    (SELECT COALESCE(SUM(amount),0) FROM transactions WHERE transaction_type = 'Credit'
        AND status = 'Success')                                                 AS total_credits,
    (SELECT COALESCE(SUM(amount),0) FROM transactions WHERE transaction_type = 'Debit'
        AND status = 'Success')                                                 AS total_debits,

    -- Fraud KPIs
    (SELECT COUNT(*) FROM transactions WHERE is_fraud = 1)                      AS fraud_transactions,
    (SELECT ROUND(COUNT(*) * 100.0 /
        NULLIF((SELECT COUNT(*) FROM transactions), 0), 2)
     FROM transactions WHERE is_fraud = 1)                                      AS fraud_rate_pct,
    (SELECT COALESCE(SUM(amount),0) FROM transactions WHERE is_fraud = 1)       AS fraud_amount;
