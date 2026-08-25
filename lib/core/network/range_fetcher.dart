// ============================================================
// RangeFetcher — byte-range walking for googlevideo
// ============================================================
// googlevideo refuses open-ended GETs and caps a single ranged request
// at a size that varies by network and client, so every consumer has to
// walk the file in bounded slices, remember which range dialect the host
// accepted, and step down a size ladder when a slice is refused.
//
// That logic used to live inside StreamProxy, where only playback could
// reach it — downloads re-implemented a naive fetch and stalled at the
// first refusal. It lives here now: the relay walks a window of a file
// for mpv, a download walks the whole file to disk, and both get the
// same negotiation, the same ladder, and the same per-host memory.
// ============================================================

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// One accepted range response.
class RangeSlice {
  const RangeSlice(this.bytes, this.end);

  final Uint8List bytes;

  /// Inclusive index of the last byte this slice carries.
  final int end;
}

/// What a HEAD-equivalent probe learned about a remote file. Constant for
/// the life of a signed URL, so it is worth caching.
class RemoteFileInfo {
  const RemoteFileInfo({required this.total, required this.contentType});

  final int total;
  final String contentType;
}

/// Which of the two range dialects googlevideo accepted for a host. The
/// `&range=a-b` query form works more often; the Range header is the
/// fallback. Once one is known to work, the other is not tried again.
enum RangeDialect { unknown, query, header }

/// Walks remote files by byte range, negotiating slice size and range
/// dialect per host.
///
/// Instances are stateful caches. Playback and downloads deliberately do
/// **not** share one: a download saturating the ladder down to 64 KiB
/// should not drag the player's slice size with it.
class RangeFetcher {
  RangeFetcher({HttpClient? client, this.maxConnectionsPerHost = 8})
      : _client = client ??
            // Keep Dart's default User-Agent: googlevideo accepts it
            // (verified), and mismatched custom UAs can trigger 403 on
            // stream URLs.
            (HttpClient()
              ..connectionTimeout = const Duration(seconds: 20)
              ..maxConnectionsPerHost = maxConnectionsPerHost
              ..idleTimeout = const Duration(seconds: 30));

  final HttpClient _client;
  final int maxConnectionsPerHost;

  /// Upstream fetch granularity. googlevideo caps a single request at a
  /// size that varies by network/client, so the walk starts optimistically
  /// and halves until the server accepts, remembering the size that worked.
  static const List<int> chunkLadder = [
    1024 * 1024,
    512 * 1024,
    256 * 1024,
    128 * 1024,
    64 * 1024,
  ];

  int _chunkSize = chunkLadder.first;

  /// The largest slice size the server has accepted so far.
  int get chunkSize => _chunkSize;

  final Map<String, RemoteFileInfo> _infoCache = {};
  final Map<String, RangeDialect> _dialect = {};

  int _transferWindowBytes = 0;
  DateTime _transferWindowStarted = DateTime.now();
  double _transferMbps = 0;

  /// Recent throughput in Mbit/s. Deliberately a short rolling window:
  /// diagnostics should describe the network now, not average the whole
  /// session including pauses and seeks.
  double get transferMbps => _transferMbps;

  /// Total size + content type, learned once from a 2-byte range request
  /// and cached — a seek or a resume must not pay to rediscover it.
  Future<RemoteFileInfo?> info(Uri url) async {
    final key = url.toString();
    final cached = _infoCache[key];
    if (cached != null) return cached;

    // Ask with whichever dialect this host is known to take, so a URL
    // that only answers query ranges is not written off here.
    for (final query in _dialectOrder(url.host)) {
      final learned = (await _probeVia(url, query: query))?.info;
      if (learned != null) {
        _dialect[url.host] = query ? RangeDialect.query : RangeDialect.header;
        _cacheInfo(key, learned);
        return learned;
      }
    }
    return null;
  }

  /// Total size of [url] in bytes, or 0 when the server won't say.
  Future<int> contentLength(Uri url) async => (await info(url))?.total ?? 0;

