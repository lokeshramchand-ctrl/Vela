import logging
from datetime import UTC, date, datetime, time
from typing import Any

from bson import ObjectId
from bson.errors import InvalidId

from database.mongo import db
from models.schemas import InsightItem, Statement, StatementAnalytics, StatementStatus

logger = logging.getLogger(__name__)

_SORTABLE_FIELDS = {"uploaded_at", "period_start", "period_end", "transaction_count"}


def _bsonify_dates(value: Any) -> Any:
    """MongoDB/BSON has no bare-date type - only datetime. Pydantic's `date`
    fields (Statement.period_start/end, DailyTrendItem.date inside the
    embedded analytics) need converting to midnight-UTC datetimes before an
    insert/update, or pymongo raises InvalidDocument. Reading back needs no
    inverse conversion: Pydantic v2 already coerces a datetime into a `date`
    field automatically when the model is reconstructed."""
    if isinstance(value, datetime):
        return value
    if isinstance(value, date):
        return datetime.combine(value, time.min, tzinfo=UTC)
    if isinstance(value, dict):
        return {k: _bsonify_dates(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_bsonify_dates(v) for v in value]
    return value


class StatementRepository:
    async def store_pdf(self, raw_bytes: bytes, filename: str) -> str:
        """Retains the original upload via GridFS - reuses this app's
        existing Mongo connection, no new storage infrastructure."""
        file_id = await db.gridfs_bucket.upload_from_stream(filename, raw_bytes)
        return str(file_id)

    async def delete_pdf(self, gridfs_file_id: str) -> None:
        try:
            await db.gridfs_bucket.delete(ObjectId(gridfs_file_id))
        except Exception:
            logger.warning("Failed to delete GridFS file %s - continuing.", gridfs_file_id, exc_info=True)

    async def create(self, statement: Statement) -> Statement:
        doc = _bsonify_dates(statement.model_dump(by_alias=True, exclude={"id"}))
        result = await db.statements.insert_one(doc)
        statement.id = str(result.inserted_id)
        return statement

    async def get_by_id(self, statement_id: str) -> Statement | None:
        try:
            oid = ObjectId(statement_id)
        except (InvalidId, TypeError):
            return None
        doc = await db.statements.find_one({"_id": oid})
        if not doc:
            return None
        doc["_id"] = str(doc["_id"])
        return Statement(**doc)

    async def list_for_user(
        self,
        user_id: str,
        page: int,
        page_size: int,
        status_filter: StatementStatus | None = None,
        sort_by: str = "uploaded_at",
        sort_order: int = -1,
    ) -> tuple[list[Statement], int]:
        query: dict[str, Any] = {"user_id": user_id}
        if status_filter is not None:
            query["processing_status"] = status_filter.value

        sort_field = sort_by if sort_by in _SORTABLE_FIELDS else "uploaded_at"

        total = await db.statements.count_documents(query)
        cursor = (
            db.statements.find(query)
            .sort(sort_field, sort_order)
            .skip((page - 1) * page_size)
            .limit(page_size)
        )
        items = []
        async for doc in cursor:
            doc["_id"] = str(doc["_id"])
            items.append(Statement(**doc))
        return items, total

    async def set_job(self, statement_id: str, job_id: str) -> None:
        await db.statements.update_one(
            {"_id": ObjectId(statement_id)},
            {"$set": {"current_job_id": job_id}},
        )

    async def mark_processing(self, statement_id: str) -> None:
        await db.statements.update_one(
            {"_id": ObjectId(statement_id)},
            {
                "$set": {
                    "processing_status": StatementStatus.PROCESSING.value,
                    "processing_started_at": datetime.now(UTC),
                }
            },
        )

    async def mark_completed(
        self,
        statement_id: str,
        *,
        transaction_count: int,
        computed_sent_amount: float,
        computed_received_amount: float,
        reconciliation_ok: bool | None,
        analytics: StatementAnalytics,
        insights: list[InsightItem],
        processing_duration_ms: int,
    ) -> None:
        await db.statements.update_one(
            {"_id": ObjectId(statement_id)},
            {
                "$set": {
                    "processing_status": StatementStatus.COMPLETED.value,
                    "transaction_count": transaction_count,
                    "computed_sent_amount": computed_sent_amount,
                    "computed_received_amount": computed_received_amount,
                    "reconciliation_ok": reconciliation_ok,
                    "analytics": _bsonify_dates(analytics.model_dump()),
                    "insights": [i.model_dump() for i in insights],
                    "processing_completed_at": datetime.now(UTC),
                    "processing_duration_ms": processing_duration_ms,
                }
            },
        )

    async def mark_failed(self, statement_id: str, error_message: str) -> None:
        await db.statements.update_one(
            {"_id": ObjectId(statement_id)},
            {
                "$set": {
                    "processing_status": StatementStatus.FAILED.value,
                    "error_message": error_message,
                    "processing_completed_at": datetime.now(UTC),
                }
            },
        )

    async def delete(self, statement_id: str) -> None:
        await db.statements.delete_one({"_id": ObjectId(statement_id)})


statement_repo = StatementRepository()
