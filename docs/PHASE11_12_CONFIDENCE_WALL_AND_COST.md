# Phase 11-12: confidence-wall qualification and false-match cost

All numbers below are measured directly from `evaluation.run_track04_comparison`
/ `evaluation.harness.run_evaluation` against the 300-record Track 04
benchmark (`generate_track04_benchmark()`, seed=42), not hand-typed.
Reproduce with:

```
python -m evaluation.run_track04_comparison
```

## Phase 11: confidence-wall distribution

| State | Count | % of 300 |
|---|---|---|
| AUTO_MATCH | 44 | 14.7% |
| HUMAN_REVIEW | 158 | 52.7% |
| EXCEPTION | 88 | 29.3% |
| (no candidates - MISSING_RECORD) | 10 | 3.3% |

**Review + exception rate: 82.0% held for a human.** Automation rate:
14.7% of the full adversarial benchmark (18.3% of true matches
specifically - see Phase 8/9-10 commits). More of the benchmark is held
for review than is ever auto-committed - `test_review_and_exception_rate_exceeds_automation_rate`.

**False-match count: 0 / 300.** Verified across every category, including
the four the qualification spec specifically asks about:

- **Refunds / reversals / incompatible debit-credit** (`DIRECTION_CONFLICT`,
  10 cases: same merchant/amount/date, opposing direction): 0 auto-matched.
  This is the exact scenario EDGE_CASE_REPORT.md finding 4 warned would
  become a live risk if the Phase 2 confidence fix landed without Phase 1's
  direction hard-filter - both are in place, and it doesn't.
- **Duplicates** (`DUPLICATE_CANDIDATE`, 10 cases: byte-identical candidate
  pair): 0 auto-matched - `detect_ambiguity()` vetoes even though each
  candidate individually clears 0.90 in isolation.
- **Missing records** (`MISSING_RECORD`, 10 cases: no candidates at all):
  `propose_decision([])` declines cleanly, no fabricated match.

`evaluation/test_confidence_wall_policy.py` re-verifies all of this
directly, in one file, rather than leaving it as an inference readers have
to draw from several other test files.

## Phase 12: false-match cost

Illustrative cost model only (`evaluation/harness.py`:
`COST_FALSE_MATCH = 50.0`, `COST_UNRESOLVED = 1.0`) - **not real Razorpay
or production loss figures**, just a quantified version of "a false
auto-match is far worse than a record that merely waits for a human."

| | Value |
|---|---|
| False auto-match count | 0 |
| Manual-review cases (HUMAN_REVIEW) | 158 |
| Unresolved cases (EXCEPTION) | 88 |
| False-match rate | 0.00% |
| Review rate (HUMAN_REVIEW + EXCEPTION) / total | 82.0% |
| Full Vela total false-match cost | 256.0 (= 256 unresolved-cost units, zero false-match-cost units) |
| Naive baseline cost (fuzzy scoring, no confidence wall) | 2950.0 |
| Cost reduction vs. naive | 91.3% |

The naive counterfactual (`naive_baseline_cost()`) always commits to the
top-scored candidate with no confidence wall at all - its entire cost is
false-match cost, since it never declines. Vela's actual cost is 91.3%
lower purely because the confidence wall converts what would have been
expensive false matches into cheap "held for review" cases instead.

**The policy demonstrated here:** Vela prefers a review/exception over an
unsafe automatic reconciliation whenever evidence conflicts or is
insufficient - measured as zero false matches across every adversarial
category in the benchmark, at the cost of a lower (18.3%, see Phase 9-10)
automation rate. That trade is the deliberate design, not an accident: a
missed automation opportunity costs a few minutes of human review; a false
auto-match risks misstating a financial position.

## What this does not claim

This is a 300-record synthetic benchmark, not production traffic. Zero
false matches here is evidence the confidence-wall architecture holds
under the adversarial cases this benchmark specifically constructs - it is
not a guarantee against every possible real-world input shape. See
`docs/track04-final-evaluation.md` (Phase 17) for the full honesty
accounting, including what remains untested.
