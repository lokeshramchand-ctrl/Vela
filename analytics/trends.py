from datetime import datetime
from typing import Any

from database.mongo import db


class TrendAnalyzer:
    async def calculate_mom_growth(self, user_id: str, current_month: int, current_year: int) -> dict[str, Any]:
        """Calculates Month-over-Month (MoM) spending velocity."""
        curr_start = datetime(current_year, current_month, 1)
        if current_month == 12:
            next_start = datetime(current_year + 1, 1, 1)
        else:
            next_start = datetime(current_year, current_month + 1, 1)

        if current_month == 1:
            prev_start = datetime(current_year - 1, 12, 1)
        else:
            prev_start = datetime(current_year, current_month - 1, 1)

        curr_total = await self._sum_spend(user_id, curr_start, next_start)
        prev_total = await self._sum_spend(user_id, prev_start, curr_start)

        if prev_total == 0:
            growth = 0.0
        else:
            growth = ((curr_total - prev_total) / prev_total) * 100

        return {
            "current_spend": curr_total,
            "previous_spend": prev_total,
            "mom_growth_percentage": round(growth, 2),
            "trend": "up" if growth > 0 else "down"
        }

    async def _sum_spend(self, user_id: str, start: datetime, end: datetime) -> float:
        pipeline = [
            {"$match": {"user_id": user_id, "timestamp": {"$gte": start, "$lt": end}}},
            {"$group": {"_id": None, "total": {"$sum": "$amount"}}}
        ]
        res = await db.transactions.aggregate(pipeline).to_list(length=1)
        return res[0]["total"] if res else 0.0

trend_analyzer = TrendAnalyzer()
