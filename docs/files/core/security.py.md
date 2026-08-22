# File: `core/security.py`

## Purpose
Implements API-key authentication as a reusable FastAPI dependency, attached to every protected router in `app.py`.

## Responsibilities
- Define the expected header name (`X-Vela-API-Key`).
- Reject requests missing the header (401).
- Reject requests with an incorrect key value (403).
- Return an identity token for successfully authenticated requests.

## Imports
| Import | Used for |
|---|---|
| `fastapi.Security, HTTPException, status` | Dependency-injection wrapper, error responses, standard HTTP status codes |
| `fastapi.security.api_key.APIKeyHeader` | Declares the expected header for OpenAPI docs and extraction |
| `logging` | Logs rejected key attempts |

## Exports
- **`validate_api_key`** â€” the async function imported by `app.py` and wrapped in `Depends(...)`.
- **`API_KEY_NAME`**, **`api_key_header`** â€” module-level constants, not typically imported elsewhere but technically importable.

## Execution Flow
This file has no meaningful "startup" flow beyond defining `api_key_header = APIKeyHeader(name=API_KEY_NAME, auto_error=False)` at import time (cheap, no I/O). All real logic runs per-request when FastAPI invokes `validate_api_key` as a dependency before a route handler executes.

## Functions (plain English)

### `validate_api_key(api_key_header: str = Security(api_key_header))`
In simple English: "Look at the `X-Vela-API-Key` header on the incoming request. If it's missing entirely, refuse with a 401 'you forgot to send a key' error. If it's present but doesn't exactly match the one hardcoded correct value, refuse with a 403 'that key is wrong' error. If it matches, let the request through and hand back a fixed identity string." Note this function does not check the value against the application's configured `Vela_API_KEY` setting â€” it compares against a literal string written directly in the code, so changing the configured key has no effect on what's actually accepted (see `docs/16-known-issues-tech-debt.md`).

## Classes
None â€” no classes defined here; `APIKeyHeader` is a third-party class being instantiated, not subclassed.

## Interfaces
`APIKeyHeader(auto_error=False)` is FastAPI's built-in security-scheme abstraction â€” using it (rather than manually reading `request.headers`) means the `X-Vela-API-Key` requirement is automatically documented in the generated OpenAPI schema (`/docs`), which is the main benefit of using this construct over a plain header lookup.

## Hooks
`validate_api_key` is itself a FastAPI dependency-injection hook â€” it doesn't run as a decorator on a route directly, but is passed via `dependencies=[Depends(validate_api_key)]` at `app.include_router(...)` time in `app.py`, meaning it runs before every request to any route in that router, regardless of which specific endpoint is called.

## Utilities
None.

## Dependencies
`fastapi` only. No internal module dependencies (notably, it does **not** import `core.config.settings`, which is the root cause of the hardcoded-key issue).

## Side Effects
- Logs a warning (`logger.warning(...)`) on every rejected (wrong-key) attempt â€” this is the only side effect; missing-header rejections are not logged.
- Raises HTTP exceptions, which FastAPI converts into error responses â€” a side effect on the response stream, not on any external system.

## Performance Considerations
Trivial â€” a single string comparison per request. No I/O, no database lookups (the docstring's claim of routing through Redis "in production" is aspirational and not implemented), so this adds negligible latency regardless of request volume.

## Possible Interview Questions
- "Walk me through exactly why rotating `Vela_API_KEY` in `.env` doesn't change what key is accepted." (`validate_api_key` never reads `settings.Vela_API_KEY` at all â€” it compares against the hardcoded literal `"Vela_test_key_123"`. This is the single fix that would matter most for real-world security here.)
- "Why does this function return a value (`\"developer_id_789\"`) at all, given none of its callers use `Depends()` bound to a parameter to actually receive it?" (Likely written anticipating future per-caller identity resolution â€” currently the return value is computed but discarded since every router attaches this via `dependencies=[...]`, not a bound parameter.)
- "Why `auto_error=False` on `APIKeyHeader` instead of the default `True`?" (`auto_error=True` would raise FastAPI's default, less-specific 403 automatically on a missing header; `auto_error=False` lets this function distinguish 'missing' (401) from 'wrong' (403) with custom messages, which is exactly what it does.)
- "How would you add per-client rate limiting or usage tracking on top of this, given the function currently returns a static identity for every valid caller?" (You'd need real key-to-identity resolution â€” e.g., a lookup table or database of valid keys mapped to distinct identities â€” since right now every successful call is indistinguishable from any other.)

