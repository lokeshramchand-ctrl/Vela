import logging

import numpy as np
import pandas as pd
import shap
from sklearn.metrics import accuracy_score, f1_score, precision_score, recall_score, top_k_accuracy_score

logger = logging.getLogger(__name__)

class ModelEvaluator:
    @staticmethod
    def expected_calibration_error(y_true: np.ndarray, y_prob: np.ndarray, n_bins: int = 10) -> float:
        """
        Calculates Expected Calibration Error (ECE) for multi-class classification.
        Ensures a model predicting 80% confidence is actually correct 80% of the time.
        """
        confidences = np.max(y_prob, axis=1)
        predictions = np.argmax(y_prob, axis=1)
        accuracies = predictions == y_true

        ece = 0.0
        bin_boundaries = np.linspace(0, 1, n_bins + 1)

        for i in range(n_bins):
            in_bin = np.logical_and(confidences > bin_boundaries[i], confidences <= bin_boundaries[i+1])
            prob_in_bin = in_bin.mean()

            if prob_in_bin > 0:
                accuracy_in_bin = accuracies[in_bin].mean()
                avg_confidence_in_bin = confidences[in_bin].mean()
                ece += np.abs(avg_confidence_in_bin - accuracy_in_bin) * prob_in_bin

        return float(ece)

    def evaluate(self, model_name: str, y_true: np.ndarray, y_pred: np.ndarray, y_prob: np.ndarray, classes: list[str]) -> dict[str, float]:
        """Calculates standard classification metrics."""

        # Safe Top-3 calculation (fallback to Top-1 if fewer than 3 classes exist)
        k = min(3, len(classes))
        top_k = top_k_accuracy_score(y_true, y_prob, k=k, labels=np.arange(len(classes)))

        metrics = {
            "model": model_name,
            "accuracy": round(accuracy_score(y_true, y_pred), 4),
            "precision_macro": round(precision_score(y_true, y_pred, average='macro', zero_division=0), 4),
            "recall_macro": round(recall_score(y_true, y_pred, average='macro', zero_division=0), 4),
            "f1_macro": round(f1_score(y_true, y_pred, average='macro', zero_division=0), 4),
            f"top_{k}_accuracy": round(top_k, 4),
            "calibration_error_ece": round(self.expected_calibration_error(y_true, y_prob), 4)
        }

        logger.info(f"[{model_name}] Eval Complete - F1: {metrics['f1_macro']} | ECE: {metrics['calibration_error_ece']}")
        return metrics

    @staticmethod
    def generate_shap_importances(model, X_test: pd.DataFrame, model_name: str) -> dict[str, float]:
        """
        Calculates Global Feature Importance using SHAP.
        Explains *why* the model makes its decisions.
        """
        try:
            # TreeExplainer for Tree-based models (RF, XGBoost, LightGBM)
            if model_name in ["RandomForest", "XGBoost", "LightGBM"]:
                explainer = shap.TreeExplainer(model)
                shap_values = explainer.shap_values(X_test)

                # Handle multi-class shape outputs from different tree models safely
                if isinstance(shap_values, list):
                    vals = np.abs(shap_values[0]).mean(0)
                elif len(shap_values.shape) == 3:
                    vals = np.abs(shap_values).mean(0).mean(1)
                else:
                    vals = np.abs(shap_values).mean(0)
            else:
                # LinearExplainer for Logistic Regression
                explainer = shap.LinearExplainer(model, X_test)
                shap_values = explainer.shap_values(X_test)
                vals = np.abs(shap_values).mean(0)

            feature_importance = pd.DataFrame(list(zip(X_test.columns, vals, strict=True)), columns=['feature', 'importance'])
            feature_importance.sort_values(by=['importance'], ascending=False, inplace=True)

            return feature_importance.set_index('feature')['importance'].to_dict()

        except Exception as e:
            logger.warning(f"SHAP generation failed for {model_name}: {e}")
            return {}

evaluator = ModelEvaluator()
