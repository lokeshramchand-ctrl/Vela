# File: `scripts/mock_seeder.py`

## Purpose
Injects (and later removes) realistic-looking, clearly-tagged synthetic transaction data, giving the Analytics Engine something meaningful to compute against without touching real production data.

## Responsibilities
- Generate 100 randomized but plausible-looking mock transactions for a fixed test user.
- Tag every generated document so it can be safely and precisely cleaned up later.
- Provide a separate cleanup mode that removes exactly that tagged data.

## Imports
| Import | Used for |
|---|---|
| `asyncio` | Running the async `seed()`/`cleanup()` functions |
| `sys` | Reading command-line arguments to decide seed vs. cleanup mode |
| `random` | Generating randomized merchant choices, amounts, and dates |
| `datetime.datetime, timedelta, timezone` | Computing randomized past timestamps |
| `motor.motor_asyncio.AsyncIOMotorClient` | A **separate**, independently-constructed MongoDB client (does not use `database.mongo.db`) |

## Exports
None intended for import â€” a standalone script, though `seed()` and `cleanup()` are technically importable module-level functions.

## Execution Flow
1. On execution, `MONGO_URI = "mongodb://localhost:27017"` and `DB_NAME = "Vela"` are set as hardcoded module-level constants â€” **not** read from `.env`/`core.config.settings`.
2. If run as `__main__`: checks `sys.argv` â€” if the first argument is `"cleanup"`, runs `cleanup()`; otherwise (including no arguments at all) runs `seed()`.

## Functions (plain English)

### `seed()` (async)
In simple English: "Connect directly to a local MongoDB instance. Generate 100 fake transactions: for each one, randomly pick a merchant-and-category pair from a list of 10 realistic options (like Swiggy/Food, Uber/Travel, Netflix/Subscription), pick a random amount between â‚¹50 and â‚¹2,500, and pick a random date sometime in the last 60 days. Mark every single one of these fake transactions with a special flag (`is_mock: True`) so we can find and remove them later without touching real data. Insert all 100 at once, print a confirmation with an emoji, and close the connection."

### `cleanup()` (async)
In simple English: "Connect to the same local database. Delete only the transactions that belong to our specific test user *and* are marked as mock data â€” real transactions, or mock data belonging to a different user, are left completely untouched. Print how many were removed, with an emoji, and close the connection."

## Classes
None.

## Interfaces
Not applicable.

## Hooks
The `if __name__ == "__main__":` block reads `sys.argv[1]` to branch between seed and cleanup modes â€” a simple manual command-line-argument dispatch, not a formal CLI framework.

## Utilities
None beyond the two top-level functions.

## Dependencies
`asyncio`, `sys`, `random`, `datetime` (standard library); `motor` (third-party, used directly rather than through `database.mongo`).

## Side Effects
- **Inserts 100 real documents** into the `transactions` collection of whatever MongoDB instance is at `mongodb://localhost:27017` â€” regardless of what the application's actual configured `MONGODB_URI` in `.env` might be.
- **Deletes documents** matching `{user_id: "user_123", is_mock: True}` in cleanup mode â€” a targeted, safe deletion given the specific double-filter, unlike `scripts/seed.py`'s blanket delete.
- Prints status messages to stdout.

## Performance Considerations
Negligible â€” a single `insert_many` of 100 documents, or a single `delete_many` with a specific filter; both trivially fast regardless of the target collection's overall size (the delete's cost scales with how many documents *match* the filter, which is bounded at 100 by design here).

## Possible Interview Questions
- "Why does this script hardcode `mongodb://localhost:27017` instead of using `database.mongo.db`, which would respect the application's actual `.env` configuration?" (No stated reason in the code â€” plausibly written for quick, standalone local testing without needing the full app's settings validation to succeed first, but it means running this script against a non-default MongoDB setup (e.g., a Dockerized Mongo on a different host/port) silently does nothing useful, or worse, seeds data into the wrong database entirely without any error or warning.)
- "Why tag mock data with `is_mock: True` and filter cleanup on both `user_id` and that flag, rather than just deleting all transactions for `user_123`?" (Defense in depth â€” if `user_123` ever had *real*, non-mock transactions for any reason (e.g., manual testing that created genuine-looking records without the mock flag), a blanket delete by `user_id` alone would destroy them too; requiring both conditions to match protects against that.)
- "What happens if you run `seed()` twice in a row without running `cleanup()` in between?" (You'd end up with 200 mock transactions instead of 100 â€” nothing prevents duplicate seeding, since each run is purely additive (`insert_many`, not an upsert or a check for existing mock data).)
- "How would you make this script safer to accidentally run against a real production database?" (Add an explicit environment/connection-string check â€” e.g., refusing to run unless connected to a database whose name or host clearly indicates a test/dev environment â€” since currently nothing here prevents this script from being pointed at and polluting a production instance if the hardcoded URI were simply changed to one.)

