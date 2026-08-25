"""
Phase 6: live-MongoDB integration coverage for services/merchant_resolver.py
and repositories/transaction_repository.py, the two components
EDGE_CASE_REPORT.md explicitly flagged as "verified by inspection only" -
its own offline suite (evaluation/test_edge_cases.py) has no database and
can't exercise them for real.

HONESTY NOTE (read before trusting a green run of this file): this suite
was authored and written against real MongoDB semantics (the same
connect()/ensure_indexes()/upsert code paths database/mongo.py and
repositories/transaction_repository.py use in production), following the
same fixture shape test_api.py already uses against CI's `mongo:6.0`
service container. It could NOT be executed or verified in the sandbox
this branch was developed in - there is no local MongoDB instance and no
Docker available there. It has not been run successfully by a human or CI
at the time this file was written. Treat it as "ready for CI to prove,"
not as already-proven - the Phase 17 report must say so explicitly and
not claim these results as measured until a real CI run confirms them.

Uses plain `def test_...()` (not async def) and wraps each async call in
asyncio.run(), matching this repo's existing convention of no
pytest-asyncio dependency (not present in requirements.txt) rather than
adding one for this file alone. Runs against a dedicated database
(settings.MONGODB_DB_NAME + "_track04_integration"), dropped entirely in
teardown, so it never touches the `Vela_ci` data test_api.py's suite
writes to and repeated runs start from a clean slate.
"""

import asyncio
import uuid
from datetime import UTC, datetime

import pytest

from core.config import settings
from database.mongo import db
from models.schemas import Transaction, TransactionType
from repositories.transaction_repository import transaction_repo
from services.merchant_resolver import merchant_resolver

TEST_DB_NAME = (settings.MONGODB_DB_NAME or "Vela") + "_track04_integration"


def _run(coro):
    return asyncio.run(coro)


@pytest.fixture(scope="module", autouse=True)
def mongo_connection():
    _run(db.connect(uri=settings.MONGODB_URI, db_name=TEST_DB_NAME))
    _run(db.ensure_indexes())
    yield
    _run(db.client.drop_database(TEST_DB_NAME))
    _run(db.disconnect())


def _uid() -> str:
    return f"track04-{uuid.uuid4().hex[:12]}"


def _txn(user_id: str, *, reference_number: str | None, amount: float = 100.0,
          merchant: str = "Test Merchant", raw_text: str = "Paid to Test Merchant") -> Transaction:
    return Transaction(
        raw_text=raw_text,
        merchant=merchant,
        amount=amount,
        user_id=user_id,
        transaction_type=TransactionType.DEBIT,
        reference_number=reference_number,
        timestamp=datetime.now(UTC),
    )


class TestMerchantResolverIntegration:
    def test_create_and_resolve_exact_alias(self):
        canonical = f"Swiggy-{uuid.uuid4().hex[:6]}"
        _run(db.merchants.insert_one({"canonical_name": canonical, "aliases": ["SWIGGY XYZ TEST"]}))

        result = _run(merchant_resolver.resolve("SWIGGY XYZ TEST"))

        assert result.is_resolved is True
        assert result.canonical_merchant == canonical
        assert result.resolution_method == "exact_alias"
        assert result.confidence == 0.99

    def test_resolve_existing_merchant_by_noisy_raw_text(self):
        """clean_text() strips UPI/bank noise before the lookup runs - this
        confirms that normalization and the DB lookup compose correctly,
        not just clean_text() in isolation."""
        canonical = f"Zomato-{uuid.uuid4().hex[:6]}"
        _run(db.merchants.insert_one({"canonical_name": canonical, "aliases": ["ZOMATO ONLINE TEST"]}))

        result = _run(merchant_resolver.resolve("UPI/ZOMATO ONLINE TEST/1234567890AB"))

        assert result.is_resolved is True
        assert result.canonical_merchant == canonical

    def test_multiple_aliases_all_resolve_to_the_same_canonical_merchant(self):
        canonical = f"Amazon-{uuid.uuid4().hex[:6]}"
        _run(db.merchants.insert_one({
            "canonical_name": canonical,
            "aliases": ["AMAZON TEST A", "AMZN TEST A", "AMAZON PAY TEST A"],
        }))

        for alias in ("AMAZON TEST A", "AMZN TEST A", "AMAZON PAY TEST A"):
            result = _run(merchant_resolver.resolve(alias))
            assert result.canonical_merchant == canonical, f"alias {alias!r} did not resolve"

    def test_substring_match_when_no_exact_alias_exists(self):
        canonical = f"Starbucks-{uuid.uuid4().hex[:6]}"
        _run(db.merchants.insert_one({"canonical_name": canonical, "aliases": ["STARBUCKSTESTB"]}))

        result = _run(merchant_resolver.resolve("STARBUCKSTESTB COFFEE MUMBAI"))

        assert result.is_resolved is True
        assert result.canonical_merchant == canonical
        assert result.resolution_method == "substring"
        assert result.confidence == 0.75

    def test_unresolvable_merchant_falls_back_to_unknown(self):
        result = _run(merchant_resolver.resolve(f"COMPLETELY UNKNOWN MERCHANT {uuid.uuid4().hex}"))

        assert result.is_resolved is False
        assert result.canonical_merchant == "Unknown"
        assert result.resolution_method == "none"
        assert result.confidence == 0.0

    def test_conflicting_aliases_across_two_merchants_resolves_to_one_without_crashing(self):
        """FINDING: database/mongo.py's index on merchants.aliases is not
        unique, so nothing in the schema prevents two merchant documents
        from sharing the same alias string. resolve() does a plain
        find_one(), so whichever document Mongo returns first silently wins
        - there's no ambiguity detection at this layer (unlike
        ai_resolution/matcher.py's detect_ambiguity() for entity scoring).
        This test doesn't fix that - it confirms the behavior is at least
        deterministic-per-query and doesn't crash or return a partial/null
        result, and documents the gap for whoever owns this resolver next."""
        shared_alias = f"SHARED ALIAS {uuid.uuid4().hex[:8]}"
        _run(db.merchants.insert_one({"canonical_name": "Merchant One", "aliases": [shared_alias]}))
        _run(db.merchants.insert_one({"canonical_name": "Merchant Two", "aliases": [shared_alias]}))

        result = _run(merchant_resolver.resolve(shared_alias))

        assert result.is_resolved is True
        assert result.canonical_merchant in ("Merchant One", "Merchant Two")


