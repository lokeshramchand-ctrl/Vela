# 01 Â· Architecture

## 1.1 Overview

Vela is a single FastAPI service (`app.py`) that fronts two datastores (MongoDB, Milvus) and one external inference server (Ollama). It is **not** a microservice mesh â€” every router, engine, and ML component documented here runs in the same Python process, in the same container. There is no message queue, no Celery worker, and no separate training service actually wired up in this codebase, despite comments referencing them (see [16 Â· Known Issues](./16-known-issues-tech-debt.md)).

The codebase is organized as a linear sequence of "Phases," visible directly in source comments. Each phase builds on data produced by the previous one:

```mermaid
flowchart TD
    P0["Phase 0<br/>Health & Bootstrap"] --> P1
    P1["Phases 1-3<br/>Ingestion, Rules, Resolution"] --> P4
    P4["Phase 4<br/>Memory State Machine"] --> P5
    P5["Phase 5<br/>Confidence Wall"] --> P6
    P6["Phase 6<br/>Behavioral Feature Extraction"] --> P7
    P7["Phase 7<br/>Embeddings + Vector Search"] --> P8
    P8["Phase 8<br/>UMAP + HDBSCAN Clustering"] --> P9
    P9["Phase 9<br/>Baseline ML Training"] --> P10
    P10["Phase 10<br/>Feedback + Active Learning"] --> P11
    P11["Phase 11<br/>LoRA Fine-Tuning"] --> P12
    P12["Phase 12<br/>RAG Explainability"] --> P13
    P13["Phase 13<br/>Analytics Engine"] --> P14
    P14["Phase 14<br/>Observability / MLOps"] --> P15
    P15["Phase 15<br/>API Key Security"]
```

Only a subset of these phases are reachable over HTTP today. The rest exist as importable Python modules intended to be invoked by scripts, cron jobs, or a future orchestrator (Celery is referenced in comments but is not a dependency of this codebase, and no scheduler is wired up).

## 1.2 Process topology

```mermaid
flowchart LR
    subgraph Container["Vela-backend container (Dockerfile)"]
        APP["Uvicorn / FastAPI app.py"]
    end
    subgraph Data["Datastores"]
        Mongo[("MongoDB 6.0<br/>(docker-compose_local.yaml)")]
        Milvus[("Milvus<br/>external, MILVUS_URI")]
    end
    subgraph Inference["Inference"]
        Ollama[["Ollama server(s)<br/>OLLAMA_URI / OLLAMA_HOSTS"]]
    end

    Client(["API Consumer"]) -- "HTTPS + X-Vela-API-Key" --> APP
    APP -- "Motor (async)" --> Mongo
    APP -- "MilvusClient" --> Milvus
    APP -- "httpx (async)" --> Ollama
    Prometheus(["Prometheus scraper"]) -- "GET /metrics" --> APP
```

`app.py`'s `lifespan` context manager is the composition root: on startup it calls `db.connect(...)` (`database/mongo.py`), then `vector_db.connect(...)` (`database/milvus.py`), then `vector_store.ensure_collections()` (`milvus/insert_vectors.py`); on shutdown it calls the corresponding `disconnect()` methods. `db` and `vector_db` are process-wide singletons (class-level attributes on `MongoDB` and `VectorDB`), so there is exactly one Mongo client and one Milvus client per process, shared by every request via plain module import (`from database.mongo import db`), not FastAPI dependency injection.

âœ… **FIXED** â€” `milvus/insert_vectors.py`'s `VectorStoreManager` previously constructed its **own** independent `MilvusClient` at import time, reading `MILVUS_URI` directly from `os.getenv` rather than `core.config.settings`, giving the process two separate, differently-configured Milvus connections. `VectorStoreManager` no longer opens a connection itself â€” its `client` property now delegates to `vector_db.client`, the single lifespan-managed connection, and `ensure_collections()` (called once from `lifespan`, after `vector_db.connect()`) replaces the old eager-connect-at-import behavior. This also closed a real startup-stability gap: the old code made a blocking network call with no retry the moment any module importing it was loaded (e.g. via `routers.rag`), so a briefly-unreachable Milvus used to crash the whole app at import time, not just the vector-search feature. See [16 Â· Known Issues Â§16.3](./16-known-issues-tech-debt.md#163-medium-previously-disconnected-features-dead-code-silent-no-ops--fixed).

## 1.3 Request flow â€” application startup

