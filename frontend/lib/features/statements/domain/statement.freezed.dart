// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'statement.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Statement _$StatementFromJson(Map<String, dynamic> json) {
  return _Statement.fromJson(json);
}

/// @nodoc
mixin _$Statement {
  String get id => throw _privateConstructorUsedError;
  String get originalFilename => throw _privateConstructorUsedError;
  int get fileSizeBytes => throw _privateConstructorUsedError;
  int? get pageCount => throw _privateConstructorUsedError;
  DateTime get periodStart => throw _privateConstructorUsedError;
  DateTime get periodEnd => throw _privateConstructorUsedError;
  double? get declaredSentAmount => throw _privateConstructorUsedError;
  double? get declaredReceivedAmount => throw _privateConstructorUsedError;
  double? get computedSentAmount => throw _privateConstructorUsedError;
  double? get computedReceivedAmount => throw _privateConstructorUsedError;
  bool? get reconciliationOk => throw _privateConstructorUsedError;
  int get transactionCount => throw _privateConstructorUsedError;
  ProcessingStatus get processingStatus => throw _privateConstructorUsedError;
  String? get currentJobId => throw _privateConstructorUsedError;
  String? get errorMessage => throw _privateConstructorUsedError;
  String get analyticsVersion => throw _privateConstructorUsedError;
  DateTime get uploadedAt => throw _privateConstructorUsedError;
  DateTime? get processingCompletedAt => throw _privateConstructorUsedError;
  int? get processingDurationMs => throw _privateConstructorUsedError;

  /// Serializes this Statement to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Statement
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StatementCopyWith<Statement> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StatementCopyWith<$Res> {
  factory $StatementCopyWith(Statement value, $Res Function(Statement) then) =
      _$StatementCopyWithImpl<$Res, Statement>;
  @useResult
  $Res call({
    String id,
    String originalFilename,
    int fileSizeBytes,
    int? pageCount,
    DateTime periodStart,
    DateTime periodEnd,
    double? declaredSentAmount,
    double? declaredReceivedAmount,
    double? computedSentAmount,
    double? computedReceivedAmount,
    bool? reconciliationOk,
    int transactionCount,
    ProcessingStatus processingStatus,
    String? currentJobId,
    String? errorMessage,
    String analyticsVersion,
    DateTime uploadedAt,
    DateTime? processingCompletedAt,
    int? processingDurationMs,
  });
}

/// @nodoc
class _$StatementCopyWithImpl<$Res, $Val extends Statement>
    implements $StatementCopyWith<$Res> {
  _$StatementCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Statement
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? originalFilename = null,
    Object? fileSizeBytes = null,
    Object? pageCount = freezed,
    Object? periodStart = null,
    Object? periodEnd = null,
    Object? declaredSentAmount = freezed,
    Object? declaredReceivedAmount = freezed,
    Object? computedSentAmount = freezed,
    Object? computedReceivedAmount = freezed,
    Object? reconciliationOk = freezed,
    Object? transactionCount = null,
    Object? processingStatus = null,
    Object? currentJobId = freezed,
    Object? errorMessage = freezed,
    Object? analyticsVersion = null,
    Object? uploadedAt = null,
    Object? processingCompletedAt = freezed,
    Object? processingDurationMs = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            originalFilename: null == originalFilename
                ? _value.originalFilename
                : originalFilename // ignore: cast_nullable_to_non_nullable
                      as String,
            fileSizeBytes: null == fileSizeBytes
                ? _value.fileSizeBytes
                : fileSizeBytes // ignore: cast_nullable_to_non_nullable
                      as int,
            pageCount: freezed == pageCount
                ? _value.pageCount
                : pageCount // ignore: cast_nullable_to_non_nullable
                      as int?,
            periodStart: null == periodStart
                ? _value.periodStart
                : periodStart // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            periodEnd: null == periodEnd
                ? _value.periodEnd
                : periodEnd // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            declaredSentAmount: freezed == declaredSentAmount
                ? _value.declaredSentAmount
                : declaredSentAmount // ignore: cast_nullable_to_non_nullable
                      as double?,
            declaredReceivedAmount: freezed == declaredReceivedAmount
                ? _value.declaredReceivedAmount
                : declaredReceivedAmount // ignore: cast_nullable_to_non_nullable
                      as double?,
            computedSentAmount: freezed == computedSentAmount
                ? _value.computedSentAmount
                : computedSentAmount // ignore: cast_nullable_to_non_nullable
                      as double?,
            computedReceivedAmount: freezed == computedReceivedAmount
                ? _value.computedReceivedAmount
                : computedReceivedAmount // ignore: cast_nullable_to_non_nullable
                      as double?,
            reconciliationOk: freezed == reconciliationOk
                ? _value.reconciliationOk
                : reconciliationOk // ignore: cast_nullable_to_non_nullable
                      as bool?,
            transactionCount: null == transactionCount
                ? _value.transactionCount
                : transactionCount // ignore: cast_nullable_to_non_nullable
                      as int,
            processingStatus: null == processingStatus
                ? _value.processingStatus
                : processingStatus // ignore: cast_nullable_to_non_nullable
                      as ProcessingStatus,
            currentJobId: freezed == currentJobId
                ? _value.currentJobId
                : currentJobId // ignore: cast_nullable_to_non_nullable
                      as String?,
            errorMessage: freezed == errorMessage
                ? _value.errorMessage
                : errorMessage // ignore: cast_nullable_to_non_nullable
                      as String?,
            analyticsVersion: null == analyticsVersion
                ? _value.analyticsVersion
                : analyticsVersion // ignore: cast_nullable_to_non_nullable
                      as String,
            uploadedAt: null == uploadedAt
                ? _value.uploadedAt
                : uploadedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            processingCompletedAt: freezed == processingCompletedAt
                ? _value.processingCompletedAt
                : processingCompletedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            processingDurationMs: freezed == processingDurationMs
                ? _value.processingDurationMs
                : processingDurationMs // ignore: cast_nullable_to_non_nullable
                      as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$StatementImplCopyWith<$Res>
    implements $StatementCopyWith<$Res> {
  factory _$$StatementImplCopyWith(
    _$StatementImpl value,
    $Res Function(_$StatementImpl) then,
  ) = __$$StatementImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String originalFilename,
    int fileSizeBytes,
    int? pageCount,
    DateTime periodStart,
    DateTime periodEnd,
    double? declaredSentAmount,
    double? declaredReceivedAmount,
    double? computedSentAmount,
    double? computedReceivedAmount,
    bool? reconciliationOk,
    int transactionCount,
    ProcessingStatus processingStatus,
    String? currentJobId,
    String? errorMessage,
    String analyticsVersion,
    DateTime uploadedAt,
    DateTime? processingCompletedAt,
    int? processingDurationMs,
  });
}

