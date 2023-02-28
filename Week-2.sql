-- Creating Tables For Week 2 Challnages --
DROP TABLE IF EXISTS #cleaned_customer_orders;
DROP TABLE IF EXISTS #extras;
DROP TABLE IF EXISTS #exclusions;
DROP TABLE IF EXISTS runners;
CREATE TABLE runners (
  "runner_id" INTEGER,
  "registration_date" DATE
);
GO
INSERT INTO runners
  (runner_id, registration_date)
VALUES
  (1, '2021-01-01'),
  (2, '2021-01-03'),
  (3, '2021-01-08'),
  (4, '2021-01-15');
GO

DROP TABLE IF EXISTS customer_orders;
CREATE TABLE customer_orders (
  "order_id" INTEGER,
  "customer_id" INTEGER,
  "pizza_id" INTEGER,
  "exclusions" VARCHAR(4),
  "extras" VARCHAR(4),
  "order_time" DATETIME
);
GO

INSERT INTO customer_orders
  ("order_id", "customer_id", "pizza_id", "exclusions", "extras", "order_time")
VALUES
  ('1', '101', '1', '', '', '2020-01-01 18:05:02'),
  ('2', '101', '1', '', '', '2020-01-01 19:00:52'),
  ('3', '102', '1', '', '', '2020-01-02 23:51:23'),
  ('3', '102', '2', '', NULL, '2020-01-02 23:51:23'),
  ('4', '103', '1', '4', '', '2020-01-04 13:23:46'),
  ('4', '103', '1', '4', '', '2020-01-04 13:23:46'),
  ('4', '103', '2', '4', '', '2020-01-04 13:23:46'),
  ('5', '104', '1', 'null', '1', '2020-01-08 21:00:29'),
  ('6', '101', '2', 'null', 'null', '2020-01-08 21:03:13'),
  ('7', '105', '2', 'null', '1', '2020-01-08 21:20:29'),
  ('8', '102', '1', 'null', 'null', '2020-01-09 23:54:33'),
  ('9', '103', '1', '4', '1, 5', '2020-01-10 11:22:59'),
  ('10', '104', '1', 'null', 'null', '2020-01-11 18:34:49'),
  ('10', '104', '1', '2, 6', '1, 4', '2020-01-11 18:34:49');
GO

DROP TABLE IF EXISTS runner_orders;
CREATE TABLE runner_orders (
  "order_id" INTEGER,
  "runner_id" INTEGER,
  "pickup_time" VARCHAR(19),
  "distance" VARCHAR(7),
  "duration" VARCHAR(10),
  "cancellation" VARCHAR(23)
);
GO

INSERT INTO runner_orders
  ("order_id", "runner_id", "pickup_time", "distance", "duration", "cancellation")
VALUES
  ('1', '1', '2020-01-01 18:15:34', '20km', '32 minutes', ''),
  ('2', '1', '2020-01-01 19:10:54', '20km', '27 minutes', ''),
  ('3', '1', '2020-01-03 00:12:37', '13.4km', '20 mins', NULL),
  ('4', '2', '2020-01-04 13:53:03', '23.4', '40', NULL),
  ('5', '3', '2020-01-08 21:10:57', '10', '15', NULL),
  ('6', '3', 'null', 'null', 'null', 'Restaurant Cancellation'),
  ('7', '2', '2020-01-08 21:30:45', '25km', '25mins', 'null'),
  ('8', '2', '2020-01-10 00:15:02', '23.4 km', '15 minute', 'null'),
  ('9', '2', 'null', 'null', 'null', 'Customer Cancellation'),
  ('10', '1', '2020-01-11 18:50:20', '10km', '10minutes', 'null');
GO

DROP TABLE IF EXISTS pizza_names;
CREATE TABLE pizza_names (
  "pizza_id" INTEGER,
  "pizza_name" TEXT
);
GO

INSERT INTO pizza_names
  ("pizza_id", "pizza_name")
VALUES
  (1, 'Meatlovers'),
  (2, 'Vegetarian');
GO

DROP TABLE IF EXISTS pizza_recipes;
CREATE TABLE pizza_recipes (
  "pizza_id" INTEGER,
  "toppings" TEXT
);
GO

