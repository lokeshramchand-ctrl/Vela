# Wave 8: Evaluation — Summary

## What shipped

A ground-truth evaluation harness for the matching engine, treated as a first-class feature: a synthetic 250-vs-250
record dataset with known answers, run blind through the real matcher, scored on precision, recall, exception rate,
throughput, and false-match cost — with 20 automated tests and a CI gate.

```
evaluation/dataset.py        250 source-A / 250 source-B records: 221 true matches, 21 known
                              exceptions, 8 ambiguous cases (seeded, deterministic)
evaluation/harness.py        Runs ai_resolution.matcher.AIEntityMatcher with no ground truth,
                              scores the result against the withheld answer key
evaluation/run_evaluation.py CLI report: python -m evaluation.run_evaluation
evaluation/test_evaluation.py 20 tests — dataset shape, precision/recall/exception-rate bounds,
                              zero-false-match guarantees, false-match-cost comparison
docs/WAVE8.md                 Full write-up, methodology, and findings
```

## The headline result

**Zero false auto-matches, anywhere** — across all 21 known-exception traps and all 8 ambiguous ties, at seed 42.
Every true match was correctly *discovered* (the right candidate always ranked first), but the matcher only
auto-commits when it's certain; everything else goes to a human instead of a guess.

```
Precision:             100.00%
Recall (discovered):   100.00%
Automation rate:         0.00%
Exception rate:        100.00%

False-match cost:
  Vela (confidence walls):   250.0
  Naive (always commit):    1450.0
  Cost reduction:             82.8%
```

That cost comparison is the Track 04 story made concrete: a false auto-match is modeled as 50x more expensive than
an exception, and Vela's conservative routing — even fully un-automated on this dataset — still costs 83% less than
a matcher that always commits to its top-scored candidate. **Vela prefers an exception over an unsafe
reconciliation, measured, not assumed.**

## The finding worth flagging

Automation rate came back at 0% not because the dataset was too hard, but because it's currently *impossible* to
clear the 0.90 AUTO_MATCH threshold: two real bugs in `ai_resolution/matcher.py` — a dict-key mismatch that silently
drops `trust_state_factor` from every confidence score, and a `name_similarity` formula that tops out at 0.80 instead
of 1.0 — cap the maximum achievable confidence at 0.8425. Proven algebraically and by test
(`evaluation/test_evaluation.py::TestConfidenceCeilingFinding`), not just observed in this run. Full analysis and a
recommended fix are in `docs/WAVE8.md`.

This is exactly what "evaluation is not optional" is for: it caught something the existing (also mostly-passing)
test suite for the matcher didn't.

## How to run it

```bash
python -m evaluation.run_evaluation      # full report
python -m pytest evaluation/test_evaluation.py -v   # 20 tests
```

No production code changed. No database, no network, no fixtures beyond the seeded generator — reruns are
byte-identical, so this is safe to gate CI on (`.github/workflows/ci.yml`, `test` job).

## Branch

`wave8`, off `wave7`. Not merged — see `docs/WAVE8.md` for what's deliberately out of scope (fixing the matcher,
wiring into `routers/controller.py`, a UI).
