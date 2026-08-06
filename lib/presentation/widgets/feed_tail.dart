// ============================================================
// FeedTail — the row under the last card of a paged feed
// ============================================================

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../providers/content_providers.dart' show PagedFeed;

/// The row under the last card of a [PagedFeed]: a spinner while the
/// next page loads, an offer to retry a page that failed, or empty space
/// once the feed is exhausted.
///
/// A failed `loadMore()` never destroys the pages already on screen — a
/// feed four pages deep must not collapse into an error screen because
/// the fifth timed out — so the retry lives here at the bottom rather
/// than replacing the list.
class FeedTail extends StatelessWidget {
  const FeedTail({super.key, required this.feed, required this.onRetry});

  final PagedFeed feed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (feed.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (feed.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(AppLocalizations.of(context).retry),
          ),
        ),
      );
    }
    return const SizedBox(height: 24);
  }
}
