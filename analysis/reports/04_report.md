# 04/Lifetime value segmentation – optimization

Legacy query file: `analysis/queries/04_segment_active_customers_legacy.sql`

Optimized query file: `analysis/queries/04_segment_active_customers_optimized.sql`

---

### 1. Executive summary

- **Problem:** the legacy query took **~16.4 seconds**. After building a `customer_metrics` CTE (~3 000 qualifying customers), it executed a **correlated `LATERAL` join 2 997 times**. Inside each iteration a full sequential scan of the customers table was performed (filtering out ~99 k rows every time) together with nested `ORDER BY … LIMIT 1` subqueries for the top category. This produced **8.77 million shared-hit blocks**.
- **Solution:** kept the early-filtering CTE, but replaced the entire correlated `LATERAL` path with a single-pass window-function approach (`ROW_NUMBER()` for the latest order + `FIRST_VALUE()` for the most expensive category). `customer_id` was carried into the CTE so the customers table is never re-joined. All heavy work is now done once on a dramatically smaller set of rows.
- **Result:** the query is now **~50× faster** (execution time dropped from **16 382 ms to 326 ms**, **−98 %**). Shared-hit blocks collapsed from **8.77 M to 12.5 k**, and the expensive per-customer loops disappeared completely.

---

### 2. Benchmark


| Metric                       | Before (legacy) | After (optimized)        | Effect                           |
| ---------------------------- | --------------- | ------------------------ | -------------------------------- |
| Execution time               | 16 381.952 ms   | **325.845 ms**           | **−98.0 % / ~50× faster**      |
| Planning time                | 1.578 ms        | **0.831 ms**             | **−47 %**                       |
| Qualifying customers         | 2 997           | 2 997                    | identical                        |
| Rows discarded by HAVING     | 93 099          | 93 099                   | same early filter                |
| LATERAL / per-customer loops | **2 997**       | **0** (window functions) | eliminated                       |
| Shared hit blocks (RAM)      | **8 774 283**   | **12 537**               | **−99.86 %**                    |
| Shared read blocks (disk)    | 2 434           | 3 646                    | slightly higher (one-time reads) |
| Final sort space used        | 542 KB          | 538 KB                   | same                             |
| Temp disk usage (Spilling)   | 0 blocks        | 0 blocks                 | no spilling                      |

---

### 3. Bottlenecks

- **[Problem 1]**: correlated `LATERAL` join executed **2 997 times** (once per qualifying customer). Each iteration re-scanned large portions of the data.
- **[Problem 2]**: inside the `LATERAL`, a sequential scan of the entire `olist_customers_dataset` table was performed on every loop, discarding ~99 439 rows each time.
- **[Problem 3]**: nested correlated subquery (`ORDER BY price DESC LIMIT 1`) to obtain the top product category was executed almost 3 000 times.
- **[Problem 4]**: enormous buffer-cache pressure — **8.77 million shared-hit blocks** caused by the repeated scans.

---

### 4. Changes Applied

- **SQL**:
  1. Early-filtering CTE (`customer_metrics`) that already reduces the set from ~99 k to ~3 k customers and now also carries `customer_id`.
  2. Completely replaced the `LEFT JOIN LATERAL (… ORDER BY … LIMIT 1)` construct with a single-pass window-function CTE that uses `ROW_NUMBER()` (latest order) and `FIRST_VALUE()` (top category).
  3. All joins to orders / items / products are now performed only against the already-filtered set of customers.

```sql
-- Key rewrite: window functions instead of correlated LATERAL
ROW_NUMBER() OVER (
    PARTITION BY cm.customer_unique_id
    ORDER BY ood.order_purchase_timestamp DESC
) AS rn,

FIRST_VALUE(opd.product_category_name) OVER (
    PARTITION BY ood.order_id
    ORDER BY ooid.price DESC
) AS top_category
```

---

### 5. Implementation comparison


| Step                       | Legacy execution flow                                                           | Optimized execution flow                                                 | Performance impact                     |
| -------------------------- | ------------------------------------------------------------------------------- | ------------------------------------------------------------------------ | -------------------------------------- |
| 1. Customer filtering      | CTE aggregates all customers, keeps only<br /> those with > 1 order (~3 k rows) | Same early filter + carries customer_id                                  | Identical cardinality, better join key |
| 2. Latest-order extraction | LEFT JOIN LATERAL executed 2 997 times                                          | Single-pass ROW_NUMBER() window function                                 | 2 997 loops → 0                       |
| 3. Top-category extraction | Nested correlated subquery (ORDER BY<br />price DESC LIMIT 1) per order         | FIRST_VALUE(... ORDER BY price DESC) window<br /> function               | No repeated subqueries                 |
| 4. Join strategy           | Inside LATERAL: Seq Scan on full customers<br />table + index lookups           | Hash / Merge joins only against the already-filtered<br />~3 k customers | Massive reduction in scanned rows      |
| 5. Buffer I/O pressure     | 8.77 million shared-hit blocks                                                  | 12.5 thousand shared-hit blocks                                          | **~99.86 %**                           |
| 6. Final result            | 16 382 ms                                                                       | **326 ms**                                                               | **~50x faster**                        |
