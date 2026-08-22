import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../statements/domain/statement_analytics.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/avatar_chip.dart';
import '../../../shared/widgets/category_bar_row.dart';
import '../../../shared/widgets/delta_chip.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../shared/widgets/period_pill.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/signal_card.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_state.dart';
import '../../statements/domain/statement.dart';
import '../../statements/presentation/period_providers.dart';
import 'period_switcher_sheet.dart';

class OverviewScreen extends ConsumerStatefulWidget {
  const OverviewScreen({super.key});

  @override
  ConsumerState<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends ConsumerState<OverviewScreen> {
  bool _categoriesExpanded = false;

  @override
  Widget build(BuildContext context) {
    final periodsAsync = ref.watch(periodsProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: periodsAsync.when(
        loading: () => const _OverviewSkeleton(),
        error: (error, _) => ErrorRetry(onRetry: () => ref.invalidate(periodsProvider)),
        data: (periods) {
          final current = ref.watch(currentPeriodProvider);
          if (current == null) {
            return EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No periods yet',
              subtitle: 'Add your first Google Pay statement to see your overview.',
              cta: PrimaryPillButton(label: 'Add a statement', expand: false, onPressed: () => showPeriodSwitcher(context, ref)),
            );
          }
          if (current.processingStatus != ProcessingStatus.completed) {
            return _ProcessingPlaceholder(period: current);
          }
          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: () async {
              ref.invalidate(periodsProvider);
              ref.invalidate(currentPeriodAnalyticsProvider);
              ref.invalidate(currentPeriodInsightsProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(period: current),
                  Padding(
                    padding: EdgeInsets.fromLTRB(AppSpacing.gutter, 24, AppSpacing.gutter, AppSpacing.navClearance + MediaQuery.of(context).padding.bottom),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SignalsPreview(),
                        const SizedBox(height: 26),
                        _CategoryBreakdown(expanded: _categoriesExpanded, onExpand: () => setState(() => _categoriesExpanded = true)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.period});
  final Statement period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(currentPeriodAnalyticsProvider);
    final previousAsync = ref.watch(previousPeriodAnalyticsProvider);
    final authState = ref.watch(authControllerProvider).valueOrNull;
    final initials = switch (authState) {
      AuthAuthenticated(:final user) => user.initials,
      _ => '?',
    };

    return Container(
      color: AppColors.ink900,
      padding: EdgeInsets.fromLTRB(AppSpacing.gutter, MediaQuery.of(context).padding.top + 6, AppSpacing.gutter, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PeriodPill(
                label: formatPeriodRange(period.periodStart, period.periodEnd),
                onTap: () => showPeriodSwitcher(context, ref),
              ),
              const Spacer(),
              ExcludeSemantics(
                child: Container(
                  width: 34,
                  height: 34,
                  margin: const EdgeInsets.only(right: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.ink800, border: Border.all(color: AppColors.hairlineDark), shape: BoxShape.circle),
                  child: Icon(Icons.notifications_none_rounded, size: 17, color: AppColors.onDarkMuted),
                ),
              ),
              Semantics(
                button: true,
                label: 'Open profile',
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.push('/profile'),
                    child: Center(
                      child: AvatarChip(
                        initials: initials,
                        size: 34,
                        gradient: LinearGradient(colors: [AppColors.accent, AppColors.accentDim]),
                        foregroundColor: AppColors.accentInk,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text('NET FLOW · ${_spanLabel(period)}', style: AppTypography.microLabel11.copyWith(color: AppColors.onDarkFaint)),
          const SizedBox(height: 6),
          analyticsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 180, height: 40, dark: true),
                  SizedBox(height: 16),
                  SkeletonBox(width: double.infinity, height: 8, radius: 4, dark: true),
                  SizedBox(height: 14),
                  SkeletonBox(width: 120, height: 30, dark: true),
                ],
              ),
            ),
            error: (e, _) => Text('Could not load analytics.', style: AppTypography.footnote12.copyWith(color: AppColors.rose)),
            data: (analytics) {
              if (analytics == null) return const SizedBox.shrink();
              final net = analytics.totalIncome - analytics.totalSpend;
              double? deltaPercent;
              final previous = previousAsync.valueOrNull;
              if (previous != null) {
                final prevNet = previous.totalIncome - previous.totalSpend;
                // Chip communicates how outflow trended, not raw net: rose+▲
                // means you're further in the red than last period, accent+▼
                // means it improved - matches the mock's "▲12%" rose chip
                // sitting next to a negative net-flow hero.
                if (prevNet != 0) deltaPercent = (prevNet - net) / prevNet.abs() * 100;
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(formatCurrency(net), style: AppTypography.heroAmount44.copyWith(color: AppColors.onDark)),
                      if (deltaPercent != null) ...[
                        const SizedBox(width: 10),
                        DeltaChip(
                          label: '${deltaPercent >= 0 ? '▲' : '▼'} ${deltaPercent.abs().round()}%',
                          up: deltaPercent >= 0,
                          tint: (deltaPercent >= 0 ? AppColors.rose : AppColors.accent).withValues(alpha: 0.16),
                          foreground: deltaPercent >= 0 ? AppColors.rose : AppColors.accent,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 8,
                      child: Row(
                        children: [
                          Expanded(
                          flex: analytics.totalSpend.round().clamp(1, 1 << 30),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [AppColors.rose, AppColors.roseFlowGradientEnd]),
                            ),
                          ),
                        ),
                          const SizedBox(width: 3),
                          Expanded(flex: analytics.totalIncome.round().clamp(1, 1 << 30), child: Container(color: AppColors.accent)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SENT', style: AppTypography.microLabel11.copyWith(color: AppColors.onDarkFaint)),
                          Text(formatCurrency(analytics.totalSpend), style: AppTypography.amountMedium17.copyWith(color: AppColors.onDark)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('RECEIVED', style: AppTypography.microLabel11.copyWith(color: AppColors.onDarkFaint)),
                          Text(formatCurrency(analytics.totalIncome), style: AppTypography.amountMedium17.copyWith(color: AppColors.accentDim)),
                        ],
                      ),
                    ],
                  ),
                  if (period.reconciliationOk != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                      decoration: BoxDecoration(color: AppColors.ink850, border: Border.all(color: AppColors.hairlineDark), borderRadius: BorderRadius.circular(AppRadius.field)),
                      child: Row(
                        children: [
                          Icon(
                            period.reconciliationOk! ? Icons.check_rounded : Icons.info_outline_rounded,
                            size: 15,
                            color: period.reconciliationOk! ? AppColors.accent : AppColors.amber,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              period.reconciliationOk!
                                  ? "Reconciled against the statement's own totals"
                                  : "Doesn't quite match the statement's declared totals",
                              style: AppTypography.body14.copyWith(fontSize: 12, color: AppColors.onDarkMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _spanLabel(Statement period) {
    final months = (period.periodEnd.year - period.periodStart.year) * 12 + (period.periodEnd.month - period.periodStart.month) + 1;
    return months <= 1 ? '1 MONTH' : '$months MONTHS';
  }
}

class _SignalsPreview extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(currentPeriodInsightsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          label: 'SIGNALS',
          labelColor: AppColors.onLightFaint,
          trailing: TextActionLink(label: 'All →', onPressed: () => context.go('/shell/signals')),
        ),
        const SizedBox(height: 12),
        insightsAsync.when(
          loading: () => const Column(children: [SkeletonBox(width: double.infinity, height: 74, radius: 16), SizedBox(height: 12), SkeletonBox(width: double.infinity, height: 74, radius: 16)]),
          error: (e, _) => Text('Could not load signals.', style: AppTypography.footnote12.copyWith(color: AppColors.onLightMuted)),
          data: (insights) {
            if (insights.isEmpty) {
              return Text('No signals yet for this period.', style: AppTypography.footnote12.copyWith(color: AppColors.onLightMuted));
            }
            final preview = insights.take(2).toList();
            return Column(
              children: [
                for (var i = 0; i < preview.length; i++) ...[
                  SignalCard(
                    kind: preview[i].severity.signalKind,
                    subtype: preview[i].type.toUpperCase(),
                    body: preview[i].message,
                    dark: false,
                    entranceDelayMs: i * 60,
                  ),
                  if (i != preview.length - 1) const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CategoryBreakdown extends ConsumerWidget {
  const _CategoryBreakdown({required this.expanded, required this.onExpand});
  final bool expanded;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(currentPeriodAnalyticsProvider);
    final previousAsync = ref.watch(previousPeriodAnalyticsProvider);

    return analyticsAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < 4; i++) ...[
              const SkeletonBox(width: double.infinity, height: 34),
              if (i != 3) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (analytics) {
        if (analytics == null || analytics.categoryBreakdown.isEmpty) return const SizedBox.shrink();
        final sorted = [...analytics.categoryBreakdown]..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
        final totalOfShown = analytics.totalSpend;
        final maxAmount = sorted.first.totalAmount == 0 ? 1 : sorted.first.totalAmount;
        final visible = expanded ? sorted : sorted.take(4).toList();
        final previousCategories = previousAsync.valueOrNull?.categoryBreakdown;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              label: 'WHERE IT WENT',
              labelColor: AppColors.onLightFaint,
              trailing: Text('of ${formatCurrency(totalOfShown)}', style: AppTypography.body14.copyWith(fontSize: 12, color: AppColors.onLightFaint)),
            ),
            const SizedBox(height: 4),
            for (final entry in visible)
              CategoryBarRow(
                name: entry.category,
                amountLabel: formatCurrency(entry.totalAmount),
                percentOfTotal: totalOfShown == 0 ? 0 : (entry.totalAmount / totalOfShown * 100).round(),
                relativeWidthFraction: entry.totalAmount / maxAmount,
                color: AppColors.forCategory(entry.category),
                trendCaption: _trendCaption(entry.category, entry.totalAmount, previousCategories),
                onTap: () => context.push('/category/${Uri.encodeComponent(entry.category)}'),
              ),
            if (!expanded && sorted.length > 4) ...[
              const SizedBox(height: 8),
              TextActionLink(label: 'Show ${sorted.length - 4} more categories', onPressed: onExpand),
            ],
          ],
        );
      },
    );
  }

  String? _trendCaption(String category, double current, List<CategoryBreakdownEntry>? previousCategories) {
    if (previousCategories == null) return null;
    final match = previousCategories.firstWhereOrNull((e) => e.category == category);
    if (match == null || match.totalAmount == 0) return null;
    final delta = (current - match.totalAmount) / match.totalAmount * 100;
    final arrow = delta <= 0 ? '↓' : '↑';
    return '$arrow ${delta.abs().round()}% vs previous period';
  }
}

class _ProcessingPlaceholder extends StatelessWidget {
  const _ProcessingPlaceholder({required this.period});
  final Statement period;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.accent),
            const SizedBox(height: 20),
            Text("We're still analysing your statement", textAlign: TextAlign.center, style: AppTypography.bigHeadline22.copyWith(color: AppColors.onLight)),
            const SizedBox(height: 8),
            Text(period.originalFilename, textAlign: TextAlign.center, style: AppTypography.footnote12.copyWith(color: AppColors.onLightMuted)),
            const SizedBox(height: 20),
            if (period.currentJobId != null)
              PrimaryPillButton(
                label: 'View progress',
                expand: false,
                onPressed: () => context.push('/upload/analysing/${period.currentJobId}'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Full-page skeleton matching Overview's header/signals/category layout,
/// shown while the initial periods load is in flight.
class _OverviewSkeleton extends StatelessWidget {
  const _OverviewSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppColors.ink900,
            padding: EdgeInsets.fromLTRB(AppSpacing.gutter, MediaQuery.of(context).padding.top + 6, AppSpacing.gutter, 26),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SkeletonBox(width: 96, height: 30, radius: 100, dark: true),
                    Spacer(),
                    SkeletonBox(width: 34, height: 34, radius: 17, dark: true),
                    SizedBox(width: 10),
                    SkeletonBox(width: 34, height: 34, radius: 17, dark: true),
                  ],
                ),
                SizedBox(height: 26),
                SkeletonBox(width: 140, height: 12, dark: true),
                SizedBox(height: 10),
                SkeletonBox(width: 180, height: 40, dark: true),
                SizedBox(height: 16),
                SkeletonBox(width: double.infinity, height: 8, radius: 4, dark: true),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.gutter, 24, AppSpacing.gutter, AppSpacing.navClearance + MediaQuery.of(context).padding.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(width: 90, height: 12),
                const SizedBox(height: 12),
                const SkeletonBox(width: double.infinity, height: 74, radius: 16),
                const SizedBox(height: 12),
                const SkeletonBox(width: double.infinity, height: 74, radius: 16),
                const SizedBox(height: 26),
                const SkeletonBox(width: 120, height: 12),
                const SizedBox(height: 16),
                for (var i = 0; i < 4; i++) ...[
                  const SkeletonBox(width: double.infinity, height: 34),
                  if (i != 3) const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
