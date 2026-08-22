# Architecture — 20 Questions

---

### A1. Walk me through what happens, in order, from `python app.py` (or `uvicorn app:app`) to the server accepting its first request.
- **Difficulty:** Medium | **Importance:** 9
- **Expected Answer:** Python imports `app.py` top to bottom: `core.config.settings` loads and validates `.env` (fails fast if incomplete); importing `routers.rag` transitively triggers `core.ollama_client`'s host resolution (real, blocking HTTP calls); `milvus.insert_vectors.VectorStoreManager()` connects to Milvus and may create a collection, all at import time. Then `FastAPI(...)` is constructed, rate limiting and Prometheus are attached, five routers are included. Only once the ASGI server delivers a startup event does `lifespan()` run: `db.connect()` then `vector_db.connect()` (with blocking retries). Only after `lifespan` yields does the server accept traffic.
- **Follow-ups:** "What happens if Ollama is unreachable during this sequence?" "Why is this risky compared to doing all I/O inside `lifespan`?"
- **Common Mistakes:** Assuming all initialization happens inside `lifespan` — most of the risky I/O in this codebase actually happens at plain Python import time, before FastAPI's own lifecycle even begins.
- **What This Tests:** Whether the candidate understands the difference between import-time and runtime side effects in Python, and can trace a real, non-obvious startup path rather than assuming a textbook FastAPI lifecycle.
- **Red Flags:** "It just starts Uvicorn and FastAPI handles the rest" — no mention of import-time side effects at all.
- **Excellent Answer:** Names the three specific import-time failure points (`core.config`, `core.ollama_client`, `milvus.insert_vectors`) and explains why each could independently crash the process before `lifespan` runs.
- **Poor Answer:** "FastAPI starts, then the lifespan connects to the databases, then it's ready" — technically not wrong, but misses that most of the fragility is elsewhere.

---

### A2. Why does this codebase use module-level singletons (`rule_engine = RuleEngine()`) instead of FastAPI's `Depends()` for every service and engine?
- **Difficulty:** Medium | **Importance:** 8
- **Expected Answer:** Simplicity and predictability — one instance per process, no per-request construction cost, no need to wire dependency graphs. The trade-off is there's no seam for `app.dependency_overrides` in tests, so you can't easily swap in a fake `db` or a fake `rule_engine` without monkeypatching the module directly.
- **Follow-ups:** "How would you refactor this to be more testable without a huge rewrite?" "Is there anywhere in this codebase `Depends()` IS used?"
- **Common Mistakes:** Not knowing `Depends()` is used exactly once in the entire codebase (auth) — assuming FastAPI's DI is used more broadly because it's "the FastAPI way."
- **What This Tests:** Understanding of dependency injection trade-offs, not just "DI is always better."
- **Red Flags:** Claims singletons are simply "wrong" with no acknowledgment of the simplicity trade-off, or claims `Depends()` is used throughout without checking.
- **Excellent Answer:** Notes that singletons are actually *fine* for stateless engines (`rule_engine`, `confidence_engine`) but become a real liability for anything needing per-request scoping or test isolation — and cites `database.mongo.db` specifically as the case where it matters most.
- **Poor Answer:** "Singletons are a bad pattern, should always use DI" — dogmatic, no situational reasoning.

---

### A3. This codebase describes itself in comments as "15 phases." Is that a real architectural boundary, or documentation flavor?
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** It's real and traceable — `# Phase 3 Endpoint`, `# Phase 9 Specific Features` etc. appear directly in source comments, and the phases roughly correspond to folder boundaries (rule engine = 1-2, resolver = 3, memory = 4, confidence = 5, features/behaviour = 6, embeddings/milvus = 7, clustering = 8, training = 9, feedback = 10, finetune = 11, rag = 12, analytics = 13, observability = 14, security = 15). But several phases (8, 9, 10, 11, 14) are disconnected from the live HTTP surface — the phase numbering describes intended sequence, not actual runtime connectivity.
- **Follow-ups:** "Which phases can't currently run at all, and why?" "Is this a good way to structure a codebase?"
- **Common Mistakes:** Assuming phase number = execution order at runtime, when several phases are simply dead ends today.
- **What This Tests:** Whether the candidate distinguishes "how the code is organized/commented" from "what actually executes when you hit an endpoint."
- **Red Flags:** Can't name a single disconnected phase.
- **Excellent Answer:** Names specifically that Phase 8 (clustering) has two bugs preventing it from even importing, Phase 10 (feedback) is unreachable because its router isn't mounted, and Phases 9/11 (training) are script-only with synthetic data.
- **Poor Answer:** "Yeah it's organized into phases" with no detail on which are live.

