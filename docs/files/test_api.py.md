# File: `test_api.py`

## Purpose
The automated pytest suite covering nearly the entire HTTP surface of the application, using FastAPI's `TestClient` against the real, fully-imported `app` object.

## Responsibilities
- Verify system health and security (auth rejection, rate limiting).
- Exercise ingestion/resolution endpoints with parametrized real-world-shaped inputs.
- Exercise the memory state machine's promotion behavior across multiple calls.
- Exercise the confidence wall's rejection behavior.
- Exercise analytics boundary conditions.
- Smoke-test the (unmounted) feedback endpoint and the RAG/observability endpoints.

## Imports
| Import | Used for |
|---|---|
| `pytest` | Test framework, fixtures, `@pytest.mark.parametrize`/`xfail` |
| `fastapi.testclient.TestClient` | Synchronous test client that drives the real ASGI app, including lifespan |
| `uuid` | Generates unique merchant names per test run to avoid state collisions |
| `random` | Generates random transaction IDs |
| `logging` | Narrative test-run logging |
| `app.app` | The FastAPI application under test |

## Exports
None — this is a test module, not intended to be imported elsewhere.

## Execution Flow
1. `pytest` discovers and imports this module, which imports `app` — triggering the entire application import chain (and, notably, whatever import-time failures exist in `repositories/profile_repository.py`, `clustering/cluster_engine.py`, etc., if those modules are transitively reached — though only `app.py`'s actual import graph, which does **not** include `clustering/` or `feedback/`, applies here).
2. The module-scoped `client` fixture wraps `app` in `TestClient(app)`, entering its context manager — this triggers the real `lifespan` (Mongo/Milvus connect) once for the whole test module.
3. Each test function runs against that shared client, in file order unless pytest is configured otherwise.
4. After all tests in the module finish, the fixture's teardown runs, closing the `TestClient` (triggering `lifespan`'s shutdown half).

## Functions (plain English)

### `client()` (pytest fixture, module scope)
In simple English: "Before any test runs, spin up the whole app for real — including connecting to the real databases — and hand every test the same running client. After all tests are done, shut it down." Because it's `scope="module"`, all tests in this file share one running app instance rather than each getting a fresh one.

### `test_health_check(client)`
In simple English: "Hit `/health` and make sure it responds with either `healthy` or `degraded` — not some other unexpected value — and log which one it was." It doesn't require a specific status, just that the endpoint responds sensibly.

### `test_security_missing_key(client)`
In simple English: "Try to categorize a transaction without providing the API key header, and make sure the server says no (401 or 403) instead of letting it through."

### `test_rate_limiter_defense(client)`
Marked `xfail` (expected to fail). In simple English: "Fire 55 rapid categorize requests pretending to come from the same IP address, and check that at some point the server starts saying 'too many requests' (429). We expect this test to fail because the test client doesn't behave like a real network connection, so IP-based rate limiting doesn't reliably kick in here."

### `test_resolution_regex_engine(client, raw_string, expected_match)` (parametrized over 4 inputs)
In simple English: "Send four different realistic noisy bank/UPI text strings to the resolve endpoint, one at a time, and just check that the response includes a `cleaned_text` field — not checking what that cleaned text actually says, just that the field exists."

### `test_categorize_valid_payload(client)`
In simple English: "Send a normal-looking transaction ('paid 500 to swiggy') to the categorize endpoint and check the response has `merchant`, `category`, and `confidence` fields." (This test is expected to fail against the current implementation, since the real handler crashes on a `.get()` call — see `docs/16-known-issues-tech-debt.md`.)

### `test_memory_engine_lifecycle(client)`
In simple English: "Invent a brand-new, never-seen-before merchant name. Report an encounter with it once — it should be `EPHEMERAL` (brand new). Report it two more times (three total). By the third time, it should have been promoted to `TEMPORARY`, since the system requires 3 sightings for that promotion."

### `test_confidence_evaluator_blocks_hallucinations(client)`
In simple English: "Send a prediction of 'Travel' with only 40% confidence, and confirm the system overrides it to 'Unknown' and flags it as a hallucination risk, since 40% is below the 50% trust threshold."

