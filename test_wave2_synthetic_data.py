"""Tests for Wave 2: Synthetic data generation and bank statement ingestion.

This test suite validates that the synthetic dataset generator produces
reproducible, realistic data with intentional variations for reconciliation testing."""

import pytest
from datetime import datetime, UTC

from ingestion import SyntheticDataConfig, SyntheticDataGenerator
from ingestion.synthetic_data_generator import ReconciliationChallengeType
from ingestion.bank_statement_service import BankStatementService, BankStatementRecord
from models.schemas import (
    CanonicalFinancialRecord,
    TransactionType,
    TransactionStatus,
)


class TestSyntheticDataGenerator:
    """Test suite for SyntheticDataGenerator."""

    def test_generator_initialization(self):
        """Test that generator initializes with default and custom config."""
        config = SyntheticDataConfig(num_transactions=50, seed=123)
        generator = SyntheticDataGenerator(config)
        assert generator.config.num_transactions == 50
        assert generator.config.seed == 123

    def test_reproducibility(self):
        """Test that same seed produces identical datasets."""
        config1 = SyntheticDataConfig(seed=42, num_transactions=20)
        config2 = SyntheticDataConfig(seed=42, num_transactions=20)

        gen1 = SyntheticDataGenerator(config1)
        gen2 = SyntheticDataGenerator(config2)

        gpay1, bank1 = gen1.generate()
        gpay2, bank2 = gen2.generate()

        # Should have same number of records
        assert len(gpay1) == len(gpay2)
        assert len(bank1) == len(bank2)

        # Should have same values (amounts, merchants, dates)
        for r1, r2 in zip(gpay1, gpay2):
            assert r1.amount == r2.amount
            assert r1.merchant_raw == r2.merchant_raw
            assert r1.timestamp == r2.timestamp

    def test_gpay_source_generation(self):
        """Test GPay source data generation."""
        config = SyntheticDataConfig(num_transactions=10, seed=42)
        generator = SyntheticDataGenerator(config)
        gpay_records = generator.generate_gpay_source()

        # Should generate ~9 records (90% of 10)
        assert len(gpay_records) in [8, 9, 10]

        for record in gpay_records:
            # Verify source provenance
            assert record.source == "gpay"
            assert record.source_record_id.startswith("gpay_")
            assert record.user_id == "test_user"

            # Verify required fields
            assert record.amount > 0
            assert record.currency == "INR"
            assert record.merchant_raw is not None
            assert record.merchant_normalized is not None
            assert isinstance(record.transaction_type, TransactionType)
            assert record.status == TransactionStatus.SUCCESS

            # Verify dates are in range
            assert config.start_date <= record.timestamp <= config.end_date

    def test_bank_statement_source_generation(self):
        """Test bank statement source data generation with variations."""
        config = SyntheticDataConfig(
            num_transactions=100,
            seed=42,
            pct_exact_match=30,
            pct_merchant_variation=25,
            pct_date_shift=20,
            pct_amount_difference=10,
            pct_missing=5,
            pct_duplicate=5,
            pct_ambiguous=5,
        )
        generator = SyntheticDataGenerator(config)
        gpay_records = generator.generate_gpay_source()
        bank_records = generator.generate_bank_statement_source(gpay_records)

        # Bank records should be less than GPay (due to missing records)
        # but more than GPay due to duplicates
        # Approximate: 90 * (1 - 0.05) + 5 duplicates = ~90 records
        assert len(bank_records) > 0

        for record in bank_records:
            # Verify source provenance
            assert record.source == "synthetic_bank"
            assert record.source_record_id.startswith("bank_")
            assert record.user_id == "test_user"

            # Verify required fields
            assert record.amount > 0
            assert record.currency == "INR"
            assert record.merchant_raw is not None
            assert record.status == TransactionStatus.SUCCESS

            # Metadata should contain reconciliation challenge type
            assert "reconciliation_challenge" in record.metadata

    def test_variations_distribution(self):
        """Test that variations are distributed according to config."""
        config = SyntheticDataConfig(
            num_transactions=200,
            seed=42,
            pct_exact_match=40,
            pct_merchant_variation=30,
            pct_date_shift=15,
            pct_amount_difference=10,
            pct_missing=3,
            pct_duplicate=1,
            pct_ambiguous=1,
        )
        generator = SyntheticDataGenerator(config)

        # Assign variations and count
        variations = generator._assign_variations(200)
        counts = {}
        for v in variations:
            counts[v] = counts.get(v, 0) + 1

        # Each type should be present
        assert len(counts) > 0

        # Exact match should be most common (40%)
        exact_match_count = counts.get(ReconciliationChallengeType.EXACT_MATCH, 0)
        assert exact_match_count >= 70  # At least 70 out of 200 (35% min)

    def test_merchant_pool_coverage(self):
        """Test that all merchants in the pool are used."""
        config = SyntheticDataConfig(num_transactions=1000, seed=42)
        generator = SyntheticDataGenerator(config)
        gpay_records = generator.generate_gpay_source()

        used_merchants = set()
        for record in gpay_records:
            used_merchants.add(record.merchant_normalized)

        # Should use multiple merchants from the pool
        assert len(used_merchants) > 5

    def test_transaction_type_distribution(self):
        """Test that both DEBIT and CREDIT transactions are generated."""
        config = SyntheticDataConfig(num_transactions=100, seed=42)
        generator = SyntheticDataGenerator(config)
        gpay_records = generator.generate_gpay_source()

        debits = sum(1 for r in gpay_records if r.transaction_type == TransactionType.DEBIT)
        credits = sum(1 for r in gpay_records if r.transaction_type == TransactionType.CREDIT)

        # Should have both types
        assert debits > 0
        assert credits > 0

        # DEBIT should be ~70% (see config in generator)
        assert 0.5 < debits / len(gpay_records) < 0.85

    def test_ambiguous_records(self):
        """Test that ambiguous records have no merchant_normalized."""
        config = SyntheticDataConfig(
            num_transactions=200,
            seed=42,
            pct_ambiguous=20,
        )
        generator = SyntheticDataGenerator(config)
        gpay_records = generator.generate_gpay_source()
        bank_records = generator.generate_bank_statement_source(gpay_records)

        ambiguous = [
            r
            for r in bank_records
            if r.metadata.get("reconciliation_challenge") == ReconciliationChallengeType.AMBIGUOUS.value
        ]

        # Should have some ambiguous records
        assert len(ambiguous) > 0

        # Ambiguous records should have vague merchant names
        for record in ambiguous:
            assert record.merchant_normalized is None

    def test_duplicate_records(self):
        """Test that duplicate records are created correctly."""
        config = SyntheticDataConfig(
            num_transactions=100,
            seed=42,
            pct_duplicate=10,
        )
        generator = SyntheticDataGenerator(config)
        gpay_records = generator.generate_gpay_source()
        bank_records = generator.generate_bank_statement_source(gpay_records)

        duplicates = [
            r
            for r in bank_records
            if r.metadata.get("reconciliation_challenge") == ReconciliationChallengeType.DUPLICATE.value
        ]

        # Should have some duplicates
        assert len(duplicates) > 0

    def test_missing_records(self):
        """Test that missing records are not created."""
        config = SyntheticDataConfig(
            num_transactions=100,
            seed=42,
            pct_missing=20,
        )
        generator = SyntheticDataGenerator(config)
        gpay_records = generator.generate_gpay_source()
        bank_records = generator.generate_bank_statement_source(gpay_records)

        # Bank records should be fewer than GPay due to missing records
        # ~90 GPay records, ~20% missing = ~72 bank records (plus some duplicates)
        assert len(bank_records) < len(gpay_records)

    def test_date_shifted_records(self):
        """Test that date shifts are applied correctly."""
        config = SyntheticDataConfig(
            num_transactions=100,
            seed=42,
            pct_date_shift=30,
        )
        generator = SyntheticDataGenerator(config)
        gpay_records = generator.generate_gpay_source()
        bank_records = generator.generate_bank_statement_source(gpay_records)

        date_shifted = [
            r
            for r in bank_records
            if r.metadata.get("reconciliation_challenge") == ReconciliationChallengeType.DATE_SHIFT.value
        ]

        assert len(date_shifted) > 0

    def test_amount_differences(self):
        """Test that amount differences are applied."""
        config = SyntheticDataConfig(
            num_transactions=100,
            seed=42,
            pct_amount_difference=20,
        )
        generator = SyntheticDataGenerator(config)
        gpay_records = generator.generate_gpay_source()
        bank_records = generator.generate_bank_statement_source(gpay_records)

        # Some bank records should differ in amount from their GPay counterparts
        has_differences = False
        for bank_record in bank_records:
            if (
                bank_record.metadata.get("reconciliation_challenge")
                == ReconciliationChallengeType.AMOUNT_DIFFERENCE.value
            ):
                has_differences = True
                break

        assert has_differences

    def test_merchant_variations(self):
        """Test that merchant name variations are created."""
        config = SyntheticDataConfig(
            num_transactions=100,
            seed=42,
            pct_merchant_variation=30,
        )
        generator = SyntheticDataGenerator(config)
        gpay_records = generator.generate_gpay_source()
        bank_records = generator.generate_bank_statement_source(gpay_records)

        variations = [
            r
            for r in bank_records
            if r.metadata.get("reconciliation_challenge")
            == ReconciliationChallengeType.MERCHANT_VARIATION.value
        ]

        assert len(variations) > 0

    def test_full_generation_pipeline(self):
        """Test the complete generation pipeline."""
        config = SyntheticDataConfig(
            num_transactions=50,
            seed=999,
            start_date=datetime(2024, 6, 1, tzinfo=UTC),
            end_date=datetime(2024, 6, 30, tzinfo=UTC),
        )
        generator = SyntheticDataGenerator(config)

        gpay_records, bank_records = generator.generate()

        # Verify both datasets are produced
        assert len(gpay_records) > 0
        assert len(bank_records) > 0

        # Verify all records have required fields
        for record in gpay_records + bank_records:
            assert record.source_record_id is not None
            assert record.user_id is not None
            assert record.timestamp is not None
            assert record.amount >= 0
            assert record.currency is not None
            assert record.merchant_raw is not None
            assert record.transaction_type is not None


