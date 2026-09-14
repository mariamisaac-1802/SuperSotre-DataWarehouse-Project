/*
===============================================================================
DDL Script: Create Gold Views
===============================================================================
Script Purpose:
    This script creates views for the Gold layer in the data warehouse.
    The Gold layer represents the final dimension and fact views (Star Schema).
    Silver is a single flat, cleansed table at line-item grain
    (silver.sales_order) — the Fact/Dimension split happens ONLY here, by
    projecting distinct attribute sets out of that table into dimension
    views and joining back into a fact view.

Usage:
    - These views can be queried directly for analytics and reporting.
===============================================================================
*/

-- =============================================================================
-- Create Dimension: gold.dim_customer
-- =============================================================================
IF OBJECT_ID('gold.dim_customer', 'V') IS NOT NULL
    DROP VIEW gold.dim_customer;
GO

CREATE VIEW gold.dim_customer AS
SELECT
    ROW_NUMBER() OVER (ORDER BY customer_id) AS customer_key,  -- Surrogate key
    customer_id,
    customer_name,
    segment
FROM (SELECT DISTINCT customer_id, customer_name, segment FROM silver.sales_order) c;
GO

-- =============================================================================
-- Create Dimension: gold.dim_product
-- =============================================================================
IF OBJECT_ID('gold.dim_product', 'V') IS NOT NULL
    DROP VIEW gold.dim_product;
GO

CREATE VIEW gold.dim_product AS
SELECT
    ROW_NUMBER() OVER (ORDER BY product_id) AS product_key,  -- Surrogate key
    product_id,
    category,
    sub_category,
    product_name
FROM (SELECT DISTINCT product_id, category, sub_category, product_name FROM silver.sales_order) p;
GO

-- =============================================================================
-- Create Dimension: gold.dim_location
-- =============================================================================
IF OBJECT_ID('gold.dim_location', 'V') IS NOT NULL
    DROP VIEW gold.dim_location;
GO

CREATE VIEW gold.dim_location AS
SELECT
    ROW_NUMBER() OVER (ORDER BY country, state, city, postal_code) AS location_key,  -- Surrogate key
    country,
    state,
    city,
    postal_code,
    region
FROM (SELECT DISTINCT country, state, city, postal_code, region FROM silver.sales_order) l;
GO

-- =============================================================================
-- Create Dimension: gold.dim_date
-- =============================================================================
IF OBJECT_ID('gold.dim_date', 'V') IS NOT NULL
    DROP VIEW gold.dim_date;
GO

CREATE VIEW gold.dim_date AS
SELECT
    CONVERT(INT, FORMAT(d.order_date, 'yyyyMMdd')) AS date_key,  -- Surrogate key
    d.order_date                                   AS full_date,
    YEAR(d.order_date)                             AS [year],
    DATEPART(QUARTER, d.order_date)                AS [quarter],
    MONTH(d.order_date)                            AS [month],
    DATENAME(MONTH, d.order_date)                  AS month_name,
    DAY(d.order_date)                              AS [day],
    DATENAME(WEEKDAY, d.order_date)                AS day_name,
    CASE WHEN DATEPART(WEEKDAY, d.order_date) IN (1, 7) THEN 1 ELSE 0 END AS is_weekend
FROM (SELECT DISTINCT order_date FROM silver.sales_order) d;
GO

-- =============================================================================
-- Create Fact Table: gold.fact_sales
-- =============================================================================
IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
    DROP VIEW gold.fact_sales;
GO

CREATE VIEW gold.fact_sales AS
SELECT
    so.row_id                                      AS sales_key,      -- degenerate PK
    so.order_id                                    AS order_number,   -- degenerate dimension
    so.ship_mode,                                                     -- degenerate dimension
    dc.customer_key,
    dp.product_key,
    dl.location_key,
    CONVERT(INT, FORMAT(so.order_date, 'yyyyMMdd')) AS order_date_key,
    CONVERT(INT, FORMAT(so.ship_date, 'yyyyMMdd'))  AS ship_date_key,
    so.sales,
    so.quantity,
    so.discount,
    so.profit,
    so.profit_margin,
    so.shipping_delay_days,
    so.is_loss_making
FROM silver.sales_order so
LEFT JOIN gold.dim_customer dc ON dc.customer_id = so.customer_id
LEFT JOIN gold.dim_product  dp ON dp.product_id  = so.product_id
LEFT JOIN gold.dim_location dl ON dl.country = so.country
                               AND dl.state = so.state
                               AND dl.city = so.city
                               AND ISNULL(dl.postal_code, -1) = ISNULL(so.postal_code, -1);
GO
