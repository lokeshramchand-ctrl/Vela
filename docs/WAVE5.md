# Wave 5: Confidence Walls + Exception Management

**Date**: August 22, 2026  
**Status**: Complete  
**Build on**: Wave 4 (AI-assisted entity resolution matcher)

## Overview

Wave 5 implements the confidence wall philosophy: a system that routes merchant matches based on confidence thresholds rather than forcing uncertain matches. The key insight is **never auto-accept a match simply because the system must produce an answer**.

```
Match confidence: 98%  →  AUTO-MATCH (no human review needed)
Match confidence: 81%  →  HUMAN_REVIEW (needs approval)
Match confidence: 42%  →  EXCEPTION (unresolved, escalate)
```

## Architecture

### Confidence Walls

Three deterministic routing buckets based on confidence score:

| Wall | Confidence | Action | Rationale |
|------|-----------|--------|-----------|
| **AUTO_MATCH** | >90% | Accept automatically | High confidence in match quality |
| **HUMAN_REVIEW** | 65-90% | Require human approval | Moderate confidence, edge case |
| **EXCEPTION** | <65% | Escalate unresolved | Low confidence, needs investigation |

### Exception Handling

When a candidate falls into the EXCEPTION bucket, the system classifies the failure reason:

- **LOW_CONFIDENCE**: Overall confidence score is very low (<40%)
- **WEAK_NAME_MATCH**: Name similarity is poor despite other signals
- **AMBIGUOUS_CANDIDATES**: Multiple candidates are too close in confidence (within 5%)
- **CONFLICTING_SIGNALS**: Different scoring factors disagree (e.g., name ≠ amount)
- **MISSING_CONTEXT**: Insufficient data to make a decision

### Key Components

#### `ConfidenceWall` Enum
Routing decision for a candidate:
- `AUTO_MATCH`: Trust the system
- `HUMAN_REVIEW`: Needs approval
- `EXCEPTION`: Escalate

#### `ExceptionReason` Enum
Why a match was routed to EXCEPTION:
- `LOW_CONFIDENCE`
- `WEAK_NAME_MATCH`
- `AMBIGUOUS_CANDIDATES`
- `CONFLICTING_SIGNALS`
- `MISSING_CONTEXT`

#### `route_by_confidence_wall()`
Deterministically assigns a candidate to a wall based on its confidence score.

```python
wall = matcher.route_by_confidence_wall(candidate)
# Returns: ConfidenceWall.AUTO_MATCH | HUMAN_REVIEW | EXCEPTION
```

#### `detect_exception_reason()`
Classifies *why* a candidate failed to reach AUTO_MATCH or HUMAN_REVIEW.

```python
reason = matcher.detect_exception_reason(candidate, all_candidates)
# Returns: ExceptionReason enum + context
```

#### `detect_ambiguity()`
Flags scenarios where multiple candidates are too similar to rank confidently.

```python
is_ambiguous = matcher.detect_ambiguity(candidates)
# True if top 2 candidates within 5% confidence
```

## Integration

### Changes to `EntityCandidate`
- `confidence_wall`: Assigned by `route_by_confidence_wall()`
- `exception_reason`: Set when routed to EXCEPTION

### Changes to `ResolutionResponse`
- `routing_decision`: Overall decision (AUTO_MATCH | HUMAN_REVIEW | EXCEPTION)
- `exceptions`: List of escalation notes
- `is_ambiguous`: Flag for ambiguous scenarios

### Changes to `AIEntityMatcher.__init__()`
New constructor parameters:
- `high_confidence_threshold`: Cutoff for AUTO_MATCH (default 0.90)
- `medium_confidence_threshold`: Cutoff for HUMAN_REVIEW (default 0.65)

### Threshold Customization

```python
matcher = AIEntityMatcher(
    high_confidence_threshold=0.92,    # Stricter AUTO_MATCH
    medium_confidence_threshold=0.60,  # More permissive HUMAN_REVIEW
)
```

## Decision Logic

### For AUTO_MATCH (confidence > 0.90)
- No human review required
- Directly apply the match
- Log confidence for audit

### For HUMAN_REVIEW (0.65 ≤ confidence ≤ 0.90)
- Display candidate to user
- Require explicit approval
- Log user decision (accept/reject)

### For EXCEPTION (confidence < 0.65)
- Do not auto-apply
- Escalate with reason context
- Route to manual investigation queue
- Track failure patterns for future ML training

## Test Coverage

**Wave 5 Tests (9/9 passing):**

1. `test_route_auto_match_high_confidence` — >0.90 routes to AUTO_MATCH
2. `test_route_human_review_medium_confidence` — 0.65-0.90 routes to HUMAN_REVIEW
3. `test_route_exception_low_confidence` — <0.65 routes to EXCEPTION
4. `test_detect_exception_reason_low_confidence` — Flags very low confidence
5. `test_detect_exception_reason_weak_name_match` — Flags poor name similarity
6. `test_detect_ambiguity_similar_candidates` — Detects candidates within 5%
7. `test_detect_ambiguity_clear_winner` — Clear gaps are not ambiguous
8. `test_propose_decision_with_confidence_wall` — Decision includes wall + reason
9. `test_propose_decision_exception_with_reason` — Exception includes reason enum

## Usage Example

```python
from ai_resolution.matcher import AIEntityMatcher, ResolutionRequest

matcher = AIEntityMatcher()

# Score a candidate
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

# Route by confidence wall
decision = matcher.propose_decision([candidate])

if decision.confidence_wall == ConfidenceWall.AUTO_MATCH:
    apply_match_directly(decision.merchant)
    
elif decision.confidence_wall == ConfidenceWall.HUMAN_REVIEW:
    queue_for_human_approval(decision)
    
else:  # EXCEPTION
    escalate_with_reason(decision.exception_reason)
```

## Philosophy

**Never force a match.**

This is the centerpiece of Wave 5. Rather than optimizing for throughput (matching 100% of transactions), Vela optimizes for **accuracy and trust**:

- ✅ Accept high-confidence matches without review
- ✓ Flag medium-confidence matches for quick user validation
- ✗ Escalate low-confidence cases rather than guessing

This approach builds user confidence in the system because:
1. High-confidence decisions are reliable (reduces false positives)
2. Medium-confidence decisions are quick to validate (reduces friction)
3. Low-confidence cases are transparent about uncertainty (builds trust)

## Future Work

- **Wave 6**: Active learning feedback loop (user rejections inform model retraining)
- **Wave 7**: Temporal confidence decay (trust decreases over time for unchanged merchants)
- **Wave 8**: Ensemble confidence (combine multiple independent matchers)
