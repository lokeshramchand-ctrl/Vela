# File: `routers/rag.py`

## Purpose
Exposes the Phase 12 grounded-explanation pipeline as a single HTTP endpoint, orchestrating all three RAG stages inline.

## Responsibilities
- Expose `POST /v1/explain`.
- Call the retrieve → build → generate pipeline in sequence.
- Shape the final response with a small amount of metadata (`retrieved_documents` count).

## Imports
| Import | Used for |
|---|---|
| `fastapi.APIRouter` | Router construction |
| `pydantic.BaseModel` | Base for the local `ExplainRequest` |
| `rag.retriever.context_retriever` | Stage 1: semantic search + structured lookups |
| `rag.context_builder.context_builder` | Stage 2: prompt formatting |
| `rag.generator.explanation_generator` | Stage 3: LLM call + JSON parsing |

## Exports
**`router`** — mounted by `app.py` under prefix `/v1` (adding the `/explain` path to that prefix).

## Execution Flow
1. On import, `router` and `ExplainRequest` are declared.
2. Per-request: `explain_transaction` runs all three pipeline stages synchronously in sequence, awaiting each before starting the next (no parallelism between stages, since each depends on the previous one's output).

## Functions (plain English)

### `explain_transaction(request: ExplainRequest)`
Bound to `POST /v1/explain`. In simple English: "First, go find any merchants that seem semantically related to this transaction text, along with everything we know about them. Then, format all of that into a clear, structured block of text. Finally, hand that block plus the user's question to the language model and ask it to explain — using only what we gave it, nothing it might otherwise know or guess. Send back the model's answer, along with how many merchants we actually found data for." This function contains no branching logic itself — all the "what if nothing was found" handling lives inside the three delegated stage functions; this handler just chains their outputs together.

## Classes

### `ExplainRequest(BaseModel)`
Two fields: `transaction_text: str`, `target_question: str` (defaults to `"Why was this transaction categorized this way?"`). The request body shape for `/v1/explain`.

## Interfaces
Not applicable formally — the response shape here is a plain dict, not a declared `response_model`.

## Hooks
Auth dependency attached externally in `app.py`, same as every other router.

## Utilities
None.

## Dependencies
`fastapi`, `pydantic` (third-party); `rag.retriever`, `rag.context_builder`, `rag.generator` (internal).

## Side Effects
- Triggers a real vector search against Milvus, multiple MongoDB reads, and a real HTTP call to an Ollama LLM server — this is the single most I/O-heavy endpoint in the entire application, combining three different external systems in one request.

## Performance Considerations
- Latency here is the sum of: embedding generation (up to 15s timeout), Milvus search, up to `top_k × 3` sequential Mongo lookups, and LLM generation (up to 30s timeout) — in the worst case, this endpoint could take tens of seconds to respond if any stage is slow, since nothing runs in parallel.
- Because `explanation_generator` and `context_retriever`'s dependencies (`core.ollama_client`, `milvus.insert_vectors`) do real I/O at *their own* import time, the very first request to hit this router after a cold start doesn't pay any extra cost beyond the request-time work itself — the risky cost (host resolution, Milvus client construction) already happened when the process started, not when this specific endpoint is first called.

## Possible Interview Questions
- "Why does this router orchestrate three separate service calls inline, rather than having a single `rag_service.explain(...)` facade function like other routers delegate to a single call?" (Arguably an inconsistency with the thin-router pattern used elsewhere (`routers/v1.py`, `routers/memory.py`) — worth discussing whether extracting a facade function would improve testability without changing behavior.)
- "What happens to the total request latency if Milvus is completely down when this endpoint is called?" (`milvus/search_vectors.py`'s broad exception handling catches the failure and returns `[]`, which flows through to `\"NO_CONTEXT_AVAILABLE\"` and a short-circuited response — so a Milvus outage actually makes this endpoint *faster*, not slower, since the LLM is never called at all.)
- "Why is `retrieved_documents` in the response just `len(raw_context)` rather than something like total feedback records or behavior data points considered?" (It's counting matched *merchants*, i.e., how many entities the semantic search found — a coarse but simple proxy for 'how much context did we actually have to work with.')
