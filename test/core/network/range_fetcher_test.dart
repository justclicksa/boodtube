// Exercises the range walking against a loopback server that behaves
// like googlevideo: query ranges only, a slice size it refuses above,
// and a per-URL byte cap it stops serving at.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smarttube_poc/core/network/range_fetcher.dart';

/// A stand-in for a googlevideo edge.
class _FakeCdn {
  _FakeCdn({
    required this.total,
    this.maxSliceBytes,
    this.servesUpTo,
    this.acceptHeaderRanges = false,
    this.acceptQueryRanges = true,
  });

  /// Size of the file it claims to have.
  final int total;

  /// Ranges wider than this are refused with 416, forcing the ladder
  /// down a rung.
  final int? maxSliceBytes;

  /// Byte offset past which every request is refused with 403 — the cap
  /// that used to strand downloads a few MiB in.
  final int? servesUpTo;

  final bool acceptHeaderRanges;
  final bool acceptQueryRanges;

  HttpServer? _server;
  int requests = 0;

  /// Requests that asked for a range starting at or beyond [servesUpTo].
  int refusals = 0;

  Uri get url => Uri.parse('http://127.0.0.1:${_server!.port}/video');

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handle);
  }

  Future<void> stop() async => _server?.close(force: true);

  /// Byte i of the file is `i % 251`, so a test can verify not just the
  /// length of what arrived but that the offsets line up.
  static int byteAt(int index) => index % 251;

  Future<void> _handle(HttpRequest request) async {
    requests++;
    final res = request.response;
    final queryRange = request.uri.queryParameters['range'];
    final headerRange = request.headers.value(HttpHeaders.rangeHeader);

    int? start;
    int? end;
    if (queryRange != null && acceptQueryRanges) {
      final parts = queryRange.split('-');
      start = int.tryParse(parts.first);
      end = int.tryParse(parts.last);
    } else if (headerRange != null && acceptHeaderRanges) {
      final parts = headerRange.replaceFirst('bytes=', '').split('-');
      start = int.tryParse(parts.first);
      end = int.tryParse(parts.last);
    }

    if (start == null || end == null) {
      res.statusCode = HttpStatus.forbidden;
      await res.close();
      return;
    }
    if (maxSliceBytes != null && end - start + 1 > maxSliceBytes!) {
      res.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      await res.close();
      return;
    }
    if (servesUpTo != null && start >= servesUpTo!) {
      refusals++;
      res.statusCode = HttpStatus.forbidden;
      await res.close();
      return;
    }

    var last = end > total - 1 ? total - 1 : end;
    if (servesUpTo != null && last >= servesUpTo!) last = servesUpTo! - 1;

    res
      ..statusCode = HttpStatus.partialContent
      ..headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$last/$total')
      ..headers.set(HttpHeaders.contentTypeHeader, 'video/mp4')
      ..add(
        Uint8List.fromList([
          for (var i = start; i <= last; i++) byteAt(i),
        ]),
      );
    await res.close();
  }
}

