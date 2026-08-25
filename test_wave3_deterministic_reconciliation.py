"""Test suite for Wave 3: Deterministic reconciliation baseline.

Demonstrates that deterministic rules can match transactions without ML,
providing a measurable baseline for comparing AI-based improvements.

Tests validate:
1. Exact matches via reference ID + amount
2. Strong matches via merchant + amount + date proximity
3. Amount mismatches identified (but not as full matches)
4. Unmatched records correctly identified
"""

import pytest
from datetime import datetime, UTC

from ingestion.synthetic_data_generator import (
    SyntheticDataGenerator,
    SyntheticDataConfig,
    ReconciliationChallengeType,
)
from models.schemas import CanonicalFinancialRecord, TransactionType, TransactionStatus
from reconciliation.deterministic_matcher import (
    DeterministicMatcher,
    MatchType,
)


@pytest.fixture
def matcher():
    """Create a deterministic matcher with default settings."""
    return DeterministicMatcher(date_tolerance_days=1, amount_tolerance=0.01)


@pytest.fixture
def sample_records():
    """Generate reproducible sample records for testing."""
    config = SyntheticDataConfig(
        seed=42,
        num_transactions=50,
        start_date=datetime(2024, 1, 1, tzinfo=UTC),
        end_date=datetime(2024, 1, 31, tzinfo=UTC),
        user_id="test_user",
    )
    generator = SyntheticDataGenerator(config)

    gpay_source = generator.generate_gpay_source()
    bank_source = generator.generate_bank_statement_source()

    return {"gpay": gpay_source, "bank": bank_source}


class TestExactMatching:
    """Tests for Rule 1: Exact match via reference ID + amount."""

    def test_exact_match_by_reference_and_amount(self, matcher, sample_records):
        """Verify exact matches are identified via reference ID + amount."""
        gpay = sample_records["gpay"]
        bank = sample_records["bank"]

        results = matcher.reconcile(gpay, bank)

        exact_matches = results["exact"]
        assert len(exact_matches) > 0, "Should find at least some exact matches"

        for match in exact_matches:
            assert match.match_type == MatchType.EXACT
            assert match.confidence == 1.0
            assert match.source_record.reference_id == match.target_record.reference_id
            assert match.source_record.amount == match.target_record.amount

    def test_reference_id_mismatch_not_exact(self, matcher):
        """Verify records with different reference IDs are not exact matches."""
        record1 = CanonicalFinancialRecord(
            source="source_a",
            source_record_id="a1",
            user_id="user1",
            timestamp=datetime(2024, 1, 1, tzinfo=UTC),
            amount=100.0,
            merchant_raw="Merchant A",
            transaction_type=TransactionType.DEBIT,
            reference_id="ref_001",
        )
        record2 = CanonicalFinancialRecord(
            source="source_b",
            source_record_id="b1",
            user_id="user1",
            timestamp=datetime(2024, 1, 1, tzinfo=UTC),
            amount=100.0,
            merchant_raw="Merchant A",
            transaction_type=TransactionType.DEBIT,
            reference_id="ref_002",  # Different reference ID
        )

        result = matcher.match_by_reference_and_amount(record1, [record2])
        assert result is None, "Should not match with different reference IDs"

    def test_amount_mismatch_not_exact(self, matcher):
        """Verify records with same reference but different amounts are not exact."""
        record1 = CanonicalFinancialRecord(
            source="source_a",
            source_record_id="a1",
            user_id="user1",
            timestamp=datetime(2024, 1, 1, tzinfo=UTC),
            amount=100.0,
            merchant_raw="Merchant A",
            transaction_type=TransactionType.DEBIT,
            reference_id="ref_001",
        )
        record2 = CanonicalFinancialRecord(
            source="source_b",
            source_record_id="b1",
            user_id="user1",
            timestamp=datetime(2024, 1, 1, tzinfo=UTC),
            amount=100.50,  # Different amount
            merchant_raw="Merchant A",
            transaction_type=TransactionType.DEBIT,
            reference_id="ref_001",
        )

        result = matcher.match_by_reference_and_amount(record1, [record2])
        assert result is None, "Should not match when amounts differ"


