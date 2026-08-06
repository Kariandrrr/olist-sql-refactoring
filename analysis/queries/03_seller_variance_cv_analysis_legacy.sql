/*
===============================================================================
		Seller variance and coefficient of variation analysis
================================================================================
1. Business objective:
   Identify seller regions (by state and city) with high price dispersion 
   and volatility. Measures seller count, order volume, total revenue, 
   price variance, and coefficient of variation (CV) to detect unusual 
   pricing patterns across regions while retaining state-level sub-totals.

2. Key metrics:
   - seller_city: city where sellers are based (NULL for state sub-totals)
   - seller_state: state code of the seller location
   - is_state_summary: flag (1 if row represents a state sub-total, 0 for city)
   - sellers_count: count of unique active sellers
   - orders_count: count of unique orders fulfilled by sellers
   - total_revenue: total items sales revenue
   - price_variance: statistical sample variance of item prices
   - cv_percent: coefficient of variation (STDDEV / AVG * 100) expressed as %

3. Technical highlights:
   - Grouping sets: uses GROUP BY GROUPING SETS for multi-level aggregation 
     without generating global totals.
   - Advanced dispersion statistics: combines STDDEV(), AVG(), and VARIANCE() 
     to evaluate relative price spread (CV).
   - Complex HAVING filters: filters aggregated groups on multiple criteria:
     revenue (>30k), order volume (>100), and pricing dispersion (CV > 50%).
===============================================================================
*/


SELECT osd.seller_city,
       osd.seller_state,
       GROUPING(osd.seller_city)     AS is_state_summary,
       COUNT(DISTINCT osd.seller_id) AS sellers_count,
       COUNT(DISTINCT ooid.order_id) AS orders_count,
       SUM(ooid.price)               AS total_revenue,
       variance(ooid.price),
       round
       ((stddev(ooid.price) / AVG(ooid.price) * 100):: NUMERIC,
        2
       )                             AS cv
FROM olist_sellers_dataset osd
         JOIN olist_order_items_dataset ooid
              ON
                  osd.seller_id = ooid.seller_id
         JOIN olist_order_payments_dataset oopd
              ON
                  ooid.order_id = oopd.order_id
GROUP BY
    GROUPING SETS ( (osd.seller_state,
                     osd.seller_city),
                    (osd.seller_state)
    )
HAVING SUM(ooid.price) > 30000
   AND COUNT(DISTINCT ooid.order_id) > 100
   AND (stddev(ooid.price) / AVG(ooid.price) * 100) > 50
ORDER BY osd.seller_state ASC,
         is_state_summary DESC,
         total_revenue DESC;
 
 
 
 