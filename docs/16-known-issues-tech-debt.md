# 16 Â· Known Issues & Tech Debt

This document previously consolidated every concrete defect, inconsistency, and gap identified while reading the implementation. As of this update, **every item in Â§16.1 (Critical), Â§16.2 (High), and essentially all of Â§16.3/Â§16.4 has been fixed and verified** (full test suite green, every module import-checked, and the fixes exercised end-to-end against a real MongoDB instance). Each entry below is kept for history, marked with its resolution, and cites the fix. A small number of items are intentionally left as documented, not-yet-built features rather than "fixed" â€” those are called out explicitly in Â§16.5.

## 16.1 Critical (previously broke the application or a whole feature) â€” ALL FIXED

### âœ… FIXED â€” `profile_repository.py` missing import
**File**: `repositories/profile_repository.py`
Added `from typing import Optional`. This was the proximate cause of the app failing to import at all (`app.py` â†’ `routers.memory` â†’ `memory.memory_manager` â†’ `repositories.profile_repository` â†’ crash). Verified: `import app` now succeeds cleanly.

### âœ… FIXED â€” `requirements.txt` is not the app's dependency list
**Files**: `requirements.txt`, `requirements-linux.txt`
Both files are replaced with the actual runtime dependency list (`fastapi`, `uvicorn`, `motor`, `pymilvus`, `slowapi`, `httpx`, `pydantic-settings`, `prometheus-fastapi-instrumentator`, `scikit-learn`, `umap-learn`, `networkx`, `pandas`, `numpy`, `lightgbm`, `xgboost`, `shap`, `tabulate`, and the fine-tuning stack `torch`/`transformers`/`peft`/`datasets`), pinned to specific versions. `pip install -r requirements.txt` now installs everything `app.py`'s import graph needs.

### âœ… FIXED â€” `/v1/categorize` is broken
**File**: `routers/v1.py`
Fixed all three bugs in the same block: the pydantic body parameter is read via `payload.text` (not `.get()`), the timestamp uses `datetime.now(timezone.utc)` (not `time.timezone.utc`), and the Mongo insert now writes the actual resolved values (`result["merchant"]`, `result["category"]`, `result["confidence"]`) instead of module/function objects. The endpoint also now returns the inserted `transaction_id`, which `/v1/feedback/` needs to join feedback back to a merchant (see the `feedback.prediction` fix below). Verified end-to-end with a real MongoDB instance and covered by `test_categorize_valid_payload`.

### âœ… FIXED â€” `davies_bouldin_index` does not exist in scikit-learn
**File**: `clustering/cluster_engine.py`
Renamed the import and call site to `davies_bouldin_score`.

**Also fixed â€” the masked second bug in the same function**: `run_discovery_pipeline` now calls `vector_store.client.query(collection_name=..., filter=..., output_fields=...)` instead of the nonexistent `vector_store.behavior_collection.query(...)`. Verified importable with `umap-learn` + `scikit-learn` installed.

## 16.2 High (previously security / correctness with real user impact) â€” ALL FIXED

### âœ… FIXED â€” Hardcoded API key, config setting unused
**File**: `core/security.py`
`validate_api_key` now compares against `settings.Vela_API_KEY` instead of the literal `"Vela_test_key_123"`. Rotating `Vela_API_KEY` in `.env`/deployment config now actually takes effect.

### âœ… FIXED â€” Plaintext credential committed in `docker-compose_production.yaml`
**File**: `docker-compose_production.yaml`
The inline Mongo connection string is replaced with `${MONGODB_URI:?...}`-style variable substitution sourced from a compose `.env` file or the host/CI secret store â€” no credential is committed in this file going forward.
**Action still required from the repo owner** (cannot be done from inside this environment): the previously-committed credential (`lokesh:Lokesh%401234@...`) is in git history and must be treated as compromised â€” rotate it on the actual MongoDB server/hosting provider.

### âœ… FIXED â€” Category vocabulary mismatch
**File**: `models/schemas.py`
`TransactionCategory` now includes `Subscription`, `Shopping`, and `Utility` alongside the original members, matching what `merchant_aliases.json` and `scripts/mock_seeder.py` actually produce. `ConfidenceEngine.evaluate()` no longer force-rejects these to `Unknown`.

### âœ… FIXED â€” Month-over-month trend is mocked
**File**: `analytics/trends.py`
`prev_total` is now a real aggregation query against the previous calendar month (not a hardcoded â‚¹15,000). Also fixed an adjacent bug found while correcting this: the "current month" query previously had no upper date bound and would sum every transaction from the 1st of the month onward *forever*, not just within that month.

