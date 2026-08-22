# 20 Â· Design Decisions Deep Dive

Every major architectural decision in Vela, analyzed the way a design-review committee would: why it was chosen, what else was on the table, its real pros and cons, the core tradeoff it represents, why it fits (or doesn't) this specific project, the conditions under which it breaks, how a FAANG-caliber team would harden it, and what changes at 1 million users.

This document covers the **13 decisions that actually define this system's character** â€” not every implementation detail, but the choices that would come up in a real architecture review. Where the codebase doesn't explicitly document its own rationale (most of it doesn't), that's stated plainly as inference from context, not asserted as fact.

## Table of Contents
1. [Layered, Deterministic-First Categorization Pipeline](#1-layered-deterministic-first-categorization-pipeline)
2. [The Confidence Wall](#2-the-confidence-wall)
3. [The Memory / Trust State Machine](#3-the-memory--trust-state-machine)
4. [Grounded RAG (Retrieval-Gated Generation)](#4-grounded-rag-retrieval-gated-generation)
5. [Dual Database Architecture (MongoDB + Milvus)](#5-dual-database-architecture-mongodb--milvus)
6. [Document-Oriented, Schemaless Data Modeling](#6-document-oriented-schemaless-data-modeling)
7. [Module-Level Singletons Instead of Dependency Injection](#7-module-level-singletons-instead-of-dependency-injection)
8. [Single Shared Static API Key](#8-single-shared-static-api-key)
9. [Async-First Architecture (FastAPI + Motor)](#9-async-first-architecture-fastapi--motor)
10. [No Caching Layer](#10-no-caching-layer)
11. [Self-Hosted Ollama Instead of a Hosted LLM API](#11-self-hosted-ollama-instead-of-a-hosted-llm-api)
12. [UMAP + HDBSCAN for Unsupervised Merchant Clustering](#12-umap--hdbscan-for-unsupervised-merchant-clustering)
13. [Pure-Function Feature Extraction Layer](#13-pure-function-feature-extraction-layer)

---

## 1. Layered, Deterministic-First Categorization Pipeline

**What it is**: `engines/rule_engine.py` handles categorization first, via a static, pre-compiled regex dictionary â€” cheap, fast, fully deterministic â€” before any statistical or ML-based approach is invoked.

**Why this approach was chosen**: This is the classic "cascade" pattern used across the industry (spam filters, fraud detection, ad ranking) â€” put the cheapest, most confident classifier first, and only escalate to expensive, uncertain methods for what it can't handle. The code's own phase numbering (Phase 1-2 for rules, later phases for ML) shows this was a deliberate sequencing, not an accident.

**Alternative approaches**:
- A single ML classifier handling every transaction from day one.
- A single LLM call per transaction (prompt-based categorization with no rule layer at all).
- A fully manual, rule-only system with no ML escalation path ever.

**Pros**: Zero inference cost and near-zero latency for covered merchants; fully deterministic and auditable (you can always explain *why* a categorization happened by pointing at the exact matched alias); works with zero model dependency, so it's resilient to Ollama/ML pipeline outages entirely.

**Cons**: Brittle to spelling variation, new merchants, and regional narration formats; coverage is hard-capped by dictionary size (9 entries today); requires manual curation to grow, with no automatic learning loop currently wired up.

**Tradeoffs**: Coverage vs. cost, latency, and determinism. Precision on covered cases is excellent; recall is bounded entirely by how comprehensive the static dictionary is.

**Why it fits this project**: Personal transaction data has a genuinely "fat head, long tail" distribution â€” a small number of extremely common merchants (food delivery, ride-hailing, streaming) account for a large share of real transaction volume, so a cheap dictionary lookup correctly resolves the majority case before anything expensive is ever invoked.

**When it would fail**: The moment a user's transaction history is dominated by merchants outside the dictionary's fixed 9 entries â€” which, in this current implementation, is *most* real-world transaction data, since the dictionary has never been grown from production feedback. It also fails silently: an uncategorized transaction just becomes `"Uncategorized"` with no signal to anyone that the dictionary needs updating.

**How FAANG engineers might improve it**: Close the loop between Phase 10 (the currently-unmounted feedback system) and this dictionary â€” every human correction should be a candidate for automatic alias mining, with a review/approval step before promotion into the live dictionary (exactly the "active learning" pattern this codebase's own comments gesture at but never wire up). At dictionary sizes beyond a few hundred entries, replace the current N-independent-regexes linear scan with an Aho-Corasick automaton for O(text length) matching regardless of dictionary size. Treat the alias dictionary as a versioned, canary-deployable artifact (like a model), not a static JSON file baked into the container image.

**How to scale it to 1 million users**: The lookup itself is already O(1) per process (in-memory, pre-compiled) and needs no scaling work on its own. What needs to scale is the *pipeline that keeps it comprehensive*: a real feedback-mining job aggregating corrections across a million users' worth of transaction diversity, a human-review sampling process to approve new aliases without full manual curation of every case, and hot-reloading the dictionary across all running instances without a redeploy (e.g., via a shared config service polled or pushed to every replica) so a newly-mined alias benefits every user immediately, not just after the next deployment.

---

## 2. The Confidence Wall

**What it is**: `engines/confidence_engine.py::evaluate` forces any prediction below a 0.5 confidence threshold, or outside the known category vocabulary, to `Unknown` rather than passing a low-confidence guess through.

**Why this approach was chosen**: Explicit, stated design philosophy â€” *"Unknown is a valid answer."* In a system whose output feeds analytics, budgeting insights, and RAG explanations, a wrong-but-confident-looking category corrupts everything built on top of it. Abstaining is safer than guessing.

**Alternative approaches**:
- Always return the best available guess with a raw confidence score, and let each downstream consumer decide its own threshold.
- A multi-tier fallback chain (rule engine â†’ ML model â†’ LLM) that only resorts to `Unknown` if every tier fails.
- Route low-confidence predictions to a human review queue instead of discarding them to `Unknown`.

**Pros**: Simple, single choke point; protects every downstream consumer uniformly without each one needing its own trust logic; prevents silent, compounding data corruption in analytics.

**Cons**: A single, static, global threshold (`0.5`) ignores that acceptable confidence should plausibly vary by category (misclassifying "Bills" as "Entertainment" may be more costly than the reverse) and by how well-calibrated the specific upstream model actually is â€” untested by any calibration study in this codebase, despite `evaluation/metrics.py` already implementing the exact metric (`expected_calibration_error`) that could validate it.

| | Pros | Cons |
|---|---|---|
| **Correctness** | Never propagates a low-confidence wrong answer | Perfectly calibrated 0.49 confidence and wildly miscalibrated 0.49 confidence are treated identically |
| **Simplicity** | One rule, one threshold, easy to reason about | No per-category or per-context nuance |
| **User experience** | Predictable, honest behavior | High false-abstain rate frustrates users if the model is poorly calibrated |

**Tradeoffs**: Precision vs. recall/coverage â€” a blunt instrument that trades usefulness (fewer categorized transactions) for correctness (fewer wrong ones).

**Why it fits this project**: Financial categorization errors compound â€” a miscategorized transaction skews trend charts, subscription detection, and budget alerts, all without the user necessarily noticing the root cause. Users are far more forgiving of "we don't know" than of silently wrong numbers in their financial dashboard.

**When it would fail**: If the underlying model is systematically *underconfident* (predicts correctly but with low reported confidence), this wall would reject a large fraction of genuinely correct predictions, ballooning the `Unknown` bucket and frustrating users â€” and this codebase has no mechanism to detect that specific failure mode, since nothing currently feeds real predictions through `evaluation/metrics.py`'s calibration measurement.

**How FAANG engineers might improve it**: Actually wire `expected_calibration_error` into a feedback loop that periodically recalibrates the threshold (or better, fits a proper Platt/isotonic calibration curve, which `calibrate_probability`'s docstring already promises but doesn't implement) against real production outcomes. Move to per-category thresholds informed by the actual cost of a misclassification in that category. Route rejected/`Unknown` predictions into an active-learning queue with human labeling at scale, closing the loop that currently dead-ends.

**How to scale it to 1 million users**: The evaluation itself is cheap and stateless â€” no scaling challenge there. The real work is operationalizing continuous calibration: a scheduled job recomputing ECE against a growing, representative sample of labeled outcomes, shadow-testing any threshold change against historical data before rolling it out, and per-tenant/per-locale threshold tuning once user diversity (different countries' merchant landscapes, different bank narration formats) means one global threshold stops being the right global assumption.

---

## 3. The Memory / Trust State Machine

**What it is**: `memory/state_machine.py` and `memory/memory_manager.py` implement a four-state trust ladder (`EPHEMERAL â†’ TEMPORARY â†’ PERMANENT`, with `ARCHIVED` for long-dormant entities) driven purely by encounter frequency (3 and 10 sightings as thresholds).

**Why this approach was chosen**: To avoid building expensive downstream profiles (behavioral fingerprints, embeddings) for entities that might be one-off noise â€” typos, fraud-adjacent strings, or genuinely rare merchants. README explicitly states: "Heavy analytics and embedding generations are reserved for PERMANENT entities to optimize compute costs."

**Alternative approaches**:
- Treat every entity identically from first sight (no trust gating at all).
- A continuous, probabilistic trust score (e.g., a logistic function of recency-weighted encounter count) instead of four discrete states.
- Exponential-decay trust that erodes gradually over time rather than a hard 180-day cliff to `ARCHIVED`.

**Pros**: Simple, explainable, four human-readable states; naturally throttles expensive compute to well-established entities; has an explicit reactivation path for dormant-but-real entities.

**Cons**: Thresholds (3, 10) are hardcoded with zero empirical validation anywhere in the codebase; `frequency` is a ratchet that never resets, even across archival/reactivation, meaning historical noise permanently inflates future trust decisions; the four discrete buckets can't express "almost trustworthy" â€” a merchant at 9 encounters is treated identically to one at 3.

**Tradeoffs**: Simplicity and explainability now, versus statistical rigor and nuance later â€” a textbook "ship the simple version first" trade that hasn't yet been revisited.

**Why it fits this project**: Personal finance narration text is genuinely noisy (bank-specific formatting, typos, ambiguous abbreviations) â€” requiring repeated confirmation before treating a string as a stable, canonical entity is a sound defense against wasting compute (and polluting analytics) on garbage.

**When it would fail**: Under bursty or adversarial input â€” a merchant seen 9 times, one short of `TEMPORARY`, gets no trust benefit at all, an all-or-nothing cliff with no smooth degradation. It also fails to distinguish a highly active user who racks up 10 encounters with a genuinely one-off merchant within a week from a low-activity user who needs a year to hit the same raw count for a truly recurring one â€” frequency thresholds aren't normalized by activity level or time window at all.

**How FAANG engineers might improve it**: Replace raw encounter counts with a time-windowed or recency-weighted rate (encounters per unit of the user's own activity, not an absolute count) so the thresholds mean the same thing for a heavy user and a light user. Move to a continuous trust score enabling graceful downstream decisions (e.g., "70% confidence this merchant deserves embedding" rather than a hard binary gate). A/B test threshold changes against a real quality metric (behavior-profile accuracy, RAG explanation usefulness) before rolling them out globally, using an internal experimentation platform.

**How to scale it to 1 million users**: The core question is whether merchant trust should be *global* (shared reference data â€” "Swiggy" is trustworthy to everyone) or *per-user* (a private landlord or employer is genuinely personal). At 1M users, a hybrid model is likely correct: seed and maintain a shared, curated global merchant registry (benefiting from cross-user signal â€” a merchant seen by thousands of users reaches `PERMANENT` almost instantly) while retaining a lightweight per-user trust track for genuinely idiosyncratic entities that will never be common across users. This requires sharding trust state by a combination of global-merchant-ID and user-ID, a materially different data model than today's single global `merchant_profiles` collection.

---

## 4. Grounded RAG (Retrieval-Gated Generation)

**What it is**: `rag/retriever.py`, `context_builder.py`, and `generator.py` implement a pipeline that refuses to call the LLM at all if semantic retrieval finds nothing, and constrains the LLM with both a strict system prompt and structured (`format: "json"`) decoding when it is called.

**Why this approach was chosen**: To prevent hallucinated financial explanations â€” a stated design goal, defended in depth at two independent layers (prompt-level instruction and decoding-level structure) rather than relying on either alone.

**Alternative approaches**:
- Always call the LLM and trust the prompt alone to produce "I don't know" when appropriate.
- Fine-tune a small, purpose-built explanation model instead of prompting a general-purpose LLM.
- Skip the LLM entirely â€” generate explanations from a fixed template filled in with structured stats (no generative model at all).

**Pros**: Strong hallucination resistance; saves real cost and latency by never invoking the (slow, expensive) LLM when there's nothing to ground it in; structured decoding meaningfully reduces parsing failures compared to free-form text generation.

**Cons**: Coverage is entirely bottlenecked by retrieval quality â€” and since the embedding-write pipeline that would populate Milvus has no live caller anywhere in this codebase, the system reports "no data available" far more often than the underlying data would actually justify; there's no schema validation of the LLM's *parsed* output, only its JSON syntax, so a syntactically valid but semantically wrong response passes through unchecked.

**Tradeoffs**: Faithfulness and safety vs. coverage and perceived usefulness â€” the system would rather say nothing than say something plausible-but-wrong, at a real user-experience cost when that caution isn't actually necessary.

**Why it fits this project**: An explanation that shapes a user's understanding of their own finances carries real trust implications â€” a fabricated-but-eloquent explanation is worse than an honest "insufficient data," especially for a system whose whole broader philosophy (see the Confidence Wall) is built around refusing to guess.

**When it would fail**: At any meaningful scale, if the retrieval pipeline's data-population side remains unoperationalized (as it is today) â€” a "grounded" system that's silently starved of ground truth degrades into a technically-safe but practically-useless one, with no monitoring anywhere in this codebase to surface that degradation as a visible signal to operators.

**How FAANG engineers might improve it**: Add output-schema validation with automatic retry-with-correction (re-prompt the model with the validation error if its JSON doesn't match the expected keys) instead of silently trusting the parse. Instrument retrieval hit-rate as a first-class, alerted-on metric â€” a grounded RAG system's most dangerous failure mode is silent, gradual data starvation, not a loud crash. Build a continuous evaluation harness (a golden set of query/expected-explanation pairs) that gates any prompt or model change, since prompt engineering without regression testing is famously fragile.

**How to scale it to 1 million users**: Embedding and generation costs become the dominant driver â€” aggressive caching by content hash (identical or near-identical transaction narration text â€” "UPI Swiggy" â€” recurs constantly across a large user base, making this an unusually cache-friendly workload), request batching to the inference layer, and tiered model routing (a small, fast, cheap model for the common case, escalating to a larger model only for genuinely novel queries the small model reports low confidence on) would all be necessary. Milvus would need its distributed/cluster deployment mode at the resulting vector volume, and the currently-nonexistent write pipeline would need to become real, monitored, horizontally-scaled infrastructure â€” likely a CDC-driven ingestion pipeline (see Decision 5) rather than an ad hoc script.

---

## 5. Dual Database Architecture (MongoDB + Milvus)

**What it is**: MongoDB serves as the system of record for all structured domain state; Milvus is a separate, purpose-built vector database for semantic similarity search.

**Why this approach was chosen**: Likely because purpose-built vector databases historically offered more mature, tunable approximate-nearest-neighbor indexing (HNSW with configurable `M`/`efConstruction`/`ef`) than general-purpose databases' earlier, more limited vector-search add-ons â€” a legitimate "best tool for the job" instinct at the time this was architected.

**Alternative approaches**:
- MongoDB Atlas Vector Search â€” unify storage and vector search on one platform.
- PostgreSQL with the `pgvector` extension â€” a single relational-plus-vector system.
- A fully managed third-party vector search service, trading some tuning control for reduced operational burden.

**Pros**: Milvus's dedicated ANN indexing is likely to outperform a bolt-on vector feature at genuinely large scale; MongoDB's schema flexibility suits a domain model that's visibly still evolving (new fields bolted onto `behavior_patterns` without a corresponding schema update, for instance).

**Cons**: Two independent systems to run, monitor, secure, and keep consistent â€” and this specific cost has already manifested as concrete, documented bugs: two separate, inconsistently-configured Milvus client instances, and a completely unoperationalized write path leaving the vector store permanently empty in most deployments.

**Tradeoffs**: Best-of-breed feature depth per system vs. operational simplicity and built-in consistency guarantees a single unified system would provide "for free."

**Why it fits this project**: Arguably, it doesn't yet â€” at this project's current maturity and scale, the operational complexity of running two databases has already outweighed the benefit, since the vector-search feature it enables isn't even reliably populated end-to-end. The theoretical performance ceiling Milvus offers has never been tested against real load this system has actually experienced.

**When it would fail**: It's already failing in the specific sense that matters most â€” data consistency between the two stores was never solved, so the vector index doesn't reflect reality. It would also fail operationally for a small team: maintaining two data stores' backups, access control, and monitoring is a real, ongoing tax that a single-database approach would avoid entirely at this scale.

**How FAANG engineers might improve it**: Adopt a formal outbox or Change-Data-Capture pattern â€” write behavioral/profile changes to MongoDB as the single source of truth, and use MongoDB Change Streams (or a CDC tool like Debezium) to reliably, asynchronously propagate relevant updates into Milvus, eliminating today's manual, never-invoked write path entirely. Add scheduled reconciliation jobs that diff document counts/checksums between the two stores and page someone on drift. Treat "is the vector index actually in sync with Mongo" as a monitored SLO, not an assumption.

**How to scale it to 1 million users**: Milvus needs its distributed/cluster deployment mode (not the standalone mode implied by this codebase's setup) to handle the resulting vector volume and query throughput; MongoDB needs sharding (see Decision 6/Database analysis for shard key design); and the CDC pipeline connecting them becomes essential, monitored infrastructure â€” at this scale, manual or synchronous dual-writes would never keep pace with write volume, making an asynchronous, replayable event pipeline a hard requirement rather than a nice-to-have.

---

## 6. Document-Oriented, Schemaless Data Modeling

**What it is**: The entire domain model is stored as MongoDB documents with no server-side schema validation (`$jsonSchema` validators), no foreign-key constraints, and â€” for six of seven collections â€” no repository abstraction layer between business logic and raw document shape.

**Why this approach was chosen**: MongoDB's flexibility is well suited to a domain model that's still actively evolving â€” `behavior_patterns.discovered_cluster` being added by a second writer with no corresponding Pydantic model update is a direct example of this flexibility being actively exercised, for better and worse.

**Alternative approaches**:
- A relational database (PostgreSQL) with normalized tables, foreign keys, and migrations enforcing referential integrity.
- MongoDB with `$jsonSchema` validators enforced from day one, trading away some flexibility for database-level correctness guarantees.
- An ORM/ODM layer (e.g., Beanie, MongoEngine) providing a consistent, validated access pattern uniformly across every collection, rather than the current one-collection-has-a-repository, six-don't inconsistency.

**Pros**: Fast iteration â€” no migration ceremony required to add a field; natural fit for the genuinely variable shapes different phases produce; low ceremony for a small team moving quickly.

**Cons**: Zero referential integrity anywhere â€” the `feedback.prediction`-holds-a-category-but-is-queried-as-a-merchant-name bug (documented in the Database Analysis) is a direct, real consequence of having no schema contract enforced at the database layer; six of seven collections are queried with raw dicts scattered across many files, meaning a schema change requires grepping the whole codebase rather than updating one place.

**Tradeoffs**: Development speed and flexibility now vs. data-integrity guarantees and long-term maintainability â€” this codebase has already paid for this trade with at least one confirmed silent data-integrity bug.

**Why it fits this project**: For the genuinely fast-evolving, exploratory parts of the system (feature extraction outputs, clustering results), schema flexibility is a legitimate asset. It fits far less well for the parts of the system acting as a stable contract between multiple consumers (`feedback`, `merchant_profiles`) â€” exactly where the real bugs have appeared.

**When it would fail**: It's already failing in the specific, documented case of `feedback.prediction`'s field-semantics mismatch â€” a `$jsonSchema` validator or even a shared repository would have made this class of bug far harder to introduce silently. It would fail more broadly as more independent consumers read/write the same collections without a single shared contract to coordinate them.

**How FAANG engineers might improve it**: Add `$jsonSchema` validators at minimum to the collections with more than one active consumer (`merchant_profiles`, `behavior_patterns`, `feedback`) â€” a cheap, database-enforced correctness backstop that doesn't require abandoning MongoDB's flexibility elsewhere. Extend the repository pattern (currently only `ProfileRepository`) to every collection with more than one reader/writer, centralizing the "what does this document actually look like" knowledge in one place per collection instead of scattering it. Introduce contract tests that assert every writer of a collection produces documents every reader can correctly interpret.

**How to scale it to 1 million users**: Schema drift and referential-integrity bugs get *more* expensive to discover and fix as data volume grows â€” a bug like the `feedback.prediction` mismatch discovered at 1M-user scale means retroactively repairing potentially billions of documents, versus a comparatively trivial fix today. This argues strongly for closing the schema-validation and repository-abstraction gaps *before* significant scale, not after â€” the cost of fixing this asymmetrically favors doing it early.

---

## 7. Module-Level Singletons Instead of Dependency Injection

**What it is**: Every service, engine, and repository in this codebase is instantiated once at import time as a module-level object (`rule_engine = RuleEngine()`), imported directly wherever needed â€” FastAPI's `Depends()` mechanism is used for exactly one thing (authentication) in the entire application.

**Why this approach was chosen**: Simplicity and development velocity â€” one line per service, zero wiring/configuration ceremony, versus the additional structure a consistent DI approach would require.

**Alternative approaches**:
- FastAPI's own `Depends()`-based service injection, applied uniformly, not just for auth.
- A dedicated DI container library (e.g., `dependency-injector`).
- Factory functions registered on `app.state`, resolved per-request.

**Pros**: Minimal boilerplate; predictable single-instance-per-process behavior; fast to read and write for a small codebase and team; no framework lock-in beyond what FastAPI itself already requires.

**Cons**: No test-isolation seam â€” mocking a dependency requires monkeypatching the module directly rather than `app.dependency_overrides`; the true dependency graph is only visible via import statements, not function signatures, requiring a full-codebase read to understand (exactly the exercise this whole documentation series undertook); several singletons perform real I/O at import time (Ollama host resolution, Milvus client construction), creating startup fragility that a lazily-resolved dependency wouldn't have.

**Tradeoffs**: Development velocity and simplicity today, in direct exchange for testability and flexibility later â€” a classic, deliberately-or-not deferred cost.

**Why it fits this project**: Given the current test suite is a single file requiring live database connections rather than isolated unit tests, the lack of a DI seam has arguably not yet cost this specific team much in *practice* â€” though this is as much a symptom of the same underlying trade-off as a justification for it.

**When it would fail**: The moment meaningful unit-test coverage is needed (today, testing `engines/confidence_engine.py` in isolation, for instance, is actually already easy since it's a stateless pure-ish class â€” but testing anything touching `database.mongo.db` requires a real MongoDB, since there's no seam to substitute a fake). It also fails the moment multi-tenancy requires per-tenant-configured service instances (e.g., different regional Ollama endpoints), since a singleton assumes one global configuration for the entire process's lifetime.

**How FAANG engineers might improve it**: Introduce `Depends()`-based factory functions for every service behind a `Protocol`/interface, enabling `app.dependency_overrides` in tests without touching production code paths. Move every import-time I/O side effect (Ollama resolution, Milvus client construction) into a lazily-resolved, cached factory invoked on first actual use rather than at import â€” preserving today's "resolve once, reuse" performance characteristic while removing the "importing this file crashes the process" risk entirely.

**How to scale it to 1 million users**: DI becomes valuable specifically for expressing per-tenant or per-shard service configuration (routing different tenants to different regional database clusters or inference endpoints) and for enabling canary/feature-flagged service swaps (a new rule-engine version served to 1% of traffic) â€” neither of which a fixed global singleton can express without a substantial rewrite. Introducing the DI seam before this need arrives is materially cheaper than retrofitting it under scaling pressure.

---

## 8. Single Shared Static API Key

**What it is**: `core/security.py` checks every request against one hardcoded literal string, with no per-caller identity, revocation, or authorization model of any kind.

**Why this approach was chosen**: Almost certainly a placeholder for an early-stage/internal-testing phase â€” the literal value itself (`Vela_test_key_123`) names itself as a test artifact, and the codebase's config layer (`core/config.py`) already correctly declares a real `Vela_API_KEY` setting that was simply never wired into the check, suggesting this was intended to be temporary.

**Alternative approaches**:
- OAuth2/OIDC against a real identity provider (Auth0, Okta, Cognito, or an internal SSO).
- JWT with per-user claims and short expiry, issued via a login flow.
- A lighter intermediate step: per-client API keys in a lookup table, without a full identity-provider integration.

**Pros**: Trivial to implement and integrate for early testing â€” zero infrastructure (no token issuance service, no identity provider, no key-management system) required to unblock initial development.

**Cons**: No revocation without a code change and redeploy; no per-caller attribution or audit trail at all; no authorization whatsoever â€” every valid caller has identical, undifferentiated access to all data, and the configured `Vela_API_KEY` setting is completely inert.

**Tradeoffs**: Time-to-first-working-auth vs. every property a real production authentication system needs â€” revocability, attribution, least-privilege access, auditability.

**Why it fits this project**: It fits, narrowly, an internal-testing phase with no real user data at stake â€” which is explicitly this codebase's current, self-described status. It does not fit the broader system's own implied direction (per-user analytics, feedback attribution) at all, which already assumes a real identity model this auth mechanism can't provide.

**When it would fail**: Immediately and catastrophically upon exposure to real user financial data with more than one trusted caller â€” anyone holding the (source-code-visible) key has complete access to every user's data with no way to distinguish or limit them.

**How FAANG engineers might improve it**: A managed identity platform issuing short-lived, revocable tokens; an API gateway (Envoy, Kong, or a cloud provider's managed gateway) performing authentication *before* requests reach application code at all, so individual services don't each reimplement this concern; secrets stored and rotated via a vault (AWS Secrets Manager, HashiCorp Vault) rather than a `.env` file a developer edits by hand.

**How to scale it to 1 million users**: A real per-user identity and session/token issuance flow is a hard prerequisite â€” without it, there's no way to scope data access per user at all, making "1 million users" meaningless as a concept (today, all traffic is functionally one shared identity). Rate limiting would need to key on real user identity rather than IP address (already discussed as a related gap). An API gateway layer becomes essential for centralizing authentication/authorization logic that shouldn't be reimplemented per internal service as the system inevitably grows beyond one monolithic FastAPI app.

---

## 9. Async-First Architecture (FastAPI + Motor)

**What it is**: The entire application is built on `async`/`await`, using FastAPI and the async MongoDB driver (Motor), to handle many concurrent I/O-bound requests per process without one OS thread per request.

**Why this approach was chosen**: The workload â€” network calls to MongoDB, Milvus, and Ollama on nearly every request â€” is a natural fit for async concurrency, and FastAPI's modern ecosystem (automatic validation, OpenAPI generation) makes it an attractive default choice for a new Python API in this domain.

**Alternative approaches**:
- A synchronous framework (Flask/Django) with a process-or-thread-pool concurrency model (e.g., Gunicorn with sync workers).
- A different async framework (raw Starlette, aiohttp, Sanic).
- Synchronous PyMongo instead of the async Motor driver, accepting blocking I/O per request.

**Pros**: High I/O concurrency per process for a workload dominated by network waits; a modern, well-supported ecosystem; a strong natural fit for this codebase's most I/O-heavy endpoint (`/v1/explain`'s multi-service orchestration).

**Cons**: Async programming is genuinely easier to get subtly wrong â€” this codebase demonstrates it twice: a documented sequential-instead-of-concurrent bug in `rag/retriever.py` (missed opportunity, not a correctness bug), and a real, more serious bug in `database/milvus.py`, where a *blocking* `time.sleep` inside async startup code freezes the *entire* event loop, not just one request, for up to 15 seconds.

**Tradeoffs**: A higher I/O-concurrency ceiling than a thread-per-request model, in exchange for a much worse failure mode when a mistake (a single blocking call) is made â€” one bad line of code can stall every concurrent user, not just the request that triggered it.

**Why it fits this project**: The live endpoints are overwhelmingly I/O-bound (database and LLM calls dominate their latency), which is exactly the workload async excels at. It fits far less well for the system's CPU-bound phases (SHAP computation, UMAP/HDBSCAN clustering) â€” none of which are currently wired to a live request path, which is fortunate, since running them there would defeat the entire purpose of the async design.

**When it would fail**: The moment any genuinely CPU-bound work (feature extraction at real scale, SHAP, clustering) is triggered from within this same async process during a live request â€” it would block the event loop for the duration of that computation, stalling every other concurrent user, a categorically worse failure mode than the equivalent mistake in a thread-per-request architecture.

**How FAANG engineers might improve it**: Enforce a strict architectural boundary between I/O-bound work (stays in the async web tier) and CPU-bound work (moves to a dedicated worker pool or separate service, e.g., via Celery, Ray, or a dedicated batch-processing service) â€” never mixed in one process. Add static analysis/lint rules that specifically flag blocking calls (`time.sleep`, synchronous HTTP clients) inside `async def` functions, which would have caught the Milvus bug automatically in CI rather than requiring a manual documentation audit to surface it.

**How to scale it to 1 million users**: Run multiple Uvicorn worker processes (the current single-worker setup uses at most one CPU core, regardless of how many are available) behind a load balancer. Move every CPU-bound workload fully out of the request-serving process family entirely. Tune connection pool sizes for MongoDB/Milvus against real observed concurrency, rather than relying on untuned defaults, which is the current state.

---

## 10. No Caching Layer

**What it is**: There is no caching anywhere in this codebase â€” no `lru_cache`, no Redis, no HTTP caching headers â€” despite a comment in `core/security.py` aspirationally referencing Redis as a "production" mechanism that doesn't actually exist.

**Why this approach was chosen**: Most plausibly, this reflects "hasn't been needed yet" rather than a deliberate rejection of caching â€” at the scale this system has presumably been exercised at (implied single-user or small-scale testing), redundant computation costs are invisible enough not to have forced the issue.

**Alternative approaches**:
- In-process memoization (`functools.lru_cache`) for pure, input-deterministic functions like embedding generation.
- A shared Redis cache for anything that needs to be consistent across multiple processes (rate-limiter state, embeddings, short-TTL analytics results).
- HTTP-level caching (`ETag`/`Cache-Control` headers) for genuinely cacheable read endpoints.

**Pros of the current no-cache state**: Zero staleness risk anywhere in the system; the simplest possible mental model for correctness; no cache-invalidation bugs, widely regarded as one of the two genuinely hard problems in computer science.

**Cons**: Every repeated call to Ollama for identical or near-identical transaction text re-embeds from scratch via a real network call, even though embeddings are a pure function of their input and never change; every analytics aggregation recomputes from a full collection scan every time, even for identical, rapidly-repeated queries; the in-memory rate limiter's state (a de facto uncoordinated "cache" of request counts) can't be shared across replicas without a shared caching substrate regardless.

**Tradeoffs**: Correctness-by-always-being-fresh vs. cost and latency at any meaningful scale â€” always recomputing is the safest possible default, but it isn't free, especially for data that's provably immutable given its input.

**Why it fits this project**: At the implied current scale, this has cost nothing visible. It stops fitting the moment real traffic volume exists, since Ollama inference cost and latency then scale linearly with request volume with zero amortization of repeated work.

**When it would fail**: Immediately upon meaningful traffic growth â€” both in raw Ollama inference cost (a real, metered, or at least compute-constrained resource) and in database load for repeatedly-executed identical analytics queries. It also already effectively "fails" today in the specific, narrower sense that the rate limiter's state can't be shared across more than one process without exactly the caching infrastructure this decision has deferred.

**How FAANG engineers might improve it**: Introduce Redis as shared infrastructure serving three purposes simultaneously: rate-limiter state (fixing the horizontal-scaling gap), an embedding cache keyed by a content hash of the input text (a purely, permanently cacheable value with no invalidation complexity at all, since a given text's embedding never changes), and short-TTL caching for read-heavy analytics aggregations (where a few seconds of staleness is inconsequential). Monitor cache hit rate as a first-class operational metric from day one, not an afterthought.

**How to scale it to 1 million users**: Caching becomes mandatory infrastructure, not an optional optimization. A multi-tier design â€” in-process LRU for the hottest keys within a single process, Redis for cross-replica shared state, and potentially a CDN layer for any genuinely public, non-personalized response â€” would be needed to keep both Ollama inference cost and database load tractable. Given how common repeated transaction narration text is expected to be across a large user population ("UPI Swiggy" appears constantly across completely unrelated users), an embedding cache alone could plausibly eliminate a very large fraction of total LLM-related cost at this scale.

---

## 11. Self-Hosted Ollama Instead of a Hosted LLM API

**What it is**: Embeddings and generation both go through a self-hosted Ollama server (`core/ollama_client.py`) rather than a third-party hosted API (OpenAI, Anthropic, Cohere, etc.).

**Why this approach was chosen**: Likely a combination of data-sovereignty concerns (financial transaction text never leaves infrastructure the team controls), cost predictability at scale (no per-token metered billing to an external vendor), and avoiding vendor lock-in for a system whose core value proposition (grounded, explainable categorization) doesn't strictly require frontier-model capability.

**Alternative approaches**:
- A hosted API (OpenAI, Anthropic) for generation and/or embeddings, trading control for zero infrastructure burden and access to more capable models.
- A hybrid: self-hosted embeddings (cheap, high-volume, less capability-sensitive) with a hosted API for generation (lower volume, more capability-sensitive).
- A fully open-weights model run via a different serving stack (vLLM, TGI) instead of Ollama specifically.

**Pros**: Full control over data residency â€” meaningful for financial transaction text; no per-request metered cost to an external vendor, making cost more predictable (bounded by owned/rented compute, not usage-based billing); no dependency on a third party's uptime or API changes.

**Cons**: Self-hosted inference has a real compute ceiling (likely GPU-bound) that doesn't elastically scale the way a hosted API's shared infrastructure does; the current failover mechanism (`OLLAMA_HOSTS`) provides failover only, not load balancing (each process commits to one resolved host for its entire lifetime, per `core/ollama_client.py`'s design); running and maintaining inference infrastructure is a genuinely different operational skill set than running a typical web application.

**Tradeoffs**: Data control and predictable infrastructure cost vs. the operational burden of running inference infrastructure and a real, hard compute ceiling a hosted API's provider would otherwise absorb.

**Why it fits this project**: For a system whose stated design goal is explainability and hallucination-resistance rather than frontier reasoning capability, a well-chosen open-weights model served locally is plausibly sufficient â€” the RAG pipeline's strict grounding constraints do most of the quality-control work, reducing dependence on raw model capability.

**When it would fail**: The moment request volume exceeds what the self-hosted infrastructure can serve within acceptable latency â€” with no autoscaling, no load balancing across the configured host list (only failover), and no queueing/backpressure mechanism anywhere in this codebase, a load spike would simply produce slow or timed-out requests with no graceful degradation.

**How FAANG engineers might improve it**: Add genuine load balancing (not just failover) across multiple Ollama instances â€” round-robin or least-connections request routing, resolved per-request rather than once at process startup. Introduce request queuing with backpressure (reject or defer new requests gracefully under sustained overload, rather than letting every request degrade uniformly). Consider a tiered-model strategy: a smaller, faster model handling the common case, escalating to a larger one only when needed, to stretch fixed inference capacity further.

**How to scale it to 1 million users**: Self-hosted inference capacity becomes the single most likely hard scaling bottleneck in the entire system â€” GPU/compute capacity for embeddings and generation doesn't scale as elastically or cheaply as stateless web tiers or well-indexed databases do. At this scale, a serious capacity-planning exercise (measured throughput per inference node, expected request volume, target p99 latency) becomes essential, likely alongside the caching strategy from Decision 10 (which directly reduces the load this expensive tier needs to absorb) and a real load-balancing layer in front of a horizontally-scaled pool of inference nodes, rather than the current single-resolved-host-per-process model.

---

## 12. UMAP + HDBSCAN for Unsupervised Merchant Clustering

**What it is**: `clustering/umap_projection.py` and `hdbscan_cluster.py` reduce 768-dimensional merchant behavior embeddings to 5 dimensions via UMAP, then cluster them with HDBSCAN â€” a density-based algorithm that doesn't require specifying the number of clusters upfront and explicitly models outliers as "noise" rather than forcing them into a cluster.

**Why this approach was chosen**: The domain problem (discover natural groupings among merchants by behavior, with an unknown and evolving number of true groups, and a legitimate expectation that some merchants are genuinely idiosyncratic) is a strong theoretical fit for HDBSCAN specifically, over algorithms like k-means that require a pre-specified cluster count and force every point into some cluster.

**Alternative approaches**:
- K-means, with the cluster count chosen via a heuristic (elbow method, silhouette analysis) â€” simpler and faster, but forces every merchant into a cluster even if it doesn't really belong to one.
- Skip dimensionality reduction and cluster directly in the original 768-dimensional embedding space â€” theoretically possible but suffers badly from the curse of dimensionality for density-based methods specifically.
- A fully supervised approach â€” hand-label a training set of merchant categories and train a classifier instead of discovering clusters unsupervised.

**Pros**: HDBSCAN naturally handles an unknown, evolving number of clusters and explicitly represents "doesn't belong to any group" â€” both a good fit for a real-world set of merchants that will always include outliers; UMAP's dimensionality reduction makes density estimation tractable in a way it wouldn't be in the raw 768-dimensional space.

**Cons**: Both algorithms have hyperparameters (`n_neighbors`, `min_cluster_size`, `min_samples`) currently set to fixed, unvalidated defaults with no evidence of tuning against this system's actual data; UMAP's stochastic optimization process means results can vary subtly across library versions even with a fixed random seed; the entire pipeline is currently non-functional due to two independent, confirmed bugs, so none of this theoretical fit has ever actually been validated against real data.

**Tradeoffs**: Flexibility and outlier-awareness (HDBSCAN) vs. simplicity and speed (k-means) â€” a reasonable choice for exploratory, evolving cluster structure, at the cost of more hyperparameters to get right and less predictable, less easily-explained output than a fixed-k approach.

**Why it fits this project**: Merchant behavioral archetypes (subscription services, ride-hailing, food delivery, one-off retail) genuinely don't have a fixed, known-in-advance count, and forcing every merchant into a cluster (as k-means would) would misrepresent genuinely unique entities as belonging to a group they don't.

**When it would fail**: At small data volumes (the code's own `< 10` vectors guard acknowledges this) HDBSCAN can't find meaningful structure at all â€” and more importantly, as documented elsewhere, this entire pipeline currently cannot run due to a nonexistent scikit-learn function name and a nonexistent attribute reference, meaning its theoretical fit for the problem has never actually been tested against this system's real data.

**How FAANG engineers might improve it**: Fix the two blocking bugs first (an unavoidable prerequisite to any further improvement), then run a genuine hyperparameter search (`min_cluster_size`, `min_samples`, `n_neighbors`) validated against the silhouette score and Davies-Bouldin index the code already computes but has never actually been able to use, since the pipeline can't run. Add a labeled validation set (even a small, manually-curated one) to measure whether discovered clusters actually correspond to meaningful real-world merchant categories, not just statistically dense groupings. Version and track clustering runs (which hyperparameters, which data snapshot, which resulting metrics) the way a real ML team tracks any model training run.

**How to scale it to 1 million users**: UMAP and HDBSCAN are both batch algorithms not designed for real-time, per-request use â€” they need to run as periodic, scheduled batch jobs against the full merchant embedding population, likely on dedicated compute (not the same process serving live requests, tying back to Decision 9's I/O/CPU separation principle). At 1M users' worth of merchant behavior data, this batch job itself would need to scale (UMAP's construction of a nearest-neighbor graph is expensive for very large point counts) â€” likely via approximate methods, sampling, or a distributed implementation, rather than the current single-process, full-dataset approach.

---

## 13. Pure-Function Feature Extraction Layer

**What it is**: `features/amount_features.py`, `temporal_features.py`, `frequency_features.py`, and `periodicity.py` are all stateless, side-effect-free functions computing statistical summaries from raw amount/timestamp lists â€” no I/O, no shared state, orchestrated by a single caller (`behaviour/behavior_engine.py`).

**Why this approach was chosen**: Almost certainly a deliberate application of functional-core/imperative-shell design â€” isolating the actual mathematical logic from I/O concerns makes it trivially testable and easy to reason about in isolation, even though (as documented) no tests currently exist for these functions.

**Alternative approaches**:
- Bake the statistical computation directly into `behaviour/behavior_engine.py` as inline logic, rather than extracting separate, reusable functions.
- Use a heavier-weight feature-engineering framework (e.g., Featuretools) instead of hand-rolled functions.
- Compute these statistics as a database-side aggregation (MongoDB aggregation pipeline `$stdDevPop`, etc.) rather than pulling raw data into Python.

**Pros**: Trivially unit-testable in isolation with zero mocking required (a real design strength, even unrealized by an actual test suite today); easy to reason about correctness by inspection alone, which is exactly how the correctness of these specific functions was verified throughout this documentation effort; reusable independently of the one current caller, if a future feature needed the same statistics computed differently.

**Cons**: A real, if currently latent, bug exists specifically because of an inconsistency at the *edges* of this purity â€” the empty-input branches of two of these functions return differently-named dictionary keys than their normal-path branches, a mismatch that's only currently masked by the one caller's own defensive guard.

**Tradeoffs**: The purity that makes these functions easy to verify in isolation doesn't automatically extend to verifying *contract consistency* between a function's different branches â€” purity is necessary but not sufficient for correctness.

**Why it fits this project**: The underlying math (mean, variance, entropy, periodicity via coefficient of variation) is genuinely stable, well-understood, and unlikely to need the flexibility a heavier framework would provide â€” hand-rolled, purpose-built functions are the right level of abstraction for a fixed, known set of statistical computations.

**When it would fail**: The exact scenario already identified: any future caller of these functions that doesn't replicate `behaviour/behavior_engine.py`'s specific empty-input guard would hit a `KeyError` immediately, since the pure functions' own internal contract isn't self-consistent across their branches.

**How FAANG engineers might improve it**: Add the missing unit tests these functions were clearly designed to make trivial â€” a small, high-value investment given the near-zero mocking cost. Fix the branch-inconsistency bug and add a contract test asserting all branches of a given function always return the same key set. Consider migrating the actual numerical computation to a vectorized library (`numpy`/`pandas`) for both a performance improvement at larger transaction-list sizes and a reduction in hand-written arithmetic that could itself harbor subtle bugs.

**How to scale it to 1 million users**: The functions themselves are already cheap and don't need architectural change to scale â€” the actual scaling concern is upstream, in `behaviour/behavior_engine.py`'s unbounded, full-history fetch per merchant profiling run (already documented as a bottleneck). At 1M users' worth of transaction volume, this would need to move to incremental computation (updating running statistics as new transactions arrive, rather than recomputing from complete history every time) â€” a genuinely different algorithmic approach for amount/frequency statistics (maintaining running sums/counts) than the current from-scratch batch computation, though periodicity and entropy calculations would need more careful incremental redesign, since they aren't naturally expressible as simple running aggregates.

---

## Cross-Cutting Observation

A pattern worth naming explicitly, visible across all 13 decisions above: **this codebase consistently makes reasonable, defensible architectural choices for its stated domain problem, but consistently under-invests in the operational maturity (monitoring, testing, calibration, consistency guarantees) needed to validate that those choices are actually working as intended.** The confidence wall's threshold has never been calibrated against real outcomes. The clustering pipeline's algorithmic fit has never been tested because it can't currently run. The dual-database architecture's consistency was never actually implemented. This is not a criticism of any individual decision in isolation â€” it's the single most useful thing a FAANG-caliber review would tell this team: the *decisions* are largely sound; the *follow-through* is where the gap consistently lies.

## Related documents
[08 Â· Design Decisions (interview questions)](./interview/08-design-decisions.md) for a Q&A-format companion covering many of these same decisions from an interview-preparation angle, [17 Â· Senior Architect Review](./17-senior-architect-review.md) and [18 Â· Database Analysis](./18-database-analysis.md) for the implementation-level detail underlying the analysis above.

