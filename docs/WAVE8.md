# Wave 8: Evaluation (Ground Truth)

**Status**: Complete
**Branch**: `wave8`
**Builds on**: Wave 4-5 (`ai_resolution/matcher.py`)

## Executive Summary

Every prior wave shipped a confidence score, a routing decision, or an exception without ever measuring — against
data with a known right answer — whether those decisions were actually correct. Wave 8 closes that gap: a synthetic,
ground-truth-labeled dataset is run *blind* through the real matcher (no ground truth passed in), and the matcher's
decisions are then scored against the withheld ground truth on precision, recall, exception rate, throughput, and
false-match cost.

**This is treated as a first-class product feature, not a one-off script.** The dataset generator and harness live in
`evaluation/`, are covered by 20 automated tests in `evaluation/test_evaluation.py`, and run in CI on every push
(`.github/workflows/ci.yml`).

## The Problem It Solves

Wave 5's design philosophy is "never force a match" — confidence walls exist specifically to prefer an exception over
an unsafe auto-match. That's a strong claim. Nothing before Wave 8 verified it. Without ground truth:

- We didn't know if the matcher's precision was 99% or 60%.
- We didn't know if "conservative routing" was actually conservative, or just broken.
- We had no way to catch a regression in matching quality before it reached production.
- We had no quantified answer to "how much does a false match cost us, versus an exception?"

Wave 8 builds exactly that: a repeatable, CI-gated experiment with a known answer key.

## The Dataset

`evaluation/dataset.py` generates two ledgers that mimic reconciling two independent records of the same
transactions (an internal ledger vs. a bank statement), with realistic noise — merchant-name spelling drift, small
amount deltas (fees/FX rounding), and settlement-date lag.

| | Count |
|---|---|
| Source A records | 250 |
| Source B records | 250 |
| **True matches** | 221 |
| **Known exceptions** (confusable non-matches) | 21 |
| **Ambiguous** (genuinely tied candidates) | 8 |

221 + 21 + 8 = 250. (These are the same numbers Wave 6's controller dashboard already displayed as mock stats —
Wave 8 checks whether the real matcher can actually produce them.)

**TRUE_MATCH (221)**: each source-A record has exactly one correct partner in source B, plus two random distractors
from the wider pool, so finding the right answer requires actually out-ranking competition, not just scoring the one
candidate handed to it. Half are "clean" (well-known recurring merchant, exact amount, same-day settlement) and half
are "noisy" (less-familiar merchant, small fee/FX drift, one-to-two-day settlement lag) — a realistic mix, not a
softball.

**KNOWN_EXCEPTION (21)**: a source-A record with *no* true partner in source B, deliberately paired against an
unrelated B record that's confusable (close amount, close date, sometimes a different merchant). The correct system
behavior is to decline to commit, not to be tricked by the resemblance.

**AMBIGUOUS (8)**: a source-A record torn between two plausible B candidates — one matches on merchant name, the
other matches on amount — so name and amount signals disagree and no candidate cleanly wins. There is no single
defensible answer; the correct behavior is to flag it, not silently pick one.

Source B also carries 29 unmatched filler records (extra bank-side entries with no internal counterpart) — a
realistic reconciliation artifact, and the pool that known-exception/ambiguous cases draw their decoys from.

The generator is seeded (`generate_dataset(seed=42)`) and deterministic — reruns produce an identical dataset, so
results are reproducible and regressions are catchable.

## The Harness

`evaluation/harness.py` runs `ai_resolution.matcher.AIEntityMatcher` — the real Wave 4/5 matcher, completely
unmodified — over every case, with no access to `case.category` or `case.true_b_id`. It only sees merchant text,
amount, date, and (for realism) each entity's historical-encounter count and trust state, exactly as the production
matcher would.

After the run, each case's outcome is classified against the withheld ground truth:

| Outcome | Meaning |
|---|---|
| `CORRECT_AUTO_MATCH` | Auto-matched, and right — fully automated |
| `CORRECT_HUMAN_REVIEW` | Found the right candidate, correctly held for a human to confirm |
| `FALSE_AUTO_MATCH` | Auto-matched, but wrong — or auto-matched a case with no true answer at all |
| `CORRECT_EXCEPTION` | No true match existed; correctly declined to commit |
| `MISSED_MATCH` | A true match existed but the wrong candidate came out on top |

### Metrics

- **Precision** — of everything Vela auto-committed (no human in the loop), how much was correct.
- **Recall** — of all true matches, how many did Vela *discover* (surfaced the correct candidate at all, whether
  auto-matched or queued for review)? This is deliberately distinct from...
- **Automation rate** — of all true matches, how many were auto-committed with *zero* human involvement.
- **Exception rate** — fraction of all 250 records that required a human to look at them.
- **Throughput** — records processed per second.
- **False-match cost** — a naive cost model where a false auto-match costs 50x an unresolved exception
  (`COST_FALSE_MATCH = 50`, `COST_UNRESOLVED = 1`), compared against a naive baseline matcher that always commits to
  its top-scored candidate with no confidence wall at all.

Recall vs. automation rate is the crux of the whole story: a system can *find* the right answer without being
*willing to act on it alone*. Conflating the two would hide exactly the behavior Wave 5 was designed to produce.

## Results (seed=42)

