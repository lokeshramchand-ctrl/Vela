// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$JobImpl _$$JobImplFromJson(Map<String, dynamic> json) => _$JobImpl(
  id: json['id'] as String,
  jobType: json['job_type'] as String,
  resourceType: json['resource_type'] as String,
  resourceId: json['resource_id'] as String,
  status: $enumDecode(_$JobStatusEnumMap, json['status']),
  stage: json['stage'] as String?,
  progressPercent: (json['progress_percent'] as num).toInt(),
  errorMessage: json['error_message'] as String?,
  createdAt: DateTime.parse(json['created_at'] as String),
  startedAt: json['started_at'] == null
      ? null
      : DateTime.parse(json['started_at'] as String),
  completedAt: json['completed_at'] == null
      ? null
      : DateTime.parse(json['completed_at'] as String),
);

Map<String, dynamic> _$$JobImplToJson(_$JobImpl instance) => <String, dynamic>{
  'id': instance.id,
  'job_type': instance.jobType,
  'resource_type': instance.resourceType,
  'resource_id': instance.resourceId,
  'status': _$JobStatusEnumMap[instance.status]!,
  'stage': instance.stage,
  'progress_percent': instance.progressPercent,
  'error_message': instance.errorMessage,
  'created_at': instance.createdAt.toIso8601String(),
  'started_at': instance.startedAt?.toIso8601String(),
  'completed_at': instance.completedAt?.toIso8601String(),
};

const _$JobStatusEnumMap = {
  JobStatus.queued: 'QUEUED',
  JobStatus.running: 'RUNNING',
  JobStatus.completed: 'COMPLETED',
  JobStatus.failed: 'FAILED',
};
