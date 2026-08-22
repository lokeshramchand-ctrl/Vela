# File: `training/train.py`

## Purpose
A script-invoked benchmark harness comparing four classical ML classifiers for transaction categorization, using synthetic data as a stand-in for real production data.

## Responsibilities
- Define a preprocessing pipeline (scaling numeric features, one-hot encoding categorical features).
- Train and evaluate four different model architectures on the same data split.
- Extract SHAP feature importances for each trained model.
- Print a comparative benchmark summary.

## Imports
| Import | Used for |
|---|---|
| `logging` | Progress logging |
| `pandas` | Synthetic DataFrame construction and results table formatting |
| `numpy` | Random data generation |
| `sklearn.model_selection.train_test_split` | Splitting data into train/test sets |
| `sklearn.preprocessing.StandardScaler, OneHotEncoder, LabelEncoder` | Feature scaling, categorical encoding, target label encoding |
| `sklearn.compose.ColumnTransformer` | Combining different preprocessing per column type |
| `sklearn.pipeline.Pipeline` | Chaining preprocessing and model into one fit/predict unit |
| `sklearn.linear_model.LogisticRegression` | Model 1 |
| `sklearn.ensemble.RandomForestClassifier` | Model 2 |
| `lightgbm.LGBMClassifier` | Model 3 |
| `xgboost.XGBClassifier` | Model 4 |
| `evaluation.metrics.evaluator` | Shared metric computation |

## Exports
**`BaselineTrainer`** — the class. No module-level singleton is created here (unlike most other files in this codebase) — an instance is only created inside the `if __name__ == "__main__":` block, meaning importing this file elsewhere does **not** automatically create a trainer or trigger any I/O.

## Execution Flow
This file has no effect when merely imported (no top-level singleton instantiation). It only does anything when run directly: `trainer = BaselineTrainer()` → `trainer.run_benchmarks()`, which internally calls `load_data()` once, then loops over all four models sequentially.

## Functions (plain English)

### `BaselineTrainer.__init__(self)`
In simple English: "Set up everything needed before training starts: which columns are numbers that need scaling (amount, hour, frequency), which are categories that need encoding (merchant, cluster ID, memory state), a combined preprocessing recipe for both kinds of columns, and a dictionary of four different model types to try, each configured to handle class imbalance."

### `BaselineTrainer.load_data(self) -> pd.DataFrame`
In simple English: "Generate 1,000 rows of made-up, random transaction-like data — random amounts following a realistic-looking distribution, random hours, random visit frequencies, and randomly-assigned merchant/cluster/memory-state/category labels. This is a stand-in for what would eventually be a real query against the actual transaction database." Despite its docstring describing an intended MongoDB query, this function does not touch any database — it's purely synthetic data generation.

### `BaselineTrainer.run_benchmarks(self)`
In simple English: "Get the (synthetic) training data. Separate out the columns we'll use as input features from the category we're trying to predict, and convert that target category into numeric labels the models can work with. Split everything into a training portion and a held-out test portion, keeping the same proportion of each category in both (stratified splitting). Then, one model at a time: build a full pipeline combining our preprocessing steps with that specific model, train it on the training data, use it to make predictions on the test data, score how well it did using our standard evaluation metrics, and also figure out which input features mattered most to that model's decisions using SHAP. After going through all four models, print out a neat side-by-side comparison table of how each one performed."

## Classes

### `BaselineTrainer`
Instance attributes: `self.numeric_features`, `self.categorical_features` (lists of column names), `self.preprocessor` (a `ColumnTransformer`), `self.models` (a dict of four configured, untrained model instances).

## Interfaces
Not applicable formally — though this file conforms to the standard scikit-learn `Pipeline`/`fit`/`predict`/`predict_proba` conventions throughout.

## Hooks
Not applicable — the `if __name__ == "__main__":` block is Python's standard "only run this if executed directly, not if imported" convention, not a framework-specific hook.

## Utilities
None beyond the three methods described above.

## Dependencies
`pandas`, `numpy`, `scikit-learn`, `lightgbm`, `xgboost` (all third-party); `evaluation.metrics` (internal).

## Side Effects
- No database or network I/O anywhere in this file — everything operates on in-memory synthetic data.
- Prints to stdout (the final benchmark table).
- Logs progress via the module logger.
- Model training itself is CPU-intensive but produces no persistent side effects (nothing is saved to disk — trained models are discarded once the script ends).

## Performance Considerations
- Training four different model architectures sequentially (not in parallel) on the same 1,000-row synthetic dataset — fast in absolute terms given the small data size, but would need parallelization (e.g., `joblib`) to scale efficiently if run against a much larger real dataset with all four models.
- `RandomForestClassifier`, `LGBMClassifier`, and `XGBClassifier` all use `n_estimators=100` — a moderate, reasonable default tree count that balances training speed against model quality for a first-pass benchmark.
- SHAP computation (`generate_shap_importances`, called once per model) can be notably slower than the model training itself for tree-based models on larger datasets — `TreeExplainer` is relatively efficient, but still adds meaningful overhead on top of the fit/predict cycle.

## Possible Interview Questions
- "Why does `load_data` generate synthetic data instead of querying MongoDB, despite its own docstring describing the intended production behavior?" (This is explicitly a benchmark/template script — the docstring documents *intended* future behavior, but the actual implementation was never connected to real data; a good prompt to check whether documentation and implementation have drifted apart.)
- "Why is `BaselineTrainer` not instantiated as a module-level singleton the way almost everything else in this codebase is?" (Because this file is meant to be run as a standalone script, not imported as a library component by other application code — instantiating it only inside `if __name__ == '__main__':` avoids any accidental side effects (like generating random data or logging) just from importing the module for, say, testing or introspection.)
- "Why train four different model types instead of just picking one architecture upfront?" (Different model families have different strengths — linear models are fast and interpretable but limited in capturing non-linear patterns; tree-based ensembles (Random Forest, LightGBM, XGBoost) can capture more complex feature interactions. Benchmarking all four on the same data and metrics gives an empirical basis for choosing, rather than guessing which will perform best.)
- "This script has no persistence step — trained models vanish when it ends. What would you add to make this production-useful?" (A model-serialization step — e.g., `joblib.dump` or a proper model registry integration (the code's own comment mentions MLflow) — to save the best-performing model's artifacts somewhere the live application could later load and use for real predictions.)
