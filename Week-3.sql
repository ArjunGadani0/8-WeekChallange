-------------------------
-- A. Customer Journey --
-------------------------

SELECT 
	customer_id,
	s.plan_id,
	plan_name,
	price,
	start_date
FROM subscriptions s
JOIN plans p
ON s.plan_id = p.plan_id
WHERE customer_id < 9;
GO

/*
Above query produce result which contains 8 customer's on boarding journey,
i'll describe subcription journey for 2 customers in brief.

customer 2 - has started his subscription on 2020-09-27 by opting-in trial plan
of 7 days, after completion of trial plan customer has opted for "pro annual"
which costs around $199.0 / annualy and plan includes no watch time limits and 
are able to download videos for offline viewing.

customer 4 - has started his subscription on 2020-01-17 by opting-in trial plan
of 7 days, after completion of trial plan customer has enrolled for "basic"
which costs around $9.90 / monthly and plan have limited access and 
can only stream their videos, after around 3 months of subscription customer 
has cancelled his subscription on 2020-04-21.

*/
--------------------------------
-- B. Data Analysis Questions --
--------------------------------

-- 1.How many customers has Foodie-Fi ever had?
SELECT
	COUNT(DISTINCT customer_id) Total_customers
FROM subscriptions;
GO
-- 2.What is the monthly distribution of trial plan start_date values for our dataset - use the start of the month as the group by value
SELECT 
	DATEPART(MONTH, start_date) month,
	COUNT(*) trial_plan
FROM subscriptions
WHERE plan_id = 0
GROUP BY DATEPART(MONTH, start_date)
ORDER BY DATEPART(MONTH, start_date);
GO
-- 3.What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name
DROP TABLE IF EXISTS #e_20;
DROP TABLE IF EXISTS #e_21;

SELECT 
	  p.plan_id,
	  p.plan_name,
	  COUNT(*) AS events_2020
INTO #e_20
FROM subscriptions s
LEFT JOIN plans p
	ON s.plan_id = p.plan_id
WHERE s.start_date < '2021-01-01'
GROUP BY p.plan_id, p.plan_name;
GO

SELECT 
	p.plan_id,
	p.plan_name,
	COUNT(*) AS events_2021
INTO #e_21
FROM subscriptions s
LEFT JOIN plans p
	ON s.plan_id = p.plan_id
WHERE s.start_date >= '2021-01-01'
GROUP BY p.plan_id, p.plan_name;
GO

SELECT 
	a.plan_id,
	a.plan_name,
	events_2020,
	COALESCE(events_2021, 0) events_2021
FROM #e_20 a
LEFT JOIN #e_21 b
ON a.plan_id = b.plan_id
ORDER BY a.plan_id;
GO

-- 4.What is the customer count and percentage of customers who have churned rounded to 1 decimal place?
SELECT
	COUNT(*) churn_count,
	CAST(CAST(COUNT(*) AS NUMERIC) / (SELECT COUNT(DISTINCT customer_id) FROM subscriptions) * 100 AS NUMERIC(10, 1))churn_p
FROM subscriptions
WHERE plan_id = 4;
GO

-- 5.How many customers have churned straight after their initial free trial - what percentage is this rounded to the nearest whole number?
WITH cte
AS (SELECT
	s.customer_id,
	p.plan_id,
	p.plan_name,
	ROW_NUMBER() OVER(
		PARTITION BY customer_id ORDER BY customer_id) sub_r
	FROM subscriptions s
	JOIN plans p
	ON p.plan_id = s.plan_id)

SELECT
	COUNT(*) churn_count,
	CAST(ROUND(CAST(COUNT(*) AS NUMERIC) / (SELECT COUNT(DISTINCT customer_id) FROM subscriptions) * 100, 0) AS NUMERIC)churn_p
FROM cte
WHERE plan_id = 4 AND sub_r = 2;
GO

-- 6.What is the number and percentage of customer plans after their initial free trial?
WITH cte
AS (SELECT
	s.customer_id,
	p.plan_id,
	p.plan_name,
	LEAD(p.plan_id) OVER(
		PARTITION BY customer_id ORDER BY p.plan_id) plan_n
	FROM subscriptions s
	JOIN plans p
	ON p.plan_id = s.plan_id)

SELECT
	plan_n,
	COUNT(*) churn_count,
	CAST(CAST(COUNT(*) AS NUMERIC) / (SELECT COUNT(DISTINCT customer_id) FROM subscriptions) * 100 AS NUMERIC(10, 1))churn_p