### `test_analytics_categories_negative_days(client)`
In simple English: "Ask for a category breakdown using a nonsensical negative number of days, and just make sure the server doesn't crash outright — either a normal 200 response or a 422 validation error is acceptable."

### `test_analytics_anomaly_check(client)`
In simple English: "Check whether a ₹99,999 Uber ride gets flagged as anomalous, and just confirm the endpoint responds successfully with an `is_anomaly` field present — not asserting what that value actually is."

### `test_feedback_triggers_retraining_queue(client)`
In simple English: "Submit a correction (the model said 'Unknown', a human said it should be 'Travel') to the feedback endpoint. If the server responds with success, check that it reports the correction was recorded." Because the feedback router isn't actually mounted in `app.py`, this request 404s, and since the assertion is guarded by `if response.status_code == 200:`, the test passes trivially without ever really checking anything.

### `test_rag_explanation_safety(client)`
In simple English: "Ask the system to explain a 'Swiggy order' transaction, and just confirm it responds with one of a few acceptable status codes (200, 404, or 500) — a smoke test to make sure the endpoint doesn't hang or throw an unhandled server error type outside that set."

### `test_observability_endpoints(client)`
In simple English: "Hit both observability stub endpoints and confirm they respond with their expected canned behavior — success for the drift-trigger, and either 200 or 404 for the report-fetch (which today is always 404)."

## Classes
None.

## Interfaces
Not applicable — no formal interfaces; the "contract" being tested is each endpoint's JSON response shape, verified ad hoc per test via dict key/value assertions.

## Hooks
- The `client` **pytest fixture** is the one hook in this file — it wraps setup/teardown around every test function that requests it as a parameter.
- `@pytest.mark.parametrize` is used once, to run `test_resolution_regex_engine` four times with different inputs.
- `@pytest.mark.xfail` is used once, on the rate-limiter test, to mark a known-unreliable test without failing the whole suite.

## Utilities
`HEADERS` and `VALID_API_KEY` are module-level constants (not functions) reused across nearly every test to avoid repeating the auth header setup.

## Dependencies
`pytest`, `fastapi.testclient`, plus the entire application (`app.app`) and therefore transitively every module `app.py` imports.

## Side Effects
- Opens real connections to MongoDB and Milvus for the duration of the test module (via the real `lifespan`).
- `test_memory_engine_lifecycle` writes real `merchant_profiles` documents (with unique, uuid-suffixed names, so it doesn't collide with other test data, but does leave permanent records behind — there's no cleanup step for this test's data).
- `test_feedback_triggers_retraining_queue` would write real `feedback`/`retraining_queue` documents if the endpoint were ever mounted; today it's a no-op due to the 404.
- Test-local logging is configured at `INFO` level with a custom emoji-prefixed format, separate from (but coexisting with) `app.py`'s global `DEBUG` root logger configuration.

## Performance Considerations
- Module-scoped `client` fixture means one shared app instance across all tests — faster than reconnecting per test, but means tests are not fully isolated from each other's side effects (e.g., accumulated test data in Mongo).
- `test_rate_limiter_defense` fires 55 synchronous requests in a loop — the slowest test in the file by request count, though it's expected to fail early or run to completion without ever reaching a stable pass.

## Possible Interview Questions
- "Why is `test_categorize_valid_payload` expected to fail against the current codebase, and how would you discover that without running it?" (Trace `routers/v1.py`'s `categorize_transaction` — the `.get()` call on a Pydantic model raises `AttributeError` before a response can be constructed.)
- "Why does `test_feedback_triggers_retraining_queue` pass even though the feature it's testing is completely unreachable?" (The assertion is nested inside `if response.status_code == 200:`, so a 404 skips the assertion entirely rather than failing.)
- "Why use `uuid.uuid4().hex[:6]` for the merchant name in the memory lifecycle test instead of a fixed name like `'Zomato'`?" (Avoids state leaking between test runs — a fixed name would accumulate frequency across repeated test runs, eventually breaking the `EPHEMERAL`→`TEMPORARY` assertion once it naturally crossed into `PERMANENT` territory.)
- "This suite requires live MongoDB and Milvus to run at all. What are the trade-offs of that versus mocking the databases?" (Higher fidelity/confidence that real behavior is correct, at the cost of needing real infrastructure available in CI/dev, and no isolation between test runs' data.)
