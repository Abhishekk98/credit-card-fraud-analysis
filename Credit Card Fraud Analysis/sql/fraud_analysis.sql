/* =====================================================================
   CREDIT CARD FRAUD ANALYSIS - SQL SERVER (T-SQL)
   Run in SSMS, one block at a time (select the block, press F5).
   Input : txn_final.csv (8,000 rows), cust_final.csv (1,000 rows)
   Expected numbers are written next to the queries - if yours differ,
   something went wrong in loading, so fix that first.
   ===================================================================== */

/* ---------- STEP 1: create database and tables ---------- */
CREATE DATABASE CardFraudDB;
GO
USE CardFraudDB;
GO

CREATE TABLE dbo.cust (
    customer_id   VARCHAR(10) NOT NULL PRIMARY KEY,   -- grain: 1 row = 1 customer
    customer_name VARCHAR(60),
    gender        VARCHAR(10),
    dob           DATE NULL,
    age           INT NULL,
    age_band      VARCHAR(15),
    city          VARCHAR(30),
    signup_date   DATE NULL,
    credit_limit  INT NULL,
    credit_band   VARCHAR(15)
);

CREATE TABLE dbo.txn (
    txn_id          VARCHAR(10) NOT NULL PRIMARY KEY, -- grain: 1 row = 1 transaction
    customer_id     VARCHAR(10),
    txn_datetime    DATETIME2(0) NULL,
    txn_date        DATE NULL,
    txn_hour        INT NULL,
    txn_day         VARCHAR(5) NULL,
    txn_month       VARCHAR(10) NULL,
    merchant_name   VARCHAR(40),
    category        VARCHAR(20),
    amount          DECIMAL(12,2) NULL,
    amount_flag     VARCHAR(10),
    payment_channel VARCHAR(10),
    city            VARCHAR(30),
    status          VARCHAR(10),
    is_fraud        TINYINT,
    amt_band        VARCHAR(12),
    time_bucket     VARCHAR(20),
    has_time        VARCHAR(3),
    customer_known  VARCHAR(8),
    age_band        VARCHAR(15),
    credit_band     VARCHAR(15),
    city_mismatch   VARCHAR(8),
    is_outlier      VARCHAR(8)
);
GO

/* ---------- STEP 2: load the CSV files ----------
   OPTION A (script): change the folder path, then run.
   If you get "Access is denied" / "Operating system error 5", use OPTION B.
   OPTION B (wizard): right-click CardFraudDB > Tasks > Import Flat File...
        choose the CSV > table name txn (or cust), schema dbo > Next >
        on "Modify Columns" set the data types to match the tables above > Finish.
        (If the tables already exist, drop them first or use different names.)
*/
BULK INSERT dbo.cust
FROM 'C:\FraudProject\cust_final.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', KEEPNULLS, TABLOCK);

BULK INSERT dbo.txn
FROM 'C:\FraudProject\txn_final.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', KEEPNULLS, TABLOCK);
GO

/* ---------- STEP 3: reconcile with Excel (ALWAYS do this) ---------- */
-- Expected: 8000 | 1000 | 182 | 29788933.71
SELECT (SELECT COUNT(*) FROM dbo.txn)           AS txn_rows,
       (SELECT COUNT(*) FROM dbo.cust)          AS cust_rows,
       (SELECT SUM(is_fraud) FROM dbo.txn)      AS fraud_txns,
       (SELECT SUM(amount) FROM dbo.txn)        AS total_valid_amount;

-- Data quality: blanks are expected only where the data was invalid
SELECT SUM(CASE WHEN amount   IS NULL THEN 1 ELSE 0 END) AS null_amount,      -- expect 68
       SUM(CASE WHEN txn_hour IS NULL THEN 1 ELSE 0 END) AS null_hour,        -- expect 650
       SUM(CASE WHEN txn_date IS NULL THEN 1 ELSE 0 END) AS null_date         -- expect 10
FROM dbo.txn;
GO

/* ---------- STEP 4: analysis queries ----------
   Fraud rate = fraud transactions / all transactions (use rate, not count). */

-- Q1. Headline KPIs                         expect 8000 | 182 | 2.28 | ~3.07M fraud amount
SELECT COUNT(*)                                        AS total_txns,
       SUM(is_fraud)                                   AS fraud_txns,
       ROUND(100.0 * SUM(is_fraud) / COUNT(*), 2)      AS fraud_rate_pct,
       SUM(amount)                                     AS total_amount,
       SUM(CASE WHEN is_fraud = 1 THEN amount END)     AS fraud_amount,
       AVG(CASE WHEN is_fraud = 1 THEN amount END)     AS avg_fraud_ticket,
       AVG(CASE WHEN is_fraud = 0 THEN amount END)     AS avg_genuine_ticket
