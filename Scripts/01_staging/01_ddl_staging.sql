/*
===============================================================================
DDL Script: Create Staging Table
===============================================================================
Script Purpose:
    This script creates the table in the 'staging' schema, dropping the
    existing table if it already exists. Every column is NVARCHAR(255) with
    no type enforcement, so a load never fails on a data-quality issue.
    Run this script to re-define the DDL structure of the 'staging' table.
===============================================================================
*/

IF OBJECT_ID('staging.stg_central_superstore', 'U') IS NOT NULL
    DROP TABLE staging.stg_central_superstore;
GO

CREATE TABLE staging.stg_central_superstore (
    row_iD          NVARCHAR(255),
    order_iD        NVARCHAR(255),
    order_date      NVARCHAR(255),
    ship_date       NVARCHAR(255),
    ship_mode       NVARCHAR(255),
    customer_iD     NVARCHAR(255),
    customer_name   NVARCHAR(255),
    segment         NVARCHAR(255),
    country         NVARCHAR(255),
    city            NVARCHAR(255),
    state           NVARCHAR(255),
    postal_code     NVARCHAR(255),
    region          NVARCHAR(255),
    product_iD      NVARCHAR(255),
    category        NVARCHAR(255),
    sub_category    NVARCHAR(255),
    product_name    NVARCHAR(255),
    sales           NVARCHAR(255),
    quantity        NVARCHAR(255),
    discount        NVARCHAR(255),
    profit          NVARCHAR(255)
);
GO
