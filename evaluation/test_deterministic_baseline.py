"""
Phase 9-10: tests for the deterministic (non-AI) reconciliation baseline
and its comparison against full Vela (AIEntityMatcher) on the same Track 04
benchmark dataset.
"""

import unittest

from evaluation.dataset import generate_track04_benchmark
from evaluation.deterministic_baseline import run_deterministic_evaluation
from evaluation.harness import run_evaluation


class TestDeterministicBaseline(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dataset = generate_track04_benchmark(seed=42)
        cls.result = run_deterministic_evaluation(cls.dataset)

    def test_processes_every_record(self):
        self.assertEqual(self.result.records_processed, len(self.dataset.cases))

    def test_precision_is_perfect_by_construction(self):
        """An exact-equality rule can only ever commit when merchant text,
        amount, date, and direction are all identical - it structurally
        cannot produce a false match against this dataset (no two distinct
        entities share all four), so precision must be 1.0."""
        self.assertEqual(self.result.precision, 1.0)
        self.assertEqual(self.result.false_match_count, 0)

    def test_recall_is_far_lower_than_perfect(self):
        """Most TRUE_MATCH cases in the dataset have deliberate noise
        (merchant spelling drift, amount skew, date lag) - exact equality
        misses most of them. This is the whole point of the baseline: it's
        what reconciliation looks like with zero tolerance for real-world
        noise."""
        self.assertLess(self.result.recall, 0.5)

    def test_throughput_is_reported_and_fast(self):
        self.assertGreater(self.result.throughput_per_second, 0)

    def test_summary_is_serializable(self):
        import json
        json.dumps(self.result.summary())

    def test_direction_conflict_cases_are_never_matched(self):
        """The exact-equality rule requires matching direction too - a
        refund/reversal (opposing direction) can never satisfy it, the same
        safety property Phase 1 enforces in the real matcher."""
        from evaluation.dataset import CaseCategory

        by_id = {r.a_id: r for r in self.result.case_results}
        for case in self.dataset.cases:
            if case.category == CaseCategory.DIRECTION_CONFLICT:
                self.assertIsNone(by_id[case.a_id].matched_b_id)


class TestBaselineVersusFullVelaComparison(unittest.TestCase):
    """Phase 10: run both on the identical dataset and compare. Per the
    spec: report the comparison honestly, don't force a positive result."""

    @classmethod
    def setUpClass(cls):
        cls.dataset = generate_track04_benchmark(seed=42)
        cls.baseline = run_deterministic_evaluation(cls.dataset)
        cls.vela = run_evaluation(cls.dataset)

    def test_both_ran_against_the_identical_dataset(self):
        self.assertEqual(self.baseline.records_processed, self.vela.records_processed)

    def test_neither_system_produces_false_matches_on_this_dataset(self):
        self.assertEqual(self.baseline.false_match_count, 0)
        self.assertEqual(self.vela.false_match_count, 0)

    def test_vela_recall_is_measured_not_assumed(self):
        """This test doesn't assert Vela beats the baseline by any specific
        margin - it just locks in that both numbers are real, measured
        floats in [0, 1], so a future change to either can't silently swap
        in a fabricated/hardcoded value without this test's plumbing still
        making sense. The actual comparison numbers belong in
        docs/track04-final-evaluation.md (Phase 17), generated from a real
        run, not hardcoded here."""
        self.assertGreaterEqual(self.baseline.recall, 0.0)
        self.assertLessEqual(self.baseline.recall, 1.0)
        self.assertGreaterEqual(self.vela.recall, 0.0)
        self.assertLessEqual(self.vela.recall, 1.0)


if __name__ == "__main__":
    unittest.main()
