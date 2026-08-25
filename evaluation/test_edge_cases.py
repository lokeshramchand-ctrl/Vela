"""
Testing branch: adversarial edge-case suite for the matching engine.

Wave 8 (evaluation/harness.py) answers "is the matcher's routing safe on
average, over a representative dataset?" This suite asks a narrower,
uglier question: what does it do on the specific transaction shapes that
break naive reconciliation logic in production - a 1-rupee rounding diff,
a refund that mirrors its original debit, a recurring payment that lands
outside the temporal window, a PDF that passes header validation but dies
on text extraction?

Every test asserts *observed* behavior, verified by hand against
ai_resolution/matcher.py and statements/pdf_parser.py before being written
down here - not desired behavior. Where the observed behavior is unsafe or
surprising, the test is annotated with FINDING and the gap is recorded in
evaluation/EDGE_CASE_REPORT.md. Nothing in ai_resolution/matcher.py or
statements/pdf_parser.py is modified by this suite.
"""

import unittest
from datetime import datetime, timedelta

from ai_resolution.matcher import AIEntityMatcher, ConfidenceWall
from statements.pdf_parser import (
    CorruptedPDFError,
    UnsupportedStatementError,
    statement_parser,
)

BASE_DATE = datetime(2026, 3, 1)


class MatchingEngineEdgeCases(unittest.TestCase):
    """ai_resolution.matcher.AIEntityMatcher against the 15 transaction-level
    scenarios. Every case scores a single candidate the way evaluation/harness.py
    does, then checks the resulting confidence wall."""

    def setUp(self):
        self.matcher = AIEntityMatcher()

    def score(self, **kw):
        kw.setdefault("historical_encounters", 10)
        kw.setdefault("trust_state", None)
        return self.matcher.score_candidate(**kw)

    # 1. Exact match ----------------------------------------------------
    def test_exact_match_now_reaches_auto_match(self):
        """FIXED (was FINDING): a byte-identical merchant name, amount, and
        date - the best possible input the matcher could ever see - now
        clears the 0.90 AUTO_MATCH wall. Two bugs compounded to block this
        before: (1) NameSimilarityMatcher.score() declared an 'exact_alias'
        weight (0.20) but never applied it, so an exact text match on
        "Amazon"/"Amazon" only got Levenshtein's 0.50 weight; (2)
        ScoringFactors.aggregate() looked up a nonexistent 'trust_state'
        attribute (stripping the "_factor" suffix) instead of
        'trust_state_factor', silently dropping that weight's entire 0.10
        contribution from every aggregate. Both are fixed together, since
        fixing only the first still capped the best case at ~0.89, just
        under the wall."""
        c = self.score(
            query_text="Amazon", query_amount=999.0, query_date=BASE_DATE,
            candidate_merchant="Amazon", candidate_amount=999.0, candidate_date=BASE_DATE,
            historical_encounters=25, trust_state="PERMANENT",
        )
        self.assertAlmostEqual(c.scoring_factors.name_similarity, 0.7, places=2)
        self.assertEqual(self.matcher.route_by_confidence_wall(c), ConfidenceWall.AUTO_MATCH)

    # 2. Merchant variation ----------------------------------------------
    def test_known_abbreviation_scores_at_least_as_well_as_plain_exact_match(self):
        """FIXED: with exact_alias now applied, a byte-identical name
        ("Amazon" vs "Amazon", name_similarity=0.7: 0.5 Levenshtein + 0.2
        exact) is no longer weaker than a listed abbreviation ("AMZN" ->
        "Amazon", name_similarity=0.7: partial Levenshtein + 0.3 abbreviation
        bonus) - previously the abbreviation stub table scored strictly
        higher than a literal exact match, which was backwards. They now tie
        in this case; abbreviation coverage is still a hardcoded stub dict,
        so it only helps merchants already listed in it."""
        abbrev = self.score(
            query_text="AMZN", query_amount=500.0, query_date=BASE_DATE,
            candidate_merchant="Amazon", candidate_amount=500.0, candidate_date=BASE_DATE,
        )
        exact = self.score(
            query_text="Amazon", query_amount=500.0, query_date=BASE_DATE,
            candidate_merchant="Amazon", candidate_amount=500.0, candidate_date=BASE_DATE,
        )
        self.assertGreaterEqual(abbrev.scoring_factors.name_similarity, exact.scoring_factors.name_similarity)

    def test_unlisted_surface_form_variation_scores_moderately(self):
        """"AMAZON PAY" vs "Amazon" isn't a listed abbreviation, so it falls
        back to pure Levenshtein similarity - a real but partial signal."""
        c = self.score(
            query_text="AMAZON PAY", query_amount=500.0, query_date=BASE_DATE,
            candidate_merchant="Amazon", candidate_amount=500.0, candidate_date=BASE_DATE,
        )
        self.assertGreater(c.scoring_factors.name_similarity, 0.2)
        self.assertLess(c.scoring_factors.name_similarity, 0.6)

    # 3. Rupee 1 difference -----------------------------------------------
    def test_one_rupee_diff_on_large_amount_gets_tolerance_credit(self):
        """AmountMatcher's tolerance is percentage-based (5%), not absolute.
        On a Rs 5000 transaction, a Rs 1 diff is 0.02% - comfortably inside
        tolerance -> partial credit (0.7)."""
        c = self.score(
            query_text="Amazon", query_amount=5000.0, query_date=BASE_DATE,
            candidate_merchant="Amazon", candidate_amount=4999.0, candidate_date=BASE_DATE,
        )
        self.assertEqual(c.scoring_factors.amount_match, 0.7)

    def test_one_rupee_diff_on_small_amount_fails_tolerance(self):
        """FINDING: the same Rs 1 diff on a Rs 10 transaction is a 10% delta -
        outside the 5% tolerance band -> scores 0, identical to a completely
        wrong amount. A percentage-only tolerance is systematically harsher
        on small transactions (coffee, tips, auto-rickshaw fares) than large
        ones, for the same absolute rounding/FX noise."""
        c = self.score(
            query_text="Amazon", query_amount=10.0, query_date=BASE_DATE,
            candidate_merchant="Amazon", candidate_amount=9.0, candidate_date=BASE_DATE,
        )
        self.assertEqual(c.scoring_factors.amount_match, 0.0)

    # 4. Rupee 100 difference ----------------------------------------------
    def test_hundred_rupee_diff_within_five_percent_gets_tolerance_credit(self):
        """Rs 100 on a Rs 5000 base is exactly 2% - still within the 5% band."""
        c = self.score(
            query_text="Amazon", query_amount=5000.0, query_date=BASE_DATE,
            candidate_merchant="Amazon", candidate_amount=4900.0, candidate_date=BASE_DATE,
        )
        self.assertEqual(c.scoring_factors.amount_match, 0.7)

    def test_hundred_rupee_diff_beyond_five_percent_fails(self):
        """The same Rs 100 diff on a Rs 500 base is 20% - fails tolerance."""
        c = self.score(
            query_text="Amazon", query_amount=500.0, query_date=BASE_DATE,
            candidate_merchant="Amazon", candidate_amount=400.0, candidate_date=BASE_DATE,
        )
        self.assertEqual(c.scoring_factors.amount_match, 0.0)

    # 5/6. Date shifts -------------------------------------------------------
    def test_one_day_date_shift_scores_near_same_day(self):
        c = self.score(
            query_text="Amazon", query_amount=500.0, query_date=BASE_DATE,
            candidate_merchant="Amazon", candidate_amount=500.0, candidate_date=BASE_DATE + timedelta(days=1),
        )
        self.assertEqual(c.scoring_factors.temporal_proximity, 0.9)

    def test_seven_day_date_shift_scores_zero(self):
        """Beyond TemporalProximityMatcher's max_days=3, proximity is a hard 0
        - settlement lag longer than 3 days (common for card networks, ACH,
        or cross-border payments) gets no credit at all, not partial credit."""
        c = self.score(
            query_text="Amazon", query_amount=500.0, query_date=BASE_DATE,
            candidate_merchant="Amazon", candidate_amount=500.0, candidate_date=BASE_DATE + timedelta(days=7),
        )
        self.assertEqual(c.scoring_factors.temporal_proximity, 0.0)

    # 7. Missing record -------------------------------------------------------
    def test_missing_record_no_candidates_declines_gracefully(self):
        """No candidate transaction exists at all (record present on one side
        of a reconciliation, absent on the other). propose_decision must not
        crash or fabricate a match - it returns None, which the calling code
        must translate into an exception, not a match."""
        decision = self.matcher.propose_decision([])
        self.assertIsNone(decision)
        ranked = self.matcher.rank_candidates([])
        self.assertEqual(ranked, [])

    # 8. Duplicate record -----------------------------------------------------
    def test_duplicate_record_is_flagged_ambiguous(self):
        """Two byte-identical candidate records (e.g. the same statement line
        ingested twice into the candidate pool) tie exactly -> detect_ambiguity
        must catch this since confidence alone can't break the tie.
        NOTE: propose_decision() itself does NOT consult detect_ambiguity() -
        callers must call both and combine, the way evaluation/harness.py does
        (see harness.py:214-218). A caller that only calls propose_decision()
        would miss this veto."""
        dupe_kwargs = dict(
            query_text="Amazon", query_amount=500.0, query_date=BASE_DATE,
            candidate_merchant="Amazon", candidate_amount=500.0, candidate_date=BASE_DATE,
        )
        c1, c2 = self.score(**dupe_kwargs), self.score(**dupe_kwargs)
        ranked = self.matcher.rank_candidates([c1, c2])
        self.assertTrue(self.matcher.detect_ambiguity(ranked))

    # 9. Same merchant / different transaction ---------------------------------
    def test_same_merchant_different_transaction_does_not_collapse(self):
        """Two genuinely distinct Amazon purchases (different amount, 10 days
        apart) must not be treated as the same transaction just because the
        merchant name matches - amount and temporal signals correctly drag
        confidence down to EXCEPTION."""
        c = self.score(
            query_text="Amazon", query_amount=1200.0, query_date=BASE_DATE,
            candidate_merchant="Amazon", candidate_amount=350.0, candidate_date=BASE_DATE - timedelta(days=10),
        )
        self.assertEqual(self.matcher.route_by_confidence_wall(c), ConfidenceWall.EXCEPTION)

    # 10. Same amount / different merchant ---------------------------------------
    def test_same_amount_different_merchant_does_not_auto_match(self):
        """A coincidental amount match (Rs 500 Swiggy vs Rs 500 Amazon, same
        day) must not be trusted on amount+date alone - weak name similarity
        correctly keeps this out of AUTO_MATCH. NOTE: after the Phase 2
        trust_state_factor fix, this now lands in HUMAN_REVIEW rather than
        EXCEPTION (0% name similarity is still outweighed by amount+date+
        historical-trust agreement) - still safe (never auto-matched, a
        human sees a 0% name-similarity pairing and rejects it), just a
        different, still-non-automated bucket than before the fix."""
        c = self.score(
            query_text="Swiggy", query_amount=500.0, query_date=BASE_DATE,
            candidate_merchant="Amazon", candidate_amount=500.0, candidate_date=BASE_DATE,
        )
        self.assertEqual(c.scoring_factors.name_similarity, 0.0)
        wall = self.matcher.route_by_confidence_wall(c)
        self.assertIn(wall, (ConfidenceWall.HUMAN_REVIEW, ConfidenceWall.EXCEPTION))
        self.assertNotEqual(wall, ConfidenceWall.AUTO_MATCH)

    # 11. Recurring payment ------------------------------------------------------
    def test_recurring_monthly_payment_loses_all_temporal_credit(self):
        """FINDING (still open - Phase 4 territory): a legitimate monthly
        subscription (same merchant, same amount, ~30 days apart) is exactly
        the kind of match a real user would expect to auto-reconcile - but
        TemporalProximityMatcher's max_days=3 gives it zero temporal credit,
        identical to a transaction 7 days or 7 months away. There's no
        periodicity-aware exception for recurring billing, even though
        features/periodicity.py exists elsewhere in this codebase for
        exactly this signal - it isn't wired into the matcher. NOTE: after
        the Phase 2 trust_state_factor fix, this now lands in HUMAN_REVIEW
        (was EXCEPTION) since the other signals are strong enough to clear
        0.65 on their own - still correctly held for a human, not
        auto-matched, but the periodicity gap itself is unchanged."""
        c = self.score(
            query_text="Netflix", query_amount=649.0, query_date=BASE_DATE,
            candidate_merchant="Netflix", candidate_amount=649.0, candidate_date=BASE_DATE + timedelta(days=30),
            historical_encounters=25, trust_state="PERMANENT",
        )
        self.assertEqual(c.scoring_factors.temporal_proximity, 0.0)
        wall = self.matcher.route_by_confidence_wall(c)
        self.assertIn(wall, (ConfidenceWall.HUMAN_REVIEW, ConfidenceWall.EXCEPTION))
        self.assertNotEqual(wall, ConfidenceWall.AUTO_MATCH)

    # 12. Refund -------------------------------------------------------------------
    def test_refund_with_negated_amount_fails_amount_match_entirely(self):
        """AmountMatcher still does a direct numeric comparison with no
        sign-awareness on its own (-500 vs 500 scores 0 there, unchanged),
        but a refund is now also caught structurally: when the caller
        supplies direction (CREDIT for the refund vs. DEBIT for the original
        purchase it reverses), route_by_confidence_wall forces EXCEPTION
        regardless of any other score - see test 13/14 below for the
        direction-aware fix itself."""
        c = self.score(
            query_text="Amazon", query_amount=-500.0, query_date=BASE_DATE,
            candidate_merchant="Amazon", candidate_amount=500.0, candidate_date=BASE_DATE,
        )
        self.assertEqual(c.scoring_factors.amount_match, 0.0)

    # 13. Reversal -------------------------------------------------------------------
    def test_reversal_same_signed_amount_is_now_caught_by_direction(self):
        """FIXED (was FINDING - unsafe direction): a reversal recorded with
        the *same* sign/magnitude as the original debit (a same-day,
        same-merchant, same-amount txn - which is exactly what a same-day
        reversal often looks like on a statement) used to score identically
        to matching the transaction against itself, because score_candidate()
        had no direction parameter at all. score_candidate() now accepts
        query_direction/candidate_direction, and route_by_confidence_wall()
        treats a known direction disagreement as a hard pre-filter: even
        though the two candidates below have identical confidence (name/
        amount/date are unchanged), only the direction-conflicting one is
        forced to EXCEPTION."""
        original = self.score(
            query_text="Amazon", query_amount=500.0, query_date=BASE_DATE,
            candidate_merchant="Amazon", candidate_amount=500.0, candidate_date=BASE_DATE,
            query_direction="DEBIT", candidate_direction="DEBIT",
        )
        reversal = self.score(
            query_text="Amazon", query_amount=500.0, query_date=BASE_DATE,
            candidate_merchant="Amazon", candidate_amount=500.0, candidate_date=BASE_DATE,
            query_direction="CREDIT", candidate_direction="DEBIT",
        )
        self.assertEqual(original.confidence, reversal.confidence)
        self.assertFalse(original.direction_conflict)
        self.assertTrue(reversal.direction_conflict)
        self.assertNotEqual(
            self.matcher.route_by_confidence_wall(reversal), ConfidenceWall.AUTO_MATCH,
        )
        self.assertEqual(self.matcher.route_by_confidence_wall(reversal), ConfidenceWall.EXCEPTION)

    # 14. Debit vs credit --------------------------------------------------------------
    def test_score_candidate_now_has_direction_parameters_and_enforces_them(self):
        """FIXED (was FINDING): score_candidate() now takes query_direction
        and candidate_direction. This isn't a fuzzy score input - it's
        consulted as a hard pre-filter in route_by_confidence_wall(), so a
        debit can never be routed to AUTO_MATCH against a credit no matter
        how strong name/amount/date are."""
        import inspect
        params = inspect.signature(self.matcher.score_candidate).parameters
        self.assertIn("query_direction", params)
        self.assertIn("candidate_direction", params)

        c = self.score(
            query_text="Amazon", query_amount=999.0, query_date=BASE_DATE,
            candidate_merchant="Amazon", candidate_amount=999.0, candidate_date=BASE_DATE,
            historical_encounters=25, trust_state="PERMANENT",
            query_direction="DEBIT", candidate_direction="CREDIT",
        )
        self.assertEqual(self.matcher.route_by_confidence_wall(c), ConfidenceWall.EXCEPTION)

    # 15. Partial data -----------------------------------------------------------------
    def test_missing_amount_falls_back_to_neutral_score(self):
        c = self.score(
            query_text="Amazon", query_amount=None, query_date=BASE_DATE,
            candidate_merchant="Amazon", candidate_amount=500.0, candidate_date=BASE_DATE,
        )
        self.assertEqual(c.scoring_factors.amount_match, 0.5)

    def test_missing_date_falls_back_to_neutral_score(self):
        c = self.score(
            query_text="Amazon", query_amount=500.0, query_date=None,
            candidate_merchant="Amazon", candidate_amount=500.0, candidate_date=BASE_DATE,
        )
        self.assertEqual(c.scoring_factors.temporal_proximity, 0.5)

    def test_missing_amount_and_date_never_reaches_auto_match(self):
        """FINDING (safe direction): with both amount and date missing, name
        similarity is the only real signal left, but two neutral 0.5 scores
        still contribute 50% of the weighted aggregate - confidence lands
        around 0.50, well short of AUTO_MATCH. Partial data is safely
        conservative here, purely as a side effect of the confidence math,
        not because of an explicit "insufficient data" rule."""
        c = self.score(
            query_text="Amazon", query_amount=None, query_date=None,
            candidate_merchant="Amazon", candidate_amount=500.0, candidate_date=BASE_DATE,
        )
        self.assertEqual(self.matcher.route_by_confidence_wall(c), ConfidenceWall.EXCEPTION)


