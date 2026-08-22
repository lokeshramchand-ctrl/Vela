# File: `features/frequency_features.py`

## Purpose
Computes how often, on average, a merchant's transactions occur — daily and weekly visit rates.

## Responsibilities
- Compute the total time span covered by a set of transaction timestamps.
- Derive daily and weekly frequency rates from that span.
- Compute the average gap between consecutive transactions.

## Imports
| Import | Used for |
|---|---|
| `datetime.datetime` | Type hint for timestamp inputs |
| `typing.List, Dict` | Type hints |

## Exports
- **`FrequencyExtractor`** — the class.
- **`frequency_extractor`** — the singleton instance, imported by `behaviour/behavior_engine.py`.

## Execution Flow
Pure and stateless, same pattern as the other `features/` modules.

## Functions (plain English)

### `FrequencyExtractor.extract_frequency_metrics(self, timestamps: List[datetime]) -> Dict`
In simple English: "Given a list of transaction timestamps for one merchant, figure out roughly how often, on average, this merchant gets visited — both per day and per week. If there are fewer than 2 timestamps, there's no meaningful 'frequency' to compute yet, so just return zeros. Otherwise: sort the timestamps chronologically, measure the total number of days between the very first and very last one, and divide the total number of transactions by that span to get a daily rate (protecting against a divide-by-zero if every transaction happened on the exact same day, by treating the minimum span as at least 1 day). Multiply that daily rate by 7 to get a weekly rate. Also compute, on average, how many days pass between one transaction and the next."

## Classes

### `FrequencyExtractor`
No instance state — stateless computation class with one method.

## Interfaces
The dict keys (`daily_frequency`, `weekly_frequency`, `avg_days_between`) form the contract `behaviour/behavior_engine.py` partially relies on — it reads `daily_frequency` and `weekly_frequency` but does **not** use `avg_days_between` at all (that value is computed here and then simply discarded by the caller, since `BehaviorPattern` has no field for it).

## Hooks
Not applicable.

## Utilities
None — a single-purpose class.

## Dependencies
`datetime` (standard library, used only for type hints).

## Side Effects
None — pure computation.

## Performance Considerations
Trivial — sorting is the only O(n log n) operation; everything else is O(1) arithmetic once the span is known. No concerns at any realistic scale of per-merchant transaction history.

## Possible Interview Questions
- "Why guard `total_span_days` with `max(total_span_days, 1.0)`?" (Prevents a division by zero (or an artificially huge frequency number) in the edge case where every transaction in the list happened within the same calendar day — treating that as 'at least a 1-day span' gives a conservative, sane frequency estimate instead of an undefined or absurd one.)
- "Why compute `avg_days_between` if nothing downstream actually uses it?" (Likely written as a natural companion metric to daily/weekly frequency during development, but `BehaviorPattern` (the schema this feeds into) was never extended with a field for it — a small piece of computed-but-unused work, harmless but worth cleaning up or actually wiring in.)
- "Is `daily_frequency = n / span_days` the same as 'average transactions per calendar day,' or something subtly different?" (It's an average rate over the *entire observed span*, not a count of distinct calendar days that had at least one transaction — a merchant visited twice in one day and never again for 30 days would show a low daily frequency here, even though on the one day it was visited, the rate was much higher than the average suggests.)
- "How would this function's output differ for a merchant visited exactly twice, one day apart, versus one visited twice, 300 days apart?" (Both have `n=2`, but `total_span_days` differs enormously — 1 vs. 300 — giving daily frequencies of 2.0 vs. ~0.0033 respectively; with only 2 data points, though, neither number is statistically very meaningful.)
