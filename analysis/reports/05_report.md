# 05/Seller performance – optimization

Legacy query file: `analysis/queries/05_seller_performance_audit_legacy.sql`

Optimized query file: `analysis/queries/05_seller_performance_audit_optimized.sql`

---

### 1. Executive summary

- **Problem:** the legacy query executed in ~1 079 ms. After filtering sellers with revenue > $1 000 (1 428 sellers), it ran a correlated `LATERAL` join **1 428 times**. Each iteration performed bitmap index scans on order items and repeated index lookups on the products table (over 100 k product lookups in total), generating **512 544 shared-hit blocks**.
- **Solution:** kept the early-filtering CTE (`seller_metrics`) that reduces the set from 112 k order-item rows to 1 428 qualifying sellers. Replaced the expensive `LATERAL` subquery with a single-pass set-based approach using `GROUP BY` + `DISTINCT ON (seller_id)` ordered by category revenue. All category aggregation now happens once instead of once per seller.
- **Result:** the query is now **~4.6× faster** (execution time dropped from **1 078.9 ms to 232.5 ms**, **−78.5 %**). Shared-hit blocks collapsed from **512 k to 6.7 k** (−98.7 %), and the repeated per-seller index scans disappeared.

---

### 2. Benchmark


| Metric                     | Before (legacy) | After (optimized)   | Effect                           |
| -------------------------- | --------------- | ------------------- | -------------------------------- |
| Execution time             | 1 078.936 ms    | **232.508 ms**      | **−78.5 % / ~4.6× faster**     |
| Planning time              | 0.827 ms        | **0.508 ms**        | **−38.6 %**                     |
| Qualifying sellers         | 1 428           | 1 428               | identical                        |
| Rows discarded by HAVING   | 1 667           | 1 667               | same early filter                |
| LATERAL / per-seller loops | **1 428**       | **0** (DISTINCT ON) | eliminated                       |
| Shared hit blocks (RAM)    | **512 544**     | **6 743**           | **−98.7 %**                     |
| Shared read blocks (disk)  | 2 298           | 2 998               | slightly higher (one-time reads) |
| Final sort space used      | 181 KB          | 181 KB              | same                             |
| Pre-aggregation sort space | 12 753 KB       | 12 753 KB           | same                             |
| Temp disk usage (Spilling) | 0 blocks        | 0 blocks            | no spilling                      |

---

### 3. Bottlenecks

- **[Problem 1]**: correlated `LATERAL` join executed **1 428 times** (once per qualifying seller).
- **[Problem 2]**: inside each `LATERAL` iteration a Bitmap Heap Scan on order items + repeated Index Scans on the products table were performed (104 840 product lookups in total).
- **[Problem 3]**: nested aggregation + `ORDER BY SUM(price) DESC LIMIT 1` inside the lateral subquery forced a sort and top-N heapsort on every seller.
- **[Problem 4]**: high buffer-cache pressure — **512 544 shared-hit blocks** caused by the repeated scans.

---

### 4. Changes Applied

- **SQL**:
  1. Early-filtering CTE (`seller_metrics`) that already reduces the working set to 1 428 high-revenue sellers.
  2. Completely replaced the `LEFT JOIN LATERAL (… GROUP BY … ORDER BY SUM(price) DESC LIMIT 1)` construct with a single-pass CTE that aggregates revenue per (seller, category) and then applies `DISTINCT ON (seller_id)` ordered by category revenue.
  3. All joins to order items and products are now performed only against the already-filtered set of sellers.

```sql
-- Key rewrite: set-based top category instead of correlated LATERAL
top_category AS (
    SELECT DISTINCT ON (sm.seller_id)
           sm.seller_id,
           opd.product_category_name AS top_category_name,
           SUM(ooid.price) AS category_revenue
    FROM seller_metrics sm
    JOIN olist_order_items_dataset ooid ON ooid.seller_id = sm.seller_id
    JOIN olist_products_dataset opd ON opd.product_id = ooid.product_id
    GROUP BY sm.seller_id, opd.product_category_name
    ORDER BY sm.seller_id, SUM(ooid.price) DESC
)
```

---

### 5. Implementation comparison


| Step                       | Legacy execution flow                                                                | Optimized execution flow                                                 | Performance impact                  |
| -------------------------- | ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------ | ----------------------------------- |
| 1. Seller filtering        | CTE aggregates all sellers, keeps only those with<br /> revenue > $1000 (1 428 rows) | Same early filter                                                        | Identical cardinality               |
| 2. Top-category extraction | LEFT JOIN LATERAL executed 1 428 times                                               | Single-pass GROUP BY + DISTINCT ON (seller_id)                           | **1 428 loops → 0**                |
| 3. Product lookups         | 104 840 index scans on products table (repeated per seller)                          | One hash join to products for the whole filtered set                     | Dramatic reduction in index lookups |
| 4. Aggregation strategy    | Nested sorted aggregate + top-N heapsort inside each lateral                         | HashAggregate on (seller, category) followed <br />by Unique/DISTINCT ON | Lower CPU and memory pressure       |
| 5. Buffer / I/O pressure   | 512 544 shared-hit blocks                                                            | **6 743 shared-hit blocks**                                              | **~98.7 %**                         |
| 6. Final result            | 1 078.9 ms                                                                           | **232.5 ms**                                                             | **~4.6x faster**                    |
