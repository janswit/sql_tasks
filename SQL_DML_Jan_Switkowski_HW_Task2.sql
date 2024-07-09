CREATE TABLE table_to_delete AS
               SELECT 'veeeeeeery_long_string' || x AS col
               FROM generate_series(1,(10^7)::int) x; -- generate_series() creates 10^7 rows of sequential numbers from 1 to 10000000 (10^7)
               
SELECT *, pg_size_pretty(total_bytes) AS total,
                                    pg_size_pretty(index_bytes) AS INDEX,
                                    pg_size_pretty(toast_bytes) AS toast,
                                    pg_size_pretty(table_bytes) AS TABLE
               FROM ( SELECT *, total_bytes-index_bytes-COALESCE(toast_bytes,0) AS table_bytes
                               FROM (SELECT c.oid,nspname AS table_schema,
                                                               relname AS TABLE_NAME,
                                                              c.reltuples AS row_estimate,
                                                              pg_total_relation_size(c.oid) AS total_bytes,
                                                              pg_indexes_size(c.oid) AS index_bytes,
                                                              pg_total_relation_size(reltoastrelid) AS toast_bytes
                                              FROM pg_class c
                                              LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
                                              WHERE relkind = 'r'
                                              ) a
                                    ) a
               WHERE table_name LIKE '%table_to_delete%';

DELETE FROM table_to_delete
WHERE REPLACE(col, 'veeeeeeery_long_string','')::int % 3 = 0; -- removes 1/3 of all rows
 
VACUUM FULL VERBOSE table_to_delete;
 
TRUNCATE TABLE table_to_delete;

INSERT INTO table_to_delete (col)
SELECT 'veeeeeeery_long_string' || x
FROM generate_series(1, (10^7)::int) x;

TRUNCATE TABLE table_to_delete;

 -- Space consumption after creating it = 574mb
 -- First DELETE took 15 seconds
 -- SPACE consumption after first DELETE = 575mb
-- Second Delete took 18 seconds
 -- SPACE Consumption after VACUUM = 383MB
 -- Inserting took 21 seconds
-- TRUNCUATE was instantenous 
-- Space consumption after truncuate was 0 bytes
-- DELETE operations didn't reduce the space conusmption
-- Performing VACUUM reclaimed a good amount of space
-- TRUNCATE is much more efficient in terms of reclaiming space compared to DELETE
-- Inserting new data takes time and can increase space consumption.

