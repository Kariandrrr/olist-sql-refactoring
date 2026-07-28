-- step 2: ADD FK CONSTRAINT 

-- Description: 
-- This script establishes relational integrity between the isolated 
-- Olist tables by adding Foreign Key constraints



--1. PK in olist_orders_dataset
ALTER TABLE olist_orders_dataset 
ADD CONSTRAINT pk_orders PRIMARY KEY (order_id)


--2. link items to orders 
ALTER TABLE olist_order_items_dataset 
ADD CONSTRAINT fk_items_order FOREIGN KEY (order_id)
REFERENCES olist_orders_dataset(order_id)
ON
DELETE
	CASCADE;


--3. link payment to orders 
ALTER TABLE olist_order_payments_dataset 
ADD CONSTRAINT fk_paymenent_order FOREIGN KEY (order_id)
REFERENCES olist_orders_dataset(order_id)
ON
DELETE
	CASCADE;


--4. link reviews to orders 
ALTER TABLE olist_order_reviews_dataset  
ADD CONSTRAINT fk_review_order FOREIGN KEY (order_id)
REFERENCES olist_orders_dataset(order_id)
ON
DELETE
	CASCADE;