class TestTransactionDedupIntegration:
    def test_first_insert_persists_all_transactions(self):
        user_id = _uid()
        txns = [_txn(user_id, reference_number=f"ref-{i}") for i in range(5)]

        upserted = _run(transaction_repo.bulk_upsert(txns))

        assert upserted == 5
        count = _run(db.transactions.count_documents({"user_id": user_id}))
        assert count == 5

    def test_identical_reinsert_updates_in_place_not_duplicated(self):
        """The exact scenario evaluation/test_edge_cases.py's
        test_parsing_the_same_upload_twice_is_deterministic establishes at
        the parser level (re-parsing produces identical records) - this is
        the other half: re-upserting those identical records must not
        double the transaction count."""
        user_id = _uid()
        txn = _txn(user_id, reference_number="ref-dup", amount=250.0)

        _run(transaction_repo.bulk_upsert([txn]))
        _run(transaction_repo.bulk_upsert([txn]))  # same (user_id, reference_number)

        count = _run(db.transactions.count_documents({"user_id": user_id}))
        assert count == 1

    def test_same_reference_number_updates_fields_on_reupload(self):
        """A re-upload with a corrected amount for the same reference_number
        (e.g. re-parsing after a parser fix) must update the existing
        document, not create a second one alongside a stale first."""
        user_id = _uid()
        original = _txn(user_id, reference_number="ref-update", amount=100.0)
        corrected = _txn(user_id, reference_number="ref-update", amount=150.0)

        _run(transaction_repo.bulk_upsert([original]))
        _run(transaction_repo.bulk_upsert([corrected]))

        count = _run(db.transactions.count_documents({"user_id": user_id}))
        assert count == 1
        doc = _run(db.transactions.find_one({"user_id": user_id, "reference_number": "ref-update"}))
        assert doc["amount"] == 150.0

    def test_similar_but_distinct_transactions_are_not_collapsed(self):
        """Same merchant, same amount, same day, but distinct reference
        numbers (two genuinely separate purchases) must persist as two
        documents - the dedup key is (user_id, reference_number), not
        transaction content."""
        user_id = _uid()
        txns = [
            _txn(user_id, reference_number="ref-a", amount=500.0, merchant="Same Merchant"),
            _txn(user_id, reference_number="ref-b", amount=500.0, merchant="Same Merchant"),
        ]

        _run(transaction_repo.bulk_upsert(txns))

        count = _run(db.transactions.count_documents({"user_id": user_id}))
        assert count == 2

    def test_concurrent_repeated_upsert_of_the_same_batch_stays_idempotent(self):
        """Two overlapping bulk_upsert calls for the same (user_id,
        reference_number) batch - simulating a retried upload racing the
        original - must still converge to exactly one document per
        reference_number, not raise, and not duplicate. Relies on MongoDB's
        per-document upsert atomicity, not on application-level locking."""
        user_id = _uid()
        txns = [_txn(user_id, reference_number=f"ref-concurrent-{i}") for i in range(10)]

        async def _race():
            await asyncio.gather(
                transaction_repo.bulk_upsert(txns),
                transaction_repo.bulk_upsert(txns),
            )

        _run(_race())

        count = _run(db.transactions.count_documents({"user_id": user_id}))
        assert count == 10

    def test_different_users_with_the_same_reference_number_do_not_collide(self):
        """The dedup key is (user_id, reference_number), not
        reference_number alone - two different users' statements can
        legitimately share a UPI transaction ID format/value space."""
        user_a, user_b = _uid(), _uid()
        _run(transaction_repo.bulk_upsert([_txn(user_a, reference_number="shared-ref")]))
        _run(transaction_repo.bulk_upsert([_txn(user_b, reference_number="shared-ref")]))

        assert _run(db.transactions.count_documents({"user_id": user_a})) == 1
        assert _run(db.transactions.count_documents({"user_id": user_b})) == 1

    def test_transactions_without_a_reference_number_are_never_deduped(self):
        """The unique index is partial (only applies where reference_number
        exists - database/mongo.py), so POST /v1/categorize-style
        transactions (no reference_number) must never collide with each
        other even if every other field is identical."""
        user_id = _uid()
        txns = [_txn(user_id, reference_number=None, amount=42.0) for _ in range(3)]

        _run(transaction_repo.bulk_upsert(txns))

        count = _run(db.transactions.count_documents({"user_id": user_id}))
        assert count == 3
