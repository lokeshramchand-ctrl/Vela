import logging
from datetime import UTC, datetime

from database.mongo import db

logger = logging.getLogger(__name__)

class RetrainingQueueManager:
    def __init__(self, batch_threshold: int = 100):
        # Number of pending corrections required to trigger a new model training run
        self.batch_threshold = batch_threshold

    async def check_retraining_status(self) -> dict:
        """
        Monitors the queue to see if enough concept drift / corrections
        have occurred to justify spinning up the Phase 9 baseline trainer.
        """
        pending_count = await db.retraining_queue.count_documents({"status": "pending"})
        should_retrain = pending_count >= self.batch_threshold

        return {
            "pending_corrections": pending_count,
            "threshold": self.batch_threshold,
            "should_trigger_retraining": should_retrain
        }

    async def trigger_retraining_if_needed(self) -> bool:
        """
        Checks the queue and triggers the background training pipeline if thresholds are met.
        In Phase 11/14, this will trigger a Celery task tracked by MLflow.
        """
        status = await self.check_retraining_status()

        if not status["should_trigger_retraining"]:
            logger.info(f"Retraining not needed yet. Pending: {status['pending_corrections']}/{self.batch_threshold}")
            return False

        logger.warning(f"Threshold reached ({status['pending_corrections']} corrections). Triggering Retraining Pipeline...")

        # 1. Lock the pending records so they aren't processed twice
        await db.retraining_queue.update_many(
            {"status": "pending"},
            {"$set": {"status": "processing", "processing_started_at": datetime.now(UTC)}}
        )

        # 2. Trigger your training pipeline (from Phase 9)
        # TODO: Launch `BaselineTrainer().run_benchmarks()` via Celery asynchronously here.

        return True

retraining_manager = RetrainingQueueManager()
