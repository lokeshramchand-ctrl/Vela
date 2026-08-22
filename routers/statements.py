import logging
from datetime import datetime

from fastapi import APIRouter, BackgroundTasks, Depends, File, Form, HTTPException, Query, Request, UploadFile, status

from core.config import settings
from core.jwt_auth import get_current_user
from core.pagination import PaginationParams, resolve_sort_order, total_pages
from core.rate_limiter import limiter
from models.schemas import (
    Job,
    JobType,
    Statement,
    StatementAnalyticsResponse,
    StatementInsightsResponse,
    StatementListResponse,
    StatementResponse,
    StatementStatus,
    StatementUploadResponse,
    TransactionListResponse,
    TransactionResponse,
    TransactionType,
    User,
)
from repositories.job_repository import job_repo
from repositories.statement_repository import statement_repo
from repositories.transaction_repository import transaction_repo
from statements.pdf_parser import (
    CorruptedPDFError,
    IncorrectPasswordError,
    PasswordRequiredError,
    UnsupportedStatementError,
    statement_parser,
)
from statements.statement_service import statement_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/statements", tags=["Statements"])


async def _get_owned_statement(statement_id: str, current_user: User) -> Statement:
    """404s if the statement doesn't exist *or* belongs to someone else -
    deliberately not 403, so a caller can't tell the difference between "not
    yours" and "doesn't exist" (same posture already used for /memory/*)."""
    statement = await statement_repo.get_by_id(statement_id)
    if statement is None or statement.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Statement not found")
    return statement


def _to_statement_response(statement: Statement) -> StatementResponse:
    return StatementResponse(
        id=statement.id,
        original_filename=statement.original_filename,
        file_size_bytes=statement.file_size_bytes,
        page_count=statement.page_count,
        period_start=statement.period_start,
        period_end=statement.period_end,
        declared_sent_amount=statement.declared_sent_amount,
        declared_received_amount=statement.declared_received_amount,
        computed_sent_amount=statement.computed_sent_amount,
        computed_received_amount=statement.computed_received_amount,
        reconciliation_ok=statement.reconciliation_ok,
        transaction_count=statement.transaction_count,
        processing_status=statement.processing_status,
        current_job_id=statement.current_job_id,
        error_message=statement.error_message,
        analytics_version=statement.analytics_version,
        uploaded_at=statement.uploaded_at,
        processing_completed_at=statement.processing_completed_at,
        processing_duration_ms=statement.processing_duration_ms,
    )


@router.post("/upload", response_model=StatementUploadResponse, status_code=status.HTTP_202_ACCEPTED)
@limiter.limit("10/minute")
async def upload_statement(
    request: Request,
    background_tasks: BackgroundTasks,
    file: UploadFile = File(..., description="A Google Pay 'Transaction statement' PDF"),
    password: str | None = Form(None, description="PDF password, if the statement is password-protected"),
    current_user: User = Depends(get_current_user),
):
    """
    Validates the upload is a supported Google Pay statement, then returns
    immediately (202) with a job to poll - GET /jobs/{job_id} - while the
    actual parsing/categorization/analytics/insights pipeline runs in the
    background. The frontend should never block on this request.
    """
    if not file.filename or not file.filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="File must be a PDF.")

    raw_bytes = await file.read()
    if len(raw_bytes) > settings.MAX_STATEMENT_PDF_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"PDF exceeds the maximum allowed size of {settings.MAX_STATEMENT_PDF_BYTES} bytes.",
        )

    try:
        page_count, pdf_metadata = statement_parser.open_and_inspect(raw_bytes, password)
        full_text = statement_parser.extract_text(raw_bytes, password)
        statement_parser.validate_signature(full_text)
        period_start, period_end = statement_parser.parse_period(full_text)
        declared_sent, declared_received = statement_parser.parse_declared_totals(full_text)
    except (CorruptedPDFError, PasswordRequiredError, IncorrectPasswordError, UnsupportedStatementError) as e:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=str(e)) from e

    gridfs_file_id = await statement_repo.store_pdf(raw_bytes, file.filename)

    statement = await statement_repo.create(
        Statement(
            user_id=current_user.id,
            original_filename=file.filename,
            file_size_bytes=len(raw_bytes),
            page_count=page_count,
            pdf_metadata=pdf_metadata or None,
            gridfs_file_id=gridfs_file_id,
            period_start=period_start,
            period_end=period_end,
            declared_sent_amount=declared_sent,
            declared_received_amount=declared_received,
        )
    )

    job = await job_repo.create(
        Job(
            user_id=current_user.id,
            job_type=JobType.STATEMENT_PROCESSING,
            resource_type="statement",
            resource_id=statement.id,
        )
    )
    await statement_repo.set_job(statement.id, job.id)

    background_tasks.add_task(statement_service.process_statement, statement.id, job.id, full_text)

    logger.info("Statement %s queued for processing (job %s).", statement.id, job.id)
    return StatementUploadResponse(statement_id=statement.id, job_id=job.id, status=statement.processing_status)


