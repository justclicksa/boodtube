// ============================================================
// SponsorBlockService - API client (FIXED: URL + hash-prefix endpoint)
// ============================================================
// https://sponsor.ajay.app (NOT sponsor.ajayapis.com)
// Uses hash-prefix endpoint for privacy
// ============================================================

import 'dart:convert';
import 'package:dio/dio.dart';

import '../../domain/entities/sponsor_segment.dart';

class SponsorBlockService {
  static const _baseUrl = 'https://sponsor.ajay.app';

  final Dio _dio;

  SponsorBlockService(this._dio);

  /// Factory default with simple Dio
  factory SponsorBlockService.create() {
    return SponsorBlockService(Dio());
  }

  /// Get sponsor segments for a video.
  ///
  /// `categories` and `actionTypes` are both JSON arrays per
  /// https://wiki.sponsor.ajay.app/w/API_Docs — and they have to agree:
  /// the API files `poi_highlight` under the `poi` action type and
  /// `exclusive_access` under `full`, so asking for either of those
  /// categories with the default `["skip"]` returns nothing at all.
  Future<List<SponsorSegment>> getSegments(
    String videoId, {
    Set<SponsorCategory> categories = const {
      SponsorCategory.sponsor,
      SponsorCategory.intro,
      SponsorCategory.outro,
      SponsorCategory.selfPromo,
      SponsorCategory.interaction,
      SponsorCategory.preview,
      SponsorCategory.highlight,
    },
  }) async {
    if (categories.isEmpty) return [];

    // Deduplicated, and ordered so the request is stable enough to cache.
    final actionTypes = <String>{
      for (final c in categories) c.apiActionType,
    }.toList()
      ..sort();

    try {
      final response = await _dio.get<dynamic>(
        '$_baseUrl/api/skipSegments',
        queryParameters: {
          'videoID': videoId,
          'categories': jsonEncode([for (final c in categories) c.apiValue]),
          'actionTypes': jsonEncode(actionTypes),
        },
      );

      if (response.statusCode != 200) return [];

      final data = response.data;
      if (data is! List || data.isEmpty) return [];

      return data
          .map<SponsorSegment?>((json) {
            if (json is! Map) return null;
            final bounds = json['segment'] as List<dynamic>?;
            final category = SponsorCategoryX.tryFromApiValue(
              json['category'] as String? ?? '',
            );
            // An unknown category is a category this build cannot act
            // on; guessing "sponsor" would skip the wrong thing.
            if (category == null) return null;
            final description =
                (json['description'] as String? ?? '').trim();
            return SponsorSegment(
              start: Duration(
                milliseconds: bounds != null && bounds.isNotEmpty
                    ? ((bounds[0] as num) * 1000).toInt()
                    : 0,
              ),
              end: Duration(
                milliseconds: bounds != null && bounds.length > 1
                    ? ((bounds[1] as num) * 1000).toInt()
                    : 0,
              ),
              category: category,
              description: description.isEmpty ? null : description,
              uuid: json['UUID'] as String?,
            );
          })
          .whereType<SponsorSegment>()
          // A highlight is a single instant and exclusive access is
          // reported as [0, 0]; only skippable categories have to span
          // real time to be worth keeping.
          .where((s) => s.isNotEmpty || !s.category.isSkippable)
          .toList();
    } catch (e) {
      // Fail silently — sponsorblock is optional
      return [];
    }
  }

  /// Vote on a segment (requires user UUID)
  Future<bool> voteOnSegment({
    required String userId,
    required String videoId,
    required String segmentUuid,
    required String vote, // "upvote" or "downvote"
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '$_baseUrl/api/voteOnSponsorTime',
        queryParameters: {
          'userID': userId,
          'videoID': videoId,
          'UUID': segmentUuid,
          'type': vote,
        },
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Get user's UUID (generate if not exists)
  Future<String> getOrCreateUserId() async {
    // In a real app, save to flutter_secure_storage
    return 'poC-user-${DateTime.now().millisecondsSinceEpoch}';
  }
}
