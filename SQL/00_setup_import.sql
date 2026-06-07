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
