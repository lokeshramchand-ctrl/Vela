"""
Wave 5: Confidence Walls + Exception Management

Extends Wave 4 with deterministic confidence routing:
  - HIGH CONFIDENCE (>0.90): AUTO-MATCH (no human review)
  - MEDIUM CONFIDENCE (0.65-0.90): HUMAN_REVIEW (needs approval)
  - LOW CONFIDENCE (<0.65): EXCEPTION (unresolved, requires escalation)

Never force a match simply because the system has to produce an answer.

Architecture:
  1. Score candidates (Wave 4 pipeline)
  2. Route by confidence wall
  3. Track exceptions and rejection patterns
  4. Flag high-risk scenarios (ambiguous, multiple competitors)
  5. Escalate to human judgment when uncertain
"""

from dataclasses import dataclass, field
from typing import Optional, Callable, Dict, List
from enum import Enum
from datetime import datetime
from difflib import SequenceMatcher


class ConfidenceSource(str, Enum):
    """Track which heuristic contributed to confidence score."""
    NAME_SIMILARITY = "name_similarity"
    AMOUNT_MATCH = "amount_match"
    TEMPORAL_PROXIMITY = "temporal_proximity"
    HISTORICAL_CONTEXT = "historical_context"
    TRUST_STATE = "trust_state"


class ConfidenceWall(str, Enum):
    """Deterministic routing based on confidence thresholds."""
    AUTO_MATCH = "auto_match"  # >0.90: trust the system
    HUMAN_REVIEW = "human_review"  # 0.65-0.90: needs approval
    EXCEPTION = "exception"  # <0.65: unresolved, escalate


class ExceptionReason(str, Enum):
    """Categorize why a match was routed to exception."""
    LOW_CONFIDENCE = "low_confidence"
    WEAK_NAME_MATCH = "weak_name_match"
    AMBIGUOUS_CANDIDATES = "ambiguous_candidates"
    CONFLICTING_SIGNALS = "conflicting_signals"
    MISSING_CONTEXT = "missing_context"
    DIRECTION_MISMATCH = "direction_mismatch"


@dataclass
class ScoringFactors:
    """Breakdown of how a candidate was scored."""
    name_similarity: float = 0.0
    amount_match: float = 0.0
    temporal_proximity: float = 0.0
    historical_context: float = 0.0
    trust_state_factor: float = 0.0

    def aggregate(self, weights: Optional[Dict[str, float]] = None) -> float:
        """Weighted average of all factors.

        Args:
            weights: Custom weights per factor. If None, uses equal weighting.

        Returns:
            Aggregated confidence score [0, 1].
        """
        if weights is None:
            weights = {
                "name_similarity": 0.25,
                "amount_match": 0.30,
                "temporal_proximity": 0.20,
                "historical_context": 0.15,
                "trust_state_factor": 0.10,
            }

        # Weight keys ("name_similarity", "trust_state_factor", ...) match
        # ScoringFactors' field names exactly - previously this stripped a
        # "_factor" suffix before the lookup, which only ever matched a
        # non-existent "trust_state" attribute and silently dropped
        # trust_state_factor's entire 0.10 weight from every aggregate,
        # capping the best possible score at 0.90 regardless of how strong
        # every other signal was.
        total = sum(
            getattr(self, k, 0) * v
            for k, v in weights.items()
            if k in self.__dict__
        )
        return min(1.0, max(0.0, total))


@dataclass
class EntityCandidate:
    """A proposed merchant match with confidence and routing decision."""
    merchant: str
    confidence: float
    scoring_factors: ScoringFactors
    evidence: Dict = field(default_factory=dict)
    requires_human_review: bool = False
    confidence_wall: Optional[ConfidenceWall] = None
    exception_reason: Optional[ExceptionReason] = None
    direction_conflict: bool = False

    def to_dict(self) -> dict:
        """Serialize to JSON-compatible dict."""
        return {
            "merchant": self.merchant,
            "confidence": round(self.confidence, 3),
            "reasoning": {
                "name_similarity": round(self.scoring_factors.name_similarity, 3),
                "amount_match": round(self.scoring_factors.amount_match, 3),
                "temporal_proximity": round(self.scoring_factors.temporal_proximity, 3),
                "historical_context": round(self.scoring_factors.historical_context, 3),
                "trust_state_factor": round(self.scoring_factors.trust_state_factor, 3),
            },
            "evidence": self.evidence,
            "requires_human_review": self.requires_human_review,
            "confidence_wall": self.confidence_wall,
            "exception_reason": self.exception_reason,
            "direction_conflict": self.direction_conflict,
        }