/// @nodoc
class __$$StatementImplCopyWithImpl<$Res>
    extends _$StatementCopyWithImpl<$Res, _$StatementImpl>
    implements _$$StatementImplCopyWith<$Res> {
  __$$StatementImplCopyWithImpl(
    _$StatementImpl _value,
    $Res Function(_$StatementImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Statement
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? originalFilename = null,
    Object? fileSizeBytes = null,
    Object? pageCount = freezed,
    Object? periodStart = null,
    Object? periodEnd = null,
    Object? declaredSentAmount = freezed,
    Object? declaredReceivedAmount = freezed,
    Object? computedSentAmount = freezed,
    Object? computedReceivedAmount = freezed,
    Object? reconciliationOk = freezed,
    Object? transactionCount = null,
    Object? processingStatus = null,
    Object? currentJobId = freezed,
    Object? errorMessage = freezed,
    Object? analyticsVersion = null,
    Object? uploadedAt = null,
    Object? processingCompletedAt = freezed,
    Object? processingDurationMs = freezed,
  }) {
    return _then(
      _$StatementImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        originalFilename: null == originalFilename
            ? _value.originalFilename
            : originalFilename // ignore: cast_nullable_to_non_nullable
                  as String,
        fileSizeBytes: null == fileSizeBytes
            ? _value.fileSizeBytes
            : fileSizeBytes // ignore: cast_nullable_to_non_nullable
                  as int,
        pageCount: freezed == pageCount
            ? _value.pageCount
            : pageCount // ignore: cast_nullable_to_non_nullable
                  as int?,
        periodStart: null == periodStart
            ? _value.periodStart
            : periodStart // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        periodEnd: null == periodEnd
            ? _value.periodEnd
            : periodEnd // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        declaredSentAmount: freezed == declaredSentAmount
            ? _value.declaredSentAmount
            : declaredSentAmount // ignore: cast_nullable_to_non_nullable
                  as double?,
        declaredReceivedAmount: freezed == declaredReceivedAmount
            ? _value.declaredReceivedAmount
            : declaredReceivedAmount // ignore: cast_nullable_to_non_nullable
                  as double?,
        computedSentAmount: freezed == computedSentAmount
            ? _value.computedSentAmount
            : computedSentAmount // ignore: cast_nullable_to_non_nullable
                  as double?,
        computedReceivedAmount: freezed == computedReceivedAmount
            ? _value.computedReceivedAmount
            : computedReceivedAmount // ignore: cast_nullable_to_non_nullable
                  as double?,
        reconciliationOk: freezed == reconciliationOk
            ? _value.reconciliationOk
            : reconciliationOk // ignore: cast_nullable_to_non_nullable
                  as bool?,
        transactionCount: null == transactionCount
            ? _value.transactionCount
            : transactionCount // ignore: cast_nullable_to_non_nullable
                  as int,
        processingStatus: null == processingStatus
            ? _value.processingStatus
            : processingStatus // ignore: cast_nullable_to_non_nullable
                  as ProcessingStatus,
        currentJobId: freezed == currentJobId
            ? _value.currentJobId
            : currentJobId // ignore: cast_nullable_to_non_nullable
                  as String?,
        errorMessage: freezed == errorMessage
            ? _value.errorMessage
            : errorMessage // ignore: cast_nullable_to_non_nullable
                  as String?,
        analyticsVersion: null == analyticsVersion
            ? _value.analyticsVersion
            : analyticsVersion // ignore: cast_nullable_to_non_nullable
                  as String,
        uploadedAt: null == uploadedAt
            ? _value.uploadedAt
            : uploadedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        processingCompletedAt: freezed == processingCompletedAt
            ? _value.processingCompletedAt
            : processingCompletedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        processingDurationMs: freezed == processingDurationMs
            ? _value.processingDurationMs
            : processingDurationMs // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$StatementImpl implements _Statement {
  const _$StatementImpl({
    required this.id,
    required this.originalFilename,
    required this.fileSizeBytes,
    this.pageCount,
    required this.periodStart,
    required this.periodEnd,
    this.declaredSentAmount,
    this.declaredReceivedAmount,
    this.computedSentAmount,
    this.computedReceivedAmount,
    this.reconciliationOk,
    required this.transactionCount,
    required this.processingStatus,
    this.currentJobId,
    this.errorMessage,
    required this.analyticsVersion,
    required this.uploadedAt,
    this.processingCompletedAt,
    this.processingDurationMs,
  });

  factory _$StatementImpl.fromJson(Map<String, dynamic> json) =>
      _$$StatementImplFromJson(json);

  @override
  final String id;
  @override
  final String originalFilename;
  @override
  final int fileSizeBytes;
  @override
  final int? pageCount;
  @override
  final DateTime periodStart;
  @override
  final DateTime periodEnd;
  @override
  final double? declaredSentAmount;
  @override
  final double? declaredReceivedAmount;
  @override
  final double? computedSentAmount;
  @override
  final double? computedReceivedAmount;
  @override
  final bool? reconciliationOk;
  @override
  final int transactionCount;
  @override
  final ProcessingStatus processingStatus;
  @override
  final String? currentJobId;
  @override
  final String? errorMessage;
  @override
  final String analyticsVersion;
  @override
  final DateTime uploadedAt;
  @override
  final DateTime? processingCompletedAt;
  @override
  final int? processingDurationMs;

  @override
  String toString() {
    return 'Statement(id: $id, originalFilename: $originalFilename, fileSizeBytes: $fileSizeBytes, pageCount: $pageCount, periodStart: $periodStart, periodEnd: $periodEnd, declaredSentAmount: $declaredSentAmount, declaredReceivedAmount: $declaredReceivedAmount, computedSentAmount: $computedSentAmount, computedReceivedAmount: $computedReceivedAmount, reconciliationOk: $reconciliationOk, transactionCount: $transactionCount, processingStatus: $processingStatus, currentJobId: $currentJobId, errorMessage: $errorMessage, analyticsVersion: $analyticsVersion, uploadedAt: $uploadedAt, processingCompletedAt: $processingCompletedAt, processingDurationMs: $processingDurationMs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StatementImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.originalFilename, originalFilename) ||
                other.originalFilename == originalFilename) &&
            (identical(other.fileSizeBytes, fileSizeBytes) ||
                other.fileSizeBytes == fileSizeBytes) &&
            (identical(other.pageCount, pageCount) ||
                other.pageCount == pageCount) &&
            (identical(other.periodStart, periodStart) ||
                other.periodStart == periodStart) &&
            (identical(other.periodEnd, periodEnd) ||
                other.periodEnd == periodEnd) &&
            (identical(other.declaredSentAmount, declaredSentAmount) ||
                other.declaredSentAmount == declaredSentAmount) &&
            (identical(other.declaredReceivedAmount, declaredReceivedAmount) ||
                other.declaredReceivedAmount == declaredReceivedAmount) &&
            (identical(other.computedSentAmount, computedSentAmount) ||
                other.computedSentAmount == computedSentAmount) &&
            (identical(other.computedReceivedAmount, computedReceivedAmount) ||
                other.computedReceivedAmount == computedReceivedAmount) &&
            (identical(other.reconciliationOk, reconciliationOk) ||
                other.reconciliationOk == reconciliationOk) &&
            (identical(other.transactionCount, transactionCount) ||
                other.transactionCount == transactionCount) &&
            (identical(other.processingStatus, processingStatus) ||
                other.processingStatus == processingStatus) &&
            (identical(other.currentJobId, currentJobId) ||
                other.currentJobId == currentJobId) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage) &&
            (identical(other.analyticsVersion, analyticsVersion) ||
                other.analyticsVersion == analyticsVersion) &&
            (identical(other.uploadedAt, uploadedAt) ||
                other.uploadedAt == uploadedAt) &&
            (identical(other.processingCompletedAt, processingCompletedAt) ||
                other.processingCompletedAt == processingCompletedAt) &&
            (identical(other.processingDurationMs, processingDurationMs) ||
                other.processingDurationMs == processingDurationMs));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    originalFilename,
    fileSizeBytes,
    pageCount,
    periodStart,
    periodEnd,
    declaredSentAmount,
    declaredReceivedAmount,
    computedSentAmount,
    computedReceivedAmount,
    reconciliationOk,
    transactionCount,
    processingStatus,
    currentJobId,
    errorMessage,
    analyticsVersion,
    uploadedAt,
    processingCompletedAt,
    processingDurationMs,
  ]);

  /// Create a copy of Statement
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StatementImplCopyWith<_$StatementImpl> get copyWith =>
      __$$StatementImplCopyWithImpl<_$StatementImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StatementImplToJson(this);
  }
}

