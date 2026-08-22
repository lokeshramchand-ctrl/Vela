# GET `/v1/analytics/trends/mom`

## Method
`GET`

## URL
`/v1/analytics/trends/mom`

## Purpose
Intended to report month-over-month spending growth. **Currently half-mocked**: the current month's figure is a real query; the previous month's figure is a hardcoded constant.

## Authentication
**Required.** `X-Vela-API-Key: Vela_test_key_123`.

## Headers
| Header | Required | Value |
|---|---|---|
| `X-Vela-API-Key` | Yes | `Vela_test_key_123` |

## Request body
None. No query parameters.

## Validation
Not applicable â€” no inputs.

## Response
`200 OK`, untyped JSON object:
```json
{
  "current_spend": 8213.5,
  "previous_spend": 15000.0,
  "mom_growth_percentage": -45.24,
  "trend": "down"
}
```
`previous_spend` is **always `15000.0`** in the current implementation, regardless of the user's actual historical data.

## Error codes
| Code | When |
|---|---|
| `401` | Missing API key |
| `403` | Wrong API key |
| No error case for zero previous spend | Guarded explicitly (`if prev_total == 0: growth = 0.0`) â€” moot currently since `prev_total` is a fixed non-zero constant, but the guard exists for when this is eventually made real |

## Internal execution flow
```mermaid
sequenceDiagram
    participant C as Client
    participant Ctl as routers/analytics.py::get_mom_trends
    participant Svc as analytics.trends.trend_analyzer
    participant Mongo as MongoDB (transactions)

    C->>Ctl: GET /v1/analytics/trends/mom
    Ctl->>Ctl: now = datetime.now(UTC)
    Ctl->>Svc: calculate_mom_growth(TEST_USER, now.month, now.year)
    Svc->>Svc: curr_start = datetime(year, month, 1)
    Svc->>Mongo: aggregate([$match(user_id, timestamp >= curr_start), $group(sum)])
    Mongo-->>Svc: curr_total
    Svc->>Svc: prev_total = 15000.0  (HARDCODED, not queried)
    Svc->>Svc: growth = (curr - prev) / prev * 100
    Svc-->>Ctl: {current_spend, previous_spend, mom_growth_percentage, trend}
    Ctl-->>C: JSON object
```

## Controller
`get_mom_trends()` in `routers/analytics.py` â€” computes "now," delegates.

## Service
`analytics.trends.trend_analyzer.calculate_mom_growth(user_id, current_month, current_year)`.

## Database queries
```js
db.transactions.aggregate([
  { $match: { user_id: "user_123", timestamp: { $gte: curr_start } } },
  { $group: { _id: null, total: { $sum: "$amount" } } }
])
```
**Only the current month is actually queried.** No query is ever run for the previous month â€” `prev_total = 15000.0` is a Python literal in `analytics/trends.py`, with a code comment reading `# Replace with actual DB query`.

## Example request
```bash
curl -s http://localhost:8000/v1/analytics/trends/mom \
  -H "X-Vela-API-Key: Vela_test_key_123"
```

## Example response
```json
{
  "current_spend": 8213.5,
  "previous_spend": 15000.0,
  "mom_growth_percentage": -45.24,
  "trend": "down"
}
```
**âš  Do not treat this response as reflecting real month-over-month behavior** â€” see Purpose above.

## Interview questions
- "Is the `mom_growth_percentage` this endpoint returns trustworthy?" (No â€” it compares a real current-month total against a hardcoded constant (â‚¹15,000), not the user's actual previous month's spend. This should not be surfaced to end users as real analytics until fixed; see `docs/16-known-issues-tech-debt.md#mom-trend-is-mocked`.)
- "What would the correct fix look like?" (Compute the previous month's start/end date boundaries â€” correctly handling the January-wraps-to-prior-December edge case â€” and run the same kind of aggregation query used for the current month against that range, replacing the `15000.0` literal with the real result.)
- "Why does the function guard against `prev_total == 0`?" (To avoid a `ZeroDivisionError` in the growth-percentage calculation â€” currently unreachable in practice since `prev_total` is a non-zero constant, but the guard would become load-bearing the moment the query is made real, since a user with zero spend in the comparison month is a plausible real scenario.)
- "How would you detect that this endpoint is returning mocked data without reading the source code?" (Call it with two different real users or at two different points in a billing cycle and notice `previous_spend` never changes â€” a fixed, unchanging value across otherwise-varying calls is a strong signal of a hardcoded placeholder; this is exactly the kind of thing integration/contract tests with real assertions on values, rather than just key-presence checks, would catch.)

