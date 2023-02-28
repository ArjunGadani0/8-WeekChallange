-------------------------------
-- High Level Sales Analysis --
-------------------------------

-- 1.What was the total quantity sold for all products?
SELECT 
	SUM(qty) total_qty_sold
FROM sales;
GO

-- 2.What is the total generated revenue for all products before discounts?
SELECT 
	SUM(qty * price) total_revenue
FROM sales

-- 3.What was the total discount amount for all products?
SELECT 
	SUM(discount) total_discount
FROM sales

--------------------------
-- Transaction Analysis --
--------------------------

-- 1.How many unique transactions were there?
SELECT 
	COUNT(DISTINCT txn_id) unq_txn
FROM sales;
GO

-- 2.What is the average unique products purchased in each transaction?
WITH cte
AS (
	SELECT 
		txn_id,
		COUNT(DISTINCT prod_id) unq_prod_count
	FROM sales
	GROUP BY txn_id)
SELECT 
	AVG(CAST(unq_prod_count AS NUMERIC(10, 2))) avg_unq_prod_count
FROM cte
GO

-- 3.What are the 25th, 50th and 75th percentile values for the revenue per transaction?
WITH cte AS(
  SELECT
    ROUND(
      SUM((1 - CAST(discount AS NUMERIC(10, 2)) / 100) * price * qty),
      2
    ) AS total_revenue
  FROM
    sales
  GROUP BY
    txn_id
)
SELECT 
	DISTINCT
	PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY total_revenue) OVER () perc_25,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_revenue) OVER () perc_50,
	PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total_revenue) OVER () perc_75
FROM cte;
GO

-- 4.What is the average discount value per transaction?
WITH cte AS(
  SELECT
      SUM(discount) total_dis
  FROM
    sales
  GROUP BY
    txn_id
)
SELECT
	ROUND(AVG(CAST(total_dis AS NUMERIC(10, 2))), 2) avg_dis
FROM
	cte;
GO

 -- 5.What is the percentage split of all transactions for members vs non-members?
WITH cte
AS(
	SELECT 
		'member' mem_type,
		ROUND(CAST(COUNT(member) AS NUMERIC(10, 2)) / (SELECT COUNT(member) FROM sales), 2) split_perct
	FROM sales
	WHERE member = 0),

innerCte
AS (
	SELECT 
		'non_member' mem_type,
		ROUND(CAST(COUNT(member) AS NUMERIC(10, 2)) / (SELECT COUNT(member) FROM sales), 2) split_perct
	FROM sales
	WHERE member = 1)

SELECT * FROM cte
UNION 
SELECT * FROM innerCte;
GO

-- 6.What is the average revenue for member transactions and non-member transactions?
WITH cte AS(
  SELECT
    txn_id,
    member,
    SUM((1 - CAST(discount AS NUMERIC(10, 2)) / 100) * price * qty) AS total_revenue
  FROM
    sales
  GROUP BY txn_id, member
)
SELECT
  member,
  CAST(ROUND(AVG(total_revenue), 2) AS NUMERIC(10, 2)) avg_revenue
FROM cte
GROUP BY member

----------------------
-- Product Analysis --
----------------------

-- 1.What are the top 3 products by total revenue before discount?
SELECT 
	TOP 3
	product_name,
	SUM(p.price * qty) revenue
FROM sales s
JOIN product_details p
ON p.product_id = s.prod_id
GROUP BY product_name
ORDER BY SUM(p.price * qty) DESC;
GO

-- 2.What is the total quantity, revenue and discount for each segment?
SELECT
	segment_name,
	SUM(qty) total_qty,
	CAST(SUM((1 - CAST(discount AS NUMERIC(10, 2)) / 100) * p.price * qty) AS NUMERIC(10, 2))total_revenue,
	SUM(discount) total_discount
FROM sales s
JOIN product_details p
ON p.product_id = s.prod_id
GROUP BY segment_name;
GO

