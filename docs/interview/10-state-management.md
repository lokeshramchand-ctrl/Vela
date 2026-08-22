# State Management â€” 12 Questions

> Not React/Redux state â€” this category tests understanding of Vela's genuine domain state machine (the memory engine) plus the several architectural "state" patterns worth interrogating in a backend system: singletons as implicit application state, in-memory rate-limiter state, and an in-memory graph that doesn't survive a restart.

---

### SM1. Draw and explain the complete state transition diagram for a merchant profile's `memory_state`, including every transition this codebase actually implements.
- **Difficulty:** Medium | **Importance:** 9
- **Expected Answer:** `EPHEMERAL` (start, frequency=1) â†’ `TEMPORARY` (frequency â‰¥ 3) â†’ `PERMANENT` (frequency â‰¥ 10, sticky, no further promotion logic applies). Separately, any non-`PERMANENT`, non-`ARCHIVED` profile whose `last_seen` exceeds 180 days can transition to `ARCHIVED` via `memory/decay_engine.py::run_archive_sweep` (though nothing currently calls this automatically). An `ARCHIVED` profile that's encountered again transitions directly to `TEMPORARY` (not back through `EPHEMERAL`), via an explicit override in `memory/memory_manager.py::process_encounter` that bypasses the state machine's own logic for this one case.
- **Follow-ups:** "Can a `PERMANENT` profile ever become `ARCHIVED`? Check the actual code, not intuition."
- **Common Mistakes:** Assuming `PERMANENT` is fully immune to archival â€” checking `repositories/profile_repository.py::get_stale_profiles`'s query (`{"memory_state": {"$ne": "ARCHIVED"}}`) shows it excludes only already-archived profiles, meaning a `PERMANENT` profile *is* eligible for archival if inactive long enough, unless `memory/decay_engine.py`'s own code comment's suggested (but unimplemented) `PERMANENT` exclusion were added.
- **What This Tests:** Whether the candidate traces the actual query logic rather than assuming intuitive behavior (that "permanent" should mean "never decays").
- **Red Flags:** States `PERMANENT` never decays without checking the actual stale-profile query.
- **Excellent Answer:** Explicitly quotes the decay engine's own code comment (`# Optional: You might decide PERMANENT memory never decays. If so, add...`) as evidence that this exact ambiguity was noticed by whoever wrote the code but deliberately left as an open decision rather than resolved.
- **Poor Answer:** Draws an incomplete diagram missing the `ARCHIVED â†’ TEMPORARY` reactivation edge or the `PERMANENT`-can-still-archive edge case.

---

### SM2. Why is `frequency` a monotonically increasing counter with no reset anywhere in the state machine, and what state-consistency risk does that create?
- **Difficulty:** Hard | **Importance:** 7
- **Expected Answer:** Nothing in `memory/state_machine.py`, `memory/decay_engine.py`, or `memory/memory_manager.py` ever decreases `frequency` â€” it only accumulates for the life of the document, across any number of archival/reactivation cycles. The risk: a profile's "trust level" is meant to reflect current, ongoing reliability, but the raw counter conflates "seen many times a long time ago" with "seen many times recently" â€” a reactivated profile with old accumulated frequency can immediately re-qualify for `PERMANENT`, even if it's been dormant for years in between.
- **Follow-ups:** "How would you redesign this state to distinguish 'total lifetime frequency' from 'recent frequency'?"
- **Common Mistakes:** Assuming this is definitely a bug rather than considering it might be an accepted, if unstated, trade-off (as discussed in Design Decisions DD3).
- **What This Tests:** Connecting a state-management observation to its downstream consistency implications â€” does the state actually represent what its name implies at all times.
- **Red Flags:** Doesn't articulate the specific gap between "what frequency is supposed to represent" and "what it actually tracks."
- **Excellent Answer:** Proposes tracking two separate counters â€” `total_frequency` (lifetime, never reset) and `frequency_since_reactivation` (reset on `ARCHIVED â†’ TEMPORARY` transitions) â€” letting the state machine's promotion logic use the latter for genuinely "recent trust" decisions while preserving the former for historical/analytics purposes.
- **Poor Answer:** Identifies the issue without proposing a concrete state-model fix.

