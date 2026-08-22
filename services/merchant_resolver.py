import logging
import re

from database.mongo import db
from models.schemas import ResolutionResult

logger = logging.getLogger(__name__)

class MerchantResolver:
    def __init__(self):
        # Common Indian banking and UPI prefixes/suffixes that add noise
        self.noise_patterns = [
            r"\bUPI(?:/CR|/DR)?\b",
            r"\bIMPS\b",
            r"\bNEFT\b",
            r"\bRTGS\b",
            r"\bINB\b",
            r"\b[A-Z0-9]{12}\b",  # Matches standard 12-digit UPI reference numbers
            r"\b(?:@icici|@okaxis|@okhdfcbank|@ybl|@sbi|@paytm)\b" # UPI handles
        ]
        self.noise_regex = re.compile("|".join(self.noise_patterns), re.IGNORECASE)

        # Strip special characters except spaces and alphanumeric
        self.special_chars_regex = re.compile(r"[^a-zA-Z0-9\s]")

    def clean_text(self, raw_text: str) -> str:
        """Removes banking noise and normalizes the transaction string."""
        # Remove noise patterns (e.g., "UPI/CR/", ref numbers)
        text = self.noise_regex.sub(" ", raw_text)
        # Remove special characters (slashes, hyphens)
        text = self.special_chars_regex.sub(" ", text)
        # Condense multiple spaces into one and convert to uppercase for standard matching
        text = re.sub(r"\s+", " ", text).strip().upper()
        return text

    async def resolve(self, raw_text: str) -> ResolutionResult:
        """
        Attempts to resolve a raw transaction string to a canonical merchant.
        """
        cleaned_text = self.clean_text(raw_text)

        # Step 1: Database Lookup - Exact Alias Match
        # Assuming your MongoDB `merchants` collection has an `aliases` array field
        # e.g., { "canonical_name": "Swiggy", "aliases": ["BUNDL TECHNOLOGIES", "SWIGGY"] }
        exact_match = await db.merchants.find_one({
            "aliases": cleaned_text
        })

        if exact_match:
            return ResolutionResult(
                raw_text=raw_text,
                cleaned_text=cleaned_text,
                canonical_merchant=exact_match["canonical_name"],
                confidence=0.99,
                is_resolved=True,
                resolution_method="exact_alias"
            )

        # Step 2: Database Lookup - Substring / Regex Match
        # If the cleaned text CONTAINS an alias (e.g., "MCDONALDS MUMBAI" contains "MCDONALDS")
        # Note: In production with millions of rows, text-indexing or Milvus (Phase 7) handles this faster.
        # For Phase 3, we use a regex query against the aliases array.
        words = cleaned_text.split()
        for word in words:
            if len(word) < 4:
                continue # Skip short words like "LTD", "PVT", "INC"

            substring_match = await db.merchants.find_one({
                "aliases": {"$regex": f"^{word}", "$options": "i"}
            })

            if substring_match:
                return ResolutionResult(
                    raw_text=raw_text,
                    cleaned_text=cleaned_text,
                    canonical_merchant=substring_match["canonical_name"],
                    confidence=0.75,
                    is_resolved=True,
                    resolution_method="substring"
                )

        # Step 3: Embrace the Unknown
        return ResolutionResult(
            raw_text=raw_text,
            cleaned_text=cleaned_text,
            canonical_merchant="Unknown",
            confidence=0.0,
            is_resolved=False,
            resolution_method="none"
        )

# Singleton instance
merchant_resolver = MerchantResolver()
