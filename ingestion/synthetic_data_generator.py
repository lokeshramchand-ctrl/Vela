"""Synthetic bank statement dataset generator with reproducible ground truth.

This module generates realistic bank statement data with intentional variations
that mirror real-world reconciliation challenges:
- Exact matches (baseline cases)
- Merchant name variations (normalization testing)
- Date shifts (settlement vs posting date differences)
- Amount differences (rounding, fees)
- Missing records (transactions that don't appear in both sources)
- Duplicates (same transaction recorded twice)
- Ambiguous records (unclear merchant, vague descriptions)

All data is reproducible via a seeded random generator, ensuring consistent
test ground truth across runs."""

import random
from dataclasses import dataclass, field
from datetime import datetime, timedelta, UTC
from enum import Enum

from models.schemas import CanonicalFinancialRecord, TransactionType, TransactionStatus


class ReconciliationChallengeType(str, Enum):
    """Types of intentional variations in synthetic data for testing."""
    EXACT_MATCH = "exact_match"
    MERCHANT_VARIATION = "merchant_variation"
    DATE_SHIFT = "date_shift"
    AMOUNT_DIFFERENCE = "amount_difference"
    MISSING_RECORD = "missing_record"
    DUPLICATE = "duplicate"
    AMBIGUOUS = "ambiguous"


@dataclass
class SyntheticDataConfig:
    """Configuration for synthetic dataset generation."""
    seed: int = 42
    num_transactions: int = 100
    start_date: datetime = field(default_factory=lambda: datetime(2024, 1, 1, tzinfo=UTC))
    end_date: datetime = field(default_factory=lambda: datetime(2024, 1, 31, tzinfo=UTC))
    user_id: str = "test_user"

    # Variation distribution (must sum to ~100)
    pct_exact_match: float = 30.0
    pct_merchant_variation: float = 25.0
    pct_date_shift: float = 20.0
    pct_amount_difference: float = 10.0
    pct_missing: float = 5.0
    pct_duplicate: float = 5.0
    pct_ambiguous: float = 5.0


