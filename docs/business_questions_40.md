# Campfly Sales Analytics — 40 MySQL Business Questions

This markdown file is arranged as a manager-facing SQL analysis document. It first creates the database/table and imports the CSV, then answers 40 selected questions using MySQL.

> **Scope note:** The source question document has more than 40 questions. Because the requested deliverable is exactly **40 questions**, this file uses **8 manager-priority sections × 5 questions each**: Revenue, Customer, Product, Sales Channel, Warehouse, Shipping & Operations, Regional, and Time-Series.

> **Profit logic note:** The CSV field named `Total Unit Cost` behaves like a unit-level cost, so this project calculates `profit = total_revenue - (unit_cost * order_quantity)`. The setup view also includes `profit_using_pdf_formula` if you need the literal formula `Total Revenue - Total Unit Cost`.

---

## How each section should be arranged

Use this structure for every section in your final analysis report:

1. **Section heading** — example: `## 1. Revenue & Sales Performance`.
2. **Manager question** — write the exact business question.
3. **Why this matters** — one or two sentences explaining the management decision it supports.
4. **SQL query** — paste the MySQL query in a fenced SQL code block.
5. **Result placeholder** — add a small table after running the query.
6. **Manager takeaway** — explain the action suggested by the result.

Recommended format:

````markdown
### Q1. What is the total revenue generated?

**Why this matters:** Revenue is the first indicator of business scale and sales momentum.

```sql
SELECT ...;
```

**Result:**

| Metric | Value |
|---|---:|
| Total Revenue | ... |

**Manager takeaway:** ...
````

---

## 0. Database Setup + CSV Import

Run this first. It creates the database, imports the CSV, and builds a clean analysis view.

