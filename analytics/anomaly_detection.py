from typing import Any

from database.mongo import db


class AnomalyDetector:
    async def flag_transaction(self, merchant_name: str, amount: float) -> dict[str, Any]:
        """
        Uses Phase 6 statistical baselines (mean, variance) to detect outlier spending
        in real-time (e.g., using a 3-Sigma / Z-Score rule).
        """
        pattern = await db.behavior_patterns.find_one({"merchant_name": merchant_name})

        if not pattern or pattern.get("std_dev", 0) == 0:
            return {"is_anomaly": False, "reason": "Insufficient baseline data"}

        avg_amount = pattern["avg_amount"]
        std_dev = pattern["std_dev"]

        # Z-Score Calculation: How many standard deviations away from the mean is this?
        z_score = abs(amount - avg_amount) / std_dev

        if z_score > 3.0: # 3 Sigma Rule
            direction = "higher" if amount > avg_amount else "lower"
            return {
                "is_anomaly": True,
                "confidence": min(0.99, z_score / 10.0),
                "reason": f"Amount is significantly {direction} than the typical {avg_amount:.2f} spent here."
            }

        return {"is_anomaly": False, "reason": "Normal spending range"}

anomaly_detector = AnomalyDetector()
