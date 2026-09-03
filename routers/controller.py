from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Path
from pydantic import BaseModel, Field
from typing import List

from core.jwt_auth import get_current_user
from models.schemas import Statement, User
from repositories.statement_repository import statement_repo

router = APIRouter(prefix="/controller", tags=["Controller"])

# Mirrors statements/statement_service.py::_RECONCILIATION_EPSILON - used
# here to figure out *which* side (sent/received) of an already-flagged
# statement actually mismatched, since Statement.reconciliation_ok only
# stores the combined AND of both checks.
_RECONCILIATION_EPSILON = 0.01


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

class CashPositionResponse(BaseModel):
    opening_balance: float
    verified_inflows: float
    verified_outflows: float
    expected_closing_balance: float
    reported_closing_balance: float
    variance: float
    contributing_exceptions: List[TransactionExceptionResponse]


def _mismatched_sides(statement: Statement) -> list[str]:
    """Which of declared-vs-computed sent/received actually differ beyond
    tolerance. Statement.reconciliation_ok is a single AND of both checks
    (statements/statement_service.py::_check_reconciliation), so recovering
    which side is responsible has to redo the per-side comparison."""
    sides = []
    if statement.declared_sent_amount is None or statement.declared_received_amount is None:
        return sides
    if abs(statement.computed_sent_amount - statement.declared_sent_amount) >= _RECONCILIATION_EPSILON:
        sides.append("sent")
    if abs(statement.computed_received_amount - statement.declared_received_amount) >= _RECONCILIATION_EPSILON:
        sides.append("received")
    return sides


def _exception_for_side(statement: Statement, side: str) -> TransactionExceptionResponse:
    declared = statement.declared_sent_amount if side == "sent" else statement.declared_received_amount
    computed = statement.computed_sent_amount if side == "sent" else statement.computed_received_amount
    diff = abs(computed - declared)
    period_end = datetime.combine(statement.period_end, datetime.min.time())

    return TransactionExceptionResponse(
        id=f"{statement.id}:{side}",
        source_a_merchant=f"{statement.original_filename} (declared)",
        source_a_amount=declared,
        source_a_date=period_end,
        source_b_merchant=f"{statement.original_filename} (computed from transactions)",
        source_b_amount=computed,
        source_b_date=period_end,
        issue=f"{side.capitalize()} amount mismatch",
        confidence=1.0,
        reason=(
            f"Statement declares {side} amount {declared:.2f}, but the parsed "
            f"transactions sum to {computed:.2f} - a difference of {diff:.2f}, "
            f"which exceeds the {_RECONCILIATION_EPSILON} reconciliation tolerance."
        ),
    )


async def _pending_exceptions(user_id: str) -> tuple[list[TransactionExceptionResponse], list[Statement]]:
    statements = await statement_repo.list_completed_for_user(user_id)
    flagged = [s for s in statements if s.reconciliation_ok is False and not s.reconciliation_resolved]
    exceptions = [
        _exception_for_side(statement, side)
        for statement in flagged
        for side in (_mismatched_sides(statement) or ["sent"])
    ]
    return exceptions, statements


@router.get("/stats", response_model=ReconciliationStatsResponse)
async def get_reconciliation_stats(current_user: User = Depends(get_current_user)):
    """
    Returns reconciliation statistics computed from the current user's
    completed statements: each statement's declared (from its own Sent/
    Received header) vs computed (summed from parsed transactions) totals
    are compared to classify it as matched, an exception, or unresolved
    (declared totals weren't available to check against at all).
    """
    statements = await statement_repo.list_completed_for_user(current_user.id)

    records_processed = sum(s.transaction_count for s in statements)
    matched_statements = [s for s in statements if s.reconciliation_ok is True]
    exception_statements = [s for s in statements if s.reconciliation_ok is False]
    unresolved_statements = [s for s in statements if s.reconciliation_ok is None]

    matched = sum(s.transaction_count for s in matched_statements)
    exceptions = sum(s.transaction_count for s in exception_statements)
    unresolved = sum(s.transaction_count for s in unresolved_statements)
    match_rate = matched / records_processed if records_processed else 0.0
    amount_reconciled = sum(
        (s.computed_sent_amount or 0.0) + (s.computed_received_amount or 0.0) for s in matched_statements
    )

    return ReconciliationStatsResponse(
        records_processed=records_processed,
        matched=matched,
        exceptions=exceptions,
        unresolved=unresolved,
        match_rate=match_rate,
        amount_reconciled=amount_reconciled,
    )

@router.get("/exceptions", response_model=ExceptionsListResponse)
async def get_exceptions(current_user: User = Depends(get_current_user)):
    """
    Returns pending exceptions: completed statements whose declared totals
    don't match their computed (parsed-transaction) totals, and that haven't
    already been resolved via POST /exceptions/{id}/resolve.
    """
    exceptions, _ = await _pending_exceptions(current_user.id)
    return ExceptionsListResponse(exceptions=exceptions)

@router.get("/cash-position", response_model=CashPositionResponse)
async def get_cash_position(current_user: User = Depends(get_current_user)):
    """
    Reconciles the user's cash position across all completed statements:
    verified inflows/outflows are the computed (parsed-transaction) sums,
    while the reported closing balance uses each statement's own declared
    totals. Any variance is attributed to the still-open exceptions that
    could explain it.
    """
    exceptions, statements = await _pending_exceptions(current_user.id)

    opening_balance = 0.0  # No account-balance ledger exists in this app; each statement is a self-contained period.
    verified_inflows = sum(s.computed_received_amount or 0.0 for s in statements)
    verified_outflows = sum(s.computed_sent_amount or 0.0 for s in statements)
    expected_closing_balance = opening_balance + verified_inflows - verified_outflows

    declared_statements = [s for s in statements if s.declared_sent_amount is not None]
    reported_inflows = sum(s.declared_received_amount or 0.0 for s in declared_statements)
    reported_outflows = sum(s.declared_sent_amount or 0.0 for s in declared_statements)
    reported_closing_balance = opening_balance + reported_inflows - reported_outflows

    variance = reported_closing_balance - expected_closing_balance

    return CashPositionResponse(
        opening_balance=opening_balance,
        verified_inflows=verified_inflows,
        verified_outflows=verified_outflows,
        expected_closing_balance=expected_closing_balance,
        reported_closing_balance=reported_closing_balance,
        variance=variance,
        contributing_exceptions=exceptions,
    )

@router.post("/exceptions/{exception_id}/resolve")
async def resolve_exception(
    exception_id: str = Path(..., min_length=1),
    request: ResolveExceptionRequest = None,
    current_user: User = Depends(get_current_user),
):
    """
    Resolves an exception (statement_id:side) by approving or rejecting the
    flagged declared-vs-computed mismatch. Persists to the statement itself
    so it drops out of future /exceptions and /cash-position responses.
    """
    if request is None:
        raise HTTPException(status_code=400, detail="Request body is required")

    statement_id, _, side = exception_id.partition(":")
    statement = await statement_repo.get_by_id(statement_id)
    if (
        statement is None
        or statement.user_id != current_user.id
        or statement.reconciliation_ok is not False
        or side not in ("sent", "received")
    ):
        raise HTTPException(status_code=404, detail="Exception not found")

    await statement_repo.mark_reconciliation_resolved(statement_id, request.approved)

    return {
        "success": True,
        "exception_id": exception_id,
        "approved": request.approved,
        "resolved_at": datetime.now().isoformat(),
    }
