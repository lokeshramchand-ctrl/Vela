# Wave 2 Quickstart Guide

## Generating Synthetic Test Data

### Basic Usage

```python
from ingestion import SyntheticDataGenerator, SyntheticDataConfig

# Create default configuration (100 transactions, seed=42)
config = SyntheticDataConfig()
generator = SyntheticDataGenerator(config)

# Generate both GPay and bank statement datasets
gpay_records, bank_records = generator.generate()

# Access the records
for record in gpay_records[:5]:
    print(f"{record.merchant_normalized}: {record.amount} INR")
```

### Customized Configuration

```python
from datetime import datetime, UTC
from ingestion import SyntheticDataConfig, SyntheticDataGenerator

# Custom date range and transaction count
config = SyntheticDataConfig(
    num_transactions=200,
    seed=12345,  # For reproducibility
    start_date=datetime(2024, 6, 1, tzinfo=UTC),
    end_date=datetime(2024, 6, 30, tzinfo=UTC),
    user_id="customer_001",
    
    # Customize variation distribution
    pct_exact_match=40,
    pct_merchant_variation=25,
    pct_date_shift=15,
    pct_amount_difference=10,
    pct_missing=5,
    pct_duplicate=3,
    pct_ambiguous=2,
)

generator = SyntheticDataGenerator(config)
gpay_records, bank_records = generator.generate()
```

## Processing Bank Statements

### Convert Parsed Records to Canonical Form

```python
from ingestion import BankStatementService, BankStatementRecord
from datetime import datetime, UTC

service = BankStatementService(user_id="user123", source_name="bank_statement")

# Create records from parsed bank statement
records = [
    BankStatementRecord(
        transaction_id="stmt_001",
        date=datetime(2024, 1, 15, tzinfo=UTC),
        description="Swiggy Food Order",
        amount=500.00,
        is_debit=True,
        merchant="Swiggy",
        reference_id="REF_789",
        metadata={"bank": "ICICI", "account_last4": "5678"},
    ),
    BankStatementRecord(
        transaction_id="stmt_002",
        date=datetime(2024, 1, 20, tzinfo=UTC),
        description="Salary Credit",
        amount=50000.00,
        is_debit=False,
        merchant="Employer Inc",
    ),
]

# Convert to CanonicalFinancialRecords
canonical = service.process_statements(
    records,
    statement_metadata={"bank": "ICICI", "statement_id": "stmt_20240131"}
)

# Use canonical records for reconciliation
for record in canonical:
    print(f"{record.source}: {record.merchant_raw}")
```

## Understanding Reconciliation Challenges

Each synthetic bank record includes a `reconciliation_challenge` in its metadata:

```python
generator = SyntheticDataGenerator(SyntheticDataConfig(seed=42))
_, bank_records = generator.generate()

for record in bank_records:
    challenge = record.metadata.get("reconciliation_challenge")
    print(f"{record.source_record_id}: {challenge}")
    
# Output examples:
# bank_000001: exact_match
# bank_000002: merchant_variation
# bank_000003: date_shift
# bank_000004: amount_difference
# (missing records don't appear in bank_records)
# bank_000005: duplicate
# bank_000006: ambiguous
```

### Challenge Types Explained

| Challenge | Description | Example |
|-----------|-------------|---------|
| `exact_match` | Perfect match between GPay and bank | Same amount, merchant, date |
| `merchant_variation` | Same merchant, different name format | "SWIGGY" vs "Swiggy Food" |
| `date_shift` | Settlement vs posting date difference | ±1-2 days |
| `amount_difference` | Rounding, fees, or small variations | ₹500 vs ₹499.75 |
| `missing_record` | Transaction in GPay but not in bank | Not in bank_records list |
| `duplicate` | Same transaction twice in bank | Two bank records → one GPay |
| `ambiguous` | Vague merchant description | "Unknown Merchant" |

## Reproducibility & Ground Truth

### Same Seed = Same Data

```python
# Generate dataset A
config_a = SyntheticDataConfig(seed=42, num_transactions=100)
gen_a = SyntheticDataGenerator(config_a)
gpay_a, bank_a = gen_a.generate()

# Generate dataset B with same seed
config_b = SyntheticDataConfig(seed=42, num_transactions=100)
gen_b = SyntheticDataGenerator(config_b)
gpay_b, bank_b = gen_b.generate()

# Datasets are identical
assert gpay_a[0].amount == gpay_b[0].amount
assert bank_a[0].merchant_raw == bank_b[0].merchant_raw
```

