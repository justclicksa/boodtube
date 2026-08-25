import 'package:http_parser/http_parser.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../../reverse_engineering/models/fragment.dart';
import '../../video_id.dart';
import '../mixins/stream_info.dart';
import '../models/audio_track.dart';
import '../streams.dart';

part 'audio_only_stream_info.g.dart';

/// YouTube media stream that only contains audio.
@JsonSerializable()
class AudioOnlyStreamInfo with StreamInfo, AudioStreamInfo {
  @override
  final VideoId videoId;

  @override
  final int tag;

  @override
  final Uri url;

  @override
  final StreamContainer container;

  @override
  final FileSize size;

  @override
  final Bitrate bitrate;

  @override
  final String audioCodec;

  @override
  @JsonKey(toJson: mediaTypeToJson, fromJson: mediaTypeFromJson)
  final MediaType codec;

  @override
  final List<Fragment> fragments;

  @override
  final String qualityLabel;

  @override
  final AudioTrack? audioTrack;

  @override
  final String? initRange;

  @override
  final String? indexRange;

  @override
  final int? audioSamplingRate;

  AudioOnlyStreamInfo(
    this.videoId,
    this.tag,
    this.url,
    this.container,
    this.size,
    this.bitrate,
    this.audioCodec,
    this.qualityLabel,
    this.fragments,
    this.codec,
    this.audioTrack, {
    this.initRange,
    this.indexRange,
    this.audioSamplingRate,
  });

  @override
  String toString() =>
      'Audio-only ($tag | $container | ${audioTrack?.displayName})';

  factory AudioOnlyStreamInfo.fromJson(Map<String, dynamic> json) =>
      _$AudioOnlyStreamInfoFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$AudioOnlyStreamInfoToJson(this);
}
