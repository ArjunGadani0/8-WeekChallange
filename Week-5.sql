-----------------------------
-- 1. Data Cleansing Steps --
-----------------------------
DROP TABLE IF EXISTS clean_weekly_sales;
GO

WITH cte
AS (
	SELECT
		*,
		CONVERT(DATE, week_date, 3) week_d
	FROM weekly_sales)

SELECT 
	week_d,
	DATEPART(WEEK, week_d) week_number,
	DATEPART(MONTH, week_d) month_number,
	DATEPART(YEAR, week_d) calendar_year,
	segment,
	(CASE
		WHEN segment IN ('C1', 'F1')
			THEN 'Young Adults'
		WHEN segment IN ('C2', 'F2')
			THEN 'Middle Aged'
		WHEN segment IN ('C3', 'F3', 'C4')
			THEN 'Retirees'
		ELSE
			'unknown'
	END) age_band,
	(CASE
		WHEN segment LIKE 'C%'
			THEN 'Couples'
		WHEN segment LIKE 'F%'
			THEN 'Families'
		ELSE
			'unknown'
	END) demographic,
	CAST(ROUND((CAST(sales AS NUMERIC(10, 2)) / transactions) * 100, 2) AS NUMERIC(10, 2)) avg_transaction,
	transactions,
	CAST(sales AS BIGINT) sales, 
	region,
	platform,
	customer_type
INTO clean_weekly_sales
FROM cte;
GO

SELECT * FROM clean_weekly_sales;
GO
-------------------------
-- 2. Data Exploration --
-------------------------
-- 1.What day of the week is used for each week_date value?
SELECT 
	DISTINCT
	DATENAME(WEEKDAY, week_d) day_name
FROM clean_weekly_sales;
GO

-- 2.What range of week numbers are missing from the dataset?
-- 1-12 AND 37-53
SELECT DISTINCT week_number
FROM clean_weekly_sales
ORDER BY week_number ASC;

-- 3.How many total transactions were there for each year in the dataset?
SELECT 
	calendar_year,
	COUNT(transactions) count_trans
FROM clean_weekly_sales
GROUP BY calendar_year;
GO

-- 4.What is the total sales for each region for each month?
SELECT 
	region,
	month_number,
	SUM(CAST(sales AS BIGINT)) sales_per_region_month
FROM clean_weekly_sales
GROUP BY region, month_number;
GO

-- 5.What is the total count of transactions for each platform?
SELECT 
	platform,
	SUM(transactions) count_trans
FROM clean_weekly_sales
GROUP BY platform;
GO

-- 6.What is the percentage of sales for Retail vs Shopify for each month?
WITH sales_cte AS
  (SELECT calendar_year,
          month_number,
          SUM(CASE
                  WHEN platform = 'Retail' THEN sales
              END) retail_sales,
		  SUM(CASE
                  WHEN platform = 'Shopify' THEN sales
              END) shopify_sales,
          CAST(sum(sales) AS BIGINT) total_sales
   FROM clean_weekly_sales
   GROUP BY calendar_year,
            month_number)
SELECT calendar_year,
       month_number,
       CAST(ROUND(CAST(retail_sales AS NUMERIC(18, 2)) / total_sales * 100, 2) AS NUMERIC(18, 2)) retail_p,
       CAST(ROUND(CAST(shopify_sales AS NUMERIC(18, 2)) / total_sales * 100, 2) AS NUMERIC(18, 2)) shopify_p
FROM sales_cte;

-- 7.What is the percentage of sales by demographic for each year in the dataset?
WITH sales_cte AS
  (SELECT calendar_year,
          region,
          SUM(CASE
                  WHEN platform = 'Retail' THEN sales
              END) retail_sales,
		  SUM(CASE
                  WHEN platform = 'Shopify' THEN sales
              END) shopify_sales,
          CAST(sum(sales) AS BIGINT) total_sales
   FROM clean_weekly_sales
   GROUP BY calendar_year,
            region)
SELECT calendar_year,
       region,
       CAST(ROUND(CAST(retail_sales AS NUMERIC(18, 2)) / total_sales * 100, 2) AS NUMERIC(18, 2)) retail_p,
       CAST(ROUND(CAST(shopify_sales AS NUMERIC(18, 2)) / total_sales * 100, 2) AS NUMERIC(18, 2)) shopify_p
FROM sales_cte;
GO