FROM dbo.txn;

-- Q2. Fraud by channel                      expect Online 3435 / 121 / 3.52, POS 3925 / 51, ATM 640 / 10
SELECT payment_channel, COUNT(*) AS txns, SUM(is_fraud) AS fraud_txns,
       ROUND(100.0 * SUM(is_fraud) / COUNT(*), 2) AS fraud_rate_pct
FROM dbo.txn
GROUP BY payment_channel
ORDER BY fraud_rate_pct DESC;

-- Q3. Fraud by category
SELECT category, COUNT(*) AS txns, SUM(is_fraud) AS fraud_txns,
       ROUND(100.0 * SUM(is_fraud) / COUNT(*), 2) AS fraud_rate_pct
FROM dbo.txn
GROUP BY category
ORDER BY fraud_rate_pct DESC;

-- Q4. Fraud by hour (only rows where time is known)
SELECT txn_hour, COUNT(*) AS txns, SUM(is_fraud) AS fraud_txns,
       ROUND(100.0 * SUM(is_fraud) / COUNT(*), 2) AS fraud_rate_pct
FROM dbo.txn
WHERE txn_hour IS NOT NULL
GROUP BY txn_hour
ORDER BY txn_hour;

-- Q5. Night vs rest of the day              expect Night (0-4): 268 txns / 26 fraud / 9.70%
SELECT time_bucket, COUNT(*) AS txns, SUM(is_fraud) AS fraud_txns,
       ROUND(100.0 * SUM(is_fraud) / COUNT(*), 2) AS fraud_rate_pct
FROM dbo.txn
GROUP BY time_bucket
ORDER BY fraud_rate_pct DESC;

-- Q6. Fraud by amount band                  expect 20K+: 216 txns / 39 fraud / 18.06%
SELECT amt_band, COUNT(*) AS txns, SUM(is_fraud) AS fraud_txns,
       ROUND(100.0 * SUM(is_fraud) / COUNT(*), 2) AS fraud_rate_pct
FROM dbo.txn
GROUP BY amt_band
ORDER BY amt_band;

-- Q7. Monthly trend with change vs previous month and running total (window functions)
WITH m AS (
    SELECT txn_month, COUNT(*) AS txns, SUM(is_fraud) AS fraud_txns
    FROM dbo.txn
    WHERE txn_month IS NOT NULL
    GROUP BY txn_month
)
SELECT txn_month, txns, fraud_txns,
       ROUND(100.0 * fraud_txns / txns, 2)                       AS fraud_rate_pct,
       LAG(fraud_txns) OVER (ORDER BY txn_month)                 AS prev_month_fraud,
       fraud_txns - LAG(fraud_txns) OVER (ORDER BY txn_month)    AS change_vs_prev,
       SUM(fraud_txns) OVER (ORDER BY txn_month
                             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_fraud
FROM m
ORDER BY txn_month;

-- Q8. City mismatch (txn city vs home city)  expect Yes: 874 txns / 35 fraud / 4.00%
SELECT city_mismatch, COUNT(*) AS txns, SUM(is_fraud) AS fraud_txns,
       ROUND(100.0 * SUM(is_fraud) / COUNT(*), 2) AS fraud_rate_pct
FROM dbo.txn
GROUP BY city_mismatch
ORDER BY fraud_rate_pct DESC;

-- Q9. JOIN practice: fraud rate by customer HOME city
SELECT c.city AS home_city, COUNT(*) AS txns, SUM(t.is_fraud) AS fraud_txns,
       ROUND(100.0 * SUM(t.is_fraud) / COUNT(*), 2) AS fraud_rate_pct
FROM dbo.txn t
JOIN dbo.cust c ON c.customer_id = t.customer_id      -- INNER JOIN drops UNKNOWN / orphan IDs
GROUP BY c.city
ORDER BY fraud_rate_pct DESC;

-- Q10. Orphan check: transactions whose customer is not in the customers table   expect 15
SELECT COUNT(*) AS orphan_txns
FROM dbo.txn t
LEFT JOIN dbo.cust c ON c.customer_id = t.customer_id
WHERE c.customer_id IS NULL AND t.customer_id <> 'UNKNOWN';

-- Q11. Top 10 customers by fraud transactions (JOIN + aggregation)
SELECT TOP 10 t.customer_id, c.customer_name, COUNT(*) AS txns,
       SUM(t.is_fraud) AS fraud_txns,
       SUM(CASE WHEN t.is_fraud = 1 THEN t.amount END) AS fraud_amount
FROM dbo.txn t
LEFT JOIN dbo.cust c ON c.customer_id = t.customer_id
WHERE t.customer_id <> 'UNKNOWN'
GROUP BY t.customer_id, c.customer_name
HAVING SUM(t.is_fraud) >= 1
ORDER BY fraud_txns DESC, fraud_amount DESC;

-- Q12. Merchants with enough volume (HAVING) ranked by fraud rate
SELECT TOP 10 merchant_name, COUNT(*) AS txns, SUM(is_fraud) AS fraud_txns,
       ROUND(100.0 * SUM(is_fraud) / COUNT(*), 2) AS fraud_rate_pct
FROM dbo.txn
GROUP BY merchant_name
HAVING COUNT(*) >= 100
ORDER BY fraud_rate_pct DESC;

-- Q13. Top 3 categories by fraud count inside each channel (CTE + ROW_NUMBER)
WITH x AS (
    SELECT payment_channel, category, COUNT(*) AS txns, SUM(is_fraud) AS fraud_txns
    FROM dbo.txn
    WHERE category <> 'Unknown'
    GROUP BY payment_channel, category
), r AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY payment_channel ORDER BY fraud_txns DESC) AS rn
    FROM x
)
SELECT payment_channel, category, txns, fraud_txns,
       ROUND(100.0 * fraud_txns / txns, 2) AS fraud_rate_pct