INSERT INTO pizza_recipes
  ("pizza_id", "toppings")
VALUES
  (1, '1, 2, 3, 4, 5, 6, 8, 10'),
  (2, '4, 6, 7, 9, 11, 12');
GO

DROP TABLE IF EXISTS pizza_toppings;
CREATE TABLE pizza_toppings (
  "topping_id" INTEGER,
  "topping_name" TEXT
);
GO

INSERT INTO pizza_toppings
  ("topping_id", "topping_name")
VALUES
  (1, 'Bacon'),
  (2, 'BBQ Sauce'),
  (3, 'Beef'),
  (4, 'Cheese'),
  (5, 'Chicken'),
  (6, 'Mushrooms'),
  (7, 'Onions'),
  (8, 'Pepperoni'),
  (9, 'Peppers'),
  (10, 'Salami'),
  (11, 'Tomatoes'),
  (12, 'Tomato Sauce');
GO

-- Week 2 Challange --

----------------------
-- A. Pizza Metrics --
----------------------

-- 1.How many pizzas were ordered?
SELECT COUNT(*) Orders
FROM customer_orders;
GO
-- 2.How many unique customer orders were made
SELECT COUNT(DISTINCT customer_id) Unique_customer
FROM customer_orders;
GO

-- 3.How many successful orders were delivered by each runner?
SELECT COUNT(order_id) Successful_Orders
FROM runner_orders
WHERE duration != 'null';
Go

-- 4.How many of each type of pizza was delivered?
SELECT pizza_id, COUNT(*) number_of_orders
FROM customer_orders
WHERE order_id NOT IN(
	SELECT order_id
	FROM runner_orders
	WHERE duration = 'null')
GROUP BY pizza_id;
GO

-- 5.How many Vegetarian and Meatlovers were ordered by each customer?
SELECT customer_id, pizza_id, COUNT(*) number_of_orders
FROM customer_orders
GROUP BY pizza_id, customer_id;
GO

-- 6.What was the maximum number of pizzas delivered in a single order?
SELECT TOP 1 order_id, COUNT(*) Max_orders
FROM customer_orders
GROUP BY order_id, customer_id
ORDER BY COUNT(*) DESC;
GO

-- 7.For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
WITH cte
AS(SELECT
		customer_id,
		COALESCE(CASE
			WHEN exclusions != '' AND exclusions != 'null'
				THEN (SELECT COUNT(c) 
						FROM (SELECT CAST(LTRIM(value) AS INT) c FROM STRING_SPLIT(exclusions, ',')) AS x_table)
		END, 0)
		+
		COALESCE(CASE
			WHEN extras != '' AND extras != 'null' AND extras != 'NaN'
				THEN (SELECT COUNT(c) 
						FROM (SELECT CAST(LTRIM(value) AS INT) c FROM STRING_SPLIT(extras, ',')) AS x_table)
		END, 0) no_of_changes
	FROM customer_orders
	WHERE order_id NOT IN(
	SELECT order_id
	FROM runner_orders
	WHERE duration = 'null'))

SELECT customer_id, SUM(no_of_changes) no_of_changes
FROM cte
WHERE no_of_changes > 0
GROUP BY customer_id;
GO

-- 8.How many pizzas were delivered that had both exclusions and extras?
SELECT COUNT(*) pizza_count
FROM customer_orders
WHERE 
	exclusions != '' AND 
	exclusions != 'null' AND 
	extras != '' AND 
	extras != 'null' 
	AND extras != 'NaN' 
	AND order_id NOT IN(
		SELECT order_id
		FROM runner_orders
		WHERE duration = 'null');
GO

--9.What was the total volume of pizzas ordered for each hour of the day?
SELECT pizza_id, DATEPART(HOUR, order_time) Hour, DATEPART(DAY, order_time) Day, COUNT(*) ordered_pizza
FROM customer_orders
GROUP BY DATEPART(HOUR, order_time), DATEPART(DAY, order_time), pizza_id;
GO

--10.What was the volume of orders for each day of the week?
SELECT DATEPART(DAY, order_time) Day, DATEPART(WEEK, order_time) Week, COUNT(*) ordered_pizza
FROM customer_orders
GROUP BY DATEPART(DAY, order_time), DATEPART(WEEK, order_time);
GO

