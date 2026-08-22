// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'analytics_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

CategoryPatternEntry _$CategoryPatternEntryFromJson(Map<String, dynamic> json) {
  return _CategoryPatternEntry.fromJson(json);
}

/// @nodoc
mixin _$CategoryPatternEntry {
  String get category => throw _privateConstructorUsedError;
  double get totalAmount => throw _privateConstructorUsedError;
  int get count => throw _privateConstructorUsedError;

  /// Serializes this CategoryPatternEntry to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CategoryPatternEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CategoryPatternEntryCopyWith<CategoryPatternEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CategoryPatternEntryCopyWith<$Res> {
  factory $CategoryPatternEntryCopyWith(
    CategoryPatternEntry value,
    $Res Function(CategoryPatternEntry) then,
  ) = _$CategoryPatternEntryCopyWithImpl<$Res, CategoryPatternEntry>;
  @useResult
  $Res call({String category, double totalAmount, int count});
}

/// @nodoc
class _$CategoryPatternEntryCopyWithImpl<
  $Res,
  $Val extends CategoryPatternEntry
>
    implements $CategoryPatternEntryCopyWith<$Res> {
  _$CategoryPatternEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CategoryPatternEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? category = null,
    Object? totalAmount = null,
    Object? count = null,
  }) {
    return _then(
      _value.copyWith(
            category: null == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                      as String,
            totalAmount: null == totalAmount
                ? _value.totalAmount
                : totalAmount // ignore: cast_nullable_to_non_nullable
                      as double,
            count: null == count
                ? _value.count
                : count // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CategoryPatternEntryImplCopyWith<$Res>
    implements $CategoryPatternEntryCopyWith<$Res> {
  factory _$$CategoryPatternEntryImplCopyWith(
    _$CategoryPatternEntryImpl value,
    $Res Function(_$CategoryPatternEntryImpl) then,
  ) = __$$CategoryPatternEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String category, double totalAmount, int count});
}

/// @nodoc
class __$$CategoryPatternEntryImplCopyWithImpl<$Res>
    extends _$CategoryPatternEntryCopyWithImpl<$Res, _$CategoryPatternEntryImpl>
    implements _$$CategoryPatternEntryImplCopyWith<$Res> {
  __$$CategoryPatternEntryImplCopyWithImpl(
    _$CategoryPatternEntryImpl _value,
    $Res Function(_$CategoryPatternEntryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CategoryPatternEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? category = null,
    Object? totalAmount = null,
    Object? count = null,
  }) {
    return _then(
      _$CategoryPatternEntryImpl(
        category: null == category
            ? _value.category
            : category // ignore: cast_nullable_to_non_nullable
                  as String,
        totalAmount: null == totalAmount
            ? _value.totalAmount
            : totalAmount // ignore: cast_nullable_to_non_nullable
                  as double,
        count: null == count
            ? _value.count
            : count // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CategoryPatternEntryImpl implements _CategoryPatternEntry {
  const _$CategoryPatternEntryImpl({
    this.category = 'Unknown',
    this.totalAmount = 0,
    this.count = 0,
  });

  factory _$CategoryPatternEntryImpl.fromJson(Map<String, dynamic> json) =>
      _$$CategoryPatternEntryImplFromJson(json);

  @override
  @JsonKey()
  final String category;
  @override
  @JsonKey()
  final double totalAmount;
  @override
  @JsonKey()
  final int count;

  @override
  String toString() {
    return 'CategoryPatternEntry(category: $category, totalAmount: $totalAmount, count: $count)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CategoryPatternEntryImpl &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.totalAmount, totalAmount) ||
                other.totalAmount == totalAmount) &&
            (identical(other.count, count) || other.count == count));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, category, totalAmount, count);

  /// Create a copy of CategoryPatternEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CategoryPatternEntryImplCopyWith<_$CategoryPatternEntryImpl>
  get copyWith =>
      __$$CategoryPatternEntryImplCopyWithImpl<_$CategoryPatternEntryImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$CategoryPatternEntryImplToJson(this);
  }
}

abstract class _CategoryPatternEntry implements CategoryPatternEntry {
  const factory _CategoryPatternEntry({
    final String category,
    final double totalAmount,
    final int count,
  }) = _$CategoryPatternEntryImpl;

  factory _CategoryPatternEntry.fromJson(Map<String, dynamic> json) =
      _$CategoryPatternEntryImpl.fromJson;

  @override
  String get category;
  @override
  double get totalAmount;
  @override
  int get count;

  /// Create a copy of CategoryPatternEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CategoryPatternEntryImplCopyWith<_$CategoryPatternEntryImpl>
  get copyWith => throw _privateConstructorUsedError;
}

MerchantPatternEntry _$MerchantPatternEntryFromJson(Map<String, dynamic> json) {
  return _MerchantPatternEntry.fromJson(json);
}

/// @nodoc
mixin _$MerchantPatternEntry {
  String? get merchant => throw _privateConstructorUsedError;
  int get visits => throw _privateConstructorUsedError;
  double get spent => throw _privateConstructorUsedError;

  /// Serializes this MerchantPatternEntry to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MerchantPatternEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MerchantPatternEntryCopyWith<MerchantPatternEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MerchantPatternEntryCopyWith<$Res> {
  factory $MerchantPatternEntryCopyWith(
    MerchantPatternEntry value,
    $Res Function(MerchantPatternEntry) then,
  ) = _$MerchantPatternEntryCopyWithImpl<$Res, MerchantPatternEntry>;
  @useResult
  $Res call({String? merchant, int visits, double spent});
}

/// @nodoc
class _$MerchantPatternEntryCopyWithImpl<
  $Res,
  $Val extends MerchantPatternEntry
>
    implements $MerchantPatternEntryCopyWith<$Res> {
  _$MerchantPatternEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MerchantPatternEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? merchant = freezed,
    Object? visits = null,
    Object? spent = null,
  }) {
    return _then(
      _value.copyWith(
            merchant: freezed == merchant
                ? _value.merchant
                : merchant // ignore: cast_nullable_to_non_nullable
                      as String?,
            visits: null == visits
                ? _value.visits
                : visits // ignore: cast_nullable_to_non_nullable
                      as int,
            spent: null == spent
                ? _value.spent
                : spent // ignore: cast_nullable_to_non_nullable
                      as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MerchantPatternEntryImplCopyWith<$Res>
    implements $MerchantPatternEntryCopyWith<$Res> {
  factory _$$MerchantPatternEntryImplCopyWith(
    _$MerchantPatternEntryImpl value,
    $Res Function(_$MerchantPatternEntryImpl) then,
  ) = __$$MerchantPatternEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String? merchant, int visits, double spent});
}

/// @nodoc
class __$$MerchantPatternEntryImplCopyWithImpl<$Res>
    extends _$MerchantPatternEntryCopyWithImpl<$Res, _$MerchantPatternEntryImpl>
    implements _$$MerchantPatternEntryImplCopyWith<$Res> {
  __$$MerchantPatternEntryImplCopyWithImpl(
    _$MerchantPatternEntryImpl _value,
    $Res Function(_$MerchantPatternEntryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MerchantPatternEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? merchant = freezed,
    Object? visits = null,
    Object? spent = null,
  }) {
    return _then(
      _$MerchantPatternEntryImpl(
        merchant: freezed == merchant
            ? _value.merchant
            : merchant // ignore: cast_nullable_to_non_nullable
                  as String?,
        visits: null == visits
            ? _value.visits
            : visits // ignore: cast_nullable_to_non_nullable
                  as int,
        spent: null == spent
            ? _value.spent
            : spent // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MerchantPatternEntryImpl implements _MerchantPatternEntry {
  const _$MerchantPatternEntryImpl({
    this.merchant,
    this.visits = 0,
    this.spent = 0,
  });

  factory _$MerchantPatternEntryImpl.fromJson(Map<String, dynamic> json) =>
      _$$MerchantPatternEntryImplFromJson(json);

  @override
  final String? merchant;
  @override
  @JsonKey()
  final int visits;
  @override
  @JsonKey()
  final double spent;

  @override
  String toString() {
    return 'MerchantPatternEntry(merchant: $merchant, visits: $visits, spent: $spent)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MerchantPatternEntryImpl &&
            (identical(other.merchant, merchant) ||
                other.merchant == merchant) &&
            (identical(other.visits, visits) || other.visits == visits) &&
            (identical(other.spent, spent) || other.spent == spent));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, merchant, visits, spent);

  /// Create a copy of MerchantPatternEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MerchantPatternEntryImplCopyWith<_$MerchantPatternEntryImpl>
  get copyWith =>
      __$$MerchantPatternEntryImplCopyWithImpl<_$MerchantPatternEntryImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$MerchantPatternEntryImplToJson(this);
  }
}

abstract class _MerchantPatternEntry implements MerchantPatternEntry {
  const factory _MerchantPatternEntry({
    final String? merchant,
    final int visits,
    final double spent,
  }) = _$MerchantPatternEntryImpl;

  factory _MerchantPatternEntry.fromJson(Map<String, dynamic> json) =
      _$MerchantPatternEntryImpl.fromJson;

  @override
  String? get merchant;
  @override
  int get visits;
  @override
  double get spent;

  /// Create a copy of MerchantPatternEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MerchantPatternEntryImplCopyWith<_$MerchantPatternEntryImpl>
  get copyWith => throw _privateConstructorUsedError;
}

SubscriptionDetail _$SubscriptionDetailFromJson(Map<String, dynamic> json) {
  return _SubscriptionDetail.fromJson(json);
}

/// @nodoc
mixin _$SubscriptionDetail {
  String get merchant => throw _privateConstructorUsedError;
  double get estimatedMonthlyCost => throw _privateConstructorUsedError;
  double get periodicityScore => throw _privateConstructorUsedError;
  DateTime? get lastBilled => throw _privateConstructorUsedError;

  /// Serializes this SubscriptionDetail to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SubscriptionDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SubscriptionDetailCopyWith<SubscriptionDetail> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SubscriptionDetailCopyWith<$Res> {
  factory $SubscriptionDetailCopyWith(
    SubscriptionDetail value,
    $Res Function(SubscriptionDetail) then,
  ) = _$SubscriptionDetailCopyWithImpl<$Res, SubscriptionDetail>;
  @useResult
  $Res call({
    String merchant,
    double estimatedMonthlyCost,
    double periodicityScore,
    DateTime? lastBilled,
  });
}

/// @nodoc
class _$SubscriptionDetailCopyWithImpl<$Res, $Val extends SubscriptionDetail>
    implements $SubscriptionDetailCopyWith<$Res> {
  _$SubscriptionDetailCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SubscriptionDetail
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? merchant = null,
    Object? estimatedMonthlyCost = null,
    Object? periodicityScore = null,
    Object? lastBilled = freezed,
  }) {
    return _then(
      _value.copyWith(
            merchant: null == merchant
                ? _value.merchant
                : merchant // ignore: cast_nullable_to_non_nullable
                      as String,
            estimatedMonthlyCost: null == estimatedMonthlyCost
                ? _value.estimatedMonthlyCost
                : estimatedMonthlyCost // ignore: cast_nullable_to_non_nullable
                      as double,
            periodicityScore: null == periodicityScore
                ? _value.periodicityScore
                : periodicityScore // ignore: cast_nullable_to_non_nullable
                      as double,
            lastBilled: freezed == lastBilled
                ? _value.lastBilled
                : lastBilled // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SubscriptionDetailImplCopyWith<$Res>
    implements $SubscriptionDetailCopyWith<$Res> {
  factory _$$SubscriptionDetailImplCopyWith(
    _$SubscriptionDetailImpl value,
    $Res Function(_$SubscriptionDetailImpl) then,
  ) = __$$SubscriptionDetailImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String merchant,
    double estimatedMonthlyCost,
    double periodicityScore,
    DateTime? lastBilled,
  });
}

/// @nodoc
class __$$SubscriptionDetailImplCopyWithImpl<$Res>
    extends _$SubscriptionDetailCopyWithImpl<$Res, _$SubscriptionDetailImpl>
    implements _$$SubscriptionDetailImplCopyWith<$Res> {
  __$$SubscriptionDetailImplCopyWithImpl(
    _$SubscriptionDetailImpl _value,
    $Res Function(_$SubscriptionDetailImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SubscriptionDetail
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? merchant = null,
    Object? estimatedMonthlyCost = null,
    Object? periodicityScore = null,
    Object? lastBilled = freezed,
  }) {
    return _then(
      _$SubscriptionDetailImpl(
        merchant: null == merchant
            ? _value.merchant
            : merchant // ignore: cast_nullable_to_non_nullable
                  as String,
        estimatedMonthlyCost: null == estimatedMonthlyCost
            ? _value.estimatedMonthlyCost
            : estimatedMonthlyCost // ignore: cast_nullable_to_non_nullable
                  as double,
        periodicityScore: null == periodicityScore
            ? _value.periodicityScore
            : periodicityScore // ignore: cast_nullable_to_non_nullable
                  as double,
        lastBilled: freezed == lastBilled
            ? _value.lastBilled
            : lastBilled // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SubscriptionDetailImpl implements _SubscriptionDetail {
  const _$SubscriptionDetailImpl({
    required this.merchant,
    required this.estimatedMonthlyCost,
    required this.periodicityScore,
    this.lastBilled,
  });

  factory _$SubscriptionDetailImpl.fromJson(Map<String, dynamic> json) =>
      _$$SubscriptionDetailImplFromJson(json);

  @override
  final String merchant;
  @override
  final double estimatedMonthlyCost;
  @override
  final double periodicityScore;
  @override
  final DateTime? lastBilled;

  @override
  String toString() {
    return 'SubscriptionDetail(merchant: $merchant, estimatedMonthlyCost: $estimatedMonthlyCost, periodicityScore: $periodicityScore, lastBilled: $lastBilled)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SubscriptionDetailImpl &&
            (identical(other.merchant, merchant) ||
                other.merchant == merchant) &&
            (identical(other.estimatedMonthlyCost, estimatedMonthlyCost) ||
                other.estimatedMonthlyCost == estimatedMonthlyCost) &&
            (identical(other.periodicityScore, periodicityScore) ||
                other.periodicityScore == periodicityScore) &&
            (identical(other.lastBilled, lastBilled) ||
                other.lastBilled == lastBilled));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    merchant,
    estimatedMonthlyCost,
    periodicityScore,
    lastBilled,
  );

  /// Create a copy of SubscriptionDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SubscriptionDetailImplCopyWith<_$SubscriptionDetailImpl> get copyWith =>
      __$$SubscriptionDetailImplCopyWithImpl<_$SubscriptionDetailImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$SubscriptionDetailImplToJson(this);
  }
}

abstract class _SubscriptionDetail implements SubscriptionDetail {
  const factory _SubscriptionDetail({
    required final String merchant,
    required final double estimatedMonthlyCost,
    required final double periodicityScore,
    final DateTime? lastBilled,
  }) = _$SubscriptionDetailImpl;

  factory _SubscriptionDetail.fromJson(Map<String, dynamic> json) =
      _$SubscriptionDetailImpl.fromJson;

  @override
  String get merchant;
  @override
  double get estimatedMonthlyCost;
  @override
  double get periodicityScore;
  @override
  DateTime? get lastBilled;

  /// Create a copy of SubscriptionDetail
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SubscriptionDetailImplCopyWith<_$SubscriptionDetailImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SubscriptionsSummary _$SubscriptionsSummaryFromJson(Map<String, dynamic> json) {
  return _SubscriptionsSummary.fromJson(json);
}

/// @nodoc
mixin _$SubscriptionsSummary {
  int get activeSubscriptions => throw _privateConstructorUsedError;
  double get totalMonthlyBurn => throw _privateConstructorUsedError;
  List<SubscriptionDetail> get details => throw _privateConstructorUsedError;

  /// Serializes this SubscriptionsSummary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SubscriptionsSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SubscriptionsSummaryCopyWith<SubscriptionsSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SubscriptionsSummaryCopyWith<$Res> {
  factory $SubscriptionsSummaryCopyWith(
    SubscriptionsSummary value,
    $Res Function(SubscriptionsSummary) then,
  ) = _$SubscriptionsSummaryCopyWithImpl<$Res, SubscriptionsSummary>;
  @useResult
  $Res call({
    int activeSubscriptions,
    double totalMonthlyBurn,
    List<SubscriptionDetail> details,
  });
}

/// @nodoc
class _$SubscriptionsSummaryCopyWithImpl<
  $Res,
  $Val extends SubscriptionsSummary
>
    implements $SubscriptionsSummaryCopyWith<$Res> {
  _$SubscriptionsSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SubscriptionsSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? activeSubscriptions = null,
    Object? totalMonthlyBurn = null,
    Object? details = null,
  }) {
    return _then(
      _value.copyWith(
            activeSubscriptions: null == activeSubscriptions
                ? _value.activeSubscriptions
                : activeSubscriptions // ignore: cast_nullable_to_non_nullable
                      as int,
            totalMonthlyBurn: null == totalMonthlyBurn
                ? _value.totalMonthlyBurn
                : totalMonthlyBurn // ignore: cast_nullable_to_non_nullable
                      as double,
            details: null == details
                ? _value.details
                : details // ignore: cast_nullable_to_non_nullable
                      as List<SubscriptionDetail>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SubscriptionsSummaryImplCopyWith<$Res>
    implements $SubscriptionsSummaryCopyWith<$Res> {
  factory _$$SubscriptionsSummaryImplCopyWith(
    _$SubscriptionsSummaryImpl value,
    $Res Function(_$SubscriptionsSummaryImpl) then,
  ) = __$$SubscriptionsSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int activeSubscriptions,
    double totalMonthlyBurn,
    List<SubscriptionDetail> details,
  });
}

/// @nodoc
class __$$SubscriptionsSummaryImplCopyWithImpl<$Res>
    extends _$SubscriptionsSummaryCopyWithImpl<$Res, _$SubscriptionsSummaryImpl>
    implements _$$SubscriptionsSummaryImplCopyWith<$Res> {
  __$$SubscriptionsSummaryImplCopyWithImpl(
    _$SubscriptionsSummaryImpl _value,
    $Res Function(_$SubscriptionsSummaryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SubscriptionsSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? activeSubscriptions = null,
    Object? totalMonthlyBurn = null,
    Object? details = null,
  }) {
    return _then(
      _$SubscriptionsSummaryImpl(
        activeSubscriptions: null == activeSubscriptions
            ? _value.activeSubscriptions
            : activeSubscriptions // ignore: cast_nullable_to_non_nullable
                  as int,
        totalMonthlyBurn: null == totalMonthlyBurn
            ? _value.totalMonthlyBurn
            : totalMonthlyBurn // ignore: cast_nullable_to_non_nullable
                  as double,
        details: null == details
            ? _value._details
            : details // ignore: cast_nullable_to_non_nullable
                  as List<SubscriptionDetail>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SubscriptionsSummaryImpl implements _SubscriptionsSummary {
  const _$SubscriptionsSummaryImpl({
    this.activeSubscriptions = 0,
    this.totalMonthlyBurn = 0,
    final List<SubscriptionDetail> details = const <SubscriptionDetail>[],
  }) : _details = details;

  factory _$SubscriptionsSummaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$SubscriptionsSummaryImplFromJson(json);

  @override
  @JsonKey()
  final int activeSubscriptions;
  @override
  @JsonKey()
  final double totalMonthlyBurn;
  final List<SubscriptionDetail> _details;
  @override
  @JsonKey()
  List<SubscriptionDetail> get details {
    if (_details is EqualUnmodifiableListView) return _details;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_details);
  }

  @override
  String toString() {
    return 'SubscriptionsSummary(activeSubscriptions: $activeSubscriptions, totalMonthlyBurn: $totalMonthlyBurn, details: $details)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SubscriptionsSummaryImpl &&
            (identical(other.activeSubscriptions, activeSubscriptions) ||
                other.activeSubscriptions == activeSubscriptions) &&
            (identical(other.totalMonthlyBurn, totalMonthlyBurn) ||
                other.totalMonthlyBurn == totalMonthlyBurn) &&
            const DeepCollectionEquality().equals(other._details, _details));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    activeSubscriptions,
    totalMonthlyBurn,
    const DeepCollectionEquality().hash(_details),
  );

  /// Create a copy of SubscriptionsSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SubscriptionsSummaryImplCopyWith<_$SubscriptionsSummaryImpl>
  get copyWith =>
      __$$SubscriptionsSummaryImplCopyWithImpl<_$SubscriptionsSummaryImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$SubscriptionsSummaryImplToJson(this);
  }
}

abstract class _SubscriptionsSummary implements SubscriptionsSummary {
  const factory _SubscriptionsSummary({
    final int activeSubscriptions,
    final double totalMonthlyBurn,
    final List<SubscriptionDetail> details,
  }) = _$SubscriptionsSummaryImpl;

  factory _SubscriptionsSummary.fromJson(Map<String, dynamic> json) =
      _$SubscriptionsSummaryImpl.fromJson;

  @override
  int get activeSubscriptions;
  @override
  double get totalMonthlyBurn;
  @override
  List<SubscriptionDetail> get details;

  /// Create a copy of SubscriptionsSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SubscriptionsSummaryImplCopyWith<_$SubscriptionsSummaryImpl>
  get copyWith => throw _privateConstructorUsedError;
}

MoMTrend _$MoMTrendFromJson(Map<String, dynamic> json) {
  return _MoMTrend.fromJson(json);
}

/// @nodoc
mixin _$MoMTrend {
  double get currentSpend => throw _privateConstructorUsedError;
  double get previousSpend => throw _privateConstructorUsedError;
  double get momGrowthPercentage => throw _privateConstructorUsedError;
  String get trend => throw _privateConstructorUsedError;

  /// Serializes this MoMTrend to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MoMTrend
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MoMTrendCopyWith<MoMTrend> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MoMTrendCopyWith<$Res> {
  factory $MoMTrendCopyWith(MoMTrend value, $Res Function(MoMTrend) then) =
      _$MoMTrendCopyWithImpl<$Res, MoMTrend>;
  @useResult
  $Res call({
    double currentSpend,
    double previousSpend,
    double momGrowthPercentage,
    String trend,
  });
}

/// @nodoc
class _$MoMTrendCopyWithImpl<$Res, $Val extends MoMTrend>
    implements $MoMTrendCopyWith<$Res> {
  _$MoMTrendCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MoMTrend
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? currentSpend = null,
    Object? previousSpend = null,
    Object? momGrowthPercentage = null,
    Object? trend = null,
  }) {
    return _then(
      _value.copyWith(
            currentSpend: null == currentSpend
                ? _value.currentSpend
                : currentSpend // ignore: cast_nullable_to_non_nullable
                      as double,
            previousSpend: null == previousSpend
                ? _value.previousSpend
                : previousSpend // ignore: cast_nullable_to_non_nullable
                      as double,
            momGrowthPercentage: null == momGrowthPercentage
                ? _value.momGrowthPercentage
                : momGrowthPercentage // ignore: cast_nullable_to_non_nullable
                      as double,
            trend: null == trend
                ? _value.trend
                : trend // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MoMTrendImplCopyWith<$Res>
    implements $MoMTrendCopyWith<$Res> {
  factory _$$MoMTrendImplCopyWith(
    _$MoMTrendImpl value,
    $Res Function(_$MoMTrendImpl) then,
  ) = __$$MoMTrendImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    double currentSpend,
    double previousSpend,
    double momGrowthPercentage,
    String trend,
  });
}

/// @nodoc
class __$$MoMTrendImplCopyWithImpl<$Res>
    extends _$MoMTrendCopyWithImpl<$Res, _$MoMTrendImpl>
    implements _$$MoMTrendImplCopyWith<$Res> {
  __$$MoMTrendImplCopyWithImpl(
    _$MoMTrendImpl _value,
    $Res Function(_$MoMTrendImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MoMTrend
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? currentSpend = null,
    Object? previousSpend = null,
    Object? momGrowthPercentage = null,
    Object? trend = null,
  }) {
    return _then(
      _$MoMTrendImpl(
        currentSpend: null == currentSpend
            ? _value.currentSpend
            : currentSpend // ignore: cast_nullable_to_non_nullable
                  as double,
        previousSpend: null == previousSpend
            ? _value.previousSpend
            : previousSpend // ignore: cast_nullable_to_non_nullable
                  as double,
        momGrowthPercentage: null == momGrowthPercentage
            ? _value.momGrowthPercentage
            : momGrowthPercentage // ignore: cast_nullable_to_non_nullable
                  as double,
        trend: null == trend
            ? _value.trend
            : trend // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MoMTrendImpl extends _MoMTrend {
  const _$MoMTrendImpl({
    this.currentSpend = 0,
    this.previousSpend = 0,
    this.momGrowthPercentage = 0,
    this.trend = 'down',
  }) : super._();

  factory _$MoMTrendImpl.fromJson(Map<String, dynamic> json) =>
      _$$MoMTrendImplFromJson(json);

  @override
  @JsonKey()
  final double currentSpend;
  @override
  @JsonKey()
  final double previousSpend;
  @override
  @JsonKey()
  final double momGrowthPercentage;
  @override
  @JsonKey()
  final String trend;

  @override
  String toString() {
    return 'MoMTrend(currentSpend: $currentSpend, previousSpend: $previousSpend, momGrowthPercentage: $momGrowthPercentage, trend: $trend)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MoMTrendImpl &&
            (identical(other.currentSpend, currentSpend) ||
                other.currentSpend == currentSpend) &&
            (identical(other.previousSpend, previousSpend) ||
                other.previousSpend == previousSpend) &&
            (identical(other.momGrowthPercentage, momGrowthPercentage) ||
                other.momGrowthPercentage == momGrowthPercentage) &&
            (identical(other.trend, trend) || other.trend == trend));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    currentSpend,
    previousSpend,
    momGrowthPercentage,
    trend,
  );

  /// Create a copy of MoMTrend
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MoMTrendImplCopyWith<_$MoMTrendImpl> get copyWith =>
      __$$MoMTrendImplCopyWithImpl<_$MoMTrendImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MoMTrendImplToJson(this);
  }
}

abstract class _MoMTrend extends MoMTrend {
  const factory _MoMTrend({
    final double currentSpend,
    final double previousSpend,
    final double momGrowthPercentage,
    final String trend,
  }) = _$MoMTrendImpl;
  const _MoMTrend._() : super._();

  factory _MoMTrend.fromJson(Map<String, dynamic> json) =
      _$MoMTrendImpl.fromJson;

  @override
  double get currentSpend;
  @override
  double get previousSpend;
  @override
  double get momGrowthPercentage;
  @override
  String get trend;

  /// Create a copy of MoMTrend
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MoMTrendImplCopyWith<_$MoMTrendImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AnomalyCheckResult _$AnomalyCheckResultFromJson(Map<String, dynamic> json) {
  return _AnomalyCheckResult.fromJson(json);
}

/// @nodoc
mixin _$AnomalyCheckResult {
  bool get isAnomaly => throw _privateConstructorUsedError;
  String get reason => throw _privateConstructorUsedError;
  double? get confidence => throw _privateConstructorUsedError;

  /// Serializes this AnomalyCheckResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AnomalyCheckResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AnomalyCheckResultCopyWith<AnomalyCheckResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AnomalyCheckResultCopyWith<$Res> {
  factory $AnomalyCheckResultCopyWith(
    AnomalyCheckResult value,
    $Res Function(AnomalyCheckResult) then,
  ) = _$AnomalyCheckResultCopyWithImpl<$Res, AnomalyCheckResult>;
  @useResult
  $Res call({bool isAnomaly, String reason, double? confidence});
}

/// @nodoc
class _$AnomalyCheckResultCopyWithImpl<$Res, $Val extends AnomalyCheckResult>
    implements $AnomalyCheckResultCopyWith<$Res> {
  _$AnomalyCheckResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AnomalyCheckResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isAnomaly = null,
    Object? reason = null,
    Object? confidence = freezed,
  }) {
    return _then(
      _value.copyWith(
            isAnomaly: null == isAnomaly
                ? _value.isAnomaly
                : isAnomaly // ignore: cast_nullable_to_non_nullable
                      as bool,
            reason: null == reason
                ? _value.reason
                : reason // ignore: cast_nullable_to_non_nullable
                      as String,
            confidence: freezed == confidence
                ? _value.confidence
                : confidence // ignore: cast_nullable_to_non_nullable
                      as double?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AnomalyCheckResultImplCopyWith<$Res>
    implements $AnomalyCheckResultCopyWith<$Res> {
  factory _$$AnomalyCheckResultImplCopyWith(
    _$AnomalyCheckResultImpl value,
    $Res Function(_$AnomalyCheckResultImpl) then,
  ) = __$$AnomalyCheckResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool isAnomaly, String reason, double? confidence});
}

/// @nodoc
class __$$AnomalyCheckResultImplCopyWithImpl<$Res>
    extends _$AnomalyCheckResultCopyWithImpl<$Res, _$AnomalyCheckResultImpl>
    implements _$$AnomalyCheckResultImplCopyWith<$Res> {
  __$$AnomalyCheckResultImplCopyWithImpl(
    _$AnomalyCheckResultImpl _value,
    $Res Function(_$AnomalyCheckResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AnomalyCheckResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isAnomaly = null,
    Object? reason = null,
    Object? confidence = freezed,
  }) {
    return _then(
      _$AnomalyCheckResultImpl(
        isAnomaly: null == isAnomaly
            ? _value.isAnomaly
            : isAnomaly // ignore: cast_nullable_to_non_nullable
                  as bool,
        reason: null == reason
            ? _value.reason
            : reason // ignore: cast_nullable_to_non_nullable
                  as String,
        confidence: freezed == confidence
            ? _value.confidence
            : confidence // ignore: cast_nullable_to_non_nullable
                  as double?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AnomalyCheckResultImpl implements _AnomalyCheckResult {
  const _$AnomalyCheckResultImpl({
    required this.isAnomaly,
    required this.reason,
    this.confidence,
  });

  factory _$AnomalyCheckResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$AnomalyCheckResultImplFromJson(json);

  @override
  final bool isAnomaly;
  @override
  final String reason;
  @override
  final double? confidence;

  @override
  String toString() {
    return 'AnomalyCheckResult(isAnomaly: $isAnomaly, reason: $reason, confidence: $confidence)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AnomalyCheckResultImpl &&
            (identical(other.isAnomaly, isAnomaly) ||
                other.isAnomaly == isAnomaly) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, isAnomaly, reason, confidence);

  /// Create a copy of AnomalyCheckResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AnomalyCheckResultImplCopyWith<_$AnomalyCheckResultImpl> get copyWith =>
      __$$AnomalyCheckResultImplCopyWithImpl<_$AnomalyCheckResultImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AnomalyCheckResultImplToJson(this);
  }
}

abstract class _AnomalyCheckResult implements AnomalyCheckResult {
  const factory _AnomalyCheckResult({
    required final bool isAnomaly,
    required final String reason,
    final double? confidence,
  }) = _$AnomalyCheckResultImpl;

  factory _AnomalyCheckResult.fromJson(Map<String, dynamic> json) =
      _$AnomalyCheckResultImpl.fromJson;

  @override
  bool get isAnomaly;
  @override
  String get reason;
  @override
  double? get confidence;

  /// Create a copy of AnomalyCheckResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AnomalyCheckResultImplCopyWith<_$AnomalyCheckResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