FROM cte
WHERE plan_id = 0
GROUP BY plan_n
ORDER BY plan_n;
GO

-- 7.What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?
WITH cte
AS (SELECT
	*,
	LEAD(s.start_date) OVER(
		PARTITION BY customer_id ORDER BY s.start_date) plan_n
	FROM subscriptions s
	WHERE start_date <= '2020-12-31'),
innerCte
AS (SELECT 
		plan_id,
		COUNT (DISTINCT customer_id) n_cut
	FROM cte
	WHERE (plan_n IS NOT NULL AND (start_date < '2020-12-31' AND plan_n >= '2020-12-31'))
		OR (plan_n IS NULL AND start_date < '2020-12-31')
	GROUP BY plan_id)

SELECT
	plan_id,
	n_cut,
	CAST(CAST(n_cut AS NUMERIC) * 100 / (SELECT COUNT(DISTINCT customer_id) FROM subscriptions) AS NUMERIC(10, 1)) n_cut_p
FROM innerCte
GROUP BY plan_id, n_cut
ORDER BY plan_id
GO

-- 8.How many customers have upgraded to an annual plan in 2020?
WITH cte
AS (SELECT
	s.customer_id,
	p.plan_id,
	p.plan_name,
	start_date,
	LEAD(p.plan_id) OVER(
		PARTITION BY customer_id ORDER BY p.plan_id) plan_n
	FROM subscriptions s
	JOIN plans p
	ON p.plan_id = s.plan_id)

SELECT COUNT(*) pro_annual_customer
FROM cte
WHERE DATEPART(YEAR, start_date) = 2020 AND plan_n = 3;
GO

-- 9.How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?
WITH cte
AS (SELECT
	s.customer_id,
	p.plan_id,
	p.plan_name,
	start_date,
	ROW_NUMBER() OVER(
		PARTITION BY customer_id ORDER BY customer_id) plan_n
	FROM subscriptions s
	JOIN plans p
	ON p.plan_id = s.plan_id),
innerCte1
AS(
	SELECT * FROM subscriptions
	WHERE plan_id = 0
),
innerCte2
AS(
	SELECT * FROM cte
	WHERE plan_id = 3
)

SELECT AVG(DATEDIFF(day, a.start_date, b.start_date)) avg_days_for_annual_plan
FROM innerCte1 a
JOIN innerCte2 b
ON a.customer_id = b.customer_id;
GO

-- 10.Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
WITH cte
AS (SELECT
	s.customer_id,
	p.plan_id,
	p.plan_name,
	start_date,
	ROW_NUMBER() OVER(
		PARTITION BY customer_id ORDER BY customer_id) plan_n
	FROM subscriptions s
	JOIN plans p
	ON p.plan_id = s.plan_id),
innerCte1
AS(
	SELECT * FROM cte
	WHERE plan_id = 0
),
innerCte2
AS(
	SELECT * FROM cte
	WHERE plan_id = 3
),
cteDays
AS (
	SELECT DATEDIFF(day, a.start_date, b.start_date) d
	FROM innerCte1 a
	JOIN innerCte2 b
	ON a.customer_id = b.customer_id
)

SELECT count(*) AS frequency,
       CAST((30 * FLOOR(d / 30)) AS VARCHAR) + '-' + CAST((30 * (FLOOR(d / 30) + 1)) AS VARCHAR) day_range
FROM cteDays
GROUP BY 30 * FLOOR(d / 30), 30 * (FLOOR(d / 30) + 1)
ORDER BY MIN(d);
GO

-- 11.How many customers downgraded from a pro monthly to a basic monthly plan in 2020?
WITH cte
AS (SELECT
	s.customer_id,
	p.plan_id,
	p.plan_name,
	start_date,
	LEAD(p.plan_id) OVER(
		PARTITION BY customer_id ORDER BY p.plan_id) plan_n
	FROM subscriptions s
	JOIN plans p
	ON p.plan_id = s.plan_id)

SELECT COUNT(*) down_customer
FROM cte
WHERE 
	DATEPART(YEAR, start_date) = 2020 AND
	plan_id = 2 AND 
	plan_n = 1;
GO

-----------------------------------
-- C. Challenge Payment Question --
-----------------------------------

