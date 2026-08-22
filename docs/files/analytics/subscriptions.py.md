# File: `analytics/subscriptions.py`

## Purpose
Identifies which merchants likely represent recurring subscriptions, by joining transaction history against precomputed periodicity scores.

## Responsibilities
- Join `transactions` with `behavior_patterns` to find merchants with highly regular billing intervals.
- Report each detected subscription's estimated cost and periodicity.

## Imports
| Import | Used for |
|---|---|
| `typing.List, Dict, Any` | Type hints |
| `database.mongo.db` | Running the join aggregation |

## Exports
- **`SubscriptionEngine`** — the class.
- **`subscription_engine`** — the singleton instance, imported by `routers/analytics.py`.

## Execution Flow
On import, `subscription_engine = SubscriptionEngine()` runs trivially. `identify_active_subscriptions(...)` runs one multi-stage aggregation pipeline per call.

## Functions (plain English)

### `SubscriptionEngine.identify_active_subscriptions(self, user_id: str) -> List[Dict[str, Any]]` (async)
In simple English: "For this user, group all their transactions by merchant, and for each merchant, note the most recent amount and timestamp we saw (though, as it happens, without explicitly sorting first, MongoDB doesn't strictly guarantee these are truly the *most* recent — just whatever the underlying query happened to see last). Then, for each of those merchants, go look up their precomputed behavioral statistics — specifically, how regular their billing intervals have historically been. Only keep merchants whose regularity score is very high (0.85 or above out of 1.0) — the signature of a genuine subscription rather than a coincidentally-repeated purchase. For each one that qualifies, report the merchant's name, its last-known charge amount (treated as the estimated monthly cost), its regularity score, and when it was last billed."

## Classes

### `SubscriptionEngine`
No instance state — one method, no helper functions.

## Interfaces
Not applicable formally — the returned list-of-dicts shape (`merchant`, `estimated_monthly_cost`, `periodicity_score`, `last_billed`) is consumed directly by `routers/analytics.py`'s `get_subscriptions` handler, which sums `estimated_monthly_cost` across the list.

## Hooks
Not applicable.

## Utilities
None.

## Dependencies
`database.mongo` (internal).

## Side Effects
Read-only — a single aggregation query, no writes.

## Performance Considerations
- This is the most expensive analytics query in the codebase: it combines a `$group`, a `$lookup` (a join, generally the most costly aggregation stage), an `$unwind`, and a second `$match` — all without any supporting indexes on either `transactions` or `behavior_patterns`.
- **No `$sort` precedes the `$group` stage** — this means MongoDB doesn't guarantee the `$last`/`$max` accumulators reflect true chronological order; a `{$sort: {timestamp: 1}}` stage inserted before the `$group` would fix this and make `last_amount`/`last_seen` reliably accurate.
- The `$lookup` join means this query's cost scales with both the size of `transactions` and `behavior_patterns` — as both grow, this becomes progressively the slowest analytics endpoint without proper indexing on the join keys (`_id`/`merchant_name`).

## Possible Interview Questions
- "Why does this pipeline lack a `$sort` stage before the `$group`, and why does that matter?" (MongoDB's `$group` accumulators like `$last` and `$max` operate on whatever order documents happen to arrive in from the previous stage — without an explicit `$sort` first, that order isn't guaranteed to be chronological, so `last_amount`/`last_seen` could reflect an arbitrary transaction rather than the genuinely most recent one. The fix is a `{$sort: {timestamp: 1}}` stage immediately before the `$group`.)
- "Why use a fixed threshold of `periodicity_score >= 0.85` rather than something configurable?" (Simplicity for a first-pass implementation — a hardcoded magic number with no accompanying tuning/validation process, which means changing sensitivity (catching more possible subscriptions at the risk of false positives, or fewer at the risk of missing genuine ones) currently requires a code change rather than a configuration change.)
- "This function's data entirely depends on `behavior_patterns` being populated. What happens if it's empty (a fresh deployment)?" (The `$lookup` produces an empty `behavior` array for every merchant, and `$unwind` on an empty array drops that document from the pipeline entirely — so every merchant gets filtered out, and the function returns an empty list regardless of how many real, regular transactions actually exist.)
- "Why is `estimated_monthly_cost` just the last observed amount rather than an average or median of recent charges?" (Simplicity — subscriptions are often assumed to charge a fixed amount each period, so 'the last known amount' is a reasonable proxy, though it wouldn't correctly reflect a subscription with a recently changed price or one with genuinely variable billing amounts.)
