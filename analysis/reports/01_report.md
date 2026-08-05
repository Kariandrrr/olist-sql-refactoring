# 01/Regional sales query performance optimization

---
Legacy query file: analysis/queries/01_seller_hierarchial_sales_legacy.sql

Optimized query file: analysis/queries/01_seller_hierarchial_sales_optimised.sql

---

### 1. Executive summary

* **Problem:** the query was slow (~609 ms) because postgres was spilling temporary data to disk (`external merge` with 6.7 MB), missing indexes on join keys, and calculating heavy `COUNT(DISTINCT)` and `STDDEV` operations on un-aggregated rows.
* **Solution:** increased session memory (`SET work_mem = '16MB'`), created a B-Tree index on `seller_id`, and rewritten the query using a CTE to pre-aggregate order items (replacing `COUNT(DISTINCT)` with a regular `COUNT`).
* **Result:** the query is now **7.6x faster** (execution time dropped from 608.98 ms to 80.14 ms), and disk spilling was completely eliminated (temp disk usage dropped to 0 blocks).

---

### 2. Benchmark

| Metric                         | Before (legacy)      | After (optimized) | Effect |
|:-------------------------------|:---------------------|:------------------| :--- |
| **Execution time**             | 608.98 ms            | **80.14 ms**      | **-86.8% / 7.6x faster** |
| **Planning time**              | 7.12 ms              | **0.27 ms**       | **-96.2%** |
| **Shared hit blocks (RAM)**    | 0 blocks             | **3,183 blocks**  | Processed directly in RAM cache |
| **Shared read blocks (disk)**  | 4,640 blocks         | **1,457 blocks**  | Reduced disk reads by **68.6%** |
| **Temp disk usage (Spilling)** | 847 blocks (~6.7 MB) | **0 blocks**      | **100% eliminated** |

---

### 3. Bottlenecks

* **[Problem 1]: disk spilling during sorting (`external merge`).** The default `work_mem` limit was too low, forcing postgres to dump intermediate sorting data for the `ROLLUP` step into temporary files on disk (847 blocks).
* **[Problem 2]: high CPU load from `COUNT(DISTINCT)`.** Calculating distinct order IDs over 112,650 rows alongside `STDDEV` forced the database to maintain heavy hash tables across every aggregation level in the `ROLLUP`.
* **[Problem 3]: sequential scans (`Seq Scan`).** Joining `olist_order_items_dataset` and `olist_sellers_dataset` was running full table scans without taking advantage of an index on the `seller_id` foreign key.

---

### 4. Changes applied

* **SQL:** added the `unique_order_items` CTE to group items by `(seller_id, order_id)`. This replaced the slow `COUNT(DISTINCT order_id)` in the main query with a fast `COUNT(order_id)` and allowed postgres to switch to a much faster `HashAgg` strategy.
* **Indexes / DDL:**
```sql
-- Allocate memory for in-RAM sorting
SET work_mem = '16MB';

-- B-Tree index to speed up join operations
CREATE INDEX IF NOT EXISTS idx_olist_order_items_seller_id 
    ON olist_order_items_dataset (seller_id);
```
---
### 5. Implementation comparison

### 5. Implementation Comparison

| Step                     | Legacy execution flow                               | Optimized execution flow                 | Performance impact                           |
|:-------------------------|:----------------------------------------------------|:------------------------------------------------|:---------------------------------------------|
| **1. Preparation**       | Default session settings (`work_mem` = 4MB)         | `SET work_mem = '16MB'`                         | Prepares enough RAM for in-memory operations |
| **2. Indexing**          | No indexes used (sequential scan)                   | B-Tree index lookup on `seller_id`              | Speeds up table joins and lookup time        |
| **3. Pre-aggregation**   | *None* (processes all raw rows)                     | CTE aggregates items to `(seller_id, order_id)` | Reduces row count from `112.6k` to `100k`    |
| **4. Join & Filter**     | `Seq Scan` + `Hash Join` on large dataset           | Indexed `Hash Join` on reduced dataset          | Significant decrease in shared read blocks   |
| **5. Grouping strategy** | `Strategy: Sorted` (requires full sort)             | `Strategy: Mixed` (`HashAgg`)                   | Avoids expensive sorting phase               |
| **6. Aggregation logic** | `COUNT(DISTINCT order_id)` on unaggregated rows     | Simple `COUNT(order_id)` on CTE pairs           | Eliminates heavy CPU hash-table overhead     |
| **7. Data processing**   | **`external merge` sort to disk** (847 temp blocks) | **`quicksort` in RAM** (0 temp blocks)          | **100% elimination of disk I/O spilling**    |
| **8. Final output**      | `608.98 ms` total execution time                    | **`80.14 ms` total execution time**             | **7.6x faster execution (~87% speedup)**     |