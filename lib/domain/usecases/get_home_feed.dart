// ============================================================
// Use Cases (Single-purpose business logic)
// ============================================================
// Each use case wraps one repository method with extra logic.
// FIXED: was missing from project but documented in strategy.

import '../../core/utils/result.dart';
import '../entities/media_group.dart';
import '../repositories/content_repository.dart';

class GetHomeFeed {
  final ContentRepository _repo;
  const GetHomeFeed(this._repo);

  Future<Result<List<MediaGroup>>> call() => _repo.getHomeFeed();
}
