-----------------------------------
-- A. Customer Nodes Exploration --
-----------------------------------

-- 1.How many unique nodes are there on the Data Bank system?

SELECT COUNT(DISTINCT node_id) unique_node
FROM customer_nodes;
GO

-- 2.What is the number of nodes per region?
SELECT c.region_id, COUNT(node_id) node_count
FROM customer_nodes c
JOIN regions r 
ON r.region_id = c.region_id
GROUP BY c.region_id
ORDER BY c.region_id;
GO

--3.How many customers are allocated to each region?
SELECT c.region_id, COUNT(customer_id) customer_count
FROM customer_nodes c
JOIN regions r 
ON r.region_id = c.region_id
GROUP BY c.region_id
ORDER BY c.region_id;
GO

--4.How many days on average are customers reallocated to a different node?
WITH cte AS (
  SELECT 
    customer_id, 
	node_id, 
    DATEDIFF(DAY, start_date, end_date) AS day_diff
  FROM customer_nodes
  WHERE end_date != '9999-12-31'
  GROUP BY customer_id, node_id, start_date, end_date
  ),
innerCte AS (
  SELECT 
    customer_id, node_id, SUM(day_diff) AS sum_diff
  FROM cte
  GROUP BY customer_id, node_id)

SELECT 
  AVG(sum_diff) AS avg_d
FROM innerCte;

-- 5.What is the median, 80th and 95th percentile for this same reallocation days metric for each region?
WITH cte AS (
	SELECT
		r.region_id,
		DATEDIFF(DAY, start_date, end_date) AS day_diff
	FROM customer_nodes c
	JOIN regions r 
	ON r.region_id = c.region_id
	WHERE end_date != '9999-12-31'
	GROUP BY start_date, end_date, r.region_id
  )

SELECT 
	DISTINCT
	region_id,
	percentile_cont(0.5) within group(order by day_diff) over (partition by region_id) as Meadian,
	percentile_cont(0.8) within group(order by day_diff) over (partition by region_id) as percentile_cont_80,
	percentile_cont(0.95) within group(order by day_diff) over (partition by region_id) as percentile_cont_95
FROM cte;
GO

------------------------------
-- B. Customer Transactions --
------------------------------

-- 1.What is the unique count and total amount for each transaction type?
SELECT 
	txn_type, SUM(txn_amount) total_amount
FROM customer_transactions
GROUP BY txn_type;
GO

-- 2.What is the average total historical deposit counts and amounts for all customers?
WITH cte
AS (SELECT
	customer_id,
	COUNT(customer_id) dep_count,
	SUM(txn_amount) total_amt
FROM customer_transactions
WHERE txn_type = 'deposit'
GROUP BY customer_id)

SELECT 
	AVG(dep_count) avg_dep_count,
	AVG(total_amt) avg_total_amt
FROM cte;
GO

-- 3.For each month - how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?
WITH cte_customer AS (
	SELECT
		DATEPART(MONTH, txn_date) AS Month,
		customer_id,
		SUM(CASE WHEN txn_type = 'deposit' THEN 1 ELSE 0 END) AS deposit_count,
		SUM(CASE WHEN txn_type = 'purchase' THEN 1 ELSE 0 END) AS purchase_count,
		SUM(CASE WHEN txn_type = 'withdrawal' THEN 1 ELSE 0 END) AS withdrawal_count
	FROM customer_transactions
	GROUP BY
		DATEPART(MONTH, txn_date),
		customer_id
)
SELECT 
	Month,
	COUNT(customer_id) AS cust_count
FROM cte_customer
WHERE deposit_count > 1 AND (purchase_count >= 1 OR withdrawal_count >= 1)
GROUP BY 
	Month
ORDER BY Month;
GO

-- 4.What is the closing balance for each customer at the end of the month?
DROP TABLE IF EXISTS #closing_bal;
GO
WITH cte AS
  (SELECT customer_id,
          month(txn_date) AS txn_month,
          SUM(CASE
                  WHEN txn_type = 'deposit' THEN txn_amount
                  ELSE -txn_amount
              END) AS txn_amt_month
   FROM customer_transactions
   GROUP BY customer_id,
            month(txn_date))
SELECT customer_id, 
       txn_month,
       txn_amt_month,
       sum(txn_amt_month) over(PARTITION BY customer_id ORDER BY txn_month) AS final_month_balance
INTO #closing_bal
FROM cte;
GO

SELECT * FROM #closing_bal
ORDER BY customer_id;
GO

-- 5.What is the percentage of customers who increase their closing balance by more than 5%?
WITH cte
AS (
	SELECT 
		*,
		ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY txn_month) r
	FROM #closing_bal),
