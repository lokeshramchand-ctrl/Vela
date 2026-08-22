# 04 Â· Core Infrastructure

Everything in this document lives under `core/` and `database/`, plus the composition root in `app.py`.

## 4.1 Configuration â€” `core/config.py`

Configuration is a single Pydantic `Settings` object (`BaseSettings`), instantiated once at import time as the module-level singleton `settings`. It loads from a `.env` file in the working directory (`SettingsConfigDict(env_file=".env")`).

| Env var | Type | Required | Default | Purpose |
|---|---|---|---|---|
| `MONGODB_URI` | `str` | Yes | â€” | Mongo connection string |
| `MONGODB_DB_NAME` | `str` | No | `"Vela"` | Mongo database name |
| `MILVUS_URI` | `str` | Yes | â€” | Milvus endpoint |
| `OLLAMA_URI` | `str \| None` | No | `None` | Single Ollama host; takes precedence over `OLLAMA_HOSTS` |
| `OLLAMA_HOSTS` | `str \| None` | No | `None` | Comma-separated list of Ollama hosts for failover resolution |
| `EMBED_MODEL` | `str` | Yes | â€” | Ollama model name for embeddings |
| `LLM_MODEL` | `str` | Yes | â€” | Ollama model name for generation |
| `Vela_API_KEY` | `str` | Yes | â€” | **Declared but never read by `core/security.py`** â€” see [Known Issues](./16-known-issues-tech-debt.md#hardcoded-api-key) |

Because these are all required (no default) except where noted, **the process will fail to start** (Pydantic validation error at `settings = Settings()`) if `.env` is missing any of `MONGODB_URI`, `MILVUS_URI`, `EMBED_MODEL`, `LLM_MODEL`, or `Vela_API_KEY`.

`ollama_hosts_list` is a computed property that splits `OLLAMA_HOSTS` on commas and strips whitespace; returns `[]` if unset.

## 4.2 Ollama host resolution â€” `core/ollama_client.py`

âœ… **FIXED â€” resolution is now deferred to first use, not import time.** Previously this module computed `OLLAMA_HOST` as a module-level constant the moment anything imported `core.ollama_client`, and would `raise RuntimeError` from that import if `OLLAMA_URI` wasn't set and every host in `OLLAMA_HOSTS` failed its 2-second health check â€” crashing the entire app at startup (via `app.py` â†’ `routers.rag` â†’ `rag.generator` â†’ `core.ollama_client`), not just degrading RAG/embeddings.

```mermaid
flowchart TD
    A[First actual API call needing Ollama] --> B[get_ollama_host called]
    B --> C{already resolved this process?}
    C -- yes --> Z[return cached host]
    C -- no --> D{settings.OLLAMA_URI set?}
    D -- yes --> E[cache + return OLLAMA_URI]
    D -- no --> F[resolve_ollama_host: GET each host, 2s timeout]
    F --> G{any host returns 200?}
    G -- yes --> E
    G -- no --> H[raise RuntimeError â€” only this request fails, app already running]
```

Consumers: `rag/generator.py` and `embeddings/generate_embeddings.py` now call `get_ollama_host()` inside their request-handling methods (not at `__init__`/import time) and build their API URLs per-call. A temporarily-unreachable Ollama fleet now only fails the specific RAG/embedding request that needed it, instead of preventing the whole app from starting. See [16 Â· Known Issues Â§16.3](./16-known-issues-tech-debt.md#163-medium-previously-disconnected-features-dead-code-silent-no-ops--fixed).

## 4.3 Security â€” `core/security.py`

```python
async def validate_api_key(api_key_header: str = Security(api_key_header)) -> str:
    if not api_key_header:
        raise HTTPException(401, "Missing X-Vela-API-Key header")
    if api_key_header != settings.Vela_API_KEY:
        raise HTTPException(403, "Invalid or revoked API Key")
    return "developer_id_789"
```

- The header name is `X-Vela-API-Key` (`API_KEY_NAME`), implemented via `fastapi.security.api_key.APIKeyHeader(auto_error=False)` so that a missing header is handled explicitly (401) rather than FastAPI's default 403.
- âœ… **FIXED** â€” the comparison now reads `settings.Vela_API_KEY` instead of a hardcoded literal. Rotating `Vela_API_KEY` in `.env`/deployment config now actually takes effect. See [16 Â· Known Issues Â§16.2](./16-known-issues-tech-debt.md#162-high-previously-security--correctness-with-real-user-impact--all-fixed).
- On success, the function still returns a **hardcoded identity string** `"developer_id_789"` â€” there is no real multi-tenant identity resolution; this return value is unused by any caller today (FastAPI dependency return values are discarded when used only in `dependencies=[...]`, not `Depends()` bound to a parameter). This is a genuine remaining limitation (multi-tenancy is on the roadmap), not something silently fixed here.
- The docstring claims "In production, this routes through Redis for sub-millisecond validation" â€” no Redis client, dependency, or configuration exists anywhere in this repository.

## 4.4 Rate limiting â€” `core/rate_limiter.py`

Uses **SlowAPI** (`slowapi.Limiter`), keyed by `get_remote_address` (client IP). Global defaults: `1000/day`, `100/minute`. `setup_rate_limiting(app)` attaches the limiter to `app.state.limiter` and registers `RateLimitExceeded` â†’ `_rate_limit_exceeded_handler`.

âœ… **FIXED** â€” the `@limiter.limit("50/minute")` override now lives on the real `POST /v1/categorize` handler in `routers/v1.py` (the pydantic body parameter was renamed from `request` to `payload` so a real `Request` object could be bound to the parameter name SlowAPI requires). Previously this decorator only existed on a dead-code duplicate route in `app.py` that never received traffic, so no live endpoint had a tighter-than-default limit. Verified: 55 rapid calls return `429` once the limit is hit.

`test_api.py::test_rate_limiter_defense` is no longer `xfail` â€” it passes for real now that the limit is actually enforced on a live route, and resets `limiter` state afterward so its 55 hits don't count against the shared-fixture budget of other tests in the same module.

## 4.5 Database clients

### MongoDB â€” `database/mongo.py`
- `MongoDB` is a class used purely as a namespace (all methods are `@classmethod`, attributes are class-level) â€” instantiated once as `db = MongoDB()`, but since everything is class-level, any import of `database.mongo.db` sees the same shared state as `MongoDB` itself.
- `connect(uri, db_name)` creates one `AsyncIOMotorClient` and binds seven named collection accessors as class attributes (`transactions`, `feedback`, `categories`, `merchants`, `merchant_profiles`, `behavior_patterns`, `retraining_queue`).
- `disconnect()` closes the client if present.
- No connection pooling configuration, no TLS options, no retryWrites configuration â€” whatever Motor/PyMongo defaults apply given the URI.

### Milvus â€” `database/milvus.py`
- `VectorDB.connect(uri, retries=5, delay=3)` retries up to 5 times with a blocking `time.sleep(delay)` between attempts (this is a **synchronous** sleep inside code called from the async `lifespan`, so it blocks the event loop for up to 15 seconds during startup if Milvus is slow to come up).
- On success it calls `client.list_collections()` purely to confirm connectivity (result is logged at DEBUG, not otherwise used).
- On exhausting all retries, `cls.client` is set to `None` rather than raising â€” the app will start in a degraded state and `/health` will report `milvus: disconnected`.
- **This `vector_db` singleton is not used anywhere else in the codebase.** All actual Milvus reads/writes go through the separate `milvus.insert_vectors.VectorStoreManager` (`vector_store`) and `milvus.search_vectors.VectorSearchEngine` (`vector_search`), which each construct their own `MilvusClient` directly from `os.getenv("MILVUS_URI", "http://localhost:19530")` â€” bypassing `core.config.settings` entirely. See [01 Â· Architecture Â§1.2](./01-architecture.md#12-process-topology) and [Known Issues](./16-known-issues-tech-debt.md#duplicate-milvus-clients).

## 4.6 Application composition â€” `app.py`

- Logging is configured globally at `DEBUG` level via `logging.basicConfig` â€” this applies to the root logger, so every module's `logging.getLogger(__name__)` calls inherit `DEBUG` verbosity in any environment unless overridden. There is no environment-based log-level switch (no `LOG_LEVEL` env var is read).
- `FastAPI(title="Vela", version="1.0.0", lifespan=lifespan)` â€” OpenAPI docs are available at the default `/docs` and `/redoc` paths (not disabled).
- Router mount order: `v1` â†’ `memory` â†’ `analytics` â†’ `rag` â†’ `observability`, each with `dependencies=[Depends(validate_api_key)]` applied at the `include_router` call (this wraps every route in that router with the auth dependency, in addition to any dependencies declared on the router or individual routes directly â€” there are none of the latter here).
- The local dev entry point (`if __name__ == "__main__": uvicorn.run(...)`) hardcodes `reload=True`, `host="0.0.0.0"`, `port=8000` â€” this path is bypassed entirely in Docker, where the `CMD`/`command` directly invokes `uvicorn app:app` without `--reload`.

