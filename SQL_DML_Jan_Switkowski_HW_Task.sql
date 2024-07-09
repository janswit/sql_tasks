/* This SQL statement inserts records into the public.film table for new films that do not already exist.
It selects film information from a VALUES clause and adds it to the public.film table.
The SELECT query uses a WHERE NOT EXISTS clause to ensure that only films not already in the table are inserted.
The subquery checks for the existence of films with the same title, ignoring case sensitivity.
 */

INSERT INTO public.film
    (title, description, release_year, language_id, original_language_id, rental_duration, rental_rate, length, replacement_cost, rating, special_features, fulltext)
SELECT 
    title,
    description,
    release_year,
    (SELECT language_id FROM language WHERE name = 'English'),
    NULL,
    rental_duration,
    rental_rate,
    length,
    replacement_cost,
    'R'::mpaa_rating,
    special_features::TEXT[],
    to_tsvector(CONCAT(title, ' ', description)) AS fulltext
FROM
    (VALUES 
        ('THE WOLF OF WALL STREET', 'Excess and greed in the stock market.', 2013,
        7, 4.99, 180, 
        19.99, 'R', '{Deleted Scenes, Trailers}'),
        ('THE GODFATHER', 'Power, loyalty, family: Mafia drama masterpiece unfolds.', 1972, 
        14, 9.99, 175, 
        19.99, 'R', '{Deleted Scenes, Trailers}'),
        ('THE BIG SHORT', 'The financial crisis through insider stories.', 2015,
        21, 19.99, 130, 
        19.99, 'R', '{Deleted Scenes, Trailers}')
    ) AS new_films (title, description, release_year, 
                rental_duration, rental_rate, length, 
                replacement_cost, rating, special_features)
WHERE NOT EXISTS (SELECT 1
					FROM film
					WHERE UPPER(film.title) = UPPER(new_films.title)
    				);

-- Changed the way I insert data to actor table as requested
-- Created a CTE named new_actors with columns first_name and last_name
-- List actors' names I want to add in VALUES
-- Actor_id is serial and last_updated is default now() so I don't need to specify it
-- Added WHERE NOT EXISTS to filter rows
-- This condition checks if there is no existing row in the public.actor table with the same first_name and last_name
-- Used UPPER clause to ensure case-insensitive matching


INSERT INTO public.actor(first_name, last_name)
SELECT first_name, last_name 
FROM (VALUES	
	('STEVE', 'CARRELL'),
    ('CHRISTIAN', 'BALE'),
    ('LEONARDO', 'DICAPRIO'),
    ('MARGOT', 'ROBBIE'),
    ('AL', 'PACINO'),
    ('MARLON', 'BRANDO')) AS new_actors(first_name, last_name)
WHERE NOT EXISTS (
    SELECT 1
    FROM public.actor
    WHERE UPPER(actor.first_name) = UPPER(new_actors.first_name)
    AND UPPER(actor.last_name) = UPPER(new_actors.last_name));

		 
		 
-- Created a CTE film_actor_data with actors' names and film titles
-- Joined actor table on concatenated full name with the UPPER clause to to ensure case-insensitive matching
-- Joined film table on film_title with the UPPER clause to ensure case-insensitive matching
-- Added WHERE NOT EXISTS clause to filter rows from joined tables
-- The subquery returns 1 for each row that satisfies the WHERE condition below
-- This condition checks if there is no existing row in the public.film_actor table with the same actor_id and film_id
-- I selected actor_id and film_id to be inserted into film_actor table

  
INSERT INTO public.film_actor (actor_id, film_id)
SELECT a.actor_id, f.film_id
FROM (
    VALUES 
    ('STEVE CARRELL', 'THE BIG SHORT'),
    ('CHRISTIAN BALE', 'THE BIG SHORT'),
    ('MARGOT ROBBIE', 'THE WOLF OF WALL STREET'),
    ('LEONARDO DICAPRIO', 'THE WOLF OF WALL STREET'),
    ('AL PACINO', 'THE GODFATHER'),
    ('MARLON BRANDO', 'THE GODFATHER')
) AS film_actor_data(actor_name, film_title)
JOIN public.actor a ON CONCAT(UPPER(a.first_name), ' ', UPPER(a.last_name)) = UPPER(film_actor_data.actor_name)
JOIN public.film f ON UPPER(f.title) = UPPER(film_actor_data.film_title)
WHERE NOT EXISTS (
    SELECT 1
    FROM public.film_actor fa
    WHERE fa.actor_id = a.actor_id
    AND fa.film_id = f.film_id
);

