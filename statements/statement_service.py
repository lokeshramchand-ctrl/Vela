import logging
import time

from analytics.statement_analytics import statement_analytics_engine
from behaviour.behavior_engine import behavior_engine
from database.mongo import db
from embeddings.generate_embeddings import embedding_generator
from embeddings.vectorizer import vectorizer
from engines.rule_engine import rule_engine
from insights.statement_insights import statement_insight_generator
from milvus.insert_vectors import vector_store
from models.schemas import BehaviorPattern, CanonicalFinancialRecord, Statement, Transaction, TransactionCategory, TransactionType
from repositories.canonical_record_repository import canonical_record_repo
from repositories.job_repository import job_repo
from repositories.statement_repository import statement_repo
from repositories.transaction_repository import transaction_repo
from statements.pdf_parser import ParsedTransaction, statement_parser

logger = logging.getLogger(__name__)

_RECONCILIATION_EPSILON = 0.01


class StatementService:
    """Owns the full processing pipeline, run as a FastAPI BackgroundTask
    after POST /statements/upload has already returned 202. PDF structural/
    signature validation (open_and_inspect, validate_signature, parse_period,
    parse_declared_totals) already happened synchronously in the upload
    handler - by the time this runs, `full_text` is already known-good, so
    the only failure modes here are unexpected internal errors, not
    malformed input.

    Because this runs outside the request/response cycle, a failure here
    can't go through core/error_handlers.py - it's caught directly and
    written onto the Job/Statement documents instead (full detail logged
    server-side, a generic message persisted for the client), which is
    exactly why the polling contract (GET /jobs/{id}) exists.
    """

    async def process_statement(self, statement_id: str, job_id: str, full_text: str) -> None:
        start_time = time.monotonic()
        statement = await statement_repo.get_by_id(statement_id)
        if statement is None:
            logger.error("Statement %s vanished before processing could start.", statement_id)
            return

        try:
            await statement_repo.mark_processing(statement_id)
            await job_repo.mark_running(job_id, "parsing")

            parsed_records = statement_parser.parse_transactions(full_text)

            await job_repo.update_progress(job_id, "categorizing", 20)
            transactions, canonical_records = self._build_transactions(statement.user_id, statement_id, parsed_records)

            await job_repo.update_progress(job_id, "persisting_transactions", 40)
            await transaction_repo.bulk_upsert(transactions)
            await canonical_record_repo.bulk_upsert(canonical_records)

            await job_repo.update_progress(job_id, "profiling_merchants", 55)
            await self._refresh_behavior_profiles(statement_id)

            await job_repo.update_progress(job_id, "generating_embeddings", 70)
            await self._sync_embeddings(statement_id)

            await job_repo.update_progress(job_id, "computing_analytics", 85)
            analytics = await statement_analytics_engine.compute(statement.user_id, statement_id)

            await job_repo.update_progress(job_id, "generating_insights", 95)
            insights = await statement_insight_generator.generate(analytics)

            computed_sent = round(
                sum(t.amount for t in transactions if t.transaction_type == TransactionType.DEBIT), 2
            )
            computed_received = round(
                sum(t.amount for t in transactions if t.transaction_type == TransactionType.CREDIT), 2
            )
            reconciliation_ok = self._check_reconciliation(statement, computed_sent, computed_received)

            duration_ms = int((time.monotonic() - start_time) * 1000)
            await statement_repo.mark_completed(
                statement_id,
                transaction_count=len(transactions),
                computed_sent_amount=computed_sent,
                computed_received_amount=computed_received,
                reconciliation_ok=reconciliation_ok,
                analytics=analytics,
                insights=insights,
                processing_duration_ms=duration_ms,
            )
            await job_repo.mark_completed(job_id)
            logger.info("Statement %s processed successfully (%d transactions).", statement_id, len(transactions))

        except Exception:
            logger.exception("Statement processing failed for statement %s", statement_id)
            generic_message = "Statement processing failed due to an internal error."
            await statement_repo.mark_failed(statement_id, generic_message)
            await job_repo.mark_failed(job_id, generic_message)

    def _build_transactions(
        self, user_id: str, statement_id: str, parsed_records: list[ParsedTransaction]
    ) -> tuple[list[Transaction], list[CanonicalFinancialRecord]]:
        transactions = []
        canonical_records = []
        for record in parsed_records:
            if record.direction == "Paid to":
                result = rule_engine.categorize(record.counterparty_raw)
                merchant = result["merchant"]
                category = result["category"]
                transaction_type = TransactionType.DEBIT
            else:
                # "Received from X" - X is a person or a source like "Google
                # Pay rewards", not a spending category. rule_engine has no
                # concept of categorizing who sent you money.
                merchant = record.counterparty_raw
                category = TransactionCategory.INCOME.value
                transaction_type = TransactionType.CREDIT

            txn = Transaction(
                raw_text=f"{record.direction} {record.counterparty_raw}",
                merchant=merchant,
                amount=record.amount,
                category=category,
                user_id=user_id,
                timestamp=record.timestamp,
                statement_id=statement_id,
                transaction_type=transaction_type,
                counterparty_raw=record.counterparty_raw,
                reference_number=record.reference_number,
                bank=record.bank,
                account_last4=record.account_last4,
            )
            transactions.append(txn)

            # Populate canonical record alongside transaction with full provenance
            canonical = CanonicalFinancialRecord(
                source="gpay",
                source_record_id=record.reference_number,
                user_id=user_id,
                timestamp=record.timestamp,
                amount=record.amount,
                merchant_raw=record.counterparty_raw,
                merchant_normalized=merchant,
                transaction_type=transaction_type,
                category=category,
                reference_id=record.reference_number,
                description=f"{record.direction} {record.counterparty_raw}",
                metadata={
                    "bank": record.bank,
                    "account_last4": record.account_last4,
                    "direction": record.direction,
                    "statement_id": statement_id,
                },
            )
            canonical_records.append(canonical)

        return transactions, canonical_records

    async def _refresh_behavior_profiles(self, statement_id: str) -> None:
        """Reuses behaviour/behavior_engine.py verbatim - the same per-
        merchant try/except resilience pattern routers/pipelines.py's
        run-all already uses, so one merchant's failure doesn't abort the
        whole job."""
        merchant_names = await transaction_repo.get_distinct_debit_merchants(statement_id)
        for merchant_name in merchant_names:
            try:
                await behavior_engine.profile_merchant_behavior(merchant_name)
            except Exception:
                logger.warning("Behavior profiling failed for '%s' - continuing.", merchant_name, exc_info=True)

    async def _sync_embeddings(self, statement_id: str) -> None:
        """Reuses embeddings/generate_embeddings.py + milvus/insert_vectors.py
        verbatim, mirroring POST /v1/pipelines/embeddings/sync. A Milvus/
        Ollama outage degrades this statement to "completed, AI enrichment
        skipped" rather than failing the whole job - transactions and
        analytics are already the core value and don't depend on Milvus."""
        if vector_store.client is None:
            logger.warning("Milvus not connected - skipping embedding sync for statement %s.", statement_id)
            return

        merchant_names = await transaction_repo.get_distinct_debit_merchants(statement_id)
        for merchant_name in merchant_names:
            try:
                doc = await db.behavior_patterns.find_one({"merchant_name": merchant_name})
                if not doc:
                    continue
                doc["_id"] = str(doc["_id"])
                pattern = BehaviorPattern(**doc)
                text = vectorizer.stringify_behavior(pattern)
                vector = await embedding_generator.generate(text)
                vector_store.insert_behavior_vector(pattern_id=pattern.id, merchant_name=pattern.merchant_name, vector=vector)
            except Exception:
                logger.warning("Embedding sync failed for '%s' - continuing.", merchant_name, exc_info=True)

    @staticmethod
    def _check_reconciliation(statement: Statement, computed_sent: float, computed_received: float) -> bool | None:
        if statement.declared_sent_amount is None or statement.declared_received_amount is None:
            return None
        return (
            abs(computed_sent - statement.declared_sent_amount) < _RECONCILIATION_EPSILON
            and abs(computed_received - statement.declared_received_amount) < _RECONCILIATION_EPSILON
        )


statement_service = StatementService()
