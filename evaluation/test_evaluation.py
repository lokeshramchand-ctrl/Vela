"""
Wave 8: Evaluation harness tests.

These are the acceptance tests for the "Track 04" story: given a synthetic
dataset with withheld ground truth, run the real matcher and prove that it
(a) is precise when it commits to an auto-match, (b) never launders a known
non-match or a genuinely ambiguous case into an unsafe auto-match, and (c)
costs less, by its own false-match economics, than a naive always-commit
baseline.
"""

import unittest
from datetime import datetime

from ai_resolution.matcher import AIEntityMatcher, ConfidenceWall, ScoringFactors
from evaluation.dataset import (
    AMBIGUOUS_COUNT,
    KNOWN_EXCEPTION_COUNT,
    TOTAL_B_RECORDS,
    TRUE_MATCH_COUNT,
    CaseCategory,
    generate_dataset,
)
from evaluation.harness import Outcome, naive_baseline_cost, run_evaluation


class TestDatasetGroundTruth(unittest.TestCase):
    """The dataset itself must match the Track 04 evaluation brief exactly."""

    def setUp(self):
        self.dataset = generate_dataset(seed=42)

    def test_record_counts(self):
        self.assertEqual(len(self.dataset.source_a), 250)
        self.assertEqual(len(self.dataset.source_b), TOTAL_B_RECORDS)

    def test_case_category_counts(self):
        counts = {category: 0 for category in CaseCategory}
        for case in self.dataset.cases:
            counts[case.category] += 1

        self.assertEqual(counts[CaseCategory.TRUE_MATCH], TRUE_MATCH_COUNT)
        self.assertEqual(counts[CaseCategory.KNOWN_EXCEPTION], KNOWN_EXCEPTION_COUNT)
        self.assertEqual(counts[CaseCategory.AMBIGUOUS], AMBIGUOUS_COUNT)
        self.assertEqual(sum(counts.values()), 250)

    def test_true_match_cases_have_a_real_partner(self):
        b_ids = {r.id for r in self.dataset.source_b}
        for case in self.dataset.cases:
            if case.category == CaseCategory.TRUE_MATCH:
                self.assertIsNotNone(case.true_b_id)
                self.assertIn(case.true_b_id, b_ids)

    def test_known_exception_and_ambiguous_cases_have_no_true_partner(self):
        for case in self.dataset.cases:
            if case.category in (CaseCategory.KNOWN_EXCEPTION, CaseCategory.AMBIGUOUS):
                self.assertIsNone(case.true_b_id)

    def test_ambiguous_cases_have_two_candidates(self):
        for case in self.dataset.cases:
            if case.category == CaseCategory.AMBIGUOUS:
                self.assertEqual(len(case.candidate_b_ids), 2)

    def test_deterministic_given_seed(self):
        rerun = generate_dataset(seed=42)
        self.assertEqual(
            [r.id for r in self.dataset.source_a], [r.id for r in rerun.source_a],
        )
        self.assertEqual(
            [c.category for c in self.dataset.cases], [c.category for c in rerun.cases],
        )


class TestConfidenceCeilingFinding(unittest.TestCase):
    """FIXED in Phase 2 (testing/edge-case-matching branch). This class used
    to document that AUTO_MATCH (>0.90) was mathematically unreachable.

    Two compounding bugs caused it:

    1. `ScoringFactors.aggregate()` built its weighted sum by looking up
       `getattr(self, key.replace("_factor", ""))` for each weight key. For
       "trust_state_factor" that stripped to "trust_state", which was never
       an attribute on ScoringFactors (the real attribute is
       "trust_state_factor") - so that weight's entire 0.10 contribution was
       silently dropped from every aggregate, regardless of its value.
    2. `NameSimilarityMatcher.score()` declared an "exact_alias" weight
       (0.20) but never multiplied it into the score, so even a
       byte-identical merchant name topped out at 0.50-0.80 instead of up
       to 1.0.

    Fixing only one of the two still left the best case just under 0.90
    (see ai_resolution/matcher.py's score() and ScoringFactors.aggregate()
    for the fix and evaluation/EDGE_CASE_REPORT.md finding 1 for the
    original diagnosis). With both fixed, the true ceiling is ~0.996 and a
    maximal-trust exact match now clears AUTO_MATCH - verified here against
    ScoringFactors and AIEntityMatcher directly, not just re-asserted.
    """

    def test_maximum_possible_confidence_now_clears_the_auto_match_wall(self):
        best_case = ScoringFactors(
            name_similarity=1.0,  # exact + abbreviation match, post-fix ceiling
            amount_match=1.0,  # exact amount match
            temporal_proximity=1.0,  # same-day
            historical_context=0.95,  # >20 historical encounters ceiling
            trust_state_factor=1.15,  # PERMANENT trust, now applied
        )
        self.assertAlmostEqual(best_case.aggregate(), 1.0, places=3)
        self.assertGreaterEqual(best_case.aggregate(), AIEntityMatcher().high_confidence_threshold)

    def test_trust_state_factor_now_affects_aggregate(self):
        low_trust = ScoringFactors(0.80, 1.0, 1.0, 0.95, trust_state_factor=0.0)
        high_trust = ScoringFactors(0.80, 1.0, 1.0, 0.95, trust_state_factor=100.0)
        self.assertLess(low_trust.aggregate(), high_trust.aggregate())

    def test_ideal_ubers_style_case_now_reaches_auto_match(self):
        """An abbreviation-boosted, exact-amount, same-day, well-known-merchant
        match with maximal historical trust - about as strong a case as the
        matcher can ever see - now clears the AUTO_MATCH wall."""
        matcher = AIEntityMatcher()
        candidate = matcher.score_candidate(
            query_text="UBER",
            query_amount=500.0,
            query_date=datetime(2026, 1, 1),
            candidate_merchant="UBER",
            candidate_amount=500.0,
            candidate_date=datetime(2026, 1, 1),
            historical_encounters=25,
            trust_state="PERMANENT",
        )
        self.assertEqual(matcher.route_by_confidence_wall(candidate), ConfidenceWall.AUTO_MATCH)


