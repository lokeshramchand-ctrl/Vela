from datetime import datetime


class TemporalExtractor:
    @staticmethod
    def get_time_bucket(hour: int) -> str:
        if 5 <= hour < 12:
            return "morning"
        if 12 <= hour < 17:
            return "afternoon"
        if 17 <= hour < 21:
            return "evening"
        return "night"

    def extract_temporal_metrics(self, timestamps: list[datetime]) -> dict:
        if not timestamps:
            return {
                "preferred_hour": 12,
                "time_bucket_distribution": {},
                "weekday_distribution": [0.0] * 7
            }

        hours = [t.hour for t in timestamps]
        preferred_hour = max(set(hours), key=hours.count)

        # Initialize distributions
        buckets = {"morning": 0.0, "afternoon": 0.0, "evening": 0.0, "night": 0.0}
        weekday_counts = [0.0] * 7

        for t in timestamps:
            buckets[self.get_time_bucket(t.hour)] += 1.0
            weekday_counts[t.weekday()] += 1.0

        total = len(timestamps)
        normalized_buckets = {k: v / total for k, v in buckets.items()}
        normalized_weekdays = [v / total for v in weekday_counts]

        return {
            "preferred_hour": preferred_hour,
            "time_bucket_distribution": normalized_buckets,
            "weekday_distribution": normalized_weekdays
        }

temporal_extractor = TemporalExtractor()
