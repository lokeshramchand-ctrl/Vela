"""Reconciliation service for matching transactions across sources.

Provides high-level API for transaction reconciliation with deterministic baseline
before any ML-based matching is attempted.
"""

import logging
from typing import Optional

from models.schemas import CanonicalFinancialRecord
from reconciliation.deterministic_matcher import (
    DeterministicMatcher,
    MatchResult,
)

logger = logging.getLogger(__name__)


class ReconciliationService:
    """Service for reconciling transactions across multiple sources."""

    def __init__(
        self,
        date_tolerance_days: int = 1,
        amount_tolerance: float = 0.01,
    ):
        """Initialize reconciliation service.

        Args:
            date_tolerance_days: Allow date differences up to this many days.
            amount_tolerance: Allow amount differences up to this percentage (0-1).
        """
        self.matcher = DeterministicMatcher(
            date_tolerance_days=date_tolerance_days,
            amount_tolerance=amount_tolerance,
        )
        self.logger = logger

    def reconcile_sources(
        self,
        primary_source: list[CanonicalFinancialRecord],
        secondary_source: list[CanonicalFinancialRecord],
    ) -> dict:
        """Reconcile two transaction sources.

        Args:
            primary_source: The primary/canonical source of truth.
            secondary_source: The source to reconcile against primary.

        Returns:
            Dictionary containing:
            - exact_matches: Records with identical reference ID + amount
            - strong_matches: Records matching merchant + amount + date
            - amount_mismatches: Same merchant but different amounts
            - unmatched: Records with no reasonable match
            - statistics: Summary statistics of the reconciliation
        """
        self.logger.info(
            f"Reconciling {len(secondary_source)} secondary records "
            f"against {len(primary_source)} primary records"
        )

        results = self.matcher.reconcile(primary_source, secondary_source)

        # Prepare response
        response = {
            "exact_matches": results["exact"],
            "strong_matches": results["strong"],
            "amount_mismatches": results["amount_mismatch"],
            "unmatched": results["unmatched"],
            "statistics": self._compute_statistics(results),
        }

        self.logger.info(
            f"Reconciliation complete: {response['statistics']['total_matched']} "
            f"matched, {len(results['unmatched'])} unmatched"
        )

        return response

    def _compute_statistics(self, results: dict) -> dict:
        """Compute reconciliation statistics.

        Args:
            results: Raw reconciliation results.

        Returns:
            Dictionary with statistics.
        """
        exact = len(results["exact"])
        strong = len(results["strong"])
        amount_mismatch = len(results["amount_mismatch"])
        unmatched = len(results["unmatched"])
        total = exact + strong + amount_mismatch + unmatched

        matched = exact + strong + amount_mismatch

        return {
            "total_records": total,
            "exact_matches": exact,
            "strong_matches": strong,
            "amount_mismatches": amount_mismatch,
            "unmatched": unmatched,
            "total_matched": matched,
            "match_rate": matched / total if total > 0 else 0,
            "exact_rate": exact / total if total > 0 else 0,
            "strong_rate": strong / total if total > 0 else 0,
        }

    def get_unmatched_records(self, reconciliation_result: dict) -> list[MatchResult]:
        """Extract unmatched records from reconciliation result.

        Args:
            reconciliation_result: Result from reconcile_sources().

        Returns:
            List of unmatched MatchResult objects.
        """
        return reconciliation_result["unmatched"]

    def get_matches_by_type(
        self, reconciliation_result: dict, match_type: str
    ) -> list[MatchResult]:
        """Extract matches of a specific type.

        Args:
            reconciliation_result: Result from reconcile_sources().
            match_type: One of "exact", "strong", "amount_mismatch".

        Returns:
            List of MatchResult objects of the specified type.
        """
        match_key = {
            "exact": "exact_matches",
            "strong": "strong_matches",
            "amount_mismatch": "amount_mismatches",
        }.get(match_type)

        if not match_key:
            raise ValueError(f"Unknown match type: {match_type}")

        return reconciliation_result.get(match_key, [])
