# File: `database/mongo.py`

## Purpose
Owns the async MongoDB connection lifecycle and exposes every named collection the application uses as simple class attributes.

## Responsibilities
- Create one `AsyncIOMotorClient` on `connect()`.
- Bind seven named collection handles for convenient, typo-resistant access elsewhere in the codebase.
- Close the client cleanly on `disconnect()`.

## Imports
| Import | Used for |
|---|---|
| `motor.motor_asyncio.AsyncIOMotorClient` | The async MongoDB driver client |
| `logging` | Connection lifecycle logging |
| `core.config.settings` | Fallback values for `uri`/`db_name` if not explicitly passed to `connect` |

## Exports
- **`MongoDB`** — the class itself (rarely referenced directly; used for its class-level state).
- **`db`** — the singleton instance, imported everywhere data access is needed: `from database.mongo import db`.

## Execution Flow
1. On import, the `MongoDB` class is defined and `db = MongoDB()` is instantiated — but this is nearly free, since `MongoDB` has no `__init__` and no instance state; all "state" lives on the class itself.
2. Nothing connects to MongoDB until `db.connect(...)` is explicitly called — this happens exactly once, from `app.py`'s `lifespan`, at application startup (or manually, from scripts like `scripts/seed.py`).
3. `connect()` creates the client and binds all seven collections as class attributes — after this call, `db.transactions`, `db.feedback`, etc. all become valid.
4. `disconnect()` is called from the same `lifespan`, on shutdown.

## Functions (plain English)

### `MongoDB.connect(cls, uri=None, db_name=None)` (classmethod)
In simple English: "Connect to MongoDB. If you didn't tell me exactly which address or database name to use, fall back to whatever's configured in the app's settings. Once connected, set up quick-access shortcuts for all seven collections we care about, so the rest of the code can just say `db.transactions` instead of typing out collection names as strings everywhere." This is async because creating the underlying client and the network handshake happen asynchronously (though `AsyncIOMotorClient(uri)` itself is actually lazy/non-blocking at construction — the real connection happens on first use).

### `MongoDB.disconnect(cls)` (classmethod)
In simple English: "If we have an open connection, close it properly and say so in the logs."

## Classes

### `MongoDB`
A namespace class — every attribute (`client`, `db`, and the seven collection handles) and every method is at the **class level**, not instance level. This means `db = MongoDB()` and `MongoDB` itself refer to the same shared state; there is effectively one true "instance" no matter how many times you instantiate it. Class attributes: `client: AsyncIOMotorClient = None`, `db = None` (both initially `None` until `connect()` runs), plus `transactions`, `feedback`, `categories`, `merchants`, `merchant_profiles`, `behavior_patterns`, `retraining_queue` (all bound dynamically inside `connect()`, not declared as class attributes up front — meaning accessing e.g. `db.transactions` before `connect()` has run would raise `AttributeError`, not return `None`).

## Interfaces
Not applicable formally — but the seven bound collection names function as an implicit "schema of what data domains this app has," and any new feature needing a new collection would need to add a line here to follow the established convention (several modules bypass this convention — see Common Mistakes in `docs/folders/database.md`).

## Hooks
Not FastAPI hooks directly, but `connect`/`disconnect` are the two halves of the resource-lifecycle hook pattern invoked by `app.py`'s `lifespan` — this file provides the implementation that hook calls into.

## Utilities
None beyond the two lifecycle methods.

## Dependencies
`motor` (third-party async MongoDB driver), `core.config` (internal, for fallback settings).

## Side Effects
- Opens a real network-facing database client on `connect()`.
- Mutates shared, process-wide class state (`MongoDB.client`, `.db`, and all collection attributes) — any code anywhere in the process that reads `db.transactions` after `connect()` sees the same shared handle.
- Closes the network client on `disconnect()`.
- Logs connection/disconnection events.

## Performance Considerations
- `AsyncIOMotorClient` internally manages its own connection pool — no manual pool-size tuning is done here, so whatever Motor's defaults are apply.
- Because `MongoDB` is a true process-wide singleton, there is exactly one client (and its underlying connection pool) shared by every concurrent request — this is the correct pattern for an async app (avoids the overhead of reconnecting per request) but also means a single misbehaving query or a connection pool exhaustion event affects every concurrent caller.
- No indexes are created anywhere in this file (or the rest of the codebase) — every query against these collections runs without index support unless the underlying MongoDB deployment has indexes configured out-of-band.

## Possible Interview Questions
- "Why are `MongoDB`'s methods `@classmethod`s operating on class attributes, rather than a normal class with `__init__` and instance attributes?" (Guarantees a true singleton without extra machinery — any reference to `MongoDB` or any instance of it sees the same state — at the cost of making it harder to spin up a second, isolated instance for testing.)
- "What happens if code tries to access `db.transactions` before `connect()` has been called?" (`AttributeError`, since the collection attributes are only ever assigned inside `connect()` — they don't exist as class attributes beforehand, unlike `client`/`db` which are explicitly initialized to `None`.)
- "Why does `connect()` accept optional `uri`/`db_name` parameters with a fallback to `settings`, rather than always reading from `settings` directly?" (Flexibility for testing or scripts that might want to connect to a different database than the one configured in `.env` — though in practice, every caller in this codebase either passes explicit values matching `settings` or relies entirely on the fallback.)
- "If you wanted to add a new collection for a new feature, what would you need to change here?" (Add a new `cls.<name> = cls.db.get_collection("<name>")` line inside `connect()` — a manual step easy to forget, since nothing enforces that new collections used elsewhere in the codebase are registered here.)
