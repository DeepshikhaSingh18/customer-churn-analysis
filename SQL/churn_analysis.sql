-- ============================================
-- PROJECT  : Customer Churn Analysis
-- DATABASE : SQL Server (SSMS)
-- AUTHOR   : Your Name
-- DATE     : 2025
-- ============================================

-- -----------------------------------------------
-- SECTION 1: Database & Table Setup
-- SECTION 2: Data Exploration
-- ROW COUNT
SELECT 
	COUNT(*) AS total_records
FROM TelcoCustomer

-- PREVIEW DATA
SELECT TOP 10
	*
FROM TelcoCustomer

-- CHURN DISRIBUTION - How many customers left and what % is left or stayed
SELECT 
	Churn,
	COUNT(*) as total,
	ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(),2) AS Percentage
FROM TelcoCustomer
GROUP BY Churn


-- -----------------------------------------------
-- SECTION 3: Data Cleaning
-- -----------------------------------------------

--Check for Nulls across key columns
SELECT
	SUM(CASE WHEN customerID IS NULL THEN 1 ELSE 0 END) AS null_customerID,
	SUM(CASE WHEN tenure IS NULL THEN 1 ELSE 0 END) AS null_tenure,
	SUM(CASE WHEN MonthlyCharges IS NULL THEN 1 ELSE 0 END) AS null_MonthlyCharges,
	SUM(CASE WHEN TotalCharges IS NULL OR TotalCharges = '' THEN 1 ELSE 0 END) AS blank_TotalCharges,
    SUM(CASE WHEN Churn IS NULL THEN 1 ELSE 0 END) AS null_Churn
FROM TelcoCustomer;

-- Fix Null values on TotalCharges column
ALTER TABLE TelcoCustomer ADD TotalCharges_Clean DECIMAL(10,2);
-- CONVERT blank to NULL, then cast to Decimal
UPDATE TelcoCustomer
SET TotalCharges_Clean = CASE
	WHEN TotalCharges = '' THEN NULL
	ELSE CAST(TotalCharges AS DECIMAL(10,2))
END;

-- Fill NULL totalcharges with tenure * MonthlyChages --- LOGICAL IMPUTATION
UPDATE TelcoCustomer
SET TotalCharges_Clean = tenure * MonthlyCharges
WHERE TotalCharges_Clean IS NULL;

-- -----------------------------------------------
-- SECTION 4: Business Insight Queries
-- -----------------------------------------------

-- USE CASE 1: Churn Rate by Contract type

SELECT 
	Contract,
	COUNT(*) AS total_customers,
	SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) AS churned,
	ROUND(SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS churn_rate_percentage
FROM TelcoCustomer
GROUP BY Contract
ORDER BY churn_rate_percentage DESC;

-- USE CASE 2 - Churn rate by tenure bucket

WITH tenure_buckets AS (
	SELECT *,
		CASE
			WHEN tenure BETWEEN 0 AND 12 THEN '0-12 Months'
			WHEN tenure BETWEEN 13 AND 24 THEN '13-24 Months'
			WHEN tenure BETWEEN 25 AND 48 THEN '25-48 Months'
			ELSE '49+ Months'
		END AS tenure_group
	FROM TelcoCustomer
)

SELECT 
	tenure_group,
	COUNT(*) AS total_customers,
	SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) AS churned,
	ROUND(SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS churn_rate_percentage
FROM tenure_buckets
GROUP BY tenure_group
ORDER BY churn_rate_percentage DESC;

-- USE CASE 3 - Revenure lost due to churn
SELECT
	Churn,
	ROUND(SUM(MonthlyCharges), 2) AS total_monthly_revenure,
	ROUND(AVG(MonthlyCharges), 2) AS avg_monthly_charges,
	ROUND(SUM(TotalCharges_Clean), 2) AS total_lifetime_revenure
FROM TelcoCustomer
GROUP BY Churn;

-- USE CASE 4 - High risk customer segments (short tenure + high charges + month-to-month)

SELECT 
	customerID, 
	tenure,
	MonthlyCharges,
	Contract,
	Churn,
	RANK() OVER(ORDER BY MonthlyCharges DESC) AS soend_rank
FROM TelcoCustomer
WHERE Contract = 'Month-to-month'
	AND tenure < 12
	AND MonthlyCharges > 70
ORDER BY MonthlyCharges DESC;