  /// Probes [url] with a tiny range request and returns the HTTP status.
  /// Used to skip stream URLs googlevideo refuses (403) before handing
  /// them to mpv, and to learn the file size for free while doing it.
  Future<int> probe(Uri url) async {
    // Match the walk: query ranges work on URLs that reject the Range
    // header. Testing only the header caused intermittent false 403s.
    var status = -1;
    for (final query in [true, false]) {
      final probed = await _probeVia(url, query: query);
      if (probed == null) continue;
      status = probed.status;
      if (status >= 200 && status < 300) {
        _dialect[url.host] = query ? RangeDialect.query : RangeDialect.header;
        if (probed.info != null) _cacheInfo(url.toString(), probed.info!);
        return status;
      }
    }
    return status;
  }

  /// Downloads one slice starting at [start], never past [hardEnd].
  /// Steps down the size ladder when the server refuses, remembering the
  /// size that worked for the rest of the session. Null means refused.
  Future<RangeSlice?> fetchSlice(Uri url, int start, int hardEnd) async {
    if (start > hardEnd) return null;
    for (final size in chunkLadder) {
      if (size > _chunkSize) continue;
      final end = (start + size - 1) > hardEnd ? hardEnd : start + size - 1;
      final bytes = await _readRange(url, start, end);
      if (bytes != null) {
        _chunkSize = size;
        return RangeSlice(bytes, start + bytes.length - 1);
      }
      debugPrint('RangeFetcher: slice size $size refused, stepping down');
    }
    return null;
  }

  /// Walks [url] from [from] to [to] (inclusive, defaults to the last
  /// byte), yielding slices in order.
  ///
  /// One slice of read-ahead is always in flight: the next request is
  /// issued before the current slice is handed over, so a consumer that
  /// takes time to write bytes out never leaves the socket idle for a
  /// full round-trip.
  ///
  /// When the server stops serving part-way through — the per-video byte
  /// cap googlevideo applies to some URLs — [onRefused] is called with
  /// the offset reached and the total, and the stream ends. It does not
  /// throw: the caller decides whether that is a failure (playback) or a
  /// reason to re-resolve the URL and resume (downloads).
  Stream<RangeSlice> walk(
    Uri url, {
    int from = 0,
    int? to,
    int retries = 1,
    Duration retryDelay = const Duration(milliseconds: 400),
    void Function(int servedBytes, int totalBytes)? onRefused,
  }) async* {
    final fileInfo = await info(url);
    if (fileInfo == null) {
      onRefused?.call(from, 0);
      return;
    }
    final last =
        to == null || to > fileInfo.total - 1 ? fileInfo.total - 1 : to;
    if (from > last) return;

    var offset = from;
    var inFlight = fetchSlice(url, offset, last);
    while (true) {
      var slice = await inFlight;
      // A refusal can be transient; a retry costs a round-trip and saves
      // the transfer when it is.
      for (var attempt = 0; slice == null && attempt < retries; attempt++) {
        await Future<void>.delayed(retryDelay);
        slice = await fetchSlice(url, offset, last);
      }
      if (slice == null) {
        debugPrint('RangeFetcher: upstream stopped at $offset '
            'of ${fileInfo.total}');
        onRefused?.call(offset, fileInfo.total);
        return;
      }
      offset = slice.end + 1;
      inFlight = offset <= last
          ? fetchSlice(url, offset, last)
          : Future<RangeSlice?>.value();
      yield slice;
      if (offset > last) return;
    }
  }

  /// Byte stream form of [walk], for consumers that only want the bytes.
  Stream<List<int>> read(
    Uri url, {
    int from = 0,
    int? to,
    int retries = 1,
    void Function(int servedBytes, int totalBytes)? onRefused,
  }) {
    return walk(url, from: from, to: to, retries: retries, onRefused: onRefused)
        .map((slice) => slice.bytes);
  }

