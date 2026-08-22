# File: `embeddings/vectorizer.py`

## Purpose
Converts structured domain objects (`MerchantProfile`, `BehaviorPattern`) into natural-language sentences suitable for feeding to an embedding model — the "what do we actually say about this entity" step of the Phase 7 pipeline.

## Responsibilities
- Produce a descriptive sentence summarizing a merchant's identity.
- Produce a descriptive sentence summarizing a merchant's behavioral fingerprint.

## Imports
| Import | Used for |
|---|---|
| `models.schemas.MerchantProfile, BehaviorPattern` | The input types being stringified |

## Exports
- **`SemanticVectorizer`** — the class.
- **`vectorizer`** — the singleton instance. **Not imported anywhere else in the codebase** — this file is fully implemented but currently unreachable from any live code path.

## Execution Flow
Pure, stateless — importing this file does nothing beyond defining the class. Each method call is independent and side-effect-free.

## Functions (plain English)

### `SemanticVectorizer.stringify_profile(profile: MerchantProfile) -> str` (static method)
In simple English: "Take a merchant's profile data and write it out as a plain English sentence describing who they are: their name, all the alternate spellings/aliases we know for them, how trusted they currently are (their memory state), how many times we've seen them, and what type of entity they are." Example output: `"Entity: Swiggy. Known aliases include: BUNDL, SWIGGY. Memory State: PERMANENT. Transaction Frequency: Seen 14 times. Type: Business."`

### `SemanticVectorizer.stringify_behavior(pattern: BehaviorPattern) -> str` (static method)
In simple English: "Take a merchant's computed behavioral statistics and write them out as a plain English sentence: their typical spend amount and how much it varies, what time of day they're usually visited, how often per week, and how predictable/regular their visit pattern is." Example output: `"Behavior footprint for Swiggy: Average transaction amount is 412.30 with a standard deviation of 88.10. Preferred time of day is 20:00. Weekly transaction frequency is 3.20. Periodicity score is 0.22 (1.0 means highly predictable)."`

## Classes

### `SemanticVectorizer`
No instance state — both methods are `@staticmethod`s, meaning the class exists purely as a namespace for grouping these two related functions; it could equally have been two standalone module-level functions.

## Interfaces
Not applicable formally — the two methods' string-template outputs function as an informal "prompt contract" for whatever embedding model eventually consumes them, though nothing in the current codebase actually calls either method.

## Hooks
Not applicable.

## Utilities
Both methods are, in effect, utility/formatting functions.

## Dependencies
`models.schemas` (internal) only. No third-party dependencies, no I/O.

## Side Effects
None — pure string formatting with no side effects whatsoever.

## Performance Considerations
Trivial — simple f-string interpolation, effectively free regardless of call volume.

## Possible Interview Questions
- "This file is fully implemented and bug-free, but nothing calls it. How would you verify that, and what would you build to actually use it?" (Grep for `stringify_profile`/`stringify_behavior`/`vectorizer` across the repo and find zero other references. To use it, you'd need an orchestrating job that iterates `merchant_profiles`/`behavior_patterns` documents, calls these methods, feeds the resulting strings to `embeddings/generate_embeddings.py`, and stores the resulting vectors via `milvus/insert_vectors.py` — none of which exists as a script or scheduled task today.)
- "Why generate a natural-language sentence rather than embedding raw JSON or a simple key-value string?" (Embedding models are trained predominantly on natural language; a well-formed descriptive sentence tends to produce a more semantically meaningful vector than serialized structured data, which introduces syntactic noise unrelated to actual meaning.)
- "Why are both methods `@staticmethod`s rather than instance methods or standalone functions?" (Grouping them under one class provides a small amount of namespacing/organization without needing any actual instance state — a matter of style; standalone module-level functions would work identically.)
- "If you wanted to make these templates configurable (e.g., different wording for different entity types), how would you change this design?" (You'd likely need to move from hardcoded f-string templates to a templating system or per-entity-type template selection logic — a meaningfully larger change than the current fixed-format approach.)
