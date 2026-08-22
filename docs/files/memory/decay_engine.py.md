# File: `memory/decay_engine.py`

## Purpose
Implements the "forgetting" half of Phase 4: entities that haven't been seen in a long time should lose their trust status. Currently fully implemented but never actually invoked by anything in the codebase.

## Responsibilities
- Find every profile that hasn't been seen in over 180 days and isn't already archived.
- Transition each one to `ARCHIVED`.
- Report how many were archived.

## Imports
| Import | Used for |
|---|---|
| `datetime.datetime, timezone, timedelta` | Computing the 180-day cutoff date |
| `repositories.profile_repository.profile_repo` | Fetching stale profiles and persisting the state change |
| `models.schemas.MemoryState` | The `ARCHIVED` enum member being applied |
| `logging` | Progress/summary logging |

## Exports
- **`DecayEngine`** — the class.
- **`decay_engine`** — the singleton instance. **Not imported by any other file in the codebase.**

## Execution Flow
On import, `decay_engine = DecayEngine()` runs trivially. `run_archive_sweep()` would, if ever called, run once as a complete batch job: compute cutoff → fetch all stale profiles → loop and update each one sequentially, awaiting each write before moving to the next.

## Functions (plain English)

### `DecayEngine.__init__(self)`
In simple English: "Remember that 'stale' means 180 days without being seen."

### `DecayEngine.run_archive_sweep(self) -> int` (async)
In simple English: "Figure out the exact date 180 days ago from right now. Ask the profile repository for every merchant profile that hasn't been updated since before that date and isn't already archived. For each one we find, mark it as ARCHIVED and save the change. Keep a running count of how many we archived, and report that total at the end." This is a full batch operation — it processes every eligible profile in one call, not one at a time on demand, and there is no pagination or batching within the sweep itself, so a very large number of stale profiles would all be processed in one synchronous loop within a single call.

## Classes

### `DecayEngine`
Instance attribute: `self.ARCHIVE_DAYS = 180`, set once in `__init__`.

## Interfaces
Not applicable formally — though the code comment inside `run_archive_sweep` notes a design consideration left as an explicit choice for whoever finishes wiring this up: "Optional: You might decide PERMANENT memory never decays. If so, add `if profile.memory_state == MemoryState.PERMANENT: continue`" — meaning as written today, even `PERMANENT` profiles are eligible for archival if inactive long enough (the repository query only excludes profiles already `ARCHIVED`, not `PERMANENT` ones).

## Hooks
Not applicable — and notably, this is exactly the kind of function that *should* be triggered by a scheduling hook (a cron job, `APScheduler`, or similar), but no such hook exists anywhere in this codebase.

## Utilities
None.

## Dependencies
`datetime` (standard library); `repositories.profile_repository`, `models.schemas` (internal).

## Side Effects
- Reads from and writes to MongoDB — potentially many documents in a single call, depending on how many profiles qualify as stale.
- Logs a start message and a summary count at the end.

## Performance Considerations
- No batching/pagination: `get_stale_profiles` materializes the *entire* result set into a Python list (via a list comprehension over the cursor) before this function starts looping — for a very large number of stale profiles, this could use significant memory and take a long time in one unbroken call, with the whole operation succeeding or failing as one unit rather than incrementally.
- Each archived profile triggers its own individual `update_one` call (via `profile_repo.update_profile`) rather than a single bulk update — for N stale profiles, this means N separate round trips to MongoDB, which would be considerably slower than a single `update_many({"last_seen": {"$lt": cutoff}, ...}, {"$set": {"memory_state": "ARCHIVED"}})` call.

## Possible Interview Questions
- "This function is fully implemented and bug-free but never called anywhere. How would you notice that during a review, and what would you need to add to make it useful?" (A reverse-dependency search — grep for `decay_engine` or `DecayEngine` outside this file turns up nothing. To make it useful, you'd need a scheduler: a cron entry, an APScheduler job registered at app startup, or a Celery beat task, none of which exist in this codebase today.)
- "Should `PERMANENT` profiles ever be archived due to inactivity? What does the current code do, and what does its own comment suggest?" (As written, yes — `PERMANENT` is not excluded from the stale-profile query, so a very old but historically frequent merchant could still be archived if untouched for 180+ days. The code's own comment flags this as an open design decision the author left unresolved.)
- "Why does this function process profiles one at a time with individual `update_one` calls instead of a single bulk `update_many`?" (Simplicity of reusing the existing `profile_repo.update_profile` method (which operates on one `MerchantProfile` at a time) — at the cost of significantly worse performance at scale compared to a single bulk operation.)
- "What would happen if this sweep were run while `memory_manager.process_encounter` was simultaneously processing a fresh encounter for one of the same profiles?" (A race condition is possible: the sweep might archive a profile at nearly the same moment a new encounter is reviving it, with the final state depending on which write lands last — no locking protects against this.)
