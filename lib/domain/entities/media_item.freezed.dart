// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'media_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$MediaItem {
  String get videoId => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError; // Channel info
  String get author => throw _privateConstructorUsedError;
  String get channelId => throw _privateConstructorUsedError;
  String? get channelTitle => throw _privateConstructorUsedError; // Timing
  Duration get duration => throw _privateConstructorUsedError;
  DateTime get publishedAt => throw _privateConstructorUsedError; // Media
  String? get thumbnailUrl => throw _privateConstructorUsedError;
  List<MediaFormat> get formats => throw _privateConstructorUsedError;
  List<MediaSubtitle> get subtitles => throw _privateConstructorUsedError;
  List<ChapterItem> get chapters =>
      throw _privateConstructorUsedError; // SponsorBlock
  List<SponsorSegment> get sponsorSegments =>
      throw _privateConstructorUsedError; // DeArrow
  DeArrowData? get deArrowData =>
      throw _privateConstructorUsedError; // User state
  int? get percentWatched => throw _privateConstructorUsedError;
  Duration? get resumePosition => throw _privateConstructorUsedError; // Flags
  bool get isLive => throw _privateConstructorUsedError;
  bool get isUpcoming => throw _privateConstructorUsedError;
  bool get isShorts => throw _privateConstructorUsedError;
  bool get isVerified => throw _privateConstructorUsedError; // Stats
  int? get viewCount => throw _privateConstructorUsedError;
  int? get likeCount => throw _privateConstructorUsedError;

  /// Create a copy of MediaItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MediaItemCopyWith<MediaItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MediaItemCopyWith<$Res> {
  factory $MediaItemCopyWith(MediaItem value, $Res Function(MediaItem) then) =
      _$MediaItemCopyWithImpl<$Res, MediaItem>;
  @useResult
  $Res call(
      {String videoId,
      String title,
      String? description,
      String author,
      String channelId,
      String? channelTitle,
      Duration duration,
      DateTime publishedAt,
      String? thumbnailUrl,
      List<MediaFormat> formats,
      List<MediaSubtitle> subtitles,
      List<ChapterItem> chapters,
      List<SponsorSegment> sponsorSegments,
      DeArrowData? deArrowData,
      int? percentWatched,
      Duration? resumePosition,
      bool isLive,
      bool isUpcoming,
      bool isShorts,
      bool isVerified,
      int? viewCount,
      int? likeCount});

  $DeArrowDataCopyWith<$Res>? get deArrowData;
}

