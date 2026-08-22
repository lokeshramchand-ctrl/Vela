import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/feature_providers.dart';
import '../../../core/providers/settings_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/avatar_chip.dart';
import '../../../shared/widgets/screen_back_header.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../../../shared/widgets/toggle_row.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_state.dart';
import '../../statements/domain/statement.dart';
import '../../statements/domain/transaction.dart';
import '../../statements/presentation/period_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider).valueOrNull;
    final periodsAsync = ref.watch(periodsProvider);
    final themeMode = ref.watch(themeModeProvider);

    final user = authState is AuthAuthenticated ? authState.user : null;
    final initials = user?.initials ?? '?';

    final periods = periodsAsync.valueOrNull ?? const <Statement>[];
    final completed = periods.where((p) => p.processingStatus == ProcessingStatus.completed).toList();
    final totalTxns = completed.fold<int>(0, (sum, p) => sum + p.transactionCount);

    return Scaffold(
      backgroundColor: AppColors.ink900,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 6, AppSpacing.gutter, 28),
          children: [
            ScreenBackHeader(title: 'You', titleStyle: AppTypography.screenTitle24),
            const SizedBox(height: 18),
            Row(
              children: [
                AvatarChip(initials: initials, size: 54, gradient: LinearGradient(colors: [AppColors.accent, AppColors.accentDim]), foregroundColor: AppColors.accentInk),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(user?.fullName?.trim().isNotEmpty == true ? user!.fullName! : (user?.email ?? ''), style: AppTypography.rowLabel14.copyWith(fontSize: 16, color: AppColors.onDark)),
                      const SizedBox(height: 3),
                      Text(user?.email ?? '', style: AppTypography.meta12.copyWith(color: AppColors.onDarkFaint)),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () => _editName(context, ref, user?.fullName),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.hairlineDark), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                  child: Text('Edit', style: AppTypography.buttonLabel12.copyWith(color: AppColors.onDark)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: StatTile(label: 'PERIODS', value: '${periods.length}')),
                const SizedBox(width: 10),
                Expanded(child: StatTile(label: 'TXNS ANALYSED', value: '$totalTxns')),
                const SizedBox(width: 10),
                Expanded(child: StatTile(label: 'COMPLETED', value: '${completed.length}')),
              ],
            ),
            const SizedBox(height: 26),
            const _SectionLabel('DATA'),
            const SizedBox(height: 10),
            _Card(
              children: [
                _NavRow(title: 'Manage periods', trailing: '${periods.length} ›', onTap: () => context.push('/profile/periods')),
                Divider(height: 1, color: AppColors.hairlineDark),
                _NavRow(title: 'Spending patterns', trailing: '›', onTap: () => context.push('/profile/analytics')),
                Divider(height: 1, color: AppColors.hairlineDark),
                Consumer(builder: (context, ref, _) {
                  final keep = ref.watch(keepOriginalPdfsProvider);
                  return ToggleRow(title: 'Keep original PDFs', value: keep, onChanged: (v) => ref.read(keepOriginalPdfsProvider.notifier).set(v));
                }),
                Divider(height: 1, color: AppColors.hairlineDark),
                _NavRow(title: 'Export my data', trailing: '›', onTap: () => _exportData(context, ref)),
              ],
            ),
            const SizedBox(height: 22),
            const _SectionLabel('APPEARANCE & ALERTS'),
            const SizedBox(height: 10),
            _Card(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Theme', style: AppTypography.rowLabel14.copyWith(color: AppColors.onDark)),
                      VelaSegmentedControl<ThemeMode>(
                        value: themeMode,
                        options: const [(ThemeMode.light, 'Light'), (ThemeMode.dark, 'Dark'), (ThemeMode.system, 'Auto')],
                        onChanged: (mode) => ref.read(themeModeProvider.notifier).set(mode),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: AppColors.hairlineDark),
                Consumer(builder: (context, ref, _) {
                  final value = ref.watch(notifyAnalysisFinishedProvider);
                  return ToggleRow(
                    title: 'Analysis finished',
                    subtitle: 'Push when a period is ready',
                    value: value,
                    onChanged: (v) => ref.read(notifyAnalysisFinishedProvider.notifier).set(v),
                  );
                }),
                Divider(height: 1, color: AppColors.hairlineDark),
                Consumer(builder: (context, ref, _) {
                  final value = ref.watch(notifyUnusualSpendProvider);
                  return ToggleRow(
                    title: 'Unusual spend',
                    subtitle: 'Only WATCH-level signals',
                    value: value,
                    onChanged: (v) => ref.read(notifyUnusualSpendProvider.notifier).set(v),
                  );
                }),
              ],
            ),
            const SizedBox(height: 22),
            const _SectionLabel('LEGAL'),
            const SizedBox(height: 10),
            _Card(
              children: [
                _NavRow(title: 'Privacy Policy', trailing: '›', onTap: () => context.push('/profile/privacy')),
                Divider(height: 1, color: AppColors.hairlineDark),
                _NavRow(title: 'Terms of Service', trailing: '›', onTap: () => context.push('/profile/terms')),
              ],
            ),
            const SizedBox(height: 26),
            OutlinedButton(
              onPressed: () async {
                await ref.read(authControllerProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
              style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.hairlineDark), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
              child: Text('Sign out', style: AppTypography.buttonLabel14.copyWith(color: AppColors.onDark)),
            ),
            const SizedBox(height: 14),
            Center(
              child: TextButton(
                onPressed: () => _confirmDeleteAccount(context, ref),
                child: Text('Delete account and all data', style: AppTypography.footnote12.copyWith(color: AppColors.rose)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref, String? currentName) async {
    final controller = TextEditingController(text: currentName ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.ink850,
        title: Text('Edit name', style: AppTypography.rowLabel14.copyWith(color: AppColors.onDark)),
        content: TextField(controller: controller, style: TextStyle(color: AppColors.onDark), decoration: const InputDecoration(hintText: 'Your name')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Cancel', style: TextStyle(color: AppColors.onDarkMuted))),
          TextButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: Text('Save', style: TextStyle(color: AppColors.accent))),
        ],
      ),
    );
    if (result == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authRepositoryProvider).updateProfile(fullName: result.isEmpty ? null : result);
      ref.invalidate(authControllerProvider);
      messenger.showSnackBar(SnackBar(content: const Text('Name updated'), backgroundColor: AppColors.ink700));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.rose));
    }
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    final period = ref.read(currentPeriodProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (period == null) {
      messenger.showSnackBar(SnackBar(content: const Text('Add a statement first to export its transactions.'), backgroundColor: AppColors.ink700));
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator(color: AppColors.accent)),
    );
    try {
      final repo = ref.read(statementsRepositoryProvider);
      final transactions = <Transaction>[];
      var page = 1;
      // Safety cap, not a truncation limit: 500 pages * 100/page = 50k
      // transactions, far beyond any real statement - guards against an
      // infinite loop if the backend ever reports a bad total_pages.
      const maxPages = 500;
      while (page <= maxPages) {
        final result = await repo.transactions(period.id, page: page, pageSize: 100, sortBy: 'timestamp', sortOrder: 'desc');
        transactions.addAll(result.items);
        if (page >= result.totalPages) break;
        page++;
      }
      final buffer = StringBuffer('date,merchant,category,amount,type,status\n');
      for (final txn in transactions) {
        buffer.writeln('${txn.timestamp.toIso8601String()},${txn.merchant ?? ''},${txn.category ?? ''},${txn.amount},${txn.transactionType.name},${txn.status.name}');
      }
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      await Share.share(buffer.toString(), subject: 'Vela export - ${period.originalFilename}');
    } on ApiException catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      messenger.showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.rose));
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.ink850,
        title: Text('Delete account?', style: AppTypography.rowLabel14.copyWith(color: AppColors.onDark)),
        content: Text(
          "This signs you out and clears this device's local session. Full account and data deletion isn't available from the app yet - contact support to permanently delete your account.",
          style: AppTypography.footnote12.copyWith(color: AppColors.onDarkMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Cancel', style: TextStyle(color: AppColors.onDarkMuted))),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Sign out', style: TextStyle(color: AppColors.rose))),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authControllerProvider.notifier).logout();
    if (context.mounted) context.go('/login');
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: AppTypography.microLabelTracked105.copyWith(color: AppColors.onDarkFaint));
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.ink850, border: Border.all(color: AppColors.hairlineDark), borderRadius: BorderRadius.circular(AppRadius.field + 4)),
      child: Column(children: children),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.title, required this.trailing, required this.onTap});
  final String title;
  final String trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: AppTypography.rowLabel14.copyWith(color: AppColors.onDark)),
            Text(trailing, style: AppTypography.meta12.copyWith(color: AppColors.onDarkFaint)),
          ],
        ),
      ),
    );
  }
}
