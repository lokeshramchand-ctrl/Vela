# File: `models/schemas.py`

## Purpose
The single shared vocabulary of the entire system — every Pydantic model, enum, and request/response contract used across routers, engines, and services.

## Responsibilities
- Define the base model configuration inherited by all other models.
- Define domain entities (`Merchant`, `Category`, `Transaction`, `Feedback`, `MerchantProfile`, `BehaviorPattern`).
- Define API request/response contracts (`CategorizeRequest`, `CategorizeResponse`, `ResolutionResult`, `ConfidenceEvaluation`).
- Define closed vocabularies (`MemoryState`, `TransactionCategory`).

## Imports
| Import | Used for |
|---|---|
| `pydantic.BaseModel, Field, ConfigDict` | Model base class, field customization (aliases, defaults), model-wide config |
| `typing.Optional, List, Dict` | Type hints for optional/collection fields |
| `datetime.datetime, timezone, timedelta` | Timestamp fields and default-now factories (`timedelta` is imported but unused anywhere in this file) |
| `enum.Enum` | Base class for `MemoryState` and `TransactionCategory` |

## Exports
Every class and enum in the file is a public export: `CoreModel`, `Merchant`, `Category`, `Transaction`, `Feedback`, `CategorizeRequest`, `CategorizeResponse`, `ResolutionResult`, `MemoryState`, `MerchantProfile`, `TransactionCategory`, `ConfidenceEvaluation`, `BehaviorPattern`.

## Execution Flow
Pure declarations — importing this module runs no logic beyond defining classes and enums. There is no instantiation, no I/O, and no validation performed at import time (validation happens per-instance, whenever some other code constructs, e.g., `MerchantProfile(**data)`).

## Functions (plain English)
This file contains **no standalone functions** — only class/field declarations and `Field(default_factory=lambda: ...)` inline lambdas, which aren't named functions but are worth explaining individually since they run logic:

### The `default_factory=lambda: datetime.now(timezone.utc)` lambdas (appear on `Merchant.created_at`, `Transaction.timestamp`, `Feedback.timestamp`, `MerchantProfile.first_seen`/`last_seen`, `BehaviorPattern.last_updated`)
In simple English: "If nobody explicitly provides a value for this timestamp field when creating the object, automatically fill it in with the current date and time (in UTC)." Each of these runs fresh every time a new object without that field is constructed — they are not evaluated once and cached.

## Classes

### `CoreModel(BaseModel)`
The shared base class. `model_config = ConfigDict(populate_by_name=True, arbitrary_types_allowed=True)` — this means a field declared with `Field(alias="_id")` can be populated using *either* the alias (`_id`) *or* the Python attribute name (`id`), which matters for round-tripping MongoDB documents (which use `_id`) into Python-friendly objects.

### `Merchant(CoreModel)`
Fields: `id` (aliased from `_id`), `name`, `aliases` (list, defaults empty), `created_at` (defaults to now). In simple English: "A record describing one merchant by its display name and any alternate spellings it's known by." Note: doesn't match the actual shape of documents in the `merchants` collection (which use `canonical_name`, not `name`) — see `docs/16-known-issues-tech-debt.md`.

### `Category(CoreModel)`
Fields: `id`, `name`, `description` (optional). In simple English: "A named spending category with an optional human-readable description." Never actually used by any other file in the codebase.

### `Transaction(CoreModel)`
Fields: `id` (optional), `raw_text`, `merchant` (optional), `amount`, `category` (optional), `source`, `timestamp` (defaults to now). In simple English: "One financial transaction — what the original text said, how much it was for, who it was with (once resolved), and what category it falls into."

### `Feedback(CoreModel)`
Fields: `id` (optional), `transaction_id`, `prediction`, `corrected_category`, `confidence`, `timestamp` (defaults to now). In simple English: "A record of what the system originally predicted for a transaction, and what a human said it should actually have been."

### `CategorizeRequest(BaseModel)`
Field: `text` (required, with a description). In simple English: "The shape of the JSON body someone must send to categorize a transaction: just the raw text."

### `CategorizeResponse(BaseModel)`
Fields: `merchant`, `category`, `confidence`. In simple English: "The shape of the answer you get back after categorization: who it was, what category, and how sure the system is."

### `ResolutionResult(BaseModel)`
Fields: `raw_text`, `cleaned_text`, `canonical_merchant`, `confidence`, `is_resolved`, `resolution_method` (documented as one of `exact_alias, substring, rule_engine, or none`). In simple English: "The full story of how a noisy piece of bank text got turned into a clean merchant name — the original text, the cleaned-up version, the merchant name we landed on, how confident we are, whether we actually found a match, and which method found it."