@dataclass
class ResolutionRequest:
    """Input to the AI entity resolver."""
    query_text: str
    query_amount: Optional[float] = None
    query_date: Optional[datetime] = None
    user_id: Optional[str] = None
    top_k: int = 5
    confidence_threshold: float = 0.65


@dataclass
class ResolutionResponse:
    """Output from the AI entity resolver with confidence wall routing."""
    query: str
    candidates: List[EntityCandidate]
    proposed_decision: Optional[EntityCandidate] = None
    routing_decision: Optional[ConfidenceWall] = None
    exceptions: List[str] = field(default_factory=list)
    is_ambiguous: bool = False

    def to_dict(self) -> dict:
        return {
            "query": self.query,
            "candidates": [c.to_dict() for c in self.candidates],
            "proposed_decision": (
                self.proposed_decision.to_dict()
                if self.proposed_decision
                else None
            ),
            "routing_decision": self.routing_decision,
            "exceptions": self.exceptions,
            "is_ambiguous": self.is_ambiguous,
        }


class NameSimilarityMatcher:
    """Computes string-based similarity between merchant names."""

    def __init__(self, weights: Optional[Dict[str, float]] = None):
        """Initialize with optional custom weights for different metrics.

        Args:
            weights: Dict with keys 'levenshtein', 'abbreviation', 'exact_alias'.
                     Defaults to equal weighting if None.
        """
        self.weights = weights or {
            "levenshtein": 0.50,
            "abbreviation": 0.30,
            "exact_alias": 0.20,
        }

    def levenshtein_ratio(self, a: str, b: str) -> float:
        """Compute normalized Levenshtein-like similarity (0 to 1).

        Uses SequenceMatcher for quick approximation; for production,
        consider python-Levenshtein or jellyfish for exact distance.
        """
        return SequenceMatcher(None, a.upper(), b.upper()).ratio()

    def is_abbreviation_match(self, short: str, long: str) -> bool:
        """Check if short is a known abbreviation of long.

        Examples:
            'AMZN' -> 'AMAZON' (True)
            'UBER' -> 'UBER EATS' (True)

        This is a stub; in production, load a frozen abbreviation dict.
        """
        abbrev_map = {
            "AMZN": "AMAZON",
            "UBER": "UBER",
            "SWIGGY": "SWIGGY",
            "ZOMATO": "ZOMATO",
            "GPay": "GOOGLE PAY",
            "PhonePe": "PHONEPE",
        }
        return short.upper() in abbrev_map and abbrev_map[short.upper()] in long.upper()

    def score(self, query: str, candidate: str) -> float:
        """Score similarity between query and candidate merchant names.

        Returns:
            Confidence score [0, 1].
        """
        lev = self.levenshtein_ratio(query, candidate)
        abbrev = 1.0 if self.is_abbreviation_match(query, candidate) else 0.0
        # A byte-identical name (modulo whitespace/case) is the strongest
        # possible signal this matcher can see - the 'exact_alias' weight
        # exists specifically to credit it, separately from Levenshtein
        # (which already returns 1.0 for identical strings, but only carries
        # its own 0.50 weight) and from the abbreviation stub (which only
        # covers a hardcoded few merchants).
        exact = 1.0 if query.strip().upper() == candidate.strip().upper() else 0.0

        # Weighted sum
        score = (
            lev * self.weights["levenshtein"]
            + abbrev * self.weights["abbreviation"]
            + exact * self.weights["exact_alias"]
        )
        return min(1.0, score)