class PDFIngestionEdgeCases(unittest.TestCase):
    """statements.pdf_parser.GooglePayStatementParser against malformed,
    empty, and duplicate document uploads. No database or FastAPI app
    required - the parser is a pure text-in/records-out component."""

    # 16. Malformed PDF -----------------------------------------------------------------
    def test_garbage_bytes_raise_corrupted_pdf_error(self):
        with self.assertRaises(CorruptedPDFError):
            statement_parser.open_and_inspect(b"this is not a pdf at all")

    def test_truncated_pdf_header_raises_corrupted_pdf_error(self):
        with self.assertRaises(CorruptedPDFError):
            statement_parser.open_and_inspect(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3")

    def test_real_pdf_that_passes_header_check_but_fails_text_extraction(self):
        """FINDING: mock/gpay_statement_20260101_20260630.pdf is a real,
        non-empty PDF (267KB, valid %PDF-1.5 header) whose xref table pypdf
        tolerates with a warning ("incorrect startxref pointer") -
        open_and_inspect() succeeds and reports 19 pages. But pdfplumber
        (via pdfminer) refuses the same bytes outright ("No /Root object! -
        Is this really a PDF?") once extract_text() is called. The two PDF
        libraries disagree on whether this file is valid, so a file can pass
        Vela's own "is this a readable PDF" gate and still hard-fail one
        step later - the error surfaces as a second, separate
        CorruptedPDFError from extract_text() rather than being caught
        up front."""
        with open("mock/gpay_statement_20260101_20260630.pdf", "rb") as f:
            raw = f.read()
        page_count, _ = statement_parser.open_and_inspect(raw)
        self.assertGreater(page_count, 0)
        with self.assertRaises(CorruptedPDFError):
            statement_parser.extract_text(raw)

    def test_valid_pdf_wrong_layout_raises_unsupported_statement_error(self):
        with self.assertRaises(UnsupportedStatementError):
            statement_parser.validate_signature("this text has none of the required markers")

    # 17. Empty source ------------------------------------------------------------------
    def test_empty_bytes_raise_corrupted_pdf_error(self):
        with self.assertRaises(CorruptedPDFError):
            statement_parser.open_and_inspect(b"")

    def test_empty_extracted_text_parses_to_zero_transactions_not_an_error(self):
        """An empty text body isn't a parse error - it's zero transactions.
        Correct: an empty statement shouldn't be treated as corrupted."""
        self.assertEqual(statement_parser.parse_transactions(""), [])

    # 18. Duplicate upload -----------------------------------------------------------------
    def test_parsing_the_same_upload_twice_is_deterministic(self):
        """The parser itself has no dedup responsibility (dedup happens at
        repositories/transaction_repository.py via an upsert on
        (user_id, reference_number) - see that file's docstring, not
        exercised here since it needs Mongo). What the parser must guarantee
        is determinism: re-parsing an identical upload produces byte-for-byte
        identical records, so the repository's upsert key is stable across
        re-uploads of the same statement."""
        with open("assets/gpay_statement_20260201_20260731.pdf", "rb") as f:
            raw = f.read()
        text = statement_parser.extract_text(raw)
        first = statement_parser.parse_transactions(text)
        second = statement_parser.parse_transactions(text)

        self.assertGreater(len(first), 0)
        self.assertEqual(len(first), len(second))
        self.assertEqual(
            [t.reference_number for t in first],
            [t.reference_number for t in second],
        )
        self.assertEqual(
            [(t.amount, t.counterparty_raw, t.timestamp) for t in first],
            [(t.amount, t.counterparty_raw, t.timestamp) for t in second],
        )

    def test_real_statement_end_to_end_smoke(self):
        """Sanity check that the whole pipeline still works on a genuinely
        valid statement, so the malformed-file tests above are contrasted
        against a known-good baseline rather than tested in isolation."""
        with open("assets/gpay_statement_20260201_20260731.pdf", "rb") as f:
            raw = f.read()
        page_count, _ = statement_parser.open_and_inspect(raw)
        text = statement_parser.extract_text(raw)
        statement_parser.validate_signature(text)
        txns = statement_parser.parse_transactions(text)

        self.assertGreater(page_count, 0)
        self.assertGreater(len(txns), 0)
        for t in txns:
            self.assertIn(t.direction, ("Paid to", "Received from"))
            self.assertGreater(t.amount, 0)


if __name__ == "__main__":
    unittest.main()