```mermaid
sequenceDiagram
    participant OS as Process Start
    participant App as FastAPI (app.py)
    participant Mongo as database.mongo.db
    participant Milvus as database.milvus.vector_db
    participant Prom as Instrumentator

    OS->>App: import app.py
    App->>App: configure logging (DEBUG level)
    App->>App: setup_rate_limiting(app)
    App->>Prom: Instrumentator().instrument(app).expose(app, "/metrics")
    App->>App: include_router(v1, memory, analytics, rag, observability)
    Note over App: lifespan() begins
    App->>Mongo: db.connect(MONGODB_URI, MONGODB_DB_NAME)
    Mongo-->>App: collections bound (transactions, feedback, categories, merchants, merchant_profiles, behavior_patterns, retraining_queue)
    App->>Milvus: vector_db.connect(MILVUS_URI)
    Milvus-->>App: MilvusClient created (retries up to 5x, 3s delay)
    App->>App: yield (ready to serve)
```

## 1.4 Request flow â€” `/v1/categorize` (rule-based categorization)

This is the primary ingestion endpoint. âœ… Previously it raised an exception on every call (documented in [16 Â· Known Issues](./16-known-issues-tech-debt.md#161-critical-previously-broke-the-application-or-a-whole-feature--all-fixed)) â€” that's fixed; the flow below reflects the current, working code.

```mermaid
sequenceDiagram
    participant C as Client
    participant R as routers/v1.py
    participant RE as engines.rule_engine
    participant Mongo as database.mongo.db

    C->>R: POST /v1/categorize {"text": "..."}
    R->>R: start_time = time.time()
    R->>RE: rule_engine.categorize(payload.text)
    RE-->>R: {merchant, category, confidence}
    R->>R: text_content = payload.text
    R->>Mongo: db.transactions.insert_one({..., "merchant": result["merchant"], "category": result["category"], "confidence": result["confidence"]})
    Mongo-->>R: inserted_id
    R-->>C: {merchant, category, confidence, transaction_id}
```

`RuleEngine.categorize` itself (`engines/rule_engine.py`) is a clean, deterministic implementation:

1. On startup, loads `merchant_aliases.json` into memory and pre-compiles a `\b<alias>\b` case-insensitive regex per alias.
2. `categorize(text)` scans compiled patterns in dict-insertion order and returns the **first** alias match with `confidence: 0.95`.
3. No match â†’ `{"merchant": "Unknown", "category": "Uncategorized", "confidence": 0.0}`.

## 1.5 Request flow â€” `/v1/resolve` (merchant resolution)

This is the working, well-formed counterpart to `/v1/categorize` for noisy bank/UPI text.

```mermaid
sequenceDiagram
    participant C as Client
    participant R as routers/v1.py
    participant MR as services.merchant_resolver
    participant Mongo as MongoDB (merchants collection)

    C->>R: POST /v1/resolve {"text": "UPI/CR/.../BUNDL TECHNOLOGIES/HDFC"}
    R->>MR: merchant_resolver.resolve(text)
    MR->>MR: clean_text(): strip UPI/IMPS/NEFT/RTGS/INB noise, 12-digit ref#s, UPI handles, special chars
    MR->>Mongo: find_one({aliases: cleaned_text})  (exact match)
    alt exact alias hit
        Mongo-->>MR: {canonical_name: "Swiggy", ...}
        MR-->>R: ResolutionResult(confidence=0.99, method="exact_alias")
    else no exact hit
        loop each word (len >= 4) in cleaned text
            MR->>Mongo: find_one({aliases: {$regex: "^WORD", $options: "i"}})
        end
        alt substring hit
            MR-->>R: ResolutionResult(confidence=0.75, method="substring")
        else no hit
            MR-->>R: ResolutionResult(canonical_merchant="Unknown", confidence=0.0, method="none")
        end
    end
    R-->>C: ResolutionResult JSON
```

## 1.6 Request flow â€” `/v1/explain` (RAG explainability)

```mermaid
sequenceDiagram
    participant C as Client
    participant R as routers/rag.py
    participant Retr as rag.retriever
    participant VS as milvus.search_vectors
    participant Emb as embeddings.generate_embeddings
    participant Mongo as MongoDB
    participant CB as rag.context_builder
    participant Gen as rag.generator
    participant Ollama as Ollama /api/generate

    C->>R: POST /v1/explain {transaction_text, target_question}
    R->>Retr: fetch_grounded_context(transaction_text)
    Retr->>Emb: generate(transaction_text) -> query_vector
    Emb->>Ollama: POST /api/embeddings {model: EMBED_MODEL, prompt}
    Ollama-->>Emb: embedding vector
    Retr->>VS: find_similar_behaviors(transaction_text, top_k=3)
    VS-->>Retr: [{merchant_name, similarity_score, id}, ...]
    loop each matched merchant
        Retr->>Mongo: merchant_profiles.find_one(canonical_name)
        Retr->>Mongo: behavior_patterns.find_one(merchant_name)
        Retr->>Mongo: feedback.find({prediction: name}).sort(-1).limit(3)
    end
    Retr-->>R: context_payloads[]
    R->>CB: build_prompt_string(context_payloads)
    CB-->>R: XML-tagged <MERCHANT_DATA> prompt block
    R->>Gen: generate_explanation(query, context_string)
    Gen->>Ollama: POST /api/generate {system, prompt, format:"json"}
    Ollama-->>Gen: {"response": "<json string>"}
    Gen-->>R: parsed JSON {explanation, confidence_in_explanation, primary_data_source}
    R-->>C: {query, retrieved_documents, result}
```

If Milvus returns zero hits, `fetch_grounded_context` returns `[]`, `build_prompt_string` returns the literal string `"NO_CONTEXT_AVAILABLE"`, and `generate_explanation` short-circuits with `{"error": "No historical behavior found to explain this transaction."}` **without calling Ollama** â€” this is the system's core hallucination-prevention guarantee.

## 1.7 Request flow â€” `/memory/update` (state machine)

```mermaid
sequenceDiagram
    participant C as Client
    participant R as routers/memory.py
    participant MM as memory.memory_manager
    participant Repo as repositories.profile_repository
    participant SM as memory.state_machine
    participant Mongo as MongoDB (merchant_profiles)

    C->>R: POST /memory/update {canonical_name, raw_text}
    R->>MM: process_encounter(canonical_name, raw_text)
    MM->>Repo: get_profile(canonical_name)
    alt profile not found
        MM->>MM: new MerchantProfile(frequency=1, state=EPHEMERAL)
        MM->>Repo: create_profile(profile)
        Repo->>Mongo: insert_one(profile)
    else profile found
        MM->>MM: frequency += 1, last_seen = now, append alias if new
        MM->>SM: evaluate_promotion(profile)
        SM-->>MM: new_state (EPHEMERAL/TEMPORARY/PERMANENT, sticky at PERMANENT/ARCHIVED)
        MM->>MM: if was ARCHIVED -> wake to TEMPORARY, else apply new_state
        MM->>Repo: update_profile(profile)
        Repo->>Mongo: update_one({canonical_name}, {$set: ...})
    end
    MM-->>R: MerchantProfile
    R-->>C: MerchantProfile JSON
```

State thresholds (`memory/state_machine.py`): `frequency >= 10` â†’ `PERMANENT`; `frequency >= 3` â†’ `TEMPORARY`; otherwise `EPHEMERAL`. `PERMANENT` and `ARCHIVED` are treated as non-demotable by `evaluate_promotion`, but `MemoryManager.process_encounter` explicitly overrides an `ARCHIVED` profile back to `TEMPORARY` on any new encounter (bypassing `evaluate_promotion`'s own state machine for that one transition).

## 1.8 Security & rate limiting

- **Auth â€” two independent layers**: every router except `/health`, `/live`, `/ready`, and `/metrics` is mounted with `dependencies=[Depends(validate_api_key)]` in `app.py`, unchanged from before. `validate_api_key` (`core/security.py`) checks the `X-Vela-API-Key` header against `settings.Vela_API_KEY` â€” this authenticates the *calling application* (the one trusted client consuming this backend), not an individual end user.

  A second, independent layer authenticates the *end user* within that application boundary: `core/jwt_auth.py::get_current_user` validates a `Authorization: Bearer <JWT>` access token and resolves it to a `User` document. Unlike the API key (attached once per router via `dependencies=[...]`), this is bound explicitly as a handler parameter â€” `current_user: User = Depends(get_current_user)` â€” only on the specific endpoints that need to know *which* user is calling: `POST /auth/me`/`/auth/logout` implicitly via the token, `POST /v1/categorize`, every `GET /v1/analytics/*`, and `POST /v1/feedback/`. Endpoints that operate on data that isn't scoped to one user (`/v1/resolve`, `/v1/confidence/evaluate`, `/v1/explain`, `/memory/*`, `/v1/pipelines/*`, `/v1/observability/*`, `/v1/analytics/anomaly/check`) stay API-key-only, exactly as before.

  The two layers compose independently and are both enforced whenever both are declared: the router-level API-key dependency runs regardless of what any individual handler additionally requires, so a genuine JWT presented without the API key is rejected before a handler runs, and a valid API key alone is not sufficient on a JWT-protected handler. See [22 Â· Authentication](./22-authentication.md) for the full endpoint-by-endpoint breakdown, token lifecycle, and password/refresh-token storage design.

- **Rate limiting**: SlowAPI (`core/rate_limiter.py`) applies a global default of `1000/day` and `100/minute` per client IP (`get_remote_address`). `POST /v1/categorize` additionally declares `@limiter.limit("50/minute")`. `POST /auth/register`, `/auth/login`, and `/auth/refresh`/`/auth/logout` declare their own tighter limits (`5/minute`, `10/minute`, `20/minute` respectively) â€” see [22 Â· Authentication Â§22.6](./22-authentication.md#226-rate-limiting).
- **Metrics**: `prometheus_fastapi_instrumentator` auto-instruments every route and exposes `GET /metrics` with no auth dependency.

## 1.9 Batch pipelines â€” now reachable via `/v1/pipelines/*`

The following modules are fully implemented but have no natural scheduler in this repo (no Celery/cron exists here). Rather than leaving them reachable only via direct import/script invocation, each is now exposed as a manually-triggered endpoint under `routers/pipelines.py` (mounted at `/v1/pipelines`, same auth as every other router) â€” see [02 Â· API Reference Â§2.13](./02-api-reference.md#213-batch-pipelines-routerspipelinespy-prefix-v1pipelines) for full request/response detail:

| Module | Singleton | Reachable via |
|---|---|---|
| `behaviour/behavior_engine.py` | `behavior_engine` | `POST /v1/pipelines/behavior/run`, `/run-all` |
| `clustering/cluster_engine.py` | `cluster_engine` | `POST /v1/pipelines/clustering/run` (imported lazily so a missing `umap-learn`/`scikit-learn` install only breaks this endpoint) |
| `memory/decay_engine.py` | `decay_engine` | `POST /v1/pipelines/decay/sweep` |
| `graphs/graph_builder.py` | `graph_engine` | `POST /v1/pipelines/graph/build`, `GET /v1/pipelines/graph/neighborhood/{name}` |
| `embeddings/*` + `milvus/insert_vectors.py` | n/a | `POST /v1/pipelines/embeddings/sync` |
| `feedback/api_router.py` | `router` | Mounted in `app.py`; reachable at `/v1/feedback/` |
| `training/train.py` | `BaselineTrainer` (script entry point only) | Manual `python training/train.py` â€” intentionally not exposed as an endpoint; see below |
| `training/finetune.py` | `FinetuneEngine` (script entry point only) | Manual `python training/finetune.py` â€” intentionally not exposed as an endpoint; see below |

`training/*` are deliberately **not** wired to an endpoint: both currently train on synthetic/mock data rather than real feedback, and `BaselineTrainer.run_benchmarks()` is a long-running, CPU-heavy synchronous job that would block the event loop if called from a request handler. Exposing either as-is would look "fixed" while actually being misleading â€” see [16 Â· Known Issues Â§16.5](./16-known-issues-tech-debt.md#165-whats-intentionally-still-open-productinfra-decisions-not-bugs).

Operationally: in a fresh environment, run `POST /v1/pipelines/behavior/run-all` before expecting real results from `/v1/analytics/subscriptions` or `/v1/analytics/anomaly/check`, and run it followed by `POST /v1/pipelines/embeddings/sync` before expecting `/v1/explain` to retrieve real grounded context. Nothing runs these automatically yet â€” that requires a scheduler, which is a separate infra decision.

## 1.10 Request flow â€” `POST /statements/upload` (Google Pay statement ingestion)

The primary product surface: `Statement â†’ Transactions â†’ Analytics â†’ AI Insights`, sourced from a Google Pay PDF statement rather than one-at-a-time raw text. Full detail â€” the real statement format, the processing pipeline, and how it reuses `rule_engine`, `behavior_engine`, embeddings/Milvus, and the Ollama-calling convention â€” is in [23 Â· Statement Ingestion Pipeline](./23-statements-pipeline.md).

```mermaid
sequenceDiagram
    participant C as Client
    participant R as routers/statements.py
    participant P as statements/pdf_parser.py
    participant BG as BackgroundTasks
    participant S as statements/statement_service.py

    C->>R: POST /statements/upload (file, password?)
    R->>P: validate (structure, signature, decrypt) - synchronous, fails fast with 422
    R->>R: create Statement(PENDING) + Job(QUEUED)
    R-->>C: 202 {statement_id, job_id}
    R->>BG: add_task(process_statement, ...)
    BG->>S: parse -> categorize -> persist -> profile -> embed -> analyze -> generate insights -> COMPLETED
```

Job execution is in-process (`fastapi.BackgroundTasks`), consistent with Â§1.9's "no scheduler/Celery exists in this repo" - the client-facing contract (`GET /jobs/{id}` polling) is identical regardless of what actually executes the job, so a real task queue could replace this later with zero API change.

