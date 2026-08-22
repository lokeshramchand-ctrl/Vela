import logging
import os

import numpy as np
import torch
from datasets import Dataset
from peft import LoraConfig, TaskType, get_peft_model
from sklearn.metrics import f1_score, roc_auc_score
from transformers import AutoModelForSequenceClassification, AutoTokenizer, EvalPrediction, Trainer, TrainingArguments

# Reuse the Expected Calibration Error (ECE) metric you defined in Phase 9
from evaluation.metrics import evaluator

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class FinetuneEngine:
    def __init__(self, base_model_id: str = "ProsusAI/finbert", output_dir: str = "./models/velar-finbert-lora"):
        self.base_model_id = base_model_id
        self.output_dir = output_dir

        # Load standard Tokenizer
        self.tokenizer = AutoTokenizer.from_pretrained(self.base_model_id)

    def load_training_data(self) -> tuple[Dataset, list[str]]:
        """
        In production, this connects to MongoDB: `db.feedback.find({"is_correction": True})`
        and combines it with your baseline dataset to prevent catastrophic forgetting.
        """
        logger.info("Extracting verified transaction data from Feedback Engine...")

        # Simulated data extracted from Phase 10 Feedback Loop
        raw_data = {
            "text": [
                "UPI/CR/1234/SWIGGY/HDFC",
                "NEFT/SALARY/TECH_CORP",
                "POS/STARBUCKS/MUMBAI",
                "UPI/DR/NETFLIX/SUBSCRIPTION"
            ] * 100, # Expanded for mock training
            "label_name": ["Food", "Income", "Food", "Subscription"] * 100
        }

        # Get unique classes
        unique_classes = sorted(list(set(raw_data["label_name"])))
        self.label2id = {label: i for i, label in enumerate(unique_classes)}
        self.id2label = {i: label for label, i in self.label2id.items()}

        # Convert labels to IDs
        raw_data["label"] = [self.label2id[label] for label in raw_data["label_name"]]

        dataset = Dataset.from_dict(raw_data)

        # Tokenize the dataset
        def tokenize_function(examples):
            return self.tokenizer(examples["text"], padding="max_length", truncation=True, max_length=64)

        tokenized_dataset = dataset.map(tokenize_function, batched=True)
        return tokenized_dataset.train_test_split(test_size=0.2), unique_classes

    def compute_metrics(self, p: EvalPrediction) -> dict[str, float]:
        """
        Calculates Phase 11 required metrics: F1, ROC AUC, and Calibration Error.
        """
        logits = p.predictions
        labels = p.label_ids

        # Convert logits to probabilities using Softmax
        probabilities = torch.nn.functional.softmax(torch.tensor(logits), dim=-1).numpy()
        predictions = np.argmax(probabilities, axis=-1)

        # F1 Score
        f1 = f1_score(labels, predictions, average="weighted")

        # ROC AUC (requires probabilities, highly useful for imbalanced transaction classes)
        try:
            roc_auc = roc_auc_score(labels, probabilities, multi_class="ovr", average="weighted")
        except ValueError:
            roc_auc = 0.0 # Fallback if a batch is missing a class

        # Expected Calibration Error (Crucial for Phase 5 Confidence Wall)
        ece = evaluator.expected_calibration_error(labels, probabilities)

        return {
            "f1": f1,
            "roc_auc": roc_auc,
            "calibration_error": ece
        }

    def train(self):
        """Executes the LoRA Fine-Tuning Pipeline."""
        datasets, classes = self.load_training_data()
        num_labels = len(classes)

        logger.info(f"Loading Base Model: {self.base_model_id} with {num_labels} classes.")

        # Load Base Model
        base_model = AutoModelForSequenceClassification.from_pretrained(
            self.base_model_id,
            num_labels=num_labels,
            id2label=self.id2label,
            label2id=self.label2id
        )

        # Configure LoRA (Low-Rank Adaptation)
        # r=8 and alpha=16 provides a great balance of accuracy vs memory for text classification
        peft_config = LoraConfig(
            task_type=TaskType.SEQ_CLS,
            inference_mode=False,
            r=8,
            lora_alpha=16,
            lora_dropout=0.1,
            target_modules=["query", "value"] # Targets specific attention layers in BERT
        )

        # Wrap model in PEFT
        model = get_peft_model(base_model, peft_config)
        model.print_trainable_parameters()

        # Define Training Arguments
        training_args = TrainingArguments(
            output_dir=self.output_dir,
            learning_rate=2e-4, # Higher LR is safe for LoRA compared to full fine-tuning
            per_device_train_batch_size=32,
            per_device_eval_batch_size=32,
            num_train_epochs=3,
            weight_decay=0.01,
            eval_strategy="epoch",
            save_strategy="epoch",
            load_best_model_at_end=True,
            metric_for_best_model="f1"
        )

        # Initialize Trainer
        trainer = Trainer(
            model=model,
            args=training_args,
            train_dataset=datasets["train"],
            eval_dataset=datasets["test"],
            tokenizer=self.tokenizer,
            compute_metrics=self.compute_metrics
        )

        logger.info("Starting LoRA Fine-Tuning...")
        trainer.train()

        # Save the finalized LoRA adapter
        final_save_path = os.path.join(self.output_dir, "final_adapter")
        model.save_pretrained(final_save_path)
        self.tokenizer.save_pretrained(final_save_path)
        logger.info(f"LoRA Adapter saved to {final_save_path}")

if __name__ == "__main__":
    # You can easily swap "ProsusAI/finbert" for "distilbert-base-uncased"
    engine = FinetuneEngine(base_model_id="ProsusAI/finbert")
    engine.train()
