import re
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, Field

from core.jwt_auth import get_current_user
from core.rate_limiter import limiter
from database.mongo import db
from engines.confidence_engine import confidence_engine
from engines.rule_engine import rule_engine
from models.schemas import CategorizeRequest, CategorizeResponse, ConfidenceEvaluation, ResolutionResult, User
from services.merchant_resolver import merchant_resolver

router = APIRouter(prefix="/v1", tags=["Transaction Intelligence"])

@router.post("/categorize", response_model=CategorizeResponse)
@limiter.limit("50/minute")
async def categorize_transaction(
    request: Request, payload: CategorizeRequest, current_user: User = Depends(get_current_user)
):
    # Process text through the Rule Engine
    result = rule_engine.categorize(payload.text)

    # Per-request latency is already captured automatically for every route by
    # prometheus_fastapi_instrumentator (see app.py) - no need to hand-roll it here.
    amount = 0.0
    text_content = payload.text
    amount_match = re.search(r'₹\s*([0-9.,]+)', text_content)
    if amount_match:
        amount = float(amount_match.group(1).replace(',', ''))

    # 2. Save the fully enriched transaction to MongoDB
    insert_result = await db.transactions.insert_one({
        "user_id": current_user.id,
        "raw_text": text_content,
        "merchant": result["merchant"],
        "category": result["category"],
        "amount": amount,
        "confidence": result["confidence"],
        "timestamp": datetime.now(UTC)
    })

    return {**result, "transaction_id": str(insert_result.inserted_id)}

class ResolveRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=2000)

@router.post("/resolve", response_model=ResolutionResult)
async def resolve_transaction_merchant(request: ResolveRequest):
    """
    Phase 3 Endpoint: Takes a raw UPI/Bank transaction string and resolves it to a canonical merchant.
    """
    result = await merchant_resolver.resolve(request.text)
    return result

class MockModelPrediction(BaseModel):
    predicted_category: str = Field(..., min_length=1, max_length=100)
    raw_confidence: float = Field(..., ge=0.0, le=1.0)

@router.post("/confidence/evaluate", response_model=ConfidenceEvaluation)
async def evaluate_prediction_confidence(request: MockModelPrediction):
    """
    Phase 5 Endpoint: Evaluates an upstream category prediction.
    Forces the response to 'Unknown' if the confidence wall is breached.
    """
    evaluation = confidence_engine.evaluate(
        predicted_category=request.predicted_category,
        raw_confidence=request.raw_confidence
    )
    return evaluation
