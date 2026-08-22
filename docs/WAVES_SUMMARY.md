# Vela Entity Resolution: Multi-Wave Development Summary

## Quick Reference

| Wave | Focus | Status | Location |
|------|-------|--------|----------|
| **Wave 1-3** | Foundation | Historical | Early commits |
| **Wave 4** | AI-Assisted Semantic Matching | ✅ Complete | `ai_resolution/matcher.py` |
| **Wave 5** | Confidence Walls + Exception Management | ✅ Complete | `ai_resolution/matcher.py` + `docs/WAVE5.md` |

---

## Wave 4: AI-Assisted Entity Resolution Matcher

**Commit**: `c56f63c`  
**Doc**: See `docs/06-confidence-behavioral-intelligence.md` for full architecture

### Problem Solved
Merchant names in bank statements are noisy and inconsistent (e.g., "UBER INDIA" vs "Uber"). Deterministic rule-based matching fails when names don't align. Wave 4 adds semantic matching on top of rules.

### Architecture
1. **Candidate Nomination**: Deterministic rules generate candidate merchants
2. **Heuristic Scoring**: Apply weighted factors to rank candidates
   - Name similarity (Levenshtein + abbreviation detection)
   - Amount matching (exact + tolerance-based)
   - Temporal proximity (same-day bonuses)
   - Historical context (trust weights from Phase 4)
   - Trust state (EPHEMERAL/TEMPORARY/PERMANENT boost)
3. **Ranking**: Sort candidates by confidence score
4. **Proposal**: Return top candidate with reasoning breakdown

### Key Classes
- **`AIEntityMatcher`**: Main orchestrator
- **`NameSimilarityMatcher`**: String-based similarity (Levenshtein, abbreviations)
- **`AmountMatcher`**: Exact + tolerance-based amount matching
- **`TemporalProximityMatcher`**: Date-based proximity scoring
- **`EntityCandidate`**: Proposed match with confidence + reasoning
- **`ScoringFactors`**: Breakdown of how candidate was scored

### Example Output
```python
candidate = matcher.score_candidate(
    query_text="UBER INDIA",
    query_amount=382.0,
    query_date=datetime(2026, 8, 22),
    candidate_merchant="Uber",
    candidate_amount=382.0,
    candidate_date=datetime(2026, 8, 22),
    historical_encounters=20,
    trust_state="PERMANENT",
)

# Output:
EntityCandidate(
    merchant="Uber",
    confidence=0.87,
    scoring_factors=ScoringFactors(
        name_similarity=0.95,
        amount_match=1.0,
        temporal_proximity=1.0,
        historical_context=0.95,
        trust_state_factor=1.04,  # PERMANENT boost
    ),
    requires_human_review=True,  # Still needs approval in Wave 4
)
```

### Test Coverage
**Wave 4 Tests**: 24 tests covering:
- Name similarity (exact, case-insensitive, partial, abbreviations)
- Amount matching (exact, tolerance, missing data)
- Temporal proximity (same-day, adjacent, beyond max_days)
- Scoring factor aggregation (equal/custom weights)
- Candidate ranking and filtering

### Limitations
- Proposes candidates but doesn't route decisions
- All candidates require human review or downstream acceptance
- No distinction between high/medium/low confidence scenarios
- No exception handling or escalation paths

---

## Wave 5: Confidence Walls + Exception Management

**Branch**: `wave5`  
**Doc**: See `docs/WAVE5.md` for full details

### Problem Solved
Wave 4 scores candidates but doesn't tell downstream systems what to do with them. A 95% confidence match should auto-apply. A 42% confidence match should escalate. Wave 5 implements this routing.

### Core Philosophy
**Never force a match simply because the system has to produce an answer.**

### Confidence Walls
Three deterministic routing buckets:

```
95% confidence  →  AUTO-MATCH       (apply directly, no review)
78% confidence  →  HUMAN_REVIEW     (show to user, needs approval)
42% confidence  →  EXCEPTION        (escalate, investigate)
```

### Exception Classification
When routed to EXCEPTION, classify the failure:
- **LOW_CONFIDENCE**: Overall score is very low (<40%)
- **WEAK_NAME_MATCH**: Name similarity is poor despite other signals
- **AMBIGUOUS_CANDIDATES**: Multiple candidates within 5% confidence
- **CONFLICTING_SIGNALS**: Scoring factors disagree (name ≠ amount)
- **MISSING_CONTEXT**: Insufficient data to decide

### Key Additions

#### Enums
```python
class ConfidenceWall(str, Enum):
    AUTO_MATCH = "auto_match"          # >90%
    HUMAN_REVIEW = "human_review"      # 65-90%
    EXCEPTION = "exception"            # <65%

class ExceptionReason(str, Enum):
    LOW_CONFIDENCE = "low_confidence"
    WEAK_NAME_MATCH = "weak_name_match"
    AMBIGUOUS_CANDIDATES = "ambiguous_candidates"
    CONFLICTING_SIGNALS = "conflicting_signals"
    MISSING_CONTEXT = "missing_context"
```

#### Methods
- **`route_by_confidence_wall()`**: Assign candidate to wall
- **`detect_exception_reason()`**: Classify why it failed
- **`detect_ambiguity()`**: Flag ambiguous scenarios (top 2 within 5%)

#### Updated Classes
- **`EntityCandidate`**: Now includes `confidence_wall` + `exception_reason`
- **`ResolutionResponse`**: Now includes `routing_decision`, `exceptions`, `is_ambiguous`
- **`AIEntityMatcher.__init__()`**: New threshold parameters for customization

