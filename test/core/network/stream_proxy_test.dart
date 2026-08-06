import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smarttube_poc/core/network/stream_proxy.dart';

void main() {
  test('probe accepts a URL that only supports query ranges', () async {
    final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = upstream.listen((request) async {
      if (request.uri.queryParameters['range'] == '0-1') {
        request.response
          ..statusCode = HttpStatus.partialContent
          ..headers.set(HttpHeaders.contentRangeHeader, 'bytes 0-1/4')
          ..headers.contentType = ContentType.binary
          ..add(const [0, 1]);
      } else {
        request.response.statusCode = HttpStatus.forbidden;
      }
      await request.response.close();
    });
    final proxy = StreamProxy();
    addTearDown(() async {
      await proxy.dispose();
      await subscription.cancel();
      await upstream.close(force: true);
    });

    final url = Uri.parse('http://127.0.0.1:${upstream.port}/video');

    expect(await proxy.probe(url), HttpStatus.partialContent);
    expect(await proxy.contentLength(url), 4);
  });
}
