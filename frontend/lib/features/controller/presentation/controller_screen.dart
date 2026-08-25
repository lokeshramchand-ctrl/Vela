import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../shared/widgets/skeleton.dart';
import '../domain/cash_position.dart';
import 'controller_controller.dart';

class ControllerScreen extends ConsumerWidget {
  const ControllerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controllerState = ref.watch(controllerProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        title: const Text('VELA FINANCE CONTROLLER'),
        titleTextStyle: AppTypography.navTitle15.copyWith(
          color: AppColors.onLight,
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            color: AppColors.onLight,
            onPressed: () {
              ref.read(controllerProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: controllerState.isLoading
        ? const _ControllerSkeleton()
        : controllerState.error != null
          ? ErrorRetry(
            onRetry: () => ref.read(controllerProvider.notifier).refresh(),
          )
          : SingleChildScrollView(
            padding: EdgeInsets.all(AppSpacing.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatsGrid(stats: controllerState.stats),
                SizedBox(height: AppSpacing.lg),
                _CashPositionSection(
                  cashPosition: controllerState.cashPosition,
                  onView: () {
                    context.push('/controller/cash-position');
                  },
                ),
                SizedBox(height: AppSpacing.lg),
                _ExceptionSection(
                  exceptions: controllerState.exceptions,
                  onReview: () {
                    context.push('/controller/exceptions');
                  },
                ),
              ],
            ),
          ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final dynamic stats;

  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.6,
          children: [
            _StatCard(
              label: 'Records processed',
              value: stats.recordsProcessed.toString(),
              color: AppColors.accentDim,
            ),
            _StatCard(
              label: 'Matched',
              value: stats.matched.toString(),
              color: AppColors.accentDim,
            ),
            _StatCard(
              label: 'Exceptions',
              value: stats.exceptions.toString(),
              color: AppColors.amberInk,
            ),
            _StatCard(
              label: 'Unresolved',
              value: stats.unresolved.toString(),
              color: AppColors.roseInk,
            ),
          ],
        ),
        SizedBox(height: AppSpacing.lg),
        _MetricCard(
          label: 'Match rate',
          value: '${(stats.matchRate * 100).toStringAsFixed(1)}%',
        ),
        SizedBox(height: AppSpacing.md),
        _MetricCard(
          label: 'Amount reconciled',
          value: formatCurrency(stats.amountReconciled),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.hairlineLight, width: 1),
      ),
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.footnote12.copyWith(
              color: AppColors.onLightMuted,
            ),
          ),
          Text(
            value,
            style: AppTypography.bigHeadline26.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.hairlineLight, width: 1),
      ),
      padding: EdgeInsets.all(AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.cardBody15.copyWith(
              color: AppColors.onLightMuted,
            ),
          ),
          Text(
            value,
            style: AppTypography.amountMedium19.copyWith(
              color: AppColors.onLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _CashPositionSection extends StatelessWidget {
  final CashPosition? cashPosition;
  final VoidCallback onView;

  const _CashPositionSection({
    required this.cashPosition,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final cashPosition = this.cashPosition;
    if (cashPosition == null) return const SizedBox.shrink();

    final isBalanced = cashPosition.isBalanced;
    final varianceColor = isBalanced ? AppColors.accentDim : AppColors.roseInk;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.hairlineLight, width: 1),
          ),
          padding: EdgeInsets.all(AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cash position',
                    style: AppTypography.footnote12.copyWith(
                      color: AppColors.onLightMuted,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    isBalanced ? 'Books balance' : 'Variance ${formatCurrency(cashPosition.variance, forceSign: true)}',
                    style: AppTypography.amountMedium19.copyWith(
                      color: varianceColor,
                    ),
                  ),
                ],
              ),
              Icon(Icons.chevron_right, color: AppColors.onLightMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExceptionSection extends StatelessWidget {
  final List<dynamic> exceptions;
  final VoidCallback onReview;

  const _ExceptionSection({
    required this.exceptions,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Exceptions',
          style: AppTypography.bigHeadline22.copyWith(
            color: AppColors.onLight,
          ),
        ),
        SizedBox(height: AppSpacing.md),
        if (exceptions.isEmpty)
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.hairlineLight, width: 1),
            ),
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: Text(
                'No exceptions to review',
                style: AppTypography.cardBody15.copyWith(
                  color: AppColors.onLightMuted,
                ),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.amberTint,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: AppColors.amber.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            padding: EdgeInsets.all(AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${exceptions.length} exceptions pending',
                        style: AppTypography.rowLabel145.copyWith(
                          color: AppColors.onLight,
                        ),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        'Review and resolve transaction mismatches',
                        style: AppTypography.footnote12.copyWith(
                          color: AppColors.onLightMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                PrimaryPillButton(
                  label: 'Review',
                  expand: false,
                  onPressed: onReview,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ControllerSkeleton extends StatelessWidget {
  const _ControllerSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.6,
            children: List.generate(
              4,
              (_) => SkeletonBox(width: double.infinity, height: 100, radius: AppRadius.card),
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          SkeletonBox(width: double.infinity, height: 64, radius: AppRadius.card),
          SizedBox(height: AppSpacing.md),
          SkeletonBox(width: double.infinity, height: 64, radius: AppRadius.card),
        ],
      ),
    );
  }
}
