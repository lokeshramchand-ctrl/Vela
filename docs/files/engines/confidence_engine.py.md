# File: `engines/confidence_engine.py`

## Purpose
Implements the "confidence wall" — the Phase 5 policy that rejects low-confidence or out-of-vocabulary predictions rather than letting them masquerade as trustworthy categorizations.

## Responsibilities
- Validate a predicted category against the known `TransactionCategory` vocabulary.
- Apply a (currently trivial) calibration step to a raw confidence score.
- Enforce a minimum confidence threshold, forcing anything below it to `Unknown`.

## Imports
| Import | Used for |
|---|---|
| `logging` | Logging rejected/invalid predictions |
| `models.schemas.TransactionCategory, ConfidenceEvaluation` | The closed category vocabulary and the output contract |

## Exports
- **`ConfidenceEngine`** — the class.
- **`confidence_engine`** — the singleton instance, `threshold=0.5`, imported by `routers/v1.py`.

## Execution Flow
1. On import, `confidence_engine = ConfidenceEngine(threshold=0.5)` runs — this precomputes `self.valid_categories` once (every `TransactionCategory` member except `UNKNOWN`).
2. Per call, `evaluate(...)` runs the full decision logic synchronously, with no I/O.

## Functions (plain English)

### `ConfidenceEngine.__init__(self, threshold: float = 0.5)`
In simple English: "Remember what confidence threshold we're using, and precompute the full list of category names we're willing to trust (every real category except 'Unknown' itself, since a model shouldn't be 'predicting' Unknown directly — that's a rejection outcome, not a real prediction)."

### `ConfidenceEngine.calibrate_probability(self, raw_confidence: float, category: str) -> float`
In simple English: "Take whatever confidence number was given and make sure it's squeezed into the valid range between 0.0 and 1.0 — if it's negative, bump it up to 0; if it's above 1, cap it at 1. Right now, that's literally all this does — it doesn't actually adjust the number based on any learned calibration curve, even though the name suggests it eventually will." The `category` parameter is accepted but currently unused inside the function body — a placeholder for a future per-category calibration adjustment.

### `ConfidenceEngine.evaluate(self, predicted_category: str, raw_confidence: float) -> ConfidenceEvaluation`
In simple English: "First, clean up the confidence number using `calibrate_probability`. Then check: is the predicted category even one of the categories we recognize? If not, that's a red flag — treat it as an invalid prediction, log a warning, and force the result to 'Unknown' with zero confidence. If the category is valid, check the (calibrated) confidence against our threshold of 0.5. If it's too low, again force the result to 'Unknown,' but this time keep the actual confidence number and mark that calibration was applied. If the confidence is high enough, trust the prediction as-is and return it unchanged, just repackaged into our standard evaluation format." This is the one public method — everything else in this class exists to support it.

## Classes

### `ConfidenceEngine`
Instance attributes: `self.threshold` (float, defaults `0.5`), `self.valid_categories` (a `set[str]` computed once at construction). No inheritance beyond `object`.

## Interfaces
`ConfidenceEvaluation` (from `models/schemas.py`) is the output contract every call to `evaluate()` returns — a predictable, typed shape regardless of which branch of the logic was taken.

## Hooks
Not applicable.

## Utilities
`calibrate_probability` is best understood as an internal utility supporting `evaluate` — though it's a public method (no leading underscore), nothing outside this class calls it directly today.

## Dependencies
`logging` (standard library); `models.schemas` (internal). No third-party dependencies.

## Side Effects
- Logs a warning on invalid-category rejections and an info-level message on low-confidence rejections.
- No I/O, no database access, no mutation of anything outside the instance's own (immutable-after-construction) attributes.

## Performance Considerations
Trivial — a set membership check, a comparison, and a few dict/object constructions. This function could be called an enormous number of times per second with no meaningful performance concern, since it's pure in-memory logic with no I/O.

## Possible Interview Questions
- "Why is `calibrate_probability` currently just a clamp, and what would 'real' calibration look like?" (A real implementation might use Platt scaling — fitting a logistic regression on top of the raw model outputs — or isotonic regression, to correct for a model being systematically over- or under-confident; the current version does neither, so `calibration_applied: "identity"` is honestly named but not yet doing meaningful calibration work.)
- "Why does the engine treat 'predicted category is not in our vocabulary' as a *different* kind of rejection (`calibration_applied: 'none'`) than 'confidence too low' (`calibration_applied: 'identity'`)?" (They represent different failure modes worth distinguishing for diagnostics: one means 'the upstream model is fundamentally broken or out of spec,' the other means 'the upstream model is working correctly but just isn't sure' — conflating them would lose that signal for anyone debugging model behavior later.)
- "Why is `UNKNOWN` excluded from `valid_categories`?" (Because `Unknown` is meant to be an *outcome* of this engine's rejection logic, not something a model should ever legitimately 'predict' as a confident answer — allowing it as a valid input category would blur the distinction between 'the model doesn't know' and 'the confidence wall rejected this.')
- "Is `threshold=0.5` justified by any evidence in this codebase?" (No — it's a hardcoded default with no accompanying calibration study or reference to `evaluation/metrics.py`'s `expected_calibration_error`, which is exactly the kind of metric that *should* inform whether 0.5 is actually the right cutoff for this specific model's calibration behavior.)
