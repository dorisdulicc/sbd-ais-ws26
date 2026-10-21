## Activity 2.2 — Why Is This Self-Join So Slow?

### Step 1 — Measuring how the join grows

The self-join matches rows when they have the same country. If a country has k people, it contributes k^2 matching pairs, so the total number of matching pairs is the sum of the squared group sizes for all countries.

| Table | Input rows | Join result (`COUNT(*)`) | Execution time |
|---|---:|---:|---:|
| `people_50k` | 50,000 | 275,018,222 | 3.095 s |
| `people_100k` | 100,000 | 1,099,465,608 | 13.522 s |
| `people_200k` | 200,000 | 4,393,956,606 | 56.494 s |

Doubling the input size produces approximately four times as many matching pairs and roughly four times the runtime (quadratic growth). This shows how quickly the self-join becomes expensive as the table grows. The rewritten query on the full million-row table returned 10,983,941,260 matching pairs in about 0.46–0.69 seconds.

### Step 2 — Does an index help?

I created an index on `people_100k(country)` and ran `ANALYZE people_100k`. The indexed query gave the same result, 1,099,465,608 pairs. In my measurements, the original join took 13.522 seconds, while the indexed run took approximately 20.947 seconds.

`EXPLAIN ANALYZE` showed a parallel hash join and parallel index-only scans. The index did not improve performance in this experiment because the query still had to count an enormous number of matching pairs. An index can help locate matching rows, but it can't remove the fundamental cost of producing or counting all those matches. Execution times can also vaary because of caching and paralel execution.

### Step 3 — Rewriting the query

Instead of generating all matching pairs, I counted rows per country and summed the square of each count:

```sql
SELECT SUM(country_count * country_count) AS total_pairs
FROM (
    SELECT country, COUNT(*) AS country_count
    FROM people_100k
    GROUP BY country
) AS country_counts;
```

For `people_100k`, this returned 1,099,465,608, with exaclty matched my self-join result. It took 12.120 milliseconds in my measurement, compared with 13.522 seconds for the original join.

The same rewrite on `people_big` returned 10,983,941,260 pairs. The repeated measurements took approximately 462–695 milliseconds. The rewrite is dramatically faster because it adds the small number of country groups rather than generating billions of matching row pairs.

### Step 4 — Discussion: scalability and efficiency

**Query rewrite versus hardware or indexing.** This experiment showed that improving the algorithm can be much more effective than adding hardware or an index. The rewritten query computes the needed count directly, avoiding the unecessary generation of every pair. More CPU, memory, or faster storage may also reduce execution time, but it does not eliminate quadratic growth in the original join.

**If the business needs the actual pairs.** If every matching pair is genuinely required, the output itself may have billions of rows. A larger machine could help process the workload, but it really can't avoid the cost of producing, transferring, and storing such a large result. So before scaling out, I would check whether the business really needs every pair or whether it can use aggregation, filtering, pagination, or incremental processing. If all pairs are required, a distributed analytical processing system may be more appropriate.

**Limits of a single-node OLTP database.** PostgreSQL is effective for transactional workloads, but a huge analytical self-join can consume CPU, memory, and I/O resources and interfere with other users. For large analytical workloads, a columnar analytical database, data warehouse, or distributed query engine may be more suitable. The right architecture depends on data volume, concurrency, requirements, and whether the workload is transactional or analytical.
