# File: `memory/memory_manager.py`

## Purpose
Orchestrates the full lifecycle of a single "entity encounter" — the Phase 4 process that turns a raw mention of a merchant into an updated, persisted trust profile.

## Responsibilities
- Fetch an existing profile, or create a brand-new one.
- Update frequency and alias tracking on repeat encounters.
- Delegate the promotion decision to the state machine.
- Apply the special "wake up from archive" business rule.
- Persist the result.

## Imports
| Import | Used for |
|---|---|
| `datetime.datetime, timezone` | Setting `last_seen` to the current UTC time on repeat encounters |
| `repositories.profile_repository.profile_repo` | All persistence operations |
| `memory.state_machine.state_machine` | The promotion-decision singleton |
| `models.schemas.MerchantProfile, MemoryState` | The profile model and state enum |

## Exports
- **`MemoryManager`** — the class.
- **`memory_manager`** — the singleton instance, imported by `routers/memory.py`.

## Execution Flow
1. On import, `memory_manager = MemoryManager()` runs — trivial, no state, no I/O.
2. Per call, `process_encounter(...)` runs a single linear flow: fetch → branch (new vs. existing) → (if existing) mutate in memory → persist → return.

## Functions (plain English)

### `MemoryManager.process_encounter(self, canonical_name: str, raw_text: str) -> MerchantProfile` (async)
In simple English: "Someone just told us they saw this merchant. First, check if we already have a profile for them. If we've never seen this merchant before, create a brand new profile starting at the lowest trust level (EPHEMERAL) with a frequency of 1, remembering this raw text as its first known alias, and save it. If we *have* seen this merchant before, bump its seen-count up by one, update the 'last seen' timestamp to right now, and if this particular wording is new, add it to the list of known aliases. Then ask the state machine whether this merchant has now earned a promotion to a higher trust level. There's one special case: if the merchant had previously been marked as ARCHIVED (forgotten due to inactivity), seeing it again means it's relevant again — so instead of trusting whatever the state machine says, force it directly back to TEMPORARY. Otherwise, just use whatever the state machine decided. Finally, save all these changes and hand back the updated profile." This is the only public method on this class.

## Classes

### `MemoryManager`
No instance attributes, no constructor logic beyond the implicit default — a pure orchestration class with one method.

## Interfaces
`MerchantProfile` is both the input shape (implicitly, via what's fetched/constructed) and the output/return type — a consistent contract throughout.

## Hooks
Not applicable.

## Utilities
None — the whole class is one cohesive orchestration method, with no smaller helper functions.

## Dependencies
`datetime` (standard library); `repositories.profile_repository`, `memory.state_machine`, `models.schemas` (internal).

## Side Effects
- Reads from and writes to MongoDB (via `profile_repo`) — every call either inserts a new document or updates an existing one; there are no side-effect-free calls to this function.
- Mutates the in-memory `profile` object's attributes (`frequency`, `last_seen`, `aliases`, `memory_state`) before persisting — a local mutation, not a global one.

## Performance Considerations
- Every call does exactly one read (`get_profile`) followed by exactly one write (`create_profile` or `update_profile`) — a classic read-modify-write pattern with no optimistic concurrency control (no version field, no compare-and-swap), meaning two simultaneous encounters for the same merchant could race, with the second write silently overwriting fields set by the first (e.g., one increment to `frequency` could be lost).
- `state_machine.evaluate_promotion` is a pure, synchronous, in-memory function call — adds no meaningful latency compared to the two database round trips, which dominate this function's total cost.

## Possible Interview Questions
- "Walk through exactly what happens if two requests for the same brand-new merchant name arrive at almost the same instant." (Both could see 'not found' from `get_profile`, both construct a fresh `MerchantProfile(frequency=1, ...)`, and both call `create_profile` — resulting in either a duplicate document (if `canonical_name` isn't a unique index in MongoDB, which it isn't here) or a race condition depending on timing; there's no locking or upsert-based deduplication here.)
- "Why does `process_encounter` explicitly override the state machine's output only for the `ARCHIVED` case, rather than letting `evaluate_promotion` handle every transition uniformly?" (Because `evaluate_promotion` deliberately treats `ARCHIVED` as sticky/terminal on its own — it never promotes an archived profile out of that state by design. The override in this function represents a distinct business rule: 'being seen again means relevance has returned,' which isn't really a frequency-based *promotion* at all, so it makes sense to model it separately rather than folding it into the state machine's core logic.)
- "Does `frequency` get reset when a profile becomes `ARCHIVED` and is later reactivated?" (No — `frequency` keeps accumulating indefinitely across archival/reactivation cycles, meaning a reactivated profile with a high historical frequency could very quickly re-qualify for `PERMANENT` on its very next encounter, bypassing the `TEMPORARY` waiting period the reactivation override just placed it in.)
- "How would you add a check to prevent two concurrent encounters from corrupting frequency counts?" (Use an atomic MongoDB update like `$inc` on `frequency` directly in the database, rather than the current read-into-Python, increment-in-memory, write-back-out pattern — that would make the increment itself atomic even without application-level locking.)
