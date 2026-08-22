from datetime import datetime
from typing import Any

from database.mongo import db
from models.schemas import (
    CategoryBreakdownItem,
    DailyTrendItem,
    MerchantSpendItem,
    RecurringPaymentItem,
    StatementAnalytics,
    TransactionStatus,
    TransactionType,
)


class StatementAnalyticsEngine:
    """Same aggregation style as analytics/spending_patterns.py,
    analytics/subscriptions.py, etc., but scoped to one statement
    (user_id + statement_id) instead of an open-ended date range - a
    statement's transaction set is already exact and bounded, so there's no
    need to guess a window. Computed once by statements/statement_service.py
    during job processing and persisted onto the Statement document; GET
    /statements/{id}/analytics reads that back rather than recomputing."""

    async def compute(self, user_id: str, statement_id: str) -> StatementAnalytics:
        base_match = {"user_id": user_id, "statement_id": statement_id}

        totals = await self._compute_totals(base_match)
        category_breakdown = await self._category_breakdown(base_match)
        top_merchants = await self._top_merchants(base_match)
        daily_trend = await self._daily_trend(base_match)
        recurring_payments = await self._recurring_payments(base_match)
        failed_count = await db.transactions.count_documents(
            {**base_match, "status": TransactionStatus.FAILED.value}
        )

        return StatementAnalytics(
            total_spend=totals["total_spend"],
            total_income=totals["total_income"],
            net=round(totals["total_income"] - totals["total_spend"], 2),
            average_transaction_value=totals["average_transaction_value"],
            transaction_count=totals["transaction_count"],
            failed_transaction_count=failed_count,
            category_breakdown=category_breakdown,
            top_merchants=top_merchants,
            daily_trend=daily_trend,
            recurring_payments=recurring_payments,
        )

    async def _compute_totals(self, base_match: dict[str, Any]) -> dict[str, Any]:
        pipeline = [
            {"$match": base_match},
            {
                "$group": {
                    "_id": None,
                    "total_spend": {
                        "$sum": {"$cond": [{"$eq": ["$transaction_type", TransactionType.DEBIT.value]}, "$amount", 0]}
                    },
                    "total_income": {
                        "$sum": {"$cond": [{"$eq": ["$transaction_type", TransactionType.CREDIT.value]}, "$amount", 0]}
                    },
                    "transaction_count": {"$sum": 1},
                    "amount_sum": {"$sum": "$amount"},
                }
            },
        ]
        result = await db.transactions.aggregate(pipeline).to_list(length=1)
        if not result:
            return {"total_spend": 0.0, "total_income": 0.0, "transaction_count": 0, "average_transaction_value": 0.0}

        row = result[0]
        avg = row["amount_sum"] / row["transaction_count"] if row["transaction_count"] else 0.0
        return {
            "total_spend": round(row["total_spend"], 2),
            "total_income": round(row["total_income"], 2),
            "transaction_count": row["transaction_count"],
            "average_transaction_value": round(avg, 2),
        }

    async def _category_breakdown(self, base_match: dict[str, Any]) -> list[CategoryBreakdownItem]:
        pipeline = [
            {"$match": base_match},
            {"$group": {"_id": "$category", "total_amount": {"$sum": "$amount"}, "count": {"$sum": 1}}},
            {"$sort": {"total_amount": -1}},
        ]
        return [
            CategoryBreakdownItem(category=doc["_id"] or "Unknown", total_amount=doc["total_amount"], count=doc["count"])
            async for doc in db.transactions.aggregate(pipeline)
        ]

    async def _top_merchants(self, base_match: dict[str, Any], limit: int = 10) -> list[MerchantSpendItem]:
        # DEBIT only: "top merchants" means "where you spend", not "who sent you money".
        pipeline = [
            {"$match": {**base_match, "transaction_type": TransactionType.DEBIT.value}},
            {"$group": {"_id": "$merchant", "total_amount": {"$sum": "$amount"}, "count": {"$sum": 1}}},
            {"$sort": {"total_amount": -1}},
            {"$limit": limit},
        ]
        return [
            MerchantSpendItem(merchant=doc["_id"] or "Unknown", total_amount=doc["total_amount"], count=doc["count"])
            async for doc in db.transactions.aggregate(pipeline)
        ]

    async def _daily_trend(self, base_match: dict[str, Any]) -> list[DailyTrendItem]:
        pipeline = [
            {"$match": {**base_match, "transaction_type": TransactionType.DEBIT.value}},
            {
                "$group": {
                    "_id": {"$dateToString": {"format": "%Y-%m-%d", "date": "$timestamp"}},
                    "total_amount": {"$sum": "$amount"},
                    "count": {"$sum": 1},
                }
            },
            {"$sort": {"_id": 1}},
        ]
        return [
            DailyTrendItem(
                date=datetime.strptime(doc["_id"], "%Y-%m-%d").date(),
                total_amount=doc["total_amount"],
                count=doc["count"],
            )
            async for doc in db.transactions.aggregate(pipeline)
        ]

    async def _recurring_payments(
        self, base_match: dict[str, Any], min_periodicity: float = 0.85
    ) -> list[RecurringPaymentItem]:
        """Same periodicity-score join analytics/subscriptions.py already
        does, scoped to this statement's transactions. behavior_patterns
        itself stays a global, cross-statement/cross-user merchant knowledge
        base (see statements/statement_service.py) - only the transaction
        side of this join is statement-scoped."""
        pipeline = [
            {"$match": {**base_match, "transaction_type": TransactionType.DEBIT.value}},
            {"$group": {"_id": "$merchant", "last_amount": {"$last": "$amount"}, "occurrences": {"$sum": 1}}},
            {
                "$lookup": {
                    "from": "behavior_patterns",
                    "localField": "_id",
                    "foreignField": "merchant_name",
                    "as": "behavior",
                }
            },
            {"$unwind": "$behavior"},
            {"$match": {"behavior.periodicity_score": {"$gte": min_periodicity}}},
        ]
        return [
            RecurringPaymentItem(
                merchant=doc["_id"],
                estimated_monthly_cost=doc["last_amount"],
                periodicity_score=doc["behavior"]["periodicity_score"],
                occurrences=doc["occurrences"],
            )
            async for doc in db.transactions.aggregate(pipeline)
        ]


statement_analytics_engine = StatementAnalyticsEngine()
