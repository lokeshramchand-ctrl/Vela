"""
Unit tests for Wave 4-5 AI Entity Resolution Matcher

Wave 4: Semantic candidate generation and confidence scoring
Wave 5: Confidence walls and exception management
"""

import unittest
from datetime import datetime, timedelta
from .matcher import (
    AIEntityMatcher,
    NameSimilarityMatcher,
    AmountMatcher,
    TemporalProximityMatcher,
    EntityCandidate,
    ScoringFactors,
    ConfidenceWall,
    ExceptionReason,
)


class TestNameSimilarityMatcher(unittest.TestCase):
    """Test merchant name similarity matching."""

    def setUp(self):
        self.matcher = NameSimilarityMatcher()

    def test_exact_match(self):
        """Exact matches should score high."""
        score = self.matcher.score("UBER", "UBER")
        self.assertGreater(score, 0.95)

    def test_case_insensitive(self):
        """Matching should be case-insensitive."""
        score = self.matcher.score("uber", "UBER")
        self.assertGreater(score, 0.95)

    def test_partial_match(self):
        """Partial string matches should score moderately.

        KNOWN PRE-EXISTING GAP (not fixed by Phase 2): this asserts >0.70 for
        a substring match ("AMAZON PAY" contains "AMAZON") that is neither
        byte-identical (exact_alias) nor in the hardcoded abbreviation stub,
        so it only ever earns Levenshtein's 0.50 weight (~0.375 here). Unlike
        exact_alias (a declared-but-unapplied weight - a genuine bug, fixed
        in Phase 2) and trust_state_factor (a dict-key typo - also fixed),
        this gap has no missing-but-declared weight to apply: it would need a
        new substring/fuzzy-credit heuristic that doesn't exist yet anywhere
        in NameSimilarityMatcher. That's a real ML-quality improvement, but a
        different, undeclared one - out of scope for the findings this
        branch investigates (EDGE_CASE_REPORT.md findings 1-4)."""
        score = self.matcher.score("AMAZON PAY", "AMAZON")
        self.assertGreater(score, 0.70)
        self.assertLess(score, 1.0)

    def test_abbreviation_match(self):
        """Known abbreviations should be recognized."""
        score = self.matcher.score("AMZN", "AMAZON")
        self.assertGreater(score, 0.50)

    def test_no_match(self):
        """Very different strings should score low."""
        score = self.matcher.score("AMAZON", "SWIGGY")
        self.assertLess(score, 0.3)


class TestAmountMatcher(unittest.TestCase):
    """Test amount-based transaction matching."""

    def setUp(self):
        self.matcher = AmountMatcher(tolerance_pct=0.05)

    def test_exact_amount_match(self):
        """Exact amount match should score perfectly."""
        score = self.matcher.score(100.0, 100.0)
        self.assertEqual(score, 1.0)

    def test_within_tolerance(self):
        """Amounts within tolerance should score partially."""
        score = self.matcher.score(100.0, 102.0)  # 2% difference, tolerance is 5%
        self.assertGreater(score, 0.65)

    def test_outside_tolerance(self):
        """Amounts outside tolerance should score zero."""
        score = self.matcher.score(100.0, 110.0)  # 10% difference, tolerance is 5%
        self.assertEqual(score, 0.0)

    def test_missing_amount_neutral(self):
        """Missing amount data should return neutral score."""
        score = self.matcher.score(None, 100.0)
        self.assertEqual(score, 0.5)


class TestTemporalProximityMatcher(unittest.TestCase):
    """Test temporal proximity matching."""

    def setUp(self):
        self.matcher = TemporalProximityMatcher(max_days=3)
        self.base_date = datetime(2024, 8, 11)

    def test_same_day(self):
        """Same-day transactions should score perfectly."""
        score = self.matcher.score(self.base_date, self.base_date)
        self.assertEqual(score, 1.0)

    def test_adjacent_day(self):
        """Adjacent days should score high."""
        next_day = self.base_date + timedelta(days=1)
        score = self.matcher.score(self.base_date, next_day)
        self.assertEqual(score, 0.9)

    def test_within_max_days(self):
        """Transactions within max_days should score > 0."""
        three_days = self.base_date + timedelta(days=3)
        score = self.matcher.score(self.base_date, three_days)
        self.assertGreater(score, 0.0)
        self.assertLess(score, 0.9)

    def test_beyond_max_days(self):
        """Transactions beyond max_days should score zero."""
        far_date = self.base_date + timedelta(days=5)
        score = self.matcher.score(self.base_date, far_date)
        self.assertEqual(score, 0.0)

    def test_missing_date_neutral(self):
        """Missing date should return neutral score."""
        score = self.matcher.score(None, self.base_date)
        self.assertEqual(score, 0.5)


