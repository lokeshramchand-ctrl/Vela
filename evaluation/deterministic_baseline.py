"""
Phase 9: deterministic (non-AI) reconciliation baseline.

No fuzzy scoring, no confidence, no historical trust, no direction
hard-filter as a separate concept - just the simplest rule a naive
reconciliation script would actually ship: normalize the merchant text,
then match only if merchant (case/whitespace-insensitive), amount, and
calendar date are ALL exactly equal. If exactly one candidate satisfies
that, commit to it (MATCHED). If zero or more than one candidate satisfies
it, decline (UNRESOLVED) - a deterministic system has no way to rank
multiple exact ties, so it must not guess between them any more than
AIEntityMatcher does.

This is the "what would we have without any of Vela's AI matching layer"
counterfactual for Phase 10's comparison, distinct from
evaluation/harness.py's naive_baseline_cost() (which reuses the real
fuzzy matcher's top-ranked candidate with no confidence wall - a different
counterfactual: "what does removing safety, but keeping fuzzy scoring,
cost").
"""

import time
from dataclasses import dataclass
from enum import Enum

from evaluation.dataset import CaseCategory, EvaluationDataset, LedgerRecord

# Categories where a real correct partner exists - mirrors
# evaluation/harness.py's _TRUE_MATCH_CATEGORIES (kept as an independent
# copy rather than importing a private name across modules).
_TRUE_MATCH_CATEGORIES = frozenset({
    CaseCategory.TRUE_MATCH, CaseCategory.RECURRING, CaseCategory.PARTIAL_METADATA,
})


class DeterministicOutcome(str, Enum):
    CORRECT_MATCH = "correct_match"  # matched, and to the right candidate
    FALSE_MATCH = "false_match"  # matched, but wrong (or no true match exists at all)
    CORRECT_UNRESOLVED = "correct_unresolved"  # no true match exists, correctly declined
    MISSED_MATCH = "missed_match"  # true match existed, exact-equality rule didn't find it


@dataclass
class DeterministicCaseResult:
    a_id: str
    category: CaseCategory
    matched_b_id: str | None
    outcome: DeterministicOutcome


@dataclass
class DeterministicResult:
    case_results: list[DeterministicCaseResult]
    elapsed_seconds: float
    records_processed: int

    def _count(self, outcome: DeterministicOutcome) -> int:
        return sum(1 for c in self.case_results if c.outcome == outcome)

    @property
    def throughput_per_second(self) -> float:
        return self.records_processed / self.elapsed_seconds if self.elapsed_seconds > 0 else float("inf")

    @property
    def match_count(self) -> int:
        return sum(1 for c in self.case_results if c.matched_b_id is not None)

    @property
    def true_match_total(self) -> int:
        return sum(1 for c in self.case_results if c.category in _TRUE_MATCH_CATEGORIES)

    @property
    def precision(self) -> float:
        correct = self._count(DeterministicOutcome.CORRECT_MATCH)
        total = self.match_count
        return correct / total if total else 1.0

    @property
    def recall(self) -> float:
        correct = self._count(DeterministicOutcome.CORRECT_MATCH)
        return correct / self.true_match_total if self.true_match_total else 1.0

    @property
    def match_rate(self) -> float:
        """Fraction of all records the deterministic rule committed to
        (matched), whether correctly or not - the direct counterpart to
        AIEntityMatcher's automation_rate."""
        total = len(self.case_results)
        return self.match_count / total if total else 0.0

    @property
    def false_match_count(self) -> int:
        return self._count(DeterministicOutcome.FALSE_MATCH)

    @property
    def unresolved_count(self) -> int:
        return sum(1 for c in self.case_results if c.matched_b_id is None)

    def summary(self) -> dict:
        return {
            "records_processed": self.records_processed,
            "elapsed_seconds": round(self.elapsed_seconds, 4),
            "throughput_per_second": round(self.throughput_per_second, 1),
            "match_count": self.match_count,
            "unresolved_count": self.unresolved_count,
            "precision": round(self.precision, 4),
            "recall": round(self.recall, 4),
            "match_rate": round(self.match_rate, 4),
            "false_match_count": self.false_match_count,
            "outcomes": {outcome.value: self._count(outcome) for outcome in DeterministicOutcome},
        }


def _exact_match_candidates(a_record: LedgerRecord, candidates: list[LedgerRecord]) -> list[LedgerRecord]:
    def _norm(text: str) -> str:
        return " ".join(text.split()).upper()

    matches = []
    for b in candidates:
        if a_record.amount is None or b.amount is None or a_record.date is None or b.date is None:
            continue  # a deterministic exact-equality rule cannot match on missing data at all
        if (
            _norm(a_record.text) == _norm(b.text)
            and a_record.amount == b.amount
            and a_record.date.date() == b.date.date()
            and a_record.direction == b.direction
        ):
            matches.append(b)
    return matches


def _classify(category: CaseCategory, true_b_id: str | None, matched_b_id: str | None) -> DeterministicOutcome:
    if true_b_id is not None:
        if matched_b_id == true_b_id:
            return DeterministicOutcome.CORRECT_MATCH
        if matched_b_id is not None:
            return DeterministicOutcome.FALSE_MATCH
        return DeterministicOutcome.MISSED_MATCH
    if matched_b_id is not None:
        return DeterministicOutcome.FALSE_MATCH
    return DeterministicOutcome.CORRECT_UNRESOLVED


def run_deterministic_evaluation(dataset: EvaluationDataset) -> DeterministicResult:
    a_by_id = dataset.a_by_id()
    b_by_id = dataset.b_by_id()

    results: list[DeterministicCaseResult] = []
    start = time.perf_counter()

    for case in dataset.cases:
        a_record = a_by_id[case.a_id]
        candidates = [b_by_id[b_id] for b_id in case.candidate_b_ids]
        exact_matches = _exact_match_candidates(a_record, candidates)

        matched_b_id = exact_matches[0].id if len(exact_matches) == 1 else None
        outcome = _classify(case.category, case.true_b_id, matched_b_id)

        results.append(DeterministicCaseResult(
            a_id=case.a_id, category=case.category, matched_b_id=matched_b_id, outcome=outcome,
        ))

    elapsed = time.perf_counter() - start
    return DeterministicResult(case_results=results, elapsed_seconds=elapsed, records_processed=len(dataset.cases))
