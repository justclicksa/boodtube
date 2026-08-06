// ============================================================
// SearchScreen - شاشة البحث الرئيسية
// ============================================================
// Three states, in the order the user moves through them:
//   1. nothing typed  → persisted search history
//   2. typing         → YouTube's own completions, debounced
//   3. submitted      → results for the query + the chosen filters
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/media_item.dart';
import '../../../domain/entities/search_options.dart';
import '../../../domain/repositories/content_repository.dart'
    show SearchFilters;
import '../../../l10n/app_localizations.dart';
import '../../providers/content_providers.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/video_card.dart';

// ============================================================
// Search history — persisted
// ============================================================

const _historyPrefsKey = 'search.history';
const _historyLimit = 12;

/// Recent queries, newest first, surviving app restarts.
class SearchHistory extends StateNotifier<List<String>> {
  SearchHistory(this._prefs)
      : super(_prefs.getStringList(_historyPrefsKey) ?? const []);

  final SharedPreferences _prefs;

  Future<void> add(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return Future.value();
    final next = [trimmed, ...state.where((q) => q != trimmed)];
    return _write(
      next.length > _historyLimit ? next.sublist(0, _historyLimit) : next,
    );
  }

  Future<void> remove(String query) =>
      _write(state.where((q) => q != query).toList());

  Future<void> clear() => _write(const []);

  Future<void> _write(List<String> next) async {
    state = next;
    await _prefs.setStringList(_historyPrefsKey, next);
  }
}

final searchHistoryProvider =
    StateNotifierProvider<SearchHistory, List<String>>((ref) {
  return SearchHistory(ref.watch(sharedPreferencesProvider));
});

// ============================================================
// Filters
// ============================================================

extension _FilterEditing on SearchFilters {
  /// [SearchFilters] is a hand-written value class in the domain layer
  /// with no `copyWith`, and the filter sheet needs one.
  SearchFilters replacing({
    SearchUploadDate? uploadDate,
    SearchType? type,
    SearchDuration? duration,
    SearchSortBy? sortBy,
  }) =>
      SearchFilters(
        uploadDate: uploadDate ?? this.uploadDate,
        type: type ?? this.type,
        duration: duration ?? this.duration,
        sortBy: sortBy ?? this.sortBy,
      );

  /// How many facets the user has moved off their default.
  int get activeCount => [
        uploadDate != SearchUploadDate.any,
        type != SearchType.any,
        duration != SearchDuration.any,
        sortBy != SearchSortBy.relevance,
      ].where((active) => active).length;
}

