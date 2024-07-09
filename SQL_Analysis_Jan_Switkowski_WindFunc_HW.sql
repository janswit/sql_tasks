-- I create a CTE that returns a table with total_sales grouped by channel and customer.
-- To avoid grouing by people or channel with same names, I also group by channel_id and cust_id
WITH channelsales AS (
    SELECT 
        s.channel_id,
        ch.channel_desc,
        c.cust_id,
        c.cust_first_name || ' ' || c.cust_last_name AS customer_name,
        SUM(s.quantity_sold * s.amount_sold) AS total_sales
    FROM sh.sales s
    JOIN sh.customers c ON s.cust_id = c.cust_id
    JOIN sh.channels ch ON s.channel_id = ch.channel_id
    GROUP BY s.channel_id, ch.channel_desc, c.cust_id, c.cust_first_name, c.cust_last_name
),
totalchannelsales AS (
    SELECT
        channel_id,
        SUM(total_sales) AS channel_total_sales
    FROM channelsales
    GROUP BY channel_id
),
-- I use DENSE_RANK windowfunction partitioned by channel_id and order it by total_sales, 
-- which I will later use to join totalchannelssales only to top 5
rankedsales AS (
    SELECT 
        cs.channel_id,
        cs.channel_desc,
        cs.customer_name,
        cs.total_sales,
        DENSE_RANK() OVER (PARTITION BY cs.channel_id ORDER BY cs.total_sales DESC) AS sales_rank
    FROM channelsales cs
)
-- I select channel_desc, customer_name, and use TO_CHAR with amount_sold and sales_percentage to get required decimal laces
-- I set a condition that sales_rank has to be less or equal to 5 and order by channel_desc, total_sales
SELECT
    rs.channel_desc,
    rs.customer_name,
    TO_CHAR(rs.total_sales, '999,999,999.99') AS amount_sold,
    TO_CHAR((rs.total_sales / tcs.channel_total_sales) * 100, '99.9999') || '%' AS sales_percentage
FROM rankedsales rs
JOIN totalchannelsales tcs ON rs.channel_id = tcs.channel_id
WHERE rs.sales_rank <= 5
ORDER BY rs.channel_desc, rs.total_sales DESC;



-- TASK 2


SET search_path TO sh;
CREATE EXTENSION IF NOT EXISTS tablefunc;

CREATE EXTENSION IF NOT EXISTS tablefunc;

SELECT * 
FROM crosstab(
    $$ SELECT p.prod_name, t.calendar_quarter_desc, SUM(s.quantity_sold * s.amount_sold) AS quarterly_sales
       FROM sales s
       JOIN products p ON s.prod_id = p.prod_id
       JOIN times t ON s.time_id = t.time_id
       JOIN customers c ON s.cust_id = c.cust_id 
       JOIN countries c2 ON c.country_id = c2.country_id 
       WHERE p.prod_category_desc = 'Photo' AND
             c2.country_region = 'Asia' AND
             t.calendar_year = 2000
       GROUP BY p.prod_name, t.calendar_quarter_desc
       ORDER BY p.prod_name, t.calendar_quarter_desc $$,
    $$ SELECT distinct calendar_quarter_desc FROM times WHERE calendar_year = 2000 ORDER BY calendar_quarter_desc $$
) AS final_result(
    prod_name TEXT,
    q1 NUMERIC,
    q2 NUMERIC,
    q3 NUMERIC,
    q4 NUMERIC
);


-- This is the best I could do using crosstab, I didn't know how to get year_sum in the final table other way
WITH ct AS (
SELECT * 
FROM crosstab(
    $$ SELECT p.prod_name, t.calendar_quarter_desc, SUM(s.quantity_sold * s.amount_sold) AS quarterly_sales
       FROM sales s
       JOIN products p ON s.prod_id = p.prod_id
       JOIN times t ON s.time_id = t.time_id
       JOIN customers c ON s.cust_id = c.cust_id 
       JOIN countries c2 ON c.country_id = c2.country_id 
       WHERE p.prod_category_desc = 'Photo' AND
             c2.country_region = 'Asia' AND
             t.calendar_year = 2000
       GROUP BY p.prod_name, t.calendar_quarter_desc
       ORDER BY p.prod_name, t.calendar_quarter_desc $$,
    $$ SELECT distinct calendar_quarter_desc FROM times WHERE calendar_year = 2000 ORDER BY calendar_quarter_desc $$
) AS final_result(
    prod_name TEXT,
    q1 NUMERIC,
    q2 NUMERIC,
    q3 NUMERIC,
    q4 NUMERIC
)
),
yearsum AS (
SELECT  prod_name,
        SUM(s.quantity_sold * s.amount_sold) OVER (PARTITION BY prod_name) AS year_sum
FROM sales s
JOIN products p ON s.prod_id = p.prod_id
JOIN times t ON s.time_id = t.time_id
JOIN customers c ON s.cust_id = c.cust_id 
JOIN countries c2 ON c.country_id = c2.country_id 
WHERE p.prod_category_desc = 'Photo' AND
             c2.country_region = 'Asia' AND
             t.calendar_year = 2000
)
SELECT DISTINCT(ct.prod_name), 
		TO_CHAR(ct.q1, '999,999.99') AS q1, 
		TO_CHAR(ct.q2, '999,999.99') AS q2, 
		TO_CHAR(ct.q3, '999,999.99') AS q3, 
		TO_CHAR(ct.q4, '999,999.99') AS q4,
		ys.year_sum AS year_sum
