import logging
from typing import Any

from pymongo import UpdateOne

from database.mongo import db
from models.schemas import CanonicalFinancialRecord

logger = logging.getLogger(__name__)


class CanonicalRecordRepository:
    async def bulk_upsert(self, records: list[CanonicalFinancialRecord]) -> int:
        """Upserts on (user_id, source, source_record_id) to ensure each
        financial source can only produce one record per original ID."""
        if not records:
            return 0

        operations = [
            UpdateOne(
                {
                    "user_id": record.user_id,
                    "source": record.source,
                    "source_record_id": record.source_record_id,
                },
                {"$set": record.model_dump(by_alias=True, exclude={"id"})},
                upsert=True,
            )
            for record in records
        ]
        result = await db.canonical_records.bulk_write(operations, ordered=False)
        return result.upserted_count + result.modified_count

    async def get_by_id(self, record_id: str) -> CanonicalFinancialRecord | None:
        doc = await db.canonical_records.find_one({"_id": record_id})
        if doc:
            doc["_id"] = str(doc["_id"])
            return CanonicalFinancialRecord(**doc)
        return None

    async def get_by_source_id(
        self, user_id: str, source: str, source_record_id: str
    ) -> CanonicalFinancialRecord | None:
        doc = await db.canonical_records.find_one(
            {
                "user_id": user_id,
                "source": source,
                "source_record_id": source_record_id,
            }
        )
        if doc:
            doc["_id"] = str(doc["_id"])
            return CanonicalFinancialRecord(**doc)
        return None

    async def list_for_user(
        self,
        user_id: str,
        page: int = 1,
        page_size: int = 50,
        source: str | None = None,
    ) -> tuple[list[CanonicalFinancialRecord], int]:
        query: dict[str, Any] = {"user_id": user_id}
        if source:
            query["source"] = source

        total = await db.canonical_records.count_documents(query)
        cursor = (
            db.canonical_records.find(query)
            .sort("timestamp", -1)
            .skip((page - 1) * page_size)
            .limit(page_size)
        )
        items = []
        async for doc in cursor:
            doc["_id"] = str(doc["_id"])
            items.append(CanonicalFinancialRecord(**doc))
        return items, total

    async def delete_by_source_batch(
        self, user_id: str, source: str, source_ids: list[str]
    ) -> int:
        result = await db.canonical_records.delete_many(
            {
                "user_id": user_id,
                "source": source,
                "source_record_id": {"$in": source_ids},
            }
        )
        return result.deleted_count


canonical_record_repo = CanonicalRecordRepository()