innercte
As (
	SELECT
	customer_id,
	final_month_balance f
	FROM cte
	WHERE r = 1),
innerCte2
AS (
	SELECT 
		*,
		ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY txn_month DESC) r
	FROM #closing_bal),
innercte3
AS (
	SELECT
	customer_id,
	final_month_balance l
	FROM innercte2
	WHERE r = 1),
final_cte
AS (SELECT 
	a.customer_id,
	f,
	l,
	(CASE
		WHEN (l / f) * 100 > 5
			THEN 1
		ELSE 0
	END) bool_perc
FROM innercte a
JOIN innerCte3 b
ON a.customer_id = b.customer_id)

SELECT CAST(CAST(SUM(bool_perc) AS NUMERIC(10, 2))/COUNT(DISTINCT customer_id) * 100 AS NUMERIC(10, 2)) cust_perc
FROM final_cte;
GO

----------------------------------
-- C. Data Allocation Challenge --
----------------------------------
-- OPTION 1
WITH cte AS
  (SELECT *,
          last_value(final_month_balance) over(PARTITION BY customer_id, txn_month
                                                    ORDER BY txn_month) AS month_end_balance
   FROM #closing_bal),
     innerCte AS
  (SELECT customer_id,
          txn_month,
          month_end_balance
   FROM cte
   GROUP BY customer_id,
            txn_month,
			month_end_balance),
innerCte2
AS (
	SELECT 
		*, 
		(CASE	
			WHEN month_end_balance > 0
				THEN month_end_balance
			ELSE
				0
		END) AS mod_month_end_balance
	FROM innerCte)
SELECT txn_month,
       sum(mod_month_end_balance) AS data
FROM innerCte2
GROUP BY txn_month
ORDER BY txn_month;
GO

-- OPTION 2
WITH cte AS
  (SELECT customer_id,
          txn_month,
          avg(final_month_balance) over(PARTITION BY customer_id) AS avg_bal
   FROM #closing_bal
   GROUP BY customer_id,
            txn_month,
			final_month_balance)
SELECT txn_month,
       round(sum(avg_bal), 2) AS data
FROM cte
GROUP BY txn_month
ORDER BY txn_month;

-- Option 3
SELECT txn_month,
       SUM(final_month_balance) AS data
FROM #closing_bal
GROUP BY txn_month
ORDER BY txn_month;
GO

------------------------
-- D. Extra Challenge --
------------------------

/*
To calculate the data growth using an interest calculation, we can use the following formula:

data growth = (initial data allocation) * (1 + (interest rate / 365) * (number of days in a month))

Assuming an annual interest rate of 6% and a 30-day month, the calculation would be as follows:

data growth = (initial data allocation) * (1 + (0.06 / 365) * 30)
This calculation represents a non-compounding interest calculation.
To calculate the daily compounding interest, we can use the formula:
data growth = (initial data allocation) * (1 + (interest rate / 365))^(number of days in a month)

With the same parameters as above, the calculation would be:
data growth = (initial data allocation) * (1 + (0.06 / 365))^30

Headline Insights for Marketing:
Data Bank offers daily interest calculation on data allocation, just like a savings account.
With a 6% annual interest rate, customers can expect their data allocation to grow every month.
Non-compounding and compounding interest options available for customers to choose from.
Data Bank is dedicated to providing customers with a secure and rewarding data banking experience.

Presentation Slide:

Introduction
	- Explain the purpose of the presentation, which is to provide information about the options for data provisioning at Data Bank.

Non-Compounding Interest Option
	- Explain the formula used to calculate data growth with non-compounding interest.
	- Provide an example calculation with a 6% interest rate and a 30-day month.

Compounding Interest Option
	- Explain the formula used to calculate data growth with compounding interest.
	- Provide an example calculation with a 6% interest rate and a 30-day month.

Headline Insights
	- Highlight the key points from the headline insights section, such as the daily interest calculation, the 6% annual interest rate,
   and the two interest calculation options.
 
Conclusion
	- Summarize the information presented in the presentation and emphasize Data Bank's commitment to providing customers with a secure and rewarding data banking experience. 
*/
-----------------------
-- Extension Request --
-----------------------

/* 
1. Using the outputs generated from the customer node questions, generate a few headline insights 
which Data Bank might use to market it’s world-leading security features to potential investors 
and customers.
*/

SELECT c.region_id, COUNT(node_id) node_count
FROM customer_nodes c
JOIN regions r 
ON r.region_id = c.region_id
GROUP BY c.region_id
ORDER BY c.region_id;
GO

-- From the results we can see cloud data is seperated by each regional area which are given region_id,
-- As data and money is diversified through regions,This random distribution changes frequently to reduce 
-- the risk of hackers getting into Data Bank’s system and stealing customer’s money and data!