-- CREATE DATABASE mount_club

CREATE SCHEMA IF NOT EXISTS mc;

-- I use varchar for building, apartment and zip code to account for letters and signs like "-"
-- NOT NULL values are set for the columns that are required
-- Create a constraint that allows only unique addresses to avoid storing duplicates

CREATE TABLE IF NOT EXISTS mc.addresses (
    address_id SERIAL PRIMARY KEY,
    street VARCHAR(100) NOT NULL,
    building VARCHAR(15) NOT NULL,
    apartment VARCHAR(15),
    country VARCHAR(50) NOT NULL,
    zip_code VARCHAR(15) NOT NULL,
    CONSTRAINT unique_address_constraint UNIQUE (street, building, apartment, country, zip_code)
);

-- I skip address_id because it is serial
-- ON CONFLICT prevents entering duplicates
INSERT INTO mc.addresses (street, building, apartment, country, zip_code)
VALUES ('Hikers Paradise', 13, 135, 'Poland', '80-345'),
		('Downing street', 1, 2, 'England', '213-8790')
ON CONFLICT ON CONSTRAINT unique_address_constraint DO NOTHING;


-- Storing the concatenated lowercase full name of the person to prevent duplicate entries
-- NOT NULL constraints ensure all required columns are present
-- Constraint `unq_full_name_address` guarantees uniqueness of each full name and address combination
-- Defining a foreign key constraint referencing the `addresses` table, with ON DELETE SET NULL and ON UPDATE CASCADE actions
-- The ON DELETE SET NULL ensures that if a referenced row in the `mc.areas` table is deleted, 
-- the corresponding `area_id` in the `mc.mountains` table will be set to NULL. 
-- The ON UPDATE CASCADE specifies that if the referenced `area_id` is updated, 
-- the corresponding `area_id` in the `mc.mountains` table will also be updated accordingly.

CREATE TABLE IF NOT EXISTS mc.people (
    person_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    phone VARCHAR(15) NOT NULL,
    address_id INT,
    full_name VARCHAR(100) GENERATED ALWAYS AS (lower(first_name) || ' ' || lower(last_name)) STORED,
    CONSTRAINT unq_full_name_address UNIQUE (full_name, address_id),
    FOREIGN KEY (address_id) REFERENCES mc.addresses(address_id) ON DELETE SET NULL ON UPDATE CASCADE
);


-- In this insert statement I create data CTE that selects address_id based on street, building, apartment and zip_code
-- The ON CONFLICT clause allows for two of two people living under the same address to have the same address_id
INSERT INTO mc.people (first_name, last_name, phone, address_id)
SELECT first_name, last_name, phone, address_id
FROM (
    VALUES 
        ('Jan', 'Switkowski', '897098765', (SELECT address_id FROM mc.addresses 
                                             WHERE lower(street) = 'hikers paradise' AND building = '13' 
                                             AND apartment = '135' AND lower(country) = 'poland'
                                             AND zip_code = '80-345')),
        ('ANNA', 'Gruda', '897198765', (SELECT address_id FROM mc.addresses 
                                         WHERE lower(street) = 'downing street' AND building = '1'
                                         AND lower(apartment) = '2' AND lower(country) = 'england'
                                         AND zip_code = '213-8790'))
) AS data(first_name, last_name, phone, address_id)
ON CONFLICT (full_name, address_id) DO NOTHING;



-- ON DELETE RESTRICT prevents deleting person_id from people table as someone still can be an emergency contact.
-- start_date and end_date CHECKS ensure that entered dates are between 2000-01-02(including) and 2030-01-01
-- status CHECK ensures that status is either active or inactive
-- CONSTRAINT unique_id ensures that only unique person_id can be entered
CREATE TABLE IF NOT EXISTS mc.climbers (
	climber_id SERIAL PRIMARY KEY,
	person_id INT NOT NULL,
	start_date DATE CHECK (start_date BETWEEN '2000-01-02' AND '2030-01-01'),
	end_date DATE CHECK (end_date BETWEEN '2000-01-02' AND '2030-01-01'),
	status VARCHAR(8) NOT NULL CHECK (status IN ('active', 'inactive')),
	FOREIGN KEY (person_id) REFERENCES mc.people(person_id) ON DELETE RESTRICT ON UPDATE CASCADE,
	CONSTRAINT unq_person_id UNIQUE (person_id)
);

