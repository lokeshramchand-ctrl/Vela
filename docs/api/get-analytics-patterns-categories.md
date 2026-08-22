# GET `/v1/analytics/patterns/categories`

## Method
`GET`

## URL
`/v1/analytics/patterns/categories?days=30`

## Purpose
Aggregates a user's total spend and transaction count grouped by category, over a configurable lookback window.

## Authentication
**Required.** `X-Vela-API-Key: Vela_test_key_123`.

## Headers
| Header | Required | Value |
|---|---|---|
| `X-Vela-API-Key` | Yes | `Vela_test_key_123` |

## Request body
None â€” parameters are passed via query string.

## Validation
`days: int = Query(30, description="Lookback window in days")` â€” type-coerced to an integer, **no lower or upper bound declared** (`ge=1` is absent). A negative value is accepted by validation and passed straight into business logic (confirmed by `test_api.py::test_analytics_categories_negative_days`, which explicitly expects this to be tolerated rather than rejected with `422`).

## Response
`200 OK`, a plain JSON array (no `response_model` declared â€” untyped from FastAPI's perspective):
```json
[
  { "category": "Food", "total_amount": 4230.5, "count": 12 },
  { "category": "Travel", "total_amount": 1850.0, "count": 4 },
  { "category": "Unknown", "total_amount": 300.0, "count": 2 }
]
```
Sorted descending by `total_amount`. A `null`/missing category in the underlying data is relabeled `"Unknown"` in the response.

## Error codes
| Code | When |
|---|---|
| `401` | Missing API key |
| `403` | Wrong API key |
| `422` | `days` present but not coercible to an integer (e.g., `days=abc`) |
| `200` (not an error) | Negative `days` â€” tolerated, simply produces an empty or nonsensical-but-non-crashing date range |

## Internal execution flow
```mermaid
sequenceDiagram
    participant C as Client
    participant Ctl as routers/analytics.py::get_category_patterns
    participant Svc as analytics.spending_patterns.spending_patterns
    participant Mongo as MongoDB (transactions)

    C->>Ctl: GET /v1/analytics/patterns/categories?days=30
    Ctl->>Ctl: end_date = now(UTC); start_date = end_date - timedelta(days=30)
    Ctl->>Svc: get_category_breakdown(TEST_USER, start_date, end_date)
    Svc->>Mongo: aggregate([$match(user_id, timestamp range), $group(by category, sum, count), $sort(desc)])
    Mongo-->>Svc: grouped results
    Svc-->>Ctl: [{category, total_amount, count}, ...]
    Ctl-->>C: JSON array
```

## Controller
`get_category_patterns(days: int = Query(30, ...))` in `routers/analytics.py` â€” computes the date range, then delegates.

## Service
`analytics.spending_patterns.spending_patterns.get_category_breakdown(user_id, start_date, end_date)` â€” runs the aggregation pipeline.

## Database queries
```js
db.transactions.aggregate([
  { $match: { user_id: "user_123", timestamp: { $gte: start_date, $lte: end_date } } },
  { $group: { _id: "$category", total_amount: { $sum: "$amount" }, transaction_count: { $sum: 1 } } },
  { $sort: { total_amount: -1 } }
])
```
No index exists on `{user_id, timestamp}` or `category` â€” this runs as a collection scan.

## Example request
```bash
curl -s "http://localhost:8000/v1/analytics/patterns/categories?days=30" \
  -H "X-Vela-API-Key: Vela_test_key_123"
```

## Example response
```json
[
  { "category": "Food", "total_amount": 4230.5, "count": 12 },
  { "category": "Subscription", "total_amount": 998.0, "count": 2 },
  { "category": "Travel", "total_amount": 1850.0, "count": 4 }
]
```

## Interview questions
- "Every request to this endpoint uses `TEST_USER = 'user_123'`, hardcoded in `routers/analytics.py`. What would you need to change to make this multi-tenant?" (Only the router layer â€” derive a real authenticated user ID (requiring `core/security.py` to first resolve one, which it currently doesn't) and pass that instead of the constant; `get_category_breakdown` already accepts `user_id` as a parameter, so the service layer needs no changes.)
- "Why does `days=-5` not get rejected with a `422`?" (The `Query(30, ...)` declaration has no `ge=1` constraint, so any integer passes type validation; a negative value simply produces a `start_date` later than `end_date`, which MongoDB's `$match` handles by matching zero documents rather than erroring.)
- "How would you add pagination if the number of distinct categories grew very large?" (Add `$skip`/`$limit` stages to the aggregation pipeline and corresponding `page`/`page_size` query parameters â€” not currently supported, though in practice the number of categories is naturally bounded and unlikely to need pagination.)
- "Why does this endpoint have no `response_model`, unlike `/v1/resolve` or `/memory/update`?" (An inconsistency in this codebase â€” every `routers/analytics.py` endpoint returns a plain dict/list rather than a validated Pydantic response, meaning the OpenAPI schema for this endpoint is generic/untyped and FastAPI performs no response-shape validation before sending it to the client.)

