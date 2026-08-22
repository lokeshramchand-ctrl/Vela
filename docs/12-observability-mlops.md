# 12 · Observability & MLOps (Phase 14)

## 12.1 Prometheus metrics — `app.py`

```python
Instrumentator().instrument(app).expose(app, endpoint="/metrics")
```
This is the entire observability implementation for request-level metrics. `prometheus_fastapi_instrumentator` auto-instruments all routes with its library defaults (request counts, latency histograms, in-progress gauges, etc.) — no custom `Instrumentator(...)` configuration (buckets, excluded paths, custom labels) is supplied, and no custom `Counter`/`Histogram`/`Gauge` objects are defined anywhere in the codebase. `GET /metrics` has no auth dependency, so it is world-readable to anything that can reach the service.

The `/v1/categorize` handler in `routers/v1.py` contains the comment `# TODO: Log process_time to Prometheus for Latency metrics` next to a manually-computed `process_time = time.time() - start_time` that is **computed and then discarded** — it's never actually exported as a metric. This confirms that no custom metrics exist beyond the instrumentator's automatic ones.

## 12.2 Drift analysis stubs — `routers/observability.py`

Prefix `/v1/observability`. Both endpoints are placeholders with no real logic behind them, despite `README.md` describing Evidently AI drift analysis as a shipped capability:

### `POST /v1/observability/drift/analyze`
```python
return {"status": "success", "message": "Drift analysis triggered successfully."}
```
No Evidently AI import, no background task, no Celery call — the docstring's claim ("Triggers a background Evidently AI task to detect Data & Target Drift" / "In production, this triggers an async Celery task") is aspirational and not implemented. Calling this endpoint does nothing except return a canned success message.

### `GET /v1/observability/reports/latest`
```python
return JSONResponse(status_code=404, content={"message": "No drift reports have been generated yet."})
```
Unconditionally returns 404 — there is no file store, no report generation job, and no code path that could ever produce a different response. The comment confirms this is intentional for now: "For testing purposes, we return 404 to simulate no reports generated yet."

## 12.3 What "MLOps" actually means in this codebase today

| README/comment claim | Reality |
|---|---|
| Evidently AI drift detection | Two stub endpoints, no Evidently dependency, no drift computation |
| MLflow experiment tracking | Referenced in comments ("we will push these results directly to MLflow") in `training/train.py`; no MLflow client, config, or calls anywhere |
| Celery async task queue | Referenced in comments in `feedback/retraining_queue.py` and `routers/observability.py`; no Celery dependency, worker, or broker configured anywhere in the repo |
| Prometheus metrics | **Actually implemented** via `prometheus-fastapi-instrumentator`, default config only |

If you're asked to build out Phase 14 for real, the concrete starting points are: (1) add an Evidently AI dependency and a reference-dataset snapshot mechanism for `drift/analyze` to compare against; (2) persist generated HTML reports somewhere `reports/latest` can actually serve from (`FileResponse` over a known path, or object storage); (3) decide whether Celery/MLflow are genuinely needed or whether background work should stay on FastAPI's built-in `BackgroundTasks` (already used successfully in [09 · Feedback & Active Learning](./09-feedback-active-learning.md)).
