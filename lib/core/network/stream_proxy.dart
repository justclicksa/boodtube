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
// googlevideo refuses open-ended ranges, so the bytes come from
// RangeFetcher, which walks the file in negotiated slices and keeps one
// slice of read-ahead in flight — a naive fetch→write→fetch loop leaves
// mpv starved for a full round-trip after every slice, which is audible
// as periodic stutter. That walking logic lives in core/network/
// range_fetcher.dart so downloads use exactly the same negotiation.
// ============================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'range_fetcher.dart';

class StreamProxy {
  StreamProxy({RangeFetcher? fetcher}) : _fetcher = fetcher ?? RangeFetcher();

  /// The relay keeps its own fetcher: a download stepping the slice
  /// ladder down should not drag playback's slice size with it.
  final RangeFetcher _fetcher;

  HttpServer? _server;

  final Map<String, Uri> _routes = {};

  int _nextId = 0;

  /// Recent relay throughput. It is deliberately a short rolling window:
  /// diagnostics should describe the network now, not average the whole
  /// video including pauses and seeks.
  double get transferMbps => _fetcher.transferMbps;

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
      final info = await _fetcher.info(target);
      if (info == null) {
        request.response.statusCode = HttpStatus.badGateway;
        await request.response.close();
        return;
      }
      final total = info.total;

      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
      final (start, requestedEnd) =
          RangeFetcher.parseRangeHeader(rangeHeader, total);
      final end = (requestedEnd ?? total - 1).clamp(start, total - 1);

      final res = request.response
        ..statusCode =
            rangeHeader == null ? HttpStatus.ok : HttpStatus.partialContent;
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

      await for (final slice in _fetcher.walk(
        target,
        from: start,
        to: end,
        onRefused: (served, totalBytes) {
          if (served > end) return;
          debugPrint('StreamProxy[$id]: upstream stopped at $served '
              'of $totalBytes');
          onUpstreamRefused?.call(served, totalBytes);
        },
      )) {
        res.add(slice.bytes);
        await res.flush();
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

  /// Probe a remote URL with a tiny Range request and return the HTTP
  /// status. Used to skip stream URLs that googlevideo refuses (403)
  /// before handing them to mpv.
  Future<int> probe(Uri url) => _fetcher.probe(url);

  /// Total size of [url] in bytes, or 0 when the server won't say.
  Future<int> contentLength(Uri url) => _fetcher.contentLength(url);

  /// Reads the whole resource using the same negotiated slice sizes the
  /// relay uses.
  ///
  /// Downloads use [RangeFetcher] directly (they need to resume from an
  /// offset and to hear about a refusal); this stays for callers that
  /// only want the bytes of a URL the relay already knows.
  Stream<List<int>> readAll(Uri url) => _fetcher.read(url);

  Future<void> dispose() async {
    await _server?.close(force: true);
    _server = null;
    _routes.clear();
    _fetcher.close();
  }
}
