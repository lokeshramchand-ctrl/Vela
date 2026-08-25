"""Deterministic reconciliation matcher for financial transactions.

Implements baseline rules to match transactions from multiple sources without ML.
This serves as the foundation for measuring whether AI-based reconciliation actually
improves over deterministic matching.

Matching rules (in priority order):
1. Exact match: same reference_id + same amount
2. Strong match: same normalized merchant + same amount + date within 1 day
3. Amount mismatch: same merchant + different amount (records relationship but notes discrepancy)
4. Unmatched: no reasonable candidate found
"""

from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Optional

from models.schemas import CanonicalFinancialRecord, TransactionType


class MatchType:
    """Classification of match strength."""
    EXACT = "exact"
    STRONG = "strong"
    AMOUNT_MISMATCH = "amount_mismatch"
    UNMATCHED = "unmatched"


@dataclass
class MatchResult:
    """Result of a reconciliation attempt between two records."""
    source_record: CanonicalFinancialRecord
    target_record: Optional[CanonicalFinancialRecord]
    match_type: str
    confidence: float
    reason: str

    def __repr__(self) -> str:
        if self.target_record:
            return (
                f"MatchResult("
                f"type={self.match_type}, "
                f"confidence={self.confidence:.2f}, "
                f"src={self.source_record.source_record_id[:8]}, "
                f"tgt={self.target_record.source_record_id[:8]}, "
                f"reason={self.reason})"
            )
        return (
            f"MatchResult("
            f"type={self.match_type}, "
            f"confidence={self.confidence:.2f}, "
            f"src={self.source_record.source_record_id[:8]}, "
            f"unmatched, "
            f"reason={self.reason})"
        )