class SyntheticDataGenerator:
    """Generates reproducible synthetic bank statement data."""

    # Canonical merchants and their variations
    MERCHANT_POOL = {
        "Swiggy": ["SWIGGY", "Swiggy Food", "SWIGGY FOODS", "swiggy.in"],
        "Zomato": ["ZOMATO", "Zomato Food", "zomato.com"],
        "Amazon": ["AMAZON.IN", "Amazon Pay", "amazon shopping", "AMAZON"],
        "Flipkart": ["FLIPKART", "Flipkart Online", "flipkart.com"],
        "Starbucks": ["STARBUCKS", "Starbucks Coffee", "COFFEE", "Cafe Coffee"],
        "Netflix": ["NETFLIX", "netflix.com", "NETFLIX_SUBSCRIPTION"],
        "Spotify": ["SPOTIFY", "spotify.com", "MUSIC_STREAMING"],
        "Uber": ["UBER", "UBER EATS", "Uber Ride", "uber.com"],
        "Ola": ["OLA", "OLA_CAB", "OLA RIDE", "ola.com"],
        "ICICI Bank": ["ICICI", "ICICI ATM", "ICICI_CHARGE", "ICICI BANK ATM"],
    }

    # Ambiguous merchant descriptions
    AMBIGUOUS_MERCHANTS = [
        "Unknown Merchant",
        "Payment Received",
        "Online Transfer",
        "POS Purchase",
        "Debit Card Usage",
        "Transfer to Account",
        "Online Purchase",
    ]

    def __init__(self, config: SyntheticDataConfig | None = None):
        """Initialize the generator with configuration.

        Args:
            config: SyntheticDataConfig with generation parameters. Uses defaults if None.
        """
        self.config = config or SyntheticDataConfig()
        self.rng = random.Random(self.config.seed)
        self._generated_ids: set[str] = set()

    def generate_gpay_source(self) -> list[CanonicalFinancialRecord]:
        """Generate the 'canonical' GPay source transactions.

        These represent the ground truth that bank statements will try to match.
        Returns:
            List of CanonicalFinancialRecords with source="gpay"
        """
        records = []
        num_txns = int(self.config.num_transactions * 0.9)  # 90% appear in both sources

        date_range = self.config.end_date - self.config.start_date

        for i in range(num_txns):
            days_offset = self.rng.randint(0, date_range.days)
            seconds_offset = self.rng.randint(0, 86400)
            timestamp = self.config.start_date + timedelta(days=days_offset, seconds=seconds_offset)

            # 70% DEBIT, 30% CREDIT
            txn_type = (
                TransactionType.DEBIT
                if self.rng.random() < 0.7
                else TransactionType.CREDIT
            )

            amount = self._generate_amount(txn_type)
            canonical_merchant = self.rng.choice(list(self.MERCHANT_POOL.keys()))
            merchant_raw = self.rng.choice(self.MERCHANT_POOL[canonical_merchant])

            source_id = f"gpay_{i:06d}"
            self._generated_ids.add(source_id)

            record = CanonicalFinancialRecord(
                source="gpay",
                source_record_id=source_id,
                user_id=self.config.user_id,
                timestamp=timestamp,
                amount=amount,
                currency="INR",
                merchant_raw=merchant_raw,
                merchant_normalized=canonical_merchant,
                transaction_type=txn_type,
                status=TransactionStatus.SUCCESS,
                reference_id=f"UPI/{self.rng.randint(1000000000, 9999999999)}",
                description=f"{canonical_merchant} transaction",
                metadata={
                    "source_app": "Google Pay",
                    "payment_method": "UPI" if self.rng.random() < 0.6 else "Card",
                },
            )
            records.append(record)

        return records

    def generate_bank_statement_source(
        self, gpay_records: list[CanonicalFinancialRecord]
    ) -> list[CanonicalFinancialRecord]:
        """Generate synthetic bank statement records with variations from GPay.

        This creates records with intentional challenges for reconciliation:
        - Some exact matches
        - Some with merchant variations
        - Some with date shifts
        - Some with amount differences
        - Some missing entirely
        - Some duplicated
        - Some ambiguous

        Args:
            gpay_records: Reference GPay records to base variations on

        Returns:
            List of CanonicalFinancialRecords with source="synthetic_bank"
        """
        records = []
        record_id = 0

        # Build a variation assignment for each GPay record
        variations = self._assign_variations(len(gpay_records))

        for i, gpay_record in enumerate(gpay_records):
            variation_type = variations[i]

            if variation_type == ReconciliationChallengeType.MISSING_RECORD:
                continue  # Don't create a bank record for this

            source_id = f"bank_{record_id:06d}"
            record_id += 1

            # Start with GPay values and apply variation
            timestamp = gpay_record.timestamp
            amount = gpay_record.amount
            merchant_raw = gpay_record.merchant_raw
            merchant_normalized = gpay_record.merchant_normalized

            match variation_type:
                case ReconciliationChallengeType.EXACT_MATCH:
                    pass  # Use values as-is

                case ReconciliationChallengeType.MERCHANT_VARIATION:
                    # Change merchant name slightly
                    if gpay_record.merchant_normalized:
                        merchant_raw = self.rng.choice(
                            self.MERCHANT_POOL[gpay_record.merchant_normalized]
                        )

                case ReconciliationChallengeType.DATE_SHIFT:
                    # Shift by 1-2 days (settlement vs posting date)
                    days = self.rng.randint(-2, 2)
                    timestamp = timestamp + timedelta(days=days)

                case ReconciliationChallengeType.AMOUNT_DIFFERENCE:
                    # Add small fee or rounding difference
                    variation = self.rng.uniform(-50, 50)  # ±50 paise
                    amount = round(amount + variation, 2)

                case ReconciliationChallengeType.DUPLICATE:
                    pass  # Will create record, then create it again below

                case ReconciliationChallengeType.AMBIGUOUS:
                    merchant_raw = self.rng.choice(self.AMBIGUOUS_MERCHANTS)
                    merchant_normalized = None

            # Create the bank record
            bank_record = CanonicalFinancialRecord(
                source="synthetic_bank",
                source_record_id=source_id,
                user_id=self.config.user_id,
                timestamp=timestamp,
                amount=amount,
                currency="INR",
                merchant_raw=merchant_raw,
                merchant_normalized=merchant_normalized,
                transaction_type=gpay_record.transaction_type,
                status=TransactionStatus.SUCCESS,
                reference_id=f"CHK/{self.rng.randint(100000, 999999)}",
                description=f"Bank statement: {merchant_raw}",
                metadata={
                    "bank": "ICICI",
                    "account_last4": "1234",
                    "statement_id": "stmt_20240131",
                    "reconciliation_challenge": variation_type.value,
                },
            )
            records.append(bank_record)

            # If DUPLICATE, create the exact same record again
            if variation_type == ReconciliationChallengeType.DUPLICATE:
                source_id = f"bank_{record_id:06d}"
                record_id += 1
                duplicate = CanonicalFinancialRecord(
                    source="synthetic_bank",
                    source_record_id=source_id,
                    user_id=self.config.user_id,
                    timestamp=bank_record.timestamp,
                    amount=bank_record.amount,
                    currency=bank_record.currency,
                    merchant_raw=bank_record.merchant_raw,
                    merchant_normalized=bank_record.merchant_normalized,
                    transaction_type=bank_record.transaction_type,
                    status=TransactionStatus.SUCCESS,
                    reference_id=f"CHK/{self.rng.randint(100000, 999999)}",
                    description=bank_record.description,
                    metadata={**bank_record.metadata, "duplicate_of": records[-1].source_record_id},
                )
                records.append(duplicate)

        return records

    def _assign_variations(self, num_records: int) -> list[ReconciliationChallengeType]:
        """Assign variation types to records according to configured distribution.

        Args:
            num_records: Number of records to assign variations for

        Returns:
            List of ReconciliationChallengeType assignments
        """
        variations = []

        # Calculate how many of each type
        counts = {
            ReconciliationChallengeType.EXACT_MATCH: int(
                num_records * self.config.pct_exact_match / 100
            ),
            ReconciliationChallengeType.MERCHANT_VARIATION: int(
                num_records * self.config.pct_merchant_variation / 100
            ),
            ReconciliationChallengeType.DATE_SHIFT: int(
                num_records * self.config.pct_date_shift / 100
            ),
            ReconciliationChallengeType.AMOUNT_DIFFERENCE: int(
                num_records * self.config.pct_amount_difference / 100
            ),
            ReconciliationChallengeType.MISSING_RECORD: int(
                num_records * self.config.pct_missing / 100
            ),
            ReconciliationChallengeType.DUPLICATE: int(
                num_records * self.config.pct_duplicate / 100
            ),
            ReconciliationChallengeType.AMBIGUOUS: int(
                num_records * self.config.pct_ambiguous / 100
            ),
        }

        # Build list with proper distribution
        for variation_type, count in counts.items():
            variations.extend([variation_type] * count)

        # Fill remainder with exact matches
        if len(variations) < num_records:
            variations.extend(
                [ReconciliationChallengeType.EXACT_MATCH] * (num_records - len(variations))
            )

        # Shuffle for randomness
        self.rng.shuffle(variations)
        return variations

    def _generate_amount(self, txn_type: TransactionType) -> float:
        """Generate a realistic transaction amount.

        Args:
            txn_type: DEBIT or CREDIT

        Returns:
            Amount in rupees
        """
        # Distribution: 40% small (₹0-500), 40% medium (₹500-5000), 20% large (₹5000+)
        rand = self.rng.random()
        if rand < 0.4:
            amount = self.rng.uniform(10, 500)
        elif rand < 0.8:
            amount = self.rng.uniform(500, 5000)
        else:
            amount = self.rng.uniform(5000, 50000)

        return round(amount, 2)

    def generate(self) -> tuple[list[CanonicalFinancialRecord], list[CanonicalFinancialRecord]]:
        """Generate both GPay and bank statement datasets.

        Returns:
            Tuple of (gpay_records, bank_statement_records)
        """
        gpay_records = self.generate_gpay_source()
        bank_records = self.generate_bank_statement_source(gpay_records)
        return gpay_records, bank_records