@router.get("", response_model=StatementListResponse)
async def list_statements(
    pagination: PaginationParams = Depends(),
    processing_status: StatementStatus | None = Query(None),
    sort_by: str = Query("uploaded_at"),
    sort_order: str = Query("desc", pattern="^(asc|desc)$"),
    current_user: User = Depends(get_current_user),
):
    items, total = await statement_repo.list_for_user(
        current_user.id,
        pagination.page,
        pagination.page_size,
        status_filter=processing_status,
        sort_by=sort_by,
        sort_order=resolve_sort_order(sort_order),
    )
    return StatementListResponse(
        items=[_to_statement_response(s) for s in items],
        page=pagination.page,
        page_size=pagination.page_size,
        total=total,
        total_pages=total_pages(total, pagination.page_size),
    )


@router.get("/{statement_id}", response_model=StatementResponse)
async def get_statement(statement_id: str, current_user: User = Depends(get_current_user)):
    statement = await _get_owned_statement(statement_id, current_user)
    return _to_statement_response(statement)


@router.delete("/{statement_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_statement(statement_id: str, current_user: User = Depends(get_current_user)):
    """Cascades: every transaction belonging to this statement, its job
    history, and the retained original PDF. Deliberately does not touch
    behavior_patterns or Milvus vectors - those are a shared, cross-
    statement/cross-user merchant knowledge base, not this statement's data."""
    statement = await _get_owned_statement(statement_id, current_user)

    await transaction_repo.delete_for_statement(statement_id)
    await job_repo.delete_for_resource(statement_id)
    if statement.gridfs_file_id:
        await statement_repo.delete_pdf(statement.gridfs_file_id)
    await statement_repo.delete(statement_id)


@router.get("/{statement_id}/transactions", response_model=TransactionListResponse)
async def list_statement_transactions(
    statement_id: str,
    pagination: PaginationParams = Depends(),
    category: str | None = Query(None),
    transaction_type: TransactionType | None = Query(None),
    merchant: str | None = Query(None, description="Case-insensitive substring match"),
    start_date: str | None = Query(None, description="ISO 8601 date, inclusive"),
    end_date: str | None = Query(None, description="ISO 8601 date, inclusive"),
    sort_by: str = Query("timestamp"),
    sort_order: str = Query("desc", pattern="^(asc|desc)$"),
    current_user: User = Depends(get_current_user),
):
    statement = await _get_owned_statement(statement_id, current_user)

    parsed_start = datetime.fromisoformat(start_date) if start_date else None
    parsed_end = datetime.fromisoformat(end_date) if end_date else None

    items, total = await transaction_repo.list_for_statement(
        statement.id,
        current_user.id,
        pagination.page,
        pagination.page_size,
        category=category,
        transaction_type=transaction_type,
        merchant=merchant,
        start_date=parsed_start,
        end_date=parsed_end,
        sort_by=sort_by,
        sort_order=resolve_sort_order(sort_order),
    )
    return TransactionListResponse(
        items=[
            TransactionResponse(
                id=t.id,
                statement_id=t.statement_id,
                timestamp=t.timestamp,
                merchant=t.merchant,
                category=t.category,
                amount=t.amount,
                transaction_type=t.transaction_type,
                status=t.status,
                counterparty_raw=t.counterparty_raw,
                reference_number=t.reference_number,
                bank=t.bank,
                account_last4=t.account_last4,
                payment_method=t.payment_method,
            )
            for t in items
        ],
        page=pagination.page,
        page_size=pagination.page_size,
        total=total,
        total_pages=total_pages(total, pagination.page_size),
    )


def _require_completed(statement: Statement) -> None:
    if statement.processing_status != StatementStatus.COMPLETED:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                f"Statement is not yet processed (status: {statement.processing_status.value}). "
                f"Check GET /jobs/{statement.current_job_id} for progress."
            ),
        )


@router.get("/{statement_id}/analytics", response_model=StatementAnalyticsResponse)
async def get_statement_analytics(statement_id: str, current_user: User = Depends(get_current_user)):
    """Reads the analytics computed once during job processing
    (analytics/statement_analytics.py) - never recomputed per-request."""
    statement = await _get_owned_statement(statement_id, current_user)
    _require_completed(statement)
    return StatementAnalyticsResponse(statement_id=statement.id, **statement.analytics.model_dump())


@router.get("/{statement_id}/insights", response_model=StatementInsightsResponse)
async def get_statement_insights(statement_id: str, current_user: User = Depends(get_current_user)):
    """Reads the insights generated once during job processing
    (insights/statement_insights.py) - no LLM call happens on this request."""
    statement = await _get_owned_statement(statement_id, current_user)
    _require_completed(statement)
    return StatementInsightsResponse(statement_id=statement.id, insights=statement.insights)
