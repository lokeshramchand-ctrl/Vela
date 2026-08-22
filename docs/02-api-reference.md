# 02 Â· API Reference

All endpoints are served by the single FastAPI app defined in `app.py`. Base path prefixes come from each `APIRouter(prefix=...)` declaration; there is no global `/api` prefix.

**Authentication**: unless noted otherwise, every endpoint requires the header `X-Vela-API-Key`, checked against `settings.Vela_API_KEY` (see `core/security.py`). A subset of endpoints â€” marked **Both** in the table below â€” additionally require `Authorization: Bearer <access token>` (a JWT obtained from `POST /auth/login` or `/auth/refresh`), resolved to a specific `User` by `core/jwt_auth.py::get_current_user`. The API key authenticates the calling application; the JWT authenticates the end user within it. Full detail in [22 Â· Authentication](./22-authentication.md).

## 2.1 Endpoint index

| Method | Path | Router | Auth | Rate limit | Purpose |
|---|---|---|---|---|---|
| GET | `/health` | `app.py` | None | global (1000/day, 100/min) | Liveness + dependency status (Mongo, Milvus, Ollama) |
| GET | `/metrics` | `app.py` (Instrumentator) | None | global | Prometheus scrape endpoint |
| POST | `/auth/register` | `routers/auth.py` | API key | 5/min | Create a new user account |
| POST | `/auth/login` | `routers/auth.py` | API key | 10/min | Exchange email + password for an access/refresh token pair |
| POST | `/auth/refresh` | `routers/auth.py` | API key | 20/min | Rotate a refresh token for a new access/refresh pair |
| POST | `/auth/logout` | `routers/auth.py` | API key | 20/min | Revoke a refresh token |
| GET | `/users/me` | `routers/users.py` | Both | global | Fetch the calling user's own profile |
| PATCH | `/users/me` | `routers/users.py` | Both | global | Update editable profile fields (`full_name` only) |
| POST | `/statements/upload` | `routers/statements.py` | Both | 10/min | Upload a Google Pay statement PDF; returns `202` + `{statement_id, job_id}` |
| GET | `/statements` | `routers/statements.py` | Both | global | List the caller's statements (paginated, filterable, sortable) |
| GET | `/statements/{id}` | `routers/statements.py` | Both | global | Fetch one statement's metadata/status |
| DELETE | `/statements/{id}` | `routers/statements.py` | Both | global | Delete a statement, cascading its transactions, job history, and stored PDF |
| GET | `/statements/{id}/transactions` | `routers/statements.py` | Both | global | List a statement's transactions (paginated, filterable, sortable) |
| GET | `/statements/{id}/analytics` | `routers/statements.py` | Both | global | Read the statement's precomputed analytics |
| GET | `/statements/{id}/insights` | `routers/statements.py` | Both | global | Read the statement's precomputed AI insights |
| GET | `/jobs/{id}` | `routers/jobs.py` | Both | global | Poll a background job's status/progress/error |
| POST | `/v1/categorize` | `routers/v1.py` | Both | 50/min | Rule-engine categorize + persist (attributed to the caller); returns `transaction_id` |
| POST | `/v1/resolve` | `routers/v1.py` | API key | global | Resolve noisy bank text to canonical merchant |
| POST | `/v1/confidence/evaluate` | `routers/v1.py` | API key | global | Apply the confidence wall to an upstream prediction |
| POST | `/memory/update` | `routers/memory.py` | API key | global | Record an entity encounter, run state machine |
| GET | `/memory/profile/{canonical_name}` | `routers/memory.py` | API key | global | Fetch full merchant memory profile |
| GET | `/memory/state/{canonical_name}` | `routers/memory.py` | API key | global | Fetch just memory state + frequency |
| GET | `/v1/analytics/patterns/categories` | `routers/analytics.py` | Both | global | Spend breakdown by category over a lookback window, scoped to the caller |
| GET | `/v1/analytics/patterns/merchants` | `routers/analytics.py` | Both | global | Top merchants by visit frequency, scoped to the caller |
| GET | `/v1/analytics/subscriptions` | `routers/analytics.py` | Both | global | Detected recurring subscriptions + monthly burn, scoped to the caller |
| GET | `/v1/analytics/trends/mom` | `routers/analytics.py` | Both | global | Month-over-month spend growth, scoped to the caller |
| POST | `/v1/analytics/anomaly/check` | `routers/analytics.py` | API key | global | Z-score anomaly check for a transaction amount (merchant-global, not user-scoped) |
| POST | `/v1/explain` | `routers/rag.py` | API key | global | Grounded RAG explanation of a transaction |
| POST | `/v1/feedback/` | `feedback/api_router.py` | Both | global | Submit human correction feedback (attributed to the caller); joins back to `merchant_name` |
| POST | `/v1/pipelines/behavior/run`, `/run-all` | `routers/pipelines.py` | API key | global | Phase 6 behavior profiling (single merchant / all) |
| POST | `/v1/pipelines/embeddings/sync` | `routers/pipelines.py` | API key | global | Phase 7 embedding generation + Milvus write |
| POST | `/v1/pipelines/decay/sweep` | `routers/pipelines.py` | API key | global | Phase 4 180-day archival sweep |
| POST | `/v1/pipelines/graph/build` | `routers/pipelines.py` | API key | global | Phase 13 knowledge graph rebuild |
| GET | `/v1/pipelines/graph/neighborhood/{merchant_name}` | `routers/pipelines.py` | API key | global | Ego-graph around a merchant |
| POST | `/v1/pipelines/clustering/run` | `routers/pipelines.py` | API key | global | Phase 8 UMAP + HDBSCAN discovery pipeline |
| POST | `/v1/observability/drift/analyze` | `routers/observability.py` | API key | global | Stub: "triggers" drift analysis |
| GET | `/v1/observability/reports/latest` | `routers/observability.py` | API key | global | Stub: always 404, no report generation exists |

