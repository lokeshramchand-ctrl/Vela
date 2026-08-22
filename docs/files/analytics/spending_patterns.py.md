# File: `analytics/spending_patterns.py`

## Purpose
Answers two of the most basic spend-analytics questions: "how much did I spend, by category?" and "who do I spend with most often?"

## Responsibilities
- Aggregate transactions by category within a date range.
- Aggregate transactions by merchant, ranked by visit frequency.

## Imports
| Import | Used for |
|---|---|
| `datetime.datetime, timezone` | Type hints (declared, though `timezone` isn't actually referenced in this file's logic beyond the type hint context — the actual date range is computed by the caller in `routers/analytics.py`) |
| `typing.Dict, Any, List` | Type hints |
| `database.mongo.db` | Running aggregation pipelines against `transactions` |

## Exports
- **`SpendingPatternsEngine`** — the class.
- **`spending_patterns`** — the singleton instance, imported by `routers/analytics.py`.

## Execution Flow
On import, `spending_patterns = SpendingPatternsEngine()` runs trivially. Each method independently builds and runs one MongoDB aggregation pipeline per call.

## Functions (plain English)

### `SpendingPatternsEngine.get_category_breakdown(self, user_id: str, start_date: datetime, end_date: datetime) -> List[Dict[str, Any]]` (async)
In simple English: "Look at all of this user's transactions that happened between the given start and end dates. Group them by category, add up the total amount spent in each category, and count how many transactions fell into each. Sort the results so the category with the most total spending comes first. If a transaction had no category recorded at all, label it 'Unknown' rather than leaving it blank."

### `SpendingPatternsEngine.get_merchant_frequency(self, user_id: str, limit: int = 5) -> List[Dict[str, Any]]` (async)
In simple English: "Look at *all* of this user's transactions, with no date restriction. Group them by merchant, counting how many times each merchant was visited and how much was spent there in total. Sort so the most-visited merchant comes first, and only return the top N (5 by default)."

## Classes

### `SpendingPatternsEngine`
No instance state — pure orchestration class with two independent methods.

## Interfaces
Not applicable formally — return shapes here are plain lists of dicts, not validated against a declared schema.

## Hooks
Not applicable.

## Utilities
None — both methods are self-contained.

## Dependencies
`database.mongo` (internal). No third-party dependencies beyond what Motor itself uses internally.

## Side Effects
Both methods are read-only — no writes, no mutation, just aggregation queries against MongoDB.

## Performance Considerations
- `get_category_breakdown` filters by both `user_id` and a `timestamp` range before grouping — without a compound index on `{user_id, timestamp}` (none exists anywhere in this codebase), this is a full collection scan filtered in-memory by MongoDB's query engine, which becomes slower as the `transactions` collection grows.
- `get_merchant_frequency` filters only by `user_id`, with no date bound — meaning it always scans that user's *entire* transaction history, which only gets more expensive over time as more transactions accumulate, unlike the category breakdown which at least bounds itself to a window.
- Both aggregations request MongoDB to do all the grouping/sorting/limiting server-side (rather than pulling raw documents into Python and processing them there) — the correct approach for performance, letting the database engine do what it's optimized for.

## Possible Interview Questions
- "Why does `get_merchant_frequency` not accept a date range parameter the way `get_category_breakdown` does?" (An inconsistency in the API design — there's no technical reason it couldn't accept one; it may simply reflect that 'who do I visit most, ever' was considered a more useful all-time question than a windowed one, though that's a design assumption not stated anywhere in the code.)
- "What happens to a transaction with `category: null` or a missing `category` field in `get_category_breakdown`?" (MongoDB's `$group` would group all such documents under `_id: null`, and the Python code explicitly checks `doc["_id"] or "Unknown"`, converting that null grouping into the friendly label `'Unknown'` in the final response.)
- "If you wanted to add pagination to `get_merchant_frequency` beyond just a `limit`, what would you add?" (A `$skip` stage before the `$limit` stage in the aggregation pipeline, combined with an offset/page parameter passed in from the caller — not currently supported.)
- "Why is `timezone` imported here if it's not directly used in this file's logic?" (It's imported alongside `datetime` for type-hinting completeness/consistency with how date ranges are constructed elsewhere in the codebase (e.g., in `routers/analytics.py`, which does use `timezone.utc` when building the actual date range passed into these functions) — within this specific file, though, it's not referenced in any executable logic.)
