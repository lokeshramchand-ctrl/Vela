# File: `clustering/umap_projection.py`

## Purpose
Wraps UMAP dimensionality reduction with a fixed, named configuration, turning high-dimensional embeddings into a smaller space suitable for density-based clustering.

## Responsibilities
- Configure a UMAP reducer once, with reproducible settings.
- Reduce a batch of embeddings to fewer dimensions.

## Imports
| Import | Used for |
|---|---|
| `umap` | The UMAP dimensionality-reduction library |
| `numpy` | Type hint (`np.ndarray`) for input/output arrays |
| `logging` | Progress logging |

## Exports
- **`UMAPProjector`** — the class.
- **`umap_projector`** — the singleton instance, imported by `clustering/cluster_engine.py`.

## Execution Flow
On import, `umap_projector = UMAPProjector()` runs, constructing (but not yet fitting) a `umap.UMAP` reducer object with fixed hyperparameters. `reduce_dimensions(...)` is called once per clustering pipeline run, performing the actual (computationally significant) fit-and-transform work at that point.

## Functions (plain English)

### `UMAPProjector.__init__(self, n_neighbors=15, n_components=5, metric='cosine')`
In simple English: "Set up a dimensionality-reduction tool with these settings: look at each point's 15 nearest neighbors to understand local structure, compress everything down to just 5 dimensions, measure 'closeness' using cosine similarity (appropriate since our input vectors come from an embedding model where cosine is the natural similarity measure), and always use the same random starting point (`random_state=42`) so that running this on the same data twice gives the same result."

### `UMAPProjector.reduce_dimensions(self, embeddings: np.ndarray) -> np.ndarray`
In simple English: "Take a big batch of high-dimensional vectors (768 numbers each) and compress each one down to just 5 numbers, while trying to preserve which vectors were originally close together and which were far apart. This is the computationally expensive step where UMAP actually analyzes the whole dataset's structure and learns how to project it down."

## Classes

### `UMAPProjector`
Instance attribute: `self.reducer` (a `umap.UMAP` instance, configured once at construction).

## Interfaces
Not applicable formally — `reduce_dimensions(embeddings: np.ndarray) -> np.ndarray` is a simple array-in, array-out contract.

## Hooks
Not applicable.

## Utilities
None beyond the one method.

## Dependencies
`umap-learn` (third-party, imported as `umap`), `numpy` (third-party, for type hints).

## Side Effects
None beyond logging — this is a pure computational transformation with no I/O, though it can be CPU/memory-intensive for large inputs.

## Performance Considerations
- UMAP's `fit_transform` is the computationally heaviest step in the whole clustering pipeline — its cost scales with both the number of points and `n_neighbors`; for large datasets this can take significant time and memory.
- `random_state=42` sacrifices some potential parallelism/speed (UMAP's fully parallel mode can be faster but non-deterministic) in exchange for exact reproducibility across runs — a reasonable trade-off for a system where consistent, comparable clustering results across pipeline runs matters more than raw speed.
- `n_components=5` (versus a smaller number like 2, common for visualization) balances preserving more of the original structure against the fact that HDBSCAN (the next pipeline stage) needs enough dimensions to distinguish genuinely separate clusters, but not so many that density estimation suffers from the curse of dimensionality.

## Possible Interview Questions
- "Why reduce to 5 dimensions specifically, rather than 2 (common for visualization) or staying in the original 768?" (768 dimensions is too high for density-based clustering to work well — distances become less meaningful ('curse of dimensionality'). 2 dimensions is great for visualization but can lose too much structure for accurate clustering. 5 is a middle ground commonly used in practice when the goal is clustering quality rather than visualization.)
- "Why use `metric='cosine'` for the UMAP step specifically?" (The input vectors come from a text embedding model, where cosine similarity is the natural, standard way to measure semantic closeness — using the same metric UMAP uses to understand local structure keeps the reduction consistent with how the embeddings were designed to be compared.)
- "What does `random_state=42` actually control, and why does it matter here?" (It seeds UMAP's internal random number generator, used during its optimization process — setting it fixes the outcome so that running this exact code on the exact same input data always produces the same reduced output, which matters for reproducible, comparable clustering results across pipeline runs.)
- "If you doubled the size of the input dataset, how would that affect this function's runtime?" (UMAP's complexity is worse than linear in the number of points for the nearest-neighbor graph construction step, though approximate nearest-neighbor techniques it uses internally keep this from being quadratic — in practice, expect noticeably more than double the runtime, not exactly double.)
