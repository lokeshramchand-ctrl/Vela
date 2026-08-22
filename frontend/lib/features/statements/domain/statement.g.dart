// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'statement.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$StatementImpl _$$StatementImplFromJson(Map<String, dynamic> json) =>
    _$StatementImpl(
      id: json['id'] as String,
      originalFilename: json['original_filename'] as String,
      fileSizeBytes: (json['file_size_bytes'] as num).toInt(),
      pageCount: (json['page_count'] as num?)?.toInt(),
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      declaredSentAmount: (json['declared_sent_amount'] as num?)?.toDouble(),
      declaredReceivedAmount: (json['declared_received_amount'] as num?)
          ?.toDouble(),
      computedSentAmount: (json['computed_sent_amount'] as num?)?.toDouble(),
      computedReceivedAmount: (json['computed_received_amount'] as num?)
          ?.toDouble(),
      reconciliationOk: json['reconciliation_ok'] as bool?,
      transactionCount: (json['transaction_count'] as num).toInt(),
      processingStatus: $enumDecode(
        _$ProcessingStatusEnumMap,
        json['processing_status'],
      ),
      currentJobId: json['current_job_id'] as String?,
      errorMessage: json['error_message'] as String?,
      analyticsVersion: json['analytics_version'] as String,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
      processingCompletedAt: json['processing_completed_at'] == null
          ? null
          : DateTime.parse(json['processing_completed_at'] as String),
      processingDurationMs: (json['processing_duration_ms'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$StatementImplToJson(
  _$StatementImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'original_filename': instance.originalFilename,
  'file_size_bytes': instance.fileSizeBytes,
  'page_count': instance.pageCount,
  'period_start': instance.periodStart.toIso8601String(),
  'period_end': instance.periodEnd.toIso8601String(),
  'declared_sent_amount': instance.declaredSentAmount,
  'declared_received_amount': instance.declaredReceivedAmount,
  'computed_sent_amount': instance.computedSentAmount,
  'computed_received_amount': instance.computedReceivedAmount,
  'reconciliation_ok': instance.reconciliationOk,
  'transaction_count': instance.transactionCount,
  'processing_status': _$ProcessingStatusEnumMap[instance.processingStatus]!,
  'current_job_id': instance.currentJobId,
  'error_message': instance.errorMessage,
  'analytics_version': instance.analyticsVersion,
  'uploaded_at': instance.uploadedAt.toIso8601String(),
  'processing_completed_at': instance.processingCompletedAt?.toIso8601String(),
  'processing_duration_ms': instance.processingDurationMs,
};

const _$ProcessingStatusEnumMap = {
  ProcessingStatus.pending: 'PENDING',
  ProcessingStatus.processing: 'PROCESSING',
  ProcessingStatus.completed: 'COMPLETED',
  ProcessingStatus.failed: 'FAILED',
};

_$StatementListResponseImpl _$$StatementListResponseImplFromJson(
  Map<String, dynamic> json,
) => _$StatementListResponseImpl(
  items: (json['items'] as List<dynamic>)
      .map((e) => Statement.fromJson(e as Map<String, dynamic>))
      .toList(),
  page: (json['page'] as num).toInt(),
  pageSize: (json['page_size'] as num).toInt(),
  total: (json['total'] as num).toInt(),
  totalPages: (json['total_pages'] as num).toInt(),
);

Map<String, dynamic> _$$StatementListResponseImplToJson(
  _$StatementListResponseImpl instance,
) => <String, dynamic>{
  'items': instance.items.map((e) => e.toJson()).toList(),
  'page': instance.page,
  'page_size': instance.pageSize,
  'total': instance.total,
  'total_pages': instance.totalPages,
};

_$StatementUploadResponseImpl _$$StatementUploadResponseImplFromJson(
  Map<String, dynamic> json,
) => _$StatementUploadResponseImpl(
  statementId: json['statement_id'] as String,
  jobId: json['job_id'] as String,
  status: $enumDecode(_$ProcessingStatusEnumMap, json['status']),
);

Map<String, dynamic> _$$StatementUploadResponseImplToJson(
  _$StatementUploadResponseImpl instance,
) => <String, dynamic>{
  'statement_id': instance.statementId,
  'job_id': instance.jobId,
  'status': _$ProcessingStatusEnumMap[instance.status]!,
};
