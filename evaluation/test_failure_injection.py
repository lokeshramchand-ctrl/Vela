"""
Phase 14: failure injection.

Two kinds of coverage here:

1. New tests for failure modes not already exercised elsewhere - primarily
   "MongoDB unavailable," verified for real against an unreachable Mongo
   URI (this sandbox has no local MongoDB, which made this one of the
   easiest scenarios to actually prove rather than only reason about), and
   malformed-transaction/invalid-date validation via the real Pydantic
   model.
2. An explicit index below, so "did we cover failure mode X" has one place
   to check instead of requiring a grep across every test file. Nothing in
   this file duplicates a test that already exists elsewhere.

| Failure mode | Where it's covered | Verified in this sandbox? |
|---|---|---|
| Malformed PDF (garbage/truncated bytes) | evaluation/test_edge_cases.py (16) | Yes |
| Empty PDF | evaluation/test_edge_cases.py (17) | Yes |
| Partial PDF (passes header, fails extraction) | evaluation/test_pdf_ingestion_hardening.py | Yes |
| Missing source (no candidates) | evaluation/test_track04_benchmark.py (MISSING_RECORD) | Yes |
| Malformed transaction (missing required field) | this file | Yes |
| Missing amount / invalid date | evaluation/test_edge_cases.py (15), this file | Yes |
| Duplicate upload (parser determinism) | evaluation/test_edge_cases.py (18) | Yes |
| Duplicate transaction (dedup upsert) | evaluation/test_mongo_integration.py | No live Mongo in this sandbox - see that file's honesty note |
| MongoDB unavailable | this file | Yes |
| Reconciliation service unavailable | not applicable - AIEntityMatcher has no external service dependency, it's a pure in-process scorer (see ai_resolution/matcher.py) | n/a |
| AI/LLM unavailable, AI timeout, invalid AI response | not applicable to the matcher for the same reason; statements/statement_service.py's `_sync_embeddings` step already degrades gracefully on a Milvus/Ollama outage per its own docstring ("completed, AI enrichment skipped") - not independently re-verified here, would need a live Milvus/Ollama to exercise for real | Partial (by inspection only) |
| Ambiguous candidate set | evaluation/test_track04_benchmark.py (AMBIGUOUS, DUPLICATE_CANDIDATE) | Yes |
| Large batch | evaluation/test_performance.py (Phase 16) | Yes |
| Repeated reconciliation | evaluation/test_mongo_integration.py (repeated bulk_upsert) | No live Mongo - see above |
| Concurrent requests | evaluation/test_mongo_integration.py (concurrent upsert race) | No live Mongo - see above |
"""

import unittest

import pydantic
import pymongo.errors

from models.schemas import Transaction


class TestMalformedTransactionValidation(unittest.TestCase):
    def test_missing_required_amount_field_fails_validation_cleanly(self):
        with self.assertRaises(pydantic.ValidationError):
            Transaction(raw_text="Paid to Someone", user_id="u1")

    def test_invalid_date_string_fails_validation_cleanly(self):
        with self.assertRaises(pydantic.ValidationError):
            Transaction(raw_text="x", amount=100.0, user_id="u1", timestamp="not-a-date")

    def test_negative_amount_is_accepted_by_the_schema_but_flagged_for_downstream_review(self):
        """Transaction.amount has no positivity constraint at the schema
        level - a refund/reversal-as-negative-amount (EDGE_CASE_REPORT.md
        finding 4) is schema-valid. Documented here as an intentional
        non-failure: rejecting negative amounts at ingestion would break
        legitimate refund records, so the safety boundary is correctly
        placed at matching time (Phase 1's direction filter), not at
        ingestion-time validation."""
        txn = Transaction(raw_text="Refund", amount=-500.0, user_id="u1")
        self.assertEqual(txn.amount, -500.0)


class TestMongoDBUnavailable(unittest.TestCase):
    """Verified against a real unreachable Mongo URI (localhost:1, nothing
    listening) - not simulated/mocked. Confirms the failure mode this
    sandbox actually has (no local MongoDB) produces a clean, catchable,
    bounded-time error rather than a hang or an unhandled crash."""

    def test_unreachable_mongo_raises_a_clean_bounded_time_error(self):
        import asyncio

        from database.mongo import db

        async def _attempt():
            await db.connect(uri="mongodb://localhost:1", db_name="track04_failure_injection")
            try:
                with self.assertRaises(pymongo.errors.ServerSelectionTimeoutError):
                    await db.merchants.find_one({"probe": True})
            finally:
                await db.disconnect()

        asyncio.run(_attempt())


if __name__ == "__main__":
    unittest.main()