```sql
-- ============================================================
-- Campfly Sales Analytics Project
-- MySQL setup + CSV import script
-- ============================================================
-- Requirements:
--   MySQL 8.0+
--   Client must allow LOCAL INFILE.
--   Example run from the repository root:
--     mysql --local-infile=1 -u root -p < sql/00_setup_import.sql
--
-- If MySQL blocks local infile, run this once as an admin user:
--     SET GLOBAL local_infile = 1;
-- Then reconnect using --local-infile=1.
-- ============================================================

CREATE DATABASE IF NOT EXISTS campfly_sales_analytics;
USE campfly_sales_analytics;

DROP VIEW IF EXISTS vw_sales_orders;
DROP TABLE IF EXISTS sales_orders;

CREATE TABLE sales_orders (
    order_number VARCHAR(30) NOT NULL,
    order_date DATE NOT NULL,
    ship_date DATE NOT NULL,
    customer_name_index INT NOT NULL,
    channel VARCHAR(50) NOT NULL,
    currency_code VARCHAR(10) NOT NULL,
    warehouse_code VARCHAR(20) NOT NULL,
    delivery_region_index INT NOT NULL,
    product_description_index INT NOT NULL,
    order_quantity INT NOT NULL,
    unit_price DECIMAL(14, 2) NOT NULL,
    unit_cost DECIMAL(14, 3) NOT NULL,
    total_revenue DECIMAL(16, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (order_number)
);

-- ------------------------------------------------------------
-- Import the CSV file.
-- Keep this script path as-is if you run the command from repo root.
-- If using MySQL Workbench, replace 'data/sales_orders.csv' with the
-- absolute path of the CSV file on your computer.
-- ------------------------------------------------------------
LOAD DATA LOCAL INFILE 'data/sales_orders.csv'
INTO TABLE sales_orders
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(@order_number, @order_date, @ship_date, @customer_name_index, @channel, @currency_code,
 @warehouse_code, @delivery_region_index, @product_description_index, @order_quantity,
 @unit_price, @unit_cost, @total_revenue)
SET
    order_number = TRIM(@order_number),
    order_date = STR_TO_DATE(TRIM(@order_date), '%e-%b-%y'),
    ship_date = STR_TO_DATE(TRIM(@ship_date), '%e-%b-%y'),
    customer_name_index = CAST(NULLIF(TRIM(@customer_name_index), '') AS UNSIGNED),
    channel = TRIM(@channel),
    currency_code = TRIM(@currency_code),
    warehouse_code = TRIM(@warehouse_code),
    delivery_region_index = CAST(NULLIF(TRIM(@delivery_region_index), '') AS UNSIGNED),
    product_description_index = CAST(NULLIF(TRIM(@product_description_index), '') AS UNSIGNED),
    order_quantity = CAST(NULLIF(TRIM(@order_quantity), '') AS UNSIGNED),
    unit_price = CAST(NULLIF(TRIM(@unit_price), '') AS DECIMAL(14, 2)),
    unit_cost = CAST(NULLIF(TRIM(@unit_cost), '') AS DECIMAL(14, 3)),
    total_revenue = CAST(NULLIF(TRIM(@total_revenue), '') AS DECIMAL(16, 2));

-- Helpful indexes for analysis queries.
CREATE INDEX idx_sales_order_date ON sales_orders(order_date);
CREATE INDEX idx_sales_ship_date ON sales_orders(ship_date);
CREATE INDEX idx_sales_customer ON sales_orders(customer_name_index);
CREATE INDEX idx_sales_product ON sales_orders(product_description_index);
CREATE INDEX idx_sales_region ON sales_orders(delivery_region_index);
CREATE INDEX idx_sales_channel ON sales_orders(channel);
CREATE INDEX idx_sales_warehouse ON sales_orders(warehouse_code);
CREATE INDEX idx_sales_currency ON sales_orders(currency_code);

-- ------------------------------------------------------------
-- Analysis view.
-- Important business logic note:
-- The CSV field named "Total Unit Cost" behaves like cost per unit.
-- Therefore this project uses:
--     total_cost = unit_cost * order_quantity
--     profit     = total_revenue - total_cost
-- If your evaluator wants the literal PDF formula instead, use
-- profit_using_pdf_formula in the view below.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_sales_orders AS
SELECT
    order_number,
    order_date,
    ship_date,
    customer_name_index AS customer_id,
    channel,
    currency_code,
    warehouse_code,
    delivery_region_index AS region_id,
    product_description_index AS product_id,
    order_quantity,
    unit_price,
    unit_cost,
    total_revenue,
    ROUND(unit_cost * order_quantity, 2) AS total_cost,
    ROUND(total_revenue - (unit_cost * order_quantity), 2) AS profit,
    ROUND(total_revenue - unit_cost, 2) AS profit_using_pdf_formula,
    ROUND((total_revenue - (unit_cost * order_quantity)) / NULLIF(total_revenue, 0), 4) AS profit_margin,
    DATEDIFF(ship_date, order_date) AS shipping_delay_days,
    CAST(DATE_FORMAT(order_date, '%Y-%m-01') AS DATE) AS month_start,
    YEAR(order_date) AS order_year,
    QUARTER(order_date) AS order_quarter
FROM sales_orders;

-- Quick validation checks.
SELECT COUNT(*) AS imported_rows FROM sales_orders;
SELECT MIN(order_date) AS first_order_date, MAX(order_date) AS last_order_date FROM sales_orders;
SELECT * FROM vw_sales_orders LIMIT 5;
```

---

## 1–8. Business Questions SQL

The following SQL contains the 40 selected business questions.

