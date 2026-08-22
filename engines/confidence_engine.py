import logging

from models.schemas import ConfidenceEvaluation, TransactionCategory

logger = logging.getLogger(__name__)

class ConfidenceEngine:
    def __init__(self, threshold: float = 0.5):
        self.threshold = threshold
        # Set of valid categories known to the system
        self.valid_categories = {cat.value for cat in TransactionCategory if cat != TransactionCategory.UNKNOWN}

    def calibrate_probability(self, raw_confidence: float, category: str) -> float:
        """
        Applies a calibration scale factor.
        In Phase 9+, this will map back to a calibrated Platt scaling or isotonic regression vector.
        For now, it acts as an identity pass-through.
        """
        # Ensure confidence stays strictly between 0.0 and 1.0
        return max(0.0, min(1.0, raw_confidence))

    def evaluate(self, predicted_category: str, raw_confidence: float) -> ConfidenceEvaluation:
        """
        Evaluates a model prediction against the confidence threshold wall.
        If confidence drops below the threshold, it flags it as an hallucination risk
        and overrides the category to 'Unknown'.
        """
        calibrated_conf = self.calibrate_probability(raw_confidence, predicted_category)

        # Guard clause for out-of-vocabulary model responses
        if predicted_category not in self.valid_categories:
            logger.warning(f"Model returned invalid category '{predicted_category}'. Defaulting to Unknown.")
            return ConfidenceEvaluation(
                raw_category=predicted_category,
                final_category=TransactionCategory.UNKNOWN,
                confidence=0.0,
                is_hallucination_risk=True,
                calibration_applied="none"
            )

        # Enforce Core Strategic Rule: Confidence < 0.5 -> Unknown
        if calibrated_conf < self.threshold:
            logger.info(
                f"Prediction '{predicted_category}' rejected due to low confidence ({calibrated_conf:.4f} < {self.threshold}). "
                f"Routed to Unknown."
            )
            return ConfidenceEvaluation(
                raw_category=predicted_category,
                final_category=TransactionCategory.UNKNOWN,
                confidence=calibrated_conf,
                is_hallucination_risk=True,
                calibration_applied="identity"
            )

        # High confidence match passed through
        return ConfidenceEvaluation(
            raw_category=predicted_category,
            final_category=TransactionCategory(predicted_category),
            confidence=calibrated_conf,
            is_hallucination_risk=False,
            calibration_applied="identity"
        )

# Singleton Instance
confidence_engine = ConfidenceEngine(threshold=0.5)
