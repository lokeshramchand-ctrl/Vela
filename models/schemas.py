from datetime import UTC, date, datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator


class CoreModel(BaseModel):
    model_config = ConfigDict(populate_by_name=True, arbitrary_types_allowed=True)


class User(CoreModel):
    """Persisted shape of a `users` document. `hashed_password` never leaves
    this model - API responses use `UserPublic` instead (see below)."""
    id: str | None = Field(alias="_id", default=None)
    email: EmailStr
    hashed_password: str
    full_name: str | None = None
    is_active: bool = True
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(UTC))

    def to_public(self) -> "UserPublic":
        # Explicit field-by-field mapping rather than UserPublic(**self.model_dump())
        # so a future field added here (e.g. an MFA secret) can never leak
        # into a response just because someone forgot to also update this.
        return UserPublic(
            id=self.id, email=self.email, full_name=self.full_name,
            is_active=self.is_active, created_at=self.created_at,
        )


class UserPublic(BaseModel):
    """Safe, external-facing view of a User - deliberately a separate model
    (not User with a field excluded) so a future field added to User can
    never leak into a response by accident."""
    id: str
    email: EmailStr
    full_name: str | None
    is_active: bool
    created_at: datetime


class UpdateUserRequest(BaseModel):
    """Email is deliberately not editable here - changing it is a bigger
    reverification flow (confirm the new address, re-check the uniqueness
    index) than a simple profile PATCH, and isn't required by anything this
    API needs to support yet."""
    full_name: str | None = Field(default=None, min_length=1, max_length=200)


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=8, max_length=128)

    @field_validator("email")
    @classmethod
    def _normalize_email(cls, v: str) -> str:
        # Prevents "Foo@x.com" and "foo@x.com" from registering as two
        # distinct accounts against the case-sensitive unique index on email.
        return v.lower()


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=1, max_length=128)

    @field_validator("email")
    @classmethod
    def _normalize_email(cls, v: str) -> str:
        return v.lower()


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"  # noqa: S105 - the OAuth2/RFC 6750 scheme name, not a credential
    expires_in: int = Field(description="Access token lifetime in seconds")


class RefreshRequest(BaseModel):
    refresh_token: str = Field(..., min_length=1, max_length=1024)


class LogoutRequest(BaseModel):
    refresh_token: str = Field(..., min_length=1, max_length=1024)

class TransactionType(str, Enum):
    DEBIT = "DEBIT"    # money out ("Paid to" on a Google Pay statement)
    CREDIT = "CREDIT"  # money in ("Received from")


class TransactionStatus(str, Enum):
    SUCCESS = "SUCCESS"
    FAILED = "FAILED"
    PENDING = "PENDING"


class Transaction(CoreModel):
    id: str | None = Field(alias="_id", default=None)
    raw_text: str
    merchant: str | None = None
    amount: float
    category: str | None = None
    user_id: str = "system_user"
    is_mock: bool = False
    timestamp: datetime = Field(default_factory=lambda: datetime.now(UTC))

    # Statement-derived fields (statements/statement_service.py). All optional/
    # defaulted so the existing POST /v1/categorize write path (routers/v1.py),
    # which only ever sets the fields above, needs no changes at all.
    statement_id: str | None = None
    transaction_type: TransactionType = TransactionType.DEBIT
    status: TransactionStatus = TransactionStatus.SUCCESS
    counterparty_raw: str | None = None  # the raw "Paid to X" / "Received from X" name, pre-categorization
    reference_number: str | None = None  # UPI Transaction ID - also the dedup key, see database/mongo.py
    bank: str | None = None
    account_last4: str | None = None
    payment_method: str = "UPI"

class Feedback(CoreModel):
    id: str | None = Field(alias="_id", default=None)
    transaction_id: str
    merchant_name: str | None = None
    prediction: str
    corrected_category: str
    confidence: float
    is_correction: bool = False
    user_id: str = "system_user"
    timestamp: datetime = Field(default_factory=lambda: datetime.now(UTC))

class CategorizeRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=2000, description="Raw transaction SMS or bank statement text")

class CategorizeResponse(BaseModel):
    merchant: str
    category: str
    confidence: float
    transaction_id: str | None = None

class ResolutionResult(BaseModel):
    raw_text: str
    cleaned_text: str
    canonical_merchant: str
    confidence: float
    is_resolved: bool
    resolution_method: str = Field(description="exact_alias, substring, or none")


