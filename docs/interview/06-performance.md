# Performance — 15 Questions

---

### P1. What's the single biggest performance risk in this entire system, and why does it outrank every other candidate?
- **Difficulty:** Medium | **Importance:** 10
- **Expected Answer:** Zero MongoDB indexes anywhere in the codebase (confirmed by grep — the only index in either database is Milvus's HNSW vector index). Every `find_one`, every `$match`, every `$lookup` is a full collection scan. This outranks other candidates (like sequential I/O or blocking sleeps) because it affects *every single database query in the application*, and its cost grows unboundedly with data volume, whereas most other performance issues here are localized to specific endpoints.
- **Follow-ups:** "Why does this matter more at scale than the sequential-I/O issue in `rag/retriever.py`?"
- **Common Mistakes:** Naming a more "interesting" or specific bottleneck (like the blocking `time.sleep` in Milvus's connect retry) as the biggest issue, without weighing breadth of impact.
- **What This Tests:** Prioritization by breadth of impact, not just individual defect severity.
- **Red Flags:** Names a narrow, single-endpoint issue as "the biggest" without comparing it against systemic ones.
- **Excellent Answer:** Explicitly frames this as a multiplier: fixing the sequential-I/O issue in one function saves latency in one code path; adding indexes improves every query, everywhere, permanently, and gets *more* valuable as the system grows, not less.
- **Poor Answer:** Names a real but narrow issue without articulating why breadth matters more here.

---

### P2. Why is `database/milvus.py::VectorDB.connect`'s retry loop a real performance problem specifically because it's inside an `async` function, not just because it retries?
- **Difficulty:** Hard | **Importance:** 8
- **Expected Answer:** It uses `time.sleep(delay)` — a *blocking* call — inside code invoked from `app.py`'s async `lifespan`. This freezes the entire event loop for up to `retries × delay` (15 seconds by default) during startup: no other coroutine, not just ones related to Milvus, can make any progress during that window. `asyncio.sleep(delay)` would yield control back to the event loop instead, letting unrelated startup work proceed concurrently.
- **Follow-ups:** "Does this matter if it only happens once, at startup?" "What if Milvus is flaky and this reconnect logic ran mid-request instead?"
- **Common Mistakes:** Saying "retrying with a fixed delay is bad practice" without identifying the specific `time.sleep` vs. `asyncio.sleep` distinction that makes this an event-loop-blocking bug rather than just a slow retry.
- **What This Tests:** Precise `asyncio` knowledge — many candidates know retries can be slow but don't articulate *why* a blocking sleep inside async code is qualitatively different from a slow-but-non-blocking one.
- **Red Flags:** Doesn't distinguish `time.sleep` from `asyncio.sleep` at all.
- **Excellent Answer:** Notes that since this specifically happens during startup (before the server accepts traffic), the practical impact today is "slow startup," not "frozen production traffic" — but flags that the exact same anti-pattern reused anywhere in a request-handling path would be far more serious, since it would freeze the *entire* server, not just delay one request.
- **Poor Answer:** Correctly identifies retries are slow without engaging with the blocking-vs-async distinction.

---

### P3. Quantify, as precisely as the code allows, the worst-case latency of a single `POST /v1/explain` call.
- **Difficulty:** Hard | **Importance:** 8
- **Expected Answer:** Roughly the sum of: the embedding call's 15-second timeout (`embeddings/generate_embeddings.py`), Milvus search time (unbounded but typically fast), up to `top_k × 3 = 9` sequential MongoDB round trips (each individually cheap but summed in series, not parallel), and the generation call's 30-second timeout (`rag/generator.py`). In the worst case (both external calls timing out), this could approach 45+ seconds for one request, though that specific combination (both timing out) would also mean the caller gets an error response, not a slow success.
- **Follow-ups:** "Which single change would reduce this worst case the most?"
- **Common Mistakes:** Only citing one of the two timeout values (15s or 30s) without recognizing they're both in the same request path and can both contribute.
- **What This Tests:** Ability to trace a multi-stage async pipeline and sum its sequential dependencies accurately.
- **Red Flags:** Estimates latency without referencing the actual timeout values found in the code.
- **Excellent Answer:** Identifies parallelizing the per-merchant Mongo lookups (via `asyncio.gather`) as the highest-leverage single fix, since it's the only stage with genuine, currently-unexploited parallelism opportunity — the two Ollama calls are inherently sequential (generation needs the retrieved context, which needs the embedding).
- **Poor Answer:** Gives a rough guess without citing specific timeout values from the code.

---

### P4. Why does `services/merchant_resolver.py`'s fallback substring match potentially cost more the *longer* the input text is?
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** The fallback loop iterates every word (≥4 characters) in the cleaned input text and issues one MongoDB `$regex` query per word until a match is found or the words run out — so a long, unmatched input string (worst case) triggers proportionally more sequential database round trips than a short one. Combined with the total lack of an index on `merchants.aliases`, each of those queries is also individually a collection scan.
- **Follow-ups:** "How would you cap the worst-case cost without changing the matching logic itself?"
- **Common Mistakes:** Assuming the cost is fixed regardless of input length, since "it's just one function call."
- **What This Tests:** Recognizing that a function's *asymptotic* cost can depend on its *input's* shape, not just be a fixed constant — an easy thing to overlook in a short, simple-looking loop.
- **Red Flags:** Treats the function as O(1) cost regardless of input.
- **Excellent Answer:** Proposes capping the number of words actually attempted (e.g., only try the first N qualifying words) as a cheap mitigation that bounds worst-case cost without requiring the deeper architectural fix (an index, or replacing this with the codebase's own suggested long-term direction — Milvus semantic search).
- **Poor Answer:** No engagement with the input-length-dependent cost at all.

---

### P5. Why does adding indexes NOT fix `graphs/graph_builder.py::build_graph`'s performance problem?
- **Difficulty:** Hard | **Importance:** 6
- **Expected Answer:** Its three queries (`merchant_profiles.find()`, `behavior_patterns.find()`, `feedback.find()`) have **no filter conditions at all** — they fetch every document in each collection unconditionally. Indexes speed up queries that filter or sort on specific fields; a query with no `$match` clause has nothing for an index to help with, since every document must be read regardless. The actual fix here is architectural (incremental fetching, filtering by a "modified since" timestamp), not indexing.
- **Follow-ups:** "What's the minimum schema change needed to support an incremental version of this function?"
- **Common Mistakes:** Reflexively proposing "add an index" as the fix for every slow-query problem, without checking whether the query even has a filterable predicate.
- **What This Tests:** Recognizing that indexing is not a universal performance fix — a genuinely important distinction many candidates miss.
- **Red Flags:** Proposes indexing as the fix without checking that these specific queries have no filter clause.
- **Excellent Answer:** Proposes adding a `last_updated`/`last_modified` timestamp field consistently across the relevant collections (some already have one, like `behavior_patterns.last_updated`, others like `merchant_profiles` have `last_seen` which serves a related but not identical purpose) and filtering `build_graph`'s queries to only documents changed since the last graph build.
- **Poor Answer:** Suggests indexing without noticing the queries are unconditional.

---

### P6. `memory/decay_engine.py::run_archive_sweep` updates documents one at a time in a loop, while `clustering/cluster_engine.py::_persist_clusters` uses a single `bulk_write`. Quantify the performance difference for, say, 10,000 stale profiles.
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** The decay engine's loop issues 10,000 separate `update_one` round trips to MongoDB, each paying its own network latency overhead; `bulk_write` batches many operations into far fewer round trips (subject to MongoDB's batch size limits), dramatically reducing total network overhead for the same logical amount of work. For 10,000 documents, this is plausibly the difference between many seconds/minutes and a small fraction of that.
- **Follow-ups:** "Rewrite `run_archive_sweep` to use a single operation instead of a loop at all."
- **Common Mistakes:** Assuming the difference is negligible without considering network round-trip overhead specifically (as opposed to the database's own processing time, which is comparatively fast either way).
- **What This Tests:** Understanding that round-trip *count*, not just total data volume, is often the dominant cost in this kind of batch operation.
- **Red Flags:** Doesn't distinguish "10,000 operations" from "10,000 network round trips" as the actual cost driver.
- **Excellent Answer:** Provides the actual one-line fix: a single `update_many({"last_seen": {"$lt": cutoff}, "memory_state": {"$ne": "ARCHIVED"}}, {"$set": {"memory_state": "ARCHIVED"}})` call replaces the entire loop, requiring zero per-document Python logic and one round trip regardless of how many documents match.
- **Poor Answer:** Recommends `bulk_write` as an improvement without recognizing `update_many` is an even simpler, more direct fix for this specific case (since every matched document gets the identical update).

---

### P7. Why might pre-compiling regex patterns in `engines/rule_engine.py` at startup become a liability rather than an asset if the alias dictionary grew to 100,000 entries?
- **Difficulty:** Hard | **Importance:** 5
- **Expected Answer:** Startup time would grow with the size of the dictionary (compiling 100,000 individual regex patterns is not free), and — more importantly — `categorize()`'s linear scan through all compiled patterns for every single call would become the dominant per-request cost, since there's no early-exit optimization beyond "first match wins" and no indexing structure (like a trie or Aho-Corasick automaton) for efficiently checking many patterns against one string simultaneously.
- **Follow-ups:** "What data structure would you use instead, and why?"
- **Common Mistakes:** Assuming pre-compilation alone solves scalability regardless of dictionary size — it solves the "don't recompile per request" problem but not the "linearly scan N patterns per request" problem.
- **What This Tests:** Recognizing that an optimization appropriate at one scale (9 aliases today) can become insufficient at another scale, and understanding what the *next* bottleneck would be.
- **Red Flags:** Treats regex pre-compilation as a permanently sufficient solution regardless of scale.
- **Excellent Answer:** Names Aho-Corasick (a multi-pattern string-matching algorithm) as the appropriate data structure for efficiently checking many fixed patterns against one input string in roughly linear time regardless of pattern count, in contrast to the current linear-scan-of-N-regexes approach.
- **Poor Answer:** No specific alternative data structure proposed.

---

### P8. Why does using `secondaryPreferred` read preference for `analytics/*.py`'s queries make sense, but doing the same for `memory/memory_manager.py`'s reads would be risky?
- **Difficulty:** Hard | **Importance:** 6
- **Expected Answer:** Analytics queries are read-heavy, tolerant of slightly stale data (a spend breakdown being a few seconds out of date is inconsequential), and would benefit from offloading load to secondary replicas. `memory/memory_manager.py::process_encounter` reads a profile immediately before deciding how to mutate and write it back — if that read hit a lagging secondary, it could see stale `frequency`/`memory_state` values, making an incorrect promotion decision based on outdated data (worse than the race condition already discussed in Backend B7, since it's a *systematic* staleness risk, not just a rare concurrent-request race).
- **Follow-ups:** "How would you configure this selectively, on a per-query basis, in Motor?"
- **Common Mistakes:** Proposing a single, application-wide read-preference setting without recognizing different query patterns have different staleness tolerance.
- **What This Tests:** Nuanced trade-off reasoning connecting a database configuration choice to a specific, previously-discussed correctness risk.
- **Red Flags:** Proposes a blanket configuration change with no differentiation by query type.
- **Excellent Answer:** Notes Motor supports per-query read preference overrides (not just a client-wide default), meaning this could be applied surgically to `analytics/`'s specific query call sites without touching `memory/`'s.
- **Poor Answer:** Doesn't connect this to the read-modify-write pattern discussed elsewhere.

---

### P9. What's the performance cost of this application running as a single Uvicorn worker with no `--workers` flag or process manager?
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** All requests share one Python process and one event loop — CPU-bound work (regex matching, feature-extraction math, SHAP computation if that pipeline were ever live-triggered) blocks the entire event loop for the duration of that computation, meaning *every other concurrent request* stalls, not just the one doing the CPU work. I/O-bound work (the majority of this codebase's actual per-request cost) is fine under a single worker, since `asyncio` handles concurrent I/O well — but any accidental CPU-heavy code path is a much bigger problem here than it would be with multiple worker processes.
- **Follow-ups:** "Which endpoint in this codebase is most at risk of this specific problem?"
- **Common Mistakes:** Assuming a single worker is inherently bad for all workloads, without distinguishing I/O-bound (fine) from CPU-bound (risky) work.
- **What This Tests:** Correct mental model of when single-process `asyncio` concurrency is sufficient vs. insufficient.
- **Red Flags:** Says "single worker is always bad" without the I/O-vs-CPU distinction.
- **Excellent Answer:** Identifies `/v1/explain`'s pipeline as the least risky (it's almost entirely awaited I/O) but flags that if `training/`'s scripts, `clustering/`'s UMAP/HDBSCAN computation, or `evaluation/metrics.py`'s SHAP calculation were ever triggered from a live request instead of a standalone script, they'd be genuinely CPU-bound work that would stall the entire server for every other concurrent user.
- **Poor Answer:** General "should use multiple workers" without connecting it to which parts of this codebase are actually at risk.

---

### P10. Why does the global `DEBUG`-level logging configuration in `app.py` matter for performance, not just log noise?
- **Difficulty:** Medium | **Importance:** 4
- **Expected Answer:** Every `logger.debug(...)` call anywhere in the codebase actually formats and emits its message at this level (since the root logger accepts `DEBUG` and up), rather than being a cheap no-op — string formatting and I/O to whatever log handler is configured happen on every call, adding real (if individually small) overhead per request, multiplied across every module's debug statements, under any request volume.
- **Follow-ups:** "How would you make this configurable per environment without a code change per deploy?"
- **Common Mistakes:** Assuming log level only affects what's *displayed*, not what work is actually performed to produce a log line.
- **What This Tests:** Understanding that logging isn't free even when you don't look at the output — the cost is in producing the line, not just storing/displaying it.
- **Red Flags:** Says log level only affects filtering after the fact with zero cost to produce a suppressed line (not strictly true — the log call itself still executes, including any string formatting, unless lazy `%`-style formatting is used correctly).
- **Excellent Answer:** Notes that even with lazy `%`-style formatting (which this codebase's `logger.info(f"...")`-style f-string calls do *not* consistently use — several format strings eagerly interpolate before the logger decides whether to emit), the interpolation cost is paid regardless of the configured level, since f-strings evaluate immediately at the call site.
- **Poor Answer:** Only discusses log volume/noise, not the underlying formatting cost.

---

### P11. Why is Milvus's `ef=64` search parameter (in `milvus/search_vectors.py`) a performance/accuracy trade-off, and what would happen if it were set to `8`?
- **Difficulty:** Hard | **Importance:** 5
- **Expected Answer:** `ef` (in HNSW search) controls how many candidate nodes are explored during the graph traversal at query time — higher values explore more of the graph, improving recall (finding the true nearest neighbors more reliably) at the cost of query latency; lower values search faster but risk missing genuinely relevant matches, returning lower-quality (or simply fewer correct) results. Setting it to `8` would make searches faster but would meaningfully increase the risk of `/v1/explain` missing a real semantic match that a higher `ef` would have found.
- **Follow-ups:** "How would you determine the right `ef` value empirically for this specific dataset?"
- **Common Mistakes:** Confusing `ef` (search-time parameter) with `efConstruction` (index-build-time parameter) — they serve related but distinct purposes.
- **What This Tests:** Precise understanding of HNSW's tunable parameters, a common area of superficial-vs-deep knowledge gap.
- **Red Flags:** Conflates `ef` and `efConstruction`.
- **Excellent Answer:** Proposes an empirical approach: run a benchmark set of known query/expected-match pairs against varying `ef` values, plotting recall against p99 latency, to find the elbow point appropriate for this system's actual latency budget (bounded above by the 30-second generation timeout that follows it anyway).
- **Poor Answer:** Describes `ef` correctly but has no proposal for how to actually tune it for this system.

---

### P12. Rank these three performance issues by expected real-world impact, and justify the ranking: (a) missing MongoDB indexes, (b) sequential I/O in `rag/retriever.py`, (c) the blocking `time.sleep` in Milvus's connect retry.
- **Difficulty:** Expert | **Importance:** 8
- **Expected Answer:** (a) missing indexes ranks highest — affects every query, every endpoint, and gets worse over time as data grows, with no natural ceiling. (b) sequential I/O ranks second — affects one endpoint (`/v1/explain`) but that endpoint is already the slowest in the system, so the fix has a proportionally large relative impact there. (c) the blocking sleep ranks lowest — it's a one-time startup cost, bounded at 15 seconds, that never recurs during steady-state operation and doesn't affect request-serving latency at all once the process is up.
- **Follow-ups:** "Would your ranking change if this system had 100x the current data volume?"
- **Common Mistakes:** Ranking based on "how interesting/subtle the bug is" rather than actual measured or reasoned impact on users.
- **What This Tests:** Whether the candidate can produce a defensible, reasoned prioritization rather than a list with no justification for order.
- **Red Flags:** Ranks the blocking-sleep issue highest because it's the most "obviously wrong-looking" code, without weighing its actual bounded, one-time impact.
- **Excellent Answer:** Explicitly notes the ranking would *not* change even at 100x data volume for (c), since it's structurally a fixed, one-time cost regardless of data size — reinforcing that (a) and (b) are the ones whose relative importance would only grow further.
- **Poor Answer:** Provides a ranking with no comparative justification between the three.

---

### P13. Why doesn't caching exist anywhere in this codebase, and where would it deliver the most value if added?
- **Difficulty:** Medium | **Importance:** 7
- **Expected Answer:** Confirmed by grep — no `lru_cache`, no Redis, despite a comment in `core/security.py` aspirationally claiming Redis is used "in production." Highest-value addition: caching embedding results for identical or near-identical query text in `embeddings/generate_embeddings.py`, since repeated calls to `/v1/explain` with the same transaction text currently re-embed from scratch every time via a real network call to Ollama, and embeddings for a fixed piece of text never change.
- **Follow-ups:** "What cache invalidation strategy would you use for a merchant-profile cache, given profiles change on every encounter?"
- **Common Mistakes:** Proposing caching for data that changes frequently (like `merchant_profiles`, updated on nearly every encounter) as the top priority, without recognizing embeddings are a much better caching candidate because they're pure functions of their input text.
- **What This Tests:** Recognizing which specific data in this system is actually cache-friendly (immutable given its key) versus which would need careful invalidation logic.
- **Red Flags:** Proposes caching frequently-mutated data without addressing invalidation at all.
- **Excellent Answer:** Explicitly contrasts embeddings (pure function of input text, trivially cacheable with a simple TTL or even permanent cache) against `merchant_profiles` (mutated on nearly every request that touches a given merchant, requiring either very short TTLs or explicit invalidation on write — meaningfully harder to get right).
- **Poor Answer:** Says "add Redis" with no specifics about what to cache or how to invalidate it.

---

### P14. Why does `analytics/subscriptions.py`'s `$lookup` join tend to be the most expensive single query in this codebase's live HTTP surface?
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** It combines a `$group`, a `$lookup` (MongoDB's join operation, typically the most expensive aggregation stage type since it must correlate documents across two collections), an `$unwind`, and a second `$match` — all without any supporting indexes on either `transactions` or `behavior_patterns`. Joins in general are more expensive than single-collection filters because they require correlating data across two potentially large, unindexed data sets.
- **Follow-ups:** "What single index addition would help this specific query the most?"
- **Common Mistakes:** Treating this query as equivalent in cost to the simpler `$match`+`$group` queries in `analytics/spending_patterns.py`, without recognizing the join stage's distinct cost profile.
- **What This Tests:** Recognizing that not all aggregation stages have equal cost — joins deserve special scrutiny.
- **Red Flags:** Treats all aggregation pipelines in this codebase as equally expensive.
- **Excellent Answer:** Identifies an index on `behavior_patterns.merchant_name` (the `$lookup`'s `foreignField`) as the single highest-value addition, since it directly speeds up the join's lookup side without requiring changes to the query itself.
- **Poor Answer:** Correctly identifies the query as expensive without specifying which index would help most.

---

### P15. If you could only make three performance changes to this system before a hypothetical 10x traffic increase, what would they be, in order?
- **Difficulty:** Expert | **Importance:** 9
- **Expected Answer:** A strong answer: (1) add indexes on every actively-queried field, especially unique indexes on `merchant_profiles.canonical_name` and `behavior_patterns.merchant_name` (fixes correctness *and* performance in one change); (2) parallelize `rag/retriever.py`'s per-merchant lookups with `asyncio.gather`, since `/v1/explain` is both the slowest endpoint and one with genuine untapped parallelism; (3) add an embedding cache to cut redundant Ollama calls, since Ollama inference is likely the least horizontally-scalable part of the whole stack (a self-hosted LLM server has real compute limits that databases, with proper indexing, don't share in the same way at this traffic scale).
- **Follow-ups:** "What would you monitor to confirm these three changes actually delivered the expected improvement?"
- **Common Mistakes:** Picking three unrelated micro-optimizations (e.g., three different small code cleanups) rather than the three highest-leverage systemic changes.
- **What This Tests:** Synthesis — pulling together everything discussed across this whole category into one prioritized, load-bearing action plan, the actual deliverable a senior engineer would be expected to produce.
- **Red Flags:** Picks changes that don't meaningfully move the needle at 10x scale (e.g., "clean up unused imports").
- **Excellent Answer:** Proposes concrete monitoring for each: query latency percentiles (via the existing Prometheus instrumentator) before/after indexing, `/v1/explain`'s p50/p99 latency before/after parallelization, and Ollama request volume/cache-hit-rate after adding the embedding cache.
- **Poor Answer:** Lists three changes with no monitoring/verification plan attached.
