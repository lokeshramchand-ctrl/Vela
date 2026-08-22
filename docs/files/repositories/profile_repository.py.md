# File: `repositories/profile_repository.py`

## Purpose
The persistence layer (Repository pattern) for `MerchantProfile` documents — the only place in the codebase that translates between the Pydantic model and raw MongoDB documents in `merchant_profiles`.

## Responsibilities
- Fetch a profile by canonical name.
- Create a new profile.
- Update an existing profile, protecting immutable fields.
- Fetch all profiles stale enough to be archived.

## Imports
| Import | Used for |
|---|---|
| `logging` | Declared but never actually used to log anything in this file (no `logger` variable is even created) |
| `database.mongo.db` | The `merchant_profiles` collection handle |
| `models.schemas.MerchantProfile, MemoryState` | The model being persisted and the enum used in the staleness filter |

**⚠ Critical defect**: this file uses `Optional[MerchantProfile]` as a return-type annotation on `get_profile` but never imports `Optional` from `typing` anywhere — there is no `from typing import Optional` and no `from __future__ import annotations` in this file. Since Python evaluates function annotations eagerly at `def`-statement execution time (not lazily, without that future import), **this raises `NameError: name 'Optional' is not defined` the instant this module is imported** — before `ProfileRepository` can even be fully defined, let alone instantiated. See `docs/16-known-issues-tech-debt.md` for the full blast-radius analysis.

## Exports
- **`ProfileRepository`** — the class (though, per the defect above, the module currently cannot be imported at all, so this export is presently unreachable).
- **`profile_repo`** — the intended singleton instance, imported by `memory/memory_manager.py`, `memory/decay_engine.py`, and `routers/memory.py`.

## Execution Flow
Intended: on import, `profile_repo = ProfileRepository()` runs trivially (no constructor logic). Each method is called independently, per request, doing exactly one MongoDB operation each. **Actual**: the module fails at import time before reaching the `profile_repo = ProfileRepository()` line, due to the `NameError` described above.

## Functions (plain English)

### `ProfileRepository.get_profile(self, canonical_name: str) -> Optional[MerchantProfile]` (async)
In simple English: "Look up a merchant profile by its canonical name, but don't bother returning its raw MongoDB ID field. If we found a matching document, build a `MerchantProfile` object out of it and hand that back. If nothing matched, just say `None` — no error, no exception, just 'nothing here.'" (As noted above, this function's own type annotation is what currently breaks the whole module at import time.)

### `ProfileRepository.create_profile(self, profile: MerchantProfile)` (async)
In simple English: "Take a brand-new profile object, convert it into a plain dictionary using its Mongo-friendly field names (so `id` becomes `_id`, for instance — except we specifically leave `id` out entirely, since a new document doesn't have one yet), and insert it as a new document. Then just hand the same profile object back, unchanged, for convenience."

### `ProfileRepository.update_profile(self, profile: MerchantProfile)` (async)
In simple English: "Take an existing, modified profile object and save its changes back to the database — but deliberately leave three things untouched no matter what: its database ID, when it was first seen, and its canonical name. Those are treated as permanent facts about the profile that should never be overwritten by a routine update. Find the matching document by its canonical name, and apply everything else as a set of field updates." Also returns the same profile object back for convenience.

### `ProfileRepository.get_stale_profiles(self, cutoff_date) -> list[MerchantProfile]` (async)
In simple English: "Find every profile that hasn't been seen since before the given cutoff date, and isn't already marked as ARCHIVED. Turn each matching database document into a proper `MerchantProfile` object, and hand back the whole list at once."

## Classes

### `ProfileRepository`
No instance attributes, no constructor logic — every method operates directly against the shared `db.merchant_profiles` collection handle imported from `database.mongo`.

## Interfaces
`MerchantProfile` is the consistent input/output type contract across every method in this class — the class exists specifically to let the rest of the codebase work exclusively in terms of this typed model, never touching raw MongoDB query syntax directly.

## Hooks
Not applicable.

## Utilities
None — every method is a direct, single-purpose database operation; there are no shared helper functions.

## Dependencies
`logging` (imported, unused); `database.mongo`, `models.schemas` (internal). Third-party: none directly (Motor is used transitively through `database.mongo.db`).

## Side Effects
- Every method except `get_profile` and `get_stale_profiles` performs a database write; the latter two are read-only.
- No logging actually occurs despite `logging` being imported — there is no `logger = logging.getLogger(...)` line and no `logger.something(...)` calls anywhere in the file, making the `import logging` statement fully dead code.

## Performance Considerations
- `get_profile` and `update_profile`/`create_profile` each do exactly one document operation — cheap in isolation, but none of these queries are backed by an index on `canonical_name` anywhere in this codebase, so lookups become collection scans as the `merchant_profiles` collection grows.
- `get_stale_profiles` materializes its entire result set into a Python list via `[MerchantProfile(**doc) async for doc in cursor]` — for a very large stale-profile backlog, this loads everything into memory at once rather than streaming/paginating.

## Possible Interview Questions
- "This file currently cannot be imported at all. Explain precisely why, and name every downstream module that breaks as a result." (`Optional[MerchantProfile]` in `get_profile`'s signature is evaluated at `def`-time since there's no `from __future__ import annotations`, and `Optional` was never imported from `typing` — raising `NameError` immediately. This breaks `memory/memory_manager.py`, `memory/decay_engine.py`, and `routers/memory.py`, all of which import `profile_repo` from this file — and since `app.py` imports `routers.memory`, this likely prevents the entire application from starting.)
- "What are the two ways you could fix this bug, and what's the trade-off between them?" (1. Add `from typing import Optional` — the minimal, safest fix. 2. Add `from __future__ import annotations` at the top of the file, which makes *all* annotations in the file lazy strings rather than evaluated eagerly — this would also fix the immediate crash, but wouldn't catch a similar mistake with a different missing type in the future the way explicitly importing `Optional` would.)
- "Why does `create_profile` exclude `id` from the dumped dict, but `update_profile` excludes `id`, `first_seen`, *and* `canonical_name`?" (`create_profile` only needs to avoid sending a `null`/`None` `_id` field that could conflict with MongoDB's auto-generated ID on insert; `update_profile` additionally protects two fields that represent facts that should never change once a profile exists — a deliberate invariant enforced at the persistence layer rather than trusted to every caller.)
- "Why does `get_profile` project out `_id` entirely (`{"_id": 0}`) instead of keeping it and mapping it to the model's `id` field via the alias mechanism `CoreModel` provides elsewhere?" (A design inconsistency worth probing — `MerchantProfile` does support populating `id` from `_id` via `Field(alias="_id")`, but this method deliberately discards it anyway, meaning every profile fetched this way always reports `id: None`, regardless of what's actually stored in MongoDB.)