---

### A4. Why does `models/schemas.py` have zero internal dependencies while nearly every other module depends on it?
- **Difficulty:** Easy | **Importance:** 6
- **Expected Answer:** It's a deliberate leaf node in the dependency graph — pure data contracts (Pydantic models, enums) with no business logic and no I/O, so it can be safely imported from anywhere without circular-import risk. This is the correct shape for a shared-vocabulary module.
- **Follow-ups:** "What would happen if `models/schemas.py` imported from `database/mongo.py`?"
- **Common Mistakes:** Not recognizing this as an intentional architectural pattern (shared kernel / leaf dependency), describing it as coincidental.
- **What This Tests:** Understanding of dependency direction and why leaf modules matter for avoiding circular imports.
- **Red Flags:** No mention of circular import risk at all.
- **Excellent Answer:** Explains that this makes `models/schemas.py` "trivially safe to import from anywhere" and contrasts it with, say, `database/mongo.py`, which has real dependencies and import-order sensitivity.
- **Poor Answer:** "It's just the models file" — no architectural reasoning.

---

### A5. `services/`, `engines/`, `memory/`, `analytics/`, and `rag/` all contain what is architecturally the same kind of thing — business logic. Why five different folder/naming conventions for one concept?
- **Difficulty:** Medium | **Importance:** 7
- **Expected Answer:** No principled reason found in the code — it's an organic naming inconsistency (`Engine`, `Resolver`, `Manager`, `Analyzer`, `Detector`, `Builder` are all used for the same conceptual "service layer" role). This is a real maintainability cost: a new engineer has to learn five vocabularies to find "where does business logic live."
- **Follow-ups:** "How would you consolidate this without a disruptive rewrite?"
- **Common Mistakes:** Inventing a retroactive justification (e.g., "engines are deterministic, services are async") that doesn't actually hold up when checked against the code — `services/merchant_resolver.py` is async and I/O-bound, same as several "engines."
- **What This Tests:** Willingness to say "this is inconsistent, not intentional" rather than rationalizing every pattern as deliberate.
- **Red Flags:** Confidently asserts a naming rule that doesn't survive a check against the actual code.
- **Excellent Answer:** Acknowledges the inconsistency directly and proposes a concrete, low-risk consolidation path (e.g., a style guide going forward, not a mass rename).
- **Poor Answer:** Fabricates a clean distinction between the folder names that isn't supported by the code.

---

