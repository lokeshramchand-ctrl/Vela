// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'upload_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$UploadState {
  UploadStage get stage => throw _privateConstructorUsedError;
  String? get fileName => throw _privateConstructorUsedError;
  int? get fileSizeBytes => throw _privateConstructorUsedError;
  double get progressPercent => throw _privateConstructorUsedError;
  String? get jobId => throw _privateConstructorUsedError;
  Statement? get statement => throw _privateConstructorUsedError;
  String? get errorMessage => throw _privateConstructorUsedError;

  /// Create a copy of UploadState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UploadStateCopyWith<UploadState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UploadStateCopyWith<$Res> {
  factory $UploadStateCopyWith(
    UploadState value,
    $Res Function(UploadState) then,
  ) = _$UploadStateCopyWithImpl<$Res, UploadState>;
  @useResult
  $Res call({
    UploadStage stage,
    String? fileName,
    int? fileSizeBytes,
    double progressPercent,
    String? jobId,
    Statement? statement,
    String? errorMessage,
  });

  $StatementCopyWith<$Res>? get statement;
}

/// @nodoc
class _$UploadStateCopyWithImpl<$Res, $Val extends UploadState>
    implements $UploadStateCopyWith<$Res> {
  _$UploadStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UploadState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? stage = null,
    Object? fileName = freezed,
    Object? fileSizeBytes = freezed,
    Object? progressPercent = null,
    Object? jobId = freezed,
    Object? statement = freezed,
    Object? errorMessage = freezed,
  }) {
    return _then(
      _value.copyWith(
            stage: null == stage
                ? _value.stage
                : stage // ignore: cast_nullable_to_non_nullable
                      as UploadStage,
            fileName: freezed == fileName
                ? _value.fileName
                : fileName // ignore: cast_nullable_to_non_nullable
                      as String?,
            fileSizeBytes: freezed == fileSizeBytes
                ? _value.fileSizeBytes
                : fileSizeBytes // ignore: cast_nullable_to_non_nullable
                      as int?,
            progressPercent: null == progressPercent
                ? _value.progressPercent
                : progressPercent // ignore: cast_nullable_to_non_nullable
                      as double,
            jobId: freezed == jobId
                ? _value.jobId
                : jobId // ignore: cast_nullable_to_non_nullable
                      as String?,
            statement: freezed == statement
                ? _value.statement
                : statement // ignore: cast_nullable_to_non_nullable
                      as Statement?,
            errorMessage: freezed == errorMessage
                ? _value.errorMessage
                : errorMessage // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }

  /// Create a copy of UploadState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $StatementCopyWith<$Res>? get statement {
    if (_value.statement == null) {
      return null;
    }

    return $StatementCopyWith<$Res>(_value.statement!, (value) {
      return _then(_value.copyWith(statement: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$UploadStateImplCopyWith<$Res>
    implements $UploadStateCopyWith<$Res> {
  factory _$$UploadStateImplCopyWith(
    _$UploadStateImpl value,
    $Res Function(_$UploadStateImpl) then,
  ) = __$$UploadStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    UploadStage stage,
    String? fileName,
    int? fileSizeBytes,
    double progressPercent,
    String? jobId,
    Statement? statement,
    String? errorMessage,
  });

  @override
  $StatementCopyWith<$Res>? get statement;
}

/// @nodoc
class __$$UploadStateImplCopyWithImpl<$Res>
    extends _$UploadStateCopyWithImpl<$Res, _$UploadStateImpl>
    implements _$$UploadStateImplCopyWith<$Res> {
  __$$UploadStateImplCopyWithImpl(
    _$UploadStateImpl _value,
    $Res Function(_$UploadStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of UploadState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? stage = null,
    Object? fileName = freezed,
    Object? fileSizeBytes = freezed,
    Object? progressPercent = null,
    Object? jobId = freezed,
    Object? statement = freezed,
    Object? errorMessage = freezed,
  }) {
    return _then(
      _$UploadStateImpl(
        stage: null == stage
            ? _value.stage
            : stage // ignore: cast_nullable_to_non_nullable
                  as UploadStage,
        fileName: freezed == fileName
            ? _value.fileName
            : fileName // ignore: cast_nullable_to_non_nullable
                  as String?,
        fileSizeBytes: freezed == fileSizeBytes
            ? _value.fileSizeBytes
            : fileSizeBytes // ignore: cast_nullable_to_non_nullable
                  as int?,
        progressPercent: null == progressPercent
            ? _value.progressPercent
            : progressPercent // ignore: cast_nullable_to_non_nullable
                  as double,
        jobId: freezed == jobId
            ? _value.jobId
            : jobId // ignore: cast_nullable_to_non_nullable
                  as String?,
        statement: freezed == statement
            ? _value.statement
            : statement // ignore: cast_nullable_to_non_nullable
                  as Statement?,
        errorMessage: freezed == errorMessage
            ? _value.errorMessage
            : errorMessage // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$UploadStateImpl implements _UploadState {
  const _$UploadStateImpl({
    this.stage = UploadStage.idle,
    this.fileName,
    this.fileSizeBytes,
    this.progressPercent = 0,
    this.jobId,
    this.statement,
    this.errorMessage,
  });

  @override
  @JsonKey()
  final UploadStage stage;
  @override
  final String? fileName;
  @override
  final int? fileSizeBytes;
  @override
  @JsonKey()
  final double progressPercent;
  @override
  final String? jobId;
  @override
  final Statement? statement;
  @override
  final String? errorMessage;

  @override
  String toString() {
    return 'UploadState(stage: $stage, fileName: $fileName, fileSizeBytes: $fileSizeBytes, progressPercent: $progressPercent, jobId: $jobId, statement: $statement, errorMessage: $errorMessage)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UploadStateImpl &&
            (identical(other.stage, stage) || other.stage == stage) &&
            (identical(other.fileName, fileName) ||
                other.fileName == fileName) &&
            (identical(other.fileSizeBytes, fileSizeBytes) ||
                other.fileSizeBytes == fileSizeBytes) &&
            (identical(other.progressPercent, progressPercent) ||
                other.progressPercent == progressPercent) &&
            (identical(other.jobId, jobId) || other.jobId == jobId) &&
            (identical(other.statement, statement) ||
                other.statement == statement) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    stage,
    fileName,
    fileSizeBytes,
    progressPercent,
    jobId,
    statement,
    errorMessage,
  );

  /// Create a copy of UploadState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UploadStateImplCopyWith<_$UploadStateImpl> get copyWith =>
      __$$UploadStateImplCopyWithImpl<_$UploadStateImpl>(this, _$identity);
}

abstract class _UploadState implements UploadState {
  const factory _UploadState({
    final UploadStage stage,
    final String? fileName,
    final int? fileSizeBytes,
    final double progressPercent,
    final String? jobId,
    final Statement? statement,
    final String? errorMessage,
  }) = _$UploadStateImpl;

  @override
  UploadStage get stage;
  @override
  String? get fileName;
  @override
  int? get fileSizeBytes;
  @override
  double get progressPercent;
  @override
  String? get jobId;
  @override
  Statement? get statement;
  @override
  String? get errorMessage;

  /// Create a copy of UploadState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UploadStateImplCopyWith<_$UploadStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