abstract class _Statement implements Statement {
  const factory _Statement({
    required final String id,
    required final String originalFilename,
    required final int fileSizeBytes,
    final int? pageCount,
    required final DateTime periodStart,
    required final DateTime periodEnd,
    final double? declaredSentAmount,
    final double? declaredReceivedAmount,
    final double? computedSentAmount,
    final double? computedReceivedAmount,
    final bool? reconciliationOk,
    required final int transactionCount,
    required final ProcessingStatus processingStatus,
    final String? currentJobId,
    final String? errorMessage,
    required final String analyticsVersion,
    required final DateTime uploadedAt,
    final DateTime? processingCompletedAt,
    final int? processingDurationMs,
  }) = _$StatementImpl;

  factory _Statement.fromJson(Map<String, dynamic> json) =
      _$StatementImpl.fromJson;

  @override
  String get id;
  @override
  String get originalFilename;
  @override
  int get fileSizeBytes;
  @override
  int? get pageCount;
  @override
  DateTime get periodStart;
  @override
  DateTime get periodEnd;
  @override
  double? get declaredSentAmount;
  @override
  double? get declaredReceivedAmount;
  @override
  double? get computedSentAmount;
  @override
  double? get computedReceivedAmount;
  @override
  bool? get reconciliationOk;
  @override
  int get transactionCount;
  @override
  ProcessingStatus get processingStatus;
  @override
  String? get currentJobId;
  @override
  String? get errorMessage;
  @override
  String get analyticsVersion;
  @override
  DateTime get uploadedAt;
  @override
  DateTime? get processingCompletedAt;
  @override
  int? get processingDurationMs;

