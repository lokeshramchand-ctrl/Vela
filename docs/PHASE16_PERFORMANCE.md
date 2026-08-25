# Phase 16: performance qualification at scale

Reproduce: `python -m evaluation.run_performance_benchmark`

All numbers below are from a real run in this development sandbox
(single-threaded, in-process Python, no MongoDB/network I/O involved -
see "What this measures" below), not extrapolated.

| Records | Elapsed | Throughput (rec/s) | Avg latency/record |
|---|---|---|---|
| 50 | 0.00345s | 14,478.9 | 0.069 ms |
| 100 | 0.00667s | 14,981.7 | 0.067 ms |
| 250 | 0.01697s | 14,732.6 | 0.068 ms |
| 500 | 0.03298s | 15,160.8 | 0.066 ms |

Throughput and per-record latency are flat across the measured range - no
degradation from 50 to 500 records. False-match count is 0 and precision
is 1.0 at every scale (`evaluation/test_performance.py`).

## What this measures

`AIEntityMatcher.score_candidate()` + `route_by_confidence_wall()` via
`evaluation.harness.run_evaluation()` - the actual matching/scoring
algorithm, in-process, against `evaluation.dataset.generate_scaled_dataset()`
(TRUE_MATCH-shaped records with realistic candidate competition, the same
shape Wave 8 uses).

## What this does not measure

- **No MongoDB I/O.** No live MongoDB was available in this sandbox
  (same constraint as Phase 6). A real reconciliation run persists
  matches/exceptions and reads candidate pools from Mongo - this number
  is the matching algorithm's own cost, not the full request's.
- **No PDF parsing.** Ingestion (pypdf/pdfplumber extraction) has its own
  cost, not included here - see `statements/pdf_parser.py`; the real
  22-page/210-transaction statement used in `evaluation/test_edge_cases.py`
  parses in well under a second locally, but wasn't formally benchmarked
  at scale.
- **No network/API layer.** FastAPI request handling, auth, rate
  limiting are not included.
- **No batch beyond 500.** The spec allows testing "500 records if
  practical" - it was practical here, so it's included; nothing beyond
  500 was run, and nothing here should be read as implying performance at
  5,000 or 50,000 records without actually measuring it.

## Honest takeaway

The matching algorithm itself is not a throughput bottleneck at any scale
Track 04 (50+ records) requires - by a wide margin. The real-world
bottleneck for a production reconciliation run is almost certainly
MongoDB I/O and PDF parsing, neither of which this phase could measure in
this sandbox (Phase 6's honest caveat applies equally here). A live-Mongo
CI run (`evaluation/test_mongo_integration.py`'s environment) would be the
right place to measure true end-to-end throughput.