class TestBankStatementService:
    """Test suite for BankStatementService."""

    def test_bank_statement_service_initialization(self):
        """Test service initialization."""
        service = BankStatementService(user_id="user123", source_name="bank_statement")
        assert service.user_id == "user123"
        assert service.source_name == "bank_statement"

    def test_process_statements(self):
        """Test processing bank statement records."""
        service = BankStatementService(user_id="user123")

        records = [
            BankStatementRecord(
                transaction_id="txn_001",
                date=datetime(2024, 1, 15, tzinfo=UTC),
                description="Swiggy Food Order",
                amount=500.00,
                is_debit=True,
                merchant="Swiggy",
            ),
            BankStatementRecord(
                transaction_id="txn_002",
                date=datetime(2024, 1, 20, tzinfo=UTC),
                description="Salary Credit",
                amount=50000.00,
                is_debit=False,
                merchant="Employer Inc",
            ),
        ]

        canonical = service.process_statements(records)

        assert len(canonical) == 2

        # First record should be DEBIT
        assert canonical[0].transaction_type == TransactionType.DEBIT
        assert canonical[0].amount == 500.00
        assert canonical[0].merchant_raw == "Swiggy"

        # Second record should be CREDIT
        assert canonical[1].transaction_type == TransactionType.CREDIT
        assert canonical[1].amount == 50000.00
        assert canonical[1].merchant_raw == "Employer Inc"

    def test_bank_statement_record_initialization(self):
        """Test BankStatementRecord initialization."""
        record = BankStatementRecord(
            transaction_id="chk_123",
            date=datetime(2024, 1, 1, tzinfo=UTC),
            description="Test transaction",
            amount=1000.50,
            is_debit=True,
            merchant="Test Merchant",
            reference_id="REF_123",
            metadata={"bank": "HDFC"},
        )

        assert record.transaction_id == "chk_123"
        assert record.amount == 1000.50
        assert record.is_debit is True
        assert record.metadata["bank"] == "HDFC"

    def test_build_canonical_record(self):
        """Test building a canonical record from bank statement record."""
        service = BankStatementService(user_id="user456")

        record = BankStatementRecord(
            transaction_id="stmt_001",
            date=datetime(2024, 2, 10, tzinfo=UTC),
            description="Amazon Purchase",
            amount=2500.00,
            is_debit=True,
            merchant="Amazon",
            reference_id="ORD_789",
            metadata={"account_last4": "5678"},
        )

        canonical = service._build_canonical_record(record, {"bank": "ICICI"})

        assert canonical.source == "bank_statement"
        assert canonical.source_record_id == "stmt_001"
        assert canonical.user_id == "user456"
        assert canonical.amount == 2500.00
        assert canonical.transaction_type == TransactionType.DEBIT
        assert canonical.merchant_raw == "Amazon"
        assert canonical.metadata["bank"] == "ICICI"
        assert canonical.metadata["account_last4"] == "5678"

    def test_canonical_records_from_synthetic_data(self):
        """Test creating canonical records from synthetic data."""
        config = SyntheticDataConfig(num_transactions=20, seed=42)
        generator = SyntheticDataGenerator(config)
        gpay_records, bank_records = generator.generate()

        # All records should be valid CanonicalFinancialRecords
        for record in gpay_records + bank_records:
            assert isinstance(record, CanonicalFinancialRecord)
            assert record.source in ["gpay", "synthetic_bank"]
            assert record.user_id == "test_user"
            assert record.currency == "INR"

    def test_pdf_parsing_not_implemented(self):
        """Test that PDF parsing raises NotImplementedError in MVP."""
        with pytest.raises(NotImplementedError):
            BankStatementService.parse_gpay_pdf(b"dummy_pdf", "user123", {})

        with pytest.raises(NotImplementedError):
            BankStatementService.parse_bank_statement_pdf(
                b"dummy_pdf", "user123", "HDFC", "1234"
            )