  /// Create a copy of Statement
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StatementImplCopyWith<_$StatementImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

StatementListResponse _$StatementListResponseFromJson(
  Map<String, dynamic> json,
) {
  return _StatementListResponse.fromJson(json);
}

/// @nodoc
mixin _$StatementListResponse {
  List<Statement> get items => throw _privateConstructorUsedError;
  int get page => throw _privateConstructorUsedError;
  int get pageSize => throw _privateConstructorUsedError;
  int get total => throw _privateConstructorUsedError;
  int get totalPages => throw _privateConstructorUsedError;

  /// Serializes this StatementListResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of StatementListResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StatementListResponseCopyWith<StatementListResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StatementListResponseCopyWith<$Res> {
  factory $StatementListResponseCopyWith(
    StatementListResponse value,
    $Res Function(StatementListResponse) then,
  ) = _$StatementListResponseCopyWithImpl<$Res, StatementListResponse>;
  @useResult
  $Res call({
    List<Statement> items,
    int page,
    int pageSize,
    int total,
    int totalPages,
  });
}

/// @nodoc
class _$StatementListResponseCopyWithImpl<
  $Res,
  $Val extends StatementListResponse
>
    implements $StatementListResponseCopyWith<$Res> {
  _$StatementListResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StatementListResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? items = null,
    Object? page = null,
    Object? pageSize = null,
    Object? total = null,
    Object? totalPages = null,
  }) {
    return _then(
      _value.copyWith(
            items: null == items
                ? _value.items
                : items // ignore: cast_nullable_to_non_nullable
                      as List<Statement>,
            page: null == page
                ? _value.page
                : page // ignore: cast_nullable_to_non_nullable
                      as int,
            pageSize: null == pageSize
                ? _value.pageSize
                : pageSize // ignore: cast_nullable_to_non_nullable
                      as int,
            total: null == total
                ? _value.total
                : total // ignore: cast_nullable_to_non_nullable
                      as int,
            totalPages: null == totalPages
                ? _value.totalPages
                : totalPages // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$StatementListResponseImplCopyWith<$Res>
    implements $StatementListResponseCopyWith<$Res> {
  factory _$$StatementListResponseImplCopyWith(
    _$StatementListResponseImpl value,
    $Res Function(_$StatementListResponseImpl) then,
  ) = __$$StatementListResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<Statement> items,
    int page,
    int pageSize,
    int total,
    int totalPages,
  });
}

/// @nodoc
class __$$StatementListResponseImplCopyWithImpl<$Res>
    extends
        _$StatementListResponseCopyWithImpl<$Res, _$StatementListResponseImpl>
    implements _$$StatementListResponseImplCopyWith<$Res> {
  __$$StatementListResponseImplCopyWithImpl(
    _$StatementListResponseImpl _value,
    $Res Function(_$StatementListResponseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of StatementListResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? items = null,
    Object? page = null,
    Object? pageSize = null,
    Object? total = null,
    Object? totalPages = null,
  }) {
    return _then(
      _$StatementListResponseImpl(
        items: null == items
            ? _value._items
            : items // ignore: cast_nullable_to_non_nullable
                  as List<Statement>,
        page: null == page
            ? _value.page
            : page // ignore: cast_nullable_to_non_nullable
                  as int,
        pageSize: null == pageSize
            ? _value.pageSize
            : pageSize // ignore: cast_nullable_to_non_nullable
                  as int,
        total: null == total
            ? _value.total
            : total // ignore: cast_nullable_to_non_nullable
                  as int,
        totalPages: null == totalPages
            ? _value.totalPages
            : totalPages // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$StatementListResponseImpl implements _StatementListResponse {
  const _$StatementListResponseImpl({
    required final List<Statement> items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  }) : _items = items;

  factory _$StatementListResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$StatementListResponseImplFromJson(json);

  final List<Statement> _items;
  @override
  List<Statement> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  final int page;
  @override
  final int pageSize;
  @override
  final int total;
  @override
  final int totalPages;

  @override
  String toString() {
    return 'StatementListResponse(items: $items, page: $page, pageSize: $pageSize, total: $total, totalPages: $totalPages)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StatementListResponseImpl &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.page, page) || other.page == page) &&
            (identical(other.pageSize, pageSize) ||
                other.pageSize == pageSize) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.totalPages, totalPages) ||
                other.totalPages == totalPages));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_items),
    page,
    pageSize,
    total,
    totalPages,
  );

  /// Create a copy of StatementListResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StatementListResponseImplCopyWith<_$StatementListResponseImpl>
  get copyWith =>
      __$$StatementListResponseImplCopyWithImpl<_$StatementListResponseImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$StatementListResponseImplToJson(this);
  }
}

