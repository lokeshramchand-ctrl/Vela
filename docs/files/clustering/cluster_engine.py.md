# File: `clustering/cluster_engine.py`

## Purpose
Orchestrates the full Phase 8 unsupervised discovery pipeline: fetch stored embeddings, reduce them, cluster them, evaluate the result, and persist cluster assignments. **Currently cannot be imported or run** due to two independent bugs.

## Responsibilities
- Fetch all stored behavior vectors from Milvus.
- Run UMAP reduction and HDBSCAN clustering.
- Compute unsupervised evaluation metrics.
- Bulk-persist discovered cluster IDs back into MongoDB.

## Imports
| Import | Used for |
|---|---|
| `numpy` | Array handling for embeddings and labels |
| `logging` | Progress/error logging |
| `typing.Dict, Any` | Type hints |
| `sklearn.cluster.KMeans` | **Imported but never used anywhere in this file** — dead import |
| `sklearn.metrics.silhouette_score, davies_bouldin_index` | Clustering evaluation metrics — **`davies_bouldin_index` does not exist in scikit-learn** (the real name is `davies_bouldin_score`), so this import line raises `ImportError` the instant this module is loaded |
| `database.mongo.db` | Persisting cluster assignments |
| `milvus.insert_vectors.vector_store` | Fetching stored vectors (via a call that references a nonexistent attribute — see below) |
| `clustering.umap_projection.umap_projector` | Dimensionality reduction |
| `clustering.hdbscan_cluster.hdbscan_clusterer` | Density clustering |

## Exports
- **`ClusterEngine`** — the class (currently unreachable — the module fails to import).
- **`cluster_engine`** — the intended singleton instance.

## Execution Flow
**Intended**: fetch vectors → guard on minimum count → UMAP reduce → HDBSCAN cluster → compute metrics → persist cluster assignments → return summary. **Actual**: the module fails at the `from sklearn.metrics import ... davies_bouldin_index` line before any class or function in this file can even be defined — nothing in this file executes at all when imported.

## Functions (plain English)

### `ClusterEngine.run_discovery_pipeline(self) -> Dict[str, Any]` (async)
In simple English, as intended: "Go fetch every stored behavior vector we have from Milvus. If we don't have at least 10 of them, there's not enough data to find meaningful patterns, so just give up quietly and return nothing useful. Otherwise, compress all those vectors down to a smaller number of dimensions, then look for natural groupings among them. Measure how good those groupings are using a couple of standard clustering-quality scores. Save which cluster each merchant landed in back into the database. Finally, report a summary: how many merchants we processed, how many distinct clusters we found, how many were considered noise (didn't fit any cluster), and the quality metrics." As written, the call to fetch vectors (`vector_store.behavior_collection.query(...)`) references an attribute (`behavior_collection`) that doesn't exist on `vector_store` — even setting aside the import error, this specific line would raise `AttributeError` if it were ever reached.

### `ClusterEngine._calculate_metrics(self, data: np.ndarray, labels: np.ndarray) -> Dict[str, float]`
In simple English, as intended: "Given the clustered data and the cluster label each point was assigned, figure out how good the clustering actually is. First, throw out anything labeled as noise, since clustering-quality metrics don't apply to points that don't belong to any cluster. If we don't have at least 2 real clusters, there's nothing meaningful to measure, so just say so. Otherwise, compute two standard scores: silhouette score (close to 1.0 means the clusters are tight and well-separated; below 0 means they overlap badly) and the Davies-Bouldin index (lower is better, measuring how compact each cluster is relative to how far apart clusters are from each other)."

### `ClusterEngine._persist_clusters(self, names: list[str], labels: np.ndarray)` (async)
In simple English, as intended: "For every merchant and its assigned cluster label, prepare a database update saying 'this merchant belongs to this cluster' (or 'this merchant is noise' if it wasn't assigned to any real cluster). Do all of these updates in a single efficient batch operation instead of one at a time, and if we successfully updated at least one, log that we're done."

## Classes

### `ClusterEngine`
No instance state — orchestration class with three methods (one public entry point, two internal helpers).

## Interfaces
The summary dict returned by `run_discovery_pipeline` (`total_entities_processed`, `clusters_discovered`, `noise_entities`, `metrics`) is the intended output contract, though nothing in the codebase currently consumes it (no caller exists).

## Hooks
Not applicable.

## Utilities
`_calculate_metrics` and `_persist_clusters` are private helper methods supporting the one public entry point.

## Dependencies
`numpy`, `scikit-learn` (third-party — with one broken import); `database.mongo`, `milvus.insert_vectors`, `clustering.umap_projection`, `clustering.hdbscan_cluster` (internal).

## Side Effects
As intended: reads from Milvus, writes (bulk update) to MongoDB's `behavior_patterns` collection, logs throughout. As actually written: none of this ever executes, since the module fails to import.

## Performance Considerations
- `_persist_clusters` correctly uses `bulk_write` with a list of `UpdateOne` operations rather than individual `update_one` calls in a loop — a good performance choice for writing many cluster assignments at once, in contrast to some other batch operations in this codebase (e.g., `memory/decay_engine.py`) that do use a less efficient one-at-a-time pattern.
- The `< 10` results guard in `run_discovery_pipeline` avoids wasting UMAP/HDBSCAN computation on datasets too small to produce meaningful clusters.
- None of this matters currently, since the pipeline cannot run at all.

## Possible Interview Questions
- "This file has two independent bugs. Walk through both, and explain why fixing only one wouldn't be enough." (1. `from sklearn.metrics import ... davies_bouldin_index` — the real function is named `davies_bouldin_score`; this raises `ImportError` at module load, before anything else in the file can run. 2. `vector_store.behavior_collection.query(...)` — `VectorStoreManager` has no `behavior_collection` attribute, only `client` and `behavior_col_name`; this would raise `AttributeError` the moment it executed. Fixing only the import wouldn't make the pipeline functional — you'd immediately hit the second bug on the very next attempt to run it.)
- "Why is `sklearn.cluster.KMeans` imported but never used?" (Dead import — possibly leftover from an earlier draft of this file that considered k-means as an alternative to HDBSCAN before settling on HDBSCAN for its ability to find clusters of varying density and explicitly model noise.)
- "Why does `_persist_clusters` use `bulk_write` while some other batch-update code elsewhere in the codebase doesn't?" (A better-performing design choice for writing many documents at once — a good example of the kind of pattern worth applying consistently elsewhere, like in `memory/decay_engine.py`, which currently updates documents one at a time in a loop.)
- "Given this module can't even be imported today, how would you have discovered these bugs without being told about them?" (Attempting to actually run/import the module — `python -c "import clustering.cluster_engine"` — would immediately surface the `ImportError`; a static analysis tool or IDE with proper type-checking would also flag both the nonexistent `sklearn.metrics` name and the nonexistent attribute access on `vector_store`.)
