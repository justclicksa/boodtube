// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'media_group.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$MediaGroup {
  String get title => throw _privateConstructorUsedError;
  MediaGroupType get type => throw _privateConstructorUsedError;
  List<MediaItem> get mediaItems => throw _privateConstructorUsedError;
  String? get nextPageToken => throw _privateConstructorUsedError;
  String? get channelId => throw _privateConstructorUsedError;
  String? get thumbnailUrl => throw _privateConstructorUsedError;

  /// Create a copy of MediaGroup
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MediaGroupCopyWith<MediaGroup> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MediaGroupCopyWith<$Res> {
  factory $MediaGroupCopyWith(
          MediaGroup value, $Res Function(MediaGroup) then) =
      _$MediaGroupCopyWithImpl<$Res, MediaGroup>;
  @useResult
  $Res call(
      {String title,
      MediaGroupType type,
      List<MediaItem> mediaItems,
      String? nextPageToken,
      String? channelId,
      String? thumbnailUrl});
}

/// @nodoc
class _$MediaGroupCopyWithImpl<$Res, $Val extends MediaGroup>
    implements $MediaGroupCopyWith<$Res> {
  _$MediaGroupCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MediaGroup
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? type = null,
    Object? mediaItems = null,
    Object? nextPageToken = freezed,
    Object? channelId = freezed,
    Object? thumbnailUrl = freezed,
  }) {
    return _then(_value.copyWith(
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as MediaGroupType,
      mediaItems: null == mediaItems
          ? _value.mediaItems
          : mediaItems // ignore: cast_nullable_to_non_nullable
              as List<MediaItem>,
      nextPageToken: freezed == nextPageToken
          ? _value.nextPageToken
          : nextPageToken // ignore: cast_nullable_to_non_nullable
              as String?,
      channelId: freezed == channelId
          ? _value.channelId
          : channelId // ignore: cast_nullable_to_non_nullable
              as String?,
      thumbnailUrl: freezed == thumbnailUrl
          ? _value.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MediaGroupImplCopyWith<$Res>
    implements $MediaGroupCopyWith<$Res> {
  factory _$$MediaGroupImplCopyWith(
          _$MediaGroupImpl value, $Res Function(_$MediaGroupImpl) then) =
      __$$MediaGroupImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String title,
      MediaGroupType type,
      List<MediaItem> mediaItems,
      String? nextPageToken,
      String? channelId,
      String? thumbnailUrl});
}

/// @nodoc
class __$$MediaGroupImplCopyWithImpl<$Res>
    extends _$MediaGroupCopyWithImpl<$Res, _$MediaGroupImpl>
    implements _$$MediaGroupImplCopyWith<$Res> {
  __$$MediaGroupImplCopyWithImpl(
      _$MediaGroupImpl _value, $Res Function(_$MediaGroupImpl) _then)
      : super(_value, _then);

  /// Create a copy of MediaGroup
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? type = null,
    Object? mediaItems = null,
    Object? nextPageToken = freezed,
    Object? channelId = freezed,
    Object? thumbnailUrl = freezed,
  }) {
    return _then(_$MediaGroupImpl(
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as MediaGroupType,
      mediaItems: null == mediaItems
          ? _value._mediaItems
          : mediaItems // ignore: cast_nullable_to_non_nullable
              as List<MediaItem>,
      nextPageToken: freezed == nextPageToken
          ? _value.nextPageToken
          : nextPageToken // ignore: cast_nullable_to_non_nullable
              as String?,
      channelId: freezed == channelId
          ? _value.channelId
          : channelId // ignore: cast_nullable_to_non_nullable
              as String?,
      thumbnailUrl: freezed == thumbnailUrl
          ? _value.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$MediaGroupImpl extends _MediaGroup {
  const _$MediaGroupImpl(
      {required this.title,
      required this.type,
      required final List<MediaItem> mediaItems,
      this.nextPageToken,
      this.channelId,
      this.thumbnailUrl})
      : _mediaItems = mediaItems,
        super._();

  @override
  final String title;
  @override
  final MediaGroupType type;
  final List<MediaItem> _mediaItems;
  @override
  List<MediaItem> get mediaItems {
    if (_mediaItems is EqualUnmodifiableListView) return _mediaItems;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_mediaItems);
  }

  @override
  final String? nextPageToken;
  @override
  final String? channelId;
  @override
  final String? thumbnailUrl;

  @override
  String toString() {
    return 'MediaGroup(title: $title, type: $type, mediaItems: $mediaItems, nextPageToken: $nextPageToken, channelId: $channelId, thumbnailUrl: $thumbnailUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MediaGroupImpl &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.type, type) || other.type == type) &&
            const DeepCollectionEquality()
                .equals(other._mediaItems, _mediaItems) &&
            (identical(other.nextPageToken, nextPageToken) ||
                other.nextPageToken == nextPageToken) &&
            (identical(other.channelId, channelId) ||
                other.channelId == channelId) &&
            (identical(other.thumbnailUrl, thumbnailUrl) ||
                other.thumbnailUrl == thumbnailUrl));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      title,
      type,
      const DeepCollectionEquality().hash(_mediaItems),
      nextPageToken,
      channelId,
      thumbnailUrl);

  /// Create a copy of MediaGroup
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MediaGroupImplCopyWith<_$MediaGroupImpl> get copyWith =>
      __$$MediaGroupImplCopyWithImpl<_$MediaGroupImpl>(this, _$identity);
}

abstract class _MediaGroup extends MediaGroup {
  const factory _MediaGroup(
      {required final String title,
      required final MediaGroupType type,
      required final List<MediaItem> mediaItems,
      final String? nextPageToken,
      final String? channelId,
      final String? thumbnailUrl}) = _$MediaGroupImpl;
  const _MediaGroup._() : super._();

  @override
  String get title;
  @override
  MediaGroupType get type;
  @override
  List<MediaItem> get mediaItems;
  @override
  String? get nextPageToken;
  @override
  String? get channelId;
  @override
  String? get thumbnailUrl;

  /// Create a copy of MediaGroup
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MediaGroupImplCopyWith<_$MediaGroupImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
