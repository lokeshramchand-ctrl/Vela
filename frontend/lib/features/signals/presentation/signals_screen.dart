import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../shared/widgets/signal_card.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../statements/domain/insight.dart';
import '../../statements/presentation/period_providers.dart';

enum _SignalFilter { all, watch, good }

class SignalsScreen extends ConsumerStatefulWidget {
  const SignalsScreen({super.key});

  @override
  ConsumerState<SignalsScreen> createState() => _SignalsScreenState();
}

class _SignalsScreenState extends ConsumerState<SignalsScreen> {
  _SignalFilter _filter = _SignalFilter.all;

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(currentPeriodProvider);
    final analyticsAsync = ref.watch(currentPeriodAnalyticsProvider);
    final insightsAsync = ref.watch(currentPeriodInsightsProvider);

    return Scaffold(
      backgroundColor: AppColors.ink900,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(AppSpacing.gutter, 6, AppSpacing.gutter, AppSpacing.navClearance + MediaQuery.of(context).padding.bottom),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Signals', style: AppTypography.screenTitle24.copyWith(color: AppColors.onDark)),
                if (period != null)
                  Text(
                    '${monthAbbr(period.periodStart.month)}–${monthAbbr(period.periodEnd.month)} ${period.periodEnd.year}'.toUpperCase(),
                    style: AppTypography.microLabel11.copyWith(color: AppColors.onDarkFaint),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            analyticsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (analytics) {
                if (analytics == null) return const SizedBox.shrink();
                final sorted = [...analytics.categoryBreakdown]..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
                final top = sorted.take(2).map((e) => e.category).join(' and ');
                final share = analytics.totalSpend == 0 ? 0 : (sorted.take(2).fold<double>(0, (m, e) => m + e.totalAmount) / analytics.totalSpend * 100).round();
                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.accent.withValues(alpha: 0.14), Colors.transparent]),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.28)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('THE HEADLINE', style: AppTypography.microLabelTracked105.copyWith(color: AppColors.accent)),
                      const SizedBox(height: 10),
                      Text.rich(
                        TextSpan(
                          style: AppTypography.signalBody17.copyWith(color: AppColors.onDark),
                          children: [
                            const TextSpan(text: 'You spent '),
                            TextSpan(text: formatCurrency(analytics.totalSpend), style: AppTypography.amountMedium17.copyWith(color: AppColors.onDark)),
                            const TextSpan(text: ' this period and kept '),
                            TextSpan(text: formatCurrency(analytics.totalIncome), style: AppTypography.amountMedium17.copyWith(color: AppColors.onDark)),
                            const TextSpan(text: ' coming in.'),
                            if (sorted.isNotEmpty) TextSpan(text: ' $top ${sorted.length > 1 ? 'are' : 'is'} $share% of everything.'),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            insightsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (insights) {
                final watchCount = insights.where((i) => i.severity == InsightSeverity.warning).length;
                final goodCount = insights.where((i) => i.severity == InsightSeverity.positive).length;
                return Row(
                  children: [
                    _chip('All ${insights.length}', _filter == _SignalFilter.all, () => setState(() => _filter = _SignalFilter.all)),
                    const SizedBox(width: 8),
                    _chip('Watch $watchCount', _filter == _SignalFilter.watch, () => setState(() => _filter = _SignalFilter.watch)),
                    const SizedBox(width: 8),
                    _chip('Good $goodCount', _filter == _SignalFilter.good, () => setState(() => _filter = _SignalFilter.good)),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            insightsAsync.when(
              loading: () => Column(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    const SkeletonBox(width: double.infinity, height: 96, radius: 16, dark: true),
                    if (i != 2) const SizedBox(height: 12),
                  ],
                ],
              ),
              error: (e, _) => ErrorRetry(dark: true, message: 'Could not load signals.', onRetry: () => ref.invalidate(currentPeriodInsightsProvider)),
              data: (insights) {
                final filtered = insights.where((i) {
                  return switch (_filter) {
                    _SignalFilter.all => true,
                    _SignalFilter.watch => i.severity == InsightSeverity.warning,
                    _SignalFilter.good => i.severity == InsightSeverity.positive,
                  };
                }).toList();
                if (filtered.isEmpty) {
                  return const EmptyState(
                    dark: true,
                    icon: Icons.auto_awesome_outlined,
                    title: 'No signals in this filter yet',
                    subtitle: 'Switch filters or check back after your next statement.',
                  );
                }
                return Column(
                  children: [
                    for (var i = 0; i < filtered.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SignalCard(
                          kind: filtered[i].severity.signalKind,
                          subtype: filtered[i].type.toUpperCase(),
                          body: filtered[i].message,
                          dark: true,
                          entranceDelayMs: i * 60,
                          ctaLabel: filtered[i].type.toUpperCase().contains('RECUR') ? 'Open' : null,
                          onCta: filtered[i].type.toUpperCase().contains('RECUR') ? () => context.push('/recurring') : null,
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              "Signals are written from your computed analytics only. If a figure isn't in your statement, Vela won't claim it.",
              textAlign: TextAlign.center,
              style: AppTypography.footnote1155.copyWith(color: AppColors.onDarkFaint),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.ink700 : Colors.transparent,
            border: Border.all(color: AppColors.hairlineDark),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(label, style: AppTypography.buttonLabel12.copyWith(color: selected ? AppColors.onDark : AppColors.onDarkMuted)),
        ),
      ),
    );
  }
}
