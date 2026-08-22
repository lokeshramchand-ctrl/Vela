from fastapi import APIRouter, Depends, HTTPException, status

from core.jwt_auth import get_current_user
from models.schemas import JobResponse, User
from repositories.job_repository import job_repo

router = APIRouter(prefix="/jobs", tags=["Jobs"])


@router.get("/{job_id}", response_model=JobResponse)
async def get_job(job_id: str, current_user: User = Depends(get_current_user)):
    """404s if the job doesn't exist *or* belongs to another user - same
    ownership posture as GET /statements/{id}."""
    job = await job_repo.get_by_id(job_id)
    if job is None or job.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Job not found")

    return JobResponse(
        id=job.id,
        job_type=job.job_type,
        resource_type=job.resource_type,
        resource_id=job.resource_id,
        status=job.status,
        stage=job.stage,
        progress_percent=job.progress_percent,
        error_message=job.error_message,
        created_at=job.created_at,
        started_at=job.started_at,
        completed_at=job.completed_at,
    )
