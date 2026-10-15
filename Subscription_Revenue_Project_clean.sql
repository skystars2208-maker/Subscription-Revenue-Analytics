/* ==========================================================
   PROJECT : Subscription Revenue & Cohort Analytics
   TOOL    : MySQL Workbench (MySQL 8)
   DATA    : 5,000 customers, signups from Jan 2022 to Dec 2024
   ========================================================== */
/* ==========================================================
   SECTION 1: CREATE THE DATABASE AND THE RAW TABLE
   ========================================================== */
CREATE DATABASE subscription_project;
USE subscription_project;
CREATE TABLE subscriptions_raw (
    customer_id         VARCHAR(20),
    signup_date         VARCHAR(20),
    cancellation_date   VARCHAR(20),
    plan_type           VARCHAR(20),
    monthly_revenue     INT,
    payment_status      VARCHAR(20),
    acquisition_channel VARCHAR(30),
    region              VARCHAR(30)
);
-- >>> IMPORT THE CSV NOW 
-- Quick check afterwards: SELECT COUNT(*) FROM subscriptions_raw;  -- should be 5000
/* ==========================================================
   SECTION 2: CONVERT TEXT DATES INTO REAL DATES
   ========================================================== */
CREATE TABLE subscriptions AS
SELECT
    customer_id,
    STR_TO_DATE(signup_date, '%d-%m-%Y')                      AS signup_date,
    STR_TO_DATE(NULLIF(cancellation_date, ''), '%d-%m-%Y')    AS cancellation_date,
    plan_type,
    monthly_revenue,
    payment_status,
    acquisition_channel,
    region
FROM subscriptions_raw;
/* ==========================================================
   SECTION 3: LIST OF MONTH-END DATES (36 MONTHS)
   ========================================================== */
CREATE TABLE month_list AS
WITH RECURSIVE months AS (
    SELECT DATE('2022-01-31') AS month_end                              -- start
    UNION ALL
    SELECT LAST_DAY(DATE_ADD(month_end, INTERVAL 1 MONTH))              -- next month-end
    FROM months
    WHERE month_end < '2024-12-31'                                      -- stop here
)
SELECT month_end FROM months;
/* ==========================================================
   SECTION 4: MRR, ARR AND ACTIVE CUSTOMERS PER MONTH
   ========================================================== */
CREATE TABLE monthly_mrr AS
SELECT
    m.month_end,
    COUNT(s.customer_id)         AS active_customers,
    SUM(s.monthly_revenue)       AS mrr,
    SUM(s.monthly_revenue) * 12  AS arr
FROM month_list m
JOIN subscriptions s
    ON  s.signup_date <= m.month_end
    AND (s.cancellation_date IS NULL OR s.cancellation_date > m.month_end)
GROUP BY m.month_end
ORDER BY m.month_end;
/* ==========================================================
   SECTION 5: CHURNED CUSTOMERS PER MONTH
   ========================================================== */
CREATE TABLE monthly_churn AS
SELECT
    m.month_end,
    COUNT(s.customer_id) AS churned_customers
FROM month_list m
LEFT JOIN subscriptions s
    ON  s.cancellation_date >  LAST_DAY(DATE_SUB(m.month_end, INTERVAL 1 MONTH))
    AND s.cancellation_date <= m.month_end
GROUP BY m.month_end
ORDER BY m.month_end;
/* ==========================================================
   SECTION 6: ONE FINAL TABLE WITH ALL MONTHLY METRICS
   ========================================================== */
CREATE TABLE monthly_metrics AS
SELECT
    r.month_end,
    r.active_customers,
    r.mrr,
    r.arr,
    ROUND(r.mrr / r.active_customers, 2)                                   AS arpu,
    c.churned_customers,
    p.active_customers                                                     AS starting_customers,
    ROUND(c.churned_customers / p.active_customers * 100, 2)               AS churn_rate_pct
FROM monthly_mrr r
JOIN monthly_churn c
    ON c.month_end = r.month_end
LEFT JOIN monthly_mrr p
    ON p.month_end = LAST_DAY(DATE_SUB(r.month_end, INTERVAL 1 MONTH))
