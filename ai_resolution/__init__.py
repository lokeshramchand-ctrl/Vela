"""Wave 4: AI-Assisted Entity Resolution Module

This module provides semantic and heuristic-based candidate generation
for merchant matching in ambiguous cases, augmenting (not replacing) the
deterministic rule engine.

Key classes:
  - AIEntityMatcher: Main orchestrator for scoring candidates
  - NameSimilarityMatcher: String-based merchant name matching
  - AmountMatcher: Amount-based transaction matching
  - TemporalProximityMatcher: Date-based proximity scoring
  - EntityCandidate: Proposed match with confidence and reasoning
"""

from .matcher import (
    AIEntityMatcher,
    AmountMatcher,
    NameSimilarityMatcher,
    TemporalProximityMatcher,
    EntityCandidate,
    ResolutionRequest,
    ResolutionResponse,
    ScoringFactors,
    ConfidenceSource,
)

__all__ = [
    "AIEntityMatcher",
    "AmountMatcher",
    "NameSimilarityMatcher",
    "TemporalProximityMatcher",
    "EntityCandidate",
    "ResolutionRequest",
    "ResolutionResponse",
    "ScoringFactors",
    "ConfidenceSource",
]
