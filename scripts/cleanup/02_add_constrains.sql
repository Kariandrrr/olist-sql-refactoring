-- step 2: ADD FK CONSTRAINT 

-- Description: 
-- This script establishes relational integrity between the isolated 
-- Olist tables by adding Foreign Key constraints



--1. PK in olist_orders_dataset
alter table olist_orders_dataset 
add constraint pk_orders primary key (order_id)

--2. link items to orders 
alter table olist_order_items_dataset 
add constraint fk_items_order foreign key (order_id)
references olist_orders_dataset(order_id)
on delete cascade;

--3. link payment to orders 
alter table olist_order_payments_dataset 
add constraint fk_paymenent_order foreign key (order_id)
references olist_orders_dataset(order_id)
on delete cascade;

--4. link reviews to orders 
alter table olist_order_reviews_dataset  
add constraint fk_review_order foreign key (order_id)
references olist_orders_dataset(order_id)
on delete cascade;