class TestScoringFactors(unittest.TestCase):
    """Test scoring factor aggregation."""

    def test_equal_weighting(self):
        """Equal weighting should average all factors."""
        factors = ScoringFactors(
            name_similarity=1.0,
            amount_match=1.0,
            temporal_proximity=1.0,
            historical_context=1.0,
            trust_state_factor=1.0,
        )
        score = factors.aggregate()
        self.assertEqual(score, 1.0)

    def test_mixed_factors(self):
        """Aggregate should weight factors appropriately."""
        factors = ScoringFactors(
            name_similarity=0.90,
            amount_match=1.0,
            temporal_proximity=0.70,
            historical_context=0.60,
            trust_state_factor=0.85,
        )
        score = factors.aggregate()
        self.assertGreater(score, 0.70)
        self.assertLess(score, 0.95)

    def test_custom_weights(self):
        """Custom weights should override defaults."""
        factors = ScoringFactors(name_similarity=1.0, amount_match=0.0)
        # With default weights, amount_match has 30% weight, name_similarity 25%
        score_default = factors.aggregate()

        # With custom weights favoring name_similarity
        custom_weights = {
            "name_similarity": 0.9,
            "amount_match": 0.1,
        }
        score_custom = factors.aggregate(weights=custom_weights)
        self.assertGreater(score_custom, score_default)


class TestAIEntityMatcher(unittest.TestCase):
    """Integration tests for the main entity matcher."""

    def setUp(self):
        self.matcher = AIEntityMatcher()
        self.base_date = datetime(2024, 8, 11)

    def test_score_candidate_high_confidence(self):
        """Candidate with matching name, amount, and date should score high.

        KNOWN PRE-EXISTING GAP (not fixed by Phase 2): "UBER INDIA" vs "Uber"
        is the same substring-credit gap as test_partial_match above -
        "UBER INDIA" isn't a literal abbrev_map key and isn't byte-identical
        to "Uber", so name_similarity is Levenshtein-only (~0.286) and the
        aggregate lands at ~0.795, just under this test's >0.80 bar. Left
        failing and documented rather than fixed, since it needs the same
        out-of-scope substring heuristic, not the exact_alias/trust_state_factor
        fixes this branch makes."""
        candidate = self.matcher.score_candidate(
            query_text="UBER INDIA",
            query_amount=382.0,
            query_date=self.base_date,
            candidate_merchant="Uber",
            candidate_amount=382.0,
            candidate_date=self.base_date,
            historical_encounters=20,
            trust_state="PERMANENT",
        )
        self.assertGreater(candidate.confidence, 0.80)
        self.assertFalse(candidate.requires_human_review)

    def test_score_candidate_low_confidence(self):
        """Candidate with poor name match should score low and require review."""
        candidate = self.matcher.score_candidate(
            query_text="AMAZON PAY",
            query_amount=100.0,
            query_date=self.base_date,
            candidate_merchant="SWIGGY",
            candidate_amount=200.0,
            candidate_date=self.base_date + timedelta(days=5),
            historical_encounters=0,
            trust_state="EPHEMERAL",
        )
        self.assertLess(candidate.confidence, 0.75)
        self.assertTrue(candidate.requires_human_review)

    def test_rank_candidates(self):
        """Candidates should be ranked by confidence."""
        candidates = [
            EntityCandidate(
                merchant="Candidate A",
                confidence=0.60,
                scoring_factors=ScoringFactors(),
            ),
            EntityCandidate(
                merchant="Candidate B",
                confidence=0.95,
                scoring_factors=ScoringFactors(),
            ),
            EntityCandidate(
                merchant="Candidate C",
                confidence=0.75,
                scoring_factors=ScoringFactors(),
            ),
        ]
        ranked = self.matcher.rank_candidates(candidates, top_k=2)
        self.assertEqual(ranked[0].merchant, "Candidate B")
        self.assertEqual(ranked[1].merchant, "Candidate C")

    def test_filter_by_threshold(self):
        """Only candidates above threshold should pass."""
        candidates = [
            EntityCandidate(
                merchant="High",
                confidence=0.85,
                scoring_factors=ScoringFactors(),
            ),
            EntityCandidate(
                merchant="Low",
                confidence=0.60,
                scoring_factors=ScoringFactors(),
            ),
        ]
        filtered = self.matcher.filter_by_threshold(candidates, threshold=0.70)
        self.assertEqual(len(filtered), 1)
        self.assertEqual(filtered[0].merchant, "High")

    def test_propose_decision_high_confidence(self):
        """High-confidence candidates should not require review."""
        candidates = [
            EntityCandidate(
                merchant="Uber",
                confidence=0.96,
                scoring_factors=ScoringFactors(name_similarity=0.95),
            ),
        ]
        decision = self.matcher.propose_decision(candidates)
        self.assertFalse(decision.requires_human_review)

    def test_propose_decision_medium_confidence(self):
        """Medium-confidence candidates should require review."""
        candidates = [
            EntityCandidate(
                merchant="Ambiguous",
                confidence=0.72,
                scoring_factors=ScoringFactors(name_similarity=0.65),
            ),
        ]
        decision = self.matcher.propose_decision(candidates)
        self.assertTrue(decision.requires_human_review)

    def test_propose_decision_empty(self):
        """Empty candidate list should return None."""
        decision = self.matcher.propose_decision([])
        self.assertIsNone(decision)


