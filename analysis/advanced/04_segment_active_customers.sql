/*
===============================================================================
		Lifetime Value Segmentation
================================================================================
1. Business objective:
    Segment active Olist customers (more than 1 order) to analyze their 
    Lifetime Value (LTV) alongside metrics from their most recent delivered order 
    (latest order ID, date, order total, and primary product category).

2. Key metrics:
    - customer_unique_id: Unique identifier for the customer
    - total_orders_count: Total number of orders placed by the customer
    - lifetime_value: Total monetary value spent by the customer across all orders
    - customer_segment: Segment classification based on LTV (VIP, High Value, Standard)
    - latest_order_id: ID of the customer's most recent delivered order
    - latest_order_date: Purchase timestamp of the most recent delivered order
    - latest_order_amount: Total purchase amount for the latest delivered order
    - latest_order_top_category: Most expensive product category in the latest order

3. Technical highlights:
    - Common Table Expressions (CTE) for pre-aggregating customer metrics
    - LATERAL JOIN to efficiently extract top-1 latest delivered order details
    - Searched CASE statements for customer segmentation
    - COALESCE for null handling and fallback default values
===============================================================================
*/

WITH customer_metrics AS (
    -- Aggregate total orders and lifetime value for customers with > 1 order
    SELECT
        ocd.customer_unique_id,
        COUNT(DISTINCT ood.order_id) AS total_orders_count,
        COALESCE(SUM(ooid.price), 0) AS lifetime_value
    FROM
        olist_customers_dataset ocd
    JOIN olist_orders_dataset ood 
        ON ocd.customer_id = ood.customer_id
    LEFT JOIN olist_order_items_dataset ooid 
        ON ood.order_id = ooid.order_id
    GROUP BY
        ocd.customer_unique_id
    HAVING
        COUNT(DISTINCT ood.order_id) > 1
)

SELECT
    cm.customer_unique_id,
    cm.total_orders_count,
    ROUND(cm.lifetime_value::NUMERIC, 2) AS lifetime_value,
    
    -- Customer segmentation based on LTV 
    CASE
        WHEN cm.lifetime_value > 500 THEN 'VIP'
        WHEN cm.lifetime_value >= 200 THEN 'High Value'
        ELSE 'Standard'
    END AS customer_segment,
    
    latest_order.order_id AS latest_order_id,
    latest_order.order_purchase_timestamp AS latest_order_date,
    ROUND(COALESCE(latest_order.order_amount, 0)::NUMERIC, 2) AS latest_order_amount,
    COALESCE(latest_order.top_category, 'Uncategorized') AS latest_order_top_category
FROM
    customer_metrics cm
    
    -- Retrieve details of the latest delivered order 
LEFT JOIN LATERAL (
    SELECT
        ood_sub.order_id,
        ood_sub.order_purchase_timestamp,
        SUM(ooid_sub.price) AS order_amount,
        
        -- Subquery to determine the category with the highest price in this order 
        (
            SELECT
                COALESCE(opd.product_category_name, 'Uncategorized')
            FROM
                olist_order_items_dataset ooid_inner
            LEFT JOIN olist_products_dataset opd 
                ON ooid_inner.product_id = opd.product_id
            WHERE
                ooid_inner.order_id = ood_sub.order_id
            ORDER BY
                ooid_inner.price DESC
            LIMIT 1
        ) AS top_category
    
FROM
        olist_customers_dataset ocd_sub
JOIN olist_orders_dataset ood_sub 
        ON
ocd_sub.customer_id = ood_sub.customer_id
LEFT JOIN olist_order_items_dataset ooid_sub 
        ON
ood_sub.order_id = ooid_sub.order_id
WHERE
        ocd_sub.customer_unique_id = cm.customer_unique_id
AND ood_sub.order_status = 'delivered'
GROUP BY
        ood_sub.order_id,
        ood_sub.order_purchase_timestamp
ORDER BY
        ood_sub.order_purchase_timestamp DESC
LIMIT 1
) latest_order ON
TRUE
ORDER BY
    lifetime_value DESC;