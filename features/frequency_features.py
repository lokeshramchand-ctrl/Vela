from datetime import datetime


class FrequencyExtractor:
    def extract_frequency_metrics(self, timestamps: list[datetime]) -> dict:
        n = len(timestamps)
        if n < 2:
            return {
                "daily_frequency": 0.0,
                "weekly_frequency": 0.0,
                "avg_days_between": 0.0
            }

        # Sort chronologically
        sorted_times = sorted(timestamps)

        # Calculate total timespan in days
        total_span_days = (sorted_times[-1] - sorted_times[0]).total_seconds() / 86400.0

        # Prevent division by zero if multiple transactions happen on the exact same day
        total_span_days = max(total_span_days, 1.0)

        daily_freq = n / total_span_days
        weekly_freq = daily_freq * 7.0

        # Average days between transactions
        avg_days_between = total_span_days / (n - 1)

        return {
            "daily_frequency": round(daily_freq, 4),
            "weekly_frequency": round(weekly_freq, 4),
            "avg_days_between": round(avg_days_between, 2)
        }

frequency_extractor = FrequencyExtractor()
