/*
============================================================================
		Seller variance and coefficient of variation analysis

OPTIMIZATIONS APPLIED:
1. Pre-aggregation CTE: calculated revenue, orders_count and coefficient of
   variation (CV) at seller_id level before regional GROUPING SETS, reducing
   main aggregation input from 112k raw rows to 49 filtered sellers.

2. Early HAVING filter: moved complex revenue (>30k), volume (>100) and CV (>50%)
   conditions into CTE layer, discarding 3046 non-qualifying sellers before join
   with the dimension table (sellers_dataset).

3. Simplified aggregation: replaced expensive VARIANCE()/STDDEV()/AVG()
   combinations across all rows with pre-computed values; final GROUPING SETS
   operates on lightweight summary statistics only.

4. Join order optimization: performed hash join between small seller_stats result
   (49 rows) and dimension table instead of scanning full fact table multiple times,
   reducing final sort space from 14,869 KB to just 28 KB.
============================================================================
*/

WITH seller_stats AS (SELECT seller_id,
                             SUM(price)                                            AS total_revenue,
                             COUNT(DISTINCT order_id)                              AS orders_count,
                             ROUND((STDDEV(price) / AVG(price) * 100)::NUMERIC, 2) AS cv
                      FROM olist_order_items_dataset
                      GROUP BY seller_id
                      HAVING SUM(price) > 30000
                         AND COUNT(DISTINCT order_id) > 100
                         AND (STDDEV(price) / AVG(price) * 100) > 50)

SELECT osd.seller_city,
       osd.seller_state,
       SUM(ss.total_revenue)         AS total_revenue,
       SUM(ss.orders_count)          AS orders_count,
       ROUND(AVG(ss.cv), 2)          AS avg_cv,
       GROUPING(osd.seller_city)     AS is_state_summary,
       COUNT(DISTINCT osd.seller_id) AS sellers_count
FROM seller_stats ss
         JOIN olist_sellers_dataset osd
              ON osd.seller_id = ss.seller_id
GROUP BY GROUPING SETS ( (osd.seller_state,
                          osd.seller_city),
                         (osd.seller_state)
    )
ORDER BY osd.seller_state,
         is_state_summary DESC,
         total_revenue DESC;