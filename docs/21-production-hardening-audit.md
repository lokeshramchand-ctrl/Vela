# 21 Â· Production Hardening & Security Audit

This document records a full pre-production security/reliability/operability audit of the Vela backend, performed under the assumption that this service handles real financial data and will face hostile internet traffic. It follows on from [16 Â· Known Issues & Tech Debt](./16-known-issues-tech-debt.md), which already fixed every functional bug found in an earlier pass â€” this audit assumes that pass is done and focuses on hardening, not correctness bugs.

Every finding below was verified, not assumed: the full test suite was run after each meaningful change, the Docker image was actually built and run end-to-end against a real MongoDB, `ruff` and `pip-audit` were run to completion, and two real regressions were caught and fixed *during this audit* by that verification discipline (see Â§9).

## 1. Security issues found (and fixed)

| # | Finding | Severity | Fix |
|---|---|---|---|
| 1 | No `max_length`/`min_length` on any free-text request field (`CategorizeRequest.text`, `ExplainRequest.transaction_text`, `MemoryUpdateRequest`, `FeedbackRequest`, `MerchantRequest`, etc.) | High (CWE-400, uncontrolled resource consumption) | Added explicit bounds to every Pydantic input field and path/query parameter across `models/schemas.py`, `routers/v1.py`, `routers/memory.py`, `routers/rag.py`, `routers/pipelines.py`, `feedback/api_router.py`. Verified: a 2MB `text` payload now returns `413` before parsing; a 3000-char `text` (over the 2000 limit) returns `422`. |
| 2 | No request body size cap at all (Content-Length or streamed) | High (CWE-400) | New `BodySizeLimitMiddleware` (`core/middleware.py`) rejects (413) both a declared oversized `Content-Length` *before* reading the body, and a running byte count during streaming (covers chunked transfer-encoding, which has no Content-Length to check). Verified against a real 2MB payload. |
| 3 | `logging.basicConfig(level=logging.DEBUG)` unconditionally, in every environment | High (CWE-532, information exposure through logs) | Confirmed DEBUG level logs full pymongo command payloads - real transaction amounts, merchants, user ids - into logs. Log level is now `Settings.LOG_LEVEL` (default `INFO`), only escalated to DEBUG as a deliberate opt-in. |
| 4 | `/health` (unauthenticated) returned raw `str(exception)` for Mongo/Milvus/Ollama failures | Medium (CWE-209, information exposure through error message) | `_check_dependencies()` now returns a fixed, generic message ("...see server logs") on failure; the real exception is still logged server-side with `logger.exception(...)`. `/health`'s response *shape* is otherwise unchanged (backward compatible). |
| 5 | Hardcoded API key comparison, ignoring configured `Vela_API_KEY` (carried over from the prior fix pass, re-verified here) | Critical | Already fixed to read `settings.Vela_API_KEY`; this audit additionally replaced the `!=` comparison with `secrets.compare_digest` (constant-time), closing a timing side-channel `docs/17-senior-architect-review.md` had flagged. |
| 6 | Real concurrency race in `memory_manager.process_encounter`: read-then-write on `frequency` (lost updates under concurrent traffic for the same merchant), plus a check-then-insert race on a brand-new merchant (could produce duplicate profile documents) | High (CWE-362, race condition) | Replaced with a single atomic `find_one_and_update(..., upsert=True)` using `$inc`/`$setOnInsert` (`repositories/profile_repository.py::increment_encounter`), backed by a new unique index on `canonical_name` so any remaining insert race becomes a retried upsert, not a duplicate. Verified via the existing `test_memory_engine_lifecycle` (3-encounter promotion sequence still produces the exact same `EPHEMERAL -> TEMPORARY` transitions). |
| 7 | Zero MongoDB indexes anywhere in the codebase (confirmed by grep before this audit) | Medium (performance/DoS - every query is a collection scan) | `MongoDB.ensure_indexes()` (`database/mongo.py`), called once from `lifespan`, creates indexes on every field this app's actual query patterns hit: unique `merchant_profiles.canonical_name`, unique `behavior_patterns.merchant_name`, `transactions.{user_id,timestamp}` compound + `transactions.merchant`, `merchants.aliases`, `feedback.merchant_name`/`transaction_id`, `retraining_queue.status`. Wrapped so a permissions failure logs a warning instead of crashing startup. Verified: `MongoDB indexes ensured.` in logs on both local and containerized runs. |
| 8 | No security response headers | Low | New `SecurityHeadersMiddleware` adds `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy`, `Cross-Origin-Resource-Policy` to every response. Full CSP/HSTS deliberately left to the TLS-terminating reverse proxy in front of this service - this is a headless JSON API with no HTML rendering, so those headers belong at the edge, not here. Verified present on real responses. |
| 9 | `.env` not excluded from the Docker build context | High (secret leakage into image layers) | Added to `.dockerignore`, along with `*.pem`/`*.key` and the local scratch venv (`.venv-linux`, 1.4GB - was also a build-context bloat risk). |
| 10 | Both compose files bind-mounted the entire repo (`.:/app`) over the built image | High (defeats image reproducibility; also would have mounted the host's `.env` into the container) | `docker-compose_production.yaml` no longer bind-mounts anything - it runs exactly what was built into the image. `docker-compose_local.yaml` keeps the bind mount (that's the point, for local dev hot-reload) with an explicit comment explaining why production doesn't do the same. |
| 11 | No non-root Docker user, single-stage build, no HEALTHCHECK | Medium | See Â§6 (Docker). |
| 12 | Heavy/batch endpoints (`/v1/pipelines/*`, `/v1/explain`) had no tighter rate limit than the global default, despite being expensive (LLM calls, O(all data) batch jobs, CPU-heavy clustering) | Medium (resource-exhaustion DoS) | Added per-endpoint SlowAPI limits: `/v1/explain` 20/min, `/v1/pipelines/behavior/run` 30/min, `/behavior/run-all` \| `/embeddings/sync` \| `/decay/sweep` \| `/graph/build` 10/min, `/clustering/run` 5/min (the single most CPU-intensive operation in the app). |
| 13 | Inconsistent, framework-default error responses; unhandled exceptions could leak stack-trace-adjacent detail | Medium | Centralized exception handling (`core/error_handlers.py`) for `HTTPException`, `RequestValidationError`, and the catch-all `Exception` - every error response now shares one JSON envelope (`{"error": {"detail", "request_id", ...}}`), and an unhandled exception is always logged in full server-side but never returns more than a generic message + correlation id to the client. |

