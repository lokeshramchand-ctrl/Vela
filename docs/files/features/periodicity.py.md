# File: `features/periodicity.py`

## Purpose
Measures how *regularly spaced* a merchant's transactions are — the key signal for detecting subscription-like recurring behavior.

## Responsibilities
- Compute the gaps (in days) between consecutive transactions.
- Turn the variability of those gaps into a single 0–1 "periodicity score."
- Heuristically flag likely subscriptions based on that score and the typical gap length.

## Imports
| Import | Used for |
|---|---|
| `datetime.datetime` | Type hint for timestamp inputs |
| `typing.List, Dict` | Type hints |
| `math` | `math.sqrt` for standard deviation |

## Exports
- **`PeriodicityExtractor`** — the class.
- **`periodicity_extractor`** — the singleton instance, imported by `behaviour/behavior_engine.py`.

## Execution Flow
Pure and stateless, same pattern as the other `features/` modules.

## Functions (plain English)

### `PeriodicityExtractor.calculate_periodicity(self, timestamps: List[datetime]) -> Dict`
In simple English: "Given a list of transaction timestamps, figure out how *regular* the spacing between them is — like a subscription that bills every 30 days versus random, unpredictable visits. You need at least 3 timestamps to make this meaningful (with only 2, there's just one single gap, which trivially looks 'perfectly regular' with no way to tell if it's a fluke). Sort the timestamps, then measure the gap in days between each consecutive pair. Compute the average gap and how much the gaps vary around that average (their standard deviation). Divide the variability by the average to get a 'coefficient of variation' — a way of expressing 'how noisy is this, relative to its own scale.' Turn that into a periodicity score between 0 and 1, where 1 means the gaps are all exactly the same length (extremely regular), and lower numbers mean more erratic spacing. As a bonus, if the score is high (above 0.85) *and* the typical gap is close to either a month (27–33 days) or a year (360–370 days), flag this as looking like a subscription." If the average gap comes out to exactly zero (multiple transactions happening at the identical timestamp), the function short-circuits and reports a perfect periodicity score of 1.0, but explicitly does *not* flag it as a likely subscription (since a zero-day gap isn't what a monthly or annual subscription would look like).

## Classes

### `PeriodicityExtractor`
No instance state — stateless computation class with one method.

## Interfaces
The dict key `periodicity_score` is the one field `behaviour/behavior_engine.py` actually consumes; `is_likely_subscription` is computed here but **not** propagated into the `BehaviorPattern` schema at all — the live `/v1/analytics/subscriptions` endpoint re-derives its own, simpler subscription heuristic independently in `analytics/subscriptions.py`, entirely ignoring this field.

## Hooks
Not applicable.

## Utilities
None — a single-purpose class.

## Dependencies
`math`, `datetime` (standard library).

## Side Effects
None — pure computation.

## Performance Considerations
Sorting is the only O(n log n) step; everything else is a single linear pass to compute intervals plus O(1) arithmetic on the resulting interval list. No performance concerns at realistic per-merchant transaction volumes.

## Possible Interview Questions
- "Why is a coefficient of variation (`std_dev / mean`) used instead of just the raw standard deviation of the intervals?" (Raw standard deviation isn't comparable across merchants with very different typical gap lengths — a 2-day standard deviation is huge for a merchant billed every 3 days, but tiny for one billed every 365 days. Dividing by the mean normalizes for scale, making the resulting score comparable across merchants regardless of their typical interval length.)
- "Why does `periodicity_score = 1 / (1 + cv)` produce a value in `(0, 1]` rather than `[0, 1]`?" (When `cv = 0` — perfectly regular intervals — the score is exactly `1 / (1+0) = 1.0`. As `cv` grows toward infinity (extremely erratic intervals), the score approaches but never quite reaches `0`. So the range is `(0, 1]`, asymptotically approaching but never touching zero.)
- "Why require at least 3 timestamps, and what would go wrong with only 2?" (With only 2 timestamps there's exactly 1 interval, which has zero variance by definition — the coefficient of variation would be `0/mean = 0`, giving a trivially 'perfect' periodicity score of `1.0` for what might just be two coincidentally-timed, otherwise random transactions. Requiring 3+ timestamps ensures at least 2 intervals exist, so genuine variability — or its absence — can actually be measured.)
- "The subscription heuristic checks for gaps of 27–33 days or 360–370 days. What real-world billing patterns might this miss?" (Weekly subscriptions (~7-day gaps), bi-weekly/fortnightly patterns (~14 days), or quarterly billing (~90 days) would all score highly on periodicity but wouldn't be flagged as 'likely subscription' by this specific range check — a limitation of hardcoding only monthly/annual windows.)
