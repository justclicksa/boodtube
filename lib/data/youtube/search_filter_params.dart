// ============================================================
// Search filters -> YouTube's `sp` parameter
// ============================================================
// YouTube encodes the filter panel's state as a protobuf message,
// base64'd into the `sp` query parameter of the results page:
//
//   field 1 (varint)   sort order
//   field 2 (message)  filters
//     field 1 (varint) upload date
//     field 2 (varint) result type
//     field 3 (varint) duration
//
// youtube_explode ships one constant per single filter (TypeFilters,
// UploadDateFilter, ...) and no way to combine two of them — its values
// are exactly the messages below with one field set. Building the
// message here means "last month" + "long" + "sort by views" is a
// single request, the way the website does it, instead of a choice of
// one filter.
// ============================================================

import 'dart:convert';

import 'package:youtube_explode_dart/youtube_explode_dart.dart'
    show SearchFilter;

import '../../domain/entities/search_options.dart';
import '../../domain/repositories/content_repository.dart' show SearchFilters;

/// The `sp` value for [filters], or an empty filter when nothing is set.
SearchFilter searchFilterFor(SearchFilters filters) {
  final nested = <int>[
    ..._varint(1, _uploadDateCode(filters.uploadDate)),
    ..._varint(2, _typeCode(filters.type)),
    ..._varint(3, _durationCode(filters.duration)),
  ];

  final message = <int>[
    // The sort field is always sent — YouTube reads its absence as
    // "relevance" too, but the website sends it explicitly.
    0x08, _sortCode(filters.sortBy),
    if (nested.isNotEmpty) ...[0x12, nested.length, ...nested],
  ];

  // Unpadded base64url: `sp` is read as websafe base64, and leaving the
  // padding off avoids the `%3D` escaping dance (youtube_explode splices
  // the value into the URL unencoded).
  final encoded = base64Url.encode(message).replaceAll('=', '');
  return SearchFilter(encoded);
}

/// A field is omitted entirely when the user asked for "any".
List<int> _varint(int field, int? value) =>
    value == null ? const [] : [field << 3, value];

int _sortCode(SearchSortBy sortBy) => switch (sortBy) {
      SearchSortBy.relevance => 0,
      SearchSortBy.rating => 1,
      SearchSortBy.date => 2,
      SearchSortBy.viewCount => 3,
    };

int? _uploadDateCode(SearchUploadDate uploadDate) => switch (uploadDate) {
      SearchUploadDate.any => null,
      SearchUploadDate.hour => 1,
      SearchUploadDate.today => 2,
      SearchUploadDate.week => 3,
      SearchUploadDate.month => 4,
      SearchUploadDate.year => 5,
    };

int? _typeCode(SearchType type) => switch (type) {
      // "Any" still means video for us: the feed entities this app builds
      // are videos, so an unfiltered query is asked for as a video query.
      SearchType.any => 1,
      SearchType.video => 1,
      SearchType.movie => 4,
    };

int? _durationCode(SearchDuration duration) => switch (duration) {
      SearchDuration.any => null,
      SearchDuration.short => 1,
      SearchDuration.long => 2,
      SearchDuration.medium => 3,
    };
