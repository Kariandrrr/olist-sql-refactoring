/*
===============================================================================
	Hierarchical Seller Sales Analysis
===============================================================================
1. Business objective:
   Calculate seller revenue, total unique orders, average order value (AOV),
   and price standard deviation broken down by seller region (state and city).
   Includes sub-totals per state and a grand total across the entire company
   for comprehensive hierarchical financial reporting.

2. Key Metrics / Output Columns:
   - seller_state: State code of the seller location (NULL for grand total)
   - seller_city: City name of the seller location (NULL for state sub-totals)
   - total_revenue: Total sales price per group/sub-total
   - unique_orders_count: Count of unique orders
   - avg_order_value: Average order value (Revenue / Unique Orders)
   - price_stddev: Standard deviation of item prices within the group

3. Technical Highlights:
   - Aggregations & Rollups: Uses GROUP BY ROLLUP(seller_state, seller_city) 
     to generate hierarchical aggregations (City -> State -> Grand Total).
   - Post-Aggregation Filtering: Uses HAVING clause to retain high-volume 
     groups with total revenue exceeding 50,000.
   - Statistical Functions: Calculates standard deviation using STDDEV().
===============================================================================
*/


SELECT 
	osd.seller_city, 
	osd.seller_state, 
	sum(ooid.price) AS total, 
	count(DISTINCT ooid.order_id) AS uq_orders_count, 
	round(sum(ooid.price) / count(DISTINCT ooid.order_id), 2) AS avg_order_value, 
	round(stddev(ooid.price), 2) AS price_sttdev
FROM
	olist_sellers_dataset osd
JOIN olist_order_items_dataset ooid 
		ON
	osd.seller_id = ooid.seller_id
GROUP BY 
	ROLLUP(osd.seller_state, osd.seller_city)
HAVING 
	sum(price) > 50000
ORDER BY 
	osd.seller_state ASC NULLS FIRST, 
	osd.seller_city ASC NULLS FIRST,
	total DESC;
 
 
 