**Audited and confirmed NOT exploitable** (documented here since a security audit should say what it checked, not just what it found):
- **NoSQL injection**: every Mongo query built from user input either uses plain string equality (Pydantic's strict typing rejects a dict/operator payload where a `str` is expected, returning 422 before it ever reaches a query) or the one `$regex` query in `merchant_resolver.py`, which is fed only alphanumeric-stripped text (verified in the prior audit pass, re-confirmed here).
- **SSRF**: no endpoint accepts a user-supplied URL to fetch; Ollama/Milvus/Mongo hosts are all operator-configured, never user input.
- **Command/path injection, insecure deserialization**: no `subprocess`/`os.system`/`eval`/`exec`/`pickle.load`/`yaml.load` calls anywhere in the codebase (grepped).
- **Hardcoded secrets**: none found via grep for common secret-assignment patterns; `.env` is gitignored.

## 2. Reliability improvements

- Fixed the concurrency race described in Â§1.6 - the single most impactful reliability fix, since it could silently corrupt trust-state data under real concurrent traffic.
- MongoDB client now has explicit `serverSelectionTimeoutMS`/`connectTimeoutMS` (both configurable, default 5s) instead of driver defaults - a dead Mongo now fails fast and predictably rather than hanging a request for an unbounded/default period.
- `/live` and `/ready` added alongside the existing `/health`, following standard liveness/readiness convention: liveness never touches a dependency (a hung Mongo/Milvus/Ollama should never trigger a container restart-loop that can't fix the actual problem), readiness gates on the one hard dependency (Mongo) that every write path needs.
- Centralized exception handling means an unhandled exception anywhere now degrades to a clean `500` with a correlation id instead of an unpredictable framework-default response.

## 3. Performance improvements

- MongoDB indexes (Â§1.7) turn every actively-queried field from a collection scan into an index seek - the single highest-leverage performance fix available, given the app had zero indexes before this audit.
- The atomic `find_one_and_update` fix (Â§1.6) also removes an extra round-trip: the old code did a `find_one` then a separate `update_one`; the new code does one operation.

## 4. Scalability improvements

- Per-endpoint rate limits on the batch/heavy endpoints (Â§1.12) mean one client can no longer monopolize the CPU-heavy clustering pipeline or hammer the Ollama-calling embedding-sync loop at unbounded frequency.
- Docker resource limits (`deploy.resources.limits/reservations` in `docker-compose_production.yaml`) bound how much CPU/memory a single container instance can consume, protecting co-located workloads on the same host.
- The image is meaningfully smaller (Â§6), which matters directly for horizontal-scaling speed (faster pull/start on new nodes).

## 5. Observability improvements

- `RequestIDMiddleware` (`core/middleware.py`): every request gets a correlation id (reusing an inbound `X-Request-ID` if a proxy already set one), echoed back as a response header and included in every error response and every "unhandled exception" log line - so a client-reported failure can be matched to the exact server-side log entry.
- Log level is now configurable (`LOG_LEVEL`, default `INFO`) instead of hardcoded `DEBUG` - see Â§1.3.
- `/live` and `/ready` give an orchestrator (Kubernetes, Coolify, etc.) the standard two-endpoint health-check contract instead of one conflated `/health`.
- Docker `HEALTHCHECK` talks to `/live` specifically, so a dependency outage doesn't also make Docker think the *process* is unhealthy and restart it.

## 6. Docker improvements

- **Multi-stage build**: a `builder` stage installs dependencies (with build tools) into `/install`; the `runtime` stage copies only the installed packages, discarding build tools, pip's cache, and any sdist build artifacts.
- **Non-root user**: the app now runs as an unprivileged `Vela` system user (verified: `docker run ... id` reports `uid=999(Vela)`), not root.
- **HEALTHCHECK**: added, polling `/live` every 30s. Verified: `docker inspect` reports `"Status":"healthy"` after startup.
- **`.dockerignore`**: now excludes `.env`, `*.pem`/`*.key`, the local dev venvs, `.git`, docs, and the local-only compose files - shrinking the build context and closing the secret-leak risk from Â§1.9.
- **Compose hardening**: `security_opt: [no-new-privileges:true]` and `cap_drop: [ALL]` on both compose files; resource limits and the bind-mount fix (Â§1.10) on the production file specifically.
- **Image size**: reduced from what it would have been with the full dependency list (including `torch`/`transformers`/`peft`/`datasets`, multi-GB) to ~256MB compressed / ~1.1GB uncompressed, by moving the offline-training-only dependencies to a separate file (Â§8) that the Dockerfile never installs.
- Base image kept at `python:3.12-slim` rather than switching to Alpine: Alpine's musl libc has known compatibility friction with scientific-Python wheels (`scikit-learn`, `numpy`, `umap-learn`) that this app's clustering endpoint genuinely needs at runtime - `slim` is the correct tradeoff here, not a missed optimization.
- **Verified end-to-end**: built the image, ran it against a real MongoDB with `docker run`, confirmed `/live`, `/v1/categorize` (full DB round-trip), `/metrics`, and `/health` all work correctly inside the container, and that the Docker healthcheck reports `healthy`.

## 7. CI/CD improvements

No CI/CD existed before this audit (confirmed: no `.github/`, no other CI config anywhere in the repo). Added:
- **`.github/workflows/ci.yml`**: five jobs - `secret-scan` (gitleaks), `lint` (ruff), `dependency-scan` (pip-audit against both requirement files), `test` (pytest against a real MongoDB service container, mirroring exactly how `test_api.py` exercises the app), and `docker` (Dockerfile lint via hadolint, image build, Trivy vulnerability scan - informational/non-blocking for now, since this is the first CI pass and severity triage hasn't happened yet).
- **`.pre-commit-config.yaml`**: ruff (with `--fix`), trailing-whitespace/end-of-file/large-file/private-key/merge-conflict hygiene hooks, and gitleaks - catches secrets and style issues before they're even committed, not just in CI.
- **`pyproject.toml`**: `[tool.ruff]` config (security-relevant `S` (bandit) and `B` (bugbear) rule sets enabled, not just style) and `[tool.pytest.ini_options]`.

## 8. Dependencies updated

Ran `pip-audit` against the full dependency set; found and fixed real vulnerabilities - and, in fixing them, caught two genuine regressions purely by re-running the verification suite (documented in detail in Â§9, since "found a CVE, bumped a pin" is the easy 90% and "the bump broke something else" is the part that actually matters):

| Package | Before | After | Why |
|---|---|---|---|
| `fastapi` | 0.115.6 | 0.140.13 | Pulls in a patched `starlette` (was 0.41.3, landed on 1.3.1), closing 7 separate CVEs (`PYSEC-2026-161/248/249/1941/1942/2280/2281`) that only existed transitively - `starlette` was never pinned directly, so the correct fix is upgrading the package that governs its version bound, not force-pinning it against an untested `fastapi` version. |
| `pytest` | 8.3.4 | 9.1.1 | `PYSEC-2026-1845`, fixed starting in 9.0.3. Dev/test-only dependency, not shipped in the production image. |
| `setuptools` | (implicit) | 83.0.0 (explicit) | Pinned explicitly (wasn't before) because an isolated multi-stage `pip install --prefix` doesn't reliably bring it in, and `pymilvus<2.6` needs `pkg_resources` from it at import time. Patches `PYSEC-2025-49` / `PYSEC-2026-3447`. |
| `pymilvus` | 2.5.3 | 2.6.17 | Required by the `setuptools` bump above: `setuptools>=83` **removed** the `pkg_resources` module entirely (discovered by actually testing the combination, not assumed), which `pymilvus<2.6` imports at module load. 2.6.17 dropped that dependency, so the real dependency (not a workaround) is upgraded. |
| `prometheus-fastapi-instrumentator` | 7.0.0 | 8.1.0 | 7.0.0's internal Starlette route-name lookup (`route.path` on an internal `_IncludedRouter` object) breaks under the Starlette version pulled in by the `fastapi` bump above - `AttributeError: '_IncludedRouter' object has no attribute 'path'`. Caught by re-running the full test suite after the `fastapi` bump (13 of 15 tests failed), not assumed compatible. |

**Separated production and training dependencies**: `torch`, `transformers`, `peft`, `datasets`, `pandas`, `lightgbm`, `xgboost`, `shap`, `tabulate` were all in the single production `requirements.txt` despite being used exclusively by `training/train.py` and `training/finetune.py` - neither of which is ever imported by the live app (confirmed by grep: `app.py`'s import graph never touches `training/` or `evaluation/`). Moved to a new `requirements-training.txt`. The Dockerfile only installs `requirements.txt`. This is a genuine attack-surface reduction, not just a size optimization: every one of those packages was previously part of the deployed image's CVE-scanning surface for code that never runs in production.

## 9. Verification results

Every change in this audit was verified, not assumed - and verification caught real problems, which is the entire point of doing it:

- **`ruff check .`** â†’ `All checks passed!` (started at 387 findings; 368 auto-fixed safely, 19 addressed manually - `zip(..., strict=True)`, `raise ... from e`, dead-variable removal, an intentional `noqa` for the `0.0.0.0` bind address which is correct for a containerized service, and two items deliberately left alone with a documented reason: `StrEnum` migration - real behavior-change risk for enums that flow through Pydantic/Mongo serialization everywhere - and `S311` non-crypto `random` usage in test/mock-seeding code, which isn't a security-sensitive context).
- **`pip-audit -r requirements.txt`** â†’ `No known vulnerabilities found` (started at 14 known vulnerabilities across 3 packages).
- **Full module import sweep**: all 48 non-training modules import cleanly (training modules require `torch`, deliberately not installed in the verification environment - see Â§8).
- **`pytest test_api.py`**: all 15 tests pass, run repeatedly after each meaningful change (env-var/index changes, the concurrency-fix rewrite, the dependency bumps, the lint auto-fix pass) - not just once at the end.
- **Docker build + run, end-to-end, against a real MongoDB**: built the final image, ran it with `docker run`, confirmed `/live`, `/health`, and a real `/v1/categorize` request (full DB round-trip, real `transaction_id` returned) all work, confirmed `/metrics` (the endpoint the `prometheus-fastapi-instrumentator` regression would have broken) actually serves Prometheus text output, and confirmed Docker's own `HEALTHCHECK` reports the container `healthy`.
- **Two real regressions were caught by this verification discipline, not by inspection**: the `fastapi` upgrade silently broke `prometheus-fastapi-instrumentator` (only surfaced when the test suite was re-run), and the `setuptools` CVE fix silently broke `pymilvus`'s import (only surfaced when the actual Docker image was built and run). Both are documented in Â§8 with the exact error and fix.

## 10. Remaining risks (not fixed here, and why)

- **No per-caller authorization** - every request bearing the single shared `Vela_API_KEY` gets identical, undifferentiated access to all data and all admin/batch endpoints. Fixing this is a real feature (multi-tenancy, per-key scoping), not a hardening tweak, and was already on the pre-existing roadmap in `docs/16-known-issues-tech-debt.md` Â§16.5.
- **Retraining queue has no executor** and **training pipelines run on synthetic data** - both require standing up a task queue (Celery + broker) and a real MongoDB-backed training-data pipeline respectively; unchanged from the prior audit's findings.
- **Observability endpoints are stubs** (no real Evidently AI/MLflow integration) - unchanged; requires standing up that infrastructure.
- **No caching layer** - not added here; nothing in the current traffic pattern demonstrably needs one yet, and adding a cache without a measured hot path would be premature complexity.
- **The Trivy image scan in CI is non-blocking** (`exit-code: "0"`) - deliberately, since this is the *first* time this image has been scanned and any findings need human triage before the build is allowed to hard-fail on them. Flip to `exit-code: "1"` once that triage has happened.
- **Docker resource limits are starting defaults, not tuned** - `cpus: "2.0"`/`memory: 2g` in `docker-compose_production.yaml` are reasonable guesses, not measured against real production load.
- **`deploy.resources` requires Docker Compose V2** - the legacy standalone `docker-compose` v1 binary ignores it outside Swarm mode; documented inline in the compose file.
- **Git history still contains a previously-committed MongoDB credential** (from before this audit, in `docker-compose_production.yaml`'s history) - removing it from the current file (already done in the prior fix pass) does not undo its exposure. **This requires the repo owner to rotate that credential on the actual MongoDB server** - it cannot be fixed from inside this repository.

## 11. Recommended future improvements

1. Stand up a task queue (Celery + broker) and wire the retraining executor and a real scheduler for `/v1/pipelines/*` to it, instead of manual triggering.
2. Build a real MongoDB-backed training-data assembly pipeline for `training/train.py`/`training/finetune.py`.
3. Real multi-tenancy: per-caller API keys with actual scoping, replacing the single shared secret.
4. Wire real Evidently AI/MLflow observability instead of the current stubs.
5. Tune Docker resource limits against real measured production load rather than the current starting defaults.
6. Flip the Trivy CI job to blocking once initial findings have been triaged.
7. Consider a caching layer once a real hot, repeated query pattern is measured (not before).
8. Add a LICENSE file - this is a decision for the repo owner (license choice has real legal implications), not something to auto-select.

