-- PERFORMANCE OPTIMIZATION: INDEXES 

-- search by clients and statuses 
create index if not exists idx_orders_customers on olist_orders_dataset(customer_id);
create index if not exists idx_orders_purchase_timestamp on olist_orders_dataset(order_purchase_timestamp);


-- speed up join in order 
create index if not exists idx_order_items_product_id on olist_order_items_dataset(product_id);
create index if not exists idx_order_items_seller_id on olist_order_items_dataset(seller_id);


-- speed up product search 
create index if not exists idx_products_category on olist_products_dataset(product_category_name);

