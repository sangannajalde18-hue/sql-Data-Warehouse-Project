<div align="center">

# 🏗️ SQL Data Warehouse Project

**A modern data warehouse built in SQL Server using the Medallion architecture (Bronze → Silver → Gold), with ETL, star-schema modelling, data quality tests and SQL analytics.**

![SQL Server](https://img.shields.io/badge/SQL%20Server-T--SQL-CC2927?logo=microsoftsqlserver&logoColor=white)
![Architecture](https://img.shields.io/badge/Architecture-Medallion-orange)
![Model](https://img.shields.io/badge/Model-Star%20Schema-blue)
![License](https://img.shields.io/badge/License-MIT-green)

[Overview](#-overview) · [Architecture](#-architecture) · [Layers](#-layer-by-layer) · [Data Model](#-gold-layer-data-model) · [Quality Checks](#-data-quality-checks) · [Analytics](#-sql-analytics--reports) · [Structure](#-repository-structure) · [Run It](#-getting-started)

</div>

---

## 📖 Overview

This project consolidates sales data from **two source systems (CRM and ERP, provided as CSV files)** into a single, clean, analytics-ready warehouse. Raw data is loaded, cleansed and then modelled into a **star schema** that supports reporting on customer behaviour, product performance and sales trends.

| Area | What was built |
|------|----------------|
| 🗄️ **Data Architecture** | `DataWarehouse` database with `bronze`, `silver` and `gold` schemas |
| 🔄 **ETL** | Stored procedures: `bronze.load_bronze` (BULK INSERT) and `silver.load_silver` (cleansing & transformation) |
| ⭐ **Data Modelling** | Gold views: `dim_customers`, `dim_products`, `fact_sales` |
| ✅ **Data Quality** | Validation scripts for the Silver and Gold layers |
| 📊 **Analytics** | Exploratory data analysis plus customer and product report views |

> 💡 Click any ▶ section below to expand it.

---

## 🏛️ Architecture

```
  CRM (CSV)  ─┐                                                     
              ├─▶  🥉 BRONZE  ──▶  🥈 SILVER  ──▶  🥇 GOLD  ──▶  📊 SQL Analytics
  ERP (CSV)  ─┘    raw, as-is      cleaned &         star schema     EDA + reports
                   (BULK INSERT)    standardised      (views)
```

| Layer | Purpose | Object type |
|-------|---------|-------------|
| 🥉 **Bronze** | Raw data exactly as it arrives from the sources | Tables |
| 🥈 **Silver** | Cleansed, standardised, deduplicated data | Tables |
| 🥇 **Gold** | Business-ready dimensional model | Views |

### Source systems

| System | Tables |
|--------|--------|
| **CRM** | `crm_cust_info`, `crm_prd_info`, `crm_sales_details` |
| **ERP** | `erp_cust_az12`, `erp_loc_a101`, `erp_px_cat_g1v2` |

---

## 🔍 Layer by Layer

<details>
<summary><b>🛠️ Step 0 – Database initialisation</b></summary>

`scripts/init_database.sql` creates the `DataWarehouse` database and the three schemas: `bronze`, `silver` and `gold`.

</details>

<details>
<summary><b>🥉 Bronze layer – raw ingestion</b></summary>

- `ddl_bronze.sql` drops and recreates the 6 Bronze tables (3 CRM + 3 ERP)
- `proc_load_bronze.sql` defines `bronze.load_bronze`, which:
  - **Truncates** each table, then loads the CSV using **`BULK INSERT`** (`FIRSTROW = 2`, `TABLOCK`)
  - Prints a **load duration** for every table
  - Wraps everything in **`TRY...CATCH`** for error reporting

```sql
EXEC bronze.load_bronze;
```

</details>

<details>
<summary><b>🥈 Silver layer – cleansing & standardisation</b></summary>

`silver.load_silver` truncates and reloads all Silver tables from Bronze. Every Silver table also carries a `dwh_create_date` audit column.

| Table | Transformations applied |
|-------|------------------------|
| `crm_cust_info` | Removed nulls on the ID, **deduplicated using `ROW_NUMBER()`** (keeps the latest record per customer), `TRIM`med names, decoded marital status (`S`/`M` → Single/Married) and gender (`F`/`M` → Female/Male), defaulting unknowns to `n/a` |
| `crm_prd_info` | **Derived `cat_id` and `prd_key`** by splitting the raw product key, replaced null cost with 0, decoded product line (`M`/`R`/`S`/`T` → Mountain/Road/Other Sales/Touring), calculated **`prd_end_dt` with `LEAD()`** so each product version ends the day before the next begins |
| `crm_sales_details` | Converted integer dates (YYYYMMDD) to real `DATE`s, set invalid dates to `NULL`, **recalculated `sales` = quantity × price** where values were wrong, missing or negative, derived price from sales ÷ quantity where it was missing |
| `erp_cust_az12` | Stripped the `NAS` prefix from customer IDs, nulled out **future birthdates**, standardised gender |
| `erp_loc_a101` | Removed `-` from customer IDs, mapped country codes (`DE` → Germany, `US`/`USA` → United States), blank → `n/a` |
| `erp_px_cat_g1v2` | Loaded as-is (already clean) |

```sql
EXEC silver.load_silver;
```

</details>

<details>
<summary><b>🥇 Gold layer – star schema</b></summary>

Three views in `scripts/gold/ddl_gold.sql` integrate the CRM and ERP data:

- **`gold.dim_customers`** – joins CRM customer info with ERP demographics and location; creates a **surrogate key** with `ROW_NUMBER()`; treats **CRM as the master source for gender** and falls back to ERP when CRM has no value
- **`gold.dim_products`** – joins CRM products with ERP categories; creates a surrogate key; **filters out historical product versions** (`prd_end_dt IS NULL`) so only current products remain
- **`gold.fact_sales`** – sales transactions linked to both dimensions through their surrogate keys

</details>

---

## ⭐ Gold Layer Data Model

```
                 ┌──────────────────┐
                 │  dim_customers   │
                 │ customer_key (PK)│
                 └────────▲─────────┘
                          │
 ┌──────────────────┐   ┌─┴────────────────┐
 │  dim_products    │◀──│   fact_sales     │
 │ product_key (PK) │   │ product_key (FK) │
 └──────────────────┘   │ customer_key (FK)│
                        └──────────────────┘
```

<details>
<summary><b>📋 Column reference (see <code>docs/data_catalog.md</code> for full detail)</b></summary>

**`gold.dim_customers`** – `customer_key`, `customer_id`, `customer_number`, `first_name`, `last_name`, `country`, `marital_status`, `gender`, `birthdate`, `create_date`

**`gold.dim_products`** – `product_key`, `product_id`, `product_number`, `product_name`, `category_id`, `category`, `subcategory`, `maintenance`, `cost`, `product_line`, `start_date`

**`gold.fact_sales`** – `order_number`, `product_key`, `customer_key`, `order_date`, `shipping_date`, `due_date`, `sales_amount`, `quantity`, `price`

</details>

---

## ✅ Data Quality Checks

Validation scripts live in `tests/`. Each query is written so that **no rows returned = pass**.

<details>
<summary><b>🥈 <code>quality_checks_silver.sql</code></b></summary>

- Nulls or duplicates in primary keys
- Unwanted leading/trailing spaces
- Data standardisation and consistency (e.g. gender, marital status, country values)
- Negative or null numeric values such as product cost
- Invalid date orders (e.g. end date before start date, order date after ship date)
- Sales = Quantity × Price consistency
- Out-of-range birthdates

</details>

<details>
<summary><b>🥇 <code>quality_checks_gold.sql</code></b></summary>

- Uniqueness of surrogate keys in `dim_customers` and `dim_products`
- Referential integrity between `fact_sales` and both dimensions

</details>

---

## 📊 SQL Analytics & Reports

All analysis is built on the Gold layer (`scripts/SQL Data analytics/`).

<details>
<summary><b>🔎 <code>EDA.sql</code> – Exploratory Data Analysis</b></summary>

| Section | What it covers |
|---------|----------------|
| 1. Database & schema exploration | Tables and columns in the warehouse |
| 2. Dimension & measure exploration | Countries, product hierarchy, order date range, youngest/oldest customer |
| 3. KPI summary | Total sales, items sold, average price, total orders, products, customers and active customers, plus a consolidated metrics report |
| 4. Grouping & distribution | Customers by country and gender, products by category, average cost and revenue by category, revenue per customer |
| 5. Ranking | Top 5 / bottom 5 products by revenue, top 10 customers, bottom 3 customers by orders |
| 6. Advanced analytics | Monthly trends, **running total and moving average**, **year-over-year product performance**, **part-to-whole category contribution**, cost-range segmentation and **customer segmentation (VIP / Regular / New)** |

</details>

<details>
<summary><b>👤 <code>Customer_report.sql</code> → <code>gold.report_customers</code></b></summary>

A reusable view with one row per customer, including:

- **Segments:** VIP (12+ months and sales > 5,000), Regular (12+ months and sales ≤ 5,000), New (everything else) and age groups (Under 20, 20-29, 30-39, 40-49, 50+)
- **Aggregates:** total orders, sales, quantity, products and lifespan in months
- **KPIs:** recency, average order value (AOV), average monthly spend

</details>

<details>
<summary><b>📦 <code>Product_report.sql</code> → <code>gold.report_products</code></b></summary>

A reusable view with one row per product, including:

- **Segments:** High-Performer (sales ≥ 50,000), Mid-Range (≥ 10,000), Low-Performer (below 10,000)
- **Aggregates:** total orders, sales, quantity, unique customers and lifespan in months
- **KPIs:** recency, average order revenue (AOR), average monthly revenue

</details>

---

## 🛠️ Tech Stack & Concepts

| Category | Details |
|----------|---------|
| Database | Microsoft SQL Server (T-SQL) |
| ETL | Stored procedures, `BULK INSERT`, `TRUNCATE`, `TRY...CATCH` |
| SQL techniques | CTEs, window functions (`ROW_NUMBER`, `LEAD`, running totals, moving averages), `CASE`, `COALESCE`, `NULLIF`, joins, aggregations, views |
| Modelling | Medallion architecture, star schema, surrogate keys |
| Quality | Rule-based validation queries, audit columns |

---

## 📁 Repository Structure

```
sql-Data-Warehouse-Project/
├── datasets/                    # Source CSVs (CRM and ERP)
├── docs/
│   └── data_catalog.md          # Gold layer data catalog
├── scripts/
│   ├── init_database.sql        # Create DataWarehouse + schemas
│   ├── bronze/
│   │   ├── ddl_bronze.sql
│   │   └── proc_load_bronze.sql
│   ├── silver/
│   │   ├── ddl_silver.sql
│   │   └── proc_load_silver.sql
│   ├── gold/
│   │   └── ddl_gold.sql
│   └── SQL Data analytics/
│       ├── EDA.sql
│       ├── Customer_report.sql
│       └── Product_report.sql
├── tests/
│   ├── quality_checks_silver.sql
│   └── quality_checks_gold.sql
└── LICENSE
```

---

## 🚀 Getting Started

<details>
<summary><b>Run the project end to end</b></summary>

**Prerequisites:** SQL Server (Express works) and SSMS or Azure Data Studio.

1. **Clone the repo**
   ```bash
   git clone https://github.com/sangannajalde18-hue/sql-Data-Warehouse-Project.git
   ```
2. **Initialise the database** – run `scripts/init_database.sql`
3. **Create tables** – run `ddl_bronze.sql`, then `ddl_silver.sql`
4. **Update the file paths** in `scripts/bronze/proc_load_bronze.sql` so each `BULK INSERT` points to the CSVs on your machine
5. **Load the layers**
   ```sql
   EXEC bronze.load_bronze;
   EXEC silver.load_silver;
   ```
6. **Create the Gold views** – run `scripts/gold/ddl_gold.sql`
7. **Validate** – run the scripts in `tests/` (no rows returned means the checks pass)
8. **Analyse** – run `EDA.sql` and create the report views

</details>

---

## 👩‍💻 Author

**Sanganna Jalade** · MSc Data Science, Fergusson College, Pune

[💻 GitHub](https://github.com/sangannajalde18-hue)

📄 Licensed under the MIT License.
