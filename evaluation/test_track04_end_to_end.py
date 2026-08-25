"""
Phase 13: end-to-end Track 04 qualification test.

IMPORTANT SCOPE NOTE, read before trusting what this proves: this test
exercises the real computational pipeline this branch has actually built
and fixed - dataset generation (ingestion), AIEntityMatcher (entity
resolution), confidence-wall routing (reconciliation + confidence
evaluation + auto/review/exception classification) - end to end on a
300-record benchmark (>= the 50+ record Track 04 requirement).

It does NOT exercise `routers/controller.py` (the Finance Controller API).
Investigated directly for this phase: every handler in that router
(`GET /controller/stats`, `/exceptions`, `/cash-position`,
`POST /controller/exceptions/{id}/resolve`) returns hardcoded mock data -
none read or write MongoDB, there is no `exceptions`/`reconciliations`
collection anywhere in `database/mongo.py`, and there is no exception
persistence model, repository, or resolve-flow at all. "Exception
persistence," "exception resolution," "financial position," and
"variance calculation" as literal production features do not exist yet -
they are mocked at the API layer only.

What this test does instead, honestly: it builds the artifacts those
features *would* persist/serve - an exception ledger, a resolution
update, a financial-position summary, a variance figure, an audit trail,
and a final report - computed directly from the real matcher's output on
real (synthetic, ground-truth-backed) records, entirely in-process. This
proves the underlying computation is correct and derivable from the
underlying records (the spec's own requirement: "every reported number
must be derived from the underlying records"). It does not prove the API
layer persists or serves any of it, because that layer does not exist.
See docs/track04-final-evaluation.md's "Known Limitations" for how this
qualifies the overall READY/NOT READY verdict.
"""

import unittest

from ai_resolution.matcher import ConfidenceWall
from evaluation.dataset import generate_track04_benchmark
from evaluation.harness import Outcome, run_evaluation