class MemoryState(str, Enum):
    EPHEMERAL = "EPHEMERAL"
    TEMPORARY = "TEMPORARY"
    PERMANENT = "PERMANENT"
    ARCHIVED = "ARCHIVED"

class MerchantProfile(BaseModel):
    id: str | None = Field(alias="_id", default=None)
    canonical_name: str
    display_name: str | None = None
    aliases: list[str] = Field(default_factory=list)
    entity_type: str = "Unknown"  # e.g., "Individual", "Business"

    # Phase 4 Core Variables
    memory_state: MemoryState = MemoryState.EPHEMERAL
    frequency: int = 1
    first_seen: datetime = Field(default_factory=lambda: datetime.now(UTC))
    last_seen: datetime = Field(default_factory=lambda: datetime.now(UTC))

    notes: str | None = None
    confidence: float = 0.0
    category: str | None = None
    subcategory: str | None = None



class TransactionCategory(str, Enum):
    FOOD = "Food"
    TRAVEL = "Travel"
    ENTERTAINMENT = "Entertainment"
    BILLS = "Bills"
    FRIENDS = "Friends"
    EDUCATION = "Education"
    HEALTHCARE = "Healthcare"
    SUBSCRIPTION = "Subscription"
    SHOPPING = "Shopping"
    UTILITY = "Utility"
    INCOME = "Income"  # CREDIT transactions (money received) - not run through the expense rule engine, see statements/statement_service.py
    UNKNOWN = "Unknown"

class ConfidenceEvaluation(BaseModel):
    raw_category: str
    final_category: TransactionCategory
    confidence: float
    is_hallucination_risk: bool
    calibration_applied: str

class BehaviorPattern(BaseModel):
    id: str | None = Field(alias="_id", default=None)
    merchant_name: str  # Can be a resolved name or an "Unknown" entity string

    # Statistical Amount Metrics
    avg_amount: float
    median_amount: float
    variance: float
    std_dev: float

    # Temporal & Frequency Metrics
    preferred_hour: int
    time_bucket_distribution: dict[str, float]  # e.g., {"morning": 0.7, "night": 0.3}
    weekday_distribution: list[float]          # Length 7 array representing normalized frequency per day
    daily_frequency: float                     # Average number of times seen per day
    weekly_frequency: float                    # Average number of times seen per week

    # Advanced Intelligence Metrics
    periodicity_score: float                   # 0.0 (highly random) to 1.0 (perfectly predictable interval)
    entropy_score: float                       # Measures predictability of spending amounts
    last_updated: datetime = Field(default_factory=lambda: datetime.now(UTC))


# =====================================================================
# Statement ingestion: Statement -> Transactions -> Analytics -> Insights
# (statements/*, analytics/statement_analytics.py, insights/*, routers/statements.py)
# =====================================================================

class StatementStatus(str, Enum):
    PENDING = "PENDING"
    PROCESSING = "PROCESSING"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"


class JobStatus(str, Enum):
    QUEUED = "QUEUED"
    RUNNING = "RUNNING"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"


class JobType(str, Enum):
    STATEMENT_PROCESSING = "STATEMENT_PROCESSING"


class InsightSeverity(str, Enum):
    INFO = "INFO"
    POSITIVE = "POSITIVE"
    WARNING = "WARNING"


class CategoryBreakdownItem(BaseModel):
    category: str
    total_amount: float
    count: int


class MerchantSpendItem(BaseModel):
    merchant: str
    total_amount: float
    count: int


class DailyTrendItem(BaseModel):
    date: date
    total_amount: float
    count: int


class RecurringPaymentItem(BaseModel):
    merchant: str
    estimated_monthly_cost: float
    periodicity_score: float
    occurrences: int


class StatementAnalytics(BaseModel):
    """Computed once by statements/statement_service.py during job processing
    and persisted onto the Statement document - GET /statements/{id}/analytics
    reads this back directly rather than recomputing an aggregation on every
    request."""
    total_spend: float = 0.0
    total_income: float = 0.0
    net: float = 0.0
    average_transaction_value: float = 0.0
    transaction_count: int = 0
    failed_transaction_count: int = 0  # honestly 0 for Google Pay statements - see statements/pdf_parser.py
    category_breakdown: list[CategoryBreakdownItem] = Field(default_factory=list)
    top_merchants: list[MerchantSpendItem] = Field(default_factory=list)
    daily_trend: list[DailyTrendItem] = Field(default_factory=list)
    recurring_payments: list[RecurringPaymentItem] = Field(default_factory=list)
    generated_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class InsightItem(BaseModel):
    type: str
    message: str
    severity: InsightSeverity = InsightSeverity.INFO


