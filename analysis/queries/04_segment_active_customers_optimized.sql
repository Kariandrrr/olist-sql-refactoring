/*
============================================================================
		Customer lifetime value & latest order analysis

OPTIMIZATIONS APPLIED:
1. Early filtering CTE: created customer_metrics to filter customers with >1 order
   before main processing, reducing input from 99k to 3k customers (-97% rows)
2. Replaced correlated LATERAL: removed per-customer subquery execution (2997 loops)
   with window functions (ROW_NUMBER, FIRST_VALUE) in single pass
3. Optimized JOIN strategy: added customer_id to first CTE to avoid redundant
   joins with customers table in second CTE
4. Window function aggregation: used ROW_NUMBER() for latest order + FIRST_VALUE()
   for top category instead of nested ORDER BY ... LIMIT 1 subqueries
============================================================================
*/

WITH customer_metrics AS (SELECT ocd.customer_unique_id,
                                 MIN(ocd.customer_id)         AS customer_id,
                                 COUNT(DISTINCT ood.order_id) AS total_orders_count,
                                 COALESCE(SUM(ooid.price), 0) AS lifetime_value
                          FROM olist_customers_dataset ocd
                                   JOIN olist_orders_dataset ood
                                        ON ocd.customer_id = ood.customer_id
                                   LEFT JOIN olist_order_items_dataset ooid
                                             ON ood.order_id = ooid.order_id
                          GROUP BY ocd.customer_unique_id
                          HAVING COUNT(DISTINCT ood.order_id) > 1),

     latest_order AS (SELECT customer_unique_id,
                             order_id,
                             order_purchase_timestamp,
                             order_amount,
                             top_category
                      FROM (SELECT cm.customer_unique_id,
                                   ood.order_id,
                                   ood.order_purchase_timestamp,
                                   SUM(ooid.price) OVER (PARTITION BY ood.order_id) AS order_amount,


                                   FIRST_VALUE(opd.product_category_name) OVER (
                                       PARTITION BY ood.order_id
                                       ORDER BY ooid.price DESC
                                       )                                            AS top_category,
                                   ROW_NUMBER() OVER (
                                       PARTITION BY cm.customer_unique_id
                                       ORDER BY ood.order_purchase_timestamp DESC
                                       )                                            AS rn
                            FROM customer_metrics cm
                                     JOIN olist_orders_dataset ood
                                          ON ood.customer_id = cm.customer_id
                                     LEFT JOIN olist_order_items_dataset ooid
                                               ON ooid.order_id = ood.order_id
                                     LEFT JOIN olist_products_dataset opd
                                               ON opd.product_id = ooid.product_id
                            WHERE ood.order_status = 'delivered') ranked
                      WHERE ranked.rn = 1)

SELECT cm.customer_unique_id,
       cm.total_orders_count,
       ROUND(cm.lifetime_value::NUMERIC, 2)            AS lifetime_value,

       CASE
           WHEN cm.lifetime_value > 500 THEN 'VIP'
           WHEN cm.lifetime_value >= 200 THEN 'High Value'
           ELSE 'Standard'
           END                                         AS customer_segment,

       lo.order_id                                     AS latest_order_id,
       lo.order_purchase_timestamp                     AS latest_order_date,
       ROUND(COALESCE(lo.order_amount, 0)::NUMERIC, 2) AS latest_order_amount,
       COALESCE(lo.top_category, 'Uncategorized')      AS latest_order_top_category
FROM customer_metrics cm
         LEFT JOIN latest_order lo
                   ON cm.customer_unique_id = lo.customer_unique_id
ORDER BY lifetime_value DESC;
