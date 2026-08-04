// ============================================================
// Repository Providers (Riverpod)
// ============================================================
// كل الـ providers الأساسية (repositories + infrastructure).
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:media_kit/media_kit.dart';
import 'package:dio/dio.dart';

import 'package:smarttube_poc/core/network/stream_proxy.dart';
import 'package:smarttube_poc/data/dearrow/dearrow_service.dart';
import 'package:smarttube_poc/data/youtube/comments_service.dart';
import 'package:smarttube_poc/data/youtube/return_dislike_service.dart';
import 'package:smarttube_poc/data/youtube/innertube_client.dart';
import 'package:smarttube_poc/data/youtube/stream_resolver.dart';
import 'package:smarttube_poc/data/repositories/content_repository_impl.dart';
import 'package:smarttube_poc/data/repositories/media_item_repository_impl.dart';
import 'package:smarttube_poc/data/repositories/local_library_repository_impl.dart';
import 'package:smarttube_poc/data/sponsorblock/sponsorblock_service.dart';
import 'package:smarttube_poc/data/local/database/app_database.dart';
import 'package:smarttube_poc/domain/repositories/content_repository.dart';
import 'package:smarttube_poc/domain/repositories/media_item_repository.dart';
import 'package:smarttube_poc/domain/repositories/local_library_repository.dart';
import 'package:smarttube_poc/presentation/providers/auth_providers.dart';
import 'package:smarttube_poc/services/history_sync.dart';

// ============================================================
// Infrastructure providers
// ============================================================

/// YouTube API client
final youtubeExplodeProvider = Provider<YoutubeExplode>((ref) {
  final yt = YoutubeExplode();
  ref.onDispose(yt.close);
  return yt;
});

final innerTubeClientProvider = Provider<InnerTubeClient>((ref) {
  return InnerTubeClient(ref.watch(youtubeExplodeProvider));
});

final streamResolverProvider = Provider<StreamResolver>((ref) {
  return StreamResolver(ref.watch(youtubeExplodeProvider));
});

final commentsServiceProvider = Provider<CommentsService>((ref) {
  return CommentsService(ref.watch(youtubeExplodeProvider));
});

/// Public like/dislike counts (YouTube hides dislikes).
final returnDislikeServiceProvider = Provider<ReturnDislikeService>((ref) {
  return ReturnDislikeService(ref.watch(dioProvider));
});

/// Community-sourced alternative titles and thumbnails.
final deArrowServiceProvider = Provider<DeArrowService>((ref) {
  return DeArrowService(ref.watch(dioProvider));
});

/// The single Player instance shared by the UI and the background audio
/// handler. main() overrides this with the instance it handed to
/// audio_service, so notification controls and on-screen controls drive
/// the same playback.
final mediaPlayerProvider = Provider<Player>((ref) {
  final player = Player();
  ref.onDispose(player.dispose);
  return player;
});

/// Local loopback proxy that relays media streams to mpv over plain
/// http://127.0.0.1 — mpv's bundled TLS is unreliable (broken outright on
/// the Android x86_64 emulator), while Dart's HTTP stack works everywhere.
final streamProxyProvider = Provider<StreamProxy>((ref) {
  final proxy = StreamProxy();
  ref.onDispose(proxy.dispose);
  return proxy;
});

/// Dio HTTP client
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio();
  dio.options.connectTimeout = const Duration(seconds: 15);
  dio.options.receiveTimeout = const Duration(seconds: 15);
  return dio;
});

/// SponsorBlock service
final sponsorBlockServiceProvider = Provider<SponsorBlockService>((ref) {
  return SponsorBlockService(ref.watch(dioProvider));
});

/// Drift database (singleton)
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// ============================================================
// Repositories
// ============================================================

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  return ContentRepositoryImpl(
    ref.watch(innerTubeClientProvider),
    ref.watch(appDatabaseProvider),
  );
});

final mediaItemRepositoryProvider = Provider<MediaItemRepository>((ref) {
  return MediaItemRepositoryImpl(
    ref.watch(innerTubeClientProvider),
    ref.watch(streamResolverProvider),
  );
});

final localLibraryRepositoryProvider = Provider<LocalLibraryRepository>((ref) {
  return LocalLibraryRepositoryImpl(ref.watch(appDatabaseProvider));
});

/// Watch history and resume positions, synchronised with the account so
/// a video started elsewhere continues here and vice versa.
final historySyncProvider = Provider<HistorySync>((ref) {
  return HistorySync(
    ref.watch(authenticatedClientProvider),
    ref.watch(appDatabaseProvider),
    ref.watch(localLibraryRepositoryProvider),
  );
});
