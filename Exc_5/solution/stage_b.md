# Stage B - Architectural Decision Record

## Context

The system must process 600 readings per second in the laboratory and be able to scale to 100,000 readings per second in the future.

The requirements are:

- R1 - Scalability: support the laboratory workload and the projected future workload.
- R2 - Completeness and ordering: process every reading, in sequence, for each machine.
- R3 - Detection latency: detect anomalies with p95 latency below 5 seconds.
- R4 - Independent consumers: allow separate consumers, such as the training archive and live dashboard, to receive raw readings without adding load to PostgreSQL or affecting one another.

## Option 1 - Improve PostgreSQL polling

Multiple detector instances could poll separate subsets of machines, distributing the inference workload.

This approach could improve processing throughput and would require relatively few architectural changes, but PostgreSQL would still handle all incoming readings and repeated polling queries. More pollers and independent consumers would also add database load.

The Stage A experiments already showed an extra correctness problem: increasing database IDs are not necessarily committed in ID order. A detector that advances its ID checkpoint can permanently skip a row that commits later with a smaller ID. This would need to be addressed separately.

## Option 2 - Introduce Kafka

The gateways publish readings to Kafka. Each reading uses the machine ID as its message key, so readings from the same machine are routed to the same partition. This allows their order to be preserved within that partition.

Detector instances consume the readings topic as members of one consumer group. Kafka distributes partitions between the instances, allowing processing to scale horizontally.

Other applications, such as a training archive and a live dashboard, can use independent consumer groups. Each group maintains its own offsets and can consume the raw readings independently.

PostgreSQL can remain responsible for the machine registry rather than serving as the central high-volume event transport.

## Decision

I would choose option 2: Kafka, as the central messaging platform.

Kafka provides partition-based parallelism, durable event storage, independent consumer offsets and the ability to replay events. It separetes ingestion from processing and allows additional consumers without requiring each consumer to poll PostgreSQL.

## Capacity estimation

The model requires approximately 3 ms per reading.

The theoretical processing capacity of one detector instance is:

1 / 0.003 = approximately 333 readings/s.

| Workload | Theoretical minimum detector instances |
|---|---:|
| 600 readings/s | 2 |
| 100,000 readings/s | 300 |

These are theoretical minimums. Real deployments need additional capacity for overhead, uneven partition distribution, failures and latency headroom. The number of Kafka partitions must also be enough to support the desired consumer parallelism.

## Tipping point

The experiments do not establish one exact universal throughput threshold at which PostgreSQL polling stops being suitable. They do show that the baseline implementation was already inadequate at the laboratory workload of 600 readings per second: the backlog grew to more than 21,000 readings and the observed delay reached approximately 38.9 seconds.

Multiple PostgreSQL pollers might improve throughput, but database contention, polling overhead and the checkpoint-ordering problem remain concerns. Kafka is therefore the more suitable architecture for the current workload and expected growth.