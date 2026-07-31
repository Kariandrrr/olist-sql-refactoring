--step 3: ADD PRIMARY KEYS AND FOREIGN KEYS FOR REMAINING TABLES


-- 1. Add simple primary keys for reference/dimension tables
ALTER TABLE olist_products_dataset ADD CONSTRAINT pk_products PRIMARY KEY (product_id);

ALTER TABLE olist_sellers_dataset ADD CONSTRAINT pk_seller PRIMARY KEY (seller_id);


-- CLEAN UP DUPLICATES AND ADD PK 
-- 2. for customers
-- Error [23505] occurs due to duplicate customer_id entries in raw data
DELETE
FROM
	olist_customers_dataset a
		USING olist_customers_dataset b
WHERE
	a.ctid < b.ctid
	AND a.customer_id = b.customer_id;

ALTER TABLE olist_customers_dataset ADD CONSTRAINT pk_customers PRIMARY KEY (customer_id);


-- 3. Link order items to products and sellers (FK)
ALTER TABLE olist_order_items_dataset 
ADD CONSTRAINT fk_items_product FOREIGN KEY (product_id)
REFERENCES olist_products_dataset(product_id)
ON
DELETE
	CASCADE;

ALTER TABLE olist_order_items_dataset
ADD CONSTRAINT fk_items_seller FOREIGN KEY (seller_id) 
REFERENCES olist_sellers_dataset(seller_id)
ON
DELETE
	CASCADE;


-- 4. for order items (order_id + order_item_id)
DELETE
FROM
	olist_order_items_dataset a
		USING olist_order_items_dataset b
WHERE
	a.ctid < b.ctid
	AND a.order_id = b.order_id
	AND a.order_item_id = b.order_item_id;

ALTER TABLE olist_order_items_dataset 
ADD CONSTRAINT pk_order_items PRIMARY KEY (order_id, order_item_id);


-- 5. for order payments (order_id + payment_sequential)
DELETE
FROM
	olist_order_payments_dataset a
		USING olist_order_payments_dataset b
WHERE
	a.ctid < b.ctid
	AND a.order_id = b.order_id
	AND a.payment_sequential = b.payment_sequential;

ALTER TABLE olist_order_payments_dataset 
ADD CONSTRAINT pk_order_payments PRIMARY KEY (order_id, payment_sequential);


-- 6. for reviews (review_id)
DELETE
FROM
	olist_order_reviews_dataset a
		USING olist_order_reviews_dataset b
WHERE
	a.ctid < b.ctid
	AND a.review_id = b.review_id;

ALTER TABLE olist_order_reviews_dataset 
ADD CONSTRAINT pk_order_reviews PRIMARY KEY (review_id);


-- 7. for product category translations
DELETE
FROM
	product_category_name_translation a
		USING product_category_name_translation b
WHERE
	a.ctid < b.ctid
	AND a.product_category_name = b.product_category_name;

ALTER TABLE product_category_name_translation 
ADD CONSTRAINT pk_category_translation PRIMARY KEY (product_category_name);


-- 8. for customers and orders 
ALTER TABLE olist_orders_dataset
  ADD CONSTRAINT fk_orders_customers 
  FOREIGN KEY (customer_id) 
  REFERENCES olist_customers_dataset (customer_id)
  ON
DELETE
	RESTRICT   
  ON
	UPDATE
	CASCADE;


-- 9. for products and their trunslations (fix the problem with values that were not in translator)
UPDATE
	olist_products_dataset
SET
	product_category_name = NULL
WHERE
	product_category_name = ''
	OR TRIM(product_category_name) = '';

SELECT
	DISTINCT p.product_category_name
FROM
	olist_products_dataset p
LEFT JOIN product_category_name_translation t 
       ON
	p.product_category_name = t.product_category_name
WHERE
	p.product_category_name IS NOT NULL
	AND t.product_category_name IS NULL;

INSERT
	INTO
	product_category_name_translation (product_category_name,
	product_category_name_english)
VALUES 
  ('pc_gamer',
'pc_gamer'),
  ('portateis_cozinha_e_preparadores_de_alimentos',
'portable_kitchen_and_food_preparers')
ON
CONFLICT (product_category_name) DO NOTHING;

ALTER TABLE olist_products_dataset
  ADD CONSTRAINT fk_products_category_translation 
  FOREIGN KEY (product_category_name) 
  REFERENCES product_category_name_translation (product_category_name)
  ON
DELETE
	SET
	NULL
  ON
	UPDATE
	CASCADE;