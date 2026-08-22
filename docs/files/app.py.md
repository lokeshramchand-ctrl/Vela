# File: `app.py`

## Purpose
The composition root of the entire service. Creates the FastAPI application, wires in every middleware/router/lifecycle hook, and defines the two routes that live directly on `app` rather than in `routers/`.

## Responsibilities
- Configure global logging.
- Define the `lifespan` context manager that connects/disconnects MongoDB and Milvus.
- Instantiate `FastAPI`, attach rate limiting and Prometheus instrumentation.
- Mount every router with a shared auth dependency.
- Define the dead-code duplicate `/v1/categorize` stub and the real `/health` endpoint.
- Provide a `uvicorn.run(...)` dev entry point.

## Imports
| Import | Used for |
|---|---|
| `contextlib.asynccontextmanager` | Decorator to build the `lifespan` async context manager |
| `logging` | Global log configuration |
| `httpx` | Async HTTP client used in `/health` to ping Ollama |
| `fastapi.FastAPI, Depends, Request` | App object, dependency injection, request object for rate limiting |
| `core.config.settings` | Reads `MONGODB_URI`, `MONGODB_DB_NAME`, `MILVUS_URI`, `OLLAMA_URI` |
| `prometheus_fastapi_instrumentator.Instrumentator` | Auto-instruments all routes for `/metrics` |
| `core.security.validate_api_key` | Auth dependency attached to every router |
| `core.rate_limiter.setup_rate_limiting, limiter` | Rate-limit configuration and the `@limiter.limit(...)` decorator |
| `database.mongo.db` | MongoDB singleton, connected/disconnected in `lifespan` |
| `database.milvus.vector_db` | Milvus singleton, connected/disconnected in `lifespan` |
| `routers.v1, memory, analytics, rag` | The four feature routers |
| `routers.observability.router` | The observability router (imported by name, not module) |

## Exports
`app` — the FastAPI instance. This is the only symbol other modules import from this file (`test_api.py` does `from app import app`; `uvicorn app:app` references it by string).

## Execution Flow
1. Module-level statements run top to bottom on import: logging config, then every import above (each triggering its own transitive import-time side effects — e.g. importing `routers.rag` eventually resolves the Ollama host inside `core/ollama_client.py`).
2. `app = FastAPI(...)` is constructed with `lifespan=lifespan`.
3. `setup_rate_limiting(app)` attaches the limiter to `app.state`.
4. Prometheus instrumentation is attached and `/metrics` exposed.
5. Five `include_router(...)` calls mount the feature routers, each wrapped in the API-key dependency.
6. The inline `/v1/categorize` and `/health` routes are declared directly on `app`.
7. On ASGI server startup, `lifespan` runs: `db.connect(...)` then `vector_db.connect(...)`.
8. Requests are served.
9. On shutdown, `lifespan` resumes after its `yield`: `db.disconnect()` then `vector_db.disconnect()`.
10. If run as `__main__`, `uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=True)` starts a local dev server.

## Functions (plain English)

### `lifespan(app: FastAPI)`
This function runs once when the server starts, and again (the part after `yield`) when the server shuts down. In simple English: "Before we start taking requests, connect to MongoDB and to Milvus. Once we're told to shut down, disconnect from both, cleanly." It's declared `async` and used as a context manager (`async with`), which is how FastAPI expects lifespan hooks to be written.

### `public_categorize(request: Request, payload: dict)`
This is a route handler bound to `POST /v1/categorize`, registered directly on `app`. In simple English: "No matter what you send me, I just say 'Transaction routed to Intelligence Engine' and don't actually do anything with your data." It's dead code in practice — a router-mounted version of the same path (in `routers/v1.py`) is registered earlier and wins the route match, so this function's body never actually executes for real traffic.

### `health_check()`
Bound to `GET /health`. In simple English: "Check three things — can I ping MongoDB? Does the Milvus client exist? Can I reach Ollama over HTTP? — and tell you `healthy` if all three say yes, or `degraded` otherwise, along with the specific detail message for each check." Every check is wrapped in its own `try/except` so one failing service doesn't crash the whole health check — it just gets recorded as `"error"` with the exception text.

## Classes
None — this file contains no class definitions.

## Interfaces
Not applicable in the Python sense (no `Protocol`/`ABC` defined here). The closest equivalent is the implicit contract that every router module must expose a `router` attribute (an `APIRouter` instance) — `app.py` relies on that convention when it does `routers.v1.router`, `routers.memory.router`, etc.

## Hooks
This file *is* almost entirely FastAPI lifecycle/dependency hooks:
- **`lifespan`** — the ASGI startup/shutdown hook.
- **`Depends(validate_api_key)`** — a dependency-injection hook attached to every mounted router, run before each request handler.
- **`@limiter.limit("50/minute")`** — a rate-limiting hook on the (dead-code) inline categorize route.

## Utilities
None — no small helper/utility functions exist in this file beyond the route handlers themselves.

## Dependencies
Third-party: `fastapi`, `httpx`, `prometheus-fastapi-instrumentator`, `uvicorn` (dev entrypoint only). Internal: `core.config`, `core.security`, `core.rate_limiter`, `database.mongo`, `database.milvus`, `routers.*`.

## Side Effects
- Sets the **root logger** to `DEBUG` globally via `logging.basicConfig` — affects every module in the process, not just this file.
- Opens/closes real network connections to MongoDB and Milvus on startup/shutdown.
- `/health` makes a live outbound HTTP call to Ollama on every invocation (2s timeout) — this is a side-effecting network call triggered by what looks like a read-only health check.
- Registers global middleware (rate limiter, Prometheus instrumentator) that intercepts every request in the process.

## Performance Considerations
- `Instrumentator().instrument(app)` wraps every route with metrics-collection overhead — negligible per request but worth knowing it's there.
- `/health`'s live Ollama ping adds up to 2 seconds of latency to that endpoint under a slow/unresponsive Ollama server; if `/health` is polled frequently by an orchestrator, this could generate meaningful background load against Ollama.
- `Milvus.connect`'s retry loop (inside `database/milvus.py`, invoked from here) uses blocking `time.sleep`, which can add up to ~15 seconds of blocking delay to startup if Milvus is slow to become available — this blocks the whole event loop during that window, though it happens before the server accepts traffic.
- Global `DEBUG`-level logging can add measurable overhead and log volume in a high-throughput deployment; there is no environment-based override.

## Possible Interview Questions
- "Trace exactly what happens between `docker run` and the first successful request being served." (Tests understanding of import-time side effects, `lifespan`, and ASGI startup sequencing.)
- "Why does `/health` make a live network call to Ollama rather than caching the last known status?" (Freshness vs. cost trade-off — worth discussing whether that's the right call for a frequently-polled endpoint.)
- "Why is there a rate-limit decorator on a route that never actually executes?" (Tests whether the candidate has traced the duplicate-route issue with `routers/v1.py`.)
- "What would happen if `core.ollama_client`'s host resolution raised during the import chain triggered by `from routers import ... rag`? Would `lifespan` ever run?" (No — the process would fail before `app = FastAPI(...)` is even reached, since imports happen before that line executes.)
