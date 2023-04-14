------------------------------------
-- Data Exploration and Cleansing --
------------------------------------

-- 1.Update the fresh_segments.interest_metrics table by modifying the month_year column to be a date data type with the start of the month
ALTER TABLE interest_metrics
ALTER COLUMN month_year VARCHAR(20);
GO

UPDATE interest_metrics
SET month_year = CONVERT(DATE, '01-' + month_year, 105);

ALTER TABLE interest_metrics
ALTER COLUMN month_year DATE;
GO

SELECT * FROM interest_metrics;
GO

-- 2.What is count of records in the fresh_segments.interest_metrics for each month_year value sorted in 
-- chronological order (earliest to latest) with the null values appearing first?

SELECT 
	month_year,
	COUNT(*)
FROM interest_metrics
GROUP BY month_year
ORDER BY COALESCE(month_year, '2020-01-01') DESC;
GO

-- 3.What do you think we should do with these null values in the fresh_segments.interest_metrics
SELECT count(*) AS null_c
FROM interest_metrics
WHERE month_year IS NULL;
GO

DELETE FROM interest_metrics
WHERE month_year IS NULL;
GO

SELECT count(*) AS null_c
FROM interest_metrics
WHERE month_year IS NULL;
GO

-- 4.How many interest_id values exist in the fresh_segments.interest_metrics table but not in the 
-- fresh_segments.interest_map table? What about the other way around?
WITH cte
AS (
	SELECT 
		DISTINCT
		id,
		interest_id
	FROM interest_map a
	FULL JOIN interest_metrics b
	ON b.interest_id = a.id
	WHERE interest_id IS NULL OR 
	id IS NULL)

SELECT 
	SUM(CASE
			WHEN id IS NULL THEN 1
			ELSE 0
		END) total_not_in_map,
	SUM(CASE
			WHEN interest_id IS NULL THEN 1
			ELSE 0
		END) total_not_in_metric
FROM cte;
GO

-- 5.Summarise the id values in the fresh_segments.interest_map by its total record count in this table
SELECT 
	COUNT(id) id_counts
FROM interest_map;
GO

-- 6.What sort of table join should we perform for our analysis and why? Check your logic by checking the rows where 
-- interest_id = 21246 in your joined output and include all columns from fresh_segments.interest_metrics and all columns 
-- from fresh_segments.interest_map except from the id column.
SELECT a.*,
	interest_name,
	interest_summary,
	created_at,
	last_modified
FROM interest_metrics a
LEFT JOIN interest_map b 
ON a.interest_id = b.id
WHERE a.interest_id = '21246';

-- 7.Are there any records in your joined table where the month_year value is before the created_at value from 
-- the fresh_segments.interest_map table? Do you think these values are valid and why?
WITH cte AS (
	SELECT m1.*,
		interest_name,
		interest_summary,
		created_at,
		last_modified
	FROM interest_metrics AS m1
	LEFT JOIN interest_map AS m2 ON m1.interest_id = m2.id
)
SELECT *
FROM cte
WHERE month_year < created_at;

-- Yes there certainly 188 rows which have created_at > month year, because in month_year at the time of table creation
-- there was no day specified to month_created but in first cleaning task we have given explicit day of 01 to each 
-- month_year value.

-----------------------
-- Interest Analysis --
-----------------------
-- 1.Which interests have been present in all month_year dates in our dataset?
WITH cte AS (
	SELECT interest_id
	FROM interest_metrics
	GROUP BY interest_id
	HAVING count(DISTINCT month_year) = (SELECT count(DISTINCT month_year)
										FROM interest_metrics)
)
SELECT count(*) AS tota_interests
FROM cte;
GO

-- 2.Using this same total_months measure - calculate the cumulative percentage of all records 
-- starting at 14 months - which total_months value passes the 90% cumulative percentage value?
WITH cte AS (
	SELECT interest_id,
		COUNT(DISTINCT month_year) AS total_month
	FROM interest_metrics
	GROUP BY interest_id
),
innerCte AS (
	SELECT total_month,
		COUNT(*) AS total_id,
		CAST(ROUND(100 * SUM(CAST(COUNT(*) AS NUMERIC(10, 2))) OVER (ORDER BY total_month DESC) 
			/ 
			SUM(COUNT(*)) over(), 2) AS NUMERIC(10, 2)) c_perc
	FROM cte
	GROUP BY total_month
)

