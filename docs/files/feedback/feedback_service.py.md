# File: `feedback/feedback_service.py`

## Purpose
Persists every human feedback event (correction or confirmation) and routes actual corrections into the retraining queue.

## Responsibilities
- Determine whether a piece of feedback represents a correction or a confirmation.
- Save every feedback event, regardless of which it is.
- Push corrections specifically into the retraining queue.

## Imports
| Import | Used for |
|---|---|
| `logging` | Logging feedback events |
| `datetime.datetime, timezone` | Timestamping feedback and queue records |
| `typing.Dict, Any` | Type hints |
| `database.mongo.db` | Writing to `feedback` and `retraining_queue` collections |

## Exports
- **`FeedbackService`** — the class.
- **`feedback_service`** — the singleton instance, imported (only) by `feedback/api_router.py` — and therefore, given that router is unmounted, not reachable from live traffic today.

## Execution Flow
On import, `feedback_service = FeedbackService()` runs trivially. `process_feedback(...)`, if called, runs: determine correction status → insert one `feedback` document → conditionally insert one `retraining_queue` document.

## Functions (plain English)

### `FeedbackService.process_feedback(self, transaction_id, original_prediction, corrected_category, confidence, user_id="system_user") -> Dict[str, Any]` (async)
In simple English: "Compare what the model originally predicted against what a human said the answer should be — if they're different, this is a genuine correction; if they match, it's just a confirmation that the model got it right. Either way, build a record of this feedback event, including who submitted it (though that's always just a generic placeholder identity since nothing passes in a real user), and save it permanently. If this was an actual correction, also queue it up separately for the retraining process to eventually pick up. Report back the full record we just saved, including whether it counted as a correction."

### `FeedbackService._queue_for_retraining(self, transaction_id, verified_category, failed_prediction)` (async)
In simple English: "Build a small record capturing exactly what needs to be relearned — this transaction's ID, what the human said the right answer was, and what the model got wrong — mark it as 'pending' (not yet processed), and save it to the retraining queue." The leading underscore signals this is a private helper only meant to be called from within `process_feedback`.

## Classes

### `FeedbackService`
No instance state — a pure orchestration class with one public method and one private helper.

## Interfaces
Not applicable formally — the returned dict from `process_feedback` doubles as both the persisted document's shape and the function's return contract.

## Hooks
Not applicable.

## Utilities
`_queue_for_retraining` is a small internal utility supporting the main method.

## Dependencies
`datetime`, `logging` (standard library); `database.mongo` (internal).

## Side Effects
- Always writes exactly one document to `db.feedback`.
- Conditionally writes exactly one document to `db.retraining_queue`, only when the feedback represents a correction.
- Logs the outcome of every call.

## Performance Considerations
Trivial — two simple, single-document MongoDB inserts at most per call, no aggregation, no complex queries. The only latency here is the network round trip(s) to MongoDB itself.

## Possible Interview Questions
- "Why does `user_id` default to `'system_user'` and never get overridden by any caller?" (Because nothing upstream — including the router calling this function — passes a real, authenticated user identity through; `core/security.py`'s auth mechanism doesn't resolve a meaningful per-caller identity either, so there's currently no real user context to thread through even if this function were changed to accept it.)
- "Why save *every* feedback event, including confirmations where the model was already right, rather than only logging actual corrections?" (A confirmation is still valuable signal — it tells you the model got something right, which matters for measuring overall accuracy and building a complete audit trail, even though only corrections are specifically useful for the retraining/active-learning loop.)
- "What would happen if `_queue_for_retraining` failed (e.g., a database error) after `feedback.insert_one` had already succeeded?" (The feedback record would be durably saved, but the correction would never make it into the retraining queue — there's no transaction or rollback tying these two writes together, so a partial-failure scenario like this would silently under-count the retraining backlog with no automatic recovery or alerting.)
- "How would you extend this to support a real, authenticated `user_id` instead of the hardcoded default?" (You'd need `core/security.py` to resolve a real per-caller identity from the API key (which it currently doesn't do meaningfully), then thread that identity through `feedback/api_router.py`'s handler and into this function's `user_id` parameter instead of relying on the default.)
