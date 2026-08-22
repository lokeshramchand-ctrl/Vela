import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/screen_back_header.dart';
import 'legal_documents.dart';

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 6, AppSpacing.gutter, 32),
          children: [
            ScreenBackHeader(title: document.title, titleStyle: AppTypography.screenTitle24, dark: false),
            const SizedBox(height: 4),
            Text('Last updated ${document.lastUpdated}', style: AppTypography.meta12.copyWith(color: AppColors.onLightFaint)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.amber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Text(document.intro, style: AppTypography.footnote15.copyWith(color: AppColors.onLight, height: 1.5)),
            ),
            const SizedBox(height: 26),
            for (final section in document.sections) ...[
              Text(section.heading, style: AppTypography.rowLabel14.copyWith(color: AppColors.onLight, fontSize: 16)),
              const SizedBox(height: 8),
              Text(section.body, style: AppTypography.footnote15.copyWith(color: AppColors.onLightMuted, height: 1.55)),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}
