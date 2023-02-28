-------------------------
-- 2. Digital Analysis --
-------------------------

-- 1.How many users are there?
SELECT 
	COUNT(DISTINCT user_id) usr_count
FROM users;
GO

-- 2.How many cookies does each user have on average?
WITH cte
AS (SELECT
	user_id,
	COUNT(cookie_id) c_count
FROM users
GROUP BY user_id)

SELECT 
	CAST(ROUND(AVG(CAST(c_count AS NUMERIC(18, 2))), 2) AS NUMERIC(18, 2)) avg_c_count
FROM cte;
GO
-- 3.What is the unique number of visits by all users per month?
SELECT 
	DATEPART(MONTH, event_time) Month,
	COUNT(DISTINCT visit_id) unq_visits
FROM events
GROUP BY DATEPART(MONTH, event_time)
ORDER BY DATEPART(MONTH, event_time);
GO

-- 4.What is the number of events for each event type?
SELECT 
	event_type,
	COUNT(event_type) evnt_count
FROM events
GROUP BY event_type
ORDER BY event_type;
GO

-- 5.What is the percentage of visits which have a purchase event?
WITH cte
AS (
	SELECT
	COUNT(DISTINCT visit_id) total_count
	FROM events),

innerCte
AS (
	SELECT
		COUNT(visit_id) purchase_count
	FROM events
	WHERE page_id = 13)

SELECT 
	CAST(ROUND(CAST(purchase_count AS NUMERIC(10, 2)) / total_count * 100, 2) AS NUMERIC(10, 2)) AS purchase_percentage
FROM cte, innerCte;
GO

-- 6.What is the percentage of visits which view the checkout page but do not have a purchase event?
WITH cte
AS (
	SELECT
		COUNT(visit_id) total_count
	FROM events
	WHERE page_id = 12),

innerCte
AS (
	SELECT
		COUNT(visit_id) purchase_count
	FROM events
	WHERE page_id = 12 AND visit_id NOT IN (SELECT
											visit_id
										FROM events a
										WHERE event_type = 3))

SELECT 
	CAST(ROUND(CAST(purchase_count AS NUMERIC(10, 2)) / total_count * 100, 2) AS NUMERIC(10, 2)) AS checkout_percentage
FROM cte, innerCte;
GO

-- 7.What are the top 3 pages by number of views?
SELECT 
	TOP 3
	page_name,
	COUNT(e.page_id) page_count
FROM events e
JOIN page_hierarchy p
ON e.page_id = p.page_id
WHERE event_type = 1
GROUP BY page_name
ORDER BY COUNT(e.page_id) DESC;
GO

-- 8.What is the number of views and cart adds for each product category?
WITH cte
AS (
	SELECT
		product_category,
		COUNT(e.page_id) view_count
	FROM events e
	JOIN page_hierarchy p
	ON e.page_id = p.page_id
	WHERE product_category IS NOT NULL AND event_type = 1
	GROUP BY product_category),

innerCte
AS (
	SELECT
		product_category,
		COUNT(e.page_id) add_count
	FROM events e
	JOIN page_hierarchy p
	ON e.page_id = p.page_id
	JOIN event_identifier ei
	ON e.event_type = ei.event_type
	WHERE product_category IS NOT NULL AND ei.event_type = 2
	GROUP BY product_category)

SELECT 
	c.product_category,
	view_count,
	add_count
FROM cte c
JOIN innerCte i
ON c.product_category = i.product_category;
GO

-- 9.What are the top 3 products by purchases?
WITH cte
As (
	SELECT
		visit_id,
		cookie_id,
		e.page_id,
		page_name
	FROM events e
	JOIN page_hierarchy p
	ON e.page_id = p.page_id
	WHERE event_type = 2)

SELECT 
	TOP 3
	page_name,
	COUNT(page_id) purchase_count
FROM cte
WHERE visit_id IN (SELECT
					visit_id
				FROM events a
				WHERE event_type = 3)
