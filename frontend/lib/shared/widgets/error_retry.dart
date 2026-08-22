import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'app_buttons.dart';

/// Centered error message + Retry CTA, used wherever an AsyncValue.error is
/// rendered so a failed load is always recoverable without a full app reload.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.onRetry, this.message, this.dark = false});

  final VoidCallback onRetry;
  final String? message;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final onSurfaceMuted = dark ? AppColors.onDarkMuted : AppColors.onLightMuted;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 28, color: onSurfaceMuted),
            const SizedBox(height: 12),
            Text(message ?? 'Something went wrong.', textAlign: TextAlign.center, style: AppTypography.footnote15.copyWith(color: onSurfaceMuted)),
            const SizedBox(height: 16),
            dark
                ? SecondaryPillButton(label: 'Retry', expand: false, foreground: AppColors.onDark, borderColor: AppColors.hairlineDark, onPressed: onRetry)
                : PrimaryPillButton(label: 'Retry', expand: false, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
