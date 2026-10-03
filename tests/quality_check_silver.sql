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
PRINT'========================================='
  TEST CASES RUN DURING DATA  CLEANING 
  PRINT'======================================'


PRINT'======================================='
PRINT'silver.crm_cust_info TEST-CASES'
PRINT'======================================='
SELECT * FROM silver.crm_cust_info;
--Checking Duplicates and nulls
SELECT 
	cst_id,
	COUNT(*) as count_id
FROM silver.crm_cust_info
GROUP BY cst_id 
HAVING COUNT(*)>1 OR cst_id IS NULL;

--CHECK : Check inwanted spaces for all columns 
--expected: NO result should be display
--LIST----
SELECT
cst_key
FROM silver.crm_cust_info
WHERE cst_key != TRIM(cst_key);

SELECT
cst_firstname
FROM silver.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname);

SELECT
cst_lastname
FROM silver.crm_cust_info
WHERE cst_lastname != TRIM(cst_lastname);

SELECT
cst_marital_status
FROM silver.crm_cust_info
WHERE cst_marital_status != TRIM(cst_marital_status);

SELECT
cst_gndr
FROM silver.crm_cust_info
WHERE cst_gndr != TRIM(cst_gndr);

PRINT'======================================='
PRINT'silver.crm_prd_info TEST-CASES'
PRINT'======================================='

---CHECK NULLS AND DUPLICATES
SELECT
prd_id,
COUNT(*) As counting
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*)>1 ;


--check leading and traling spaces
SELECT
	prd_nm
FROM silver.crm_prd_info
WHERE prd_nm!=TRIM(prd_nm);

--Check negative values and nulls
SELECT
	prd_cost
FROM silver.crm_prd_info
WHERE prd_cost<0 OR prd_cost IS NULL;

--Check distinct products
SELECT
	DISTINCT prd_line
FROM silver.crm_prd_info;

--check date quality prd_start_dt must be greater then prd_end_dt
SELECT*
FROM silver.crm_prd_info
WHERE prd_start_dt>prd_end_dt;

----fix date quality prd_start_dt must be greater then prd_end_dt sing window function LEAD
SELECT
	prd_id,
	prd_line,
	prd_start_dt,
	LEAD(prd_start_dt) OVER(PARTITION BY prd_key ORDER BY prd_start_dt)-1 AS prd_end_dt_test,
	prd_end_dt
FROM silver.crm_prd_info;

PRINT'======================================='
PRINT'silver.crm_sales_details TEST-CASES'
PRINT'======================================='

SELECT * FROM silver.crm_sales_details;
---CHECK leading and traling spaces  
SELECT
	sls_ord_num
	sls_prd_key,
	sls_cust_id
FROM silver.crm_sales_details
WHERE sls_ord_num!=TRIM(sls_ord_num);

SELECT
	sls_prd_key
FROM silver.crm_sales_details
WHERE sls_prd_key!=TRIM(sls_prd_key);

--check dates quality acroos 3 dates
SELECT 
NULLIF(sls_order_dt,0) sls_order_dt
FROM silver.crm_sales_details
WHERE sls_order_dt<0    ---dates not negative
OR LEN(sls_order_dt)!=8   --Dates not greater then 8 NUMBERS 
OR sls_order_dt>20250101 --OUTLIERS
OR sls_order_dt<19000101; ----OUTLIERS


--check invalid (date means not possible) 
SELECT 
* FROM silver.crm_sales_details
WHERE sls_order_dt>sls_ship_dt OR sls_order_dt>sls_due_dt;

--Check data consistancy between sales,quantity,price
--sales=quantiy*price
--Values must not ne NULL,ZERO,negative
SELECT
sls_sales,
sls_quantity,
sls_price
FROM silver.crm_sales_details
WHERE sls_sales!=sls_quantity*sls_price
OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
OR sls_sales<=0 OR sls_quantity<=0 OR sls_price<=0;

--Cheking sample
SELECT
sls_sales AS OLD_SALES,
sls_quantity,
sls_price AS OLD_SALES,
CASE WHEN sls_sales IS NULL OR sls_sales<=0 OR sls_sales!=sls_quantity*ABS(sls_price)
     THEN sls_quantity*ABS(sls_price)
	 ELSE sls_sales
END AS sls_sales,
CASE WHEN sls_price IS NULL OR sls_price<=0 
	 THEN sls_sales/NULLIF(sls_quantity,0)
	 ELSE sls_price
END AS sls_price
FROM silver.crm_sales_details;

PRINT'======================================='
PRINT'silver.erp_cust_az12 TEST-CASES'
PRINT'======================================='

SELECT * FROM silver.erp_cust_az12;
--Check valid date
SELECT
	bdate
FROM silver.erp_cust_az12
WHERE bdate<'1920-01-01' OR bdate >GETDATE();

--check consistancy
SELECT distinct(gen)
FROM silver.erp_cust_az12;


PRINT'======================================='
PRINT'silver.erp_loc_a101 TEST-CASES'
PRINT'======================================='

SELECT * FROM silver.erp_loc_a101;

SELECT * FROM silver.crm_cust_info;
--check data consistancy
SELECT DISTINCT(cntry)
FROM silver.erp_loc_a101;


PRINT'======================================='
PRINT'bronze.erp_px_cat_g1v2 TEST-CASES'
PRINT'======================================='
--TRY TO MAKE CONSISTANT 
SELECT * FROM bronze.erp_px_cat_g1v2;
SELECT * FROM silver.crm_prd_info;

--Check leadning and traling spaces
SELECT
cat,
subcat,
maintenance
FROM bronze.erp_px_cat_g1v2
WHERE cat!=TRIM(cat) OR subcat!=TRIM(subcat) OR maintenance!=TRIM(maintenance) 

SELECT DISTINCT subcat FROM bronze.erp_px_cat_g1v2;





