import logging

import numpy as np
from sklearn.cluster import HDBSCAN

logger = logging.getLogger(__name__)

class DensityClusterer:
    def __init__(self, min_cluster_size=5, min_samples=3):
        # min_cluster_size: Minimum number of entities to form a valid group (e.g., 5 similar merchants)
        self.clusterer = HDBSCAN(
            min_cluster_size=min_cluster_size,
            min_samples=min_samples,
            metric='euclidean' # UMAP output works best with standard euclidean distance
        )

    def fit_predict(self, data: np.ndarray) -> np.ndarray:
        logger.info("Running HDBSCAN density clustering...")
        labels = self.clusterer.fit_predict(data)

        n_clusters = len(set(labels)) - (1 if -1 in labels else 0)
        noise_points = list(labels).count(-1)

        logger.info(f"Discovery Complete: Found {n_clusters} distinct clusters. Ignored {noise_points} noisy outliers.")
        return labels

hdbscan_clusterer = DensityClusterer()
