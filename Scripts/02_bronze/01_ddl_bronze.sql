/*
===============================================================================
DDL Script: Create Bronze Table
===============================================================================
Script Purpose:
    This script creates the table in the 'bronze' schema, dropping the
    existing table if it already exists. Same grain as staging (one row per
    order line item, keyed by the source's Row_ID), but with native data
    types and a surrogate bronze_id that tracks load history.
    Run this script to re-define the DDL structure of the 'bronze' table.
===============================================================================
*/

IF OBJECT_ID('bronze.sales_order', 'U') IS NOT NULL
    DROP TABLE bronze.sales_order;
GO

CREATE TABLE bronze.sales_order (
    bronze_id           INT IDENTITY(1,1) PRIMARY KEY,  -- surrogate load-tracking key
    row_id              INT             NOT NULL,       -- natural/business key from source
    order_id            VARCHAR(20),
    order_date          DATE,
    ship_date           DATE,
    ship_mode           VARCHAR(50),
    customer_id         VARCHAR(20),
    customer_name       VARCHAR(200),
    segment             VARCHAR(50),
    country             VARCHAR(100),
    city                VARCHAR(100),
    state               VARCHAR(100),
    postal_code         INT,
    region              VARCHAR(50),
    product_id          VARCHAR(30),
    category            VARCHAR(50),
    sub_category        VARCHAR(50),
    product_name        VARCHAR(500),
    sales               DECIMAL(18,4),
    quantity            INT,
    discount            DECIMAL(5,2),
    profit              DECIMAL(18,4),
    bronze_load_date    DATETIME2 DEFAULT GETDATE()
);
GO

CREATE NONCLUSTERED INDEX ix_bronze_sales_order_row_id
    ON bronze.sales_order (row_id);
GO
