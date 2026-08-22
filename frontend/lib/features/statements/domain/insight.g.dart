// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'insight.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$InsightImpl _$$InsightImplFromJson(Map<String, dynamic> json) =>
    _$InsightImpl(
      type: json['type'] as String,
      message: json['message'] as String,
      severity: $enumDecode(_$InsightSeverityEnumMap, json['severity']),
    );

Map<String, dynamic> _$$InsightImplToJson(_$InsightImpl instance) =>
    <String, dynamic>{
      'type': instance.type,
      'message': instance.message,
      'severity': _$InsightSeverityEnumMap[instance.severity]!,
    };

const _$InsightSeverityEnumMap = {
  InsightSeverity.info: 'INFO',
  InsightSeverity.positive: 'POSITIVE',
  InsightSeverity.warning: 'WARNING',
};

_$StatementInsightsResponseImpl _$$StatementInsightsResponseImplFromJson(
  Map<String, dynamic> json,
) => _$StatementInsightsResponseImpl(
  statementId: json['statement_id'] as String,
  insights: (json['insights'] as List<dynamic>)
      .map((e) => Insight.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$$StatementInsightsResponseImplToJson(
  _$StatementInsightsResponseImpl instance,
) => <String, dynamic>{
  'statement_id': instance.statementId,
  'insights': instance.insights.map((e) => e.toJson()).toList(),
};
