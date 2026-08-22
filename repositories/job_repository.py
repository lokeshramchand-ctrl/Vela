import logging
from datetime import UTC, datetime

from bson import ObjectId
from bson.errors import InvalidId

from database.mongo import db
from models.schemas import Job, JobStatus

logger = logging.getLogger(__name__)


class JobRepository:
    async def create(self, job: Job) -> Job:
        doc = job.model_dump(by_alias=True, exclude={"id"})
        result = await db.jobs.insert_one(doc)
        job.id = str(result.inserted_id)
        return job

    async def get_by_id(self, job_id: str) -> Job | None:
        try:
            oid = ObjectId(job_id)
        except (InvalidId, TypeError):
            return None
        doc = await db.jobs.find_one({"_id": oid})
        if not doc:
            return None
        doc["_id"] = str(doc["_id"])
        return Job(**doc)

    async def mark_running(self, job_id: str, stage: str) -> None:
        await db.jobs.update_one(
            {"_id": ObjectId(job_id)},
            {"$set": {"status": JobStatus.RUNNING.value, "stage": stage, "started_at": datetime.now(UTC)}},
        )

    async def update_progress(self, job_id: str, stage: str, progress_percent: int) -> None:
        await db.jobs.update_one(
            {"_id": ObjectId(job_id)},
            {"$set": {"stage": stage, "progress_percent": progress_percent}},
        )

    async def mark_completed(self, job_id: str) -> None:
        await db.jobs.update_one(
            {"_id": ObjectId(job_id)},
            {
                "$set": {
                    "status": JobStatus.COMPLETED.value,
                    "stage": "completed",
                    "progress_percent": 100,
                    "completed_at": datetime.now(UTC),
                }
            },
        )

    async def mark_failed(self, job_id: str, error_message: str) -> None:
        await db.jobs.update_one(
            {"_id": ObjectId(job_id)},
            {
                "$set": {
                    "status": JobStatus.FAILED.value,
                    "error_message": error_message,
                    "completed_at": datetime.now(UTC),
                }
            },
        )

    async def delete_for_resource(self, resource_id: str) -> int:
        result = await db.jobs.delete_many({"resource_id": resource_id})
        return result.deleted_count


job_repo = JobRepository()