GROUP BY page_name
ORDER BY COUNT(page_id) DESC;
GO

--------------------------------
-- 3. Product Funnel Analysis --
--------------------------------

-- 1.Using a single SQL query - create a new output table which has the following details:
DROP TABLE IF EXISTS #view_temp;
GO

SELECT
	page_name,
	COUNT(e.page_id) page_count
INTO #view_temp
FROM events e
JOIN page_hierarchy p
ON e.page_id = p.page_id
WHERE event_type = 1
GROUP BY page_name;
GO

DROP TABLE IF EXISTS #add_temp;
GO

SELECT
	page_name,
	COUNT(e.page_id) add_count
INTO #add_temp
FROM events e
JOIN page_hierarchy p
ON e.page_id = p.page_id
WHERE event_type = 2
GROUP BY page_name;
GO

DROP TABLE IF EXISTS #np_temp;
GO

WITH cte
As (
	SELECT
		visit_id,
		cookie_id,
		e.page_id,
		page_name
	FROM events e
	JOIN page_hierarchy p
	ON e.page_id = p.page_id
	WHERE event_type = 2)

SELECT 
	page_name,
	COUNT(page_id) abandon_count
INTO #np_temp
FROM cte
WHERE visit_id NOT IN (SELECT
					visit_id
				FROM events a
				WHERE event_type = 3)
GROUP BY page_name
ORDER BY COUNT(page_id) DESC;
GO

DROP TABLE IF EXISTS #p_temp;
GO

WITH cte
As (
	SELECT
		visit_id,
		cookie_id,
		e.page_id,
		page_name
	FROM events e
	JOIN page_hierarchy p
	ON e.page_id = p.page_id
	WHERE event_type = 2)

SELECT 
	page_name,
	COUNT(page_id) purchase_count
INTO #p_temp
FROM cte
WHERE visit_id IN (SELECT
					visit_id
				FROM events a
				WHERE event_type = 3)
GROUP BY page_name
ORDER BY COUNT(page_id) DESC;
GO

DROP TABLE IF EXISTS #product_details;
GO

SELECT 
	product_id,
	p.page_name AS product_name,
	product_category,
	page_count,
	add_count,
	abandon_count,
	purchase_count
INTO #product_details
FROM #p_temp p
JOIN #add_temp a
ON a.page_name = p.page_name
JOIN #np_temp n
ON n.page_name = p.page_name
JOIN #view_temp v
ON v.page_name = p.page_name
JOIN page_hierarchy ph
ON ph.page_name = p.page_name
ORDER BY product_id;
GO

SELECT * FROM #product_details
ORDER BY product_id;
GO

SELECT
	product_category,
	SUM(page_count) page_count,
	SUM(add_count) add_count,
	SUM(abandon_count) abandon_count,
	SUM(purchase_count) purchase_count
FROM #product_details
GROUP BY product_category;
GO

SELECT *  
FROM (
	SELECT 
		TOP 1
		'Most Viewed' AS Most,
		product_name,
		page_count
	FROM #product_details
	ORDER BY page_count DESC) MV

UNION

SELECT *  
FROM (
	SELECT 
		TOP 1
		'Most Cart Add' AS Most,
		product_name,
		add_count
	FROM #product_details
	ORDER BY add_count DESC) MC

UNION

SELECT *  
FROM (
	SELECT 
		TOP 1
		'Most Purchases' AS Most,
		product_name,
		purchase_count
	FROM #product_details
	ORDER BY purchase_count DESC) MP;
GO

-- 2.Which product was most likely to be abandoned
SELECT 
	TOP 1
	product_name,
	abandon_count
FROM #product_details
ORDER BY abandon_count DESC;
GO