---

### SM3. Explain precisely why two concurrent requests updating the same merchant's `frequency` can silently lose an increment, in terms of state consistency, not just "it's a race condition."
- **Difficulty:** Hard | **Importance:** 8
- **Expected Answer:** `memory/memory_manager.py::process_encounter` performs a classic read-modify-write: fetch the current profile (with its current `frequency`), increment it *in Python memory*, then write the whole mutated object back. If two requests both read `frequency=5` before either writes, both compute `frequency=6` independently and both write `6` â€” the second write doesn't know about the first's increment, so the net effect of two encounters is a single increment instead of two. This is specifically because the increment happens in application memory rather than atomically inside the database (e.g., via MongoDB's `$inc` operator, which *is* safe under concurrency).
- **Follow-ups:** "Why would using MongoDB's `$inc` operator directly fix this?"
- **Common Mistakes:** Describing this only as "a race condition" without explaining the specific mechanism (read-modify-write vs. atomic increment) that causes the data loss.
- **What This Tests:** Deep, mechanism-level understanding of *why* this specific pattern is unsafe, not just pattern-recognition that "concurrent writes can race."
- **Red Flags:** Says "race condition" with no explanation of the actual read-modify-write mechanism.
- **Excellent Answer:** Explains that `$inc` is safe specifically because MongoDB executes it as a single atomic document operation server-side â€” there's no window where two operations can both read the same "before" value, since the increment and the read of the current value happen as one indivisible step at the database layer, unlike the current design where the read and write are two separate round trips with application code in between.
- **Poor Answer:** Correctly identifies a race condition but can't explain why `$inc` specifically would fix it.

---

### SM4. Is a module-level singleton like `rule_engine = RuleEngine()` a form of "state management"? Defend your answer.
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** Yes, in a real sense â€” `rule_engine.compiled_rules` is state (the loaded, compiled alias dictionary) held in process memory for the entire lifetime of the application, shared implicitly by every request. It's a simpler form of state management than a database (no persistence, no concurrency control needed since it's read-only after startup), but it's still state that every part of the codebase relying on `rule_engine` implicitly depends on being correctly initialized.
- **Follow-ups:** "What would happen to this 'state' if the process restarted mid-request?"
- **Common Mistakes:** Assuming "state management" only refers to mutable, request-scoped, or database-backed state, dismissing read-only in-memory singletons as "not really state."
- **What This Tests:** A broad, correct definition of "state" that includes read-only, process-lifetime, in-memory data â€” not just the narrower, mutable-and-persistent connotation.
- **Red Flags:** Denies this counts as state management at all.
- **Excellent Answer:** Contrasts `rule_engine`'s state (immutable after startup, safe to share across all concurrent requests with zero synchronization needed) against `database.mongo.db`'s state (a live connection whose validity can change at runtime) â€” both are "singleton state," but they have meaningfully different risk profiles.
- **Poor Answer:** Gives a yes/no answer with no supporting distinction between different kinds of singleton state.

---

### SM5. Why does SlowAPI's rate-limiter state become a correctness problem specifically if this application is ever horizontally scaled to multiple replicas?
- **Difficulty:** Medium | **Importance:** 8
- **Expected Answer:** `core/rate_limiter.py`'s `Limiter` uses SlowAPI's default in-memory storage â€” each replica maintains its own independent count of requests per IP. A client sending 100 requests/minute against a 3-replica deployment (assuming even load-balancer distribution) would only hit ~33 requests per replica, meaning the *effective* system-wide limit becomes roughly 300/minute instead of the intended 100/minute â€” the rate limit is silently weakened by a factor equal to the replica count, with no error or warning indicating this.
- **Follow-ups:** "What would you replace the storage backend with to fix this, and what new dependency would that introduce?"
- **Common Mistakes:** Assuming rate limiting "just works" regardless of how many processes/replicas are running.
- **What This Tests:** Connecting an in-memory-state design choice to its concrete failure mode under horizontal scaling â€” a classic and important distributed-systems gotcha.
- **Red Flags:** Doesn't recognize that in-memory state doesn't share across separate processes/replicas at all.
- **Excellent Answer:** Names SlowAPI's Redis-backed storage option as the fix, and correctly notes this introduces a new hard dependency on Redis being available and low-latency, since every rate-limit check would now require a network round trip instead of an in-process memory lookup â€” a real trade-off, not a free upgrade.
- **Poor Answer:** Identifies Redis as a fix with no acknowledgment of the added dependency/latency trade-off.

