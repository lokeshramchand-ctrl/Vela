# POST `/v1/feedback/`

## Method
`POST`

## URL
`/v1/feedback/`

## âœ… Reachability status
**This endpoint is mounted and reachable.** `app.py` now imports `feedback.router` and calls `app.include_router(feedback_router, dependencies=[Depends(validate_api_key)])`, matching the same auth pattern as every other router. Previously `app.py` never imported `feedback` at all and any request here received a generic `404` â€” see [16 Â· Known Issues Â§16.3](../16-known-issues-tech-debt.md#163-medium-previously-disconnected-features-dead-code-silent-no-ops--fixed).

## Purpose
Accepts human feedback on a model prediction (correction or confirmation), resolves and persists the merchant it's about, and â€” for actual corrections â€” checks in the background whether enough corrections have accumulated to justify triggering a retraining run.

## Authentication
**Required.** `X-Vela-API-Key: <settings.Vela_API_KEY>`, enforced via `Depends(validate_api_key)`.

## Headers
| Header | Required | Value |
|---|---|---|
| `X-Vela-API-Key` | Yes | Your configured `Vela_API_KEY` |
| `Content-Type` | Yes | `application/json` |

## Request body
```json
{
  "transaction_id": "666f6f2d6261722d71757578",
  "original_prediction": "Unknown",
  "corrected_category": "Travel",
  "confidence": 0.40
}
```
Validated against the router-local `FeedbackRequest` model (`feedback/api_router.py`): all four fields required. `transaction_id` should be the id returned by `POST /v1/categorize` â€” `process_feedback` uses it to look up the transaction's `merchant` field.

## Validation
Type-level only â€” no constraint that `original_prediction`/`corrected_category` be valid `TransactionCategory` enum values, and `confidence` has no `[0, 1]` bound. `transaction_id` isn't validated as a real `ObjectId` before use â€” an unresolvable id just results in `merchant_name: null` being stored, not an error.

## Response
`200 OK`:
```json
{ "status": "success", "feedback_recorded": true }
```
`feedback_recorded` reflects whether `original_prediction != corrected_category` (i.e., whether this was an actual correction versus a confirmation).

## Error codes
| Code | When |
|---|---|
| `401` | Missing API key |
| `403` | Wrong API key |
| `422` | Any of the four required fields missing or wrong type |

## Internal execution flow
```mermaid
sequenceDiagram
    participant C as Client
    participant Ctl as feedback/api_router.py::submit_feedback
    participant FS as feedback.feedback_service.feedback_service
    participant Mongo as MongoDB (transactions, feedback, retraining_queue)
    participant BG as FastAPI BackgroundTasks
    participant RQ as feedback.retraining_queue.retraining_manager

    C->>Ctl: POST /v1/feedback/ {transaction_id, original_prediction, corrected_category, confidence}
    Ctl->>FS: process_feedback(...)
    FS->>Mongo: transactions.find_one({"_id": ObjectId(transaction_id)}, {"merchant": 1})
    Mongo-->>FS: merchant_name (or None if not found)
    FS->>FS: is_correction = original_prediction != corrected_category
    FS->>Mongo: feedback.insert_one({..., merchant_name, ...})
    alt is_correction
        FS->>Mongo: retraining_queue.insert_one(queue_doc, status="pending")
    end
    FS-->>Ctl: feedback_doc
    alt is_correction
        Ctl->>BG: background_tasks.add_task(retraining_manager.trigger_retraining_if_needed)
    end
    Ctl-->>C: {"status": "success", "feedback_recorded": is_correction}
    Note over BG,RQ: Runs after the response is already sent
    BG->>RQ: trigger_retraining_if_needed()
    RQ->>Mongo: count_documents(retraining_queue, status="pending")
    alt pending_count >= 100
        RQ->>Mongo: update_many(status: pending -> processing)
        Note over RQ: Still a TODO in source â€” actual training launch requires a task queue (Celery), not implemented; see 16 Â· Known Issues Â§16.5
    end
```

## Controller
`submit_feedback(request: FeedbackRequest, background_tasks: BackgroundTasks)` in `feedback/api_router.py`.

## Service
`feedback.feedback_service.feedback_service.process_feedback(...)` â€” now also resolves `merchant_name` via `_lookup_merchant_name(transaction_id)` before writing â€” and, deferred to a background task, `feedback.retraining_queue.retraining_manager.trigger_retraining_if_needed()` (threshold check).

## Database queries
- `db.transactions.find_one({"_id": ObjectId(transaction_id)}, {"merchant": 1})` â€” resolves the merchant name; returns `None` gracefully if `transaction_id` isn't a valid/resolvable `ObjectId`.
- `db.feedback.insert_one(feedback_doc)` â€” always, one write, now including `merchant_name`.
- `db.retraining_queue.insert_one(queue_doc)` â€” only if `is_correction` is true.
- (Background, deferred) `db.retraining_queue.count_documents({"status": "pending"})` and, conditionally, `db.retraining_queue.update_many({"status": "pending"}, {"$set": {"status": "processing", ...}})`.

## Example request
```bash
curl -s -X POST http://localhost:8000/v1/feedback/ \
  -H "X-Vela-API-Key: $Vela_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"transaction_id": "666f6f2d6261722d71757578", "original_prediction": "Unknown", "corrected_category": "Travel", "confidence": 0.40}'
```

## Example response
```http
HTTP/1.1 200 OK
Content-Type: application/json

{ "status": "success", "feedback_recorded": true }
```

## Interview questions
- "This was unreachable before â€” what was the exact fix?" (`app.py` never imported the `feedback` package or called `app.include_router(feedback.router, ...)` â€” a pure wiring omission. Fixed by importing `feedback.router` as `feedback_router` and including it alongside the other routers with the same `validate_api_key` dependency.)
- "Why does `merchant_name` exist on the feedback document now, when it didn't before?" (Previously `feedback.prediction` held a *category* string, but `rag/retriever.py` and `graphs/graph_builder.py` both queried/matched that field as if it held a *merchant* name â€” so real feedback essentially never joined correctly. `process_feedback` now looks up the transaction via `transaction_id` and stores its actual `merchant` as `merchant_name`, and both read sites now query on that field instead. See [18 Â· Database Analysis Â§2.2](../18-database-analysis.md#22-the-feedbackprediction-field-mismatch--fixed).)
- "Why use `BackgroundTasks` for the retraining-threshold check instead of awaiting it directly before responding?" (The caller submitting feedback doesn't need to wait for â€” or know about â€” whether their submission happened to cross a global retraining threshold; deferring it keeps the response fast and decouples an unrelated batch-processing concern from the individual feedback-submission request.)
- "The retraining queue flips records to `\"processing\"` once the threshold is hit â€” then what?" (Nothing, currently. Actually launching `BaselineTrainer().run_benchmarks()` requires a task queue like Celery, which doesn't exist in this repo. Calling it synchronously from a background task would block on a CPU-heavy job and would still only train on synthetic data, not real feedback â€” that's a scoped feature to build, not a bug to fix. See [16 Â· Known Issues Â§16.5](../16-known-issues-tech-debt.md#165-whats-intentionally-still-open-productinfra-decisions-not-bugs).)

