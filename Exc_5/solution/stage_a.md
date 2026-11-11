# Stage A - PostgreSQL Baseline Experiments

## Objective

The goal of Stage A was to evaluate the existing PostgreSQL-based plant and detector, observe whether the detector could keep up with incoming readings, and investigate missing readings.

## Experiment 1 - Small plant

The first experiment used 20 machines, each producing 10 readings per second.

| Measurement | Result |
|---|---:|
| Machines | 20 |
| Expected input rate | 200 readings/s |
| Readings sent by plant | 21,920 |
| Detector readings processed | 10,506 |
| Readings reported missing | 1,528 |
| Observed detector delay | Approximately 0.2-0.4 s |

A SQL count of the readings for the run returned 21,920, matching the number sent by the plant. This indicates that the readings were stored in PostgreSQL, but the detector did not process all of them.

## Experiment 2 - Full laboratory load

The second experiment used 60 machines producing 10 readings per second each.

| Measurement | Result |
|---|---:|
| Machines | 60 |
| Expected input rate | 600 readings/s |
| Readings sent by plant | 43,200 |
| Detector readings processed | 22,038 |
| Approximate backlog | 21,130 |
| Readings reported missing | 32 |
| Maximum observed delay | Approximately 38.9 s |

The detector could not keep up with the incoming rate. The backlog grew during the experiment and the delay increased a lot.

## Explanation of missing readings

The baseline detector uses an increasing database ID as its checkpoint, but database IDs can be assigned before transactions commit. Transactions can therefore commit in a different order from the order in which their IDs were assigned.

If the detector sees a higher ID and advances its checkpoint before a transaction with a lower ID has committed, that later-committing row can be skipped by a query that only requests IDs greater than the checkpoint.

The SQL row count in the small experiment matched the plant's sent count, so the discrepancy was caused by the polling/checkpoint approach rather than readings being absent from the database.

## Conclusion

The PostgreSQL baseline has two important limitations:

1. The increasing-ID checkpoint can skip readings when transactions commit out of order.
2. At 600 readings per second, the detector cannot keep up- its backlog grows and latency becomes too high.

These observations motivated the architectural comparison in Stage B.