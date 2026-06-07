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
