/*
===============================================================================
Analytics Queries
===============================================================================
Script Purpose:
    15 business analysis queries against the Gold layer views only:
    5 Profitability | 5 Customer Behavior | 5 Sales Trends
===============================================================================
*/

USE SuperstoreDW;
GO

-- =============================================================================
-- Profitability
-- =============================================================================

-- 1.1 Profit margin by Category and Sub-Category
SELECT
    dp.category,
    dp.sub_category,
    SUM(f.sales)                                   AS total_sales,
    SUM(f.profit)                                  AS total_profit,
    CAST(SUM(f.profit) * 100.0 / NULLIF(SUM(f.sales), 0) AS DECIMAL(9,2)) AS profit_margin_pct
FROM gold.fact_sales f
JOIN gold.dim_product dp ON dp.product_key = f.product_key
GROUP BY dp.category, dp.sub_category
ORDER BY profit_margin_pct DESC;
GO

-- 1.2 Top 10 loss-making products (net negative profit)
SELECT TOP 10
    dp.product_id,
    dp.product_name,
    dp.category,
    SUM(f.profit)       AS total_profit,
    SUM(f.sales)        AS total_sales,
    COUNT(*)            AS orders_count
FROM gold.fact_sales f
JOIN gold.dim_product dp ON dp.product_key = f.product_key
GROUP BY dp.product_id, dp.product_name, dp.category
HAVING SUM(f.profit) < 0
ORDER BY total_profit ASC;
GO

-- 1.3 Discount level vs. average profit margin (does discounting kill margin?)
SELECT
    CASE
        WHEN f.discount = 0            THEN '0% (No Discount)'
        WHEN f.discount <= 0.20        THEN '1-20%'
        WHEN f.discount <= 0.40        THEN '21-40%'
        WHEN f.discount <= 0.60        THEN '41-60%'
        ELSE '61%+'
    END                                             AS discount_band,
    COUNT(*)                                        AS line_items,
    CAST(AVG(f.profit_margin) * 100 AS DECIMAL(9,2)) AS avg_profit_margin_pct,
    SUM(f.profit)                                   AS total_profit
FROM gold.fact_sales f
GROUP BY
    CASE
        WHEN f.discount = 0            THEN '0% (No Discount)'
        WHEN f.discount <= 0.20        THEN '1-20%'
        WHEN f.discount <= 0.40        THEN '21-40%'
        WHEN f.discount <= 0.60        THEN '41-60%'
        ELSE '61%+'
    END
ORDER BY avg_profit_margin_pct DESC;
GO

-- 1.4 Top 10 most profitable products
SELECT TOP 10
    dp.product_id,
    dp.product_name,
    dp.category,
    SUM(f.profit)   AS total_profit,
    SUM(f.sales)    AS total_sales
FROM gold.fact_sales f
JOIN gold.dim_product dp ON dp.product_key = f.product_key
GROUP BY dp.product_id, dp.product_name, dp.category
ORDER BY total_profit DESC;
GO

-- 1.5 Profitability by Ship Mode
SELECT
    f.ship_mode,
    COUNT(*)                                       AS line_items,
    SUM(f.sales)                                   AS total_sales,
    SUM(f.profit)                                  AS total_profit,
    CAST(AVG(f.shipping_delay_days) AS DECIMAL(9,2)) AS avg_shipping_delay_days
FROM gold.fact_sales f
GROUP BY f.ship_mode
ORDER BY total_profit DESC;
GO


-- =============================================================================
-- Customer Behavior
-- =============================================================================

-- 2.1 Top 10 customers by total revenue
SELECT TOP 10
    dc.customer_id,
    dc.customer_name,
    dc.segment,
    SUM(f.sales)    AS total_sales,
    SUM(f.profit)   AS total_profit,
    COUNT(DISTINCT f.order_id) AS total_orders
FROM gold.fact_sales f
JOIN gold.dim_customer dc ON dc.customer_key = f.customer_key
GROUP BY dc.customer_id, dc.customer_name, dc.segment
ORDER BY total_sales DESC;
GO

-- 2.2 Revenue and profit contribution by Segment
SELECT
    dc.segment,
    COUNT(DISTINCT dc.customer_id)             AS customer_count,
    SUM(f.sales)                               AS total_sales,
    SUM(f.profit)                              AS total_profit,
    CAST(SUM(f.sales) * 100.0 / SUM(SUM(f.sales)) OVER () AS DECIMAL(9,2)) AS pct_of_total_sales
FROM gold.fact_sales f
JOIN gold.dim_customer dc ON dc.customer_key = f.customer_key
GROUP BY dc.segment
ORDER BY total_sales DESC;
GO

