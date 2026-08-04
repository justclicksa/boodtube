// ============================================================
// SearchVideos Use Case
// ============================================================

import '../../core/utils/result.dart';
import '../entities/media_group.dart';
import '../repositories/content_repository.dart';

class SearchVideos {
  final ContentRepository _repo;
  const SearchVideos(this._repo);

  Future<Result<MediaGroup>> call(
    String query, {
    String? pageToken,
    SearchFilters filters = const SearchFilters(),
  }) {
    if (query.trim().isEmpty) {
      return Future.value(
        Success(
          MediaGroup(
            title: '',
            type: MediaGroupType.search,
            mediaItems: const [],
          ),
        ),
      );
    }
    return _repo.search(query, pageToken: pageToken, filters: filters);
  }
}
