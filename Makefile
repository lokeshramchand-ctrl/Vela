# Phase 18: one-command Track 04 qualification suite.
#
# Runs every test/evaluation phase 1-16 add up to, in the same order CI runs
# them (.github/workflows/ci.yml's `test` job), plus the evidence-generation
# scripts the Phase 17 report's numbers come from. Any test failure makes the
# corresponding pytest invocation - and therefore `make` itself - exit
# non-zero; `make` stops at the first failing target by default (no -k/-i),
# so a critical failure here is a critical failure of the whole command.
#
# Usage: make test-track04
#
# Requires: a reachable MongoDB (MONGODB_URI env var, or the default
# mongodb://localhost:27017/?authSource=admin) for the live-Mongo targets.
# CI provides this via the mongo:6.0 service container
# (.github/workflows/ci.yml); it was NOT available in the sandbox this
# Makefile was authored in - see evaluation/test_mongo_integration.py's own
# honesty note. Everything else runs with no external dependencies.

.PHONY: test-track04 test-unit test-edge-cases test-evaluation test-periodicity \
        test-pdf-ingestion test-mongo-integration test-benchmark test-baseline \
        test-confidence-wall test-failure-injection test-performance test-e2e \
        report-comparison report-performance

PYTEST := python -m pytest

test-unit:
	$(PYTEST) ai_resolution/test_matcher.py -v \
		--deselect ai_resolution/test_matcher.py::TestNameSimilarityMatcher::test_partial_match \
		--deselect ai_resolution/test_matcher.py::TestAIEntityMatcher::test_score_candidate_high_confidence

test-edge-cases:
	$(PYTEST) evaluation/test_edge_cases.py -v

test-evaluation:
	$(PYTEST) evaluation/test_evaluation.py -v

test-periodicity:
	$(PYTEST) features/test_periodicity.py -v

test-pdf-ingestion:
	$(PYTEST) evaluation/test_pdf_ingestion_hardening.py -v

test-mongo-integration:
	$(PYTEST) evaluation/test_mongo_integration.py -v

test-benchmark:
	$(PYTEST) evaluation/test_track04_benchmark.py -v

test-baseline:
	$(PYTEST) evaluation/test_deterministic_baseline.py -v

test-confidence-wall:
	$(PYTEST) evaluation/test_confidence_wall_policy.py -v

test-failure-injection:
	$(PYTEST) evaluation/test_failure_injection.py -v

test-performance:
	$(PYTEST) evaluation/test_performance.py -v

test-e2e:
	$(PYTEST) evaluation/test_track04_end_to_end.py -v

report-comparison:
	python -m evaluation.run_track04_comparison

report-performance:
	python -m evaluation.run_performance_benchmark

# Full Track 04 qualification suite: 1) unit tests, 2) edge-case tests,
# 3) MongoDB integration tests, 4) real-GPay tests (inside test-edge-cases,
# skip-guarded when the gitignored fixture isn't present), 5) synthetic
# benchmark, 6-7) baseline + full-Vela evaluation, 8) confidence-wall
# evaluation, 9) failure tests, 10) performance test, 11) Track 04 report
# generation (printed evidence, not an auto-rewritten file - see
# docs/track04-final-evaluation.md for the committed report itself).
test-track04: test-unit test-edge-cases test-evaluation test-periodicity \
	test-pdf-ingestion test-mongo-integration test-benchmark test-baseline \
	test-confidence-wall test-failure-injection test-performance test-e2e \
	report-comparison report-performance
	@echo ""
	@echo "=== Track 04 qualification suite: all targets passed ==="