### A6. `repositories/` contains exactly one repository (`ProfileRepository`), but six other collections are queried directly from their consuming modules. Is this a problem?
- **Difficulty:** Medium | **Importance:** 8
- **Expected Answer:** Yes — it's an inconsistent data-access architecture. The one repository correctly hides Mongo-specific concerns (projections, `$set` semantics) behind a typed interface; every other collection (`transactions`, `merchants`, `feedback`, `behavior_patterns`) is queried with raw dicts scattered across `analytics/`, `rag/`, `graphs/`, `feedback/`. A schema change to any of those requires grepping the whole codebase instead of updating one file.
- **Follow-ups:** "Which collection would you prioritize wrapping in a repository next, and why?"
- **Common Mistakes:** Treating "only one repository exists" as automatically fine because "not every collection needs one."
- **What This Tests:** Whether the candidate can identify architectural inconsistency as a real cost, not just a stylistic quirk.
- **Red Flags:** No opinion either way — treats it as a non-issue.
- **Excellent Answer:** Prioritizes `merchant_profiles`-adjacent collections that are read from multiple places (`behavior_patterns`, since it's read by `analytics/`, `rag/`, and `graphs/` — three consumers directly coupled to its raw shape).
- **Poor Answer:** "It's fine, MongoDB is schemaless anyway" — misses that the *code's* coupling to a raw shape is the actual risk, not the database's schema flexibility.

---

### A7. `database/milvus.py` and `milvus/insert_vectors.py` both construct a `MilvusClient`. Why does this exist, and what's the risk?
- **Difficulty:** Medium | **Importance:** 8
- **Expected Answer:** Two independent client instances reading configuration two different ways — `database/milvus.py`'s `vector_db` reads `settings.MILVUS_URI` (via `core.config`) and is managed by the app's `lifespan`, but is never actually used for real traffic. `milvus/insert_vectors.py`'s `vector_store` reads `MILVUS_URI` via `os.getenv` directly, bypassing `core.config` entirely, and is what actually powers `/v1/explain`'s search. Risk: configuration drift — fixing "Milvus connectivity" by editing `.env` could silently fail to affect the client that matters, since the two clients don't necessarily observe the same environment-loading mechanism consistently.
- **Follow-ups:** "How would you consolidate these into one client?" "Which one does `/health` actually check?"
- **Common Mistakes:** Assuming `/health`'s Milvus status reflects the client that powers `/v1/explain` — it doesn't; `/health` checks the unused `vector_db`.
- **What This Tests:** Ability to trace which of two similarly-named objects is actually load-bearing, a common real-world debugging skill.
- **Red Flags:** Doesn't distinguish the two clients at all, treats "Milvus client" as one thing.
- **Excellent Answer:** Explicitly calls out that `/health` can report `milvus: connected` while the real search path is broken, or vice versa — a genuinely dangerous observability gap.
- **Poor Answer:** "There's a Milvus client that connects to the vector database" — no awareness of the duplication.

---

### A8. Why does `routers/v1.py` have two handlers registered for `POST /v1/categorize`?
- **Difficulty:** Hard | **Importance:** 7
- **Expected Answer:** One is the real handler in `routers/v1.py` (mounted via `include_router` at line 65 of `app.py`); the other is a static-response stub declared inline on `app` in `app.py` (line 73). Because Starlette matches routes in registration order and the router is included *before* the inline stub is declared, the router's handler wins every time — the inline stub is unreachable dead code, not a live ambiguity.
- **Follow-ups:** "What would happen if the order of those two registrations were swapped?" "How would you detect this kind of duplication in code review?"
- **Common Mistakes:** Assuming FastAPI would raise an error or warn about a duplicate path — it doesn't; both are silently registered and the first match wins.
- **What This Tests:** Deep understanding of Starlette/FastAPI route resolution order, not just "how do I define a route."
- **Red Flags:** Says "FastAPI would throw an error for duplicate routes" (false) or can't explain which one wins.
- **Excellent Answer:** Correctly identifies that swapping the order would make the inline stub win instead, silently breaking the real categorize logic without any error — and that this is exactly the kind of bug that's invisible without reading `app.py` line-by-line.
- **Poor Answer:** "Not sure which one runs, probably both fire?" — factually wrong about how routing works.

---

### A9. Why does `graphs/graph_builder.py` exist with zero callers anywhere in the codebase — not even from other unused modules?
- **Difficulty:** Medium | **Importance:** 5
- **Expected Answer:** It represents a synthesis layer intended to model relationships across Phases 4, 6, 8, and 10's outputs (memory state, behavior, clusters, feedback) that no single collection captures — but it was apparently built and then never wired to anything, not even the other disconnected modules that at least reference each other conceptually (e.g., `clustering/` writes a field `graphs/` reads, but `graphs/` doesn't know `clustering/` exists as a caller relationship).
- **Follow-ups:** "How would you decide whether to finish this or delete it?" "What would the minimum viable integration look like?"
- **Common Mistakes:** Assuming code with zero callers must be recently written/incomplete — it could equally be abandoned or superseded; the candidate should reason about how to tell the difference (check git history, check for a corresponding router stub, check TODO comments).
- **What This Tests:** Comfort with "dead code" triage — a real, constant task in production codebases.
- **Red Flags:** Assumes without checking that something else must call it.
- **Excellent Answer:** Proposes checking whether `rag/context_builder.py`'s docstrings or comments reference the graph (they do — "extracting context for the Phase 12 RAG LLM") as evidence of original intent, then scoping a minimal router to expose it before deciding to delete.
- **Poor Answer:** "It's probably used somewhere" without verifying.

---

