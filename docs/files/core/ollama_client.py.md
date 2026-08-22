# File: `core/ollama_client.py`

## Purpose
Resolves, once at import time, which Ollama server the application should talk to (supporting both a single fixed host and a failover list), and exposes the resolved host plus model names as importable constants.

## Responsibilities
- Prefer a single configured `OLLAMA_URI` if present.
- Otherwise, try each host in `OLLAMA_HOSTS` in order and use the first one that responds successfully.
- Fail loudly if no host is configured or none respond.
- Re-export `EMBED_MODEL`/`LLM_MODEL` as plain constants for convenience.

## Imports
| Import | Used for |
|---|---|
| `httpx` | Synchronous HTTP client used for the health-check GET requests during resolution |
| `logging` | Logs which host was resolved, and warnings/errors for failed hosts |
| `core.config.settings` | Source of `OLLAMA_URI`, `ollama_hosts_list`, `EMBED_MODEL`, `LLM_MODEL` |

## Exports
- **`resolve_ollama_host`** — the resolution function itself (importable, though nothing else in the codebase calls it directly — it's invoked once, internally, to compute the module-level constant).
- **`OLLAMA_HOST`** — the resolved base URL string; imported by `rag/generator.py` and `embeddings/generate_embeddings.py`.
- **`EMBED_MODEL`**, **`LLM_MODEL`** — plain string constants re-exported from `settings`, imported by the same two consumers.

## Execution Flow
1. On import, `resolve_ollama_host` is *defined* first (no execution yet).
2. Then, module-level code runs immediately: `OLLAMA_HOST = settings.OLLAMA_URI if settings.OLLAMA_URI else resolve_ollama_host(settings.ollama_hosts_list)`.
3. If `OLLAMA_URI` is set, resolution is instant — no network calls.
4. If not, `resolve_ollama_host` runs synchronously, making real HTTP GET requests (2s timeout each) to every host in the list, in order, stopping at the first `200` response.
5. If the list is empty, or every host fails, a `RuntimeError` is raised **immediately at import time** — this propagates up through whatever import chain triggered it (e.g., `app.py → routers.rag → rag.generator → core.ollama_client`), potentially crashing the whole application before it can start.
6. Finally, `EMBED_MODEL = settings.EMBED_MODEL` and `LLM_MODEL = settings.LLM_MODEL` are assigned.

## Functions (plain English)

### `resolve_ollama_host(hosts: list[str]) -> str`
In simple English: "Given a list of candidate server addresses, go through them one at a time. For each one, try to reach it with a quick (2 second) request. The moment one responds successfully, stop and use that one. If the list was empty to begin with, or if I tried every single one and none of them worked, give up and raise an error instead of guessing." This function does real, blocking network I/O — it is not async, and it can take up to `2 seconds × number of hosts` in the worst case (all but the last host being down) before either succeeding or exhausting the list.

## Classes
None.

## Interfaces
Not applicable — no formal interface, though `resolve_ollama_host`'s signature (`list[str] -> str`, raising on total failure) is a simple, predictable contract any caller could rely on.

## Hooks
Not applicable — no FastAPI-specific hooks. The "hook" here is really the import-time side effect itself: any module importing this file implicitly triggers host resolution as a side effect of the import statement, which is an unusual (and somewhat risky) pattern worth being aware of.

## Utilities
`resolve_ollama_host` is itself best described as a utility function — the whole file is essentially one utility plus the constants it's used to compute.

## Dependencies
`httpx` (third-party), `core.config` (internal).

## Side Effects
- **Performs real network calls at import time** — the single most significant side effect in this file, and unusual compared to most modules, which limit I/O to explicit function calls at runtime.
- **Can raise an exception at import time**, which is a major side effect: it can prevent the entire application (or any script importing this module, directly or transitively) from starting at all if no Ollama host is reachable.
- Logs the resolved host on success, and a warning per failed host attempt.

## Performance Considerations
- Import-time resolution means this cost is paid exactly once per process lifetime (Python caches imported modules), not per request — good for steady-state performance, but it does mean the *first* import (typically at app startup) can be slow if early hosts in the failover list are down, since each failed attempt costs up to 2 seconds.
- Because resolution happens once and is cached as a plain string constant, the application has **no mechanism to notice if the resolved Ollama host later goes down and failover to another** — a host outage after startup would cause every subsequent request depending on `OLLAMA_HOST` to fail, with no automatic re-resolution.

## Possible Interview Questions
- "Why is this resolution done at import time instead of lazily, on first actual use?" (Fail-fast: if no Ollama host is reachable, you find out immediately at startup rather than on the first user request — arguably a deliberate trade-off, though it means unrelated tooling that imports this module transitively also pays this cost and risk.)
- "What happens if the resolved host goes down 10 minutes after startup?" (Nothing re-resolves — `OLLAMA_HOST` is a fixed string computed once; every subsequent call using it would simply fail against a dead host until the process is restarted.)
- "Why use a synchronous `httpx.Client` here instead of the async client used everywhere else in the codebase (e.g., `embeddings/generate_embeddings.py`)?" (This resolution happens at module-import time, outside of any running event loop, so a synchronous client is actually the correct and simplest choice here — using `httpx.AsyncClient` would require an event loop already running, which doesn't exist yet at plain Python import time.)
- "How would you make Ollama host selection more resilient — e.g., handle a mid-request failure by trying a different host?" (You'd need to move resolution out of this import-time pattern and into a per-request or periodically-refreshed mechanism, likely with retry/circuit-breaker logic around each actual API call in `rag/generator.py` and `embeddings/generate_embeddings.py`.)