class TestDirectionAwareMatching(unittest.TestCase):
    """Phase 1 regression tests: a debit must never auto-match a credit.

    Direction is a hard pre-filter enforced in route_by_confidence_wall(),
    not a fuzzy score penalty - so these tests check the routing decision
    and exception_reason, not just the raw confidence number.
    """

    def setUp(self):
        self.matcher = AIEntityMatcher()
        self.base_date = datetime(2024, 8, 11)

    def _score(self, query_direction=None, candidate_direction=None, **overrides):
        kwargs = dict(
            query_text="Amazon", query_amount=500.0, query_date=self.base_date,
            candidate_merchant="Amazon", candidate_amount=500.0, candidate_date=self.base_date,
            historical_encounters=25, trust_state="PERMANENT",
            query_direction=query_direction, candidate_direction=candidate_direction,
        )
        kwargs.update(overrides)
        return self.matcher.score_candidate(**kwargs)

    def test_debit_does_not_match_credit_even_with_perfect_signals(self):
        """Best possible name/amount/date signal, but query is a debit and
        the candidate is a credit - must be forced to EXCEPTION regardless
        of how high the raw confidence score is."""
        candidate = self._score(query_direction="DEBIT", candidate_direction="CREDIT")
        self.assertTrue(candidate.direction_conflict)
        self.assertEqual(self.matcher.route_by_confidence_wall(candidate), ConfidenceWall.EXCEPTION)

    def test_normal_payment_does_not_match_refund(self):
        """A refund (CREDIT) must not be treated as a match for the original
        debit purchase it's refunding, even with identical merchant/amount/date."""
        candidate = self._score(query_direction="DEBIT", candidate_direction="CREDIT")
        reason = self.matcher.detect_exception_reason(candidate, [candidate])
        self.assertEqual(reason, ExceptionReason.DIRECTION_MISMATCH)

    def test_normal_payment_does_not_match_reversal(self):
        """A same-day, same-amount reversal recorded with the same sign as
        the original (the realistic statement pattern from EDGE_CASE_REPORT
        finding 4) is only distinguishable by its direction column - this
        must still be caught even though amount/date/name all agree."""
        candidate = self._score(query_direction="CREDIT", candidate_direction="DEBIT")
        self.assertEqual(self.matcher.route_by_confidence_wall(candidate), ConfidenceWall.EXCEPTION)

    def test_reversal_does_not_match_original_payment(self):
        """Symmetric to the above: from the reversal's point of view, the
        original debit it's reversing must also be rejected as a match."""
        candidate = self._score(query_direction="DEBIT", candidate_direction="CREDIT")
        self.assertEqual(self.matcher.route_by_confidence_wall(candidate), ConfidenceWall.EXCEPTION)

    def test_compatible_same_direction_transactions_can_still_reconcile(self):
        """Two debits (the normal case: the same purchase reported on two
        ledgers) must not be penalized just because direction is now checked -
        direction_conflict must be False and the wall must be decided purely
        by confidence, same as before this change."""
        candidate = self._score(query_direction="DEBIT", candidate_direction="DEBIT")
        self.assertFalse(candidate.direction_conflict)

    def test_unknown_direction_is_not_treated_as_a_conflict(self):
        """Missing direction data (None on either side) must not be conflated
        with a *known* conflict - that would make every legacy record
        lacking direction metadata unmatchable. Missing data is already
        handled conservatively by the existing confidence math."""
        candidate = self._score(query_direction=None, candidate_direction="DEBIT")
        self.assertFalse(candidate.direction_conflict)
        candidate2 = self._score(query_direction=None, candidate_direction=None)
        self.assertFalse(candidate2.direction_conflict)

    def test_direction_check_is_case_insensitive(self):
        candidate = self._score(query_direction="debit", candidate_direction="DEBIT")
        self.assertFalse(candidate.direction_conflict)