class DeterministicMatcher:
    """Deterministic transaction matcher with baseline reconciliation rules."""

    def __init__(self, date_tolerance_days: int = 1, amount_tolerance: float = 0.01):
        """Initialize the matcher with tolerance parameters.

        Args:
            date_tolerance_days: Allow matches with dates within this many days.
            amount_tolerance: Allow amount matches within this percentage (0-1).
        """
        self.date_tolerance = timedelta(days=date_tolerance_days)
        self.amount_tolerance = amount_tolerance

    def normalize_merchant(self, merchant: str) -> str:
        """Normalize merchant name for comparison.

        Args:
            merchant: Raw merchant name.

        Returns:
            Normalized merchant name (lowercase, trimmed, whitespace collapsed).
        """
        return " ".join(merchant.lower().split())

    def amounts_match(self, amount1: float, amount2: float) -> bool:
        """Check if two amounts are equal within tolerance.

        Args:
            amount1: First amount.
            amount2: Second amount.

        Returns:
            True if amounts are within tolerance.
        """
        if amount1 == 0 or amount2 == 0:
            return amount1 == amount2

        pct_diff = abs(amount1 - amount2) / max(abs(amount1), abs(amount2))
        return pct_diff <= self.amount_tolerance

    def dates_close(self, date1: datetime, date2: datetime) -> bool:
        """Check if two dates are within tolerance.

        Args:
            date1: First date.
            date2: Second date.

        Returns:
            True if dates are within tolerance.
        """
        return abs(date1 - date2) <= self.date_tolerance

    def match_by_reference_and_amount(
        self,
        source: CanonicalFinancialRecord,
        candidates: list[CanonicalFinancialRecord],
    ) -> Optional[MatchResult]:
        """Rule 1: Match by reference ID + amount (highest confidence).

        Args:
            source: Source record to match.
            candidates: List of candidate records from other source.

        Returns:
            MatchResult if found, None otherwise.
        """
        if not source.reference_id:
            return None

        for candidate in candidates:
            if (
                candidate.reference_id == source.reference_id
                and self.amounts_match(source.amount, candidate.amount)
            ):
                return MatchResult(
                    source_record=source,
                    target_record=candidate,
                    match_type=MatchType.EXACT,
                    confidence=1.0,
                    reason=f"reference_id={source.reference_id} + amount_match",
                )
        return None

    def match_by_merchant_amount_date(
        self,
        source: CanonicalFinancialRecord,
        candidates: list[CanonicalFinancialRecord],
    ) -> Optional[MatchResult]:
        """Rule 2: Match by normalized merchant + amount + date proximity.

        Args:
            source: Source record to match.
            candidates: List of candidate records from other source.

        Returns:
            MatchResult if found, None otherwise.
        """
        if not source.merchant_normalized:
            return None

        source_merchant = self.normalize_merchant(source.merchant_normalized)

        for candidate in candidates:
            if not candidate.merchant_normalized:
                continue

            candidate_merchant = self.normalize_merchant(candidate.merchant_normalized)

            if (
                source_merchant == candidate_merchant
                and self.amounts_match(source.amount, candidate.amount)
                and self.dates_close(source.timestamp, candidate.timestamp)
            ):
                return MatchResult(
                    source_record=source,
                    target_record=candidate,
                    match_type=MatchType.STRONG,
                    confidence=0.95,
                    reason=(
                        f"merchant={source_merchant} + "
                        f"amount_match + "
                        f"date_diff={abs(source.timestamp - candidate.timestamp).days}d"
                    ),
                )
        return None

    def match_by_merchant_only(
        self,
        source: CanonicalFinancialRecord,
        candidates: list[CanonicalFinancialRecord],
    ) -> Optional[MatchResult]:
        """Rule 3: Match by merchant name only (identifies amount discrepancies).

        Note: This is used to identify potential duplicates or amount mismatches
        where the merchant is the same but amount differs.

        Args:
            source: Source record to match.
            candidates: List of candidate records from other source.

        Returns:
            MatchResult if found with amount mismatch, None otherwise.
        """
        if not source.merchant_normalized:
            return None

        source_merchant = self.normalize_merchant(source.merchant_normalized)

        for candidate in candidates:
            if not candidate.merchant_normalized:
                continue

            candidate_merchant = self.normalize_merchant(candidate.merchant_normalized)

            if (
                source_merchant == candidate_merchant
                and not self.amounts_match(source.amount, candidate.amount)
                and self.dates_close(source.timestamp, candidate.timestamp)
            ):
                amount_diff = source.amount - candidate.amount
                return MatchResult(
                    source_record=source,
                    target_record=candidate,
                    match_type=MatchType.AMOUNT_MISMATCH,
                    confidence=0.7,
                    reason=(
                        f"merchant={source_merchant} + "
                        f"amount_diff={amount_diff:.2f} ({amount_diff/candidate.amount*100:.1f}%)"
                    ),
                )
        return None

    def reconcile(
        self,
        source_records: list[CanonicalFinancialRecord],
        target_records: list[CanonicalFinancialRecord],
    ) -> dict[str, list[MatchResult]]:
        """Run reconciliation against all source records.

        Matches each source record against target records using rules in priority order:
        1. Reference ID + amount (exact)
        2. Normalized merchant + amount + date (strong)
        3. Merchant only (amount mismatch)
        4. No match (unmatched)

        Args:
            source_records: Primary source of truth records.
            target_records: Records to reconcile against source.

        Returns:
            Dictionary with keys:
            - "exact": list of exact matches
            - "strong": list of strong matches
            - "amount_mismatch": list of merchant matches with amount differences
            - "unmatched": list of unmatched source records
        """
        exact_matches = []
        strong_matches = []
        amount_mismatches = []
        unmatched = []

        # Pre-normalize merchant names in target records for efficiency
        for record in target_records:
            if record.merchant_normalized is None and record.merchant_raw:
                record.merchant_normalized = record.merchant_raw

        for source in source_records:
            # Normalize source merchant
            if source.merchant_normalized is None and source.merchant_raw:
                source.merchant_normalized = source.merchant_raw

            # Try rules in priority order
            result = self.match_by_reference_and_amount(source, target_records)
            if result:
                exact_matches.append(result)
                continue

            result = self.match_by_merchant_amount_date(source, target_records)
            if result:
                strong_matches.append(result)
                continue

            result = self.match_by_merchant_only(source, target_records)
            if result:
                amount_mismatches.append(result)
                continue

            unmatched.append(
                MatchResult(
                    source_record=source,
                    target_record=None,
                    match_type=MatchType.UNMATCHED,
                    confidence=0.0,
                    reason="no_matching_candidate_found",
                )
            )

        return {
            "exact": exact_matches,
            "strong": strong_matches,
            "amount_mismatch": amount_mismatches,
            "unmatched": unmatched,
        }