-- Inserted specified movie_ids into all stores
-- Used CROSS JOIN to generate all combinations of movie IDs and store IDs
-- Used WHERE NOT EXISTS to ensure each movie is inserted into each store only once

INSERT INTO public.inventory (film_id, store_id)
SELECT f.film_id, s.store_id
FROM public.film f
CROSS JOIN store s
WHERE f.title IN ('THE BIG SHORT', 'THE WOLF OF WALL STREET', 'THE GODFATHER')
AND NOT EXISTS (
    SELECT 1
    FROM public.inventory i
    WHERE i.film_id = f.film_id
    AND i.store_id = s.store_id
);

-- I'm not sure if I can hardcode customer_id, or I can choose it somewhat 'randomly' as I did here
-- IN CTE, in subquery, I select customer_id from rental and group by it, 
-- and then I add a condition to retrieve only ids that have more than or equal to 43 rentals
-- The same logic goes for the main select statement, 
-- I find the customer_ids that have more than or equal to 43 payments and add a condition that it has to be among the 
-- the ids that have more than or equal to 43 rentals
-- Lastly, I update customer table with my data
-- I add condition that customer_id has to come from the CTE along with its conditions
-- I add not exists that checks if customer with name Jan Switkowski already exists

WITH eligible_customers AS (
    SELECT p.customer_id
    FROM payment p 
    WHERE p.customer_id IN (
        SELECT r.customer_id
        FROM rental r		
        GROUP BY r.customer_id 
        HAVING COUNT(r.rental_id) >= 43
    )
    GROUP BY p.customer_id
    HAVING COUNT(p.payment_id) >= 43
    LIMIT 1 
)
UPDATE customer c
SET first_name = 'JAN',
    last_name = 'SWITKOWSKI',
    email = 'janswit@pm.me',
    address_id = 22 
WHERE 
    customer_id IN (SELECT customer_id FROM eligible_customers)
    AND NOT EXISTS (
        SELECT 1
        FROM customer
        WHERE UPPER(first_name) = 'JAN' AND UPPER(last_name) = 'SWITKOWSKI')
RETURNING customer_id
;


-- Start a transaction to ensure ACID principles
-- The CTE deleted_payments deletes payments associated with customers who have made 43 or more rentals(logic explained above).
-- The RETURNING clause retrieves the customer IDs of the deleted payments which will later be used in another DELETE.
-- The second DELETE statement removes rental records for customers whose payments were deleted in the previous step.
-- WHERE condition filters rentals based on customer IDs obtained from the deleted_payments CTE.
-- Commit the transaction

BEGIN TRANSACTION;

WITH deleted_payments AS (
    DELETE FROM public.payment
    WHERE customer_id IN (
        SELECT p.customer_id
        FROM payment p 
        WHERE p.customer_id IN (
            SELECT COUNT(r.rental_id) AS rental_count
            FROM rental r
            GROUP BY r.customer_id 
            HAVING COUNT(r.rental_id) >= 43
        )
        GROUP BY p.customer_id
        HAVING COUNT(p.payment_id) >= 43
    )
    RETURNING customer_id
)
DELETE FROM rental
WHERE customer_id IN (SELECT customer_id FROM deleted_payments);

COMMIT;
     	
