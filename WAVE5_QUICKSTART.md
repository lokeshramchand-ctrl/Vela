# Wave 5: Quick Start Guide

## What Changed?

Wave 5 adds **confidence wall routing** to the entity resolver. Matches are now automatically classified into three buckets based on confidence:

### The Three Walls

```python
from ai_resolution.matcher import AIEntityMatcher, ConfidenceWall

matcher = AIEntityMatcher()

# Score a candidate (Wave 4)
candidate = matcher.score_candidate(...)  # Returns: confidence=0.85

# Route by wall (Wave 5)
decision = matcher.propose_decision([candidate])

if decision.confidence_wall == ConfidenceWall.AUTO_MATCH:       # >90%
    apply_match_directly()
    # No review needed—system is confident
    
elif decision.confidence_wall == ConfidenceWall.HUMAN_REVIEW:   # 65-90%
    queue_for_user_approval()
    # Quick validation (usually <30 seconds)
    
else:  # ConfidenceWall.EXCEPTION                               # <65%
    escalate_with_reason(decision.exception_reason)
    # Route to manual investigation
```

## Key Addition: Exception Reasons

When a match falls into EXCEPTION, the system explains why:

```python
from ai_resolution.matcher import ExceptionReason

decision = matcher.propose_decision([low_confidence_candidate])

if decision.exception_reason == ExceptionReason.LOW_CONFIDENCE:
    print("Overall score is too low")
    
elif decision.exception_reason == ExceptionReason.WEAK_NAME_MATCH:
    print("Merchant name doesn't match, despite other signals")
    
elif decision.exception_reason == ExceptionReason.AMBIGUOUS_CANDIDATES:
    print("Multiple candidates are equally plausible")
    
elif decision.exception_reason == ExceptionReason.CONFLICTING_SIGNALS:
    print("Name and amount signals disagree")
    
else:  # MISSING_CONTEXT
    print("Insufficient data to decide")
```

## Example: Full Flow

```python
from ai_resolution.matcher import AIEntityMatcher, ConfidenceWall
from datetime import datetime

matcher = AIEntityMatcher(
    high_confidence_threshold=0.90,      # Can customize
    medium_confidence_threshold=0.65,    # Can customize
)

# Scenario 1: High confidence (matches well)
candidate_a = matcher.score_candidate(
    query_text="UBER INDIA",
    query_amount=382.0,
    query_date=datetime(2026, 8, 22),
    candidate_merchant="Uber",
    candidate_amount=382.0,
    candidate_date=datetime(2026, 8, 22),
    historical_encounters=25,
    trust_state="PERMANENT",
)
# confidence ≈ 0.94 → AUTO_MATCH ✓

# Scenario 2: Medium confidence (partial match)
candidate_b = matcher.score_candidate(
    query_text="SWIGGY EATS",
    query_amount=450.0,
    query_date=datetime(2026, 8, 22),
    candidate_merchant="Swiggy",
    candidate_amount=460.0,          # Different amount
    candidate_date=datetime(2026, 8, 21),  # Different day
    historical_encounters=3,
    trust_state="TEMPORARY",
)
# confidence ≈ 0.73 → HUMAN_REVIEW ⚠️

# Scenario 3: Low confidence (weak match)
candidate_c = matcher.score_candidate(
    query_text="XXX UNKNOWN MERCHANT",
    query_amount=100.0,
    query_date=datetime(2026, 8, 22),
    candidate_merchant="Some Random Store",
    candidate_amount=200.0,              # Very different
    candidate_date=datetime(2026, 8, 15),    # 7 days apart
    historical_encounters=0,
    trust_state="EPHEMERAL",
)
# confidence ≈ 0.42 → EXCEPTION ❌
```

## Testing

Run Wave 5 tests:

```bash
# All tests
python -m unittest ai_resolution.test_matcher.TestConfidenceWalls -v

# Output:
# test_route_auto_match_high_confidence ... ok
# test_route_human_review_medium_confidence ... ok
# test_route_exception_low_confidence ... ok
# test_detect_exception_reason_low_confidence ... ok
# test_detect_exception_reason_weak_name_match ... ok
# test_detect_ambiguity_similar_candidates ... ok
# test_detect_ambiguity_clear_winner ... ok
# test_propose_decision_with_confidence_wall ... ok
# test_propose_decision_exception_with_reason ... ok
# ✅ 9/9 tests passing
```

## Configuration

### Custom Thresholds

```python
# Stricter AUTO_MATCH (require 95% confidence)
matcher = AIEntityMatcher(high_confidence_threshold=0.95)

# More permissive HUMAN_REVIEW (allow 55% confidence)
matcher = AIEntityMatcher(medium_confidence_threshold=0.55)

# Both custom
matcher = AIEntityMatcher(
    high_confidence_threshold=0.92,
    medium_confidence_threshold=0.60,
)
```

### Reading a Decision

```python
decision = matcher.propose_decision([candidate])

print(f"Merchant: {decision.merchant}")
print(f"Confidence: {decision.confidence:.1%}")
print(f"Route: {decision.confidence_wall}")
print(f"Requires review: {decision.requires_human_review}")
print(f"Why (if exception): {decision.exception_reason}")

# Serialize to JSON
import json
print(json.dumps(decision.to_dict(), indent=2))
```

## Philosophy: Never Force a Match

Wave 5 embodies Vela's core principle: **accuracy over throughput**.

Rather than trying to match 100% of transactions (many incorrectly), Wave 5 aims for:
- ✅ 100% accuracy on AUTO_MATCH cases
- ✓ Fast approval on HUMAN_REVIEW cases
- ℹ️ Transparent escalation on EXCEPTION cases

This builds **user trust** because:
1. High-confidence decisions rarely need correction
2. Medium-confidence decisions are quick to validate
3. Low-confidence cases show honest uncertainty

## Files

| File | Purpose |
|------|---------|
| `ai_resolution/matcher.py` | Core Wave 4-5 implementation |
| `ai_resolution/test_matcher.py` | 33 tests (24 Wave 4 + 9 Wave 5) |
| `docs/WAVE5.md` | Complete Wave 5 specification |
| `docs/WAVES_SUMMARY.md` | Summary of all waves |
| `WAVE5_QUICKSTART.md` | This file |

## Git History

```
commit 8619950  Wave 5: Confidence walls + exception management
commit c56f63c  Wave 4: AI-assisted entity resolution matcher
```

Branch: `wave5` (ready to PR to `master`)

## Next Steps

1. **Review** the WAVE5.md specification
2. **Run tests** to verify implementation
3. **Integrate** into transaction processing pipeline
4. **Monitor** AUTO_MATCH accuracy and EXCEPTION patterns
5. **Plan Wave 6** (active learning feedback loop)

---

**Need help?** See `docs/WAVE5.md` for detailed architecture and design decisions.
