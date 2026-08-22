// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'insight.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Insight _$InsightFromJson(Map<String, dynamic> json) {
  return _Insight.fromJson(json);
}

/// @nodoc
mixin _$Insight {
  String get type => throw _privateConstructorUsedError;
  String get message => throw _privateConstructorUsedError;
  InsightSeverity get severity => throw _privateConstructorUsedError;

  /// Serializes this Insight to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Insight
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $InsightCopyWith<Insight> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $InsightCopyWith<$Res> {
  factory $InsightCopyWith(Insight value, $Res Function(Insight) then) =
      _$InsightCopyWithImpl<$Res, Insight>;
  @useResult
  $Res call({String type, String message, InsightSeverity severity});
}

/// @nodoc
class _$InsightCopyWithImpl<$Res, $Val extends Insight>
    implements $InsightCopyWith<$Res> {
  _$InsightCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Insight
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? message = null,
    Object? severity = null,
  }) {
    return _then(
      _value.copyWith(
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as String,
            message: null == message
                ? _value.message
                : message // ignore: cast_nullable_to_non_nullable
                      as String,
            severity: null == severity
                ? _value.severity
                : severity // ignore: cast_nullable_to_non_nullable
                      as InsightSeverity,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$InsightImplCopyWith<$Res> implements $InsightCopyWith<$Res> {
  factory _$$InsightImplCopyWith(
    _$InsightImpl value,
    $Res Function(_$InsightImpl) then,
  ) = __$$InsightImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String type, String message, InsightSeverity severity});
}

/// @nodoc
class __$$InsightImplCopyWithImpl<$Res>
    extends _$InsightCopyWithImpl<$Res, _$InsightImpl>
    implements _$$InsightImplCopyWith<$Res> {
  __$$InsightImplCopyWithImpl(
    _$InsightImpl _value,
    $Res Function(_$InsightImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Insight
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? message = null,
    Object? severity = null,
  }) {
    return _then(
      _$InsightImpl(
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        message: null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String,
        severity: null == severity
            ? _value.severity
            : severity // ignore: cast_nullable_to_non_nullable
                  as InsightSeverity,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$InsightImpl implements _Insight {
  const _$InsightImpl({
    required this.type,
    required this.message,
    required this.severity,
  });

  factory _$InsightImpl.fromJson(Map<String, dynamic> json) =>
      _$$InsightImplFromJson(json);

  @override
  final String type;
  @override
  final String message;
  @override
  final InsightSeverity severity;

  @override
  String toString() {
    return 'Insight(type: $type, message: $message, severity: $severity)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InsightImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.severity, severity) ||
                other.severity == severity));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, type, message, severity);

  /// Create a copy of Insight
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$InsightImplCopyWith<_$InsightImpl> get copyWith =>
      __$$InsightImplCopyWithImpl<_$InsightImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$InsightImplToJson(this);
  }
}

abstract class _Insight implements Insight {
  const factory _Insight({
    required final String type,
    required final String message,
    required final InsightSeverity severity,
  }) = _$InsightImpl;

  factory _Insight.fromJson(Map<String, dynamic> json) = _$InsightImpl.fromJson;

  @override
  String get type;
  @override
  String get message;
  @override
  InsightSeverity get severity;

  /// Create a copy of Insight
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$InsightImplCopyWith<_$InsightImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

StatementInsightsResponse _$StatementInsightsResponseFromJson(
  Map<String, dynamic> json,
) {
  return _StatementInsightsResponse.fromJson(json);
}

/// @nodoc
mixin _$StatementInsightsResponse {
  String get statementId => throw _privateConstructorUsedError;
  List<Insight> get insights => throw _privateConstructorUsedError;

  /// Serializes this StatementInsightsResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of StatementInsightsResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StatementInsightsResponseCopyWith<StatementInsightsResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StatementInsightsResponseCopyWith<$Res> {
  factory $StatementInsightsResponseCopyWith(
    StatementInsightsResponse value,
    $Res Function(StatementInsightsResponse) then,
  ) = _$StatementInsightsResponseCopyWithImpl<$Res, StatementInsightsResponse>;
  @useResult
  $Res call({String statementId, List<Insight> insights});
}

/// @nodoc
class _$StatementInsightsResponseCopyWithImpl<
  $Res,
  $Val extends StatementInsightsResponse
>
    implements $StatementInsightsResponseCopyWith<$Res> {
  _$StatementInsightsResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StatementInsightsResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? statementId = null, Object? insights = null}) {
    return _then(
      _value.copyWith(
            statementId: null == statementId
                ? _value.statementId
                : statementId // ignore: cast_nullable_to_non_nullable
                      as String,
            insights: null == insights
                ? _value.insights
                : insights // ignore: cast_nullable_to_non_nullable
                      as List<Insight>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$StatementInsightsResponseImplCopyWith<$Res>
    implements $StatementInsightsResponseCopyWith<$Res> {
  factory _$$StatementInsightsResponseImplCopyWith(
    _$StatementInsightsResponseImpl value,
    $Res Function(_$StatementInsightsResponseImpl) then,
  ) = __$$StatementInsightsResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String statementId, List<Insight> insights});
}

/// @nodoc
class __$$StatementInsightsResponseImplCopyWithImpl<$Res>
    extends
        _$StatementInsightsResponseCopyWithImpl<
          $Res,
          _$StatementInsightsResponseImpl
        >
    implements _$$StatementInsightsResponseImplCopyWith<$Res> {
  __$$StatementInsightsResponseImplCopyWithImpl(
    _$StatementInsightsResponseImpl _value,
    $Res Function(_$StatementInsightsResponseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of StatementInsightsResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? statementId = null, Object? insights = null}) {
    return _then(
      _$StatementInsightsResponseImpl(
        statementId: null == statementId
            ? _value.statementId
            : statementId // ignore: cast_nullable_to_non_nullable
                  as String,
        insights: null == insights
            ? _value._insights
            : insights // ignore: cast_nullable_to_non_nullable
                  as List<Insight>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$StatementInsightsResponseImpl implements _StatementInsightsResponse {
  const _$StatementInsightsResponseImpl({
    required this.statementId,
    required final List<Insight> insights,
  }) : _insights = insights;

  factory _$StatementInsightsResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$StatementInsightsResponseImplFromJson(json);

  @override
  final String statementId;
  final List<Insight> _insights;
  @override
  List<Insight> get insights {
    if (_insights is EqualUnmodifiableListView) return _insights;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_insights);
  }

  @override
  String toString() {
    return 'StatementInsightsResponse(statementId: $statementId, insights: $insights)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StatementInsightsResponseImpl &&
            (identical(other.statementId, statementId) ||
                other.statementId == statementId) &&
            const DeepCollectionEquality().equals(other._insights, _insights));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    statementId,
    const DeepCollectionEquality().hash(_insights),
  );

  /// Create a copy of StatementInsightsResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StatementInsightsResponseImplCopyWith<_$StatementInsightsResponseImpl>
  get copyWith =>
      __$$StatementInsightsResponseImplCopyWithImpl<
        _$StatementInsightsResponseImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StatementInsightsResponseImplToJson(this);
  }
}

abstract class _StatementInsightsResponse implements StatementInsightsResponse {
  const factory _StatementInsightsResponse({
    required final String statementId,
    required final List<Insight> insights,
  }) = _$StatementInsightsResponseImpl;

  factory _StatementInsightsResponse.fromJson(Map<String, dynamic> json) =
      _$StatementInsightsResponseImpl.fromJson;

  @override
  String get statementId;
  @override
  List<Insight> get insights;

  /// Create a copy of StatementInsightsResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StatementInsightsResponseImplCopyWith<_$StatementInsightsResponseImpl>
  get copyWith => throw _privateConstructorUsedError;
}
