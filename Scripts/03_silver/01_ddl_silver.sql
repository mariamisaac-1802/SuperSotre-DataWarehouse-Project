/*
===============================================================================
DDL Script: Create Silver Table
===============================================================================
Script Purpose:
    This script creates the table in the 'silver' schema, dropping the
    existing table if it already exists. Silver stays at the same grain as
    Bronze (one row per order line item) and is NOT split into fact/dimension
    tables — that modeling happens only in the Gold layer views. This table
    is the single cleansed, constrained, enriched source Gold is built on.
    Run this script to re-define the DDL structure of the 'silver' table.
===============================================================================
*/

IF OBJECT_ID('silver.sales_order', 'U') IS NOT NULL
    DROP TABLE silver.sales_order;
GO

CREATE TABLE silver.sales_order (
    row_id              INT             NOT NULL PRIMARY KEY,  -- one row per order line item
    order_id            VARCHAR(20)     NOT NULL,
    order_date          DATE            NOT NULL,
    ship_date           DATE            NOT NULL CHECK (ship_date >= order_date),
    ship_mode           VARCHAR(50)     NOT NULL CHECK (ship_mode IN ('Standard Class', 'Second Class', 'First Class', 'Same Day')),
    customer_id         VARCHAR(20)     NOT NULL,
    customer_name       VARCHAR(200)    NOT NULL,
    segment             VARCHAR(50)     NOT NULL CHECK (segment IN ('Consumer', 'Corporate', 'Home Office')),
    country              VARCHAR(100)    NOT NULL,
    city                VARCHAR(100)    NOT NULL,
    state               VARCHAR(100)    NOT NULL,
    postal_code         INT,
    region              VARCHAR(50)     NOT NULL,
    product_id          VARCHAR(30)     NOT NULL,
    category            VARCHAR(50)     NOT NULL CHECK (category IN ('Office Supplies', 'Furniture', 'Technology')),
    sub_category        VARCHAR(50)     NOT NULL,
    product_name        VARCHAR(500)    NOT NULL,
    sales               DECIMAL(18,4)   NOT NULL CHECK (sales > 0),
    quantity            INT             NOT NULL CHECK (quantity > 0),
    discount            DECIMAL(5,2)    NOT NULL CHECK (discount BETWEEN 0 AND 1),
    profit              DECIMAL(18,4)   NOT NULL,
    profit_margin       DECIMAL(9,4),               -- enrichment: profit / sales
    order_year          SMALLINT,                    -- enrichment
    order_month         TINYINT,                     -- enrichment
    shipping_delay_days SMALLINT,                    -- enrichment: ship_date - order_date
    is_loss_making      BIT,                         -- enrichment: 1 if profit < 0
    dwh_create_date     DATETIME2       DEFAULT GETDATE()
);
GO

CREATE NONCLUSTERED INDEX ix_silver_sales_order_customer_id ON silver.sales_order (customer_id);
CREATE NONCLUSTERED INDEX ix_silver_sales_order_product_id  ON silver.sales_order (product_id);
CREATE NONCLUSTERED INDEX ix_silver_sales_order_order_date  ON silver.sales_order (order_date);
GO
