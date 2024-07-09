-- TASK 1

/* I join all the necessaray tables to get category names associated with payments.
 * I set a condition where I extract year and quarter from payment_date and it has to equal to
 * extracting year and quarter from current date.
 * I group the the results by category names with a having condition as
 * sum(p.amount) > 0 to ensure that there was at least one sale.
 */

CREATE OR REPLACE VIEW public.sales_revenue_by_category_qtr
AS SELECT c.name AS category,
    sum(p.amount) AS total_sales
   FROM payment p
     JOIN rental r ON p.rental_id = r.rental_id
     JOIN inventory i ON r.inventory_id = i.inventory_id
     JOIN film f ON i.film_id = f.film_id
     JOIN film_category fc ON f.film_id = fc.film_id
     JOIN category c ON fc.category_id = c.category_id
    WHERE EXTRACT(YEAR FROM p.payment_date) = EXTRACT(YEAR FROM CURRENT_DATE) AND 
    	  EXTRACT(QUARTER FROM p.payment_date) = EXTRACT(QUARTER FROM CURRENT_DATE)
  GROUP BY c.name
  HAVING sum(p.amount) > 0
  ORDER BY (sum(p.amount)) DESC;
 
 -- SELECT * FROM sales_revenue_by_category_qtr;

 -- TASK 2
 
 /* I'm creating a function with one text parameter quarter_year(which should be formatted 
  * as 'quarter-year', for example '1-2017'). This function returns a table with film category and total_sales
  * The select statement is almost identical as above except for the condition part.
  * I split the input text at '-' and cast the values as integers. 
  */
 
 CREATE OR REPLACE FUNCTION public.get_sales_revenue_by_category_qtr(quarter_year TEXT)
 RETURNS TABLE (category TEXT, total_sales NUMERIC) 
 LANGUAGE sql
AS $function$
    SELECT c.name AS category,
    sum(p.amount) AS total_sales
   FROM payment p
     JOIN rental r ON p.rental_id = r.rental_id
     JOIN inventory i ON r.inventory_id = i.inventory_id
     JOIN film f ON i.film_id = f.film_id
     JOIN film_category fc ON f.film_id = fc.film_id
     JOIN category c ON fc.category_id = c.category_id
    WHERE EXTRACT(QUARTER FROM p.payment_date) = CAST(SPLIT_PART(quarter_year, '-', 1) AS INTEGER) AND
    	  EXTRACT(YEAR FROM p.payment_date) = CAST(SPLIT_PART(quarter_year, '-', 2) AS INTEGER)   	  
  GROUP BY c.name
  HAVING sum(p.amount) > 0
  ORDER BY (sum(p.amount)) DESC; 
$function$
;

-- SELECT * FROM get_sales_revenue_by_category_qtr('1-2017');

-- TASK 3
/* I create a function that takes in an array as input so I can loop over it
 * I declare to variables, v_country_name as text and v_country_found as bool so I can later check if country is in the database
 * I use the FOREACH to loop over every country in countries array(in case there is more than one)
 * I set to v_country_found to FALSE and check if exists in the database. If it does it will set v_country_found as TRUE
 * If country is not found, it will raise an error
 * I use return query so I can return a required table. 
 * SELECT statement is pretty straightforward where I do a few joins, to get all the required tables. 
 * I set a where condition that retrieves results for the country currently processed. I group by the selected values,
 * and order by descending count of rental_id and limit it to the top result.
 * I cast the language name as varchar as it is in a datatype that I couldn't specify. 
 */

DROP FUNCTION most_popular_film_by_countries(text[]);
CREATE OR REPLACE FUNCTION public.most_popular_film_by_countries(countries TEXT[])
RETURNS TABLE(country TEXT, title TEXT, rating public.mpaa_rating, language_name VARCHAR, 
				film_length SMALLINT, release_year public.year)
LANGUAGE plpgsql AS
$$
DECLARE
	v_country_name TEXT;
	v_country_found BOOLEAN;
BEGIN
	FOREACH v_country_name IN ARRAY countries
	LOOP
		RAISE NOTICE 'Processing country: %', v_country_name;
		v_country_found := FALSE;
		
		SELECT EXISTS (SELECT 1 FROM country c3 
								WHERE lower(c3.country) = lower(v_country_name))
			INTO v_country_found;
		
		IF NOT v_country_found THEN
			RAISE EXCEPTION 'Country with specified name does not exist: %', v_country_name;
		END IF;
		

		RETURN QUERY SELECT c3.country, f.title, f.rating, l.name::VARCHAR AS language_name, 
							f.length, f.release_year
			FROM film f
				JOIN inventory i ON f.film_id = i.film_id
				JOIN rental r ON i.inventory_id = r.inventory_id 
				JOIN customer c ON r.customer_id = c.customer_id 
				JOIN address a ON c.address_id = a.address_id 
				JOIN city c2 ON a.city_id = c2.city_id 
				JOIN country c3 ON c2.country_id = c3.country_id
				JOIN "language" l ON f.language_id = l.language_id
			WHERE lower(c3.country) = lower(v_country_name)
			GROUP BY c3.country, f.title, f.rating, l.name, f.length, f.release_year 
			ORDER BY count(r.rental_id) DESC 
			LIMIT 1;
		END LOOP;
