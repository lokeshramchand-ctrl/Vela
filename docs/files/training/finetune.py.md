# File: `training/finetune.py`

## Purpose
A script-invoked LoRA fine-tuning pipeline adapting a pretrained financial-domain BERT model (`ProsusAI/finbert`) for transaction categorization, using mock data as a stand-in for real feedback data.

## Responsibilities
- Load a tokenizer and prepare a (currently mock) labeled dataset.
- Configure and apply LoRA to a pretrained sequence-classification model.
- Compute rich evaluation metrics (F1, ROC AUC, calibration error) during training.
- Train and save the resulting LoRA adapter.

## Imports
| Import | Used for |
|---|---|
| `os` | Building the adapter save path |
| `torch` | Softmax conversion of logits to probabilities |
| `numpy` | Argmax over probabilities |
| `logging` | Progress logging |
| `typing.Dict, List, Tuple` | Type hints |
| `datasets.Dataset` | HuggingFace dataset construction/splitting |
| `transformers.AutoTokenizer, AutoModelForSequenceClassification, TrainingArguments, Trainer, EvalPrediction` | Model loading, training configuration, and the training loop itself |
| `peft.get_peft_model, LoraConfig, TaskType` | Applying LoRA adaptation to the base model |
| `sklearn.metrics.f1_score, roc_auc_score` | Two of the three metrics computed during evaluation |
| `evaluation.metrics.evaluator` | Reused `expected_calibration_error` computation |

## Exports
**`FinetuneEngine`** â€” the class. Like `training/train.py`, no module-level singleton is created â€” an instance is only constructed inside `if __name__ == "__main__":`.

## Execution Flow
No effect on plain import. When run directly: `engine = FinetuneEngine(base_model_id="ProsusAI/finbert")` â†’ `engine.train()`, which internally calls `load_training_data()` once, then runs the full HuggingFace `Trainer.train()` loop (3 epochs, evaluating and computing metrics after each), then saves the resulting adapter to disk.

## Functions (plain English)

### `FinetuneEngine.__init__(self, base_model_id="ProsusAI/finbert", output_dir="./models/Vela-finbert-lora")`
In simple English: "Remember which pretrained model we're starting from and where to save our results, then immediately load that model's tokenizer (the tool that converts raw text into the numeric tokens the model actually understands)."

### `FinetuneEngine.load_training_data(self) -> Tuple[Dataset, List[str]]`
In simple English: "Build a small, made-up training dataset â€” a handful of example transaction texts (like a UPI Swiggy payment, a salary deposit, a Starbucks purchase, a Netflix charge) repeated 100 times each, paired with their correct categories. Figure out the full list of distinct categories present, and build lookup tables to convert between category names and numeric IDs (since the model needs numbers, not text labels). Convert every example's text into the token format the model expects. Finally, split this whole dataset into a training portion and a held-out testing portion, and hand back both, along with the list of category names." As with `training/train.py`, this uses hardcoded mock data rather than a real query against the feedback database, despite the docstring describing that intended production behavior.

### `FinetuneEngine.compute_metrics(self, p: EvalPrediction) -> Dict[str, float]`
In simple English: "After the model makes predictions during an evaluation pass, take its raw output scores and convert them into proper probabilities (using softmax, which makes sure all the probabilities for one example add up to 100%). Figure out which category the model actually guessed for each example (whichever had the highest probability). Compute how well those guesses matched the true answers using a standard scoring measure (F1) that balances catching every category correctly. Also try to compute how well the model can distinguish between all the different categories overall (ROC AUC) â€” though if a particular evaluation batch happens to be missing examples of some category, just report a score of 0 instead of crashing. Finally, measure how well-calibrated the model's confidence actually is â€” does it saying '80% sure' actually mean it's right 80% of the time? Report all three numbers together."

### `FinetuneEngine.train(self)`
In simple English: "Prepare the training and test data. Load the actual pretrained financial-BERT model, configured to output exactly as many categories as we found in our data. Apply LoRA â€” a technique that only trains a small number of new, added parameters rather than the entire massive pretrained model, making fine-tuning dramatically cheaper and faster while still adapting the model's behavior meaningfully. Print out how many parameters we'll actually be training, for visibility. Set up all the training configuration: how fast to learn, how many examples to process at once, how many full passes over the data to make (3), and to always keep whichever version of the model scored best on F1 across those passes. Hand everything to HuggingFace's training engine and let it run the actual training loop. Once done, save just the small LoRA adaptation (not the entire base model) to disk, along with the tokenizer, so it can be loaded and used later."

