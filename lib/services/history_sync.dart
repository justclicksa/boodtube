// ============================================================
// HistorySync — watch history and resume positions, both ways
// ============================================================
// Locally the app already remembers where you stopped. That only helps
// on this device. YouTube keeps the same information per account, so:
//
//   pull  FEhistory carries a "watched %" per video -> local positions,
//         which is what lets a video started on a phone or on the web
//         resume here.
//   push  /api/stats/watchtime reports the position back, which is what
//         lets it resume *there*.
//
// A video is only pushed once playback has actually moved, and pulled
// positions never overwrite a newer local one — whichever side watched
// more recently wins.
// ============================================================

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/local/database/app_database.dart';
import '../data/youtube/authenticated_client.dart';
import '../domain/entities/media_item.dart';
import '../domain/repositories/local_library_repository.dart';

class HistorySync {
  HistorySync(this._remote, this._db, this._library);

  final AuthenticatedInnerTubeClient _remote;
  final AppDatabase _db;
  final LocalLibraryRepository _library;

  /// Positions below this are treated as "just started" and neither
  /// stored nor reported — YouTube does the same, so a mistap does not
  /// litter the history.
  static const _minimumPosition = Duration(seconds: 5);

  /// Within this much, two positions are the same moment; used so a
  /// pulled position does not fight a local one that is effectively
  /// identical.
  static const _tolerance = Duration(seconds: 15);

  /// Pulls the account's history into the local tables.
  ///
  /// Returns how many entries were applied, or null when signed out.
  Future<int?> pull() async {
    final entries = await _remote.getHistory();
    if (entries == null) return null;

    var applied = 0;
    for (final entry in entries) {
      final item = entry.item;
      final percent = entry.percentWatched;
      final remotePosition = _positionFrom(item, percent);
      await _library.addToHistory(item, position: remotePosition);
      if (remotePosition == null) continue;

      final local = await _db.getPlayPosition(item.videoId);
      final localPosition = local == null
          ? Duration.zero
          : Duration(milliseconds: local.positionMs);

      // Keep the further-along position: the account may know about a
      // session this device never saw, and vice versa.
      if (remotePosition > localPosition + _tolerance) {
        await _db.savePlayPosition(item.videoId, remotePosition);
        applied++;
      }
    }
    debugPrint('HistorySync: pulled ${entries.length} entries, '
        '$applied positions applied');
    return applied;
  }

  static Duration? _positionFrom(MediaItem item, int? percent) {
    if (percent == null || percent <= 0) return null;
    if (item.duration <= Duration.zero) return null;
    final ms = item.duration.inMilliseconds * (percent.clamp(0, 100) / 100);
    final position = Duration(milliseconds: ms.round());
    return position < _minimumPosition ? null : position;
  }

  /// Reports [position] for [videoId] so other devices resume there.
  Future<void> push({
    required String videoId,
    required Duration position,
    required Duration duration,
    required String cpn,
  }) async {
    if (position < _minimumPosition || duration <= Duration.zero) return;
    await _remote.reportPosition(
      videoId: videoId,
      position: position,
      duration: duration,
      cpn: cpn,
    );
  }

  /// A client playback nonce: YouTube expects one 16-character
  /// identifier per playback session, and ties the reported positions of
  /// that session together.
  static String newCpn() {
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
    final random = Random();
    return List.generate(
      16,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }
}
