# File: `feedback/retraining_queue.py`

## Purpose
Tracks how many corrections have accumulated and decides when there's enough to justify kicking off a retraining run. The "trigger" half is intentionally left unfinished.

## Responsibilities
- Count how many corrections are currently pending processing.
- Decide whether that count meets the retraining threshold.
- Lock pending records (mark them "processing") once triggered, to avoid double-processing.

## Imports
| Import | Used for |
|---|---|
| `logging` | Status logging |
| `datetime.datetime, timezone` | Timestamping when processing begins |
| `database.mongo.db` | Counting and updating `retraining_queue` documents |

## Exports
- **`RetrainingQueueManager`** — the class.
- **`retraining_manager`** — the singleton instance, imported by `feedback/api_router.py` — again, unreachable in practice since that router is unmounted.

## Execution Flow
On import, `retraining_manager = RetrainingQueueManager(batch_threshold=100)` runs trivially. If called: `trigger_retraining_if_needed()` first calls `check_retraining_status()` (a read), then conditionally performs a bulk write, and then... stops, per its own `TODO` comment.

## Functions (plain English)

### `RetrainingQueueManager.__init__(self, batch_threshold: int = 100)`
In simple English: "Remember how many pending corrections we need before it's worth bothering to retrain — 100 by default."

### `RetrainingQueueManager.check_retraining_status(self) -> dict` (async)
In simple English: "Count how many corrections are currently sitting in the queue waiting to be processed. Compare that count against our threshold, and report both the count and whether we've crossed the line into 'yes, we should retrain now.'"

### `RetrainingQueueManager.trigger_retraining_if_needed(self) -> bool` (async)
In simple English: "First, check the current status. If we haven't hit the threshold yet, just note that in the logs and stop here — nothing to do. If we *have* hit the threshold, log a clear warning that we're about to act, then immediately mark every currently-pending record as 'processing' (recording exactly when we started), so that if this check runs again before we've actually finished, it won't try to process the same records twice. At this point, a real system would kick off the actual retraining job — but that part was never built; there's just a comment marking where it should eventually go. Report `True` to indicate that retraining was (nominally) triggered."

## Classes

### `RetrainingQueueManager`
Instance attribute: `self.batch_threshold` (int, defaults `100`).

## Interfaces
Not applicable formally — `check_retraining_status`'s returned dict shape (`pending_corrections`, `threshold`, `should_trigger_retraining`) is a small, self-contained contract.

## Hooks
Not applicable — though this class is exactly the kind of thing a real background-job scheduler or message-queue consumer would eventually hook into, once actually wired up.

## Utilities
None — two focused, related methods.

## Dependencies
`datetime`, `logging` (standard library); `database.mongo` (internal).

## Side Effects
- `check_retraining_status` is read-only (a `count_documents` call).
- `trigger_retraining_if_needed` performs a bulk `update_many` write when the threshold is met — the only write in this file, and the last thing this function does before returning (nothing after it ever executes, since the actual training-launch step was never implemented).
- Logs at every decision point.

## Performance Considerations
- `count_documents({"status": "pending"})` scans/counts based on the `status` field — no index exists on this field anywhere in the codebase, so this becomes a full collection scan as the queue grows, though the queue is presumably kept small in practice by frequent draining (once the missing training-trigger step is eventually implemented).
- `update_many` is used correctly here for a batch state transition — a single, efficient bulk write rather than iterating and updating documents one at a time.

## Possible Interview Questions
- "What exactly happens to records after they're marked 'processing,' given the actual training launch was never implemented?" (Nothing — they stay in the 'processing' state forever, since nothing in this codebase ever transitions them to 'completed' or back to 'pending.' This creates a permanent backlog: the next 100 pending corrections would need to accumulate from scratch before this function would trigger again, since the already-'processing' records no longer count toward the pending total.)
- "Why mark records as 'processing' *before* actually starting a training job, rather than after it successfully completes?" (Defensive locking — it prevents this same check from picking up and 'triggering' on the same batch of records again if it happens to run a second time in quick succession, e.g., from two nearly-simultaneous feedback submissions both crossing the threshold at once.)
- "If you were asked to finish this function, what would the missing piece look like?" (Something like calling `training.train.BaselineTrainer().run_benchmarks()` — ideally offloaded to a background worker/task queue rather than run synchronously inside this background task — followed by, on success, updating the now-'processing' records to a final 'completed' status, and on failure, likely reverting them back to 'pending' so they aren't lost.)
- "What's the risk of running this check from a `BackgroundTask` (as `feedback/api_router.py` does) rather than a dedicated worker process?" (Background tasks run within the same web-server process and share its resources — a long-running training job accidentally triggered this way (if the missing piece were implemented naively) could starve the server of resources needed to handle other incoming requests, which is exactly why the code's own comments reference wanting a separate Celery-based task queue instead.)