WITH
    join_table --create base table
        AS
    (
        SELECT 
            s.customer_id,
            s.plan_id,
            p.plan_name,
            s.start_date payment_date,
            s.start_date,
            LEAD(s.start_date, 1) OVER(PARTITION BY s.customer_id ORDER BY s.start_date, s.plan_id) next_date,
            p.price amount
        FROM [foodie_fi].[subscriptions] s
        left join [foodie_fi].[plans] p on p.plan_id = s.plan_id
    ),
        new_join --filter table (deselect trial and churn)
        AS
    (
        SELECT 
            customer_id,
            plan_id,
            plan_name,
            payment_date,
            start_date,
            CASE WHEN next_date IS NULL or next_date > '20201231' THEN '20201231' ELSE next_date END next_date,
            amount
        FROM join_table
        WHERE plan_name not in ('trial', 'churn')
    ),
        new_join1 --add new column, 1 month before next_date
        AS
    (
        SELECT 
            customer_id,
            plan_id,
            plan_name,
            payment_date,
            start_date,
            next_date,
            DATEADD(MONTH, -1, next_date) next_date1,
            amount
        FROM new_join
    ),
    Date_CTE  --recursive function (for payment_date)
        AS
    (
        SELECT 
            customer_id,
            plan_id,
            plan_name,
            start_Date,
            payment_date = (SELECT TOP 1 start_date FROM new_join1 WHERE customer_id = a.customer_id AND plan_id = a.plan_id),
            next_date, 
            next_date1,
            amount
        FROM new_join1 a

 

            UNION ALL 

        SELECT 
            customer_id,
            plan_id,
            plan_name,
            start_Date, 
            DATEADD(M, 1, payment_date) payment_date,
            next_date, 
            next_date1,
            amount
        FROM Date_CTE b
        WHERE payment_date < next_date1 AND plan_id != 3
)
SELECT 
    customer_id,
    plan_id,
    plan_name,
    payment_date,
    amount,
    RANK() OVER(PARTITION BY customer_id ORDER BY customer_id, plan_id, payment_date) payment_order
FROM Date_CTE
WHERE YEAR(payment_date) = 2020
ORDER BY customer_id, plan_id, payment_date;
GO

----------------------------------
-- D. Outside The Box Questions --
----------------------------------
DROP TABLE IF EXISTS #ppp_cust;
GO
WITH cte
AS (
	SELECT DATEPART(MONTH, start_date) Month, COUNT(*) pro_plan_customers
FROM subscriptions s
	JOIN plans p
	ON p.plan_id = s.plan_id
WHERE p.plan_id IN (2, 3) AND DATEPART(YEAR, start_date) = 2020
GROUP BY DATEPART(MONTH, start_date)),
innerCte
AS (
	SELECT *, 
		LAG(pro_plan_customers) OVER(ORDER BY Month) plan_n
	FROM cte)

SELECT
	Month,
	COALESCE(CAST(ROUND((CAST(pro_plan_customers AS NUMERIC(10, 2)) / plan_n), 2) AS NUMERIC(10, 2)), 0) pro_plan_percent
INTO #ppp_cust
FROM innerCte
GO

DROP TABLE IF EXISTS #up_cust;
GO
WITH cte
AS (
	SELECT
		s.customer_id,
		p.plan_id,
		p.plan_name,
		start_date,
		LEAD(p.plan_id) OVER(
			PARTITION BY customer_id ORDER BY p.plan_id) plan_n
	FROM subscriptions s
	JOIN plans p
	ON p.plan_id = s.plan_id),
innerCte
AS (
	SELECT DATEPART(MONTH, start_date) Month, COUNT(*) plan_upgrade
	FROM cte
	WHERE plan_n != 4 AND plan_id != 0 AND plan_id < plan_n AND plan_n IS NOT NULL AND DATEPART(YEAR, start_date) = 2020
	GROUP BY DATEPART(MONTH, start_date)),
innerCte2
AS (
	SELECT *, 
		LAG(plan_upgrade) OVER(ORDER BY Month) plan_n
	FROM innerCte)
SELECT
	Month,
	COALESCE(CAST(ROUND((CAST(plan_upgrade AS NUMERIC(10, 2)) / plan_n), 2) AS NUMERIC(10, 2)), 0) upgrade_percent
INTO #up_cust
FROM innerCte2
GO

SELECT
	u.Month,
	pro_plan_percent,
	upgrade_percent
