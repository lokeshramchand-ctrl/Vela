import 'package:freezed_annotation/freezed_annotation.dart';

part 'analytics_models.freezed.dart';
part 'analytics_models.g.dart';

// These endpoints have no response_model on the backend (see
// docs/API_REFERENCE.md §6/§10) - shapes are reverse-engineered from the
// underlying analytics/*.py modules and could drift silently, so every
// field here is deliberately nullable/defaulted rather than required.

@freezed
abstract class CategoryPatternEntry with _$CategoryPatternEntry {
  const factory CategoryPatternEntry({
    @Default('Unknown') String category,
    @Default(0) double totalAmount,
    @Default(0) int count,
  }) = _CategoryPatternEntry;

  factory CategoryPatternEntry.fromJson(Map<String, dynamic> json) => _$CategoryPatternEntryFromJson(json);
}

@freezed
abstract class MerchantPatternEntry with _$MerchantPatternEntry {
  const factory MerchantPatternEntry({
    String? merchant,
    @Default(0) int visits,
    @Default(0) double spent,
  }) = _MerchantPatternEntry;

  factory MerchantPatternEntry.fromJson(Map<String, dynamic> json) => _$MerchantPatternEntryFromJson(json);
}

@freezed
abstract class SubscriptionDetail with _$SubscriptionDetail {
  const factory SubscriptionDetail({
    required String merchant,
    required double estimatedMonthlyCost,
    required double periodicityScore,
    DateTime? lastBilled,
  }) = _SubscriptionDetail;

  factory SubscriptionDetail.fromJson(Map<String, dynamic> json) => _$SubscriptionDetailFromJson(json);
}

@freezed
abstract class SubscriptionsSummary with _$SubscriptionsSummary {
  const factory SubscriptionsSummary({
    @Default(0) int activeSubscriptions,
    @Default(0) double totalMonthlyBurn,
    @Default(<SubscriptionDetail>[]) List<SubscriptionDetail> details,
  }) = _SubscriptionsSummary;

  factory SubscriptionsSummary.fromJson(Map<String, dynamic> json) => _$SubscriptionsSummaryFromJson(json);
}

@freezed
abstract class MoMTrend with _$MoMTrend {
  const factory MoMTrend({
    @Default(0) double currentSpend,
    @Default(0) double previousSpend,
    @Default(0) double momGrowthPercentage,
    @Default('down') String trend,
  }) = _MoMTrend;

  factory MoMTrend.fromJson(Map<String, dynamic> json) => _$MoMTrendFromJson(json);

  const MoMTrend._();
  bool get isUp => trend == 'up';
}

@freezed
abstract class AnomalyCheckResult with _$AnomalyCheckResult {
  const factory AnomalyCheckResult({
    required bool isAnomaly,
    required String reason,
    double? confidence,
  }) = _AnomalyCheckResult;

  factory AnomalyCheckResult.fromJson(Map<String, dynamic> json) => _$AnomalyCheckResultFromJson(json);
}