-- 2.3 Repeat customers vs. one-time customers
SELECT
    CASE WHEN order_count = 1 THEN 'One-Time Customer' ELSE 'Repeat Customer' END AS customer_type,
    COUNT(*)            AS customer_count,
    SUM(customer_sales) AS total_sales
FROM (
    SELECT
        dc.customer_id,
        COUNT(DISTINCT f.order_id) AS order_count,
        SUM(f.sales)               AS customer_sales
    FROM gold.fact_sales f
    JOIN gold.dim_customer dc ON dc.customer_key = f.customer_key
    GROUP BY dc.customer_id
) x
GROUP BY CASE WHEN order_count = 1 THEN 'One-Time Customer' ELSE 'Repeat Customer' END;
GO

-- 2.4 Average order value (AOV) by Segment
SELECT
    dc.segment,
    COUNT(DISTINCT f.order_id)                                   AS total_orders,
    SUM(f.sales)                                                 AS total_sales,
    CAST(SUM(f.sales) / NULLIF(COUNT(DISTINCT f.order_id), 0) AS DECIMAL(18,2)) AS avg_order_value
FROM gold.fact_sales f
JOIN gold.dim_customer dc ON dc.customer_key = f.customer_key
GROUP BY dc.segment
ORDER BY avg_order_value DESC;
GO

-- 2.5 Customer lifetime value ranking with percentile tier
SELECT
    dc.customer_id,
    dc.customer_name,
    dc.segment,
    SUM(f.sales)  AS lifetime_sales,
    SUM(f.profit) AS lifetime_profit,
    NTILE(4) OVER (ORDER BY SUM(f.sales) DESC) AS value_quartile  -- 1 = top 25% by revenue
FROM gold.fact_sales f
JOIN gold.dim_customer dc ON dc.customer_key = f.customer_key
GROUP BY dc.customer_id, dc.customer_name, dc.segment
ORDER BY lifetime_sales DESC;
GO


-- =============================================================================
-- Sales Trends
-- =============================================================================

-- 3.1 Monthly sales trend across all years
SELECT
    dd.[year],
    dd.[month],
    dd.month_name,
    SUM(f.sales)  AS total_sales,
    SUM(f.profit) AS total_profit
FROM gold.fact_sales f
JOIN gold.dim_date dd ON dd.date_key = f.order_date_key
GROUP BY dd.[year], dd.[month], dd.month_name
ORDER BY dd.[year], dd.[month];
GO

-- 3.2 Year-over-year sales growth
SELECT
    [year],
    total_sales,
    LAG(total_sales) OVER (ORDER BY [year])                       AS prior_year_sales,
    CAST((total_sales - LAG(total_sales) OVER (ORDER BY [year])) * 100.0
         / NULLIF(LAG(total_sales) OVER (ORDER BY [year]), 0) AS DECIMAL(9,2)) AS yoy_growth_pct
FROM (
    SELECT dd.[year], SUM(f.sales) AS total_sales
    FROM gold.fact_sales f
    JOIN gold.dim_date dd ON dd.date_key = f.order_date_key
    GROUP BY dd.[year]
) yearly
ORDER BY [year];
GO

-- 3.3 Seasonality: average sales by calendar month (across all years)
SELECT
    dd.[month],
    dd.month_name,
    AVG(monthly_sales.total_sales) AS avg_monthly_sales_across_years
FROM (
    SELECT dd.[year], dd.[month], SUM(f.sales) AS total_sales
    FROM gold.fact_sales f
    JOIN gold.dim_date dd ON dd.date_key = f.order_date_key
    GROUP BY dd.[year], dd.[month]
) monthly_sales
JOIN gold.dim_date dd ON dd.[month] = monthly_sales.[month]
GROUP BY dd.[month], dd.month_name
ORDER BY dd.[month];
GO

-- 3.4 Sales by Ship Mode over time (yearly)
SELECT
    dd.[year],
    f.ship_mode,
    SUM(f.sales)     AS total_sales,
    COUNT(*)         AS line_items
FROM gold.fact_sales f
JOIN gold.dim_date dd ON dd.date_key = f.order_date_key
GROUP BY dd.[year], f.ship_mode
ORDER BY dd.[year], total_sales DESC;
GO

-- 3.5 Category sales trend by year
SELECT
    dd.[year],
    dp.category,
    SUM(f.sales)  AS total_sales,
    SUM(f.profit) AS total_profit
FROM gold.fact_sales f
JOIN gold.dim_date dd    ON dd.date_key = f.order_date_key
JOIN gold.dim_product dp ON dp.product_key = f.product_key
GROUP BY dd.[year], dp.category
ORDER BY dd.[year], total_sales DESC;
GO