### A10. What's the blast radius if `models/schemas.py` were deleted?
- **Difficulty:** Easy | **Importance:** 6
- **Expected Answer:** Total, immediate failure — nearly every router, engine, service, and repository imports from it directly. `app.py`'s router includes would fail to import, meaning the entire HTTP API becomes unloadable, not just degraded.
- **Follow-ups:** "Contrast that with deleting `graphs/`."
- **Common Mistakes:** Underestimating the blast radius because "it's just data models."
- **What This Tests:** Understanding that a "boring" shared-types file can be the single point of failure for an entire system.
- **Red Flags:** Says "probably just breaks a few things" without recognizing the fan-in.
- **Excellent Answer:** Explicitly contrasts this with `graphs/graph_builder.py` (zero callers, zero impact if deleted) to demonstrate understanding that blast radius is about *fan-in*, not code size or complexity.
- **Poor Answer:** Vague "some stuff would break."

---

### A11. Is `core/ollama_client.py` resolving the Ollama host at import time a good design choice?
- **Difficulty:** Hard | **Importance:** 7
- **Expected Answer:** Defensible as fail-fast (you find out immediately at startup rather than on the first user request), but risky because it means *any* module importing this one transitively — including test collection, or an unrelated script — pays the cost and risk of real network calls and possible `RuntimeError`. A lazier, request-time or health-check-driven resolution would isolate the failure mode to the specific feature that needs it.
- **Follow-ups:** "How would you redesign this to keep fail-fast behavior without the import-time coupling?"
- **Common Mistakes:** Treating fail-fast as unconditionally good without acknowledging the blast-radius cost of doing it via import-time side effects specifically.
- **What This Tests:** Nuanced trade-off reasoning, not a one-sided "fail fast is best practice" answer.
- **Red Flags:** No mention of the coupling/blast-radius cost at all.
- **Excellent Answer:** Proposes a lazy singleton pattern (resolve on first actual use, cache the result) that preserves fail-fast-on-first-use semantics without punishing unrelated imports.
- **Poor Answer:** "Fail fast is always good practice" with no critique.

---

### A12. Why might `evaluation/metrics.py` and `features/*.py` be considered the highest-quality code in this repository, architecturally speaking?
- **Difficulty:** Medium | **Importance:** 5
- **Expected Answer:** They're pure functions — no I/O, no shared state, no side effects beyond logging (in `evaluation/metrics.py`'s case). This makes them trivially unit-testable (even though no tests currently exist for them) and safe to reason about in isolation, in contrast to most of the rest of the codebase, which mixes I/O and business logic.
- **Follow-ups:** "Why do you think these specific modules ended up this clean while others didn't?"
- **Common Mistakes:** Conflating "has no bugs" with "is well-architected" — some other modules also have no known bugs but aren't pure functions.
- **What This Tests:** Ability to identify architectural quality independent of bug count.
- **Red Flags:** Can't articulate what "pure function" means or why it matters for testability.
- **Excellent Answer:** Notes that being pure functions is *why* they were easy to verify correctness on by inspection alone (as this documentation effort did), compared to the I/O-heavy modules that required tracing real database/network behavior.
- **Poor Answer:** "They're good because they work" — no architectural reasoning.

---

### A13. The RAG pipeline (`rag/retriever.py`, `context_builder.py`, `generator.py`) has three files for three pipeline stages. Is this the same pattern as `clustering/`'s three files?
- **Difficulty:** Medium | **Importance:** 5
- **Expected Answer:** Similar shape (multiple single-purpose files feeding one orchestrator) but different origin: RAG's three stages are genuinely sequential and each does meaningfully different work (retrieval, formatting, generation); `clustering/`'s three files are more like algorithm-wrapper-plus-orchestrator (`umap_projection.py` and `hdbscan_cluster.py` are thin config wrappers around library calls, while `cluster_engine.py` does the real orchestration and persistence).
- **Follow-ups:** "Which pattern would you use as a template for a new pipeline feature?"
- **Common Mistakes:** Treating all "three-file pipelines" in the codebase as interchangeable without noticing the different distribution of responsibility.
- **What This Tests:** Close reading — can the candidate distinguish two structurally similar-looking designs by their actual responsibility split.
- **Red Flags:** Says they're "basically the same pattern" with no distinction.
- **Excellent Answer:** Notes that RAG's `routers/rag.py` inlines the orchestration of all three stages (a controller doing what should arguably be a service's job), whereas clustering's orchestration is properly contained in `cluster_engine.py` — an inconsistency worth naming.
- **Poor Answer:** Generic "separation of concerns, good design" with no specifics.

