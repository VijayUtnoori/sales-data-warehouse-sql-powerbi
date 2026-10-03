/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process to
    populate the 'silver' schema tables from the 'bronze' schema.
Actions Performed:
    - Truncates Silver tables.
    - Inserts transformed and cleansed data from Bronze into Silver tables.

Parameters:
    None.
    This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC Silver.load_silver;
===============================================================================
*/
--CREATED STORED PROCEDURE
CREATE OR ALTER PROCEDURE silver.load_silver AS 
BEGIN
	DECLARE @start_time DATETIME,@end_time DATETIME
	BEGIN TRY
	PRINT'=============================================';
	PRINT 'LOADING SILVER LAYER';
	PRINT'==============================================';

	PRINT '-------------------------------------------';
	PRINT 'LOAD CRM TABLE';
	PRINT'--------------------------------------------';
	SET @start_time=GETDATE();
	PRINT'>>TRUNCATE TABLE:silver.crm_cust_info'
	TRUNCATE TABLE silver.crm_cust_info;
	PRINT'>>INSERTING DATA INTO:silver.crm_cust_info'
	INSERT INTO silver.crm_cust_info(
		cst_id,
		cst_key,
		cst_firstname,
		cst_lastname,
		cst_marital_status,
		cst_gndr,
		cst_create_date)
	SELECT
	cst_id,
	cst_key,
	 --remove leading and trailing spaces
	TRIM(cst_firstname) AS cst_firstname,
	TRIM(cst_lastname) AS cst_lastname,
	CASE WHEN UPPER(TRIM(cst_marital_status))='M' THEN 'Married'
		 WHEN UPPER(TRIM(cst_marital_status))= 'S' THEN 'Single'
		 ELSE 'n/a' 
	END AS cst_marital_status, --Normlize customer merital status in redable formate
	CASE WHEN UPPER(TRIM(cst_gndr))='F'THEN 'Female'
		WHEN UPPER(TRIM(cst_gndr))='M'THEN 'Male'
		ELSE 'n/a' 
	END AS cst_gndr, --Normlize gender in redable formate
	cst_create_date
	FROM(
		SELECT *,
		ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) AS Ranking
		FROM bronze.crm_cust_info
		WHERE cst_id IS NOT NULL)t
		WHERE ranking=1;--select only recent records per customer

	    SET @end_time=GETDATE();
		PRINT'>>LOAD DURATION: '+ CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR)+'second';
		PRINT'------'



	-----------------------------------------------------------

	PRINT'>>TRUNCATE TABLE:silver.crm_prd_info'
	SET @start_time=GETDATE()
	TRUNCATE TABLE silver.crm_prd_info;
	PRINT'>>INSERTING DATA INTO:silver.crm_prd_info'
	INSERT INTO silver.crm_prd_info(
	prd_id,
	cat_id,
	prd_key,
	prd_nm,
	prd_cost,
	prd_line,
	prd_start_dt,
	prd_end_dt
	)
	SELECT
	prd_id,
	REPLACE(SUBSTRING(prd_key,1,5),'-','_') AS cat_id, --Etracted category id from prd_key
	SUBSTRING(prd_key,7,LEN(prd_key)) AS prd_key,----Etracted product_key from full prd_key
	prd_nm,
	ISNULL(prd_cost,0) AS prd_cost, --handle nulls and negative values using ISNULL replace with 0
	--mapped prd_line with appropriate mearning 
	CASE WHEN UPPER(TRIM(prd_line))='M' THEN 'Mountain'
		 WHEN UPPER(TRIM(prd_line))='R' THEN 'Road'
		 WHEN UPPER(TRIM(prd_line))='S' THEN 'Other Sales'
		 WHEN UPPER(TRIM(prd_line))='T' THEN 'Touring'
		 ELSE 'n/a'
	END prd_line,
	--fix date quality prd_start_dt must be greater then prd_end_dt sing window function LEAD
	CAST(prd_start_dt AS DATE) AS prd_start_dt,
	CAST(LEAD(prd_start_dt) OVER(PARTITION BY prd_key ORDER BY prd_start_dt)-1 AS DATE) AS prd_end_dt
	FROM bronze.crm_prd_info;

	SET @end_time=GETDATE();
	PRINT'>>LOAD DURATION: '+ CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR)+'second';
	PRINT'------'

	-----------------------------------------------------------
	--INSERT clean data into silver
	PRINT'>>TRUNCATE TABLE:silver.crm_cust_info'
	SET @start_time=GETDATE()
	TRUNCATE TABLE silver.crm_sales_details;
	PRINT'>>INSERTING DATA INTO:silver.crm_cust_info '
	INSERT INTO silver.crm_sales_details(
		sls_ord_num,
		sls_prd_key,
		sls_cust_id,
		sls_order_dt,
		sls_ship_dt,
		sls_due_dt,
		sls_sales,
		sls_quantity,
		sls_price
	)
	SELECT 
		sls_ord_num,
		sls_prd_key,
		sls_cust_id,
		--handled invalid dates convert with proper formate
		CASE WHEN sls_order_dt<0 OR LEN(sls_order_dt)!=8 THEN NULL
			ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE) 
		END AS sls_order_dt,
		CASE WHEN sls_ship_dt<0 OR LEN(sls_ship_dt)!=8 THEN NULL
			ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE) 
		END AS sls_ship_dt,
		CASE WHEN sls_due_dt<0 OR LEN(sls_due_dt)!=8 THEN NULL
			ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE) 
		END AS sls_due_dt,
		--handled quality issues in sales,quantity and price
		CASE WHEN sls_sales IS NULL OR sls_sales<=0 OR sls_sales!=sls_quantity*ABS(sls_price)
			 THEN sls_quantity*ABS(sls_price) --handled negative values
			 ELSE sls_sales
		END AS sls_sales,
		sls_quantity,
		CASE WHEN sls_price IS NULL OR sls_price<=0 
			 THEN sls_sales/NULLIF(sls_quantity,0) --handled feature zero values error
			 ELSE sls_price
		END AS sls_price
	FROM bronze.crm_sales_details

	SET @end_time=GETDATE();
	PRINT'>>LOAD DURATION: '+ CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR)+'second';
	PRINT'------'
	----------------------------------------------------

	--INSERT DATA INTO silver.erp_cust_az12
	PRINT'>>TRUNCATE TABLE:silver.erp_cust_az12'
	SET @start_time=GETDATE()
	TRUNCATE TABLE silver.erp_cust_az12;
	PRINT'>>INSERTING DATA INTO:silver.erp_cust_az12'
	INSERT INTO silver.erp_cust_az12(
	cid,
	bdate,
	gen
	)

	SELECT
		CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid,4,LEN(cid))
			ELSE cid
		END AS cid, --Removes NAS from cid maintain the consistancy with customer info cus_key
		CASE WHEN bdate>GETDATE() THEN NULL
			 ELSE bdate --set features birthdate as null
		END AS bdate,
		CASE WHEN UPPER(TRIM(gen)) IN('F','Female') THEN 'Female'
			 WHEN UPPER(TRIM(gen)) IN('M','Male') THEN 'Male'
			 ELSE 'n/a'
		 END AS gen---normlized gender values handled nulls
	FROM bronze.erp_cust_az12;
	SET @end_time=GETDATE();
	PRINT'>>LOAD DURATION: '+ CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR)+'second';
	PRINT'------'
	----------------------------------------------------------
	PRINT'>>TRUNCATE TABLE:silver.erp_loc_a101'
	SET @start_time=GETDATE()
	TRUNCATE TABLE silver.erp_loc_a101;
	PRINT'>>INSERTING DATA INTO:silver.erp_loc_a101'
	INSERT INTO silver.erp_loc_a101(
	cid,
	cntry
	) 

	SELECT
	REPLACE(cid,'-','') AS cid,-- removes '-' to match with customer info
	CASE WHEN TRIM(cntry)='DE' THEN 'Germany'
		 WHEN TRIM(cntry) IN ('USA','US') THEN 'United states'
		 WHEN TRIM(cntry)='' OR cntry IS NULL THEN 'n/a'
		 ELSE TRIM(cntry) --Data normlization handled missing values and in consistancy in country names
	END AS cntry
	FROM bronze.erp_loc_a101;
	SET @end_time=GETDATE();
	PRINT'>>LOAD DURATION: '+ CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR)+'second';
	PRINT'------'

	-----------------------------------------------------
	PRINT'>>TRUNCATE TABLE:silver.erp_px_cat_g1v2'
	SET @start_time=GETDATE()
	TRUNCATE TABLE silver.erp_px_cat_g1v2;
	PRINT'>>INSERTING DATA INTO:silver.erp_px_cat_g1v2'
	INSERT INTO silver.erp_px_cat_g1v2(
		id,
		cat,
		subcat,
		maintenance)
	SELECT 
	id,
	cat,
	subcat,maintenance
	FROM bronze.erp_px_cat_g1v2
	SET @end_time=GETDATE();
	PRINT'>>LOAD DURATION: '+ CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR)+'second';
	PRINT'------'
	END TRY
		BEGIN CATCH
		PRINT'=====================================================';
		PRINT'ERROR OCCURED DURING THE EXCUTION'
		PRINT'Error Message'+ ERROR_MESSAGE();
		PRINT'Error Message'+ CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT'Error Message'+ CAST(ERROR_STATE() AS NVARCHAR);
		PRINT'=====================================================';
	END CATCH
END;


EXEC silver.load_silver


