"""
Phase 8: tests for the Track 04 qualification benchmark
(generate_track04_benchmark(), evaluation/dataset.py) - the Wave 8 250/250
core plus five additional adversarial categories, 300/300 records total.

Kept as its own file rather than added to evaluation/test_evaluation.py so
Wave 8's original 20 tests (asserting the untouched 250/250 dataset) stay
exactly as they were - see evaluation/dataset.py's generate_dataset()
docstring for how backward compatibility is preserved (the
extra_categories flag defaults to False).
"""

import unittest

from ai_resolution.matcher import ConfidenceWall
from evaluation.dataset import (
    DIRECTION_CONFLICT_COUNT,
    DUPLICATE_CANDIDATE_COUNT,
    MISSING_RECORD_COUNT,
    PARTIAL_METADATA_COUNT,
    PHASE8_TOTAL_A_RECORDS,
    PHASE8_TOTAL_B_RECORDS,
    RECURRING_COUNT,
    CaseCategory,
    generate_dataset,
    generate_track04_benchmark,
)
from evaluation.harness import Outcome, run_evaluation


class TestBackwardCompatibility(unittest.TestCase):
    """generate_dataset()'s default behavior (extra_categories=False, what
    every Wave 8 test calls) must be provably untouched by Phase 8."""

    def test_default_call_matches_wave8_record_counts_exactly(self):
        dataset = generate_dataset(seed=42)
        self.assertEqual(len(dataset.source_a), 250)
        self.assertEqual(len(dataset.source_b), 250)
        self.assertEqual(len(dataset.cases), 250)
        categories = {c.category for c in dataset.cases}
        self.assertEqual(
            categories, {CaseCategory.TRUE_MATCH, CaseCategory.KNOWN_EXCEPTION, CaseCategory.AMBIGUOUS},
        )


class TestTrack04BenchmarkStructure(unittest.TestCase):
    def setUp(self):
        self.dataset = generate_track04_benchmark(seed=42)

    def test_record_counts_are_at_least_250_250(self):
        self.assertGreaterEqual(len(self.dataset.source_a), 250)
        self.assertGreaterEqual(len(self.dataset.source_b), 250)
        self.assertEqual(len(self.dataset.source_a), PHASE8_TOTAL_A_RECORDS)
        self.assertEqual(len(self.dataset.source_b), PHASE8_TOTAL_B_RECORDS)

    def test_wave8_core_categories_are_unchanged_in_count(self):
        counts = {category: 0 for category in CaseCategory}
        for case in self.dataset.cases:
            counts[case.category] += 1
        self.assertEqual(counts[CaseCategory.TRUE_MATCH], 221)
        self.assertEqual(counts[CaseCategory.KNOWN_EXCEPTION], 21)
        self.assertEqual(counts[CaseCategory.AMBIGUOUS], 8)

    def test_all_five_phase8_categories_present_at_expected_counts(self):
        counts = {category: 0 for category in CaseCategory}
        for case in self.dataset.cases:
            counts[case.category] += 1
        self.assertEqual(counts[CaseCategory.DIRECTION_CONFLICT], DIRECTION_CONFLICT_COUNT)
        self.assertEqual(counts[CaseCategory.RECURRING], RECURRING_COUNT)
        self.assertEqual(counts[CaseCategory.PARTIAL_METADATA], PARTIAL_METADATA_COUNT)
        self.assertEqual(counts[CaseCategory.MISSING_RECORD], MISSING_RECORD_COUNT)
        self.assertEqual(counts[CaseCategory.DUPLICATE_CANDIDATE], DUPLICATE_CANDIDATE_COUNT)

    def test_deterministic_given_seed(self):
        rerun = generate_track04_benchmark(seed=42)
        self.assertEqual([r.id for r in self.dataset.source_a], [r.id for r in rerun.source_a])
        self.assertEqual([r.id for r in self.dataset.source_b], [r.id for r in rerun.source_b])
        self.assertEqual(
            [(c.a_id, c.category, c.true_b_id) for c in self.dataset.cases],
            [(c.a_id, c.category, c.true_b_id) for c in rerun.cases],
        )

    def test_ground_truth_never_leaks_into_the_scorable_record(self):
        """LedgerRecord.as_dict() - what a caller would actually hand to a
        real matching pipeline - must never include canonical_entity (the
        withheld ground-truth identity)."""
        for record in self.dataset.source_a + self.dataset.source_b:
            self.assertNotIn("canonical_entity", record.as_dict())

    def test_direction_conflict_candidates_have_opposing_direction(self):
        b_by_id = self.dataset.b_by_id()
        a_by_id = self.dataset.a_by_id()
        for case in self.dataset.cases:
            if case.category != CaseCategory.DIRECTION_CONFLICT:
                continue
            a_record = a_by_id[case.a_id]
            self.assertIsNone(case.true_b_id)
            self.assertEqual(len(case.candidate_b_ids), 1)
            b_record = b_by_id[case.candidate_b_ids[0]]
            self.assertNotEqual(a_record.direction, b_record.direction)
            self.assertEqual(a_record.amount, b_record.amount)
            self.assertEqual(a_record.date, b_record.date)

    def test_recurring_candidates_are_a_true_match_about_thirty_days_apart(self):
        b_by_id = self.dataset.b_by_id()
        a_by_id = self.dataset.a_by_id()
        for case in self.dataset.cases:
            if case.category != CaseCategory.RECURRING:
                continue
            self.assertIsNotNone(case.true_b_id)
            a_record, b_record = a_by_id[case.a_id], b_by_id[case.true_b_id]
            self.assertEqual(a_record.direction, b_record.direction)
            self.assertEqual(a_record.amount, b_record.amount)
            gap = abs((b_record.date - a_record.date).days)
            self.assertGreaterEqual(gap, 28)
            self.assertLessEqual(gap, 32)

    def test_partial_metadata_candidates_are_missing_exactly_one_field(self):
        a_by_id = self.dataset.a_by_id()
        for case in self.dataset.cases:
            if case.category != CaseCategory.PARTIAL_METADATA:
                continue
            a_record = a_by_id[case.a_id]
            self.assertIsNotNone(case.true_b_id)
            missing = [a_record.amount is None, a_record.date is None]
            self.assertEqual(sum(missing), 1, "exactly one of amount/date must be missing")

    def test_missing_record_cases_have_no_candidates_at_all(self):
        for case in self.dataset.cases:
            if case.category != CaseCategory.MISSING_RECORD:
                continue
            self.assertIsNone(case.true_b_id)
            self.assertEqual(case.candidate_b_ids, [])

    def test_duplicate_candidate_cases_have_two_byte_identical_candidates(self):
        b_by_id = self.dataset.b_by_id()
        for case in self.dataset.cases:
            if case.category != CaseCategory.DUPLICATE_CANDIDATE:
                continue
            self.assertIsNone(case.true_b_id)
            self.assertEqual(len(case.candidate_b_ids), 2)
            dup1, dup2 = (b_by_id[bid] for bid in case.candidate_b_ids)
            self.assertEqual(dup1.text, dup2.text)
            self.assertEqual(dup1.amount, dup2.amount)
            self.assertEqual(dup1.date, dup2.date)
            self.assertNotEqual(dup1.id, dup2.id)