---------------------------------------
-- B. Runner and Customer Experience --
---------------------------------------

-- 1.How many runners signed up for each 1 week period?
SELECT DATEPART(WEEK, registration_date) week, COUNT(*) no_of_sign_ups
FROM runners
GROUP BY DATEPART(WEEK, registration_date);
GO

-- 2.What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
SELECT runner_id, AVG(DATEPART(MINUTE, CAST(pickup_time AS DATETIME) - order_time)) avg_pickup_time
FROM runner_orders r
JOIN customer_orders c
ON c.order_id = r.order_id
WHERE pickup_time != 'null'
GROUP BY runner_id;
GO

--3.Is there any relationship between the number of pizzas and how long the order takes to prepare?
WITH cte
AS (SELECT c.order_id o_id, DATEPART(MINUTE, CAST(pickup_time AS DATETIME) - order_time) prep_time
FROM runner_orders r
JOIN customer_orders c
ON c.order_id = r.order_id
WHERE pickup_time != 'null')

SELECT o_id, prep_time, COUNT(o_id) no_pizza
FROM cte
GROUP BY o_id, prep_time
ORDER BY COUNT(o_id);
GO

-- We can see in most of the cases prep_time is higher where number of pizza is > 1.

--4.What was the average distance travelled for each customer?
SELECT 
	customer_id,
	CAST(ROUND(AVG(CAST(RTRIM(REPLACE(distance, 'km', '')) AS NUMERIC(10,2))), 2) AS DECIMAL(18,2)) avg_dist
FROM runner_orders r
JOIN customer_orders c
ON c.order_id = r.order_id
WHERE distance != 'null'
GROUP BY customer_id;
GO

--5.What was the difference between the longest and shortest delivery times for all orders?
WITH cte
AS(
	SELECT MAX(d) l, MIN(d) s
	FROM	
	(SELECT
		CAST((SELECT TOP 1 RTRIM(value) c FROM STRING_SPLIT(duration, 'm') AS tempX) AS INT) d
	FROM runner_orders
	WHERE duration != 'null')x_temp)


SELECT 
	order_id,
	(SELECT l FROM cte)
	-
	CAST((SELECT TOP 1 RTRIM(value) c FROM STRING_SPLIT(duration, 'm') AS tempX) AS INT) long_diff,
	CAST((SELECT TOP 1 RTRIM(value) c FROM STRING_SPLIT(duration, 'm') AS tempX) AS INT)
	-
	(SELECT s FROM cte) short_diff
FROM runner_orders r
WHERE duration != 'null';
GO

-- 6.What was the average speed for each runner for each delivery and do you notice any trend for these values?
SELECT
	order_id,
	runner_id,
	CAST(ROUND(CAST(RTRIM(REPLACE(distance, 'km', '')) AS DECIMAL(18,2))
	/
	CAST((SELECT TOP 1 RTRIM(value) c FROM STRING_SPLIT(duration, 'm') AS tempX) AS DECIMAL(18,2)), 2) * 60 AS DECIMAL(18,2)) avg_speed
FROM runner_orders
WHERE duration != 'null';
GO

-- 7.What is the successful delivery percentage for each runner
WITH cte
AS (
	SELECT
		runner_id,
		total_orders - 1 s_orders,
		total_orders
	FROM  (
		SELECT 
		runner_id, 
		COUNT(runner_id) total_orders
		FROM runner_orders
		GROUP BY runner_id)tempX
	WHERE runner_id IN(
				SELECT runner_id
				FROM runner_orders
				WHERE duration = 'null')

	UNION 

	SELECT
		runner_id,
		total_orders - 1 s_orders,
		total_orders
	FROM  (
		SELECT 
		runner_id, 
		COUNT(runner_id) total_orders
		FROM runner_orders
		GROUP BY runner_id)tempX
	WHERE runner_id IN(
				SELECT runner_id
				FROM runner_orders
				WHERE duration != 'null'))

SELECT 
	runner_id,
	s_orders,
	total_orders,
	CAST(CAST(s_orders AS DECIMAL(18,2))/ CAST(total_orders AS DECIMAL(18,2)) * 100 AS DECIMAL(18,2))AS s_percentage
