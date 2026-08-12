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