class AmountMatcher:
    """Matches transactions by amount with a two-tier tolerance: an absolute
    floor for rounding/FX noise, then a proportional band for larger
    transactions.

    Percentage-only tolerance (the previous design) is systematically harsher
    on small transactions than large ones for the exact same absolute noise:
    a Rs 1 diff is 10% of a Rs 10 fare but 0.02% of a Rs 5,000 purchase, so
    only the latter survived a flat 5% band (EDGE_CASE_REPORT.md finding 2).
    Real-world rounding/FX noise is an absolute quantity, not a fraction of
    the transaction - so it needs an absolute floor that applies regardless
    of amount, on top of (not instead of) the existing proportional band for
    larger, non-trivial discrepancies.

    Four deterministic tiers, evaluated in order:
      1. Exact match                                -> exact_weight (1.0)
      2. abs(diff) <= absolute_floor                 -> near_exact_weight (0.85)
         (rounding/FX noise - an absolute quantity, independent of amount)
      3. abs(diff) <= max(absolute_floor, amount * tolerance_pct)
                                                       -> tolerance_weight (0.7)
         (proportional band - meaningful for larger transactions)
      4. anything else                               -> 0.0 (a real mismatch)

    This only ever *adds* credit for small absolute diffs that used to score
    0 - it never grants credit to a discrepancy that already failed the
    proportional band, so it cannot turn a large financial mismatch into a
    high-confidence match.
    """

    def __init__(
        self,
        exact_weight: float = 1.0,
        tolerance_pct: float = 0.05,
        absolute_floor: float = 2.0,
        near_exact_weight: float = 0.85,
        tolerance_weight: float = 0.7,
    ):
        """Initialize with match strategy.

        Args:
            exact_weight: Score for exact amount match (default 1.0).
            tolerance_pct: Fractional tolerance for the proportional band
                (e.g., 0.05 = +/-5%).
            absolute_floor: Absolute rupee tolerance applied regardless of
                amount, for rounding/FX noise (default Rs 2).
            near_exact_weight: Score for a diff within absolute_floor.
            tolerance_weight: Score for a diff within the proportional band.
        """
        self.exact_weight = exact_weight
        self.tolerance_pct = tolerance_pct
        self.absolute_floor = absolute_floor
        self.near_exact_weight = near_exact_weight
        self.tolerance_weight = tolerance_weight

    def score(self, query_amount: Optional[float], candidate_amount: Optional[float]) -> float:
        """Score match between two amounts.

        Args:
            query_amount: Amount from query transaction.
            candidate_amount: Amount from candidate/historical transaction.

        Returns:
            Confidence score [0, 1].
        """
        if query_amount is None or candidate_amount is None:
            return 0.5  # Neutral if missing data

        diff = abs(query_amount - candidate_amount)

        if diff == 0:
            return self.exact_weight

        if diff <= self.absolute_floor:
            return self.near_exact_weight

        tolerance = max(self.absolute_floor, query_amount * self.tolerance_pct)
        if diff <= tolerance:
            return self.tolerance_weight

        return 0.0


class TemporalProximityMatcher:
    """Scores temporal proximity between transactions."""

    def __init__(self, max_days: int = 3):
        """Initialize with maximum acceptable day difference.

        Args:
            max_days: Transactions beyond this many days apart score 0.
        """
        self.max_days = max_days

    def score(
        self, query_date: Optional[datetime], candidate_date: Optional[datetime]
    ) -> float:
        """Score temporal proximity.

        Args:
            query_date: Date of query transaction.
            candidate_date: Date of candidate transaction.

        Returns:
            Confidence score [0, 1], with 1.0 for same-day matches.
        """
        if query_date is None or candidate_date is None:
            return 0.5

        delta = abs((query_date - candidate_date).days)

        if delta == 0:
            return 1.0  # Same day
        if delta == 1:
            return 0.9  # Adjacent day
        if delta <= self.max_days:
            return 0.7 - (0.1 * delta)  # Linear decay
        return 0.0


def _directions_conflict(query_direction: Optional[str], candidate_direction: Optional[str]) -> bool:
    """True only when both directions are known and disagree.

    Unknown direction (None on either side) is not a conflict - it's missing
    data, and the existing confidence math already handles missing data
    conservatively. A conflict is only ever raised when we *know* one side
    is money out and the other is money in, e.g. a debit being proposed as
    a match for a credit (a refund/reversal pair), which must never be
    treated as "the same transaction" no matter how well name/amount/date
    line up.
    """
    if query_direction is None or candidate_direction is None:
        return False
    return query_direction.strip().upper() != candidate_direction.strip().upper()