---

### SM6. `graphs/graph_builder.py`'s `KnowledgeGraphBuilder` holds its entire graph as an instance attribute (`self.graph`). What happens to this state on a process restart, and does that matter given the current codebase?
- **Difficulty:** Medium | **Importance:** 5
- **Expected Answer:** The graph is held purely in process memory (a `networkx.DiGraph`) and is never persisted to disk or a database â€” a restart loses it entirely, with no automatic rebuild on startup either. Given that nothing in the codebase currently calls `build_graph()` at all (it has zero live callers), this doesn't currently matter in practice â€” but it would matter immediately the moment any endpoint or scheduled job were added that relies on the graph being available without an explicit rebuild step first.
- **Follow-ups:** "If you added an endpoint exposing `get_merchant_neighborhood`, what would you need to add to make it work correctly on a freshly-restarted process?"
- **Common Mistakes:** Treating this as an urgent problem without first checking that the current lack of any caller makes it moot today.
- **What This Tests:** Calibrating urgency correctly â€” this is a real design gap, but its priority depends entirely on whether the feature is actually live, which the candidate should check rather than assume.
- **Red Flags:** Treats this as an active production bug without checking the feature is currently unused.
- **Excellent Answer:** Proposes that any new endpoint exposing this graph would need a lazy-build-on-first-access pattern (build the graph if `self.graph` is empty, or track a staleness timestamp and rebuild periodically) â€” since a fresh process otherwise has an empty, unbuilt graph that would return "not found" for every merchant, appearing to be a data problem when it's actually a state-initialization gap.
- **Poor Answer:** Only notes the state is lost on restart without connecting it to what would need to change if the feature were ever exposed.

---

### SM7. Why is MongoDB itself the "real" state store for this application, and every in-process object (singletons, the graph, the rate limiter) a form of derived or cached state?
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** MongoDB documents (`merchant_profiles`, `behavior_patterns`, etc.) are the durable, authoritative record of the system's state â€” they survive process restarts, are shared correctly across concurrent requests via the database's own concurrency control, and are the only state that would still exist if every application process were killed and restarted. Everything else (the rule engine's compiled patterns, the in-memory graph, the rate limiter's counters) is either fully derived from static configuration (rule engine) or genuinely ephemeral, expected-to-be-lost state (rate limiter, graph).
- **Follow-ups:** "Where does `merchant_profiles.confidence` fit into this distinction, given it's a durable field that's never actually populated?"
- **Common Mistakes:** Treating all forms of "state" in the system as equivalent in durability/authority, without this database-vs-process distinction.
- **What This Tests:** A clean mental model separating "source of truth" state from "derived/cache/ephemeral" state â€” foundational for reasoning about correctness and scaling.
- **Red Flags:** Doesn't distinguish durable from ephemeral state at all.
- **Excellent Answer:** Notes `merchant_profiles.confidence` is an interesting edge case: it's durable *storage* (survives restarts, part of the database schema) but not durable *state*, since no application logic ever populates it meaningfully â€” a field that's technically part of the source-of-truth store but currently carries no real information.
- **Poor Answer:** Correctly identifies MongoDB as the source of truth without engaging with the nuanced edge case in the follow-up.

---

