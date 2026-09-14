/*
===============================================================================
Stored Procedure: Load Staging Layer (Source CSV -> Staging)
===============================================================================
Script Purpose:
    This stored procedure loads data into the 'staging' schema from the
    source CSV file.
    Actions Performed:
        - Truncates the staging table before loading.
        - Uses BULK INSERT to load the CSV file into the staging table.

Parameters:
    None.
    This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC staging.load_staging;
===============================================================================
*/

CREATE OR ALTER PROCEDURE staging.load_staging AS
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME;

    BEGIN TRY
        SET @start_time = GETDATE();
        PRINT '================================================';
        PRINT 'Loading Staging Layer';
        PRINT '================================================';

        PRINT '>> Truncating Table: staging.stg_central_superstore';
        TRUNCATE TABLE staging.stg_central_superstore;

        PRINT '>> Inserting Data Into: staging.stg_central_superstore';
        -- NOTE: update the file path below to wherever the CSV lives on the
        -- SQL Server host (BULK INSERT reads from the server's file system).
        BULK INSERT staging.stg_central_superstore
        FROM 'D:\SuperstoreDW_MedallionArchitecture\SuperstoreDW\source_data_Central_Superstore.csv'
        WITH (
            FIRSTROW        = 2,        -- skip header row
            FIELDTERMINATOR = ',',
            ROWTERMINATOR   = '\r\n',   -- source file uses Windows (CRLF) line endings
            FIELDQUOTE      = '"',      -- honor quoted fields (e.g. product names containing commas)
            CODEPAGE        = '65001',  -- UTF-8
            TABLOCK
        );

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '================================================';
        PRINT 'Loading Staging Layer is Completed';
        PRINT '================================================';
    END TRY
    BEGIN CATCH
        PRINT '==========================================';
        PRINT 'ERROR OCCURRED DURING LOADING STAGING LAYER';
        PRINT 'Error Message ' + ERROR_MESSAGE();
        PRINT 'Error Number  ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT 'Error State   ' + CAST(ERROR_STATE() AS NVARCHAR);
        PRINT '==========================================';
    END CATCH
END
GO