class AIEntityMatcher:
    """
    Main orchestrator for AI-assisted entity resolution with confidence walls.

    Extends Wave 4 with deterministic confidence routing:
      HIGH CONFIDENCE (>0.90) → AUTO-MATCH (trust the system)
      MEDIUM CONFIDENCE (0.65-0.90) → HUMAN_REVIEW (needs approval)
      LOW CONFIDENCE (<0.65) → EXCEPTION (escalate)

    Does NOT perform the actual database lookups or call the deterministic
    matcher — those are responsibilities of routers/services that use this.
    This class focuses on *scoring* candidates and routing by confidence.
    """

    def __init__(
        self,
        name_matcher: Optional[NameSimilarityMatcher] = None,
        amount_matcher: Optional[AmountMatcher] = None,
        temporal_matcher: Optional[TemporalProximityMatcher] = None,
        high_confidence_threshold: float = 0.90,
        medium_confidence_threshold: float = 0.65,
    ):
        self.name_matcher = name_matcher or NameSimilarityMatcher()
        self.amount_matcher = amount_matcher or AmountMatcher()
        self.temporal_matcher = temporal_matcher or TemporalProximityMatcher()
        self.high_confidence_threshold = high_confidence_threshold
        self.medium_confidence_threshold = medium_confidence_threshold

    def score_candidate(
        self,
        query_text: str,
        query_amount: Optional[float],
        query_date: Optional[datetime],
        candidate_merchant: str,
        candidate_amount: Optional[float] = None,
        candidate_date: Optional[datetime] = None,
        historical_encounters: int = 0,
        trust_state: Optional[str] = None,
        query_direction: Optional[str] = None,
        candidate_direction: Optional[str] = None,
    ) -> EntityCandidate:
        """Score a single candidate merchant.

        Args:
            query_text: Noisy merchant text from transaction.
            query_amount: Amount of query transaction.
            query_date: Date of query transaction.
            candidate_merchant: Proposed canonical merchant name.
            candidate_amount: Amount of candidate txn (if known).
            candidate_date: Date of candidate txn (if known).
            historical_encounters: How many times user has seen this merchant.
            trust_state: Phase 4 trust state (EPHEMERAL, TEMPORARY, PERMANENT).
            query_direction: Direction of the query txn, e.g. "DEBIT"/"CREDIT"
                (matches models.schemas.TransactionType values). None if unknown.
            candidate_direction: Direction of the candidate txn. None if unknown.

        Returns:
            EntityCandidate with scored factors. If both directions are known
            and disagree, `direction_conflict` is set - this is a hard
            pre-filter enforced by `route_by_confidence_wall`, not a fuzzy
            score penalty, so a debit can never auto-match a credit no
            matter how strong the other signals are.
        """
        factors = ScoringFactors()

        # Name similarity
        factors.name_similarity = self.name_matcher.score(query_text, candidate_merchant)

        # Amount matching
        factors.amount_match = self.amount_matcher.score(query_amount, candidate_amount)

        # Temporal proximity
        factors.temporal_proximity = self.temporal_matcher.score(query_date, candidate_date)

        # Historical context: higher score for merchants user has seen before
        if historical_encounters > 20:
            factors.historical_context = 0.95
        elif historical_encounters > 5:
            factors.historical_context = 0.80
        elif historical_encounters > 0:
            factors.historical_context = 0.60
        else:
            factors.historical_context = 0.30

        # Trust state boost: PERMANENT > TEMPORARY > EPHEMERAL
        trust_multiplier = {
            "PERMANENT": 1.15,
            "TEMPORARY": 1.05,
            "EPHEMERAL": 0.95,
            None: 1.0,
        }.get(trust_state, 1.0)

        factors.trust_state_factor = 0.9 * trust_multiplier

        # Aggregate
        confidence = factors.aggregate()

        # Decide if human review is needed
        requires_review = confidence < 0.75 or factors.name_similarity < 0.70

        return EntityCandidate(
            merchant=candidate_merchant,
            confidence=confidence,
            scoring_factors=factors,
            requires_human_review=requires_review,
            direction_conflict=_directions_conflict(query_direction, candidate_direction),
        )

    def rank_candidates(
        self, candidates: List[EntityCandidate], top_k: int = 5
    ) -> List[EntityCandidate]:
        """Sort candidates by confidence, return top_k."""
        sorted_candidates = sorted(candidates, key=lambda c: c.confidence, reverse=True)
        return sorted_candidates[:top_k]

    def filter_by_threshold(
        self, candidates: List[EntityCandidate], threshold: float
    ) -> List[EntityCandidate]:
        """Keep only candidates above confidence threshold."""
        return [c for c in candidates if c.confidence >= threshold]

    def route_by_confidence_wall(
        self, candidate: EntityCandidate
    ) -> ConfidenceWall:
        """Deterministically route candidate by confidence threshold.

        Returns:
            ConfidenceWall enum indicating routing decision.
        """
        # Hard pre-filter: a known direction conflict (debit vs. credit)
        # overrides the confidence score entirely. This must never be
        # AUTO_MATCH or even HUMAN_REVIEW-by-default-confidence - it's routed
        # straight to EXCEPTION regardless of how strong name/amount/date
        # look, since those signals are exactly what make refund/reversal
        # pairs look deceptively like a match.
        if candidate.direction_conflict:
            return ConfidenceWall.EXCEPTION
        if candidate.confidence >= self.high_confidence_threshold:
            return ConfidenceWall.AUTO_MATCH
        elif candidate.confidence >= self.medium_confidence_threshold:
            return ConfidenceWall.HUMAN_REVIEW
        else:
            return ConfidenceWall.EXCEPTION

    def detect_exception_reason(
        self, candidate: EntityCandidate, all_candidates: List[EntityCandidate]
    ) -> Optional[ExceptionReason]:
        """Classify why a candidate is an exception.

        Args:
            candidate: The routed candidate.
            all_candidates: All candidates considered (for ambiguity detection).

        Returns:
            ExceptionReason enum, or None if not an exception.
        """
        wall = self.route_by_confidence_wall(candidate)
        if wall != ConfidenceWall.EXCEPTION:
            return None

        if candidate.direction_conflict:
            return ExceptionReason.DIRECTION_MISMATCH

        # Determine specific reason
        if candidate.confidence < 0.40:
            return ExceptionReason.LOW_CONFIDENCE
        if candidate.scoring_factors.name_similarity < 0.50:
            return ExceptionReason.WEAK_NAME_MATCH
        if len(all_candidates) > 2:
            top_scores = sorted(
                [c.confidence for c in all_candidates[:3]], reverse=True
            )
            if len(top_scores) > 1 and abs(top_scores[0] - top_scores[1]) < 0.10:
                return ExceptionReason.AMBIGUOUS_CANDIDATES
        if (
            abs(candidate.scoring_factors.name_similarity - candidate.scoring_factors.amount_match)
            > 0.40
        ):
            return ExceptionReason.CONFLICTING_SIGNALS

        return ExceptionReason.MISSING_CONTEXT

    def detect_ambiguity(self, candidates: List[EntityCandidate]) -> bool:
        """Check if match result is ambiguous (multiple strong candidates).

        Args:
            candidates: Ranked list of candidates.

        Returns:
            True if ambiguity detected (multiple candidates within 5% confidence).
        """
        if len(candidates) < 2:
            return False

        top = candidates[0].confidence
        second = candidates[1].confidence

        return abs(top - second) < 0.05

    def propose_decision(
        self, candidates: List[EntityCandidate]
    ) -> Optional[EntityCandidate]:
        """Select top candidate with confidence wall routing.

        Returns:
            Top candidate with routing decision, or None if no candidates.
        """
        if not candidates:
            return None

        top = candidates[0]

        # Route by confidence wall (Wave 5)
        wall = self.route_by_confidence_wall(top)
        top.confidence_wall = wall
        exception_reason = self.detect_exception_reason(top, candidates)
        top.exception_reason = exception_reason

        # Set requires_human_review based on wall
        if wall == ConfidenceWall.AUTO_MATCH:
            top.requires_human_review = False
        elif wall == ConfidenceWall.HUMAN_REVIEW:
            top.requires_human_review = True
        else:  # EXCEPTION
            top.requires_human_review = True

        return top
