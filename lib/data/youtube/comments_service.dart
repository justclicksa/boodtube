// ============================================================
// CommentsService - YouTube comments via youtube_explode_dart v3
// ============================================================
// FIXED: uses real API:
//   - CommentsClient.getComments(Video video) not getComments(VideoId)
//   - Comment fields: author, channelId, text, likeCount, publishedTime (String!), replyCount, isHearted, continuation
//   - No id, isPinned, or thumbnail fields in Comment
// ============================================================

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../core/errors/exceptions.dart';
import '../../domain/entities/comment_item.dart';

class CommentsService {
  final YoutubeExplode _yt;

  CommentsService(this._yt);

  /// Get comments for a video
  ///
  /// FIXED: YouTube's getComments requires a Video object (not VideoId)
  /// We need to fetch the Video first.
  Future<List<CommentItem>> getComments(String videoId) async {
    try {
      // 1) Fetch the video first (required by API)
      final video = await _yt.videos.get(videoId);

      // 2) Get comments
      final commentsList = await _yt.videos.commentsClient.getComments(video);
      if (commentsList == null) {
        return []; // comments disabled
      }

      // 3) Map to our entity
      return commentsList
          .map((c) => CommentItem(
                // FIXED: no id field in Comment, use channelId + text hash
                id: '${c.channelId.value}_${c.text.hashCode}',
                author: c.author,
                authorChannelId: c.channelId.value,
                authorAvatarUrl: null, // FIXED: not in Comment
                content: c.text,
                // FIXED: publishedTime is String, not DateTime
                // Convert "2 years ago" -> DateTime
                publishedAt: _parsePublishedTime(c.publishedTime),
                likeCount: c.likeCount,
                replyCount: c.replyCount > 0 ? c.replyCount : null,
                parentId: null,
                isHearted: c.isHearted,
                isPinned: false, // FIXED: not in Comment
              ))
          .toList();
    } on Exception {
      rethrow;
    } catch (e) {
      // A parse failure is not "this video has comments turned off", and
      // swallowing it here is what made the comment sheet look empty on
      // every video instead of broken on all of them. youtube_explode
      // reads a commentRenderer YouTube no longer sends, so its null
      // check throws for every video; the caller has to be able to say
      // so rather than render nothing.
      throw ParseException(e.toString());
    }
  }

  /// Get replies to a specific comment
  Future<List<CommentItem>> getReplies(String videoId, String commentId) async {
    try {
      final video = await _yt.videos.get(videoId);

      // Find the comment
      final commentsList = await _yt.videos.commentsClient.getComments(video);
      if (commentsList == null) return [];

      // The API: we need a Comment object to call getReplies
      // For PoC, we'll fetch top-level comments and filter by id
      // (full implementation would track the Comment object)
      // FIXED: getReplies takes Comment, not videoId + commentId
      // This is a simplified version

      return []; // PoC: not implemented
    } catch (e) {
      return [];
    }
  }

  /// Parse YouTube's "X ago" string to DateTime
  DateTime _parsePublishedTime(String time) {
    final now = DateTime.now();
    final lower = time.toLowerCase();

    if (lower.contains('minute')) {
      final match = RegExp(r'(\d+)').firstMatch(lower);
      if (match != null) {
        return now.subtract(Duration(minutes: int.parse(match.group(1)!)));
      }
    } else if (lower.contains('hour')) {
      final match = RegExp(r'(\d+)').firstMatch(lower);
      if (match != null) {
        return now.subtract(Duration(hours: int.parse(match.group(1)!)));
      }
    } else if (lower.contains('day')) {
      final match = RegExp(r'(\d+)').firstMatch(lower);
      if (match != null) {
        return now.subtract(Duration(days: int.parse(match.group(1)!)));
      }
    } else if (lower.contains('week')) {
      final match = RegExp(r'(\d+)').firstMatch(lower);
      if (match != null) {
        return now.subtract(Duration(days: int.parse(match.group(1)!) * 7));
      }
    } else if (lower.contains('month')) {
      final match = RegExp(r'(\d+)').firstMatch(lower);
      if (match != null) {
        return now.subtract(Duration(days: int.parse(match.group(1)!) * 30));
      }
    } else if (lower.contains('year')) {
      final match = RegExp(r'(\d+)').firstMatch(lower);
      if (match != null) {
        return now.subtract(Duration(days: int.parse(match.group(1)!) * 365));
      }
    } else if (lower.contains('second')) {
      return now.subtract(const Duration(seconds: 30));
    }

    return now;
  }
}
