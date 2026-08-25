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
import '../domain/cash_position.dart';
import 'controller_controller.dart';

class CashPositionScreen extends ConsumerWidget {
  const CashPositionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controllerState = ref.watch(controllerProvider);
    final cashPosition = controllerState.cashPosition;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        title: const Text('CASH POSITION'),
        titleTextStyle: AppTypography.navTitle15.copyWith(
          color: AppColors.onLight,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            color: AppColors.onLight,
            onPressed: () => ref.read(controllerProvider.notifier).fetchCashPosition(),
          ),
        ],
      ),
      body: controllerState.isLoading && cashPosition == null
        ? const _CashPositionSkeleton()
        : controllerState.error != null && cashPosition == null
          ? ErrorRetry(
            onRetry: () => ref.read(controllerProvider.notifier).fetchCashPosition(),
          )
          : cashPosition == null
            ? const SizedBox.shrink()
            : SingleChildScrollView(
              padding: EdgeInsets.all(AppSpacing.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BuildUpCard(cashPosition: cashPosition),
                  SizedBox(height: AppSpacing.lg),
                  _VarianceCard(cashPosition: cashPosition),
                  SizedBox(height: AppSpacing.lg),
                  _ContributingSection(cashPosition: cashPosition),
                ],
              ),
            ),
    );
  }
}

class _BuildUpCard extends StatelessWidget {
  final CashPosition cashPosition;

  const _BuildUpCard({required this.cashPosition});

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
        children: [
          Text(
            'Expected closing balance',
            style: AppTypography.footnote12.copyWith(
              color: AppColors.onLightMuted,
            ),
          ),
          SizedBox(height: AppSpacing.md),
          _LedgerRow(label: 'Opening balance', value: cashPosition.openingBalance),
          SizedBox(height: AppSpacing.sm),
          _LedgerRow(label: 'Verified inflows', value: cashPosition.verifiedInflows, sign: '+', color: AppColors.accentDim),
          SizedBox(height: AppSpacing.sm),
          _LedgerRow(label: 'Verified outflows', value: cashPosition.verifiedOutflows, sign: '−', color: AppColors.roseInk),
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Divider(color: AppColors.hairlineLight, height: 1),
          ),
          _LedgerRow(
            label: 'Expected closing balance',
            value: cashPosition.expectedClosingBalance,
            bold: true,
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  final String label;
  final double value;
  final String? sign;
  final Color? color;
  final bool bold;

  const _LedgerRow({
    required this.label,
    required this.value,
    this.sign,
    this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: (bold ? AppTypography.rowLabel145 : AppTypography.cardBody15).copyWith(
            color: AppColors.onLight,
          ),
        ),
        Text(
          '${sign ?? ''}${formatCurrency(value)}',
          style: (bold ? AppTypography.amountMedium19 : AppTypography.cardBody15).copyWith(
            color: color ?? AppColors.onLight,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _VarianceCard extends StatelessWidget {
  final CashPosition cashPosition;

  const _VarianceCard({required this.cashPosition});

  @override
  Widget build(BuildContext context) {
    final isBalanced = cashPosition.isBalanced;
    final varianceColor = isBalanced ? AppColors.accentDim : AppColors.roseInk;
    final tintColor = isBalanced ? AppColors.accentTint : AppColors.roseTint;

    return Container(
      decoration: BoxDecoration(
        color: tintColor,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: varianceColor.withValues(alpha: 0.3), width: 1),
      ),
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LedgerRow(label: 'Reported closing balance', value: cashPosition.reportedClosingBalance),
          SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Variance',
                style: AppTypography.rowLabel145.copyWith(
                  color: AppColors.onLight,
                ),
              ),
              Text(
                formatCurrency(cashPosition.variance, forceSign: true),
                style: AppTypography.bigHeadline26.copyWith(
                  color: varianceColor,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            isBalanced
              ? 'Books balance. No variance to explain.'
              : 'Books do not balance. See exceptions below for likely causes.',
            style: AppTypography.footnote12.copyWith(color: AppColors.onLightMuted),
          ),
        ],
      ),
    );
  }
}

class _ContributingSection extends StatelessWidget {
  final CashPosition cashPosition;

  const _ContributingSection({required this.cashPosition});

  @override
  Widget build(BuildContext context) {
    final exceptions = cashPosition.contributingExceptions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contributing exceptions',
          style: AppTypography.bigHeadline22.copyWith(
            color: AppColors.onLight,
          ),
        ),
        SizedBox(height: AppSpacing.md),
        if (exceptions.isEmpty)
          EmptyState(
            icon: Icons.check_circle_outline,
            title: 'Nothing to explain',
            subtitle: 'No open exceptions could account for this variance',
          )
        else
          Column(
            children: exceptions.map((exception) {
              final delta = exception.sourceBAmount - exception.sourceAAmount;
              return Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.push(
                      '/controller/exceptions/${exception.id}',
                      extra: exception,
                    ),
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${exception.sourceAMerchant} vs ${exception.sourceBMerchant}',
                                  style: AppTypography.rowLabel145.copyWith(
                                    color: AppColors.onLight,
                                  ),
                                ),
                                SizedBox(height: AppSpacing.xs),
                                Text(
                                  exception.issue,
                                  style: AppTypography.footnote12.copyWith(color: AppColors.onLightMuted),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            formatCurrency(delta, forceSign: true),
                            style: AppTypography.rowLabel145.copyWith(
                              color: delta == 0 ? AppColors.onLightMuted : AppColors.amberInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _CashPositionSkeleton extends StatelessWidget {
  const _CashPositionSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: double.infinity, height: 180, radius: AppRadius.card),
          SizedBox(height: AppSpacing.lg),
          SkeletonBox(width: double.infinity, height: 120, radius: AppRadius.card),
          SizedBox(height: AppSpacing.lg),
          SkeletonBox(width: double.infinity, height: 100, radius: AppRadius.card),
        ],
      ),
    );
  }
}
