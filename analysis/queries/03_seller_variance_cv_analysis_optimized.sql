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