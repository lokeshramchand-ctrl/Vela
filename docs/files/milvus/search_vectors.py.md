# File: `milvus/search_vectors.py`

## Purpose
The live, actually-used query-time semantic search path — turns a piece of query text into an embedding and finds the most similar stored merchant behavior vectors.

## Responsibilities
- Embed a query string.
- Search the Milvus collection for the closest matches.
- Format the raw Milvus hit objects into clean, simple dicts.
- Degrade gracefully (empty list) on any failure.

## Imports
| Import | Used for |
|---|---|
| `logging` | Error logging |
| `typing.List, Dict, Any` | Type hints |
| `milvus.insert_vectors.vector_store` | The shared Milvus client and collection name |
| `embeddings.generate_embeddings.embedding_generator` | Turning query text into a vector |

## Exports
- **`VectorSearchEngine`** — the class.
- **`vector_search`** — the singleton instance, imported by `rag/retriever.py` — this is the actual, live entry point for semantic search in the running application.

## Execution Flow
On import, `vector_search = VectorSearchEngine()` runs trivially (no constructor logic, so no additional side effects beyond whatever importing `milvus.insert_vectors` and `embeddings.generate_embeddings` already triggers). Per call, `find_similar_behaviors(...)` runs: embed → search → format, all inside one large `try/except`.

## Functions (plain English)

### `VectorSearchEngine.find_similar_behaviors(self, query_text: str, top_k: int = 3) -> List[Dict[str, Any]]` (async)
In simple English: "Take a piece of query text and turn it into a vector using the embedding model. Then ask Milvus: 'which of your stored merchant vectors are most similar to this one?' — asking for the top 3 matches by default. For each match Milvus gives back, pull out just the merchant name, how similar it was (rounded to 4 decimal places), and its ID, and package those into a simple, clean dictionary. If literally anything goes wrong anywhere in this whole process — the embedding call fails, Milvus is unreachable, the search errors out for any reason — don't crash; just log what happened and return an empty list, as if nothing matched at all." This is the one public method, and its all-encompassing `try/except Exception` is a deliberate design choice: any failure anywhere in the semantic-search path degrades to "no results" rather than propagating an exception up to the caller.

## Classes

### `VectorSearchEngine`
No instance state — a pure orchestration class with one method.

## Interfaces
The returned dict shape (`{"merchant_name", "similarity_score", "id"}`) is the implicit contract `rag/retriever.py` relies on.

## Hooks
Not applicable.

## Utilities
None — one cohesive method.

## Dependencies
`milvus.insert_vectors`, `embeddings.generate_embeddings` (internal). No direct third-party dependency (Milvus/httpx usage happens inside the modules it delegates to).

## Side Effects
- Triggers a real network call to Ollama (via `embedding_generator.generate`) and a real query against Milvus — both are read-only from Milvus's perspective (no data is written), but both are genuine external I/O operations with real latency and failure modes.
- Logs a warning on any failure.

## Performance Considerations
- Two sequential network-dependent operations per call (embed, then search) — no way to parallelize them, since the search depends on the embedding's output.
- `search_params={"metric_type": "COSINE", "params": {"ef": 64}}` — the `ef` parameter controls the HNSW search's accuracy/speed trade-off (higher `ef` means more thorough, slower search); `64` is a reasonable middle-ground default, not tuned specifically for this dataset's characteristics.
- The broad `try/except Exception` means a genuinely broken configuration (e.g., wrong collection name, dimension mismatch) looks identical, from the caller's perspective, to "no semantic matches exist" — a debugging cost traded for resilience.

## Possible Interview Questions
- "Why does this function catch every possible exception and return an empty list, rather than letting specific errors propagate?" (Consistent with the broader system's 'Unknown/no-data is a valid, safe answer' philosophy — a failure in semantic search should degrade the RAG pipeline to 'no grounded context available' rather than causing a hard failure of the entire `/v1/explain` request; the trade-off is that genuine bugs and legitimate 'nothing matched' cases become indistinguishable without checking logs.)
- "Is `similarity_score` here literally a similarity, or could it be a distance?" (For Milvus's `COSINE` metric type, the returned `distance` field actually represents similarity — where higher values mean more similar — so this code's naming (`similarity_score = hit.get("distance", ...)`) is technically accurate for this specific metric, though it would be misleading if the metric type were ever changed to something where 'distance' truly means dissimilarity, like Euclidean.)
- "What would you need to change to search based on more than just text — e.g., filtering by a specific merchant category alongside semantic similarity?" (Milvus supports hybrid search combining a vector similarity search with scalar field filters — you'd need to add a filter expression to the `search` call and ensure the relevant scalar field (e.g., a category) is part of the collection schema, which currently only stores `id`, `merchant_name`, and `embedding`.)
- "How would you distinguish a genuine 'no matches' result from a silently swallowed configuration bug, given the current design?" (You'd need to inspect the application logs for the warning this function emits on exception — the API response itself gives no signal that a real error occurred versus a legitimate empty result.)
