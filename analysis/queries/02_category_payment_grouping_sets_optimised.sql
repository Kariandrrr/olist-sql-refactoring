/*
============================================================================
		Multi-Dimensional Payment & Category Analysis

OPTIMIZATIONS APPLIED:
1. CTE pre-aggregation: reduced data to order-level (order_id + category + payment_type)
   before main aggregation to lower row count and memory usage.
2. Replaced GROUPING SETS: removed expensive GROUPING SETS + COUNT(DISTINCT) combination
   in favour of UNION ALL with separate GROUP BY blocks for better planner efficiency.
3. Early filtering: introduced `stats` CTE to identify qualifying groups first,
   then applied this filter to all subsequent aggregations instead of post-filtering everything.
4. Simplified aggregation: eliminated the need for heavy sorting before aggregation
   and reduced the volume of data processed by COUNT(DISTINCT).
-- ============================================================================
*/

WITH order_level AS (SELECT oopd.payment_type,
                            opd.product_category_name,
                            ooid.order_id,
                            SUM(oopd.payment_value) AS payment_value
                     FROM olist_order_payments_dataset oopd
                              JOIN olist_order_items_dataset ooid ON ooid.order_id = oopd.order_id
                              JOIN olist_products_dataset opd ON opd.product_id = ooid.product_id
                     GROUP BY oopd.payment_type, opd.product_category_name, ooid.order_id),
     stats AS (SELECT SUM(payment_value)       AS total_payment,
                      payment_type,
                      product_category_name,
                      COUNT(DISTINCT order_id) AS unique_orders
               FROM order_level
               GROUP BY payment_type, product_category_name
               HAVING SUM(payment_value) > 100000
                  AND COUNT(DISTINCT order_id) > 500)
SELECT product_category_name,
       payment_type,
       total_payment,
       unique_orders,
       grouping_category,
       grouping_payment
FROM (SELECT product_category_name,
             payment_type,
             total_payment,
             unique_orders,
             0 AS grouping_category,
             0 AS grouping_payment
      FROM stats
      UNION ALL
      SELECT product_category_name, NULL::TEXT, SUM(payment_value), COUNT(DISTINCT order_id), 0, 1
      FROM order_level
      WHERE (product_category_name, payment_type) IN (SELECT product_category_name, payment_type FROM stats)
      GROUP BY product_category_name
      HAVING SUM(payment_value) > 100000
         AND COUNT(DISTINCT order_id) > 500
      UNION ALL
      SELECT NULL::TEXT, payment_type, SUM(payment_value), COUNT(DISTINCT order_id), 1, 0
      FROM order_level
      WHERE (product_category_name, payment_type) IN (SELECT product_category_name, payment_type FROM stats)
      GROUP BY payment_type
      HAVING SUM(payment_value) > 100000
         AND COUNT(DISTINCT order_id) > 500) combined
ORDER BY grouping_category, unique_orders DESC;