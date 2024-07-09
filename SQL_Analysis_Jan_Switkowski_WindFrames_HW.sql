WITH presales AS (
    SELECT 
        c2.country_region, 
        ch.channel_desc,
        t.calendar_year,
        SUM(s.quantity_sold * s.amount_sold) AS total_sales
    FROM sh.sales s
    JOIN sh.times t ON s.time_id = t.time_id
    JOIN sh.channels ch ON ch.channel_id = s.channel_id
    JOIN sh.products p ON s.prod_id = p.prod_id
    JOIN sh.customers c ON s.cust_id = c.cust_id 
    JOIN sh.countries c2 ON c.country_id = c2.country_id 
    WHERE 
        c2.country_region IN ('Americas', 'Asia', 'Europe') AND
        ch.channel_desc IN ('Internet', 'Partners', 'Direct Sales') AND 
        t.calendar_year IN (1998, 1999, 2000, 2001)
    GROUP BY 
        c2.country_region, 
        t.calendar_year,
        ch.channel_desc    
),
presales2 AS (
	SELECT
	    country_region,
	    calendar_year,
	    channel_desc,
	    total_sales,
	    CAST(total_sales / SUM(total_sales) OVER (PARTITION BY country_region, calendar_year) * 100 AS DECIMAL(10,2)) AS percent_of_total_sales
	FROM presales
	ORDER BY country_region, calendar_year, channel_desc
),
presales3 AS (
	SELECT 
		country_region,
		calendar_year,
		channel_desc,
		total_sales,
		percent_of_total_sales,
		LAG(percent_of_total_sales, 1) OVER (PARTITION BY country_region, channel_desc ORDER BY calendar_year) AS percent_previous_period
	FROM presales2
	ORDER BY country_region, calendar_year, channel_desc),
finaltable AS (
	SELECT 
		country_region,
		calendar_year,
		channel_desc,
		total_sales,
		percent_of_total_sales,
		percent_previous_period,
		COALESCE(CAST((CAST(percent_of_total_sales AS DECIMAL(10,2)) - CAST(COALESCE(percent_previous_period) AS DECIMAL(10,2))) 
		AS DECIMAL(10,2)), 0.00) AS percent_difference
	FROM presales3)
SELECT 
	country_region,
	calendar_year,
	channel_desc,
	total_sales,
	percent_of_total_sales || '%' AS "% BY CHANNELS" ,
	percent_previous_period  || '%' AS "% PREVIOUS PERIOD",
	percent_difference || '%' AS "% DIFFERENCE"
FROM finaltable
WHERE calendar_year >= 1999
;

    
WITH pretable AS (
	SELECT 
		t.calendar_week_number,
		t.time_id,
		t.day_name,
	    SUM(s.quantity_sold * s.amount_sold) AS total_sales
	FROM sh.sales s
	JOIN sh.times t ON s.time_id = t.time_id
	JOIN sh.channels ch ON ch.channel_id = s.channel_id
	JOIN sh.products p ON s.prod_id = p.prod_id
	WHERE t.calendar_year = 1999 AND calendar_week_number IN (49,50,51)
	GROUP BY t.calendar_week_number, t.time_id, t.day_name
),
cum_sales AS (
	SELECT 
		calendar_week_number,
		time_id,
		day_name,
		total_sales,
		TO_CHAR(SUM(SUM(total_sales)) OVER (PARTITION BY calendar_week_number ORDER BY time_id asc
									RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), '9,999,999,999.99')
									 AS cum_sales
	FROM pretable
	GROUP BY calendar_week_number, time_id, day_name, total_sales
),
avg_sales AS (
	SELECT
		calendar_week_number,
	    time_id,
	    day_name,
	    total_sales,
	    cum_sales,
	    CAST(CASE
	    	WHEN day_name = 'Monday' THEN AVG(total_sales) OVER (PARTITION BY calendar_week_number ORDER BY time_id
	                                                             ROWS BETWEEN 2 PRECEDING AND 1 FOLLOWING)
	        WHEN day_name = 'Friday' THEN AVG(total_sales) OVER (PARTITION BY calendar_week_number ORDER BY time_id
	                                                              ROWS BETWEEN 1 PRECEDING AND 2 FOLLOWING)
	        ELSE AVG(total_sales) OVER (PARTITION BY calendar_week_number ORDER BY time_id
	                                    ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING)
	        END AS DECIMAL (10,2)
	        )centered_3_day_avg
	    FROM cum_sales
)
SELECT 
    calendar_week_number,
    time_id,
    day_name,
    TO_CHAR(total_sales, '9,999,999,999.99') AS total_sales,
    cum_sales,
    centered_3_day_avg
FROM avg_sales
ORDER BY calendar_week_number, time_id;

-- Here I I add a column total_sales which sums up all sales made on that day
-- I use window frame where I partition by day_name and order by time_id,
-- and finnally I use ROWS between unbounded preceding and current row which 
-- gives me a running total of sales made on that day.
-- I use RANGE to get all the values that fall within specified range
-- I use ROWS with between 2 preceding and current row to get a 3 day moving average
SELECT 
    t.calendar_week_number,
    t.time_id,
    t.day_name,
    SUM(s.quantity_sold * s.amount_sold) AS total_sales,
    TO_CHAR(SUM(SUM(s.quantity_sold * s.amount_sold)) OVER (
        PARTITION BY t.day_name 
        ORDER BY t.time_id
        RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ), '9,999,999.99')  AS cum_sales_by_day,
    TO_CHAR(AVG(SUM(s.quantity_sold * s.amount_sold)) OVER ( 
    	PARTITION BY calendar_week_number
        ORDER BY t.time_id
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), '9,999,999.99') AS three_day_ma      
FROM sh.sales s
JOIN sh.times t ON s.time_id = t.time_id
JOIN sh.channels ch ON ch.channel_id = s.channel_id
JOIN sh.products p ON s.prod_id = p.prod_id
WHERE t.calendar_year = 2000 AND t.calendar_week_number IN (1, 2, 3)
GROUP BY t.calendar_week_number, t.time_id, t.day_name
ORDER BY t.calendar_week_number, t.time_id;

-- This query uses GROUPS which allows me to sum products  
-- and handle multiple values with same time_id
SELECT 
    t.calendar_week_number,
    t.time_id,
    t.day_name,
    p.prod_desc,
    TO_CHAR(SUM(s.quantity_sold * s.amount_sold) OVER ( 
        PARTITION BY p.prod_desc
        ORDER BY t.time_id
        GROUPS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), '9,999,999.99') AS cum_sum_per_product_per_day
FROM sh.sales s
JOIN sh.times t ON s.time_id = t.time_id
JOIN sh.channels ch ON ch.channel_id = s.channel_id
JOIN sh.products p ON s.prod_id = p.prod_id
WHERE t.calendar_year = 2000 AND t.calendar_week_number IN (1, 2, 3) AND p.prod_desc = 'Envoy Ambassador'
ORDER BY t.calendar_week_number, t.time_id, p.prod_desc;






   