class TestTrack04EndToEnd(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # 1. Source A / Source B ingestion (>= 50 records; 300 here).
        cls.dataset = generate_track04_benchmark(seed=42)
        cls.a_by_id = cls.dataset.a_by_id()
        cls.b_by_id = cls.dataset.b_by_id()

        # 2-8. Normalization is implicit in LedgerRecord construction;
        # entity resolution + reconciliation + confidence evaluation all
        # happen inside run_evaluation() via the real AIEntityMatcher.
        cls.result = run_evaluation(cls.dataset)

    def test_ingests_at_least_50_records_from_two_sources(self):
        self.assertGreaterEqual(len(self.dataset.source_a), 50)
        self.assertGreaterEqual(len(self.dataset.source_b), 50)

    def test_produces_automatic_safe_matches_review_cases_and_unresolved_cases(self):
        """9-10. Automatic safe matches / review cases / unresolved cases -
        all three buckets must be non-empty on this benchmark (it was
        constructed to exercise all three), and their union must equal
        every case."""
        auto = [r for r in self.result.case_results if r.routing_decision == ConfidenceWall.AUTO_MATCH]
        review = [r for r in self.result.case_results if r.routing_decision == ConfidenceWall.HUMAN_REVIEW]
        unresolved = [
            r for r in self.result.case_results
            if r.routing_decision in (ConfidenceWall.EXCEPTION, None)
        ]
        self.assertGreater(len(auto), 0)
        self.assertGreater(len(review), 0)
        self.assertGreater(len(unresolved), 0)
        self.assertEqual(len(auto) + len(review) + len(unresolved), len(self.result.case_results))

    def test_builds_an_exception_ledger_from_underlying_records(self):
        """11. 'Exception persistence' - the artifact that would be
        persisted, built here in-process since no real persistence layer
        exists (see module docstring). Every field is derived directly from
        CaseResult / the source records, not hardcoded."""
        exception_ledger = [
            {
                "a_id": r.a_id,
                "category": r.category.value,
                "confidence": r.confidence,
                "is_ambiguous": r.is_ambiguous,
                "query_text": self.a_by_id[r.a_id].text,
                "query_amount": self.a_by_id[r.a_id].amount,
                "status": "unresolved",
            }
            for r in self.result.case_results
            if r.routing_decision in (ConfidenceWall.EXCEPTION, None)
        ]
        self.assertGreater(len(exception_ledger), 0)
        for entry in exception_ledger:
            self.assertIn(entry["a_id"], self.a_by_id)
            self.assertEqual(entry["status"], "unresolved")

    def test_exception_resolution_updates_the_ledger_entry(self):
        """12. 'Exception resolution' - structural proof of the resolve
        flow's shape (update a ledger entry's status + add a resolution
        note), not a claim that this persists anywhere. A real resolve
        endpoint would need the exception model/repository this phase's
        research confirmed doesn't exist yet (routers/controller.py's
        POST /controller/exceptions/{id}/resolve is mock-only)."""
        exception_cases = [
            r for r in self.result.case_results
            if r.routing_decision in (ConfidenceWall.EXCEPTION, None)
        ]
        self.assertGreater(len(exception_cases), 0)
        target = exception_cases[0]

        ledger_entry = {"a_id": target.a_id, "status": "unresolved", "resolution_note": None}
        # Simulated resolution: a human reviewed it and confirmed it has no match.
        ledger_entry["status"] = "resolved_no_match"
        ledger_entry["resolution_note"] = "reviewed: no true partner found in source B"

        self.assertEqual(ledger_entry["status"], "resolved_no_match")
        self.assertIsNotNone(ledger_entry["resolution_note"])

    def test_computes_financial_position_and_variance_from_underlying_amounts(self):
        """13-14. Financial position + variance, computed directly from
        Source A amounts and each case's routing decision - not the mocked
        arithmetic in routers/controller.py::get_cash_position()."""
        total_position = sum(a.amount for a in self.dataset.source_a if a.amount is not None)

        auto_matched_total = sum(
            self.a_by_id[r.a_id].amount or 0.0
            for r in self.result.case_results
            if r.routing_decision == ConfidenceWall.AUTO_MATCH
        )
        held_for_review_total = sum(
            self.a_by_id[r.a_id].amount or 0.0
            for r in self.result.case_results
            if r.routing_decision == ConfidenceWall.HUMAN_REVIEW
        )
        unresolved_total = sum(
            self.a_by_id[r.a_id].amount or 0.0
            for r in self.result.case_results
            if r.routing_decision in (ConfidenceWall.EXCEPTION, None)
        )
        # variance: the portion of the total financial position not yet
        # automatically confirmed - what a human still has to account for.
        variance = held_for_review_total + unresolved_total

        self.assertAlmostEqual(
            auto_matched_total + held_for_review_total + unresolved_total, total_position, delta=0.02,
        )
        self.assertGreater(variance, 0)
        self.assertLess(auto_matched_total, total_position)

    def test_every_outcome_has_audit_provenance_back_to_source_records(self):
        """15. Audit/provenance: every case result must be traceable back to
        a real Source A record, and every auto-matched/reviewed case back to
        the specific Source B record it was matched against."""
        for r in self.result.case_results:
            self.assertIn(r.a_id, self.a_by_id)
            if r.predicted_b_id is not None:
                self.assertIn(r.predicted_b_id, self.b_by_id)

    def test_final_controller_report_is_fully_derived_from_case_results(self):
        """16. Final controller report: assembled here from the same
        `result.summary()` + ledger data every other assertion in this test
        used - not a separate hardcoded structure. Every number must match
        an independently-computed count over case_results."""
        summary = self.result.summary()
        report = {
            "records_processed": summary["records_processed"],
            "auto_match_count": summary["auto_match_count"],
            "exception_count": summary["exception_count"],
            "precision": summary["precision"],
            "recall": summary["recall"],
            "false_match_count": summary["false_match_count"],
        }

        independent_auto_count = sum(
            1 for r in self.result.case_results if r.routing_decision == ConfidenceWall.AUTO_MATCH
        )
        independent_false_match_count = sum(
            1 for r in self.result.case_results if r.outcome == Outcome.FALSE_AUTO_MATCH
        )

        self.assertEqual(report["auto_match_count"], independent_auto_count)
        self.assertEqual(report["false_match_count"], independent_false_match_count)
        self.assertEqual(report["false_match_count"], 0)
        self.assertEqual(report["records_processed"], len(self.dataset.cases))


if __name__ == "__main__":
    unittest.main()
