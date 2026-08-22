# File: `rag/generator.py`

## Purpose
Stage 3 of the RAG pipeline: calls the LLM with a strict, hallucination-resistant system prompt and parses its structured JSON response.

## Responsibilities
- Define the system prompt enforcing grounded, non-conversational, strictly-JSON output.
- Short-circuit without calling the LLM when there's no context to ground it in.
- Make the actual Ollama generation call and parse the result.
- Convert any failure into a safe, generic error response rather than propagating an exception.

## Imports
| Import | Used for |
|---|---|
| `httpx` | Async HTTP client for the Ollama call |
| `logging` | Error logging |
| `json` | Parsing the LLM's JSON-formatted response string |
| `typing.Dict, Any` | Type hints |
| `core.ollama_client.OLLAMA_HOST, LLM_MODEL` | The resolved Ollama base URL and generation model name |

## Exports
- **`ExplanationGenerator`** — the class.
- **`explanation_generator`** — the singleton instance, imported by `routers/rag.py`.

## Execution Flow
On import, `explanation_generator = ExplanationGenerator()` runs — its constructor builds `self.api_url` and defines `self.system_prompt`, both fixed for the process's lifetime. Per call, `generate_explanation(...)` either short-circuits immediately (no context) or makes one real, awaited HTTP call to Ollama.

## Functions (plain English)

### `ExplanationGenerator.__init__(self)`
In simple English: "Set up the exact web address for Ollama's text-generation endpoint, and write out, once, the strict rulebook we'll hand to the language model every single time we ask it something: don't act like a chatbot, don't make things up if the data doesn't support an answer, and always respond in one specific JSON format."

### `ExplanationGenerator.generate_explanation(self, query: str, context_string: str) -> Dict[str, Any]` (async)
In simple English: "If the context we were given is literally the special 'no data available' marker, don't even bother calling the language model — just immediately say we have no historical data to explain this with. Otherwise, combine the context and the user's actual question into one full prompt, and send it to Ollama along with our strict rulebook, explicitly telling Ollama to force its output into valid JSON format (a feature Ollama itself enforces, not just something we're asking nicely for). Wait up to 30 seconds for a response. If we get one back successfully, the language model's actual answer comes back as a JSON string inside Ollama's response — parse that string into a real Python dictionary and hand it back. If literally anything goes wrong anywhere in this process — a network failure, a timeout, the model returning something that isn't valid JSON after all — don't crash; log what happened and return a generic 'something went wrong internally' error message instead."

## Classes

### `ExplanationGenerator`
Instance attributes: `self.api_url` (string, built once), `self.system_prompt` (a long fixed instruction string, defined once).

## Interfaces
The system prompt itself defines an output-format contract the LLM is instructed to follow: `{"explanation": str, "confidence_in_explanation": "HIGH|MEDIUM|LOW", "primary_data_source": str}` (or an error object). Nothing in this file *validates* that the parsed response actually matches this shape — it trusts the model (backed by Ollama's `format: "json"` decoding constraint) to comply.

## Hooks
Not applicable.

## Utilities
None beyond the one method.

## Dependencies
`httpx` (third-party); `core.ollama_client` (internal, itself depending on `core.config`); `json` (standard library).

## Side Effects
- Makes a real network call to an Ollama LLM server — the most expensive, highest-latency operation in the entire application.
- Logs on any failure.

## Performance Considerations
- 30-second timeout — the longest timeout anywhere in the codebase, reflecting that text generation is typically much slower than embedding generation (15s) or simple database queries.
- No streaming: `"stream": False` means the entire response is generated server-side before anything is returned to this function — for a slow model or long output, this means the caller waits for the *complete* answer rather than seeing partial output incrementally, which is simpler to handle but produces a worse perceived-latency experience for an end user watching a spinner.
- No retry logic on transient failures — a single network hiccup or timeout results in the generic error response immediately, with no automatic retry attempt.
- No caching — an identical `(query, context_string)` pair would trigger a full new LLM call every time, even if asked moments apart.

## Possible Interview Questions
- "Why check for the exact string `'NO_CONTEXT_AVAILABLE'` before doing anything else in this function?" (It's the cheapest possible way to avoid an expensive, slow, and pointless LLM call when we already know from the previous pipeline stage that there's no real data to ground an answer in — calling the LLM anyway would either produce a low-value generic response or risk it hallucinating something not actually grounded in real data.)
- "This function's system prompt instructs the model not to hallucinate, and `format: 'json'` forces valid JSON syntax. Does that guarantee the *content* of the response is trustworthy?" (No — `format: 'json'` only guarantees syntactically valid JSON, not that the JSON's actual claims are true or well-grounded; the system prompt's instructions are a strong nudge but not a hard technical guarantee the way JSON-mode is for syntax. The real grounding guarantee comes from the earlier pipeline stages only ever providing real retrieved data as context in the first place.)
- "What happens if Ollama returns a syntactically valid JSON response, but with different keys than the ones specified in the system prompt (e.g., missing `confidence_in_explanation`)?" (Nothing in this function validates the parsed dict's shape — it would be returned to the client exactly as received, potentially missing expected fields; there's no schema validation layer on the LLM's output here.)
- "Why is the timeout here (30s) longer than the embedding timeout (15s) in `embeddings/generate_embeddings.py`?" (Text generation, especially producing a structured multi-field JSON explanation, is generally a slower operation for an LLM than producing a fixed-size embedding vector — the longer timeout reflects that realistic expectation, though neither value appears to be based on measured latency data from this specific system.)
