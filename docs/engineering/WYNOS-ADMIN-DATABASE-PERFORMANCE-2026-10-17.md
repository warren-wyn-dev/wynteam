# Admin payment/history performance evidence

Date: 2026-10-17. This records isolated PostgreSQL measurements, not browser/API latency, concurrency capacity, representative production hardware or an approved production SLO.

## Inputs and method

PostgreSQL 17.11 ran in the disposable `wynos-admin-qa-pg17` container with network `none`, Unix-socket access and tmpfs data. A new uniquely owned database used synthetic fixtures: **100,000 orders, 10,000 buyers, 69,490 payment ledger rows and 213,862 webhook events**. The schema/helpers are representative fixtures; indexes and tested RPC definitions come from the repository. No customer data, live database, secrets or production-backed preview were used.

Each case had an initial invocation, three `EXPLAIN (ANALYZE, BUFFERS, TIMING OFF)` execution samples, and a separate detailed nested plan. Medians below use the three execution samples. Before/after used the same seeded database, indexes and global configuration, with sequential warmed runs. Small differences can reflect shared-runner noise. Time-based seed data were generated relative to this run, so October 14 and October 17 counts/timings must not be mixed.

Baseline and candidate variants passed **74/74 independent oracle checks** and **37/37 complete-response comparisons**, excluding only the volatile top-level `as_of`. Customer-history searches still select matching buyers and aggregate their complete order histories; no lifetime totals, filters, permissions, fields, ordering or pagination were removed.

## Accepted change: local history JIT configuration

Global searches spent 241–294 ms in JIT compilation in detailed baseline plans. Disabling compilation only for `admin_food_customer_history` removed that work. Global database configuration stays unchanged, and PostgreSQL restores the caller's setting when the function returns.

| Case | Before median ms | After median ms |
| --- | ---: | ---: |
| Search by rare order | 329.562 | 83.376 |
| Search with no match | 321.225 | 67.281 |
| Search by buyer UUID | 337.574 | 86.049 |
| Customer list, first page | 63.129 | 67.993 |
| Customer with 2,010 orders | 3.898 | 4.229 |

The measured improvement applies to global searches. No gain is claimed for unfiltered lists or selected-buyer paths. Selected-buyer cases remain roughly 3–4 ms; list cases remain roughly 62–71 ms. This changes compilation overhead, not asymptotic scan cost. The maintained **45-assertion** payment/customer fixture passes through the corrected CI wrapper after the source change, including authorization, redaction, pagination and rollback/reapply.

## Rejected monitor candidate

Combining three indexed webhook lookups into one ordered array aggregate reduced an ordinary 365-day monitor case from 721.406 to 523.969 ms. However, when 25 orders each had 10,000 recent events, the same candidate regressed from **9.634 to 96.163 ms** because it read all events instead of stopping near the newest indexed events. Eight edge-semantic checks and four heavy public-response comparisons retained parity, but parity alone did not establish a safe performance improvement.

That monitor rewrite is **not included**. The existing indexed lookups and full total/review counts remain. No extra index, global JIT or `work_mem` change was made.

## Evidence and limits

Task-local artifacts are in `/workspace/scratch/admin-db/payment-perf-ab-20261017/`: `README.md`, `metadata.json`, `comparison.tsv`, before/after `summary.tsv`, detailed plans, `heavy-comparison.json` and `cleanup.json`. The uniquely owned benchmark database was dropped; the shared QA container remained available for other synthetic fixtures.

Authenticated nonproduction browser/API timing, constrained networks, representative-volume concurrent load, agreed latency/error targets and production monitoring are still required before claiming the whole system is very fast or maximally stable.
