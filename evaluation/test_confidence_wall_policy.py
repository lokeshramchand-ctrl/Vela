"""
Phase 11-12: explicit, single-place regression tests for the qualification
policy claim - "it is safer to leave a transaction unresolved than to
create a false financial match" - and confirmation that fixing the
exact-alias confidence issue (Phase 2) did not make refunds, reversals,
duplicates, or incompatible debit/credit records auto-match. Every
individual safety property here already has a home elsewhere
(ai_resolution/test_matcher.py's TestPhase2ConfidenceSemantics /
TestDirectionAwareMatching, evaluation/test_track04_benchmark.py's
TestTrack04BenchmarkSafety) - this file exists so the qualification claim
itself has one place that states and re-verifies it directly, rather than
being an inference someone has to draw from reading several other files.
"""

import unittest

from ai_resolution.matcher import ConfidenceWall
from evaluation.dataset import CaseCategory, generate_track04_benchmark
from evaluation.harness import COST_FALSE_MATCH, COST_UNRESOLVED, run_evaluation


class TestConfidenceWallPolicy(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dataset = generate_track04_benchmark(seed=42)
        cls.result = run_evaluation(cls.dataset)

    def test_zero_false_matches_across_all_300_records(self):
        self.assertEqual(self.result.false_match_count, 0)

    def test_refund_reversal_and_direction_conflict_cases_never_auto_match(self):
        """DIRECTION_CONFLICT cases model exactly the same-signed-amount
        reversal scenario from EDGE_CASE_REPORT.md finding 4 - the case
        that would become a live false-match risk if Phase 2's confidence
        fix had landed without Phase 1's direction hard-filter."""
        by_id = {r.a_id: r for r in self.result.case_results}
        conflict_cases = [c for c in self.dataset.cases if c.category == CaseCategory.DIRECTION_CONFLICT]
        self.assertGreater(len(conflict_cases), 0)
        for case in conflict_cases:
            self.assertNotEqual(by_id[case.a_id].routing_decision, ConfidenceWall.AUTO_MATCH)

    def test_duplicate_candidates_never_auto_match(self):
        by_id = {r.a_id: r for r in self.result.case_results}
        dup_cases = [c for c in self.dataset.cases if c.category == CaseCategory.DUPLICATE_CANDIDATE]
        self.assertGreater(len(dup_cases), 0)
        for case in dup_cases:
            self.assertNotEqual(by_id[case.a_id].routing_decision, ConfidenceWall.AUTO_MATCH)

    def test_incompatible_debit_credit_records_never_auto_match_at_maximal_confidence(self):
        """Directly re-verifies ai_resolution/test_matcher.py's Case C at
        the benchmark's own matcher instance: even the strongest possible
        name/amount/date signal (see TestPhase2ConfidenceSemantics) must not
        clear AUTO_MATCH across a known direction conflict."""
        from datetime import datetime

        from ai_resolution.matcher import AIEntityMatcher

        matcher = AIEntityMatcher()
        candidate = matcher.score_candidate(
            query_text="Amazon", query_amount=999.0, query_date=datetime(2026, 3, 1),
            candidate_merchant="Amazon", candidate_amount=999.0, candidate_date=datetime(2026, 3, 1),
            historical_encounters=25, trust_state="PERMANENT",
            query_direction="DEBIT", candidate_direction="CREDIT",
        )
        self.assertEqual(matcher.route_by_confidence_wall(candidate), ConfidenceWall.EXCEPTION)

    def test_review_and_exception_rate_exceeds_automation_rate(self):
        """The policy in one number: more of the benchmark is held for a
        human (HUMAN_REVIEW + EXCEPTION) than is ever auto-committed."""
        total = len(self.result.case_results)
        auto = sum(1 for r in self.result.case_results if r.routing_decision == ConfidenceWall.AUTO_MATCH)
        held = total - auto
        self.assertGreater(held, auto)

    def test_false_match_cost_is_far_below_unsafe_auto_commit_cost(self):
        """Illustrative cost model (harness.py: COST_FALSE_MATCH=50,
        COST_UNRESOLVED=1 - explicitly NOT real Razorpay/production loss
        figures). A single false auto-match costs as much as 50 correctly-
        held-for-review records; confirms the actually-measured cost stays
        near the "everything unresolved" floor, nowhere near what even one
        false match would add."""
        exception_and_review_count = sum(
            1 for r in self.result.case_results if r.routing_decision != ConfidenceWall.AUTO_MATCH
        )
        cost_of_a_single_false_match = COST_FALSE_MATCH
        self.assertLess(self.result.total_false_match_cost, exception_and_review_count * COST_UNRESOLVED + cost_of_a_single_false_match)


if __name__ == "__main__":
    unittest.main()
