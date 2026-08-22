from typing import Any

from database.mongo import db


class SubscriptionEngine:
    async def identify_active_subscriptions(self, user_id: str) -> list[dict[str, Any]]:
        """
        Leverages Phase 6 Periodicity Scores to isolate active subscriptions,
        calculating the total fixed monthly burn rate.
        """
        # Join user transactions with the global behavior patterns we calculated in Phase 6
        pipeline = [
            {"$match": {"user_id": user_id}},
            {"$group": {"_id": "$merchant", "last_amount": {"$last": "$amount"}, "last_seen": {"$max": "$timestamp"}}},
            {"$lookup": {
                "from": "behavior_patterns",
                "localField": "_id",
                "foreignField": "merchant_name",
                "as": "behavior"
            }},
            {"$unwind": "$behavior"},
            # Filter for high periodicity (e.g., score > 0.85 means highly predictable intervals)
            {"$match": {"behavior.periodicity_score": {"$gte": 0.85}}}
        ]

        cursor = db.transactions.aggregate(pipeline)
        subscriptions = []

        async for doc in cursor:
            subscriptions.append({
                "merchant": doc["_id"],
                "estimated_monthly_cost": doc["last_amount"],
                "periodicity_score": doc["behavior"]["periodicity_score"],
                "last_billed": doc["last_seen"]
            })

        return subscriptions

subscription_engine = SubscriptionEngine()
