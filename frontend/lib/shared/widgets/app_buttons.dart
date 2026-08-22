import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_typography.dart';

/// Full/auto-width filled pill CTA - accent bg, accent-ink text.
class PrimaryPillButton extends StatelessWidget {
  const PrimaryPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = true,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expand;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.accentInk,
        disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.6),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
        elevation: 0,
      ),
      child: loading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentInk),
            )
          : Text(label, style: AppTypography.buttonLabel15.copyWith(color: AppColors.accentInk)),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Outline pill - hairline border, transparent bg.
class SecondaryPillButton extends StatelessWidget {
  const SecondaryPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = true,
    required this.foreground,
    required this.borderColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expand;
  final Color foreground;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        side: BorderSide(color: borderColor, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
      ),
      child: Text(label, style: AppTypography.buttonLabel14.copyWith(color: foreground)),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// No-container text link, e.g. "See transaction", "All 5 →".
class TextActionLink extends StatelessWidget {
  const TextActionLink({super.key, required this.label, required this.onPressed, this.color});

  final String label;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Text(
        label,
        style: AppTypography.buttonLabel12.copyWith(color: color ?? AppColors.accentDim),
      ),
    );
  }
}