-- This seems like a very convulutated way to retrieve person_id but it seems necessary to get it right. 
-- Is there a more optimal way to retrieve it?
-- Since two people can live under the same roof I need to get the name and the address to get the person_id
-- and that's the way I approached it. 
INSERT INTO mc.climbers(person_id, start_date, end_date, status)
SELECT data.person_id, data.start_date, data.end_date, data.status
FROM (
    VALUES 
        (
            (SELECT person_id 
             FROM mc.people 
             WHERE lower(full_name) = 'jan switkowski' AND
                   address_id = (SELECT address_id 
                                 FROM mc.addresses 
                                 WHERE lower(street) = 'hikers paradise' AND 
                                       building = '13' AND 
                                       apartment = '135' AND 
                                       lower(country) = 'poland' AND
                                       zip_code = '80-345')
            ), 
            '2003-01-01'::date, '2010-02-09'::date, 'active'
        ),
        (
            (SELECT person_id 
             FROM mc.people 
             WHERE lower(full_name) = 'anna gruda' AND
                   address_id = (SELECT address_id 
                                 FROM mc.addresses 
                                 WHERE lower(street) = 'downing street' AND 
                                       building = '1' AND 
                                       apartment = '2' AND 
                                       lower(country) = 'england' AND
                                       zip_code = '213-8790')
            ), 
            '2003-01-01'::date, '2010-02-09'::date, 'active'
        )
) AS data(person_id, start_date, end_date, status)
ON CONFLICT ON CONSTRAINT unq_person_id DO NOTHING;



-- The area_id column serves as the primary key, auto-incrementing with the SERIAL data type.
-- area_name stores the name of the mountain area, ensuring it is not NULL.
-- country stores the country associated with the mountain area, ensuring it is not NULL.
-- CONSTRAINT `unq_area_name_country` ensures that each combination of `area_name` and `country` is unique.
CREATE TABLE IF NOT EXISTS mc.areas( 
    area_id SERIAL PRIMARY KEY,
    area_name VARCHAR(100) NOT NULL,
    country VARCHAR(50) NOT NULL,
    CONSTRAINT unq_area_name_country UNIQUE (area_name, country)
);

-- The ON CONFLICT ON CONSTRAINT unq_area_name_country DO NOTHING clause ensures that if there's a conflict 
-- due to violating the unique constraint (unq_area_name_country), the conflicting row will be ignored and 
-- no action will be taken, preventing duplicate entries in the table.
INSERT INTO mc.areas (area_name, country)
VALUES 
    ('Bieszczady', 'Poland'),
    ('Mont Blanc massif', 'France')
ON CONFLICT ON CONSTRAINT unq_area_name_country DO NOTHING;


-- CHECK (height > 0) ensures that mountain height is a positive number
-- CONSTRAINT unq_mountain_name prevents from inserting the same mountain
-- FOREIGN KEY is set to area_id referencing mc.areas(area_id)
-- The ON DELETE SET NULL ensures that if a referenced row in the mc.areas table is deleted, 
-- the corresponding area_id in the mountains table is set to NULL. 
-- The ON UPDATE CASCADE  specifies that if the referenced area_id is updated, 
-- the corresponding area_id in the mountains table will also be updated accordingly

CREATE TABLE IF NOT EXISTS mc.mountains(
	mountain_id SERIAL PRIMARY KEY,
	mountain_name VARCHAR(100) NOT NULL,
	height INT NOT NULL CHECK (height > 0),
	area_id INT,
	CONSTRAINT unq_mountain_name UNIQUE (mountain_name),
	FOREIGN KEY (area_id) REFERENCES mc.areas(area_id) ON DELETE SET NULL ON UPDATE CASCADE
);


-- It selects data from a VALUES clause containing mountain names, heights, and corresponding area_ids, 
-- obtained by querying the mc.areas table for the respective area_id based on the area_name and country.
-- The ON CONFLICT ON CONSTRAINT unq_mountain_name DO NOTHING clause ensures that if there's a conflict 
-- due to violating the unique constraint (unq_mountain_name), the conflicting row will be ignored and 
-- no action will be taken, preventing duplicate entries in the table.

INSERT INTO mc.mountains (mountain_name, height, area_id)
SELECT data.mountain_name, data.height, data.area_id
FROM (VALUES 
    ('Mont Blanc', 4808, (SELECT area_id FROM mc.areas 
                          WHERE lower(area_name) = 'mont blanc massif' AND lower(country) = 'france')),
    ('Tarnica', 1346, (SELECT area_id FROM mc.areas 
                       WHERE lower(area_name) = 'bieszczady' AND lower(country) = 'poland'))
) AS data(mountain_name, height, area_id)
ON CONFLICT ON CONSTRAINT unq_mountain_name DO NOTHING;


