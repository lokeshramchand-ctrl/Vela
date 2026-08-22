# File: `rag/retriever.py`

## Purpose
Stage 1 of the RAG pipeline: finds semantically relevant merchants and gathers everything the system knows about each one, forming the raw material the rest of the pipeline will ground its explanation in.

## Responsibilities
- Perform a semantic (vector) search to find relevant merchants.
- For each match, fetch its memory profile, behavioral statistics, and recent human feedback.
- Return a clean, structured list ready for prompt formatting.

## Imports
| Import | Used for |
|---|---|
| `logging` | Warning when no semantic matches are found |
| `typing.List, Dict, Any` | Type hints |
| `database.mongo.db` | Structured lookups (`merchant_profiles`, `behavior_patterns`, `feedback`) |
| `milvus.search_vectors.vector_search` | The semantic search step |

## Exports
- **`ContextRetriever`** — the class.
- **`context_retriever`** — the singleton instance, imported by `routers/rag.py`.

## Execution Flow
On import, `context_retriever = ContextRetriever()` runs trivially. Per call, `fetch_grounded_context(...)` runs: one semantic search call, then a loop of up to `top_k` iterations, each doing three sequential (awaited) MongoDB lookups.

## Functions (plain English)

### `ContextRetriever.fetch_grounded_context(self, query_text: str, top_k: int = 3) -> List[Dict[str, Any]]` (async)
In simple English: "Given a piece of transaction text someone wants explained, first find up to 3 merchants whose stored behavioral 'fingerprint' seems semantically similar to this text. If we don't find any matches at all, immediately give up and return an empty list — there's no point continuing if we have nothing to ground an explanation in. Otherwise, for each matching merchant, go gather three separate pieces of information about them: their memory profile (how trusted/well-known they are), their behavioral statistics (typical amounts, timing patterns), and their three most recent pieces of human feedback (corrections or confirmations). If any of these pieces of information don't exist for a given merchant, just use an empty placeholder instead of failing. Also strip out MongoDB's internal ID field from the feedback records, since we don't need it and it can't be easily converted to plain JSON. Package everything about each merchant into one tidy bundle, and return the full list of bundles."

## Classes

### `ContextRetriever`
No instance state — a pure orchestration class with one method.

## Interfaces
The returned list-of-dicts shape (`{merchant_name, profile, behavior, recent_feedback}`) is the contract `rag/context_builder.py`'s `build_prompt_string` expects as its input.

## Hooks
Not applicable.

## Utilities
None — one cohesive method.

## Dependencies
`database.mongo`, `milvus.search_vectors` (internal). No direct third-party dependency.

## Side Effects
- Triggers a real semantic search (embedding + Milvus query, via `vector_search`) — read-only from a data-mutation standpoint, but genuine external I/O.
- Performs up to `top_k × 3` sequential MongoDB read queries.
- Logs a warning if the semantic search returns nothing.

## Performance Considerations
- The `for name in merchant_names:` loop awaits three separate MongoDB queries **sequentially** for each matched merchant, rather than firing them concurrently (e.g., via `asyncio.gather`) — for `top_k=3`, this means up to 9 sequential round trips to MongoDB in the worst case, each adding to total request latency in series rather than in parallel.
- None of the three MongoDB queries per merchant (`merchant_profiles.find_one`, `behavior_patterns.find_one`, `feedback.find(...).sort(...).limit(3)`) are backed by indexes on the fields they filter on (`canonical_name`, `merchant_name`, `prediction`) anywhere in this codebase — each is effectively a collection scan as those collections grow.

## Possible Interview Questions
- "Why does this function loop through matched merchants and await each lookup sequentially, rather than concurrently?" (Simplicity of implementation — sequential awaiting is easier to reason about and debug, at the cost of higher total latency compared to firing all the lookups for all matched merchants concurrently with something like `asyncio.gather`, which would be a natural performance improvement here since none of these lookups depend on each other's results.)
- "Why strip `_id` from the feedback documents specifically, but not from the profile or behavior documents?" (Because those two are fetched with an explicit `{"_id": 0}` projection directly in the `find_one` call, so `_id` is never even returned by MongoDB for them — the feedback query doesn't use that projection, so the manual `f.pop('_id', None)` cleanup step is needed afterward instead.)
- "What happens if the same merchant name is somehow matched twice by the semantic search (e.g., two near-duplicate vectors)?" (Nothing de-duplicates `merchant_names` before the lookup loop — the same merchant's profile/behavior/feedback would simply be fetched and included twice in the resulting context list, and `context_builder.py` would render it as two separate, identical-looking `<MERCHANT_DATA>` blocks.)
- "Why return an empty list rather than raising an exception when no semantic matches are found?" (Consistent with the system's broader philosophy of treating 'no data' as a normal, expected outcome rather than an error — this lets `rag/context_builder.py` cleanly detect the empty case and short-circuit to `\"NO_CONTEXT_AVAILABLE\"`, which in turn lets `rag/generator.py` avoid calling the LLM entirely when there's nothing to ground it with.)