```
Records processed:     250
Throughput:            ~14,000-33,000 records/sec (pure in-process scoring, no I/O)

Precision:             100.00%
Recall (discovered):   100.00%
Automation rate:       0.00%
Exception rate:        100.00%

Outcome breakdown:
  correct_auto_match     0
  correct_human_review   221
  false_auto_match       0
  correct_exception      29
  missed_match           0

False-match cost:
  Vela (confidence walls):   250.0
  Naive (always commit):     1450.0
  Cost reduction:            82.8%

Known exceptions falsely auto-matched:  0 / 21
Ambiguous cases falsely auto-matched:   0 / 8
```

Run it yourself: `python -m evaluation.run_evaluation`

### Reading these numbers

**The headline result**: zero false auto-matches, anywhere, across all 250 records — including all 21 known
exceptions and all 8 ambiguous cases specifically engineered to be tempting. Every true match was correctly
*discovered* (the right candidate was always top-ranked), but none were auto-committed without a human — and that
80%+ false-match-cost reduction against the naive baseline is the quantified version of "Vela prefers an exception
over an unsafe reconciliation."

**Automation rate is 0%, and that's not a dataset artifact — it's a discovered defect.** See below.

## Finding: AUTO_MATCH Is Currently Unreachable

Investigating why *zero* true matches ever auto-committed — even the "clean" half of the dataset, with exact amounts
and same-day settlement — led to two real bugs in the existing scoring code, verified directly against
`ScoringFactors` and `AIEntityMatcher` in `evaluation/test_evaluation.py::TestConfidenceCeilingFinding`:

1. **`trust_state_factor` is silently dropped from the aggregate.** `ScoringFactors.aggregate()`
   (`ai_resolution/matcher.py:78-83`) builds its weighted sum via
   `getattr(self, key.replace("_factor", ""))` for each weight key. For `"trust_state_factor"`, that strips to
   `"trust_state"` — which is not an attribute on `ScoringFactors` (the real attribute is `trust_state_factor`) — so
   the lookup falls through to the default of `0` and the entire trust-state contribution vanishes, regardless of its
   value. Verified: setting `trust_state_factor=0.0` vs. `100.0` produces an *identical* aggregate confidence.

2. **`name_similarity` tops out at 0.80, not 1.0.** `NameSimilarityMatcher.score()`
   (`ai_resolution/matcher.py:195-209`) computes `lev * 0.50 + abbrev * 0.30` — the constructor also defines an
   `"exact_alias"` weight of `0.20` (line 166) that is never referenced in `score()`. Even a perfect exact-string
   match (`lev = 1.0`) plus a known-abbreviation hit (`abbrev = 1.0`) maxes out at `0.80`.

Combined with `historical_context`'s own ceiling of `0.95` (the highest tier in `score_candidate()`'s if/elif ladder,
`ai_resolution/matcher.py:351-358`), the **maximum aggregate confidence obtainable from any input whatsoever is
0.8425** — strictly below the `0.90` `AUTO_MATCH` threshold. This is not a probabilistic tendency; it's an algebraic
ceiling, reproduced exactly by
`evaluation/test_evaluation.py::TestConfidenceCeilingFinding::test_maximum_possible_confidence_is_below_auto_match_wall`.

As shipped, the confidence-wall router can never fully automate a match — every match, however clean, is routed to
`HUMAN_REVIEW` at best. This also explains 5 pre-existing failures in `ai_resolution/test_matcher.py`
(`test_exact_match`, `test_case_insensitive`, `test_partial_match`, `test_equal_weighting`,
`test_score_candidate_high_confidence`), confirmed present on `wave7` before this branch touched anything — Wave 8
didn't introduce this defect, it's the first thing to actually measure its effect and quantify it.

**Recommendation for a follow-up wave** (deliberately not fixed here — Wave 8's job is measurement, not a matcher
rewrite, and touching the scoring formula deserves its own reviewed change): fix the `trust_state_factor` key lookup,
either apply or remove the dead `exact_alias` weight, and re-run `python -m evaluation.run_evaluation` to confirm
`automation_rate` moves off zero without `false_match_count` moving off zero.

## Architecture

```
evaluation/
  dataset.py          Synthetic ground-truth dataset generator (250/250, 221/21/8 split)
  harness.py           Runs AIEntityMatcher blind, scores against withheld ground truth
  run_evaluation.py    CLI: python -m evaluation.run_evaluation — prints the full report
  test_evaluation.py   20 tests: dataset shape, harness metrics, the confidence-ceiling finding,
                        and the false-match-cost story
  metrics.py            (pre-existing, unrelated) sklearn-based evaluator for the categorization
                        models in training/ - not used by the matching-engine harness above
```

No production code was modified. `ai_resolution/matcher.py` is exercised exactly as it ships.

## Testing

```
python -m pytest evaluation/test_evaluation.py -v   # 20 passed
python -m ruff check evaluation/                     # clean
```

Wired into CI (`.github/workflows/ci.yml`, `test` job) alongside `test_api.py`, so a future change that reintroduces
a false auto-match, breaks the dataset's shape, or silently "fixes" the confidence ceiling without updating the
finding test will fail the build.

## What Wave 8 Deliberately Does Not Do

- **Does not fix the matcher.** The confidence-ceiling bug is documented and tested as a *finding*, not patched —
  changing production scoring weights is a separate, reviewable decision with its own blast radius.
- **Does not wire into `routers/controller.py`.** The controller's endpoints still return hardcoded mock data (a
  pre-existing gap, not introduced here); Wave 8 evaluates the matching engine directly, not through the API layer.
- **Does not add a UI.** This is a backend evaluation harness and CI gate, consistent with the "evaluation is not
  optional" brief — the audience is the test suite and this document, not an operator screen.
