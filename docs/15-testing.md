# 15 · Testing

## 15.1 Automated suite — `test_api.py`

Single pytest file using FastAPI's `TestClient` against the real `app` object (imported directly from `app.py`), so the module-scoped `client` fixture genuinely triggers the `lifespan` context manager — real MongoDB/Milvus connection attempts happen during test setup, meaning **this suite requires live MongoDB reachable at whatever `.env`/`MONGODB_URI` currently points to; nothing is mocked.** (Milvus is optional at test time — `vector_db.connect` retries then falls back to a `None` client, and every Milvus-dependent code path degrades gracefully rather than crashing.)

✅ **All 15 tests pass** (verified against a real, locally-run MongoDB instance; no failures, xfails, or skips). Previously the entire suite couldn't even collect, because `app.py`'s import chain (`routers.memory` → `memory.memory_manager` → `repositories.profile_repository`) raised `NameError` on a missing `Optional` import — fixed, see [16 · Known Issues §16.1](./16-known-issues-tech-debt.md#161-critical-previously-broke-the-application-or-a-whole-feature--all-fixed).

| Test | Covers | Notes |
|---|---|---|
| `test_health_check` | `GET /health` | Asserts status is `healthy` or `degraded` — never fails purely on service unavailability |
| `test_security_missing_key` | Auth rejection | Asserts `401`/`403` on `POST /v1/categorize` with no key |
| `test_rate_limiter_defense` | SlowAPI 429 on `/v1/categorize` | No longer `xfail` — the rate limit now actually lives on the real handler (previously only a dead-code duplicate route had it) and genuinely triggers `429` after 50 rapid calls. The test resets `limiter` state in a `finally` block afterward, since `TestClient` requests all share one identity (`get_remote_address` sees the same fake host for every request in a session) — without the reset, this test's hits would count against the rate-limit budget of every other test sharing the module-scoped `client` fixture |
| `test_resolution_regex_engine` | `POST /v1/resolve`, parametrized over 4 raw UPI/NEFT/IMPS/POS strings | Only asserts `cleaned_text` key presence, not its actual value — a weak assertion that would pass even if the cleaning logic regressed to producing wrong (but present) output |
| `test_categorize_valid_payload` | `POST /v1/categorize` | Asserts response has `merchant`/`category`/`confidence` keys — passes; the endpoint's `.get()`-on-a-Pydantic-model bug, the `time.timezone.utc` typo, and the placeholder-object Mongo writes are all fixed |
| `test_memory_engine_lifecycle` | `/memory/update` state promotion | Drives a unique merchant through 3 encounters, asserting `EPHEMERAL` then `TEMPORARY` |
| `test_confidence_evaluator_blocks_hallucinations` | Confidence wall | Straightforward, matches implementation |
| `test_analytics_categories_negative_days` | Boundary handling | Accepts either `200` or `422` — deliberately loose |
| `test_analytics_anomaly_check` | Z-score anomaly | Only checks `200` + key presence, not the actual anomaly verdict |
| `test_feedback_triggers_retraining_queue` | `POST /v1/feedback/` | The feedback router is now mounted, so this genuinely exercises the endpoint (previously it 404'd and the `if response.status_code == 200:` guard let the test pass trivially without testing anything) |
| `test_rag_explanation_safety` | `POST /v1/explain` | Accepts `200`, `404`, or `500` — a smoke test confirming the route exists and doesn't hard-crash, not a correctness test |
| `test_observability_endpoints` | Drift stubs | Matches the stub implementation exactly — these remain intentional stubs, see [16 · Known Issues §16.5](./16-known-issues-tech-debt.md#165-whats-intentionally-still-open-productinfra-decisions-not-bugs) |

## 15.2 Manual E2E script — `scripts/test_pipeline.sh`

See [14 · Deployment & Operations §14.6](./14-deployment-operations.md#146-scriptstest_pipelinesh-manual-e2e-smoke-test). This is a curl-driven smoke test intended to be run against a live, already-started server — it is not invoked by CI (no CI configuration files exist anywhere in this repository; there is no `.github/workflows`, `.gitlab-ci.yml`, or equivalent — still on the roadmap).

## 15.3 What is not tested at all

- Rule engine (`engines/rule_engine.py`) has no direct unit test — only indirectly exercised via `/v1/categorize`.
- Feature extractors (`features/*.py`) have no unit tests despite containing the most mathematically dense logic in the codebase (entropy, coefficient of variation, periodicity scoring).
- `behaviour/behavior_engine.py`, `clustering/*`, `embeddings/*`, `milvus/*`, `graphs/graph_builder.py`, `training/*`, `evaluation/metrics.py` have zero automated test coverage. These are now reachable via `/v1/pipelines/*` (see [01 · Architecture §1.9](./01-architecture.md#19-batch-pipelines--now-reachable-via-v1pipelines)) and were manually exercised end-to-end during the fix pass (behavior/run-all, graph/build, and decay/sweep verified against real MongoDB; embeddings/sync and clustering/run verified to fail gracefully without Milvus) — but no `pytest` coverage exists for them yet.
- No test verifies the actual *content* of resolved merchant names, confidence values, or category outputs beyond key presence in several places (noted per-test above) — meaning a logic regression that still returns the right JSON shape would not be caught.