-- 3.What is the top selling product for each segment?
WITH cte
AS (
	SELECT
		segment_name,
		product_name,
		CAST(SUM((1 - CAST(discount AS NUMERIC(10, 2)) / 100) * p.price * qty) AS NUMERIC(10, 2))total_revenue
	FROM sales s
	JOIN product_details p
	ON p.product_id = s.prod_id
	GROUP BY segment_name, product_name),
innerCte
AS (
	SELECT 
		segment_name,
		product_name,
		total_revenue,
		ROW_NUMBER() OVER(PARTITION BY segment_name ORDER BY total_revenue DESC) r_n
	FROM cte)

SELECT 
	segment_name,
	product_name,
	total_revenue
FROM innerCte
WHERE r_n = 1
GO

-- 4.What is the total quantity, revenue and discount for each category?
SELECT
	category_name,
	SUM(qty) total_qty,
	CAST(SUM((1 - CAST(discount AS NUMERIC(10, 2)) / 100) * p.price * qty) AS NUMERIC(10, 2))total_revenue,
	SUM(discount) total_discount
FROM sales s
JOIN product_details p
ON p.product_id = s.prod_id
GROUP BY category_name;
GO

-- 5.What is the top selling product for each category?
WITH cte
AS (
	SELECT
		category_name,
		product_name,
		CAST(SUM((1 - CAST(discount AS NUMERIC(10, 2)) / 100) * p.price * qty) AS NUMERIC(10, 2))total_revenue
	FROM sales s
	JOIN product_details p
	ON p.product_id = s.prod_id
	GROUP BY category_name, product_name),
innerCte
AS (
	SELECT 
		category_name,
		product_name,
		total_revenue,
		ROW_NUMBER() OVER(PARTITION BY category_name ORDER BY total_revenue DESC) r_n
	FROM cte)

SELECT 
	category_name,
	product_name,
	total_revenue
FROM innerCte
WHERE r_n = 1
GO

-- 6.What is the percentage split of revenue by product for each segment?
WITH cte
AS (
	SELECT 
		segment_name,
		CAST(SUM((1 - CAST(discount AS NUMERIC(10, 2)) / 100) * p.price * qty) AS NUMERIC(10, 2)) total_revenue
	FROM sales s
	JOIN product_details p
	ON p.product_id = s.prod_id
	GROUP BY segment_name),

innerCte
AS (
	SELECT 
		segment_name,
		product_name,
		CAST(SUM((1 - CAST(discount AS NUMERIC(10, 2)) / 100) * p.price * qty) AS NUMERIC(10, 2)) prod_total_revenue
	FROM sales s
	JOIN product_details p
	ON p.product_id = s.prod_id
	GROUP BY segment_name, product_name)

SELECT 
	c.segment_name,
	product_name,
	CAST(prod_total_revenue / total_revenue * 100 AS NUMERIC(10, 2)) AS rev_perc
FROM cte c
JOIN innerCte i
ON c.segment_name = i.segment_name
ORDER BY segment_name;
GO

-- 7.What is the percentage split of revenue by segment for each category?
WITH cte
AS (
	SELECT 
		category_name,
		CAST(SUM((1 - CAST(discount AS NUMERIC(10, 2)) / 100) * p.price * qty) AS NUMERIC(10, 2)) total_revenue
	FROM sales s
	JOIN product_details p
	ON p.product_id = s.prod_id
	GROUP BY category_name),

innerCte
AS (
	SELECT 
		category_name,
		product_name,
		CAST(SUM((1 - CAST(discount AS NUMERIC(10, 2)) / 100) * p.price * qty) AS NUMERIC(10, 2)) prod_total_revenue
	FROM sales s
	JOIN product_details p
	ON p.product_id = s.prod_id
	GROUP BY category_name, product_name)