### âœ… FIXED â€” `feedback.prediction` field holds a category, not a merchant name
**Files**: `feedback/feedback_service.py`, `rag/retriever.py`, `graphs/graph_builder.py`, `models/schemas.py`
`process_feedback` now looks up the source transaction (via the `transaction_id` returned by `/v1/categorize`) and writes a real `merchant_name` field. `rag/retriever.py` and `graphs/graph_builder.py` now query/match on `merchant_name` instead of `prediction`. `Feedback` schema updated to include `merchant_name`, `is_correction`, and `user_id` â€” the fields actually written. Verified end-to-end: a categorize â†’ feedback round-trip correctly stores `"merchant_name": "Swiggy"`.

## 16.3 Medium (previously disconnected features, dead code, silent no-ops) â€” FIXED

### âœ… FIXED â€” Feedback router not mounted
**Files**: `feedback/api_router.py`, `app.py`
`feedback.router` is now imported and mounted in `app.py` behind the same `validate_api_key` dependency as every other router. `POST /v1/feedback/` is reachable and covered by `test_feedback_triggers_retraining_queue`.

### âœ… FIXED â€” Duplicate `/v1/categorize` route
**File**: `app.py`
The dead inline stub (`public_categorize`) is removed. Its intended tighter rate limit (`50/minute`) was moved onto the real handler in `routers/v1.py` (see below) instead of being lost.

### âœ… FIXED â€” Duplicate/inconsistent Milvus clients
**Files**: `database/milvus.py`, `milvus/insert_vectors.py`
`VectorStoreManager` (`milvus/insert_vectors.py`) no longer creates its own `MilvusClient` or connects at import time. It now delegates to the single client owned by `database.milvus.vector_db` (the one connected/disconnected via the app `lifespan`), via a `client` property. A new `ensure_collections()` method (called once from `lifespan`, after `vector_db.connect()`) replaces the old eager-connect-at-import behavior. This also fixes a real, previously-undocumented stability bug: importing `milvus/insert_vectors.py` used to make a **blocking network connection attempt at module-import time**, with no retry â€” if Milvus was briefly unreachable when any module importing it (transitively, e.g. `routers.rag`) was first loaded, the entire app would fail to start with an unhandled `MilvusException`, not just the vector-search feature.

### âœ… FIXED â€” Rate limit override was unreachable
**File**: `routers/v1.py`
The `@limiter.limit("50/minute")` decorator now lives on the real `/v1/categorize` handler (the pydantic body parameter was renamed from `request` to `payload` so a real `Request` object could be bound to the name SlowAPI requires). Verified: 55 rapid calls now return `429` once the limit is hit.

### âœ… FIXED â€” Previously undocumented: eager Ollama host resolution at import time
**File**: `core/ollama_client.py`, `rag/generator.py`, `embeddings/generate_embeddings.py`
Same class of bug as the Milvus one above, found while fixing it: if `OLLAMA_URI` isn't set and `OLLAMA_HOSTS` is used instead, `resolve_ollama_host()` made a synchronous health-check network call **at import time**, raising `RuntimeError` (crashing the whole app) if every host happened to be briefly unreachable at startup. Host resolution is now deferred to first actual use via `get_ollama_host()`, so a temporarily-unreachable Ollama fleet only degrades RAG/embedding endpoints, not the whole app.

### Newly reachable (previously orphaned) pipelines â€” addressed via manual-trigger endpoints
**New file**: `routers/pipelines.py` (mounted at `/v1/pipelines`, same auth as every other router)
Behavior profiling, the embedding-write pipeline, the decay sweep, and the knowledge graph builder were fully implemented but had zero callers anywhere in the repo (Â§16.3 previously listed these as four separate "never runs automatically" issues). None of these have a natural home yet (no Celery/cron scheduler exists in this repo), so rather than inventing scheduling infrastructure, each is now exposed as a manually-triggerable endpoint:
- `POST /v1/pipelines/behavior/run` / `run-all` â€” Phase 6 behavior profiling
- `POST /v1/pipelines/embeddings/sync` â€” Phase 7 embedding generation + Milvus write
- `POST /v1/pipelines/decay/sweep` â€” Phase 4 180-day archival sweep
- `POST /v1/pipelines/graph/build` + `GET /v1/pipelines/graph/neighborhood/{merchant_name}` â€” Phase 13 knowledge graph
- `POST /v1/pipelines/clustering/run` â€” Phase 8 clustering (imported lazily inside the handler so a broken/missing `umap-learn`/`scikit-learn` install only breaks this one endpoint, not app startup)

