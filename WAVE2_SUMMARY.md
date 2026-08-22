# Wave 2: Multi-Source Ingestion & Synthetic Dataset Generator

## Summary

Wave 2 establishes the second data source pathway and builds a reproducible synthetic dataset generator that bridges financial data ingestion from multiple sources. This enables comprehensive reconciliation testing without requiring real banking integrations.

## Acceptance Criteria ✓

- [x] Synthetic dataset generator produces reproducible data (seeded randomization)
- [x] Synthetic data includes intentional variations for reconciliation testing
- [x] Bank statement ingestion creates CanonicalFinancialRecords
- [x] Ground truth is known, documented, and reproducible
- [x] All synthetic records conform to CanonicalFinancialRecord schema
- [x] Reconciliation challenges are identifiable and traceable

## Architecture

### 1. Synthetic Data Generator (`ingestion/synthetic_data_generator.py`)

Creates two parallel datasets (GPay and synthetic bank statements) with reproducible, intentional variations:

```python
class SyntheticDataGenerator:
    def generate() -> tuple[list[CanonicalFinancialRecord], list[CanonicalFinancialRecord]]:
        # Returns (gpay_records, bank_statement_records)
```

**Key Features:**
- Reproducible via seeded random generator (default seed=42)
- Realistic merchant pool (10+ merchants with variations)
- Distribution of transaction types (70% DEBIT, 30% CREDIT)
- Realistic amount ranges ($10-$50,000 with proper distribution)
- Configurable date ranges and transaction counts

**Reconciliation Variations:**
```python
class ReconciliationChallengeType:
    EXACT_MATCH           # Baseline: perfect match between sources
    MERCHANT_VARIATION    # Same merchant, different name format
    DATE_SHIFT            # Settlement vs posting date (±1-2 days)
    AMOUNT_DIFFERENCE     # Rounding, fees (±50 paise)
    MISSING_RECORD        # Transaction in GPay but not bank
    DUPLICATE             # Same transaction twice in bank statement
    AMBIGUOUS             # Vague merchant description
```

**Configuration:**
```python
@dataclass
class SyntheticDataConfig:
    seed: int = 42
    num_transactions: int = 100
    start_date: datetime = datetime(2024, 1, 1)
    end_date: datetime = datetime(2024, 1, 31)
    user_id: str = "test_user"
    
    # Variation distribution (% of records)
    pct_exact_match: float = 30.0
    pct_merchant_variation: float = 25.0
    pct_date_shift: float = 20.0
    pct_amount_difference: float = 10.0
    pct_missing: float = 5.0
    pct_duplicate: float = 5.0
    pct_ambiguous: float = 5.0
```

### 2. Bank Statement Ingestion Service (`ingestion/bank_statement_service.py`)

Handles conversion of bank statement data to CanonicalFinancialRecords:

```python
class BankStatementService:
    def process_statements(
        parsed_records: list[BankStatementRecord],
        statement_metadata: dict
    ) -> list[CanonicalFinancialRecord]
```

**Responsibilities:**
- Parse bank statement records (or synthetic records)
- Create CanonicalFinancialRecords with source="bank_statement" or "synthetic_bank"
- Preserve source provenance and metadata
- Stub for future PDF parsing (not implemented for MVP)

**BankStatementRecord Schema:**
```python
@dataclass
class BankStatementRecord:
    transaction_id: str          # Unique ID from bank
    date: datetime               # Transaction date
    description: str             # Full description
    amount: float                # Amount in base currency
    is_debit: bool               # Direction
    merchant: str                # Merchant/counterparty
    reference_id: str | None     # Check number, etc.
    metadata: dict | None        # Bank-specific fields
```

### 3. Ingestion Module (`ingestion/__init__.py`)

Exports:
- `SyntheticDataGenerator`
- `SyntheticDataConfig`
- `BankStatementService`
- `BankStatementRecord`

## Test Coverage (`test_wave2_synthetic_data.py`)

Comprehensive test suite with 25+ test cases validating:

**Generator Tests:**
- `test_reproducibility` — Same seed produces identical data
- `test_gpay_source_generation` — GPay records have correct schema
- `test_bank_statement_source_generation` — Bank records with variations
- `test_variations_distribution` — Correct % of each challenge type
- `test_merchant_pool_coverage` — Multiple merchants used
- `test_transaction_type_distribution` — Both DEBIT and CREDIT present
- `test_ambiguous_records` — No merchant_normalized on ambiguous
- `test_duplicate_records` — Duplicates properly marked
- `test_missing_records` — Missing records not created
- `test_date_shifted_records` — Date shifts applied correctly
- `test_amount_differences` — Amount variations present
- `test_merchant_variations` — Merchant name variations applied
- `test_full_generation_pipeline` — End-to-end generation works

**Service Tests:**
- `test_bank_statement_service_initialization` — Service initializes
- `test_process_statements` — Records converted to canonical form
- `test_bank_statement_record_initialization` — Record schema valid
- `test_build_canonical_record` — Canonical record created correctly
- `test_canonical_records_from_synthetic_data` — Synthetic data conforms

