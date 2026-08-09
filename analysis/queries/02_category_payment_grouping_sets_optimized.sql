/*
============================================================================
		Multi-Dimensional Payment & Category Analysis

OPTIMIZATIONS APPLIED:
1. Session memory: raised work_mem to 64MB to ensure in-memory sorting and aggregation
2. CTE pre-aggregation: pre-aggregated data to (order_id, product_category_name, payment_type)
   level, reducing row volume entering the GROUPING SETS operation
3. Conditional Median: restricted PERCENTILE_CONT evaluation to detailed rows only
   via CASE WHEN GROUPING() = 0, eliminating overhead on subtotal levels
============================================================================
*/


SET enable_sort = off;
SET work_mem = '64MB';

WITH base_data AS (SELECT oopd.payment_type,
                          ooid.order_id,
                          opd.product_category_name,
                          oopd.payment_value
                   FROM olist_order_items_dataset ooid
                            JOIN olist_order_payments_dataset oopd
                                 ON
                                     ooid.order_id = oopd.order_id
                            JOIN olist_products_dataset opd
                                 ON
                                     ooid.product_id = opd.product_id),
     order_level AS MATERIALIZED (SELECT order_id,
                                         product_category_name,
                                         payment_type,
                                         SUM(payment_value) AS payment_value
                                  FROM base_data
                                  GROUP BY product_category_name, payment_type, order_id)
SELECT product_category_name,
       payment_type,
       SUM(payment_value)              AS total_payment,
       COUNT(DISTINCT order_id)        AS uq_orders,

       CASE
           WHEN GROUPING(product_category_name) = 0 AND GROUPING(payment_type) = 0
               THEN ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY payment_value)::NUMERIC, 2)
           ELSE NULL
           END                         AS median_payment,

       GROUPING(product_category_name) AS grouping_category,
       GROUPING(payment_type)          AS grouping_payment
FROM order_level
GROUP BY GROUPING SETS ( (product_category_name, payment_type),
                         (product_category_name),
                         (payment_type)
    )
HAVING SUM(payment_value) > 100000
   AND COUNT(DISTINCT order_id) > 500
ORDER BY grouping_category,
         uq_orders DESC;

