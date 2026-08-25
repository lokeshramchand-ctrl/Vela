# Wave 4: AI-Assisted Entity Resolution

**Status:** Planned | **Phase:** Post-deterministic enhancement  
**Introduced:** 2026-08-22

---

## Philosophy

AI should **augment**, not replace, the deterministic reconciliation engine.

The rule-based system (Phases 1-3) handles the obvious cases fast and cheaply. But some merchant name variations are genuinely ambiguous without semantic understanding:

- `AMAZON PAY` vs `AMZN INDIA` — likely same merchant
- `UPI` reference to `Uber ₹382` vs bank statement `UBER INDIA ₹382` — same txn, likely resolved
- `GPay Transfer` to `Swiggy FOOD` — subscription or split transaction?

Wave 4 introduces **AI-assisted candidate generation** for these edge cases, while keeping final matching logic explainable and debuggable.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Incoming Transaction / Noisy Text                      │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
            ┌────────────────────────┐
            │ Phase 1-3: Deterministic│
            │  Rule Matcher           │
            └─────────┬──────────────┘
                      │
          ┌───────────┴──────────────┐
          │                          │
      ┌───▼────┐            ┌───────▼──┐
      │ MATCH  │            │ NO MATCH │
      │ (High  │            │ or LOW   │
      │Conf)   │            │ CONF     │
      └────────┘            └────┬─────┘
                                  │
                     ┌────────────▼────────────┐
                     │ Phase 4: AI Matcher     │
                     │ (This Wave)             │
                     │                         │
                     │ - Merchant similarity   │
                     │ - Temporal proximity    │
                     │ - Amount heuristics     │
                     │ - Historical context    │
                     └────┬───────────────────┘
                          │
         ┌────────────────┬┴──────────────────┐
         │                │                   │
    ┌────▼─────┐   ┌─────▼──┐        ┌──────▼────┐
    │ Candidate│   │Ranking │        │ Confidence│
    │Generation│   │by Score│        │ Assignment│
    └──────────┘   └────────┘        └───────────┘
         │                                   │
         └───────────────┬───────────────────┘
                         │
                    ┌────▼────────────────┐
                    │ Proposal to Human   │
                    │ or Next Stage       │
                    └────────────────────┘
```

**Key invariants:**
- AI proposes, it doesn't auto-decide
- Every candidate carries a confidence score
- Decisions remain traceable: which heuristics fired?
- Falls back to deterministic rule matcher (human review queue)

---

## Candidate Scoring Heuristics

### 1. **Merchant Name Similarity**
- Levenshtein distance (exact-match proximity)
- Semantic embedding similarity (via Ollama)
- Abbreviation matching (AMZN → AMAZON)
- Common merchant aliases (frozen set lookup)

### 2. **Temporal Proximity**
- Same day / adjacent day transactions
- Weekday patterns (recurring pattern matching)
- Time-of-day clustering

### 3. **Amount Heuristics**
- Exact amount match (highest signal)
- Amount within tolerance (e.g., ±5 for rounding)
- Common transaction size ranges per merchant

### 4. **Historical Context**
- User's prior encounter with both merchants
- Trust state of proposed match (Phase 4 trust state machine)
- Category alignment

### 5. **Transaction Type Alignment**
- UPI → bank statement type matching
- Card payment fingerprints
- Subscription vs ad-hoc classification

---

## API Contract

### Request: Candidate Generation

```json
POST /v1/ai/entity-resolve
{
  "query_text": "UBER INDIA ₹382 AUG-11",
  "query_amount": 382,
  "query_date": "2024-08-11",
  "user_id": "user-123",
  "top_k": 5,
  "confidence_threshold": 0.65
}
```

### Response: Candidates with Scores

```json
{
  "query": "UBER INDIA ₹382 AUG-11",
  "candidates": [
    {
      "merchant": "Uber",
      "confidence": 0.96,
      "reasoning": {
        "name_similarity": 0.94,
        "temporal_proximity": 0.98,
        "amount_match": 1.0,
        "historical_context": 0.92
      },
      "evidence": {
        "last_seen": "2024-08-10",
        "encounter_count": 24,
        "canonical_category": "travel.cab"
      }
    },
    {
      "merchant": "UberEats",
      "confidence": 0.42,
      "reasoning": {
        "name_similarity": 0.85,
        "temporal_proximity": 0.88,
        "amount_match": 0.65,
        "historical_context": 0.12
      },
      "evidence": {
        "last_seen": "2024-07-15",
        "encounter_count": 3,
        "canonical_category": "food.delivery"
      }
    }
  ],
  "proposed_decision": {
    "merchant": "Uber",
    "confidence": 0.96,
    "requires_human_review": false
  }
}
```

---

## Phase 4 Memory Integration

The AI matcher **must** read from the Phase 4 trust state machine:

```python
# Pseudo-code
trust_profile = memory_engine.get_merchant_profile(candidate)
factors = {
    "trust_state": trust_profile.state,        # EPHEMERAL, TEMPORARY, PERMANENT
    "encounter_frequency": trust_profile.frequency,
    "confidence_decay_factor": trust_profile.decay,
}
```

A merchant with `PERMANENT` trust state scores higher than `EPHEMERAL`, all else equal.

---

## Implementation Plan

### Iteration 1: Name & Amount Matching (MVP)
- [ ] Implement `LevenshteinMatcher` (exact string distance)
- [ ] Add `AmountMatcher` (exact + tolerance-based)
- [ ] Wire Phase 4 trust state lookup
- [ ] Basic confidence aggregation (weighted average of heuristics)

### Iteration 2: Temporal & Historical Context
- [ ] Add temporal proximity scoring
- [ ] Integrate user transaction history
- [ ] Implement encounter-frequency weighting

### Iteration 3: Semantic Similarity (Embeddings)
- [ ] Wire Ollama embeddings for merchant names
- [ ] Cache merchant embeddings in Milvus
- [ ] Add semantic similarity heuristic

### Iteration 4: API & Integration
- [ ] Mount `/v1/ai/entity-resolve` endpoint
- [ ] Add to `/v1/resolve` decision tree (fallback after deterministic rules)
- [ ] Create human review queue integration

### Iteration 5: Observability & Feedback Loop
- [ ] Track AI matcher precision on accepted vs rejected proposals
- [ ] Add to `/v1/feedback/` (human corrections to AI candidates)
- [ ] Metrics: candidate recall, false-positive rate, avg confidence

---

## Non-Goals (Wave 4 Scope)

- Automatic acceptance of candidate matches (human-in-the-loop only)
- Real-time embedding generation (cached, batch-updated)
- Replacing the deterministic engine for high-confidence cases
- End-to-end retraining on user feedback (deferred to task queue infra)

---

## Success Metrics

1. **Candidate Recall:** AI matcher catches 80%+ of ambiguous cases deterministic rules miss
2. **Precision:** Top candidate is human-preferred in 90%+ of cases
3. **Latency:** Candidate generation completes in <500ms (including DB/vector lookups)
4. **Confidence Calibration:** Predicted confidence ≈ actual acceptance rate across buckets

---

## Related Documentation

- [Phase 1-3: Deterministic Merchant Resolution](./05-ingestion-resolution-memory.md)
- [Phase 4: Memory & Trust State Machine](./05-ingestion-resolution-memory.md)
- [Phase 7: Embeddings & Vector Search](./07-embeddings-vectorsearch-clustering.md)
- [RAG & Explainability](./10-rag-explainability.md)
