# Vela Backend API Reference (for Flutter/Dart client)

Extracted from the FastAPI backend source (`app.py`, `core/*.py`, `routers/*.py`, `feedback/api_router.py`). This is the contract the Dart networking/repository layer is generated against.

## 0. Conventions

**Base path**: no global prefix; routers mount their own prefixes (`/auth`, `/users`, `/v1`, `/v1/analytics`, `/v1/feedback`, `/v1/pipelines`, `/memory`, `/statements`, `/jobs`). Unauthenticated system routes (`/live`, `/ready`, `/health`, `/metrics`) sit at root.

**Two-layer auth, every non-system route requires layer 1 at minimum:**
1. **API key (all routers, always)**: header `X-Vela-API-Key: <key>` — validated in `core/security.py::validate_api_key` against `settings.Vela_API_KEY` via `secrets.compare_digest`. Not a per-user credential; authenticates the calling application only. There is no client-facing endpoint to obtain this key — it's a static value the mobile app ships/configures with.
2. **JWT bearer (per-endpoint, additive)**: header `Authorization: Bearer <access_token>` — validated in `core/jwt_auth.py::get_current_user`. Obtained from `POST /auth/login` or `POST /auth/refresh`.

Order matters for error precedence: the router-level API-key dependency runs before any handler-level JWT dependency — a request with a bad JWT but no/bad API key gets the API-key error, not a JWT error.

**Standard error envelope** (`core/error_handlers.py`):

```jsonc
// HTTPException (404, 401, 403, 409, etc.)
{ "error": { "detail": "<string>", "request_id": "<string>" } }

// 422 request validation (Pydantic)
{ "error": { "detail": "Request validation failed.", "errors": [{ "loc": ["body","field"], "msg": "...", "type": "..." }], "request_id": "<string>" } }

// 500 unhandled exception
{ "error": { "detail": "An unexpected error occurred. Contact support with this request_id.", "request_id": "<string>" } }
```

Every response carries `X-Request-ID`.

**Two exceptions that do NOT use the standard envelope:**
- **413 fast-path** (`Content-Length` header exceeds `MAX_REQUEST_BODY_BYTES`, 15MB default): `{ "error": "payload_too_large", "detail": "Request body exceeds the maximum allowed size." }`. (The slower streaming-counter 413 path *does* use the standard envelope — a 413 can arrive in either shape.)
- **429 rate limit** (slowapi default): `{ "error": "Rate limit exceeded: <limit string>" }`, headers `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`, `Retry-After`.

Global default rate limit: **1000/day, 100/minute** per IP unless a handler overrides it (noted per-endpoint below).

**Pagination** (`core/pagination.py`), every list endpoint:
- Query: `page` (default 1), `page_size` (default 20, max 100).
- Response envelope: `{ items: [...], page, page_size, total, total_pages }`.
- `sort_order`: `"asc"` | `"desc"` (default `"desc"`; anything else resolves to desc).

**Client-relevant config** (`core/config.py`):
- `JWT_ACCESS_TOKEN_EXPIRE_MINUTES` = 15
- `JWT_REFRESH_TOKEN_EXPIRE_DAYS` = 30
- `MAX_STATEMENT_PDF_BYTES` = 10,000,000 (10MB)
- `MAX_REQUEST_BODY_BYTES` = 15,000,000 (15MB)

---

## 1. Auth — `/auth` (API key only)

### `POST /auth/register` (5/min)
Body: `{ email: string, password: string(8-128) }` → `201 UserPublic { id, email, full_name: string|null, is_active, created_at }`. Errors: `409` email taken, `422` validation.

### `POST /auth/login` (10/min)
Body: `{ email: string, password: string(1-128) }` → `200 TokenResponse { access_token, refresh_token, token_type: "bearer", expires_in: int }`. Errors: `401` bad credentials, `403` account disabled.

