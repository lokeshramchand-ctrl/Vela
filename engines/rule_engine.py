import json
import logging
import re
from pathlib import Path

logger = logging.getLogger(__name__)

# Resolve the path to the JSON file dynamically
BASE_DIR = Path(__file__).resolve().parent.parent
ALIASES_FILE = BASE_DIR / "merchant_aliases.json"

class RuleEngine:
    def __init__(self):
        self.rules = self._load_rules()
        self._compile_patterns()

    def _load_rules(self) -> dict:
        try:
            with open(ALIASES_FILE) as f:
                logger.info("Loaded merchant aliases.")
                return json.load(f)
        except FileNotFoundError:
            logger.warning(f"Aliases file not found at {ALIASES_FILE}. Starting with empty rules.")
            return {}

    def _compile_patterns(self):
        # Pre-compile regex patterns for performance on startup
        self.compiled_rules = {}
        for alias, data in self.rules.items():
            # \b ensures we only match whole words
            pattern = re.compile(rf"\b{re.escape(alias)}\b", re.IGNORECASE)
            self.compiled_rules[pattern] = data

    def categorize(self, text: str) -> dict:
        """
        Scans the transaction text against pre-compiled regex rules.
        """
        for pattern, data in self.compiled_rules.items():
            if pattern.search(text):
                return {
                    "merchant": data["merchant"],
                    "category": data["category"],
                    "confidence": 0.95  # High confidence for deterministic rules
                }

        # Fallback if no rule matches
        return {
            "merchant": "Unknown",
            "category": "Uncategorized",
            "confidence": 0.0
        }

# Instantiate a singleton to be used by the router
rule_engine = RuleEngine()