-- 8.Which age_band and demographic values contribute the most to Retail sales?
SELECT age_band,
       demographic,
       ROUND(100*sum(sales)/
               (SELECT SUM(sales)
                FROM clean_weekly_sales
                WHERE platform='Retail'), 2) AS retail_sales_percentage
FROM clean_weekly_sales
WHERE platform='Retail'
GROUP BY age_band,
       demographic;
GO

-- 9.Can we use the avg_transaction column to find the average transaction size 
-- for each year for Retail vs Shopify? If not - how would you calculate it instead?

--It would give incorrect output to use avg_transaction to find the average transaction size as described below.
SELECT calendar_year,
       platform,
       ROUND(SUM(sales)/SUM(transactions), 2) AS correct_avg,
       ROUND(AVG(avg_transaction), 2) AS incorrect_avg
FROM clean_weekly_sales
GROUP BY calendar_year,
         platform
ORDER BY calendar_year,
         platform;
GO

--------------------------------
-- 3. Before & After Analysis --
--------------------------------

-- 1.What is the total sales for the 4 weeks before and after 2020-06-15? What is the growth or reduction rate in actual values and percentage of sales?
WITH cte
AS (
	SELECT
	  DISTINCT week_number wn
	FROM clean_weekly_sales
	WHERE
	  week_d = '2020-06-15'),
innerCte
AS (
	SELECT 'Before' time, SUM(sales) sales 
	FROM clean_weekly_sales, cte
	WHERE week_number BETWEEN wn - 4 AND wn -1
	UNION
	SELECT  'After', SUM(sales)
	FROM clean_weekly_sales, cte
	WHERE week_number BETWEEN wn AND wn + 3
),
innerCte2
AS (
	SELECT
		*,
		LEAD(sales) OVER(ORDER BY time) sales_n
	FROM innerCte
)
SELECT 
	sales - sales_n AS reduction_v,
	CAST(ROUND((CAST((sales) AS NUMERIC(18, 2)) / sales_n), 2) AS NUMERIC(18,2)) AS reduction_p
FROM innerCte2
WHERE sales_n IS NOT NULL;
GO

-- 2.What about the entire 12 weeks before and after?
WITH cte
AS (
	SELECT
	  DISTINCT week_number wn
	FROM clean_weekly_sales
	WHERE
	  week_d = '2020-06-15'),
innerCte
AS (
	SELECT 'Before' time, SUM(sales) sales 
	FROM clean_weekly_sales, cte
	WHERE week_number BETWEEN wn - 12 AND wn -1
	UNION
	SELECT  'After', SUM(sales)
	FROM clean_weekly_sales, cte
	WHERE week_number BETWEEN wn AND wn + 11
),
innerCte2
AS (
	SELECT
		*,
		LEAD(sales) OVER(ORDER BY time) sales_n
	FROM innerCte
)
SELECT 
	*
FROM innerCte2
WHERE sales_n IS NOT NULL;
GO

-- 3.How do the sale metrics for these 2 periods before and after compare with the previous years in 2018 and 2019?
DROP TABLE IF EXISTS #xy;
DROP TABLE IF EXISTS #yx;

WITH cte
AS (
	SELECT
	  DISTINCT week_number wn
	FROM clean_weekly_sales
	WHERE
	  week_d = '2020-06-15'),
innerCte
AS (
	SELECT  '2018' time, SUM(sales) sales
	FROM clean_weekly_sales, cte
	WHERE calendar_year = 2018
	UNION
	SELECT  '2019', SUM(sales)
	FROM clean_weekly_sales, cte
	WHERE calendar_year = 2019
)
SELECT *
INTO #xy
FROM innerCte;
GO

WITH cte
AS (
	SELECT
	  DISTINCT week_number wn
	FROM clean_weekly_sales
	WHERE
	  week_d = '2020-06-15'),
innerCte
AS (
	SELECT 'Custom_Before' time, SUM(sales) sales_a
	FROM clean_weekly_sales, cte
	WHERE week_number BETWEEN wn - 12 AND wn -1
	UNION
	SELECT  'Custom_After', SUM(sales)
	FROM clean_weekly_sales, cte
	WHERE week_number BETWEEN wn AND wn + 11
)

SELECT 
	* , 
	LEAD(sales_a) OVER(ORDER BY time) sales_b
INTO #yx
FROM innerCte;
GO

SELECT 
	x.time Year,
	CAST(ROUND(CAST(sales_a AS NUMERIC(18, 2)) / sales, 5) AS NUMERIC(18, 5)) AS Custom_After,
	CAST(ROUND(CAST(sales_b AS NUMERIC(18, 2)) / sales, 5) AS NUMERIC(18, 5)) AS Custom_Before
