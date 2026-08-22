# File: `milvus/insert_vectors.py`

## Purpose
Owns the live, actually-used Milvus collection: creates it (and its index) if needed, and provides the write path for storing a merchant's behavior embedding.

## Responsibilities
- Construct a Milvus client independently (bypassing `core.config.settings`).
- Define the `behavior_vectors` collection schema and its HNSW index, creating both if they don't already exist.
- Load the collection into memory so it's searchable.
- Provide an upsert method for writing/overwriting a vector.

## Imports
| Import | Used for |
|---|---|
| `os` | Reading `MILVUS_URI` directly from the environment |
| `logging` | Lifecycle logging |
| `pymilvus.MilvusClient, DataType` | The Milvus client and field-type enum for schema definition |

## Exports
- **`VectorStoreManager`** — the class.
- **`vector_store`** — the singleton instance, imported by `milvus/search_vectors.py` and (attempting to, via a currently-broken attribute reference) `clustering/cluster_engine.py`.
- **`VECTOR_DIM`** — module-level constant (`768`), not imported anywhere else but documents the expected embedding dimensionality.

## Execution Flow
1. On import, `VECTOR_DIM = 768` is set.
2. `vector_store = VectorStoreManager()` runs **immediately at import time** — this is not a lazy singleton.
3. `__init__` reads `MILVUS_URI` via `os.getenv(..., "http://localhost:19530")` (default fallback if unset), constructs a real `MilvusClient`, and calls `_ensure_collections()`.
4. `_ensure_collections()` checks if the collection exists; if not, creates it with its schema and index; either way, it ends by loading the collection into memory.
5. From then on, `insert_behavior_vector(...)` can be called any number of times.

## Functions (plain English)

### `VectorStoreManager.__init__(self)`
In simple English: "When this manager is created, figure out which Milvus server to talk to (checking the environment directly, defaulting to a local address if nothing's set), connect to it, and then make sure our vector collection actually exists and is ready to use — creating it from scratch if this is the very first time."

### `VectorStoreManager._ensure_collections(self)`
In simple English: "Check whether our 'behavior_vectors' collection already exists in Milvus. If it doesn't, define its structure — an ID field, a merchant-name field, and a 768-number vector field — and create it. Also build a search index on the vector field, using a method (HNSW) and similarity measure (cosine) well-suited to fast approximate nearest-neighbor search. Whether the collection already existed or we just created it, finish by loading it into memory so it's actually ready to be searched."

### `VectorStoreManager.insert_behavior_vector(self, pattern_id: str, merchant_name: str, vector: list[float])`
In simple English: "Save (or overwrite, if one already exists with this same ID) a merchant's behavior vector into the collection." This uses Milvus's "upsert" operation, so calling it again later for the same `pattern_id` cleanly replaces the old vector rather than creating a duplicate.

## Classes

### `VectorStoreManager`
Instance attributes: `self.behavior_col_name = "behavior_vectors"` (a plain string, not an actual collection object), `self.client` (the real `MilvusClient`). Note: there is **no** `self.behavior_collection` attribute anywhere in this class — `clustering/cluster_engine.py` incorrectly assumes one exists (see `docs/16-known-issues-tech-debt.md`).

## Interfaces
The Milvus collection schema itself (`id`, `merchant_name`, `embedding`) is the data contract this file defines and enforces at the database level — any code inserting into this collection must conform to that shape.

## Hooks
Not applicable — though this file's import-time side effect (connecting to Milvus and possibly creating a collection) functions similarly to a lifecycle hook, just an implicit one triggered by Python's import machinery rather than an explicit FastAPI hook.

## Utilities
None beyond the lifecycle/insert methods described above.

## Dependencies
`pymilvus` (third-party); `os`, `logging` (standard library). Notably does **not** depend on `core.config` — it reads the environment directly instead, which is the source of the "two separate Milvus clients with potentially divergent configuration" issue documented in `docs/folders/milvus.md`.

## Side Effects
- Connects to a real Milvus server at import time.
- Can create a new collection and index in Milvus (a schema-level, persistent side effect) the first time this code runs against a fresh Milvus instance.
- Loads the collection into memory (a Milvus-side resource allocation).
- `insert_behavior_vector` performs a real write (upsert) against Milvus.
- Logs each significant step (connection, collection creation, index creation, insertion).

## Performance Considerations
- `_ensure_collections` runs its existence check and (conditionally) creation/index-building logic once, at import time — not per request — so this cost is paid exactly once per process lifetime.
- `load_collection` brings the entire collection into memory inside Milvus — appropriate for the HNSW index to function efficiently, but worth knowing that collection size directly affects Milvus's own memory footprint, not this Python process's.
- `insert_behavior_vector` is a single upsert call — cheap per call, though called individually rather than in a batch, so bulk-loading many vectors would mean many separate round trips rather than one batched operation.

## Possible Interview Questions
- "Why does this file read `MILVUS_URI` via `os.getenv` directly instead of importing `core.config.settings`?" (No clear justification in the code — likely an inconsistency from iterative development. The practical risk: if `.env`-based configuration (loaded through `pydantic-settings`) and the actual process environment diverge, this file could silently connect to a different Milvus instance than the one `core.config.settings.MILVUS_URI` reports, with `database/milvus.py`'s separate client using the `settings`-based value.)
- "Why does `_ensure_collections` unconditionally call `load_collection` at the end, even when the collection already existed?" (Because `load_collection` needs to run every time the *process* starts, regardless of whether the collection itself is new — Milvus collections aren't automatically kept loaded in memory across client sessions/restarts, so this ensures the collection is always query-ready after this manager initializes.)
- "What would happen if `EMBED_MODEL` (used elsewhere, in `embeddings/generate_embeddings.py`) produced vectors of a different dimensionality than the hardcoded `VECTOR_DIM = 768` here?" (Nothing in this file validates that at insert or search time — a mismatch would only surface as an error from Milvus itself when attempting to insert or search a vector of the wrong size, not as a clear, early validation error from this codebase.)
- "`clustering/cluster_engine.py` calls `vector_store.behavior_collection.query(...)`. Does that work?" (No — `VectorStoreManager` has no `behavior_collection` attribute at all, only `self.client` and `self.behavior_col_name`; that call would raise `AttributeError` if it were ever reached. It's currently masked by an unrelated import error in that same file — see `docs/16-known-issues-tech-debt.md`.)