/// @nodoc
class _$MediaItemCopyWithImpl<$Res, $Val extends MediaItem>
    implements $MediaItemCopyWith<$Res> {
  _$MediaItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MediaItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? videoId = null,
    Object? title = null,
    Object? description = freezed,
    Object? author = null,
    Object? channelId = null,
    Object? channelTitle = freezed,
    Object? duration = null,
    Object? publishedAt = null,
    Object? thumbnailUrl = freezed,
    Object? formats = null,
    Object? subtitles = null,
    Object? chapters = null,
    Object? sponsorSegments = null,
    Object? deArrowData = freezed,
    Object? percentWatched = freezed,
    Object? resumePosition = freezed,
    Object? isLive = null,
    Object? isUpcoming = null,
    Object? isShorts = null,
    Object? isVerified = null,
    Object? viewCount = freezed,
    Object? likeCount = freezed,
  }) {
    return _then(_value.copyWith(
      videoId: null == videoId
          ? _value.videoId
          : videoId // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      author: null == author
          ? _value.author
          : author // ignore: cast_nullable_to_non_nullable
              as String,
      channelId: null == channelId
          ? _value.channelId
          : channelId // ignore: cast_nullable_to_non_nullable
              as String,
      channelTitle: freezed == channelTitle
          ? _value.channelTitle
          : channelTitle // ignore: cast_nullable_to_non_nullable
              as String?,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as Duration,
      publishedAt: null == publishedAt
          ? _value.publishedAt
          : publishedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      thumbnailUrl: freezed == thumbnailUrl
          ? _value.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      formats: null == formats
          ? _value.formats
          : formats // ignore: cast_nullable_to_non_nullable
              as List<MediaFormat>,
      subtitles: null == subtitles
          ? _value.subtitles
          : subtitles // ignore: cast_nullable_to_non_nullable
              as List<MediaSubtitle>,
      chapters: null == chapters
          ? _value.chapters
          : chapters // ignore: cast_nullable_to_non_nullable
              as List<ChapterItem>,
      sponsorSegments: null == sponsorSegments
          ? _value.sponsorSegments
          : sponsorSegments // ignore: cast_nullable_to_non_nullable
              as List<SponsorSegment>,
      deArrowData: freezed == deArrowData
          ? _value.deArrowData
          : deArrowData // ignore: cast_nullable_to_non_nullable
              as DeArrowData?,
      percentWatched: freezed == percentWatched
          ? _value.percentWatched
          : percentWatched // ignore: cast_nullable_to_non_nullable
              as int?,
      resumePosition: freezed == resumePosition
          ? _value.resumePosition
          : resumePosition // ignore: cast_nullable_to_non_nullable
              as Duration?,
      isLive: null == isLive
          ? _value.isLive
          : isLive // ignore: cast_nullable_to_non_nullable
              as bool,
      isUpcoming: null == isUpcoming
          ? _value.isUpcoming
          : isUpcoming // ignore: cast_nullable_to_non_nullable
              as bool,
      isShorts: null == isShorts
          ? _value.isShorts
          : isShorts // ignore: cast_nullable_to_non_nullable
              as bool,
      isVerified: null == isVerified
          ? _value.isVerified
          : isVerified // ignore: cast_nullable_to_non_nullable
              as bool,
      viewCount: freezed == viewCount
          ? _value.viewCount
          : viewCount // ignore: cast_nullable_to_non_nullable
              as int?,
      likeCount: freezed == likeCount
          ? _value.likeCount
          : likeCount // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }

  /// Create a copy of MediaItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DeArrowDataCopyWith<$Res>? get deArrowData {
    if (_value.deArrowData == null) {
      return null;
    }

    return $DeArrowDataCopyWith<$Res>(_value.deArrowData!, (value) {
      return _then(_value.copyWith(deArrowData: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$MediaItemImplCopyWith<$Res>
    implements $MediaItemCopyWith<$Res> {
  factory _$$MediaItemImplCopyWith(
          _$MediaItemImpl value, $Res Function(_$MediaItemImpl) then) =
      __$$MediaItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String videoId,
      String title,
      String? description,
      String author,
      String channelId,
      String? channelTitle,
      Duration duration,
      DateTime publishedAt,
      String? thumbnailUrl,
      List<MediaFormat> formats,
      List<MediaSubtitle> subtitles,
      List<ChapterItem> chapters,
      List<SponsorSegment> sponsorSegments,
      DeArrowData? deArrowData,
      int? percentWatched,
      Duration? resumePosition,
      bool isLive,
      bool isUpcoming,
      bool isShorts,
      bool isVerified,
      int? viewCount,
      int? likeCount});

  @override
  $DeArrowDataCopyWith<$Res>? get deArrowData;
}

/// @nodoc
class __$$MediaItemImplCopyWithImpl<$Res>
    extends _$MediaItemCopyWithImpl<$Res, _$MediaItemImpl>
    implements _$$MediaItemImplCopyWith<$Res> {
  __$$MediaItemImplCopyWithImpl(
      _$MediaItemImpl _value, $Res Function(_$MediaItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of MediaItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? videoId = null,
    Object? title = null,
    Object? description = freezed,
    Object? author = null,
    Object? channelId = null,
    Object? channelTitle = freezed,
    Object? duration = null,
    Object? publishedAt = null,
    Object? thumbnailUrl = freezed,
    Object? formats = null,
    Object? subtitles = null,
    Object? chapters = null,
    Object? sponsorSegments = null,
    Object? deArrowData = freezed,
    Object? percentWatched = freezed,
    Object? resumePosition = freezed,
    Object? isLive = null,
    Object? isUpcoming = null,
    Object? isShorts = null,
    Object? isVerified = null,
    Object? viewCount = freezed,
    Object? likeCount = freezed,
  }) {
    return _then(_$MediaItemImpl(
      videoId: null == videoId
          ? _value.videoId
          : videoId // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      author: null == author
          ? _value.author
          : author // ignore: cast_nullable_to_non_nullable
              as String,
      channelId: null == channelId
          ? _value.channelId
          : channelId // ignore: cast_nullable_to_non_nullable
              as String,
      channelTitle: freezed == channelTitle
          ? _value.channelTitle
          : channelTitle // ignore: cast_nullable_to_non_nullable
              as String?,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as Duration,
      publishedAt: null == publishedAt
          ? _value.publishedAt
          : publishedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      thumbnailUrl: freezed == thumbnailUrl
          ? _value.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      formats: null == formats
          ? _value._formats
          : formats // ignore: cast_nullable_to_non_nullable
              as List<MediaFormat>,
      subtitles: null == subtitles
          ? _value._subtitles
          : subtitles // ignore: cast_nullable_to_non_nullable
              as List<MediaSubtitle>,
      chapters: null == chapters
          ? _value._chapters
          : chapters // ignore: cast_nullable_to_non_nullable
              as List<ChapterItem>,
      sponsorSegments: null == sponsorSegments
          ? _value._sponsorSegments
          : sponsorSegments // ignore: cast_nullable_to_non_nullable
              as List<SponsorSegment>,
      deArrowData: freezed == deArrowData
          ? _value.deArrowData
          : deArrowData // ignore: cast_nullable_to_non_nullable
              as DeArrowData?,
      percentWatched: freezed == percentWatched
          ? _value.percentWatched
          : percentWatched // ignore: cast_nullable_to_non_nullable
              as int?,
      resumePosition: freezed == resumePosition
          ? _value.resumePosition
          : resumePosition // ignore: cast_nullable_to_non_nullable
              as Duration?,
      isLive: null == isLive
          ? _value.isLive
          : isLive // ignore: cast_nullable_to_non_nullable
              as bool,
      isUpcoming: null == isUpcoming
          ? _value.isUpcoming
          : isUpcoming // ignore: cast_nullable_to_non_nullable
              as bool,
      isShorts: null == isShorts
          ? _value.isShorts
          : isShorts // ignore: cast_nullable_to_non_nullable
              as bool,
      isVerified: null == isVerified
          ? _value.isVerified
          : isVerified // ignore: cast_nullable_to_non_nullable
              as bool,
      viewCount: freezed == viewCount
          ? _value.viewCount
          : viewCount // ignore: cast_nullable_to_non_nullable
              as int?,
      likeCount: freezed == likeCount
          ? _value.likeCount
          : likeCount // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc

class _$MediaItemImpl extends _MediaItem {
  const _$MediaItemImpl(
      {required this.videoId,
      required this.title,
      this.description,
      required this.author,
      required this.channelId,
      this.channelTitle,
      required this.duration,
      required this.publishedAt,
      this.thumbnailUrl,
      required final List<MediaFormat> formats,
      required final List<MediaSubtitle> subtitles,
      required final List<ChapterItem> chapters,
      final List<SponsorSegment> sponsorSegments = const <SponsorSegment>[],
      this.deArrowData,
      this.percentWatched,
      this.resumePosition,
      this.isLive = false,
      this.isUpcoming = false,
      this.isShorts = false,
      this.isVerified = false,
      this.viewCount,
      this.likeCount})
      : _formats = formats,
        _subtitles = subtitles,
        _chapters = chapters,
        _sponsorSegments = sponsorSegments,
        super._();

  @override
  final String videoId;
  @override
  final String title;
  @override
  final String? description;
// Channel info
  @override
  final String author;
  @override
  final String channelId;
  @override
  final String? channelTitle;
// Timing
  @override
  final Duration duration;
  @override
  final DateTime publishedAt;
// Media
  @override
  final String? thumbnailUrl;
  final List<MediaFormat> _formats;
  @override
  List<MediaFormat> get formats {
    if (_formats is EqualUnmodifiableListView) return _formats;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_formats);
  }

  final List<MediaSubtitle> _subtitles;
  @override
  List<MediaSubtitle> get subtitles {
    if (_subtitles is EqualUnmodifiableListView) return _subtitles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_subtitles);
  }

  final List<ChapterItem> _chapters;
  @override
  List<ChapterItem> get chapters {
    if (_chapters is EqualUnmodifiableListView) return _chapters;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_chapters);
  }

// SponsorBlock
  final List<SponsorSegment> _sponsorSegments;
// SponsorBlock
  @override
  @JsonKey()
  List<SponsorSegment> get sponsorSegments {
    if (_sponsorSegments is EqualUnmodifiableListView) return _sponsorSegments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sponsorSegments);
  }

// DeArrow
  @override
  final DeArrowData? deArrowData;
// User state
  @override
  final int? percentWatched;
  @override
  final Duration? resumePosition;
// Flags
  @override
  @JsonKey()
  final bool isLive;
  @override
  @JsonKey()
  final bool isUpcoming;
  @override
  @JsonKey()
  final bool isShorts;
  @override
  @JsonKey()
  final bool isVerified;
// Stats
  @override
  final int? viewCount;
  @override
  final int? likeCount;

  @override
  String toString() {
    return 'MediaItem(videoId: $videoId, title: $title, description: $description, author: $author, channelId: $channelId, channelTitle: $channelTitle, duration: $duration, publishedAt: $publishedAt, thumbnailUrl: $thumbnailUrl, formats: $formats, subtitles: $subtitles, chapters: $chapters, sponsorSegments: $sponsorSegments, deArrowData: $deArrowData, percentWatched: $percentWatched, resumePosition: $resumePosition, isLive: $isLive, isUpcoming: $isUpcoming, isShorts: $isShorts, isVerified: $isVerified, viewCount: $viewCount, likeCount: $likeCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MediaItemImpl &&
            (identical(other.videoId, videoId) || other.videoId == videoId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.channelId, channelId) ||
                other.channelId == channelId) &&
            (identical(other.channelTitle, channelTitle) ||
                other.channelTitle == channelTitle) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.publishedAt, publishedAt) ||
                other.publishedAt == publishedAt) &&
            (identical(other.thumbnailUrl, thumbnailUrl) ||
                other.thumbnailUrl == thumbnailUrl) &&
            const DeepCollectionEquality().equals(other._formats, _formats) &&
            const DeepCollectionEquality()
                .equals(other._subtitles, _subtitles) &&
            const DeepCollectionEquality().equals(other._chapters, _chapters) &&
            const DeepCollectionEquality()
                .equals(other._sponsorSegments, _sponsorSegments) &&
            (identical(other.deArrowData, deArrowData) ||
                other.deArrowData == deArrowData) &&
            (identical(other.percentWatched, percentWatched) ||
                other.percentWatched == percentWatched) &&
            (identical(other.resumePosition, resumePosition) ||
                other.resumePosition == resumePosition) &&
            (identical(other.isLive, isLive) || other.isLive == isLive) &&
            (identical(other.isUpcoming, isUpcoming) ||
                other.isUpcoming == isUpcoming) &&
            (identical(other.isShorts, isShorts) ||
                other.isShorts == isShorts) &&
            (identical(other.isVerified, isVerified) ||
                other.isVerified == isVerified) &&
            (identical(other.viewCount, viewCount) ||
                other.viewCount == viewCount) &&
            (identical(other.likeCount, likeCount) ||
                other.likeCount == likeCount));
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        videoId,
        title,
        description,
        author,
        channelId,
        channelTitle,
        duration,
        publishedAt,
        thumbnailUrl,
        const DeepCollectionEquality().hash(_formats),
        const DeepCollectionEquality().hash(_subtitles),
        const DeepCollectionEquality().hash(_chapters),
        const DeepCollectionEquality().hash(_sponsorSegments),
        deArrowData,
        percentWatched,
        resumePosition,
        isLive,
        isUpcoming,
        isShorts,
        isVerified,
        viewCount,
        likeCount
      ]);

  /// Create a copy of MediaItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MediaItemImplCopyWith<_$MediaItemImpl> get copyWith =>
      __$$MediaItemImplCopyWithImpl<_$MediaItemImpl>(this, _$identity);
}

