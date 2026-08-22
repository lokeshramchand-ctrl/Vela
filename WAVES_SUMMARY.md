# Vela Waves: Development Roadmap

A progressive series of features that build from raw transaction data to a complete finance operations platform.

## Wave Overview

| Wave | Feature | Status | PR |
|------|---------|--------|-----|
| Wave 1 | Core ingestion and categorization | ✅ Complete | merged |
| Wave 2 | Memory system and trust states | ✅ Complete | merged |
| Wave 3 | Behavioral signals and patterns | ✅ Complete | merged |
| Wave 4 | AI-assisted entity resolution | ✅ Complete | merged |
| Wave 5 | Confidence routing + exception management | ✅ Complete | merged |
| Wave 6 | Finance Controller UI | 🚀 Ready | pending |
| Wave 7 | Feedback loop + confidence calibration | 📋 Planned | - |
| Wave 8 | Batch operations + audit | 📋 Planned | - |

## Detailed Breakdown

### Wave 1: Core Ingestion (Foundation)

**What**: Parse bank statements, categorize transactions, store in database.

- PDF parsing (PyPDFium2)
- Transaction extraction (regex + merchant aliasing)
- SQLite/MongoDB storage
- Category classification (Merchant Name → Category)

**Why**: You can't build intelligence on data you don't have. Wave 1 ingests raw transactions and makes them queryable.

**Files**: `ingestion/`, `statements/`, `models/schemas.py`

---

### Wave 2: Memory System (Learned Context)

**What**: Remember merchants over time, track trust/permanence.

- Frequency-based entity encounters
- Trust state transitions (EPHEMERAL → TEMPORARY → PERMANENT)
- Merchant profile storage
- Historical pattern tracking

**Why**: A transaction is context-dependent. If you've seen "AMAZON" 100 times before, you trust it more than a one-off "AMAZON PAY".

**Files**: `memory/`, `behaviour/`, `repositories/profile_repository.py`

**Key Concept**: Trust is earned, not assumed.

---

### Wave 3: Behavioral Signals (Pattern Recognition)

**What**: Extract spending patterns, subscriptions, recurring transactions.

- Subscription detection (same merchant, regular intervals)
- Spending pattern anomalies
- Merchant category trends
- Cashback/refund identification

**Why**: Patterns reveal intent. Recurring transactions are different from one-time purchases. Anomalies hint at fraud or errors.

**Files**: `analytics/`, `engines/`, `features/`

**Key Insight**: A duplicate transaction on the same merchant 2 hours later is probably a mismatch, not a subscription.

---

### Wave 4: AI-Assisted Entity Resolution (Matching)

**What**: Given two transaction texts (e.g., "UBER INDIA" vs "UBER EATS"), decide if they're the same merchant.

- Merchant name similarity (fuzzy matching, embeddings)
- Amount alignment (within 1%? 10%?)
- Date proximity (same day? adjacent days?)
- Historical encounter context (how often do these co-occur?)

**Why**: Bank statements have different merchant names for the same entity. "Amazon" vs "Amazon.com" vs "AMZN". Without resolution, you can't reconcile.

**Files**: `ai_resolution/matcher.py`, `embeddings/`

**Key Output**: Confidence score (0-1) for each candidate match.

---

### Wave 5: Confidence Routing (Smart Filtering)

**What**: Route matches into three buckets based on Wave 4 confidence:

- **HIGH (>90%)**: Auto-match, no review needed
- **MEDIUM (65-90%)**: Queue for quick human review
- **LOW (<65%)**: Flag as exception, requires investigation

**Why**: Perfect accuracy > high throughput. A high-confidence auto-match is worth more than 10 unreviewed matches that might be wrong.

**Files**: `ai_resolution/matcher.py` (ConfidenceWall enum), `ai_resolution/test_matcher.py`

**Key Principle**: Never force a match. Better to flag than guess.

---

### Wave 6: Finance Controller UI (Operations Interface)

**What**: Build the operator dashboard for reviewing exceptions from Wave 5.

**Controller Dashboard**:
- Stats at a glance (records, matched, exceptions, unresolved, match rate, amount)
- Exception review workflow
- Quick approval/rejection of flagged transactions

**Why**: Exceptions are only useful if operators can act on them. Wave 6 closes the loop between backend intelligence and human decision-making.

**Files**: `frontend/lib/features/controller/`, `routers/controller.py`

**Key Metric**: Match rate at a glance. Operators know system health in real-time.

**User Journey**:
1. Open Controller → see summary
2. Tap "Review Exceptions" → see all flagged transactions
3. Tap exception → compare sources + system reasoning
4. Approve or reject → exception resolved, stats updated

---

### Wave 7: Feedback Loop (Calibration)

**What** (Planned): Use operator decisions from Wave 6 to improve Wave 5's confidence walls.

**Concept**:
- When operator approves exception with 72% confidence → note that 72% is actually reliable
- When operator rejects exception with 80% confidence → note that 80% is not reliable enough
- Retrain Wave 5 thresholds based on this feedback

