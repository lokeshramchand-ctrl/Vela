# GET `/metrics`

## Method
`GET`

## URL
`/metrics`

## Purpose
Exposes Prometheus-format metrics (request counts, latency histograms, in-progress request gauges) auto-collected by `prometheus-fastapi-instrumentator` across every route in the application, for scraping by a Prometheus server.

## Authentication
**None.** Like `/health`, this endpoint is attached via `Instrumentator().instrument(app).expose(app, endpoint="/metrics")` directly on `app`, outside any `include_router(..., dependencies=[...])` call — no API key is required.

## Headers
None required for the request. The response is served with `Content-Type: text/plain` (Prometheus's standard exposition format), set automatically by the instrumentator library, not by any code in this repository.

## Request body
None.

## Validation
None.

## Response
`200 OK` with a plain-text body in Prometheus exposition format, e.g.:
```
# HELP http_requests_total Total number of requests by method, status and handler.
# TYPE http_requests_total counter
http_requests_total{handler="/v1/resolve",method="POST",status="2xx"} 42.0
# HELP http_request_duration_seconds Duration of HTTP requests
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{handler="/v1/resolve",le="0.1"} 40.0
...
```
The exact metric names and labels are entirely determined by the third-party `prometheus-fastapi-instrumentator` library's defaults — no custom metrics, labels, or buckets are configured anywhere in this codebase.

## Error codes
None expected under normal operation — this is a library-managed endpoint with no application-specific failure modes coded.

## Internal execution flow
1. On every request to *any* route in the application (not just this one), the instrumentator's middleware records timing and outcome data into its internal metric registry.
2. When `GET /metrics` is called, the instrumentator serializes its entire current registry into Prometheus text format and returns it.

## Controller
Not application code — this route is registered entirely by the `prometheus-fastapi-instrumentator` library's `expose()` call in `app.py`; there is no handler function defined anywhere in this repository for this path.

## Service
None — no application business logic is involved.

## Database queries
None — metrics are held entirely in-process memory by the instrumentator library.

## Example request
```bash
curl -s http://localhost:8000/metrics
```

## Example response
```
# HELP http_requests_total Total number of requests by method, status and handler.
# TYPE http_requests_total counter
http_requests_total{handler="/health",method="GET",status="2xx"} 12.0
http_requests_total{handler="/v1/resolve",method="POST",status="2xx"} 5.0
http_requests_total{handler="/v1/categorize",method="POST",status="5xx"} 3.0
```

## Interview questions
- "Why is this endpoint entirely absent from application code, unlike every other route?" (It's provided end-to-end by a third-party library (`prometheus-fastapi-instrumentator`) that wraps the FastAPI app and registers its own route and middleware — the only application involvement is the two lines in `app.py` that instantiate and expose it.)
- "Why does `POST /v1/categorize` show up with a `5xx` status label in this example, given that endpoint is known to be broken?" (Because every request to it currently raises an unhandled `AttributeError`, which FastAPI/Starlette converts to a `500 Internal Server Error` — the instrumentator faithfully records that outcome, making `/metrics` an accurate, if indirect, way to observe that this endpoint is failing in production without reading logs.)
- "Should this endpoint require authentication?" (It's unauthenticated here, consistent with typical Prometheus deployment patterns where the scrape endpoint is reachable only from a trusted internal network rather than protected by application-level auth — but if this service were ever exposed to the public internet without a network-level restriction, this endpoint would leak internal route names, request volumes, and latency distributions to anyone.)
- "How would you add a custom business metric — e.g., 'number of transactions routed to Unknown category' — to this endpoint?" (Define a custom `prometheus_client.Counter` (or similar) in the relevant module, e.g., `engines/confidence_engine.py`, increment it inside `evaluate()` whenever a rejection occurs, and it would automatically be included in this endpoint's output once registered with the same registry the instrumentator uses — nothing like this currently exists anywhere in the codebase.)
