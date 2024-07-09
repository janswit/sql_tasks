-- All animation movies released between 2017 and 2019 with rate more than 1, sorted alphabetical
-- I select the film table from which I can get film title. 
-- Then I join film_category which will allow me to join categroy table on category_id
-- Now I have access to all the data I will be setting the conditions on: 
-- release_year, 'Animation' category and rental_rate
-- I use UPPER to account for mistakes in capitalization and order by title
SELECT  
	f.title AS film_title, 
    	c.name AS category_name 
FROM 
	film f
INNER JOIN 
	film_category fc ON f.film_id = fc.film_id 
INNER JOIN 
	category c ON fc.category_id = c.category_id 
WHERE 
	f.release_year BETWEEN 2017 AND 2019 AND 
	UPPER(c.name) = 'ANIMATION' AND 
    	f.rental_rate > 1 
ORDER BY 
	f.title;

-- `the revenue earned by each rental store after March 2017 (columns: address and address2 – as one column, revenue)
SELECT 
	SUM(p.amount),
	CONCAT(a.address, ' ', COALESCE(a.address2)) AS full_address 
FROM 
	payment p 
INNER JOIN 
	staff s ON p.staff_id = s.staff_id 
INNER JOIN 
	store s2 ON s.store_id = s2.store_id 
INNER JOIN 
	address a ON s2.address_id = a.address_id 
WHERE 
	p.payment_date > '2017-03-31'
GROUP BY 
	full_address
;

-- I join payment, rental, inventory and store tables so I can group by store_id
-- I aldo group by full_address(column i created) to ensure that payments are aggragated properly
-- Then based on store_id I join address table so I can get address and address2
-- I sum up the the payment amoounts as requested
-- I use concat to join address and address2 and coalesce to handle potential null values
SELECT 
	SUM(p.amount),
	CONCAT(a.address, ' ', COALESCE(a.address2)) AS full_address 
FROM 
	payment p 
INNER JOIN 
	rental r ON p.rental_id = r.rental_id 
INNER JOIN 
	inventory i ON r.inventory_id = i.inventory_id
INNER JOIN 
	store s ON i.store_id = s.store_id 
INNER JOIN 
	address a ON a.address_id = s.address_id
WHERE 
	p.payment_date > '2017-03-31'
GROUP BY 
	i.store_id, full_address;

-- Top-5 actors by number of movies (released after 2015) they took part in (columns: first_name, last_name, number_of_movies, sorted by number_of_movies in descending order)
-- Here I'm selecting film_ids from film_actor, as well as first_name and last name from actor
-- I have to join actor table to film_actor so I can retrieve actors' names based on id
-- I join film table because I need to set a condition for release_year
-- I group by a.actor_id, a.first_name, a.last_name to ensure everything is aggragated properly
SELECT  
	a.first_name,
        a.last_name,
        COUNT(fa.film_id) AS number_of_movies
FROM   
	film_actor fa 
JOIN 
	actor a ON fa.actor_id = a.actor_id
JOIN 
	film f ON fa.film_id = f.film_id
WHERE 
	f.release_year > 2015 
GROUP BY 
	a.actor_id,
	a.first_name,
    a.last_name		
ORDER BY 
	number_of_movies DESC 
LIMIT 5; 


/* Number of Drama, Travel, Documentary per year 
(columns: release_year, number_of_drama_movies, number_of_travel_movies, number_of_documentary_movies), 
sorted by release year in descending order. */

-- I join film to film_category and category to retrieve neccessary data
-- I set a condition to consider only films in the mentioned Categories 
-- and use upper function to account for capitalization
-- I select release year as requested
-- I do conditional count functions that count number of films that belong to a specific category 
-- Finally I group the results by release_year and order them in descending order

SELECT 
	f.release_year,
        COUNT(CASE WHEN UPPER(c.name) = 'DRAMA' THEN fc.film_id END) AS number_of_drama_movies,
        COUNT(CASE WHEN UPPER(c.name) = 'TRAVEL' THEN fc.film_id END) AS number_of_travel_movies,
        COUNT(CASE WHEN UPPER(c.name) = 'DOCUMENTARY' THEN fc.film_id END) AS number_of_documentary_movies
FROM 
	film f
JOIN 
	film_category fc ON f.film_id = fc.film_id
JOIN 
	category c ON fc.category_id = c.category_id
WHERE 
	UPPER(c.name) IN ('DRAMA', 'TRAVEL', 'DOCUMENTARY') 
GROUP BY 
	f.release_year 
ORDER BY 
	f.release_year DESC;


/*Who were the top revenue-generating staff members in 2017? They should be rewarded with a bonus for their performance. */

SELECT 
	s.staff_id, 
	CONCAT(s.first_name,' ', s.last_name) AS full_name,
	SUM(p.amount) AS revenue_generated,
	s2.store_id
FROM 
	staff s
JOIN 
	payment p ON s.staff_id = p.staff_id
JOIN 
	store s2 ON s.store_id = s2.store_id 
WHERE 
	EXTRACT(YEAR FROM p.payment_date) = 2017 
GROUP BY 
	s.staff_id, 
	s.first_name, 
	s.last_name, 
	s2.store_id
ORDER BY 
	revenue_generated DESC;

/* Hanna Carry GENERATED the most revenue nearly doubling the NEXT best person.
Rounding out the top 3 were Hanna Rainbow and Peter Lockyard */


/* Which 5 movies were rented more than others, and what's the expected age of the audience for these movies? 
 To determine expected age please use 'Motion Picture Association film rating system' */

-- I join the rental, inventory and film tables so I can retrieve necessary data and make the connection
-- I select title, rating and count rental_ids
-- I group by title and rating and order by total_rentals desc and limit to top 5 results

SELECT 
	COUNT(r.rental_id) AS total_rentals, -- Total count OF rentals
	f.title,
	f.rating AS category_name
FROM 
	rental r 
INNER JOIN 
	inventory i ON r.inventory_id = i.inventory_id 
INNER JOIN 
	film f ON i.film_id = f.film_id 
GROUP BY 
	f.title, f.rating
ORDER BY 
	total_rentals DESC 
LIMIT 5; 

/* There are two movies that are rated NC-17 which means 'No one 17 and under admitted'. 
 * This clearly means that those films are meant for adults and hopefully that's the majority of the audience
 * There are also two movies rated PG-13 which means that Parents are strongly cautioned
 * and some material may be inappropriate for children under 13. This movie is expected to be viewed 
 * by people who are at least 13 years old.
 * Lastly, there is one PG rated movie which means some material may not be suitable for children.
 * I assume that this movie is watched by audience of all ages excluding the 10-and-under or so.
 */ 


-- Which actors/actresses didn't act for a longer period of time than the others? 
-- V1:  gap between the latest release_year and current year per each actor

-- I join film_actor, film and actor table to make the necessary connection
-- I concat first and last name

SELECT a.first_name,	
	a.last_name,
       (MAX(f.release_year) - EXTRACT(YEAR FROM CURRENT_DATE)) * -1 AS release_year_gap
FROM 
	film_actor fa
JOIN 
	film f ON fa.film_id = f.film_id
JOIN 
	actor a ON fa.actor_id = a.actor_id
GROUP BY 
		a.first_name,
		a.last_name
ORDER BY 
	release_year_gap DESC;


-- The results are sorted in a descending order so we can clearly see who hasn't starred in a movie for the longest period of time
-- V2: gaps between sequential films per each actor
-- I'm creating a CTE so I can join the necessary data on itself later on

WITH actor_film_release AS (
    SELECT 
        fa.actor_id,
        a.first_name,
        a.last_name,
        f.release_year
    FROM 
        film_actor fa
    JOIN 
        film f ON fa.film_id = f.film_id
    JOIN 
        actor a ON fa.actor_id = a.actor_id
),
/* As mentioned above, I join actor_film_release on itself using actor_id
 Now I have two release_year columns next to each other. 
 I set a condition to account for values that hare equal or greater than 1
 I group by name, and release year
 I calculate gaps between years which I will later use in the next query 
 */
gap_calculated AS (
    SELECT 
        afr.first_name AS actor_first_name,
        afr.last_name AS actor_last_name,
        afr.release_year AS release_year,
        afr1.release_year AS release_year_two,
        afr1.release_year - afr.release_year AS min_gap
    FROM 
        actor_film_release afr
    JOIN 
        actor_film_release afr1 ON afr.actor_id = afr1.actor_id
    WHERE 
        afr1.release_year - afr.release_year >= 1
    GROUP BY 
        afr.first_name, 
        afr.last_name, 
        afr.release_year, 
        afr1.release_year
)
/* 
Computing the minimum gap for each actor and release year
Grouping the results by actor names and ordering them by the maximum minimum gap in descending order
Selecting the maximum minimum gap (max_unemployed) between consecutive release years for each actor.
 */
SELECT 
    actor_first_name, 
    actor_last_name,
    MAX(min_gap) as max_unemployed
FROM 
    (
        SELECT 
            gc.actor_first_name,
            gc.actor_last_name,
            gc.release_year,
            MIN(gc.min_gap) AS min_gap
        FROM 
            gap_calculated gc
        GROUP BY 
            gc.actor_first_name,
            gc.actor_last_name,
            gc.release_year
    )
GROUP BY 
    actor_first_name, 
    actor_last_name
ORDER BY max_unemployed DESC
;


-- V3: gap between the release of their first and last film
-- I'm not exactly sure how to correct this, this is exactly what the third version is asking me to count,
-- even though it doesn't make sense. I did it the way you asked below

SELECT 
    CONCAT(a.first_name, ' ', a.last_name) AS full_name,
    MAX(actor_films.max_release_year) - MIN(actor_films.min_release_year) AS gap_between_first_and_last_film
FROM 
    (SELECT fa.actor_id,
            MIN(f.release_year) AS min_release_year,
            MAX(f.release_year) AS max_release_year
     FROM   film_actor fa
     JOIN   film f ON fa.film_id = f.film_id
     GROUP BY fa.actor_id
    ) AS actor_films 
JOIN actor a ON a.actor_id = actor_films.actor_id
GROUP BY actor_films.actor_id, full_name
ORDER BY full_name ASC;


--
/* The CTE named actor_film_release retrieves information about actors, their corresponding films, 
 * and the release years of those films.
 * In gap_calculated CTE I join the actor_film_release on itself. I use the condition >= 1 to get rid of
 * negative values and in case there were two movies released in the same year.  
 * The final SELECT statement calculates the total unempployed tim for each actor
 * by summing up the differences between consecutive release years, 
 * excluding cases where the gap is less than one year 
 * and orders the results alphabetically by actor names 
*/

WITH actor_film_release AS (
    SELECT 
        fa.actor_id,
        a.first_name,
        a.last_name,
        f.title AS film_title,
        f.release_year
    FROM 
        film_actor fa
    JOIN 
        film f ON fa.film_id = f.film_id
    JOIN 
        actor a ON fa.actor_id = a.actor_id
),
gap_calculated AS (
    SELECT 
        afr.first_name AS actor_first_name,
        afr.last_name AS actor_last_name,
        afr.release_year AS release_year,
        MIN(afr1.release_year) AS release_year_two        
    FROM 
        actor_film_release afr
    JOIN 
        actor_film_release afr1 ON afr.actor_id = afr1.actor_id
    WHERE 
        afr1.release_year - afr.release_year >= 1
    GROUP BY 
        afr.first_name, 
        afr.last_name, 
        afr.release_year        
       )
 SELECT gc.actor_first_name,
 		gc.actor_last_name,
 		SUM(gc.release_year_two - gc.release_year) AS total_unemployed
 FROM gap_calculated gc
 WHERE gc.release_year_two - gc.release_year > 1
 GROUP BY gc.actor_first_name,
 		  gc.actor_last_name
 ORDER BY total_unemployed DESC
;
