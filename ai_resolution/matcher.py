"""
Wave 4: AI-Assisted Entity Resolution Matcher

Handles ambiguous merchant-matching cases using semantic similarity,
temporal proximity, and historical context. Proposes candidates but
does not auto-decide — all matches require human review or explicit
acceptance by downstream logic.

Architecture:
  1. Query arrives: noisy merchant text + context (amount, date, user)
  2. Candidate generation: similar merchants from deterministic rules
  3. Scoring: apply heuristics (name, amount, temporal, historical)
  4. Ranking: sort by confidence, filter by threshold
  5. Proposal: return candidates with reasoning (not auto-accept)
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

        total = sum(
            getattr(self, k.replace("_factor", ""), 0) * v
            for k, v in weights.items()
            if k.replace("_factor", "") in self.__dict__
        )
        return min(1.0, max(0.0, total))


@dataclass
class EntityCandidate:
    """A proposed merchant match with confidence and reasoning."""
    merchant: str
    confidence: float
    scoring_factors: ScoringFactors
    evidence: Dict = field(default_factory=dict)
    requires_human_review: bool = False

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
    """Output from the AI entity resolver."""
    query: str
    candidates: List[EntityCandidate]
    proposed_decision: Optional[EntityCandidate] = None

    def to_dict(self) -> dict:
        return {
            "query": self.query,
            "candidates": [c.to_dict() for c in self.candidates],
            "proposed_decision": (
                self.proposed_decision.to_dict()
                if self.proposed_decision
                else None
            ),
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

        # Weighted sum
        score = (
            lev * self.weights["levenshtein"]
            + abbrev * self.weights["abbreviation"]
        )
        return min(1.0, score)


class AmountMatcher:
    """Matches transactions by amount with configurable tolerance."""

    def __init__(self, exact_weight: float = 1.0, tolerance_pct: float = 0.05):
        """Initialize with match strategy.

        Args:
            exact_weight: Score for exact amount match (default 1.0).
            tolerance_pct: Fractional tolerance (e.g., 0.05 = ±5%).
        """
        self.exact_weight = exact_weight
        self.tolerance_pct = tolerance_pct

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

        if query_amount == candidate_amount:
            return self.exact_weight

        tolerance = query_amount * self.tolerance_pct
        if abs(query_amount - candidate_amount) <= tolerance:
            return 0.7  # Partial credit for within-tolerance match

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


class AIEntityMatcher:
    """
    Main orchestrator for AI-assisted entity resolution.

    Does NOT perform the actual database lookups or call the deterministic
    matcher — those are responsibilities of routers/services that use this.
    This class focuses on *scoring* candidates once they've been nominated.
    """

    def __init__(
        self,
        name_matcher: Optional[NameSimilarityMatcher] = None,
        amount_matcher: Optional[AmountMatcher] = None,
        temporal_matcher: Optional[TemporalProximityMatcher] = None,
    ):
        self.name_matcher = name_matcher or NameSimilarityMatcher()
        self.amount_matcher = amount_matcher or AmountMatcher()
        self.temporal_matcher = temporal_matcher or TemporalProximityMatcher()

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

        Returns:
            EntityCandidate with scored factors.
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

    def propose_decision(
        self, candidates: List[EntityCandidate]
    ) -> Optional[EntityCandidate]:
        """Select top candidate as the proposal (if any).

        Returns:
            Top candidate, or None if no candidates.
        """
        if not candidates:
            return None

        top = candidates[0]

        # Only auto-propose if confidence is high enough AND name match is strong
        if top.confidence >= 0.75 and top.scoring_factors.name_similarity >= 0.70:
            top.requires_human_review = False
        else:
            top.requires_human_review = True

        return top