---

### A14. Explain the actual dependency chain that would break if `core/config.py` failed to import.
- **Difficulty:** Medium | **Importance:** 8
- **Expected Answer:** `core.ollama_client`, `database.mongo`, `database.milvus`, and `app.py` all import `settings` directly — all four fail immediately. Since `app.py` needs `database.mongo`/`database.milvus` and (transitively via routers) `core.ollama_client`, the entire application fails to import, not just start.
- **Follow-ups:** "At what exact line does this failure happen, and why does it happen before any FastAPI code runs?"
- **Common Mistakes:** Saying "the app would just fail to start" without identifying that it's an import-time, not runtime, failure — meaning even something as innocuous as `pytest --collect-only` would fail.
- **What This Tests:** Precision about *when* in the Python execution model a failure occurs.
- **Red Flags:** Conflates "fails to start" with "starts but errors on first request" — these are very different failure modes here.
- **Excellent Answer:** Notes that `settings = Settings()` runs at `core/config.py`'s module level, so the failure happens the instant that line executes — before `app = FastAPI(...)` is even reached, let alone `lifespan`.
- **Poor Answer:** "The health check would report unhealthy" — wrong; the process wouldn't even get that far.

---

### A15. Why does `app.py` configure `logging.basicConfig(level=logging.DEBUG)` at the root logger level rather than per-module?
- **Difficulty:** Easy | **Importance:** 4
- **Expected Answer:** `basicConfig` sets the root logger's level, which every module's `logging.getLogger(__name__)` inherits by default unless it explicitly overrides its own level — so this one line controls verbosity application-wide. The cost: no environment-based override (no `LOG_LEVEL` env var read anywhere), so every deployment runs at maximum verbosity regardless of environment.
- **Follow-ups:** "How would you make this configurable per environment?"
- **Common Mistakes:** Assuming each module's logger has an independent level unless proven otherwise.
- **What This Tests:** Basic but often-misunderstood Python logging hierarchy knowledge.
- **Red Flags:** Doesn't know what `basicConfig` actually configures.
- **Excellent Answer:** Proposes reading a `LOG_LEVEL` setting from `core.config.Settings` and passing it into `basicConfig`, defaulting to `INFO` in anything but explicit local dev.
- **Poor Answer:** "It just turns logging on" — no understanding of the hierarchy or scope.

---

### A16. Contrast the failure-handling philosophy in `database/milvus.py::VectorDB.connect` versus `core/ollama_client.py::resolve_ollama_host`.
- **Difficulty:** Hard | **Importance:** 7
- **Expected Answer:** `VectorDB.connect` degrades gracefully — after exhausting retries, it sets `client = None` and returns normally, letting the app start in a degraded state. `resolve_ollama_host` raises `RuntimeError` on total failure, which (since it runs at import time) can crash the whole process. These are inconsistent philosophies for what should arguably be treated the same way (both are "can we reach an external dependency" checks).
- **Follow-ups:** "Which philosophy do you think is correct for each, and why might they differ?"
- **Common Mistakes:** Assuming this inconsistency was deliberate risk-based design rather than likely an artifact of different authors/times.
- **What This Tests:** Ability to spot and name inconsistency as a real finding, not just describe each function individually.
- **Red Flags:** Describes each function's behavior correctly but never compares them or notes the inconsistency.
- **Excellent Answer:** Argues that Milvus's graceful degradation is arguably more correct (some traffic can still work without it) while Ollama's hard failure blocks feature areas (RAG, embeddings) that specifically need it — and that a consistent policy would apply "degrade gracefully" to both, deferring failure to actual request time.
- **Poor Answer:** Only describes one of the two functions.

---

