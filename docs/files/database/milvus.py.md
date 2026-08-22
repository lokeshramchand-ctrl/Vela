# File: `database/milvus.py`

## Purpose
Owns a Milvus client connection lifecycle managed by the app's `lifespan`, with startup retry logic. Notably, despite existing for exactly this purpose, it is **not** what powers any actual vector search/insert in the running application — see `docs/folders/milvus.md` for the parallel client in `milvus/insert_vectors.py` that does the real work.

## Responsibilities
- Attempt to connect to Milvus with retries and backoff.
- Confirm connectivity by listing collections.
- Degrade to a `None` client (rather than crashing) if Milvus is unreachable after all retries.
- Close the client cleanly on disconnect.

## Imports
| Import | Used for |
|---|---|
| `logging` | Connection lifecycle logging |
| `time` | `time.sleep(delay)` between retry attempts |
| `pymilvus.MilvusClient, MilvusException` | The Milvus driver client and its specific exception type |
| `core.config.settings` | Fallback `MILVUS_URI` if not explicitly passed |

## Exports
- **`VectorDB`** — the class itself.
- **`vector_db`** — the singleton instance, imported only by `app.py`.

## Execution Flow
1. On import, `VectorDB` is defined and `vector_db = VectorDB()` instantiated (cheap — one class attribute, `client = None`).
2. `app.py`'s `lifespan` calls `vector_db.connect(uri)` once at startup, **after** `db.connect(...)` (Mongo) has already run.
3. `connect()` loops up to `retries` times (default 5): try to construct a `MilvusClient` and call `list_collections()` to confirm it actually works; on `MilvusException` or any other exception, sleep `delay` seconds (default 3) and try again.
4. If all attempts fail, `cls.client` is explicitly set to `None` and the function returns normally (no exception raised) — this is a deliberate "degrade gracefully" choice, unlike `core/ollama_client.py`'s "raise on total failure" approach.
5. `app.py`'s `lifespan` calls `vector_db.disconnect()` on shutdown.

## Functions (plain English)

### `VectorDB.connect(cls, uri=None, retries=5, delay=3)` (classmethod)
In simple English: "Try to connect to Milvus. If it doesn't work right away — which can happen if Milvus's container is still starting up — wait a few seconds and try again, up to 5 times total. Each time, after connecting, double-check the connection actually works by asking Milvus to list its collections. If we've tried 5 times and it still doesn't work, give up quietly — don't crash the whole app, just leave the client empty so other parts of the system know Milvus isn't available." Two different exception types are handled slightly differently: `MilvusException` gets a `warning`-level log (expected, transient failure), while any other unexpected exception gets a full `exception`-level log with stack trace (unexpected failure) — but both cases sleep and retry identically.

### `VectorDB.disconnect(cls)` (classmethod)
In simple English: "If we have an open Milvus connection, try to close it properly. If closing it fails for some reason, don't let that crash anything — just log it and clear our reference to the client anyway." The `finally: cls.client = None` ensures the client reference is always cleared regardless of whether `close()` succeeded, preventing a half-closed client from lingering as if it were still usable.

## Classes

### `VectorDB`
Like `MongoDB`, a namespace class with only class-level state: `client: MilvusClient | None = None`. All methods are `@classmethod`s.

## Interfaces
Not applicable formally. `client: MilvusClient | None` is a type-hinted contract signaling to callers that they must always check for `None` before use — `app.py`'s `/health` endpoint follows this convention (`if vector_db.client: ...`).

## Hooks
Same pattern as `database/mongo.py` — `connect`/`disconnect` are the implementation behind `app.py`'s `lifespan` hook, specifically for Milvus.

## Utilities
None beyond the two lifecycle methods.

## Dependencies
`pymilvus` (third-party), `core.config` (internal).

## Side Effects
- Opens a real network connection to Milvus (with retries).
- Uses **blocking** `time.sleep()` between retries — inside code invoked from an `async` lifespan context, meaning failed connection attempts block the entire event loop (no other coroutine can run) for up to `retries × delay` seconds (15 seconds by default) during startup.
- Mutates process-wide class state (`VectorDB.client`).
- Logs every attempt, success, and failure.

## Performance Considerations
- The blocking retry loop is the most notable performance concern: in a slow-starting environment (e.g., Milvus's own etcd/storage dependencies still initializing), this can add up to 15 seconds of fully blocked startup time, during which literally nothing else in the process can execute (not just this request — the entire async event loop is frozen by `time.sleep`).
- Because this client (`vector_db`) is never actually used for real queries anywhere else in the codebase, its connection health has no bearing on the actual functioning of `/v1/explain` or clustering — only on what `/health` reports for the `milvus` sub-status, which can be a misleading signal (this client could show `disconnected` while the *actually used* client in `milvus/insert_vectors.py` is working fine, or vice versa).

## Possible Interview Questions
- "Why does `VectorDB.connect` degrade to `client = None` on failure, while `core/ollama_client.py`'s equivalent logic raises an exception instead?" (An inconsistency in failure philosophy across the codebase — Milvus is treated as an optional-at-startup dependency (the app can still serve some traffic without it), while Ollama's resolution is treated as fatal. Worth asking whether that distinction was deliberate or accidental.)
- "What's the impact of using `time.sleep` instead of `asyncio.sleep` inside code called from an async `lifespan`?" (Blocks the entire event loop for the sleep duration — no other coroutine, including ones unrelated to Milvus, can make progress during that window. `asyncio.sleep` would yield control back to the event loop instead.)
- "This class's `client` attribute is never read by anything outside `app.py`. Is that a bug or dead code?" (Effectively dead code from a functional standpoint — the real Milvus traffic goes through a separate, independently-constructed client in `milvus/insert_vectors.py`. This file exists but its connection is only used for the `/health` status check.)
- "Why call `list_collections()` after constructing the client instead of just trusting that `MilvusClient(...)` succeeding means the connection is good?" (`MilvusClient`'s constructor may not itself fail on an unreachable server depending on the driver's connection semantics — actively calling a real API method is a more reliable way to confirm the connection genuinely works end-to-end.)
