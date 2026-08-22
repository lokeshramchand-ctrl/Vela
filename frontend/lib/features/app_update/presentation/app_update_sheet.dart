// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/bottom_sheet_scaffold.dart';
import '../../../shared/widgets/sweep_progress_bar.dart';
import 'app_update_controller.dart';
import 'app_update_state.dart';

/// Shown once from AppShell when a launch-time check finds a newer release
/// than the one installed. Self-hosted equivalent of a Play Store update
/// prompt - see routers/app_updates.py.
Future<void> showAppUpdateSheet(BuildContext context) {
  return showVelaSheet<void>(context, dark: true, isScrollControlled: false, child: const _AppUpdateSheetBody());
}

class _AppUpdateSheetBody extends ConsumerWidget {
  const _AppUpdateSheetBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appUpdateControllerProvider);
    final controller = ref.read(appUpdateControllerProvider.notifier);
    final info = state.info;

    ref.listen(appUpdateControllerProvider, (previous, next) {
      // installApk() launches Android's own installer on top of the app -
      // once that hand-off has happened there's nothing left for this sheet
      // to show, so close it instead of leaving a stale "ready" sheet behind
      // the system install prompt.
      if (next.stage == AppUpdateStage.readyToInstall && previous?.stage != AppUpdateStage.readyToInstall) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        });
      }
    });

    if (info == null) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.ink700, border: Border.all(color: AppColors.hairlineDark), borderRadius: BorderRadius.circular(AppRadius.field)),
              child: Icon(Icons.system_update_alt_rounded, color: AppColors.accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Update available', style: AppTypography.rowLabel14.copyWith(color: AppColors.onDark, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text('Version ${info.versionName}', style: AppTypography.meta115.copyWith(color: AppColors.onDarkFaint)),
                ],
              ),
            ),
          ],
        ),
        if (info.releaseNotes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(color: AppColors.ink800, border: Border.all(color: AppColors.hairlineDark), borderRadius: BorderRadius.circular(14)),
            child: Text(info.releaseNotes, style: AppTypography.footnote12.copyWith(color: AppColors.onDarkMuted, height: 1.5)),
          ),
        ],
        const SizedBox(height: 20),
        if (state.stage == AppUpdateStage.downloading) ...[
          SweepProgressBar(percent: state.progressPercent),
          const SizedBox(height: 8),
          Text('DOWNLOADING · ${state.progressPercent.round()}%', style: AppTypography.meta115.copyWith(color: AppColors.onDarkMuted)),
          const SizedBox(height: 18),
          SecondaryPillButton(
            label: 'Cancel',
            foreground: AppColors.onDarkMuted,
            borderColor: AppColors.hairlineDark,
            onPressed: controller.cancelDownload,
          ),
        ] else if (state.stage == AppUpdateStage.readyToInstall) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
              const SizedBox(width: 10),
              Text('Opening installer…', style: AppTypography.footnote12.copyWith(color: AppColors.onDarkMuted)),
            ],
          ),
        ] else ...[
          if (state.stage == AppUpdateStage.error && state.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              decoration: BoxDecoration(color: AppColors.amberTint, borderRadius: BorderRadius.circular(14)),
              child: Text(state.errorMessage!, style: AppTypography.footnote12.copyWith(color: AppColors.amberTextOnTint)),
            ),
            const SizedBox(height: 14),
          ],
          PrimaryPillButton(label: 'Update now', onPressed: controller.downloadAndInstall),
          const SizedBox(height: 10),
          SecondaryPillButton(
            label: 'Later',
            foreground: AppColors.onDarkMuted,
            borderColor: AppColors.hairlineDark,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ],
    );
  }
}