### `MemoryState(str, Enum)`
Members: `EPHEMERAL`, `TEMPORARY`, `PERMANENT`, `ARCHIVED`. In simple English: "The four possible trust levels an entity can have in the memory system, from 'just seen once' to 'well-established' to 'forgotten due to inactivity.'"

### `MerchantProfile(BaseModel)`
Fields: `id` (optional), `canonical_name`, `display_name` (optional), `aliases` (list), `entity_type` (defaults `"Unknown"`), `memory_state` (defaults `EPHEMERAL`), `frequency` (defaults `1`), `first_seen`/`last_seen` (default now), `notes` (optional), `confidence` (defaults `0.0`), `category`/`subcategory` (optional). In simple English: "Everything the system currently believes about one specific merchant entity: its name and known aliases, how trustworthy it's considered, how many times it's been seen, and when it was first and last encountered." Note: extends `BaseModel` directly, not `CoreModel` — meaning it doesn't inherit the `populate_by_name`/`arbitrary_types_allowed` config (though it re-declares its own `id: Optional[str] = Field(alias="_id", ...)`, so alias behavior still works for that one field via Pydantic's normal alias support — it just doesn't get the `arbitrary_types_allowed` behavior `CoreModel`-based classes get, which isn't needed here anyway since no field uses a non-Pydantic type).

### `TransactionCategory(str, Enum)`
Members: `FOOD`, `TRAVEL`, `ENTERTAINMENT`, `BILLS`, `FRIENDS`, `EDUCATION`, `HEALTHCARE`, `UNKNOWN` (values: `"Food"`, `"Travel"`, etc.). In simple English: "The complete, fixed list of categories the confidence engine is allowed to trust — anything outside this list gets treated as invalid." Notably does not include `Subscription`, `Shopping`, or `Utility`, which other parts of the system (rule engine, mock seeder) do produce.

### `ConfidenceEvaluation(BaseModel)`
Fields: `raw_category`, `final_category` (a `TransactionCategory`), `confidence`, `is_hallucination_risk`, `calibration_applied`. In simple English: "The verdict from the confidence wall: what was originally predicted, what category we're actually going to trust, how confident we are, whether this looked like a risky/hallucinated guess, and what calibration method (if any) was applied."

### `BehaviorPattern(BaseModel)`
Fields: `id` (optional), `merchant_name`, `avg_amount`/`median_amount`/`variance`/`std_dev` (amount stats), `preferred_hour`, `time_bucket_distribution` (dict), `weekday_distribution` (list of 7), `daily_frequency`/`weekly_frequency`, `periodicity_score`, `entropy_score`, `last_updated` (defaults now). In simple English: "A complete statistical fingerprint of how one merchant behaves over time — how much they typically charge, when during the day/week they show up, how often, and how predictable that pattern is."

## Interfaces
Every model in this file functions as a data-contract "interface" in the loose sense — a fixed shape that producers and consumers agree to. There is no formal `Protocol`/`ABC` usage.

## Hooks
Not applicable.

## Utilities
None beyond the inline `default_factory` lambdas described above.

## Dependencies
`pydantic` (third-party) and Python standard library (`typing`, `datetime`, `enum`) only. Zero internal dependencies.

## Side Effects
None at import time. At instantiation time, Pydantic validation can raise `ValidationError` if required fields are missing or types don't match — this is the only "side effect," and it's a normal, expected part of using Pydantic.

## Performance Considerations
Negligible — Pydantic model instantiation/validation is fast, and there's no per-request overhead beyond what any Pydantic-based FastAPI app already pays for request/response serialization.

## Possible Interview Questions
- "Why does `MerchantProfile` extend `BaseModel` directly instead of `CoreModel` like most other models in this file?" (Likely an oversight/inconsistency rather than a deliberate choice — worth checking whether `arbitrary_types_allowed` is ever actually needed for this model (it isn't, since all its fields are standard types), which is probably why the inconsistency has never caused a visible bug.)
- "Why is `timedelta` imported but never used anywhere in this file?" (Dead import — likely left over from an earlier version of the file where it was used, e.g., for a decay-related default; a linter would flag this.)
- "What's the practical difference between `Optional[str] = Field(alias='_id', default=None)` and just `id: str | None = None`?" (The `alias='_id'` part is what lets this field be populated from a MongoDB document's `_id` key while still being addressed as `.id` in Python code — without it, you'd need to manually rename the key before constructing the model.)
- "If you added a new `TransactionCategory` member, what else in the codebase would need to change to keep everything consistent?" (Nothing structurally — but you'd want to check `merchant_aliases.json`'s category strings and any rule-engine outputs to make sure they align with the enum, since a mismatch causes silent rejection in `engines/confidence_engine.py`.)