### Finding Corresponding Records

The generator creates bank records based on GPay records, so you can track variations:

```python
config = SyntheticDataConfig(seed=42, num_transactions=50)
gen = SyntheticDataGenerator(config)
gpay, bank = gen.generate()

# GPay has 45 records (90% of 50), bank has ~50 (minus missing, plus duplicates)
# You can identify correspondences by analyzing the variations in metadata
```

## Integration with Repositories

### Storing Synthetic Data

```python
from database.mongo import MongoDB
from ingestion import SyntheticDataConfig, SyntheticDataGenerator

# Initialize database
db = await MongoDB.connect()

# Generate synthetic data
config = SyntheticDataConfig(num_transactions=100, seed=42)
generator = SyntheticDataGenerator(config)
gpay_records, bank_records = generator.generate()

# Store using CanonicalRecordRepository
canonical_repo = CanonicalRecordRepository(db)

# Bulk upsert (idempotent by source_record_id)
await canonical_repo.bulk_upsert(gpay_records)
await canonical_repo.bulk_upsert(bank_records)

# Query by source
gpay_from_db = await canonical_repo.list_for_user(
    user_id="test_user",
    source="gpay",
    limit=10
)

bank_from_db = await canonical_repo.list_for_user(
    user_id="test_user",
    source="synthetic_bank",
    limit=10
)
```

## Testing

### Run the Test Suite

```bash
# Full test suite
pytest test_wave2_synthetic_data.py -v

# Specific test class
pytest test_wave2_synthetic_data.py::TestSyntheticDataGenerator -v

# Specific test
pytest test_wave2_synthetic_data.py::TestSyntheticDataGenerator::test_reproducibility -v
```

### Key Tests

- **Reproducibility**: Same seed produces identical datasets
- **Variation Distribution**: Challenge types are distributed as configured
- **Schema Validation**: All records conform to CanonicalFinancialRecord
- **Ground Truth**: Reproducible across multiple runs
- **Integration**: Synthetic data works with CanonicalRecordRepository

## What's NOT Implemented (Wave 3 & Beyond)

- ❌ **PDF Parsing** — Real GPay PDF exports (will stub with synthetic data)
- ❌ **Bank Statement PDF Parsing** — Real bank statement PDFs (will stub with synthetic data)
- ❌ **Reconciliation Matching** — Finding corresponding records across sources
- ❌ **Merchant Normalization** — Resolving merchant variations
- ❌ **Confidence Scoring** — Match quality assessment
- ❌ **Deduplication** — Identifying duplicate records

These are implemented in Wave 3.

## Example: Full Reconciliation Scenario

```python
from ingestion import SyntheticDataConfig, SyntheticDataGenerator
from repositories.canonical_record_repository import CanonicalRecordRepository

# 1. Generate synthetic data
config = SyntheticDataConfig(
    num_transactions=100,
    seed=42,
    user_id="customer_001",
)
gen = SyntheticDataGenerator(config)
gpay, bank = gen.generate()

# 2. Store in database
# (assumes async context with MongoDB initialized)
repo = CanonicalRecordRepository(db)
await repo.bulk_upsert(gpay)
await repo.bulk_upsert(bank)

# 3. Query both sources for the same user
gpay_records = await repo.list_for_user("customer_001", source="gpay")
bank_records = await repo.list_for_user("customer_001", source="synthetic_bank")

# 4. (Wave 3) Reconciliation logic would:
#    - Match records across sources
#    - Resolve merchant name variations
#    - Handle amount differences
#    - Identify missing/duplicate records
#    - Compute match confidence scores

print(f"GPay records: {len(gpay_records)}")
print(f"Bank records: {len(bank_records)}")
print(f"Records to reconcile...")
```

## Next Steps

- Wave 3: Implement reconciliation matching engine
- Wave 3: Add merchant normalization service
- Wave 4: Build evaluation framework against ground truth
- Future: Real PDF parsing for GPay and bank statements
