# File: `clustering/hdbscan_cluster.py`

## Purpose
Wraps HDBSCAN density-based clustering with a fixed configuration, finding natural groupings (and outliers) in the UMAP-reduced embedding space.

## Responsibilities
- Configure an HDBSCAN clusterer once.
- Run clustering on a batch of reduced-dimension data.
- Log a summary of what was found.

## Imports
| Import | Used for |
|---|---|
| `sklearn.cluster.HDBSCAN` | The density-clustering algorithm |
| `numpy` | Type hints |
| `logging` | Progress/summary logging |

## Exports
- **`DensityClusterer`** — the class.
- **`hdbscan_clusterer`** — the singleton instance, imported by `clustering/cluster_engine.py`.

## Execution Flow
On import, `hdbscan_clusterer = DensityClusterer()` runs, constructing (but not fitting) an `HDBSCAN` instance. `fit_predict(...)` is called once per clustering pipeline run.

## Functions (plain English)

### `DensityClusterer.__init__(self, min_cluster_size=5, min_samples=3)`
In simple English: "Set up a clustering tool that requires at least 5 points close together to call something a real cluster (fewer than that gets treated as noise, not a group), uses a slightly more conservative core-point definition (`min_samples=3`) to decide what counts as 'dense enough,' and measures closeness using plain straight-line (euclidean) distance — appropriate since the input here has already been through UMAP, which produces a space where euclidean distance is meaningful."

### `DensityClusterer.fit_predict(self, data: np.ndarray) -> np.ndarray`
In simple English: "Look at this batch of (UMAP-reduced) points and figure out which ones naturally cluster together into dense groups, and which ones don't really belong to any group (labeled as noise, using a special label of -1). Count how many real clusters were found and how many points were called noise, log that summary, and hand back the list of cluster labels — one per input point, in the same order they came in."

## Classes

### `DensityClusterer`
Instance attribute: `self.clusterer` (an `HDBSCAN` instance, configured once at construction).

## Interfaces
Not applicable formally — `fit_predict(data) -> labels` mirrors scikit-learn's standard clusterer interface convention.

## Hooks
Not applicable.

## Utilities
None beyond the one method.

## Dependencies
`scikit-learn` (third-party, providing `HDBSCAN`), `numpy` (third-party, for type hints).

## Side Effects
None beyond logging — a pure computational step with no I/O.

## Performance Considerations
- HDBSCAN's runtime scales with the number of points and the chosen `min_samples`/`min_cluster_size` — generally much cheaper than the preceding UMAP step for typical dataset sizes, since it operates on the already-reduced 5-dimensional space rather than the original 768 dimensions.
- Unlike k-means-style algorithms, HDBSCAN doesn't require specifying the number of clusters in advance — it discovers that automatically, which is well-suited to this use case where the "true" number of natural merchant groupings is genuinely unknown ahead of time.

## Possible Interview Questions
- "Why `min_cluster_size=5` specifically?" (A judgment call balancing sensitivity against noise tolerance — requiring at least 5 similar entities to call something a genuine cluster avoids treating small coincidental groupings as meaningful patterns, while not being so strict that only very large, obvious clusters get recognized.)
- "What does a label of `-1` mean, and is it an error?" (No — it's HDBSCAN's standard way of marking a point as 'noise,' meaning it doesn't fit densely enough into any discovered cluster. It's an expected, normal outcome for outlier merchants whose behavior doesn't resemble any group.)
- "Why is `metric='euclidean'` appropriate here, given the earlier UMAP step used `metric='cosine'`?" (UMAP's output space is constructed such that euclidean distance in the reduced space meaningfully reflects the relationships UMAP learned — it's standard practice to switch to euclidean distance for the *clustering* step after a UMAP reduction, even if the original embedding space used cosine similarity.)
- "How would you decide whether `min_cluster_size=5` and `min_samples=3` are the 'right' values for this dataset?" (You'd typically experiment across a range of values and evaluate results using metrics like the silhouette score or Davies-Bouldin index — computed by `clustering/cluster_engine.py`'s `_calculate_metrics` — to see which configuration produces the most cohesive, well-separated clusters for the actual data at hand, rather than relying on fixed defaults.)