FROM r
WHERE rn <= 3
ORDER BY payment_channel, rn;

-- Q14. Rule simulation: precision / recall / % of genuine customers disturbed
--      expect R2: flagged 686, caught 64 | R4: flagged 27, caught 8
WITH r AS (
    SELECT 'R1 amount >= 20000' AS rule_name, COUNT(*) AS flagged, SUM(is_fraud) AS caught
    FROM dbo.txn WHERE amount >= 20000
    UNION ALL
    SELECT 'R2 online and amount >= 5000', COUNT(*), SUM(is_fraud)
    FROM dbo.txn WHERE payment_channel = 'Online' AND amount >= 5000
    UNION ALL
    SELECT 'R3 online and hour 0-4', COUNT(*), SUM(is_fraud)
    FROM dbo.txn WHERE payment_channel = 'Online' AND txn_hour <= 4
    UNION ALL
    SELECT 'R4 online, 5000+, hour 0-4', COUNT(*), SUM(is_fraud)
    FROM dbo.txn WHERE payment_channel = 'Online' AND amount >= 5000 AND txn_hour <= 4
    UNION ALL
    SELECT 'R5 risky category and 5000+', COUNT(*), SUM(is_fraud)
    FROM dbo.txn WHERE category IN ('Travel','Electronics','Jewellery') AND amount >= 5000
)
SELECT rule_name, flagged, caught AS fraud_caught, flagged - caught AS genuine_hit,
       ROUND(100.0 * caught / flagged, 1)                                   AS precision_pct,
       ROUND(100.0 * caught / (SELECT SUM(is_fraud) FROM dbo.txn), 1)       AS recall_pct,
       ROUND(100.0 * (flagged - caught) /
             (SELECT COUNT(*) - SUM(is_fraud) FROM dbo.txn), 2)             AS genuine_hit_pct
FROM r
ORDER BY recall_pct DESC;

-- Q15. Customers with 2 or more fraud transactions (repeat victims)
SELECT customer_id, SUM(is_fraud) AS fraud_txns
FROM dbo.txn
WHERE customer_id <> 'UNKNOWN'
GROUP BY customer_id
HAVING SUM(is_fraud) >= 2
ORDER BY fraud_txns DESC;
GO

/* ---------- STEP 5: view for Power BI ---------- */
CREATE VIEW dbo.vw_fraud_txn AS
SELECT t.*, c.gender, c.city AS home_city, c.credit_limit
FROM dbo.txn t
LEFT JOIN dbo.cust c ON c.customer_id = t.customer_id;
GO
SELECT TOP 5 * FROM dbo.vw_fraud_txn;
