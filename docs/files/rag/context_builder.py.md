# File: `rag/context_builder.py`

## Purpose
Stage 2 of the RAG pipeline: converts the raw, structured context gathered by the retriever into a clearly-delimited text block designed to keep the LLM from hallucinating outside the provided data.

## Responsibilities
- Format each matched merchant's data as an unambiguous, pseudo-XML block.
- Signal explicitly when there's no context at all to work with.

## Imports
| Import | Used for |
|---|---|
| `typing.List, Dict, Any` | Type hints |

## Exports
- **`ContextBuilder`** — the class.
- **`context_builder`** — the singleton instance, imported by `routers/rag.py`.

## Execution Flow
On import, `context_builder = ContextBuilder()` runs trivially (no constructor, no state). Called once per `/v1/explain` request, purely synchronously — no I/O, no `await`.

## Functions (plain English)

### `ContextBuilder.build_prompt_string(context_data: List[Dict[str, Any]]) -> str` (static method)
In simple English: "Take the list of merchant information bundles gathered earlier and turn it into one big block of clearly-labeled text, ready to hand to a language model. For each merchant, write out its name, how trusted it currently is, how many times it's been seen, its typical spending amount, how predictable its timing pattern is, its usual hour of day, and how many times a human has corrected predictions about it — all wrapped in clear tags like `<NAME>` and `<BEHAVIOR_SIGNATURE>` so there's no ambiguity about what each piece of information means. If we were given absolutely no merchant data at all (an empty list), don't try to build an empty or confusing block — just return a special marker string, `'NO_CONTEXT_AVAILABLE'`, so whoever calls this function next knows immediately that there's genuinely nothing to work with." Missing sub-fields (e.g., a merchant with no behavior data) are handled gracefully via `.get(..., default)` calls, substituting sensible placeholders like `'UNKNOWN'`, `0`, or `'N/A'` rather than raising an error.

## Classes

### `ContextBuilder`
No instance state — the one method is a `@staticmethod`, so the class exists purely as an organizational namespace.

## Interfaces
The output string format (the pseudo-XML `<MERCHANT_DATA>` blocks, or the sentinel `"NO_CONTEXT_AVAILABLE"`) is the contract `rag/generator.py` depends on — specifically checking for that exact sentinel string to decide whether to skip calling the LLM entirely.

## Hooks
Not applicable.

## Utilities
The one method is itself best understood as a formatting utility.

## Dependencies
`typing` (standard library, for hints only). No internal or third-party dependencies beyond that.

## Side Effects
None — pure string formatting, no I/O, no logging, no mutation.

## Performance Considerations
Trivial — string formatting over at most `top_k` (typically 3) items; effectively free regardless of call frequency.

## Possible Interview Questions
- "Why format the context as pseudo-XML rather than just passing the raw JSON/dict data straight into the prompt?" (Clear, unambiguous delimiters like `<NAME>` and `<BEHAVIOR_SIGNATURE>` are believed to help keep a language model 'on rails' by making it visually and structurally obvious what's data versus what's instruction — a common, if not rigorously proven in this specific codebase, prompt-engineering technique.)
- "Why does `<HUMAN_CORRECTIONS>` only report a count of feedback records rather than their actual content?" (A deliberate (or at least effective) limitation — the model can know 'this merchant has been corrected N times before' but can't reference *what* those corrections actually said, which constrains how specifically it can incorporate past correction history into its explanation. A natural follow-up: how would you change this to include the actual correction details?)
- "Why return the specific sentinel string `'NO_CONTEXT_AVAILABLE'` instead of, say, an empty string or `None`?" (A distinctive, unambiguous, hard-to-confuse-with-real-data string that `rag/generator.py` can reliably check for with an exact string comparison — an empty string or `None` could theoretically be confused with other edge cases or accidentally match unrelated falsy checks.)
- "What happens if `context_data` contains a merchant with a `profile` field that's `None` rather than an empty dict `{}`?" (This would break — `profile.get('memory_state', 'UNKNOWN')` assumes `profile` is at least a dict; calling `.get()` on `None` raises `AttributeError`. Looking at `rag/retriever.py`, it always supplies `{}` rather than `None` for missing profile/behavior data, so this edge case doesn't currently occur in practice, but it's a latent fragility if a future caller passed `None` instead.)
