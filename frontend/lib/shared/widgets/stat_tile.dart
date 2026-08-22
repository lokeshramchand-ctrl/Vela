import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_typography.dart';

/// Small stat card: mono micro-label + Space Grotesk value, e.g. the
/// "PERIODS / TXNS ANALYSED / CORRECTIONS" row on the Profile screen.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.valueColor, this.dark = true});

  final String label;
  final String value;
  final Color? valueColor;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? AppColors.ink850 : AppColors.card,
        border: Border.all(color: dark ? AppColors.hairlineDark : AppColors.hairlineLight),
        borderRadius: BorderRadius.circular(AppRadius.field + 4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.microLabel11.copyWith(color: dark ? AppColors.onDarkFaint : AppColors.onLightFaint),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTypography.amountMedium20.copyWith(color: valueColor ?? (dark ? AppColors.onDark : AppColors.onLight)),
          ),
        ],
      ),
    );
  }
}
