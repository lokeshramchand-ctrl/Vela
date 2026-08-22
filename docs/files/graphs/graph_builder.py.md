# File: `graphs/graph_builder.py`

## Purpose
Builds a cross-collection relational graph (merchants, memory states, behaviors, clusters, feedback) using NetworkX. The most architecturally isolated file in the codebase — fully implemented, but with zero callers anywhere.

## Responsibilities
- Fetch data from three MongoDB collections in one pass.
- Construct a directed graph connecting merchants to their memory state, behavior fingerprint, cluster assignment, and feedback history.
- Compute basic topology metrics.
- Extract a bounded local neighborhood around any given merchant.

## Imports
| Import | Used for |
|---|---|
| `networkx` | The graph data structure and algorithms (`DiGraph`, `density`, `ego_graph`) |
| `logging` | Progress/summary logging |
| `typing.Dict, Any, List` | Type hints |
| `database.mongo.db` | Fetching `merchant_profiles`, `behavior_patterns`, `feedback` |

## Exports
- **`KnowledgeGraphBuilder`** — the class.
- **`graph_engine`** — the singleton instance. **Not imported anywhere else in the codebase.**

## Execution Flow
On import, `graph_engine = KnowledgeGraphBuilder()` runs, creating one empty `nx.DiGraph()` instance attribute. If ever called: `build_graph()` clears and fully rebuilds the graph from three fresh MongoDB reads every time it's invoked (no incremental updates). `get_merchant_neighborhood(...)` can only usefully be called *after* `build_graph()` has run at least once in that process's lifetime — it operates purely on the in-memory graph state.

## Functions (plain English)

### `KnowledgeGraphBuilder.__init__(self)`
In simple English: "Create an empty directed graph to hold everything we're about to learn about how merchants, their trust states, their behaviors, their clusters, and human feedback all connect to each other." A "directed" graph means connections have a direction — for example, a merchant *has* a memory state, which is a one-way relationship, not a two-way one.

### `KnowledgeGraphBuilder.build_graph(self) -> Dict[str, Any]` (async)
In simple English: "Start completely fresh by wiping out whatever graph we had before. Go fetch every merchant profile, every behavioral pattern, and every piece of feedback we have on record — all of it, no filtering. For every merchant profile, add a node representing that merchant, and connect it to a node representing its current trust level (like 'Memory_PERMANENT'). Skip any profile that's missing a name entirely. Next, for every behavior pattern — but only if we already added a node for that exact merchant in the step before — add a node capturing its typical spend amount and how predictable its timing is, connected back to the merchant. If that behavior record also says which discovery cluster the merchant was grouped into (and it's not just 'noise'), add a node for that cluster too and connect the merchant to it. Finally, for every piece of feedback — again, only if the merchant it was about already has a node — add a node representing that specific feedback event, connected *from* the feedback *to* the merchant it concerns. Once everything's built, count up how many total nodes and connections we ended up with, and calculate how 'dense' the graph is (what fraction of all theoretically possible connections actually exist). Report that summary."

### `KnowledgeGraphBuilder.get_merchant_neighborhood(self, merchant_name: str, radius: int = 2) -> Dict[str, Any]`
In simple English: "If we've never even added a node for this merchant to our graph, say so with a clear error. Otherwise, extract just the small local neighborhood around this specific merchant — everything within 2 steps of connections away from it, by default — rather than the entire graph, which could be much bigger and less relevant. Convert that neighborhood into a simple, plain format (a list of nodes with their properties, and a list of connections with what kind of relationship each one represents) that's easy to turn into JSON or feed into a visualization tool."

## Classes

### `KnowledgeGraphBuilder`
Instance attribute: `self.graph` (an `nx.DiGraph`, created once in `__init__` and cleared/rebuilt by `build_graph`).

## Interfaces
Not applicable formally, though NetworkX's `DiGraph` API itself is the underlying interface this class builds on top of.

## Hooks
Not applicable.

## Utilities
None — two focused public methods, no smaller helpers.

## Dependencies
`networkx` (third-party); `database.mongo` (internal).

## Side Effects
- Reads (unfiltered, full-collection) from three MongoDB collections every time `build_graph()` runs.
- Mutates `self.graph` in place — a purely in-memory side effect that's lost entirely when the process restarts (the graph is never persisted to disk or a database).
- Logs a summary after each build.

## Performance Considerations
- `build_graph()` does three full, unfiltered collection scans every single time it's called (`merchant_profiles.find()`, `behavior_patterns.find()`, `feedback.find()`, each materialized fully into a Python list before processing begins) — this cost grows linearly with total data size and is repeated in full on every call, with no incremental/delta-based update mechanism.
- `nx.ego_graph` is an efficient, standard way to extract a bounded local neighborhood without traversing or copying the entire graph — appropriate for this use case regardless of overall graph size.
- Because the graph lives only in memory, exposing `build_graph()` as a live, frequently-called endpoint (which nothing currently does) would repeat this expensive full-rebuild cost on every single request — a real design concern if this were ever wired up naively.

## Possible Interview Questions
- "Why does `build_graph()` only add a `Behavior`/`Cluster`/`Feedback` node when the corresponding merchant node already exists, rather than adding it unconditionally?" (Ensures graph integrity — a behavior record or feedback event references a merchant by name, and if that merchant was never processed through the memory system (no profile exists), attaching data to a non-existent, unverified entity would create orphaned, potentially confusing nodes with no real merchant identity backing them.)
- "This module has literally zero callers anywhere in the repository — not even from other unused modules. How would you discover that, and what would you build to actually use this?" (A simple reverse-search — grep for `graph_engine`, `KnowledgeGraphBuilder`, or `build_graph` outside this file turns up nothing. To use it, you'd need at minimum a router exposing `build_graph()`/`get_merchant_neighborhood()` over HTTP, plus a decision about whether to rebuild on every request or cache/schedule rebuilds given the full-collection-scan cost described above.)
- "Why is the graph directed rather than undirected?" (Several of the relationships modeled here are inherently one-directional in meaning — a merchant *has* a memory state, is *repeated with* a behavior pattern, *belongs to* a cluster, and *receives* feedback — none of these are naturally symmetric relationships, so a directed graph correctly captures that asymmetry, unlike an undirected graph which would treat all edges as bidirectional.)
- "How would you persist this graph so it survives a process restart, and what trade-offs would that introduce?" (You could serialize it to a graph-native database like Neo4j, or simply dump/reload NetworkX's own serialization formats (e.g., GraphML, pickle) to a file or MongoDB document — the trade-off is added complexity in keeping a persisted graph in sync with the underlying source-of-truth collections as they change over time, versus this current design's simplicity of always rebuilding fresh from source data.)
