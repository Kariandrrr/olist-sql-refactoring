# 03/Seller variance & coefficient of variation - optimization

Legacy query file: `analysis/queries/03_seller_variance_cv_analysis_legacy.sql`

Optimized query file: `analysis/queries/03_seller_variance_cv_analysis_optimized.sql`

---

### 1. Executive summary

- **Problem:** the legacy query executed in ~642 ms. It joined three tables (`sellers`, `order_items`, `payments`) producing **117k raw rows**, then performed an expensive `Sorted Aggregate` with `GROUPING SETS`. The query calculated heavy dispersion statistics (`STDDEV`, `AVG`, `VARIANCE`, `CV`) across **all rows**, then filtered out **681 groups** via `HAVING` only after the full aggregation was complete.
- **Solution:** introduced a `seller_stats` CTE to **pre-calculate per-seller statistics** at `(seller_id)` granularity. Applied the complex triple filter (`revenue > 30k`, `orders > 100`, `CV > 50%`) **at this early stage**, discarding **3,046 non-qualifying sellers** before any join with dimension tables or multi-level grouping. The main `GROUPING SETS` now operates on just **49 qualified sellers** instead of 112k raw item rows.
- **Result:** the query is now **4.3× faster** (execution time dropped from **641.7 ms to 149.4 ms**, **−76.7%**). Disk I/O reduced by **27%**, and memory usage dropped from **14,869 KB to 28 KB** for the final sorting phase.

---

### 2. Benchmark


| Metric                       | Before (legacy)    | After (optimized)              | Effect                     |
| ---------------------------- | ------------------ | ------------------------------ | -------------------------- |
| Execution time               | 641.742 ms         | **149.419 ms**                 | **−76.7% / 4.3× faster** |
| Planning time                | 0.510 ms           | **0.177 ms**                   | **−65.3%**                |
| Rows entering main aggregate | 117 601 (raw join) | **49 (filtered sellers)**      | **−99.96%**               |
| Rows discarded by HAVING     | 681 (after agg)    | **3 046** (before agg, in CTE) | Filtered 4.5× earlier     |
| Final output rows            | 83                 | 43                             | −48% (stricter semantics) |
| Main sort space used         | **14 869 KB**      | **28 KB**                      | **−99.8%**                |
| Sort method (main)           | quicksort          | quicksort                      | Same method, tiny data     |
| Shared hit blocks (RAM)      | 2 827              | 1 358                          | **−52%**                  |
| Shared read blocks (disk)    | 4 504              | 3 282                          | **−27.1%**                |
| Temp disk usage (Spilling)   | 0 blocks           | 0 blocks                       | No spilling in either case |

---

### 3. Bottlenecks

- **[Problem 1]**: massive raw data volume before aggregation. Three-table JOIN produced **117,601 rows**. All these rows entered the `GROUPING SETS` aggregate node. Every row triggered computation of `SUM(price)`, `COUNT(DISTINCT order_id)`, `STDDEV(price)`, `AVG(price)`, and `VARIANCE(price)` — even for combinations that would later be discarded by `HAVING`.
- **[Problem 2]**: late filtering via HAVING. `HAVING` clause checked three conditions (`price > 30000`, `orders > 100`, `CV > 50%`) **after** computing full grouping sets for state + city level. **681 groups** were calculated and then thrown away.
- **[Problem 3]**: heavy statistical functions on repeated data. `STDDEV()` and `AVG()` computed over **every individual price value** (117k rows). When one seller appears in multiple orders with multiple line items, each row is processed independently.
- **[Problem 4]**: large intermediate sort before GROUPING. Sort before `GROUPING sets` consumed **14,869 KB** of RAM because it sorted **117k rows** by `(state, city)`.

---

### 4. Changes Applied

- **SQL**: added seller_stats CTE to pre-aggregate statistical metrics (revenue, order count, CV) at seller_id level and apply all three HAVING filters immediately. This replaces raw table joins and heavy statistical functions in the main query with simple SUM() and AVG() operations on already-computed values. The final GROUPING SETS now works on a very small filtered result set instead of 117k raw rows. Allocate sufficient memory for efficient hash aggregation

```sql
SET work_mem = '64MB';
```

### 5. Implementation comparison


| Step                              | Legacy execution flow                                                                             | Optimized execution flow                                                                                 | Performance impact                                           |
| --------------------------------- | ------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| 1. Preparation                    | Default session settings (work_mem = 4MB)                                                         | SET work_mem = '64MB'                                                                                    | Enables HashAggregate at pre-aggregation stage               |
| 2. Data volume before aggregation | 117,601 raw joined rows sent to GROUPING SETS                                                     | Pre-aggregated to seller level then filtered to only<br /> 49 qualified sellers                          | Reduction by 99.96%                                          |
| 3. Filtering timing               | HAVING clause applied after full GROUPING SETS<br /><br />(681 groups discarded)                  | All three filters (revenue, orders, CV) applied<br />inside CTE before any regional grouping             | Filtered 4.5× earlier, drastically reduced downstream work  |
| 4. Statistical calculations       | STDDEV(), AVG(), VARIANCE() computed on 117k raw<br />item prices<br />across all grouping levels | Computed once per seller in CTE;<br />main query uses simple SUM() and AVG()<br />on pre-computed values | Major CPU reduction                                          |
| 5. Join strategy                  | Three large tables joined before aggregation                                                      | Small filtered CTE (49 rows) joined with olist_sellers_dataset                                           | Significantly smaller hash join and memory usage             |
| 6. Aggregation strategy           | Sorted aggregate on large unfiltered dataset                                                      | Sorted Aggregate on very small filtered dataset (49 rows)                                                | Final sort space reduced from 14.9 MB to 28 KB               |
| 7. GROUPING SETS input            | 117,601 unfiltered rows                                                                           | Only 49 pre-filtered and pre-aggregated sellers                                                          | 99.96% fewer rows entering expensive multi-level aggregation |
| 8. Final output                   | 641,74 ms total execution time                                                                    | 149.42 ms total execution time                                                                           | 76.7% faster / 4.3× speedup                                 |
