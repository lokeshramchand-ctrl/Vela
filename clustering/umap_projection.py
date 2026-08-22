import logging

import numpy as np
import umap

logger = logging.getLogger(__name__)

class UMAPProjector:
    def __init__(self, n_neighbors=15, n_components=5, metric='cosine'):
        # UMAP configuration optimized for semantic clustering
        self.reducer = umap.UMAP(
            n_neighbors=n_neighbors,
            n_components=n_components,
            metric=metric,
            random_state=42  # Ensuring reproducible pipeline runs
        )

    def reduce_dimensions(self, embeddings: np.ndarray) -> np.ndarray:
        logger.info(f"Running UMAP reduction: {embeddings.shape[1]}D -> {self.reducer.n_components}D")
        reduced_data = self.reducer.fit_transform(embeddings)
        return reduced_data

umap_projector = UMAPProjector()
