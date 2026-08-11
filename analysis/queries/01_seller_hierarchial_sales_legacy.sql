/*
===============================================================================
		Hierarchical Seller Sales Analysis
===============================================================================

-- STATUS: LEGACY / UNOPTIMIZED

1. Business objective:
   Calculate seller revenue, total unique orders, average order value, 
   and price standard deviation broken down by seller region (state and city).
   Includes sub-totals per state and a grand total across the entire company
   for comprehensive hierarchical financial reporting.

2. Key metrics:
   - seller_state: state code of the seller location (NULL for grand total)
   - seller_city: city name of the seller location (NULL for state sub-totals)
   - total_revenue: total sales price per group/sub-total
   - unique_orders_count: count of unique orders
   - avg_order_value: average order value (revenue / unique orders)
   - price_stddev: standard deviation of item prices within the group

3. Technical highlights:
   - Aggregations & rollups: uses GROUP BY ROLLUP(seller_state, seller_city) 
     to generate hierarchical aggregations (City -> State -> Grand Total).
   - Post-aggregation filtering: uses HAVING clause to retain high-volume 
     groups with total revenue exceeding 50,000.
   - Statistical functions: calculates standard deviation using STDDEV().
===============================================================================
*/


SELECT osd.seller_city,
       osd.seller_state,
       SUM(ooid.price)                                                       AS total,
       COUNT(DISTINCT ooid.order_id)                                         AS uq_orders_count,
       ROUND((SUM(ooid.price) / COUNT(DISTINCT ooid.order_id)):: NUMERIC, 2) AS avg_order_value,
       ROUND(STDDEV(ooid.price)::NUMERIC, 2)                                 AS price_sttdev
FROM olist_sellers_dataset osd
         JOIN olist_order_items_dataset ooid
              ON
                  osd.seller_id = ooid.seller_id
GROUP BY
    ROLLUP (osd.seller_state, osd.seller_city)
HAVING SUM(ooid.price) > 50000
ORDER BY osd.seller_state NULLS FIRST,
         osd.seller_city NULLS FIRST,
         total DESC;
 
 
 