### SM8. Is there any session state or per-request-scoped state anywhere in this application?
- **Difficulty:** Medium | **Importance:** 5
- **Expected Answer:** No â€” there's no session concept at all (no cookies, no server-side session store), consistent with the stateless, header-authenticated-per-request API design. Every request is fully self-contained: authentication is re-checked from scratch on every call (via the shared static key), and no per-request context object accumulates state across multiple requests from the same client.
- **Follow-ups:** "What would need to be added if this system needed a multi-step workflow (e.g., a multi-page form submission) that required state to persist across several requests?"
- **Common Mistakes:** Assuming FastAPI's `Request` object or dependency injection implies some form of session state by default â€” it doesn't, without explicit session middleware.
- **What This Tests:** Correct understanding that statelessness is the default for this kind of API unless explicitly built otherwise.
- **Red Flags:** Invents session state that doesn't exist in the code.
- **Excellent Answer:** Proposes that a genuinely multi-step workflow would need either client-side state (the client resubmits accumulated context with each request) or a new, explicit server-side state store (e.g., a `workflow_sessions` MongoDB collection keyed by a session token) â€” noting the current architecture has no existing pattern to reuse for this, since it was never designed with statefulness across requests in mind.
- **Poor Answer:** Correctly says there's no session state but has no proposal for how to add it if needed.

---

### SM9. Why does the RAG pipeline (`rag/retriever.py`, `context_builder.py`, `generator.py`) have effectively zero persistent state of its own?
- **Difficulty:** Medium | **Importance:** 5
- **Expected Answer:** All three classes are stateless orchestrators â€” each method call is a fresh computation from its inputs (a query string) and external reads (Milvus, MongoDB), with no instance state that accumulates or persists between calls. This is architecturally clean: each `/v1/explain` request is fully independent, with no risk of state leaking between unrelated requests or growing unbounded in memory over the life of the process.
- **Follow-ups:** "What would change if you wanted to cache embeddings, discussed in the Performance category, within this pipeline?"
- **Common Mistakes:** Assuming statelessness is somehow accidental rather than the natural, correct shape for this kind of request-scoped pipeline.
- **What This Tests:** Recognizing when *lack* of state is the correct design, connecting back to the caching discussion elsewhere in this bank.
- **Red Flags:** Treats the absence of state as a gap needing to be filled without justification.
- **Excellent Answer:** Notes that adding an embedding cache (as proposed in Performance P13) would introduce the *first* piece of genuine cross-request state into this otherwise fully stateless pipeline â€” worth deliberately isolating in its own component (e.g., a dedicated `EmbeddingCache` singleton) rather than mixing mutable cache state into the currently-clean, stateless `EmbeddingGenerator` class.
- **Poor Answer:** Doesn't connect this to any concrete future design consideration.

---

### SM10. What's the difference between "state" and "configuration" in this codebase, and can you give one example the codebase gets subtly wrong?
- **Difficulty:** Hard | **Importance:** 6
- **Expected Answer:** Configuration (`core/config.py::settings`) is meant to be fixed for the life of the process, set once at startup from the environment. State is meant to change during the process's lifetime in response to events. A subtle case the codebase gets wrong: `core/ollama_client.py`'s `OLLAMA_HOST` is computed once at import time and treated as if it were fixed configuration, but it's actually the *result* of a runtime health check (which host responded successfully) â€” closer to "cached state derived from a point-in-time observation" than true configuration, yet it's never re-evaluated if the underlying situation changes (e.g., the resolved host later goes down).
- **Follow-ups:** "How would you redesign `OLLAMA_HOST` to correctly reflect its actual nature as derived state rather than fixed configuration?"
- **Common Mistakes:** Treating "configuration" and "state" as interchangeable terms, missing the conceptual distinction the question is probing.
- **What This Tests:** A genuinely subtle distinction â€” recognizing that something *computed* from a runtime check but then treated as immutable afterward occupies an awkward middle ground worth naming explicitly.
- **Red Flags:** Can't articulate the configuration-vs-state distinction at all.
- **Excellent Answer:** Proposes a periodic re-resolution mechanism (e.g., re-run `resolve_ollama_host` on a timer, or on detecting a failed request to the currently-cached host) that would correctly treat `OLLAMA_HOST` as state that can change, rather than configuration fixed for the process's entire lifetime.
- **Poor Answer:** Identifies the example without articulating the underlying configuration-vs-state distinction it illustrates.