class TestStrongMatching:
    """Tests for Rule 2: Strong match via merchant + amount + date."""

    def test_strong_match_by_merchant_amount_date(self, matcher, sample_records):
        """Verify strong matches are identified via merchant + amount + date."""
        gpay = sample_records["gpay"]
        bank = sample_records["bank"]

        results = matcher.reconcile(gpay, bank)

        strong_matches = results["strong"]
        assert len(strong_matches) > 0, "Should find at least some strong matches"

        for match in strong_matches:
            assert match.match_type == MatchType.STRONG
            assert match.confidence == 0.95

            # Verify merchant names are normalized and match
            src_merchant = matcher.normalize_merchant(
                match.source_record.merchant_normalized or match.source_record.merchant_raw
            )
            tgt_merchant = matcher.normalize_merchant(
                match.target_record.merchant_normalized or match.target_record.merchant_raw
            )
            assert src_merchant == tgt_merchant

            # Verify amounts match
            assert matcher.amounts_match(
                match.source_record.amount, match.target_record.amount
            )

            # Verify dates are close
            assert matcher.dates_close(
                match.source_record.timestamp, match.target_record.timestamp
            )

    def test_strong_match_with_merchant_variations(self, matcher):
        """Verify normalization handles merchant name variations."""
        record1 = CanonicalFinancialRecord(
            source="source_a",
            source_record_id="a1",
            user_id="user1",
            timestamp=datetime(2024, 1, 1, 12, 0, 0, tzinfo=UTC),
            amount=250.0,
            merchant_raw="Swiggy",
            merchant_normalized="Swiggy",
            transaction_type=TransactionType.DEBIT,
        )
        record2 = CanonicalFinancialRecord(
            source="source_b",
            source_record_id="b1",
            user_id="user1",
            timestamp=datetime(2024, 1, 1, 12, 30, 0, tzinfo=UTC),
            amount=250.0,
            merchant_raw="SWIGGY FOODS",
            merchant_normalized="SWIGGY FOODS",
            transaction_type=TransactionType.DEBIT,
        )

        result = matcher.match_by_merchant_amount_date(record1, [record2])
        assert result is not None, "Should match different merchant name variations"
        assert result.match_type == MatchType.STRONG

    def test_date_outside_tolerance_not_strong_match(self, matcher):
        """Verify records outside date tolerance are not strong matches."""
        record1 = CanonicalFinancialRecord(
            source="source_a",
            source_record_id="a1",
            user_id="user1",
            timestamp=datetime(2024, 1, 1, tzinfo=UTC),
            amount=100.0,
            merchant_raw="Merchant A",
            merchant_normalized="Merchant A",
            transaction_type=TransactionType.DEBIT,
        )
        record2 = CanonicalFinancialRecord(
            source="source_b",
            source_record_id="b1",
            user_id="user1",
            timestamp=datetime(2024, 1, 5, tzinfo=UTC),  # 4 days later
            amount=100.0,
            merchant_raw="Merchant A",
            merchant_normalized="Merchant A",
            transaction_type=TransactionType.DEBIT,
        )

        result = matcher.match_by_merchant_amount_date(record1, [record2])
        assert (
            result is None
        ), "Should not match when date difference exceeds tolerance"


class TestAmountMismatchDetection:
    """Tests for Rule 3: Amount mismatch detection."""

    def test_identifies_amount_mismatch(self, matcher):
        """Verify amount mismatches are identified."""
        record1 = CanonicalFinancialRecord(
            source="source_a",
            source_record_id="a1",
            user_id="user1",
            timestamp=datetime(2024, 1, 1, 12, 0, 0, tzinfo=UTC),
            amount=100.0,
            merchant_raw="Amazon",
            merchant_normalized="Amazon",
            transaction_type=TransactionType.DEBIT,
        )
        record2 = CanonicalFinancialRecord(
            source="source_b",
            source_record_id="b1",
            user_id="user1",
            timestamp=datetime(2024, 1, 1, 14, 0, 0, tzinfo=UTC),
            amount=105.0,  # Different amount (maybe includes fee)
            merchant_raw="Amazon",
            merchant_normalized="Amazon",
            transaction_type=TransactionType.DEBIT,
        )

        result = matcher.match_by_merchant_only(record1, [record2])
        assert result is not None, "Should identify amount mismatch"
        assert result.match_type == MatchType.AMOUNT_MISMATCH
        assert result.confidence == 0.7

    def test_amount_difference_calculation(self, matcher):
        """Verify amount difference is correctly calculated in reason."""
        record1 = CanonicalFinancialRecord(
            source="source_a",
            source_record_id="a1",
            user_id="user1",
            timestamp=datetime(2024, 1, 1, 12, 0, 0, tzinfo=UTC),
            amount=100.0,
            merchant_raw="Store",
            merchant_normalized="Store",
            transaction_type=TransactionType.DEBIT,
        )
        record2 = CanonicalFinancialRecord(
            source="source_b",
            source_record_id="b1",
            user_id="user1",
            timestamp=datetime(2024, 1, 1, 12, 30, 0, tzinfo=UTC),
            amount=110.0,
            merchant_raw="Store",
            merchant_normalized="Store",
            transaction_type=TransactionType.DEBIT,
        )

        result = matcher.match_by_merchant_only(record1, [record2])
        assert result is not None
        assert "amount_diff" in result.reason
        assert "-10.00" in result.reason  # 100 - 110 = -10


