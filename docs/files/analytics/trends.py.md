# File: `analytics/trends.py`

## Purpose
Intended to compute month-over-month spending growth. Currently half-real, half-mocked: the current month is queried live, but the previous month's figure is a hardcoded placeholder.

## Responsibilities
- Query real current-month spending.
- (Intended, not implemented) query real previous-month spending.
- Compute a percentage growth figure and a simple up/down trend label.

## Imports
| Import | Used for |
|---|---|
| `datetime.datetime` | Constructing the start-of-current-month boundary |
| `typing.Dict, Any` | Type hints |
| `database.mongo.db` | Querying current-month transaction totals |

## Exports
- **`TrendAnalyzer`** — the class.
- **`trend_analyzer`** — the singleton instance, imported by `routers/analytics.py`.

## Execution Flow
On import, `trend_analyzer = TrendAnalyzer()` runs trivially. `calculate_mom_growth(...)` runs one real aggregation for the current month, then uses a hardcoded constant for the comparison figure, then computes a simple derived percentage.

## Functions (plain English)

### `TrendAnalyzer.calculate_mom_growth(self, user_id: str, current_month: int, current_year: int) -> Dict[str, Any]` (async)
In simple English: "Figure out the very first moment of the given month and year. Add up everything this user has spent from that moment until now. That part is real and accurate. For 'last month's total,' though — instead of actually looking it up — just use a fixed placeholder number (₹15,000) that the code's own comment admits should eventually be replaced with a real database query. Compare the real current total against that placeholder previous total to compute a percentage change (being careful not to divide by zero if the placeholder were ever zero). Report the current total, the placeholder previous total, the percentage change, and a simple label of whether spending is trending 'up' or 'down.'"

## Classes

### `TrendAnalyzer`
No instance state — one method.

## Interfaces
Not applicable formally — the returned dict shape (`current_spend`, `previous_spend`, `mom_growth_percentage`, `trend`) is the contract `routers/analytics.py`'s `get_mom_trends` handler passes straight through unchanged.

## Hooks
Not applicable.

## Utilities
None.

## Dependencies
`datetime` (standard library); `database.mongo` (internal).

## Side Effects
One real, read-only aggregation query against `transactions` for the current month; no side effects for the (mocked) previous-month figure.

## Performance Considerations
Cheap — a single aggregation query filtered by `user_id` and a `timestamp >= start_of_month` bound, though again without a supporting index on those fields.

## Possible Interview Questions
- "Is the growth percentage this function reports currently trustworthy?" (No — it's comparing a real current-month total against a hardcoded constant (₹15,000) rather than a real previous-month query, so the resulting percentage and 'up'/'down' trend label don't reflect this user's actual month-over-month behavior at all. This should not be surfaced to end users as real analytics until fixed.)
- "What would the correct fix look like?" (Compute the previous month's start and end boundaries — accounting correctly for January wrapping to the prior December — and run the same kind of aggregation query used for the current month against that date range, replacing the hardcoded `15000.0` with the real result.)
- "Why does the function guard against `prev_total == 0` before computing the percentage?" (To avoid a division-by-zero error — if a user had genuinely spent nothing in the comparison period, computing `(curr - 0) / 0` would raise a `ZeroDivisionError`; the guard instead reports `0.0%` growth in that edge case.)
- "This function takes `current_month` and `current_year` as explicit parameters rather than deriving 'now' internally. What's the benefit?" (Makes the function more testable and reusable — a caller could ask about any specific month, not just the current one, though in practice the only caller, `routers/analytics.py`, always passes in the actual current month and year, so this flexibility isn't currently exercised.)