FROM cte;
GO

--------------------------------
-- C. Ingredient Optimisation --
--------------------------------
-- Creating Temp tables
SELECT 
    order_id,
    customer_id,
    pizza_id,
    CASE
        WHEN exclusions = 'null' OR exclusions = ''
			THEN null
        ELSE exclusions
    END as exclusions,
    CASE
        WHEN extras = 'null' OR extras = ''  OR extras = 'NaN' 
			THEN null
        ELSE extras
    END as extras,
    order_time
INTO #cleaned_customer_orders
FROM customer_orders;
GO

ALTER TABLE #cleaned_customer_orders
ADD record_id INT IDENTITY(1,1);
GO

-- to generate extra table
SELECT		
	c.record_id,
	c.order_id,
	TRIM(e.value) AS topping_id
INTO #extras
FROM 
	#cleaned_customer_orders as c
	CROSS APPLY string_split(c.extras, ',') as e
;
GO
-- to generate exclusions table
SELECT		
	c.record_id,
	TRIM(e.value) AS topping_id
INTO #exclusions
FROM 
	#cleaned_customer_orders as c
	CROSS APPLY string_split(c.exclusions, ',') as e
;
GO
--
-- 1.What are the standard ingredients for each pizza?
WITH cte
AS (
	SELECT 
		pizza_id,
		CAST(LTRIM(value) AS INT) t_id
	FROM pizza_recipes
	CROSS APPLY STRING_SPLIT(CAST(toppings AS VARCHAR), ',')
)

SELECT 
	pizza_id,
	t_id,
	topping_name
FROM cte c
JOIN pizza_toppings pt
ON c.t_id = pt.topping_id;
GO


-- 2.What was the most commonly added extra?
WITH cte
AS (
	SELECT
	  order_id,
	  (CASE
			WHEN extras != '' AND extras != 'null' AND extras != 'NaN'
				THEN CAST(LTRIM(value) AS INT) 
			ELSE 0
		END) x
	FROM customer_orders
	CROSS APPLY STRING_SPLIT(extras, ','))

SELECT TOP 1 x topping_id, COUNT(x) frequency
FROM cte
WHERE x != 0
GROUP BY  x
ORDER BY COUNT(X) DESC;
GO
-- 3.What was the most common exclusion
WITH cte
AS (
	SELECT
	  order_id,
	  (CASE
				WHEN exclusions != '' AND exclusions != 'null'
					THEN CAST(LTRIM(value) AS INT) 
				ELSE 0
		END) x
	FROM customer_orders
	CROSS APPLY STRING_SPLIT(exclusions, ','))

SELECT TOP 1 x topping_id, COUNT(x) frequency
FROM cte
WHERE x != 0
GROUP BY  x
ORDER BY COUNT(x) DESC;
GO

-- 4.Generate an order item for each record in the customers_orders table in specified format.
WITH extras_cte AS
(
	SELECT 
		record_id,
		'Extra ' + STRING_AGG(CAST(t.topping_name AS VARCHAR), ', ') as record_options
	FROM
		#extras e,
		pizza_toppings t
	WHERE e.topping_id = t.topping_id
	GROUP BY record_id
),
exclusions_cte AS
(
	SELECT 
		record_id,
		'Exclude ' + STRING_AGG(CAST(t.topping_name AS VARCHAR), ', ') as record_options
	FROM
		#exclusions e,
		pizza_toppings t
	WHERE e.topping_id = t.topping_id
	GROUP BY record_id
),
union_cte AS
(
	SELECT * FROM extras_cte
	UNION
	SELECT * FROM exclusions_cte
)

SELECT 
	c.record_id,
	CONCAT_WS(' - ', CAST(p.pizza_name AS VARCHAR), STRING_AGG(cte.record_options, ' - ')) order_details
FROM 
	#cleaned_customer_orders c
	JOIN pizza_names p
	ON c.pizza_id = p.pizza_id
	LEFT JOIN union_cte cte
	ON c.record_id = cte.record_id
GROUP BY
	c.record_id,
	CAST(p.pizza_name AS VARCHAR)
