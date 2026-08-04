// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'comment_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$CommentItem {
  String get id => throw _privateConstructorUsedError;
  String get author => throw _privateConstructorUsedError;
  String get authorChannelId => throw _privateConstructorUsedError;
  String? get authorAvatarUrl => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;
  DateTime get publishedAt => throw _privateConstructorUsedError;
  int get likeCount => throw _privateConstructorUsedError;
  int? get replyCount => throw _privateConstructorUsedError;
  String? get parentId =>
      throw _privateConstructorUsedError; // null = top-level comment
  bool get isHearted => throw _privateConstructorUsedError;
  bool get isPinned => throw _privateConstructorUsedError;

  /// Create a copy of CommentItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CommentItemCopyWith<CommentItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CommentItemCopyWith<$Res> {
  factory $CommentItemCopyWith(
          CommentItem value, $Res Function(CommentItem) then) =
      _$CommentItemCopyWithImpl<$Res, CommentItem>;
  @useResult
  $Res call(
      {String id,
      String author,
      String authorChannelId,
      String? authorAvatarUrl,
      String content,
      DateTime publishedAt,
      int likeCount,
      int? replyCount,
      String? parentId,
      bool isHearted,
      bool isPinned});
}

/// @nodoc
class _$CommentItemCopyWithImpl<$Res, $Val extends CommentItem>
    implements $CommentItemCopyWith<$Res> {
  _$CommentItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CommentItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? author = null,
    Object? authorChannelId = null,
    Object? authorAvatarUrl = freezed,
    Object? content = null,
    Object? publishedAt = null,
    Object? likeCount = null,
    Object? replyCount = freezed,
    Object? parentId = freezed,
    Object? isHearted = null,
    Object? isPinned = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      author: null == author
          ? _value.author
          : author // ignore: cast_nullable_to_non_nullable
              as String,
      authorChannelId: null == authorChannelId
          ? _value.authorChannelId
          : authorChannelId // ignore: cast_nullable_to_non_nullable
              as String,
      authorAvatarUrl: freezed == authorAvatarUrl
          ? _value.authorAvatarUrl
          : authorAvatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      publishedAt: null == publishedAt
          ? _value.publishedAt
          : publishedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      likeCount: null == likeCount
          ? _value.likeCount
          : likeCount // ignore: cast_nullable_to_non_nullable
              as int,
      replyCount: freezed == replyCount
          ? _value.replyCount
          : replyCount // ignore: cast_nullable_to_non_nullable
              as int?,
      parentId: freezed == parentId
          ? _value.parentId
          : parentId // ignore: cast_nullable_to_non_nullable
              as String?,
      isHearted: null == isHearted
          ? _value.isHearted
          : isHearted // ignore: cast_nullable_to_non_nullable
              as bool,
      isPinned: null == isPinned
          ? _value.isPinned
          : isPinned // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CommentItemImplCopyWith<$Res>
    implements $CommentItemCopyWith<$Res> {
  factory _$$CommentItemImplCopyWith(
          _$CommentItemImpl value, $Res Function(_$CommentItemImpl) then) =
      __$$CommentItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String author,
      String authorChannelId,
      String? authorAvatarUrl,
      String content,
      DateTime publishedAt,
      int likeCount,
      int? replyCount,
      String? parentId,
      bool isHearted,
      bool isPinned});
}