class TestUnmatchedDetection:
    """Tests for Rule 4: Unmatched record detection."""

    def test_identifies_unmatched_records(self, matcher, sample_records):
        """Verify unmatched records are correctly identified."""
        gpay = sample_records["gpay"]
        bank = sample_records["bank"]

        results = matcher.reconcile(gpay, bank)

        unmatched = results["unmatched"]
        # With synthetic data, we expect some unmatched records due to missing_record scenarios
        assert isinstance(unmatched, list)

        for match in unmatched:
            assert match.match_type == MatchType.UNMATCHED
            assert match.confidence == 0.0
            assert match.target_record is None

    def test_no_candidates_returns_unmatched(self, matcher):
        """Verify a record with no candidates returns unmatched."""
        record = CanonicalFinancialRecord(
            source="source_a",
            source_record_id="a1",
            user_id="user1",
            timestamp=datetime(2024, 1, 1, tzinfo=UTC),
            amount=999.99,
            merchant_raw="Unique Merchant",
            merchant_normalized="Unique Merchant",
            transaction_type=TransactionType.DEBIT,
        )

        result = matcher.reconcile([record], [])
        assert len(result["unmatched"]) == 1
        assert result["unmatched"][0].source_record == record


class TestReconciliationSummary:
    """Tests for overall reconciliation statistics."""

    def test_reconciliation_covers_all_records(self, matcher, sample_records):
        """Verify reconciliation results cover all source records."""
        gpay = sample_records["gpay"]
        bank = sample_records["bank"]

        results = matcher.reconcile(gpay, bank)

        total_matched = (
            len(results["exact"])
            + len(results["strong"])
            + len(results["amount_mismatch"])
            + len(results["unmatched"])
        )

        assert (
            total_matched == len(gpay)
        ), "All source records should have a result (matched or unmatched)"

    def test_reconciliation_match_breakdown(self, matcher, sample_records):
        """Verify reconciliation produces meaningful breakdown of results."""
        gpay = sample_records["gpay"]
        bank = sample_records["bank"]

        results = matcher.reconcile(gpay, bank)

        exact = len(results["exact"])
        strong = len(results["strong"])
        amount_mismatch = len(results["amount_mismatch"])
        unmatched = len(results["unmatched"])

        # Print for visibility
        total = exact + strong + amount_mismatch + unmatched
        print(
            f"\nReconciliation Results (n={total}):\n"
            f"  Exact matches:      {exact:3d} ({exact/total*100:5.1f}%)\n"
            f"  Strong matches:     {strong:3d} ({strong/total*100:5.1f}%)\n"
            f"  Amount mismatches:  {amount_mismatch:3d} ({amount_mismatch/total*100:5.1f}%)\n"
            f"  Unmatched:          {unmatched:3d} ({unmatched/total*100:5.1f}%)"
        )

        # Verify we have at least some matches
        total_matches = exact + strong + amount_mismatch
        assert (
            total_matches > 0
        ), "Should find at least some matches in synthetic data"


class TestMerchantNormalization:
    """Tests for merchant name normalization."""

    def test_normalization_handles_case_variations(self, matcher):
        """Verify normalization handles case differences."""
        test_cases = [
            ("Amazon", "amazon"),
            ("SWIGGY", "swiggy"),
            ("Starbucks Coffee", "starbucks coffee"),
            ("NETFLIX_SUBSCRIPTION", "netflix_subscription"),
        ]

        for original, expected in test_cases:
            assert matcher.normalize_merchant(original) == expected

    def test_normalization_collapses_whitespace(self, matcher):
        """Verify normalization collapses extra whitespace."""
        test_cases = [
            ("  Amazon  ", "amazon"),
            ("Starbucks  Coffee", "starbucks coffee"),
            ("UBER\t\tEATS", "uber eats"),
        ]

        for original, expected in test_cases:
            assert matcher.normalize_merchant(original) == expected


class TestAmountComparison:
    """Tests for amount comparison logic."""

    def test_amounts_match_exact(self, matcher):
        """Verify exact amount matches."""
        assert matcher.amounts_match(100.0, 100.0)
        assert matcher.amounts_match(100.50, 100.50)

    def test_amounts_match_within_tolerance(self, matcher):
        """Verify amounts within tolerance match."""
        # Default tolerance is 1%
        assert matcher.amounts_match(100.0, 100.99)  # Within 1%
        assert matcher.amounts_match(100.0, 99.01)   # Within 1%

    def test_amounts_dont_match_outside_tolerance(self, matcher):
        """Verify amounts outside tolerance don't match."""
        assert not matcher.amounts_match(100.0, 102.0)  # 2% difference
        assert not matcher.amounts_match(100.0, 98.0)   # 2% difference

    def test_zero_amounts_must_match_exactly(self, matcher):
        """Verify zero amounts must match exactly."""
        assert matcher.amounts_match(0.0, 0.0)
        assert not matcher.amounts_match(0.0, 0.01)


if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])
