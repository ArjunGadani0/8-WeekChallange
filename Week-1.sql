-- CREATING TABLES

CREATE TABLE sales (
  "customer_id" VARCHAR(1),
  "order_date" DATE,
  "product_id" INTEGER
);
GO

INSERT INTO sales
  ("customer_id", "order_date", "product_id")
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
GO

CREATE TABLE menu (
  "product_id" INTEGER,
  "product_name" VARCHAR(5),
  "price" INTEGER
);
GO

INSERT INTO menu
  ("product_id", "product_name", "price")
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
GO  

CREATE TABLE members (
  "customer_id" VARCHAR(1),
  "join_date" DATE
);
GO

INSERT INTO members
  ("customer_id", "join_date")
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');
GO

-- 1.What is the total amount each customer spent at the restaurant?
SELECT s.customer_id, SUM(price) total_spend
FROM sales s
JOIN menu m 
ON s.product_id = m.product_id
GROUP BY s.customer_id;
GO

-- 2.How many days has each customer visited the restaurant?
SELECT customer_id, COUNT(DISTINCT order_date) num_visited
FROM sales
GROUP BY customer_id;
GO

-- 3.What was the first item from the menu purchased by each customer?
SELECT 
	st.customer_id,
	m.product_name
FROM(SELECT 
	customer_id,
	product_id,
	ROW_NUMBER() OVER (
		PARTITION BY customer_id
		ORDER BY order_date
		) cust_row
FROM sales) st
JOIN menu m
ON st.product_id = m.product_id
WHERE cust_row < 2;
GO

-- 4.What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT TOP 1
	m.product_name, 
	prod_count
FROM (
	SELECT product_id, COUNT(product_id) prod_count
	FROM sales
	GROUP BY product_id )x
JOIN menu m
ON x.product_id = m.product_id
ORDER BY x.product_id DESC;
GO

-- 5.Which item was the most popular for each customer?
WITH cte
AS(SELECT
		customer_id,
		product_id,
		RANK() OVER(PARTITION BY customer_id
				ORDER BY COUNT(product_id) DESC) r
		FROM sales
		GROUP BY customer_id, product_id)

SELECT 
	customer_id,
	m.product_name
FROM cte c
JOIN menu m
ON c.product_id = m.product_id
WHERE r < 2
ORDER BY customer_id;
GO

-- 6.Which item was purchased first by the customer after they became a member?
WITH cte
AS(SELECT 
	s.customer_id,
	product_id,
	ROW_NUMBER() OVER (
		PARTITION BY s.customer_id
		ORDER BY order_date
		) cust_row
	FROM sales s
	JOIN members mb
	ON s.customer_id = mb.customer_id
	WHERE order_date >= join_date)
SELECT 
	customer_id,
	m.product_name
FROM cte c
JOIN menu m
ON c.product_id = m.product_id
WHERE cust_row < 2;
GO

-- 7.Which item was purchased just before the customer became a member
SELECT 
	DISTINCT
	s.customer_id,
	m.product_name
FROM sales s
JOIN members mb
ON s.customer_id = mb.customer_id
JOIN menu m
ON s.product_id = m.product_id
WHERE order_date < join_date
ORDER BY s.customer_id;
GO

--8.What is the total items and amount spent for each member before they became a member?
SELECT 
	s.customer_id,
	COUNT(s.product_id) total_products,
	SUM(price) total_spent
FROM sales s
JOIN members mb
ON s.customer_id = mb.customer_id
JOIN menu m
ON s.product_id = m.product_id
WHERE order_date < join_date
GROUP BY s.customer_id
ORDER BY s.customer_id;

--9.If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
WITH cte
AS(
	SELECT *,
		(CASE 
			WHEN product_id = 1
				THEN price * 20
			ELSE price * 10
		END
		)x
	FROM menu
)
SELECT
	customer_id,
	SUM(x) total_pts
FROM cte c
JOIN sales s
ON s.product_id = c.product_id
GROUP BY customer_id;
GO

-- 10.In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
SELECT 
	s.customer_id Customer,
	SUM(CASE 
		WHEN order_date BETWEEN join_date AND DATEADD(day , 6, join_date)
			THEN price * 2
		WHEN order_date BETWEEN DATEADD(day , 6, join_date) AND '2021-01-31'
			THEN price * 1
	END
	)Total_pts
FROM menu m
JOIN sales s
ON s.product_id = m.product_id
JOIN members mb
ON s.customer_id = mb.customer_id
GROUP BY s.customer_id;
GO

-- BONUS QUESTION --

--Join All The Things
SELECT 
	s.customer_id Customer,
	s.order_date,
	m.product_name,
	m.price,
	(CASE
		WHEN order_date >= join_date
			THEN 'Y'
		ELSE
			'N'
	END) member
FROM menu m
JOIN sales s
ON s.product_id = m.product_id
LEFT JOIN members mb
ON s.customer_id = mb.customer_id;
GO

-- Rank All The Things
WITH cte
AS(SELECT 
	s.customer_id Customer,
	s.order_date,
	m.product_name,
	m.price,
	(CASE
		WHEN order_date >= join_date
			THEN 'Y'
		ELSE
			'N'
	END) member
	FROM menu m
	JOIN sales s
	ON s.product_id = m.product_id
	LEFT JOIN members mb
	ON s.customer_id = mb.customer_id
)

SELECT 
	Customer, 
	order_date, 
	product_name,
	price, 
	member,
	(CASE
		WHEN r < 1
			THEN NULL
		ELSE
			r
	END) ranking
FROM (SELECT 
	*,
	ROW_NUMBER() OVER(PARTITION BY Customer ORDER BY order_date)
	-
	SUM(CASE
             WHEN member = 'N' THEN
               1
             ELSE
               0
           END) OVER(PARTITION BY Customer ORDER BY order_date) r
FROM cte) table_r