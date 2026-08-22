import logging

import numpy as np
import pandas as pd
from lightgbm import LGBMClassifier
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestClassifier

# Model Architectures
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import LabelEncoder, OneHotEncoder, StandardScaler
from xgboost import XGBClassifier

from evaluation.metrics import evaluator

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class BaselineTrainer:
    def __init__(self):
        # Phase 9 Specific Features
        self.numeric_features = ['amount', 'hour', 'frequency']
        self.categorical_features = ['merchant', 'cluster_id', 'memory_state']

        # Prepare standard preprocessing (scaling for numeric, encoding for categorical)
        self.preprocessor = ColumnTransformer(
            transformers=[
                ('num', StandardScaler(), self.numeric_features),
                ('cat', OneHotEncoder(handle_unknown='ignore', sparse_output=False), self.categorical_features)
            ])

        self.models = {
            "LogisticRegression": LogisticRegression(max_iter=1000, class_weight='balanced'),
            "RandomForest": RandomForestClassifier(n_estimators=100, random_state=42, class_weight='balanced'),
            "LightGBM": LGBMClassifier(n_estimators=100, random_state=42, class_weight='balanced'),
            "XGBoost": XGBClassifier(n_estimators=100, random_state=42, eval_metric='mlogloss')
        }

    def load_data(self) -> pd.DataFrame:
        """
        Mock data loader. In production, this queries your MongoDB
        `transactions` collection, joining with `behavior_patterns`.
        """
        # Simulated dataframe representing fully enriched Phase 8 data
        data = {
            'amount': np.random.exponential(500, 1000),
            'hour': np.random.randint(0, 24, 1000),
            'frequency': np.random.poisson(3, 1000),
            'merchant': np.random.choice(['Swiggy', 'Uber', 'Unknown', 'Netflix'], 1000),
            'cluster_id': np.random.choice(['cluster_0', 'cluster_1', 'noise'], 1000),
            'memory_state': np.random.choice(['PERMANENT', 'TEMPORARY', 'EPHEMERAL'], 1000),
            'category': np.random.choice(['Food', 'Travel', 'Subscription', 'Unknown'], 1000)
        }
        return pd.DataFrame(data)

    def run_benchmarks(self):
        """Executes the full training and evaluation benchmark suite."""
        df = self.load_data()

        X = df[self.numeric_features + self.categorical_features]
        y_raw = df['category']

        # Encode Target Labels
        label_encoder = LabelEncoder()
        y = label_encoder.fit_transform(y_raw)
        classes = list(label_encoder.classes_)

        X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)
        logger.info(f"Training Data: {X_train.shape[0]} rows. Categories: {classes}")

        benchmark_results = []

        for model_name, model in self.models.items():
            logger.info(f"--- Training {model_name} ---")

            # Create Pipeline
            pipeline = Pipeline(steps=[
                ('preprocessor', self.preprocessor),
                ('classifier', model)
            ])

            # Train
            pipeline.fit(X_train, y_train)

            # Predict
            y_pred = pipeline.predict(X_test)
            y_prob = pipeline.predict_proba(X_test)

            # Evaluate Metrics
            metrics = evaluator.evaluate(model_name, y_test, y_pred, y_prob, classes)
            benchmark_results.append(metrics)

            # SHAP Explainability extraction (requires transformed features)
            X_test_transformed = pd.DataFrame(
                pipeline.named_steps['preprocessor'].transform(X_test),
                columns=pipeline.named_steps['preprocessor'].get_feature_names_out()
            )
            trained_classifier = pipeline.named_steps['classifier']

            importances = evaluator.generate_shap_importances(trained_classifier, X_test_transformed, model_name)
            if importances:
                top_feature = list(importances.keys())[0]
                logger.info(f"[{model_name}] Top SHAP Feature: {top_feature}")

        # In Phase 14, we will push these results directly to MLflow.
        results_df = pd.DataFrame(benchmark_results)
        print("\n--- Benchmark Summary ---")
        print(results_df.to_markdown(index=False))

if __name__ == "__main__":
    # Ensure dependencies: pip install pandas scikit-learn lightgbm xgboost shap
    trainer = BaselineTrainer()
    trainer.run_benchmarks()
