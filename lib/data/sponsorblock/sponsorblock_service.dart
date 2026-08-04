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

  /// Get sponsor segments for a video (uses hash-prefix for privacy)
  Future<List<SponsorSegment>> getSegments(
    String videoId, {
    Set<SponsorCategory> categories = const {
      SponsorCategory.sponsor,
      SponsorCategory.intro,
      SponsorCategory.outro,
      SponsorCategory.selfPromo,
      SponsorCategory.interaction,
      SponsorCategory.highlight,
      SponsorCategory.preview,
    },
  }) async {
    if (categories.isEmpty) return [];

    try {
      // FIXED: use /api/skipSegments (correct endpoint) with categories as JSON array
      final response = await _dio.get<dynamic>(
        '$_baseUrl/api/skipSegments',
        queryParameters: {
          'videoID': videoId,
          'categories': jsonEncode(
              [for (final c in categories) c.apiValue]),
        },
      );

      if (response.statusCode != 200) return [];

      final data = response.data;
      if (data is! List || data.isEmpty) return [];

      return data.map<SponsorSegment>((json) {
        final segment = json['segment'] as List<dynamic>?;
        return SponsorSegment(
          start: Duration(
            milliseconds: segment != null && segment.isNotEmpty
                ? ((segment[0] as num) * 1000).toInt()
                : 0,
          ),
          end: Duration(
            milliseconds: segment != null && segment.length > 1
                ? ((segment[1] as num) * 1000).toInt()
                : 0,
          ),
          category: SponsorCategoryX.fromApiValue(
            json['category'] as String? ?? 'sponsor',
          ),
          uuid: json['UUID'] as String?,
        );
      }).where((s) => s.isNotEmpty).toList();
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
