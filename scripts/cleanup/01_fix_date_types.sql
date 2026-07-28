-- step 1: FIX DATA TYPES FOR ORDERS 
--
-- Description: 
-- The raw Olist import stored purchase timestamps and approval times 
-- as VARCHAR(50). This script safely converts them to TIMESTAMP 
-- so we can perform time-series analysis and set up proper constraints


-- 1. order_purchase_timestamp varchar -> timestapm 

ALTER TABLE olist_orders_dataset 
ALTER COLUMN order_purchase_timestamp TYPE timestamp
	USING order_purchase_timestamp::timestamp;


-- 2. order_approved_at vaarchar -> timestamp

ALTER TABLE olist_orders_dataset 
ALTER COLUMN order_approved_at TYPE timestamp
	USING order_approved_at::timestamp;
