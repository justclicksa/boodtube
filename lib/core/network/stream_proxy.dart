// ============================================================
// StreamProxy - local loopback HTTP relay for media streams
// ============================================================
// mpv's bundled TLS (mbedtls) fails on some environments (notably the
// Android x86_64 emulator), so instead of handing mpv an https URL we
// serve the stream from a 127.0.0.1 HTTP endpoint and fetch the real
// bytes with Dart's own HTTP stack (which works everywhere the app's
// API calls already work). Range requests are forwarded both ways so
// seeking keeps working.
//
// googlevideo refuses open-ended ranges, so the relay walks the file in
// bounded slices. A naive fetch→write→fetch loop leaves mpv starved for
// a full round-trip after every slice, which is audible as periodic
// stutter; the relay therefore starts downloading slice N+1 before it
// writes slice N, and remembers per-host what worked so no round-trip is
// spent rediscovering it.
// ============================================================

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

class _UpstreamInfo {
  const _UpstreamInfo({required this.total, required this.contentType});
  final int total;
  final String contentType;
}

class _Slice {
  const _Slice(this.bytes, this.end);
  final Uint8List bytes;

  /// Inclusive index of the last byte this slice carries.
  final int end;
}

/// Which of the two range dialects googlevideo accepted for a host. The
/// query form works more often; the header form is the fallback. Once one
/// is known to work, the other is not tried again.
enum _RangeForm { unknown, query, header }

class StreamProxy {
  /// Upstream fetch granularity. googlevideo caps a single request at a
  /// size that varies by network/client, so the relay starts optimistically
  /// and halves until the server accepts, remembering the size that worked.
  static const List<int> _chunkLadder = [
    1024 * 1024,
    512 * 1024,
    256 * 1024,
    128 * 1024,
    64 * 1024,
  ];
  int _chunkSize = _chunkLadder.first;