---

### SM11. Why doesn't `memory/state_machine.py::StateMachine` need any locking or concurrency control, even though `memory/memory_manager.py` (which calls it) does?
- **Difficulty:** Hard | **Importance:** 6
- **Expected Answer:** `StateMachine.evaluate_promotion` is a pure function â€” it takes a `MerchantProfile` object as an argument and returns a value with no shared, mutable state of its own; calling it from a thousand concurrent requests simultaneously is perfectly safe, since each call operates entirely on its own local input with no cross-call interaction. The concurrency risk discussed elsewhere (SM3) lives entirely in `memory_manager.py`'s read-modify-*write*-to-the-database pattern, not in the pure computation that decides *what* to write.
- **Follow-ups:** "If `StateMachine` had an instance attribute that changed based on calls (e.g., a running count of promotions), would that change your answer?"
- **Common Mistakes:** Assuming any function involved in a broader concurrency-risky workflow must itself be part of the risk.
- **What This Tests:** Precisely scoping *where* in a call chain a concurrency risk actually lives â€” not every function touched by a risky workflow is itself risky.
- **Red Flags:** Assumes `StateMachine` itself needs locking because it's "part of" a concurrency-sensitive feature.
- **Excellent Answer:** Directly answers the follow-up: yes, adding any shared mutable instance state to `StateMachine` (like a running promotion counter) would immediately introduce the same class of race condition discussed for `frequency` â€” the purity of the function today is exactly what makes it safe, and that property would need to be deliberately preserved in any future change.
- **Poor Answer:** Correctly says `StateMachine` is safe but can't explain why in terms of purity/statelessness, or can't reason about the follow-up hypothetical.

---

### SM12. Design a lightweight way to make `memory/memory_manager.py::process_encounter`'s frequency increment fully race-condition-safe, using only MongoDB features already in use elsewhere in this codebase (no new infrastructure).
- **Difficulty:** Expert | **Importance:** 8
- **Expected Answer:** Replace the read-then-write pattern for the *increment* specifically with an atomic `db.merchant_profiles.find_one_and_update({"canonical_name": name}, {"$inc": {"frequency": 1}, "$set": {"last_seen": now}}, return_document=AFTER, upsert=True)` â€” this single atomic operation handles the increment, the timestamp update, and (via `upsert=True`) the first-encounter creation case all in one indivisible database operation, eliminating the race condition entirely without introducing any new dependency (Motor/PyMongo already support this natively). The state-machine evaluation (`evaluate_promotion`) would then run against the *returned, post-increment* document, guaranteeing it always sees the correct, current frequency.
- **Follow-ups:** "Does this fully replace `create_profile`/`update_profile`, or would you still need them for anything?"
- **Common Mistakes:** Proposing an external locking mechanism (e.g., a distributed lock via Redis) when the existing database already provides a simpler, suf1nt native primitive for this exact problem.
- **What This Tests:** Whether the candidate reaches for the simplest sufficient tool (an existing atomic database operation) rather than over-engineering a distributed-systems solution for a problem MongoDB already solves natively.
- **Red Flags:** Proposes external locking infrastructure without first considering whether the existing database toolkit already solves the problem.
- **Excellent Answer:** Notes that the alias-append logic (adding a new `raw_text` variant to `aliases` if novel) would still need separate handling â€” `$addToSet` could handle that atomically too, but the *decision* of whether the state machine's `ARCHIVED â†’ TEMPORARY` override applies would need to happen based on the document's state *before* the increment (to check if it was previously `ARCHIVED`), which requires either a slightly more careful two-step atomic sequence or handling that specific transition as a documented exception to the fully-atomic happy path.
- **Poor Answer:** Proposes `$inc` correctly but doesn't address the alias-append or `ARCHIVED`-detection complications the full function actually needs to handle.

