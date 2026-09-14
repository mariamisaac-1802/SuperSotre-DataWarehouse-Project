# SuperstoreDW — Medallion Architecture Data Warehouse

A SQL Server data warehouse built on the **Medallion Architecture** (Staging → Bronze → Silver → Gold), transforming the raw Central Superstore sales CSV into a cleansed, constrained, star-schema dimensional model ready for analytics and reporting.

---

## Project Overview

| Item | Detail |
|---|---|
| **Source** | `source_data_Central_Superstore.csv` (Central region sales, one row per order line item) |
| **Platform** | Microsoft SQL Server (T-SQL) |
| **Database** | `SuperstoreDW` |
| **Schemas** | `staging`, `bronze`, `silver`, `gold` |
| **Pattern** | Medallion Architecture (multi-hop refinement) |
| **Final Model** | Star Schema — 4 dimensions + 1 fact view |
| **Loading Style** | Stored procedures, full-refresh where appropriate, incremental in Bronze |

The project ingests raw CSV data with zero type enforcement, progressively cleans and validates it, enriches it with derived business columns, and finally projects it into a dimensional star schema for BI consumption.

---

## Architecture

```
┌─────────────────────┐
│   Source CSV File   │
│  (Central Superstore)│
└──────────┬──────────┘
           │ BULK INSERT
           ▼
┌─────────────────────┐
│   STAGING Schema    │  All NVARCHAR(255) — no type enforcement,
│ stg_central_superstore│  load never fails on data-quality issues
└──────────┬──────────┘
           │ EXCEPT-based incremental insert
           ▼
┌─────────────────────┐
│   BRONZE Schema     │  Native data types, append-only,
│   sales_order       │  surrogate bronze_id tracks load history
└──────────┬──────────┘
           │ Dedupe (latest per row_id) + cleanse + enrich + business rules
           ▼
┌─────────────────────┐
│   SILVER Schema     │  Single cleansed, constrained, enriched table
│   sales_order       │  at line-item grain (NO fact/dim split here)
└──────────┬──────────┘
           │ Project distinct attribute sets → dimensions
           │ Join back → fact
           ▼
┌─────────────────────┐
│    GOLD Schema      │  Star Schema views:
│  dim_customer       │  dim_customer, dim_product,
│  dim_product        │  dim_location, dim_date, fact_sales
│  dim_location       │
│  dim_date           │
│  fact_sales         │
└─────────────────────┘
```

Each layer has a single, well-defined responsibility:

- **Staging** — land the raw file verbatim; never fail on bad data.
- **Bronze** — type the data and preserve load history; append-only.
- **Silver** — one clean, validated, enriched row per order line item.
- **Gold** — business-facing star schema for analytics.

---

## Repository Structure

```
SuperstoreDW_MedallionArchitecture/
│
├── source_data_Central_Superstore.csv   # Raw source data
├── naming_conventions.md                # Project naming standards
├── README.md                            # This file
│
├── 00_init_database.sql                 # Create DB + 4 schemas
│
├── 01_ddl_staging.sql                   # DDL: staging.stg_central_superstore
├── 02_sp_load_staging.sql               # SP: staging.load_staging
│
├── 01_ddl_bronze.sql                    # DDL: bronze.sales_order
├── 02_sp_load_bronze.sql                # SP: bronze.load_bronze
│
├── 01_ddl_silver.sql                    # DDL: silver.sales_order
├── 02_sp_load_silver.sql                # SP: silver.load_silver
│
└── 01_gold_views.sql                    # Gold dimension & fact views
```

---

## Data Model

### Gold Star Schema

```
                    ┌──────────────────┐
                    │   dim_customer   │
                    │──────────────────│
                    │ customer_key (PK)│
                    │ customer_id      │
                    │ customer_name    │
                    │ segment          │
                    └────────┬─────────┘
                             │
┌──────────────┐    ┌────────▼─────────┐    ┌──────────────────┐
│  dim_product │    │    fact_sales    │    │  dim_location    │
│──────────────│    │──────────────────│    │──────────────────│
│ product_key  ├────┤ sales_key (PK)   ├────┤ location_key (PK)│
│ product_id   │    │ order_number     │    │ country          │
│ category     │    │ ship_mode        │    │ state            │
│ sub_category │    │ customer_key (FK)│    │ city             │
│ product_name │    │ product_key (FK) │    │ postal_code      │
└──────────────┘    │ location_key (FK)│    │ region           │
                    │ order_date_key   │    └──────────────────┘
┌──────────────┐    │ ship_date_key    │
│   dim_date   │    │ sales            │
│──────────────│    │ quantity         │
│ date_key (PK)├────┤ discount         │
│ full_date    │    │ profit           │
│ year, quarter│    │ profit_margin    │
│ month, ...   │    │ shipping_delay   │
│ is_weekend   │    │ is_loss_making   │
└──────────────┘    └──────────────────┘
```