FROM #up_cust u
JOIN #ppp_cust p
ON u.Month = p.Month;
GO

-- 2.What key metrics would you recommend Foodie-Fi management to track over time to assess performance of their overall business?

-- One of the key thing Foodie-Fi has to keep a eye on is that their new customer acquisition to Churn customer ratio is declining from the
-- past year (2020), besides from that Foodie-Fi can measure upgradation growth rates as well as downgradation rates by monthly or quaterly.

DROP TABLE IF EXISTS #n_cust;
GO

WITH cte
AS (
	SELECT
		s.customer_id,
		p.plan_id,
		p.plan_name,
		start_date,
		LEAD(p.plan_id) OVER(
			PARTITION BY customer_id ORDER BY p.plan_id) plan_n
	FROM subscriptions s
	JOIN plans p
	ON p.plan_id = s.plan_id)

SELECT DATEPART(MONTH, start_date) Month, COUNT(*) New_customers
INTO #n_cust
FROM cte
WHERE plan_id = 0 AND plan_n != 4 AND plan_n IS NOT NULL AND DATEPART(YEAR, start_date) = 2020
GROUP BY DATEPART(MONTH, start_date)
ORDER BY DATEPART(MONTH, start_date);
GO

DROP TABLE IF EXISTS #c_cust;
GO

SELECT DATEPART(MONTH, start_date) Month, COUNT(*) churn_customers
INTO #c_cust
FROM subscriptions s
	JOIN plans p
	ON p.plan_id = s.plan_id
WHERE p.plan_id = 4 AND DATEPART(YEAR, start_date) = 2020
GROUP BY DATEPART(MONTH, start_date)
ORDER BY DATEPART(MONTH, start_date);
GO

DROP TABLE IF EXISTS #ncr_cust;
GO
SELECT 
	n.Month,
	CAST(ROUND((CAST(New_customers AS NUMERIC(10, 2)) / churn_customers), 2) AS NUMERIC(10, 2)) new_churn_ratio
INTO #ncr_cust
FROM #n_cust n
JOIN #c_cust c
ON n.Month = c. Month;
GO
SELECT * FROM #ncr_cust;
GO

-- 3.What are some key customer journeys or experiences that you would analyse further to improve customer retention?
-- So here from the results we can see customers who have opted out from subscription from current running plans,
-- where around ~300 customers have left out of 1000 customers in total. For both monthly either basic or pro in total 
-- ~200 have left which could be one of the major thing to look into and besides that around ~100 customers have not even 
-- subscribed for any of the plan after 7 days of trial period along with that 6 customer have opted-out from annual plan
-- probably before thier plan ends.

WITH cte
AS (
	SELECT
		s.customer_id,
		p.plan_id,
		p.plan_name,
		start_date,
		LEAD(p.plan_id) OVER(
			PARTITION BY customer_id ORDER BY p.plan_id) plan_n
	FROM subscriptions s
	JOIN plans p
	ON p.plan_id = s.plan_id)

SELECT 
	plan_id,
	COUNT(*) churn_counts
FROM cte
WHERE plan_n = 4
GROUP BY plan_id;
GO

-- 4.If the Foodie-Fi team were to create an exit survey shown to customers who wish to cancel their subscription, what questions would you include in the survey?

-- What were the trigger(s) that made you cancel?
-- What did you like about the product or service?
-- What didnt you like about the product or service?
-- What suggestions do you have to improve the product or service?
-- What suggestions do you have to improve the product or service?Would you reconsider our product in the future? What would that take?
-- Who do you think is the ideal customer for our product or service?

-- 5.What business levers could the Foodie-Fi team use to reduce the customer churn rate? How would you validate the effectiveness of your ideas?

-- From the data we have seen ~250 customers have upgraded thier plan to annual one and only ~5-10 customers have opted outfrom the annual plan
-- which is bit positive side, So problem have arised in monthly plan and trial plans,
-- If we talk about monthly plan particulaly pro monthly so there is hardly a price difference between pro monthly to pro annualy so they can 
-- set service pricing to make customers can opt for longer term plan but this is just one aspect but from trial - churn and basic - churn rate
-- we can see customers are lefting subscriptions which is 20% of total, company might need to improve effectiveness of their service and make customers 
-- feel worth of the value that service provides.

-- To talk about measuring effectiveness we could use various metrics such as churn ratio for each plan, customer plan upgradation growth monthly or quaterly.
