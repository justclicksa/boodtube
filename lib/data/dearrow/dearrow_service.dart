// ============================================================
// DeArrow — community titles and thumbnails instead of clickbait
// ============================================================
// API: GET https://sponsor.ajay.app/api/branding?videoID=<id>
// Response: {"titles":[{"title","original","votes","locked","UUID"}],
//            "thumbnails":[{"timestamp","original","votes","locked"}],
//            "randomTime":0.1,"videoDuration":123}
//
// Thumbnails are returned as a *timestamp*, not a URL: the frame is
// rendered on demand by DeArrow's thumbnail server.
// ============================================================

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/dearrow_data.dart';

class DeArrowService {
  DeArrowService(this._dio);

  final Dio _dio;

  static const _api = 'https://sponsor.ajay.app/api/branding';
  static const _thumbnailApi = 'https://dearrow-thumb.ajay.app/api/v1/getThumbnail';

  /// Returns community branding for [videoId], or null when there is
  /// none (the common case) or the request fails.
  Future<DeArrowData?> getDeArrowData(String videoId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _api,
        queryParameters: {'videoID': videoId},
        options: Options(
          receiveTimeout: const Duration(seconds: 8),
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      if (response.statusCode != 200 || response.data == null) return null;

      final title = _bestTitle(response.data!['titles']);
      final thumbnailTime = _bestThumbnailTime(response.data!['thumbnails']);
      if (title == null && thumbnailTime == null) return null;

      return DeArrowData(
        title: title,
        thumbnailUrl: thumbnailTime == null
            ? null
            : '$_thumbnailApi?videoID=$videoId&time=$thumbnailTime',
      );
    } catch (e) {
      debugPrint('DeArrow failed for $videoId: $e');
      return null;
    }
  }

  /// Prefers a locked entry, then the highest-voted one. Entries marked
  /// `original` are the uploader's own title and add nothing.
  static String? _bestTitle(dynamic titles) {
    final entries = _entries(titles).where((e) => e['original'] != true);
    if (entries.isEmpty) return null;
    final best = _highestRanked(entries);
    final title = best?['title'];
    return title is String && title.isNotEmpty ? title : null;
  }

  static double? _bestThumbnailTime(dynamic thumbnails) {
    final entries = _entries(thumbnails).where((e) => e['original'] != true);
    if (entries.isEmpty) return null;
    final best = _highestRanked(entries);
    final timestamp = best?['timestamp'];
    return timestamp is num ? timestamp.toDouble() : null;
  }

  static Iterable<Map<String, dynamic>> _entries(dynamic node) {
    if (node is! List) return const [];
    return node.whereType<Map<String, dynamic>>();
  }

  static Map<String, dynamic>? _highestRanked(
    Iterable<Map<String, dynamic>> entries,
  ) {
    Map<String, dynamic>? best;
    var bestScore = -1 << 30;
    for (final entry in entries) {
      final locked = entry['locked'] == true;
      final votes = (entry['votes'] as num?)?.toInt() ?? 0;
      // A locked entry always wins; otherwise most votes wins.
      final score = locked ? 1 << 20 : votes;
      if (score > bestScore) {
        bestScore = score;
        best = entry;
      }
    }
    return best;
  }
}
