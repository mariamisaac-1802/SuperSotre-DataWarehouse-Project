/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL process to populate
    'silver.sales_order' from 'bronze.sales_order'.
    Actions Performed:
        - Truncates silver.sales_order before loading (full refresh).
        - Takes the latest version of each Bronze record (highest bronze_id
          per row_id) — Bronze is append-only, so a natural key can have
          more than one historical row in it.
        - Cleanses (trims text) and enriches (derived columns) the data.
        - Filters out rows that would violate a Silver business rule instead
          of letting them fail the batch.
    No Fact/Dimension split happens here — Silver stays at line-item grain;
    that modeling is done only by the Gold layer views.

Parameters:
    None.
    This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC silver.load_silver;
===============================================================================
*/

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME;

    BEGIN TRY
        SET @start_time = GETDATE();
        PRINT '================================================';
        PRINT 'Loading Silver Layer';
        PRINT '================================================';

        PRINT '>> Truncating Table: silver.sales_order';
        TRUNCATE TABLE silver.sales_order;

        PRINT '>> Inserting Data Into: silver.sales_order';
        WITH latest_bronze AS (
            SELECT *, ROW_NUMBER() OVER (PARTITION BY row_id ORDER BY bronze_id DESC) AS rn
            FROM bronze.sales_order
        ),
        cleansed AS (
            SELECT
                row_id,
                TRIM(order_id) AS order_id,
                order_date,
                ship_date,
                TRIM(ship_mode) AS ship_mode,
                TRIM(customer_id) AS customer_id,
                TRIM(customer_name) AS customer_name,
                TRIM(segment) AS segment,
                TRIM(country) AS country,
                TRIM(city) AS city,
                TRIM(state) AS state,
                postal_code,
                TRIM(region) AS region,
                TRIM(product_id) AS product_id,
                TRIM(category) AS category,
                TRIM(sub_category) AS sub_category,
                TRIM(product_name) AS product_name,
                sales,
                quantity,
                discount,
                profit,
                CASE WHEN sales <> 0 THEN CAST(profit AS DECIMAL(18,4)) / sales ELSE NULL END AS profit_margin,
                YEAR(order_date) AS order_year,
                MONTH(order_date) AS order_month,
                DATEDIFF(DAY, order_date, ship_date) AS shipping_delay_days,
                CASE WHEN profit < 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS is_loss_making
            FROM latest_bronze
            WHERE rn = 1
              AND row_id IS NOT NULL
              AND order_id IS NOT NULL
              AND customer_id IS NOT NULL
              AND customer_name IS NOT NULL
              AND product_id IS NOT NULL
              AND product_name IS NOT NULL
              AND order_date IS NOT NULL
              AND ship_date IS NOT NULL
              AND ship_date >= order_date                                                    -- business rule
              AND ship_mode IN ('Standard Class', 'Second Class', 'First Class', 'Same Day')  -- business rule
              AND segment IN ('Consumer', 'Corporate', 'Home Office')                         -- business rule
              AND category IN ('Office Supplies', 'Furniture', 'Technology')                  -- business rule
              AND quantity > 0                                                                -- business rule
              AND discount BETWEEN 0 AND 1                                                    -- business rule
              AND sales > 0                                                                   -- business rule
              AND city IS NOT NULL AND state IS NOT NULL AND country IS NOT NULL AND region IS NOT NULL
        )
        INSERT INTO silver.sales_order (
            row_id, order_id, order_date, ship_date, ship_mode, customer_id, customer_name,
            segment, country, city, state, postal_code, region, product_id, category,
            sub_category, product_name, sales, quantity, discount, profit, profit_margin,
            order_year, order_month, shipping_delay_days, is_loss_making
        )
        SELECT
            row_id, order_id, order_date, ship_date, ship_mode, customer_id, customer_name,
            segment, country, city, state, postal_code, region, product_id, category,
            sub_category, product_name, sales, quantity, discount, profit, profit_margin,
            order_year, order_month, shipping_delay_days, is_loss_making
        FROM cleansed;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '================================================';
        PRINT 'Loading Silver Layer is Completed';
        PRINT '================================================';
    END TRY
    BEGIN CATCH
        PRINT '==========================================';
        PRINT 'ERROR OCCURRED DURING LOADING SILVER LAYER';
        PRINT 'Error Message ' + ERROR_MESSAGE();
        PRINT 'Error Number  ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT 'Error State   ' + CAST(ERROR_STATE() AS NVARCHAR);
        PRINT '==========================================';
    END CATCH
END
GO
