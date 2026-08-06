import 'dart:io';

import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../data/youtube/stream_resolver.dart';
import '../domain/entities/media_item.dart';

class CastService {
  CastService(this._streamResolver);

  final StreamResolver _streamResolver;

  static Future<void> initialize() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    const appId = GoogleCastDiscoveryCriteria.kDefaultApplicationId;
    final GoogleCastOptions options = Platform.isIOS
        ? IOSGoogleCastOptions(
            GoogleCastDiscoveryCriteriaInitialize.initWithApplicationID(appId),
          )
        : GoogleCastOptionsAndroid(appId: appId);
    await GoogleCastContext.instance.setSharedInstanceWithOptions(options);
  }

  Stream<List<GoogleCastDevice>> get devices =>
      GoogleCastDiscoveryManager.instance.devicesStream;

  Future<void> startDiscovery() =>
      GoogleCastDiscoveryManager.instance.startDiscovery();

  Future<void> stopDiscovery() =>
      GoogleCastDiscoveryManager.instance.stopDiscovery();

  Future<void> cast(
    GoogleCastDevice device,
    MediaItem item, {
    Duration position = Duration.zero,
  }) async {
    await connect(device);
    final stream = await _streamResolver.getCastStream(item.videoId);
    final thumbnail = item.thumbnailUrl;
    final media = GoogleCastMediaInformation(
      contentId: item.videoId,
      contentUrl: Uri.parse(stream.url),
      contentType: stream.contentType,
      streamType: CastMediaStreamType.buffered,
      duration: item.duration,
      metadata: GoogleCastMovieMediaMetadata(
        title: item.title,
        subtitle: item.author,
        images: thumbnail == null
            ? const []
            : [GoogleCastImage(url: Uri.parse(thumbnail))],
      ),
      customData: {'quality': stream.qualityLabel},
    );
    await GoogleCastRemoteMediaClient.instance.loadMedia(
      media,
      playPosition: position,
    );
  }

  Future<void> connect(GoogleCastDevice device) async {
    final connected =
        await GoogleCastSessionManager.instance.startSessionWithDevice(device);
    if (!connected) throw StateError('cast-connection-failed');
  }
}
