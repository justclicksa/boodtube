import 'dart:convert';
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

  test('registerText serves a generated manifest as dash+xml', () async {
    final proxy = StreamProxy();
    addTearDown(proxy.dispose);
    await proxy.start();

    const manifest = '<MPD profiles="urn:mpeg:dash:profile:isoff-on-demand"/>';
    final url = proxy.registerText(manifest);
    expect(url, startsWith('http://127.0.0.1:'));

    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final response = await (await client.getUrl(Uri.parse(url))).close();

    expect(response.statusCode, HttpStatus.ok);
    expect(
      response.headers.contentType?.mimeType,
      'application/dash+xml',
    );
    expect(response.contentLength, utf8.encode(manifest).length);
    expect(await response.transform(utf8.decoder).join(), manifest);
  });

  test('retainOnly drops manifests that are no longer playing', () async {
    final proxy = StreamProxy();
    addTearDown(proxy.dispose);
    await proxy.start();

    final kept = proxy.registerText('<MPD kept="1"/>');
    final dropped = proxy.registerText('<MPD dropped="1"/>');
    proxy.retainOnly([kept]);

    final client = HttpClient();
    addTearDown(() => client.close(force: true));

    final keptResponse = await (await client.getUrl(Uri.parse(kept))).close();
    expect(keptResponse.statusCode, HttpStatus.ok);
    await keptResponse.drain<void>();

    final goneResponse =
        await (await client.getUrl(Uri.parse(dropped))).close();
    expect(goneResponse.statusCode, HttpStatus.notFound);
    await goneResponse.drain<void>();
  });
}
