# 14 Â· Deployment & Operations

## 14.1 Python dependencies

âœ… **FIXED**, and since further hardened â€” full detail in [21 Â· Production Hardening Audit Â§8](./21-production-hardening-audit.md#8-dependencies-updated). `requirements.txt` previously listed Ubuntu/`apt`-managed system packages instead of application dependencies; that's fixed, and it's now further split: `requirements.txt` (installed by the Dockerfile) has only what the live API actually imports, while `torch`/`transformers`/`peft`/`datasets`/`pandas`/`lightgbm`/`xgboost`/`shap`/`tabulate` â€” used exclusively by `training/train.py` and `training/finetune.py`, never imported by the live app â€” moved to `requirements-training.txt`, which the production image never installs. Every pinned version was also run through `pip-audit`; the audit found and fixed real CVEs in `fastapi`/`starlette`, `pytest`, and `setuptools`, including two genuine dependency-upgrade regressions (a `prometheus-fastapi-instrumentator` incompatibility and a `pymilvus`/`setuptools` `pkg_resources` conflict) that were only caught by actually re-running the test suite and the Docker build â€” see the audit doc for the exact errors and fixes.

Statement ingestion ([23 Â· Statement Ingestion Pipeline](./23-statements-pipeline.md)) added `pypdf` (PDF structure validation/decryption), `pdfplumber` (text extraction â€” its default `x_tolerance` collapses this statement format's word spacing entirely, confirmed against a real sample, so it's always called with `x_tolerance=1`), and `python-multipart` (a hard runtime requirement the moment any route declares `File()`/`Form()`, per FastAPI/Starlette â€” `POST /statements/upload`).

## 14.2 Dockerfile

```dockerfile
FROM python:3.12-slim AS builder
# ... installs deps into /install ...
FROM python:3.12-slim AS runtime
# ... copies only /install, runs as a non-root `Vela` user, HEALTHCHECK on /live ...
```
âœ… **FIXED** â€” now a multi-stage build (build tools and pip cache never reach the final image), runs as a non-root user (verified: `docker run ... id` reports `uid=999(Vela)`), and has a `HEALTHCHECK` polling `/live`. See [21 Â· Production Hardening Audit Â§6](./21-production-hardening-audit.md#6-docker-improvements) for the full Dockerfile and verification detail. Base image is deliberately kept at `python:3.12-slim` rather than Alpine â€” Alpine's musl libc has known friction with the scientific-Python wheels (`scikit-learn`, `numpy`, `umap-learn`) the clustering endpoint needs at runtime.

`.dockerignore` now excludes `.env`, `*.pem`/`*.key`, local dev venvs, `.git`, docs, and the local-only compose files â€” previously `.env` was **not** excluded, meaning a `.env` file present in the build context would have been baked into the image layer via `COPY . .`. Fixed.

## 14.3 Docker Compose environments

### `docker-compose_local.yaml`
```yaml
services:
  mongodb:            # mongo:6.0, port 27017, named volume mongo_data
  Vela-backend:       # builds from local Dockerfile, port 9850:8000
                       # env_file: .env
                       # depends_on: mongodb
```
This is the intended local dev stack â€” but it only stands up **MongoDB**, not Milvus or Ollama. `README.md`'s own setup instructions describe a *different*, more complete compose file (with `milvus-standalone` on ports `19530`/`9091`) that is not actually checked into the repo as `docker-compose_local.yaml` â€” the committed compose file and the README's documented compose file have diverged. If you follow `README.md` literally, you'll need to author that Milvus service yourself; if you run the checked-in `docker-compose_local.yaml` as-is, the app will start with `milvus: disconnected` on `/health` (per `database/milvus.py`'s retry-then-`None` behavior) unless Milvus is running separately.

### `docker-compose_production.yaml`
```yaml
services:
  Vela-backend:
    build: .
    environment:
      - MONGODB_URI=${MONGODB_URI:?MONGODB_URI must be set}
      - MONGODB_DB_NAME=${MONGODB_DB_NAME:-Vela}
      - MILVUS_URI=${MILVUS_URI:?MILVUS_URI must be set}
      - OLLAMA_URI=${OLLAMA_URI:-}
      - OLLAMA_HOSTS=${OLLAMA_HOSTS:-}
      - EMBED_MODEL=${EMBED_MODEL:?EMBED_MODEL must be set}
      - LLM_MODEL=${LLM_MODEL:?LLM_MODEL must be set}
      - Vela_API_KEY=${Vela_API_KEY:?Vela_API_KEY must be set}
      - JWT_SECRET_KEY=${JWT_SECRET_KEY:?JWT_SECRET_KEY must be set}
      - JWT_ALGORITHM=${JWT_ALGORITHM:-HS256}
      - JWT_ACCESS_TOKEN_EXPIRE_MINUTES=${JWT_ACCESS_TOKEN_EXPIRE_MINUTES:-15}
      - JWT_REFRESH_TOKEN_EXPIRE_DAYS=${JWT_REFRESH_TOKEN_EXPIRE_DAYS:-30}
    networks: [coolify]   # external network, implies deployment via Coolify PaaS
```
âœ… **FIXED â€” both issues.** This file previously committed a plaintext MongoDB username/password directly in the connection string, and used env var names (`MONGO_URI`, `MONGO_DB_NAME`, `MILVUS_HOST`, `MILVUS_PORT`) that didn't match what `core/config.py` reads. It now sources every value via `${VAR:?required}`/`${VAR:-default}` substitution from a compose `.env` file or the host/CI secret store, with names matching `Settings` exactly. See [Known Issues Â§16.2â€“16.3](./16-known-issues-tech-debt.md).

**Action still required from whoever operates this deployment** (not something fixable from inside the repo): the credential previously committed here is in git history and must be treated as compromised â€” rotate it on the actual MongoDB server. Removing it from the tracked file does not undo its prior exposure.

âœ… **Also fixed in the production-hardening audit** ([21 Â· Â§6](./21-production-hardening-audit.md#6-docker-improvements)): this file previously also bind-mounted the entire repo (`volumes: - .:/app`), which meant "production" actually ran whatever was on the host filesystem at deploy time, not the code baked into the versioned image â€” that bind mount is removed here (kept, intentionally, in `docker-compose_local.yaml` for dev hot-reload). Also added: `security_opt: [no-new-privileges:true]`, `cap_drop: [ALL]`, and starting `deploy.resources.limits/reservations` for CPU/memory.

## 14.4 Required environment variables (authoritative â€” from `core/config.py`)

```env
MONGODB_URI=mongodb://<host>:27017
MONGODB_DB_NAME=Vela
MILVUS_URI=http://<host>:19530
OLLAMA_URI=http://<host>:11434        # OR use OLLAMA_HOSTS below
OLLAMA_HOSTS=http://host1:11434,http://host2:11434
EMBED_MODEL=<ollama embedding model name>
LLM_MODEL=<ollama generation model name>
Vela_API_KEY=<enforced on every non-public route via X-Vela-API-Key>
JWT_SECRET_KEY=<required, min 32 chars - app fails to start otherwise; generate with: openssl rand -hex 32>
JWT_ALGORITHM=HS256                   # optional, default shown
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=15    # optional, default shown
JWT_REFRESH_TOKEN_EXPIRE_DAYS=30      # optional, default shown
MAX_REQUEST_BODY_BYTES=15000000       # optional, default shown - raised from 1MB to fit multipart PDF uploads (POST /statements/upload)
MAX_STATEMENT_PDF_BYTES=10000000      # optional, default shown - the tighter, upload-specific ceiling checked in routers/statements.py for a clearer 413 message
```
Place this file at the repo root as `.env` for local development (loaded via `pydantic_settings`'s `env_file=".env"`); for containerized deployment, either mount/inject it or set each variable directly in the container environment (aligning names exactly â€” see the mismatch warning above for `docker-compose_production.yaml`). See [22 Â· Authentication](./22-authentication.md) for what `JWT_SECRET_KEY` signs and why a short/missing value fails startup rather than silently falling back to something insecure.

## 14.5 Bootstrapping data (manual, out-of-band steps)

None of these run automatically on startup (no scheduler exists), but all are now reachable via HTTP instead of requiring direct script/REPL invocation:

1. `python scripts/seed.py` â€” seeds canonical `merchants` (Swiggy, Zomato, Netflix + aliases) so `/v1/resolve` can find matches beyond `"Unknown"`.
2. `python scripts/mock_seeder.py` (and `python scripts/mock_seeder.py cleanup` to remove it) â€” injects 100 synthetic `is_mock: True` transactions for `user_id: "user_123"` so the Analytics Engine has data to aggregate. Used by `scripts/test_pipeline.sh`.
3. `POST /v1/pipelines/behavior/run-all` â€” profiles every distinct merchant seen in `transactions` and populates `behavior_patterns`, required before `/v1/analytics/subscriptions` or `/v1/analytics/anomaly/check` return anything non-trivial.
4. `POST /v1/pipelines/embeddings/sync` â€” generates embeddings for every stored `behavior_pattern` and inserts them into Milvus, required before `/v1/explain` can retrieve any grounded context.
5. `POST /v1/pipelines/clustering/run` â€” runs `ClusterEngine.run_discovery_pipeline()` (the `davies_bouldin_index` import bug is fixed â€” see [07 Â· Embeddings, Vector Search & Clustering Â§7.4](./07-embeddings-vectorsearch-clustering.md#74-phase-8-clustering-pipeline--clusteringpy)).
6. `POST /v1/pipelines/decay/sweep` and `POST /v1/pipelines/graph/build` â€” the Phase 4 archival sweep and Phase 13 knowledge graph rebuild, both previously fully orphaned with zero callers.

Full request/response details for all of these are in [02 Â· API Reference Â§2.13](./02-api-reference.md#213-batch-pipelines-routerspipelinespy-prefix-v1pipelines).

## 14.6 `scripts/test_pipeline.sh` â€” manual E2E smoke test

A bash script exercising the API end-to-end against a running server at `http://localhost:8080` (note: this differs from the Dockerfile's default port `8000` and compose's exposed port `9850` â€” adjust `BASE_URL` to match whichever way you've started the server). It parses `Vela_API_KEY` out of a local `.env` if present, falling back to the hardcoded `Vela_test_key_123` â€” make sure this matches your actual configured `Vela_API_KEY`, since `core/security.py` now enforces the real configured value rather than accepting that literal unconditionally. Exercises: merchant resolution, memory state promotion (3 calls to force `EPHEMERAL â†’ TEMPORARY`), the confidence wall, mock data seeding, top-merchant/category analytics, then cleans up the mock data it created.

## 14.7 Running locally without Docker

```bash
python -m venv .venv
source .venv/bin/activate
# Manually install actual runtime deps (see 14.1) â€” requirements.txt is insufficient
pip install fastapi uvicorn "pydantic-settings" motor pymilvus slowapi \
    prometheus-fastapi-instrumentator httpx scikit-learn umap-learn networkx \
    pandas numpy lightgbm xgboost shap
# create .env per Â§14.4
uvicorn app:app --reload --host 0.0.0.0 --port 8000
```
(This list is derived from cross-referencing every module's imports as documented in this suite; verify versions before pinning, since none are specified in this repository.)

