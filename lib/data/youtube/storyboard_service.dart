// ============================================================
// Storyboards — YouTube's seek-preview thumbnail sheets
// ============================================================
// A storyboard is one JPEG "contact sheet" holding a grid of small
// frames sampled at a fixed interval. Dragging the scrubber shows the
// frame under the finger by cropping the right cell out of the sheet.
//
// The player response carries a single packed spec string:
//
//   <baseUrl>|<level>|<level>|<level>
//   level = width#height#count#cols#rows#interval#name#sigh
//
// The base URL contains `$L` (level index) and `$N` (the level's image
// name, itself usually `M$M` where `$M` is the sheet number). Example:
//
//   https://i.ytimg.com/sb/ID/storyboard3_L$L/$N.jpg?sqp=-oaymw
//   |48#27#100#10#10#0#default#rs$AOn4A
//   |80#45#90#10#10#2000#M$M#rs$AOn4B
//   |160#90#90#5#5#2000#M$M#rs$AOn4C
//
// This mirrors SmartTube's YouTubeStoryParser, minus its off-by-one on
// the row index (it divides the frame number by the row count instead
// of the column count, which mis-picks the cell on non-square grids).
// ============================================================

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// One resolution level of a storyboard spec.
@immutable
class StoryboardLevel {
  const StoryboardLevel({
    required this.index,
    required this.width,
    required this.height,
    required this.frameCount,
    required this.columns,
    required this.rows,
    required this.interval,
    required this.name,
    this.signature,
  });

  /// Value substituted for `$L` in the base URL.
  final int index;

  /// Size of a single frame inside the sheet, in pixels.
  final int width;
  final int height;

  /// Total frames this level holds across all of its sheets.
  final int frameCount;

  /// Grid of the sheet.
  final int columns;
  final int rows;

  /// Playback time each frame covers. Zero for the coarse level 0,
  /// which samples the whole video into one sheet instead.
  final Duration interval;

  /// Value substituted for `$N` — usually `M$M`.
  final String name;

  /// `sigh` query parameter the CDN requires.
  final String? signature;

  int get framesPerSheet => columns * rows;

  int get sheetCount {
    if (framesPerSheet <= 0 || frameCount <= 0) return 0;
    return (frameCount + framesPerSheet - 1) ~/ framesPerSheet;
  }

  /// Whether frames can be addressed by playback time.
  bool get isTimeIndexed =>
      interval > Duration.zero && columns > 0 && rows > 0;
}

/// One frame: which sheet to fetch and which cell of it to show.
@immutable
class StoryboardTile {
  const StoryboardTile({
    required this.sheetUrl,
    required this.sheetIndex,
    required this.column,
    required this.row,
    required this.columns,
    required this.rows,
    required this.tileWidth,
    required this.tileHeight,
    required this.start,
  });

  final String sheetUrl;
  final int sheetIndex;

  /// Zero-based cell coordinates inside [sheetUrl].
  final int column;
  final int row;

  /// Grid of the sheet, needed to crop the cell out of it.
  final int columns;
  final int rows;

  /// Size of the cell in the sheet's own pixels.
  final int tileWidth;
  final int tileHeight;

  /// Playback position this frame was sampled at.
  final Duration start;

  double get aspectRatio =>
      tileHeight == 0 ? 16 / 9 : tileWidth / tileHeight;

  @override
  bool operator ==(Object other) =>
      other is StoryboardTile &&
      other.sheetUrl == sheetUrl &&
      other.column == column &&
      other.row == row;

  @override
  int get hashCode => Object.hash(sheetUrl, column, row);
}

/// A parsed `playerStoryboardSpecRenderer.spec`.
@immutable
class StoryboardSpec {
  const StoryboardSpec({required this.baseUrl, required this.levels});

  /// URL template still holding its `$L`/`$N`/`$M` placeholders.
  final String baseUrl;

  /// Levels in spec order — coarsest first.
  final List<StoryboardLevel> levels;

  /// Frame width the seek bubble is happiest with. The level closest to
  /// it wins: on YouTube's usual three-level spec that is the 160×90
  /// mid level — readable, and a sheet of it is a few dozen KB.
  static const _targetTileWidth = 160;