### Customization
```python
matcher = AIEntityMatcher(
    high_confidence_threshold=0.92,    # Stricter AUTO_MATCH
    medium_confidence_threshold=0.60,  # More permissive HUMAN_REVIEW
)
```

### Example Flow
```python
# Score candidate (Wave 4)
candidate = matcher.score_candidate(...)  # confidence=0.78

# Route by wall (Wave 5)
decision = matcher.propose_decision([candidate])
# decision.confidence_wall = ConfidenceWall.HUMAN_REVIEW

# Downstream handling:
if decision.confidence_wall == ConfidenceWall.AUTO_MATCH:
    apply_match_directly()
elif decision.confidence_wall == ConfidenceWall.HUMAN_REVIEW:
    queue_for_user_approval()
else:
    escalate_with_reason(decision.exception_reason)
```

### Test Coverage
**Wave 5 Tests**: 9/9 passing
- Confidence wall routing (AUTO_MATCH, HUMAN_REVIEW, EXCEPTION)
- Exception reason detection (all 5 categories)
- Ambiguity detection (similar vs clear winners)
- Decision proposal with wall + reason

---

## Design Principles

### 1. Deterministic Routing
Thresholds are fixed and configurable, not probabilistic. Easy to audit and explain to users.

### 2. Never Force a Match
Rather than optimizing for throughput (100% match rate), optimize for accuracy. Low-confidence matches are escalated rather than guessed.

### 3. Transparency
Every match includes reasoning: which factors contributed, why it was routed to a wall, what the uncertainty is.

### 4. Layered Confidence
- High confidence: Fast path (auto-match)
- Medium confidence: Quick approval (user validates in seconds)
- Low confidence: Investigation (manual queue)

### 5. Exception as Information
Escalated cases are not failures—they're data. Track patterns to improve future training.

---

## Data Flow

```
Transaction
    ↓
[Deterministic Rules]  ← Generate candidate merchants
    ↓
[Wave 4: Score]        ← Apply heuristics (name, amount, temporal, historical)
    ↓
[Wave 5: Route]        ← Assign confidence wall
    ↓
┌─────────────────────────────────────────────┐
│ HIGH (>90%)  │ MEDIUM (65-90%) │ LOW (<65%) │
│  AUTO-MATCH  │ HUMAN_REVIEW    │ EXCEPTION  │
└─────────────────────────────────────────────┘
    ↓              ↓                   ↓
  Apply          Queue for         Escalate
  directly       approval           + reason
```

---

## Future Roadmap

### Wave 6: Active Learning Feedback Loop
- Track user rejections and corrections
- Retrain scoring model on corrected examples
- Adjust heuristic weights based on real outcomes

### Wave 7: Temporal Confidence Decay
- Trust decreases over time for unchanged merchants
- Re-validate old matches if merchant context shifts
- Refresh historical context weights periodically

### Wave 8: Ensemble Confidence
- Combine multiple independent matchers (rules-based, embedding-based, LLM-based)
- Cross-validate for higher confidence
- Fallback to ensemble vote if individual matchers disagree

### Wave 9: Behavioral Intelligence
- Learn user-specific preferences (some users accept broader matches)
- Context-aware thresholds (higher confidence required for large transactions)
- Anomaly detection (flag suspicious patterns in match acceptance)

---

## Key Metrics

### Wave 4
- Candidate accuracy: % of top-ranked candidates that user accepts
- Confidence calibration: Does 90% confidence = 90% user agreement?

### Wave 5
- AUTO_MATCH acceptance rate: % of auto-applied matches that survive manual audit
- HUMAN_REVIEW decision time: Median seconds to user approval
- EXCEPTION escalation rate: % of transactions that reach exception bucket
- False negative rate: % of correct merchants missed by thresholds

---

## Files Modified

### Core Implementation
- `ai_resolution/matcher.py` — Wave 4-5 orchestrator and heuristics
- `ai_resolution/test_matcher.py` — 33 tests covering Waves 4-5

### Documentation
- `docs/WAVE4.md` — *Historical* (see commit c56f63c)
- `docs/WAVE5.md` — Complete Wave 5 specification
- `docs/WAVES_SUMMARY.md` — This file

### Git History
- `c56f63c` — Wave 4: AI-assisted entity resolution matcher
- `wave5` branch — Wave 5: Confidence walls + exception management

---

## Running Tests

```bash
# All tests (Wave 4-5)
python -m unittest ai_resolution.test_matcher -v

# Wave 5 tests only
python -m unittest ai_resolution.test_matcher.TestConfidenceWalls -v
```

Expected results: **9/9 Wave 5 tests passing**, **24/24 Wave 4 tests passing**.

---

## Glossary

| Term | Definition |
|------|-----------|
| **Confidence** | Score [0, 1] indicating likelihood that a match is correct |
| **Confidence Wall** | Routing bucket (AUTO_MATCH, HUMAN_REVIEW, EXCEPTION) |
| **Candidate** | Proposed merchant match with scoring breakdown |
| **Heuristic** | Rule-based scoring factor (name, amount, temporal, etc.) |
| **Exception** | Low-confidence match that requires escalation |
| **Ambiguous** | Multiple candidates within 5% confidence (unclear ranking) |
| **Historical Context** | Count of times user has seen a merchant (trust weight) |
| **Trust State** | Stability of merchant (EPHEMERAL, TEMPORARY, PERMANENT) |

---

**Last Updated**: August 22, 2026  
**Version**: Wave 5 (final)