### A17. Why are `engines/rule_engine.py` and `services/merchant_resolver.py` two entirely separate systems, given they solve adjacent problems (turning text into a merchant/category)?
- **Difficulty:** Medium | **Importance:** 6
- **Expected Answer:** Different eras/phases of development (Phase 1-2 vs Phase 3) with different data sources (`merchant_aliases.json` vs the `merchants` MongoDB collection) and different matching strategies (exact whole-word regex vs exact/substring database lookup). The rule engine's own comments even reference the resolver's Milvus-based intended successor as the "real" long-term direction. They were never unified.
- **Follow-ups:** "Would you unify them? What would that look like?"
- **Common Mistakes:** Assuming one calls the other, or that they share the alias data.
- **What This Tests:** Whether the candidate actually traced both code paths rather than assuming a sensible-sounding relationship exists.
- **Red Flags:** Claims they share a data source when they don't.
- **Excellent Answer:** Notes the `bundl` → `Swiggy` mapping exists independently in *both* `merchant_aliases.json` and (implicitly, via `scripts/seed.py`'s `merchants` collection aliases) — the same real-world fact encoded twice, in two systems that never talk to each other.
- **Poor Answer:** "They're similar functions" with no detail on the actual divergence.

---

### A18. If you had to add a new "Phase 16" feature to this codebase, what pattern from the existing architecture would you follow, and what would you deliberately avoid repeating?
- **Difficulty:** Hard | **Importance:** 7
- **Expected Answer:** Follow: single-purpose files per concern (like `features/`), a singleton service instantiated at import time (consistent with the rest of the codebase), thin router delegation. Avoid: leaving the feature's HTTP router unwritten or unmounted (as happened to Phase 10's feedback), skipping the write-path orchestrator (as happened to Phase 7's embeddings), and using ad hoc naming inconsistent with existing folders.
- **Follow-ups:** "How would you verify your new feature is actually wired end-to-end before calling it done?"
- **Common Mistakes:** Only discussing code style, not the wiring/completeness failure mode that's actually caused most of this codebase's disconnected features.
- **What This Tests:** Whether the candidate has internalized the *actual* recurring failure pattern in this codebase (half-built features), not just its code style.
- **Red Flags:** Generic "follow SOLID principles" answer with no reference to this codebase's specific history of incomplete wiring.
- **Excellent Answer:** Proposes an explicit checklist mirroring what's missing today: is the router written *and* mounted in `app.py`? Is there an automated or scheduled trigger, not just a manually-invokable function? Is there a test that exercises the full HTTP path, not just the service function directly?
- **Poor Answer:** Purely stylistic answer about naming conventions.

---

### A19. What does the fact that `feedback/api_router.py` lives inside `feedback/` rather than `routers/` suggest, architecturally?
- **Difficulty:** Medium | **Importance:** 4
- **Expected Answer:** A minor structural inconsistency — every other router lives in `routers/`, grouped by HTTP concern; this one is grouped with its own feature's service files instead. It's a small signal, but it may partly explain why it was never mounted: it wasn't sitting alongside the other routers where a reviewer updating `app.py`'s imports would naturally notice it.
- **Follow-ups:** "Does folder placement actually cause bugs, or just correlate with them?"
- **Common Mistakes:** Overstating this as "the cause" of the unmounted-router bug rather than a plausible contributing factor.
- **What This Tests:** Calibrated reasoning about correlation vs. causation in code organization.
- **Red Flags:** States this folder placement definitely caused the bug, presented as fact rather than plausible contributing factor.
- **Excellent Answer:** Frames it as "structure influences visibility, which influences correctness" — a real, if soft, argument for consistent project layout.
- **Poor Answer:** No opinion on why it matters at all.

---

### A20. In a system design review, what's the single most important architectural fact you'd want a new engineer to know before they touch this codebase?
- **Difficulty:** Hard | **Importance:** 9
- **Expected Answer:** That the visible route list in `routers/` is not the same as "what's reachable" (`feedback/api_router.py` isn't mounted) and that a working service function doesn't mean a working feature end-to-end (behavior profiling, embedding generation, clustering, and decay all have real, correct code with zero live callers). The single habit that would save the most time: before assuming any function runs automatically, grep for its actual callers.
- **Follow-ups:** "How would you bake that habit into the review process rather than relying on tribal knowledge?"
- **Common Mistakes:** Naming a specific bug instead of the meta-pattern that makes this codebase's bugs hard to find in the first place.
- **What This Tests:** Whether the candidate can zoom out from individual defects to the systemic property that produces them — the hallmark of senior-level codebase comprehension.
- **Red Flags:** Answers with "fix the categorize bug" — a real bug, but not the meta-lesson the question is asking for.
- **Excellent Answer:** Proposes a lightweight, concrete process fix — e.g., a CI check that fails if a `routers/*.py` file defining a `router` isn't referenced in `app.py`.
- **Poor Answer:** Restates a known bug without generalizing to the pattern.
