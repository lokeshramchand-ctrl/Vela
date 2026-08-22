import logging
from typing import Any

from database.mongo import db
from milvus.search_vectors import vector_search

logger = logging.getLogger(__name__)

class ContextRetriever:
    async def fetch_grounded_context(self, query_text: str, top_k: int = 3) -> list[dict[str, Any]]:
        """
        1. Semantic Search via Milvus to find relevant merchants.
        2. Deep query via MongoDB to fetch their structured histories.
        """
        # Step 1: Vector Search
        milvus_hits = await vector_search.find_similar_behaviors(query_text, top_k=top_k)

        if not milvus_hits:
            logger.warning(f"No semantic matches found in Milvus for query: {query_text}")
            return []

        merchant_names = [hit["merchant_name"] for hit in milvus_hits]

        # Step 2: Fetch Structured Context from MongoDB
        context_payloads = []
        for name in merchant_names:
            profile = await db.merchant_profiles.find_one({"canonical_name": name}, {"_id": 0})
            behavior = await db.behavior_patterns.find_one({"merchant_name": name}, {"_id": 0})

            # Fetch human feedback specifically targeting this merchant's predictions
            cursor = db.feedback.find({"merchant_name": name}).sort("timestamp", -1).limit(3)
            feedback = [doc async for doc in cursor]

            # Clean ObjectIds for JSON serialization
            for f in feedback:
                f.pop("_id", None)

            context_payloads.append({
                "merchant_name": name,
                "profile": profile or {},
                "behavior": behavior or {},
                "recent_feedback": feedback
            })

        return context_payloads

context_retriever = ContextRetriever()
