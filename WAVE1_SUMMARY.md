# Wave 1: Canonical Financial Record Foundation

## Summary

Wave 1 establishes the canonical financial record as the universal representation layer for transaction reconciliation. This is the foundation enabling multi-source reconciliation without discarding information or breaking existing functionality.

## Acceptance Criteria ✓

- [x] Existing GPay ingestion still works
- [x] Old analytics still work
- [x] Canonical records can represent current GPay transactions
- [x] Every record retains source provenance
- [x] No information is silently discarded

## Changes

### 1. CanonicalFinancialRecord Schema (models/schemas.py)
Defines the universal transaction representation:

```python
class CanonicalFinancialRecord(CoreModel):
    source: str                           # "gpay", "bank_statement", etc.
    source_record_id: str                 # Original ID from source
    user_id: str
    
    timestamp: datetime                   # When transaction occurred
    amount: float
    currency: str                         # Currently "INR"
    
    merchant_raw: str                     # Exact name from source
    merchant_normalized: str | None       # Processed via rule_engine
    
    transaction_type: TransactionType     # DEBIT or CREDIT
    status: TransactionStatus
    
    reference_id: str | None              # UPI ID, check number, etc.
    description: str | None
    category: str | None
    
    metadata: dict[str, Any]              # Raw, unprocessed data
    
    created_at: datetime
    updated_at: datetime
```

Key design decisions:
- **Dual merchant fields**: `merchant_raw` preserves source data; `merchant_normalized` stores processed result
- **Metadata dict**: Captures bank, account_last4, direction, statement_id — any field from source is preserved
- **Source provenance**: (user_id, source, source_record_id) forms a unique constraint preventing duplicates
- **Currency field**: Prepared for multi-currency support; currently defaults to "INR"

### 2. CanonicalRecordRepository (repositories/canonical_record_repository.py)

Repository pattern for managing canonical records:

- **bulk_upsert()**: Idempotent insert with (user_id, source, source_record_id) uniqueness
- **get_by_id()**: Single record lookup
- **get_by_source_id()**: Source-specific record retrieval
- **list_for_user()**: Paginated listing with optional source filtering
- **delete_by_source_batch()**: Cleanup by source batch

### 3. Database Indexes (database/mongo.py)

Indexes optimized for reconciliation queries:

```python
# Unique index ensures each source produces one record per original ID
await cls.canonical_records.create_index(
    [("user_id", 1), ("source", 1), ("source_record_id", 1)],
    unique=True,
    background=True,
)

# For efficient user transaction listing
await cls.canonical_records.create_index(
    [("user_id", 1), ("timestamp", -1)], 
    background=True
)

# For source-based filtering
await cls.canonical_records.create_index("source", background=True)
```

### 4. Statement Processing Integration (statements/statement_service.py)

Modified statement ingestion to populate both Transaction and CanonicalFinancialRecord:

```python
def _build_transactions(...) -> tuple[list[Transaction], list[CanonicalFinancialRecord]]:
    for record in parsed_records:
        # Build existing Transaction (unchanged)
        txn = Transaction(...)
        transactions.append(txn)
        
        # Build new CanonicalFinancialRecord with full provenance
        canonical = CanonicalFinancialRecord(
            source="gpay",
            source_record_id=record.reference_number,
            merchant_raw=record.counterparty_raw,
            merchant_normalized=merchant,
            metadata={
                "bank": record.bank,
                "account_last4": record.account_last4,
                "direction": record.direction,
                "statement_id": statement_id,
            }
        )
        canonical_records.append(canonical)
    
    return transactions, canonical_records
```

This approach ensures:
- Transactions are still created (backwards compatible)
- Analytics continue using existing queries
- No information is discarded
- Source provenance is captured

### 5. Schema Validation Tests (test_wave1_canonical_records.py)

Comprehensive test suite validating:
- Provenance fields capture source information
- Metadata preserves raw, unprocessed data
- Dual merchant fields (raw + normalized) both work
- Transaction model unchanged for backwards compatibility
- Both DEBIT and CREDIT types supported
- Schema is source-agnostic

## Impact Analysis

### Backwards Compatibility ✓
- **Transactions**: Unchanged. All existing fields retained.
- **Analytics**: Continue using Transaction queries; no changes needed.
- **APIs**: No changes to existing endpoints.
- **Ingestion**: GPay statement processing remains identical; just also creates canonical records.

### Forward Compatibility ✓
- **Multi-source readiness**: Schema supports "bank_statement", "credit_card", "wallet", etc.
- **Reconciliation**: Canonical records from different sources can be compared via merchant_raw/merchant_normalized
- **Extensibility**: Metadata dict captures source-specific fields without schema changes

## Git Commits

```
ec9f9b7 Wave 1: Add schema validation tests for CanonicalFinancialRecord
87f114e Wave 1: Update statement processing to create CanonicalFinancialRecords
c047b13 Wave 1: Add canonical_records collection and indexes
e4d8eac Wave 1: Add CanonicalRecordRepository
0dd7a6a Wave 1: Add CanonicalFinancialRecord schema
```

## Next Steps

Wave 2 will focus on:
1. Bank statement ingestion creating CanonicalFinancialRecords with source="bank_statement"
2. Merchant normalization across sources (reconciliation matching engine)
3. Deduplication logic when the same transaction appears in multiple sources
4. Analytics computed directly from canonical records (rather than Transactions)

## Files Changed

- `models/schemas.py`: Added CanonicalFinancialRecord class
- `repositories/canonical_record_repository.py`: New file
- `database/mongo.py`: Added canonical_records collection and indexes
- `statements/statement_service.py`: Modified _build_transactions() to create canonical records
- `test_wave1_canonical_records.py`: New file with comprehensive tests
