-- In this CTE I group by channel_desc and country_region and sum amount of sold units
-- I use window function to calculate total_channel_sales regardless of country_region
WITH grouped_sales AS (
    SELECT c3.channel_desc, 
           c2.country_region, 
           SUM(s.quantity_sold) AS sales,
           SUM(SUM(s.quantity_sold)) OVER (PARTITION BY c3.channel_desc) AS total_channel_sales
    FROM sh.sales s
    JOIN sh.products p ON s.prod_id = p.prod_id
    JOIN sh.times t ON s.time_id = t.time_id
    JOIN sh.customers c ON s.cust_id = c.cust_id 
    JOIN sh.countries c2 ON c.country_id = c2.country_id
    JOIN sh.channels c3 ON s.channel_id = c3.channel_id 
    GROUP BY c3.channel_desc, c2.country_region
)
-- I calcualte sales_percent and do some formatting
SELECT channel_desc,
       country_region,
       TO_CHAR(sales, '999,999.99') AS sales,  
       TO_CHAR((sales / total_channel_sales * 100), '999.99') || '%' AS sales_percent 
FROM grouped_sales
ORDER BY sales DESC; 




-- I use this CTE to calculate current_sales in each year and for every prod_subcategory
-- I use LAG to to create column with cumulative sales from previous year which I will use to compare values
WITH yoy AS(
	SELECT
       	p.prod_subcategory,
        t.calendar_year,
        SUM(s.quantity_sold * s.amount_sold) AS current_sales,
        LAG(SUM(s.quantity_sold * s.amount_sold)) OVER (PARTITION BY p.prod_subcategory ORDER BY t.calendar_year) AS previous_year_sales
	FROM sh.sales s
	JOIN sh.products p ON s.prod_id = p.prod_id
	JOIN sh.times t ON s.time_id = t.time_id
	WHERE t.calendar_year BETWEEN 1997 AND 2001
	GROUP BY p.prod_subcategory, t.calendar_year
)
-- I group by product_subcategory and SET a condition that the minimum difference has to be larger than 0
-- and select distinct prod_subcategories
SELECT 
    DISTINCT prod_subcategory
FROM yoy
WHERE calendar_year BETWEEN 1998 AND 2001
GROUP BY prod_subcategory
HAVING MIN(current_sales - previous_year_sales) > 0 
ORDER BY prod_subcategory;




-- In first CTE I group by required values and set conditions as instructed
-- I use it to get aggregate sum of sales which I will later use for further calculations
WITH quarter_sales AS (
    SELECT 
        t.calendar_year,
        t.calendar_quarter_desc,
        p.prod_category,
        SUM(s.quantity_sold * s.amount_sold) AS sales
    FROM 
        sh.sales s
    JOIN sh.products p ON s.prod_id = p.prod_id
    JOIN sh.times t ON s.time_id = t.time_id
    JOIN sh.channels c ON s.channel_id = c.channel_id
    WHERE 
        t.calendar_year IN (1999, 2000) AND
        p.prod_category IN ('Electronics', 'Hardware', 'Software/Other') AND 
        c.channel_desc IN ('Partners', 'Internet')
    GROUP BY 
        p.prod_category, 
        t.calendar_year,
        t.calendar_quarter_desc
),
-- In this CTE I use two window frames. I divide sales by a window frame with FIRST_VALUE 
-- to be able to calculate percent differential. I partition by calendar_year and prod_category,
-- order by calendar_quarter_desc to retrieve value from first quarter of each year
-- In the second window fram I sum sales and partition by calendar_year. I set range to unbounded preceding
-- to count all previous values and set upper boundry to current row
calculations AS (
	SELECT 
	    qs.calendar_year,
	    qs.calendar_quarter_desc,
	    qs.prod_category,
	    qs.sales,
	    ((qs.sales / FIRST_VALUE(qs.sales) OVER (
	        PARTITION BY qs.calendar_year, qs.prod_category 
	        ORDER BY qs.calendar_quarter_desc ASC) -1) * 100) AS diff_percent,
	    SUM(qs.sales) OVER (
	    	PARTITION BY qs.calendar_year
	    	ORDER BY qs.calendar_quarter_desc ASC
	    	RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cum_sales
	FROM quarter_sales qs
)
-- In final select I mostly do formatting
-- I use CASE statement to apply N/A to values from first quarter
SELECT calendar_year,
	   calendar_quarter_desc,
	   prod_category,
	   TO_CHAR(sales, '999,999,999.99') AS "sales$",
	   CASE 
	       WHEN calendar_quarter_desc IN ('1999-01', '2000-01') THEN 'N/A'
	       ELSE TO_CHAR(diff_percent, '999.99') || '%'
	   END  AS diff_percent,
	   TO_CHAR(cum_sales, '999,999,999.99')
FROM calculations
ORDER BY calendar_quarter_desc ASC, "sales$" DESC;