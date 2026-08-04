// Which InnerTube client still hands out a playable manifest for a live
// broadcast?
//
//   dart run tool/live_player_probe.dart <liveVideoId>

import 'dart:convert';
import 'dart:io';

const _clients = <String, Map<String, dynamic>>{
  'IOS': {
    'clientName': 'IOS',
    'clientVersion': '20.10.4',
    'deviceMake': 'Apple',
    'deviceModel': 'iPhone16,2',
    'osName': 'iPhone',
    'osVersion': '18.3.2.22D82',
  },
  'ANDROID': {
    'clientName': 'ANDROID',
    'clientVersion': '20.10.38',
    'androidSdkVersion': 34,
    'osName': 'Android',
    'osVersion': '14',
  },
  'WEB': {
    'clientName': 'WEB',
    'clientVersion': '2.20250312.04.00',
  },
  'MWEB': {
    'clientName': 'MWEB',
    'clientVersion': '2.20250312.04.00',
  },
  'TVHTML5': {
    'clientName': 'TVHTML5',
    'clientVersion': '7.20250101.10.00',
  },
  'ANDROID_VR': {
    'clientName': 'ANDROID_VR',
    'clientVersion': '1.62.27',
    'deviceMake': 'Oculus',
    'deviceModel': 'Quest 3',
    'osName': 'Android',
    'osVersion': '12',
    'androidSdkVersion': 32,
  },
  'WEB_EMBEDDED_PLAYER': {
    'clientName': 'WEB_EMBEDDED_PLAYER',
    'clientVersion': '1.20250310.01.00',
  },
};

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stdout.writeln('usage: dart run tool/live_player_probe.dart <videoId>');
    return;
  }
  final videoId = args.first;
  final http = HttpClient();

  for (final entry in _clients.entries) {
    stdout.write('${entry.key.padRight(20)} ');
    try {
      final req = await http.postUrl(
        Uri.parse('https://www.youtube.com/youtubei/v1/player'),
      );
      req.headers.contentType = ContentType.json;
      req.headers.set('User-Agent', _userAgent(entry.key));
      req.write(jsonEncode({
        'context': {
          'client': {...entry.value, 'hl': 'en', 'gl': 'US'},
        },
        'videoId': videoId,
        'contentCheckOk': true,
        'racyCheckOk': true,
      }));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) {
        stdout.writeln('HTTP ${res.statusCode}');
        continue;
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      final status = json['playabilityStatus'];
      final streaming = json['streamingData'];
      if (streaming is! Map) {
        stdout.writeln('no streamingData '
            '(${status is Map ? status['status'] : '?'})');
        continue;
      }
      final hls = streaming['hlsManifestUrl'];
      final dash = streaming['dashManifestUrl'];
      stdout.writeln('hls=${hls != null} dash=${dash != null} '
          'keys=${streaming.keys.join(",")}');
    } catch (e) {
      stdout.writeln('failed: ${e.toString().split('\n').first}');
    }
  }

  http.close();
}

String _userAgent(String client) => switch (client) {
      'IOS' => 'com.google.ios.youtube/20.10.4 '
          '(iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X)',
      'ANDROID' => 'com.google.android.youtube/20.10.38 '
          '(Linux; U; Android 14) gzip',
      'ANDROID_VR' => 'com.google.android.apps.youtube.vr.oculus/1.62.27 '
          '(Linux; U; Android 12; Quest 3) gzip',
      'TVHTML5' => 'Mozilla/5.0 (ChromiumStylePlatform) Cobalt/Version',
      _ => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
          'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0 Safari/537.36',
    };
