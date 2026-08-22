# 11 · Analytics Engine (Phase 13)

Router: `routers/analytics.py`, prefix `/v1/analytics`. All four sub-engines are singletons under `analytics/*.py`, each a thin wrapper around a MongoDB aggregation pipeline.

> ⚠ Every endpoint in this router operates against a single hardcoded constant, `TEST_USER = "user_123"` (`routers/analytics.py`). There is no per-caller data isolation — any authenticated client sees the same "user_123" data regardless of who they are. This is explicitly a testing artifact (matches the `user_id` used by `scripts/mock_seeder.py`), not a multi-tenant design. Do not treat this as a template for how user scoping should work in new endpoints.

## 11.1 Category breakdown — `analytics/spending_patterns.py::get_category_breakdown`

`GET /v1/analytics/patterns/categories?days=30`

```js
[
  { $match: { user_id, timestamp: { $gte: start_date, $lte: end_date } } },
  { $group: { _id: "$category", total_amount: { $sum: "$amount" }, transaction_count: { $sum: 1 } } },
  { $sort: { total_amount: -1 } }
]
```
`start_date`/`end_date` are computed in the router from `days` via `datetime.now(timezone.utc) - timedelta(days=days)` — a negative `days` value (see `test_api.py::test_analytics_categories_negative_days`) produces a `start_date` in the *future*, relative to `end_date=now`, yielding an empty result set rather than an error (the test asserts this is tolerated, accepting either `200` or `422`). Documents with a null/missing `category` are labeled `"Unknown"` in the response.

## 11.2 Top merchants — `analytics/spending_patterns.py::get_merchant_frequency`

`GET /v1/analytics/patterns/merchants?limit=5`

```js
[
  { $match: { user_id } },
  { $group: { _id: "$merchant", visit_count: { $sum: 1 }, total_spent: { $sum: "$amount" } } },
  { $sort: { visit_count: -1 } },
  { $limit: limit }
]
```
Note this is **not time-boxed** (no `timestamp` filter) — it ranks merchants over the entire transaction history for the user, unlike the category breakdown above.

## 11.3 Subscriptions — `analytics/subscriptions.py::identify_active_subscriptions`

`GET /v1/analytics/subscriptions`

```js
[
  { $match: { user_id } },
  { $group: { _id: "$merchant", last_amount: { $last: "$amount" }, last_seen: { $max: "$timestamp" } } },
  { $lookup: { from: "behavior_patterns", localField: "_id", foreignField: "merchant_name", as: "behavior" } },
  { $unwind: "$behavior" },
  { $match: { "behavior.periodicity_score": { $gte: 0.85 } } }
]
```
- Depends entirely on `behavior_patterns` being populated by the (unwired — see [06 · Confidence & Behavioral Intelligence §6.3](./06-confidence-behavioral-intelligence.md#63-phase-6-behavior-engine--behaviourbehavior_enginepy)) `behavior_engine`. In a fresh deployment this `$lookup`/`$unwind` will drop every merchant (empty `behavior` array unwinds to nothing), producing zero subscriptions regardless of actual transaction patterns.
- `$group`'s `$last`/`$max` semantics depend on **input document order to the pipeline**, which MongoDB does not guarantee is chronological unless an explicit `$sort` precedes the `$group` — there is no `$sort` stage before this `$group`, so `last_amount`/`last_seen` are not reliably "the most recent" transaction; they reflect whatever order the collection scan happens to return.
- The router (`routers/analytics.py`) sums `estimated_monthly_cost` across all detected subscriptions for `total_monthly_burn` — this is a nominal sum of last-known bill amounts, not an average or a currency-normalized figure.

## 11.4 Anomaly detection — `analytics/anomaly_detection.py::flag_transaction`

`POST /v1/analytics/anomaly/check?merchant=...&amount=...` (query parameters, despite being a `POST`)

Classic 3-sigma z-score test against the merchant's stored `behavior_patterns` baseline:
```
z = |amount - avg_amount| / std_dev
is_anomaly = z > 3.0
confidence = min(0.99, z / 10.0)
```
- No baseline document, or `std_dev == 0` (e.g., a merchant only ever charges one exact amount, so no variance to compare against) → `{"is_anomaly": false, "reason": "Insufficient baseline data"}` rather than a false positive/negative.
- `confidence` scaling (`z / 10.0`, capped at `0.99`) is a simple heuristic, not a calibrated probability — a z-score of `9.9` maps to `confidence: 0.99`; there's no statistical justification tying this specific divisor to an actual false-positive rate.
- Like subscriptions, this is only meaningful once `behavior_patterns` is populated — currently a manual, out-of-band step.

## 11.5 Month-over-month trend — `analytics/trends.py::calculate_mom_growth`

`GET /v1/analytics/trends/mom`

```python
curr_total = sum(amount) where user_id matches and first-of-current-month <= timestamp < first-of-next-month
prev_total = sum(amount) where user_id matches and first-of-previous-month <= timestamp < first-of-current-month
growth = (curr_total - prev_total) / prev_total * 100   # or 0.0 if prev_total == 0
```
✅ **FIXED** — `prev_total` is now a real aggregation over the previous calendar month, not the previously-hardcoded `15000.0`. A second, adjacent bug was fixed at the same time: the current-month query previously had no upper bound (`timestamp >= first-of-current-month` with no end date), so it would keep summing every future transaction indefinitely instead of stopping at the end of the month — both queries are now correctly bounded. See [Known Issues §16.2](./16-known-issues-tech-debt.md#162-high-previously-security--correctness-with-real-user-impact--all-fixed).

## 11.6 Summary of data dependencies

| Endpoint | Depends on |
|---|---|
| `/patterns/categories` | `transactions` only — works out of the box once transactions exist |
| `/patterns/merchants` | `transactions` only — works out of the box |
| `/subscriptions` | `transactions` **and** `behavior_patterns` — run `POST /v1/pipelines/behavior/run-all` first |
| `/anomaly/check` | `behavior_patterns` only — run `POST /v1/pipelines/behavior/run-all` first |
| `/trends/mom` | `transactions` for both the current and previous calendar month (real query, no longer hardcoded) |
