import logging
from contextlib import asynccontextmanager

import httpx
from fastapi import Depends, FastAPI
from fastapi.responses import JSONResponse

# Middleware & Security
from prometheus_fastapi_instrumentator import Instrumentator

# Settings
from core.config import settings
from core.error_handlers import register_exception_handlers
from core.middleware import BodySizeLimitMiddleware, RequestIDMiddleware, SecurityHeadersMiddleware
from core.ollama_client import get_ollama_host
from core.rate_limiter import setup_rate_limiting
from core.security import validate_api_key
from database.milvus import vector_db

# Databases
from database.mongo import db
from feedback.api_router import router as feedback_router
from milvus.insert_vectors import vector_store

# Routers
from routers import analytics, auth, jobs, memory, pipelines, rag, statements, users, v1
from routers.observability import router as observability_router

# Logging
# LOG_LEVEL defaults to INFO (never DEBUG by default): at DEBUG, pymongo/motor
# log full command payloads, including raw transaction documents - amounts,
# merchants, user ids. That's inappropriate for a service handling real
# financial data outside of a deliberate, opt-in local debugging session.
logging.basicConfig(
    level=getattr(logging, settings.LOG_LEVEL.upper(), logging.INFO),
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger(__name__)


# Lifespan
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Initializing application lifespan...")

    # MongoDB
    await db.connect(uri=settings.MONGODB_URI, db_name=settings.MONGODB_DB_NAME)
    await db.ensure_indexes()

    # Milvus
    vector_db.connect(uri=settings.MILVUS_URI)
    vector_store.ensure_collections()

    yield

    logger.info("Tearing down application lifespan...")
    await db.disconnect()
    vector_db.disconnect()


# FastAPI App
app = FastAPI(
    title="Vela",
    description="Core engine for raw transaction ingestion and ML routing.",
    version="1.0.0",
    lifespan=lifespan
)

# Centralized error handling - every error response (expected or not) comes
# back as the same JSON envelope, and unhandled exceptions never leak
# internal detail to the client (full detail is always logged server-side).
register_exception_handlers(app)

# Rate Limiting
setup_rate_limiting(app)

# Defensive middleware. Added in this order so that, relative to the ASGI
# stack (last-added = outermost), RequestIDMiddleware wraps everything else -
# even a request rejected by the body-size limiter gets a correlation id back.
app.add_middleware(SecurityHeadersMiddleware)
app.add_middleware(BodySizeLimitMiddleware, max_bytes=settings.MAX_REQUEST_BODY_BYTES)
app.add_middleware(RequestIDMiddleware)

# Prometheus Metrics
Instrumentator().instrument(app).expose(app, endpoint="/metrics")


# Routers (secured)
# Every router is mounted behind the shared X-Vela-API-Key dependency,
# regardless of whether any of its handlers also require a per-user JWT
# (core/jwt_auth.py::get_current_user, applied at the handler level where
# needed - see routers/auth.py, routers/v1.py, routers/analytics.py,
# feedback/api_router.py). The API key authenticates the calling
# application; JWT authenticates the end user within it. A JWT alone, without
# the API key, is rejected here before a handler ever runs.
app.include_router(auth.router, dependencies=[Depends(validate_api_key)])
app.include_router(users.router, dependencies=[Depends(validate_api_key)])
app.include_router(v1.router, dependencies=[Depends(validate_api_key)])
app.include_router(memory.router, dependencies=[Depends(validate_api_key)])
app.include_router(analytics.router, dependencies=[Depends(validate_api_key)])
app.include_router(rag.router, dependencies=[Depends(validate_api_key)])
app.include_router(observability_router, dependencies=[Depends(validate_api_key)])
app.include_router(feedback_router, dependencies=[Depends(validate_api_key)])
app.include_router(pipelines.router, dependencies=[Depends(validate_api_key)])
app.include_router(statements.router, dependencies=[Depends(validate_api_key)])
app.include_router(jobs.router, dependencies=[Depends(validate_api_key)])


# --- Health / Liveness / Readiness ---
# Split per k8s-style convention: liveness answers "is the process alive"
# (cheap, no dependency calls - a hung dependency should never fail liveness
# and trigger a restart-loop that won't fix anything). Readiness answers "can
# this instance actually serve traffic" (checks dependencies, used to gate
# load balancer / rollout traffic). Both are intentionally unauthenticated,
# matching standard orchestrator health-check conventions, but - unlike the
# original /health - never return raw exception text, only a coarse status,
# so they can't leak internal topology (hostnames, connection errors) to an
# unauthenticated caller. /health is kept exactly as it was for backward
# compatibility with any existing monitoring pointed at it, with the same
# info-leak fixed in place.

async def _check_dependencies() -> tuple[str, dict, dict]:
    services = {}
    details = {}

    try:
        if db.client:
            await db.client.admin.command("ping")
            services["mongodb"] = "connected"
            details["mongodb"] = "Active ping successful."
        else:
            services["mongodb"] = "disconnected"
            details["mongodb"] = "Client not initialized."
    except Exception:
        logger.exception("Dependency check: MongoDB ping failed")
        services["mongodb"] = "error"
        details["mongodb"] = "MongoDB health check failed - see server logs."

    try:
        if vector_db.client:
            services["milvus"] = "connected"
            details["milvus"] = "Client initialized."
        else:
            services["milvus"] = "disconnected"
            details["milvus"] = "Client not initialized."
    except Exception:
        logger.exception("Dependency check: Milvus check failed")
        services["milvus"] = "error"
        details["milvus"] = "Milvus health check failed - see server logs."

    try:
        async with httpx.AsyncClient(timeout=2.0) as client:
            resp = await client.get(get_ollama_host())
            if resp.status_code == 200:
                services["ollama"] = "connected"
                details["ollama"] = "Ollama engine responding."
            else:
                services["ollama"] = "degraded"
                details["ollama"] = f"Status code: {resp.status_code}"
    except Exception:
        logger.exception("Dependency check: Ollama check failed")
        services["ollama"] = "error"
        details["ollama"] = "Ollama health check failed - see server logs."

    overall_status = "healthy" if all(v == "connected" for v in services.values()) else "degraded"
    return overall_status, services, details


@app.get("/live", tags=["System"])
async def liveness():
    return {"status": "alive"}


@app.get("/ready", tags=["System"])
async def readiness():
    _, services, _ = await _check_dependencies()
    # MongoDB is this app's one hard dependency for correctness (every write
    # path needs it); Milvus/Ollama degrade specific features gracefully
    # (see rag/retriever.py, milvus/insert_vectors.py) rather than failing
    # the whole app, so they don't gate readiness.
    is_ready = services.get("mongodb") == "connected"
    return JSONResponse(
        status_code=200 if is_ready else 503,
        content={"status": "ready" if is_ready else "not_ready", "services": services},
    )


@app.get("/health", tags=["System"])
async def health_check():
    overall_status, services, details = await _check_dependencies()
    return {"status": overall_status, "services": services, "details": details}


# Local Dev Entry Point
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app:app",
        host="0.0.0.0",  # noqa: S104 - intentional: must accept connections from outside the container/network namespace, not just localhost
        port=8000,
        reload=(settings.ENVIRONMENT == "development"),
    )

