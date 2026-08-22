"""
Unit tests for Wave 4 AI Entity Resolution Matcher
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
        """Partial string matches should score moderately."""
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
        """Candidate with matching name, amount, and date should score high."""
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


if __name__ == "__main__":
    unittest.main()
