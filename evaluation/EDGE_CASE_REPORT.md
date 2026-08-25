# Edge-Case Report: Matching Engine & Statement Ingestion

**Branch:** `testing/edge-case-matching` (off `wave8`)
**Suite:** `evaluation/test_edge_cases.py` — 28 tests, 28 passing
**Scope:** `ai_resolution/matcher.py` (`AIEntityMatcher`) and
`statements/pdf_parser.py` (`GooglePayStatementParser`), exercised directly
with no mocks and no database. Every assertion below was verified by hand
against a real run before being written into the test.

Wave 8's evaluation harness measured the matcher's aggregate safety over a
250-record synthetic dataset drawn from a realistic distribution. This
report targets the specific transaction shapes that break naive
reconciliation logic in production, whether or not they're common: rounding
noise, refunds, recurring billing, and malformed uploads. Nothing here
modifies `matcher.py` or `pdf_parser.py` — nothing was fixed, only observed.

## Headline

The confidence-wall architecture (never auto-match below 0.90, prefer
exception over guessing) holds up under every adversarial case tried here —
**no unsafe auto-match was produced by any test in this suite.** But two
independent problems compound to make that safety margin much larger than
the design intends, and one structural gap (no debit/credit direction) means
the safety is partly accidental rather than by design.

## Findings

### 1. Exact match never reaches AUTO_MATCH (confirms & sharpens Wave 8's ceiling finding)

`NameSimilarityMatcher.score()` declares three weights —
`levenshtein` (0.50), `abbreviation` (0.30), `exact_alias` (0.20) — but the
method body only ever applies the first two:

```python
score = lev * self.weights["levenshtein"] + abbrev * self.weights["abbreviation"]
```

`exact_alias` is dead weight, never multiplied against anything. The
practical effect: a **byte-identical** merchant name (`"Amazon"` vs.
`"Amazon"`) scores `name_similarity = 0.50`, not `1.0`, because Levenshtein
alone caps out at `1.0 * 0.50 = 0.50` and there's no abbreviation bonus for
an already-exact name. Only names that happen to be in the hardcoded
`abbrev_map` stub (`AMZN`, `UBER`, `SWIGGY`, `ZOMATO`, `GPay`, `PhonePe`) get
the extra 0.30 and reach `0.80`.

Consequence, reproduced directly: a transaction with identical merchant
name, identical amount, identical date, 25 prior encounters, and
`PERMANENT` trust state — the best input the matcher could ever receive —
scores **0.7675** confidence and routes to `HUMAN_REVIEW`, not
`AUTO_MATCH`. This means every transaction the matcher currently sees
requires human review, regardless of how clean the signal is. Automation
rate is structurally zero at the current 0.90 wall.

This corroborates and sharpens the bug already flagged in Wave 8
(`docs/WAVE8.md`): that finding described a 0.8425 ceiling from the
`trust_state_factor` dict-key mismatch. This suite shows the ceiling is
usually much lower still (~0.77–0.80) because the `exact_alias` weight is
separately unused, and it reproduces the failure with a single concrete,
minimal example rather than an algebraic bound.

**Existing regression signal:** `ai_resolution/test_matcher.py` already
has 5 failing tests that assert the *intended* behavior (e.g.
`test_exact_match` expects `score("UBER","UBER") > 0.95`, gets `0.80`;
`test_equal_weighting` expects an all-1.0 aggregate to equal `1.0`, gets
`0.9`). Those failures are pre-existing (not introduced by this branch) and
are the same root cause as above plus the `trust_state_factor` mismatch.

### 2. Amount tolerance is percentage-only — harsher on small transactions

`AmountMatcher` tolerance is `tolerance_pct = 0.05` of the *query* amount,
with no absolute floor:

| Case | Diff | % of amount | Result |
|---|---|---|---|
| ₹1 diff on ₹5,000 | ₹1 | 0.02% | partial credit (0.7) |
| ₹1 diff on ₹10 | ₹1 | 10% | **0 — treated as a wrong amount** |
| ₹100 diff on ₹5,000 | ₹100 | 2% | partial credit (0.7) |
| ₹100 diff on ₹500 | ₹100 | 20% | **0 — treated as a wrong amount** |

Real-world rounding/FX noise is usually a small absolute amount, not a
percentage. A ₹1 difference is exactly as likely on a ₹10 auto-rickshaw fare
as on a ₹5,000 purchase, but only the latter survives. This isn't unsafe (it
never causes a false match — if anything it forces more exceptions than
necessary), but it's a real gap in matcher usefulness: small transactions
get pushed to `EXCEPTION` for the same absolute noise that large ones absorb.

