"""
Wave 8: Evaluation harness.

Runs the real Wave 4/5 matcher (`ai_resolution.matcher.AIEntityMatcher`) over
the Wave 8 synthetic dataset *without* handing it any ground truth, then scores
its routing decisions against the withheld ground truth.

Core question this answers: when Vela commits to an auto-match, is it right?
And when it isn't sure, does it say so instead of guessing?
"""

import time
from dataclasses import dataclass, field
from enum import Enum

from ai_resolution.matcher import AIEntityMatcher, ConfidenceWall, EntityCandidate
from evaluation.dataset import CaseCategory, EvaluationDataset, LedgerRecord

# False-match cost model: an unsafe auto-match that turns out wrong is far more
# expensive than an exception that merely asks a human to look. A missed match
# that gets correctly routed to review is cheap (a few minutes of review); a
# false auto-match can misstate cash position, hide a real discrepancy, or
# require unwinding a reconciliation after the fact. These weights are the
# quantified version of "never force a match" (ai_resolution/matcher.py:9).
COST_FALSE_MATCH = 50.0
COST_UNRESOLVED = 1.0
COST_CORRECT_AUTO_MATCH = 0.0

# Categories where a real correct partner exists (true_b_id is set on the
# GroundTruthCase). CaseCategory.TRUE_MATCH is the original Wave 8 category;
# RECURRING and PARTIAL_METADATA (Phase 8) are also genuine true-match cases,
# just stressing a different signal (temporal gap / missing metadata) than
# the original TRUE_MATCH cases. Every other category (KNOWN_EXCEPTION,
# AMBIGUOUS, DIRECTION_CONFLICT, MISSING_RECORD, DUPLICATE_CANDIDATE) has no
# defensible single correct answer by construction.
_TRUE_MATCH_CATEGORIES = frozenset({
    CaseCategory.TRUE_MATCH, CaseCategory.RECURRING, CaseCategory.PARTIAL_METADATA,
})


class Outcome(str, Enum):
    CORRECT_AUTO_MATCH = "correct_auto_match"  # AUTO_MATCH and right - fully automated
    CORRECT_HUMAN_REVIEW = "correct_human_review"  # right candidate surfaced, but queued for a human
    FALSE_AUTO_MATCH = "false_auto_match"  # AUTO_MATCH but wrong, or no true match exists at all
    CORRECT_EXCEPTION = "correct_exception"  # no true match exists, correctly declined to commit
    MISSED_MATCH = "missed_match"  # true match existed but the wrong candidate came out on top


@dataclass
class CaseResult:
    a_id: str
    category: CaseCategory
    routing_decision: ConfidenceWall | None
    predicted_b_id: str | None
    confidence: float
    is_ambiguous: bool
    outcome: Outcome


