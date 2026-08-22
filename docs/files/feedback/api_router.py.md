# File: `feedback/api_router.py`

## Purpose
Defines the Phase 10 feedback-submission HTTP endpoint. Fully implemented and correct, but **never mounted onto the running application** — `app.py` never imports or includes this router.

## Responsibilities
- Expose `POST /v1/feedback/`.
- Delegate feedback processing to `feedback_service`.
- Trigger a background check of the retraining queue after a correction is logged.

## Imports
| Import | Used for |
|---|---|
| `fastapi.APIRouter, BackgroundTasks` | Router construction; scheduling post-response work |
| `pydantic.BaseModel` | Base for the local `FeedbackRequest` |
| `feedback.feedback_service.feedback_service` | Persisting the feedback |
| `feedback.retraining_queue.retraining_manager` | Checking/triggering retraining after a correction |

## Exports
**`router`** — the `APIRouter` instance. Technically importable by anything, but nothing in the codebase actually imports it (specifically, `app.py` does not).

## Execution Flow
On import, `router` and `FeedbackRequest` are declared. If this router were ever mounted and called: `submit_feedback` awaits `feedback_service.process_feedback(...)` (a full request-response-cycle operation), then — only if the submission was an actual correction — schedules `retraining_manager.trigger_retraining_if_needed` to run **after** the HTTP response has already been sent back to the client, via FastAPI's `BackgroundTasks`.

## Functions (plain English)

### `submit_feedback(request: FeedbackRequest, background_tasks: BackgroundTasks)` (async)
Bound to `POST /v1/feedback/`. In simple English: "Take the feedback someone submitted — what the model originally predicted, what a human said the correct answer actually was, and how confident the original prediction was — and save it. If this feedback represents an actual correction (not just a confirmation that the model was already right), schedule a check afterward to see if we've now accumulated enough corrections to justify retraining — but don't make the person submitting the feedback wait around for that check to finish; let it happen quietly in the background after we've already told them 'thanks, got it.' Respond immediately with a simple success message and whether this was recorded as a correction."

## Classes

### `FeedbackRequest(BaseModel)`
Fields: `transaction_id: str`, `original_prediction: str`, `corrected_category: str`, `confidence: float`. The request body shape for `/v1/feedback/`.

## Interfaces
Not applicable formally — response shape here is a plain dict, not a declared `response_model`.

## Hooks
**`BackgroundTasks`** is the key hook in this file — `background_tasks.add_task(retraining_manager.trigger_retraining_if_needed)` schedules a function to run after the response is returned, a core FastAPI pattern for "don't block the client on non-critical follow-up work."

## Utilities
None.

## Dependencies
`fastapi`, `pydantic` (third-party); `feedback.feedback_service`, `feedback.retraining_queue` (internal, same folder).

## Side Effects
- Would write to MongoDB (`feedback`, and conditionally `retraining_queue`) — but only if this router is ever actually invoked, which it currently isn't, since it's unmounted.

## Performance Considerations
Not currently applicable given the router isn't reachable, but by design: using `BackgroundTasks` for the retraining check is the correct performance pattern — it keeps the feedback-submission response fast and doesn't make the caller wait for a database `count_documents` call and potential batch-status update that isn't relevant to them.

## Possible Interview Questions
- "This file is complete and bug-free, but the feature doesn't work in production. Why?" (`app.py` never calls `app.include_router(feedback.router, ...)` and never even imports the `feedback` package — the router simply isn't part of the running application's route table, so any request to `/v1/feedback/` returns a plain 404, as if the endpoint never existed.)
- "What's the exact fix to make this endpoint reachable?" (Add `from feedback import api_router as feedback` — or similar — to `app.py`'s imports, and add `app.include_router(feedback.router, dependencies=[Depends(validate_api_key)])` alongside the other four `include_router` calls, matching the existing pattern exactly.)
- "Why use `BackgroundTasks` here instead of just awaiting `trigger_retraining_if_needed()` directly before returning the response?" (The retraining-threshold check and any resulting batch-status update aren't something the feedback-submitting caller needs to wait for or knows/cares about — deferring it to a background task keeps the API response fast and decouples the two concerns, at the cost of the caller having no visibility into whether retraining was actually triggered as a result of their specific submission.)
- "Is there a risk that this router being defined but unmounted could accidentally get mounted twice, or mounted with the wrong dependencies, in the future?" (Yes, in principle — since it's a fully standalone, self-contained module with no built-in registration mechanism, whoever eventually wires it up needs to remember to match the auth dependency pattern used by the other four routers; nothing enforces that consistency automatically.)