```sql
-- ============================================================
-- Campfly Sales Analytics Project
-- 40 Manager-Level MySQL Queries
-- ============================================================
-- Run sql/00_setup_import.sql first.
-- These queries use vw_sales_orders.
-- MySQL version: 8.0+
-- ============================================================

USE campfly_sales_analytics;

-- ============================================================
-- SECTION 1: Revenue & Sales Performance
-- ============================================================

-- Q1. What is the total revenue generated?
SELECT
    ROUND(SUM(total_revenue), 2) AS total_revenue
FROM vw_sales_orders;

-- Q2. How many orders were placed?
SELECT
    COUNT(DISTINCT order_number) AS total_orders
FROM vw_sales_orders;

-- Q3. What is the average order value?
SELECT
    ROUND(SUM(total_revenue) / NULLIF(COUNT(DISTINCT order_number), 0), 2) AS average_order_value
FROM vw_sales_orders;

-- Q4. What is the total profit generated?
SELECT
    ROUND(SUM(profit), 2) AS total_profit
FROM vw_sales_orders;

-- Q5. What is the overall profit margin?
SELECT
    ROUND(100 * SUM(profit) / NULLIF(SUM(total_revenue), 0), 2) AS overall_profit_margin_pct
FROM vw_sales_orders;

-- ============================================================
-- SECTION 2: Customer Analytics
-- ============================================================

-- Q6. Who are the top 10 customers by revenue?
SELECT
    customer_id,
    COUNT(DISTINCT order_number) AS total_orders,
    ROUND(SUM(total_revenue), 2) AS total_revenue
FROM vw_sales_orders
GROUP BY customer_id
ORDER BY total_revenue DESC
LIMIT 10;

-- Q7. Who are the top 10 customers by profit?
SELECT
    customer_id,
    COUNT(DISTINCT order_number) AS total_orders,
    ROUND(SUM(profit), 2) AS total_profit,
    ROUND(100 * SUM(profit) / NULLIF(SUM(total_revenue), 0), 2) AS profit_margin_pct
FROM vw_sales_orders
GROUP BY customer_id
ORDER BY total_profit DESC
LIMIT 10;

-- Q8. What is the Customer Lifetime Value for each customer?
SELECT
    customer_id,
    COUNT(DISTINCT order_number) AS lifetime_orders,
    ROUND(SUM(total_revenue), 2) AS revenue_clv,
    ROUND(SUM(profit), 2) AS profit_clv,
    ROUND(SUM(total_revenue) / NULLIF(COUNT(DISTINCT order_number), 0), 2) AS avg_order_value
FROM vw_sales_orders
GROUP BY customer_id
ORDER BY revenue_clv DESC;

-- Q9. Which customers generate high revenue but low profit?
WITH customer_metrics AS (
    SELECT
        customer_id,
        COUNT(DISTINCT order_number) AS total_orders,
        SUM(total_revenue) AS revenue,
        SUM(profit) AS profit,
        SUM(profit) / NULLIF(SUM(total_revenue), 0) AS profit_margin
    FROM vw_sales_orders
    GROUP BY customer_id
), ranked_customers AS (
    SELECT
        customer_metrics.*,
        NTILE(4) OVER (ORDER BY revenue DESC) AS revenue_quartile,
        NTILE(4) OVER (ORDER BY profit_margin ASC) AS low_margin_quartile
    FROM customer_metrics
)
SELECT
    customer_id,
    total_orders,
    ROUND(revenue, 2) AS total_revenue,
    ROUND(profit, 2) AS total_profit,
    ROUND(100 * profit_margin, 2) AS profit_margin_pct
FROM ranked_customers
WHERE revenue_quartile = 1
  AND low_margin_quartile = 1
ORDER BY total_revenue DESC;

-- Q10. Which customers have not ordered recently?
WITH analysis_date AS (
    SELECT MAX(order_date) AS latest_order_date
    FROM vw_sales_orders
), customer_recency AS (
    SELECT
        customer_id,
        MAX(order_date) AS last_order_date,
        COUNT(DISTINCT order_number) AS total_orders,
        SUM(total_revenue) AS lifetime_revenue
    FROM vw_sales_orders
    GROUP BY customer_id
)
SELECT
    c.customer_id,
    c.last_order_date,
    DATEDIFF(a.latest_order_date, c.last_order_date) AS days_since_last_order,
    c.total_orders,
    ROUND(c.lifetime_revenue, 2) AS lifetime_revenue
FROM customer_recency c
CROSS JOIN analysis_date a
ORDER BY days_since_last_order DESC, lifetime_revenue DESC
LIMIT 10;

-- ============================================================
-- SECTION 3: Product Analytics
-- ============================================================

-- Q11. Which products generate the highest revenue?
SELECT
    product_id,
    COUNT(DISTINCT order_number) AS total_orders,
    SUM(order_quantity) AS total_quantity_sold,
    ROUND(SUM(total_revenue), 2) AS total_revenue
FROM vw_sales_orders
GROUP BY product_id
ORDER BY total_revenue DESC
LIMIT 10;

-- Q12. Which products generate the highest profit?
SELECT
    product_id,
    COUNT(DISTINCT order_number) AS total_orders,
    SUM(order_quantity) AS total_quantity_sold,
    ROUND(SUM(profit), 2) AS total_profit,
    ROUND(100 * SUM(profit) / NULLIF(SUM(total_revenue), 0), 2) AS profit_margin_pct
FROM vw_sales_orders
GROUP BY product_id
ORDER BY total_profit DESC
LIMIT 10;

-- Q13. Which products sell the highest quantity?
SELECT
    product_id,
    SUM(order_quantity) AS total_quantity_sold,
    COUNT(DISTINCT order_number) AS total_orders,
    ROUND(SUM(total_revenue), 2) AS total_revenue
FROM vw_sales_orders
GROUP BY product_id
ORDER BY total_quantity_sold DESC
LIMIT 10;

-- Q14. Which products have the highest profit margin?
SELECT
    product_id,
    COUNT(DISTINCT order_number) AS total_orders,
    ROUND(SUM(total_revenue), 2) AS total_revenue,
    ROUND(SUM(profit), 2) AS total_profit,
    ROUND(100 * SUM(profit) / NULLIF(SUM(total_revenue), 0), 2) AS profit_margin_pct
FROM vw_sales_orders
GROUP BY product_id
HAVING SUM(total_revenue) > 0
ORDER BY profit_margin_pct DESC
LIMIT 10;

-- Q15. Which products have the lowest profit margin?
SELECT
    product_id,
    COUNT(DISTINCT order_number) AS total_orders,
    ROUND(SUM(total_revenue), 2) AS total_revenue,
    ROUND(SUM(profit), 2) AS total_profit,
    ROUND(100 * SUM(profit) / NULLIF(SUM(total_revenue), 0), 2) AS profit_margin_pct
FROM vw_sales_orders
GROUP BY product_id
HAVING SUM(total_revenue) > 0
ORDER BY profit_margin_pct ASC
LIMIT 10;

-- ============================================================
-- SECTION 4: Sales Channel Analysis
-- ============================================================

-- Q16. Which sales channel generates the most revenue?
SELECT
    channel,
    COUNT(DISTINCT order_number) AS total_orders,
    ROUND(SUM(total_revenue), 2) AS total_revenue
FROM vw_sales_orders
GROUP BY channel
ORDER BY total_revenue DESC;

-- Q17. Which sales channel generates the most profit?
SELECT
    channel,
    COUNT(DISTINCT order_number) AS total_orders,
    ROUND(SUM(profit), 2) AS total_profit
FROM vw_sales_orders
GROUP BY channel
ORDER BY total_profit DESC;

-- Q18. Which channel has the highest average order value?
SELECT
    channel,
    COUNT(DISTINCT order_number) AS total_orders,
    ROUND(SUM(total_revenue) / NULLIF(COUNT(DISTINCT order_number), 0), 2) AS average_order_value
FROM vw_sales_orders
GROUP BY channel
ORDER BY average_order_value DESC;

-- Q19. Which channel has the best profit margin?
SELECT
    channel,
    ROUND(SUM(total_revenue), 2) AS total_revenue,
    ROUND(SUM(profit), 2) AS total_profit,
    ROUND(100 * SUM(profit) / NULLIF(SUM(total_revenue), 0), 2) AS profit_margin_pct
FROM vw_sales_orders
GROUP BY channel
ORDER BY profit_margin_pct DESC;

-- Q20. What percentage of total sales comes from each channel?
WITH channel_sales AS (
    SELECT
        channel,
        SUM(total_revenue) AS revenue
    FROM vw_sales_orders
    GROUP BY channel
)
SELECT
    channel,
    ROUND(revenue, 2) AS total_revenue,
    ROUND(100 * revenue / NULLIF(SUM(revenue) OVER (), 0), 2) AS revenue_contribution_pct
FROM channel_sales
ORDER BY revenue_contribution_pct DESC;

-- ============================================================
-- SECTION 5: Warehouse Performance
-- ============================================================

-- Q21. Which warehouse processes the most orders?
SELECT
    warehouse_code,
    COUNT(DISTINCT order_number) AS total_orders
FROM vw_sales_orders
GROUP BY warehouse_code
ORDER BY total_orders DESC;

-- Q22. Which warehouse generates the highest revenue?
SELECT
    warehouse_code,
    COUNT(DISTINCT order_number) AS total_orders,
    ROUND(SUM(total_revenue), 2) AS total_revenue
FROM vw_sales_orders
GROUP BY warehouse_code
ORDER BY total_revenue DESC;

-- Q23. Which warehouse generates the highest profit?
SELECT
    warehouse_code,
    COUNT(DISTINCT order_number) AS total_orders,
    ROUND(SUM(profit), 2) AS total_profit,
    ROUND(100 * SUM(profit) / NULLIF(SUM(total_revenue), 0), 2) AS profit_margin_pct
FROM vw_sales_orders
GROUP BY warehouse_code
ORDER BY total_profit DESC;

-- Q24. What is the average shipping time for each warehouse?
SELECT
    warehouse_code,
    COUNT(DISTINCT order_number) AS total_orders,
    ROUND(AVG(shipping_delay_days), 2) AS avg_shipping_delay_days
FROM vw_sales_orders
GROUP BY warehouse_code
ORDER BY avg_shipping_delay_days DESC;

-- Q25. Which warehouse has the longest shipping delays?
SELECT
    warehouse_code,
    COUNT(DISTINCT order_number) AS total_orders,
    ROUND(AVG(shipping_delay_days), 2) AS avg_shipping_delay_days,
    MAX(shipping_delay_days) AS max_shipping_delay_days
FROM vw_sales_orders
GROUP BY warehouse_code
ORDER BY avg_shipping_delay_days DESC, max_shipping_delay_days DESC
LIMIT 5;

-- ============================================================
-- SECTION 6: Shipping & Operations Analytics
-- ============================================================

-- Q26. What is the average shipping delay across all orders?
SELECT
    ROUND(AVG(shipping_delay_days), 2) AS avg_shipping_delay_days,
    MIN(shipping_delay_days) AS min_shipping_delay_days,
    MAX(shipping_delay_days) AS max_shipping_delay_days
FROM vw_sales_orders;

-- Q27. Which regions experience the longest shipping delays?
SELECT
    region_id,
    COUNT(DISTINCT order_number) AS total_orders,
    ROUND(AVG(shipping_delay_days), 2) AS avg_shipping_delay_days,
    MAX(shipping_delay_days) AS max_shipping_delay_days
FROM vw_sales_orders
GROUP BY region_id
ORDER BY avg_shipping_delay_days DESC, total_orders DESC
LIMIT 10;

-- Q28. Which customers experience the longest shipping delays?
SELECT
    customer_id,
    COUNT(DISTINCT order_number) AS total_orders,
    ROUND(AVG(shipping_delay_days), 2) AS avg_shipping_delay_days,
    MAX(shipping_delay_days) AS max_shipping_delay_days
FROM vw_sales_orders
GROUP BY customer_id
ORDER BY avg_shipping_delay_days DESC, total_orders DESC
LIMIT 10;

-- Q29. How does shipping delay vary by warehouse?
SELECT
    warehouse_code,
    COUNT(DISTINCT order_number) AS total_orders,
    ROUND(AVG(shipping_delay_days), 2) AS avg_shipping_delay_days,
    MIN(shipping_delay_days) AS min_shipping_delay_days,
    MAX(shipping_delay_days) AS max_shipping_delay_days
FROM vw_sales_orders
GROUP BY warehouse_code
ORDER BY avg_shipping_delay_days DESC;

-- Q30. Are shipping delays associated with lower order values?
WITH delay_buckets AS (
    SELECT
        CASE
            WHEN shipping_delay_days <= 3 THEN '0-3 days'
            WHEN shipping_delay_days BETWEEN 4 AND 7 THEN '4-7 days'
            WHEN shipping_delay_days BETWEEN 8 AND 14 THEN '8-14 days'
            ELSE '15+ days'
        END AS delay_bucket,
        CASE
            WHEN shipping_delay_days <= 3 THEN 1
            WHEN shipping_delay_days BETWEEN 4 AND 7 THEN 2
            WHEN shipping_delay_days BETWEEN 8 AND 14 THEN 3
            ELSE 4
        END AS bucket_sort,
        total_revenue
    FROM vw_sales_orders
)
SELECT
    delay_bucket,
    COUNT(*) AS total_orders,
    ROUND(AVG(total_revenue), 2) AS avg_order_value,
    ROUND(SUM(total_revenue), 2) AS total_revenue
FROM delay_buckets
GROUP BY delay_bucket, bucket_sort
ORDER BY bucket_sort;

-- ============================================================
-- SECTION 7: Regional Analysis
-- ============================================================

-- Q31. Which regions generate the highest revenue?
SELECT
    region_id,
    COUNT(DISTINCT order_number) AS total_orders,
    ROUND(SUM(total_revenue), 2) AS total_revenue
FROM vw_sales_orders
GROUP BY region_id
ORDER BY total_revenue DESC
LIMIT 10;

-- Q32. Which regions generate the highest profit?
SELECT
    region_id,
    COUNT(DISTINCT order_number) AS total_orders,
    ROUND(SUM(profit), 2) AS total_profit,
    ROUND(100 * SUM(profit) / NULLIF(SUM(total_revenue), 0), 2) AS profit_margin_pct
FROM vw_sales_orders
GROUP BY region_id
ORDER BY total_profit DESC
LIMIT 10;

-- Q33. Which regions place the most orders?
SELECT
    region_id,
    COUNT(DISTINCT order_number) AS total_orders,
    ROUND(SUM(total_revenue), 2) AS total_revenue
FROM vw_sales_orders
GROUP BY region_id
ORDER BY total_orders DESC, total_revenue DESC
LIMIT 10;

-- Q34. Which regions have the highest average order value?
SELECT
    region_id,
    COUNT(DISTINCT order_number) AS total_orders,
    ROUND(SUM(total_revenue) / NULLIF(COUNT(DISTINCT order_number), 0), 2) AS average_order_value
FROM vw_sales_orders
GROUP BY region_id
ORDER BY average_order_value DESC
LIMIT 10;

-- Q35. Which regions have the highest profit margins?
SELECT
    region_id,
    COUNT(DISTINCT order_number) AS total_orders,
    ROUND(SUM(total_revenue), 2) AS total_revenue,
    ROUND(SUM(profit), 2) AS total_profit,
    ROUND(100 * SUM(profit) / NULLIF(SUM(total_revenue), 0), 2) AS profit_margin_pct
FROM vw_sales_orders
GROUP BY region_id
HAVING SUM(total_revenue) > 0
ORDER BY profit_margin_pct DESC
LIMIT 10;

-- ============================================================
-- SECTION 8: Time-Series Analysis
-- ============================================================

-- Q36. How does monthly revenue change over time?
SELECT
    DATE_FORMAT(month_start, '%Y-%m') AS sales_month,
    COUNT(DISTINCT order_number) AS total_orders,
    ROUND(SUM(total_revenue), 2) AS monthly_revenue
FROM vw_sales_orders
GROUP BY month_start
ORDER BY month_start;

-- Q37. How does monthly profit change over time?
SELECT
    DATE_FORMAT(month_start, '%Y-%m') AS sales_month,
    COUNT(DISTINCT order_number) AS total_orders,
    ROUND(SUM(profit), 2) AS monthly_profit,
    ROUND(100 * SUM(profit) / NULLIF(SUM(total_revenue), 0), 2) AS monthly_profit_margin_pct
FROM vw_sales_orders
GROUP BY month_start
ORDER BY month_start;

-- Q38. Which month generated the highest revenue?
SELECT
    DATE_FORMAT(month_start, '%Y-%m') AS sales_month,
    COUNT(DISTINCT order_number) AS total_orders,
    ROUND(SUM(total_revenue), 2) AS monthly_revenue
FROM vw_sales_orders
GROUP BY month_start
ORDER BY monthly_revenue DESC
LIMIT 1;

-- Q39. What is the Month-over-Month revenue growth?
WITH monthly_revenue AS (
    SELECT
        month_start,
        SUM(total_revenue) AS revenue
    FROM vw_sales_orders
    GROUP BY month_start
), revenue_with_lag AS (
    SELECT
        month_start,
        revenue,
        LAG(revenue) OVER (ORDER BY month_start) AS previous_month_revenue
    FROM monthly_revenue
)
SELECT
    DATE_FORMAT(month_start, '%Y-%m') AS sales_month,
    ROUND(revenue, 2) AS monthly_revenue,
    ROUND(previous_month_revenue, 2) AS previous_month_revenue,
    ROUND(100 * (revenue - previous_month_revenue) / NULLIF(previous_month_revenue, 0), 2) AS mom_revenue_growth_pct
FROM revenue_with_lag
ORDER BY month_start;

-- Q40. Calculate cumulative revenue over time.
WITH monthly_revenue AS (
    SELECT
        month_start,
        SUM(total_revenue) AS revenue
    FROM vw_sales_orders
    GROUP BY month_start
)
SELECT
    DATE_FORMAT(month_start, '%Y-%m') AS sales_month,
    ROUND(revenue, 2) AS monthly_revenue,
    ROUND(SUM(revenue) OVER (ORDER BY month_start), 2) AS cumulative_revenue
FROM monthly_revenue
ORDER BY month_start;
```
