import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/bottom_sheet_scaffold.dart';
import '../../../shared/widgets/pulsing_dot.dart';
import '../../statements/domain/statement.dart';
import '../../statements/presentation/period_providers.dart';
import '../../upload/presentation/uploading_sheet.dart';

Future<void> showPeriodSwitcher(BuildContext context, WidgetRef ref) {
  return showVelaSheet<void>(context, dark: true, child: const _PeriodSwitcherBody());
}

class _PeriodSwitcherBody extends ConsumerWidget {
  const _PeriodSwitcherBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodsAsync = ref.watch(periodsProvider);
    final current = ref.watch(currentPeriodProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose a period', style: AppTypography.bigHeadline26.copyWith(fontSize: 20, color: AppColors.onDark)),
        const SizedBox(height: 6),
        Text("Each period is one Google Pay statement you've added.", style: AppTypography.body13.copyWith(color: AppColors.onDarkMuted, height: 1.4)),
        const SizedBox(height: 18),
        periodsAsync.when(
          loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('Could not load periods.', style: AppTypography.footnote12.copyWith(color: AppColors.rose)),
          data: (periods) => Column(
            children: [
              for (final period in periods)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PeriodRow(period: period, selected: current?.id == period.id),
                ),
            ],
          ),
        ),
        InkWell(
          onTap: () {
            Navigator.of(context).pop();
            startUploadFlow(context, ref);
          },
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(border: Border.all(color: AppColors.hairlineDark), borderRadius: BorderRadius.circular(AppRadius.card)),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(11)),
                  child: Text('+', style: AppTypography.amountMedium19.copyWith(color: AppColors.accentInk)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Add a statement', style: AppTypography.rowLabel14.copyWith(color: AppColors.onDark)),
                    Text('Google Pay → Transaction statement → PDF', style: AppTypography.footnote12.copyWith(color: AppColors.onDarkMuted)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Periods never overlap twice - re-uploading the same statement updates it in place.',
          textAlign: TextAlign.center,
          style: AppTypography.microLabel11.copyWith(color: AppColors.onDarkFaint, height: 1.5),
        ),
      ],
    );
  }
}

class _PeriodRow extends ConsumerWidget {
  const _PeriodRow({required this.period, required this.selected});

  final Statement period;
  final bool selected;

  bool get _isLive => period.processingStatus == ProcessingStatus.pending || period.processingStatus == ProcessingStatus.processing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () {
        if (_isLive) {
          Navigator.of(context).pop();
          if (period.currentJobId != null) context.push('/upload/analysing/${period.currentJobId}');
          return;
        }
        ref.read(selectedPeriodIdProvider.notifier).state = period.id;
        Navigator.of(context).pop();
      },
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink700 : AppColors.ink800,
          border: Border.all(color: selected ? AppColors.accent : AppColors.hairlineDark),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(formatPeriodRange(period.periodStart, period.periodEnd), style: AppTypography.rowLabel145.copyWith(color: AppColors.onDark)),
                  const SizedBox(height: 4),
                  if (_isLive)
                    _LiveProgressLabel(jobId: period.currentJobId)
                  else
                    Text(
                      '${period.transactionCount} txns · ${formatCurrency(period.computedSentAmount ?? period.declaredSentAmount ?? 0)} out',
                      style: AppTypography.meta115.copyWith(color: AppColors.onDarkMuted),
                    ),
                ],
              ),
            ),
            if (selected)
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                child: Icon(Icons.check_rounded, size: 13, color: AppColors.accentInk),
              )
            else
              Icon(Icons.chevron_right_rounded, color: AppColors.onDarkFaint),
          ],
        ),
      ),
    );
  }
}

class _LiveProgressLabel extends ConsumerWidget {
  const _LiveProgressLabel({required this.jobId});
  final String? jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (jobId == null) {
      return Text('ANALYSING', style: AppTypography.meta115.copyWith(color: AppColors.amber));
    }
    final percent = ref.watch(jobSnapshotProvider(jobId!)).valueOrNull?.progressPercent;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PulsingDot(color: AppColors.amber, size: 5),
        const SizedBox(width: 6),
        Text(
          percent == null ? 'ANALYSING' : 'ANALYSING · $percent%',
          style: AppTypography.meta115.copyWith(color: AppColors.amber),
        ),
      ],
    );
  }
}
