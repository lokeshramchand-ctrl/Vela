import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// A centered icon + title + optional subtitle/CTA, used whenever a list or
/// section has no data to show (as opposed to still loading, or errored).
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.dark = false, this.cta});

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool dark;
  final Widget? cta;

  @override
  Widget build(BuildContext context) {
    final onSurface = dark ? AppColors.onDark : AppColors.onLight;
    final onSurfaceMuted = dark ? AppColors.onDarkMuted : AppColors.onLightMuted;
    final tint = dark ? AppColors.ink800 : AppColors.card;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle, border: Border.all(color: dark ? AppColors.hairlineDark : AppColors.hairlineLight)),
              child: Icon(icon, size: 22, color: onSurfaceMuted),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: AppTypography.rowLabel145.copyWith(color: onSurface)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, textAlign: TextAlign.center, style: AppTypography.footnote12.copyWith(color: onSurfaceMuted)),
            ],
            if (cta != null) ...[
              const SizedBox(height: 18),
              cta!,
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 280.ms).moveY(begin: 8, end: 0, duration: 280.ms, curve: Curves.easeOut);
  }
}
