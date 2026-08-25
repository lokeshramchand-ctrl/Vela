"""
Wave 8: Evaluation CLI.

Generates the synthetic ground-truth dataset, runs the real matcher blind,
and prints a report: precision, recall, exception rate, throughput, and the
false-match-cost comparison against a naive always-commit baseline.

Usage:
    python -m evaluation.run_evaluation
"""

from evaluation.dataset import generate_dataset
from evaluation.harness import CaseCategory, Outcome, naive_baseline_cost, run_evaluation


def main() -> None:
    dataset = generate_dataset(seed=42)
    result = run_evaluation(dataset)
    baseline_cost = naive_baseline_cost(dataset)
    summary = result.summary()

    print("=" * 60)
    print("Vela Wave 8 - Matching Engine Evaluation")
    print("=" * 60)
    print(f"Records processed:     {summary['records_processed']}")
    print(f"Elapsed:               {summary['elapsed_seconds']}s")
    print(f"Throughput:            {summary['throughput_per_second']} records/sec")
    print()
    print(f"Precision:             {summary['precision']:.2%}")
    print(f"Recall (discovered):   {summary['recall']:.2%}")
    print(f"Automation rate:       {summary['automation_rate']:.2%}")
    print(f"Exception rate:        {summary['exception_rate']:.2%}")
    print(f"Auto-matched:          {summary['auto_match_count']}")
    print(f"Exceptions/review:     {summary['exception_count']}")
    print()
    print("Outcome breakdown:")
    for outcome in Outcome:
        print(f"  {outcome.value:<22} {summary['outcomes'][outcome.value]}")
    print()
    print("False-match cost story (lower is better):")
    print(f"  Vela (confidence walls):   {summary['total_false_match_cost']:.1f}")
    print(f"  Naive (always commit):     {baseline_cost:.1f}")
    if baseline_cost > 0:
        reduction = 1 - (summary["total_false_match_cost"] / baseline_cost)
        print(f"  Cost reduction:            {reduction:.1%}")
    print()

    known_exception_false_matches = sum(
        1 for r in result.case_results
        if r.category == CaseCategory.KNOWN_EXCEPTION and r.outcome == Outcome.FALSE_AUTO_MATCH
    )
    ambiguous_false_matches = sum(
        1 for r in result.case_results
        if r.category == CaseCategory.AMBIGUOUS and r.outcome == Outcome.FALSE_AUTO_MATCH
    )
    print(f"Known exceptions falsely auto-matched:  {known_exception_false_matches} / {21}")
    print(f"Ambiguous cases falsely auto-matched:   {ambiguous_false_matches} / {8}")
    print("=" * 60)


if __name__ == "__main__":
    main()
