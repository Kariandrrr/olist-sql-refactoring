-- step 1: FIX DATA TYPES FOR ORDERS 
--
-- Description: 
-- The raw Olist import stored purchase timestamps and approval times 
-- as VARCHAR(50). This script safely converts them to TIMESTAMP 
-- so we can perform time-series analysis and set up proper constraints


-- 1. order_purchase_timestamp varchar -> timestapm 

alter table olist_orders_dataset 
alter column order_purchase_timestamp type timestamp 
using order_purchase_timestamp::timestamp;


-- 2. order_approved_at vaarchar -> timestamp

alter table olist_orders_dataset 
alter column order_approved_at type timestamp 
using order_approved_at::timestamp;
