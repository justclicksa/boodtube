// ============================================================
// A ProviderContainer the real PlayerController can live in
// ============================================================
// PlayerController resolves its player, its library and its history
// sync in the constructor. Left alone in a test that means libmpv
// through dart:ffi and a sqlite file through path_provider, neither of
// which exists in `flutter test` — so every one of them is replaced
// here and the controller itself stays the real thing.
// ============================================================

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smarttube_poc/core/utils/result.dart';
import 'package:smarttube_poc/domain/entities/media_item.dart';
import 'package:smarttube_poc/domain/repositories/local_library_repository.dart';
import 'package:smarttube_poc/presentation/providers/player_providers.dart';
import 'package:smarttube_poc/presentation/providers/repository_providers.dart';
import 'package:smarttube_poc/presentation/providers/settings_providers.dart';
import 'package:smarttube_poc/services/audio_player_handler.dart';
import 'package:smarttube_poc/services/history_sync.dart';

import 'fake_player.dart';

class PlayerTestHarness {
  PlayerTestHarness._(this.container, this.audioHandler);

  final ProviderContainer container;

  /// A real handler over the fake player: what the notification would
  /// show is readable from `audioHandler.playbackState.value`.
  final SmartTubeAudioHandler audioHandler;

  PlayerStateData get playerState => container.read(playerControllerProvider);

  PlayerController get controller =>
      container.read(playerControllerProvider.notifier);
}

/// Builds the container and disposes it when the test ends.
///
/// [initialPreferences] seeds SharedPreferences, which is a process-wide
/// singleton under the test mock, so it is reset on every call.
Future<PlayerTestHarness> playerTestHarness({
  Map<String, Object> initialPreferences = const {},
  List<Override> overrides = const [],
}) async {
  // Feed and library providers build their own AppDatabase; nothing in
  // these tests queries it, and the warning buries the test output in
  // stack traces.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  SharedPreferences.setMockInitialValues(Map.of(initialPreferences));
  final preferences = await SharedPreferences.getInstance();
  await preferences.reload();

  final player = fakePlayer();
  final handler = SmartTubeAudioHandler(player);
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      mediaPlayerProvider.overrideWithValue(player),
      audioHandlerProvider.overrideWithValue(handler),
      localLibraryRepositoryProvider.overrideWithValue(_UnusedLibrary()),
      historySyncProvider.overrideWithValue(_UnusedHistorySync()),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  return PlayerTestHarness._(container, handler);
}

/// Resolved by the controller's constructor, and written to when the
/// controller is disposed — that is the only traffic these tests cause,
/// and none of them read it back.
class _UnusedLibrary implements LocalLibraryRepository {
  @override
  Future<Result<void>> savePlayPosition(String videoId, Duration position) =>
      Future.value(const Success(null));

  @override
  Future<Result<void>> addToHistory(MediaItem item, {Duration? position}) =>
      Future.value(const Success(null));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('no library in this test');
}

class _UnusedHistorySync implements HistorySync {
  @override
  Future<void> push({
    required String videoId,
    required Duration position,
    required Duration duration,
    required String cpn,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('no history sync in this test');
}
