# Stage C - Kafka Implementation and Evaluation

## Architecture

The Stage C implementation uses Kafka to decouple the plant's reading production from anomaly detection.

1. The plant publishes each raw reading to the `readings` topic.
2. Each reading uses its `machine_id` as the Kafka message key, so readings from the same machine are routed to the same partition.
3. Detector instances consume `readings` as members of the `guardian-detectors` consumer group.
4. Each detector sends qualifying anomaly events to the `anomalies` topic.
5. Anomaly events also use the machine ID as their key.

The `readings` and `anomalies` topics were each created with 12 partitions and replication factor 1.

## Implementation

### Kafka producer in plant.py

The `KafkaSink` publishes each reading as JSON to the `readings` topic, using `machine_id` as the key. The producer is configured with `acks=all` and idempotence enabled. Delivery callbacks are used to detect delivery errors, and the producer is flushed when the plant shuts down.

### Detector service in detector_service.py

The detector service:

- Consumes from the `readings` topic.
- Uses the shared consumer group `guardian-detectors`.
- Starts at `latest` when the group has no previously committed offset, so a newly started live detector does not replay old readings.
- Sends every received reading through `model.score()`.
- Publishes one JSON anomaly event when the score reaches the model threshold.
- Uses the machine ID as the anomaly event key.

The supplied `model.py` was left unchanged.

## Experiment 1 - Two detector instances

The first Kafka experiment used 60 machines at 10 Hz for 219 seconds.

| Measurement | Result |
|---|---:|
| Readings sent by plant | 131,700 |
| Detector instances | 2 |
| Readings initially processed before plant shutdown | 122,986 |
| Remaining Kafka lag after shutdown | 8,712 |
| Missing readings reported by scoreboard | 0 |
| Out-of-order readings reported by scoreboard | 0 |
| Faults detected | 3 of 3 |
| False alarms | 0 |
| Duplicate anomaly events | 0 |
| p95 reading-to-anomaly latency | 39.36 s |
| Maximum reading-to-anomaly latency | 40.72 s |

The two detectors did not keep up with the incoming rate during the plant run. Kafka retained the unprocessed readings. After the detectors were restarted, they consumed the remaining messages and the lag reached zero.

The scoreboard passed R2 and fault detection, but failed R3 because p95 latency exceeded the required 5 seconds.

## Experiment 2 - Four detector instances

The second experiment used four detector instances in the same consumer group, with the same 12-partition `readings` topic. The plant ran 60 machines at 10 Hz for 180 seconds.

| Measurement | Result |
|---|---:|
| Detector instances | 4 |
| Readings processed according to detector telemetry | 105,455 |
| Missing readings | 0 |
| Out-of-order readings | 0 |
| Faults detected | 3 of 3 |
| False alarms | 0 |
| Duplicate anomaly events | 0 |
| p50 reading-to-anomaly latency | 0.09 s |
| p95 reading-to-anomaly latency | 0.13 s |
| Maximum reading-to-anomaly latency | 0.17 s |

The scoreboard marked all three measurable requirements as passed:

- R2 - Complete and ordered: 0 readings missing and 0 out of order.
- R3 - Fresh detection: p95 latency of 0.13 seconds, below the 5-second requirement.
- Fault detection: all 3 faults found, with 0 false alarms.

The detector workload was distributed across the four instances, although the number of readings processed by each instance was not identical.

## Conclusion

The two-detector experiment showed that Kafka retained readings reliably, but two detector instances were insufficient to meet the latency requirement at the laboratory input rate.

Increasing the detector group to four instances allowed the laboratory experiment to pass R2, R3 and the fault-detection checks. The measured p95 reading-to-anomaly latency was 0.13 seconds.

This demonstrates that the implemented Kafka pipeline meets the measured laboratory requirements in the four-instance experiment. It does not by itself demonstrate that the system can process the projected production workload of 100,000 readings per second; that capacity would require further testing and appropriately provisioned partitions and infrastructure.

## Remaining limitations

The four-detector experiment validates the laboratory workload of 600 readings per second, but the projected production workload of 100,000 readings per second was not tested.

The architecture supports independent consumer groups for additional applications such as the training archive and live dashboard. However, these additional consumers were not implemented or benchmarked as part of this experiment.