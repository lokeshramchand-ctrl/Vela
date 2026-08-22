# File: `embeddings/generate_embeddings.py`

## Purpose
The thin HTTP client responsible for turning a piece of text into a numeric vector by calling Ollama's embeddings API.

## Responsibilities
- Build the Ollama embeddings API URL once, from the resolved host.
- POST text to that endpoint and return the resulting vector.
- Propagate failures rather than silently swallowing them.

## Imports
| Import | Used for |
|---|---|
| `httpx` | Async HTTP client |
| `logging` | Error logging on HTTP failure |
| `typing.List` | Type hint for the return value |
| `core.ollama_client.OLLAMA_HOST, EMBED_MODEL` | The resolved Ollama base URL and embedding model name |

## Exports
- **`EmbeddingGenerator`** — the class.
- **`embedding_generator`** — the singleton instance, imported by `milvus/search_vectors.py`.

## Execution Flow
1. On import, `embedding_generator = EmbeddingGenerator()` runs — its constructor reads `OLLAMA_HOST` (already resolved at *its* import time inside `core.ollama_client`) and builds `self.api_url` once.
2. Per call, `generate(text)` makes one real, awaited HTTP POST request and returns the parsed result.

## Functions (plain English)

### `EmbeddingGenerator.__init__(self)`
In simple English: "Remember the exact web address we'll be sending embedding requests to, built once from the Ollama server address the app already figured out at startup."

### `EmbeddingGenerator.generate(self, text: str) -> List[float]` (async)
In simple English: "Send this piece of text to the Ollama server and ask it to convert it into a list of numbers (a vector) that captures its meaning. Wait up to 15 seconds for a response. If everything goes well, hand back that list of numbers. If anything goes wrong with the request — the server's down, it times out, it returns an error — log what happened and then let the error propagate up to whoever called this function, rather than pretending everything's fine."

## Classes

### `EmbeddingGenerator`
Instance attribute: `self.api_url` (a string, set once in `__init__`).

## Interfaces
Not applicable formally — `generate(text: str) -> List[float]` is a simple, predictable async function contract.

## Hooks
Not applicable.

## Utilities
None beyond the one method.

## Dependencies
`httpx` (third-party); `core.ollama_client` (internal, itself depending on `core.config`).

## Side Effects
- Makes a real network call to an external Ollama server on every invocation — the only, but significant, side effect in this file.
- Logs on failure.

## Performance Considerations
- 15-second timeout per call — shorter than the 30-second timeout used for the (typically slower) generation call in `rag/generator.py`, reflecting that embedding is usually a faster operation than full text generation.
- No caching: calling `generate` twice with identical text makes two full network round trips — there's no memoization, even for repeated identical queries (which could plausibly happen for common transaction-text patterns).
- No retry logic — a single transient network hiccup causes the whole call to fail and propagate, with no automatic retry attempt.

## Possible Interview Questions
- "Why does this function re-raise the exception after logging it, rather than returning `None` or an empty list on failure?" (Failing loudly means the caller — `milvus/search_vectors.py` — is forced to explicitly handle the failure case, which it does via its own broad `try/except`, degrading to an empty result list at that higher layer instead of silently returning a meaningless zero-vector here.)
- "Why is `self.api_url` computed once in `__init__` rather than freshly on every `generate` call?" (`OLLAMA_HOST` is a fixed constant for the lifetime of the process (resolved once at `core.ollama_client` import time), so recomputing the URL string on every call would be wasted work — though this also means if `OLLAMA_HOST` could theoretically change at runtime, this cached URL would go stale.)
- "How would you add retry-with-backoff behavior to this function without changing its external contract?" (Wrap the `client.post` call in a retry loop (or use a library like `tenacity`) that catches `httpx.HTTPError`, waits, and retries up to some limit before finally re-raising — the function's signature and return type wouldn't need to change.)
- "Why use `async with httpx.AsyncClient() as client` instead of a single shared client instance reused across calls?" (Creating a new client per call is simpler and avoids potential connection-state issues across concurrent requests, but it does mean each call pays the (small) overhead of setting up a new client rather than reusing an existing connection pool — a common trade-off worth discussing for a high-throughput service.)
