import logging
from typing import Any

import numpy as np
from sklearn.metrics import davies_bouldin_score, silhouette_score

from clustering.hdbscan_cluster import hdbscan_clusterer
from clustering.umap_projection import umap_projector
from database.mongo import db
from milvus.insert_vectors import vector_store

logger = logging.getLogger(__name__)

class ClusterEngine:
    async def run_discovery_pipeline(self) -> dict[str, Any]:
        """
        Pulls vectors from Milvus, runs UMAP + HDBSCAN, evaluates metrics,
        and assigns cluster IDs back to the database.
        """
        logger.info("Initiating Phase 8 Clustering Pipeline...")

        # 1. Fetch Vectors from Milvus
        # We query for all entities that have an embedding.
        try:
            if vector_store.client is None:
                logger.error("Milvus client not connected; cannot fetch vectors.")
                return {}
            results = vector_store.client.query(
                collection_name=vector_store.behavior_col_name,
                filter="id != ''",
                output_fields=["merchant_name", "embedding"]
            )
        except Exception as e:
            logger.error(f"Failed to fetch vectors from Milvus: {e}")
            return {}

        if len(results) < 10:
            logger.warning("Not enough data to run meaningful clustering (need >10).")
            return {}

        merchant_names = [res["merchant_name"] for res in results]
        embeddings = np.array([res["embedding"] for res in results])

        # 2. UMAP Projection
        reduced_embeddings = umap_projector.reduce_dimensions(embeddings)

        # 3. HDBSCAN Clustering
        cluster_labels = hdbscan_clusterer.fit_predict(reduced_embeddings)

        # 4. Metrics Evaluation
        metrics = self._calculate_metrics(reduced_embeddings, cluster_labels)

        # 5. Persist Discoveries to MongoDB
        await self._persist_clusters(merchant_names, cluster_labels)

        return {
            "total_entities_processed": len(merchant_names),
            "clusters_discovered": len(set(cluster_labels)) - (1 if -1 in cluster_labels else 0),
            "noise_entities": list(cluster_labels).count(-1),
            "metrics": metrics
        }

    def _calculate_metrics(self, data: np.ndarray, labels: np.ndarray) -> dict[str, float]:
        """Calculates unsupervised evaluation metrics."""
        # Metrics require at least 2 valid clusters, and ignore -1 (noise) for pure cluster math
        valid_mask = labels != -1
        valid_data = data[valid_mask]
        valid_labels = labels[valid_mask]

        n_clusters = len(set(valid_labels))

        if n_clusters < 2:
            return {"silhouette_score": 0.0, "davies_bouldin": 0.0, "note": "Not enough clusters for metrics"}

        return {
            # Silhouette: Near 1.0 means clusters are dense and well-separated. < 0 means overlapping.
            "silhouette_score": round(float(silhouette_score(valid_data, valid_labels)), 4),
            # Davies Bouldin: Lower is better. Measures ratio of within-cluster scatter to between-cluster separation.
            "davies_bouldin": round(float(davies_bouldin_score(valid_data, valid_labels)), 4)
            # Note: Cluster Purity requires labeled ground-truth data, which we will calculate later
            # when comparing against Phase 2 Rule Engine outputs.
        }

    async def _persist_clusters(self, names: list[str], labels: np.ndarray):
        """Updates the MongoDB profiles with their newly discovered cluster IDs."""
        from pymongo import UpdateOne

        operations = []
        for name, label in zip(names, labels, strict=True):
            cluster_id = f"cluster_{label}" if label != -1 else "noise"

            # Upsert the cluster ID into a dedicated collection or update the profile
            operations.append(
                UpdateOne(
                    {"merchant_name": name},
                    {"$set": {"discovered_cluster": cluster_id}},
                    upsert=True
                )
            )

        if operations:
            await db.behavior_patterns.bulk_write(operations)
            logger.info("Saved cluster assignments to database.")

cluster_engine = ClusterEngine()
