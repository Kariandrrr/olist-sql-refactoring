--step 3: ADD PRIMARY KEYS AND FOREIGN KEYS FOR REMAINING TABLES

-- 1. Add simple primary keys for reference/dimension tables
alter table olist_products_dataset  add constraint pk_products primary key (product_id);
alter table olist_sellers_dataset  add constraint pk_seller primary key (seller_id);


-- CLEAN UP DUPLICATES AND ADD PK 
-- 2. for customers
-- Error [23505] occurs due to duplicate customer_id entries in raw data
delete from olist_customers_dataset a
using olist_customers_dataset b
where a.ctid < b.ctid 
	and a.customer_id = b.customer_id;

alter table olist_customers_dataset add constraint pk_customers primary key (customer_id); 

	
-- 3. Link order items to products and sellers (FK)
alter table olist_order_items_dataset 
add constraint fk_items_product foreign key (product_id)
references olist_products_dataset(product_id)
on delete cascade;

alter table olist_order_items_dataset
add constraint fk_items_seller foreign key (seller_id) 
references olist_sellers_dataset(seller_id)
on delete cascade;


-- 4. for order items (order_id + order_item_id)
delete from olist_order_items_dataset a
using olist_order_items_dataset b
where a.ctid < b.ctid 
  and a.order_id = b.order_id 
  and a.order_item_id = b.order_item_id;

alter table olist_order_items_dataset 
add constraint pk_order_items primary key (order_id, order_item_id);


-- 5. for order payments (order_id + payment_sequential)
delete from olist_order_payments_dataset a
using olist_order_payments_dataset b
where a.ctid < b.ctid 
  and a.order_id = b.order_id 
  and a.payment_sequential = b.payment_sequential;

alter table  olist_order_payments_dataset 
add constraint pk_order_payments primary key (order_id, payment_sequential);


-- 6. for reviews (review_id)
delete from olist_order_reviews_dataset a
using olist_order_reviews_dataset b
where a.ctid < b.ctid 
  and a.review_id = b.review_id;

alter table olist_order_reviews_dataset 
add constraint pk_order_reviews primary key (review_id);


-- 7. for product category translations
delete from  product_category_name_translation a
using product_category_name_translation b
where a.ctid < b.ctid 
  and a.product_category_name = b.product_category_name;

alter table product_category_name_translation 
add constraint pk_category_translation primary key (product_category_name);

