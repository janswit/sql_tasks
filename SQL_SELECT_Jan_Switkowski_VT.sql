/* Top-3 most selling movie categories of all time and total dvd rental income for each category. 
Only consider dvd rental customers from the USA. */

/*Here I'm creating a table that will have customers only from United States by joining 
 * customer, address, city and country tables and adding 'United States' as a condition
 * to get customer_id of the American customers */

WITH usa_customers AS (
    SELECT c.customer_id,
           cntr.country
    FROM customer c
    JOIN address a ON c.address_id = a.address_id
    JOIN city ct ON a.city_id = ct.city_id
    JOIN country cntr ON cntr.country_id = ct.country_id
    WHERE cntr.country = 'United States'
)
/* Here I'm joining tables rental, payment, inventory and film to get to film title information. 
 * Then I'm joining rental table to usa_customers created as CTE to account only for the American customers.
 * I'm summing up amount from payment table naming aliasing it as total_spent and grouping by film title.
 * Finally, I'm ordering by total_spen in a descending order and limiting the results to top 3 movies  */
SELECT SUM(p.amount) AS total_spent,
       f.title
FROM rental r 
JOIN payment p ON r.rental_id = p.rental_id
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN film f ON i.film_id = f.film_id
JOIN usa_customers ON usa_customers.customer_id = r.customer_id		
GROUP BY f.title 
ORDER BY total_spent DESC 
LIMIT 3;

	
/*Here I'm creating a table that will give me film_ids and categories associated with them which later 
 * allow me to associate it with inventory table */
WITH categorized_films AS (
    SELECT f.film_id, 
    	c.name AS movie_category
    FROM film f 
    JOIN film_category fc ON f.film_id = fc.film_id
    JOIN category c ON fc.category_id = c.category_id
),
/*Here I'm creating a table that will have customers only from United States by joining 
 * customer, address, city and country tables and adding 'United States' as a condition
 * to get customer_id of the American customers */
usa_customers AS (
    SELECT c.customer_id,
           cntr.country
    FROM customer c
    JOIN address a ON c.address_id = a.address_id
    JOIN city ct ON a.city_id = ct.city_id
    JOIN country cntr ON cntr.country_id = ct.country_id
    WHERE cntr.country = 'United States'
)
/* Here I'm joining rental, payment, inventory, film tables with usa_customers that only have American customers.
 * I'm also joining categorized_films which have film_ids and categories associated with them.
 * I sum the amounts, and then movies_categories so I can group by them.
 * Lastly I order the results in descending order. */
SELECT SUM(p.amount) AS total_spent,
       categorized_films.movie_category
FROM rental r 
JOIN payment p ON r.rental_id = p.rental_id
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN film f ON i.film_id = f.film_id
JOIN usa_customers ON usa_customers.customer_id = r.customer_id
JOIN categorized_films ON i.film_id = categorized_films.film_id
GROUP BY categorized_films.movie_category
ORDER BY total_spent DESC ;

/* For each client, display a list of horrors that he had ever rented (in one column, separated by commas), 
 and the amount of money that he paid for it */

/* Here I'm creating a common table expression with film table and joining film_category and category
 * tables with "Horror" condition so I can later use film_ids that are associated with horrors.  */
WITH horror_films AS (
    SELECT f.film_id, 
    	   f.title
    FROM film f 
    JOIN film_category fc ON f.film_id = fc.film_id
    JOIN category c ON fc.category_id = c.category_id
    WHERE c.name = 'Horror'
),
/* Here I'm creating a table by joining rental, inventory, film, customer and earlier created horror_film
 * so I can get all the customers that have rented a horror. Also I selected titles and rental_ids which 
 * will later help me identify payments associated with rentals and created a customer_name */
client_horrors AS (
    SELECT c.customer_id, 
    	   CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    	   horror_films.title AS horror_title,
           r.rental_id
    FROM rental r 
    JOIN inventory i ON r.inventory_id = i.inventory_id
    JOIN film f ON i.film_id = f.film_id
    JOIN customer c ON r.customer_id = c.customer_id 
    JOIN horror_films ON f.film_id = horror_films.film_id
)
/* Here I'm joining joining payment table to earlier created client_horrors. I'm grouping by 
 * client_horrors.customer_id, customer_name in case there were two same names. On top of that I select 
 * summed up payments and create a column rented_horrors with horror movies separated by commas.
 * Lastly I order the results by total spent sum in a descending order */
SELECT client_horrors.customer_id,
	customer_name,
	SUM(p.amount) AS total_spent,
	STRING_AGG(client_horrors.horror_title, ', ') AS rented_horrors
FROM client_horrors
JOIN payment p ON client_horrors.rental_id = p.rental_id
GROUP BY client_horrors.customer_id, customer_name
ORDER BY total_spent DESC;
