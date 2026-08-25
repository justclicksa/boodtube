import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smarttube_poc/data/youtube/storyboard_service.dart';
import 'package:smarttube_poc/l10n/app_localizations.dart';
import 'package:smarttube_poc/presentation/screens/player/widgets/seek_preview.dart';

const _spec =
    r'https://i.ytimg.com/sb/dQw4w9WgXcQ/storyboard3_L$L/$N.jpg?sqp=abc'
    '|48#27#100#10#10#0#default#sig0'
    r'|80#45#90#10#10#2000#M$M#sig1'
    r'|160#90#90#5#5#2000#M$M#sig2';

/// 1×1 transparent PNG — enough for the image pipeline, no network.
final _pixel = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNkYAAA'
    'AAYAAjCB0C8AAAAASUVORK5CYII=',
  ),
);

ImageProvider _fakeImage(String url) => MemoryImage(_pixel);

/// The visible tile: the clip window, not the oversized sheet behind it.
final Finder _frame = find.descendant(
  of: find.byType(SeekPreviewBubble),
  matching: find.byType(OverflowBox),
);

Widget _host(Widget child, {TextDirection direction = TextDirection.ltr}) {
  return MaterialApp(
    locale: direction == TextDirection.rtl
        ? const Locale('ar')
        : const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: SizedBox(width: 400, child: child),
      ),
    ),
  );
}

void main() {
  final spec = StoryboardSpec.parse(_spec)!;

  group('SeekPreviewBubble', () {
    testWidgets('shows the frame and the time it belongs to', (tester) async {
      await tester.pumpWidget(
        _host(
          SeekPreviewBubble(
            spec: spec,
            position: const Duration(seconds: 52),
            fraction: 0.5,
            imageProviderFactory: _fakeImage,
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('0:52'), findsOneWidget);
    });

    testWidgets('draws nothing without a storyboard', (tester) async {
      await tester.pumpWidget(
        _host(
          const SeekPreviewBubble(
            spec: null,
            position: Duration(seconds: 52),
            fraction: 0.5,
            imageProviderFactory: _fakeImage,
          ),
        ),
      );

      expect(find.byType(Image), findsNothing);
      expect(find.text('0:52'), findsNothing);
    });

    testWidgets('draws nothing when no level is addressable by time',
        (tester) async {
      final coarse = StoryboardSpec.parse(
        r'https://host/L$L/$N.jpg|48#27#100#10#10#0#default#sig',
      )!;

      await tester.pumpWidget(
        _host(
          SeekPreviewBubble(
            spec: coarse,
            position: const Duration(seconds: 10),
            fraction: 0.5,
            imageProviderFactory: _fakeImage,
          ),
        ),
      );

      expect(find.byType(Image), findsNothing);
    });

    testWidgets('crops to the cell the position lands on', (tester) async {
      // 52s -> sheet 1, cell 1 of a 5x5 grid: column 1, row 0.
      await tester.pumpWidget(
        _host(
          SeekPreviewBubble(
            spec: spec,
            position: const Duration(seconds: 52),
            fraction: 0.5,
            imageProviderFactory: _fakeImage,
          ),
        ),
      );

      final box = tester.widget<OverflowBox>(_frame);
      // column 1 of 5 -> 2*1/4 - 1 = -0.5; row 0 -> -1.
      expect(box.alignment, const Alignment(-0.5, -1));

      // The whole sheet is laid out behind the clip: 5 tiles each way.
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, box.maxWidth);
      expect(image.height, box.maxHeight);
      expect(image.width! / image.height!, closeTo(160 / 90, 0.001));

      // Only one tile of it is visible.
      final visible = tester.getRect(_frame);
      expect(visible.width, closeTo(image.width! / 5, 0.001));
    });

    testWidgets('stays inside the bar at both ends of the track',
        (tester) async {
      for (final fraction in [0.0, 1.0]) {
        await tester.pumpWidget(
          _host(
            SeekPreviewBubble(
              spec: spec,
              position: const Duration(seconds: 10),
              fraction: fraction,
              imageProviderFactory: _fakeImage,
            ),
          ),
        );

        final frame = tester.getRect(_frame);
        final track = tester.getRect(find.byType(SeekPreviewBubble));

        expect(frame.left, greaterThanOrEqualTo(track.left - 0.01));
        expect(frame.right, lessThanOrEqualTo(track.right + 0.01));
      }
    });

    testWidgets('mirrors along the track in RTL, but not the clock',
        (tester) async {
      Future<Rect> frameRect(TextDirection direction) async {
        await tester.pumpWidget(
          _host(
            SeekPreviewBubble(
              spec: spec,
              position: const Duration(seconds: 10),
              fraction: 0.1,
              imageProviderFactory: _fakeImage,
            ),
            direction: direction,
          ),
        );
        return tester.getRect(_frame);
      }

      final ltr = await frameRect(TextDirection.ltr);
      final rtl = await frameRect(TextDirection.rtl);
      final track = tester.getRect(find.byType(SeekPreviewBubble));

      // A tenth along the track is near the left in LTR and near the
      // right in RTL — the same end the slider thumb is on.
      expect(ltr.center.dx, lessThan(track.center.dx));
      expect(rtl.center.dx, greaterThan(track.center.dx));

      // The timestamp reads left-to-right in either locale.
      final text = tester.widget<Directionality>(
        find
            .ancestor(
              of: find.text('0:10'),
              matching: find.byType(Directionality),
            )
            .first,
      );
      expect(text.textDirection, TextDirection.ltr);
    });
  });

  group('during a drag', () {
    testWidgets('the bubble follows the thumb and leaves on release',
        (tester) async {
      await tester.pumpWidget(_host(_DragHarness(spec: spec)));

      expect(find.byType(Image), findsNothing);

      final slider = tester.getCenter(find.byType(Slider));
      final gesture = await tester.startGesture(slider);
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
      final middle = tester.getRect(_frame);

      await gesture.moveBy(const Offset(120, 0));
      await tester.pump();

      expect(
        tester.getRect(_frame).center.dx,
        greaterThan(middle.center.dx),
      );

      await gesture.up();
      await tester.pump();

      expect(find.byType(Image), findsNothing);
    });
  });
}

/// Mirrors how the scrub bar drives the bubble: a slider whose local
/// drag value feeds the preview, cleared on release.
class _DragHarness extends StatefulWidget {
  const _DragHarness({required this.spec});

  final StoryboardSpec spec;

  @override
  State<_DragHarness> createState() => _DragHarnessState();
}

class _DragHarnessState extends State<_DragHarness> {
  static const _durationMs = 180000.0;

  double? _scrubMs;

  @override
  Widget build(BuildContext context) {
    final value = _scrubMs ?? 0;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Slider(
          value: value,
          max: _durationMs,
          onChanged: (next) => setState(() => _scrubMs = next),
          onChangeEnd: (_) => setState(() => _scrubMs = null),
        ),
        if (_scrubMs != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 30,
            child: IgnorePointer(
              child: SeekPreviewBubble(
                spec: widget.spec,
                position: Duration(milliseconds: value.toInt()),
                fraction: value / _durationMs,
                imageProviderFactory: _fakeImage,
              ),
            ),
          ),
      ],
    );
  }
}
