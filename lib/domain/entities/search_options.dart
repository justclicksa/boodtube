// ============================================================
// SearchOptions - Freezed entity
// ============================================================

import 'package:freezed_annotation/freezed_annotation.dart';

part 'search_options.freezed.dart';

enum SearchSortBy { relevance, date, viewCount, rating }

enum SearchDuration { any, short, medium, long }

enum SearchUploadDate { any, hour, today, week, month, year }

/// What kind of result the search should return.
///
/// Channel and playlist are deliberately absent. YouTube honours both
/// (`sp` type 2 and 3), but every result then comes back as a
/// `SearchChannel` / `SearchPlaylist`, and this app's result models —
/// `MediaGroup` of `MediaItem` — describe a video: a video id, a
/// duration, an upload date, a card that opens the player. There is
/// nothing truthful to turn a channel or a playlist into, so the search
/// simply returned nothing and the filter offered two choices that did
/// not work. Movies are videos and do work, so they stay.
enum SearchType { any, video, movie }

@freezed
class SearchOptions with _$SearchOptions {
  const factory SearchOptions({
    @Default('') String query,
    @Default(SearchSortBy.relevance) SearchSortBy sortBy,
    @Default(SearchDuration.any) SearchDuration duration,
    @Default(SearchUploadDate.any) SearchUploadDate uploadDate,
    @Default(SearchType.any) SearchType type,
  }) = _SearchOptions;
}
