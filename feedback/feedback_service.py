import logging
from datetime import UTC, datetime
from typing import Any

from bson import ObjectId
from bson.errors import InvalidId

from database.mongo import db

logger = logging.getLogger(__name__)

class FeedbackService:
    async def _lookup_merchant_name(self, transaction_id: str) -> str | None:
        """Resolves the merchant name tied to a transaction, so feedback can be
        joined back to a merchant (rather than only to a category prediction)."""
        try:
            oid = ObjectId(transaction_id)
        except (InvalidId, TypeError):
            return None
        transaction = await db.transactions.find_one({"_id": oid}, {"merchant": 1})
        return transaction.get("merchant") if transaction else None

    async def process_feedback(self, transaction_id: str, original_prediction: str, corrected_category: str, confidence: float, user_id: str = "system_user") -> dict[str, Any]:
        """
        Logs human feedback. If the human corrects the model, it routes the
        transaction to the retraining queue for Active Learning.
        """
        is_correction = original_prediction != corrected_category
        merchant_name = await self._lookup_merchant_name(transaction_id)

        feedback_doc = {
            "transaction_id": transaction_id,
            "merchant_name": merchant_name,
            "prediction": original_prediction,
            "corrected_category": corrected_category,
            "confidence": confidence,
            "is_correction": is_correction,
            "user_id": user_id,
            "timestamp": datetime.now(UTC)
        }

        # 1. Save to the main feedback dataset
        await db.feedback.insert_one(feedback_doc)

        logger.info(f"Feedback logged for TX {transaction_id}. Correction made: {is_correction}")

        # 2. If the model was wrong, queue it for the next retraining batch
        if is_correction:
            await self._queue_for_retraining(transaction_id, corrected_category, original_prediction)

        return feedback_doc

    async def _queue_for_retraining(self, transaction_id: str, verified_category: str, failed_prediction: str):
        """Pushes the corrected transaction into the Active Learning queue."""
        queue_doc = {
            "transaction_id": transaction_id,
            "verified_category": verified_category,
            "failed_prediction": failed_prediction,
            "status": "pending",
            "added_at": datetime.now(UTC)
        }
        await db.retraining_queue.insert_one(queue_doc)
        logger.info(f"TX {transaction_id} queued for Active Learning retraining.")

feedback_service = FeedbackService()
