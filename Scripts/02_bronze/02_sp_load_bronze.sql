/*
===============================================================================
Stored Procedure: Load Bronze Layer (Staging -> Bronze)
===============================================================================
Script Purpose:
    This stored procedure performs an incremental load from 'staging' into
    'bronze.sales_order'.
    Actions Performed:
        - Inserts rows from staging that don't already exist in bronze
          (compared column-by-column via EXCEPT), so re-running a load with
          unchanged data adds nothing. Bronze is never truncated, and rows
          whose values changed since the last load land as a new bronze_id
          rather than overwriting the old one, preserving load history.

Parameters:
    None.
    This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC bronze.load_bronze;
===============================================================================
*/

USE SuperstoreDW;
GO

CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME;

    BEGIN TRY
        SET @start_time = GETDATE();
        PRINT '================================================';
        PRINT 'Loading Bronze Layer';
        PRINT '================================================';

        PRINT '>> Merging Data Into: bronze.sales_order';

        INSERT INTO bronze.sales_order (
            row_id,
            order_id,
            order_date,
            ship_date,
            ship_mode,
            customer_id,
            customer_name,
            segment,
            country,
            city,
            state,
            postal_code,
            region,
            product_id,
            category,
            sub_category,
            product_name,
            sales,
            quantity,
            discount,
            profit
        )
        SELECT * FROM staging.stg_central_superstore
        EXCEPT
        SELECT
            row_id,
            order_id,
            order_date,
            ship_date,
            ship_mode,
            customer_id,
            customer_name,
            segment,
            country,
            city,
            state,
            postal_code,
            region,
            product_id,
            category,
            sub_category,
            product_name,
            sales,
            quantity,
            discount,
            profit
        FROM bronze.sales_order;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '================================================';
        PRINT 'Loading Bronze Layer is Completed';
        PRINT '================================================';
    END TRY
    BEGIN CATCH
        PRINT '==========================================';
        PRINT 'ERROR OCCURRED DURING LOADING BRONZE LAYER';
        PRINT 'Error Message ' + ERROR_MESSAGE();
        PRINT 'Error Number  ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT 'Error State   ' + CAST(ERROR_STATE() AS NVARCHAR);
        PRINT '==========================================';
    END CATCH
END
GO
