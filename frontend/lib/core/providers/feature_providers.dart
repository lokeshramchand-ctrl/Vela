import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/analytics/data/analytics_repository.dart';
import '../../features/app_update/data/app_update_repository.dart';
import '../../features/feedback/data/feedback_repository.dart';
import '../../features/statements/data/jobs_repository.dart';
import '../../features/statements/data/statements_repository.dart';
import 'core_providers.dart';

final statementsRepositoryProvider = Provider<StatementsRepository>((ref) {
  return StatementsRepository(apiClient: ref.watch(apiClientProvider));
});

final jobsRepositoryProvider = Provider<JobsRepository>((ref) {
  return JobsRepository(apiClient: ref.watch(apiClientProvider));
});

final feedbackRepositoryProvider = Provider<FeedbackRepository>((ref) {
  return FeedbackRepository(apiClient: ref.watch(apiClientProvider));
});

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(apiClient: ref.watch(apiClientProvider));
});

final appUpdateRepositoryProvider = Provider<AppUpdateRepository>((ref) {
  return AppUpdateRepository(apiClient: ref.watch(apiClientProvider));
});
