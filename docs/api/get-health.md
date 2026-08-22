# GET `/health`

## Method
`GET`

## URL
`/health`

## Purpose
Reports whether the application and its three external dependencies (MongoDB, Milvus, Ollama) are reachable and responding, for use by orchestrators, load balancers, or manual operational checks.

## Authentication
**None.** This is the only data-bearing endpoint in the application with no `Depends(validate_api_key)` attached — it is defined directly on `app` in `app.py`, outside of any `include_router(..., dependencies=[...])` call.

## Headers
None required. No `Content-Type` needed since there is no request body.

## Request body
None — this is a bodiless `GET` request.

## Validation
None — there are no inputs to validate.

## Response
`200 OK` (always — this endpoint never returns a non-200 status, even when every dependency is down; failures are reported in the response body instead):
```json
{
  "status": "healthy | degraded",
  "services": {
    "mongodb": "connected | disconnected | error",
    "milvus": "connected | disconnected | error",
    "ollama": "connected | degraded | error"
  },
  "details": {
    "mongodb": "string detail message",
    "milvus": "string detail message",
    "ollama": "string detail message"
  }
}
```
`status` is `"healthy"` only when all three sub-statuses equal `"connected"`; any other combination yields `"degraded"`.

## Error codes
None — by design, this endpoint always returns `200`. There is no scenario coded that produces a 4xx or 5xx from this handler itself (an uncaught exception inside the handler's own try/except blocks would still be possible in principle, but every check is individually wrapped).

## Internal execution flow
1. Handler `health_check()` runs, with no dependencies to resolve first (no auth).
2. **MongoDB check**: if `db.client` is truthy, run `await db.client.admin.command("ping")`; success → `"connected"`; any exception → `"error"` with the exception text; if `db.client` is falsy → `"disconnected"`.
3. **Milvus check**: if `vector_db.client` is truthy → `"connected"` (no actual live query is made — this only checks that a client object exists, not that Milvus is currently responsive); otherwise `"disconnected"`; any exception constructing this check → `"error"`.
4. **Ollama check**: makes a real `httpx.AsyncClient` `GET` request to `settings.OLLAMA_URI` with a 2-second timeout; `200` response → `"connected"`; any other status code → `"degraded"`; any exception (timeout, connection refused) → `"error"`.
5. Aggregate the three statuses into the overall `status` field.
6. Return the full payload.

## Controller
`health_check()` in `app.py` — declared inline, not in any `routers/` module. It is both the controller and, unusually for this codebase, effectively its own "service" — there is no separate domain-layer function it delegates to.

## Service
None — all logic lives directly in the route handler. This is one of the few places in the codebase where the normally-thin-controller convention doesn't apply, simply because there's no reusable business logic here beyond this one health aggregation.

## Database queries
- `db.client.admin.command("ping")` — MongoDB's standard lightweight connectivity check, does not touch any application collection.
- No query against Milvus — only an in-memory truthiness check on the client object.

## Example request
```bash
curl -s http://localhost:8000/health
```

## Example response
```json
{
  "status": "healthy",
  "services": {
    "mongodb": "connected",
    "milvus": "connected",
    "ollama": "connected"
  },
  "details": {
    "mongodb": "Active ping successful.",
    "milvus": "Client initialized.",
    "ollama": "Ollama engine responding."
  }
}
```
Degraded example:
```json
{
  "status": "degraded",
  "services": { "mongodb": "connected", "milvus": "disconnected", "ollama": "error" },
  "details": {
    "mongodb": "Active ping successful.",
    "milvus": "Client not initialized.",
    "ollama": "[Errno 111] Connection refused"
  }
}
```

## Interview questions
- "Why does this endpoint always return `200`, even when every dependency is down?" (A common health-check convention: the endpoint itself is 'up' and successfully reporting status, which is a different concern from whether the *dependencies* it's reporting on are healthy — encoding health in the body rather than the status code lets callers distinguish 'the health checker is broken' (a real 5xx) from 'the health checker works and says something's unhealthy' (200 with `degraded`), though this codebase doesn't actually have a scenario for the former.)
- "The Milvus check only verifies `vector_db.client` is non-null — it doesn't make a live call the way the MongoDB and Ollama checks do. What's the blind spot?" (`vector_db.client` could be a stale, no-longer-functional client object — e.g., if the network dropped after a successful connection — and this check would still report `"connected"` since it never re-verifies connectivity, unlike the `ping` command used for MongoDB.)
- "Why does this endpoint have no authentication when every other data-bearing endpoint does?" (Health checks are typically consumed by infrastructure — load balancers, container orchestrators — that may not carry an API key, and exposing basic up/down status is usually considered low-sensitivity; the trade-off is that this endpoint does leak some operational detail, like raw exception text from failed connections, to anyone who can reach it.)
- "This is also worth noting: `vector_db` (from `database/milvus.py`) is checked here, but it's not the Milvus client actually used for real traffic (that's `milvus/insert_vectors.py`'s separately-constructed `vector_store`). What does that mean for this health check's usefulness?" (It could report `milvus: connected` while the client that actually serves `/v1/explain`'s semantic search is misconfigured or down, or vice versa — see `docs/16-known-issues-tech-debt.md#duplicate-milvus-clients`.)
