# File: `features/temporal_features.py`

## Purpose
Computes when-during-the-day and when-during-the-week a merchant's transactions tend to happen.

## Responsibilities
- Classify any given hour of the day into a named time bucket.
- Compute the most common transaction hour.
- Compute normalized distributions across time-of-day buckets and days of the week.

## Imports
| Import | Used for |
|---|---|
| `datetime.datetime` | Type hint for the timestamp inputs |
| `typing.List, Dict` | Type hints |

## Exports
- **`TemporalExtractor`** — the class.
- **`temporal_extractor`** — the singleton instance, imported by `behaviour/behavior_engine.py`.

## Execution Flow
Pure and stateless, same pattern as `amount_features.py` — no I/O, no cross-call memory.

## Functions (plain English)

### `TemporalExtractor.get_time_bucket(hour: int) -> str` (static method)
In simple English: "Given an hour of the day (0 through 23), name which part of the day it falls into: 5am–11:59am is 'morning', noon–4:59pm is 'afternoon', 5pm–8:59pm is 'evening', and everything else (9pm through 4:59am) is 'night'." Because it's a `@staticmethod`, it can be called without needing an instance of the class — `TemporalExtractor.get_time_bucket(14)` works directly.

### `TemporalExtractor.extract_temporal_metrics(self, timestamps: List[datetime]) -> Dict`
In simple English: "Given a list of moments when transactions happened, figure out three things: which single hour of the day comes up most often, what fraction of transactions fall into each time-of-day bucket (morning/afternoon/evening/night), and what fraction fall on each day of the week. If given no timestamps at all, just return sensible defaults (noon as the 'preferred hour,' and everything else empty/zero) instead of crashing." Internally, it counts occurrences of each hour and picks the most frequent one (breaking ties by whichever hour Python's internal set ordering happens to encounter first — not a meaningful tiebreaker, just an artifact of how the code is written), then tallies each timestamp into its time bucket and day-of-week slot, and finally divides every count by the total number of timestamps to turn raw counts into fractions/proportions.

## Classes

### `TemporalExtractor`
No instance state — a stateless computation class with one static helper method and one main instance method.

## Interfaces
The dict keys returned by `extract_temporal_metrics` (`preferred_hour`, `time_bucket_distribution`, `weekday_distribution`) form an implicit contract `behaviour/behavior_engine.py` relies on — note the empty-input branch returns *different* keys (`time_buckets`, `weekday_dist` instead of `time_bucket_distribution`, `weekday_distribution`), a mismatch that would cause a `KeyError` for any caller not already guarding against empty input.

## Hooks
Not applicable.

## Utilities
`get_time_bucket` is a small, genuinely reusable static utility — usable independently of the main extraction method by any code needing just the hour-to-bucket mapping.

## Dependencies
`datetime` (standard library, used only for type hints — no `datetime` methods are actually called in this file beyond what's implicitly used via `.hour` and `.weekday()` attribute/method access on the passed-in objects).

## Side Effects
None — pure computation.

## Performance Considerations
- `max(set(hours), key=hours.count)` for finding the preferred hour is a subtle performance trap: `hours.count(h)` is an O(n) linear scan of the full list, called once per *unique* hour value in the set — meaning this line is roughly O(n × k) where k is the number of distinct hours present (at most 24), rather than the O(n) a single counting pass (e.g., using `collections.Counter`) would achieve. For realistic transaction volumes per merchant this is a non-issue, but it's a textbook example of an easy-to-miss inefficiency.
- The rest of the function is a single O(n) pass over timestamps for bucketing and weekday counting.

## Possible Interview Questions
- "Why is `max(set(hours), key=hours.count)` less efficient than using `collections.Counter(hours).most_common(1)`?" (The `set`+`count` approach re-scans the entire `hours` list once for every distinct hour value, giving roughly O(n×k) behavior, while `Counter` builds a full frequency map in a single O(n) pass and can then find the maximum in O(k) — meaningfully better for large transaction volumes, though negligible at the scale this function currently operates at.)
- "How are hour-of-day ties broken when picking the 'preferred hour'?" (Not meaningfully — `max` with a `set` as its iterable relies on whatever arbitrary (though deterministic for a given Python version/build) order the set happens to produce; there's no explicit tiebreaking rule like 'prefer the earlier hour' or 'prefer the most recent occurrence.')
- "Why does `get_time_bucket` classify 9pm–4:59am as a single 'night' bucket instead of splitting late evening from early morning?" (A judgment call about what buckets are meaningful for spending-behavior analysis — treating post-9pm and pre-5am as one continuous 'off-hours' period is a reasonable simplification, though someone analyzing very late-night versus very early-morning spending specifically would need finer buckets.)
- "What real-world behavioral signal might `weekday_distribution` reveal that `time_bucket_distribution` wouldn't?" (A merchant visited only on weekends — like a leisure/entertainment venue — versus one visited only on weekdays — like a workday lunch spot — would look identical in time-of-day terms but very different in weekday distribution.)
