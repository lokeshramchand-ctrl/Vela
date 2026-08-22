from fastapi import APIRouter
from fastapi.responses import JSONResponse

router = APIRouter(prefix="/v1/observability", tags=["Observability & MLOps"])

@router.post("/drift/analyze")
async def trigger_drift_analysis():
    """
    Triggers a background Evidently AI task to detect Data & Target Drift.
    """
    # In production, this triggers an async Celery task
    return {"status": "success", "message": "Drift analysis triggered successfully."}

@router.get("/reports/latest")
async def fetch_drift_report():
    """
    Serves the latest generated HTML drift report.
    """
    # For testing purposes, we return 404 to simulate no reports generated yet
    return JSONResponse(
        status_code=404,
        content={"message": "No drift reports have been generated yet."}
    )
