# File: `scripts/seed.py`

## Purpose
A manual, one-off script that seeds canonical merchant/alias records into MongoDB so `services/merchant_resolver.py` has data to match against.

## Responsibilities
- Connect to MongoDB using the application's normal configuration.
- Wipe and repopulate the `merchants` collection with a small, fixed set of known merchants and their aliases.

## Imports
| Import | Used for |
|---|---|
| `asyncio` | Running the async `seed()` function from a synchronous script context |
| `database.mongo.db` | Connecting to and writing into MongoDB |

## Exports
None intended for import — this file is meant to be executed directly (`python scripts/seed.py`), not imported as a library module. It does still define `seed()` at module level, so it's technically importable.

## Execution Flow
1. On import (or execution), `seed()` is defined but not yet run.
2. If run as `__main__`: `asyncio.run(seed())` executes the coroutine to completion, then the process exits.
3. Inside `seed()`: connect → delete all existing `merchants` documents → insert the fixed list of three merchants → disconnect.

## Functions (plain English)

### `seed()` (async)
In simple English: "Connect to the database using the app's normal settings. Completely clear out whatever's currently in the merchants collection — don't try to merge or update, just start fresh. Insert three known merchants (Swiggy, Zomato, Netflix), each with a handful of alternate names/spellings a bank statement might use for them. Print a confirmation message. Disconnect cleanly." Calling `db.connect()` with no arguments relies on `MongoDB.connect`'s built-in fallback to the application's configured `MONGODB_URI`/`MONGODB_DB_NAME` from `.env` — this script doesn't hardcode a connection string itself.

## Classes
None.

## Interfaces
Not applicable.

## Hooks
The `if __name__ == "__main__":` guard is the standard Python convention for "only actually run this when executed directly, not when imported" — not a framework-specific hook.

## Utilities
None beyond the one `seed()` function.

## Dependencies
`asyncio` (standard library); `database.mongo` (internal, and transitively `core.config` for connection settings).

## Side Effects
- **Deletes every existing document** in the `merchants` collection (`delete_many({})`) — a destructive operation with no confirmation prompt or backup step. Running this against a real, populated `merchants` collection would permanently erase any manually-added or previously-seeded merchant data not present in this script's fixed list.
- Inserts exactly 3 new documents.
- Prints a success message to stdout.

## Performance Considerations
Negligible — a `delete_many` and a single `insert_many` of 3 documents; trivially fast regardless of collection size (though `delete_many({})` on a very large existing collection would take time proportional to that collection's size, since it's an unconditional full-collection delete).

## Possible Interview Questions
- "This script unconditionally deletes everything in `merchants` before reseeding. What's the risk of running it against a production database, and how would you make it safer?" (It would silently and irreversibly wipe out any merchant/alias data not present in this script's hardcoded list — including anything added since the script was last updated. A safer version might use `update_one(..., upsert=True)` per merchant instead of a blanket delete, or at least log/require confirmation before a destructive `delete_many({})` against a non-empty collection.)
- "Why does this script call `db.connect()` with no arguments, while `scripts/mock_seeder.py` constructs its own hardcoded connection instead?" (This script reuses the application's actual configured connection settings via `database.mongo`'s fallback-to-`core.config.settings` behavior — a more consistent, environment-aware approach than `mock_seeder.py`'s hardcoded `localhost` connection, which bypasses the app's configuration entirely; the inconsistency between the two scripts is worth flagging.)
- "What would you need to change to make this script idempotent-and-safe rather than destructive-and-safe-only-by-having-a-small-fixed-list?" (Replace the `delete_many` + `insert_many` pattern with per-merchant `update_one(..., upsert=True)` calls keyed on `canonical_name`, so re-running the script updates/adds the known merchants without touching anything else that might exist in the collection.)
