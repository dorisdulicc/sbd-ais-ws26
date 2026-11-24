# Exercise 7: From the log to the lake - Solution

## 0. Why the example fails

The example job calls `read_new(None)` on every run, so it always reads the topic
from the beginning and writes straight into the lake. It never remembers where it stopped.

- 1st run: 2,000,000 records in the lake → PASS
- 2nd run: the same 2,000,000 records are written again → lake has 4,000,000 rows in 8 files
  → `Exactly once: FAIL - 2,000,000 duplicates`

## 1. Decision: Architecture B - "the lake is the truth"

The job finds where it stopped in the lake itself (`lake_position()`), writes each run into
`STAGING` first, and then moves it into the lake in one step (`publish()`, a single rename).

Why B:
- There is only one source of truth: the lake. Data and position cannot get out of step,
  because the position is the data.
- A run is all or nothing: readers only see a run after it is published. A half-written run
  stays in `STAGING`, which nobody reads.
- The lake stays clean: no duplicates are written, so readers don't need any extra logic.

Why not A (state file): the position is saved in a separate file after writing. If the run
stops between writing and `save_state()`, the next run reads the same records again → duplicates.
(Saving the state before writing is worse: a stop in between → records are lost.)

Why not C (remove duplicates when reading): it passes, but only because every reader has to use
the dedup view. Every query pays for it, and the lake keeps growing with duplicate files.

Limitation: B needs a single-step rename. That works on a local filesystem, but cloud object
storage (S3, …) doesn't have one. There you would need a table format like Delta Lake or
Apache Iceberg, whose commit log takes the place of the rename.

## 2. Implementation

```python
def run_once():
    # 1. where did the last run stop? -> ask the lake itself
    start = lake_position()
    # 2. read what is new
    new = read_new(start)
    # 3. write it: first to staging (nobody reads it), then one-step move into the lake
    run = write_files(new, STAGING)
    publish(run)
    # 4. remember where you stopped -> not needed, the lake IS the position
```

## 3. Result

`check_all(run_once)` → **Exactly once after every run: YES**

| # | Situation | Result |
|---|---|---|
| 1 | first run | `lake_position()` is `None` → whole topic copied: 2,000,000 records, 4 files |
| 2 | new records arrive, run again | only the new 100,000 are read → 2,100,000, no duplicates |
| 3 | nothing new, run again | nothing read, nothing written → lake unchanged |
| 4 | run stops **while** writing | right after: `lag 100,000` but `miss 0`, the partial run is only in `STAGING`. Next run reads the same range again → 2,200,000, no duplicates |
| 5 | run stops **after** writing (before publish) | right after: lake is behind by 100,000, nothing missing. Next run redoes it → 2,300,000, no duplicates |

After a stop, the lake can be **behind** (lag), but a record is never **missing** or **doubled**:
the next run always continues exactly where the lake ends.
Situation 5 is where architecture A would have produced 100,000 duplicates.

## 4. Output of `check_all`

```
reset: lake, staging and state deleted

situation                                 in lake  duplicates  missing  not loaded    run  check
-----------------------------------------------------------------------------------------------
1 first run                             2,000,000           0        0           0  45.4s  PASS
2 new records arrive, run again         2,100,000           0        0           0   9.8s  PASS
3 nothing new, run again                2,100,000           0        0           0   1.7s  PASS
4 run stops WHILE writing: right after  2,100,000           0        0     100,000         PASS
  ... then the next run                 2,200,000           0        0           0  10.4s  PASS
5 run stops AFTER writing: right after  2,200,000           0        0     100,000         PASS
  ... then the next run                 2,300,000           0        0           0  12.7s  PASS
-----------------------------------------------------------------------------------------------
Exactly once after every run: YES
```