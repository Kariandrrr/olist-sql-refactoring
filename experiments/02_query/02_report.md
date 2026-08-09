# 02/Payment & category multi-dimensional analysis - optimization experiments report

**Legacy query file:**
`analysis/queries/02_category_payment_grouping_sets_legacy.sql`

**Experiment 1 file:**
`experiments/02_query/02_category_payment_grouping_sets_optimized_first.sql`

**Experiment 2 file:**
`experiments/02_query/02_category_payment_grouping_sets_optimised_second.sql`

**Status:** experiments failed — returned to optimized GROUPING SETS approach

---

### 1. Executive Summary

**Problem:**
The legacy query using `GROUP BY GROUPING SETS` + `COUNT(DISTINCT)` + `PERCENTILE_CONT()` executed in **763 ms**. While functionally correct, it used a Sorted Aggregate strategy and applied the `HAVING` filter only after computing all grouping levels, leading to unnecessary calculations on discarded groups.

**Optimization attempts:**
Two different pre-aggregation strategies were tested:

- **v1**: early aggregation into `order_level` CTE + `stats` CTE + `UNION ALL` with filtering of subtotal levels through the `stats` result.
- **v2**: similar pre-aggregation, but with fully independent `HAVING` conditions on each subtotal level (no dependency on `stats`).

**Key Finding:**
Both optimization attempts performed **significantly worse** than the original query. Experiment v1 was ~50% slower (1145 ms), and experiment v2 was ~85% slower (1413 ms).

**Conclusion:**
The combination of `GROUPING SETS` + `COUNT(DISTINCT)` turned out to be more efficient in this particular case than
manual decomposition via `UNION ALL`. Pre-aggregation introduced multiple scans of a large intermediate result set and
additional sorting overhead, outweighing any theoretical gains.

**Decision:**
All `UNION ALL` approaches have been archived. Further optimization will continue based on the `GROUPING SETS` pattern
with `MATERIALIZED` CTEs.

---

### 2. Benchmark


| Metric                      | Legacy (GROUPING SETS) | Experiment v2 (UNION ALL + filter) | Experiment v3 (Independent UNION ALL) | Effect vs Legacy    |
| --------------------------- | ---------------------- | ---------------------------------- | ------------------------------------- | ------------------- |
| Execution time              | 763.3 ms               | 1145.0 ms                          | 1412.7 ms                             | +50% / +85%         |
| Planning time               | 1.20 ms                | 5.71 ms                            | 0.95 ms                               | Mixed               |
| Total rows before aggregate | 117 601                | 102 020                            | 102 020                               | -13%                |
| Rows removed by HAVING      | 364                    | 315 + additional                   | 315 + 49 + 0                          | Different logic     |
| Aggregation strategy        | Sorted                 | Mixed (Hash + Sorted)              | Sorted (3 times)                      | Worse               |
| Number of Sort operations   | 1                      | 3                                  | 3                                     | Significantly worse |
| Temp disk usage             | 0 blocks               | 0 blocks                           | 0 blocks                              | No spilling         |
| Shared Hit Blocks           | 3 288                  | 3 288                              | 3 288                                 | Same                |

---

### 3. Bottlenecks Identified

**[Problem 1]: Multiple scans of large CTE (`order_level`)**
Both experiments materialized ~102k rows in `order_level`. This CTE was then scanned **three times** (detail level +
category subtotal + payment_type subtotal). The legacy query read the joined data only once.

**[Problem 2]: Repeated expensive operations**

- `COUNT(DISTINCT order_id)` appeared in all three branches in both experiments.
- Multiple `Sort` nodes were introduced (each sorting ~100k+ rows), whereas legacy used only one sort before the
  multi-level aggregation.

**[Problem 3]: Loss of single-pass optimization**
`GROUPING SETS` allows PostgreSQL to compute all three grouping levels in one aggregation pass. The `UNION ALL` approach
forced three separate aggregation operations, losing this advantage.

**[Problem 4]: Filter semantics changed**

- In v2, subtotal levels were filtered based on combinations that passed the detailed level (`WHERE ... IN stats`). This
  changed the business meaning compared to original `GROUPING SETS`.
- In v3, we restored independent `HAVING`, but this increased the amount of work even further.

**[Problem 5]: Median calculation complexity**
The original query could calculate `PERCENTILE_CONT()` directly. Both experiments dropped the median because it cannot
be accurately computed from pre-aggregated `SUM(payment_value)`.

---

### 4. Changes Attempted

**Common changes in both experiments:**

- Created `order_level` CTE to pre-aggregate data to `(order_id, product_category_name, payment_type)`.
- Replaced `GROUPING SETS` with three separate `GROUP BY` blocks combined via `UNION ALL`.
- Replaced `GROUPING()` function with hardcoded `0/1` flags.

**Differences:**

- **v2**: Used `stats` CTE for early filtering and applied it to subtotal levels via
  `WHERE (category, payment_type) IN (SELECT ...)`.
- **v3**: Removed the dependency on `stats` for subtotals, allowing fully independent `HAVING` conditions on each level.

**Why these changes failed:**
The overhead of multiple CTE scans and repeated sorting/aggregation outweighed the benefits of early filtering and
simplified individual `GROUP BY` clauses.

---

### 5. Implementation Comparison


| Step                 | Legacy (GROUPING SETS)                    | Experiment v2 / v3 (UNION ALL)                    | Impact                |
| -------------------- | ----------------------------------------- | ------------------------------------------------- | --------------------- |
| Data Access          | Single pass over joined tables            | Multiple scans of materialized`order_level` CTE   | Negative              |
| Aggregation Strategy | One Sorted Aggregate with 3 grouping sets | 3 separate Aggregate nodes                        | Negative              |
| Distinct Count       | One`COUNT(DISTINCT)` on multi-level agg   | Multiple`COUNT(DISTINCT)` across branches         | Negative              |
| Median Calculation   | Direct`PERCENTILE_CONT()`                 | Not implemented (impossible without raw values)   | Loss of functionality |
| Filtering (`HAVING`) | Applied once after all groups             | Applied 3 times (with or without cross-filtering) | More complex          |
| Code Complexity      | Very clean and compact                    | Significantly more verbose                        | Negative              |
| Execution Time       | 763 ms                                    | 1145 ms / 1413 ms                                 | -50% to -85%          |

---

### 6. Lessons learned 

1. **GROUPING SETS is not always the villain.** In this dataset and with this query shape, it proved more efficient than manual decomposition using `UNION ALL`.
2. **Pre-aggregation must be used carefully.** If the pre-aggregated CTE is read multiple times, the overhead can easily exceed any savings from simpler `GROUP BY` clauses.
3. **Benchmark before refactoring.** Theoretical improvements (removing `GROUPING SETS`, simplifying `COUNT(DISTINCT)`) did not translate into real performance gains.
4. **Semantic correctness matters.** Version v2 unintentionally changed the meaning of subtotal calculations by filtering them through the detailed level.

**Final decision:**
Both experiments (v1 and v2) are considered **unsuccessful** and have been moved to the `experiments/` folder. We will
now focus on optimizing the original `GROUPING SETS` pattern using `MATERIALIZED CTEs`, increased `work_mem`, and
improved pre-aggregation while preserving median calculation.

---