SELECT total_month,
	total_id,
	c_perc
FROM innerCte
WHERE c_perc >= 90;
GO

-- 3.If we were to remove all interest_id values which are lower than the total_months value 
-- we found in the previous question - how many total data points would we be removing?
WITH cte AS (
	SELECT interest_id,
		COUNT(DISTINCT month_year) AS total_months
	FROM interest_metrics
	GROUP BY interest_id
	HAVING COUNT(DISTINCT month_year) < 6
)
SELECT COUNT(*) rm_rows
FROM interest_metrics
WHERE exists(
		SELECT interest_id
		FROM cte
		WHERE cte.interest_id = interest_metrics.interest_id
	);
GO

-- 4.Does this decision make sense to remove these data points from a business perspective? Use an example where there are all 14 months 
-- present to a removed interest example for your arguments - think about what it means to have less months present from a segment perspective.

-- It dose make sense, as these data points are less valuable and do not represent any major or effective interests of the users. 
-- So excluding interests let us keep the segmets more targeted and focused to the most popular interests and customers' needs.

-- 5.After removing these interests - how many unique interests are there for each month?
SELECT
  month_year,
  COUNT(interest_id) AS number_of_interests
FROM
  interest_metrics AS im
WHERE
  month_year IS NOT NULL AND
  interest_id IN (
    SELECT interest_id
    FROM interest_metrics
    GROUP BY interest_id
    HAVING COUNT(interest_id) > 5)
GROUP BY month_year
ORDER BY month_year;
GO

----------------------
-- Segment Analysis --
----------------------

-- 1.Using our filtered dataset by removing the interests with less than 6 months worth of data, 
-- which are the top 10 and bottom 10 interests which have the largest composition values in any month_year?
-- Only use the maximum composition value for each interest but you must keep the corresponding month_year

DROP TABLE IF EXISTS #tempData;
GO
WITH cte AS (
	SELECT interest_id,
		count(DISTINCT month_year) total_months
	FROM interest_metrics
	GROUP BY interest_id
	HAVING count(DISTINCT month_year) >= 6
)
SELECT *
INTO #tempData
FROM interest_metrics
WHERE interest_id IN (SELECT interest_id FROM cte);
GO

WITH first_cte AS (
	SELECT month_year,
		interest_id,
		i.interest_name,
		composition,
		RANK() OVER (ORDER BY composition DESC) rn
	FROM #tempData
	JOIN interest_map i 
	ON interest_id = id
)
SELECT *
FROM first_cte
WHERE rn <= 10;
GO

WITH last_cte AS (
	SELECT month_year,
		interest_id,
		i.interest_name,
		composition,
		RANK() OVER (ORDER BY composition) rn
	FROM #tempData
	JOIN interest_map i 
	ON interest_id = id
)
SELECT *
FROM last_cte
WHERE rn <= 10;
GO

-- 2.Which 5 interests had the lowest average ranking value?
WITH cte AS (
	SELECT i.interest_name,
		CAST(ROUND(AVG(CAST(ranking AS NUMERIC(10, 2))), 2) AS NUMERIC(10, 2)) avg_r
	FROM #tempData
	JOIN interest_map i 
	ON interest_id= i.id
	GROUP BY i.interest_name
)
SELECT TOP 5 *
FROM cte
ORDER BY avg_r DESC;
GO
-- 3.Which 5 interests had the largest standard deviation in their percentile_ranking value?
DROP TABLE IF EXISTS #tempInt;
GO
WITH cte AS (
	SELECT i.interest_name,
		CAST(ROUND(STDEV(CAST(percentile_ranking AS NUMERIC(10, 2))), 2) AS NUMERIC(10, 2)) avg_r
	FROM #tempData
	JOIN interest_map i 
	ON interest_id= i.id
	GROUP BY i.interest_name
)
SELECT TOP 5 *
INTO #tempInt
FROM cte
ORDER BY avg_r DESC;

