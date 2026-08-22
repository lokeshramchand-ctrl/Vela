// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'statement_analytics.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

CategoryBreakdownEntry _$CategoryBreakdownEntryFromJson(
  Map<String, dynamic> json,
) {
  return _CategoryBreakdownEntry.fromJson(json);
}

/// @nodoc
mixin _$CategoryBreakdownEntry {
  String get category => throw _privateConstructorUsedError;
  double get totalAmount => throw _privateConstructorUsedError;
  int get count => throw _privateConstructorUsedError;

  /// Serializes this CategoryBreakdownEntry to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CategoryBreakdownEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CategoryBreakdownEntryCopyWith<CategoryBreakdownEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CategoryBreakdownEntryCopyWith<$Res> {
  factory $CategoryBreakdownEntryCopyWith(
    CategoryBreakdownEntry value,
    $Res Function(CategoryBreakdownEntry) then,
  ) = _$CategoryBreakdownEntryCopyWithImpl<$Res, CategoryBreakdownEntry>;
  @useResult
  $Res call({String category, double totalAmount, int count});
}

/// @nodoc
class _$CategoryBreakdownEntryCopyWithImpl<
  $Res,
  $Val extends CategoryBreakdownEntry
>
    implements $CategoryBreakdownEntryCopyWith<$Res> {
  _$CategoryBreakdownEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CategoryBreakdownEntry
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
abstract class _$$CategoryBreakdownEntryImplCopyWith<$Res>
    implements $CategoryBreakdownEntryCopyWith<$Res> {
  factory _$$CategoryBreakdownEntryImplCopyWith(
    _$CategoryBreakdownEntryImpl value,
    $Res Function(_$CategoryBreakdownEntryImpl) then,
  ) = __$$CategoryBreakdownEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String category, double totalAmount, int count});
}

