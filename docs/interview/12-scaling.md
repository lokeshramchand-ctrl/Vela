# Scaling — 12 Questions

---

### SC1. If this application were horizontally scaled to 5 replicas behind a load balancer today, with zero code changes, what would break first?
- **Difficulty:** Hard | **Importance:** 9
- **Expected Answer:** SlowAPI's in-memory rate limiter — each replica maintains an independent counter, silently multiplying the effective allowed rate by 5 (discussed in State Management SM5). Nothing would crash outright, but the intended "100/minute per IP" limit would become "up to 500/minute per IP" depending on load-balancer distribution, with no error surfaced anywhere indicating this degradation.
- **Follow-ups:** "What's the second thing that would break, and why is it less severe than the first?"
- **Common Mistakes:** Naming a database-related concern first, when MongoDB and Milvus are already external, shared services unaffected by replicating the *application* layer — the rate limiter is uniquely broken by application-layer replication specifically because its state lives inside the application process itself.
- **What This Tests:** Correctly identifying which specific component's state model is incompatible with horizontal scaling, versus which components (already external databases) are naturally unaffected.
- **Red Flags:** Names a database scaling concern as the "first thing to break" from adding application replicas, missing that the databases are already external and shared.
- **Excellent Answer:** Names the in-memory NetworkX graph in `graphs/graph_builder.py` as the second thing to break (each replica would build and hold its own independent, potentially inconsistent copy) — correctly ranks it below the rate limiter since the graph feature currently has zero live callers, so its inconsistency wouldn't actually manifest anywhere yet.
- **Poor Answer:** Correctly identifies the rate limiter but can't name a second, correctly-prioritized issue.

---

