import logging
import re
from datetime import datetime
from typing import Any

from pymongo import UpdateOne

from database.mongo import db
from models.schemas import Transaction, TransactionType

logger = logging.getLogger(__name__)

_SORTABLE_FIELDS = {"timestamp", "amount", "merchant", "category"}


class TransactionRepository:
    async def bulk_upsert(self, transactions: list[Transaction]) -> int:
        """Upserts on (user_id, reference_number) - the unique partial index
        in database/mongo.py::ensure_indexes - so re-uploading the same
        statement, or two statements with overlapping date ranges, updates
        existing transactions in place instead of duplicating them."""
        if not transactions:
            return 0

        operations = [
            UpdateOne(
                {"user_id": txn.user_id, "reference_number": txn.reference_number},
                {"$set": txn.model_dump(by_alias=True, exclude={"id"})},
                upsert=True,
            )
            for txn in transactions
        ]
        result = await db.transactions.bulk_write(operations, ordered=False)
        return result.upserted_count + result.modified_count

    async def get_distinct_debit_merchants(self, statement_id: str) -> list[str]:
        """Merchants touched by this statement's expense transactions - the
        set statements/statement_service.py refreshes behavior profiles for.
        Excludes "Unknown" (no rule_engine match) since there's nothing
        meaningful to profile there."""
        merchants = await db.transactions.distinct(
            "merchant",
            {"statement_id": statement_id, "transaction_type": TransactionType.DEBIT.value},
        )
        return [m for m in merchants if m and m != "Unknown"]

    async def list_for_statement(
        self,
        statement_id: str,
        user_id: str,
        page: int,
        page_size: int,
        category: str | None = None,
        transaction_type: TransactionType | None = None,
        merchant: str | None = None,
        start_date: datetime | None = None,
        end_date: datetime | None = None,
        sort_by: str = "timestamp",
        sort_order: int = -1,
    ) -> tuple[list[Transaction], int]:
        query: dict[str, Any] = {"statement_id": statement_id, "user_id": user_id}
        if category:
            query["category"] = category
        if transaction_type is not None:
            query["transaction_type"] = transaction_type.value
        if merchant:
            query["merchant"] = {"$regex": re.escape(merchant), "$options": "i"}
        if start_date or end_date:
            ts_filter: dict[str, datetime] = {}
            if start_date:
                ts_filter["$gte"] = start_date
            if end_date:
                ts_filter["$lte"] = end_date
            query["timestamp"] = ts_filter

        sort_field = sort_by if sort_by in _SORTABLE_FIELDS else "timestamp"

        total = await db.transactions.count_documents(query)
        cursor = (
            db.transactions.find(query)
            .sort(sort_field, sort_order)
            .skip((page - 1) * page_size)
            .limit(page_size)
        )
        items = []
        async for doc in cursor:
            doc["_id"] = str(doc["_id"])
            items.append(Transaction(**doc))
        return items, total

    async def delete_for_statement(self, statement_id: str) -> int:
        result = await db.transactions.delete_many({"statement_id": statement_id})
        return result.deleted_count


transaction_repo = TransactionRepository()
