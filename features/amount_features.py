import math


class AmountExtractor:
    def extract_statistical_metrics(self, amounts: list[float]) -> dict:
        n = len(amounts)
        if n == 0:
            return {"avg_amount": 0.0, "median_amount": 0.0, "variance": 0.0, "std_dev": 0.0, "entropy_score": 0.0}

        mean_val = sum(amounts) / n

        # Median Calculation
        sorted_amts = sorted(amounts)
        mid = n // 2
        median_val = (sorted_amts[mid] + sorted_amts[~mid]) / 2.0

        # Variance and Standard Deviation
        variance_val = sum((x - mean_val) ** 2 for x in amounts) / n if n > 1 else 0.0
        std_dev_val = math.sqrt(variance_val)

        # Amount Entropy (Value distribution predictability)
        # Groups amounts into rough visual bins to calculate behavioral chaos
        rounded_amts = [round(x, -1) for x in amounts]
        unique_counts = {}
        for amt in rounded_amts:
            unique_counts[amt] = unique_counts.get(amt, 0) + 1

        entropy_val = 0.0
        for count in unique_counts.values():
            p = count / n
            entropy_val -= p * math.log2(p)

        return {
            "avg_amount": mean_val,
            "median_amount": median_val,
            "variance": variance_val,
            "std_dev": std_dev_val,
            "entropy_score": round(entropy_val, 4)
        }

amount_extractor = AmountExtractor()
