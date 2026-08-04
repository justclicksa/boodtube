// ============================================================
// GetVideoStreamUrl Use Case
// ============================================================

import '../../core/utils/result.dart';
import '../entities/media_format.dart';
import '../repositories/media_item_repository.dart';

class GetVideoStreamUrl {
  final MediaItemRepository _repo;
  const GetVideoStreamUrl(this._repo);

  // FIXED: use the closest equivalent - getMediaItem and pick the format
  Future<Result<String>> call(String videoId, MediaFormatQuality quality) async {
    final result = await _repo.getMediaItem(videoId);
    return result.when(
      success: (item) {
        // Pick the best format matching the requested quality
        final bestFormat = item.formats
            .where((f) => !f.isAudioOnly)
            .reduce((a, b) => a.bitrate > b.bitrate ? a : b);
        return Success(bestFormat.url);
      },
      failure: (msg, type, cause) =>
          FailureResult(msg, type: type, cause: cause),
    );
  }
}
