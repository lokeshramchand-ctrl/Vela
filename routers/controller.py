from datetime import datetime
from fastapi import APIRouter, HTTPException, Path
from pydantic import BaseModel, Field
from typing import List

router = APIRouter(prefix="/controller", tags=["Controller"])

class ReconciliationStatsResponse(BaseModel):
    records_processed: int
    matched: int
    exceptions: int
    unresolved: int
    match_rate: float
    amount_reconciled: float

class TransactionExceptionResponse(BaseModel):
    id: str
    source_a_merchant: str
    source_a_amount: float
    source_a_date: datetime
    source_b_merchant: str
    source_b_amount: float
    source_b_date: datetime
    issue: str
    confidence: float
    reason: str

class ExceptionsListResponse(BaseModel):
    exceptions: List[TransactionExceptionResponse]

class ResolveExceptionRequest(BaseModel):
    approved: bool

@router.get("/stats", response_model=ReconciliationStatsResponse)
async def get_reconciliation_stats():
    """
    Returns current reconciliation statistics: records processed, matched,
    exceptions, unresolved count, match rate, and total amount reconciled.
    """
    return ReconciliationStatsResponse(
        records_processed=250,
        matched=221,
        exceptions=21,
        unresolved=8,
        match_rate=0.884,
        amount_reconciled=482300.0,
    )

@router.get("/exceptions", response_model=ExceptionsListResponse)
async def get_exceptions():
    """
    Returns list of all pending exceptions awaiting review/resolution.
    """
    return ExceptionsListResponse(
        exceptions=[
            TransactionExceptionResponse(
                id="1",
                source_a_merchant="Amazon",
                source_a_amount=2499.0,
                source_a_date=datetime(2026, 8, 10),
                source_b_merchant="Amazon Pay",
                source_b_amount=2599.0,
                source_b_date=datetime(2026, 8, 10),
                issue="Amount mismatch",
                confidence=0.98,
                reason="Merchant and date align, but amounts differ by ₹100.",
            ),
            TransactionExceptionResponse(
                id="2",
                source_a_merchant="Swiggy",
                source_a_amount=450.0,
                source_a_date=datetime(2026, 8, 15),
                source_b_merchant="Swiggy Eats",
                source_b_amount=460.0,
                source_b_date=datetime(2026, 8, 14),
                issue="Partial date mismatch",
                confidence=0.72,
                reason="Merchant names differ slightly and transactions are on different days.",
            ),
            TransactionExceptionResponse(
                id="3",
                source_a_merchant="Uber India",
                source_a_amount=382.0,
                source_a_date=datetime(2026, 8, 12),
                source_b_merchant="Uber Eats",
                source_b_amount=385.0,
                source_b_date=datetime(2026, 8, 12),
                issue="Merchant name variant",
                confidence=0.65,
                reason="Could be Uber Eats vs regular Uber. Amount variance is within 1%.",
            ),
        ]
    )

@router.post("/exceptions/{exception_id}/resolve")
async def resolve_exception(
    exception_id: str = Path(..., min_length=1),
    request: ResolveExceptionRequest = None,
):
    """
    Resolves an exception by approving or rejecting the proposed match.
    """
    if request is None:
        raise HTTPException(status_code=400, detail="Request body is required")

    return {
        "success": True,
        "exception_id": exception_id,
        "approved": request.approved,
        "resolved_at": datetime.now().isoformat(),
    }
