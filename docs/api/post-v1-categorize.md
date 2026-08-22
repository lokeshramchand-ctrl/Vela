# POST `/v1/categorize`

## Method
`POST`

## URL
`/v1/categorize`

## Purpose
Runs raw transaction text through the deterministic rule engine, persists the categorized transaction, and returns the resulting merchant/category/confidence plus the inserted transaction's id (for later use with `POST /v1/feedback/`).

> âœ… **This endpoint previously raised `AttributeError` on every call and could not complete successfully.** That's fixed â€” see [16 Â· Known Issues Â§16.1](../16-known-issues-tech-debt.md#161-critical-previously-broke-the-application-or-a-whole-feature--all-fixed) for the full history of what was wrong.

## Authentication
**Required.** `X-Vela-API-Key: <settings.Vela_API_KEY>`, enforced via `Depends(validate_api_key)` attached at `app.include_router(v1.router, dependencies=[...])`, using a constant-time comparison against the configured key.

## Rate limit
`50/minute` per client IP â€” tighter than the app's global default of `100/minute`. Exceeding it returns `429`.

## Headers
| Header | Required | Value |
|---|---|---|
| `X-Vela-API-Key` | Yes | Your configured `Vela_API_KEY` |
| `Content-Type` | Yes | `application/json` |

## Request body
```json
{ "text": "paid 500 to swiggy" }
```
Validated against `CategorizeRequest` (`models/schemas.py`): one required field, `text: str`.

## Validation
Only Pydantic type-level validation: `text` must be present and a string. No length limits, no non-empty check â€” an empty string or arbitrarily long text would pass validation and reach the handler body.

## Response
`CategorizeResponse`:
```json
{ "merchant": "Swiggy", "category": "Food", "confidence": 0.95, "transaction_id": "666f6f2d6261722d71757578" }
```
`transaction_id` is the stringified Mongo `_id` of the inserted `transactions` document â€” pass it to `POST /v1/feedback/` to let feedback resolve back to this merchant.

## Error codes
| Code | When |
|---|---|
| `401` | Missing `X-Vela-API-Key` header |
| `403` | Wrong API key value |
| `422` | `text` field missing or wrong type |
| `429` | More than 50 requests/minute from the same client |
| `500` | Unexpected internal error (e.g. a database connectivity failure) |

## Internal execution flow
```mermaid
sequenceDiagram
    participant C as Client
    participant Ctl as routers/v1.py::categorize_transaction
    participant RE as engines.rule_engine.rule_engine
    participant Mongo as database.mongo.db

    C->>Ctl: POST /v1/categorize {"text": "paid 500 to swiggy"}
    Ctl->>Ctl: start_time = time.time()
    Ctl->>RE: rule_engine.categorize(payload.text)
    RE-->>Ctl: {merchant, category, confidence}
    Ctl->>Ctl: text_content = payload.text
    Ctl->>Ctl: regex-extract amount from text_content (if a "â‚¹<amount>" pattern is present)
    Ctl->>Mongo: db.transactions.insert_one({user_id, raw_text, merchant, category, amount, confidence, timestamp})
    Mongo-->>Ctl: inserted_id
    Ctl-->>C: {merchant, category, confidence, transaction_id}
```

## Controller
`categorize_transaction(request: Request, payload: CategorizeRequest)` in `routers/v1.py`. Unusually for this codebase, real business logic â€” regex amount extraction, direct Mongo persistence â€” is embedded directly in the controller rather than delegated to a service (a fair architectural critique that remains true even though the bugs are fixed). The `request: Request` parameter exists solely so SlowAPI's `@limiter.limit("50/minute")` decorator can bind to it; the actual request body is `payload`.

## Service
`engines.rule_engine.rule_engine.categorize(text)` â€” deterministic regex-based merchant/category matching against `merchant_aliases.json`.

## Database queries
`db.transactions.insert_one({...})` â€” a single document insert into the `transactions` collection, including `user_id` (hardcoded to `"user_123"`), `raw_text`, the resolved `merchant`/`category`/`confidence`, extracted `amount`, and `timestamp`.

## Example request
```bash
curl -s -X POST http://localhost:8000/v1/categorize \
  -H "X-Vela-API-Key: $Vela_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"text": "paid 500 to swiggy"}'
```

## Example response
```http
HTTP/1.1 200 OK
Content-Type: application/json

{ "merchant": "Swiggy", "category": "Food", "confidence": 0.95, "transaction_id": "666f6f2d6261722d71757578" }
```

## Interview questions
- "This endpoint used to crash on every call â€” walk through what was wrong and how each bug was fixed." (1. `request.get("text", "")` called `.get()` on a Pydantic model, which has no such method â€” fixed by reading `payload.text` directly, after renaming the body parameter from `request` to `payload` so a real `Request` object could occupy the `request` name SlowAPI requires. 2. `datetime.now(time.timezone.utc)` â€” `time.timezone` is a plain int, not an object with a `.utc` attribute â€” fixed to `datetime.now(timezone.utc)`. 3. The Mongo insert previously wrote `merchant_resolver` (an object), `categorize_transaction` (the function itself), and `confidence_engine` (an object) into fields meant to hold resolved values â€” fixed to write `result["merchant"]`, `result["category"]`, `result["confidence"]`.)
- "Why did a duplicate, non-broken stub for this exact path used to exist in `app.py`, and why didn't it save this endpoint?" (`app.py`'s `public_categorize` inline route was registered *after* `routers.v1.router` was included, so Starlette's route table matched the router's handler first â€” the stub was dead code that never executed for real traffic. It's been removed, and its rate limit was moved onto the real handler here instead of being lost.)
- "Why does this endpoint return a `transaction_id` now when it didn't before?" (`POST /v1/feedback/` needs a way to look up which merchant a piece of feedback is about. Previously, feedback stored the *category prediction* in a field that other code mistakenly queried as if it were a merchant name â€” see [18 Â· Database Analysis Â§2.2](../18-database-analysis.md#22-the-feedbackprediction-field-mismatch--fixed). Returning `transaction_id` here lets the feedback service look up the real transaction and resolve its actual merchant.)