SELECT * FROM #tempInt;
GO

-- 4.For the 5 interests found in the previous question - what was minimum and maximum percentile_ranking values 
-- for each interest and its corresponding year_month value? Can you describe what is happening for these 5 interests?
WITH cte 
AS (
	SELECT
		month_year,
		interest_id,
		percentile_ranking,
		RANK() OVER(ORDER BY percentile_ranking) min_r,
		RANK() OVER(ORDER BY percentile_ranking DESC) max_r
	FROM #tempData
	WHERE interest_id IN (SELECT interest_id FROM #tempInt)
	)

SELECT
	c.month_year,
	interest_name,
	percentile_ranking
FROM cte c
JOIN interest_map i
ON i.id = c.interest_id
WHERE min_r = 1 OR max_r = 1
ORDER BY interest_id, percentile_ranking;
GO

-- How would you describe our customers in this segment based off their composition and ranking values? 
-- What sort of products or services should we show to these customers and what should we avoid?

-- ANS.Customers in this market category enjoy travelling, some may be business travellers, they seek a luxurious lifestyle, and they participate in sports. 
-- Instead of focusing on the budget category or any products or services connected to unrelated hobbies like computer games or astrology, 
-- we should highlight those that are relevant to luxury travel or a luxurious lifestyle. Hence, in general, we must concentrate on the interests with high composition values, 
-- but we also must monitor this metric to determine when clients become disinterested in a particular subject.

--------------------
-- Index Analysis --
--------------------

-- 1.What is the top 10 interests by the average composition for each month?
DROP TABLE IF EXISTS #tp_interests;
GO

WITH cte
AS (SELECT 
	interest_id,
	month_year,
	CAST(ROUND(composition / index_value, 2) AS NUMERIC(10, 2)) avg_comp,
	ROW_NUMBER() OVER(PARTITION BY month_year ORDER BY CAST(ROUND(composition / index_value, 2) AS NUMERIC(10, 2)) DESC) rn
FROM interest_metrics )

SELECT 
	c.interest_id,
	interest_name,
	month_year,
	avg_comp,
	rn
INTO #tp_interests
FROM cte c
JOIN interest_map i
ON i.id = c.interest_id
WHERE rn < 11;
GO

SELECT * FROM #tp_interests
ORDER BY month_year, avg_comp DESC;
GO

-- 2.For all of these top 10 interests - which interest appears the most often?
SELECT 
	TOP 1
	interest_name,
	COUNT(*) most_appeared
FROM #tp_interests
GROUP BY interest_name
ORDER BY COUNT(*) DESC;
GO

-- 3.What is the average of the average composition for the top 10 interests for each month?
SELECT
	month_year,
	AVG(avg_comp) avg_of_avg_comp
FROM #tp_interests
GROUP BY month_year;
GO

-- 4.What is the 3 month rolling average of the max average composition value from September 2018 to August 2019 
-- and include the previous top ranking interests in the same output shown below.
WITH cte
AS (SELECT 
	month_year,
	interest_name,
	avg_comp max_index_composition,
	CAST(ROUND(AVG(avg_comp) OVER(ORDER BY month_year), 2) AS NUMERIC(10, 2)) "3_month_moving_avg",
	CONCAT(LAG(interest_name) OVER(ORDER BY month_year), ' : ', LAG(avg_comp) OVER(ORDER BY month_year)) "1_month_ago",
	CONCAT(LAG(interest_name, 2) OVER(ORDER BY month_year), ' : ', LAG(avg_comp, 2) OVER(ORDER BY month_year)) "2_month_ago"
FROM #tp_interests
WHERE rn = 1)

SELECT * 
FROM cte
WHERE month_year > '2018-08-01';
GO

-- 5.Provide a possible reason why the max average composition might change from month to month? 
-- Could it signal something is not quite right with the overall business model for Fresh Segments?

-- ANS.I believe that the user's interests have shifted, and that they are now less interested in certain topics, if at all. 
-- Users "burned out," and the index composition value fell. Some usersmay need to be moved to a different segment. 
-- Although some interests have a high index composition value, which could indicate that these topics are always of interest to the users.
