import 'package:freezed_annotation/freezed_annotation.dart';

part 'job.freezed.dart';
part 'job.g.dart';

enum JobStatus {
  @JsonValue('QUEUED')
  queued,
  @JsonValue('RUNNING')
  running,
  @JsonValue('COMPLETED')
  completed,
  @JsonValue('FAILED')
  failed,
}

@freezed
abstract class Job with _$Job {
  const factory Job({
    required String id,
    required String jobType,
    required String resourceType,
    required String resourceId,
    required JobStatus status,
    String? stage,
    required int progressPercent,
    String? errorMessage,
    required DateTime createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
  }) = _Job;

  factory Job.fromJson(Map<String, dynamic> json) => _$JobFromJson(json);
}