### SC2. Why would sharding MongoDB today, before adding indexes, actually make performance worse in some cases rather than better?
- **Difficulty:** Hard | **Importance:** 7
- **Expected Answer:** Sharding distributes data across multiple nodes, but a query with no supporting index still has to scan every matching document *on whichever shard(s) it's routed to* — for queries that can't be routed to a single shard based on the shard key (a "scatter-gather" query hitting every shard), the total scan work is the same or worse than a single unsharded collection scan, now with the added overhead of coordinating across multiple nodes and merging results.
- **Follow-ups:** "Under what circumstance would sharding actually help, even without adding indexes first?"
- **Common Mistakes:** Assuming sharding is unconditionally a performance improvement regardless of query patterns or indexing state.
- **What This Tests:** Correct sequencing of scaling techniques — indexing and query optimization should generally precede horizontal data partitioning, not the reverse.
- **Red Flags:** Recommends sharding as an unconditional first step for performance improvement.
- **Excellent Answer:** Notes sharding would help even without new indexes *if* every query already filters precisely on the shard key (allowing MongoDB's query router to target a single shard directly) — but since today's queries already lack indexes on those same filter fields, the more foundational, higher-leverage fix (per Database D2/D25) is adding indexes first, which delivers most of the benefit at a fraction of the operational complexity of standing up a sharded cluster.
- **Poor Answer:** Correctly hedges that "it depends" without articulating the specific condition (shard-key-aligned queries) that would determine the outcome.

---

### SC3. Design a shard key for the `transactions` collection, and explain the trade-off of your choice against at least one alternative.
- **Difficulty:** Expert | **Importance:** 7
- **Expected Answer:** A hashed shard key on `user_id` is a strong choice — it aligns with the dominant query pattern (every real query filters by `user_id`), enabling single-shard query routing, while hashing avoids the "hot shard" risk of an unhashed `user_id` key if any single user generates disproportionately more transactions than others. The alternative, `{timestamp: 1}`, would be poor: it would create a "hot" shard for all *current* writes (since new transactions always have the most recent timestamp, all writes would target the same shard range at any given moment), even though it might seem attractive for time-range analytical queries.
- **Follow-ups:** "What's the trade-off of hashing `user_id` specifically — what capability do you lose compared to an unhashed range-based key?"
- **Common Mistakes:** Picking `timestamp` as a shard key because "the data is naturally time-ordered," without recognizing this creates a severe write-hotspotting problem.
- **What This Tests:** Genuine MongoDB sharding expertise — the timestamp-hotspot pitfall is a classic, important gotcha that separates surface familiarity from real operational understanding.
- **Red Flags:** Proposes a monotonically-increasing field (timestamp, or an auto-incrementing counter) as a shard key without recognizing the write-hotspot risk.
- **Excellent Answer:** Correctly identifies the trade-off of hashing: range queries across multiple users (rare in this system's actual query patterns, which are always single-user-scoped) would no longer be efficiently routable to a contiguous shard range — but notes this cost doesn't apply here, since no query in this codebase actually needs a multi-user range scan.
- **Poor Answer:** Picks a reasonable shard key but can't articulate any trade-off against an alternative when asked.

---

### SC4. Why is Milvus's current standalone deployment mode (implied by the connection setup in this codebase) a scaling limitation, and what would change to address it?
- **Difficulty:** Hard | **Importance:** 5
- **Expected Answer:** Milvus standalone mode runs all components (proxy, query nodes, data nodes, etc.) as a single process/deployment unit — fine for development or small vector counts, but it doesn't horizontally scale query or ingestion capacity independently the way Milvus's distributed/cluster deployment mode does. Moving to millions of vectors or high query throughput would require migrating to distributed mode, which involves substantially more operational complexity (separate etcd, object storage, and message-queue components) than the current setup.
- **Follow-ups:** "Is this a near-term concern for this specific system, given the embedding-write pipeline currently has no live caller at all?"
- **Common Mistakes:** Treating this as an urgent concern without connecting it to the earlier, established fact that the vector database is currently unpopulated in any live deployment.
- **What This Tests:** Calibrating a genuine future scaling concern against this system's actual current state — connecting back to a previously-established fact (the embedding pipeline has no caller) rather than treating every theoretical scaling limit as equally urgent.
- **Red Flags:** Treats this as an urgent, near-term priority without acknowledging the current vector count is likely at or near zero.
- **Excellent Answer:** Explicitly notes this is a "solve it when you actually have the problem" concern — prioritizing it today would be solving for a scale this system hasn't remotely approached, given the write pipeline (embeddings/vectorizer.py → generate_embeddings.py → insert_behavior_vector) has zero live callers anywhere in the codebase.
- **Poor Answer:** Discusses distributed Milvus in the abstract with no connection to this system's actual current scale.

---

### SC5. Why does the phase-based architecture (Phases 1-15) potentially make this system easier to scale out into separate services later, despite its many currently-disconnected features?
- **Difficulty:** Hard | **Importance:** 7
- **Expected Answer:** Each phase primarily communicates with adjacent phases through MongoDB collection reads/writes rather than direct in-process Python function calls — e.g., `analytics/` reads `behavior_patterns` without importing anything from `behaviour/`. This data-shape coupling (rather than code-level coupling) means several phases (behavior profiling, clustering, training) could become independent worker processes or microservices consuming from the same shared collections with comparatively minimal code changes, once currently-broken/disconnected pieces are fixed.
- **Follow-ups:** "Which phase would be the easiest to extract into a separate service first, and why?"
- **Common Mistakes:** Conflating "many features are disconnected/broken" with "the architecture doesn't support future service extraction" — these are different properties (execution completeness vs. structural coupling).
- **What This Tests:** The same architectural-potential-versus-current-defects distinction tested in Database D18 — consistency of judgment when the same underlying fact is asked about from a different angle (scaling vs. database design).
- **Red Flags:** Conflates current disconnection with poor structural design for future extraction.
- **Excellent Answer:** Names `behaviour/behavior_engine.py` as the easiest extraction candidate — it already only depends on `database.mongo` and pure `features/*.py` functions (no other application module), making it nearly ready to run as a standalone worker triggered by a message queue or scheduler, once its known bugs (none currently exist in this specific module) and missing trigger mechanism are addressed.
- **Poor Answer:** Doesn't propose a specific, well-reasoned extraction candidate.

---

### SC6. What would "read replicas" actually buy this system, given its current query patterns, and what would they NOT help with?
- **Difficulty:** Hard | **Importance:** 6
- **Expected Answer:** Read replicas would help offload read-heavy, staleness-tolerant queries (the `analytics/*.py` aggregations) from the primary node, reducing contention with write traffic. They would NOT help with the system's actual biggest performance problem — the total absence of indexes — since a query with no index is equally slow whether it runs against a primary or a secondary; replicas parallelize *load*, not *query efficiency*. Adding replicas before adding indexes would mean paying for more infrastructure to run the same inefficient scans slightly more times in parallel.
- **Follow-ups:** "In what order would you introduce indexes and read replicas, and why?"
- **Common Mistakes:** Treating read replicas as a general-purpose performance fix rather than specifically a load-distribution mechanism that doesn't address per-query efficiency at all.
- **What This Tests:** Correctly distinguishing "scaling capacity" (replicas, sharding) from "improving efficiency" (indexing, query optimization) as two different, sequenced scaling levers.
- **Red Flags:** Treats replicas as a substitute for indexing rather than a complementary, later-stage lever.
- **Excellent Answer:** Explicitly sequences: indexes first (fixes the fundamental per-query cost, benefiting every deployment topology, including a single unreplicated instance), then read replicas once query *volume* — not per-query cost — becomes the bottleneck, which is a distinct, later problem.
- **Poor Answer:** Recommends replicas without addressing the sequencing question relative to indexing.

---

### SC7. Why would adding real multi-tenancy (removing the hardcoded `TEST_USER`) be a prerequisite for meaningfully scaling this system's user base, beyond just "it's the right thing to do"?
- **Difficulty:** Medium | **Importance:** 7
- **Expected Answer:** Beyond correctness, multi-tenancy affects capacity planning and scaling strategy directly: with everyone currently sharing one hardcoded `user_id`, there's no way to reason about per-tenant data growth, no way to implement per-tenant rate limiting or resource quotas, and no way to shard or partition data meaningfully by tenant (a natural, common scaling pattern) since the data model doesn't actually distinguish tenants at all today.
- **Follow-ups:** "How would per-tenant sharding change your answer to SC3?"
- **Common Mistakes:** Treating multi-tenancy purely as a security/correctness fix, missing its direct implications for scaling strategy.
- **What This Tests:** Connecting a previously-discussed authentication/authorization gap to its distinct scaling consequences — cross-category synthesis.
- **Red Flags:** Only discusses the security angle (already covered in Authentication/Security categories) without engaging with the scaling-specific angle this question asks about.
- **Excellent Answer:** Notes that with real tenant identity in place, `transactions`' shard key (SC3) could reasonably become tenant-aware (e.g., `{tenant_id: "hashed", user_id: 1}` compound sharding), enabling per-tenant data isolation and potentially per-tenant scaling policies for especially large customers — none of which is expressible with today's single-shared-identity model.
- **Poor Answer:** Repeats the security case for multi-tenancy without the scaling-specific connection asked for.

---

### SC8. This system has no message queue or background job infrastructure. What specific scaling problem does that block, beyond "the training pipeline is unfinished"?
- **Difficulty:** Hard | **Importance:** 7
- **Expected Answer:** It blocks safely scaling *any* long-running, resource-intensive work independently from the request-serving capacity — today, if `feedback/retraining_queue.py`'s missing training-launch step were implemented naively (as a direct in-process call, the only mechanism currently available via `BackgroundTasks`), it would compete for the exact same CPU/memory as concurrent HTTP requests on the same worker process, meaning scaling up "training capacity" and "request-serving capacity" couldn't be done independently — you'd have to over-provision the entire web-serving fleet just to occasionally accommodate expensive background work.
- **Follow-ups:** "What's the minimal message-queue-based architecture you'd introduce to fix this?"
- **Common Mistakes:** Framing this purely as "the feature isn't done yet" rather than the deeper scaling-architecture consequence of *how* it would have to be built without a queue.
- **What This Tests:** Recognizing that missing infrastructure (a queue) isn't just a missing feature — it constrains the scaling *shape* of any feature eventually built on top of it.
- **Red Flags:** Discusses this purely as an incompleteness issue without the scaling-architecture angle.
- **Excellent Answer:** Proposes a minimal fix: introduce a real task queue (Celery with Redis/RabbitMQ as the broker, as the codebase's own comments already reference) so training jobs run on dedicated worker processes, scaled and provisioned entirely independently from the FastAPI web-serving fleet — allowing each to scale according to its own actual resource profile (CPU/GPU-heavy training workers vs. I/O-bound web workers).
- **Poor Answer:** Proposes a queue without articulating why independent scaling specifically requires it.

---

### SC9. Why might "scale the database" be the wrong first answer when asked how to make `/v1/explain` handle 100x more traffic?
- **Difficulty:** Hard | **Importance:** 7
- **Expected Answer:** `/v1/explain`'s dominant latency cost is two external Ollama calls (embedding + generation), not database query time — scaling MongoDB or Milvus wouldn't meaningfully reduce the 15s/30s timeout budgets those calls can consume. The actual bottleneck at high traffic would likely be Ollama's own inference capacity (a self-hosted LLM server has real, often GPU-bound, compute limits that don't scale by simply adding more database replicas) — the right first question is "how many concurrent Ollama requests can our inference infrastructure actually sustain," not "how do we scale the database."
- **Follow-ups:** "What would you actually need to know about the Ollama deployment to answer this properly?"
- **Common Mistakes:** Defaulting to "add database capacity" as a reflexive answer to any scaling question, without first identifying where the actual bottleneck lives for this specific endpoint.
- **What This Tests:** Whether the candidate does bottleneck identification before proposing a scaling solution — a foundational, often-skipped step.
- **Red Flags:** Proposes database scaling as the primary fix for an endpoint whose dominant cost is external LLM inference, not database queries.
- **Excellent Answer:** Notes the practical unknowns needed to answer this properly: is Ollama running on dedicated GPU hardware or CPU-only, is it a single instance or already load-balanced (per `OLLAMA_HOSTS`'s failover-list support), and what's its actual measured throughput ceiling — none of which this codebase's documentation can answer from source code alone, requiring direct measurement against the real deployed inference infrastructure.
- **Poor Answer:** Proposes a generic scaling fix without acknowledging the need to first identify where Ollama's actual capacity ceiling is.

---

### SC10. `core/ollama_client.py`'s `OLLAMA_HOSTS` failover list is resolved once, at import time, to a single fixed host. Why does this design not actually provide load balancing, only failover?
- **Difficulty:** Hard | **Importance:** 6
- **Expected Answer:** `resolve_ollama_host` picks the *first* host in the list that responds successfully and then commits to it as a fixed constant (`OLLAMA_HOST`) for the entire process lifetime — every subsequent request from this process goes to that same single host, never distributing load across the other healthy hosts in the list. This is failover (recovering from the first host being down at startup) but not load balancing (distributing ongoing traffic across multiple healthy hosts).
- **Follow-ups:** "How would you redesign this to actually load-balance across multiple Ollama hosts?"
- **Common Mistakes:** Assuming a list of hosts implies load distribution across all of them, rather than checking the actual resolution logic picks exactly one and commits to it.
- **What This Tests:** Distinguishing failover from load balancing — two related but functionally distinct resilience patterns, often conflated.
- **Red Flags:** Assumes the multi-host configuration already provides load distribution.
- **Excellent Answer:** Proposes round-robin or least-connections selection *per request* (rather than once at startup) across all currently-healthy hosts in the list, which would require moving this logic out of the import-time singleton pattern entirely and into a per-call resolution step — a meaningfully larger design change than the current one-time resolution.
- **Poor Answer:** Correctly identifies the current behavior as failover-only but proposes no concrete alternative design.

---

### SC11. If this system needed to support 10x more distinct merchants (not more transactions per merchant, but more unique merchants), which specific component would feel that scaling pressure first?
- **Difficulty:** Hard | **Importance:** 6
- **Expected Answer:** `services/merchant_resolver.py`'s substring-matching fallback — its cost scales with the size of the `merchants` collection being scanned per candidate word (since there's no index on `aliases`), so 10x more merchants directly means roughly 10x more work per unmatched substring query. `engines/rule_engine.py`'s linear pattern scan would also degrade (per Performance P7), though its in-memory nature makes it less severe than a database-scan cost multiplied 10x.
- **Follow-ups:** "Would adding an index on `merchants.aliases` fully solve this, or just delay the problem?"
- **Common Mistakes:** Naming `transactions`-related components, which scale with transaction *volume*, not merchant *count* — the question specifically asks about merchant-count scaling, a different axis.
- **What This Tests:** Precision about which specific scaling *dimension* (transaction volume vs. merchant count vs. user count) affects which specific component — not every scaling question has the same answer.
- **Red Flags:** Names a component that scales with the wrong dimension (e.g., transaction volume) for the specific axis asked about.
- **Excellent Answer:** Notes an index would substantially help (turning a full collection scan into an indexed lookup) but wouldn't fully eliminate the fundamental issue that this is still a substring/prefix-matching strategy that inherently costs more as the candidate set grows — the deeper fix, as the code's own comments suggest, is migrating to the already-built Milvus semantic search path instead, which scales sub-linearly via its HNSW index regardless of merchant count.
- **Poor Answer:** Names a component affected by the wrong scaling dimension, or proposes only an index with no acknowledgment of its limits.

---

### SC12. Synthesize everything discussed in this category into a single ordered roadmap: what are the first five scaling investments you'd make, and why in that specific order?
- **Difficulty:** Expert | **Importance:** 9
- **Expected Answer:** A strong ordered roadmap: (1) Fix the hardcoded-user/missing-authorization gap — a prerequisite for meaningfully reasoning about any per-tenant scaling at all. (2) Add MongoDB indexes — the highest-leverage, lowest-risk change, benefiting every subsequent scaling effort. (3) Move the in-memory rate limiter to a shared backend (Redis) — a hard blocker for horizontal replica scaling specifically. (4) Introduce a real background job queue (Celery or similar) — decouples long-running work from web-serving capacity, a prerequisite for finishing several disconnected features safely. (5) Only then consider database sharding/read replicas and Ollama load balancing, once the above foundational work means those investments would actually deliver their intended benefit rather than papering over more fundamental gaps.
- **Follow-ups:** "Defend placing authorization ahead of database indexing — isn't indexing more urgent for raw performance?"
- **Common Mistakes:** Ordering purely by "raw performance impact" without considering that some items (like authorization) are prerequisites that change what "correct scaling" even means for this system, not just performance multipliers.
- **What This Tests:** The single hardest synthesis question in this category — combining correctness, security, and performance reasoning into one coherently-prioritized roadmap, rather than treating them as separate concerns to rank independently.
- **Red Flags:** Produces a roadmap ordered purely by raw performance impact with no consideration of correctness/security prerequisites.
- **Excellent Answer:** Defends the ordering explicitly: scaling a system with no real tenant isolation just scales the blast radius of the missing-authorization problem — more users on a system where everyone sees everyone else's data isn't "successfully scaled," it's a bigger version of an already-broken product; performance investments only make sense once the *thing being scaled* is actually correct.
- **Poor Answer:** Provides five reasonable items with no defensible, well-reasoned ordering logic connecting them.