abstract class _MediaItem extends MediaItem {
  const factory _MediaItem(
      {required final String videoId,
      required final String title,
      final String? description,
      required final String author,
      required final String channelId,
      final String? channelTitle,
      required final Duration duration,
      required final DateTime publishedAt,
      final String? thumbnailUrl,
      required final List<MediaFormat> formats,
      required final List<MediaSubtitle> subtitles,
      required final List<ChapterItem> chapters,
      final List<SponsorSegment> sponsorSegments,
      final DeArrowData? deArrowData,
      final int? percentWatched,
      final Duration? resumePosition,
      final bool isLive,
      final bool isUpcoming,
      final bool isShorts,
      final bool isVerified,
      final int? viewCount,
      final int? likeCount}) = _$MediaItemImpl;
  const _MediaItem._() : super._();

  @override
  String get videoId;
  @override
  String get title;
  @override
  String? get description; // Channel info
  @override
  String get author;
  @override
  String get channelId;
  @override
  String? get channelTitle; // Timing
  @override
  Duration get duration;
  @override
  DateTime get publishedAt; // Media
  @override
  String? get thumbnailUrl;
  @override
  List<MediaFormat> get formats;
  @override
  List<MediaSubtitle> get subtitles;
  @override
  List<ChapterItem> get chapters; // SponsorBlock
  @override
  List<SponsorSegment> get sponsorSegments; // DeArrow
  @override
  DeArrowData? get deArrowData; // User state
  @override
  int? get percentWatched;
  @override
  Duration? get resumePosition; // Flags
  @override
  bool get isLive;
  @override
  bool get isUpcoming;
  @override
  bool get isShorts;
  @override
  bool get isVerified; // Stats
  @override
  int? get viewCount;
  @override
  int? get likeCount;

  /// Create a copy of MediaItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MediaItemImplCopyWith<_$MediaItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
