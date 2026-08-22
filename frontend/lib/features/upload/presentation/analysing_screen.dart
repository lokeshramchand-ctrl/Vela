import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/notifications/local_notifications_service.dart';
import '../../../core/providers/feature_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/progress_ring.dart';
import '../../../shared/widgets/pulsing_dot.dart';
import '../../statements/domain/job.dart';
import '../../statements/presentation/period_providers.dart';

class AnalysingScreen extends ConsumerStatefulWidget {
  const AnalysingScreen({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<AnalysingScreen> createState() => _AnalysingScreenState();
}

class _AnalysingScreenState extends ConsumerState<AnalysingScreen> {
  static const _stageLabels = [
    'Reading your statement',
    'Naming merchants',
    'Profiling behaviour',
    'Computing analytics',
    'Writing your signals',
  ];

  bool _notifyRequested = false;
  bool _notifiedDone = false;

  Future<void> _requestNotify() async {
    final messenger = ScaffoldMessenger.of(context);
    final granted = await LocalNotificationsService.instance.requestPermission();
    if (!mounted) return;
    if (granted) {
      setState(() => _notifyRequested = true);
      messenger.showSnackBar(SnackBar(content: const Text("We'll notify you when this finishes."), backgroundColor: AppColors.ink700));
    } else {
      messenger.showSnackBar(SnackBar(content: const Text('Notifications are turned off for Vela in system settings.'), backgroundColor: AppColors.rose));
    }
  }

  void _notifyIfRequested({required bool failed}) {
    if (!_notifyRequested || _notifiedDone) return;
    _notifiedDone = true;
    LocalNotificationsService.instance.showJobDone(
      title: failed ? 'Statement processing failed' : 'Your statement is ready',
      body: failed ? "We couldn't finish analysing your statement." : "We've found your top merchant and biggest signal.",
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobAsync = ref.watch(_jobPollProvider(widget.jobId));

    return Scaffold(
      backgroundColor: AppColors.ink900,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -1),
            radius: 1.2,
            colors: [AppColors.analysingGlowCenter, AppColors.ink900],
            stops: const [0, 0.62],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 14, AppSpacing.gutter, 30),
            child: jobAsync.when(
              loading: () => Center(child: CircularProgressIndicator(color: AppColors.accent)),
              error: (error, _) => _ErrorBody(message: error.toString()),
              data: (job) {
                if (job.status == JobStatus.failed) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _notifyIfRequested(failed: true));
                  return _ErrorBody(message: job.errorMessage ?? "This statement couldn't be processed.");
                }
                if (job.status == JobStatus.completed) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _notifyIfRequested(failed: false);
                    ref.read(selectedPeriodIdProvider.notifier).state = job.resourceId;
                    ref.invalidate(periodsProvider);
                    if (context.mounted) context.go('/shell/overview');
                  });
                }
                final progress = job.progressPercent.toDouble();
                final activeIndex = (progress / 100 * _stageLabels.length).floor().clamp(0, _stageLabels.length - 1);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Your statement', style: AppTypography.rowLabel14.copyWith(color: AppColors.onDark)),
                        Text('RUNNING IN BACKGROUND', style: AppTypography.microLabel11.copyWith(color: AppColors.onDarkFaint)),
                      ],
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 28),
                            Center(
                              child: ProgressRing(
                                percent: progress,
                                centerLabel: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(text: '${progress.round()}', style: AppTypography.heroAmount34.copyWith(color: AppColors.onDark)),
                                      TextSpan(text: '%', style: AppTypography.amountMedium20.copyWith(color: AppColors.onDark)),
                                    ],
                                  ),
                                ),
                                centerSubLabel: job.stage?.toUpperCase(),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text('Finding your patterns', textAlign: TextAlign.center, style: AppTypography.bigHeadline22.copyWith(color: AppColors.onDark)),
                            const SizedBox(height: 10),
                            Text(
                              'Profiling merchant behaviour - how often you pay them, and how much is normal.',
                              textAlign: TextAlign.center,
                              style: AppTypography.footnote15.copyWith(color: AppColors.onDarkMuted),
                            ),
                            const SizedBox(height: 26),
                            for (var i = 0; i < _stageLabels.length; i++) _StageRow(label: _stageLabels[i], state: i < activeIndex ? _StageState.done : i == activeIndex ? _StageState.active : _StageState.pending),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                      decoration: BoxDecoration(color: AppColors.ink850, border: Border.all(color: AppColors.hairlineDark), borderRadius: BorderRadius.circular(14)),
                      child: Text(
                        "We'll show your top merchant and biggest signal the moment this finishes.",
                        style: AppTypography.footnote12.copyWith(color: AppColors.onDarkMuted),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SecondaryPillButton(
                      label: _notifyRequested ? "We'll notify you" : "Notify me when it's done",
                      foreground: AppColors.onDark,
                      borderColor: AppColors.hairlineDark,
                      onPressed: _notifyRequested ? null : _requestNotify,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

enum _StageState { done, active, pending }

class _StageRow extends StatelessWidget {
  const _StageRow({required this.label, required this.state});
  final String label;
  final _StageState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Opacity(
        opacity: state == _StageState.pending ? 0.4 : 1,
        child: Row(
          children: [
            if (state == _StageState.done)
              Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 18)
            else if (state == _StageState.active)
              SizedBox(
                width: 18,
                height: 18,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.accent, width: 2))),
                    PulsingDot(color: AppColors.accent, size: 7),
                  ],
                ),
              )
            else
              Container(width: 18, height: 18, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.onDarkFaint))),
            const SizedBox(width: 12),
            Text(
              label,
              style: (state == _StageState.active ? AppTypography.rowLabel14 : AppTypography.body13).copyWith(color: AppColors.onDark),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, color: AppColors.rose, size: 40),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center, style: AppTypography.footnote15.copyWith(color: AppColors.onDarkMuted)),
          const SizedBox(height: 20),
          PrimaryPillButton(label: 'Back to overview', expand: false, onPressed: () => context.go('/shell/overview')),
        ],
      ),
    );
  }
}

final _jobPollProvider = StreamProvider.autoDispose.family<Job, String>((ref, jobId) {
  return ref.watch(jobsRepositoryProvider).poll(jobId, interval: const Duration(seconds: 2));
});
