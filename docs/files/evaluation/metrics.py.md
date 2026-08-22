# File: `evaluation/metrics.py`

## Purpose
The shared metrics toolkit used by both training pipelines: standard classification metrics, calibration measurement, and model-agnostic SHAP feature-importance extraction.

## Responsibilities
- Compute Expected Calibration Error (ECE).
- Compute a standard bundle of classification metrics (accuracy, precision, recall, F1, top-k accuracy, ECE).
- Compute global feature importances via SHAP, handling multiple model/library output shapes.

## Imports
| Import | Used for |
|---|---|
| `numpy` | Array math throughout |
| `pandas` | Building the SHAP feature-importance result table |
| `shap` | The SHAP explainability library |
| `typing.Dict, Any, List` | Type hints |
| `sklearn.metrics.accuracy_score, precision_score, recall_score, f1_score, top_k_accuracy_score` | The five standard classification metrics |
| `logging` | Result logging and failure warnings |

## Exports
- **`ModelEvaluator`** — the class.
- **`evaluator`** — the singleton instance, imported by `training/train.py` and `training/finetune.py`.

## Execution Flow
On import, `evaluator = ModelEvaluator()` runs trivially (no state, no I/O). Each method is called independently by the training scripts, once per trained model.

## Functions (plain English)

### `ModelEvaluator.expected_calibration_error(y_true, y_prob, n_bins=10)` (static method)
In simple English: "Check whether the model's confidence levels actually mean what they claim. Split all the predictions into 10 buckets based on how confident the model was (0-10% confident, 10-20%, and so on). For each bucket that actually has predictions in it, compare the model's average stated confidence in that bucket against how often it was *actually* correct in that bucket. If those two numbers match closely across all buckets, the model is well-calibrated (low error). If a bucket says '90% confident' but the model was only right 60% of the time in that bucket, that's a big calibration gap. Add up all these gaps, weighted by how many predictions fell into each bucket, to get one overall calibration error score — lower is better, meaning the model's confidence is trustworthy."

### `ModelEvaluator.evaluate(self, model_name, y_true, y_pred, y_prob, classes) -> Dict[str, float]`
In simple English: "Given a model's predictions on a test set, compute a whole report card of standard scores: how often it was exactly right (accuracy), how precise and how complete its predictions were on average across all categories (macro precision/recall), a combined balance of those two (F1), whether the correct answer was at least among its top 3 guesses (or fewer, if there aren't even 3 categories total), and how well-calibrated its confidence was. Package all of that, plus the model's name, into one tidy dictionary, log a quick summary, and hand it back."

### `ModelEvaluator.generate_shap_importances(model, X_test, model_name) -> Dict[str, float]` (static method)
In simple English: "Figure out which input features actually mattered most to this specific model's decisions. Different types of models need different explanation techniques: for tree-based models (Random Forest, XGBoost, LightGBM), use a fast, tree-specific explainer; for anything else (like Logistic Regression), use a explainer designed for linear models. Different versions of these explainer tools can hand back their results in different shapes, so carefully normalize whatever we get into one consistent format: one importance number per feature, averaged appropriately depending on the shape we received. Sort the features from most to least important and hand back that ranked list as a dictionary. If anything at all goes wrong during this process — an incompatible model type, a library quirk — don't let it crash the whole training run; just log a warning and return an empty result instead."

## Classes

### `ModelEvaluator`
No instance state — every method is either `@staticmethod` or operates purely on its arguments; the class exists as an organizational namespace.

## Interfaces
`evaluate(...)`'s returned dict shape is the implicit contract both training scripts rely on to build their comparison tables.

## Hooks
Not applicable.

## Utilities
All three methods function as reusable utilities — this entire file is, in effect, a utility module.

## Dependencies
`numpy`, `pandas`, `shap`, `scikit-learn` (all third-party). No internal dependencies.

## Side Effects
- Logs a summary line per model evaluation.
- Logs a warning if SHAP computation fails for a given model.
- No I/O beyond logging — everything else is pure in-memory computation.

## Performance Considerations
- `expected_calibration_error` does a single pass over the data per bin (`n_bins` iterations, each doing a boolean mask over the full array) — O(n_bins × n) overall, trivial for realistic dataset sizes.
- `generate_shap_importances` can be meaningfully slower than the other metrics — `TreeExplainer` is relatively efficient for tree models, but `LinearExplainer` and SHAP computation in general can still add noticeable overhead, especially as the number of test examples or features grows.
- `top_k_accuracy_score` with `k = min(3, len(classes))` avoids a crash/undefined behavior when fewer than 3 classes exist, at the cost of the resulting metric not being directly comparable across differently-sized label sets (a "top-2 accuracy" and a "top-3 accuracy" aren't the same measurement).

## Possible Interview Questions
- "Explain Expected Calibration Error to someone who's never heard of it, using a concrete example." (Imagine a model that says '80% confident' for 100 different predictions. If it turns out to actually be correct in 80 of those 100 cases, it's perfectly calibrated for that confidence level — a 0% gap. If it's only correct in 50 of those 100 cases, that's a 30-percentage-point gap for that bucket, which gets factored into the overall ECE score, weighted by how many total predictions fell into that confidence bucket.)
- "Why does this system care about calibration specifically, beyond just wanting an accurate model?" (Because `engines/confidence_engine.py`'s entire 'confidence wall' design assumes a confidence score of, say, 0.5 genuinely means '50% likely to be correct' — if the underlying model is poorly calibrated, that threshold doesn't actually mean what the system assumes it means, undermining the whole hallucination-prevention strategy.)
- "Why does `generate_shap_importances` need three different branches to handle SHAP's output shapes?" (Different SHAP explainer types and different versions of the underlying libraries return values in inconsistent shapes — sometimes a list of per-class arrays, sometimes a single 3D array, sometimes a flat 2D array — this function normalizes all three into one consistent per-feature importance vector so callers don't need to know which shape they're dealing with.)
- "Why catch and swallow all exceptions in `generate_shap_importances` but not in `evaluate`?" (SHAP explanation is treated as a diagnostic nice-to-have that shouldn't be allowed to derail an otherwise-successful training run if it fails for some model-specific or library-version reason; core evaluation metrics, by contrast, are considered essential enough that a failure there should surface loudly rather than being silently masked.)
