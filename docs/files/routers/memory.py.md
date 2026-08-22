# File: `routers/memory.py`

## Purpose
Exposes the Phase 4 memory/state-machine system over HTTP: recording encounters and reading back profile/state information.

## Responsibilities
- Expose `POST /memory/update`, `GET /memory/profile/{canonical_name}`, `GET /memory/state/{canonical_name}`.
- Translate requests into calls against `memory/memory_manager.py` and `repositories/profile_repository.py`.
- Return a friendly `404` when a profile doesn't exist, or a synthetic "UNSEEN" state instead of erroring.

## Imports
| Import | Used for |
|---|---|
| `fastapi.APIRouter, HTTPException` | Router construction; explicit 404 raising |
| `pydantic.BaseModel` | Base for the local `MemoryUpdateRequest` |
| `memory.memory_manager.memory_manager` | The encounter-processing singleton |
| `repositories.profile_repository.profile_repo` | Direct read access for the two GET endpoints |
| `models.schemas.MerchantProfile` | Response model for two of the three endpoints |

## Exports
**`router`** — the `APIRouter` instance, imported and mounted by `app.py`.

## Execution Flow
1. On import, `router = APIRouter(prefix="/memory", tags=["Memory Engine"])` and the local `MemoryUpdateRequest` model are declared.
2. Per-request: auth dependency (external, from `app.py`) → path/body validation → handler invocation → response serialization against the declared `response_model` where set.

## Functions (plain English)

### `update_memory(request: MemoryUpdateRequest)`
Bound to `POST /memory/update`. In simple English: "Tell the memory manager that we just saw this merchant again (or for the first time), and send back the merchant's updated profile — including whatever trust level it's now at."

### `get_profile(canonical_name: str)`
Bound to `GET /memory/profile/{canonical_name}`. In simple English: "Look up everything we know about this merchant. If we've genuinely never seen it, say so with a clear 404 error instead of returning empty or fake data."

### `get_memory_state(canonical_name: str)`
Bound to `GET /memory/state/{canonical_name}`. In simple English: "Give me just the trust level and how many times we've seen this merchant — a lighter-weight version of the full profile lookup. If we've never seen it, don't error out; just say its state is 'UNSEEN' (a value that doesn't actually exist in the `MemoryState` enum, so it's a special sentinel just for this response, not a real memory state)."

## Classes

### `MemoryUpdateRequest(BaseModel)`
Two fields: `canonical_name: str`, `raw_text: str`. The request body shape for `/memory/update`.

## Interfaces
`MemoryProfile` (from `models/schemas.py`) is used as the `response_model` for two endpoints, meaning FastAPI validates and serializes the return value against that schema automatically — an implicit output contract.

## Hooks
Auth dependency attached externally in `app.py`, same pattern as every other router.

## Utilities
None.

## Dependencies
`fastapi`, `pydantic` (third-party); `memory.memory_manager`, `repositories.profile_repository`, `models.schemas` (internal).

## Side Effects
- `update_memory` writes to MongoDB (via `memory_manager.process_encounter`, which ultimately calls `profile_repo.create_profile`/`update_profile`) — a real, persistent side effect.
- `get_profile`/`get_memory_state` are read-only.

## Performance Considerations
- Each `GET`/`POST` here triggers exactly one `find_one` (read endpoints) or one `find_one` + one `insert_one`/`update_one` (write endpoint) against the unindexed `merchant_profiles` collection — cheap at small scale, but a full collection scan under the hood as the collection grows, since no index exists on `canonical_name`.
- `get_memory_state`'s "lighter-weight" framing is really just about response payload size (fewer fields returned), not about doing less database work — it still fetches the entire profile document from MongoDB internally via the same `get_profile` call as the full-profile endpoint.

## Possible Interview Questions
- "Why does `get_memory_state` return a fake `'UNSEEN'` state instead of using the real `MemoryState` enum's values, when a merchant hasn't been seen?" (`MemoryState` genuinely has no "unseen" concept — a profile that doesn't exist yet has no `MemoryState` at all — so this endpoint invents a convenience sentinel value specifically for API ergonomics rather than trying to force-fit an existing enum member.)
- "Why does `get_profile` raise a 404 on a missing profile, but `get_memory_state` returns a 200 with a synthetic value for the same missing-profile case?" (A deliberate API design choice: the full-profile endpoint treats 'not found' as an error condition worth signaling via status code, while the lightweight state endpoint treats it as a normal, expected outcome worth describing in the payload instead — worth discussing whether this inconsistency is good API design or should be unified.)
- "If `repositories/profile_repository.py`'s `Optional` import bug (see that file's docs) isn't fixed, what happens when this module is imported?" (This module fails to import as well, since it imports `profile_repo` directly from the broken file — cascading up through `app.py`'s `include_router(memory.router, ...)` call.)