END;
$$;

-- SELECT * FROM most_popular_film_by_countries(ARRAY['United States', 'Canada', 'Japan']);
-- SELECT * FROM most_popular_film_by_countries(ARRAY['United States', 'Canada', 'Jaapan']);

-- TASK 4

/* I create a function that returns a table with 5 required columns
 * I declare two variables which I will later use in the loop. 
 * I use record which will be used as a placeholder for the retrieved results in a single row
 * Then I initialize the value of row_counter to 1 to start the count at 1
 * I start with an if statement  that title_word cannot be null.
 * I start the for, loop statement
 * The select statement is pretty simple, I make some joins and set a condition using ILIKE which does case-insensitive search
 */

CREATE OR REPLACE FUNCTION public.films_in_stock_by_title(title_word TEXT)
RETURNS TABLE(counter INTEGER, title TEXT, language_name TEXT,customer_name TEXT, rental_date TIMESTAMP)
LANGUAGE plpgsql AS
$$
DECLARE
	rec record;
	row_counter integer := 1;
BEGIN
	IF title_word IS NULL OR title_word = '' THEN
		RAISE EXCEPTION	'Title cannot be NULL';
	END IF;

	FOR rec IN SELECT f.title, 
					  l.name, 
					  r.rental_date, 
					  c.first_name || ' ' || c.last_name AS customer_name
				FROM film f 
				JOIN "language" l ON f.language_id = l.language_id 
				JOIN inventory i ON f.film_id =i.film_id 
				JOIN rental r ON i.inventory_id = r.inventory_id 
				JOIN customer c ON r.customer_id = c.customer_id 
				WHERE f.title ILIKE '%' || title_word || '%'				
	LOOP
		counter := row_counter;
		title := rec.title;
		language_name := rec.name;
		customer_name := rec.customer_name;
		rental_date := rec.rental_date;
		RETURN NEXT;
		row_counter := row_counter + 1;
	END LOOP;

	IF NOT FOUND THEN
		RAISE NOTICE 'There is no film with % in the title', title_word;
	END IF;
END;
$$;


-- SELECT * FROM films_in_stock_by_title('');
-- SELECT * FROM films_in_stock_by_title('lhh');
-- SELECT * FROM films_in_stock_by_title('love');


-- TASK 5
/* I create the function new_film with required movie_title, and movie language and release year optional.
 * I set default values to the latter two. The function returns a table with inserted values.
 * I declare values v_language_id and v_language_name. I use the first one to check if language exists in the database
 * and raise notice if it doesn't. I use the second one to as a variable in the the returning table.
 * I set required constants. 
 * I begin the function and check if title is not null or ''. If it is, I raise an error.
 * Then I check language_id exists for the given language. If it doesn't, I insert it into languae table
 * and return v_language_id.
 * I insert the required values into film table and return them in a table.
 * 
 */

CREATE OR REPLACE FUNCTION public.new_film(
    movie_title TEXT, 
    movie_language TEXT DEFAULT 'Klingon',
    movie_release_year INT DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)
)
RETURNS TABLE(
    movie_id INT, 
    title TEXT, 
    language_name TEXT, 
    release_year INT, 
    rental_rate NUMERIC, 
    rental_duration INT, 
    replacement_cost NUMERIC
) 
LANGUAGE plpgsql AS
$$
DECLARE
    v_language_id INT;
    v_language_name TEXT;
    c_rental_duration CONSTANT INT := 3;
    c_rental_rate CONSTANT NUMERIC := 4.99;
    c_replacement_cost CONSTANT NUMERIC := 19.99;       
BEGIN
    IF movie_title IS NULL OR movie_title = '' THEN 
        RAISE EXCEPTION 'Movie title cannot be null or empty.';
    END IF;
    
    SELECT language_id INTO v_language_id 
    FROM "language" 
    WHERE lower(name) = lower(movie_language);
    
    IF NOT FOUND THEN
        INSERT INTO "language"(name) 
        VALUES (movie_language) 
        RETURNING language_id INTO v_language_id;
    END IF;    

    IF v_language_id IS NULL THEN
        RAISE EXCEPTION 'Failed to find or insert movie language.';
    END IF;

    SELECT name INTO v_language_name 
    FROM "language" 
    WHERE language_id = v_language_id;

    RETURN QUERY
    INSERT INTO film(title, release_year, language_id, rental_duration, rental_rate, replacement_cost)
    VALUES (
        movie_title,
        movie_release_year,
        v_language_id,
        c_rental_duration,
        c_rental_rate,
        c_replacement_cost
    )
    RETURNING film_id AS movie_id, 
              movie_title, 
              v_language_name AS language_name, 
              movie_release_year, 
              c_rental_rate, 
              c_rental_duration AS rental_duration, 
              c_replacement_cost;
END;
$$;

-- SELECT * FROM new_film('Star Trek');

