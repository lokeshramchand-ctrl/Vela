# POST `/v1/explain`

## Method
`POST`

## URL
`/v1/explain`

## Purpose
Generates a grounded, hallucination-resistant natural-language explanation of a transaction categorization, by retrieving semantically relevant merchant data and constraining an LLM to reason only over that retrieved evidence.

## Authentication
**Required.** `X-Vela-API-Key: Vela_test_key_123`.

## Headers
| Header | Required | Value |
|---|---|---|
| `X-Vela-API-Key` | Yes | `Vela_test_key_123` |
| `Content-Type` | Yes | `application/json` |

## Request body
```json
{ "transaction_text": "Swiggy order", "target_question": "Why was this transaction categorized this way?" }
```
Validated against the router-local `ExplainRequest` model (`routers/rag.py`): `transaction_text: str` (required), `target_question: str` (optional, defaults to `"Why was this transaction categorized this way?"`).

## Validation
Type-level only â€” no length limits on `transaction_text`, no constraint that `target_question` be a genuine question. An empty `transaction_text` is accepted and would simply produce (most likely) zero semantic matches.

## Response
`200 OK`, untyped JSON object:
```json
{
  "query": "Swiggy order",
  "retrieved_documents": 2,
  "result": {
    "explanation": "This transaction was categorized as Food because Swiggy has a PERMANENT memory state with 14 prior transactions, averaging â‚¹412.30, consistent with food delivery spending patterns.",
    "confidence_in_explanation": "HIGH",
    "primary_data_source": "Swiggy"
  }
}
```
Three possible shapes for `result`:
1. **Grounded success** â€” the shape above, produced by the LLM under strict system-prompt constraints.
2. **No context found**: `{"error": "No historical behavior found to explain this transaction."}`, `retrieved_documents: 0` â€” produced entirely without calling the LLM.
3. **Generation failure** (Ollama down, timeout, malformed response): `{"error": "Failed to generate explanation due to internal model error."}`.

## Error codes
| Code | When |
|---|---|
| `401` | Missing API key |
| `403` | Wrong API key |
| `422` | `transaction_text` missing or wrong type |
| `500` | Unexpected â€” every known failure mode in this pipeline (empty context, Ollama failure) is caught and converted to a soft `200` response with an `"error"` key inside `result`, rather than propagating as an HTTP error |

## Internal execution flow
```mermaid
sequenceDiagram
    participant C as Client
    participant Ctl as routers/rag.py::explain_transaction
    participant Retr as rag.retriever.context_retriever
    participant VS as milvus.search_vectors.vector_search
    participant Emb as embeddings.generate_embeddings.embedding_generator
    participant Mongo as MongoDB
    participant CB as rag.context_builder.context_builder
    participant Gen as rag.generator.explanation_generator
    participant Ollama as Ollama

    C->>Ctl: POST /v1/explain {transaction_text, target_question}
    Ctl->>Retr: fetch_grounded_context(transaction_text)
    Retr->>Emb: generate(transaction_text)
    Emb->>Ollama: POST /api/embeddings
    Ollama-->>Emb: vector
    Retr->>VS: find_similar_behaviors(transaction_text, top_k=3)
    VS-->>Retr: matched merchants (or [])
    loop each match
        Retr->>Mongo: merchant_profiles.find_one, behavior_patterns.find_one, feedback.find(...).limit(3)
    end
    Retr-->>Ctl: context_payloads[]
    Ctl->>CB: build_prompt_string(context_payloads)
    CB-->>Ctl: XML block or "NO_CONTEXT_AVAILABLE"
    Ctl->>Gen: generate_explanation(target_question, context_string)
    alt context is NO_CONTEXT_AVAILABLE
        Gen-->>Ctl: {"error": "No historical behavior found..."}
    else
        Gen->>Ollama: POST /api/generate {system, prompt, format: json}
        Ollama-->>Gen: {"response": "<json string>"}
        Gen-->>Ctl: parsed JSON or {"error": "Failed to generate..."}
    end
    Ctl-->>C: {query, retrieved_documents, result}
```

## Controller
`explain_transaction(request: ExplainRequest)` in `routers/rag.py` â€” unusually for this codebase, inlines all three pipeline-stage calls directly rather than delegating to a single facade function.

## Service
Three cooperating services, called in sequence: `rag.retriever.context_retriever.fetch_grounded_context`, `rag.context_builder.context_builder.build_prompt_string` (pure, no I/O), `rag.generator.explanation_generator.generate_explanation`.

## Database queries
Per matched merchant (up to `top_k=3`, sequentially, not concurrently):
- `db.merchant_profiles.find_one({"canonical_name": name}, {"_id": 0})`
- `db.behavior_patterns.find_one({"merchant_name": name}, {"_id": 0})`
- `db.feedback.find({"prediction": name}).sort("timestamp", -1).limit(3)`

Plus one Milvus vector search (`vector_store.client.search(...)`) and one Ollama embedding call and (usually) one Ollama generation call â€” this is the most I/O-heavy endpoint in the entire application.

## Example request
```bash
curl -s -X POST http://localhost:8000/v1/explain \
  -H "X-Vela-API-Key: Vela_test_key_123" \
  -H "Content-Type: application/json" \
  -d '{"transaction_text": "Swiggy order", "target_question": "Why was this categorized as Food?"}'
```

## Example response
```json
{
  "query": "Swiggy order",
  "retrieved_documents": 1,
  "result": {
    "explanation": "Swiggy is a well-established merchant (PERMANENT memory state, 14 transactions) with an average spend of â‚¹412.30, strongly consistent with food delivery.",
    "confidence_in_explanation": "HIGH",
    "primary_data_source": "Swiggy"
  }
}
```
No-context example (common in a fresh deployment, since the embedding-write pipeline is never automatically run â€” see `docs/07-embeddings-vectorsearch-clustering.md`):
```json
{
  "query": "Swiggy order",
  "retrieved_documents": 0,
  "result": { "error": "No historical behavior found to explain this transaction." }
}
```

## Interview questions
- "Explain, layer by layer, how this endpoint prevents the LLM from hallucinating." (1. If Milvus finds no semantic matches, retrieval returns `[]`. 2. `build_prompt_string` converts that into the sentinel `\"NO_CONTEXT_AVAILABLE\"`. 3. `generate_explanation` checks for that sentinel and skips calling the LLM entirely â€” no network call, no chance for the model to invent an answer. 4. If the LLM *is* called, its system prompt explicitly instructs it to output an error if the context is insufficient. 5. `format: \"json\"` constrains Ollama's decoding to syntactically valid JSON, a model-level guarantee, not just an instruction.)
- "Why would this endpoint frequently return 'no historical behavior found' in a freshly deployed environment, even with real transaction data present?" (Because the Milvus `behavior_vectors` collection that semantic search depends on is never populated automatically â€” the embedding-generation-and-insertion pipeline (`embeddings/vectorizer.py` â†’ `embeddings/generate_embeddings.py` â†’ `milvus/insert_vectors.py`) exists as building blocks with no orchestrating script or scheduled job connecting them.)
- "What's the worst-case latency for this endpoint, and why?" (Roughly the sum of the embedding timeout (15s), Milvus search time, up to 9 sequential Mongo round trips (3 per matched merchant, not parallelized), and the generation timeout (30s) â€” potentially tens of seconds in the worst case, since nothing in this pipeline runs concurrently.)
- "Why does `retrieved_documents` count matched merchants rather than, say, total feedback records or behavior data points considered?" (It's a coarse proxy for 'how much context did we actually have,' counting distinct entities the semantic search found, not the total volume of underlying data assembled about them.)

