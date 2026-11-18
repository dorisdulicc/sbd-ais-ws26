# Exercise 6 - Card Sentinel: CDC with Debezium

## 1. Decision (Part 1)

I choose log-based CDC with Debezium. It is the only option that leaves the
certified payment path completely untouched (R1): no code change, and no extra
queries, because Debezium reads PostgreSQL's write-ahead log instead of the table.
It also delivers every committed payment exactly in commit order (R2), which
polling cannot guarantee (rows that commit out of `id` order are missed) and dual
write cannot either (a crash between commit and send loses the event, a send
before a rollback invents one). The cost is the replication slot: PostgreSQL keeps
all WAL the connector has not read yet, so if the connector is down for long, the
disk fills up and the database, and with it the payment path, stops. In
production I would monitor the WAL retained per slot (`pg_replication_slots`),
the connector status and the consumer lag, alert well before the disk limit, and
cap the risk with `max_slot_wal_keep_size`. If our team owned the payment path, I
would choose the outbox pattern, which is just as correct and does not tie us
to the database's log format.

## 2. The three runs

### Run 1 - Debezium's defaults

**Prediction:** three velocity instances at ~500 payments/s each should be
enough for 1,000 payments/s, so I expected them to share the work and R4 to pass.

**Kafka UI:** 1 partition; key = `{"id": ...}` (the primary key).

**Scoreboard (velocity):**
```
R3  frauds caught          2/7  (29%)   FAIL
R3  false alerts           0    PASS
R4  alert latency p50/p95  65.3 s / 79.7 s   FAIL
```

**Why:** Debezium created the topic with only 1 partition, and inside a consumer
group one partition is read by only one instance. So only `vel-1` got work
(`velocity-agent`: 1 partition, 3 members); `vel-2` and `vel-3` stayed idle.
One instance handles ~500 of 1,000 payments/s, so its lag kept growing (60 → 90 s)
and most frauds were still waiting in the backlog.

### Run 2 - 6 partitions

**Prediction:** now all three instances get two partitions each and keep up, so
R4 should pass. But the key is still the payment id, so the payments of one card
could be spread over several instances, and R3 might fail.

**Scoreboard (velocity):**
```
R3  frauds caught          0/3  (0%)    FAIL
R3  false alerts           0    PASS
R4  no alerts; worst lag of the velocity agents 2.1 s   PASS
```

**Why:** each instance kept up (lag ~1.8 s), so R4 passed. But with the payment
id as key, the partition is `hash(id) mod 6`, so the 12 test payments of a stolen
card were scattered over all partitions. Each instance saw only ~4 of them in its
60-s window, below the threshold of 8, so no instance ever saw the whole attack.
(The anomaly model was ~7 s behind in this run, which I put down to my laptop's
CPU running three busy velocity agents. It is a single instance, so it still sees
every payment.)

### Run 3 - cardholder (`user_id`) as key

**Prediction:** the key becomes `{"user_id": ...}`, all payments of a cardholder
go to the same instance, and both R3 and R4 should pass.

**Kafka UI:** 6 partitions; key = `{"user_id": 168992}`.

**Scoreboard (velocity):**
```
R3  frauds caught          6/6  (100%)  PASS
R3  false alerts           0    PASS
R4  alert latency p50/p95  0.7 s / 1.9 s   PASS
```

**Why:** with `message.key.columns` set to `user_id`, all payments of one
cardholder land in the same partition and are read by the same instance, in commit
order. The velocity model now sees the complete attack and alerts at the 8th
payment, while the three instances still share the load evenly. The anomaly model
also passed (6/6, p95 2.1 s), so all requirements are met.

## 3. Closing question

Debezium chose 1 partition and the primary key as message key. In
production, the single partition would have capped the velocity model at one
instance: the lag would have grown all day, and alerts would have arrived minutes
too late to block a stolen card. Adding instances would not have helped. With the
id as key, the system would have looked healthy (low lag, no errors) after
scaling out, but would silently have caught almost no card-testing fraud. Neither
problem causes a crash or an error message. The team could have noticed by
monitoring consumer lag and idle consumers (members > partitions), by checking
the topic configuration and message key during review, and above all by tracking
the detection rate against confirmed fraud (chargebacks), which would have
dropped as soon as the model was scaled.

## 4. Final connector

See [`fraud-connector.json`](fraud-connector.json).