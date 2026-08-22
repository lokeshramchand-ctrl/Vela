import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/avatar_chip.dart';
import '../../../shared/widgets/category_bar_row.dart';
import '../../../shared/widgets/delta_chip.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../shared/widgets/screen_back_header.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/skeleton.dart';
import 'analytics_providers.dart';

class SpendingPatternsScreen extends ConsumerWidget {
  const SpendingPatternsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 6, AppSpacing.gutter, 28),
          children: [
            ScreenBackHeader(title: 'Spending patterns', titleStyle: AppTypography.navTitle15.copyWith(color: AppColors.onLight), dark: false),
            const SizedBox(height: 20),
            const _MoMTrendCard(),
            const SizedBox(height: 26),
            const _CategoryPatternsSection(),
            const SizedBox(height: 26),
            const _MerchantPatternsSection(),
            const SizedBox(height: 26),
            const _SubscriptionsSection(),
          ],
        ),
      ),
    );
  }
}

class _MoMTrendCard extends ConsumerWidget {
  const _MoMTrendCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final momAsync = ref.watch(momTrendProvider);
    return momAsync.when(
      loading: () => const SkeletonBox(width: double.infinity, height: 96, radius: 16),
      error: (e, _) => ErrorRetry(message: 'Could not load month-over-month trend.', onRetry: () => ref.invalidate(momTrendProvider)),
      data: (mom) {
        final deltaPercent = mom.momGrowthPercentage;
        return Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.hairlineLight), borderRadius: BorderRadius.circular(AppRadius.card)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MONTH OVER MONTH', style: AppTypography.microLabelTracked11.copyWith(color: AppColors.onLightFaint)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(formatCurrency(mom.currentSpend), style: AppTypography.heroAmount34.copyWith(color: AppColors.onLight)),
                  const SizedBox(width: 10),
                  DeltaChip(
                    label: '${mom.isUp ? '▲' : '▼'} ${deltaPercent.abs().round()}%',
                    up: mom.isUp,
                    tint: (mom.isUp ? AppColors.rose : AppColors.accent).withValues(alpha: 0.16),
                    foreground: mom.isUp ? AppColors.rose : AppColors.accent,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('vs ${formatCurrency(mom.previousSpend)} last period', style: AppTypography.footnote12.copyWith(color: AppColors.onLightMuted)),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryPatternsSection extends ConsumerWidget {
  const _CategoryPatternsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patternsAsync = ref.watch(categoryPatternsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(label: 'CATEGORY PATTERNS (30D)', labelColor: AppColors.onLightFaint),
        const SizedBox(height: 4),
        patternsAsync.when(
          loading: () => Column(
            children: [
              for (var i = 0; i < 3; i++) ...[
                const SkeletonBox(width: double.infinity, height: 34),
                if (i != 2) const SizedBox(height: 12),
              ],
            ],
          ),
          error: (e, _) => ErrorRetry(message: 'Could not load category patterns.', onRetry: () => ref.invalidate(categoryPatternsProvider)),
          data: (entries) {
            if (entries.isEmpty) {
              return const EmptyState(icon: Icons.donut_small_outlined, title: 'No category patterns yet');
            }
            final sorted = [...entries]..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
            final maxAmount = sorted.first.totalAmount == 0 ? 1 : sorted.first.totalAmount;
            final total = sorted.fold<double>(0, (sum, e) => sum + e.totalAmount);
            return Column(
              children: [
                for (final entry in sorted)
                  CategoryBarRow(
                    name: entry.category,
                    amountLabel: formatCurrency(entry.totalAmount),
                    percentOfTotal: total == 0 ? 0 : (entry.totalAmount / total * 100).round(),
                    relativeWidthFraction: entry.totalAmount / maxAmount,
                    color: AppColors.forCategory(entry.category),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MerchantPatternsSection extends ConsumerWidget {
  const _MerchantPatternsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchantsAsync = ref.watch(merchantPatternsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(label: 'TOP MERCHANTS', labelColor: AppColors.onLightFaint),
        const SizedBox(height: 12),
        merchantsAsync.when(
          loading: () => const SkeletonBox(width: double.infinity, height: 140, radius: 16),
          error: (e, _) => ErrorRetry(message: 'Could not load top merchants.', onRetry: () => ref.invalidate(merchantPatternsProvider)),
          data: (entries) {
            if (entries.isEmpty) {
              return const EmptyState(icon: Icons.storefront_outlined, title: 'No merchant patterns yet');
            }
            return Container(
              decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.hairlineLight), borderRadius: BorderRadius.circular(AppRadius.card)),
              child: Column(
                children: [
                  for (var i = 0; i < entries.length; i++) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        children: [
                          AvatarChip(
                            initials: (entries[i].merchant?.isNotEmpty == true) ? entries[i].merchant![0].toUpperCase() : '?',
                            size: 36,
                            radius: 11,
                            backgroundColor: AppColors.accentTint,
                            foregroundColor: AppColors.accentInk,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(entries[i].merchant ?? 'Unknown', style: AppTypography.rowLabel14.copyWith(color: AppColors.onLight)),
                                Text('${entries[i].visits} visit${entries[i].visits == 1 ? '' : 's'}', style: AppTypography.meta115.copyWith(color: AppColors.onLightFaint)),
                              ],
                            ),
                          ),
                          Text(formatCurrency(entries[i].spent), style: AppTypography.amountMedium14.copyWith(color: AppColors.onLight)),
                        ],
                      ),
                    ),
                    if (i != entries.length - 1) Divider(height: 1, color: AppColors.hairlineLight, indent: 62),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SubscriptionsSection extends ConsumerWidget {
  const _SubscriptionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subsAsync = ref.watch(subscriptionsSummaryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        subsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
          data: (summary) => SectionHeader(
            label: 'SUBSCRIPTIONS',
            labelColor: AppColors.onLightFaint,
            trailing: Text('${formatCurrency(summary.totalMonthlyBurn)}/mo', style: AppTypography.body14.copyWith(fontSize: 12, color: AppColors.onLightFaint)),
          ),
        ),
        const SizedBox(height: 12),
        subsAsync.when(
          loading: () => const SkeletonBox(width: double.infinity, height: 96, radius: 16),
          error: (e, _) => ErrorRetry(message: 'Could not load subscriptions.', onRetry: () => ref.invalidate(subscriptionsSummaryProvider)),
          data: (summary) {
            if (summary.details.isEmpty) {
              return const EmptyState(icon: Icons.autorenew_rounded, title: 'No recurring subscriptions detected');
            }
            return Container(
              decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.hairlineLight), borderRadius: BorderRadius.circular(AppRadius.card)),
              child: Column(
                children: [
                  for (var i = 0; i < summary.details.length; i++) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(summary.details[i].merchant, style: AppTypography.rowLabel14.copyWith(color: AppColors.onLight)),
                                if (summary.details[i].lastBilled != null)
                                  Text('Last billed ${DateFormat('d MMM').format(summary.details[i].lastBilled!)}', style: AppTypography.meta115.copyWith(color: AppColors.onLightFaint)),
                              ],
                            ),
                          ),
                          Text('${formatCurrency(summary.details[i].estimatedMonthlyCost)}/mo', style: AppTypography.amountMedium14.copyWith(color: AppColors.onLight)),
                        ],
                      ),
                    ),
                    if (i != summary.details.length - 1) Divider(height: 1, color: AppColors.hairlineLight, indent: 14),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