// ============================================================
// Screen
// ============================================================

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounceTimer;

  /// The text the suggestion request is allowed to use. Trails
  /// `_controller.text` by the debounce interval.
  String _debouncedQuery = '';

  /// The query whose results are on screen. Empty until the first submit.
  String _submittedQuery = '';

  /// False while the user is editing the field, so suggestions win over
  /// a stale result list.
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    // Every keystroke has to rebuild: the suggestion list, the clear
    // button and the results/suggestions switch all read the controller.
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller
      ..removeListener(_onTextChanged)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // Editing sends the user back to suggestions; the results they had
    // are for the previous query.
    setState(() => _showResults = false);
    final typed = _controller.text.trim();
    _debounceTimer?.cancel();
    if (typed.isEmpty) {
      setState(() => _debouncedQuery = '');
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _debouncedQuery = typed);
    });
  }

  void _submit(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _debounceTimer?.cancel();
    unawaited(ref.read(searchHistoryProvider.notifier).add(trimmed));
    // Kept in sync for anything else keyed on the global query.
    ref.read(searchQueryProvider.notifier).state = trimmed;
    _focusNode.unfocus();
    setState(() {
      _submittedQuery = trimmed;
      _showResults = true;
    });
  }

  /// Puts [query] in the field and searches for it in one step.
  void _searchFor(String query) {
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _submit(query);
  }

  void _retry() {
    if (_submittedQuery.isEmpty) return;
    ref.invalidate(searchResultsProvider(_submittedQuery));
  }

  void _setFilters(SearchFilters filters) {
    ref.read(searchFiltersProvider.notifier).state = filters;
    // Changing a filter is itself a search, as long as there is a query.
    if (_submittedQuery.isNotEmpty) setState(() => _showResults = true);
  }

  Future<void> _showFilterSheet() async {
    final chosen = await showModalBottomSheet<SearchFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(filters: ref.read(searchFiltersProvider)),
    );
    if (chosen != null) _setFilters(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filters = ref.watch(searchFiltersProvider);
    final filterCount = filters.activeCount;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.searchYouTube,
            border: InputBorder.none,
          ),
          onSubmitted: _submit,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: l10n.clearAll,
              onPressed: () {
                _controller.clear();
                _focusNode.requestFocus();
              },
            ),
          IconButton(
            icon: Badge(
              isLabelVisible: filterCount > 0,
              label: Text('$filterCount'),
              child: const Icon(Icons.tune),
            ),
            tooltip: filterCount == 0
                ? l10n.searchFilters
                : l10n.activeFilterCount(filterCount),
            onPressed: _showFilterSheet,
          ),
        ],
        bottom: filterCount == 0
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: _ActiveFilterBar(
                  filters: filters,
                  onChanged: _setFilters,
                ),
              ),
      ),
      body: OfflineAwareBody(
        // Coming back online re-runs whatever the user was looking at.
        onReconnected: _retry,
        child: _showResults && _submittedQuery.isNotEmpty
            ? _buildResults(context, filters)
            : _buildHistoryAndSuggestions(context),
      ),
    );
  }

  // ============================================================
  // History + suggestions
  // ============================================================

  Widget _buildHistoryAndSuggestions(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final history = ref.watch(searchHistoryProvider);
    final typed = _controller.text.trim();

    // Suggestions replace history the moment there is something to
    // complete — that is what makes them reachable at all.
    final suggestions = typed.isEmpty
        ? const <String>[]
        : ref.watch(searchSuggestionsProvider(_debouncedQuery)).valueOrNull ??
            const <String>[];

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (typed.isEmpty && history.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
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
                    unawaited(ref.read(searchHistoryProvider.notifier).clear());
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
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: l10n.removeFromHistory,
                onPressed: () {
                  unawaited(
                    ref.read(searchHistoryProvider.notifier).remove(item),
                  );
                },
              ),
              onTap: () => _searchFor(item),
            ),
        ],
        for (final suggestion in suggestions)
          ListTile(
            leading: const Icon(Icons.search),
            title: Text(suggestion),
            // Fills the field without searching, the way YouTube's arrow
            // does, so the user can keep refining.
            trailing: IconButton(
              icon: const Icon(Icons.north_west, size: 18),
              onPressed: () {
                _controller.value = TextEditingValue(
                  text: suggestion,
                  selection: TextSelection.collapsed(offset: suggestion.length),
                );
              },
            ),
            onTap: () => _searchFor(suggestion),
          ),
      ],
    );
  }

  // ============================================================
  // Results
  // ============================================================

  Widget _buildResults(BuildContext context, SearchFilters filters) {
    // searchResultsProvider watches searchFiltersProvider itself, so the
    // family key stays the query alone.
    final resultsAsync = ref.watch(searchResultsProvider(_submittedQuery));
    return resultsAsync.when(
      data: (group) => _buildResultList(context, group.mediaItems, filters),
      loading: LoadingView.new,
      error: (e, st) => ErrorView(error: e, onRetry: _retry),
    );
  }

  Widget _buildResultList(
    BuildContext context,
    List<MediaItem> items,
    SearchFilters filters,
  ) {
    final l10n = AppLocalizations.of(context);

    if (items.isEmpty) {
      return EmptyView(
        icon: Icons.search_off,
        title: l10n.noResults,
        subtitle: l10n.noResultsSubtitle,
        action: FilledButton.icon(
          onPressed: _retry,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.retry),
        ),
        secondaryAction: filters.activeCount == 0
            ? null
            : TextButton(
                onPressed: () => _setFilters(const SearchFilters()),
                child: Text(l10n.clearFilters),
              ),
      );
    }

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: VideoCard(
            item: item,
            isHorizontal: true,
            onTap: () => context.push('/player/${item.videoId}'),
          ),
        );
      },
    );
  }
}

// ============================================================
// Active filter chips
// ============================================================

class _ActiveFilterBar extends StatelessWidget {
  const _ActiveFilterBar({required this.filters, required this.onChanged});

