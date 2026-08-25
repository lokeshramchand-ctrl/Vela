"""
Phase 16: performance qualification at scale.

Measures actual, real throughput/latency of the real AIEntityMatcher +
confidence-wall routing (evaluation.harness.run_evaluation) at 50, 100,
250, and 500 records - not extrapolated. Each size is its own independent
run against its own freshly-generated dataset
(evaluation.dataset.generate_scaled_dataset), so "500 records" isn't 250
doubled or estimated, it's actually run.

Usage: python -m evaluation.run_performance_benchmark
"""

import json
import time

from evaluation.dataset import generate_scaled_dataset
from evaluation.harness import run_evaluation

SCALES = (50, 100, 250, 500)


def main() -> None:
    print(f"{'records':>10}{'elapsed_s':>12}{'records/sec':>14}{'avg_latency_ms':>17}")
    results = []
    for n in SCALES:
        dataset = generate_scaled_dataset(n)
        wall_start = time.perf_counter()
        result = run_evaluation(dataset)
        wall_elapsed = time.perf_counter() - wall_start

        avg_latency_ms = (result.elapsed_seconds / n) * 1000 if n else 0.0
        results.append({
            "records": n,
            "elapsed_seconds": round(result.elapsed_seconds, 5),
            "wall_elapsed_seconds": round(wall_elapsed, 5),
            "throughput_per_second": round(result.throughput_per_second, 1),
            "avg_latency_ms_per_record": round(avg_latency_ms, 4),
            "false_match_count": result.false_match_count,
            "precision": round(result.precision, 4),
        })
        print(f"{n:>10}{result.elapsed_seconds:>12.5f}{result.throughput_per_second:>14.1f}{avg_latency_ms:>17.4f}")

    print()
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