### 3. Recurring/subscription payments get zero temporal credit

`TemporalProximityMatcher(max_days=3)` gives `0.0` proximity to anything
more than 3 days apart, with no distinction between "3 days late" and "3
months away." A same-merchant, same-amount, ~30-day-apart transaction (the
textbook shape of a Netflix/Spotify-style subscription) scores
`temporal_proximity = 0.0` — identical to a transaction with no temporal
relationship whatsoever — and lands in `EXCEPTION` even with maximal
historical trust (25 encounters, `PERMANENT`).

The codebase already has `features/periodicity.py` for detecting exactly
this kind of recurring cadence, but it isn't wired into
`AIEntityMatcher.score_candidate()`. A periodicity-aware exception to the
temporal window (e.g. "if this pair has a known ~30-day cadence, treat it
as a repeat of proximity=0.9 rather than 0.0") looks like the natural fix,
but that's a design call for whoever owns the matcher, not something this
report is proposing to implement.

### 4. No debit/credit direction — refunds and reversals are handled by accident, not by design

`AIEntityMatcher.score_candidate()` has no `direction`, `type`, or sign-aware
parameter anywhere in its signature (confirmed via `inspect.signature`, not
just reading the source). Two consequences, tested separately:

- **Refund modeled as a negated amount** (`-500` vs. `500`, same merchant,
  same day): `AmountMatcher.score()` does a plain numeric comparison, so a
  negative amount just looks like a completely wrong number and scores
  `0.0`. Safe by accident — it correctly avoids matching a refund to its
  original — but for the wrong reason (it can't tell a refund from a typo).
- **Reversal modeled with the same sign/magnitude as the original** (a very
  common statement pattern: same-day, same-merchant, same-amount entries
  where only a debit/credit column distinguishes them): the matcher scores
  it **identically** to matching the transaction against itself, because
  direction plays no role at all in the score. On real data this is exactly
  the situation with the highest chance of misreconciliation, and the
  matcher currently has no signal to catch it. It happens to still be
  routed to `HUMAN_REVIEW` today only because *no* input reaches the 0.90
  wall (see Finding 1) — if Finding 1 is fixed in isolation without also
  adding a direction check, this scenario would become a live false-match
  risk rather than a theoretical one.

**Recommendation for whoever picks up matcher fixes next:** direction
should be a hard pre-filter before scoring even starts (a debit can never
be proposed as a candidate for a credit), not left to the fuzzy confidence
score where it's currently invisible. Fixing Finding 1 without also adding
this check would be actively worse than leaving both bugs in place, since
it would let same-day reversal pairs start clearing the AUTO_MATCH wall on
name+amount+date alone.

### 5. Missing/partial data degrades safely (no fix needed, verified)

Missing amount or date falls back to `AmountMatcher`/`TemporalProximityMatcher`'s
documented neutral score (`0.5`), and missing both still lands the aggregate
confidence around `0.50` — nowhere near `AUTO_MATCH`. This is the one area
where the current behavior is exactly what you'd want, though it's a side
effect of the weighted-average math rather than an explicit
"insufficient data" rule.

### 6. Missing/duplicate candidate records are handled correctly

- **Missing record** (no candidates at all): `propose_decision([])` returns
  `None` cleanly — no crash, no fabricated match. Calling code must
  translate `None` into an exception, which is the router/service's
  responsibility, not this class's.
- **Duplicate record** (two byte-identical candidates): `detect_ambiguity()`
  correctly flags the tie. Note this is a *separate* method from
  `propose_decision()` — `propose_decision()` does not call
  `detect_ambiguity()` internally. `evaluation/harness.py` combines both
  manually (lines 214–218: downgrade `AUTO_MATCH` to `HUMAN_REVIEW` if
  ambiguous). Any other caller of `propose_decision()` that doesn't also
  call `detect_ambiguity()` and apply that downgrade itself would miss this
  veto. Worth flagging to anyone building a second caller of this matcher
  (e.g. a future non-evaluation production router).

### 7. PDF ingestion: malformed and empty inputs fail correctly, with one real inconsistency

- Garbage bytes, a truncated PDF header, and an empty byte string all raise
  `CorruptedPDFError` as designed, from `open_and_inspect()`.
- An empty extracted-text string parses to `[]`, not an error — correct,
  since an empty statement isn't corruption.
- A file with no recognized layout markers correctly raises
  `UnsupportedStatementError` from `validate_signature()`.
- **Real finding, not synthetic:** `mock/gpay_statement_20260101_20260630.pdf`
  (267KB, valid `%PDF-1.5` header, a real committed fixture) passes
  `open_and_inspect()` — `pypdf` tolerates its malformed xref table with
  just a logged warning ("incorrect startxref pointer") and reports 19
  pages successfully — but then **fails outright** in `extract_text()`,
  where `pdfplumber`/`pdfminer` refuses the same bytes ("No /Root object! -
  Is this really a PDF?"). The two PDF libraries this parser depends on
  disagree about whether the file is valid. Both failure paths are
  individually handled (each raises `CorruptedPDFError`), so nothing
  crashes — but a caller that only checks `open_and_inspect()` up front
  (e.g. to validate a file before queueing a longer job) would see success,
  then fail later at `extract_text()`. Worth confirming the upload flow
  doesn't have a gap between those two calls (e.g. an early "looks valid"
  acknowledgment sent to the user before extraction actually runs).

### 8. Duplicate upload: parser is deterministic; dedup correctly lives elsewhere

Re-parsing the same statement text twice produces identical transaction
lists (same reference numbers, amounts, counterparties, timestamps, in the
same order) — confirmed against a real 22-page/210-transaction statement.
The parser itself has no dedup logic, which is correct: dedup is handled at
`repositories/transaction_repository.py`, which upserts on
`(user_id, reference_number)` per its own docstring. That repository-level
behavior needs a real MongoDB to exercise and wasn't re-tested here — it's
verified by code inspection, not by an integration test in this suite.

## What's *not* covered here

- The repository-level dedup upsert (`(user_id, reference_number)`) needs a
  live MongoDB and is out of scope for this offline suite — flagged above as
  verified by inspection only.
- `services/merchant_resolver.py`'s exact/substring alias lookup also
  requires MongoDB and wasn't exercised.
- No load/throughput testing — Wave 8's harness already covers throughput on
  the synthetic dataset.

## Test-to-scenario mapping

| # | Scenario | Test(s) |
|---|---|---|
| 1 | Exact match | `test_exact_match_never_reaches_auto_match` |
| 2 | Merchant variation | `test_known_abbreviation_scores_higher_than_plain_exact_match`, `test_unlisted_surface_form_variation_scores_moderately` |
| 3 | ₹1 amount difference | `test_one_rupee_diff_on_large_amount_gets_tolerance_credit`, `test_one_rupee_diff_on_small_amount_fails_tolerance` |
| 4 | ₹100 amount difference | `test_hundred_rupee_diff_within_five_percent_gets_tolerance_credit`, `test_hundred_rupee_diff_beyond_five_percent_fails` |
| 5 | 1-day date shift | `test_one_day_date_shift_scores_near_same_day` |
| 6 | 7-day date shift | `test_seven_day_date_shift_scores_zero` |
| 7 | Missing record | `test_missing_record_no_candidates_declines_gracefully` |
| 8 | Duplicate record | `test_duplicate_record_is_flagged_ambiguous` |
| 9 | Same merchant / different transaction | `test_same_merchant_different_transaction_does_not_collapse` |
| 10 | Same amount / different merchant | `test_same_amount_different_merchant_does_not_auto_match` |
| 11 | Recurring payment | `test_recurring_monthly_payment_loses_all_temporal_credit` |
| 12 | Refund | `test_refund_with_negated_amount_fails_amount_match_entirely` |
| 13 | Reversal | `test_reversal_same_signed_amount_looks_identical_to_original` |
| 14 | Debit vs credit | `test_score_candidate_has_no_direction_parameter` |
| 15 | Partial data | `test_missing_amount_falls_back_to_neutral_score`, `test_missing_date_falls_back_to_neutral_score`, `test_missing_amount_and_date_never_reaches_auto_match` |
| 16 | Malformed PDF | `test_garbage_bytes_raise_corrupted_pdf_error`, `test_truncated_pdf_header_raises_corrupted_pdf_error`, `test_real_pdf_that_passes_header_check_but_fails_text_extraction`, `test_valid_pdf_wrong_layout_raises_unsupported_statement_error` |
| 17 | Empty source | `test_empty_bytes_raise_corrupted_pdf_error`, `test_empty_extracted_text_parses_to_zero_transactions_not_an_error` |
| 18 | Duplicate upload | `test_parsing_the_same_upload_twice_is_deterministic` |

Plus one end-to-end smoke test (`test_real_statement_end_to_end_smoke`) as a
known-good baseline against a real 22-page statement.

## Next test target

This suite stops at the matcher and the parser, both testable without
infrastructure. The next natural target is `services/merchant_resolver.py`
and the repository-level dedup upsert — both need a real MongoDB instance
(matching how `test_api.py` and CI's `test` job already run against a
`mongo:6.0` service container) to exercise for real rather than by
inspection.
