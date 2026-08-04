// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dearrow_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$DeArrowData {
  String? get title => throw _privateConstructorUsedError; // alt title
  String? get thumbnailUrl =>
      throw _privateConstructorUsedError; // alt thumbnail
  DeArrowLockReason? get titleLockReason => throw _privateConstructorUsedError;
  DeArrowLockReason? get thumbnailLockReason =>
      throw _privateConstructorUsedError;

  /// Create a copy of DeArrowData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DeArrowDataCopyWith<DeArrowData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DeArrowDataCopyWith<$Res> {
  factory $DeArrowDataCopyWith(
          DeArrowData value, $Res Function(DeArrowData) then) =
      _$DeArrowDataCopyWithImpl<$Res, DeArrowData>;
  @useResult
  $Res call(
      {String? title,
      String? thumbnailUrl,
      DeArrowLockReason? titleLockReason,
      DeArrowLockReason? thumbnailLockReason});
}

/// @nodoc
class _$DeArrowDataCopyWithImpl<$Res, $Val extends DeArrowData>
    implements $DeArrowDataCopyWith<$Res> {
  _$DeArrowDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DeArrowData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = freezed,
    Object? thumbnailUrl = freezed,
    Object? titleLockReason = freezed,
    Object? thumbnailLockReason = freezed,
  }) {
    return _then(_value.copyWith(
      title: freezed == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
      thumbnailUrl: freezed == thumbnailUrl
          ? _value.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      titleLockReason: freezed == titleLockReason
          ? _value.titleLockReason
          : titleLockReason // ignore: cast_nullable_to_non_nullable
              as DeArrowLockReason?,
      thumbnailLockReason: freezed == thumbnailLockReason
          ? _value.thumbnailLockReason
          : thumbnailLockReason // ignore: cast_nullable_to_non_nullable
              as DeArrowLockReason?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DeArrowDataImplCopyWith<$Res>
    implements $DeArrowDataCopyWith<$Res> {
  factory _$$DeArrowDataImplCopyWith(
          _$DeArrowDataImpl value, $Res Function(_$DeArrowDataImpl) then) =
      __$$DeArrowDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String? title,
      String? thumbnailUrl,
      DeArrowLockReason? titleLockReason,
      DeArrowLockReason? thumbnailLockReason});
}

/// @nodoc
class __$$DeArrowDataImplCopyWithImpl<$Res>
    extends _$DeArrowDataCopyWithImpl<$Res, _$DeArrowDataImpl>
    implements _$$DeArrowDataImplCopyWith<$Res> {
  __$$DeArrowDataImplCopyWithImpl(
      _$DeArrowDataImpl _value, $Res Function(_$DeArrowDataImpl) _then)
      : super(_value, _then);

  /// Create a copy of DeArrowData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = freezed,
    Object? thumbnailUrl = freezed,
    Object? titleLockReason = freezed,
    Object? thumbnailLockReason = freezed,
  }) {
    return _then(_$DeArrowDataImpl(
      title: freezed == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
      thumbnailUrl: freezed == thumbnailUrl
          ? _value.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      titleLockReason: freezed == titleLockReason
          ? _value.titleLockReason
          : titleLockReason // ignore: cast_nullable_to_non_nullable
              as DeArrowLockReason?,
      thumbnailLockReason: freezed == thumbnailLockReason
          ? _value.thumbnailLockReason
          : thumbnailLockReason // ignore: cast_nullable_to_non_nullable
              as DeArrowLockReason?,
    ));
  }
}

/// @nodoc

class _$DeArrowDataImpl implements _DeArrowData {
  const _$DeArrowDataImpl(
      {this.title,
      this.thumbnailUrl,
      this.titleLockReason,
      this.thumbnailLockReason});

  @override
  final String? title;
// alt title
  @override
  final String? thumbnailUrl;
// alt thumbnail
  @override
  final DeArrowLockReason? titleLockReason;
  @override
  final DeArrowLockReason? thumbnailLockReason;

  @override
  String toString() {
    return 'DeArrowData(title: $title, thumbnailUrl: $thumbnailUrl, titleLockReason: $titleLockReason, thumbnailLockReason: $thumbnailLockReason)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DeArrowDataImpl &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.thumbnailUrl, thumbnailUrl) ||
                other.thumbnailUrl == thumbnailUrl) &&
            (identical(other.titleLockReason, titleLockReason) ||
                other.titleLockReason == titleLockReason) &&
            (identical(other.thumbnailLockReason, thumbnailLockReason) ||
                other.thumbnailLockReason == thumbnailLockReason));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, title, thumbnailUrl, titleLockReason, thumbnailLockReason);

  /// Create a copy of DeArrowData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DeArrowDataImplCopyWith<_$DeArrowDataImpl> get copyWith =>
      __$$DeArrowDataImplCopyWithImpl<_$DeArrowDataImpl>(this, _$identity);
}

abstract class _DeArrowData implements DeArrowData {
  const factory _DeArrowData(
      {final String? title,
      final String? thumbnailUrl,
      final DeArrowLockReason? titleLockReason,
      final DeArrowLockReason? thumbnailLockReason}) = _$DeArrowDataImpl;

  @override
  String? get title; // alt title
  @override
  String? get thumbnailUrl; // alt thumbnail
  @override
  DeArrowLockReason? get titleLockReason;
  @override
  DeArrowLockReason? get thumbnailLockReason;

  /// Create a copy of DeArrowData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DeArrowDataImplCopyWith<_$DeArrowDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