-- The mountain_id column is defined as NOT NULL and serves as a foreign key referencing mountain_id in the mc.mountains table.
-- The ON DELETE SET NULL ensures that if a referenced row in the mc.mountains table is deleted, 
-- the corresponding mountain_id in the mountain_paths table is set to NULL. 
-- The ON UPDATE CASCADE specifies that if the referenced mountain_id is updated, 
-- the corresponding mountain_id in the mountain_paths table will also be updated accordingly.
-- The CONSTRAINT unq_mountain_id_description ensures that the combination of mountain_id and description is unique in the table,
-- preventing duplicate entries. Since there can be different paths to the top of the mountain, the description column
-- would ideally describe the path a bit better but I didn't have time to research different paths to the top.

CREATE TABLE IF NOT EXISTS mc.mountain_paths (
    mountain_path_id SERIAL PRIMARY KEY,
    mountain_id INT NOT NULL ,
    difficulty VARCHAR(20) NOT NULL CHECK (difficulty IN ('beginner', 'intermediate', 'advanced', 'expert')),
    length DECIMAL NOT NULL CHECK (length > 0),  
    description TEXT,
    FOREIGN KEY (mountain_id) REFERENCES mc.mountains(mountain_id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT unq_mountain_id_description UNIQUE (mountain_id, description)
);

-- The VALUES clause contains subqueries to fetch the corresponding "mountain_id" for the given mountain names.
-- The WHERE clause filters out NULL "mountain_id" values to prevent inserting paths without a valid mountain reference.
-- The ON CONFLICT clause ensures that if there's a conflict on the unique constraint "unq_mountain_id_description",
-- indicating an attempt to insert duplicate paths, the statement will do nothing and skip those conflicting rows.

INSERT INTO mc.mountain_paths(mountain_id, difficulty, length, description)
SELECT data.mountain_id, data.difficulty, data.length, data.description
FROM (
    VALUES	
    ((SELECT mountain_id FROM mc.mountains WHERE lower(mountain_name) = 'tarnica'), 
    'intermediate', 4, 'Picturesque climb in Bieszczady'),
    ((SELECT mountain_id FROM mc.mountains WHERE lower(mountain_name) = 'mont blanc'),
    'expert', 15, 'Challenging, iconic, breathtaking, alpine adventure.')
) AS data(mountain_id, difficulty, length, description) 
WHERE data.mountain_id IS NOT NULL
ON CONFLICT ON CONSTRAINT unq_mountain_id_description DO NOTHING;


-- Create the table for storing guides' information
-- Ensure uniqueness of full name and phone
CREATE TABLE IF NOT EXISTS mc.guides (
    guide_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    full_name VARCHAR(100) GENERATED ALWAYS AS (lower(first_name) || ' ' || lower(last_name)) STORED,
    phone VARCHAR(15) NOT NULL,
    experience VARCHAR(20) NOT NULL CHECK (experience IN ('beginner', 'intermediate', 'advanced', 'expert')),
    CONSTRAINT unq_full_name_phone UNIQUE (full_name, phone) 
);

-- Insert data into the guides table, ensuring uniqueness of full name and phone
INSERT INTO mc.guides (first_name, last_name, phone, experience)
SELECT data.first_name, data.last_name, data.phone, data.experience
FROM (
    VALUES
        ('Pawel', 'Kowalski', '29835789235', 'intermediate'),
        ('Karol', 'Nowak', '3889-9393', 'expert')
) AS data(first_name, last_name, phone, experience)
ON CONFLICT ON CONSTRAINT unq_full_name_phone DO NOTHING;

-- FOREIGN KEY referencing the guide assigned to the climbing group
-- ON DELETE restrict clause specifies that a row cannot be deleted from guides table 
-- if it has dependent rows in the the guide_group_assignment
-- ON UPDATE CASCADE specifies that if the referenced guide_id is updated,
-- the corresponding guide_id in guide_group_assignment will also be updated accordingly
-- CONSTRAINT unq_id_combination ensure unique combination of guide_group_id, group_id, and guide_id
-- are only allowed in the table

CREATE TABLE IF NOT EXISTS mc.climber_group_assignment (
	climber_group_id SERIAL PRIMARY KEY,
	climber_id INT NOT NULL, -- reference added AFTER creation OF climb_groups
	group_id INT NOT NULL,
	FOREIGN KEY (climber_id) REFERENCES mc.climbers(climber_id) ON DELETE RESTRICT ON UPDATE CASCADE,
	CONSTRAINT unq_climber_group_combination UNIQUE (climber_group_id, group_id, climber_id)
);

ALTER TABLE mc.climber_group_assignment
DROP CONSTRAINT IF EXISTS unq_id_combination, -- Dropping the existing constraint if it exists
ADD CONSTRAINT unq_id_combination UNIQUE (climber_group_id, group_id, climber_id); -- Adding the new unique constraint

-- FOREIGN KEY links the mountain_path_id column to the mountain_paths table,
-- ensuring that each climb is associated with a valid mountain path.
-- CONSTRAINT unq_climb_group_id ensures that each climb is associated with only one group.
-- CONSTRAINT unq_climb_path_id ensures that each climb is associated with only one mountain path.

CREATE TABLE IF NOT EXISTS mc.climbs (
	climb_id SERIAL PRIMARY KEY,
	mountain_path_id INT NOT NULL ,
	group_id INT NOT NULL, -- ADD reference
	start_date DATE CHECK (start_date BETWEEN '2000-01-02' AND '2030-01-01'),
	end_date DATE CHECK (end_date  BETWEEN '2000-01-02' AND '2030-01-01' AND end_date >= start_date),
	FOREIGN KEY (mountain_path_id) REFERENCES mc.mountain_paths(mountain_path_id) ON DELETE RESTRICT ON UPDATE CASCADE,
	CONSTRAINT unq_mountain_path_group_id_start_date UNIQUE (mountain_path_id, group_id, start_date),
	CONSTRAINT unq_climb_group_id UNIQUE (climb_id, group_id)
);

-- Inserting climbs into the mc.climbs table for two mountain paths: 'tarnica' and 'mont blanc'
-- Selecting the mountain_path_id for the mountain named 'tarnica'
-- Selecting the mountain_path_id for the mountain  named 'mont blanc'
-- Using ON CONFLICT clause to handle conflicts based on the unique constraint unq_mountain_path_group_id_start_date
-- since same group can go on the same path multiple times, but it's unlikely they will go on the same day
INSERT INTO mc.climbs (mountain_path_id, group_id, start_date, end_date)
VALUES 
((SELECT mp.mountain_path_id 
        FROM mc.mountain_paths mp
        JOIN mc.mountains m ON mp.mountain_id = m.mountain_id
        WHERE lower(m.mountain_name) = 'tarnica'), 
    0, '2024-04-03'::date, '2024-04-05'::date
),
((SELECT mp.mountain_path_id 
        	FROM mc.mountain_paths mp
        	JOIN mc.mountains m ON mp.mountain_id = m.mountain_id
        	WHERE lower(m.mountain_name) = 'mont blanc'), 
    0, '2023-03-03'::date, '2023-03-05'::date)
ON CONFLICT ON CONSTRAINT unq_mountain_path_group_id_start_date DO NOTHING;

ALTER TABLE mc.climbs
DROP CONSTRAINT IF EXISTS unq_mountain_path_group_id_start_date, -- Dropping the existing constraint if it exists
ADD CONSTRAINT unq_mountain_path_group_id_start_date UNIQUE (mountain_path_id, group_id, start_date);

-- CONSTRAINT unq_weather_area_date ensure uniqness based on climb, area, and last updated date(so one record per day), 
-- but there can be multiple forecasts
CREATE TABLE IF NOT EXISTS mc.weather_forecasts (
    weather_id SERIAL PRIMARY KEY,
    climb_id INT NOT NULL REFERENCES mc.climbs(climb_id),
    area_id INT NOT NULL REFERENCES mc.areas(area_id),
    temperature DECIMAL NOT NULL,
    wind_speed INT,
    precipitation DECIMAL,
    visibility INT,
    conditions VARCHAR(100),
    last_updated DATE DEFAULT CURRENT_DATE,
    CONSTRAINT unq_weather_area_date UNIQUE (climb_id, area_id, last_updated)
);



INSERT INTO mc.weather_forecasts (climb_id, area_id, temperature, wind_speed, precipitation, visibility)
SELECT data.climb_id, data.area_id, data.temperature, data.wind_speed, data.precipitation, data.visibility
FROM (
    VALUES 
        (
			(SELECT a.area_id AS area_id
                FROM mc.areas a
                WHERE lower(a.area_name) = 'bieszczady' 
            ),
            (SELECT c.climb_id AS climb_id
                FROM mc.areas a
                JOIN mc.mountains m ON a.area_id = m.area_id
                JOIN mc.mountain_paths mp ON m.mountain_id = mp.mountain_id
                JOIN mc.climbs c ON mp.mountain_path_id = c.mountain_path_id
                WHERE lower(a.area_name) = 'bieszczady' AND lower(m.mountain_name) = 'tarnica' AND DATE(c.start_date) = '2024-04-03'
            ),
            20, 0, 0, 100
        ),
        (	
        	(SELECT a.area_id AS area_id
                FROM mc.areas a
                WHERE lower(a.area_name) = 'mont blanc massif' 
            ),
            (SELECT c.climb_id AS climb_id
                FROM mc.areas a
                JOIN mc.mountains m ON a.area_id = m.area_id
                JOIN mc.mountain_paths mp ON m.mountain_id = mp.mountain_id
                JOIN mc.climbs c ON mp.mountain_path_id = c.mountain_path_id
                WHERE lower(a.area_name) = 'mont blanc massif' AND lower(m.mountain_name) = 'mont blanc' AND DATE(c.start_date) = '2023-03-03'
            ), 
            10, 10, 40, 70
        )
) AS data (climb_id, area_id, temperature, wind_speed, precipitation, visibility)
ON CONFLICT ON CONSTRAINT unq_weather_area_date DO NOTHING;


CREATE TABLE IF NOT EXISTS mc.guide_group_assignment (
	guide_group_id SERIAL PRIMARY KEY,
	group_id INT NOT NULL, -- reference added AFTER creation OF climb_groups
	guide_id INT NOT NULL,
	FOREIGN KEY (guide_id) REFERENCES mc.guides(guide_id) ON DELETE RESTRICT ON UPDATE CASCADE,
	CONSTRAINT unq_id_group_guide_combination UNIQUE (guide_group_id, group_id, guide_id)
); 


CREATE TABLE IF NOT EXISTS mc.climb_groups (
	group_id SERIAL PRIMARY KEY,
	guide_group_id INT NOT NULL,
	climber_guide_id INT NOT NULL,-- reference added below
	FOREIGN KEY (guide_group_id) REFERENCES mc.guide_group_assignment(guide_group_id),
	CONSTRAINT unq_group_guide_group_climber_guide_id UNIQUE (group_id, guide_group_id, climber_guide_id)
	);



					
ALTER TABLE mc.addresses
ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;

ALTER TABLE mc.people
ADD COLUMN IF NOT EXISTS  record_ts DATE NOT NULL DEFAULT current_date;

ALTER TABLE mc.climbers
ADD COLUMN IF NOT EXISTS  record_ts DATE NOT NULL DEFAULT current_date;

ALTER TABLE mc.areas
ADD COLUMN IF NOT EXISTS  record_ts DATE NOT NULL DEFAULT current_date;

ALTER TABLE mc.mountains
ADD COLUMN IF NOT EXISTS  record_ts DATE NOT NULL DEFAULT current_date;

ALTER TABLE mc.mountain_paths
ADD COLUMN IF NOT EXISTS  record_ts DATE NOT NULL DEFAULT current_date;

ALTER TABLE mc.guides
ADD COLUMN IF NOT EXISTS  record_ts DATE NOT NULL DEFAULT current_date;

ALTER TABLE mc.guide_group_assignment
ADD COLUMN IF NOT EXISTS  record_ts DATE NOT NULL DEFAULT current_date;

ALTER TABLE mc.climbs
ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;

ALTER TABLE mc.weather_forecasts
ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;

/* Not finished, had trouble figuring out how to insert data while avoiding duplicates
 INSERT INTO mc.guide_group_assignment(guide_id)
VALUES (SELECT guide_id FROM  mc.guides g
							WHERE lower(g.first_name) = 'pawel' AND lower(g.last_name) = 'kowalski')


INSERT INTO mc.climb_groups
SELECT (VALUES
	((SELECT guide_group_id FROM mc.guide_group_assignment gga
							JOIN mc.guides g
							ON gga.guide_id = g.guide_id
							WHERE lower(g.first_name) = 'pawel' AND lower(g.last_name) = 'kowalski'), 0),
	((SELECT guide_group_id FROM mc.guide_group_assignment gga
							JOIN mc.guides g
							ON gga.guide_id = g.guide_id
							WHERE lower(g.first_name) = 'karol' AND lower(g.last_name) = 'nowak'), 0)
);
 */	

							









     
     








