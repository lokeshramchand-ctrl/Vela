import 'package:freezed_annotation/freezed_annotation.dart';

part 'insight.freezed.dart';
part 'insight.g.dart';

enum InsightSeverity {
  @JsonValue('INFO')
  info,
  @JsonValue('POSITIVE')
  positive,
  @JsonValue('WARNING')
  warning,
}

@freezed
abstract class Insight with _$Insight {
  const factory Insight({
    required String type,
    required String message,
    required InsightSeverity severity,
  }) = _Insight;

  factory Insight.fromJson(Map<String, dynamic> json) => _$InsightFromJson(json);
}

@freezed
abstract class StatementInsightsResponse with _$StatementInsightsResponse {
  const factory StatementInsightsResponse({
    required String statementId,
    required List<Insight> insights,
  }) = _StatementInsightsResponse;

  factory StatementInsightsResponse.fromJson(Map<String, dynamic> json) => _$StatementInsightsResponseFromJson(json);
}
