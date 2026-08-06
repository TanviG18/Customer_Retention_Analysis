CREATE DATABASE IF NOT EXISTS telco_churn_analysis;
USE telco_churn_analysis;
 
CREATE TABLE IF NOT EXISTS churn_data (
  customerID VARCHAR(20),
  gender VARCHAR(10),
  SeniorCitizen TINYINT,
  Partner VARCHAR(5),
  Dependents VARCHAR(5),
  tenure INT,
  PhoneService VARCHAR(5),
  MultipleLines VARCHAR(25),
  InternetService VARCHAR(15),
  OnlineSecurity VARCHAR(25),
  OnlineBackup VARCHAR(25),
  DeviceProtection VARCHAR(25),
  TechSupport VARCHAR(25),
  StreamingTV VARCHAR(25),
  StreamingMovies VARCHAR(25),
  Contract VARCHAR(20),
  PaperlessBilling VARCHAR(5),
  PaymentMethod VARCHAR(30),
  MonthlyCharges DECIMAL(8,2),
  TotalCharges DECIMAL(10,2),
  Churn VARCHAR(5)
);
SHOW TABLES;
SELECT * FROM churn_data LIMIT 10;


-- Overall churn rate
SELECT
  COUNT(*) AS total_customers,
  SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END) AS churned_customers,
  ROUND(SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS churn_rate_pct
FROM churn_data;

-- Churn rate by contract type
SELECT
  Contract,
  COUNT(*) AS total_customers,
  SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END) AS churned,
  ROUND(SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS churn_rate_pct
FROM churn_data
GROUP BY Contract
ORDER BY churn_rate_pct DESC;

-- Churn rate by tenure cohort
WITH tenure_cohorts AS (
  SELECT *,
    CASE
      WHEN tenure <= 12 THEN '1. 0-12 months'
      WHEN tenure <= 24 THEN '2. 13-24 months'
      WHEN tenure <= 48 THEN '3. 25-48 months'
      ELSE                   '4. 49+ months'
    END AS tenure_cohort
  FROM churn_data
)
SELECT
  tenure_cohort,
  COUNT(*) AS total_customers,
  SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END) AS churned,
  ROUND(SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS churn_rate_pct,
  ROUND(AVG(MonthlyCharges), 2) AS avg_monthly_charges
FROM tenure_cohorts
GROUP BY tenure_cohort
ORDER BY tenure_cohort;

-- Churn rate by internet service type
SELECT
  InternetService,
  COUNT(*) AS total_customers,
  SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END) AS churned,
  ROUND(SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS churn_rate_pct
FROM churn_data
GROUP BY InternetService
ORDER BY churn_rate_pct DESC;

-- Compound risk: Tech Support x Online Security
SELECT
  TechSupport,
  OnlineSecurity,
  COUNT(*) AS total_customers,
  SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END) AS churned,
  ROUND(SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS churn_rate_pct
FROM churn_data
WHERE TechSupport <> 'No internet service' AND OnlineSecurity <> 'No internet service'
GROUP BY TechSupport, OnlineSecurity
ORDER BY churn_rate_pct DESC;

-- Churn rate by payment method
SELECT
  PaymentMethod,
  COUNT(*) AS total_customers,
  SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END) AS churned,
  ROUND(SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS churn_rate_pct
FROM churn_data
GROUP BY PaymentMethod
ORDER BY churn_rate_pct DESC;

-- Monthly charges & tenure: churned vs. retained
SELECT
  Churn,
  COUNT(*) AS total_customers,
  ROUND(AVG(MonthlyCharges), 2) AS avg_monthly_charges,
  ROUND(AVG(tenure), 2) AS avg_tenure_months
FROM churn_data
GROUP BY Churn;

-- Revenue at risk from churned customers
SELECT
  SUM(CASE WHEN Churn='Yes' THEN MonthlyCharges ELSE 0 END) AS mrr_lost_from_churn,
  ROUND(SUM(CASE WHEN Churn='Yes' THEN MonthlyCharges ELSE 0 END) * 12, 2) AS annualized_revenue_lost,
  ROUND(SUM(CASE WHEN Churn='Yes' THEN MonthlyCharges ELSE 0 END) * 100.0
    / (SELECT SUM(MonthlyCharges) FROM churn_data), 2) AS pct_of_total_mrr
FROM churn_data;

-- High-value at-risk customers
SELECT customerID, tenure, MonthlyCharges, Contract, PaymentMethod
FROM churn_data
WHERE Churn = 'Yes'
  AND tenure >= (SELECT AVG(tenure) FROM churn_data)
  AND MonthlyCharges >= (SELECT AVG(MonthlyCharges) FROM churn_data)
ORDER BY MonthlyCharges DESC, tenure DESC
LIMIT 50;

-- Monthly-charge quartiles via window function
WITH charge_quartiles AS (
  SELECT *,
    NTILE(4) OVER (ORDER BY MonthlyCharges) AS charge_quartile
  FROM churn_data
)
SELECT
  charge_quartile,
  COUNT(*) AS total_customers,
  ROUND(MIN(MonthlyCharges), 2) AS min_charge,
  ROUND(MAX(MonthlyCharges), 2) AS max_charge,
  SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END) AS churned,
  ROUND(SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS churn_rate_pct
FROM charge_quartiles
GROUP BY charge_quartile
ORDER BY charge_quartile;

-- Composite risk-scoring model: give each customer 1 point per major risk
-- factor present, then check how much of total churn the highest-risk
-- 30% of customers account for.
WITH scored AS (
  SELECT
    customerID,
    Churn,
    (CASE WHEN Contract = 'Month-to-month' THEN 1 ELSE 0 END) +
    (CASE WHEN PaymentMethod = 'Electronic check' THEN 1 ELSE 0 END) +
    (CASE WHEN TechSupport = 'No' THEN 1 ELSE 0 END) +
    (CASE WHEN OnlineSecurity = 'No' THEN 1 ELSE 0 END) +
    (CASE WHEN tenure <= 12 THEN 1 ELSE 0 END) AS risk_score
  FROM churn_data
),
ranked AS (
  SELECT *, NTILE(10) OVER (ORDER BY risk_score DESC) AS risk_decile
  FROM scored
)
SELECT
  COUNT(*) AS customers_in_top30pct,
  SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) AS churned_in_top30pct,
  ROUND(
    SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) * 100.0
    / (SELECT SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) FROM churn_data), 2
  ) AS pct_of_total_churn_captured
FROM ranked
WHERE risk_decile <= 3;
