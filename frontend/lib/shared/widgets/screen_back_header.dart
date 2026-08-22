import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// The back-button header row hand-rolled at the top of most secondary
/// screens (Recurring, Category drilldown, Manage periods, Profile,
/// Register, Rejected file) - centralised so the icon/size/tap-target stay
/// consistent instead of six near-identical copies drifting apart.
///
/// Two layouts, matching the two patterns actually used:
///  - [title]: back button + left-aligned title next to it.
///  - [centerTitle]: back button + centered title + balancing spacer, for
///    headers where the title needs to stay visually centered regardless of
///    the back button's width.
class ScreenBackHeader extends StatelessWidget {
  const ScreenBackHeader({
    super.key,
    this.title,
    this.centerTitle,
    this.titleStyle,
    this.dark = true,
    this.onBack,
  }) : assert(title == null || centerTitle == null, 'Pass either title or centerTitle, not both.');

  final String? title;
  final String? centerTitle;
  final TextStyle? titleStyle;
  final bool dark;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final color = dark ? AppColors.onDark : AppColors.onLight;
    final backButton = IconButton(
      padding: EdgeInsets.zero,
      tooltip: 'Back',
      icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: color),
      onPressed: onBack ?? () => context.pop(),
    );

    if (centerTitle != null) {
      final mutedColor = dark ? AppColors.onDarkMuted : AppColors.onLightMuted;
      return Row(
        children: [
          backButton,
          Expanded(
            child: Text(
              centerTitle!,
              textAlign: TextAlign.center,
              style: (titleStyle ?? AppTypography.buttonLabel13).copyWith(color: mutedColor),
            ),
          ),
          const SizedBox(width: 48),
        ],
      );
    }

    return Row(
      children: [
        backButton,
        if (title != null) ...[
          const SizedBox(width: 4),
          Text(title!, style: (titleStyle ?? AppTypography.navTitle15).copyWith(color: color)),
        ],
      ],
    );
  }
}