FROM ct 
JOIN yearsum ys ON ct.prod_name = ys.prod_name;
;


-- TASK 3
-- I create three CTEs for each year where I retireve required columns
-- I use RANK window function to rank top customers for each year
-- I group by required columns and set condidtion
WITH rankedsales98 AS (
	SELECT 
	    c2.channel_desc, 
	    c.cust_id, 
	    c.cust_last_name, 
	    c.cust_first_name,
	    t.calendar_year,
	    SUM(s.quantity_sold * s.amount_sold) AS total_sales, 
	    RANK () OVER (
	        ORDER BY SUM(s.quantity_sold * s.amount_sold) DESC
	    ) AS col_rank
	FROM sh.sales s 
	JOIN sh.products p ON s.prod_id = p.prod_id 
	JOIN sh.customers c ON s.cust_id = c.cust_id 
	JOIN sh.channels c2 ON s.channel_id = c2.channel_id
	JOIN sh.times t ON s.time_id = t.time_id 
	WHERE t.calendar_year = 1998
	GROUP BY c.cust_id, c2.channel_desc, t.calendar_year, c.cust_last_name, c.cust_first_name
),
rankedsales99 AS (
	SELECT 
	    c2.channel_desc, 
	    c.cust_id, 
	    c.cust_last_name, 
	    c.cust_first_name,
	    t.calendar_year,
	    SUM(s.quantity_sold * s.amount_sold) AS total_sales, 
	    RANK () OVER (
	        ORDER BY SUM(s.quantity_sold * s.amount_sold) DESC
	    ) AS col_rank
	FROM sh.sales s 
	JOIN sh.products p ON s.prod_id = p.prod_id 
	JOIN sh.customers c ON s.cust_id = c.cust_id 
	JOIN sh.channels c2 ON s.channel_id = c2.channel_id
	JOIN sh.times t ON s.time_id = t.time_id 
	WHERE t.calendar_year = 1999
	GROUP BY c.cust_id, c2.channel_desc, t.calendar_year, c.cust_last_name, c.cust_first_name
),
rankedsales01 AS (
	SELECT 
	    c2.channel_desc, 
	    c.cust_id, 
	    c.cust_last_name, 
	    c.cust_first_name,
	    t.calendar_year,
	    SUM(s.quantity_sold * s.amount_sold) AS total_sales, 
	    RANK () OVER (
	        ORDER BY SUM(s.quantity_sold * s.amount_sold) DESC
	    ) AS col_rank
	FROM sh.sales s 
	JOIN sh.products p ON s.prod_id = p.prod_id 
	JOIN sh.customers c ON s.cust_id = c.cust_id 
	JOIN sh.channels c2 ON s.channel_id = c2.channel_id
	JOIN sh.times t ON s.time_id = t.time_id 
	WHERE t.calendar_year = 2001
	GROUP BY c.cust_id, c2.channel_desc, t.calendar_year, c.cust_last_name, c.cust_first_name
),
-- I use this cte tho join all yearly CTEs and set a condition that rank has to be smaller or equal to 300
cum_sales AS (	
	SELECT rs98.channel_desc, rs98.cust_id, rs98.cust_last_name, rs98.cust_first_name, rs98.total_sales
	FROM rankedsales98 rs98
	WHERE rs98.col_rank <= 300
	UNION ALL 
	SELECT rs99.channel_desc, rs99.cust_id, rs99.cust_last_name, rs99.cust_first_name, rs99.total_sales
	FROM rankedsales99 rs99
	WHERE rs99.col_rank <= 300
	UNION ALL 
	SELECT rs01.channel_desc, rs01.cust_id, rs01.cust_last_name, rs01.cust_first_name, rs01.total_sales
	FROM rankedsales01 rs01
	WHERE rs01.col_rank <= 300)
-- Finally, I select everything from cum_sales and order it by total_sales
SELECT *
FROM cum_sales
ORDER BY total_sales DESC
;



-- TASK 4
-- I create a CTE where i make necessary joins and set required conditions
-- I select required columns and write a window function where I sum sales OVER regions, calendar_month_desc, and product category
-- I select prod_category and calendat month from created CTE which is grouped by product category and month.
-- I order it by the mentioned columns
-- I use CASE statement and MAX function to pivot the table 
WITH regional_sales AS (
    SELECT 
        t.calendar_month_desc,
        p.prod_category,
        c2.country_region,
        SUM(s.quantity_sold * s.amount_sold) OVER (
            PARTITION BY c2.country_region, t.calendar_month_desc, p.prod_category
        ) AS total_sales
    FROM sales s
    JOIN products p ON s.prod_id = p.prod_id
    JOIN times t ON s.time_id = t.time_id
    JOIN customers c ON s.cust_id = c.cust_id
    JOIN countries c2 ON c.country_id = c2.country_id
    WHERE c2.country_region IN ('Americas', 'Europe') 
        AND t.calendar_month_desc IN ('2000-01', '2000-02', '2000-03')
)
SELECT 
    rs.prod_category,
    rs.calendar_month_desc,
    MAX(CASE WHEN rs.country_region = 'Americas' THEN rs.total_sales END) AS america_sales,
    MAX(CASE WHEN rs.country_region = 'Europe' THEN rs.total_sales END) AS europe_sales
FROM regional_sales rs
GROUP BY rs.prod_category, rs.calendar_month_desc
ORDER BY rs.calendar_month_desc, rs.prod_category;


