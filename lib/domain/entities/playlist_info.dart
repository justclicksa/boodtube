// ============================================================
// PlaylistInfo - Freezed entity
// ============================================================

import 'package:freezed_annotation/freezed_annotation.dart';

part 'playlist_info.freezed.dart';

@freezed
class PlaylistInfo with _$PlaylistInfo {
  const factory PlaylistInfo({
    required String playlistId,
    required String title,
    String? description,
    String? thumbnailUrl,
    String? channelId,
    String? channelTitle,
    int? videoCount,
    DateTime? publishedAt,
    @Default(true) bool isPublic,
  }) = _PlaylistInfo;
}
