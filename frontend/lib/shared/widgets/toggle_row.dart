import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Settings-style row: title (+ optional sub-label) with a trailing switch,
/// matching the design's 38x22 pill toggle (accent when ON, ink700 when OFF).
class ToggleRow extends StatelessWidget {
  const ToggleRow({super.key, required this.title, this.subtitle, required this.value, required this.onChanged});

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 15),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppTypography.rowLabel14.copyWith(color: AppColors.onDark)),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: AppTypography.footnote1155.copyWith(color: AppColors.onDarkFaint)),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.accent,
            activeThumbColor: AppColors.accentInk,
            inactiveTrackColor: AppColors.ink700,
            inactiveThumbColor: AppColors.onDarkFaint,
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
        ],
      ),
    );
  }
}

/// "Light / Dark / Auto" style 3-way pill segmented control.
class VelaSegmentedControl<T> extends StatelessWidget {
  const VelaSegmentedControl({super.key, required this.options, required this.value, required this.onChanged});

  final List<(T value, String label)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.ink700, borderRadius: BorderRadius.circular(100)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            GestureDetector(
              onTap: () => onChanged(option.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: option.$1 == value ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  option.$2,
                  style: AppTypography.buttonLabel12.copyWith(
                    color: option.$1 == value ? AppColors.accentInk : AppColors.onDarkMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
