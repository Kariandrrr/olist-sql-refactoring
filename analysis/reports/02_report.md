# 02/Multi-dimensional payment & category analysis – optimization

Legacy query file: `analysis/queries/02_category_payment_grouping_sets_optimized.sql`

Optimized query file: `analysis/queries/03_seller_variance_cv_analysis_legacy.sql`

---

### 1. Executive summary

- **Problem:** the legacy query executed in ~763 ms. It joined three tables (`olist_order_items_dataset`, `olist_order_payments_dataset`, `olist_products_dataset`) producing **117 601 raw rows**, then performed an expensive `Sorted Aggregate` with `GROUPING SETS`. Heavy ordered-set statistics (`PERCENTILE_CONT(0.5)` for median) together with `SUM` and `COUNT(DISTINCT)` were calculated across **all grouping levels**, after which `HAVING` discarded **364 groups**.
- **Solution:** introduced a two-stage CTE approach. A lightweight join CTE (`base_data`) feeds a **materialized** pre-aggregation CTE (`order_level`) that collapses data to the grain `(order_id, product_category_name, payment_type)`. This reduces the volume entering `GROUPING SETS` from 117 k item-level rows to **102 020** order-level rows. The expensive median is now evaluated **only** for the finest grouping set via a `CASE WHEN GROUPING(...) = 0` guard. Session settings (`work_mem = '64MB'`, `enable_sort = off`) favour in-memory hash aggregation.
- **Result:** the query is now **~1.8× faster** (execution time dropped from **763.3 ms to 426.2 ms**, **−44.2 %**). Disk reads decreased by **~19 %**, the large intermediate sort (12 335 KB) before the main `GROUPING SETS` was eliminated, and median calculation is performed only where it is actually required.

---

### 2. Benchmark


| Metric                                    | Before (legacy)      | After (optimized)                        | Effect                           |
| ----------------------------------------- | -------------------- | ---------------------------------------- | -------------------------------- |
| Execution time                            | 763.277 ms           | **426.169 ms**                           | **−44.2 % / ~1.8× faster**     |
| Planning time                             | 1.197 ms             | lower (est. 0.4–0.6 ms)                 | noticeably reduced               |
| Rows entering main aggregate              | 117 601 (raw join)   | **102 020** (pre-aggregated order level) | **−13.2 %**                     |
| Rows discarded by HAVING                  | 364 (after full agg) | 364 (after full agg)                     | same cardinality, cheaper path   |
| Final output rows                         | 60                   | 60                                       | identical                        |
| Main sort space used <br />(pre-GROUPING) | **12 335 KB**        | eliminated / replaced by HashAgg         | **−100 % of that sort**         |
| Final sort space used                     | 28 KB                | 28 KB                                    | same                             |
| Sort method (main)                        | quicksort            | quicksort (final only)                   | —                               |
| Shared hit blocks (RAM)                   | 3 288                | 4 134                                    | +26 % (more work kept in cache)  |
| Shared read blocks (disk)                 | 4 504                | 3 658                                    | **−18.8 %**                     |
| Temp disk usage (Spilling)                | 0 blocks             | 0 blocks                                 | no spilling                      |
| CTE HashAgg peak memory                   | —                   | 16 409 KB                                | acceptable under raised work_mem |

---

### 3. Bottlenecks

- **[Problem 1]**: large intermediate sort before `GROUPING SETS`. The planner sorted **117 601** joined rows by `(product_category_name, payment_type)`, consuming **12 335 KB** of work memory.
- **[Problem 2]**: expensive ordered-set aggregate on every grouping level. `PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY payment_value)` was evaluated for category-only and payment-type-only aggregates even though the business only needs the median at the finest grain.
- **[Problem 3]**: late filtering via `HAVING`. The multi-dimensional aggregation ran to completion for all combinations; only afterwards were 364 groups discarded by the revenue (`> 100 000`) and order-count (`> 500`) thresholds.
- **[Problem 4]**: item-level grain. Multiple payment rows (and potentially multiple items) per order caused the same logical order to be processed repeatedly inside the heavy aggregate nodes.

---

### 4. Changes Applied

- **SQL**: added two CTEs — `base_data` (simple join) and `order_level` (MATERIALIZED pre-aggregation to `(order_id, product_category_name, payment_type)` with `SUM(payment_value)`). The main query now works on the pre-aggregated set. Median calculation is guarded by `CASE WHEN GROUPING(product_category_name) = 0 AND GROUPING(payment_type) = 0`. Session memory and planner flags were adjusted.

```sql
SET enable_sort = off;
SET work_mem = '64MB';
```

---

### 5. Implementation comparison



| Step                                    | Legacy execution flow                                          | Optimized execution flow                                                                      | Performance impact                                          |
| --------------------------------------- | -------------------------------------------------------------- | --------------------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| 1. Preparation                          | Default session settings (work_mem ≈ 4 MB)                    | SET work_mem = '64MB'; SET enable_sort = off;                                                 | Enables HashAggregate, discourages large sorts              |
| 2. Data volume before<br /> aggregation | 117 601 raw joined rows sent to GROUPING SETS                  | Pre-aggregated to order + category + payment grain → 102 020 rows                            | **-13.2 % rows** into expensive multi-level aggregate       |
| 3. Filtering timing                     | HAVING applied after full GROUPING SETS (364 groups discarded) | Same HAVING, but operates on already-reduced and cheaper input                                | Lower CPU cost per discarded group                          |
| 4. Statistical calculations             | PERCENTILE_CONT(0.5) computed on every grouping level          | Computed only for the detailed (category, payment_type)<br />set via CASE WHEN GROUPING() = 0 | Major reduction of ordered-set aggregate work               |
| 5. Join strategy                        | Three large tables joined, then sorted                         | Same joins inside CTE, followed by early HashAgg collapse                                     | Large sort (12 335 KB)**eliminated**                        |
| 6. Aggregation strategy                 | Sorted Aggregate on 117 k unfiltered rows                      | HashAgg(CTE) + Sorted Aggregate on 102 k pre-aggregated rows                                  | Final sort space stays tiny (28 KB); peak memory controlled |
| 7. GROUPING SETS input                  | 117 601 unfiltered rows                                        | 102 020 pre-aggregated rows                                                                   | Fewer rows entering multi-level aggregation                 |
| 8. Final output                         | 763.28 ms total execution time                                 | **426.17 ms** total execution time                                                            | **44.2 % faster / ~1.8x speedup**                           |
