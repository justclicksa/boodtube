// ============================================================
// SearchScreen - شاشة البحث الرئيسية
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/media_item.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/content_providers.dart';
import '../../widgets/video_card.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';

/// Starts empty — seeding it with sample queries made the app look like
/// it had a search history the user never typed.
final _searchHistoryProvider = StateProvider<List<String>>((ref) => []);

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      ref.read(searchQueryProvider.notifier).state = query;
    });
  }

  void _addToHistory(String query) {
    if (query.trim().isEmpty) return;
    final history = [...ref.read(_searchHistoryProvider)];
    history.remove(query);
    history.insert(0, query);
    if (history.length > 10) history.removeLast();
    ref.read(_searchHistoryProvider.notifier).state = history;
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final resultsAsync = ref.watch(searchResultsProvider(query));
    final history = ref.watch(_searchHistoryProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: l10n.searchYouTube,
            border: InputBorder.none,
          ),
          onChanged: _onQueryChanged,
          onSubmitted: (q) {
            _addToHistory(q);
            // FIXED: stay on search screen and show results
            ref.read(searchQueryProvider.notifier).state = q;
          },
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                _onQueryChanged('');
              },
            ),
        ],
      ),
      body: query.isEmpty
          ? _buildHistoryAndSuggestions(context, history)
          : resultsAsync.when(
              data: (group) => _buildResults(context, group.mediaItems),
              loading: () => const LoadingView(),
              error: (e, st) => ErrorView(error: e, onRetry: () {
                ref.invalidate(searchResultsProvider(query));
              }),
            ),
    );
  }

  Widget _buildHistoryAndSuggestions(
    BuildContext context,
    List<String> history,
  ) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      children: [
        // History
        if (history.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.recentSearches,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(_searchHistoryProvider.notifier).state = [];
                  },
                  child: Text(l10n.clearAll),
                ),
              ],
            ),
          ),
          for (final item in history)
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(item),
              trailing: const Icon(Icons.north_west, size: 18),
              onTap: () {
                _controller.text = item;
                _onQueryChanged(item);
              },
            ),
        ],

        // YouTube's own completions for what has been typed so far.
        Consumer(
          builder: (context, ref, _) {
            final typed = _controller.text.trim();
            if (typed.isEmpty) return const SizedBox.shrink();
            final suggestions = ref.watch(searchSuggestionsProvider(typed));
            return suggestions.maybeWhen(
              data: (list) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final suggestion in list)
                    ListTile(
                      leading: const Icon(Icons.search),
                      title: Text(suggestion),
                      trailing: const Icon(Icons.north_west, size: 18),
                      onTap: () {
                        _controller.text = suggestion;
                        _onQueryChanged(suggestion);
                      },
                    ),
                ],
              ),
              orElse: () => const SizedBox.shrink(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildResults(BuildContext context, List<MediaItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            AppLocalizations.of(context).noResults,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: VideoCard(
            item: item,
            isHorizontal: true,
            onTap: () {
              _addToHistory(ref.read(searchQueryProvider));
              context.push('/player/${item.videoId}');
            },
          ),
        );
      },
    );
  }
}