abstract class _StatementListResponse implements StatementListResponse {
  const factory _StatementListResponse({
    required final List<Statement> items,
    required final int page,
    required final int pageSize,
    required final int total,
    required final int totalPages,
  }) = _$StatementListResponseImpl;

  factory _StatementListResponse.fromJson(Map<String, dynamic> json) =
      _$StatementListResponseImpl.fromJson;

  @override
  List<Statement> get items;
  @override
  int get page;
  @override
  int get pageSize;
  @override
  int get total;
  @override
  int get totalPages;

  /// Create a copy of StatementListResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StatementListResponseImplCopyWith<_$StatementListResponseImpl>
  get copyWith => throw _privateConstructorUsedError;
}

StatementUploadResponse _$StatementUploadResponseFromJson(
  Map<String, dynamic> json,
) {
  return _StatementUploadResponse.fromJson(json);
}

/// @nodoc
mixin _$StatementUploadResponse {
  String get statementId => throw _privateConstructorUsedError;
  String get jobId => throw _privateConstructorUsedError;
  ProcessingStatus get status => throw _privateConstructorUsedError;

  /// Serializes this StatementUploadResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of StatementUploadResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StatementUploadResponseCopyWith<StatementUploadResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StatementUploadResponseCopyWith<$Res> {
  factory $StatementUploadResponseCopyWith(
    StatementUploadResponse value,
    $Res Function(StatementUploadResponse) then,
  ) = _$StatementUploadResponseCopyWithImpl<$Res, StatementUploadResponse>;
  @useResult
  $Res call({String statementId, String jobId, ProcessingStatus status});
}

