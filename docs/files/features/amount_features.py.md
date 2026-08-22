# File: `features/amount_features.py`

## Purpose
Computes statistical summaries of a merchant's transaction amounts — the "how much do they typically charge, and how consistent is it" dimension of behavioral profiling.

## Responsibilities
- Compute mean, median, variance, and standard deviation of a list of amounts.
- Compute an entropy-based measure of how predictable/repetitive the amounts are.

## Imports
| Import | Used for |
|---|---|
| `math` | `math.sqrt` (standard deviation), `math.log2` (entropy) |
| `typing.List, Dict` | Type hints |

## Exports
- **`AmountExtractor`** — the class.
- **`amount_extractor`** — the singleton instance, imported by `behaviour/behavior_engine.py`.

## Execution Flow
Pure, stateless — importing this file does nothing beyond defining the class and instantiating the singleton (no I/O, no dependencies on other modules). Each call to `extract_statistical_metrics` computes everything fresh from its input, with no memory of previous calls.

## Functions (plain English)

### `AmountExtractor.extract_statistical_metrics(self, amounts: List[float]) -> Dict`
In simple English: "Given a list of amounts someone spent at a merchant, figure out several things: what's the typical (average and middle/median) amount, how spread out are the values from that average (variance and standard deviation), and how predictable or repetitive the amounts are overall (entropy). If the list is completely empty, don't try to compute any of this — just return a set of zeroed-out placeholder values instead of crashing."

Breaking down the internal steps this one function performs:
- **Mean**: sum of all amounts divided by how many there are.
- **Median**: sort all the amounts, then take the middle one (or average the two middle ones if there's an even count) — implemented via `sorted_amts[mid]` and `sorted_amts[~mid]`, a trick that correctly picks the same single middle value twice when the count is odd, and the two true middle values when it's even.
- **Variance**: on average, how far (squared) each amount is from the mean — using the "population" formula (dividing by the total count, not count-minus-one), and explicitly guarding against dividing by zero when there's only one data point.
- **Standard deviation**: the square root of the variance — puts the "spread" measure back into the same units as the amounts themselves (e.g., rupees, not rupees-squared).
- **Entropy**: round every amount to the nearest multiple of 10 (so ₹412 and ₹418 both become ₹410, treated as "the same" amount for this purpose), count how often each rounded value appears, then compute a score that's low if the merchant almost always charges the same rounded amount, and higher if the amounts vary a lot — using the standard Shannon entropy formula from information theory.

## Classes

### `AmountExtractor`
No instance state — a stateless computation class with a single method.

## Interfaces
Not applicable formally, though the function's dict keys form an implicit contract that `behaviour/behavior_engine.py` relies on exactly (`avg_amount`, `median_amount`, `variance`, `std_dev`, `entropy_score`) — note the empty-input branch returns a *different* set of keys (`avg`, `median`, `entropy` instead of `avg_amount`, `median_amount`, `entropy_score`), which would break any caller that doesn't already guard against empty input before calling this function (see `docs/16-known-issues-tech-debt.md`).

## Hooks
Not applicable.

## Utilities
The entire class functions as a utility — no separate helper functions beyond the one main method.

## Dependencies
`math` (standard library) only. No internal dependencies.

## Side Effects
None — completely pure function, no I/O, no logging, no mutation of any state outside the returned dict.

## Performance Considerations
- Sorting the amounts list (`sorted(amounts)`) is O(n log n) — the dominant cost for large transaction histories, though transaction counts per merchant are typically small enough for this to be a non-issue in practice.
- The entropy calculation does a second full pass over the data to build the rounded-value histogram — O(n) additional work on top of the sort.
- Everything here runs in pure Python with no numpy vectorization — fine at the scale this function is actually used at (per-merchant transaction counts, not app-wide datasets), but would be a natural place to optimize with numpy if called against much larger amount lists.

## Possible Interview Questions
- "Why round to the nearest 10 before computing entropy, rather than using exact amounts?" (Exact floating-point amounts would almost never repeat, making every 'bucket' size 1 and entropy trivially maximal and meaningless — coarse rounding creates meaningful groupings that actually reveal repeat-charge behavior, like a subscription that always charges exactly ₹499.)
- "Why does the empty-input branch return keys named `avg`/`median`/`entropy` instead of matching the normal branch's `avg_amount`/`median_amount`/`entropy_score`?" (Almost certainly an oversight rather than a deliberate design choice — it's a latent bug that would cause a `KeyError` in any caller that accesses the normal-branch keys without first checking for empty input; `behaviour/behavior_engine.py` currently avoids triggering it by guarding against empty transaction lists before calling this function at all.)
- "Walk me through why `sorted_amts[mid]` and `sorted_amts[~mid]` correctly compute the median for both odd and even list lengths." (`mid = n // 2` is the index just past the true center. For odd `n`, `~mid` (which is `-mid-1`) happens to index the same single middle element from the other end, so averaging it with itself gives the correct median. For even `n`, `mid` and `~mid` land on the two true middle elements, and their average gives the correct median — a compact, if slightly clever, way to handle both cases with one line.)
- "Why use population variance (`/n`) rather than sample variance (`/(n-1)`)?" (A judgment call — population variance treats the observed transactions as the *entire* population of interest for this specific merchant at this point in time, rather than treating them as a random sample used to estimate a broader unknown population's variance; either could be defended depending on how the number will be used downstream.)
