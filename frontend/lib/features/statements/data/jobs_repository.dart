import '../../../core/network/api_client.dart';
import '../domain/job.dart';

class JobsRepository {
  JobsRepository({required this._apiClient});

  final ApiClient _apiClient;

  Future<Job> get(String jobId) async {
    final response = await _apiClient.get<Map<String, dynamic>>('/jobs/$jobId');
    return Job.fromJson(response.data!);
  }

  /// Polls until the job reaches a terminal state (COMPLETED/FAILED), or
  /// [timeout] elapses. There's no push/webhook - see docs/API_REFERENCE.md §4.
  Stream<Job> poll(String jobId, {Duration interval = const Duration(seconds: 2), Duration? timeout}) async* {
    final deadline = timeout == null ? null : DateTime.now().add(timeout);
    while (true) {
      final job = await get(jobId);
      yield job;
      if (job.status == JobStatus.completed || job.status == JobStatus.failed) return;
      if (deadline != null && DateTime.now().isAfter(deadline)) return;
      await Future.delayed(interval);
    }
  }
}
