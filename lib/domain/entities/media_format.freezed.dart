// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'media_format.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$MediaFormat {
  String get formatId => throw _privateConstructorUsedError;
  String get url => throw _privateConstructorUsedError; // Quality
  String? get qualityLabel =>
      throw _privateConstructorUsedError; // e.g., "1080p", "720p60"
  int? get width => throw _privateConstructorUsedError;
  int? get height => throw _privateConstructorUsedError;
  double? get fps => throw _privateConstructorUsedError; // Codec
  String get mimeType => throw _privateConstructorUsedError;
  String get codec => throw _privateConstructorUsedError; // Bitrate
  int get bitrate => throw _privateConstructorUsedError; // Audio
  bool get isAudioOnly => throw _privateConstructorUsedError;
  String? get audioCodec => throw _privateConstructorUsedError;
  int? get audioBitrate => throw _privateConstructorUsedError;

  /// Create a copy of MediaFormat
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MediaFormatCopyWith<MediaFormat> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MediaFormatCopyWith<$Res> {
  factory $MediaFormatCopyWith(
          MediaFormat value, $Res Function(MediaFormat) then) =
      _$MediaFormatCopyWithImpl<$Res, MediaFormat>;
  @useResult
  $Res call(
      {String formatId,
      String url,
      String? qualityLabel,
      int? width,
      int? height,
      double? fps,
      String mimeType,
      String codec,
      int bitrate,
      bool isAudioOnly,
      String? audioCodec,
      int? audioBitrate});
}

