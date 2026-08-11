WITH customer_metrics AS (SELECT ocd.customer_unique_id,
                                 ocd.customer_id,
                                 COUNT(DISTINCT ood.order_id) AS total_orders_count,
                                 COALESCE(SUM(ooid.price), 0) AS lifetime_value
                          FROM olist_customers_dataset ocd
                                   JOIN olist_orders_dataset ood
                                        ON ocd.customer_id = ood.customer_id
                                   LEFT JOIN olist_order_items_dataset ooid
                                             ON ood.order_id = ooid.order_id
                          GROUP BY ocd.customer_unique_id, ocd.customer_id
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
                                       PARTITION BY cm.customer_unique_id
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