/// @nodoc
class __$$CommentItemImplCopyWithImpl<$Res>
    extends _$CommentItemCopyWithImpl<$Res, _$CommentItemImpl>
    implements _$$CommentItemImplCopyWith<$Res> {
  __$$CommentItemImplCopyWithImpl(
      _$CommentItemImpl _value, $Res Function(_$CommentItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of CommentItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? author = null,
    Object? authorChannelId = null,
    Object? authorAvatarUrl = freezed,
    Object? content = null,
    Object? publishedAt = null,
    Object? likeCount = null,
    Object? replyCount = freezed,
    Object? parentId = freezed,
    Object? isHearted = null,
    Object? isPinned = null,
  }) {
    return _then(_$CommentItemImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      author: null == author
          ? _value.author
          : author // ignore: cast_nullable_to_non_nullable
              as String,
      authorChannelId: null == authorChannelId
          ? _value.authorChannelId
          : authorChannelId // ignore: cast_nullable_to_non_nullable
              as String,
      authorAvatarUrl: freezed == authorAvatarUrl
          ? _value.authorAvatarUrl
          : authorAvatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      publishedAt: null == publishedAt
          ? _value.publishedAt
          : publishedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      likeCount: null == likeCount
          ? _value.likeCount
          : likeCount // ignore: cast_nullable_to_non_nullable
              as int,
      replyCount: freezed == replyCount
          ? _value.replyCount
          : replyCount // ignore: cast_nullable_to_non_nullable
              as int?,
      parentId: freezed == parentId
          ? _value.parentId
          : parentId // ignore: cast_nullable_to_non_nullable
              as String?,
      isHearted: null == isHearted
          ? _value.isHearted
          : isHearted // ignore: cast_nullable_to_non_nullable
              as bool,
      isPinned: null == isPinned
          ? _value.isPinned
          : isPinned // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$CommentItemImpl extends _CommentItem {
  const _$CommentItemImpl(
      {required this.id,
      required this.author,
      required this.authorChannelId,
      this.authorAvatarUrl,
      required this.content,
      required this.publishedAt,
      required this.likeCount,
      this.replyCount,
      this.parentId,
      this.isHearted = false,
      this.isPinned = false})
      : super._();

  @override
  final String id;
  @override
  final String author;
  @override
  final String authorChannelId;
  @override
  final String? authorAvatarUrl;
  @override
  final String content;
  @override
  final DateTime publishedAt;
  @override
  final int likeCount;
  @override
  final int? replyCount;
  @override
  final String? parentId;
// null = top-level comment
  @override
  @JsonKey()
  final bool isHearted;
  @override
  @JsonKey()
  final bool isPinned;

  @override
  String toString() {
    return 'CommentItem(id: $id, author: $author, authorChannelId: $authorChannelId, authorAvatarUrl: $authorAvatarUrl, content: $content, publishedAt: $publishedAt, likeCount: $likeCount, replyCount: $replyCount, parentId: $parentId, isHearted: $isHearted, isPinned: $isPinned)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CommentItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.authorChannelId, authorChannelId) ||
                other.authorChannelId == authorChannelId) &&
            (identical(other.authorAvatarUrl, authorAvatarUrl) ||
                other.authorAvatarUrl == authorAvatarUrl) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.publishedAt, publishedAt) ||
                other.publishedAt == publishedAt) &&
            (identical(other.likeCount, likeCount) ||
                other.likeCount == likeCount) &&
            (identical(other.replyCount, replyCount) ||
                other.replyCount == replyCount) &&
            (identical(other.parentId, parentId) ||
                other.parentId == parentId) &&
            (identical(other.isHearted, isHearted) ||
                other.isHearted == isHearted) &&
            (identical(other.isPinned, isPinned) ||
                other.isPinned == isPinned));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      author,
      authorChannelId,
      authorAvatarUrl,
      content,
      publishedAt,
      likeCount,
      replyCount,
      parentId,
      isHearted,
      isPinned);

  /// Create a copy of CommentItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CommentItemImplCopyWith<_$CommentItemImpl> get copyWith =>
      __$$CommentItemImplCopyWithImpl<_$CommentItemImpl>(this, _$identity);
}

abstract class _CommentItem extends CommentItem {
  const factory _CommentItem(
      {required final String id,
      required final String author,
      required final String authorChannelId,
      final String? authorAvatarUrl,
      required final String content,
      required final DateTime publishedAt,
      required final int likeCount,
      final int? replyCount,
      final String? parentId,
      final bool isHearted,
      final bool isPinned}) = _$CommentItemImpl;
  const _CommentItem._() : super._();

  @override
  String get id;
  @override
  String get author;
  @override
  String get authorChannelId;
  @override
  String? get authorAvatarUrl;
  @override
  String get content;
  @override
  DateTime get publishedAt;
  @override
  int get likeCount;
  @override
  int? get replyCount;
  @override
  String? get parentId; // null = top-level comment
  @override
  bool get isHearted;
  @override
  bool get isPinned;

  /// Create a copy of CommentItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CommentItemImplCopyWith<_$CommentItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
