import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smarttube_poc/data/sponsorblock/sponsorblock_service.dart';
import 'package:smarttube_poc/domain/entities/sponsor_segment.dart';

/// Answers every request with [payload] and records what was asked for.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.payload);

  final List<dynamic> payload;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _RecordingAdapter adapter;
  late SponsorBlockService service;

  setUp(() {
    adapter = _RecordingAdapter([
      {
        'category': 'sponsor',
        'actionType': 'skip',
        'segment': [10.5, 30.0],
        'UUID': 'uuid-sponsor',
        'description': '',
      },
      {
        'category': 'poi_highlight',
        'actionType': 'poi',
        'segment': [42.0, 42.0],
        'UUID': 'uuid-highlight',
      },
      {
        'category': 'exclusive_access',
        'actionType': 'full',
        'segment': [0, 0],
        'UUID': 'uuid-exclusive',
      },
      {
        'category': 'chapter',
        'actionType': 'chapter',
        'segment': [60.0, 90.0],
        'UUID': 'uuid-chapter',
        'description': 'Intro talk',
      },
      {
        'category': 'sponsor',
        'actionType': 'skip',
        'segment': [100.0, 100.0],
        'UUID': 'uuid-empty',
      },
    ]);
    final dio = Dio()..httpClientAdapter = adapter;
    service = SponsorBlockService(dio);
  });

  test('asks for the categories and their matching action types', () async {
    await service.getSegments(
      'abc123',
      categories: {
        SponsorCategory.sponsor,
        SponsorCategory.highlight,
        SponsorCategory.exclusiveAccess,
      },
    );

    final query = adapter.lastRequest!.queryParameters;
    expect(adapter.lastRequest!.path, endsWith('/api/skipSegments'));
    expect(query['videoID'], 'abc123');
    expect(
      jsonDecode(query['categories'] as String),
      containsAll(<String>['sponsor', 'poi_highlight', 'exclusive_access']),
    );
    // Without these the API returns nothing for the last two.
    expect(
      jsonDecode(query['actionTypes'] as String),
      containsAll(<String>['skip', 'poi', 'full']),
    );
  });

  test('asks only for "skip" when only skippable categories are wanted',
      () async {
    await service.getSegments(
      'abc123',
      categories: {SponsorCategory.sponsor, SponsorCategory.intro},
    );

    expect(
      jsonDecode(adapter.lastRequest!.queryParameters['actionTypes'] as String),
      <String>['skip'],
    );
  });

  test('keeps zero-length highlight and exclusive-access segments', () async {
    final segments = await service.getSegments('abc123');

    final categories = segments.map((s) => s.category).toList();
    expect(categories, contains(SponsorCategory.highlight));
    expect(categories, contains(SponsorCategory.exclusiveAccess));
  });

  test('drops empty skippable segments and unknown categories', () async {
    final segments = await service.getSegments('abc123');

    expect(segments.map((s) => s.uuid), isNot(contains('uuid-empty')));
    // "chapter" is not a category this app can act on.
    expect(segments.map((s) => s.uuid), isNot(contains('uuid-chapter')));
  });

  test('parses the bounds into durations', () async {
    final segments = await service.getSegments('abc123');
    final sponsor = segments.firstWhere((s) => s.uuid == 'uuid-sponsor');

    expect(sponsor.start, const Duration(milliseconds: 10500));
    expect(sponsor.end, const Duration(seconds: 30));
    expect(sponsor.description, isNull);
  });

  test('an empty category set never reaches the network', () async {
    final segments = await service.getSegments('abc123', categories: {});

    expect(segments, isEmpty);
    expect(adapter.lastRequest, isNull);
  });
}
