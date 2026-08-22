# Vela API â€” Complete Endpoint Reference

Every HTTP endpoint the codebase defines, one page each, with full request/response contracts, internal execution flow, and the exact controller/service/database chain each request travels through. This is the ground-truth companion to [02 Â· API Reference](../02-api-reference.md) (which covers the API as a whole) â€” this section drills into each individual endpoint at maximum depth.

**Base URL**: depends on how the server was started â€” `http://localhost:8000` (Dockerfile/dev default), `http://localhost:9850` (`docker-compose_local.yaml`'s exposed port), or `http://localhost:8080` (README's manual instructions and `scripts/test_pipeline.sh`'s default). There is no single canonical value in this codebase â€” confirm which one applies to your running instance.

**Authentication**: unless marked otherwise, every endpoint requires the header `X-Vela-API-Key`, checked against `settings.Vela_API_KEY` (`.env`) using a constant-time comparison â€” previously this compared against a hardcoded literal regardless of configuration, fixed, see [16 Â· Known Issues](../16-known-issues-tech-debt.md).

> **Note on currency**: the individual endpoint pages below were written against an earlier snapshot of the codebase and may still describe bugs that have since been fixed (e.g. `POST /v1/categorize` failing, `POST /v1/feedback/` being unreachable). [`docs/16-known-issues-tech-debt.md`](../16-known-issues-tech-debt.md) is the current source of truth; the new `/v1/pipelines/*` endpoints (see [02 Â· API Reference Â§2.9](../02-api-reference.md#29-batch-pipelines-routerspipelinespy-prefix-v1pipelines)) don't have individual pages here yet.

## Endpoint index

| Method | Path | Status | Doc |
|---|---|---|---|
| GET | `/health` | âœ… Working, no auth | [get-health.md](./get-health.md) |
| GET | `/metrics` | âœ… Working, no auth | [get-metrics.md](./get-metrics.md) |
| POST | `/v1/categorize` | ðŸ”´ Broken (500 on every call) | [post-v1-categorize.md](./post-v1-categorize.md) |
| POST | `/v1/resolve` | âœ… Working | [post-v1-resolve.md](./post-v1-resolve.md) |
| POST | `/v1/confidence/evaluate` | âœ… Working | [post-v1-confidence-evaluate.md](./post-v1-confidence-evaluate.md) |
| POST | `/memory/update` | âœ… Working* | [post-memory-update.md](./post-memory-update.md) |
| GET | `/memory/profile/{canonical_name}` | âœ… Working* | [get-memory-profile.md](./get-memory-profile.md) |
| GET | `/memory/state/{canonical_name}` | âœ… Working* | [get-memory-state.md](./get-memory-state.md) |
| GET | `/v1/analytics/patterns/categories` | âœ… Working | [get-analytics-patterns-categories.md](./get-analytics-patterns-categories.md) |
| GET | `/v1/analytics/patterns/merchants` | âœ… Working | [get-analytics-patterns-merchants.md](./get-analytics-patterns-merchants.md) |
| GET | `/v1/analytics/subscriptions` | âš ï¸ Works, needs backfill | [get-analytics-subscriptions.md](./get-analytics-subscriptions.md) |
| GET | `/v1/analytics/trends/mom` | âš ï¸ Half-mocked | [get-analytics-trends-mom.md](./get-analytics-trends-mom.md) |
| POST | `/v1/analytics/anomaly/check` | âš ï¸ Works, needs backfill | [post-analytics-anomaly-check.md](./post-analytics-anomaly-check.md) |
| POST | `/v1/explain` | âœ… Working | [post-v1-explain.md](./post-v1-explain.md) |
| POST | `/v1/observability/drift/analyze` | âš ï¸ Stub, no-op | [post-observability-drift-analyze.md](./post-observability-drift-analyze.md) |
| GET | `/v1/observability/reports/latest` | âš ï¸ Stub, always 404 | [get-observability-reports-latest.md](./get-observability-reports-latest.md) |
| POST | `/v1/feedback/` | ðŸ”´ Unreachable (unmounted) | [post-v1-feedback.md](./post-v1-feedback.md) |

`*` = works, but currently blocked at import time by the `repositories/profile_repository.py` missing-`Optional`-import bug â€” see [16 Â· Known Issues](../16-known-issues-tech-debt.md#profile-repository-missing-import). Fixing that one-line bug is a prerequisite for this whole router functioning at all.

## Status legend
- âœ… **Working** â€” functions correctly end-to-end as implemented.
- âš ï¸ **Works, needs backfill / half-mocked / stub** â€” the endpoint itself runs without error, but its output is degenerate, partially fake, or a no-op until a dependency (usually `behaviour/behavior_engine.py`, never auto-invoked) is populated, or because the underlying logic is an acknowledged placeholder.
- ðŸ”´ **Broken / Unreachable** â€” the endpoint either throws an unhandled exception on every call, or cannot be reached over HTTP at all in the current build.

## Note on the duplicate `/v1/categorize` route
There are two handlers for `POST /v1/categorize` in the codebase: the real one in `routers/v1.py` and a dead-code stub registered inline in `app.py`. Because `app.py` includes `routers.v1`'s router *before* declaring the inline stub, the router's handler wins the route match and is what a real client actually hits â€” see [post-v1-categorize.md](./post-v1-categorize.md) for the full detail. The inline stub is not documented as a separate endpoint here since it is never actually reachable.