void main() {
  group('RangeFetcher', () {
    test('learns the total size from a two-byte probe', () async {
      final cdn = _FakeCdn(total: 4096);
      await cdn.start();
      final fetcher = RangeFetcher();
      addTearDown(() async {
        fetcher.close();
        await cdn.stop();
      });

      expect(await fetcher.probe(cdn.url), HttpStatus.partialContent);
      expect(await fetcher.contentLength(cdn.url), 4096);
      // Cached: asking again must not cost another round-trip.
      final before = cdn.requests;
      expect(await fetcher.contentLength(cdn.url), 4096);
      expect(cdn.requests, before);
    });

    test('walks a whole file in order when slices are accepted', () async {
      final cdn = _FakeCdn(total: 300 * 1024);
      await cdn.start();
      final fetcher = RangeFetcher();
      addTearDown(() async {
        fetcher.close();
        await cdn.stop();
      });

      final bytes = <int>[];
      await for (final chunk in fetcher.read(cdn.url)) {
        bytes.addAll(chunk);
      }

      expect(bytes.length, 300 * 1024);
      expect(bytes.first, _FakeCdn.byteAt(0));
      expect(bytes[1000], _FakeCdn.byteAt(1000));
      expect(bytes.last, _FakeCdn.byteAt(300 * 1024 - 1));
    });

    test('steps down the chunk ladder when a slice size is refused',
        () async {
      // 128 KiB is a rung on the ladder; 1 MiB and 512/256 KiB are not
      // accepted, so the walk has to find it.
      final cdn = _FakeCdn(total: 512 * 1024, maxSliceBytes: 128 * 1024);
      await cdn.start();
      final fetcher = RangeFetcher();
      addTearDown(() async {
        fetcher.close();
        await cdn.stop();
      });

      final bytes = <int>[];
      await for (final chunk in fetcher.read(cdn.url)) {
        bytes.addAll(chunk);
      }

      expect(bytes.length, 512 * 1024);
      expect(fetcher.chunkSize, 128 * 1024);
    });

    test('falls back to Range headers when query ranges are refused',
        () async {
      final cdn = _FakeCdn(
        total: 8192,
        acceptQueryRanges: false,
        acceptHeaderRanges: true,
      );
      await cdn.start();
      final fetcher = RangeFetcher();
      addTearDown(() async {
        fetcher.close();
        await cdn.stop();
      });

      final bytes = <int>[];
      await for (final chunk in fetcher.read(cdn.url)) {
        bytes.addAll(chunk);
      }
      expect(bytes.length, 8192);
    });

    test('reports the offset reached when the upstream caps the stream',
        () async {
      final cdn = _FakeCdn(total: 400 * 1024, servesUpTo: 192 * 1024);
      await cdn.start();
      final fetcher = RangeFetcher();
      addTearDown(() async {
        fetcher.close();
        await cdn.stop();
      });

      var refusedAt = -1;
      var refusedTotal = -1;
      final bytes = <int>[];
      await for (final chunk in fetcher.read(
        cdn.url,
        retries: 0,
        onRefused: (served, total) {
          refusedAt = served;
          refusedTotal = total;
        },
      )) {
        bytes.addAll(chunk);
      }

      // The stream ends quietly rather than throwing — the caller
      // decides whether a cap is fatal.
      expect(bytes.length, 192 * 1024);
      expect(refusedAt, 192 * 1024);
      expect(refusedTotal, 400 * 1024);
    });

    test('resumes from an offset, which is what makes a partial file '
        'recoverable', () async {
      final cdn = _FakeCdn(total: 200 * 1024);
      await cdn.start();
      final fetcher = RangeFetcher();
      addTearDown(() async {
        fetcher.close();
        await cdn.stop();
      });

      final bytes = <int>[];
      await for (final chunk in fetcher.read(cdn.url, from: 150 * 1024)) {
        bytes.addAll(chunk);
      }

      expect(bytes.length, 50 * 1024);
      expect(bytes.first, _FakeCdn.byteAt(150 * 1024));
      expect(bytes.last, _FakeCdn.byteAt(200 * 1024 - 1));
    });

    test('honours an explicit end, so the relay serves only the window '
        'that was asked for', () async {
      final cdn = _FakeCdn(total: 100 * 1024);
      await cdn.start();
      final fetcher = RangeFetcher();
      addTearDown(() async {
        fetcher.close();
        await cdn.stop();
      });

      final bytes = <int>[];
      await for (final chunk
          in fetcher.read(cdn.url, from: 1024, to: 2047)) {
        bytes.addAll(chunk);
      }
      expect(bytes.length, 1024);
      expect(bytes.first, _FakeCdn.byteAt(1024));
      expect(bytes.last, _FakeCdn.byteAt(2047));
    });

    test('parseRangeHeader reads what mpv sends', () {
      expect(RangeFetcher.parseRangeHeader('bytes=100-199', 1000), (100, 199));
      expect(RangeFetcher.parseRangeHeader('bytes=100-', 1000), (100, null));
      expect(RangeFetcher.parseRangeHeader(null, 1000), (0, null));
      // A start past the end is clamped rather than trusted.
      expect(RangeFetcher.parseRangeHeader('bytes=5000-', 1000), (999, null));
    });
  });
}
