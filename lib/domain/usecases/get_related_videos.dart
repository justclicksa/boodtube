// ============================================================
// GetRelatedVideos Use Case
// ============================================================
// YouTube's own "up next" list for a video — the watch page's sidebar,
// not a text search for the title (which returns re-uploads of the very
// video being watched).
// ============================================================

import '../../core/utils/result.dart';
import '../entities/media_page.dart';
import '../repositories/content_repository.dart';

class GetRelatedVideos {
  final ContentRepository _repo;
  const GetRelatedVideos(this._repo);

  Future<Result<MediaPage>> call(String videoId, {String? pageToken}) =>
      _repo.getRelatedVideos(videoId, pageToken: pageToken);
}
