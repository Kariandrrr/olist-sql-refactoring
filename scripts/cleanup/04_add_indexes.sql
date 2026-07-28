-- PERFORMANCE OPTIMIZATION: INDEXES 

-- search by clients and statuses 
CREATE INDEX IF NOT EXISTS idx_orders_customers ON
olist_orders_dataset(customer_id);

CREATE INDEX IF NOT EXISTS idx_orders_purchase_timestamp ON
olist_orders_dataset(order_purchase_timestamp);


-- speed up join in order 
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON
olist_order_items_dataset(product_id);

CREATE INDEX IF NOT EXISTS idx_order_items_seller_id ON
olist_order_items_dataset(seller_id);


-- speed up product search 
CREATE INDEX IF NOT EXISTS idx_products_category ON
olist_products_dataset(product_category_name);