> **Previously** there were two `POST /v1/categorize` routes â€” the real implementation in `routers/v1.py` and a dead inline stub in `app.py` that carried the intended `50/min` rate limit. The stub is removed and its rate limit now lives on the real handler (see [Known Issues Â§16.3](./16-known-issues-tech-debt.md#163-medium-previously-disconnected-features-dead-code-silent-no-ops--fixed)).

## 2.2 System endpoints

### `GET /health`
No auth required. Pings MongoDB (`admin.command("ping")`), checks whether the Milvus client object is non-null, and does an HTTP GET against `settings.OLLAMA_URI` with a 2s timeout.

Response `200`:
```json
{
  "status": "healthy | degraded",
  "services": { "mongodb": "connected|disconnected|error", "milvus": "connected|disconnected|error", "ollama": "connected|degraded|error" },
  "details": { "mongodb": "...", "milvus": "...", "ollama": "..." }
}
```
`status` is `"healthy"` only if all three sub-statuses equal `"connected"`; otherwise `"degraded"`. This endpoint never returns a non-200 status code itself â€” failures are reported in the body.

### `GET /metrics`
Standard Prometheus text exposition format, auto-generated by `prometheus_fastapi_instrumentator`. No custom metrics are defined anywhere in the codebase â€” only the instrumentator's defaults (request count, latency histograms, etc.) are present.

## 2.3 Authentication (`routers/auth.py`, prefix `/auth`)

Full design detail â€” token lifecycle, rotation, password hashing â€” in [22 Â· Authentication](./22-authentication.md). Request/response contracts:

### `POST /auth/register`
**Request** (`RegisterRequest`): `{ "email": "user@example.com", "password": "at-least-8-chars" }` â€” `email` is lowercased before storage/lookup, `password` must be 8â€“128 characters.
**Response** `201` (`UserPublic`): `{ "id": "...", "email": "user@example.com", "is_active": true, "created_at": "2026-01-01T00:00:00Z" }` â€” never includes the password hash.
**Errors**: `409` if the email is already registered.

### `POST /auth/login`
**Request** (`LoginRequest`): `{ "email": "...", "password": "..." }`.
**Response** `200` (`TokenResponse`): `{ "access_token": "...", "refresh_token": "...", "token_type": "bearer", "expires_in": 900 }`.
**Errors**: `401` for any invalid email/password combination â€” deliberately the same message whether the email doesn't exist or the password is wrong. `403` if the account has been disabled.

### `POST /auth/refresh`
**Request** (`RefreshRequest`): `{ "refresh_token": "..." }`.
**Response** `200` (`TokenResponse`): a brand-new access/refresh pair; the presented refresh token is revoked in the same call (rotation â€” it's single-use).
**Errors**: `401` if the token is unknown, expired, or already-used (reuse of an already-rotated token also revokes every other active session for that user).

### `POST /auth/logout`
**Request** (`LogoutRequest`): `{ "refresh_token": "..." }`.
**Response**: `204 No Content`. Idempotent â€” revoking an unknown or already-revoked token is a no-op, not an error. Works even if the caller's access token has already expired.

## 2.4 Users (`routers/users.py`, prefix `/users`)

### `GET /users/me`
Requires both the API key and a valid `Authorization: Bearer <access token>`.
**Response** `200` (`UserPublic`): `{ "id", "email", "full_name", "is_active", "created_at" }`.
**Errors**: `401` (missing/expired/malformed/wrong-signature token), `403` (account disabled).

### `PATCH /users/me`
**Request** (`UpdateUserRequest`): `{ "full_name": "Jane Doe" }`. `full_name` is the only editable field â€” email changes aren't supported (that's a bigger reverification flow, not implemented).
**Response** `200` (`UserPublic`): the updated profile.

## 2.5 Statements (`routers/statements.py`, prefix `/statements`)

Full pipeline detail â€” the real Google Pay statement format, processing stages, and AI/analytics engine reuse â€” in [23 Â· Statement Ingestion Pipeline](./23-statements-pipeline.md). Every endpoint here requires both the API key and a JWT, and 404s (not 403) for a statement that doesn't exist or belongs to another user.

### `POST /statements/upload`
**Request**: `multipart/form-data` with fields `file` (a Google Pay "Transaction statement" PDF) and optional `password`.
**Response** `202` (`StatementUploadResponse`): `{ "statement_id": "...", "job_id": "...", "status": "PENDING" }`. Processing continues in the background â€” poll `GET /jobs/{job_id}`.
**Errors**:
- `422` â€” not a PDF, a corrupted/truncated PDF, missing/incorrect password for an encrypted PDF, or a PDF that doesn't match the known Google Pay statement signature.
- `413` â€” exceeds `MAX_STATEMENT_PDF_BYTES` (10 MB default).

### `GET /statements`
**Query params**: `page` (default 1), `page_size` (default 20, max 100), `processing_status` (`PENDING`\|`PROCESSING`\|`COMPLETED`\|`FAILED`), `sort_by` (default `uploaded_at`), `sort_order` (`asc`\|`desc`, default `desc`).
**Response** `200` (`StatementListResponse`): `{ "items": [StatementResponse, ...], "page", "page_size", "total", "total_pages" }`.

### `GET /statements/{id}`
**Response** `200` (`StatementResponse`): filename, size, page count, `period_start`/`period_end`, declared vs. computed Sent/Received totals, `reconciliation_ok`, `transaction_count`, `processing_status`, `current_job_id`, timing. See [03 Â· Data Model](./03-data-model.md#statement) for every field.
**Errors**: `404` if not found or not owned by the caller.

### `DELETE /statements/{id}`
**Response**: `204 No Content`. Cascades: every transaction with this `statement_id`, its job history, and its retained GridFS PDF. Does **not** touch `behavior_patterns`/Milvus vectors (shared, cross-statement knowledge).

### `GET /statements/{id}/transactions`
**Query params**: pagination (`page`, `page_size`) + `category`, `transaction_type` (`DEBIT`\|`CREDIT`), `merchant` (case-insensitive substring), `start_date`/`end_date` (ISO 8601), `sort_by` (default `timestamp`), `sort_order`.
**Response** `200` (`TransactionListResponse`): same pagination envelope as above, `items` are `TransactionResponse` (merchant, category, amount, `transaction_type`, `status`, `counterparty_raw`, `reference_number`, `bank`, `account_last4`, `payment_method`).

### `GET /statements/{id}/analytics`
**Response** `200` (`StatementAnalyticsResponse`): total spend/income/net, average transaction value, category breakdown, top merchants, daily trend, recurring payments, failed-transaction count. Reads the analytics computed once during job processing â€” no recomputation per request.
**Errors**: `409` if the statement hasn't finished processing yet (detail names the current status and job to poll).

### `GET /statements/{id}/insights`
**Response** `200` (`StatementInsightsResponse`): `{ "statement_id", "insights": [{ "type", "message", "severity" }, ...] }`. `insights` may legitimately be an empty list if Ollama was unreachable when the job ran â€” insight generation degrades gracefully rather than failing the statement.
**Errors**: `409`, same condition as analytics.

## 2.6 Jobs (`routers/jobs.py`, prefix `/jobs`)

### `GET /jobs/{id}`
**Response** `200` (`JobResponse`): `{ "id", "job_type", "resource_type", "resource_id", "status", "stage", "progress_percent", "error_message", "created_at", "started_at", "completed_at" }`. `status` is one of `QUEUED`\|`RUNNING`\|`COMPLETED`\|`FAILED`; `stage` is a human-readable progress label (e.g. `"generating_insights"`).
**Errors**: `404` if not found or not owned by the caller.

## 2.7 Transaction Intelligence (`routers/v1.py`, prefix `/v1`)

### `POST /v1/categorize`
**Request** (`CategorizeRequest`):
```json
{ "text": "paid 500 to swiggy" }
```
**Response** (`CategorizeResponse`):
```json
{ "merchant": "Swiggy", "category": "Food", "confidence": 0.95, "transaction_id": "666f6f2d6261722d71757578" }
```
Runs the rule engine against `payload.text`, persists the enriched transaction to `transactions`, and returns the resolved merchant/category/confidence plus the inserted document's `transaction_id` (a stringified Mongo `_id`) â€” pass this to `POST /v1/feedback/` to let feedback join back to a merchant. Rate-limited to 50/minute per caller. This previously raised `AttributeError` on every call (a `.get()` call on a Pydantic model, a `time.timezone.utc` typo, and placeholder object references written to Mongo instead of resolved values) â€” fixed, see [Known Issues Â§16.1](./16-known-issues-tech-debt.md#161-critical-previously-broke-the-application-or-a-whole-feature--all-fixed).

### `POST /v1/resolve`
**Request**:
```json
{ "text": "UPI/CR/3152671239/BUNDL TECHNOLOGIES/HDFC" }
```
**Response** (`ResolutionResult`):
```json
{
  "raw_text": "UPI/CR/3152671239/BUNDL TECHNOLOGIES/HDFC",
  "cleaned_text": "BUNDL TECHNOLOGIES",
  "canonical_merchant": "Swiggy",
  "confidence": 0.99,
  "is_resolved": true,
  "resolution_method": "exact_alias"
}
```
`resolution_method` is one of `exact_alias` (0.99), `substring` (0.75), or `none` (0.0). See [05 Â· Ingestion, Resolution & Memory](./05-ingestion-resolution-memory.md) for the cleaning algorithm.

### `POST /v1/confidence/evaluate`
**Request** (`MockModelPrediction`):
```json
{ "predicted_category": "Travel", "raw_confidence": 0.40 }
```
**Response** (`ConfidenceEvaluation`):
```json
{
  "raw_category": "Travel",
  "final_category": "Unknown",
  "confidence": 0.40,
  "is_hallucination_risk": true,
  "calibration_applied": "identity"
}
```
Rule: any `predicted_category` not in the `TransactionCategory` enum (Food, Travel, Entertainment, Bills, Friends, Education, Healthcare, Unknown) is forced to `Unknown` with `confidence: 0.0` and `calibration_applied: "none"`. Otherwise, if `raw_confidence < 0.5`, it is forced to `Unknown` with `calibration_applied: "identity"` (the calibration step is presently an identity clamp to `[0,1]`, not a real Platt/isotonic calibration â€” see `engines/confidence_engine.py`).

## 2.8 Memory Engine (`routers/memory.py`, prefix `/memory`)

### `POST /memory/update`
**Request**:
```json
{ "canonical_name": "Zomato", "raw_text": "paid to zomato media pvt" }
```
**Response** (`MerchantProfile`) â€” full schema in [03 Â· Data Model](./03-data-model.md#merchantprofile).

### `GET /memory/profile/{canonical_name}`
Returns the full `MerchantProfile`. `404` with `{"detail": "Profile not found in memory."}` if unseen.

### `GET /memory/state/{canonical_name}`
Lightweight variant. If unseen, returns `200` (not 404) with:
```json
{ "canonical_name": "SomeMerchant", "memory_state": "UNSEEN" }
```
Otherwise:
```json
{ "canonical_name": "Zomato", "memory_state": "TEMPORARY", "frequency": 4 }
```

## 2.9 Analytics Engine (`routers/analytics.py`, prefix `/v1/analytics`)

All analytics endpoints are scoped to `current_user.id`, resolved from the caller's JWT (`Depends(get_current_user)`) â€” previously a hardcoded `TEST_USER = "user_123"` shared by every caller regardless of identity; see [22 Â· Authentication](./22-authentication.md).

### `GET /v1/analytics/patterns/categories?days=30`
Aggregates `transactions` by `category` within `[now - days, now]`.
```json
[ { "category": "Food", "total_amount": 4230.5, "count": 12 }, ... ]
```

### `GET /v1/analytics/patterns/merchants?limit=5`
Top merchants by visit count (all-time, not time-boxed).
```json
[ { "merchant": "Swiggy", "visits": 14, "spent": 3820.0 }, ... ]
```

### `GET /v1/analytics/subscriptions`
Joins `transactions` against `behavior_patterns` (via `$lookup` on `merchant_name`) and filters to `periodicity_score >= 0.85`.
```json
{
  "active_subscriptions": 2,
  "total_monthly_burn": 698.0,
  "details": [
    { "merchant": "Netflix", "estimated_monthly_cost": 499.0, "periodicity_score": 0.94, "last_billed": "2026-07-01T00:00:00Z" }
  ]
}
```
`estimated_monthly_cost` is simply the **last observed transaction amount** for that merchant, not an average or median.

### `GET /v1/analytics/trends/mom`
```json
{ "current_spend": 8213.5, "previous_spend": 15102.0, "mom_growth_percentage": -45.61, "trend": "down" }
```
`previous_spend` is now a real aggregation over the previous calendar month (previously a hardcoded `15000.0`) â€” fixed, see [Known Issues Â§16.2](./16-known-issues-tech-debt.md#162-high-previously-security--correctness-with-real-user-impact--all-fixed). The current-month query is also now upper-bounded to the current month only (it previously summed everything from the 1st of the month onward with no end date).

### `POST /v1/analytics/anomaly/check?merchant=Uber&amount=99999`
Note: parameters are plain query parameters (`merchant: str, amount: float` as function args), not a JSON body, despite the router being a `POST`.
```json
{ "is_anomaly": true, "confidence": 0.99, "reason": "Amount is significantly higher than the typical 350.20 spent here." }
```
If no `behavior_patterns` document exists for the merchant, or its `std_dev` is `0`: `{"is_anomaly": false, "reason": "Insufficient baseline data"}`.

## 2.10 Explainability (`routers/rag.py`, prefix `/v1`)

### `POST /v1/explain`
**Request**:
```json
{ "transaction_text": "Swiggy order", "target_question": "Why was this transaction categorized this way?" }
```
**Response**:
```json
{
  "query": "Swiggy order",
  "retrieved_documents": 2,
  "result": {
    "explanation": "...",
    "confidence_in_explanation": "HIGH|MEDIUM|LOW",
    "primary_data_source": "Swiggy"
  }
}
```
If no semantic matches are found in Milvus, `result` is `{"error": "No historical behavior found to explain this transaction."}` and `retrieved_documents` is `0`. If Ollama fails or returns malformed JSON, `result` is `{"error": "Failed to generate explanation due to internal model error."}`. Full pipeline detail in [10 Â· RAG & Explainability](./10-rag-explainability.md).

## 2.11 Observability (`routers/observability.py`, prefix `/v1/observability`)

Both endpoints are stubs with no real implementation behind them:

### `POST /v1/observability/drift/analyze`
Always returns `{"status": "success", "message": "Drift analysis triggered successfully."}`. No Evidently AI call, no background task, no Celery integration exists in this codebase despite the docstring's claim.

### `GET /v1/observability/reports/latest`
Always returns `404` with `{"message": "No drift reports have been generated yet."}`. There is no code path that could ever generate or serve a report.

## 2.12 Feedback & Active Learning (`feedback/api_router.py`, prefix `/v1/feedback`)

`app.py` now imports and mounts `feedback.router` (`app.include_router(feedback_router, dependencies=[Depends(validate_api_key)])`) behind the same auth as every other router. Previously this was dead code from an HTTP standpoint â€” fixed, see [Known Issues Â§16.3](./16-known-issues-tech-debt.md#163-medium-previously-disconnected-features-dead-code-silent-no-ops--fixed).

### `POST /v1/feedback/`
**Request**:
```json
{ "transaction_id": "666f6f2d6261722d71757578", "original_prediction": "Unknown", "corrected_category": "Travel", "confidence": 0.40 }
```
**Response**:
```json
{ "status": "success", "feedback_recorded": true }
```
`transaction_id` should be the id returned by `POST /v1/categorize`. `process_feedback` looks that transaction up to resolve its merchant and writes a real `merchant_name` field on the feedback document (previously it stored the category prediction in a field that RAG/graph readers mistakenly queried as if it were a merchant name â€” fixed, see [Known Issues Â§16.2](./16-known-issues-tech-debt.md#162-high-previously-security--correctness-with-real-user-impact--all-fixed)). If `is_correction` is true (prediction != corrected category), a background task checks whether the retraining queue threshold has been hit.

See [09 Â· Feedback & Active Learning](./09-feedback-active-learning.md) for the full pipeline.

## 2.13 Batch Pipelines (`routers/pipelines.py`, prefix `/v1/pipelines`)

New router added to make previously-orphaned pipelines reachable (Phases 4, 6, 7, 8, 13 had zero callers anywhere in the repo â€” see [Known Issues Â§16.3](./16-known-issues-tech-debt.md#163-medium-previously-disconnected-features-dead-code-silent-no-ops--fixed)). Nothing schedules these automatically yet; they're manual-trigger endpoints until a cron/Celery beat is stood up.

### `POST /v1/pipelines/behavior/run`
**Request**: `{ "merchant_name": "Swiggy" }` â€” profiles one merchant from its transaction history. `404` if the merchant has no transactions.

### `POST /v1/pipelines/behavior/run-all`
No body. Profiles every distinct merchant in `transactions`. Response: `{ "profiled": [...], "failed": [...] }`. Run this before `/v1/analytics/subscriptions` or `/v1/analytics/anomaly/check` in a fresh environment â€” both depend on `behavior_patterns` being populated.

### `POST /v1/pipelines/embeddings/sync`
No body. Generates an Ollama embedding for every stored `behavior_patterns` document and upserts it into Milvus. Returns `503` if Milvus isn't connected; otherwise `{ "synced": [...], "failed": [...] }`.

### `POST /v1/pipelines/decay/sweep`
No body. Archives merchant profiles inactive 180+ days. Response: `{ "archived_count": <int> }`.

### `POST /v1/pipelines/graph/build`
No body. Rebuilds the in-memory knowledge graph from `merchant_profiles`, `behavior_patterns`, and `feedback`. Response: `{ "total_nodes": <int>, "total_edges": <int>, "density": <float> }`.

### `GET /v1/pipelines/graph/neighborhood/{merchant_name}?radius=2`
Returns the ego-graph around a merchant. Requires `/graph/build` to have been called in this process first â€” the graph is in-memory, not persisted.

### `POST /v1/pipelines/clustering/run`
No body. Runs the Phase 8 UMAP + HDBSCAN discovery pipeline over vectors stored in Milvus (needs at least 10 vectors; requires `scikit-learn` + `umap-learn`, imported lazily inside this handler so a missing/broken install only breaks this one endpoint). Response includes cluster count, noise count, and silhouette/Davies-Bouldin metrics.

## 2.14 Error model

There is no centralized exception handler beyond FastAPI/Pydantic defaults and SlowAPI's `RateLimitExceeded` handler. Standard shapes you will encounter:

| Status | When | Body |
|---|---|---|
| `401` | Missing `X-Vela-API-Key` header | `{"detail": "Missing X-Vela-API-Key header"}` |
| `403` | Wrong API key value | `{"detail": "Invalid or revoked API Key"}` |
| `404` | Memory profile not found; observability report not found | `{"detail": "..."}` or custom `{"message": "..."}` |
| `422` | Pydantic request validation failure | Standard FastAPI validation error array |
| `429` | Rate limit exceeded | SlowAPI default body |
| `500` | Unhandled exception | Default FastAPI traceback response (`DEBUG` logging is on, so stack traces are verbose in logs) |

