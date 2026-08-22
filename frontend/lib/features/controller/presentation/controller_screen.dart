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
        titleTextStyle: AppTypography.title3.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
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
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatsGrid(stats: controllerState.stats),
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
          children: [
            _StatCard(
              label: 'Records processed',
              value: stats.recordsProcessed.toString(),
              color: AppColors.brandPrimary,
            ),
            _StatCard(
              label: 'Matched',
              value: stats.matched.toString(),
              color: AppColors.accentGreen,
            ),
            _StatCard(
              label: 'Exceptions',
              value: stats.exceptions.toString(),
              color: AppColors.accentOrange,
            ),
            _StatCard(
              label: 'Unresolved',
              value: stats.unresolved.toString(),
              color: AppColors.accentRed,
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
          value: Formatters.formatCurrency(stats.amountReconciled),
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
        color: AppColors.cardBackground,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTypography.headline2.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
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
        color: AppColors.cardBackground,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      padding: EdgeInsets.all(AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.body2.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTypography.title3.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
          style: AppTypography.title2.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: AppSpacing.md),
        if (exceptions.isEmpty)
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: AppRadius.md,
              border: Border.all(color: AppColors.divider, width: 1),
            ),
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: Text(
                'No exceptions to review',
                style: AppTypography.body2.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          )
        else
          Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.accentOrange.withOpacity(0.05),
                  borderRadius: AppRadius.md,
                  border: Border.all(
                    color: AppColors.accentOrange.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                padding: EdgeInsets.all(AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${exceptions.length} exceptions pending',
                          style: AppTypography.body1.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: AppSpacing.xs),
                        Text(
                          'Review and resolve transaction mismatches',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    AppButton.primary(
                      onPressed: onReview,
                      child: const Text('Review'),
                    ),
                  ],
                ),
              ),
            ],
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
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            children: List.generate(
              4,
              (_) => Skeleton(
                height: 120,
                borderRadius: AppRadius.md,
              ),
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          Skeleton(
            height: 80,
            borderRadius: AppRadius.md,
          ),
          SizedBox(height: AppSpacing.md),
          Skeleton(
            height: 80,
            borderRadius: AppRadius.md,
          ),
        ],
      ),
    );
  }
}
