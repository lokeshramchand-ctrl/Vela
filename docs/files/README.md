# File-by-File Reference

> **Note on currency**: these pages were written against an earlier snapshot of the codebase and may describe bugs (import errors, unmounted routers, hardcoded values, etc.) that have since been fixed. [`docs/16-known-issues-tech-debt.md`](../16-known-issues-tech-debt.md) is the current, up-to-date source of truth for what's fixed vs. still open — check it before treating any specific defect described below as still present.

Deep-dive documentation for every `.py` and `.sh` source file in the repository (49 files), mirroring the repo's own directory structure. Each page covers: purpose, responsibilities, imports (with what each is used for), exports, execution flow, every function/method explained in plain English, classes, interfaces, hooks, utilities, dependencies, side effects, performance considerations, and interview questions.

Not covered here (not executable source): `merchant_aliases.json` (data — see [03 · Data Model](../03-data-model.md)), `Dockerfile`/`docker-compose_*.yaml`/`requirements*.txt` (deployment config — see [14 · Deployment & Operations](../14-deployment-operations.md)), `README.md`.

Every function in every file is covered — none are skipped, including trivial `__init__.py` package markers and dead/unused imports, which are called out explicitly where found.

## Index by directory

| Directory | Files |
|---|---|
| `.` (root) | [`app.py`](./app.py.md) · [`test_api.py`](./test_api.py.md) |
| `core/` | [`config.py`](./core/config.py.md) · [`security.py`](./core/security.py.md) · [`rate_limiter.py`](./core/rate_limiter.py.md) · [`ollama_client.py`](./core/ollama_client.py.md) |
| `database/` | [`mongo.py`](./database/mongo.py.md) · [`milvus.py`](./database/milvus.py.md) · [`__init__.py`](./database/init.py.md) |
| `models/` | [`schemas.py`](./models/schemas.py.md) · [`__init__.py`](./models/init.py.md) |
| `routers/` | [`v1.py`](./routers/v1.py.md) · [`memory.py`](./routers/memory.py.md) · [`analytics.py`](./routers/analytics.py.md) · [`rag.py`](./routers/rag.py.md) · [`observability.py`](./routers/observability.py.md) |
| `engines/` | [`rule_engine.py`](./engines/rule_engine.py.md) · [`confidence_engine.py`](./engines/confidence_engine.py.md) |
| `services/` | [`merchant_resolver.py`](./services/merchant_resolver.py.md) |
| `memory/` | [`memory_manager.py`](./memory/memory_manager.py.md) · [`state_machine.py`](./memory/state_machine.py.md) · [`decay_engine.py`](./memory/decay_engine.py.md) |
| `repositories/` | [`profile_repository.py`](./repositories/profile_repository.py.md) ⚠ import bug |
| `features/` | [`amount_features.py`](./features/amount_features.py.md) · [`temporal_features.py`](./features/temporal_features.py.md) · [`frequency_features.py`](./features/frequency_features.py.md) · [`periodicity.py`](./features/periodicity.py.md) |
| `behaviour/` | [`behavior_engine.py`](./behaviour/behavior_engine.py.md) |
| `embeddings/` | [`generate_embeddings.py`](./embeddings/generate_embeddings.py.md) · [`vectorizer.py`](./embeddings/vectorizer.py.md) |
| `milvus/` | [`insert_vectors.py`](./milvus/insert_vectors.py.md) · [`search_vectors.py`](./milvus/search_vectors.py.md) |
| `clustering/` | [`umap_projection.py`](./clustering/umap_projection.py.md) · [`hdbscan_cluster.py`](./clustering/hdbscan_cluster.py.md) · [`cluster_engine.py`](./clustering/cluster_engine.py.md) ⚠ two bugs |
| `training/` | [`train.py`](./training/train.py.md) · [`finetune.py`](./training/finetune.py.md) |
| `evaluation/` | [`metrics.py`](./evaluation/metrics.py.md) |
| `feedback/` | [`api_router.py`](./feedback/api_router.py.md) ⚠ unmounted · [`feedback_service.py`](./feedback/feedback_service.py.md) · [`retraining_queue.py`](./feedback/retraining_queue.py.md) |
| `rag/` | [`retriever.py`](./rag/retriever.py.md) · [`context_builder.py`](./rag/context_builder.py.md) · [`generator.py`](./rag/generator.py.md) |
| `analytics/` | [`spending_patterns.py`](./analytics/spending_patterns.py.md) · [`subscriptions.py`](./analytics/subscriptions.py.md) · [`trends.py`](./analytics/trends.py.md) ⚠ mocked · [`anomaly_detection.py`](./analytics/anomaly_detection.py.md) |
| `graphs/` | [`graph_builder.py`](./graphs/graph_builder.py.md) |
| `scripts/` | [`seed.py`](./scripts/seed.py.md) · [`mock_seeder.py`](./scripts/mock_seeder.py.md) · [`test_pipeline.sh`](./scripts/test_pipeline.sh.md) |

## Files with confirmed runtime bugs, flagged in their own docs

| File | Bug |
|---|---|
| `repositories/profile_repository.py` | Missing `from typing import Optional` — raises `NameError` on import, likely preventing the whole app from starting |
| `routers/v1.py` | `.get()` on a Pydantic model, plus `time.timezone.utc` (should be `datetime.timezone.utc`) — `/v1/categorize` cannot complete a request |
| `clustering/cluster_engine.py` | `sklearn.metrics.davies_bouldin_index` doesn't exist (real name: `davies_bouldin_score`), and `vector_store.behavior_collection` doesn't exist as an attribute — two independent bugs, the second masked by the first |
| `feedback/api_router.py` | Fully correct, but never mounted in `app.py` — unreachable over HTTP |

Full detail and remediation guidance for all of these lives in [16 · Known Issues & Tech Debt](../16-known-issues-tech-debt.md).

## How this differs from the folder-level docs

[`../folders/`](../folders/README.md) documents each *directory* as a cohesive unit — its role in the system, how it relates to sibling directories, and its dependency/call graph relative to other directories. This section drills one level deeper: every individual *file*, every individual *function*, explained line-by-line in plain English. Use the folder docs to understand "what does this subsystem do and why," and this section to understand "what does this exact function do, step by step."
