// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chapter_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ChapterItem {
  String get title => throw _privateConstructorUsedError;
  Duration get start => throw _privateConstructorUsedError;
  String? get thumbnailUrl => throw _privateConstructorUsedError;

  /// Create a copy of ChapterItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChapterItemCopyWith<ChapterItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChapterItemCopyWith<$Res> {
  factory $ChapterItemCopyWith(
          ChapterItem value, $Res Function(ChapterItem) then) =
      _$ChapterItemCopyWithImpl<$Res, ChapterItem>;
  @useResult
  $Res call({String title, Duration start, String? thumbnailUrl});
}

/// @nodoc
class _$ChapterItemCopyWithImpl<$Res, $Val extends ChapterItem>
    implements $ChapterItemCopyWith<$Res> {
  _$ChapterItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChapterItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? start = null,
    Object? thumbnailUrl = freezed,
  }) {
    return _then(_value.copyWith(
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      start: null == start
          ? _value.start
          : start // ignore: cast_nullable_to_non_nullable
              as Duration,
      thumbnailUrl: freezed == thumbnailUrl
          ? _value.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChapterItemImplCopyWith<$Res>
    implements $ChapterItemCopyWith<$Res> {
  factory _$$ChapterItemImplCopyWith(
          _$ChapterItemImpl value, $Res Function(_$ChapterItemImpl) then) =
      __$$ChapterItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String title, Duration start, String? thumbnailUrl});
}

/// @nodoc
class __$$ChapterItemImplCopyWithImpl<$Res>
    extends _$ChapterItemCopyWithImpl<$Res, _$ChapterItemImpl>
    implements _$$ChapterItemImplCopyWith<$Res> {
  __$$ChapterItemImplCopyWithImpl(
      _$ChapterItemImpl _value, $Res Function(_$ChapterItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChapterItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? start = null,
    Object? thumbnailUrl = freezed,
  }) {
    return _then(_$ChapterItemImpl(
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      start: null == start
          ? _value.start
          : start // ignore: cast_nullable_to_non_nullable
              as Duration,
      thumbnailUrl: freezed == thumbnailUrl
          ? _value.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$ChapterItemImpl implements _ChapterItem {
  const _$ChapterItemImpl(
      {required this.title, required this.start, this.thumbnailUrl});

  @override
  final String title;
  @override
  final Duration start;
  @override
  final String? thumbnailUrl;

  @override
  String toString() {
    return 'ChapterItem(title: $title, start: $start, thumbnailUrl: $thumbnailUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChapterItemImpl &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.start, start) || other.start == start) &&
            (identical(other.thumbnailUrl, thumbnailUrl) ||
                other.thumbnailUrl == thumbnailUrl));
  }

  @override
  int get hashCode => Object.hash(runtimeType, title, start, thumbnailUrl);

  /// Create a copy of ChapterItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChapterItemImplCopyWith<_$ChapterItemImpl> get copyWith =>
      __$$ChapterItemImplCopyWithImpl<_$ChapterItemImpl>(this, _$identity);
}

abstract class _ChapterItem implements ChapterItem {
  const factory _ChapterItem(
      {required final String title,
      required final Duration start,
      final String? thumbnailUrl}) = _$ChapterItemImpl;

  @override
  String get title;
  @override
  Duration get start;
  @override
  String? get thumbnailUrl;

  /// Create a copy of ChapterItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChapterItemImplCopyWith<_$ChapterItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
