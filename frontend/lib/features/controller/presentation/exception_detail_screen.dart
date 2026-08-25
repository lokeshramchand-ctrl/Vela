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
        titleTextStyle: AppTypography.navTitle15.copyWith(
          color: AppColors.onLight,
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.gutter),
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
                if (context.mounted) {
                  context.pop();
                }
              },
              onKeepException: () async {
                setState(() => _isResolving = true);
                await ref.read(controllerProvider.notifier)
                  .resolveException(widget.exception.id, false);
                if (context.mounted) {
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
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.hairlineLight, width: 1),
      ),
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            source,
            style: AppTypography.footnote12.copyWith(
              color: AppColors.onLightMuted,
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
                    style: AppTypography.rowLabel145.copyWith(
                      color: AppColors.onLight,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    formatDate(date),
                    style: AppTypography.footnote12.copyWith(
                      color: AppColors.onLightMuted,
                    ),
                  ),
                ],
              ),
              Text(
                formatCurrency(amount),
                style: AppTypography.amountMedium19.copyWith(
                  color: AppColors.onLight,
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
              style: AppTypography.footnote12.copyWith(
                color: AppColors.onLightMuted,
              ),
            ),
            SizedBox(height: AppSpacing.xs),
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.hairlineLight, width: 1),
              ),
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text(
                reason,
                style: AppTypography.cardBody15.copyWith(
                  color: AppColors.onLight,
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
          style: AppTypography.footnote12.copyWith(
            color: AppColors.onLightMuted,
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            value,
            style: AppTypography.cardBody15.copyWith(
              color: AppColors.onLight,
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
      spacing: AppSpacing.md,
      children: [
        Expanded(
          child: SecondaryPillButton(
            label: 'Keep Exception',
            foreground: AppColors.onLight,
            borderColor: AppColors.hairlineLight,
            onPressed: isResolving ? null : onKeepException,
          ),
        ),
        Expanded(
          child: PrimaryPillButton(
            label: 'Resolve',
            loading: isResolving,
            onPressed: isResolving ? null : onResolve,
          ),
        ),
      ],
    );
  }
}
