import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../upload/presentation/uploading_sheet.dart';

/// Doubles as Overview's empty state when the user has zero periods.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.ink900,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md + 8, 20, AppSpacing.md + 8, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.accent, AppColors.accentDim]),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text('V', style: AppTypography.badge10.copyWith(color: AppColors.accentInk, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  Text('Vela', style: AppTypography.wordmark14.copyWith(color: AppColors.onDark)),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 26),
                      _MiniIllustration(),
                      const SizedBox(height: 26),
                      Text(
                        'Six months of spending, explained in a minute.',
                        style: AppTypography.bigHeadline32.copyWith(color: AppColors.onDark),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Add one Google Pay statement. Vela reads every transaction, names the merchants, finds the patterns and tells you what changed.',
                        style: AppTypography.footnote15.copyWith(color: AppColors.onDarkMuted),
                      ),
                      const SizedBox(height: 24),
                      _numberedStep(1, 'Open Google Pay → Transaction statement'),
                      const SizedBox(height: 12),
                      _numberedStep(2, 'Pick any date range and export the PDF'),
                      const SizedBox(height: 12),
                      _numberedStep(3, 'Add it here - analysis takes under a minute'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 26),
              PrimaryPillButton(label: 'Add your first statement', onPressed: () => startUploadFlow(context, ref)),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  'Stays on your account. Never shared, never sold.',
                  style: AppTypography.microLabel11.copyWith(color: AppColors.onDarkFaint),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numberedStep(int number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.ink800, border: Border.all(color: AppColors.hairlineDark), shape: BoxShape.circle),
          child: Text('$number', style: AppTypography.microLabelTracked105.copyWith(color: AppColors.accent, fontSize: 11)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: AppTypography.cardBody135.copyWith(color: AppColors.onDarkMuted))),
      ],
    );
  }
}

class _MiniIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const heights = [0.3, 0.5, 0.42, 0.68, 0.5, 0.85, 1.0];
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < heights.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: FractionallySizedBox(
                  heightFactor: heights[i],
                  child: Container(
                    decoration: BoxDecoration(
                      color: i == heights.length - 1
                          ? AppColors.accent
                          : i == heights.length - 3
                              ? AppColors.accentDim
                              : Colors.white.withValues(alpha: 0.09),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
