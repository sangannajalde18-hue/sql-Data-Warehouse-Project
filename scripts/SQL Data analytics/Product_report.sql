/*
===============================================================================
Script Name   : Product Report View
File Name     : Product_report.sql
Database      : Data Warehouse (Gold Layer)
Author        : Sanganna Jalade
Date Created  : 2026-07-27
Description   : 
    This script creates the 'gold.report_products' view. It consolidates key 
    product-level metrics, product hierarchy attributes, sales aggregations, 
    revenue segmentations (High-Performer, Mid-Range, Low-Performer), and key 
    KPIs such as Recency, Average Order Revenue (AOR), and Average Monthly Revenue.

===============================================================================
Purpose:
    - This report consolidates key product metrics and behaviors.

Highlights:
    1. Gathers essential fields such as product name, category, subcategory, and cost.
    2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
    3. Aggregates product-level metrics:
        - total orders
        - total sales
        - total quantity sold
        - total customers (unique)
        - lifespan (in months)
    4. Calculates valuable KPIs:
        - recency (months since last sale)
        - average order revenue (AOR)
        - average monthly revenue
===============================================================================
*/

IF OBJECT_ID('gold.report_products', 'V') IS NOT NULL
    DROP VIEW gold.report_products;
GO

CREATE VIEW gold.report_products AS 
WITH base_query AS (
    /*----------------------------------------------------------------------------
    1) Gathers essential fields such as product name, category, subcategory, and cost
    ------------------------------------------------------------------------------*/
    SELECT 
        f.order_number,
        f.order_date,
        f.customer_key,
        f.sales_amount,
        f.quantity,
        p.product_key,
        p.product_name,
        p.category,
        p.subcategory,
        p.cost
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON f.product_key = p.product_key
    WHERE f.order_date IS NOT NULL
),
product_aggregations AS (
    /*----------------------------------------------------------------------------
    3) Aggregates product-level metrics (orders, sales, quantity, unique customers, lifespan)
    ------------------------------------------------------------------------------*/
    SELECT 
        product_key,
        product_name,
        category,
        subcategory,
        cost,
        COUNT(DISTINCT order_number) AS total_orders,
        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_quantity_sold,
        COUNT(DISTINCT customer_key) AS total_customers,
        MAX(order_date) AS last_sale_date,
        DATEDIFF(month, MIN(order_date), MAX(order_date)) AS lifespan
    FROM base_query
    GROUP BY 
        product_key,
        product_name,
        category,
        subcategory,
        cost
)
SELECT 
    product_key,
    product_name,
    category,
    subcategory,
    cost,
    
    /*----------------------------------------------------------------------------
    2) Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers
    ------------------------------------------------------------------------------*/
    CASE 
        WHEN total_sales >= 50000 THEN 'High-Performer'
        WHEN total_sales >= 10000 THEN 'Mid-Range'
        ELSE 'Low-Performer'
    END AS product_segment,

    total_orders,
    total_sales,
    total_quantity_sold,
    total_customers,
    lifespan,
    
    /*----------------------------------------------------------------------------
    4) Calculates valuable KPIs (recency, average order revenue, average monthly revenue)
    ------------------------------------------------------------------------------*/
    last_sale_date,
    DATEDIFF(month, last_sale_date, GETDATE()) AS recency,

    -- Average Order Revenue (AOR)
    CASE 
        WHEN total_orders = 0 THEN 0 
        ELSE total_sales / total_orders 
    END AS avg_order_revenue,

    -- Average Monthly Revenue
    CASE 
        WHEN lifespan = 0 THEN total_sales 
        ELSE total_sales / lifespan 
    END AS avg_monthly_revenue

FROM product_aggregations;
GO
