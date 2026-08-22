import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/avatar_chip.dart';
import '../../../shared/widgets/delta_chip.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../shared/widgets/mini_bar_chart.dart';
import '../../../shared/widgets/screen_back_header.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../statements/presentation/period_providers.dart';
import 'category_drilldown_controller.dart';

class CategoryDrilldownScreen extends ConsumerWidget {
  const CategoryDrilldownScreen({super.key, required this.category});

  final String category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(currentPeriodProvider);
    final analyticsAsync = ref.watch(currentPeriodAnalyticsProvider);
    final previousAnalyticsAsync = ref.watch(previousPeriodAnalyticsProvider);
    final drilldownAsync = ref.watch(categoryDrilldownProvider(category));
    final color = AppColors.forCategory(category);

    final categoryEntry = analyticsAsync.valueOrNull?.categoryBreakdown.where((e) => e.category == category).firstOrNull;
    final total = categoryEntry?.totalAmount ?? 0;

    double? deltaPercent;
    final previousEntry = previousAnalyticsAsync.valueOrNull?.categoryBreakdown.where((e) => e.category == category).firstOrNull;
    if (previousEntry != null && previousEntry.totalAmount > 0) {
      deltaPercent = (total - previousEntry.totalAmount) / previousEntry.totalAmount * 100;
    }

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: AppColors.ink900,
                padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 6, AppSpacing.gutter, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ScreenBackHeader(centerTitle: period == null ? '' : formatPeriodRange(period.periodStart, period.periodEnd)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(category, style: AppTypography.navTitle15.copyWith(color: AppColors.onDark)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(formatCurrency(total), style: AppTypography.heroAmount36.copyWith(color: AppColors.onDark)),
                        if (deltaPercent != null) ...[
                          const SizedBox(width: 10),
                          DeltaChip(
                            label: '${deltaPercent >= 0 ? '↑' : '↓'} ${deltaPercent.abs().round()}%',
                            up: deltaPercent >= 0,
                            tint: (deltaPercent >= 0 ? AppColors.rose : AppColors.accent).withValues(alpha: 0.16),
                            foreground: deltaPercent >= 0 ? AppColors.rose : AppColors.accent,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    drilldownAsync.when(
                      loading: () => const SizedBox(height: 78),
                      error: (_, _) => const SizedBox(height: 78),
                      data: (drilldown) {
                        final maxTotal = drilldown.monthlyBuckets.fold<double>(0, (m, b) => b.total > m ? b.total : m);
                        return MiniBarChart(
                          entries: [
                            for (var i = 0; i < drilldown.monthlyBuckets.length; i++)
                              MiniBarChartEntry(
                                label: monthAbbr(drilldown.monthlyBuckets[i].month),
                                heightFraction: maxTotal == 0 ? 0.02 : (drilldown.monthlyBuckets[i].total / maxTotal).clamp(0.02, 1),
                                highlighted: i == drilldown.monthlyBuckets.length - 1,
                                tooltip: i == drilldown.monthlyBuckets.length - 1 ? formatCompactCurrency(drilldown.monthlyBuckets[i].total) : null,
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MERCHANTS IN ${category.toUpperCase()}', style: AppTypography.microLabelTracked11.copyWith(color: AppColors.onLightFaint)),
                    const SizedBox(height: 12),
                    drilldownAsync.when(
                      loading: () => Column(
                        children: [
                          for (var i = 0; i < 3; i++) ...[
                            const SkeletonListRow(),
                            if (i != 2) const Divider(height: 1, indent: 62),
                          ],
                        ],
                      ),
                      error: (e, _) => ErrorRetry(onRetry: () => ref.invalidate(categoryDrilldownProvider(category)), message: 'Could not load merchants.'),
                      data: (drilldown) {
                        if (drilldown.merchants.isEmpty) {
                          return const EmptyState(
                            icon: Icons.receipt_outlined,
                            title: 'No transactions found for this category yet',
                          );
                        }
                        final top = drilldown.merchants.take(5).toList();
                        return Container(
                          decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.hairlineLight), borderRadius: BorderRadius.circular(AppRadius.card)),
                          child: Column(
                            children: [
                              for (var i = 0; i < top.length; i++) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                  child: Row(
                                    children: [
                                      AvatarChip(
                                        initials: top[i].merchant.isEmpty ? '?' : top[i].merchant[0].toUpperCase(),
                                        size: 36,
                                        radius: 11,
                                        backgroundColor: color.withValues(alpha: 0.16),
                                        foregroundColor: color,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(top[i].merchant, style: AppTypography.rowLabel14.copyWith(color: AppColors.onLight)),
                                            Text(
                                              '${top[i].count} order${top[i].count == 1 ? '' : 's'} · ${formatCurrency(top[i].average)} avg',
                                              style: AppTypography.meta115.copyWith(color: AppColors.onLightFaint),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(formatCurrency(top[i].total), style: AppTypography.amountMedium14.copyWith(color: AppColors.onLight)),
                                    ],
                                  ),
                                ),
                                if (i != top.length - 1) Divider(height: 1, color: AppColors.hairlineLight, indent: 62),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    drilldownAsync.maybeWhen(
                      data: (drilldown) {
                        if (drilldown.merchants.isEmpty || total <= 0) return const SizedBox.shrink();
                        final topMerchant = drilldown.merchants.first;
                        final share = (topMerchant.total / total * 100).round();
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.hairlineLight), borderRadius: BorderRadius.circular(AppRadius.card)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: AppColors.accentTint, shape: BoxShape.circle),
                                child: Text('✦', style: TextStyle(fontSize: 11, color: AppColors.accentInk)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${topMerchant.merchant} accounts for $share% of your $category spend this period.',
                                  style: AppTypography.cardBody135.copyWith(color: AppColors.onLight),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
