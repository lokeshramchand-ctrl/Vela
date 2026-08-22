from database.mongo import db
from features.amount_features import amount_extractor
from features.frequency_features import frequency_extractor
from features.periodicity import periodicity_extractor
from features.temporal_features import temporal_extractor
from models.schemas import BehaviorPattern


class BehaviorEngine:
    async def profile_merchant_behavior(self, merchant_name: str) -> BehaviorPattern:
        """
        Aggregates all historical entries for a specific merchant name
        to isolate and model its underlying behavioral signature.
        """
        # Fetch all transactions matching this target entity
        cursor = db.transactions.find({"merchant": merchant_name})
        transactions = [doc async for doc in cursor]

        if not transactions:
            raise ValueError(f"No transaction footprint found for entity: {merchant_name}")

        amounts = [t["amount"] for t in transactions]
        timestamps = [t["timestamp"] for t in transactions]

        # Compute sub-components
        temporal = temporal_extractor.extract_temporal_metrics(timestamps)
        stats = amount_extractor.extract_statistical_metrics(amounts)
        frequency_data = frequency_extractor.extract_frequency_metrics(timestamps)
        periodicity = periodicity_extractor.calculate_periodicity(timestamps)
        # Combine into complete Behavior Pattern schema
        pattern = BehaviorPattern(
            merchant_name=merchant_name,
            avg_amount=stats["avg_amount"],
            median_amount=stats["median_amount"],
            variance=stats["variance"],
            std_dev=stats["std_dev"],
            entropy_score=stats["entropy_score"],
            preferred_hour=temporal["preferred_hour"],
            time_bucket_distribution=temporal["time_bucket_distribution"],
            weekday_distribution=temporal["weekday_distribution"],
            daily_frequency=frequency_data["daily_frequency"],
            weekly_frequency=frequency_data["weekly_frequency"],
            periodicity_score=periodicity["periodicity_score"]
        )

        # Persist profile or update existing record
        await db.behavior_patterns.update_one(
            {"merchant_name": merchant_name},
            {"$set": pattern.model_dump(by_alias=True, exclude={"id"})},
            upsert=True
        )

        return pattern

behavior_engine = BehaviorEngine()
