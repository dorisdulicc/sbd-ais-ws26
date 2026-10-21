
-- Exercise 2 — Activity 2.1: PostgreSQL Analytical Queries
-- Dataset: 1,000,000 e-commerce orders

-- defining the table
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    customer_name TEXT,
    product_category TEXT,
    quantity INTEGER,
    price_per_unit NUMERIC(10, 2),
    order_date DATE,
    country TEXT
);

-- A. Which order has the highest price_per_unit?
SELECT *
FROM orders
ORDER BY price_per_unit DESC
LIMIT 1;

-- B. Top 3 product categories by total quantity sold
SELECT
    product_category,
    SUM(quantity) AS total_quantity_sold
FROM orders
GROUP BY product_category
ORDER BY total_quantity_sold DESC
LIMIT 3;

-- C. Total revenue per product category
SELECT
    product_category,
    SUM(price_per_unit * quantity) AS total_revenue
FROM orders
GROUP BY product_category
ORDER BY total_revenue DESC;

-- D. Top 5 customers by total spending
SELECT
    customer_name,
    SUM(price_per_unit * quantity) AS total_spending
FROM orders
GROUP BY customer_name
ORDER BY total_spending DESC
LIMIT 5;

-- E. Order counts and spending for the top 5 customers
SELECT
    customer_name,
    COUNT(*) AS number_of_orders,
    SUM(price_per_unit * quantity) AS total_spending
FROM orders
WHERE customer_name IN (
    'Carol Taylor',
    'Nina Lopez',
    'Daniel Jackson',
    'Carol Lewis',
    'Daniel Young'
)
GROUP BY customer_name
ORDER BY total_spending DESC;

-- Verify the number of orders in each category
SELECT product_category, COUNT(*)
FROM orders
GROUP BY product_category
ORDER BY product_category;