  /// Fetches bytes [start]..[end] inclusive, or null when refused.
  ///
  /// googlevideo accepts the `&range=a-b` query form most reliably (the
  /// Range *header* is refused above a small size on some networks), so
  /// that is tried first and whichever form answers is remembered per host.
  Future<Uint8List?> _readRange(Uri url, int start, int end) async {
    final host = url.host;
    final known = _dialect[host] ?? RangeDialect.unknown;

    if (known != RangeDialect.header) {
      final bytes = await _readVia(url, start, end, query: true);
      if (bytes != null) {
        _dialect[host] = RangeDialect.query;
        return bytes;
      }
    }

    final bytes = await _readVia(url, start, end, query: false);
    if (bytes != null) {
      _dialect[host] = RangeDialect.header;
      return bytes;
    }

    // A dialect remembered for this CDN host is only a preference.
    // googlevideo can accept a different one for the next signed URL, so
    // try the alternative before declaring a live stream dead.
    if (known == RangeDialect.header) {
      final queryBytes = await _readVia(url, start, end, query: true);
      if (queryBytes != null) _dialect[host] = RangeDialect.query;
      return queryBytes;
    }
    return null;
  }

  Future<Uint8List?> _readVia(
    Uri url,
    int start,
    int end, {
    required bool query,
  }) async {
    try {
      final req = await _openRanged(url, start, end, query: query);
      final res = await req.close();
      if (res.statusCode != HttpStatus.ok &&
          res.statusCode != HttpStatus.partialContent) {
        await res.drain<void>();
        return null;
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in res) {
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      _recordTransfer(bytes.length);
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  Future<HttpClientRequest> _openRanged(
    Uri url,
    int start,
    int end, {
    required bool query,
  }) async {
    if (query) {
      final ranged = url.replace(
        queryParameters: {
          ...url.queryParameters,
          'range': '$start-$end',
        },
      );
      return _client.getUrl(ranged);
    }
    final req = await _client.getUrl(url);
    req.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-$end');
    return req;
  }

  /// Hosts whose dialect is already known are asked that way first.
  List<bool> _dialectOrder(String host) =>
      switch (_dialect[host] ?? RangeDialect.unknown) {
        RangeDialect.header => const [false, true],
        _ => const [true, false],
      };

  Future<({int status, RemoteFileInfo? info})?> _probeVia(
    Uri url, {
    required bool query,
  }) async {
    try {
      final req = await _openRanged(url, 0, 1, query: query);
      final res = await req.close().timeout(const Duration(seconds: 15));
      final contentRange = res.headers.value(HttpHeaders.contentRangeHeader);
      await res.drain<void>();
      RemoteFileInfo? parsed;
      if (res.statusCode == HttpStatus.partialContent && contentRange != null) {
        final total = int.tryParse(contentRange.split('/').last);
        if (total != null && total > 0) {
          parsed = RemoteFileInfo(
            total: total,
            contentType: res.headers.value(HttpHeaders.contentTypeHeader) ??
                'application/octet-stream',
          );
        }
      }
      return (status: res.statusCode, info: parsed);
    } catch (_) {
      return null;
    }
  }

  void _cacheInfo(String key, RemoteFileInfo value) {
    // Bound the cache: one entry per stream URL of the videos touched
    // this session is plenty.
    if (_infoCache.length > 32) _infoCache.clear();
    _infoCache[key] = value;
  }

  void _recordTransfer(int bytes) {
    if (bytes <= 0) return;
    _transferWindowBytes += bytes;
    final now = DateTime.now();
    final elapsed = now.difference(_transferWindowStarted);
    if (elapsed < const Duration(seconds: 1)) return;
    // bits / microseconds is already Mbit/s.
    _transferMbps = (_transferWindowBytes * 8) /
        elapsed.inMicroseconds.clamp(1, double.infinity);
    _transferWindowBytes = 0;
    _transferWindowStarted = now;
  }

  /// Parses an HTTP `Range: bytes=a-b` header against a known [total].
  static (int, int?) parseRangeHeader(String? header, int total) {
    if (header == null || !header.startsWith('bytes=')) return (0, null);
    final spec = header.substring(6).split('-');
    final start = int.tryParse(spec.first) ?? 0;
    final end = spec.length > 1 ? int.tryParse(spec[1]) : null;
    return (start.clamp(0, total - 1), end);
  }

  void clearCache() {
    _infoCache.clear();
  }

  void close() {
    _infoCache.clear();
    _client.close(force: true);
  }
}