/// @nodoc
class _$MediaFormatCopyWithImpl<$Res, $Val extends MediaFormat>
    implements $MediaFormatCopyWith<$Res> {
  _$MediaFormatCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MediaFormat
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? formatId = null,
    Object? url = null,
    Object? qualityLabel = freezed,
    Object? width = freezed,
    Object? height = freezed,
    Object? fps = freezed,
    Object? mimeType = null,
    Object? codec = null,
    Object? bitrate = null,
    Object? isAudioOnly = null,
    Object? audioCodec = freezed,
    Object? audioBitrate = freezed,
  }) {
    return _then(_value.copyWith(
      formatId: null == formatId
          ? _value.formatId
          : formatId // ignore: cast_nullable_to_non_nullable
              as String,
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      qualityLabel: freezed == qualityLabel
          ? _value.qualityLabel
          : qualityLabel // ignore: cast_nullable_to_non_nullable
              as String?,
      width: freezed == width
          ? _value.width
          : width // ignore: cast_nullable_to_non_nullable
              as int?,
      height: freezed == height
          ? _value.height
          : height // ignore: cast_nullable_to_non_nullable
              as int?,
      fps: freezed == fps
          ? _value.fps
          : fps // ignore: cast_nullable_to_non_nullable
              as double?,
      mimeType: null == mimeType
          ? _value.mimeType
          : mimeType // ignore: cast_nullable_to_non_nullable
              as String,
      codec: null == codec
          ? _value.codec
          : codec // ignore: cast_nullable_to_non_nullable
              as String,
      bitrate: null == bitrate
          ? _value.bitrate
          : bitrate // ignore: cast_nullable_to_non_nullable
              as int,
      isAudioOnly: null == isAudioOnly
          ? _value.isAudioOnly
          : isAudioOnly // ignore: cast_nullable_to_non_nullable
              as bool,
      audioCodec: freezed == audioCodec
          ? _value.audioCodec
          : audioCodec // ignore: cast_nullable_to_non_nullable
              as String?,
      audioBitrate: freezed == audioBitrate
          ? _value.audioBitrate
          : audioBitrate // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MediaFormatImplCopyWith<$Res>
    implements $MediaFormatCopyWith<$Res> {
  factory _$$MediaFormatImplCopyWith(
          _$MediaFormatImpl value, $Res Function(_$MediaFormatImpl) then) =
      __$$MediaFormatImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String formatId,
      String url,
      String? qualityLabel,
      int? width,
      int? height,
      double? fps,
      String mimeType,
      String codec,
      int bitrate,
      bool isAudioOnly,
      String? audioCodec,
      int? audioBitrate});
}

/// @nodoc
class __$$MediaFormatImplCopyWithImpl<$Res>
    extends _$MediaFormatCopyWithImpl<$Res, _$MediaFormatImpl>
    implements _$$MediaFormatImplCopyWith<$Res> {
  __$$MediaFormatImplCopyWithImpl(
      _$MediaFormatImpl _value, $Res Function(_$MediaFormatImpl) _then)
      : super(_value, _then);

  /// Create a copy of MediaFormat
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? formatId = null,
    Object? url = null,
    Object? qualityLabel = freezed,
    Object? width = freezed,
    Object? height = freezed,
    Object? fps = freezed,
    Object? mimeType = null,
    Object? codec = null,
    Object? bitrate = null,
    Object? isAudioOnly = null,
    Object? audioCodec = freezed,
    Object? audioBitrate = freezed,
  }) {
    return _then(_$MediaFormatImpl(
      formatId: null == formatId
          ? _value.formatId
          : formatId // ignore: cast_nullable_to_non_nullable
              as String,
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      qualityLabel: freezed == qualityLabel
          ? _value.qualityLabel
          : qualityLabel // ignore: cast_nullable_to_non_nullable
              as String?,
      width: freezed == width
          ? _value.width
          : width // ignore: cast_nullable_to_non_nullable
              as int?,
      height: freezed == height
          ? _value.height
          : height // ignore: cast_nullable_to_non_nullable
              as int?,
      fps: freezed == fps
          ? _value.fps
          : fps // ignore: cast_nullable_to_non_nullable
              as double?,
      mimeType: null == mimeType
          ? _value.mimeType
          : mimeType // ignore: cast_nullable_to_non_nullable
              as String,
      codec: null == codec
          ? _value.codec
          : codec // ignore: cast_nullable_to_non_nullable
              as String,
      bitrate: null == bitrate
          ? _value.bitrate
          : bitrate // ignore: cast_nullable_to_non_nullable
              as int,
      isAudioOnly: null == isAudioOnly
          ? _value.isAudioOnly
          : isAudioOnly // ignore: cast_nullable_to_non_nullable
              as bool,
      audioCodec: freezed == audioCodec
          ? _value.audioCodec
          : audioCodec // ignore: cast_nullable_to_non_nullable
              as String?,
      audioBitrate: freezed == audioBitrate
          ? _value.audioBitrate
          : audioBitrate // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc

class _$MediaFormatImpl extends _MediaFormat {
  const _$MediaFormatImpl(
      {required this.formatId,
      required this.url,
      this.qualityLabel,
      this.width,
      this.height,
      this.fps,
      required this.mimeType,
      required this.codec,
      required this.bitrate,
      this.isAudioOnly = false,
      this.audioCodec,
      this.audioBitrate})
      : super._();

  @override
  final String formatId;
  @override
  final String url;
// Quality
  @override
  final String? qualityLabel;
// e.g., "1080p", "720p60"
  @override
  final int? width;
  @override
  final int? height;
  @override
  final double? fps;
// Codec
  @override
  final String mimeType;
  @override
  final String codec;
// Bitrate
  @override
  final int bitrate;
// Audio
  @override
  @JsonKey()
  final bool isAudioOnly;
  @override
  final String? audioCodec;
  @override
  final int? audioBitrate;

  @override
  String toString() {
    return 'MediaFormat(formatId: $formatId, url: $url, qualityLabel: $qualityLabel, width: $width, height: $height, fps: $fps, mimeType: $mimeType, codec: $codec, bitrate: $bitrate, isAudioOnly: $isAudioOnly, audioCodec: $audioCodec, audioBitrate: $audioBitrate)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MediaFormatImpl &&
            (identical(other.formatId, formatId) ||
                other.formatId == formatId) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.qualityLabel, qualityLabel) ||
                other.qualityLabel == qualityLabel) &&
            (identical(other.width, width) || other.width == width) &&
            (identical(other.height, height) || other.height == height) &&
            (identical(other.fps, fps) || other.fps == fps) &&
            (identical(other.mimeType, mimeType) ||
                other.mimeType == mimeType) &&
            (identical(other.codec, codec) || other.codec == codec) &&
            (identical(other.bitrate, bitrate) || other.bitrate == bitrate) &&
            (identical(other.isAudioOnly, isAudioOnly) ||
                other.isAudioOnly == isAudioOnly) &&
            (identical(other.audioCodec, audioCodec) ||
                other.audioCodec == audioCodec) &&
            (identical(other.audioBitrate, audioBitrate) ||
                other.audioBitrate == audioBitrate));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      formatId,
      url,
      qualityLabel,
      width,
      height,
      fps,
      mimeType,
      codec,
      bitrate,
      isAudioOnly,
      audioCodec,
      audioBitrate);

  /// Create a copy of MediaFormat
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MediaFormatImplCopyWith<_$MediaFormatImpl> get copyWith =>
      __$$MediaFormatImplCopyWithImpl<_$MediaFormatImpl>(this, _$identity);
}

abstract class _MediaFormat extends MediaFormat {
  const factory _MediaFormat(
      {required final String formatId,
      required final String url,
      final String? qualityLabel,
      final int? width,
      final int? height,
      final double? fps,
      required final String mimeType,
      required final String codec,
      required final int bitrate,
      final bool isAudioOnly,
      final String? audioCodec,
      final int? audioBitrate}) = _$MediaFormatImpl;
  const _MediaFormat._() : super._();

  @override
  String get formatId;
  @override
  String get url; // Quality
  @override
  String? get qualityLabel; // e.g., "1080p", "720p60"
  @override
  int? get width;
  @override
  int? get height;
  @override
  double? get fps; // Codec
  @override
  String get mimeType;
  @override
  String get codec; // Bitrate
  @override
  int get bitrate; // Audio
  @override
  bool get isAudioOnly;
  @override
  String? get audioCodec;
  @override
  int? get audioBitrate;

  /// Create a copy of MediaFormat
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MediaFormatImplCopyWith<_$MediaFormatImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
