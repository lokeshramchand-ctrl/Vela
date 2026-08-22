# File: `services/merchant_resolver.py`

## Purpose
The Phase 3 database-backed, noise-tolerant merchant resolver — turns messy bank/UPI transaction text into a canonical merchant name via cleaning plus a two-tier MongoDB lookup.

## Responsibilities
- Strip banking-specific noise (UPI/IMPS/NEFT/RTGS/INB tokens, reference numbers, UPI handles, punctuation) from raw text.
- Attempt an exact alias match in MongoDB.
- Fall back to a per-word substring match.
- Return a graded confidence result, never raising on "no match."

## Imports
| Import | Used for |
|---|---|
| `re` | Building the noise-stripping and special-character regexes |
| `logging` | Used only to create `logger = logging.getLogger(__name__)` at module level — the `logger` object itself is never actually called anywhere in this file, so no log line is ever emitted by this module |
| `typing.Optional` | Imported but never referenced anywhere in the file — a fully dead import |
| `database.mongo.db` | Querying the `merchants` collection |
| `models.schemas.ResolutionResult` | The output contract |

## Exports
- **`MerchantResolver`** — the class.
- **`merchant_resolver`** — the singleton instance, imported by `routers/v1.py`.

## Execution Flow
1. On import, `merchant_resolver = MerchantResolver()` runs — `__init__` compiles two regexes (`noise_regex`, `special_chars_regex`) once, no I/O.
2. Per call, `resolve(raw_text)` runs `clean_text` synchronously (no I/O), then performs up to `1 + (number of qualifying words)` MongoDB queries, awaiting each in sequence.

## Functions (plain English)

### `MerchantResolver.__init__(self)`
In simple English: "Set up two reusable text-cleaning patterns when this resolver is created: one that recognizes common Indian banking noise (like 'UPI', 'NEFT', long reference numbers, or '@paytm'-style handles), and one that recognizes any leftover punctuation or symbols we'd want to strip out."

### `MerchantResolver.clean_text(self, raw_text: str) -> str`
In simple English: "Take a messy piece of bank text and tidy it up in three steps: first, remove all the banking jargon and reference numbers; second, remove anything that isn't a letter, number, or space; third, squeeze multiple spaces down to one and make everything uppercase, so that comparisons don't have to worry about case differences." The result is a clean, standardized string ready for comparison.

### `MerchantResolver.resolve(self, raw_text: str) -> ResolutionResult` (async)
In simple English: "First, clean up the raw text. Then check if the cleaned text is an exact match for any merchant's known alias in our database — if so, we're very confident (99%) and we're done. If not, go word by word through the cleaned text (skipping short words like 'LTD' or 'PVT' that are too generic to be useful), and for each word, check if any merchant's alias *starts with* that word — if we find one, we're moderately confident (75%). If we've tried every meaningful word and found nothing at all, admit defeat and return 'Unknown' with zero confidence — never throw an error, just honestly report that we couldn't resolve it."

## Classes

### `MerchantResolver`
Instance attributes: `self.noise_patterns` (list of regex-pattern strings), `self.noise_regex` (one compiled combined pattern), `self.special_chars_regex` (compiled pattern). No inheritance beyond `object`.

## Interfaces
`ResolutionResult` (from `models/schemas.py`) is the output contract every call to `resolve()` returns.

## Hooks
Not applicable.

## Utilities
`clean_text` is a genuinely reusable utility method — it's public (no underscore) and could sensibly be called independently of `resolve()` by any future code needing just the text-normalization step.

## Dependencies
`re`, `logging` (standard library); `database.mongo`, `models.schemas` (internal). Note: a module-level `logger` is created via `logging.getLogger(__name__)` but is never actually called anywhere in the file (so this module produces zero log output at runtime), and `typing.Optional` is imported but never referenced at all — both are effectively dead.

## Side Effects
- Issues real, read-only MongoDB queries (`find_one`) against the `merchants` collection — up to several per call in the worst case (no match found, long input text).
- No writes, no mutation of shared state.

## Performance Considerations
- The substring-matching fallback issues one `find_one` query per qualifying word (≥4 characters) until a match is found or the words are exhausted — for a long, unmatched input string, this could mean several sequential round trips to MongoDB per request.
- The `$regex: "^word"` query has no supporting index on the `aliases` array field anywhere in this codebase, meaning each such query is a collection scan under the hood — this scales poorly as the `merchants` collection grows, a limitation the code's own comments acknowledge ("In production with millions of rows, text-indexing or Milvus... handles this faster").
- `clean_text` itself is cheap (a few regex substitutions on typically short strings) — the performance cost here is entirely in the database round trips, not the text processing.

## Possible Interview Questions
- "Why skip words shorter than 4 characters in the substring-match loop?" (To avoid matching common short corporate-suffix noise like 'LTD', 'PVT', or 'INC' against unrelated merchants' aliases purely by coincidence.)
- "This function performs sequential `await`s inside a `for` loop rather than firing all the queries concurrently. What's the trade-off?" (Sequential awaiting means the function can short-circuit as soon as any word matches, avoiding unnecessary queries — firing them all concurrently with `asyncio.gather` would use more database load upfront in exchange for potentially lower total latency; whether that trade-off is worth it depends on typical database load and text length.)
- "Why does `resolve()` never raise an exception, even when nothing at all is found?" (Consistent with the app's broader 'Unknown is a valid answer' philosophy — a failed resolution is an expected, normal outcome, not an error condition, so it's represented as a data value (`is_resolved: False`) rather than an exception.)
- "This file creates a `logger` but never calls it. What's the impact, and how would you find this without being told?" (No functional impact — a linter (e.g., `flake8`/`pylint`) would flag the unused `logger` variable and the unused `Optional` import; grepping the file for `logger\.` and finding zero matches is how you'd confirm it by hand. Likely remnants of earlier code that included logging/optional-typed error handling that was later removed without cleaning up the imports.)
