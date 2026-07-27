/*
===============================================================================
Quality Checks
===============================================================================
Script Purpose:
    This script performs various quality checks for data consistency, accuracy,
    and standardization across the 'silver' schemas. It includes checks for:
    - Null or duplicate primary keys.
    - Unwanted spaces in string fields.
    - Data standardization and consistency.
    - Invalid date ranges and orders.
    - Data consistency between related fields.

Usage Notes:
    - Run these checks after data loading Silver Layer.
    - Investigate and resolve any discrepancies found during the checks.
===============================================================================
*/




-- Customers table ****
-- Check for Nulls or Duplicates in primary key
-- Expectation: No Result

SELECT 
cst_id,COUNT(*)
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*)>1 OR cst_id IS NULL


--Check for unwanted spaces
-- Expectation : No results
SELECT cst_lastname FROM silver.crm_cust_info
WHERE cst_lastname != TRIM(cst_lastname)


-- Data Standardization & Consistency

SELECT DISTINCT cst_gndr
FROM silver.crm_cust_info

SELECT * FROM silver.crm_cust_info



-- PRoduct Table****
-- Quality Checks
-- Check for NUlls or Duplicates in Primary key
-- Expectation : No result

SELECT 
prd_id,
COUNT(*)
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*)>1 OR prd_id IS NULL


-- 
-- Check for NUlls or Duplicates in Primary key
-- Expectation : No result

SELECT prd_nm FROM
silver.crm_prd_info
WHERE prd_nm!= TRIM(prd_nm)


-- CHECK for NULLs or Negative Numbers
-- Expectation : No Results
SELECT prd_cost
FROM silver.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL


-- Data Standardization & Consistency

SELECT DISTINCT prd_line
FROM silver.crm_prd_info

-- Check for Inalid Date Orders
SELECT * 
FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt



--Check for Invalid Dates

SELECT
NULLIF(sls_order_dt,0) sls_order_dt
FROM bronze.crm_sales_details
WHERE sls_order_dt <=0
OR LEN(sls_order_dt) !=8
OR sls_order_dt > 20500101
OR sls_order_dt < 19000101

-- SALES DETAILS ****
-- Check for Invalid Date Orders
SELECT 
*
FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt


-- Check Data Consistency : Between Sales , Quantity, and price
-- >> Sales = Quantity * PRice
-- >> Values must not be NULL,Zero or Negative.
SELECT DISTINCT
sls_sales ,
sls_quantity,
sls_price 
FROM silver.crm_sales_details
WHERE sls_sales != sls_quantity*sls_price
OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
OR sls_sales <=0 OR sls_quantity<=0 OR sls_price<=0
ORDER BY sls_sales,sls_quantity,sls_price


SELECT * FROM silver.crm_sales_details



-- Customer AZ Table***

SELECT 
CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid,4,LEN(cid))
	ELSE cid
END AS cid,
bdate,
gen
FROM bronze.erp_cust_az12
WHERE CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid,4,LEN(cid))
	ELSE cid
END NOT IN (SELECT DISTINCT cst_key FROM silver.crm_cust_info)

SELECT * FROM [silver].[crm_cust_info];

-- Identify Out-Of-Range Dates

SELECT DISTINCT 
bdate
FROM silver.erp_cust_az12
WHERE bdate < '1924-01-01' OR bdate > GETDATE()

-- Data Standardization & Consistency
SELECT DISTINCT gen
from silver.erp_cust_az12


SELECT * FROM silver.erp_cust_az12


-- ERP_loc_a101  TABLE***
-- cleaning table erp_loc_a101
SELECT 
REPLACE(cid,'-','')cid,
CASE WHEN TRIM(cntry) ='DE' THEN  'Germany'
	WHEN TRIM(cntry) IN ('US','USA') THEN 'United States'
	WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
	ELSE TRIM (cntry)
END AS cntry
FROM bronze.erp_loc_a101 

-- DATA Standardization & Consistency

SELECT DISTINCT cntry
FROM silver.erp_loc_a101
ORDER BY cntry
SELECT * FROM silver.erp_loc_a101



-- ERP_Px_cat_g1v2 Table***
-- Cleaning the table erp_px_cat_g1v2

SELECT id,cat,subcat,maintenance
FROM bronze.erp_px_cat_g1v2

-- Check for unwanted spaces
SELECT  * FROM bronze.erp_px_cat_g1v2
WHERE cat != TRIM(cat) OR cat != TRIM(cat) OR maintenance != TRIM(maintenance)

-- Data Standardization & Consistency 

SELECT DISTINCT 
subcat FROM bronze.erp_px_cat_g1v2

SELECT * FROM silver.erp_px_cat_g1v2