-- 3.Which product had the highest view to purchase percentage?
WITH cte
AS(
	SELECT 
		product_name,
		CAST(ROUND(CAST(page_count AS NUMERIC(10, 2)) / purchase_count, 2) AS NUMERIC(10, 2)) AS p_p_ratio
	FROM #product_details)

SELECT
	TOP 1
	product_name,
	p_p_ratio
FROM cte
ORDER BY p_p_ratio DESC;
GO

-- 4.What is the average conversion rate from view to cart add?
WITH cte
AS(
	SELECT 
		product_name,
		CAST(ROUND(CAST(add_count AS NUMERIC(10, 2)) / page_count * 100, 2) AS NUMERIC(10, 2)) AS v_a_ratio
	FROM #product_details)

SELECT
	CAST(ROUND(AVG(v_a_ratio), 2) AS NUMERIC(10, 2)) AS avg_conv
FROM cte;
GO

-- 5.What is the average conversion rate from cart add to purchase?
WITH cte
AS(
	SELECT 
		product_name,
		CAST(ROUND(CAST(purchase_count AS NUMERIC(10, 2)) / add_count * 100, 2) AS NUMERIC(10, 2)) AS a_p_ratio
	FROM #product_details)

SELECT
	CAST(ROUND(AVG(a_p_ratio), 2) AS NUMERIC(10, 2)) AS avg_conv
FROM cte;
GO

---------------------------
-- 4. Campaigns Analysis --
---------------------------
DROP TABLE IF EXISTS #campaigns;
WITH cte
AS(
	SELECT 
		visit_id,
		STRING_AGG(page_name, ', ') AS cart_prod
	FROM events e
	JOIN page_hierarchy p
	ON p.page_id = e.page_id
	WHERE p.page_id NOT IN  (1, 2, 12, 13)
	GROUP BY visit_id
	)
SELECT
	user_id,
	e.visit_id,
	MIN(event_time) visit_start_time,
	SUM(CASE
			WHEN event_type = 1
				THEN 1
			ELSE 0
	END)view_count,
	SUM(CASE
			WHEN event_type = 2
				THEN 1
			ELSE 0
	END) cart_count,
	SUM(CASE
			WHEN event_type = 3
				THEN 1
			ELSE 0
	END) purchase,
	campaign_name,
	SUM(CASE
			WHEN event_type = 4
				THEN 1
			ELSE 0
	END) impression,
	SUM(CASE
			WHEN event_type = 5
				THEN 1
			ELSE 0
	END) click,
	cart_prod
INTO #campaigns
FROM events e
JOIN cte c
ON c.visit_id = e.visit_id
JOIN users u
ON e.cookie_id = u.cookie_id
JOIN campaign_identifier ci
ON event_time BETWEEN ci.start_date AND ci.end_date
GROUP BY user_id, e.visit_id, campaign_name, cart_prod
ORDER BY user_id;
GO

SELECT * FROM #campaigns
ORDER BY user_id;
GO

DROP TABLE IF EXISTS #imp_user;
GO

WITH cte
AS (
	SELECT 
		DISTINCT
		user_id,
		campaign_name
	FROM #campaigns
	WHERE impression != 0),
innerCte
As (
	SELECT 
		user_id,
		count(user_id) imp_count
	FROM cte
	GROUP BY user_id)

SELECT
	user_id,
	imp_count
INTO #imp_user
FROM innerCte
WHERE imp_count = 3;
GO

SELECT * FROM #imp_user;
GO

-- Identifying users who have received impressions during each campaign period and comparing each metric with other users who did not have an impression event

WITH cte
AS (SELECT 
	'imp_user' user_type,
	AVG(view_count) vc,
	AVG(cart_count) cc,
	AVG(CAST(purchase AS NUMERIC(10, 2))) p
FROM #campaigns
WHERE user_id IN (SELECT user_id FROM #imp_user)
GROUP BY user_id),

innerCte
AS (
	SELECT 
		user_type,
		AVG(vc) view_count,
		AVG(cc) cart_count,
		AVG(p) purchase
	FROM cte
	GROUP BY user_type),

innerCte2
AS (SELECT 
	'non_imp_user' user_type,
	AVG(view_count) vc,
	AVG(cart_count) cc,
	AVG(CAST(purchase AS NUMERIC(10, 2))) p
FROM #campaigns
WHERE user_id NOT IN (SELECT user_id FROM #imp_user)
GROUP BY user_id),

innerCte3
AS (
	SELECT 
		user_type,
		AVG(vc) vc,
		AVG(cc) cc,
		AVG(p) p
	FROM innerCte2
	GROUP BY user_type)

SELECT * FROM innerCte
UNION
SELECT * FROM innerCte3;
GO

-- Does clicking on an impression lead to higher purchase rates?

-- Yes, as we can see from the results there is huge difference in purhcase rate when user have clicked ad.
WITH cte
AS (SELECT 
	user_id,
	'click_user' user_type,
	SUM(CASE
			WHEN click = 1 AND purchase = 1
				THEN 1
			ELSE 0
		END) p,
	SUM(CASE
			WHEN click = 1
				THEN 1
			ELSE 0
		END) t
FROM #campaigns
GROUP BY user_id),

innerCte
AS (SELECT 
	user_type,
	SUM(CAST(p AS NUMERIC(10, 2)))/SUM(t) * 100 purchase_rate
FROM cte
GROUP BY user_type),

innerCte2
AS (SELECT 
	user_id,
	'non_click_user' user_type,
	SUM(CASE
			WHEN click = 1 AND purchase = 0
				THEN 1
			ELSE 0
		END) p,
	SUM(CASE
			WHEN click = 1
				THEN 1
			ELSE 0
		END) t
FROM #campaigns
GROUP BY user_id),

innerCte3
AS (SELECT 
	user_type,
	SUM(CAST(p AS NUMERIC(10, 2)))/SUM(t) * 100 purchase_rate
FROM innerCte2
GROUP BY user_type)

SELECT * FROM innerCte
UNION
SELECT * FROM innerCte3;
GO

-- What is the uplift in purchase rate when comparing users who click on a campaign impression versus users who do 
-- not receive an impression? What if we compare them with users who just an impression but do not click?

WITH cte
AS (SELECT 
	user_id,
	'click_user' user_type,
	SUM(CASE
			WHEN click = 1 AND purchase = 1
				THEN 1
			ELSE 0
		END) p,
	COUNT(*) t
FROM #campaigns
GROUP BY user_id),

innerCte
AS (SELECT 
	user_type,
	SUM(CAST(p AS NUMERIC(10, 2)))/SUM(t) * 100 purchase_rate
FROM cte
GROUP BY user_type),

innerCte2
AS (SELECT 
	user_id,
	'non_click_user' user_type,
	SUM(CASE
			WHEN impression = 1 AND click = 0 AND purchase = 1
				THEN 1
			ELSE 0
		END) p,
	COUNT(*) t
FROM #campaigns
GROUP BY user_id),

innerCte3
AS (SELECT 
	user_type,
	SUM(CAST(p AS NUMERIC(10, 2)))/SUM(t) * 100 purchase_rate
FROM innerCte2
GROUP BY user_type),

innerCte4
AS (SELECT 
	user_id,
	'non_click_user' user_type,
	SUM(CASE
			WHEN impression = 0 AND purchase = 1
				THEN 1
			ELSE 0
		END) p,
	COUNT(*) t
FROM #campaigns
GROUP BY user_id),

innerCte5
AS (SELECT 
	user_type,
	SUM(CAST(p AS NUMERIC(10, 2)))/SUM(t) * 100 purchase_rate
FROM innerCte4
GROUP BY user_type)

SELECT * FROM innerCte
UNION
SELECT * FROM innerCte3
UNION 
SELECT * FROM innerCte5

-- What metrics can you use to quantify the success or failure of each campaign compared to eachother?

-- ANS. I believe one of the key metric to measure campaign performance would be look for purchase rate difference
-- without campaign and with campaign and as we can see from above result while clicked or impression event occured 
-- purhcase rate tend to get higher compared to users who didn't get ad campaign impression.