**Why**: Confidence walls should drift based on real-world data. Wave 7 makes the system self-improving.

---

### Wave 8: Batch Operations (Scaling)

**What** (Planned): Handle high-volume reconciliation.

**Features**:
- Bulk resolve similar exceptions (same merchant, same issue type)
- Operator batching workflows
- CSV import/export for external reconciliation
- Audit trail for compliance

**Why**: Individual exception-by-exception review doesn't scale to thousands of daily transactions.

---

## Wave 6 → 7 Transition

After Wave 6 ships (controller is live), Wave 7 will:

1. **Log operator decisions** from every resolve action
2. **Analyze patterns** (e.g., "operators always approve 71% confidence with merchant name match")
3. **Update Wave 5 thresholds** based on observed reliability
4. **A/B test** new thresholds on incoming transactions
5. **Auto-adjust** as feedback accumulates

This creates a **feedback loop** where the system gets smarter as operators use it.

---

## Current Status (Aug 22, 2026)

### Wave 5 → Wave 6 Transition

Wave 5 (backend confidence routing) is complete and tested. Wave 6 (UI + operations) is ready for deployment.

**Wave 5 Output** → Wave 6 Consumer:
```
Wave 5: "This SWIGGY vs SWIGGY EATS match has 72% confidence"
        ↓
Wave 6: "Exception! Operator, can you decide?"
        ↓
Operator: "Looks like the same restaurant, approve it"
        ↓
Wave 6: [Exception resolved]
        ↓
Wave 7 (future): Logs "72% confidence + operator approval" for retraining
```

### Code Locations

| Wave | Domain | Presentation | API |
|------|--------|--------------|-----|
| 1-3 | `models/`, `analytics/` | N/A (API-only) | `routers/statements.py` |
| 4-5 | `ai_resolution/` | N/A | `routers/v1.py` (`/v1/resolve`) |
| 6 | `frontend/lib/features/controller/` | Flutter UI | `routers/controller.py` |

### Deployment Path

1. **Merge Wave 6 PR** to master
2. **Deploy backend** (`routers/controller.py` endpoints)
3. **Release mobile app** (Flutter controller feature)
4. **Start logging** operator decisions
5. **Plan Wave 7** feedback loop

---

## Design Philosophy Across Waves

### Accuracy over Throughput
- Wave 1: Parse correctly, not fast
- Wave 4: High-confidence matches over high match rate
- Wave 5: Route conservatively (low bar for exceptions)
- Wave 6: Make exceptions reviewable in seconds

### Learn from Feedback
- Wave 2: Track encounter frequency
- Wave 3: Detect anomalies
- Wave 5: Route based on confidence, not certainty
- Wave 7: Retrain on operator feedback

### Transparent Decision-Making
- Wave 4: Explain why a match is 72% confident
- Wave 5: Show confidence buckets, not a black box score
- Wave 6: Show both sides of every mismatch + system reasoning
- Every wave: "Here's what we did and why"

---

## Metrics Across Waves

| Wave | North Star Metric | Target |
|------|-------------------|--------|
| 1 | % of transactions parsed | 100% |
| 2 | % with trust state | >95% |
| 3 | % flagged for anomalies | <5% (only true outliers) |
| 4 | High-confidence matches | >90% |
| 5 | Match rate (high+medium) | >88% |
| 6 | Exception resolution time | <5 min |
| 7 | Feedback-driven improvement | +2% match rate/quarter |
| 8 | Bulk resolution efficiency | >1000 tx/operator/day |

---

## Next: Planning Wave 7

After Wave 6 is live, Wave 7 will focus on:

1. **Feedback Loop Infrastructure**
   - Log every operator decision (approve/reject) with metadata
   - Track decision latency (how long to review)
   - Measure decision consistency (operator agreement rate)

2. **Confidence Calibration**
   - Analyze which Wave 5 scores are actually reliable
   - Update thresholds based on operator feedback
   - A/B test new thresholds

3. **Active Learning**
   - Identify patterns that confuse the system (low operator agreement)
   - Propose new features or training data for Wave 5
   - Detect drift (does the 72% confidence threshold still work after 3 months?)

---

## Summary

Each wave adds one layer of intelligence:

```
Wave 1: "Here's your data" (Ingestion)
Wave 2: "Here's what we remember" (Memory)
Wave 3: "Here's what we notice" (Patterns)
Wave 4: "Here's our best match" (Resolution)
Wave 5: "Here's our confidence" (Routing)
Wave 6: "Here's for you to review" (Operations)
Wave 7: "Here's what we learned" (Feedback)
Wave 8: "Here's how to scale" (Batch)
```

Together, they form a complete **finance operations platform** that ingests, classifies, reconciles, and improves continuously.

---

**Current Branch**: `wave6`  
**Next Milestone**: Merge Wave 6, plan Wave 7 feedback infrastructure  
**For Details**: See WAVE6_QUICKSTART.md, docs/WAVE6.md, and individual wave documentation  

