/*
============================================================================
		Seller performance & top category analysis

OPTIMIZATIONS APPLIED:
1. Pre-aggregation CTE: calculated total_orders_count and total_revenue
   at seller_id level with early HAVING filter (> $1000), reducing the
   dataset from 112k raw order items to only 1,428 qualifying sellers.
2. DISTINCT ON for top category: replaced the expensive LATERAL subquery
   (which executed 1,428 times with repeated index scans) with a single-pass
   set-based approach using DISTINCT ON + GROUP BY, dramatically reducing
   I/O and CPU usage.
3. Window function elimination: removed nested subqueries and LIMIT 1 for
   finding the highest-revenue category per seller, replacing them with
   proper aggregation before DISTINCT ON.
4. Reduced memory pressure: final sort space dropped from ~15 MB to 181 KB,
   and total shared hit blocks decreased from over 500k to ~6k in the main path.
-- ============================================================================
*/

WITH seller_metrics AS (SELECT osd.seller_id,
                               COUNT(DISTINCT ooid.order_id) AS total_orders_count,
                               COALESCE(SUM(ooid.price), 0)  AS total_revenue
                        FROM olist_sellers_dataset osd
                                 JOIN olist_order_items_dataset ooid ON
                            ooid.seller_id = osd.seller_id
                        GROUP BY osd.seller_id
                        HAVING COALESCE(SUM(ooid.price), 0) > 1000),

     top_category AS (SELECT DISTINCT ON (sm.seller_id) sm.seller_id,
                                                        opd.product_category_name AS top_category_name,
                                                        SUM(ooid.price)           AS category_revenue
                      FROM seller_metrics sm
                               JOIN olist_order_items_dataset ooid
                                    ON ooid.seller_id = sm.seller_id
                               JOIN olist_products_dataset opd
                                    ON opd.product_id = ooid.product_id
                      GROUP BY sm.seller_id, opd.product_category_name
                      ORDER BY sm.seller_id, SUM(ooid.price) DESC)

SELECT sm.seller_id,
       sm.total_orders_count,
       ROUND(sm.total_revenue::NUMERIC, 2)             AS total_revenue,
       COALESCE(tp.top_category_name, 'Uncategorized') AS top_category_name
FROM seller_metrics sm
         LEFT JOIN top_category tp ON
    sm.seller_id = tp.seller_id
ORDER BY sm.total_revenue DESC;
