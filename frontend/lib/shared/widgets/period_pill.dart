import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Header period selector chip: dot + label + caret. Tapping opens the
/// Period switcher sheet.
class PeriodPill extends StatelessWidget {
  const PeriodPill({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: 'Switch period, currently $label',
      child: SizedBox(
        height: 44,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(100),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.ink800,
                border: Border.all(color: AppColors.hairlineDark),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(label, style: AppTypography.buttonLabel14.copyWith(color: AppColors.onDark)),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.onDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
