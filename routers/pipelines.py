import logging

from fastapi import APIRouter, HTTPException, Path, Request
from pydantic import BaseModel, Field

from behaviour.behavior_engine import behavior_engine
from core.rate_limiter import limiter
from database.mongo import db
from embeddings.generate_embeddings import embedding_generator
from embeddings.vectorizer import vectorizer
from graphs.graph_builder import graph_engine
from memory.decay_engine import decay_engine
from milvus.insert_vectors import vector_store
from models.schemas import BehaviorPattern

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/v1/pipelines", tags=["Batch Pipelines"])


class MerchantRequest(BaseModel):
    merchant_name: str = Field(..., min_length=1, max_length=200)


@router.post("/behavior/run")
@limiter.limit("30/minute")
async def run_behavior_profiling(request: Request, payload: MerchantRequest):
    """Profiles a single merchant's behavioral signature (Phase 6). Writes to `behavior_patterns`."""
    try:
        return await behavior_engine.profile_merchant_behavior(payload.merchant_name)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e


@router.post("/behavior/run-all")
@limiter.limit("10/minute")
async def run_behavior_profiling_all(request: Request):
    """
    Profiles every distinct merchant seen in `transactions`. This is the batch entry
    point that keeps `behavior_patterns` populated for /v1/analytics/subscriptions
    and /v1/analytics/anomaly/check, since nothing else calls the behavior engine.
    Rate-limited tighter than default: this is an O(all merchants) batch job, not
    a per-request operation, and shouldn't be triggerable at high frequency.
    """
    merchant_names = await db.transactions.distinct("merchant")
    profiled, failed = [], []
    for name in merchant_names:
        if not name or name == "Unknown":
            continue
        try:
            await behavior_engine.profile_merchant_behavior(name)
            profiled.append(name)
        except Exception as e:
            logger.warning(f"Behavior profiling failed for '{name}': {e}")
            failed.append(name)
    return {"profiled": profiled, "failed": failed}


@router.post("/embeddings/sync")
@limiter.limit("10/minute")
async def sync_embeddings(request: Request):
    """
    Generates and stores Milvus embeddings for every persisted behavior pattern
    (Phase 7). This is the missing link between `behavior_patterns` and the
    vector search used by /v1/explain and the clustering pipeline.
    Rate-limited: this is an O(all behavior patterns) batch job making one
    Ollama embedding call per document, not a per-request operation.
    """
    if vector_store.client is None:
        raise HTTPException(status_code=503, detail="Milvus is not connected.")

    docs = [doc async for doc in db.behavior_patterns.find()]
    synced, failed = [], []
    for doc in docs:
        merchant_name = doc.get("merchant_name", "Unknown")
        try:
            doc["_id"] = str(doc["_id"])
            pattern = BehaviorPattern(**doc)
            text = vectorizer.stringify_behavior(pattern)
            vector = await embedding_generator.generate(text)
            vector_store.insert_behavior_vector(
                pattern_id=pattern.id,
                merchant_name=pattern.merchant_name,
                vector=vector,
            )
            synced.append(merchant_name)
        except Exception as e:
            logger.warning(f"Embedding sync failed for '{merchant_name}': {e}")
            failed.append(merchant_name)
    return {"synced": synced, "failed": failed}


@router.post("/decay/sweep")
@limiter.limit("10/minute")
async def run_decay_sweep(request: Request):
    """Archives merchant profiles inactive for 180+ days (Phase 4)."""
    archived_count = await decay_engine.run_archive_sweep()
    return {"archived_count": archived_count}


@router.post("/graph/build")
@limiter.limit("10/minute")
async def build_knowledge_graph(request: Request):
    """Rebuilds the in-memory merchant knowledge graph from MongoDB (Phase 13)."""
    return await graph_engine.build_graph()


@router.get("/graph/neighborhood/{merchant_name}")
async def get_graph_neighborhood(
    merchant_name: str = Path(..., min_length=1, max_length=200),
    radius: int = 2,
):
    """Returns the local ego-graph around a merchant. Call /graph/build first in this process."""
    radius = max(0, min(radius, 5))
    return graph_engine.get_merchant_neighborhood(merchant_name, radius=radius)


@router.post("/clustering/run")
@limiter.limit("5/minute")
async def run_clustering(request: Request):
    """
    Runs the UMAP + HDBSCAN discovery pipeline over stored Milvus vectors (Phase 8).
    Imported lazily so a missing/broken scikit-learn or umap-learn install only
    breaks this one endpoint instead of preventing the whole app from starting.
    Rate-limited tightest of the batch endpoints: this is the most CPU-intensive
    job in the app (UMAP dimensionality reduction + HDBSCAN clustering).
    """
    from clustering.cluster_engine import cluster_engine
    return await cluster_engine.run_discovery_pipeline()