class TestPhase2ConfidenceSemantics(unittest.TestCase):
    """Phase 2 regression tests: the four combinations the qualification
    spec calls out explicitly, now that exact-alias/trust_state_factor are
    fixed (Phase 2) and direction is a hard pre-filter (Phase 1)."""

    def setUp(self):
        self.matcher = AIEntityMatcher()
        self.base_date = datetime(2026, 3, 1)

    def test_case_a_exact_merchant_amount_direction_date_reaches_auto_match(self):
        """Strong evidence across every signal, with a compatible direction,
        is eligible for AUTO_MATCH."""
        c = self.matcher.score_candidate(
            query_text="Amazon", query_amount=999.0, query_date=self.base_date,
            candidate_merchant="Amazon", candidate_amount=999.0, candidate_date=self.base_date,
            historical_encounters=25, trust_state="PERMANENT",
            query_direction="DEBIT", candidate_direction="DEBIT",
        )
        self.assertEqual(self.matcher.route_by_confidence_wall(c), ConfidenceWall.AUTO_MATCH)

    def test_case_b_exact_merchant_amount_mismatch_does_not_auto_match(self):
        """Strong merchant similarity alone must not override conflicting
        financial evidence - a large amount discrepancy keeps this out of
        AUTO_MATCH even with a perfect name and maximal trust."""
        c = self.matcher.score_candidate(
            query_text="Amazon", query_amount=5000.0, query_date=self.base_date,
            candidate_merchant="Amazon", candidate_amount=1000.0, candidate_date=self.base_date,
            historical_encounters=25, trust_state="PERMANENT",
            query_direction="DEBIT", candidate_direction="DEBIT",
        )
        self.assertEqual(c.scoring_factors.amount_match, 0.0)
        self.assertNotEqual(self.matcher.route_by_confidence_wall(c), ConfidenceWall.AUTO_MATCH)

    def test_case_c_exact_merchant_incompatible_direction_does_not_auto_match(self):
        """Even the strongest possible name/amount/date signal must not
        auto-match across an incompatible direction - the hard pre-filter
        from Phase 1 holds after the Phase 2 confidence fix."""
        c = self.matcher.score_candidate(
            query_text="Amazon", query_amount=999.0, query_date=self.base_date,
            candidate_merchant="Amazon", candidate_amount=999.0, candidate_date=self.base_date,
            historical_encounters=25, trust_state="PERMANENT",
            query_direction="DEBIT", candidate_direction="CREDIT",
        )
        self.assertEqual(self.matcher.route_by_confidence_wall(c), ConfidenceWall.EXCEPTION)
        self.assertEqual(self.matcher.detect_exception_reason(c, [c]), ExceptionReason.DIRECTION_MISMATCH)

    def test_case_d_exact_merchant_duplicate_candidates_is_not_auto_matched(self):
        """Two byte-identical, maximally-confident candidates must not let
        propose_decision() pick one arbitrarily - detect_ambiguity() vetoes
        the auto-match, same veto pattern evaluation/harness.py already
        applies (harness.py:214-218), now confirmed against a candidate
        pair that (post-fix) clears AUTO_MATCH on its own."""
        kwargs = dict(
            query_text="Amazon", query_amount=999.0, query_date=self.base_date,
            candidate_merchant="Amazon", candidate_amount=999.0, candidate_date=self.base_date,
            historical_encounters=25, trust_state="PERMANENT",
            query_direction="DEBIT", candidate_direction="DEBIT",
        )
        c1 = self.matcher.score_candidate(**kwargs)
        c2 = self.matcher.score_candidate(**kwargs)
        ranked = self.matcher.rank_candidates([c1, c2])
        # Confirms the underlying candidates really would clear the wall in
        # isolation - the interesting assertion is the ambiguity veto below.
        self.assertEqual(self.matcher.route_by_confidence_wall(ranked[0]), ConfidenceWall.AUTO_MATCH)
        self.assertTrue(self.matcher.detect_ambiguity(ranked))


