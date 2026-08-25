"""
Phase 4 characterization tests for PeriodicityExtractor.

These tests establish what features/periodicity.py actually does on its
own, standalone - not whether/how it should be wired into the matcher.
See the Phase 4 note in docs/ (or the commit that adds this file) for the
wiring decision and why it isn't made here.
"""

import unittest
from datetime import datetime, timedelta

from features.periodicity import periodicity_extractor


def _dates(start: datetime, step_days: float, n: int) -> list[datetime]:
    return [start + timedelta(days=step_days * i) for i in range(n)]


class TestPeriodicityExtractor(unittest.TestCase):
    def setUp(self):
        self.base = datetime(2026, 1, 1)

    def test_monthly_recurring_transaction_is_flagged_as_subscription(self):
        """Six perfectly-spaced ~30-day intervals (the textbook Netflix/
        Spotify shape) score periodicity_score=1.0 and are flagged."""
        result = periodicity_extractor.calculate_periodicity(_dates(self.base, 30, 6))
        self.assertEqual(result["periodicity_score"], 1.0)
        self.assertTrue(result["is_likely_subscription"])

    def test_weekly_recurring_transaction_is_not_flagged_as_subscription(self):
        """FINDING: a perfectly-spaced weekly cadence (7-day intervals) gets
        a maximal periodicity_score (1.0, exactly as regular as the monthly
        case) but is_likely_subscription is still False, because the
        subscription-detection band only checks for ~30-day (27-33) or
        ~365-day (360-370) average intervals. Weekly billing (common for
        grocery/meal-kit subscriptions) is real recurring behavior that this
        heuristic currently can't recognize as such, even though its own
        regularity signal is as strong as it gets."""
        result = periodicity_extractor.calculate_periodicity(_dates(self.base, 7, 6))
        self.assertEqual(result["periodicity_score"], 1.0)
        self.assertFalse(result["is_likely_subscription"])

    def test_same_merchant_unrelated_transactions_score_low_periodicity(self):
        """Five genuinely irregular visits to the same merchant (no
        underlying billing cycle) must not be mistaken for a subscription -
        low periodicity_score, not flagged."""
        irregular = [
            self.base,
            self.base + timedelta(days=3),
            self.base + timedelta(days=41),
            self.base + timedelta(days=52),
            self.base + timedelta(days=9),
        ]
        result = periodicity_extractor.calculate_periodicity(irregular)
        self.assertLess(result["periodicity_score"], 0.85)
        self.assertFalse(result["is_likely_subscription"])

    def test_recurring_transaction_with_amount_change_is_invisible_to_this_module(self):
        """FINDING: calculate_periodicity() takes only timestamps - it has no
        amount parameter at all, so a merchant billed monthly with a wildly
        different amount each time (a price hike, a metered/usage-based
        bill, or an unrelated same-merchant purchase interleaved with real
        subscription charges) scores identically to a stable-amount
        subscription. Amount stability would need to be checked by whatever
        wires this in, not by this module - it's a purely temporal signal."""
        result = periodicity_extractor.calculate_periodicity(_dates(self.base, 30, 6))
        self.assertTrue(result["is_likely_subscription"])
        # No amount signal exists anywhere in the return value to check.
        self.assertEqual(set(result.keys()), {"periodicity_score", "is_likely_subscription"})

    def test_recurring_transaction_with_date_drift_still_detected_within_tolerance(self):
        """Realistic monthly billing isn't exactly 30.0 days apart (28-35 day
        drift from calendar month length, weekends, retry timing) - the CV
        based score tolerates enough drift to still flag this as long as the
        average interval stays in the 27-33 day band."""
        drifting = [
            self.base,
            self.base + timedelta(days=28),
            self.base + timedelta(days=63),
            self.base + timedelta(days=95),
            self.base + timedelta(days=126),
        ]
        result = periodicity_extractor.calculate_periodicity(drifting)
        self.assertGreater(result["periodicity_score"], 0.85)
        self.assertTrue(result["is_likely_subscription"])

    def test_fewer_than_three_points_never_claims_a_pattern(self):
        """Two data points can't establish a cadence - must not fabricate a
        subscription signal from insufficient history."""
        result = periodicity_extractor.calculate_periodicity(_dates(self.base, 30, 2))
        self.assertEqual(result["periodicity_score"], 0.0)
        self.assertFalse(result["is_likely_subscription"])


if __name__ == "__main__":
    unittest.main()
