"""Bank statement ingestion service for creating CanonicalFinancialRecords.

This module handles bank statement PDF processing and ingestion, creating
CanonicalFinancialRecords with source="bank_statement" or "synthetic_bank".
It integrates with the CanonicalRecordRepository to persist records."""

from datetime import datetime, UTC
from typing import Any

from models.schemas import CanonicalFinancialRecord, TransactionType, TransactionStatus


class BankStatementRecord:
    """Data class representing a parsed bank statement line."""

    def __init__(
        self,
        transaction_id: str,
        date: datetime,
        description: str,
        amount: float,
        is_debit: bool,
        merchant: str,
        reference_id: str | None = None,
        metadata: dict[str, Any] | None = None,
    ):
        """Initialize a bank statement record.

        Args:
            transaction_id: Unique ID for this transaction
            date: Transaction date
            description: Full transaction description
            amount: Amount in base currency
            is_debit: True if money went out, False if money came in
            merchant: Merchant or counterparty name
            reference_id: Optional check/reference number
            metadata: Optional additional data (bank, account, etc.)
        """
        self.transaction_id = transaction_id
        self.date = date
        self.description = description
        self.amount = abs(amount)
        self.is_debit = is_debit
        self.merchant = merchant
        self.reference_id = reference_id
        self.metadata = metadata or {}


class BankStatementService:
    """Converts bank statement records to CanonicalFinancialRecords."""

    def __init__(self, user_id: str, source_name: str = "bank_statement"):
        """Initialize the service.

        Args:
            user_id: User identifier
            source_name: Source identifier (e.g., "bank_statement", "synthetic_bank")
        """
        self.user_id = user_id
        self.source_name = source_name

    def process_statements(
        self,
        parsed_records: list[BankStatementRecord],
        statement_metadata: dict[str, Any] | None = None,
    ) -> list[CanonicalFinancialRecord]:
        """Convert parsed bank statement records to CanonicalFinancialRecords.

        Args:
            parsed_records: List of BankStatementRecord objects
            statement_metadata: Metadata about the statement itself (bank, account, etc.)

        Returns:
            List of CanonicalFinancialRecords
        """
        statement_metadata = statement_metadata or {}
        canonical_records = []

        for record in parsed_records:
            canonical = self._build_canonical_record(record, statement_metadata)
            canonical_records.append(canonical)

        return canonical_records

    def _build_canonical_record(
        self, record: BankStatementRecord, statement_metadata: dict[str, Any]
    ) -> CanonicalFinancialRecord:
        """Build a single CanonicalFinancialRecord from a bank statement record.

        Args:
            record: Parsed bank statement record
            statement_metadata: Statement-level metadata

        Returns:
            CanonicalFinancialRecord
        """
        return CanonicalFinancialRecord(
            source=self.source_name,
            source_record_id=record.transaction_id,
            user_id=self.user_id,
            timestamp=record.date,
            amount=record.amount,
            currency="INR",
            merchant_raw=record.merchant,
            merchant_normalized=None,  # Will be filled by normalization service
            transaction_type=TransactionType.DEBIT if record.is_debit else TransactionType.CREDIT,
            status=TransactionStatus.SUCCESS,
            reference_id=record.reference_id,
            description=record.description,
            category=None,  # Will be filled by categorization service
            metadata={
                **statement_metadata,
                **record.metadata,
                "original_description": record.description,
                "is_debit": record.is_debit,
            },
        )

    @staticmethod
    def parse_gpay_pdf(pdf_content: bytes, user_id: str, account_info: dict[str, str]) -> list[
        CanonicalFinancialRecord
    ]:
        """Parse a GPay PDF export and create CanonicalFinancialRecords.

        Note: This is a stub for the MVP. Real PDF parsing would be added in later iterations.

        Args:
            pdf_content: Raw PDF bytes
            user_id: User identifier
            account_info: Account metadata (bank, account_last4, etc.)

        Returns:
            List of CanonicalFinancialRecords from the PDF
        """
        raise NotImplementedError(
            "GPay PDF parsing is not implemented in this MVP. "
            "Use synthetic_data_generator for testing."
        )

    @staticmethod
    def parse_bank_statement_pdf(
        pdf_content: bytes, user_id: str, bank_name: str, account_last4: str
    ) -> list[CanonicalFinancialRecord]:
        """Parse a bank statement PDF and create CanonicalFinancialRecords.

        Note: This is a stub for the MVP. Real PDF parsing would be added in later iterations.
        For testing, use synthetic_data_generator which produces CanonicalFinancialRecords directly.

        Args:
            pdf_content: Raw PDF bytes
            user_id: User identifier
            bank_name: Name of the bank
            account_last4: Last 4 digits of account

        Returns:
            List of CanonicalFinancialRecords from the statement
        """
        raise NotImplementedError(
            "Bank statement PDF parsing is not implemented in this MVP. "
            "Use synthetic_data_generator for testing."
        )