class TestEvaluationHarness(unittest.TestCase):
    """Run the real matcher blind (no ground truth) and score its decisions."""

    @classmethod
    def setUpClass(cls):
        cls.dataset = generate_dataset(seed=42)
        cls.result = run_evaluation(cls.dataset)

    def test_processes_every_record(self):
        self.assertEqual(self.result.records_processed, 250)
        self.assertEqual(len(self.result.case_results), 250)

    def test_throughput_is_reported_and_positive(self):
        self.assertGreater(self.result.throughput_per_second, 0)
        self.assertGreaterEqual(self.result.elapsed_seconds, 0)

    def test_precision_is_high(self):
        # Every auto-match Vela commits to should almost always be correct -
        # that's the entire point of the confidence wall. Given the confidence
        # ceiling documented in TestConfidenceCeilingFinding, auto_match_count
        # may legitimately be 0 for this dataset, in which case precision is
        # vacuously 1.0 - there is simply nothing to be wrong about.
        self.assertGreaterEqual(self.result.precision, 0.95)

    def test_exception_rate_is_reported(self):
        self.assertGreater(self.result.exception_rate, 0.0)
        self.assertLessEqual(self.result.exception_rate, 1.0)

    def test_recall_is_reasonable(self):
        # Recall (discovery: did Vela surface the true partner at all, auto or
        # reviewed) should be high even though automation_rate may be low or
        # zero - discovering the right answer and being willing to commit to
        # it unsupervised are two different things.
        self.assertGreater(self.result.recall, 0.5)

    def test_known_exceptions_are_never_auto_matched(self):
        """The core false-match-cost story: a record engineered to look like a
        match but that has no true partner must never be auto-matched."""
        known_exception_results = [
            r for r in self.result.case_results if r.category == CaseCategory.KNOWN_EXCEPTION
        ]
        self.assertEqual(len(known_exception_results), KNOWN_EXCEPTION_COUNT)
        false_matches = [
            r for r in known_exception_results if r.routing_decision == ConfidenceWall.AUTO_MATCH
        ]
        self.assertEqual(
            len(false_matches), 0,
            f"Vela auto-matched {len(false_matches)} known-exception record(s) it should have "
            f"flagged instead: {[r.a_id for r in false_matches]}",
        )

    def test_ambiguous_cases_are_never_auto_matched(self):
        """Two near-tied candidates must never be silently resolved by picking one."""
        ambiguous_results = [r for r in self.result.case_results if r.category == CaseCategory.AMBIGUOUS]
        self.assertEqual(len(ambiguous_results), AMBIGUOUS_COUNT)
        false_matches = [r for r in ambiguous_results if r.routing_decision == ConfidenceWall.AUTO_MATCH]
        self.assertEqual(
            len(false_matches), 0,
            f"Vela auto-matched {len(false_matches)} ambiguous record(s) instead of flagging "
            f"the tie: {[r.a_id for r in false_matches]}",
        )

    def test_zero_unsafe_auto_matches_overall(self):
        """No FALSE_AUTO_MATCH outcome should exist anywhere in the run."""
        false_matches = [r for r in self.result.case_results if r.outcome == Outcome.FALSE_AUTO_MATCH]
        self.assertEqual(self.result.false_match_count, 0)
        self.assertEqual(false_matches, [])

    def test_summary_is_serializable(self):
        summary = self.result.summary()
        for key in ("precision", "recall", "exception_rate", "throughput_per_second", "false_match_count"):
            self.assertIn(key, summary)


class TestFalseMatchCostStory(unittest.TestCase):
    """Vela prefers an exception over an unsafe reconciliation - prove it
    quantitatively against a naive baseline that always commits."""

    @classmethod
    def setUpClass(cls):
        cls.dataset = generate_dataset(seed=42)
        cls.result = run_evaluation(cls.dataset)
        cls.baseline_cost = naive_baseline_cost(cls.dataset)

    def test_vela_cost_is_far_lower_than_naive_baseline(self):
        vela_cost = self.result.total_false_match_cost
        self.assertLess(vela_cost, self.baseline_cost)
        # Vela's conservative routing should cost only a small fraction of a
        # matcher that always commits to its top-scored candidate.
        self.assertLess(vela_cost, self.baseline_cost * 0.25)

    def test_naive_baseline_incurs_false_match_cost(self):
        # Sanity check on the counterfactual itself: without a confidence
        # wall, the known-exception and ambiguous traps should cost it dearly.
        self.assertGreater(self.baseline_cost, 0)


if __name__ == "__main__":
    unittest.main()