/// @nodoc
class _$StatementUploadResponseCopyWithImpl<
  $Res,
  $Val extends StatementUploadResponse
>
    implements $StatementUploadResponseCopyWith<$Res> {
  _$StatementUploadResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StatementUploadResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? statementId = null,
    Object? jobId = null,
    Object? status = null,
  }) {
    return _then(
      _value.copyWith(
            statementId: null == statementId
                ? _value.statementId
                : statementId // ignore: cast_nullable_to_non_nullable
                      as String,
            jobId: null == jobId
                ? _value.jobId
                : jobId // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as ProcessingStatus,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$StatementUploadResponseImplCopyWith<$Res>
    implements $StatementUploadResponseCopyWith<$Res> {
  factory _$$StatementUploadResponseImplCopyWith(
    _$StatementUploadResponseImpl value,
    $Res Function(_$StatementUploadResponseImpl) then,
  ) = __$$StatementUploadResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String statementId, String jobId, ProcessingStatus status});
}

/// @nodoc
class __$$StatementUploadResponseImplCopyWithImpl<$Res>
    extends
        _$StatementUploadResponseCopyWithImpl<
          $Res,
          _$StatementUploadResponseImpl
        >
    implements _$$StatementUploadResponseImplCopyWith<$Res> {
  __$$StatementUploadResponseImplCopyWithImpl(
    _$StatementUploadResponseImpl _value,
    $Res Function(_$StatementUploadResponseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of StatementUploadResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? statementId = null,
    Object? jobId = null,
    Object? status = null,
  }) {
    return _then(
      _$StatementUploadResponseImpl(
        statementId: null == statementId
            ? _value.statementId
            : statementId // ignore: cast_nullable_to_non_nullable
                  as String,
        jobId: null == jobId
            ? _value.jobId
            : jobId // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as ProcessingStatus,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$StatementUploadResponseImpl implements _StatementUploadResponse {
  const _$StatementUploadResponseImpl({
    required this.statementId,
    required this.jobId,
    required this.status,
  });

  factory _$StatementUploadResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$StatementUploadResponseImplFromJson(json);

  @override
  final String statementId;
  @override
  final String jobId;
  @override
  final ProcessingStatus status;

  @override
  String toString() {
    return 'StatementUploadResponse(statementId: $statementId, jobId: $jobId, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StatementUploadResponseImpl &&
            (identical(other.statementId, statementId) ||
                other.statementId == statementId) &&
            (identical(other.jobId, jobId) || other.jobId == jobId) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, statementId, jobId, status);

  /// Create a copy of StatementUploadResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StatementUploadResponseImplCopyWith<_$StatementUploadResponseImpl>
  get copyWith =>
      __$$StatementUploadResponseImplCopyWithImpl<
        _$StatementUploadResponseImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StatementUploadResponseImplToJson(this);
  }
}

abstract class _StatementUploadResponse implements StatementUploadResponse {
  const factory _StatementUploadResponse({
    required final String statementId,
    required final String jobId,
    required final ProcessingStatus status,
  }) = _$StatementUploadResponseImpl;

  factory _StatementUploadResponse.fromJson(Map<String, dynamic> json) =
      _$StatementUploadResponseImpl.fromJson;

  @override
  String get statementId;
  @override
  String get jobId;
  @override
  ProcessingStatus get status;

  /// Create a copy of StatementUploadResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StatementUploadResponseImplCopyWith<_$StatementUploadResponseImpl>
  get copyWith => throw _privateConstructorUsedError;
}