/// @nodoc
class __$$CategoryBreakdownEntryImplCopyWithImpl<$Res>
    extends
        _$CategoryBreakdownEntryCopyWithImpl<$Res, _$CategoryBreakdownEntryImpl>
    implements _$$CategoryBreakdownEntryImplCopyWith<$Res> {
  __$$CategoryBreakdownEntryImplCopyWithImpl(
    _$CategoryBreakdownEntryImpl _value,
    $Res Function(_$CategoryBreakdownEntryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CategoryBreakdownEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? category = null,
    Object? totalAmount = null,
    Object? count = null,
  }) {
    return _then(
      _$CategoryBreakdownEntryImpl(
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
class _$CategoryBreakdownEntryImpl implements _CategoryBreakdownEntry {
  const _$CategoryBreakdownEntryImpl({
    required this.category,
    required this.totalAmount,
    required this.count,
  });

  factory _$CategoryBreakdownEntryImpl.fromJson(Map<String, dynamic> json) =>
      _$$CategoryBreakdownEntryImplFromJson(json);

  @override
  final String category;
  @override
  final double totalAmount;
  @override
  final int count;

  @override
  String toString() {
    return 'CategoryBreakdownEntry(category: $category, totalAmount: $totalAmount, count: $count)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CategoryBreakdownEntryImpl &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.totalAmount, totalAmount) ||
                other.totalAmount == totalAmount) &&
            (identical(other.count, count) || other.count == count));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, category, totalAmount, count);

  /// Create a copy of CategoryBreakdownEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CategoryBreakdownEntryImplCopyWith<_$CategoryBreakdownEntryImpl>
  get copyWith =>
      __$$CategoryBreakdownEntryImplCopyWithImpl<_$CategoryBreakdownEntryImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$CategoryBreakdownEntryImplToJson(this);
  }
}

abstract class _CategoryBreakdownEntry implements CategoryBreakdownEntry {
  const factory _CategoryBreakdownEntry({
    required final String category,
    required final double totalAmount,
    required final int count,
  }) = _$CategoryBreakdownEntryImpl;

  factory _CategoryBreakdownEntry.fromJson(Map<String, dynamic> json) =
      _$CategoryBreakdownEntryImpl.fromJson;

  @override
  String get category;
  @override
  double get totalAmount;
  @override
  int get count;

  /// Create a copy of CategoryBreakdownEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CategoryBreakdownEntryImplCopyWith<_$CategoryBreakdownEntryImpl>
  get copyWith => throw _privateConstructorUsedError;
}

TopMerchantEntry _$TopMerchantEntryFromJson(Map<String, dynamic> json) {
  return _TopMerchantEntry.fromJson(json);
}

/// @nodoc
mixin _$TopMerchantEntry {
  String get merchant => throw _privateConstructorUsedError;
  double get totalAmount => throw _privateConstructorUsedError;
  int get count => throw _privateConstructorUsedError;

  /// Serializes this TopMerchantEntry to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TopMerchantEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TopMerchantEntryCopyWith<TopMerchantEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TopMerchantEntryCopyWith<$Res> {
  factory $TopMerchantEntryCopyWith(
    TopMerchantEntry value,
    $Res Function(TopMerchantEntry) then,
  ) = _$TopMerchantEntryCopyWithImpl<$Res, TopMerchantEntry>;
  @useResult
  $Res call({String merchant, double totalAmount, int count});
}

/// @nodoc
class _$TopMerchantEntryCopyWithImpl<$Res, $Val extends TopMerchantEntry>
    implements $TopMerchantEntryCopyWith<$Res> {
  _$TopMerchantEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TopMerchantEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? merchant = null,
    Object? totalAmount = null,
    Object? count = null,
  }) {
    return _then(
      _value.copyWith(
            merchant: null == merchant
                ? _value.merchant
                : merchant // ignore: cast_nullable_to_non_nullable
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
abstract class _$$TopMerchantEntryImplCopyWith<$Res>
    implements $TopMerchantEntryCopyWith<$Res> {
  factory _$$TopMerchantEntryImplCopyWith(
    _$TopMerchantEntryImpl value,
    $Res Function(_$TopMerchantEntryImpl) then,
  ) = __$$TopMerchantEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String merchant, double totalAmount, int count});
}

/// @nodoc
class __$$TopMerchantEntryImplCopyWithImpl<$Res>
    extends _$TopMerchantEntryCopyWithImpl<$Res, _$TopMerchantEntryImpl>
    implements _$$TopMerchantEntryImplCopyWith<$Res> {
  __$$TopMerchantEntryImplCopyWithImpl(
    _$TopMerchantEntryImpl _value,
    $Res Function(_$TopMerchantEntryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TopMerchantEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? merchant = null,
    Object? totalAmount = null,
    Object? count = null,
  }) {
    return _then(
      _$TopMerchantEntryImpl(
        merchant: null == merchant
            ? _value.merchant
            : merchant // ignore: cast_nullable_to_non_nullable
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
class _$TopMerchantEntryImpl implements _TopMerchantEntry {
  const _$TopMerchantEntryImpl({
    required this.merchant,
    required this.totalAmount,
    required this.count,
  });

  factory _$TopMerchantEntryImpl.fromJson(Map<String, dynamic> json) =>
      _$$TopMerchantEntryImplFromJson(json);

  @override
  final String merchant;
  @override
  final double totalAmount;
  @override
  final int count;

  @override
  String toString() {
    return 'TopMerchantEntry(merchant: $merchant, totalAmount: $totalAmount, count: $count)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TopMerchantEntryImpl &&
            (identical(other.merchant, merchant) ||
                other.merchant == merchant) &&
            (identical(other.totalAmount, totalAmount) ||
                other.totalAmount == totalAmount) &&
            (identical(other.count, count) || other.count == count));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, merchant, totalAmount, count);

  /// Create a copy of TopMerchantEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TopMerchantEntryImplCopyWith<_$TopMerchantEntryImpl> get copyWith =>
      __$$TopMerchantEntryImplCopyWithImpl<_$TopMerchantEntryImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$TopMerchantEntryImplToJson(this);
  }
}

abstract class _TopMerchantEntry implements TopMerchantEntry {
  const factory _TopMerchantEntry({
    required final String merchant,
    required final double totalAmount,
    required final int count,
  }) = _$TopMerchantEntryImpl;

  factory _TopMerchantEntry.fromJson(Map<String, dynamic> json) =
      _$TopMerchantEntryImpl.fromJson;

  @override
  String get merchant;
  @override
  double get totalAmount;
  @override
  int get count;

  /// Create a copy of TopMerchantEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TopMerchantEntryImplCopyWith<_$TopMerchantEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

DailyTrendEntry _$DailyTrendEntryFromJson(Map<String, dynamic> json) {
  return _DailyTrendEntry.fromJson(json);
}

/// @nodoc
mixin _$DailyTrendEntry {
  DateTime get date => throw _privateConstructorUsedError;
  double get totalAmount => throw _privateConstructorUsedError;
  int get count => throw _privateConstructorUsedError;

  /// Serializes this DailyTrendEntry to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DailyTrendEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DailyTrendEntryCopyWith<DailyTrendEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DailyTrendEntryCopyWith<$Res> {
  factory $DailyTrendEntryCopyWith(
    DailyTrendEntry value,
    $Res Function(DailyTrendEntry) then,
  ) = _$DailyTrendEntryCopyWithImpl<$Res, DailyTrendEntry>;
  @useResult
  $Res call({DateTime date, double totalAmount, int count});
}

/// @nodoc
class _$DailyTrendEntryCopyWithImpl<$Res, $Val extends DailyTrendEntry>
    implements $DailyTrendEntryCopyWith<$Res> {
  _$DailyTrendEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DailyTrendEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? totalAmount = null,
    Object? count = null,
  }) {
    return _then(
      _value.copyWith(
            date: null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                      as DateTime,
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
abstract class _$$DailyTrendEntryImplCopyWith<$Res>
    implements $DailyTrendEntryCopyWith<$Res> {
  factory _$$DailyTrendEntryImplCopyWith(
    _$DailyTrendEntryImpl value,
    $Res Function(_$DailyTrendEntryImpl) then,
  ) = __$$DailyTrendEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({DateTime date, double totalAmount, int count});
}

/// @nodoc
class __$$DailyTrendEntryImplCopyWithImpl<$Res>
    extends _$DailyTrendEntryCopyWithImpl<$Res, _$DailyTrendEntryImpl>
    implements _$$DailyTrendEntryImplCopyWith<$Res> {
  __$$DailyTrendEntryImplCopyWithImpl(
    _$DailyTrendEntryImpl _value,
    $Res Function(_$DailyTrendEntryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DailyTrendEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? totalAmount = null,
    Object? count = null,
  }) {
    return _then(
      _$DailyTrendEntryImpl(
        date: null == date
            ? _value.date
            : date // ignore: cast_nullable_to_non_nullable
                  as DateTime,
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
class _$DailyTrendEntryImpl implements _DailyTrendEntry {
  const _$DailyTrendEntryImpl({
    required this.date,
    required this.totalAmount,
    required this.count,
  });

  factory _$DailyTrendEntryImpl.fromJson(Map<String, dynamic> json) =>
      _$$DailyTrendEntryImplFromJson(json);

  @override
  final DateTime date;
  @override
  final double totalAmount;
  @override
  final int count;

  @override
  String toString() {
    return 'DailyTrendEntry(date: $date, totalAmount: $totalAmount, count: $count)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DailyTrendEntryImpl &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.totalAmount, totalAmount) ||
                other.totalAmount == totalAmount) &&
            (identical(other.count, count) || other.count == count));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, date, totalAmount, count);

  /// Create a copy of DailyTrendEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DailyTrendEntryImplCopyWith<_$DailyTrendEntryImpl> get copyWith =>
      __$$DailyTrendEntryImplCopyWithImpl<_$DailyTrendEntryImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$DailyTrendEntryImplToJson(this);
  }
}

abstract class _DailyTrendEntry implements DailyTrendEntry {
  const factory _DailyTrendEntry({
    required final DateTime date,
    required final double totalAmount,
    required final int count,
  }) = _$DailyTrendEntryImpl;

  factory _DailyTrendEntry.fromJson(Map<String, dynamic> json) =
      _$DailyTrendEntryImpl.fromJson;

  @override
  DateTime get date;
  @override
  double get totalAmount;
  @override
  int get count;

  /// Create a copy of DailyTrendEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DailyTrendEntryImplCopyWith<_$DailyTrendEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

RecurringPaymentEntry _$RecurringPaymentEntryFromJson(
  Map<String, dynamic> json,
) {
  return _RecurringPaymentEntry.fromJson(json);
}

/// @nodoc
mixin _$RecurringPaymentEntry {
  String get merchant => throw _privateConstructorUsedError;
  double get estimatedMonthlyCost => throw _privateConstructorUsedError;
  double get periodicityScore => throw _privateConstructorUsedError;
  int get occurrences => throw _privateConstructorUsedError;

  /// Serializes this RecurringPaymentEntry to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RecurringPaymentEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RecurringPaymentEntryCopyWith<RecurringPaymentEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecurringPaymentEntryCopyWith<$Res> {
  factory $RecurringPaymentEntryCopyWith(
    RecurringPaymentEntry value,
    $Res Function(RecurringPaymentEntry) then,
  ) = _$RecurringPaymentEntryCopyWithImpl<$Res, RecurringPaymentEntry>;
  @useResult
  $Res call({
    String merchant,
    double estimatedMonthlyCost,
    double periodicityScore,
    int occurrences,
  });
}

/// @nodoc
class _$RecurringPaymentEntryCopyWithImpl<
  $Res,
  $Val extends RecurringPaymentEntry
>
    implements $RecurringPaymentEntryCopyWith<$Res> {
  _$RecurringPaymentEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RecurringPaymentEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? merchant = null,
    Object? estimatedMonthlyCost = null,
    Object? periodicityScore = null,
    Object? occurrences = null,
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
            occurrences: null == occurrences
                ? _value.occurrences
                : occurrences // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RecurringPaymentEntryImplCopyWith<$Res>
    implements $RecurringPaymentEntryCopyWith<$Res> {
  factory _$$RecurringPaymentEntryImplCopyWith(
    _$RecurringPaymentEntryImpl value,
    $Res Function(_$RecurringPaymentEntryImpl) then,
  ) = __$$RecurringPaymentEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String merchant,
    double estimatedMonthlyCost,
    double periodicityScore,
    int occurrences,
  });
}

/// @nodoc
class __$$RecurringPaymentEntryImplCopyWithImpl<$Res>
    extends
        _$RecurringPaymentEntryCopyWithImpl<$Res, _$RecurringPaymentEntryImpl>
    implements _$$RecurringPaymentEntryImplCopyWith<$Res> {
  __$$RecurringPaymentEntryImplCopyWithImpl(
    _$RecurringPaymentEntryImpl _value,
    $Res Function(_$RecurringPaymentEntryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RecurringPaymentEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? merchant = null,
    Object? estimatedMonthlyCost = null,
    Object? periodicityScore = null,
    Object? occurrences = null,
  }) {
    return _then(
      _$RecurringPaymentEntryImpl(
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
        occurrences: null == occurrences
            ? _value.occurrences
            : occurrences // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RecurringPaymentEntryImpl implements _RecurringPaymentEntry {
  const _$RecurringPaymentEntryImpl({
    required this.merchant,
    required this.estimatedMonthlyCost,
    required this.periodicityScore,
    required this.occurrences,
  });

  factory _$RecurringPaymentEntryImpl.fromJson(Map<String, dynamic> json) =>
      _$$RecurringPaymentEntryImplFromJson(json);

  @override
  final String merchant;
  @override
  final double estimatedMonthlyCost;
  @override
  final double periodicityScore;
  @override
  final int occurrences;

  @override
  String toString() {
    return 'RecurringPaymentEntry(merchant: $merchant, estimatedMonthlyCost: $estimatedMonthlyCost, periodicityScore: $periodicityScore, occurrences: $occurrences)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecurringPaymentEntryImpl &&
            (identical(other.merchant, merchant) ||
                other.merchant == merchant) &&
            (identical(other.estimatedMonthlyCost, estimatedMonthlyCost) ||
                other.estimatedMonthlyCost == estimatedMonthlyCost) &&
            (identical(other.periodicityScore, periodicityScore) ||
                other.periodicityScore == periodicityScore) &&
            (identical(other.occurrences, occurrences) ||
                other.occurrences == occurrences));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    merchant,
    estimatedMonthlyCost,
    periodicityScore,
    occurrences,
  );

  /// Create a copy of RecurringPaymentEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RecurringPaymentEntryImplCopyWith<_$RecurringPaymentEntryImpl>
  get copyWith =>
      __$$RecurringPaymentEntryImplCopyWithImpl<_$RecurringPaymentEntryImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$RecurringPaymentEntryImplToJson(this);
  }
}

abstract class _RecurringPaymentEntry implements RecurringPaymentEntry {
  const factory _RecurringPaymentEntry({
    required final String merchant,
    required final double estimatedMonthlyCost,
    required final double periodicityScore,
    required final int occurrences,
  }) = _$RecurringPaymentEntryImpl;

  factory _RecurringPaymentEntry.fromJson(Map<String, dynamic> json) =
      _$RecurringPaymentEntryImpl.fromJson;

  @override
  String get merchant;
  @override
  double get estimatedMonthlyCost;
  @override
  double get periodicityScore;
  @override
  int get occurrences;

  /// Create a copy of RecurringPaymentEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RecurringPaymentEntryImplCopyWith<_$RecurringPaymentEntryImpl>
  get copyWith => throw _privateConstructorUsedError;
}

StatementAnalytics _$StatementAnalyticsFromJson(Map<String, dynamic> json) {
  return _StatementAnalytics.fromJson(json);
}

/// @nodoc
mixin _$StatementAnalytics {
  String get statementId => throw _privateConstructorUsedError;
  double get totalSpend => throw _privateConstructorUsedError;
  double get totalIncome => throw _privateConstructorUsedError;
  double get net => throw _privateConstructorUsedError;
  double get averageTransactionValue => throw _privateConstructorUsedError;
  int get transactionCount => throw _privateConstructorUsedError;
  int get failedTransactionCount => throw _privateConstructorUsedError;
  List<CategoryBreakdownEntry> get categoryBreakdown =>
      throw _privateConstructorUsedError;
  List<TopMerchantEntry> get topMerchants => throw _privateConstructorUsedError;
  List<DailyTrendEntry> get dailyTrend => throw _privateConstructorUsedError;
  List<RecurringPaymentEntry> get recurringPayments =>
      throw _privateConstructorUsedError;
  DateTime get generatedAt => throw _privateConstructorUsedError;

  /// Serializes this StatementAnalytics to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of StatementAnalytics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StatementAnalyticsCopyWith<StatementAnalytics> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StatementAnalyticsCopyWith<$Res> {
  factory $StatementAnalyticsCopyWith(
    StatementAnalytics value,
    $Res Function(StatementAnalytics) then,
  ) = _$StatementAnalyticsCopyWithImpl<$Res, StatementAnalytics>;
  @useResult
  $Res call({
    String statementId,
    double totalSpend,
    double totalIncome,
    double net,
    double averageTransactionValue,
    int transactionCount,
    int failedTransactionCount,
    List<CategoryBreakdownEntry> categoryBreakdown,
    List<TopMerchantEntry> topMerchants,
    List<DailyTrendEntry> dailyTrend,
    List<RecurringPaymentEntry> recurringPayments,
    DateTime generatedAt,
  });
}

/// @nodoc
class _$StatementAnalyticsCopyWithImpl<$Res, $Val extends StatementAnalytics>
    implements $StatementAnalyticsCopyWith<$Res> {
  _$StatementAnalyticsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StatementAnalytics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? statementId = null,
    Object? totalSpend = null,
    Object? totalIncome = null,
    Object? net = null,
    Object? averageTransactionValue = null,
    Object? transactionCount = null,
    Object? failedTransactionCount = null,
    Object? categoryBreakdown = null,
    Object? topMerchants = null,
    Object? dailyTrend = null,
    Object? recurringPayments = null,
    Object? generatedAt = null,
  }) {
    return _then(
      _value.copyWith(
            statementId: null == statementId
                ? _value.statementId
                : statementId // ignore: cast_nullable_to_non_nullable
                      as String,
            totalSpend: null == totalSpend
                ? _value.totalSpend
                : totalSpend // ignore: cast_nullable_to_non_nullable
                      as double,
            totalIncome: null == totalIncome
                ? _value.totalIncome
                : totalIncome // ignore: cast_nullable_to_non_nullable
                      as double,
            net: null == net
                ? _value.net
                : net // ignore: cast_nullable_to_non_nullable
                      as double,
            averageTransactionValue: null == averageTransactionValue
                ? _value.averageTransactionValue
                : averageTransactionValue // ignore: cast_nullable_to_non_nullable
                      as double,
            transactionCount: null == transactionCount
                ? _value.transactionCount
                : transactionCount // ignore: cast_nullable_to_non_nullable
                      as int,
            failedTransactionCount: null == failedTransactionCount
                ? _value.failedTransactionCount
                : failedTransactionCount // ignore: cast_nullable_to_non_nullable
                      as int,
            categoryBreakdown: null == categoryBreakdown
                ? _value.categoryBreakdown
                : categoryBreakdown // ignore: cast_nullable_to_non_nullable
                      as List<CategoryBreakdownEntry>,
            topMerchants: null == topMerchants
                ? _value.topMerchants
                : topMerchants // ignore: cast_nullable_to_non_nullable
                      as List<TopMerchantEntry>,
            dailyTrend: null == dailyTrend
                ? _value.dailyTrend
                : dailyTrend // ignore: cast_nullable_to_non_nullable
                      as List<DailyTrendEntry>,
            recurringPayments: null == recurringPayments
                ? _value.recurringPayments
                : recurringPayments // ignore: cast_nullable_to_non_nullable
                      as List<RecurringPaymentEntry>,
            generatedAt: null == generatedAt
                ? _value.generatedAt
                : generatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$StatementAnalyticsImplCopyWith<$Res>
    implements $StatementAnalyticsCopyWith<$Res> {
  factory _$$StatementAnalyticsImplCopyWith(
    _$StatementAnalyticsImpl value,
    $Res Function(_$StatementAnalyticsImpl) then,
  ) = __$$StatementAnalyticsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String statementId,
    double totalSpend,
    double totalIncome,
    double net,
    double averageTransactionValue,
    int transactionCount,
    int failedTransactionCount,
    List<CategoryBreakdownEntry> categoryBreakdown,
    List<TopMerchantEntry> topMerchants,
    List<DailyTrendEntry> dailyTrend,
    List<RecurringPaymentEntry> recurringPayments,
    DateTime generatedAt,
  });
}

/// @nodoc
class __$$StatementAnalyticsImplCopyWithImpl<$Res>
    extends _$StatementAnalyticsCopyWithImpl<$Res, _$StatementAnalyticsImpl>
    implements _$$StatementAnalyticsImplCopyWith<$Res> {
  __$$StatementAnalyticsImplCopyWithImpl(
    _$StatementAnalyticsImpl _value,
    $Res Function(_$StatementAnalyticsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of StatementAnalytics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? statementId = null,
    Object? totalSpend = null,
    Object? totalIncome = null,
    Object? net = null,
    Object? averageTransactionValue = null,
    Object? transactionCount = null,
    Object? failedTransactionCount = null,
    Object? categoryBreakdown = null,
    Object? topMerchants = null,
    Object? dailyTrend = null,
    Object? recurringPayments = null,
    Object? generatedAt = null,
  }) {
    return _then(
      _$StatementAnalyticsImpl(
        statementId: null == statementId
            ? _value.statementId
            : statementId // ignore: cast_nullable_to_non_nullable
                  as String,
        totalSpend: null == totalSpend
            ? _value.totalSpend
            : totalSpend // ignore: cast_nullable_to_non_nullable
                  as double,
        totalIncome: null == totalIncome
            ? _value.totalIncome
            : totalIncome // ignore: cast_nullable_to_non_nullable
                  as double,
        net: null == net
            ? _value.net
            : net // ignore: cast_nullable_to_non_nullable
                  as double,
        averageTransactionValue: null == averageTransactionValue
            ? _value.averageTransactionValue
            : averageTransactionValue // ignore: cast_nullable_to_non_nullable
                  as double,
        transactionCount: null == transactionCount
            ? _value.transactionCount
            : transactionCount // ignore: cast_nullable_to_non_nullable
                  as int,
        failedTransactionCount: null == failedTransactionCount
            ? _value.failedTransactionCount
            : failedTransactionCount // ignore: cast_nullable_to_non_nullable
                  as int,
        categoryBreakdown: null == categoryBreakdown
            ? _value._categoryBreakdown
            : categoryBreakdown // ignore: cast_nullable_to_non_nullable
                  as List<CategoryBreakdownEntry>,
        topMerchants: null == topMerchants
            ? _value._topMerchants
            : topMerchants // ignore: cast_nullable_to_non_nullable
                  as List<TopMerchantEntry>,
        dailyTrend: null == dailyTrend
            ? _value._dailyTrend
            : dailyTrend // ignore: cast_nullable_to_non_nullable
                  as List<DailyTrendEntry>,
        recurringPayments: null == recurringPayments
            ? _value._recurringPayments
            : recurringPayments // ignore: cast_nullable_to_non_nullable
                  as List<RecurringPaymentEntry>,
        generatedAt: null == generatedAt
            ? _value.generatedAt
            : generatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$StatementAnalyticsImpl implements _StatementAnalytics {
  const _$StatementAnalyticsImpl({
    required this.statementId,
    required this.totalSpend,
    required this.totalIncome,
    required this.net,
    required this.averageTransactionValue,
    required this.transactionCount,
    required this.failedTransactionCount,
    required final List<CategoryBreakdownEntry> categoryBreakdown,
    required final List<TopMerchantEntry> topMerchants,
    required final List<DailyTrendEntry> dailyTrend,
    required final List<RecurringPaymentEntry> recurringPayments,
    required this.generatedAt,
  }) : _categoryBreakdown = categoryBreakdown,
       _topMerchants = topMerchants,
       _dailyTrend = dailyTrend,
       _recurringPayments = recurringPayments;

  factory _$StatementAnalyticsImpl.fromJson(Map<String, dynamic> json) =>
      _$$StatementAnalyticsImplFromJson(json);

  @override
  final String statementId;
  @override
  final double totalSpend;
  @override
  final double totalIncome;
  @override
  final double net;
  @override
  final double averageTransactionValue;
  @override
  final int transactionCount;
  @override
  final int failedTransactionCount;
  final List<CategoryBreakdownEntry> _categoryBreakdown;
  @override
  List<CategoryBreakdownEntry> get categoryBreakdown {
    if (_categoryBreakdown is EqualUnmodifiableListView)
      return _categoryBreakdown;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_categoryBreakdown);
  }

  final List<TopMerchantEntry> _topMerchants;
  @override
  List<TopMerchantEntry> get topMerchants {
    if (_topMerchants is EqualUnmodifiableListView) return _topMerchants;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_topMerchants);
  }

  final List<DailyTrendEntry> _dailyTrend;
  @override
  List<DailyTrendEntry> get dailyTrend {
    if (_dailyTrend is EqualUnmodifiableListView) return _dailyTrend;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_dailyTrend);
  }

  final List<RecurringPaymentEntry> _recurringPayments;
  @override
  List<RecurringPaymentEntry> get recurringPayments {
    if (_recurringPayments is EqualUnmodifiableListView)
      return _recurringPayments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_recurringPayments);
  }

  @override
  final DateTime generatedAt;

  @override
  String toString() {
    return 'StatementAnalytics(statementId: $statementId, totalSpend: $totalSpend, totalIncome: $totalIncome, net: $net, averageTransactionValue: $averageTransactionValue, transactionCount: $transactionCount, failedTransactionCount: $failedTransactionCount, categoryBreakdown: $categoryBreakdown, topMerchants: $topMerchants, dailyTrend: $dailyTrend, recurringPayments: $recurringPayments, generatedAt: $generatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StatementAnalyticsImpl &&
            (identical(other.statementId, statementId) ||
                other.statementId == statementId) &&
            (identical(other.totalSpend, totalSpend) ||
                other.totalSpend == totalSpend) &&
            (identical(other.totalIncome, totalIncome) ||
                other.totalIncome == totalIncome) &&
            (identical(other.net, net) || other.net == net) &&
            (identical(
                  other.averageTransactionValue,
                  averageTransactionValue,
                ) ||
                other.averageTransactionValue == averageTransactionValue) &&
            (identical(other.transactionCount, transactionCount) ||
                other.transactionCount == transactionCount) &&
            (identical(other.failedTransactionCount, failedTransactionCount) ||
                other.failedTransactionCount == failedTransactionCount) &&
            const DeepCollectionEquality().equals(
              other._categoryBreakdown,
              _categoryBreakdown,
            ) &&
            const DeepCollectionEquality().equals(
              other._topMerchants,
              _topMerchants,
            ) &&
            const DeepCollectionEquality().equals(
              other._dailyTrend,
              _dailyTrend,
            ) &&
            const DeepCollectionEquality().equals(
              other._recurringPayments,
              _recurringPayments,
            ) &&
            (identical(other.generatedAt, generatedAt) ||
                other.generatedAt == generatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    statementId,
    totalSpend,
    totalIncome,
    net,
    averageTransactionValue,
    transactionCount,
    failedTransactionCount,
    const DeepCollectionEquality().hash(_categoryBreakdown),
    const DeepCollectionEquality().hash(_topMerchants),
    const DeepCollectionEquality().hash(_dailyTrend),
    const DeepCollectionEquality().hash(_recurringPayments),
    generatedAt,
  );

  /// Create a copy of StatementAnalytics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StatementAnalyticsImplCopyWith<_$StatementAnalyticsImpl> get copyWith =>
      __$$StatementAnalyticsImplCopyWithImpl<_$StatementAnalyticsImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$StatementAnalyticsImplToJson(this);
  }
}

abstract class _StatementAnalytics implements StatementAnalytics {
  const factory _StatementAnalytics({
    required final String statementId,
    required final double totalSpend,
    required final double totalIncome,
    required final double net,
    required final double averageTransactionValue,
    required final int transactionCount,
    required final int failedTransactionCount,
    required final List<CategoryBreakdownEntry> categoryBreakdown,
    required final List<TopMerchantEntry> topMerchants,
    required final List<DailyTrendEntry> dailyTrend,
    required final List<RecurringPaymentEntry> recurringPayments,
    required final DateTime generatedAt,
  }) = _$StatementAnalyticsImpl;

  factory _StatementAnalytics.fromJson(Map<String, dynamic> json) =
      _$StatementAnalyticsImpl.fromJson;

  @override
  String get statementId;
  @override
  double get totalSpend;
  @override
  double get totalIncome;
  @override
  double get net;
  @override
  double get averageTransactionValue;
  @override
  int get transactionCount;
  @override
  int get failedTransactionCount;
  @override
  List<CategoryBreakdownEntry> get categoryBreakdown;
  @override
  List<TopMerchantEntry> get topMerchants;
  @override
  List<DailyTrendEntry> get dailyTrend;
  @override
  List<RecurringPaymentEntry> get recurringPayments;
  @override
  DateTime get generatedAt;

  /// Create a copy of StatementAnalytics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StatementAnalyticsImplCopyWith<_$StatementAnalyticsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
