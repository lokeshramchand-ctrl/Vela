import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../domain/exception.dart';
import 'controller_controller.dart';

class ExceptionDetailScreen extends ConsumerStatefulWidget {
  final TransactionException exception;

  const ExceptionDetailScreen({
    super.key,
    required this.exception,
  });

  @override
  ConsumerState<ExceptionDetailScreen> createState() => _ExceptionDetailScreenState();
}

class _ExceptionDetailScreenState extends ConsumerState<ExceptionDetailScreen> {
  bool _isResolving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        title: const Text('EXCEPTION'),
        titleTextStyle: AppTypography.title3.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SourceCard(
              source: 'Source A',
              merchant: widget.exception.sourceAMerchant,
              amount: widget.exception.sourceAAmount,
              date: widget.exception.sourceADate,
            ),
            SizedBox(height: AppSpacing.md),
            _SourceCard(
              source: 'Source B',
              merchant: widget.exception.sourceBMerchant,
              amount: widget.exception.sourceBAmount,
              date: widget.exception.sourceBDate,
            ),
            SizedBox(height: AppSpacing.lg),
            _IssueSection(
              issue: widget.exception.issue,
              confidence: widget.exception.confidence,
              reason: widget.exception.reason,
            ),
            SizedBox(height: AppSpacing.lg),
            _ActionButtons(
              isResolving: _isResolving,
              onResolve: () async {
                setState(() => _isResolving = true);
                await ref.read(controllerProvider.notifier)
                  .resolveException(widget.exception.id, true);
                if (mounted) {
                  context.pop();
                }
              },
              onKeepException: () async {
                setState(() => _isResolving = true);
                await ref.read(controllerProvider.notifier)
                  .resolveException(widget.exception.id, false);
                if (mounted) {
                  context.pop();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  final String source;
  final String merchant;
  final double amount;
  final DateTime date;

  const _SourceCard({
    required this.source,
    required this.merchant,
    required this.amount,
    required this.date,
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
        children: [
          Text(
            source,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    merchant,
                    style: AppTypography.body1.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    Formatters.formatDate(date),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Text(
                Formatters.formatCurrency(amount),
                style: AppTypography.title3.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IssueSection extends StatelessWidget {
  final String issue;
  final double confidence;
  final String reason;

  const _IssueSection({
    required this.issue,
    required this.confidence,
    required this.reason,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(
          label: 'Issue:',
          value: issue,
        ),
        SizedBox(height: AppSpacing.md),
        _InfoRow(
          label: 'Confidence:',
          value: '${(confidence * 100).toStringAsFixed(0)}%',
        ),
        SizedBox(height: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reason:',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: AppSpacing.xs),
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: AppRadius.md,
                border: Border.all(color: AppColors.divider, width: 1),
              ),
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text(
                reason,
                style: AppTypography.body2.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            value,
            style: AppTypography.body2.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final bool isResolving;
  final VoidCallback onResolve;
  final VoidCallback onKeepException;

  const _ActionButtons({
    required this.isResolving,
    required this.onResolve,
    required this.onKeepException,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      gap: AppSpacing.md,
      children: [
        Expanded(
          child: AppButton.secondary(
            onPressed: isResolving ? null : onKeepException,
            child: const Text('Keep Exception'),
          ),
        ),
        Expanded(
          child: AppButton.primary(
            onPressed: isResolving ? null : onResolve,
            child: isResolving
              ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.accentGreen),
                ),
              )
              : const Text('Resolve'),
          ),
        ),
      ],
    );
  }
}