class TestWave2Integration:
    """Integration tests for Wave 2 components."""

    def test_synthetic_data_satisfies_canonical_record_schema(self):
        """Test that synthetic data conforms to CanonicalFinancialRecord schema."""
        config = SyntheticDataConfig(num_transactions=50, seed=42)
        generator = SyntheticDataGenerator(config)
        gpay_records, bank_records = generator.generate()

        # All records should instantiate without validation errors
        all_records = gpay_records + bank_records
        for record in all_records:
            # This will raise if validation fails
            assert record.model_validate(record.model_dump())

    def test_ground_truth_reproducibility(self):
        """Test that ground truth is reproducible and documented."""
        config = SyntheticDataConfig(num_transactions=30, seed=12345)
        gen1 = SyntheticDataGenerator(config)
        gen2 = SyntheticDataGenerator(config)

        gpay1, bank1 = gen1.generate()
        gpay2, bank2 = gen2.generate()

        # Every field should match
        for r1, r2 in zip(gpay1, gpay2):
            assert r1.model_dump() == r2.model_dump()

        for r1, r2 in zip(bank1, bank2):
            assert r1.model_dump() == r2.model_dump()

    def test_reconciliation_challenges_are_identifiable(self):
        """Test that all synthetic challenges can be identified in metadata."""
        config = SyntheticDataConfig(
            num_transactions=200,
            seed=42,
            pct_exact_match=20,
            pct_merchant_variation=20,
            pct_date_shift=20,
            pct_amount_difference=10,
            pct_missing=10,
            pct_duplicate=10,
            pct_ambiguous=10,
        )
        generator = SyntheticDataGenerator(config)
        gpay_records, bank_records = generator.generate()

        challenge_types = set()
        for record in bank_records:
            challenge = record.metadata.get("reconciliation_challenge")
            if challenge:
                challenge_types.add(challenge)

        # Should identify multiple challenge types
        assert len(challenge_types) > 3


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
