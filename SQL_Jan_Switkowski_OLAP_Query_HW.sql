-- Retrieve the total sales amount for each product category for fiscal month of January, 1998
SELECT p.prod_category, sum(quantity_sold * amount_sold) 
FROM sh.sales s
JOIN sh.products p ON s.prod_id = p.prod_id 
JOIN sh.times t ON s.time_id = t.time_id
WHERE t.fiscal_month_desc = '1998-01'
GROUP BY p.prod_category
;
 
-- Calculate the average sales quantity by region for a particular product

SELECT (sum(s.quantity_sold))/(count(DISTINCT(fiscal_month_id))) AS avg_sales_quant_in_fiscal_month,
	p.prod_name,
	c2.country_region
FROM sh.sales s
JOIN sh.customers c ON s.cust_id = c.cust_id 
JOIN sh.countries c2 ON c.country_id = c2.country_id 
JOIN sh.products p ON s.prod_id = p.prod_id 
JOIN sh.times t ON s.time_id = t.time_id
GROUP BY p.prod_name, c2.country_region;

-- Find the top five customers with the highest total sales amount

SELECT c.cust_id,
	cust_first_name || ' ' || cust_last_name AS full_name,
	sum(quantity_sold * amount_sold) AS total_sales
FROM sh.customers c 
JOIN sh.sales s ON c.cust_id = s.cust_id 
GROUP BY c.cust_id
ORDER BY total_sales DESC LIMIT 5;
