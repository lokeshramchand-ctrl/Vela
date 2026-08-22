# File: `behaviour/behavior_engine.py`

## Purpose
Orchestrates the full Phase 6 behavioral-profiling pipeline for a single merchant: fetch its transaction history, run every feature extractor against it, and persist the combined result.

## Responsibilities
- Fetch all transactions for a given merchant name.
- Delegate all statistical computation to `features/*.py`.
- Assemble a `BehaviorPattern` and upsert it into MongoDB.

## Imports
| Import | Used for |
|---|---|
| `typing.List` | Type hint (declared, not actually used in any live type annotation in this file's body beyond documentation intent) |
| `database.mongo.db` | Fetching transactions and writing the resulting behavior pattern |
| `models.schemas.BehaviorPattern` | The output schema being assembled |
| `features.temporal_features.temporal_extractor` | Time-of-day/weekday computation |
| `features.amount_features.amount_extractor` | Amount statistics computation |
| `features.periodicity.periodicity_extractor` | Interval-regularity computation |
| `features.frequency_features.frequency_extractor` | Visit-rate computation |

## Exports
- **`BehaviorEngine`** — the class.
- **`behavior_engine`** — the singleton instance. **Not imported anywhere else in the codebase.**

## Execution Flow
On import, `behavior_engine = BehaviorEngine()` runs trivially. If ever called, `profile_merchant_behavior(...)` runs a single linear flow: fetch all transactions → guard against empty results → run all four extractors → assemble the schema → upsert to MongoDB → return.

## Functions (plain English)

### `BehaviorEngine.profile_merchant_behavior(self, merchant_name: str) -> BehaviorPattern` (async)
In simple English: "Go get every single transaction on record for this merchant, no matter how old. If we can't find even one, don't pretend we have data — raise an error saying so, since a behavioral profile built from zero data points would be meaningless. Otherwise, pull out just the list of amounts and just the list of timestamps from all those transactions, and hand each list to the appropriate specialist: one calculates time-of-day/weekday patterns, one calculates amount statistics like average and entropy, one calculates how often the merchant is visited per day/week, and one calculates how *regularly spaced* the visits are. Take everything all four specialists computed and combine it into one complete behavioral profile for this merchant. Finally, save that profile to the database — if we already had a profile for this merchant from a previous run, overwrite it with the fresh numbers; if not, create a new one. Hand back the finished profile."

## Classes

### `BehaviorEngine`
No instance state — a pure orchestration class with one public method.

## Interfaces
`BehaviorPattern` (from `models/schemas.py`) is both the assembly target and the return type — a clear, singular contract.

## Hooks
Not applicable.

## Utilities
None — the whole class is one cohesive orchestration method.

## Dependencies
`database.mongo`, `models.schemas`, and all four `features/*.py` extractors (internal). No third-party dependencies directly (though the extractors it calls use `math`).

## Side Effects
- Reads potentially many documents from `db.transactions` (unbounded, no time window, no pagination — a full scan filtered by an unindexed `merchant` field).
- Writes (upserts) one document into `db.behavior_patterns` per call.
- Can raise `ValueError` — a deliberate, explicit side effect signaling "no data available," rather than silently producing a degenerate zero-valued profile.

## Performance Considerations
- Fetching **all** transactions for a merchant with no limit or time window means this function's cost grows linearly (or worse, given the lack of an index on `merchant`) with that merchant's total lifetime transaction count — for a very high-volume merchant, this could become slow and memory-intensive, since the entire result set (`[doc async for doc in cursor]`) is materialized into a Python list at once.
- The four feature extractors themselves are each cheap (see their individual docs) — the dominant cost here is the database fetch, not the computation.
- Because this function recomputes the *entire* profile from scratch every time it's called (rather than incrementally updating based on only new transactions since the last run), repeated calls for the same merchant redo all the same work from the beginning each time.

## Possible Interview Questions
- "Why does this function raise `ValueError` on an empty transaction list instead of returning a zero-valued `BehaviorPattern`?" (A zero-valued profile could be misleading — it would look like 'this merchant has zero variance and zero frequency,' which is a very different claim from 'we have no data on this merchant at all.' Raising an explicit error forces callers to distinguish those two very different situations rather than silently treating them the same.)
- "If this function were called for the same merchant twice in quick succession, what would happen?" (Both calls would independently fetch the same (or nearly the same, if new transactions arrived in between) data, redo all computation, and both would `upsert` into the same document — the second write would simply overwrite the first, which is safe here specifically because the whole document is recomputed from source data each time rather than incrementally patched.)
- "How would you change this function to support incremental updates instead of full recomputation every time?" (You'd need to store enough running state — e.g., running sums, counts, and a record of the last-processed transaction timestamp — to update statistics incrementally rather than re-deriving everything from the full history each call; a meaningfully more complex design than what exists today.)
- "This function has no caller anywhere in the codebase. What would you need to build to actually use it in production?" (Either a script that iterates every known merchant name and calls this per merchant, or a scheduled/triggered job that runs it whenever a merchant accumulates enough new transactions — neither currently exists.)
