import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/feature_providers.dart';
import '../domain/insight.dart';
import '../domain/job.dart';
import '../domain/statement.dart';
import '../domain/statement_analytics.dart';

/// A "period" is a Statement, per the design's "NEW MODEL" framing (see
/// docs/DESIGN_SPEC.md §0) - one Google Pay statement upload, switched from
/// the header pill rather than browsed as a file list.

/// Explicit user selection from the Period switcher sheet. Null means "use
/// the default" (most recent COMPLETED period) - see [currentPeriodProvider].
final selectedPeriodIdProvider = StateProvider<String?>((ref) => null);

final periodsProvider = FutureProvider<List<Statement>>((ref) async {
  final repo = ref.watch(statementsRepositoryProvider);
  final res = await repo.list(page: 1, pageSize: 50, sortBy: 'uploaded_at', sortOrder: 'desc');
  return res.items;
});

/// A single job snapshot (not polled) - for the Period switcher's live row,
/// which just needs one progress reading, not a ticking subscription.
/// `autoDispose` + `family` so Riverpod caches/dedupes this across rebuilds
/// instead of a bare `ref.read(...).get(id)` re-firing the request (and
/// resetting to "loading") every time the sheet rebuilds.
final jobSnapshotProvider = FutureProvider.autoDispose.family<Job, String>((ref, jobId) {
  return ref.watch(jobsRepositoryProvider).get(jobId);
});

final currentPeriodProvider = Provider<Statement?>((ref) {
  final periods = ref.watch(periodsProvider).valueOrNull;
  if (periods == null || periods.isEmpty) return null;

  final selectedId = ref.watch(selectedPeriodIdProvider);
  if (selectedId != null) {
    for (final period in periods) {
      if (period.id == selectedId) return period;
    }
  }

  for (final period in periods) {
    if (period.processingStatus == ProcessingStatus.completed) return period;
  }
  return periods.first;
});

final currentPeriodAnalyticsProvider = FutureProvider<StatementAnalytics?>((ref) async {
  final period = ref.watch(currentPeriodProvider);
  if (period == null || period.processingStatus != ProcessingStatus.completed) return null;
  return ref.watch(statementsRepositoryProvider).analytics(period.id);
});

final currentPeriodInsightsProvider = FutureProvider<List<Insight>>((ref) async {
  final period = ref.watch(currentPeriodProvider);
  if (period == null || period.processingStatus != ProcessingStatus.completed) return const [];
  final response = await ref.watch(statementsRepositoryProvider).insights(period.id);
  return response.insights;
});

/// The completed period immediately before [currentPeriodProvider],
/// chronologically - lets Overview/Category-drilldown show real "vs
/// previous period" deltas instead of inventing them.
final previousPeriodProvider = Provider<Statement?>((ref) {
  final periods = ref.watch(periodsProvider).valueOrNull;
  final current = ref.watch(currentPeriodProvider);
  if (periods == null || current == null) return null;

  final completed = periods.where((p) => p.processingStatus == ProcessingStatus.completed).toList();
  final index = completed.indexWhere((p) => p.id == current.id);
  if (index == -1 || index + 1 >= completed.length) return null;
  return completed[index + 1];
});

final previousPeriodAnalyticsProvider = FutureProvider<StatementAnalytics?>((ref) async {
  final previous = ref.watch(previousPeriodProvider);
  if (previous == null) return null;
  return ref.watch(statementsRepositoryProvider).analytics(previous.id);
});

/// The most recent period still being processed, if any - drives the
/// Period switcher's live "ANALYSING · N%" row and the Analysing screen.
final inProgressPeriodProvider = Provider<Statement?>((ref) {
  final periods = ref.watch(periodsProvider).valueOrNull;
  if (periods == null) return null;
  for (final period in periods) {
    if (period.processingStatus == ProcessingStatus.pending || period.processingStatus == ProcessingStatus.processing) {
      return period;
    }
  }
  return null;
});
