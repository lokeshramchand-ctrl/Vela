import logging
from typing import Any

# Assuming this is your embedding generator path based on previous tracebacks
from embeddings.generate_embeddings import embedding_generator
from milvus.insert_vectors import vector_store

logger = logging.getLogger(__name__)

class VectorSearchEngine:
    async def find_similar_behaviors(self, query_text: str, top_k: int = 3) -> list[dict[str, Any]]:
        """
        Converts text to an embedding and searches Milvus for semantic matches.
        """
        try:
            # Generate the vector for the search query
            query_vector = await embedding_generator.generate(query_text)

            # Modern MilvusClient search syntax
            search_results = vector_store.client.search(
                collection_name=vector_store.behavior_col_name,
                data=[query_vector],
                limit=top_k,
                output_fields=["merchant_name"], # Request the payload data back
                search_params={"metric_type": "COSINE", "params": {"ef": 64}}
            )

            # Format the output cleanly
            formatted_results = []
            if search_results and len(search_results) > 0:
                for hit in search_results[0]:
                    formatted_results.append({
                        "merchant_name": hit.get("entity", {}).get("merchant_name", "Unknown"),
                        "similarity_score": round(hit.get("distance", 0.0), 4),
                        "id": hit.get("id")
                    })

            return formatted_results

        except Exception as e:
            logger.error(f"Vector search failed: {e}")
            return []

vector_search = VectorSearchEngine()
