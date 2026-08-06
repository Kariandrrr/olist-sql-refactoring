/*
============================================================================
		Sales Performance

OPTIMIZATIONS APPLIED:
1. Session Memory: raised work_mem to prevent disk spilling during sorting
2. Indexing: ensured seller_id index exists for fast JOIN performance
3. CTE pre-aggregation: deduplicated items to (seller_id, order_id) level,
   replacing costly COUNT(DISTINCT) with a simple COUNT()
-- ============================================================================
*/

-- allocate memory for in-RAM sorts and hash aggregations
SET
    work_mem = '16 MB';


-- create B-Tree index on foreign key to speed up JOIN operationsCREATE INDEX idx_olist_order_items_seller_id ON
CREATE INDEX IF NOT EXISTS idx_olist_order_items_seller_id
    ON
        olist_order_items_dataset (seller_id);


WITH unique_order_items AS (SELECT seller_id,
                                   order_id,
                                   SUM(price) AS order_seller_price,
                                   COUNT(*)   AS items_count
                            FROM olist_order_items_dataset
                            GROUP BY seller_id,
                                     order_id)
SELECT osd.seller_city,
       osd.seller_state,
       SUM(uoi.order_seller_price)                                            AS total,
       COUNT(uoi.order_id)                                                    AS uq_orders_count,
       ROUND((SUM(uoi.order_seller_price) / COUNT(uoi.order_id))::NUMERIC, 2) AS avg_order_value,
       ROUND(STDDEV(uoi.order_seller_price / uoi.items_count)::NUMERIC, 2)    AS price_sttdev
FROM olist_sellers_dataset osd
         JOIN unique_order_items uoi ON
    osd.seller_id = uoi.seller_id
GROUP BY
    ROLLUP (osd.seller_state, osd.seller_city)
HAVING SUM(uoi.order_seller_price) > 50000
ORDER BY osd.seller_state NULLS FIRST,
         osd.seller_city NULLS FIRST,
         total DESC;