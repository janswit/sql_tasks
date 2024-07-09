/* I create a function with required parameters that returns a table with two columns
 * I declare two boolean and 6 text variables
 * I begin the function and check if the given customer_id exists within the database. If not, I raise an error
 * I do the second check to see if there are any records for the customer within given time frame, if there 
 * aren't any I raise an error.
 * If there is at least one record, I make a SELECT statement, if there aren't any records I raise an error
 * There is nothing fancy in the select statement. I select values into variables.
 * I join tables to retrieve necessary data, I setcondition for customer_id and date range. 
 * I group by first_name, last_name and email and use some aggregate functions.
 * I return query with specified values
 */

CREATE OR REPLACE FUNCTION public.get_customer_data(p_client_id INT, p_left_boundary DATE, p_right_boundary DATE)
RETURNS TABLE (metric_name TEXT, metric_value TEXT)
LANGUAGE plpgsql
AS $$
DECLARE
	v_customer_exists BOOLEAN;
	v_date_exists BOOLEAN;
	v_customer_name TEXT;
	v_customer_email TEXT;
	v_num_films_rented TEXT;
	v_film_titles TEXT;
	v_num_payments TEXT;
	v_sum_payments TEXT;
BEGIN
	SELECT EXISTS (
		SELECT 1
		FROM customer
		WHERE customer_id = p_client_id
		) INTO v_customer_exists;
	IF NOT v_customer_exists THEN
		RAISE EXCEPTION 'Customer ID % doesn''t exist in the database', p_client_id;
	END IF;
	SELECT EXISTS(
		SELECT 1 
		FROM rental
		WHERE customer_id = p_client_id AND
			  rental_date >= p_left_boundary AND
			  rental_date <= p_right_boundary
			  ) INTO v_date_exists;			 
	IF v_date_exists THEN
		SELECT c.first_name || ' ' || c.last_name, 
			   c.email, 
			   COUNT(DISTINCT(r.rental_id)),
			   STRING_AGG(f.title, ', '), 
			   COUNT(DISTINCT(p.payment_id)), 
			   SUM(p.amount)
		INTO v_customer_name, v_customer_email, v_num_films_rented, v_film_titles, v_num_payments, v_sum_payments
		FROM customer c
		JOIN rental r ON c.customer_id = r.customer_id
		JOIN payment p ON r.rental_id = p.rental_id
		JOIN inventory i ON r.inventory_id = i.inventory_id 
		JOIN film f ON i.film_id = f.film_id 
		WHERE c.customer_id = p_client_id  
		GROUP BY c.first_name, c.last_name, c.email;
		RETURN QUERY
		VALUES
			('customers'' info', v_customer_name || ', ' || v_customer_email),
			('num. of films rented', v_num_films_rented),
			('rented films'' titles', v_film_titles),
			('num. of payments', v_num_payments),
			('payment amount', v_sum_payments);
	ELSE 
		RAISE EXCEPTION 'No rentals for Customer ID: % from % to %',p_client_id, p_left_boundary, p_right_boundary;
	END IF;
END;
$$;




