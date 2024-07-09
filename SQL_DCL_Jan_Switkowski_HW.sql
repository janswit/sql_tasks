-- Create a new user with the username "rentaluser" and the password "rentalpassword".
-- Give the user the ability to connect to the database but no other permissions.
CREATE ROLE rentaluser PASSWORD 'rentalpassword';
GRANT CONNECT ON DATABASE dvdrental TO rentaluser;

-- Grant "rentaluser" SELECT permission for the "customer" table. 
-- Сheck to make sure this permission works correctly—write a SQL query to select all customers.
GRANT SELECT ON TABLE customer TO rentaluser;
SET ROLE rentaluser;
SELECT * FROM customer;
RESET ROLE;

-- Create a new user group called "rental" and add "rentaluser" to the group. 
CREATE ROLE rental;
GRANT rental TO rentaluser;

-- Grant the "rental" group INSERT and UPDATE permissions for the "rental" table. 
-- Insert a new row and update one existing row in the "rental" table under that role. 
GRANT SELECT, INSERT, UPDATE ON TABLE rental TO rental;
SET ROLE rentaluser;
INSERT INTO rental (rental_id, rental_date, inventory_id, customer_id, return_date, staff_id)
VALUES (9989999, '2024-04-06', 78, 2, '2024-04-10', 5);
UPDATE rental 
SET return_date = '2024-04-11'
WHERE rental_date = '2024-04-06' AND customer_id = 2;
RESET ROLE;

-- Revoke the "rental" group's INSERT permission for the "rental" table. 
-- Try to insert new rows into the "rental" table make sure this action is denied.
REVOKE INSERT ON TABLE rental FROM rental;
SET ROLE rentaluser;
INSERT INTO rental (rental_id, rental_date, inventory_id, customer_id, return_date, staff_id)
VALUES (12512821, '2024-04-04', 2, 1, '2024-04-10', 5);
RESET ROLE;

-- I create a script that will create roles based on requirements
-- I declare rec RECORD so I can loop over the names and client_role which will be the name of the roles
-- I select first name and last name from customer and join necessary tables 
-- I group by name and add HAVING to meet the requirements
-- I start the loop and assign client_ + first_name + _ + last_name
-- I run and IF to see if the role already exists, if it doesn't I execute CREATE ROLE
-- I use format function in order to use current client_role
DO $$
DECLARE
	rec RECORD;
	client_role TEXT;
BEGIN
	FOR rec IN 
		SELECT c.first_name, c.last_name
		FROM customer c  
		JOIN payment p USING(customer_id)
		JOIN rental r USING(customer_id)
		GROUP BY c.first_name, c.last_name
		HAVING count(p.payment_id) > 0 AND  count(r.rental_id) > 0
	LOOP
		client_role := 'client_' || lower(rec.first_name) || '_' || lower(rec.last_name);
		IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = client_role) THEN 
			EXECUTE format('CREATE ROLE %I', client_role);	
		END IF;
	END LOOP;
END;
$$;

-- Enable row level security
ALTER TABLE rental ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment ENABLE ROW LEVEL SECURITY;

-- Create function that retrieves customer_id based on current user

CREATE OR REPLACE FUNCTION current_customer_id()
RETURNS INT
LANGUAGE SQL
SECURITY DEFINER
AS $$
    SELECT customer_id 
    FROM customer c
    WHERE lower(c.first_name) = lower(split_part(current_user, '_', 2)) AND
          lower(c.last_name) = lower(split_part(current_user, '_', 3));
$$;
ALTER FUNCTION current_customer_id() OWNER TO postgres;

-- Create two policies that allow current user to use select on rental and payment
CREATE POLICY customer_rental_policy ON rental
    FOR SELECT USING (customer_id = current_customer_id());
   
CREATE POLICY customer_payment_policy ON payment
    FOR SELECT USING (customer_id = current_customer_id());   


-- Granting select to rental and payment to all roles that start with client
-- I had to grant select to customer table as well to execute the function.
-- I tried using SECURITY DEFINER in current_customer_id function and ran it as transaction
-- With altering function to OWNER but which restricted access to customer, but returned empty tables from rental and payment 
DO $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN 
        SELECT rolname 
        FROM pg_roles 
        WHERE rolname LIKE 'client%'
    LOOP 
        EXECUTE format('GRANT SELECT ON customer, rental, payment TO %I', rec.rolname);   
    END LOOP;
END;
$$;


SET ROLE client_jesus_mccartney;
SELECT * FROM rental;
SELECT * FROM payment;
SELECT * FROM customer;

SELECT grantee, privilege_type, table_schema, table_name
FROM information_schema.role_table_grants;

SELECT datname, datdba FROM pg_database;

SELECT pid, usename, datname, client_addr, backend_start
FROM pg_stat_activity;