@dataclass
class EvaluationResult:
    case_results: list[CaseResult] = field(default_factory=list)
    elapsed_seconds: float = 0.0
    records_processed: int = 0

    @property
    def throughput_per_second(self) -> float:
        if self.elapsed_seconds <= 0:
            return float("inf")
        return self.records_processed / self.elapsed_seconds

    def _count(self, outcome: Outcome) -> int:
        return sum(1 for c in self.case_results if c.outcome == outcome)

    @property
    def auto_match_count(self) -> int:
        return sum(1 for c in self.case_results if c.routing_decision == ConfidenceWall.AUTO_MATCH)

    @property
    def exception_count(self) -> int:
        return sum(
            1 for c in self.case_results
            if c.routing_decision in (ConfidenceWall.EXCEPTION, ConfidenceWall.HUMAN_REVIEW)
        )

    @property
    def true_match_total(self) -> int:
        return sum(1 for c in self.case_results if c.category in _TRUE_MATCH_CATEGORIES)

    @property
    def precision(self) -> float:
        """Of everything Vela marked as a match (auto-committed, no review), how
        much was actually correct? This is the safety metric: every point below
        100% here is a reconciliation Vela got wrong without asking anyone."""
        correct = self._count(Outcome.CORRECT_AUTO_MATCH)
        total = self.auto_match_count
        return correct / total if total else 1.0

    @property
    def recall(self) -> float:
        """Of all actual matches, how many did Vela discover - i.e. correctly
        identified the true partner, whether it auto-committed or queued it for
        a human to confirm? This is the "did it find it" metric, distinct from
        `automation_rate` ("did it dare commit without asking")."""
        correct = self._count(Outcome.CORRECT_AUTO_MATCH) + self._count(Outcome.CORRECT_HUMAN_REVIEW)
        return correct / self.true_match_total if self.true_match_total else 1.0

    @property
    def automation_rate(self) -> float:
        """Of all actual matches, how many were auto-committed with no human
        in the loop at all?"""
        correct = self._count(Outcome.CORRECT_AUTO_MATCH)
        return correct / self.true_match_total if self.true_match_total else 1.0

    @property
    def exception_rate(self) -> float:
        """Fraction of all records that required human attention."""
        total = len(self.case_results)
        return self.exception_count / total if total else 0.0

    @property
    def false_match_count(self) -> int:
        return self._count(Outcome.FALSE_AUTO_MATCH)

    @property
    def total_false_match_cost(self) -> float:
        return (
            self._count(Outcome.FALSE_AUTO_MATCH) * COST_FALSE_MATCH
            + (
                self._count(Outcome.CORRECT_EXCEPTION)
                + self._count(Outcome.CORRECT_HUMAN_REVIEW)
                + self._count(Outcome.MISSED_MATCH)
            ) * COST_UNRESOLVED
        )

    def summary(self) -> dict:
        return {
            "records_processed": self.records_processed,
            "elapsed_seconds": round(self.elapsed_seconds, 4),
            "throughput_per_second": round(self.throughput_per_second, 1),
            "auto_match_count": self.auto_match_count,
            "exception_count": self.exception_count,
            "precision": round(self.precision, 4),
            "recall": round(self.recall, 4),
            "automation_rate": round(self.automation_rate, 4),
            "exception_rate": round(self.exception_rate, 4),
            "false_match_count": self.false_match_count,
            "total_false_match_cost": self.total_false_match_cost,
            "outcomes": {
                outcome.value: self._count(outcome) for outcome in Outcome
            },
        }


def _score_candidates(
    matcher: AIEntityMatcher, a_record: LedgerRecord, candidates: list[LedgerRecord],
) -> list[EntityCandidate]:
    scored = [
        matcher.score_candidate(
            query_text=a_record.text,
            query_amount=a_record.amount,
            query_date=a_record.date,
            candidate_merchant=b_record.text,
            candidate_amount=b_record.amount,
            candidate_date=b_record.date,
            historical_encounters=a_record.historical_encounters,
            trust_state=a_record.trust_state,
            # Phase 8: every Wave 8 record defaults to direction="DEBIT" (see
            # evaluation/dataset.py), so this is a no-op for the original
            # 250/250 dataset - direction_conflict is only ever True for the
            # new DIRECTION_CONFLICT category, which is the point of it.
            query_direction=a_record.direction,
            candidate_direction=b_record.direction,
        )
        for b_record in candidates
    ]
    # Stash the source B id on evidence so we can trace the decision back;
    # EntityCandidate doesn't carry an id field of its own.
    for candidate, b_record in zip(scored, candidates, strict=True):
        candidate.evidence["b_id"] = b_record.id
    return matcher.rank_candidates(scored, top_k=len(scored))


