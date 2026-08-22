# File: `core/rate_limiter.py`

## Purpose
Configures SlowAPI's global rate limiter and exposes the reusable `limiter` object other modules can decorate routes with.

## Responsibilities
- Create one `Limiter` instance keyed by client IP address.
- Set global default rate limits.
- Wire the limiter and its exception handler into the FastAPI app.

## Imports
| Import | Used for |
|---|---|
| `slowapi.Limiter, _rate_limit_exceeded_handler` | The rate-limiting engine and its default 429 response handler |
| `slowapi.util.get_remote_address` | The key function — identifies clients by IP |
| `slowapi.errors.RateLimitExceeded` | The exception type raised when a limit is hit |
| `fastapi.FastAPI` | Type hint for the `app` parameter |

## Exports
- **`limiter`** — the module-level `Limiter` instance, imported by `app.py` (for `app.state.limiter`, implicitly via `setup_rate_limiting`) and directly by anything wanting to use `@limiter.limit(...)` (currently only the dead-code inline route in `app.py`).
- **`setup_rate_limiting`** — the function `app.py` calls once at startup.

## Execution Flow
1. On import, `limiter = Limiter(key_func=get_remote_address, default_limits=["1000/day", "100/minute"])` is constructed immediately — cheap, no I/O.
2. `setup_rate_limiting(app)` is called once, by `app.py`, during app construction (not per-request) — it attaches the limiter to `app.state.limiter` and registers the exception handler.
3. Per-request, SlowAPI's internal middleware (activated implicitly once `app.state.limiter` is set and any route uses `@limiter.limit`, or via the default limits) checks the caller's IP against its in-memory counters.

## Functions (plain English)

### `setup_rate_limiting(app: FastAPI)`
In simple English: "Tell this FastAPI app which rate limiter to use, and tell it what to do when someone exceeds their limit — respond with the standard 'too many requests' error instead of crashing or ignoring it." This function has no return value; it mutates the `app` object it's given.

## Classes
None defined here — `Limiter` is a third-party class being instantiated, not subclassed.

## Interfaces
Not applicable in the formal sense. `get_remote_address` acts as a pluggable "key function" interface SlowAPI expects — any callable with the same signature (extracting an identity string from a request) could be substituted (e.g., to key by API key instead of IP).

## Hooks
`setup_rate_limiting` is effectively an app-configuration hook, called once during startup wiring in `app.py` — not a per-request hook itself, but it installs the pieces (`app.state.limiter`, the exception handler) that make per-request rate-limit hooks (`@limiter.limit(...)`) function.

## Utilities
None.

## Dependencies
`slowapi`, `fastapi`. No internal module dependencies.

## Side Effects
- Mutates the passed-in `app` object (`app.state.limiter = limiter`) — a side effect on shared application state.
- Registers a global exception handler on `app`, changing how `RateLimitExceeded` errors are presented to clients app-wide.
- The `limiter` object itself maintains **in-memory counters** per client IP — this is a stateful, mutating side effect that accumulates for the life of the process (SlowAPI's default in-memory storage, since no external backend like Redis is configured here).

## Performance Considerations
- In-memory rate-limit storage (the default, since no storage backend is configured) means limits are per-process — if the app were ever scaled to multiple worker processes or replicas, each would enforce its own independent limit rather than sharing one global counter, effectively multiplying the real allowed rate by the number of instances.
- `get_remote_address` keying means limits are trivially bypassed by anyone able to vary their apparent source IP, or conversely can over-throttle many legitimate users sitting behind the same NAT/proxy IP.
- The global default (`100/minute`) applies to every route unless overridden — cheap to check (an in-memory counter increment) but worth knowing it's uniformly applied.

## Possible Interview Questions
- "Why would rate limiting behave inconsistently if this app were horizontally scaled to multiple replicas?" (Because SlowAPI's default storage is in-memory and per-process — there's no shared Redis/external store configured, so each replica enforces its own independent counter.)
- "What's the practical effect of keying by `get_remote_address` in a deployment sitting behind a reverse proxy or load balancer?" (Without trusting/parsing `X-Forwarded-For`, every request might appear to come from the proxy's IP, meaning all clients share one rate-limit bucket — a common production gotcha.)
- "Why is `setup_rate_limiting` a separate function instead of just doing `app.state.limiter = limiter` directly in `app.py`?" (Encapsulates the wiring (limiter assignment + exception handler registration) as one unit, making it easy to call once from `app.py` without duplicating both lines, and keeps rate-limiting concerns fully contained to this file.)