SELECT 
	c.category_name,
	product_name,
	CAST(prod_total_revenue / total_revenue * 100 AS NUMERIC(10, 2)) AS rev_perc
FROM cte c
JOIN innerCte i
ON c.category_name = i.category_name
ORDER BY category_name;
GO

-- 8.What is the percentage split of total revenue by category?
WITH cte
AS (
	SELECT 
		category_name,
		CAST(SUM((1 - CAST(discount AS NUMERIC(10, 2)) / 100) * p.price * qty) AS NUMERIC(10, 2)) total_revenue
	FROM sales s
	JOIN product_details p
	ON p.product_id = s.prod_id
	GROUP BY category_name),

innerCte
AS (
	SELECT 
		category_name,
		product_name,
		CAST(SUM((1 - CAST(discount AS NUMERIC(10, 2)) / 100) * p.price * qty) AS NUMERIC(10, 2)) prod_total_revenue
	FROM sales s
	JOIN product_details p
	ON p.product_id = s.prod_id
	GROUP BY category_name, product_name)

SELECT 
	c.category_name,
	product_name,
	CAST(prod_total_revenue / total_revenue * 100 AS NUMERIC(10, 2)) AS rev_perc
FROM cte c
JOIN innerCte i
ON c.category_name = i.category_name
ORDER BY category_name;
GO

-- 9.What is the total transaction “penetration” for each product? (hint: penetration = number of transactions where at least 1 quantity of a product was purchased divided by total number of transactions)
WITH cte_1 AS(
	SELECT
		prod_id,
		COUNT(DISTINCT txn_id) AS prod_c
	FROM sales
	GROUP BY prod_id
	),
	cte_2 AS(
	SELECT
		COUNT(DISTINCT txn_id) AS total_txn
	FROM
	sales
	)
	SELECT
		b.product_name,
		CAST(ROUND(100 * CAST(prod_c AS NUMERIC(10, 2)) / total_txn, 2) AS NUMERIC(10, 2)) percentage
	FROM cte_1 a
	CROSS JOIN cte_2 
	INNER JOIN product_details b 
	ON a.prod_id = b.product_id;
GO

-- 10.What is the most common combination of at least 1 quantity of any 3 products in a 1 single transaction?
DROP TABLE IF EXISTS #tm;
GO

SELECT x, y, prod_id z, b.txn_id
INTO #tm
FROM
	(SELECT a.prod_id x, b.prod_id y, a.txn_id
	FROM sales a
	CROSS JOIN sales b
	WHERE a.txn_id = b.txn_id AND
	a.prod_id != b.prod_id) AS tempp
CROSS JOIN sales b
WHERE tempp.txn_id = b.txn_id AND
prod_id != x AND
prod_id != y
ORDER BY b.txn_id

-- Bit solution
DROP TABLE IF EXISTS #tx;
GO