ORDER BY r.month_end;

-- >>> EXPORT TO EXCEL (sheet: Monthly_Metrics):
SELECT * FROM monthly_metrics;
/* ==========================================================
   SECTION 7: LTV (LIFETIME VALUE OF ONE CUSTOMER)
   ========================================================== */
SELECT
    ROUND(AVG(arpu), 2)                                     AS avg_arpu,
    ROUND(AVG(churn_rate_pct), 2)                           AS avg_churn_pct,
    ROUND(100 / AVG(churn_rate_pct), 1)                     AS avg_lifetime_months,
    ROUND(AVG(arpu) / (AVG(churn_rate_pct) / 100), 2)       AS ltv
FROM monthly_metrics;
/* ==========================================================
   SECTION 8: SEGMENT SUMMARY (PLAN, CHANNEL, REGION)
   ========================================================== */
-- 8A. By plan type    >>> EXPORT TO EXCEL (sheet: Segments)
SELECT
    plan_type,
    COUNT(*)                                                       AS total_customers,
    SUM(cancellation_date IS NULL)                                 AS active_customers,
    SUM(monthly_revenue * (cancellation_date IS NULL))             AS mrr,
    SUM(cancellation_date IS NOT NULL)                             AS cancelled_customers,
    ROUND(SUM(cancellation_date IS NOT NULL) / COUNT(*) * 100, 2)  AS churn_pct
FROM subscriptions
GROUP BY plan_type
ORDER BY mrr DESC;

-- 8B. By acquisition channel    >>> EXPORT TO EXCEL (sheet: Segments)
SELECT
    acquisition_channel,
    COUNT(*)                                                       AS total_customers,
    SUM(cancellation_date IS NULL)                                 AS active_customers,
    SUM(monthly_revenue * (cancellation_date IS NULL))             AS mrr,
    SUM(cancellation_date IS NOT NULL)                             AS cancelled_customers,
    ROUND(SUM(cancellation_date IS NOT NULL) / COUNT(*) * 100, 2)  AS churn_pct
FROM subscriptions
GROUP BY acquisition_channel
ORDER BY mrr DESC;

-- 8C. By region 
SELECT
    region,
    COUNT(*)                                                       AS total_customers,
    SUM(cancellation_date IS NULL)                                 AS active_customers,
    SUM(monthly_revenue * (cancellation_date IS NULL))             AS mrr,
    SUM(cancellation_date IS NOT NULL)                             AS cancelled_customers,
    ROUND(SUM(cancellation_date IS NOT NULL) / COUNT(*) * 100, 2)  AS churn_pct
FROM subscriptions
GROUP BY region
ORDER BY mrr DESC;
/* ==========================================================
   SECTION 9: COHORT RETENTION
   ========================================================== */
CREATE TABLE cohort_base AS
SELECT
    customer_id,
    DATE_FORMAT(signup_date, '%Y-%m')                                              AS cohort_month,
    TIMESTAMPDIFF(MONTH, signup_date, IFNULL(cancellation_date, '2024-12-31'))     AS months_stayed,
    TIMESTAMPDIFF(MONTH, signup_date, '2024-12-31')                                AS months_observed
FROM subscriptions;
CREATE TABLE cohort_retention AS
SELECT
    cohort_month,
    COUNT(*) AS cohort_size,
    ROUND(SUM(months_stayed >= 1)  / NULLIF(SUM(months_observed >= 1), 0)  * 100, 1) AS m1,
    ROUND(SUM(months_stayed >= 3)  / NULLIF(SUM(months_observed >= 3), 0)  * 100, 1) AS m3,
    ROUND(SUM(months_stayed >= 6)  / NULLIF(SUM(months_observed >= 6), 0)  * 100, 1) AS m6,
    ROUND(SUM(months_stayed >= 12) / NULLIF(SUM(months_observed >= 12), 0) * 100, 1) AS m12
FROM cohort_base
GROUP BY cohort_month
ORDER BY cohort_month;

-- >>> EXPORT TO EXCEL (sheet: Cohort_Retention), then add the colour-scale heatmap:
SELECT * FROM cohort_retention;
