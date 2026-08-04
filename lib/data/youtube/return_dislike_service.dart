// ============================================================
// Return YouTube Dislike
// ============================================================
// YouTube hid public dislike counts in 2021. This community API keeps
// serving them, and SmartTube surfaces the numbers the same way.
// Purely additive: any failure just means no counts are shown.
// ============================================================

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class VideoVotes {
  const VideoVotes({
    required this.likes,
    required this.dislikes,
    required this.viewCount,
    required this.rating,
  });

  final int likes;
  final int dislikes;
  final int viewCount;

  /// 1..5 star equivalent the API computes.
  final double rating;
}

class ReturnDislikeService {
  ReturnDislikeService(this._dio);

  final Dio _dio;

  static const _endpoint = 'https://returnyoutubedislikeapi.com/votes';

  Future<VideoVotes?> getVotes(String videoId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _endpoint,
        queryParameters: {'videoId': videoId},
        options: Options(
          receiveTimeout: const Duration(seconds: 8),
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final data = response.data;
      if (response.statusCode != 200 || data == null) return null;

      return VideoVotes(
        likes: (data['likes'] as num?)?.toInt() ?? 0,
        dislikes: (data['dislikes'] as num?)?.toInt() ?? 0,
        viewCount: (data['viewCount'] as num?)?.toInt() ?? 0,
        rating: (data['rating'] as num?)?.toDouble() ?? 0,
      );
    } catch (e) {
      debugPrint('ReturnDislike failed for $videoId: $e');
      return null;
    }
  }
}
