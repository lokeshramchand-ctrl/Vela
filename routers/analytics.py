from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, Query

from analytics.anomaly_detection import anomaly_detector
from analytics.spending_patterns import spending_patterns
from analytics.subscriptions import subscription_engine
from analytics.trends import trend_analyzer
from core.jwt_auth import get_current_user
from models.schemas import User

router = APIRouter(prefix="/v1/analytics", tags=["Analytics Engine"])

@router.get("/patterns/categories")
async def get_category_patterns(
    days: int = Query(30, description="Lookback window in days"),
    current_user: User = Depends(get_current_user),
):
    end_date = datetime.now(UTC)
    start_date = end_date - timedelta(days=days)

    return await spending_patterns.get_category_breakdown(current_user.id, start_date, end_date)

@router.get("/patterns/merchants")
async def get_top_merchants(limit: int = 5, current_user: User = Depends(get_current_user)):
    return await spending_patterns.get_merchant_frequency(current_user.id, limit)

@router.get("/subscriptions")
async def get_subscriptions(current_user: User = Depends(get_current_user)):
    subs = await subscription_engine.identify_active_subscriptions(current_user.id)
    total_burn = sum(sub["estimated_monthly_cost"] for sub in subs)
    return {
        "active_subscriptions": len(subs),
        "total_monthly_burn": total_burn,
        "details": subs
    }

@router.get("/trends/mom")
async def get_mom_trends(current_user: User = Depends(get_current_user)):
    now = datetime.now(UTC)
    return await trend_analyzer.calculate_mom_growth(current_user.id, now.month, now.year)

@router.post("/anomaly/check")
async def check_anomaly(merchant: str, amount: float):
    """Real-time evaluation for the transaction ingestion pipeline. Not
    user-scoped (a merchant/amount pair is evaluated against that merchant's
    global behavioral profile, not any one user's history) - API-key auth
    only, like /v1/resolve and /v1/confidence/evaluate."""
    return await anomaly_detector.flag_transaction(merchant, amount)
