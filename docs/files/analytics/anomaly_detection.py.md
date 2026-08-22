# File: `analytics/anomaly_detection.py`

## Purpose
Real-time detection of unusually large or small transaction amounts, compared against a merchant's own historical baseline.

## Responsibilities
- Fetch a merchant's precomputed behavioral baseline (average and standard deviation).
- Compute a z-score for a new transaction amount against that baseline.
- Flag amounts more than 3 standard deviations away as anomalous.

## Imports
| Import | Used for |
|---|---|
| `typing.Dict, Any` | Type hints |
| `database.mongo.db` | Fetching the merchant's behavioral baseline |

## Exports
- **`AnomalyDetector`** — the class.
- **`anomaly_detector`** — the singleton instance, imported by `routers/analytics.py`.

## Execution Flow
On import, `anomaly_detector = AnomalyDetector()` runs trivially. `flag_transaction(...)` runs one MongoDB read, then a small amount of arithmetic.

## Functions (plain English)

### `AnomalyDetector.flag_transaction(self, merchant_name: str, amount: float) -> Dict[str, Any]` (async)
In simple English: "Look up this merchant's historical spending baseline — their typical average amount and how much that amount usually varies. If we don't have a baseline for this merchant at all, or if their historical amounts never varied at all (zero standard deviation, meaning we can't meaningfully judge what's 'unusual' for them), just say we don't have enough information to judge, rather than guessing. Otherwise, calculate how many 'typical variations' away from their average this new amount is — this is the z-score, a standard statistical way of measuring 'how unusual is this compared to what's normal for this specific merchant.' If it's more than 3 of those typical variations away in either direction, flag it as an anomaly, note whether it's unusually higher or lower than normal, and give a confidence score that grows the more extreme the z-score is (capped at 99% so we never claim absolute certainty). If it's within that normal range, just report that it looks like normal spending for this merchant."

## Classes

### `AnomalyDetector`
No instance state — one method.

## Interfaces
Not applicable formally — the returned dict shape (`is_anomaly`, `confidence`/`reason`) is the contract `routers/analytics.py`'s `check_anomaly` handler passes straight through.

## Hooks
Not applicable.

## Utilities
None.

## Dependencies
`database.mongo` (internal).

## Side Effects
Read-only — a single `find_one` query, no writes.

## Performance Considerations
Extremely cheap — one indexed-in-theory-but-not-in-practice `find_one` lookup (no index actually exists on `merchant_name` in `behavior_patterns` anywhere in this codebase) plus a handful of arithmetic operations. This is the fastest of the four analytics endpoints.

## Possible Interview Questions
- "Walk through the statistical reasoning behind the 3-sigma rule used here." (For data that's roughly normally distributed, about 99.7% of values fall within 3 standard deviations of the mean — so an amount further than that is a statistically rare event for that specific merchant's historical pattern, a widely-used, simple heuristic for flagging outliers without needing more sophisticated statistical modeling.)
- "Why does the function treat `std_dev == 0` as 'insufficient data' rather than 'any deviation at all is infinitely anomalous'?" (A merchant with zero historical variance has never demonstrated any variability at all — treating literally any different amount as an infinite-sigma anomaly would be statistically meaningless and would also risk a division-by-zero error; declaring 'insufficient baseline' is the safer, more honest response.)
- "Why cap `confidence` at `0.99` rather than allowing it to reach `1.0`?" (A deliberate epistemic choice — never claiming absolute (100%) certainty, consistent with the confidence-wall philosophy seen elsewhere in this system, that some irreducible uncertainty should always be acknowledged.)
- "This function depends entirely on `behavior_patterns` being populated by `behaviour/behavior_engine.py`, which nothing calls automatically. What does that mean for a freshly deployed system?" (Every call to this function would return `{"is_anomaly": false, "reason": "Insufficient baseline data"}` for every merchant, since no behavioral baselines would exist yet — the anomaly detector would be functionally inert until someone manually runs the behavior-profiling pipeline for each merchant of interest.)