### Grain

- **Fact grain:** one row per order line item (`row_id`).
- **Degenerate dimensions** in the fact: `order_number`, `ship_mode`.
- All Gold objects are **views** projected from `silver.sales_order` — no physical Gold tables.

---

## Prerequisites

- **Microsoft SQL Server** (2016 or later recommended; uses `CREATE OR ALTER`, `FORMAT`, `TRIM`, `DATENAME`).
- **Permissions:** `CREATE DATABASE`, `CREATE SCHEMA`, `CREATE TABLE`, `CREATE VIEW`, `CREATE PROCEDURE`, and `BULK INSERT` / `ADMINISTER BULK OPERATIONS`.
- The CSV file must be accessible **on the SQL Server host's file system** — `BULK INSERT` reads server-side, not client-side.
- SQL Server Agent or manual execution for scheduling (optional).

---

## Setup & Execution Order

> **WARNING:** `00_init_database.sql` drops and recreates the entire `SuperstoreDW` database. All existing data will be permanently lost. Ensure backups exist before running.

Run the scripts **in this exact order**:

| Step | Script | Purpose |
|------|--------|---------|
| 1 | `00_init_database.sql` | Drop/create `SuperstoreDW`, create `staging`, `bronze`, `silver`, `gold` schemas |
| 2 | `01_ddl_staging.sql` | Create `staging.stg_central_superstore` |
| 3 | `02_sp_load_staging.sql` | Create `staging.load_staging` procedure |
| 4 | `01_ddl_bronze.sql` | Create `bronze.sales_order` + index |
| 5 | `02_sp_load_bronze.sql` | Create `bronze.load_bronze` procedure |
| 6 | `01_ddl_silver.sql` | Create `silver.sales_order` + indexes |
| 7 | `02_sp_load_silver.sql` | Create `silver.load_silver` procedure |
| 8 | `01_gold_views.sql` | Create all Gold dimension & fact views |

### Configure the file path

Before running the staging load, edit `02_sp_load_staging.sql` and update the `BULK INSERT ... FROM` path to wherever the CSV lives **on the SQL Server host**:

```sql
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
```

### Execute the loads

```sql
USE SuperstoreDW;
GO

EXEC staging.load_staging;   -- CSV  → staging
EXEC bronze.load_bronze;     -- staging → bronze (incremental)
EXEC silver.load_silver;     -- bronze → silver (full refresh)
GO
```

Gold views are virtual — query them directly, no load step required.

---

## Layer Details

### Staging

- **Table:** `staging.stg_central_superstore`
- **Columns:** all `NVARCHAR(255)` — no type enforcement, so a load never fails on a data-quality issue.
- **Load:** truncate then `BULK INSERT` from CSV (UTF-8, quoted fields, CRLF line endings).
- **Procedure:** `staging.load_staging`

### Bronze

- **Table:** `bronze.sales_order`
- **Types:** native (`DATE`, `INT`, `DECIMAL(18,4)`, etc.) plus a surrogate `bronze_id INT IDENTITY` PK.
- **Load:** **incremental, append-only.** Uses `INSERT ... SELECT * FROM staging EXCEPT SELECT ... FROM bronze` so re-running with unchanged data adds nothing. Changed rows land as a **new** `bronze_id` rather than overwriting — load history is preserved.
- **Index:** nonclustered on `row_id`.
- **Procedure:** `bronze.load_bronze`

### Silver

- **Table:** `silver.sales_order`
- **Grain:** one row per order line item; `row_id` is the PK.
- **Load:** **full refresh** (truncate + insert), deduping Bronze to the latest `bronze_id` per `row_id`.
- **Cleansing:** `TRIM` on all text columns.
- **Enrichment:**
  - `profit_margin` = `profit / sales`
  - `order_year`, `order_month`
  - `shipping_delay_days` = `ship_date − order_date`
  - `is_loss_making` = 1 if `profit < 0`
- **Business rules enforced via `CHECK` constraints and load filters:**
  - `ship_date >= order_date`
  - `ship_mode IN ('Standard Class','Second Class','First Class','Same Day')`
  - `segment IN ('Consumer','Corporate','Home Office')`
  - `category IN ('Office Supplies','Furniture','Technology')`
  - `quantity > 0`, `sales > 0`, `discount BETWEEN 0 AND 1`
  - No nulls in key descriptive columns