WITH cte
AS(
	SELECT
		p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12,
		COUNT(*) freq
	FROM
		(SELECT 
			DISTINCT
			(CASE
				WHEN 'c4a632' IN (x, y, z)
					THEN 1
				ELSE 0
			END) p1,
			(CASE
				WHEN 'e83aa3' IN (x, y, z)
					THEN 1
				ELSE 0
			END) p2,
			(CASE
				WHEN 'e31d39' IN (x, y, z)
					THEN 1
				ELSE 0
			END) p3,
			(CASE
				WHEN 'd5e9a6' IN (x, y, z)
					THEN 1
				ELSE 0
			END) p4,
			(CASE
				WHEN '72f5d4' IN (x, y, z)
					THEN 1
				ELSE 0
			END) p5,
			(CASE
				WHEN '9ec847' IN (x, y, z)
					THEN 1
				ELSE 0
			END) p6,
			(CASE
				WHEN '5d267b' IN (x, y, z)
					THEN 1
				ELSE 0
			END) p7,
			(CASE
				WHEN 'c8d436' IN (x, y, z)
					THEN 1
				ELSE 0
			END) p8,
			(CASE
				WHEN '2a2353' IN (x, y, z)
					THEN 1
				ELSE 0
			END) p9,
			(CASE
				WHEN 'f084eb' IN (x, y, z)
					THEN 1
				ELSE 0
			END) p10,
			(CASE
				WHEN 'b9a74d' IN (x, y, z)
					THEN 1
				ELSE 0
			END) p11,
			(CASE
				WHEN '2feb6b' IN (x, y, z)
					THEN 1
				ELSE 0
			END) p12,
			txn_id
		FROM #tm) AS temp_x
	GROUP BY p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12)

SELECT
TOP 1
*
INTO #tx
FROM cte
ORDER BY freq DESC

SELECT * FROM #tx;
GO
-- The most bought combination of 3 Product are:
-- 9ec847 -	Grey Fashion Jacket - Womens
-- 5d267 - White Tee Shirt - Mens
-- c8d436 - Teal Button Up Shirt - Mens
-- WITH COUNT of 352 Times

-------------------------
-- Reporting Challange --
-------------------------
-- Procedure For All Questions

DROP PROCEDURE IF EXISTS commonCombination;
GO

CREATE PROCEDURE commonCombination @monthN INT
AS
	-- Q1
	SELECT 
		TOP 3
		product_name,
		SUM(p.price * qty) revenue
	FROM sales s
	JOIN product_details p
	ON p.product_id = s.prod_id
	WHERE DATEPART(MONTH, start_txn_time) = @monthN
	GROUP BY product_name
	ORDER BY SUM(p.price * qty) DESC;

	-- Q2
	SELECT
		segment_name,
		SUM(qty) total_qty,
		CAST(SUM((1 - CAST(discount AS NUMERIC(10, 2)) / 100) * p.price * qty) AS NUMERIC(10, 2))total_revenue,
		SUM(discount) total_discount
	FROM sales s
	JOIN product_details p
	ON p.product_id = s.prod_id
	WHERE DATEPART(MONTH, start_txn_time) = @monthN
	GROUP BY segment_name;

	-- Q3
	WITH cte
	AS (
		SELECT
			segment_name,
			product_name,
			CAST(SUM((1 - CAST(discount AS NUMERIC(10, 2)) / 100) * p.price * qty) AS NUMERIC(10, 2))total_revenue
		FROM sales s
		JOIN product_details p
		ON p.product_id = s.prod_id
		WHERE DATEPART(MONTH, start_txn_time) = @monthN
		GROUP BY segment_name, product_name),
	innerCte
	AS (
		SELECT 
			segment_name,
			product_name,
			total_revenue,
			ROW_NUMBER() OVER(PARTITION BY segment_name ORDER BY total_revenue DESC) r_n
		FROM cte)

	SELECT 
		segment_name,
		product_name,
		total_revenue
	FROM innerCte
	WHERE r_n = 1;

	-- Q4
	SELECT
		category_name,
		SUM(qty) total_qty,
		CAST(SUM((1 - CAST(discount AS NUMERIC(10, 2)) / 100) * p.price * qty) AS NUMERIC(10, 2))total_revenue,
		SUM(discount) total_discount
	FROM sales s
	JOIN product_details p
	ON p.product_id = s.prod_id
	WHERE DATEPART(MONTH, start_txn_time) = @monthN
	GROUP BY category_name;

	-- Q5
	WITH cte
	AS (
		SELECT
			category_name,
			product_name,
			CAST(SUM((1 - CAST(discount AS NUMERIC(10, 2)) / 100) * p.price * qty) AS NUMERIC(10, 2))total_revenue
		FROM sales s
		JOIN product_details p
		ON p.product_id = s.prod_id
		WHERE DATEPART(MONTH, start_txn_time) = @monthN
		GROUP BY category_name, product_name),
	innerCte
	AS (
		SELECT 
			category_name,
			product_name,
			total_revenue,
			ROW_NUMBER() OVER(PARTITION BY category_name ORDER BY total_revenue DESC) r_n
		FROM cte)

	SELECT 
		category_name,
		product_name,
		total_revenue
	FROM innerCte
	WHERE r_n = 1;

	-- Q6
	WITH cte
	AS (
		SELECT 
			segment_name,
			CAST(SUM((1 - CAST(discount AS NUMERIC(10, 2)) / 100) * p.price * qty) AS NUMERIC(10, 2)) total_revenue
		FROM sales s
		JOIN product_details p
		ON p.product_id = s.prod_id
		WHERE DATEPART(MONTH, start_txn_time) = @monthN
		GROUP BY segment_name),

	innerCte
	AS (
		SELECT 
			segment_name,
			product_name,
			CAST(SUM((1 - CAST(discount AS NUMERIC(10, 2)) / 100) * p.price * qty) AS NUMERIC(10, 2)) prod_total_revenue
		FROM sales s
		JOIN product_details p
		ON p.product_id = s.prod_id
		WHERE DATEPART(MONTH, start_txn_time) = @monthN
		GROUP BY segment_name, product_name)

	SELECT 
		c.segment_name,
		product_name,
		CAST(prod_total_revenue / total_revenue * 100 AS NUMERIC(10, 2)) AS rev_perc
	FROM cte c
	JOIN innerCte i
	ON c.segment_name = i.segment_name
	ORDER BY segment_name;

	-- Q7
	WITH cte
	AS (
		SELECT 
			category_name,
			CAST(SUM((1 - CAST(discount AS NUMERIC(10, 2)) / 100) * p.price * qty) AS NUMERIC(10, 2)) total_revenue
		FROM sales s
		JOIN product_details p
		ON p.product_id = s.prod_id
		WHERE DATEPART(MONTH, start_txn_time) = @monthN
		GROUP BY category_name),

	innerCte
	AS (
		SELECT 
			category_name,
			product_name,
			CAST(SUM((1 - CAST(discount AS NUMERIC(10, 2)) / 100) * p.price * qty) AS NUMERIC(10, 2)) prod_total_revenue
		FROM sales s
		JOIN product_details p
		ON p.product_id = s.prod_id
		WHERE DATEPART(MONTH, start_txn_time) = @monthN
		GROUP BY category_name, product_name)

	SELECT 
		c.category_name,
		product_name,
		CAST(prod_total_revenue / total_revenue * 100 AS NUMERIC(10, 2)) AS rev_perc
	FROM cte c
	JOIN innerCte i
	ON c.category_name = i.category_name
	ORDER BY category_name;

	-- Q8
	WITH cte
	AS (
		SELECT 
			category_name,
			CAST(SUM((1 - CAST(discount AS NUMERIC(10, 2)) / 100) * p.price * qty) AS NUMERIC(10, 2)) total_revenue
		FROM sales s
		JOIN product_details p
		ON p.product_id = s.prod_id
		WHERE DATEPART(MONTH, start_txn_time) = @monthN
		GROUP BY category_name),

	innerCte
	AS (
		SELECT 
			category_name,
			product_name,
			CAST(SUM((1 - CAST(discount AS NUMERIC(10, 2)) / 100) * p.price * qty) AS NUMERIC(10, 2)) prod_total_revenue
		FROM sales s
		JOIN product_details p
		ON p.product_id = s.prod_id
		WHERE DATEPART(MONTH, start_txn_time) = @monthN
		GROUP BY category_name, product_name)

	SELECT 
		c.category_name,
		product_name,
		CAST(prod_total_revenue / total_revenue * 100 AS NUMERIC(10, 2)) AS rev_perc
	FROM cte c
	JOIN innerCte i
	ON c.category_name = i.category_name
	ORDER BY category_name;

	-- Q9
	WITH cte_1 
	AS(
	SELECT
		prod_id,
		COUNT(DISTINCT txn_id) AS prod_c
	FROM sales
	WHERE DATEPART(MONTH, start_txn_time) = @monthN
	GROUP BY prod_id
	),
	cte_2 
	AS(
	SELECT
		COUNT(DISTINCT txn_id) AS total_txn
	FROM sales
	WHERE DATEPART(MONTH, start_txn_time) = @monthN
	)
	SELECT
		b.product_name,
		CAST(ROUND(100 * CAST(prod_c AS NUMERIC(10, 2)) / total_txn, 2) AS NUMERIC(10, 2)) per
	FROM cte_1 a
	CROSS JOIN cte_2 
	INNER JOIN product_details b ON a.prod_id = b.product_id;

	-- Q10
	WITH cte
	AS(
		SELECT
			p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12,
			COUNT(*) freq
		FROM
			(SELECT 
				DISTINCT
				(CASE
					WHEN 'c4a632' IN (x, y, z)
						THEN 1
					ELSE 0
				END) p1,
				(CASE
					WHEN 'e83aa3' IN (x, y, z)
						THEN 1
					ELSE 0
				END) p2,
				(CASE
					WHEN 'e31d39' IN (x, y, z)
						THEN 1
					ELSE 0
				END) p3,
				(CASE
					WHEN 'd5e9a6' IN (x, y, z)
						THEN 1
					ELSE 0
				END) p4,
				(CASE
					WHEN '72f5d4' IN (x, y, z)
						THEN 1
					ELSE 0
				END) p5,
				(CASE
					WHEN '9ec847' IN (x, y, z)
						THEN 1
					ELSE 0
				END) p6,
				(CASE
					WHEN '5d267b' IN (x, y, z)
						THEN 1
					ELSE 0
				END) p7,
				(CASE
					WHEN 'c8d436' IN (x, y, z)
						THEN 1
					ELSE 0
				END) p8,
				(CASE
					WHEN '2a2353' IN (x, y, z)
						THEN 1
					ELSE 0
				END) p9,
				(CASE
					WHEN 'f084eb' IN (x, y, z)
						THEN 1
					ELSE 0
				END) p10,
				(CASE
					WHEN 'b9a74d' IN (x, y, z)
						THEN 1
					ELSE 0
				END) p11,
				(CASE
					WHEN '2feb6b' IN (x, y, z)
						THEN 1
					ELSE 0
				END) p12,
				txn_id
			FROM (SELECT x, y, prod_id z, b.txn_id
					FROM
						(SELECT a.prod_id x, b.prod_id y, a.txn_id
						FROM sales a
						CROSS JOIN sales b
						WHERE a.txn_id = b.txn_id AND
						a.prod_id != b.prod_id AND
						DATEPART(MONTH, a.start_txn_time) = @monthN AND
						DATEPART(MONTH, b.start_txn_time) = @monthN) AS tempp
					CROSS JOIN sales b
					WHERE tempp.txn_id = b.txn_id AND
					prod_id != x AND
					prod_id != y AND
					DATEPART(MONTH, b.start_txn_time) = @monthN)AS t) AS temp_x
		GROUP BY p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12)

		SELECT
		TOP 1
		*
		FROM cte
		ORDER BY freq DESC
GO

EXEC commonCombination @monthN = 1
GO

--------------------
-- Bonus Question --
--------------------

SELECT
	product_id,
	price,
	CONCAT(a.level_text, ' ', b.level_text, ' - ', c.level_text) product_name,
	c.id category_id,
	b.id segment_id,
	a.id style_id,
	c.level_text category_name,
	b.level_text segment_name,
	a.level_text style_name
FROM
	product_hierarchy a
	JOIN product_hierarchy b 
	ON a.parent_id = b.id
	JOIN product_hierarchy c 
	ON b.parent_id = c.id
	JOIN product_prices x 
	ON a.id = x.id