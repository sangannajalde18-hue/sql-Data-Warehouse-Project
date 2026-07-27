/*
===============================================================================
Script Name   : Customer Report View
File Name     : customer_report.sql
Database      : Data Warehouse (Gold Layer)
Author        : Sanganna Jalade
Date Created  : 2026-07-27
Description   : 
    This script creates the 'gold.report_customers' view. It consolidates key 
    customer-level metrics, demographic details, transaction aggregations, 
    behavioral segmentations (VIP, Regular, New), age grouping, and essential 
    KPIs such as Recency, Average Order Value (AOV), and Average Monthly Spend.

===============================================================================
Purpose:
    - This report consolidates key customer metrics and behaviors.

Highlights:
    1. Gathers essential fields such as names, ages, and transaction details.
    2. Segments customers into categories (VIP, Regular, New) and age groups.
    3. Aggregates customer-level metrics:
        - total orders
        - total sales
        - total quantity purchased
        - total products
        - lifespan (in months)
    4. Calculates valuable KPIs:
        - recency (months since last order)
        - average order value (AOV)
        - average monthly spend
===============================================================================
*/

IF OBJECT_ID('gold.report_customers', 'V') IS NOT NULL
    DROP VIEW gold.report_customers;
GO

CREATE VIEW gold.report_customers AS 
WITH base_query AS (
    /*----------------------------------------------------------------------------
    1) Base Query: Retrieves core columns from sales and customer dimension tables
    ------------------------------------------------------------------------------*/
    SELECT 
        f.order_number,
        f.product_key,
        f.order_date,
        f.sales_amount,
        f.quantity,
        c.customer_key,
        c.customer_number,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        DATEDIFF(year, c.birthdate, GETDATE()) AS age
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_customers c
        ON c.customer_key = f.customer_key
    WHERE f.order_date IS NOT NULL 
),
customer_aggregation AS (
    /*----------------------------------------------------------------------------
    2) Customer Aggregation: Aggregates order history per customer
    ------------------------------------------------------------------------------*/
    SELECT 
        customer_key,
        customer_number,
        customer_name,
        age,
        COUNT(DISTINCT order_number) AS total_orders,
        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_quantity,
        COUNT(DISTINCT product_key) AS total_products,
        MAX(order_date) AS last_order_date,
        DATEDIFF(month, MIN(order_date), MAX(order_date)) AS lifespan
    FROM base_query
    GROUP BY 
        customer_key,
        customer_number,
        customer_name,
        age
)
/*----------------------------------------------------------------------------
3) Final Selection: Segments customers and calculates customer KPIs
------------------------------------------------------------------------------*/
SELECT
    customer_key,
    customer_number,
    customer_name,
    age,
    
    -- Age group classification
    CASE 
        WHEN age < 20 THEN 'UNDER 20'
        WHEN age BETWEEN 20 AND 29 THEN '20-29'
        WHEN age BETWEEN 30 AND 39 THEN '30-39'
        WHEN age BETWEEN 40 AND 49 THEN '40-49'
        ELSE '50 and above'
    END AS age_group,

    -- Customer behavior segmentation
    CASE
        WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
        WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
        ELSE 'New'
    END AS customer_segment,

    last_order_date,
    DATEDIFF(month, last_order_date, GETDATE()) AS recency,
    total_orders,
    total_sales,
    total_quantity,
    total_products,
    lifespan,

    -- Compute Average Order Value (AOV)
    CASE 
        WHEN total_orders = 0 THEN 0 
        ELSE total_sales / total_orders 
    END AS avg_order_value,

    -- Compute Average Monthly Spend
    CASE 
        WHEN lifespan = 0 THEN total_sales
        ELSE total_sales / lifespan
    END AS avg_monthly_spend

FROM customer_aggregation;
GO
