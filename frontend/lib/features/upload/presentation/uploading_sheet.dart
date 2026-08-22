// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/bottom_sheet_scaffold.dart';
import '../../../shared/widgets/sweep_progress_bar.dart';
import 'upload_controller.dart';
import 'upload_state.dart';

/// Opens the file picker and shows the Uploading sheet, then routes to
/// Analysing/Rejected as the upload resolves. Call from the Onboarding CTA
/// or the Period switcher's "Add a statement" row.
Future<void> startUploadFlow(BuildContext context, WidgetRef ref) async {
  ref.read(uploadControllerProvider.notifier).reset();
  await showVelaSheet<void>(
    context,
    dark: true,
    child: const _UploadingSheetBody(),
  );
}

class _UploadingSheetBody extends ConsumerStatefulWidget {
  const _UploadingSheetBody();

  @override
  ConsumerState<_UploadingSheetBody> createState() => _UploadingSheetBodyState();
}

class _UploadingSheetBodyState extends ConsumerState<_UploadingSheetBody> {
  bool _pickStarted = false;
  final _passwordController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_pickStarted) {
      _pickStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
    }
  }

  Future<void> _pick() async {
    await ref.read(uploadControllerProvider.notifier).pickAndUpload();
    final state = ref.read(uploadControllerProvider);
    if (!mounted) return;
    if (state.stage == UploadStage.idle) {
      // User dismissed the native file picker without choosing a file.
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(uploadControllerProvider);
    final controller = ref.read(uploadControllerProvider.notifier);

    ref.listen(uploadControllerProvider, (previous, next) {
      if (next.stage == UploadStage.recognized && previous?.stage != UploadStage.recognized) {
        Future.delayed(const Duration(milliseconds: 700), () {
          if (!mounted) return;
          Navigator.of(context).pop();
          context.push('/upload/analysing/${next.jobId}');
        });
      } else if (next.stage == UploadStage.rejected && !controller.looksLikePasswordIssue) {
        Navigator.of(context).pop();
        context.push('/upload/rejected', extra: next.errorMessage);
      }
    });

    if (state.stage == UploadStage.idle) {
      return SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
      );
    }

    final sizeLabel = state.fileSizeBytes == null ? '' : '${(state.fileSizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.ink700, border: Border.all(color: AppColors.hairlineDark), borderRadius: BorderRadius.circular(AppRadius.field)),
              child: Text('PDF', style: AppTypography.badge10.copyWith(color: AppColors.onDarkMuted)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.fileName ?? '', style: AppTypography.rowLabel14.copyWith(color: AppColors.onDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(sizeLabel, style: AppTypography.meta115.copyWith(color: AppColors.onDarkFaint)),
                ],
              ),
            ),
            if (state.stage == UploadStage.uploading)
              IconButton(
                tooltip: 'Cancel upload',
                icon: Icon(Icons.close_rounded, color: AppColors.onDarkFaint, size: 18),
                onPressed: () {
                  controller.cancel();
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (state.stage == UploadStage.uploading) ...[
          SweepProgressBar(percent: state.progressPercent),
          const SizedBox(height: 8),
          Text(
            'UPLOADING · ${state.progressPercent.round()}%',
            style: AppTypography.meta115.copyWith(color: AppColors.onDarkMuted),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(border: Border.all(color: AppColors.hairlineDark), borderRadius: BorderRadius.circular(14)),
            child: Text(
              "Encrypted PDF? We'll ask for the password before parsing - it is never stored.",
              style: AppTypography.footnote12.copyWith(color: AppColors.onDarkMuted),
            ),
          ),
          const SizedBox(height: 18),
          SecondaryPillButton(
            label: 'Cancel upload',
            foreground: AppColors.onDarkMuted,
            borderColor: AppColors.hairlineDark,
            onPressed: () {
              controller.cancel();
              Navigator.of(context).pop();
            },
          ),
        ] else if (state.stage == UploadStage.recognized) ...[
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: AppColors.ink800, border: Border.all(color: AppColors.hairlineDark), borderRadius: BorderRadius.circular(16)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Recognised as a Google Pay statement', style: AppTypography.rowLabel14.copyWith(color: AppColors.onDark)),
                      if (state.statement != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _summaryLine(state),
                          style: AppTypography.meta115.copyWith(color: AppColors.onDarkMuted),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else if (state.stage == UploadStage.rejected && controller.looksLikePasswordIssue) ...[
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: AppColors.amberTint, borderRadius: BorderRadius.circular(14)),
            child: Text(
              state.errorMessage ?? 'This PDF needs a password.',
              style: AppTypography.footnote12.copyWith(color: AppColors.amberTextOnTint),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passwordController,
            obscureText: true,
            style: AppTypography.body14.copyWith(color: AppColors.onDark),
            decoration: InputDecoration(
              hintText: 'PDF password',
              hintStyle: AppTypography.body14.copyWith(color: AppColors.onDarkFaint),
              filled: true,
              fillColor: AppColors.ink800,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 14),
          PrimaryPillButton(
            label: 'Try again',
            onPressed: () => controller.retryWithPassword(_passwordController.text),
          ),
        ],
      ],
    );
  }

  String _summaryLine(UploadState state) {
    final statement = state.statement;
    if (statement == null) return '';
    final start = statement.periodStart;
    final end = statement.periodEnd;
    final period = '${monthAbbr(start.month)} ${start.day} - ${monthAbbr(end.month)} ${end.day} ${end.year}';
    final sent = statement.declaredSentAmount;
    final received = statement.declaredReceivedAmount;
    final parts = <String>['PERIOD $period'];
    if (sent != null) parts.add('SENT ₹${sent.toStringAsFixed(0)}');
    if (received != null) parts.add('RECEIVED ₹${received.toStringAsFixed(0)}');
    return parts.join(' · ');
  }
}
