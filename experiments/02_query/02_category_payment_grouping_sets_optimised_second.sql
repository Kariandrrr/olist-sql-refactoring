/*
============================================================================
        Multi-Dimensional Payment & Category Analysis

OPTIMIZATIONS APPLIED:
1. CTE pre-aggregation: reduced joined data to the
   (order_id, product_category_name, payment_type) level before calculating
   higher-level statistics.

2. Simplified distinct counting: replaced COUNT(DISTINCT order_id) with
   COUNT(*) for category + payment-type groups because order uniqueness is
   guaranteed by the order-level pre-aggregation.

3. Separate aggregation branches: replaced GROUPING SETS with independent
   GROUP BY operations for category + payment type, category only, and
   payment type only.

4. UNION ALL consolidation: combined independently calculated aggregation
   levels without the duplicate-removal overhead of UNION.

5. Explicit grouping indicators: replaced GROUPING() with constant flags
   identifying detailed rows, category totals, and payment-type totals.

NOTE:
- Each aggregation level is filtered independently to preserve the semantics
  of the original GROUPING SETS query.
- The median_payment metric is not included because an exact median cannot be
  reconstructed from pre-aggregated payment sums.
============================================================================
*/
EXPLAIN (ANALYSE , BUFFERS , FORMAT JSON)
WITH order_level AS (SELECT oopd.payment_type,
                            opd.product_category_name,
                            ooid.order_id,
                            SUM(oopd.payment_value) AS payment_value
                     FROM olist_order_payments_dataset oopd
                              JOIN olist_order_items_dataset ooid ON ooid.order_id = oopd.order_id
                              JOIN olist_products_dataset opd ON opd.product_id = ooid.product_id
                     GROUP BY oopd.payment_type, opd.product_category_name, ooid.order_id),
     stats AS (SELECT payment_type,
                      product_category_name,
                      COUNT(*)           AS unique_orders,
                      SUM(payment_value) AS total_payment
               FROM order_level
               GROUP BY payment_type, product_category_name
               HAVING SUM(payment_value) > 100000
                  AND COUNT(DISTINCT order_id) > 500),
     combined AS (SELECT product_category_name,
                         payment_type,
                         total_payment,
                         unique_orders,
                         0 AS grouping_category,
                         0 AS grouping_payment
                  FROM stats

                  UNION ALL

                  SELECT product_category_name,
                         NULL::TEXT               AS payment_type,
                         SUM(payment_value)       AS total_payment,
                         COUNT(DISTINCT order_id) AS unique_orders,
                         0                        AS grouping_category,
                         1                        AS grouping_payment
                  FROM order_level
                  GROUP BY product_category_name
                  HAVING SUM(payment_value) > 100000
                     AND COUNT(DISTINCT order_id) > 500

                  UNION ALL

                  SELECT NULL::TEXT               AS product_category_name,
                         payment_type,
                         SUM(payment_value)       AS total_payment,
                         COUNT(DISTINCT order_id) AS unique_orders,
                         1                        AS grouping_category,
                         0                        AS grouping_payment
                  FROM order_level
                  GROUP BY payment_type
                  HAVING SUM(payment_value) > 100000
                     AND COUNT(DISTINCT order_id) > 500)

SELECT product_category_name,
       payment_type,
       total_payment,
       unique_orders,
       grouping_category,
       grouping_payment
FROM combined
ORDER BY grouping_category,
         unique_orders DESC;
EXPLAIN (ANALYSE , BUFFERS , FORMAT JSON)
WITH order_level AS (SELECT oopd.payment_type,
                            opd.product_category_name,
                            ooid.order_id,
                            SUM(oopd.payment_value) AS payment_value
                     FROM olist_order_payments_dataset oopd
                              JOIN olist_order_items_dataset ooid ON ooid.order_id = oopd.order_id
                              JOIN olist_products_dataset opd ON opd.product_id = ooid.product_id
                     GROUP BY oopd.payment_type, opd.product_category_name, ooid.order_id),
     stats AS (SELECT payment_type,
                      product_category_name,
                      COUNT(*)           AS unique_orders,
                      SUM(payment_value) AS total_payment
               FROM order_level
               GROUP BY payment_type, product_category_name
               HAVING SUM(payment_value) > 100000
                  AND COUNT(DISTINCT order_id) > 500),
     combined AS (SELECT product_category_name,
                         payment_type,
                         total_payment,
                         unique_orders,
                         0 AS grouping_category,
                         0 AS grouping_payment
                  FROM stats

                  UNION ALL

                  SELECT product_category_name,
                         NULL::TEXT               AS payment_type,
                         SUM(payment_value)       AS total_payment,
                         COUNT(DISTINCT order_id) AS unique_orders,
                         0                        AS grouping_category,
                         1                        AS grouping_payment
                  FROM order_level
                  GROUP BY product_category_name
                  HAVING SUM(payment_value) > 100000
                     AND COUNT(DISTINCT order_id) > 500

                  UNION ALL

                  SELECT NULL::TEXT               AS product_category_name,
                         payment_type,
                         SUM(payment_value)       AS total_payment,
                         COUNT(DISTINCT order_id) AS unique_orders,
                         1                        AS grouping_category,
                         0                        AS grouping_payment
                  FROM order_level
                  GROUP BY payment_type
                  HAVING SUM(payment_value) > 100000
                     AND COUNT(DISTINCT order_id) > 500)

SELECT product_category_name,
       payment_type,
       total_payment,
       unique_orders,
       grouping_category,
       grouping_payment
FROM combined
ORDER BY grouping_category,
         unique_orders DESC