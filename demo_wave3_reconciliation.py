#!/usr/bin/env python3
"""Quick demonstration of Wave 3 deterministic reconciliation baseline.

Shows how the deterministic matcher works on synthetic data, establishing
a measurable baseline before introducing AI-based reconciliation.

Run with: python demo_wave3_reconciliation.py
"""

from datetime import datetime, UTC
from ingestion.synthetic_data_generator import SyntheticDataConfig, SyntheticDataGenerator
from reconciliation.deterministic_matcher import DeterministicMatcher, MatchType
from services.reconciliation_service import ReconciliationService


def print_section(title: str):
    """Print a section header."""
    print(f"\n{'=' * 70}")
    print(f"  {title}")
    print(f"{'=' * 70}")


def print_match_details(result, max_samples: int = 5):
    """Print details of matched records."""
    for i, match in enumerate(result[:max_samples]):
        print(f"\n  [{i + 1}] {match.match_type.upper()}")
        print(f"      Source:   {match.source_record.merchant_raw} @ {match.source_record.timestamp.date()}")
        print(f"      Amount:   ${match.source_record.amount:.2f}")
        print(f"      Target:   {match.target_record.merchant_raw if match.target_record else 'N/A'}")
        print(f"      Confidence: {match.confidence:.2f}")
        print(f"      Reason: {match.reason}")

    if len(result) > max_samples:
        print(f"\n  ... and {len(result) - max_samples} more")


def main():
    """Run the demonstration."""
    print_section("WAVE 3: DETERMINISTIC RECONCILIATION BASELINE")
    print(
        "Building a measurable baseline for transaction reconciliation.\n"
        "All matching is deterministic (no ML) to establish ground truth."
    )

    # Generate synthetic data
    print_section("STEP 1: Generate Synthetic Transaction Data")
    config = SyntheticDataConfig(
        seed=42,
        num_transactions=100,
        start_date=datetime(2024, 1, 1, tzinfo=UTC),
        end_date=datetime(2024, 1, 31, tzinfo=UTC),
        user_id="demo_user",
        pct_exact_match=30.0,
        pct_merchant_variation=25.0,
        pct_date_shift=20.0,
        pct_amount_difference=10.0,
        pct_missing=5.0,
        pct_duplicate=5.0,
        pct_ambiguous=5.0,
    )

    generator = SyntheticDataGenerator(config)
    gpay_records = generator.generate_gpay_source()
    bank_records = generator.generate_bank_statement_source()

    print(f"Generated {len(gpay_records)} GPay transactions")
    print(f"Generated {len(bank_records)} Bank statement transactions")

    # Create reconciliation service
    print_section("STEP 2: Run Deterministic Reconciliation")
    service = ReconciliationService(date_tolerance_days=1, amount_tolerance=0.01)

    result = service.reconcile_sources(gpay_records, bank_records)

    # Display statistics
    print_section("STEP 3: Reconciliation Results")
    stats = result["statistics"]

    print(f"Total records reconciled:  {stats['total_records']}")
    print(f"\nMatch Breakdown:")
    print(f"  Exact matches (Rule 1):    {stats['exact_matches']:3d} ({stats['exact_rate']*100:5.1f}%)")
    print(f"  Strong matches (Rule 2):   {stats['strong_matches']:3d} ({stats['strong_rate']*100:5.1f}%)")
    print(f"  Amount mismatches (Rule 3):{stats['amount_mismatches']:3d} ({(stats['amount_mismatches']/stats['total_records'])*100:5.1f}%)")
    print(f"  Unmatched (Rule 4):        {stats['unmatched']:3d} ({(stats['unmatched']/stats['total_records'])*100:5.1f}%)")
    print(f"\nOverall match rate: {stats['total_matched']}/{stats['total_records']} ({stats['match_rate']*100:.1f}%)")

    # Show examples of each type
    print_section("STEP 4: Example Matches by Type")

    if result["exact_matches"]:
        print("\nRule 1: EXACT MATCHES (Same reference ID + amount)")
        print_match_details(result["exact_matches"], max_samples=3)

    if result["strong_matches"]:
        print("\nRule 2: STRONG MATCHES (Same merchant + amount + date)")
        print_match_details(result["strong_matches"], max_samples=3)

    if result["amount_mismatches"]:
        print("\nRule 3: AMOUNT MISMATCHES (Same merchant, different amount)")
        print_match_details(result["amount_mismatches"], max_samples=3)

    if result["unmatched"]:
        print("\nRule 4: UNMATCHED RECORDS")
        for i, match in enumerate(result["unmatched"][:3]):
            print(f"\n  [{i + 1}] {match.match_type.upper()}")
            print(f"      Source: {match.source_record.merchant_raw} @ {match.source_record.timestamp.date()}")
            print(f"      Amount: ${match.source_record.amount:.2f}")
            print(f"      Reason: {match.reason}")

    # Show baseline key metrics
    print_section("BASELINE METRICS FOR AI COMPARISON")
    print(f"This deterministic baseline achieves:")
    print(f"  - {stats['match_rate']*100:.1f}% overall match rate")
    print(f"  - {stats['exact_rate']*100:.1f}% exact matches (highest confidence)")
    print(f"  - {stats['amount_mismatches']} potential issues identified")
    print(f"  - {stats['unmatched']} unmatched records")
    print(f"\nAI-based reconciliation should improve on these metrics.")
    print(f"Without this baseline, we cannot prove AI adds value.")

    print_section("READY FOR WAVE 4: AI-ENHANCED RECONCILIATION")
    print(
        "The deterministic baseline is now established.\n"
        "Next: Implement AI-based matching that improves over these metrics."
    )


if __name__ == "__main__":
    main()
