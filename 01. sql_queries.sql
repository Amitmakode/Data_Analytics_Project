CREATE DATABASE IF NOT EXISTS banking_analytics1
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
    

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

select * from branches ;

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


select * from customers ;

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

select * from accounts ;

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

select * from loans ;


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

select * from transactions ;


show tables ;


SELECT 'branches'    AS tbl, COUNT(*) AS total FROM branches    UNION ALL
SELECT 'customers',           COUNT(*)          FROM customers   UNION ALL
SELECT 'accounts',            COUNT(*)          FROM accounts    UNION ALL
SELECT 'loans',               COUNT(*)          FROM loans       UNION ALL
SELECT 'transactions',        COUNT(*)          FROM transactions;


UPDATE customers SET
  first_name  = TRIM(CONCAT(
                  UPPER(LEFT(TRIM(first_name), 1)),
                  LOWER(SUBSTRING(TRIM(first_name), 2))
                )),
  last_name   = TRIM(CONCAT(
                  UPPER(LEFT(TRIM(last_name), 1)),
                  LOWER(SUBSTRING(TRIM(last_name), 2))
                )),
  city        = TRIM(CONCAT(
                  UPPER(LEFT(TRIM(city), 1)),
                  LOWER(SUBSTRING(TRIM(city), 2))
                )),
  occupation  = TRIM(occupation);    
  
  
UPDATE branches SET
  branch_name = TRIM(branch_name),
  city        = TRIM(CONCAT(
                  UPPER(LEFT(TRIM(city), 1)),
                  LOWER(SUBSTRING(TRIM(city), 2))
                ));   
                

-- -------------------------------------------------------------
-- 1.2  Fix NULL emails — replace with a placeholder
-- -------------------------------------------------------------
UPDATE customers
SET email = CONCAT('unknown_', customer_id, '@bank.com')
WHERE email IS NULL OR email = '';       

select * from customers where email = '' ;   


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
  
  
select * from vw_monthly_transactions  ;


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

select * from vw_branch_performance ;


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

select * from vw_npa_analysis ;

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



-- -------------------------------------------------------------
-- 3.1  Get full customer profile by customer_id
-- -------------------------------------------------------------
DELIMITER $$
CREATE PROCEDURE sp_get_customer_profile(IN p_customer_id INT)
BEGIN
    SELECT * FROM vw_customer_360
    WHERE customer_id = p_customer_id;
END$$
DELIMITER ;


select * from vw_customer_360 ;

SELECT * FROM vw_customer_360
    WHERE customer_id = 700;
    
call  sp_get_customer_profile(400)  ;

-- -------------------------------------------------------------
-- 3.2  Get branch-wise KPI report for a given city
-- -------------------------------------------------------------
DELIMITER $$
CREATE PROCEDURE sp_branch_kpi_by_city(IN p_city VARCHAR(50))
BEGIN
    SELECT * FROM vw_branch_performance
    WHERE city = p_city
    ORDER BY total_deposits DESC;
END$$
DELIMITER ;


call sp_branch_kpi_by_city("pune" ) ;


-- -------------------------------------------------------------
-- 3.3  Insert new transaction (used for auto-refresh demo)
-- -------------------------------------------------------------
DELIMITER $$
CREATE PROCEDURE sp_insert_transaction(
    IN p_account_id         INT,
    IN p_transaction_type   VARCHAR(10),
    IN p_transaction_mode   VARCHAR(20),
    IN p_amount             DECIMAL(15,2),
    IN p_description        VARCHAR(100)
)
BEGIN
    DECLARE v_branch_id      INT;
    DECLARE v_account_number VARCHAR(15);
    DECLARE v_ref            VARCHAR(15);

    -- Get branch and account number
    SELECT branch_id, account_number
    INTO v_branch_id, v_account_number
    FROM accounts WHERE account_id = p_account_id;

    -- Generate unique transaction ref
    SET v_ref = CONCAT('TXN', LPAD(FLOOR(RAND() * 9999999999), 10, '0'));

    -- Insert transaction
    INSERT INTO transactions (
        transaction_ref, account_id, account_number,
        transaction_date, transaction_time,
        transaction_type, transaction_mode,
        amount, description, is_fraud, fraud_category, status, branch_id
    ) VALUES (
        v_ref, p_account_id, v_account_number,
        CURDATE(), CURTIME(),
        p_transaction_type, p_transaction_mode,
        p_amount, p_description, 0, 'None', 'Success', v_branch_id
    );

    -- Update account balance
    IF p_transaction_type = 'Credit' THEN
        UPDATE accounts SET balance = balance + p_amount
        WHERE account_id = p_account_id;
    ELSE
        UPDATE accounts SET balance = balance - p_amount
        WHERE account_id = p_account_id;
    END IF;

    SELECT 'Transaction inserted successfully' AS message,
            v_ref AS transaction_ref;
END$$
DELIMITER ;


-- -------------------------------------------------------------
-- 4.1  AFTER INSERT on transactions
--      → Auto-flag fraud if amount > 1,00,000 via UPI/ATM
-- -------------------------------------------------------------

DELIMITER $$
CREATE TRIGGER IF NOT EXISTS trg_flag_large_fraud
AFTER INSERT ON transactions
FOR EACH ROW
BEGIN
    IF NEW.amount > 100000
       AND NEW.transaction_mode IN ('UPI', 'ATM')
       AND NEW.is_fraud = 0 THEN

        UPDATE transactions
        SET    is_fraud       = 1,
               fraud_category = 'High Value Suspicious'
        WHERE  transaction_id = NEW.transaction_id;
    END IF;
END$$
DELIMITER ;

-- -------------------------------------------------------------
-- 4.2  AFTER INSERT on transactions
--      → Auto update account balance (safety net)
-- -------------------------------------------------------------
DELIMITER $$
CREATE TRIGGER IF NOT EXISTS trg_update_balance_on_txn
AFTER INSERT ON transactions
FOR EACH ROW
BEGIN
    IF NEW.status = 'Success' THEN
        IF NEW.transaction_type = 'Credit' THEN
            UPDATE accounts
            SET balance = balance + NEW.amount
            WHERE account_id = NEW.account_id;
        ELSEIF NEW.transaction_type = 'Debit' THEN
            UPDATE accounts
            SET balance = balance - NEW.amount
            WHERE account_id = NEW.account_id;
        END IF;
    END IF;
END$$
DELIMITER ;

-- -------------------------------------------------------------
-- 4.3  AFTER UPDATE on loans
--      → Auto update customer credit score when loan goes NPA
-- -------------------------------------------------------------
DELIMITER $$
CREATE TRIGGER IF NOT EXISTS trg_credit_score_on_npa
AFTER UPDATE ON loans
FOR EACH ROW
BEGIN
    IF NEW.loan_status = 'NPA' AND OLD.loan_status != 'NPA' THEN
        UPDATE customers
        SET credit_score = GREATEST(300, credit_score - 80)
        WHERE customer_id = NEW.customer_id;
    END IF;
END$$
DELIMITER ;


SHOW FULL TABLES WHERE Table_type = 'VIEW';

SHOW TRIGGERS;

SELECT * FROM vw_kpi_summary;










use banking_analytics1






    