  final SearchFilters filters;
  final ValueChanged<SearchFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          if (filters.uploadDate != SearchUploadDate.any)
            _chip(
              label: uploadDateLabel(l10n, filters.uploadDate),
              onDeleted: () => onChanged(
                filters.replacing(uploadDate: SearchUploadDate.any),
              ),
            ),
          if (filters.type != SearchType.any)
            _chip(
              label: searchTypeLabel(l10n, filters.type),
              onDeleted: () =>
                  onChanged(filters.replacing(type: SearchType.any)),
            ),
          if (filters.duration != SearchDuration.any)
            _chip(
              label: searchDurationLabel(l10n, filters.duration),
              onDeleted: () => onChanged(
                filters.replacing(duration: SearchDuration.any),
              ),
            ),
          if (filters.sortBy != SearchSortBy.relevance)
            _chip(
              label: sortByLabel(l10n, filters.sortBy),
              onDeleted: () => onChanged(
                filters.replacing(sortBy: SearchSortBy.relevance),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: TextButton(
              onPressed: () => onChanged(const SearchFilters()),
              child: Text(l10n.clearFilters),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip({required String label, required VoidCallback onDeleted}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: InputChip(
        label: Text(label),
        onDeleted: onDeleted,
      ),
    );
  }
}

// ============================================================
// Filter sheet
// ============================================================

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.filters});

  final SearchFilters filters;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late SearchFilters _draft = widget.filters;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.searchFilters,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _draft = const SearchFilters()),
                    child: Text(l10n.resetFilters),
                  ),
                ],
              ),
              _group<SearchUploadDate>(
                title: l10n.searchFilterUploadDate,
                values: SearchUploadDate.values,
                selected: _draft.uploadDate,
                label: (v) => uploadDateLabel(l10n, v),
                onSelected: (v) =>
                    setState(() => _draft = _draft.replacing(uploadDate: v)),
              ),
              _group<SearchType>(
                title: l10n.searchFilterType,
                values: SearchType.values,
                selected: _draft.type,
                label: (v) => searchTypeLabel(l10n, v),
                onSelected: (v) =>
                    setState(() => _draft = _draft.replacing(type: v)),
              ),
              _group<SearchDuration>(
                title: l10n.searchFilterDuration,
                values: SearchDuration.values,
                selected: _draft.duration,
                label: (v) => searchDurationLabel(l10n, v),
                onSelected: (v) =>
                    setState(() => _draft = _draft.replacing(duration: v)),
              ),
              _group<SearchSortBy>(
                title: l10n.searchFilterSortBy,
                values: SearchSortBy.values,
                selected: _draft.sortBy,
                label: (v) => sortByLabel(l10n, v),
                onSelected: (v) =>
                    setState(() => _draft = _draft.replacing(sortBy: v)),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_draft),
                  child: Text(l10n.search),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _group<T>({
    required String title,
    required List<T> values,
    required T selected,
    required String Function(T value) label,
    required ValueChanged<T> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final value in values)
              ChoiceChip(
                label: Text(label(value)),
                selected: value == selected,
                onSelected: (_) => onSelected(value),
              ),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// Localized labels for the search facets
// ============================================================

String uploadDateLabel(AppLocalizations l10n, SearchUploadDate value) =>
    switch (value) {
      SearchUploadDate.any => l10n.searchFilterAny,
      SearchUploadDate.hour => l10n.uploadDateLastHour,
      SearchUploadDate.today => l10n.uploadDateToday,
      SearchUploadDate.week => l10n.uploadDateThisWeek,
      SearchUploadDate.month => l10n.uploadDateThisMonth,
      SearchUploadDate.year => l10n.uploadDateThisYear,
    };

String searchTypeLabel(AppLocalizations l10n, SearchType value) =>
    switch (value) {
      SearchType.any => l10n.searchFilterAny,
      SearchType.video => l10n.searchTypeVideo,
      SearchType.movie => l10n.searchTypeMovie,
    };

String searchDurationLabel(AppLocalizations l10n, SearchDuration value) =>
    switch (value) {
      SearchDuration.any => l10n.searchFilterAny,
      SearchDuration.short => l10n.searchDurationShort,
      SearchDuration.medium => l10n.searchDurationMedium,
      SearchDuration.long => l10n.searchDurationLong,
    };

String sortByLabel(AppLocalizations l10n, SearchSortBy value) =>
    switch (value) {
      SearchSortBy.relevance => l10n.sortByRelevance,
      SearchSortBy.date => l10n.sortByUploadDate,
      SearchSortBy.viewCount => l10n.sortByViewCount,
      SearchSortBy.rating => l10n.sortByRating,
    };
