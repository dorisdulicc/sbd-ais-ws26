
-- Exercise 2 — Activity 2.2: Why Is This Self-Join So Slow?
-- Run after creating people_big in PostgreSQL.
\timing on

-- Step 1: Create smaller copies of the table
CREATE TABLE people_50k AS
SELECT * FROM people_big WHERE id <= 50000;

CREATE TABLE people_100k AS
SELECT * FROM people_big WHERE id <= 100000;

CREATE TABLE people_200k AS
SELECT * FROM people_big WHERE id <= 200000;

-- Verify the table sizes
SELECT 'people_50k' AS table_name, COUNT(*) FROM people_50k
UNION ALL
SELECT 'people_100k', COUNT(*) FROM people_100k
UNION ALL
SELECT 'people_200k', COUNT(*) FROM people_200k;

-- Step 1: Self-join measurements
SELECT COUNT(*)
FROM people_50k p1
JOIN people_50k p2 ON p1.country = p2.country;

SELECT COUNT(*)
FROM people_100k p1
JOIN people_100k p2 ON p1.country = p2.country;

SELECT COUNT(*)
FROM people_200k p1
JOIN people_200k p2 ON p1.country = p2.country;

-- Step 2: Index experiment
CREATE INDEX idx_people_100k_country ON people_100k(country);
ANALYZE people_100k;

SELECT COUNT(*)
FROM people_100k p1
JOIN people_100k p2 ON p1.country = p2.country;

EXPLAIN ANALYZE
SELECT COUNT(*)
FROM people_100k p1
JOIN people_100k p2 ON p1.country = p2.country;

-- Step 3: Rewrite the count without generating all matching pairs
SELECT SUM(country_count * country_count) AS total_pairs
FROM (
    SELECT country, COUNT(*) AS country_count
    FROM people_100k
    GROUP BY country
) AS country_counts;

-- Run the rewritten query on the full million-row table
SELECT SUM(country_count * country_count) AS total_pairs
FROM (
    SELECT country, COUNT(*) AS country_count
    FROM people_big
    GROUP BY country
) AS country_counts;