  HttpServer? _server;
  // Keep Dart's default User-Agent: googlevideo accepts it (verified), and
  // mismatched custom UAs can trigger 403 on stream URLs.
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 20)
    // Video, audio and their respective read-aheads are in flight at once.
    ..maxConnectionsPerHost = 8
    ..idleTimeout = const Duration(seconds: 30);

  final Map<String, Uri> _routes = {};

  /// Total size + content type per upstream URL. Constant for the life of
  /// a URL, so learning it once saves a round-trip on every seek.
  final Map<String, _UpstreamInfo> _infoCache = {};

  final Map<String, _RangeForm> _rangeForm = {};
  int _nextId = 0;

  /// Fired when googlevideo stops serving a stream part-way through.
  ///
  /// Some videos are capped: every client's URL is served for the first
  /// few MiB and then refused, whatever range dialect or slice size is
  /// used (measured with tool/client_probe.dart — the cap follows the
  /// video, not the client). Without this the player just freezes, so
  /// the controller turns it into a message.
  void Function(int servedBytes, int totalBytes)? onUpstreamRefused;

  bool get isRunning => _server != null;

  Future<void> start() async {
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handleRequest, onError: (Object _) {});
  }

  /// Register a remote URL and get a local http://127.0.0.1 URL for it.
  /// Must be called after [start].
  String register(Uri remote) {
    final server = _server;
    if (server == null) {
      throw StateError('StreamProxy.register called before start()');
    }
    final id = 's${_nextId++}';
    _routes[id] = remote;
    return 'http://127.0.0.1:${server.port}/$id';
  }

  /// Drops routes registered before [keep], so a quality switch does not
  /// leave the previous relay competing for bandwidth.
  void retainOnly(Iterable<String> keep) {
    final ids = keep
        .map((url) => Uri.tryParse(url)?.pathSegments.firstOrNull)
        .whereType<String>()
        .toSet();
    _routes.removeWhere((id, _) => !ids.contains(id));
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final id = request.uri.path.replaceFirst('/', '');
    final target = _routes[id];
    if (target == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    try {
      final info = await _upstreamInfo(target);
      if (info == null) {
        request.response.statusCode = HttpStatus.badGateway;
        await request.response.close();
        return;
      }
      final total = info.total;

      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
      final (start, requestedEnd) = _parseRange(rangeHeader, total);
      final end = (requestedEnd ?? total - 1).clamp(start, total - 1);

      final res = request.response;
      res.statusCode = rangeHeader == null
          ? HttpStatus.ok
          : HttpStatus.partialContent;
      res.headers
        ..set(HttpHeaders.acceptRangesHeader, 'bytes')
        ..set(HttpHeaders.contentTypeHeader, info.contentType);
      if (res.statusCode == HttpStatus.partialContent) {
        res.headers
            .set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$total');
      }
      res.contentLength = end - start + 1;
      // Send the header block before the first slice is fetched. Slices
      // are buffered whole (that is what makes read-ahead possible), so
      // without this mpv waits on a silent socket for as long as the
      // first slice takes and gives up with "Failed to open".
      await res.flush();

      // One slice of read-ahead: the next download is already running
      // while mpv drains the current one, so the relay never idles for a
      // full round-trip between slices.
      var offset = start;
      var inFlight = _fetchSlice(target, offset, end);
      while (true) {
        var slice = await inFlight;
        if (slice == null) {
          // A refusal can be transient; one retry costs a round-trip and
          // saves the playback when it is.
          await Future<void>.delayed(const Duration(milliseconds: 400));
          slice = await _fetchSlice(target, offset, end);
        }
        if (slice == null) {
          debugPrint('StreamProxy[$id]: upstream stopped at $offset '
              'of $total');
          onUpstreamRefused?.call(offset, total);
          break;
        }
        offset = slice.end + 1;
        inFlight = offset <= end
            ? _fetchSlice(target, offset, end)
            : Future<_Slice?>.value();
        res.add(slice.bytes);
        await res.flush();
        if (offset > end) break;
      }
      await res.close();
    } catch (e) {
      // Client hung up mid-stream (normal on seek) or upstream failed.
      debugPrint('StreamProxy[$id]: relay ended: $e');
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  /// Downloads one slice starting at [start], never past [hardEnd].
  /// Steps down the size ladder when the server refuses, remembering the
  /// size that worked for the rest of the session.
  Future<_Slice?> _fetchSlice(Uri target, int start, int hardEnd) async {
    for (final size in _chunkLadder) {
      if (size > _chunkSize) continue;
      final end = (start + size - 1) > hardEnd ? hardEnd : start + size - 1;
      final bytes = await _readRange(target, start, end);
      if (bytes != null) {
        _chunkSize = size;
        return _Slice(bytes, start + bytes.length - 1);
      }
      debugPrint('StreamProxy: slice size $size refused, stepping down');
    }
    return null;
  }

  /// Fetches bytes [start]..[end] inclusive, or null when refused.
  ///
  /// googlevideo accepts the `&range=a-b` query form most reliably (the
  /// Range *header* is refused above a small size on some networks), so
  /// that is tried first and whichever form answers is remembered per host.
  Future<Uint8List?> _readRange(Uri target, int start, int end) async {
    final host = target.host;
    final known = _rangeForm[host] ?? _RangeForm.unknown;

    if (known != _RangeForm.header) {
      final bytes = await _readVia(target, start, end, query: true);
      if (bytes != null) {
        _rangeForm[host] = _RangeForm.query;
        return bytes;
      }
      if (known == _RangeForm.query) return null;
    }

    final bytes = await _readVia(target, start, end, query: false);
    if (bytes != null) _rangeForm[host] = _RangeForm.header;
    return bytes;
  }

  Future<Uint8List?> _readVia(
    Uri target,
    int start,
    int end, {
    required bool query,
  }) async {
    try {
      final HttpClientRequest req;
      if (query) {
        req = await _client.getUrl(target.replace(queryParameters: {
          ...target.queryParameters,
          'range': '$start-$end',
        }));
      } else {
        req = await _client.getUrl(target);
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-$end');
      }
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
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  /// Total byte size + content type, learned once from a 2-byte Range
  /// request and cached — a seek must not pay for rediscovering it.
  Future<_UpstreamInfo?> _upstreamInfo(Uri target) async {
    final key = target.toString();
    final cached = _infoCache[key];
    if (cached != null) return cached;

    try {
      final req = await _client.getUrl(target);
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-1');
      final res = await req.close().timeout(const Duration(seconds: 15));
      final contentRange = res.headers.value(HttpHeaders.contentRangeHeader);
      await res.drain<void>();
      if (res.statusCode != HttpStatus.partialContent || contentRange == null) {
        return null;
      }
      final total = int.tryParse(contentRange.split('/').last);
      if (total == null) return null;
      final info = _UpstreamInfo(
        total: total,
        contentType: res.headers.value(HttpHeaders.contentTypeHeader) ??
            'application/octet-stream',
      );
      // Bound the cache: one entry per stream URL of the videos played
      // this session is plenty.
      if (_infoCache.length > 32) _infoCache.clear();
      _infoCache[key] = info;
      return info;
    } catch (_) {
      return null;
    }
  }

  static (int, int?) _parseRange(String? header, int total) {
    if (header == null || !header.startsWith('bytes=')) return (0, null);
    final spec = header.substring(6).split('-');
    final start = int.tryParse(spec.first) ?? 0;
    final end = spec.length > 1 ? int.tryParse(spec[1]) : null;
    return (start.clamp(0, total - 1), end);
  }

  /// Probe a remote URL with a tiny Range request and return the HTTP
  /// status. Used to skip stream URLs that googlevideo refuses (403)
  /// before handing them to mpv.
  Future<int> probe(Uri url) async {
    try {
      final req = await _client.getUrl(url);
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-1');
      final res = await req.close().timeout(const Duration(seconds: 10));
      final contentRange = res.headers.value(HttpHeaders.contentRangeHeader);
      await res.drain<void>();
      // The probe already carries everything _upstreamInfo would ask for,
      // so record it and save the relay a round-trip on first play.
      if (res.statusCode == HttpStatus.partialContent && contentRange != null) {
        final total = int.tryParse(contentRange.split('/').last);
        if (total != null && _infoCache.length <= 32) {
          _infoCache[url.toString()] = _UpstreamInfo(
            total: total,
            contentType: res.headers.value(HttpHeaders.contentTypeHeader) ??
                'application/octet-stream',
          );
        }
      }
      return res.statusCode;
    } catch (_) {
      return -1;
    }
  }

  /// Total size of [url] in bytes, or 0 when the server won't say.
  Future<int> contentLength(Uri url) async {
    final info = await _upstreamInfo(url);
    return info?.total ?? 0;
  }

  /// Reads the whole resource using the same negotiated slice sizes the
  /// relay uses. Lets downloads reuse the logic that makes googlevideo
  /// cooperate instead of re-implementing it.
  Stream<List<int>> readAll(Uri url) async* {
    final info = await _upstreamInfo(url);
    if (info == null) return;
    final last = info.total - 1;
    var offset = 0;
    Future<_Slice?> inFlight = _fetchSlice(url, offset, last);
    while (true) {
      final slice = await inFlight;
      if (slice == null) return;
      offset = slice.end + 1;
      inFlight = offset <= last
          ? _fetchSlice(url, offset, last)
          : Future<_Slice?>.value();
      yield slice.bytes;
      if (offset > last) return;
    }
  }

  Future<void> dispose() async {
    await _server?.close(force: true);
    _server = null;
    _routes.clear();
    _infoCache.clear();
    _client.close(force: true);
  }
}
