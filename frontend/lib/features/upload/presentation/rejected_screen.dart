import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/screen_back_header.dart';
import 'uploading_sheet.dart';

class RejectedScreen extends ConsumerWidget {
  const RejectedScreen({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 16, AppSpacing.gutter, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScreenBackHeader(
                dark: false,
                centerTitle: 'Add statement',
                onBack: () => context.canPop() ? context.pop() : context.go('/shell/overview'),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: AppColors.roseTint, borderRadius: BorderRadius.circular(16)),
                        child: Text('!', style: AppTypography.amountSmall22.copyWith(color: AppColors.rose)),
                      ),
                      const SizedBox(height: 18),
                      Text("This PDF isn't a Google Pay statement", style: AppTypography.bigHeadline26.copyWith(color: AppColors.onLight)),
                      const SizedBox(height: 10),
                      Text(
                        message ??
                            'We look for the "Transaction statement" header and UPI transaction IDs. This file has neither - it may be a bank statement or an invoice.',
                        style: AppTypography.body14.copyWith(color: AppColors.onLightMuted, height: 1.55),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.hairlineLight), borderRadius: BorderRadius.circular(AppRadius.card)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('HOW TO GET THE RIGHT FILE', style: AppTypography.microLabelTracked105.copyWith(color: AppColors.onLightFaint)),
                            const SizedBox(height: 12),
                            _step('01', 'Google Pay → profile → Transaction statement'),
                            const SizedBox(height: 10),
                            _step('02', 'Choose a date range, tap Get statement'),
                            const SizedBox(height: 10),
                            _step('03', 'Share the PDF straight into Vela'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Container(width: 5, height: 5, decoration: BoxDecoration(color: AppColors.onLightFaint, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Nothing was saved. Your other periods are untouched.', style: AppTypography.microLabel11.copyWith(color: AppColors.onLightFaint)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              PrimaryPillButton(
                label: 'Choose a different file',
                onPressed: () async {
                  context.pop();
                  await startUploadFlow(context, ref);
                },
              ),
              const SizedBox(height: 12),
              SecondaryPillButton(
                label: 'Open Google Pay',
                foreground: AppColors.onLight,
                borderColor: AppColors.hairlineLight,
                onPressed: () => launchUrl(Uri.parse('https://pay.google.com'), mode: LaunchMode.externalApplication),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _step(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(number, style: AppTypography.microLabelTracked11.copyWith(color: AppColors.accentDim)),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: AppTypography.body13.copyWith(color: AppColors.onLight))),
      ],
    );
  }
}
