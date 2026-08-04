// ============================================================
// SearchOptions - Freezed entity
// ============================================================

import 'package:freezed_annotation/freezed_annotation.dart';

part 'search_options.freezed.dart';

enum SearchSortBy { relevance, date, viewCount, rating }
enum SearchDuration { any, short, medium, long }
enum SearchUploadDate { any, hour, today, week, month, year }
enum SearchType { any, video, channel, playlist, movie }

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