-- The CTE favourite_movies selects inventory IDs of films that are available in Jan Switkowski's store
-- It ensures that only films 'THE BIG SHORT', 'THE WOLF OF WALL STREET', and 'THE GODFATHER' are considered.
-- The CTE staff_id identifies the staff member 'HANNA' working in the same store as 'JAN SWITKOWSKI'.
-- It retrieves the staff ID associated with the specified store where 'JAN SWITKOWSKI' visits.
-- The INSERT INTO statement inserts rental records into the public.rental table.
-- It generates a random rental date within the first half of 2017 for each film selected in favourite_movies.
-- The rental is associated with 'JAN SWITKOWSKI' as the customer and 'HANNA' as the staff member.
-- The WHERE NOT EXISTS clause ensures that only rentals not already present in the public.rental table are inserted.
-- It checks for existing rentals with the same inventory ID and customer ID.

WITH favourite_movies AS ( 
    SELECT i.inventory_id
    FROM film f
    JOIN inventory i ON f.film_id = i.film_id
    WHERE f.title IN ('THE BIG SHORT', 'THE WOLF OF WALL STREET', 'THE GODFATHER') 
    AND i.store_id IN (
        SELECT c.store_id 
        FROM customer c 
        WHERE UPPER(c.first_name) = 'JAN' AND 
              UPPER(c.last_name) = 'SWITKOWSKI'
    )
),
staff_id AS (
    SELECT st.staff_id AS id
    FROM store s  
    JOIN staff st ON s.store_id = st.store_id
    WHERE s.store_id = (
        SELECT c.store_id 
        FROM customer c 
        WHERE UPPER(c.first_name) = 'JAN' AND 
              UPPER(c.last_name) = 'SWITKOWSKI'
    ) 
    AND UPPER(st.first_name) = 'HANNA'
)
INSERT INTO public.rental (rental_date, inventory_id, customer_id, staff_id)
SELECT DATE '2017-01-01' + (FLOOR(random() * 180)::INT) AS rental_date, 
		inventory_id, 
		(SELECT customer_id FROM customer WHERE UPPER(first_name) = 'JAN' AND UPPER(last_name) = 'SWITKOWSKI'),
		(SELECT id FROM staff_id)
FROM favourite_movies
WHERE NOT EXISTS (
    SELECT 1 
    FROM public.rental r 
    WHERE r.inventory_id = favourite_movies.inventory_id AND 
   			r.customer_id =  (SELECT customer_id FROM customer WHERE UPPER(first_name) = 'JAN' AND UPPER(last_name) = 'SWITKOWSKI')
 				)
 ;


-- Select customer_id, staff_id, rental_id, amount, and payment_date for each rental associated with customer 'JAN SWITKOWSKI'.
-- The customer_id and staff_id are taken directly from the rental record.
-- The rental_id is linked to the corresponding rental in the rental table.
-- The amount is retrieved from the film's rental_rate in the film table, associated with the rental through the inventory.
-- The payment_date is set to the rental_date of the rental record.
-- The JOINs with rental, inventory, and film tables ensure that only rentals involving films rented by 'JAN SWITKOWSKI' are considered.
-- The WHERE NOT EXISTS clause ensures that only rentals without corresponding payment records are selected.

INSERT INTO public.payment
(customer_id, staff_id, rental_id, amount, payment_date)
SELECT r.customer_id,
		r.staff_id,
		r.rental_id,
		f.rental_rate,
		r.rental_date
FROM rental r
JOIN inventory i
ON r.inventory_id = i.inventory_id 
JOIN film f
ON i.film_id = f.film_id 
WHERE r.customer_id = (SELECT customer_id 
						FROM customer 
						WHERE UPPER(first_name) = 'JAN' AND 
						UPPER(last_name) = 'SWITKOWSKI') AND
						NOT EXISTS (SELECT 1
									FROM public.payment p
									WHERE p.rental_id = r.rental_id);










		