-- ============================================================
-- Superstore Sales Analysis
-- All queries used in the analysis, in the order I ran them.
-- Database: MySQL 8.0
-- Table: orders (single flat table, Sample Superstore dataset)
-- ============================================================


-- ------------------------------------------------------------
-- 1. Overall performance
-- What's the total revenue, profit, and margin for the business?
-- ------------------------------------------------------------
SELECT 
    SUM(sales) AS total_revenue,
    SUM(profit) AS total_profit,
    ROUND(SUM(profit) / SUM(sales) * 100, 2) AS profit_margin_pct
FROM orders;


-- ------------------------------------------------------------
-- 2. Category-wise breakdown
-- Which category brings in the most revenue, and is that revenue
-- actually profitable?
-- ------------------------------------------------------------
SELECT 
    category, 
    SUM(sales) AS total_revenue,
    SUM(profit) AS total_profit,
    ROUND(SUM(profit) / SUM(sales) * 100, 2) AS profit_margin_pct
FROM orders 
GROUP BY category
ORDER BY total_revenue DESC;


-- ------------------------------------------------------------
-- 3a. Discount vs. margin by category
-- Hypothesis: categories with heavier discounting have lower margins.
-- ------------------------------------------------------------
SELECT 
    category,
    ROUND(AVG(discount) * 100, 2) AS avg_discount_pct,
    ROUND(SUM(profit) / SUM(sales) * 100, 2) AS profit_margin_pct
FROM orders
GROUP BY category
ORDER BY avg_discount_pct DESC;


-- ------------------------------------------------------------
-- 3b. Furniture sub-category drill-down
-- Furniture has the lowest margin overall -- which sub-category
-- inside Furniture is actually causing that?
-- ------------------------------------------------------------
SELECT 
    sub_category,
    ROUND(AVG(discount) * 100, 2) AS avg_discount_pct,
    SUM(sales) AS total_revenue,
    SUM(profit) AS total_profit,
    ROUND(SUM(profit) / SUM(sales) * 100, 2) AS profit_margin_pct
FROM orders
WHERE category = 'Furniture'
GROUP BY sub_category
ORDER BY profit_margin_pct ASC;


-- ------------------------------------------------------------
-- 4. Region-wise sales
-- Which region generates the most sales overall?
-- ------------------------------------------------------------
SELECT 
    region, 
    SUM(sales) AS total_sales
FROM orders
GROUP BY region
ORDER BY total_sales DESC;


-- ------------------------------------------------------------
-- 5. Monthly sales trend
-- How does revenue move month to month across the full dataset?
-- ------------------------------------------------------------
SELECT 
    DATE_FORMAT(order_date, '%Y-%m') AS months,
    SUM(sales) AS total_sales
FROM orders
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
ORDER BY months ASC;


-- ------------------------------------------------------------
-- 6. Month-over-month growth %
-- Same trend as above, but quantified -- how much did sales
-- grow or shrink compared to the previous month?
-- Uses LAG() to pull the previous month's total into the same row.
-- ------------------------------------------------------------
SELECT 
    DATE_FORMAT(order_date, '%Y-%m') AS months,
    SUM(sales) AS total_sales,
    LAG(SUM(sales)) OVER (ORDER BY DATE_FORMAT(order_date, '%Y-%m')) AS previous_month_sales,
    ROUND(
        (SUM(sales) - LAG(SUM(sales)) OVER (ORDER BY DATE_FORMAT(order_date, '%Y-%m'))) 
        / LAG(SUM(sales)) OVER (ORDER BY DATE_FORMAT(order_date, '%Y-%m')) * 100
    , 2) AS growth_pct
FROM orders
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
ORDER BY months ASC;


-- ------------------------------------------------------------
-- 7a. Top 10 customers by sales
-- ------------------------------------------------------------
SELECT 
    customer_name, 
    SUM(sales) AS total_sales
FROM orders
GROUP BY customer_name
ORDER BY total_sales DESC
LIMIT 10;


-- ------------------------------------------------------------
-- 7b. Top 10 customers by profit
-- Run separately from 7a on purpose -- high sales doesn't always
-- mean high profit, and comparing the two lists shows that.
-- ------------------------------------------------------------
SELECT 
    customer_name, 
    SUM(profit) AS total_profit
FROM orders
GROUP BY customer_name
ORDER BY total_profit DESC
LIMIT 10;


-- ------------------------------------------------------------
-- Bonus: region-wise order ranking (window function practice)
-- Ranks every order within its own region by sales value.
-- Not part of the core findings, but useful for pulling out the
-- single biggest order per region if needed later.
-- ------------------------------------------------------------
SELECT 
    region, 
    order_id, 
    sales,
    RANK() OVER (PARTITION BY region ORDER BY sales DESC) AS rnk
FROM orders;