class TestConfidenceWalls(unittest.TestCase):
    """Test Wave 5 confidence wall routing."""

    def setUp(self):
        self.matcher = AIEntityMatcher(
            high_confidence_threshold=0.90,
            medium_confidence_threshold=0.65,
        )

    def test_route_auto_match_high_confidence(self):
        """Confidence > 0.90 should route to AUTO_MATCH."""
        candidate = EntityCandidate(
            merchant="Uber",
            confidence=0.95,
            scoring_factors=ScoringFactors(name_similarity=0.95),
        )
        wall = self.matcher.route_by_confidence_wall(candidate)
        self.assertEqual(wall, ConfidenceWall.AUTO_MATCH)

    def test_route_human_review_medium_confidence(self):
        """Confidence 0.65-0.90 should route to HUMAN_REVIEW."""
        candidate = EntityCandidate(
            merchant="Unknown Merchant",
            confidence=0.78,
            scoring_factors=ScoringFactors(name_similarity=0.72),
        )
        wall = self.matcher.route_by_confidence_wall(candidate)
        self.assertEqual(wall, ConfidenceWall.HUMAN_REVIEW)

    def test_route_exception_low_confidence(self):
        """Confidence < 0.65 should route to EXCEPTION."""
        candidate = EntityCandidate(
            merchant="Unclear",
            confidence=0.52,
            scoring_factors=ScoringFactors(name_similarity=0.45),
        )
        wall = self.matcher.route_by_confidence_wall(candidate)
        self.assertEqual(wall, ConfidenceWall.EXCEPTION)

    def test_detect_exception_reason_low_confidence(self):
        """Very low confidence should flag LOW_CONFIDENCE reason."""
        candidate = EntityCandidate(
            merchant="Unknown",
            confidence=0.35,
            scoring_factors=ScoringFactors(name_similarity=0.30),
        )
        reason = self.matcher.detect_exception_reason(candidate, [candidate])
        self.assertEqual(reason, ExceptionReason.LOW_CONFIDENCE)

    def test_detect_exception_reason_weak_name_match(self):
        """Poor name similarity should flag WEAK_NAME_MATCH."""
        candidate = EntityCandidate(
            merchant="Dissimilar",
            confidence=0.62,
            scoring_factors=ScoringFactors(
                name_similarity=0.40,
                amount_match=0.85,
                temporal_proximity=0.90,
            ),
        )
        reason = self.matcher.detect_exception_reason(candidate, [candidate])
        self.assertEqual(reason, ExceptionReason.WEAK_NAME_MATCH)

    def test_detect_ambiguity_similar_candidates(self):
        """Candidates within 5% confidence should be ambiguous."""
        candidates = [
            EntityCandidate(
                merchant="Option A",
                confidence=0.82,
                scoring_factors=ScoringFactors(),
            ),
            EntityCandidate(
                merchant="Option B",
                confidence=0.80,
                scoring_factors=ScoringFactors(),
            ),
        ]
        is_ambiguous = self.matcher.detect_ambiguity(candidates)
        self.assertTrue(is_ambiguous)

    def test_detect_ambiguity_clear_winner(self):
        """Clear confidence gap should not be ambiguous."""
        candidates = [
            EntityCandidate(
                merchant="Clear Winner",
                confidence=0.95,
                scoring_factors=ScoringFactors(),
            ),
            EntityCandidate(
                merchant="Far Behind",
                confidence=0.65,
                scoring_factors=ScoringFactors(),
            ),
        ]
        is_ambiguous = self.matcher.detect_ambiguity(candidates)
        self.assertFalse(is_ambiguous)

    def test_propose_decision_with_confidence_wall(self):
        """Proposed decision should include confidence wall routing."""
        candidates = [
            EntityCandidate(
                merchant="Uber",
                confidence=0.93,
                scoring_factors=ScoringFactors(name_similarity=0.92),
            ),
        ]
        decision = self.matcher.propose_decision(candidates)
        self.assertEqual(decision.confidence_wall, ConfidenceWall.AUTO_MATCH)
        self.assertFalse(decision.requires_human_review)

    def test_propose_decision_exception_with_reason(self):
        """Exception routing should include reason."""
        candidates = [
            EntityCandidate(
                merchant="Ambiguous",
                confidence=0.58,
                scoring_factors=ScoringFactors(name_similarity=0.40),
            ),
        ]
        decision = self.matcher.propose_decision(candidates)
        self.assertEqual(decision.confidence_wall, ConfidenceWall.EXCEPTION)
        self.assertIsNotNone(decision.exception_reason)
        self.assertTrue(decision.requires_human_review)


if __name__ == "__main__":
    unittest.main()