## Classes

### `FinetuneEngine`
Instance attributes: `self.base_model_id`, `self.output_dir` (strings, set in `__init__`), `self.tokenizer` (loaded once in `__init__`), and (set later, inside `load_training_data`) `self.label2id`/`self.id2label` (dicts mapping between category names and numeric IDs).

## Interfaces
This file follows HuggingFace's standard `Trainer`/`TrainingArguments`/`compute_metrics` conventions throughout â€” `compute_metrics` specifically must match the exact `EvalPrediction -> Dict[str, float]` signature the `Trainer` class expects to call it correctly.

## Hooks
`compute_metrics` functions as a callback hook â€” the HuggingFace `Trainer` calls it automatically after each evaluation pass during training, rather than this code calling it directly itself. This is the closest thing to a "hook" pattern in this file.

## Utilities
None beyond the methods described above.

## Dependencies
`torch`, `transformers`, `peft`, `datasets`, `scikit-learn` (all third-party, none listed in `requirements.txt`); `evaluation.metrics` (internal).

## Side Effects
- Loads a pretrained model's weights (`AutoModelForSequenceClassification.from_pretrained`) â€” this involves a real download (on first use, cached afterward) from HuggingFace's model hub, requiring network access.
- Performs real, potentially long-running GPU/CPU computation during training.
- Writes model artifacts to disk (`{output_dir}/final_adapter`) â€” a real, persistent filesystem side effect.
- Logs training progress throughout (both this file's own logging and HuggingFace's internal training logs).

## Performance Considerations
- LoRA (`r=8`, targeting only `["query", "value"]` attention projections) trains a small fraction of the base model's total parameters â€” dramatically reducing memory and compute requirements compared to full fine-tuning, at some potential cost to the ceiling of achievable adaptation quality compared to full fine-tuning.
- `learning_rate=2e-4` is deliberately higher than typical full-fine-tuning learning rates â€” appropriate specifically because LoRA's added parameters start from near-zero and can tolerate/benefit from a larger learning rate without destabilizing the (frozen) base model's existing weights.
- Batch size 32 for both train and eval is a reasonable default, though the actual achievable batch size in practice depends heavily on available GPU memory, which isn't checked or adapted to anywhere in this code.
- The mock dataset (400 total examples after 100x repetition of 4 templates) is far too small and repetitive to produce a genuinely useful fine-tuned model â€” this is explicitly a pipeline/plumbing test, not a real training run.

## Possible Interview Questions
- "Why does this fine-tuning pipeline use LoRA instead of fully fine-tuning FinBERT?" (LoRA freezes the pretrained model's original weights and only trains a small number of additional low-rank matrices injected into specific layers â€” this is dramatically cheaper in memory and compute, trains faster, and produces a small, portable adapter artifact, at the cost of a potentially lower ceiling on adaptation quality compared to full fine-tuning.)
- "Why does `compute_metrics` catch `ValueError` specifically around the ROC AUC computation?" (`roc_auc_score` with `multi_class='ovr'` requires every class to be represented in a given batch/split; if a particular evaluation split happens to be missing examples of some category â€” plausible with small or imbalanced data â€” the function would otherwise raise an error, so the code falls back to reporting `0.0` for that metric rather than crashing evaluation entirely.)
- "Why is `metric_for_best_model` set to `'f1'` rather than, say, calibration error or ROC AUC?" (A judgment call about which metric best represents 'good enough to deploy' for this use case â€” F1 balances precision and recall for a multi-class classification task, which is often considered a solid general-purpose choice, though a system this concerned with calibration (per the confidence-wall design elsewhere) might reasonably argue for weighting calibration error more heavily in model selection.)
- "The training data here is only 4 distinct examples repeated 100 times each. What would you expect to actually happen if you trained on this?" (The model would likely memorize these 4 exact patterns near-perfectly (extreme overfitting) while learning essentially nothing generalizable about real-world transaction text variety â€” this is fundamentally a pipeline-correctness test, not a data source capable of producing a genuinely useful classifier.)

