# File: `routers/analytics.py`

## Purpose
Exposes Phase 13's spend-analytics capabilities over HTTP: category breakdowns, top merchants, subscriptions, month-over-month trends, and real-time anomaly checks.

## Responsibilities
- Expose all five `/v1/analytics/*` endpoints.
- Compute date ranges from query parameters.
- Delegate all actual computation to the four `analytics/*.py` engine singletons.
- Aggregate/derive small summary fields (like `total_monthly_burn`) at the router layer.

## Imports
| Import | Used for |
|---|---|
| `fastapi.APIRouter, Query` | Router construction; declaring query-parameter defaults/descriptions |
| `typing.List, Dict, Any` | Type hints (not strictly required by any function signature actually used, mostly documentation value) |
| `datetime.datetime, timedelta, timezone` | Computing lookback date ranges |
| `analytics.spending_patterns.spending_patterns` | Category/merchant breakdown engine |
| `analytics.subscriptions.subscription_engine` | Subscription-detection engine |
| `analytics.trends.trend_analyzer` | Month-over-month trend engine |
| `analytics.anomaly_detection.anomaly_detector` | Real-time anomaly-check engine |

## Exports
**`router`** — mounted by `app.py` under prefix `/v1/analytics`.

## Execution Flow
1. On import, `router` is created and `TEST_USER = "user_123"` is declared as a module-level constant.
2. Per-request: each handler computes any needed date range, then delegates to exactly one analytics engine method, occasionally post-processing the result (e.g., summing costs) before returning.

## Functions (plain English)

### `get_category_patterns(days: int = Query(30, ...))`
Bound to `GET /v1/analytics/patterns/categories`. In simple English: "Figure out the date range covering the last N days (default 30), then ask the spending-patterns engine to total up spend and count transactions per category within that window, for our one hardcoded test user."

### `get_top_merchants(limit: int = 5)`
Bound to `GET /v1/analytics/patterns/merchants`. In simple English: "Ask for the top N merchants (default 5) this user has visited most often, across all time — not limited to a recent window."

### `get_subscriptions()`
Bound to `GET /v1/analytics/subscriptions`. In simple English: "Ask the subscription engine which merchants look like recurring subscriptions, then add up their estimated costs into one total, and report both the total and the individual details."

### `get_mom_trends()`
Bound to `GET /v1/analytics/trends/mom`. In simple English: "Figure out the current month and year, then ask the trend analyzer to compute how this month's spending compares to last month's." (As documented elsewhere, the "last month" half of that comparison is currently a hardcoded placeholder inside the engine itself, not a real query — this router has no visibility into that; it just calls the function and returns whatever it gets back.)

### `check_anomaly(merchant: str, amount: float)`
Bound to `POST /v1/analytics/anomaly/check`. In simple English: "Given a merchant name and a transaction amount (both passed as query parameters, not a JSON body, despite this being a POST route), ask the anomaly detector whether this amount looks unusually different from that merchant's typical spending, and pass the verdict straight back."

## Classes
None — no class definitions in this file.

## Interfaces
Not applicable formally — response shapes here are plain dicts/lists, not validated `response_model`s (unlike `routers/v1.py` and `routers/memory.py`), so FastAPI performs no automatic response-shape validation on these endpoints.

## Hooks
Auth dependency attached externally in `app.py`, same as every other router.

## Utilities
None — `TEST_USER` is a constant, not a function.

## Dependencies
`fastapi` (third-party); all four `analytics/*.py` modules (internal).

## Side Effects
All five endpoints are effectively read-only from the caller's perspective (no data is created or modified by anything in this file) — every actual database interaction is a read (aggregation query) performed inside the delegated engine functions.

## Performance Considerations
- `get_category_patterns` and `get_top_merchants` run MongoDB aggregation pipelines against the `transactions` collection — potentially expensive at scale without indexes on `user_id`/`timestamp`/`merchant` (none exist anywhere in this codebase).
- `get_subscriptions` runs a `$lookup` join between `transactions` and `behavior_patterns` — joins are typically the most expensive aggregation stage, and this one has no supporting indexes either.
- `check_anomaly` is the cheapest endpoint here — a single `find_one` against `behavior_patterns`.
- None of these endpoints implement caching — every call recomputes from scratch, even for identical repeated queries.

## Possible Interview Questions
- "Why does `check_anomaly` take `merchant`/`amount` as query parameters instead of a JSON request body, despite being declared as a `POST`?" (A design inconsistency — nothing prevents a `POST` from using query params, but it's unusual and inconsistent with the JSON-body convention used by every other `POST` endpoint in this codebase; worth discussing what a more RESTful design would look like.)
- "Why does `get_top_merchants` not accept a date-range parameter the way `get_category_patterns` does?" (An inconsistency in the API design — one endpoint offers a lookback window, the sibling endpoint answering a similar 'top X' question doesn't; worth probing whether that's intentional (all-time ranking is meaningful for merchants) or an oversight.)
- "None of these endpoints declare a `response_model`. What's the practical consequence?" (No automatic response validation or OpenAPI schema generation for the exact response shape — clients relying on the auto-generated docs would only see a generic 'any JSON' type for these responses, unlike the strongly-typed responses on `routers/v1.py` and `routers/memory.py`.)
- "Every endpoint here uses a hardcoded `TEST_USER`. If you had to make this multi-tenant tomorrow with minimal changes to `analytics/`, what would you change here?" (Derive the actual authenticated user's ID — which would first require fixing `core/security.py` to resolve a real per-caller identity — and pass that instead of the constant into each already-parameterized engine call; the engine functions in `analytics/` already accept `user_id` as an argument, so no changes would be needed there.)
