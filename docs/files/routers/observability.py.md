# File: `routers/observability.py`

## Purpose
Placeholder endpoints for Phase 14's intended MLOps/drift-monitoring capability. Currently pure stubs with no real logic.

## Responsibilities
- Expose `POST /v1/observability/drift/analyze` and `GET /v1/observability/reports/latest`.
- (Intended, not implemented) trigger and serve data-drift analysis reports.

## Imports
| Import | Used for |
|---|---|
| `fastapi.APIRouter` | Router construction |
| `fastapi.responses.JSONResponse` | Explicit control over the status code on the report-fetch stub |

## Exports
**`router`** — mounted by `app.py` under prefix `/v1/observability`.

## Execution Flow
Both handlers are unconditional, branch-free — they always return the exact same response regardless of input (there is no input to either handler beyond the implicit request object).

## Functions (plain English)

### `trigger_drift_analysis()`
Bound to `POST /v1/observability/drift/analyze`. In simple English: "Always just say 'drift analysis triggered successfully,' without actually doing any analysis, triggering any background job, or checking any data." The docstring claims this would trigger a background Evidently AI task via Celery in production — none of that exists in the codebase.

### `fetch_drift_report()`
Bound to `GET /v1/observability/reports/latest`. In simple English: "Always respond with a 404 'no reports have been generated yet' message — there is no code path anywhere that could make this respond any differently, since there's no mechanism that ever generates a report to serve."

## Classes
None.

## Interfaces
Not applicable.

## Hooks
Auth dependency attached externally in `app.py`, same as every other router.

## Utilities
None.

## Dependencies
`fastapi` only. No internal dependencies — this file is completely self-contained, unlike every other router in the codebase.

## Side Effects
None whatsoever — both handlers are pure, stateless, side-effect-free stubs.

## Performance Considerations
Trivially fast — no I/O, no computation, just constant dict/JSON responses.

## Possible Interview Questions
- "Why explicitly use `JSONResponse(status_code=404, ...)` instead of raising `HTTPException(404, ...)` like other 404s in this codebase (e.g., `routers/memory.py`)?" (Functionally similar end result, but a different, less idiomatic FastAPI pattern than `HTTPException` — worth asking why the inconsistency exists; possibly just two different developers' habits.)
- "If asked to make `trigger_drift_analysis` do something real, what's the minimal viable implementation?" (At minimum: accept a reference dataset and a current dataset, run an actual drift-detection library (e.g., Evidently AI) comparison, and persist a report artifact somewhere `fetch_drift_report` could then actually serve from — none of which exists as scaffolding today, not even a stubbed-out interface.)
- "This file has zero internal dependencies, unlike every other router. What does that tell you about its maturity relative to the rest of the codebase?" (It signals this is the least-developed feature area — there's no domain-layer module (`observability/` or similar) backing it at all, unlike every other router which delegates to real engines/services.)