ORDER BY c.record_id;
GO
-- 5.Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients
DROP TABLE IF EXISTS #cleaned_toppings;
GO

SELECT
	p.pizza_id,
	TRIM(t.value) AS topping_id,
	pt.topping_name
INTO #cleaned_toppings
FROM 
pizza_recipes as p
CROSS APPLY string_split(CAST(p.toppings AS VARCHAR), ',') as t
JOIN pizza_toppings as pt
ON TRIM(t.value) = pt.topping_id;
GO

WITH ingredients_cte AS
(
SELECT 
	c.record_id,
	t.topping_name,
	CASE
		WHEN t.topping_id 
		IN (select topping_id from #extras e where e.record_id = c.record_id) 
		THEN 2
		WHEN t.topping_id 
		IN (select topping_id from #exclusions e where e.record_id = c.record_id) 
		THEN 0
		ELSE 1 
	END as times_used
	FROM   
		#cleaned_customer_orders AS c
		JOIN #cleaned_toppings AS t
		ON c.pizza_id = t.pizza_id
) 

SELECT 
    CAST(topping_name AS VARCHAR) topping_name,
    SUM(times_used) AS times_used 
FROM ingredients_cte
GROUP BY CAST(topping_name AS VARCHAR)
ORDER BY SUM(times_used) DESC;

-- 6.What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?
WITH cte
AS (
	SELECT 
		pizza_id,
		CAST(LTRIM(value) AS INT) topping_id,
		topping_name
	FROM pizza_recipes pr
	CROSS APPLY string_split(CAST(pr.toppings AS VARCHAR), ',') as t
	JOIN pizza_toppings pt
	ON TRIM(t.value) = pt.topping_id
),
innerCte
AS
(
SELECT 
	c.record_id,
	CAST(t.topping_name AS VARCHAR) tn,
	CASE
		WHEN t.topping_id 
		IN (select topping_id from #extras e where e.record_id = c.record_id) 
		THEN 2
		WHEN t.topping_id 
		IN (select topping_id from #exclusions e where e.record_id = c.record_id) 
		THEN 0
		ELSE 1 
	END as times_used
	FROM   
		#cleaned_customer_orders AS c
		JOIN cte t
		ON c.pizza_id = t.pizza_id
)
SELECT
	tn,
	SUM(times_used) times_used
FROM innerCte
GROUP BY tn
ORDER BY SUM(times_used) DESC;
GO

----------------------------
-- D. Pricing and Ratings --
----------------------------

-- 1.If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - how much money has Pizza Runner made so far if there are no delivery fees?
SELECT
	runner_id,
	SUM(CASE
		WHEN pizza_id = 1
			THEN 12
		ELSE 10
	END) cost

FROM runner_orders r
JOIN customer_orders c
ON r.order_id = c.order_id
WHERE duration != 'null'
GROUP BY runner_id;
GO

-- 2.What if there was an additional $1 charge for any pizza extras? - Add cheese is $1 extra
WITH cte
AS(
	SELECT
	c.order_id,
	runner_id,
	(CASE
		WHEN pizza_id = 1
			THEN 12
		ELSE 10
	END)
	+
	(CASE
		WHEN (SELECT COUNT(c) FROM (SELECT CAST(LTRIM(value) AS INT) c FROM STRING_SPLIT(extras, ',')) AS x_table) > 0
			THEN (SELECT COUNT(c) FROM (SELECT CAST(LTRIM(value) AS INT) c FROM STRING_SPLIT(extras, ',')) AS x_table)
		ELSE 0
	END) cost
	FROM runner_orders r
	JOIN #cleaned_customer_orders c
	ON r.order_id = c.order_id
	WHERE duration != 'null')
SELECT 
	runner_id,
	SUM(cost) cost
FROM cte
GROUP BY runner_id;
GO

-- 3.The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, 
--how would you design an additional table for this new dataset - generate a schema for this new table and insert your own data for ratings for each successful customer order between 1 to 5.

SELECT
	DISTINCT
	o.order_id,
	DATEPART(MINUTE, CAST(pickup_time AS DATETIME) - order_time)
	+
	CAST((SELECT TOP 1 RTRIM(value) c FROM STRING_SPLIT(duration, 'm') AS tempX) AS INT) total_time
FROM runner_orders r
JOIN #cleaned_customer_orders o
ON r.order_id = o.order_id
WHERE pickup_time != 'null'

DROP TABLE IF EXISTS runner_rating;
GO
CREATE TABLE runner_rating (
  "order_id" INT,
  "runner_id" INT,
  "delivery_time_pts" INT,
  "pizza_condition" INT,
  "rating" INT
);
GO


WITH cte
AS (
	SELECT r.order_id o_id, runner_id, CAST((SELECT TOP 1 RTRIM(value) c FROM STRING_SPLIT(duration, 'm') AS tempX) AS INT) delivery_time
	FROM runner_orders r
	JOIN #cleaned_customer_orders o
	ON r.order_id = o.order_id
	WHERE pickup_time != 'null')

INSERT INTO runner_rating(order_id, runner_id, delivery_time_pts, pizza_condition, rating)
SELECT
	*,
	FLOOR((pts + p_c) / 2)
FROM (SELECT
			o_id,
			runner_id,
			(CASE
				WHEN delivery_time <= 15
					THEN 5
				WHEN delivery_time BETWEEN 16 AND 25
					THEN 4
				WHEN delivery_time BETWEEN 26 AND 35
					THEN 3
				WHEN delivery_time BETWEEN 36 AND 45
					THEN 2
				ELSE
					1
			END) pts,
			(CASE 
				WHEN (SELECT abs(checksum(NewId()) % 6)) > 0
					THEN (SELECT abs(checksum(NewId()) % 6))
				ELSE 
					1
			END) p_c
		FROM cte) tempX;
GO

SELECT * FROM runner_rating;
GO

-- 4.Using your newly generated table - can you join all of the information together to form a table which has the following information for successful deliveries?
DROP TABLE IF EXISTS #temp_count;
GO

SELECT 
	customer_id,
	COUNT(customer_id) total_orders
INTO #temp_count
FROM #cleaned_customer_orders co
GROUP BY customer_id;
GO

WITH cte
AS (
	SELECT
		DISTINCT
		customer_id,
		c.order_id,
		r.runner_id,
		rating,
		order_time,
		pickup_time,
		DATEPART(MINUTE, CAST(pickup_time AS DATETIME) - order_time) time_between_order_and_pickup,
		CAST((SELECT TOP 1 RTRIM(value) c FROM STRING_SPLIT(duration, 'm') AS tempX) AS INT) delivery_duration,
		CAST(ROUND(CAST(RTRIM(REPLACE(distance, 'km', '')) AS DECIMAL(18,2))
		/
		CAST((SELECT TOP 1 RTRIM(value) c FROM STRING_SPLIT(duration, 'm') AS tempX) AS DECIMAL(18,2)), 2) * 60 AS DECIMAL(18,2)) avg_speed
	FROM runner_orders r
	JOIN #cleaned_customer_orders c
		ON r.order_id = c.order_id
	JOIN runner_rating rr
		ON c.order_id = rr.order_id
	WHERE duration != 'null')


SELECT 
		c.customer_id,
		c.order_id,
		runner_id,
		rating,
		order_time,
		pickup_time,
		time_between_order_and_pickup,
		delivery_duration,
		avg_speed,
		total_orders
FROM cte c
JOIN #temp_count t
ON c.customer_id = t.customer_id;
GO

-- 5.If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 per kilometre traveled - how much money does Pizza Runner have left over after these deliveries?
SELECT
	runner_id,
	SUM((CASE
		WHEN pizza_id = 1
			THEN 12
		ELSE 10
	END)
	+
	((CAST(RTRIM(REPLACE(distance, 'km', '')) AS NUMERIC(10,2))) * 0.30)) TOTAL_EARNED
FROM runner_orders r
JOIN customer_orders c
ON r.order_id = c.order_id
WHERE distance != 'null'
GROUP BY runner_id;
GO

-- BONUS QUESTION --
INSERT INTO pizza_names
VALUES (3, 'Supreme');

INSERT INTO pizza_recipes
VALUES (3, '1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12');

SELECT * FROM pizza_names;
GO
SELECT * FROM pizza_recipes;
GO