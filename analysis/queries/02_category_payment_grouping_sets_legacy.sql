/*
===============================================================================
		Multi-Dimensional Payment & Category Analysis
===============================================================================

-- STATUS: LEGACY / UNOPTIMIZED


1. Business objective:
   Analyze total payment volume, unique order counts, and median payment value
   across three independent dimensions:
     a) Product category + payment type
     b) Product category only
     c) Payment type only
   This enables financial analysis of payment methods per product segment 
   without using expensive UNION ALL queries.

2. Key metrics:
   - product_category_name: name of the product category (NULL when aggregated)
   - payment_type: method of payment used (NULL when aggregated)
   - is_cat_aggregated: flag (1 if category is aggregated, 0 if present)
   - is_pay_aggregated: flag (1 if payment type is aggregated, 0 if present)
   - total_payment: sum of payment values within the grouping set
   - uq_orders_count: count of unique order IDs
   - median_payment: 50th percentile (median) payment value per group

3. Technical highlights:
   - Multi-dimensional aggregation: uses GROUP BY GROUPING SETS to define
     custom dimensional slices in a single query pass.
   - Aggregation indicators: employs GROUPING() functions to distinguish 
     between natural NULLs and aggregation-generated NULLs.
   - Advanced statistics: uses PERCENTILE_CONT(0.5) WITHIN GROUP for median calculation.
   - Type casting: applies ::numeric casting to double precision percentile 
     results for proper ROUND() execution in PostgreSQL.
===============================================================================
*/


SELECT opd.product_category_name,
       oopd.payment_type,
       GROUPING(opd.product_category_name) AS is_cat_aggaregated,
       GROUPING(oopd.payment_type)         AS is_pay_aggregated,
       SUM(oopd.payment_value)             AS total,
       COUNT(DISTINCT ooid.order_id)       AS uq_orders_count,
       ROUND
       (PERCENTILE_CONT(0.5) WITHIN GROUP (
           ORDER BY oopd.payment_value)::NUMERIC,
        2
       )                                   AS median_payment
FROM olist_order_items_dataset ooid
         JOIN olist_order_payments_dataset oopd
              ON
                  ooid.order_id = oopd.order_id
         JOIN olist_products_dataset opd
              ON
                  ooid.product_id = opd.product_id
GROUP BY
    GROUPING SETS ( (opd.product_category_name,
                     oopd.payment_type),
                    (opd.product_category_name),
                    (oopd.payment_type)
    )
HAVING SUM(oopd.payment_value) > 100000
   AND COUNT(DISTINCT ooid.order_id) > 500
ORDER BY is_cat_aggaregated,
         COUNT(DISTINCT ooid.order_id) DESC;