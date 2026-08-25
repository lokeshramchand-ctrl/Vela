# Phase 4: is periodicity safe to wire into the matcher?

**Verdict: experimental. Not wired into `AIEntityMatcher.score_candidate()`
in this branch.**

## What was evaluated

`features/periodicity.py`'s `PeriodicityExtractor.calculate_periodicity()`
takes a list of timestamps for one merchant/user pair and returns a
coefficient-of-variation-based regularity score plus an
`is_likely_subscription` flag when that score is high (>0.85) and the
average interval lands in a ~30-day or ~365-day band. Characterized
directly in `features/test_periodicity.py` (6 tests, all passing):

- Perfectly-spaced monthly (30-day) and date-drifted monthly (28-35 day)
  sequences are both correctly flagged.
- Genuinely irregular same-merchant history scores low and is correctly
  not flagged.
- **Finding:** a perfectly-regular *weekly* cadence gets the maximum
  possible regularity score (1.0) but is never flagged as a subscription,
  because the detection band only checks for ~30-day or ~365-day averages.
  Real weekly billing (grocery/meal-kit subscriptions) is invisible to this
  heuristic today.
- **Finding:** the module has no amount parameter at all - it is a purely
  temporal signal. A merchant billed monthly with a wildly different amount
  each time (a price hike, a metered bill, or an unrelated purchase
  interleaved with real subscription charges) would score identically to a
  stable-amount subscription.

## Why it isn't wired into `score_candidate()` here

`score_candidate()` scores one query transaction against one candidate
transaction, using at most two dates (`query_date`, `candidate_date`).
`calculate_periodicity()` needs a *history* - three or more timestamps for
that merchant/user pair - which `score_candidate()`'s current signature has
no way to receive. Wiring this in safely would require:

1. A new parameter (e.g. `historical_timestamps: list[datetime] | None`)
   threaded through `score_candidate()`, and a caller (router/service) that
   actually assembles that history per merchant/user before calling the
   matcher - a change to code outside `ai_resolution/matcher.py` that
   wasn't in scope to inspect or modify in this phase.
2. A decision on how a periodicity bonus interacts with amount evidence,
   given the module's blindness to amount - naively adding "this looks
   periodic, so raise temporal_proximity" without also checking amount
   stability would let an unrelated same-merchant transaction that happens
   to land near a subscription's usual billing date get inflated temporal
   credit it hasn't earned (a direct risk to the "same merchant, different
   transaction" safety property tested in
   `evaluation/test_edge_cases.py::test_same_merchant_different_transaction_does_not_collapse`).
3. A decision on the weekly-cadence gap above, since wiring in the
   as-shipped `is_likely_subscription` flag would silently continue to
   miss weekly recurring billing.

None of these are decisions this phase should make unilaterally - they're
product/scoring-design calls for whoever owns the matcher, same posture
EDGE_CASE_REPORT.md finding 3 already took ("that's a design call for
whoever owns the matcher, not something this report is proposing to
implement").

## What this phase does instead

- Adds standalone characterization tests for `features/periodicity.py`
  (`features/test_periodicity.py`) covering monthly, weekly, irregular,
  amount-blind, and date-drift cases, plus the insufficient-data guard.
- Leaves `evaluation/test_edge_cases.py`'s
  `test_recurring_monthly_payment_loses_all_temporal_credit` finding open
  and updates its docstring to point at this file rather than re-describing
  the gap inline.
- Does not touch `ai_resolution/matcher.py`'s temporal scoring.

## Recommendation for a future wiring attempt

If/when this is wired in, the safe shape is likely: pass
`historical_timestamps` and `historical_amounts` together, require amount
stability (e.g. all within the existing `AmountMatcher` tolerance) before
applying any periodicity bonus, and widen the subscription-detection band
to include weekly cadences. That's a larger, separately-reviewable change.
