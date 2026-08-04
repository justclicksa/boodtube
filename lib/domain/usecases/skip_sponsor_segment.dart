// ============================================================
// SkipSponsorSegment Use Case
// ============================================================

import '../../core/utils/result.dart';
import '../entities/sponsor_segment.dart';
import '../repositories/media_item_repository.dart';

class SkipSponsorSegment {
  final MediaItemRepository _repo;
  const SkipSponsorSegment(this._repo);

  Future<Result<List<SponsorSegment>>> call(
    String videoId, {
    Set<SponsorCategory> categories = const {
      SponsorCategory.sponsor,
      SponsorCategory.intro,
      SponsorCategory.outro,
    },
  }) =>
      _repo.getSponsorSegments(videoId, categories: categories);
}