  /// A level needs at least width#height#count#cols#rows#interval;
  /// name and sigh are optional tails.
  static const _minLevelFields = 6;

  /// Parses the packed spec string. Returns null when it is absent,
  /// malformed, or the single-section live form (which carries no frame
  /// interval, so a position cannot be mapped to a cell).
  static StoryboardSpec? parse(String? spec) {
    if (spec == null || spec.isEmpty) return null;

    // Specs lifted out of raw JSON still carry escaped slashes.
    final sections = spec.replaceAll(r'\/', '/').split('|');
    if (sections.length < 2) return null;

    final levels = <StoryboardLevel>[];
    for (var index = 1; index < sections.length; index++) {
      final level = _parseLevel(sections[index], index - 1);
      if (level != null) levels.add(level);
    }
    if (levels.isEmpty) return null;

    return StoryboardSpec(baseUrl: sections.first, levels: levels);
  }

  /// Pulls the spec out of a raw InnerTube `player` response.
  static StoryboardSpec? fromPlayerResponse(Map<String, dynamic>? response) {
    if (response == null) return null;
    final storyboards = response['storyboards'];
    if (storyboards is! Map) return null;

    const keys = [
      'playerStoryboardSpecRenderer',
      'playerLiveStoryboardSpecRenderer',
    ];
    for (final key in keys) {
      final renderer = storyboards[key];
      if (renderer is! Map) continue;
      final spec = renderer['spec'];
      if (spec is! String) continue;
      final parsed = parse(spec);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static StoryboardLevel? _parseLevel(String section, int index) {
    final fields = section.split('#');
    if (fields.length < _minLevelFields) return null;

    final width = int.tryParse(fields[0]);
    final height = int.tryParse(fields[1]);
    final frameCount = int.tryParse(fields[2]);
    final columns = int.tryParse(fields[3]);
    final rows = int.tryParse(fields[4]);
    final intervalMs = int.tryParse(fields[5]);
    if (width == null ||
        height == null ||
        frameCount == null ||
        columns == null ||
        rows == null ||
        intervalMs == null ||
        width <= 0 ||
        height <= 0 ||
        columns <= 0 ||
        rows <= 0) {
      return null;
    }

    final name = fields.length > 6 && fields[6].isNotEmpty
        ? fields[6]
        : r'M$M';
    final signature =
        fields.length > 7 && fields[7].isNotEmpty ? fields[7] : null;

    return StoryboardLevel(
      index: index,
      width: width,
      height: height,
      frameCount: frameCount,
      columns: columns,
      rows: rows,
      interval: Duration(milliseconds: intervalMs),
      name: name,
      signature: signature,
    );
  }

  /// The level a seek preview should use, or null when none of them can
  /// be addressed by time.
  StoryboardLevel? get previewLevel {
    final timed = levels.where((level) => level.isTimeIndexed).toList();
    if (timed.isEmpty) return null;

    var best = timed.first;
    for (final level in timed) {
      final bestGap = (best.width - _targetTileWidth).abs();
      final gap = (level.width - _targetTileWidth).abs();
      if (gap < bestGap || (gap == bestGap && level.width > best.width)) {
        best = level;
      }
    }
    return best;
  }

  /// Resolves the base URL for one sheet of [level].
  String sheetUrl(StoryboardLevel level, int sheetIndex) {
    var url = baseUrl
        .replaceAll(r'$L', '${level.index}')
        .replaceAll(r'$N', level.name)
        .replaceAll(r'$M', '$sheetIndex');

    final signature = level.signature;
    if (signature != null && signature.isNotEmpty) {
      url += '${url.contains('?') ? '&' : '?'}sigh=$signature';
    }
    return url;
  }

  /// The frame covering [position], or null when this spec cannot serve
  /// one. [level] defaults to [previewLevel].
  StoryboardTile? tileAt(Duration position, {StoryboardLevel? level}) {
    final chosen = level ?? previewLevel;
    if (chosen == null || !chosen.isTimeIndexed) return null;

    final elapsed = position.inMilliseconds < 0 ? 0 : position.inMilliseconds;
    var frame = elapsed ~/ chosen.interval.inMilliseconds;
    if (chosen.frameCount > 0 && frame > chosen.frameCount - 1) {
      frame = chosen.frameCount - 1;
    }

    final sheetIndex = frame ~/ chosen.framesPerSheet;
    final withinSheet = frame % chosen.framesPerSheet;

    return StoryboardTile(
      sheetUrl: sheetUrl(chosen, sheetIndex),
      sheetIndex: sheetIndex,
      column: withinSheet % chosen.columns,
      row: withinSheet ~/ chosen.columns,
      columns: chosen.columns,
      rows: chosen.rows,
      tileWidth: chosen.width,
      tileHeight: chosen.height,
      start: chosen.interval * frame,
    );
  }
}

/// Fetches and caches storyboard specs.
///
/// Never throws: a seek preview is an enhancement, and every failure
/// simply means no bubble.
class StoryboardService {
  StoryboardService(this._dio);

  final Dio _dio;

  static const _endpoint = 'https://www.youtube.com/youtubei/v1/player';

  /// Clients that still hand out `storyboards` without a PO token.
  /// ANDROID first — measured against the live endpoint, WEB answers
  /// UNPLAYABLE ("the page needs to be reloaded") for an unauthenticated
  /// caller with no visitor data, while ANDROID returns the full spec.
  /// WEB stays as a fallback in case that flips back.
  static const _clients = [
    _PlayerClient(
      name: 'ANDROID',
      version: '20.10.38',
      userAgent: 'com.google.android.youtube/20.10.38 '
          '(Linux; U; Android 14) gzip',
      extra: {
        'androidSdkVersion': 34,
        'osName': 'Android',
        'osVersion': '14',
      },
    ),
    _PlayerClient(
      name: 'WEB',
      version: '2.20250401.01.00',
      userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
          'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
    ),
  ];

  /// Answers already fetched this session, negatives included: most
  /// re-asks happen because the user reopened the same video.
  final _cache = <String, StoryboardSpec?>{};
  final _inFlight = <String, Future<StoryboardSpec?>>{};
  static const _maxCacheEntries = 40;

  /// The storyboard for [videoId], or null when YouTube serves none.
  Future<StoryboardSpec?> getStoryboard(String videoId) {
    if (videoId.isEmpty) return Future.value();
    if (_cache.containsKey(videoId)) return Future.value(_cache[videoId]);

    final pending = _inFlight[videoId];
    if (pending != null) return pending;

    final request = _fetch(videoId).then((spec) {
      _remember(videoId, spec);
      return spec;
    }).whenComplete(() => _inFlight.remove(videoId));

    _inFlight[videoId] = request;
    return request;
  }

  void _remember(String videoId, StoryboardSpec? spec) {
    _cache[videoId] = spec;
    while (_cache.length > _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  Future<StoryboardSpec?> _fetch(String videoId) async {
    for (final client in _clients) {
      try {
        final response = await _dio.post<Map<String, dynamic>>(
          _endpoint,
          data: {
            'context': {
              'client': {
                'clientName': client.name,
                'clientVersion': client.version,
                'hl': 'en',
                'gl': 'US',
                ...client.extra,
              },
            },
            'videoId': videoId,
            'contentCheckOk': true,
            'racyCheckOk': true,
          },
          options: Options(
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': client.userAgent,
            },
            receiveTimeout: const Duration(seconds: 10),
            validateStatus: (status) => status != null && status < 500,
          ),
        );
        if (response.statusCode != 200) continue;

        final spec = StoryboardSpec.fromPlayerResponse(response.data);
        if (spec != null) return spec;
      } catch (e) {
        debugPrint('Storyboard ${client.name} failed for $videoId: $e');
      }
    }
    return null;
  }
}

@immutable
class _PlayerClient {
  const _PlayerClient({
    required this.name,
    required this.version,
    required this.userAgent,
    this.extra = const {},
  });

  final String name;
  final String version;
  final String userAgent;
  final Map<String, dynamic> extra;
}
