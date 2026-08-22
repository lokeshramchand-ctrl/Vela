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
import '../../../shared/widgets/skeleton.dart';
import 'controller_controller.dart';

class ExceptionsListScreen extends ConsumerWidget {
  const ExceptionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controllerState = ref.watch(controllerProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        title: const Text('Review Exceptions'),
        titleTextStyle: AppTypography.title3.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: controllerState.isLoading
        ? const _ExceptionsSkeleton()
        : controllerState.error != null
          ? ErrorRetry(
            onRetry: () => ref.read(controllerProvider.notifier).refresh(),
          )
          : controllerState.exceptions.isEmpty
            ? EmptyState(
              icon: Icons.check_circle_outline,
              title: 'No exceptions',
              subtitle: 'All transactions have been resolved',
            )
            : ListView.builder(
              padding: EdgeInsets.all(AppSpacing.lg),
              itemCount: controllerState.exceptions.length,
              itemBuilder: (context, index) {
                final exception = controllerState.exceptions[index];
                return _ExceptionListItem(
                  exception: exception,
                  onTap: () {
                    context.push(
                      '/controller/exceptions/${exception.id}',
                      extra: exception,
                    );
                  },
                );
              },
            ),
    );
  }
}

class _ExceptionListItem extends StatelessWidget {
  final dynamic exception;
  final VoidCallback onTap;

  const _ExceptionListItem({
    required this.exception,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.md,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: AppRadius.md,
              border: Border.all(color: AppColors.divider, width: 1),
            ),
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exception.sourceAMerchant,
                            style: AppTypography.body1.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: AppSpacing.xs),
                          Text(
                            exception.sourceBMerchant,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.accentOrange.withOpacity(0.1),
                        borderRadius: AppRadius.sm,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      child: Text(
                        '${(exception.confidence * 100).toStringAsFixed(0)}%',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.accentOrange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Amount mismatch',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: AppSpacing.xs),
                          Text(
                            '${Formatters.formatCurrency(exception.sourceAAmount)} vs ${Formatters.formatCurrency(exception.sourceBAmount)}',
                            style: AppTypography.body2.copyWith(
                              color: AppColors.accentRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExceptionsSkeleton extends StatelessWidget {
  const _ExceptionsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.all(AppSpacing.lg),
      itemCount: 5,
      itemBuilder: (_) => Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.md),
        child: Skeleton(
          height: 100,
          borderRadius: AppRadius.md,
        ),
      ),
    );
  }
}
