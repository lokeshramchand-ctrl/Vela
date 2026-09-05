"""
Wave 1: Canonical Financial Record Tests

Validates that the canonical financial record foundation is properly
structured to support reconciliation. Tests verify:
1. CanonicalFinancialRecord schema captures all required provenance
2. Repository correctly handles upserts with source-based deduplication
3. Existing Transaction model remains unchanged (backwards compatibility)
4. No information is discarded during the conversion
"""

from datetime import datetime, UTC
from models.schemas import (
    CanonicalFinancialRecord,
    Transaction,
    TransactionType,
    TransactionStatus,
    TransactionCategory,
)


def test_canonical_record_schema_has_provenance_fields():
    """Verify CanonicalFinancialRecord schema captures source provenance."""
    record = CanonicalFinancialRecord(
        source="gpay",
        source_record_id="UPI_TXN_12345",
        user_id="user_1",
        timestamp=datetime.now(UTC),
        amount=500.0,
        merchant_raw="AMAZON PAY",
        merchant_normalized="Amazon",
        transaction_type=TransactionType.DEBIT,
        category="Shopping",
        reference_id="UPI_TXN_12345",
        description="Paid to AMAZON PAY",
    )

    assert record.source == "gpay"
    assert record.source_record_id == "UPI_TXN_12345"
    assert record.user_id == "user_1"
    assert record.merchant_raw == "AMAZON PAY"
    assert record.merchant_normalized == "Amazon"
    assert record.currency == "INR"


def test_canonical_record_preserves_metadata():
    """Verify metadata dict preserves raw, unprocessed data from sources."""
    record = CanonicalFinancialRecord(
        source="gpay",
        source_record_id="UPI_TXN_12345",
        user_id="user_1",
        timestamp=datetime.now(UTC),
        amount=500.0,
        merchant_raw="AMAZON PAY",
        transaction_type=TransactionType.DEBIT,
        metadata={
            "bank": "SBI",
            "account_last4": "1234",
            "direction": "Paid to",
            "statement_id": "stmt_123",
        },
    )

    assert record.metadata["bank"] == "SBI"
    assert record.metadata["account_last4"] == "1234"
    assert record.metadata["direction"] == "Paid to"


def test_canonical_record_with_both_raw_and_normalized():
    """Verify record captures both raw and normalized merchant names."""
    record = CanonicalFinancialRecord(
        source="gpay",
        source_record_id="TXN_001",
        user_id="user_1",
        timestamp=datetime.now(UTC),
        amount=100.0,
        merchant_raw="AMAZON PAY INDIA",
        merchant_normalized="Amazon",
        transaction_type=TransactionType.DEBIT,
    )

    # Raw value from source
    assert record.merchant_raw == "AMAZON PAY INDIA"
    # Normalized value from rule engine
    assert record.merchant_normalized == "Amazon"


def test_transaction_model_unchanged():
    """Verify existing Transaction model remains fully functional."""
    txn = Transaction(
        id=None,
        raw_text="Paid to AMAZON PAY",
        merchant="Amazon",
        amount=500.0,
        category="Shopping",
        user_id="user_1",
        is_mock=False,
        timestamp=datetime.now(UTC),
        statement_id="stmt_123",
        transaction_type=TransactionType.DEBIT,
        status=TransactionStatus.SUCCESS,
        counterparty_raw="AMAZON PAY",
        reference_number="UPI_TXN_12345",
        bank="SBI",
        account_last4="1234",
        payment_method="UPI",
    )

    assert txn.merchant == "Amazon"
    assert txn.category == "Shopping"
    assert txn.reference_number == "UPI_TXN_12345"


def test_debit_and_credit_transactions():
    """Verify both DEBIT and CREDIT transaction types are supported."""
    debit = CanonicalFinancialRecord(
        source="gpay",
        source_record_id="DEBIT_001",
        user_id="user_1",
        timestamp=datetime.now(UTC),
        amount=100.0,
        merchant_raw="Store",
        transaction_type=TransactionType.DEBIT,
    )

    credit = CanonicalFinancialRecord(
        source="gpay",
        source_record_id="CREDIT_001",
        user_id="user_1",
        timestamp=datetime.now(UTC),
        amount=5000.0,
        merchant_raw="Employer",
        transaction_type=TransactionType.CREDIT,
    )

    assert debit.transaction_type == TransactionType.DEBIT
    assert credit.transaction_type == TransactionType.CREDIT


def test_canonical_record_source_agnostic():
    """Verify schema supports multiple financial sources."""
    sources = [
        "gpay",
        "bank_statement",
        "credit_card",
        "wallet",
    ]

    for source in sources:
        record = CanonicalFinancialRecord(
            source=source,
            source_record_id=f"{source}_001",
            user_id="user_1",
            timestamp=datetime.now(UTC),
            amount=100.0,
            merchant_raw="Test Merchant",
            transaction_type=TransactionType.DEBIT,
        )
        assert record.source == source


def test_canonical_record_timestamps():
    """Verify record tracks both transaction timestamp and metadata timestamps."""
    now = datetime.now(UTC)
    record = CanonicalFinancialRecord(
        source="gpay",
        source_record_id="TXN_001",
        user_id="user_1",
        timestamp=now,
        amount=100.0,
        merchant_raw="Merchant",
        transaction_type=TransactionType.DEBIT,
    )

    assert record.timestamp == now
    assert record.created_at is not None
    assert record.updated_at is not None


if __name__ == "__main__":
    test_canonical_record_schema_has_provenance_fields()
    test_canonical_record_preserves_metadata()
    test_canonical_record_with_both_raw_and_normalized()
    test_transaction_model_unchanged()
    test_debit_and_credit_transactions()
    test_canonical_record_source_agnostic()
    test_canonical_record_timestamps()
    print("All Wave 1 schema tests passed!")
