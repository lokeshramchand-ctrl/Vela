"""
Phase 16: performance qualification tests. Runs the real matcher at each
scale and asserts only what was actually measured - no extrapolation
beyond 500 records, and no throughput/latency claims about the full
ingestion-to-persistence pipeline (this measures AIEntityMatcher +
confidence-wall routing only; it does not include PDF parsing, MongoDB
I/O, or any network round-trip - see evaluation/run_performance_benchmark.py
and docs/PHASE16_PERFORMANCE.md for the full honesty accounting).
"""

import unittest

from evaluation.dataset import generate_scaled_dataset
from evaluation.harness import run_evaluation


class TestPerformanceAtScale(unittest.TestCase):
    def test_50_100_250_500_records_all_complete_with_zero_false_matches(self):
        for n in (50, 100, 250, 500):
            with self.subTest(records=n):
                dataset = generate_scaled_dataset(n)
                result = run_evaluation(dataset)
                self.assertEqual(result.records_processed, n)
                self.assertEqual(result.false_match_count, 0)
                self.assertEqual(result.precision, 1.0)

    def test_throughput_does_not_degrade_from_50_to_500_records(self):
        """Not a strict performance regression gate (real timing is noisy on
        shared CI runners) - just confirms there's no gross
        quadratic-or-worse blowup as record count grows: 500 records must
        not take more than a generous multiple of what 50 records took."""
        throughput = {}
        for n in (50, 500):
            result = run_evaluation(generate_scaled_dataset(n))
            throughput[n] = result.throughput_per_second

        self.assertGreater(throughput[500], throughput[50] * 0.2)

    def test_500_records_completes_in_well_under_one_second(self):
        result = run_evaluation(generate_scaled_dataset(500))
        self.assertLess(result.elapsed_seconds, 1.0)


if __name__ == "__main__":
    unittest.main()
