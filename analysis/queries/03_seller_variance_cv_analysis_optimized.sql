EXPLAIN(ANALYSE , BUFFERS , FORMAT JSON)

WITH seller_stats AS (SELECT seller_id,
                             total_revenue,
                             uq_orders_count,
                             ROUND((stddev_price / avg_price * 100)::NUMERIC, 2) AS cv,
                             variance_price
                      FROM (SELECT ooid.seller_id,
                                   SUM(ooid.price)               AS total_revenue,
                                   COUNT(DISTINCT ooid.order_id) AS uq_orders_count,
                                   STDDEV(ooid.price)            AS stddev_price,
                                   AVG(ooid.price)               AS avg_price,
                                   VARIANCE(ooid.price)          AS variance_price
                            FROM olist_order_items_dataset ooid
                                     JOIN olist_order_payments_dataset oopd
                                          ON ooid.order_id = oopd.order_id
                            GROUP BY ooid.seller_id) calc
                      WHERE total_revenue > 30000
                        AND uq_orders_count > 100
                        AND (stddev_price / avg_price * 100) > 50)

SELECT osd.seller_city,
       osd.seller_state,
       SUM(ss.total_revenue)         AS total_revenue,
       SUM(ss.uq_orders_count)       AS orders_count,
       ROUND(AVG(ss.cv), 2)          AS cv,
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