class TestTrack04BenchmarkSafety(unittest.TestCase):
    """The real acceptance test for Phase 8: run the actual matcher
    (Phases 1-3 fixes included) over the full 300-record benchmark and
    confirm the safety property holds on every new adversarial category,
    not just the original Wave 8 250."""

    @classmethod
    def setUpClass(cls):
        cls.dataset = generate_track04_benchmark(seed=42)
        cls.result = run_evaluation(cls.dataset)

    def test_zero_false_auto_matches_across_the_full_benchmark(self):
        self.assertEqual(self.result.false_match_count, 0)

    def test_direction_conflict_cases_are_never_auto_matched(self):
        by_category = {(r.a_id): r for r in self.result.case_results}
        for case in self.dataset.cases:
            if case.category != CaseCategory.DIRECTION_CONFLICT:
                continue
            result = by_category[case.a_id]
            self.assertNotEqual(result.routing_decision, ConfidenceWall.AUTO_MATCH)
            self.assertIn(result.outcome, (Outcome.CORRECT_EXCEPTION,))

    def test_duplicate_candidate_cases_are_never_auto_matched(self):
        by_category = {(r.a_id): r for r in self.result.case_results}
        for case in self.dataset.cases:
            if case.category != CaseCategory.DUPLICATE_CANDIDATE:
                continue
            result = by_category[case.a_id]
            self.assertNotEqual(result.routing_decision, ConfidenceWall.AUTO_MATCH)

    def test_missing_record_cases_decline_cleanly(self):
        by_category = {(r.a_id): r for r in self.result.case_results}
        for case in self.dataset.cases:
            if case.category != CaseCategory.MISSING_RECORD:
                continue
            result = by_category[case.a_id]
            self.assertIsNone(result.predicted_b_id)
            self.assertNotEqual(result.routing_decision, ConfidenceWall.AUTO_MATCH)

    def test_recurring_cases_are_found_but_not_auto_matched(self):
        """Documents Finding 3 (docs/PHASE4_PERIODICITY.md) at the benchmark
        level: recurring subscriptions are real true matches (correctly
        surfaced to a human), but the temporal gap keeps every one of them
        out of AUTO_MATCH today - this is the concrete cost of leaving
        periodicity un-wired, made visible as a number rather than an
        abstract description."""
        by_category = {(r.a_id): r for r in self.result.case_results}
        recurring_results = [
            by_category[case.a_id] for case in self.dataset.cases if case.category == CaseCategory.RECURRING
        ]
        self.assertEqual(len(recurring_results), RECURRING_COUNT)
        for result in recurring_results:
            self.assertNotEqual(result.routing_decision, ConfidenceWall.AUTO_MATCH)
            self.assertEqual(result.outcome, Outcome.CORRECT_HUMAN_REVIEW)

    def test_summary_reports_at_least_250_250_records(self):
        self.assertGreaterEqual(len(self.dataset.source_a), 250)
        self.assertGreaterEqual(len(self.dataset.source_b), 250)
        self.assertEqual(self.result.records_processed, len(self.dataset.cases))


if __name__ == "__main__":
    unittest.main()
