import math
from datetime import datetime


class PeriodicityExtractor:
    def calculate_periodicity(self, timestamps: list[datetime]) -> dict:
        n = len(timestamps)
        if n < 3:
            # Need at least 3 points to establish a meaningful pattern of intervals
            return {
                "periodicity_score": 0.0,
                "is_likely_subscription": False
            }

        sorted_times = sorted(timestamps)

        # Calculate intervals (in days) between consecutive transactions
        intervals = [(sorted_times[i] - sorted_times[i-1]).total_seconds() / 86400.0 for i in range(1, n)]

        avg_interval = sum(intervals) / len(intervals)

        if avg_interval == 0:
            return {"periodicity_score": 1.0, "is_likely_subscription": False}

        # Calculate Coefficient of Variation (CV = std_dev / mean)
        interval_variance = sum((x - avg_interval) ** 2 for x in intervals) / len(intervals)
        interval_std_dev = math.sqrt(interval_variance)

        cv = interval_std_dev / avg_interval

        # Map CV to an invert score between 0.0 and 1.0
        # A score of 1.0 means exactly the same number of days between every transaction
        periodicity_score = 1.0 / (1.0 + cv)

        # Subscription Detection Logic
        # High periodicity score + ~30 days (monthly) or ~365 days (annual) average interval
        is_subscription = False
        if periodicity_score > 0.85:
            if (27 <= avg_interval <= 33) or (360 <= avg_interval <= 370):
                is_subscription = True

        return {
            "periodicity_score": round(periodicity_score, 4),
            "is_likely_subscription": is_subscription
        }

periodicity_extractor = PeriodicityExtractor()
