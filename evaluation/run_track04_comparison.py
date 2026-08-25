"""
Phase 9-10: runs the deterministic baseline and full Vela against the
identical Track 04 benchmark and prints both summaries plus a direct
comparison. This is the script docs/track04-final-evaluation.md's numbers
are generated from - run it and paste the output, don't hand-type numbers
into the report.

Usage: python -m evaluation.run_track04_comparison
"""

import json

from evaluation.dataset import generate_track04_benchmark
from evaluation.deterministic_baseline import run_deterministic_evaluation
from evaluation.harness import naive_baseline_cost, run_evaluation


def main() -> None:
    dataset = generate_track04_benchmark()

    print(f"Dataset: {len(dataset.source_a)} Source A / {len(dataset.source_b)} Source B / "
          f"{len(dataset.cases)} cases (seed=42, deterministic)\n")

    baseline = run_deterministic_evaluation(dataset)
    print("=== Deterministic baseline (exact-equality rule, no AI) ===")
    print(json.dumps(baseline.summary(), indent=2))
    print()

    vela = run_evaluation(dataset)
    print("=== Full Vela (AIEntityMatcher + confidence wall) ===")
    print(json.dumps(vela.summary(), indent=2))
    print()

    print("=== Comparison ===")
    print(f"{'metric':<22}{'baseline':>12}{'full Vela':>12}{'delta':>12}")
    for label, b_val, v_val in [
        ("precision", baseline.precision, vela.precision),
        ("recall", baseline.recall, vela.recall),
        ("false_match_count", baseline.false_match_count, vela.false_match_count),
        ("match/automation_rate", baseline.match_rate, vela.automation_rate),
        ("throughput_per_second", baseline.throughput_per_second, vela.throughput_per_second),
    ]:
        delta = v_val - b_val if isinstance(b_val, (int, float)) else "n/a"
        print(f"{label:<22}{b_val:>12.4f}{v_val:>12.4f}{delta:>12.4f}")

    print(f"\nnaive_baseline_cost (fuzzy scoring, no confidence wall): {naive_baseline_cost(dataset):.1f}")
    print(f"Full Vela false-match cost (from confidence-wall summary): {vela.total_false_match_cost:.1f}")


if __name__ == "__main__":
    main()