def _classify_outcome(
    category: CaseCategory,
    true_b_id: str | None,
    routing_decision: ConfidenceWall | None,
    predicted_b_id: str | None,
) -> Outcome:
    is_auto_match = routing_decision == ConfidenceWall.AUTO_MATCH

    # A real correct partner exists whenever true_b_id is set (see
    # _TRUE_MATCH_CATEGORIES above) - checking true_b_id directly rather than
    # the literal TRUE_MATCH category handles RECURRING/PARTIAL_METADATA the
    # same way without special-casing each new category.
    if true_b_id is not None:
        found_correct_candidate = predicted_b_id == true_b_id
        if is_auto_match and found_correct_candidate:
            return Outcome.CORRECT_AUTO_MATCH
        if is_auto_match:  # auto-matched, but to the wrong candidate
            return Outcome.FALSE_AUTO_MATCH
        if found_correct_candidate:  # right answer, correctly held for a human to confirm
            return Outcome.CORRECT_HUMAN_REVIEW
        return Outcome.MISSED_MATCH

    # KNOWN_EXCEPTION and AMBIGUOUS both have no correct partner to commit to;
    # any auto-match here is unsafe by definition.
    if is_auto_match:
        return Outcome.FALSE_AUTO_MATCH
    return Outcome.CORRECT_EXCEPTION


def run_evaluation(dataset: EvaluationDataset, matcher: AIEntityMatcher | None = None) -> EvaluationResult:
    """Run the matcher over the dataset with no access to ground truth, then
    score its decisions against the withheld ground truth."""
    matcher = matcher or AIEntityMatcher()
    a_by_id = dataset.a_by_id()
    b_by_id = dataset.b_by_id()

    results: list[CaseResult] = []
    start = time.perf_counter()

    for case in dataset.cases:
        a_record = a_by_id[case.a_id]
        candidates = [b_by_id[b_id] for b_id in case.candidate_b_ids]

        ranked = _score_candidates(matcher, a_record, candidates)
        top = matcher.propose_decision(ranked)
        is_ambiguous = matcher.detect_ambiguity(ranked)

        routing_decision = top.confidence_wall if top else None
        predicted_b_id = top.evidence.get("b_id") if top else None
        confidence = top.confidence if top else 0.0

        # Ambiguity is an additional, independent signal that must veto an
        # auto-match even if the top candidate's raw confidence cleared the
        # wall — two near-tied candidates is never a safe auto-match.
        if is_ambiguous and routing_decision == ConfidenceWall.AUTO_MATCH:
            routing_decision = ConfidenceWall.HUMAN_REVIEW

        outcome = _classify_outcome(case.category, case.true_b_id, routing_decision, predicted_b_id)

        results.append(CaseResult(
            a_id=case.a_id,
            category=case.category,
            routing_decision=routing_decision,
            predicted_b_id=predicted_b_id,
            confidence=confidence,
            is_ambiguous=is_ambiguous,
            outcome=outcome,
        ))

    elapsed = time.perf_counter() - start

    return EvaluationResult(
        case_results=results,
        elapsed_seconds=elapsed,
        records_processed=len(dataset.cases),
    )


def naive_baseline_cost(dataset: EvaluationDataset, matcher: AIEntityMatcher | None = None) -> float:
    """Cost of a naive matcher that always commits to the top-scored candidate,
    with no confidence wall at all. Used as the counterfactual that shows what
    Vela's conservatism buys: this baseline always "matches" (never
    exceptions), so its entire cost is false-match cost.
    """
    matcher = matcher or AIEntityMatcher()
    a_by_id = dataset.a_by_id()
    b_by_id = dataset.b_by_id()

    total_cost = 0.0
    for case in dataset.cases:
        a_record = a_by_id[case.a_id]
        candidates = [b_by_id[b_id] for b_id in case.candidate_b_ids]
        ranked = _score_candidates(matcher, a_record, candidates)
        top = ranked[0] if ranked else None
        predicted_b_id = top.evidence.get("b_id") if top else None

        is_correct = case.category in _TRUE_MATCH_CATEGORIES and predicted_b_id == case.true_b_id
        if not is_correct:
            total_cost += COST_FALSE_MATCH

    return total_cost