All five were exercised end-to-end against a real MongoDB in verification (behavior/run-all, graph/build, and decay/sweep all returned 200 with correct results; embeddings/sync and clustering/run were verified to fail gracefully â€” 503 / empty result â€” when Milvus isn't reachable, rather than crashing).

**Still requires a product decision, not fixed here:** actually scheduling these on a cron/Celery beat so they run automatically without a manual API call. That's an infrastructure choice for whoever operates this, not a bug fix â€” see Â§16.5.

### âœ… Addressed â€” `docker-compose_production.yaml` env var names vs. `core/config.py`
Compose now sets `MONGODB_URI`/`MONGODB_DB_NAME`/`MILVUS_URI`/`OLLAMA_URI`/`OLLAMA_HOSTS`/`EMBED_MODEL`/`LLM_MODEL`/`Vela_API_KEY` â€” matching `Settings` exactly â€” sourced via `${VAR:?required}` substitution instead of hardcoded/wrong-named values.

### Not changed â€” `README.md` vs. `docker-compose_local.yaml` Milvus/Ollama gap
This was re-checked and found to already be accurately documented (the README explicitly notes the local compose file only provisions MongoDB and that Milvus/Ollama must be run separately) â€” no code or doc change was needed here, it was already honest.

## 16.4 Low (previously latent bugs, unused/mismatched code, cosmetic) â€” FIXED

- âœ… **Feature-extractor empty-input key mismatch** (`features/amount_features.py`, `features/temporal_features.py`) â€” empty-input branches now return the same key names as the normal path (`avg_amount`/`median_amount`/`entropy_score`, `time_bucket_distribution`/`weekday_distribution`).
- âœ… **Schema/document drift** (`models/schemas.py`) â€” removed the fully-unused `Merchant` and `Category` model classes (zero readers/writers anywhere in the codebase); `Transaction` now has `user_id`/`is_mock` (what's actually written) instead of an unused required `source` field; `Feedback` now has `merchant_name`/`is_correction`/`user_id`.
- âœ… **`resolution_method: "rule_engine"` documented but never produced** â€” docstring in `models/schemas.py` corrected to `"exact_alias, substring, or none"`, matching what `services/merchant_resolver.py` actually emits.
- âœ… **`XGBClassifier(use_label_encoder=False)`** â€” removed; this argument was deprecated and removed in modern XGBoost.
- âœ… **`to_markdown()` requires `tabulate`** â€” added to `requirements.txt`.
- âœ… **`TrainingArguments(evaluation_strategy=...)`** (found while touching `training/finetune.py`, not previously documented) â€” renamed to `eval_strategy`, matching the argument name in the pinned `transformers==4.47.1`.

## 16.5 What's intentionally still open (product/infra decisions, not bugs)

These were flagged in earlier versions of this document as "medium" gaps but are genuinely feature work requiring an infrastructure decision (a task queue, an ML observability platform), not something safely faked in a bug-fixing pass:

- **Retraining queue has no executor.** `feedback/retraining_queue.py::trigger_retraining_if_needed` still flips queued records to `"processing"` and stops (`# TODO: Launch BaselineTrainer().run_benchmarks() via Celery`). Wiring this up for real requires a task queue (Celery + broker) â€” adding that is an infra decision for whoever operates this, not a one-line fix. Calling the (CPU-heavy, synchronous) `BaselineTrainer` in-process from a request handler would block the event loop and, worse, would still only be training on synthetic data (next point) â€” that would look "fixed" while actually being misleading.
- **Training pipelines use synthetic data.** `training/train.py::load_data()` and `training/finetune.py::load_training_data()` generate random/hardcoded datasets. Their docstrings describe querying MongoDB (`transactions`/`behavior_patterns`/`feedback`) instead â€” building that real data-assembly pipeline is a scoped feature, not a bug fix.
- **Observability endpoints are stubs.** `routers/observability.py` has no Evidently AI / MLflow / Celery integration; this requires standing up that infrastructure, which is a product decision outside the scope of fixing existing code.
- **No caching layer or database indexes.** Fine for development; a real constraint before production load, and its own piece of work (index selection needs real query-pattern data).
- **Automatic scheduling for the new `/v1/pipelines/*` endpoints.** They're reachable now (Â§16.3), but nothing calls them on a schedule â€” that requires choosing and standing up a scheduler (cron, Celery beat, etc.).

## 16.6 How this was verified

- Every module in the repository was import-checked (46 modules, excluding the two `torch`-dependent training scripts, which were syntax-checked instead to avoid an unnecessary multi-GB dependency install).
- The full `test_api.py` suite (15 tests) passes against a real, locally-run MongoDB instance with no failures, xfails, or skips.
- The categorize â†’ feedback â†’ behavior/run-all â†’ graph/build â†’ decay/sweep pipeline was exercised end-to-end via a live HTTP round-trip, confirming the `merchant_name` join fix, the new pipeline endpoints, and the real rate limit all work correctly together.