### `POST /auth/refresh` (20/min)
Body: `{ refresh_token: string(1-1024) }` → `200 TokenResponse`. Refresh tokens are single-use/rotating. Errors: `401` invalid/expired/**reused** token (reuse revokes ALL sessions server-side — force full re-login on this error, don't just retry).

### `POST /auth/logout` (20/min)
API key only (works even with an expired access token). Body: `{ refresh_token: string(1-1024) }` → `204`. Idempotent, unknown token = silent no-op.

---

## 2. Users — `/users` (API key + JWT)

### `GET /users/me` → `200 UserPublic`
### `PATCH /users/me`
Body: `{ full_name: string(1-200)|null }` (email not editable here) → `200 UserPublic`.

---

## 3. Statements — `/statements` (API key + JWT)

### `POST /statements/upload` (10/min)
multipart/form-data: `file` (binary, must end `.pdf`, required), `password` (string, optional — only for encrypted GPay PDFs).
Returns immediately; processing happens in background — client polls `GET /jobs/{job_id}`.
→ `202 StatementUploadResponse { statement_id, job_id, status: "PENDING"|"PROCESSING"|"COMPLETED"|"FAILED" }` (will be `PENDING`).
Errors:
- `422` — not `.pdf`, corrupted, password required/wrong, or not a recognized GPay format (all four share one 422 shape — branch on `detail` text if needed, e.g. to re-prompt for password).
- `413` — exceeds `MAX_STATEMENT_PDF_BYTES` (10MB) — uses the **standard envelope** (this check is app-level, not the middleware fast-path).

### `GET /statements`
Query: `page`, `page_size`, `processing_status` (optional enum filter), `sort_by` (default `uploaded_at`), `sort_order`.
→ `200 { items: StatementResponse[], page, page_size, total, total_pages }`.

**`StatementResponse`** (same shape for list items and `GET /statements/{id}`):
```
id: string
original_filename: string
file_size_bytes: int
page_count: int|null
period_start: string (YYYY-MM-DD)
period_end: string (YYYY-MM-DD)
declared_sent_amount: number|null
declared_received_amount: number|null
computed_sent_amount: number|null
computed_received_amount: number|null
reconciliation_ok: boolean|null
transaction_count: int
processing_status: "PENDING"|"PROCESSING"|"COMPLETED"|"FAILED"
current_job_id: string|null
error_message: string|null
analytics_version: string
uploaded_at: string (ISO datetime)
processing_completed_at: string|null
processing_duration_ms: int|null
```

### `GET /statements/{id}` → `200 StatementResponse`. `404` if missing/not owned (indistinguishable, deliberate).
### `DELETE /statements/{id}` → `204`. Cascades to transactions, job history, stored PDF. `404` same semantics.

### `GET /statements/{id}/transactions`
Query: `page`, `page_size`, `category`, `transaction_type` (`DEBIT`|`CREDIT`), `merchant` (substring, case-insensitive), `start_date`/`end_date` (ISO date, **not pre-validated** — send strict `YYYY-MM-DD` or risk a 500), `sort_by` (default `timestamp`), `sort_order`.
→ `200 { items: TransactionResponse[], page, page_size, total, total_pages }`.

**`TransactionResponse`**:
```
id: string
statement_id: string|null
timestamp: string (ISO datetime)
merchant: string|null
category: string|null
amount: number
transaction_type: "DEBIT"|"CREDIT"
status: "SUCCESS"|"FAILED"|"PENDING"
counterparty_raw: string|null
reference_number: string|null   // UPI transaction ID
bank: string|null
account_last4: string|null
payment_method: string          // e.g. "UPI"
```

### `GET /statements/{id}/analytics` → `200 StatementAnalyticsResponse`
```
statement_id: string
total_spend: number
total_income: number
net: number
average_transaction_value: number
transaction_count: int
failed_transaction_count: int
category_breakdown: { category: string, total_amount: number, count: int }[]
top_merchants: { merchant: string, total_amount: number, count: int }[]
daily_trend: { date: string, total_amount: number, count: int }[]
recurring_payments: { merchant: string, estimated_monthly_cost: number, periodicity_score: number, occurrences: int }[]
generated_at: string (ISO datetime)
```
Errors: `404`; `409` if statement not yet `COMPLETED` (message includes job id to poll).

### `GET /statements/{id}/insights` → `200 StatementInsightsResponse`
```
statement_id: string
insights: { type: string, message: string, severity: "INFO"|"POSITIVE"|"WARNING" }[]
```
Same `404`/`409` semantics as `/analytics`.

---

## 4. Jobs — `/jobs` (API key + JWT)

### `GET /jobs/{job_id}` → `200 JobResponse`
```
id: string
job_type: "STATEMENT_PROCESSING"
resource_type: string            // e.g. "statement"
resource_id: string
status: "QUEUED"|"RUNNING"|"COMPLETED"|"FAILED"
stage: string|null               // free text ("parsing","categorizing","generating_insights"...) - not an enum, don't hardcode a switch
progress_percent: int (0-100)
error_message: string|null
created_at: string
started_at: string|null
completed_at: string|null
```
`404` if missing/not owned. **No push/webhook** — client must poll after upload until `COMPLETED`/`FAILED`.

---

## 5. V1 / Transaction Intelligence — `/v1`

### `POST /v1/categorize` (API key + JWT, 50/min)
Body: `{ text: string(1-2000) }` → `200 { merchant, category, confidence: number, transaction_id: string|null }`. Writes a standalone transaction doc as a side effect — **not** tied to any Statement, invisible to `/statements/*` endpoints.

### `POST /v1/resolve` (API key only, no JWT)
Body: `{ text: string(1-2000) }` → `200 { raw_text, cleaned_text, canonical_merchant, confidence: number, is_resolved: boolean, resolution_method: "exact_alias"|"substring"|"none" }`.

### `POST /v1/confidence/evaluate` (API key only, no JWT)
Body: `{ predicted_category: string(1-100), raw_confidence: number(0-1) }` → `200 { raw_category, final_category: TransactionCategory, confidence, is_hallucination_risk: boolean, calibration_applied: "none"|"identity" }`. `final_category` forced to `"Unknown"` if invalid category or confidence < 0.5.

`TransactionCategory` enum: `Food, Travel, Entertainment, Bills, Friends, Education, Healthcare, Subscription, Shopping, Utility, Income, Unknown`.

---

## 6. Analytics / AI Insights — `/v1/analytics` (API key + JWT unless noted)

**No `response_model` on these handlers — shapes below are reverse-engineered from the actual return dicts, not schema-enforced. Treat as best-effort typed models with defensive parsing.**

### `GET /v1/analytics/patterns/categories?days=30`
→ `200` **array** of `{ category: string, total_amount: number, count: int }`.

### `GET /v1/analytics/patterns/merchants?limit=5`
→ `200` **array** of `{ merchant: string|null, visits: int, spent: number }` (different key names than the categories endpoint — no `count`/`total_amount` here).

### `GET /v1/analytics/subscriptions`
→ `200 { active_subscriptions: int, total_monthly_burn: number, details: { merchant, estimated_monthly_cost: number, periodicity_score: number, last_billed: string }[] }`.
Requires the batch behavior-profiling pipeline to have run at least once, else `details` is empty.

### `GET /v1/analytics/trends/mom`
No params (server "now" vs previous calendar month). → `200 { current_spend, previous_spend, mom_growth_percentage: number, trend: "up"|"down" }` (0 growth also reports `"down"`, strict `>0` check).

### `POST /v1/analytics/anomaly/check` (API key only, no JWT — evaluated against a merchant's global profile, not user-scoped)
**Query params** (not JSON body!): `merchant: string`, `amount: number`.
→ `200`, shape varies:
```jsonc
{ "is_anomaly": false, "reason": "Insufficient baseline data" }
{ "is_anomaly": false, "reason": "Normal spending range" }
{ "is_anomaly": true, "confidence": 0.0-0.99, "reason": "Amount is significantly higher/lower than the typical X.XX spent here." }
```
`confidence` key is **absent** (not null) on non-anomaly branches — model as optional.

---

## 7. Feedback — `/v1/feedback` (API key + JWT)

### `POST /v1/feedback/`
**Trailing slash matters** — without it FastAPI 307-redirects; point Dio at `/v1/feedback/` directly.
Body: `{ transaction_id: string(1-100), original_prediction: string(1-100), corrected_category: string(1-100), confidence: number(0-1) }`
→ `200 { status: "success", feedback_recorded: boolean }` (`feedback_recorded` true only if `original_prediction != corrected_category`).

This is what the Transaction sheet's "Looks right" / "Wrong category" buttons call.

---

## 8. Not user-facing (documented for completeness — do not build mobile UI against these)

- **`/memory`** (API key only, no JWT, not user-scoped) — shared cross-user merchant knowledge base.
- **`/v1/pipelines`** (API key only) — operator-triggered batch maintenance jobs (behavior profiling, embedding sync, decay sweep, graph rebuild, clustering).
- **`POST /v1/explain`** (`/v1/rag`, API key only, 20/min) — RAG explanation endpoint; `result` field is untyped/unread, not scoped to a specific stored transaction. Flag before building UI around it.

## 9. System (unauthenticated)

- `GET /live` → `200 { status: "alive" }`
- `GET /ready` → `200/503 { status, services: { mongodb, milvus, ollama: "connected"|"disconnected"|"error"|"degraded" } }` (gated only on mongodb)
- `GET /health` → `200 { status: "healthy"|"degraded", services, details }`
- `GET /metrics` — Prometheus text format, not relevant to mobile.

## 10. Open questions to confirm with backend before treating as final

1. `/v1/analytics/*` responses aren't schema-enforced — could drift silently.
2. `/v1/analytics/anomaly/check` and `/v1/pipelines/*` take query params, not JSON bodies.
3. `/v1/feedback/` needs the trailing slash.
4. `/statements/{id}/transactions` date filters aren't pre-validated — always send strict `YYYY-MM-DD`.
5. `POST /v1/explain`'s `result` field shape is unknown (backing code not inspected).