**Integration Tests:**
- `test_synthetic_data_satisfies_canonical_record_schema` — Schema validation
- `test_ground_truth_reproducibility` — Reproducible across runs
- `test_reconciliation_challenges_are_identifiable` — Challenges marked in metadata
- `test_pdf_parsing_not_implemented` — MVP stubs for future work

## Data Model Examples

### GPay Record (Synthetic)
```json
{
  "source": "gpay",
  "source_record_id": "gpay_000001",
  "user_id": "test_user",
  "timestamp": "2024-01-15T10:30:00Z",
  "amount": 450.75,
  "currency": "INR",
  "merchant_raw": "SWIGGY FOODS",
  "merchant_normalized": "Swiggy",
  "transaction_type": "DEBIT",
  "status": "SUCCESS",
  "reference_id": "UPI/1234567890",
  "description": "Swiggy transaction",
  "metadata": {
    "source_app": "Google Pay",
    "payment_method": "UPI"
  }
}
```

### Bank Statement Record (Synthetic)
```json
{
  "source": "synthetic_bank",
  "source_record_id": "bank_000001",
  "user_id": "test_user",
  "timestamp": "2024-01-16T00:00:00Z",    # date shifted by 1 day
  "amount": 450.25,                        # small fee difference
  "currency": "INR",
  "merchant_raw": "Swiggy Food",           # merchant variation
  "merchant_normalized": "Swiggy",
  "transaction_type": "DEBIT",
  "status": "SUCCESS",
  "reference_id": "CHK/123456",
  "description": "Bank statement: Swiggy Food",
  "metadata": {
    "bank": "ICICI",
    "account_last4": "1234",
    "statement_id": "stmt_20240131",
    "reconciliation_challenge": "date_shift",
    "original_description": "Swiggy Food Order"
  }
}
```

## Key Design Decisions

### 1. Seeded Randomization
**Why:** Ground truth must be reproducible. Same seed → same data every run.
**How:** `random.Random(seed)` for deterministic generation despite randomized values.

### 2. Metadata for Challenge Identification
**Why:** Reconciliation engine needs to know what challenges to expect (for evaluation metrics).
**How:** `record.metadata["reconciliation_challenge"]` labels each variation type.

### 3. Separate Sources, Known Mapping
**Why:** Track which bank record corresponds to which GPay record (for evaluation).
**How:** Generator builds GPay first, then creates bank records from GPay. Variations are deterministic.

### 4. Merchant Variations from Pool
**Why:** Real merchant names have format variations (SMS codes vs display names).
**How:** `MERCHANT_POOL` maps canonical names to 3-5 variations per merchant.

### 5. No PDF Parsing in MVP
**Why:** Real banking integration is out of scope for the buildathon.
**How:** `BankStatementService.parse_*_pdf()` raise `NotImplementedError` with guidance to use synthetic data.

## Integration with Wave 1

Wave 2 builds directly on Wave 1's CanonicalFinancialRecord:

- **Wave 1:** Established the schema for multi-source transactions
- **Wave 2:** Populates that schema from two sources (GPay + synthetic bank)
- **Wave 3 (Next):** Reconciliation engine matches records across sources using these canonical records

```
GPay Statement → SyntheticDataGenerator → CanonicalFinancialRecord (source="gpay")
                                ↓
                         ReconciliationChallengeType
                                ↓
Bank Statement → BankStatementService → CanonicalFinancialRecord (source="synthetic_bank")
```

## Files Added

- `ingestion/__init__.py` — Module exports
- `ingestion/synthetic_data_generator.py` — Reproducible data generator (400+ lines)
- `ingestion/bank_statement_service.py` — Bank statement ingestion service (100+ lines)
- `test_wave2_synthetic_data.py` — Comprehensive test suite (600+ lines, 25+ tests)

## Files Changed

None (pure addition, no modifications to existing code).

## Test Results

All 25+ tests pass, validating:
- ✓ Synthetic data reproducibility
- ✓ Variation distribution accuracy
- ✓ Schema conformance
- ✓ Ground truth consistency
- ✓ Reconciliation challenge identification

**Tests can be run:**
```bash
pytest test_wave2_synthetic_data.py -v
```

## Next Steps (Wave 3)

1. **Reconciliation Matching Engine** — Compare GPay and bank records to find matches
2. **Merchant Normalization** — Resolve variations (e.g., "Swiggy Food" → "Swiggy")
3. **Confidence Scoring** — Assign match confidence based on merchant, amount, date, etc.
4. **Deduplication** — Identify duplicate records within a single source
5. **Evaluation Framework** — Measure reconciliation accuracy against ground truth

## Git Commits

```
Wave 2: Add synthetic data generator with reproducible ground truth
Wave 2: Add bank statement ingestion service
Wave 2: Add comprehensive test suite for synthetic data generation
```

## Future Enhancements

1. **Real PDF Parsing** — Implement `parse_gpay_pdf()` and `parse_bank_statement_pdf()`
2. **OCR Support** — Handle bank statement PDFs with OCR preprocessing
3. **Format Adapters** — Support CSV, Excel, XML statement formats
4. **Batch Processing** — Process multiple statements efficiently
5. **CSV/JSON Export** — Export synthetic data for external evaluation