- Rows violating rules are **filtered out**, not allowed to fail the batch.
- **Indexes:** nonclustered on `customer_id`, `product_id`, `order_date`.
- **Procedure:** `silver.load_silver`

### Gold

- **Objects:** views only (`dim_customer`, `dim_product`, `dim_location`, `dim_date`, `fact_sales`).
- **Fact/Dimension split happens ONLY here** — Silver stays at line-item grain.
- **Surrogate keys** generated with `ROW_NUMBER() OVER (...)`.
- `dim_date.date_key` and the fact's date keys use `yyyyMMdd` integer format.
- `fact_sales` joins back to dimensions on natural/business keys.

---

## Naming Conventions

See [`naming_conventions.md`](naming_conventions.md) for full detail. Summary:

| Object | Convention | Example |
|--------|-----------|---------|
| Schemas / tables / columns | `snake_case`, English | `sales_order`, `customer_id` |
| Bronze/Silver tables | `<sourcesystem>_<entity>` | `sales_order` |
| Gold tables/views | `<category>_<entity>` (`dim_`, `fact_`, `report_`) | `dim_customer`, `fact_sales` |
| Surrogate keys | `<table_name>_key` | `customer_key` |
| Technical columns | `dwh_<column_name>` | `dwh_create_date`, `bronze_load_date` |
| Stored procedures | `load_<layer>` | `load_bronze`, `load_silver` |

---

## Sample Queries

**Total sales & profit by category:**

```sql
SELECT
    dp.category,
    SUM(fs.sales)  AS total_sales,
    SUM(fs.profit) AS total_profit
FROM gold.fact_sales fs
JOIN gold.dim_product dp ON dp.product_key = fs.product_key
GROUP BY dp.category
ORDER BY total_sales DESC;
```

**Monthly sales trend:**

```sql
SELECT
    dd.[year],
    dd.[month],
    dd.month_name,
    SUM(fs.sales) AS total_sales
FROM gold.fact_sales fs
JOIN gold.dim_date dd ON dd.date_key = fs.order_date_key
GROUP BY dd.[year], dd.[month], dd.month_name
ORDER BY dd.[year], dd.[month];
```

**Top 10 customers by profit:**

```sql
SELECT TOP 10
    dc.customer_name,
    dc.segment,
    SUM(fs.profit) AS total_profit
FROM gold.fact_sales fs
JOIN gold.dim_customer dc ON dc.customer_key = fs.customer_key
GROUP BY dc.customer_name, dc.segment
ORDER BY total_profit DESC;
```

**Loss-making line items share:**

```sql
SELECT
    CAST(SUM(CASE WHEN is_loss_making = 1 THEN 1 ELSE 0 END) AS DECIMAL) / COUNT(*) AS loss_ratio,
    SUM(CASE WHEN is_loss_making = 1 THEN profit ELSE 0 END) AS total_loss
FROM gold.fact_sales;
```

---

## Design Decisions & Notes

- **Why keep Staging all-NVARCHAR?** So ingestion never fails on a type mismatch or dirty value — all validation is deferred to Silver, where failures are handled deliberately rather than crashing the load.
- **Why is Bronze append-only?** To preserve a full audit trail of every version of a record. `bronze_id` is the load-tracking key; `row_id` is the business key.
- **Why no Fact/Dimension split in Silver?** Silver's job is cleansing and enrichment, not modeling. Keeping it flat keeps the ETL simple and lets the Gold views define the schema without a second physical layer to maintain.
- **Why views for Gold?** They're always in sync with Silver and avoid redundant storage. If Gold needs to become physical for performance, these views can be materialized into tables with `SELECT ... INTO`.
- **Surrogate keys in views** use `ROW_NUMBER()`, which is deterministic only as long as the underlying `ORDER BY` produces a stable order. For a truly stable surrogate key, persist the dimensions as tables with `IDENTITY` columns.
- **`is_weekend`** in `dim_date` uses `DATEPART(WEEKDAY, ...) IN (1, 7)` — verify your server's `DATEFIRST` setting if results look off.
- **`is_loss_making`** is stored as `BIT` in Silver and surfaced in the fact for easy loss analysis.

---

## License & Attribution

- **Source data:** Sample Superstore dataset (Central region extract).
- **Architecture & scripts:** Medallion Architecture reference implementation for SQL Server.

---

*Built with the Medallion Architecture — land raw, refine progressively, deliver business-ready data.*