class Statement(CoreModel):
    id: str | None = Field(alias="_id", default=None)
    user_id: str
    original_filename: str
    file_size_bytes: int
    page_count: int | None = None
    pdf_metadata: dict[str, str] | None = None
    gridfs_file_id: str | None = None

    # Parsed from the statement itself, not assumed - see docs/23-statements-pipeline.md:
    # a Google Pay statement's period can span multiple calendar months, so
    # there is deliberately no single "statement_month"/"statement_year" field.
    period_start: date
    period_end: date

    # Reconciliation: declared_* comes from the statement's own Sent/Received
    # header; computed_* is the sum of what was actually parsed. Mismatch
    # beyond a small epsilon is a real signal something was missed - see
    # statements/statement_service.py.
    declared_sent_amount: float | None = None
    declared_received_amount: float | None = None
    computed_sent_amount: float | None = None
    computed_received_amount: float | None = None
    reconciliation_ok: bool | None = None

    # Set only once a human has reviewed a reconciliation_ok=False statement
    # via POST /controller/exceptions/{id}/resolve - see routers/controller.py.
    reconciliation_resolved: bool = False
    reconciliation_approved: bool | None = None
    reconciliation_resolved_at: datetime | None = None

    transaction_count: int = 0
    processing_status: StatementStatus = StatementStatus.PENDING
    current_job_id: str | None = None
    error_message: str | None = None

    analytics: StatementAnalytics | None = None
    insights: list[InsightItem] = Field(default_factory=list)
    analytics_version: str = "1.0"

    uploaded_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
    processing_started_at: datetime | None = None
    processing_completed_at: datetime | None = None
    processing_duration_ms: int | None = None


class Job(CoreModel):
    id: str | None = Field(alias="_id", default=None)
    user_id: str
    job_type: JobType
    resource_type: str = "statement"
    resource_id: str
    status: JobStatus = JobStatus.QUEUED
    stage: str | None = None  # e.g. "parsing", "categorizing", "generating_insights"
    progress_percent: int = 0
    error_message: str | None = None
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
    started_at: datetime | None = None
    completed_at: datetime | None = None


class StatementUploadResponse(BaseModel):
    statement_id: str
    job_id: str
    status: StatementStatus


class StatementResponse(BaseModel):
    id: str
    original_filename: str
    file_size_bytes: int
    page_count: int | None
    period_start: date
    period_end: date
    declared_sent_amount: float | None
    declared_received_amount: float | None
    computed_sent_amount: float | None
    computed_received_amount: float | None
    reconciliation_ok: bool | None
    transaction_count: int
    processing_status: StatementStatus
    current_job_id: str | None
    error_message: str | None
    analytics_version: str
    uploaded_at: datetime
    processing_completed_at: datetime | None
    processing_duration_ms: int | None


class StatementListResponse(BaseModel):
    items: list[StatementResponse]
    page: int
    page_size: int
    total: int
    total_pages: int


class TransactionResponse(BaseModel):
    id: str
    statement_id: str | None
    timestamp: datetime
    merchant: str | None
    category: str | None
    amount: float
    transaction_type: TransactionType
    status: TransactionStatus
    counterparty_raw: str | None
    reference_number: str | None
    bank: str | None
    account_last4: str | None
    payment_method: str


class TransactionListResponse(BaseModel):
    items: list[TransactionResponse]
    page: int
    page_size: int
    total: int
    total_pages: int


class StatementAnalyticsResponse(StatementAnalytics):
    statement_id: str


class StatementInsightsResponse(BaseModel):
    statement_id: str
    insights: list[InsightItem]


class JobResponse(BaseModel):
    id: str
    job_type: JobType
    resource_type: str
    resource_id: str
    status: JobStatus
    stage: str | None
    progress_percent: int
    error_message: str | None
    created_at: datetime
    started_at: datetime | None
    completed_at: datetime | None