FROM #yx y, #xy x
WHERE sales_b IS NOT NULL;
GO

-----------------------
-- 4. Bonus Question --
-----------------------
DROP TABLE IF EXISTS #reg_temp;
DROP TABLE IF EXISTS #plat_temp;
DROP TABLE IF EXISTS #age_temp;
DROP TABLE IF EXISTS #demo_temp;
DROP TABLE IF EXISTS #cust_temp;
GO

WITH cte_region
AS (
	SELECT 
		region AS area,
		SUM(CASE
				WHEN week_number BETWEEN 13 AND 24 THEN sales
			END) before_sales,
		SUM(CASE
				WHEN week_number BETWEEN 25 AND 36 THEN sales
			END) after_sales
	FROM clean_weekly_sales
	GROUP BY region
),
innerCte
AS (
SELECT 
	area,
	CAST(ROUND(CAST((after_sales - before_sales) AS NUMERIC(18, 2)) / before_sales * 100, 2)AS NUMERIC(18, 2)) percentage
FROM cte_region)

SELECT TOP 1 area, percentage
INTO #reg_temp
FROM innerCte
ORDER BY percentage;
GO

WITH cte_platform
AS (
	SELECT 
		platform AS area,
		SUM(CASE
				WHEN week_number BETWEEN 13 AND 24 THEN sales
			END) before_sales,
		SUM(CASE
				WHEN week_number BETWEEN 25 AND 36 THEN sales
			END) after_sales
	FROM clean_weekly_sales
	GROUP BY platform
),
innerCte
AS (
SELECT 
	area,
	CAST(ROUND(CAST((after_sales - before_sales) AS NUMERIC(18, 2)) / before_sales * 100, 2)AS NUMERIC(18, 2)) percentage
FROM cte_platform)

SELECT TOP 1 area, percentage 
INTO #plat_temp
FROM innerCte
ORDER BY percentage;
GO

WITH cte_age_band
AS (
	SELECT 
		age_band AS area,
		SUM(CASE
				WHEN week_number BETWEEN 13 AND 24 THEN sales
			END) before_sales,
		SUM(CASE
				WHEN week_number BETWEEN 25 AND 36 THEN sales
			END) after_sales
	FROM clean_weekly_sales
	GROUP BY age_band
),
innerCte
AS (
SELECT 
	area,
	CAST(ROUND(CAST((after_sales - before_sales) AS NUMERIC(18, 2)) / before_sales * 100, 2)AS NUMERIC(18, 2)) percentage
FROM cte_age_band)

SELECT TOP 1 area, percentage 
INTO #age_temp
FROM innerCte
ORDER BY percentage;
GO

WITH cte_demographic
AS (
	SELECT 
		demographic AS area,
		SUM(CASE
				WHEN week_number BETWEEN 13 AND 24 THEN sales
			END) before_sales,
		SUM(CASE
				WHEN week_number BETWEEN 25 AND 36 THEN sales
			END) after_sales
	FROM clean_weekly_sales
	GROUP BY demographic
),
innerCte
AS (
SELECT 
	area,
	CAST(ROUND(CAST((after_sales - before_sales) AS NUMERIC(18, 2)) / before_sales * 100, 2)AS NUMERIC(18, 2)) percentage
FROM cte_demographic)

SELECT TOP 1 area, percentage 
INTO #demo_temp
FROM innerCte
ORDER BY percentage;
GO

WITH cte_customer_type
AS (
	SELECT 
		customer_type AS area,
		SUM(CASE
				WHEN week_number BETWEEN 13 AND 24 THEN sales
			END) before_sales,
		SUM(CASE
				WHEN week_number BETWEEN 25 AND 36 THEN sales
			END) after_sales
	FROM clean_weekly_sales
	GROUP BY customer_type
),
innerCte
AS (
SELECT 
	area,
	CAST(ROUND(CAST((after_sales - before_sales) AS NUMERIC(18, 2)) / before_sales * 100, 2)AS NUMERIC(18, 2)) percentage
FROM cte_customer_type)

SELECT TOP 1 area, percentage 
INTO #cust_temp
FROM innerCte
ORDER BY percentage;

SELECT * FROM #reg_temp
UNION ALL
SELECT * FROM #plat_temp
UNION ALL
SELECT * FROM #age_temp
UNION ALL
SELECT * FROM #demo_temp
UNION ALL
SELECT * FROM #cust_temp
ORDER BY percentage;