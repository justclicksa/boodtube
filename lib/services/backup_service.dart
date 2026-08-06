import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local/database/app_database.dart';

class BackupSummary {
  const BackupSummary({
    required this.history,
    required this.subscriptions,
    required this.favorites,
    required this.watchLater,
  });

  final int history;
  final int subscriptions;
  final int favorites;
  final int watchLater;
}

class BackupService {
  const BackupService(this._database, this._preferences);

  final AppDatabase _database;
  final SharedPreferences _preferences;

  Future<void> shareBackup() async {
    final database = await _database.exportPortableData();
    final settings = <String, Object?>{};
    for (final key in _preferences.getKeys()) {
      if (!key.startsWith('settings.')) continue;
      settings[key] = _preferences.get(key);
    }
    final payload = <String, Object?>{
      'format': 'boodtube-backup',
      'version': 1,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'settings': settings,
      'database': database,
    };
    final directory = await getTemporaryDirectory();
    final stamp = DateTime.now().toUtc().toIso8601String().split('T').first;
    final file = File('${directory.path}/boodtube-backup-$stamp.json');
    await file
        .writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'BoodTube backup',
    );
  }

  Future<BackupSummary?> pickAndRestore() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null) return null;
    final picked = result.files.single;
    final bytes = picked.bytes ??
        (picked.path == null ? null : await File(picked.path!).readAsBytes());
    if (bytes == null) throw const FormatException('Backup file is empty');
    final payload = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (payload['format'] != 'boodtube-backup' || payload['version'] != 1) {
      throw const FormatException('Unsupported BoodTube backup');
    }

    final database = Map<String, Object?>.from(payload['database'] as Map);
    final settings = Map<String, dynamic>.from(payload['settings'] as Map);
    await _database.restorePortableData(database);
    for (final entry in settings.entries) {
      await _restorePreference(entry.key, entry.value);
    }
    return BackupSummary(
      history: (database['history'] as List?)?.length ?? 0,
      subscriptions: (database['subscriptions'] as List?)?.length ?? 0,
      favorites: (database['favorites'] as List?)?.length ?? 0,
      watchLater: (database['watchLater'] as List?)?.length ?? 0,
    );
  }

  Future<void> _restorePreference(String key, Object? value) async {
    switch (value) {
      case bool value:
        await _preferences.setBool(key, value);
      case int value:
        await _preferences.setInt(key, value);
      case double value:
        await _preferences.setDouble(key, value);
      case String value:
        await _preferences.setString(key, value);
      case List<dynamic> value:
        await _preferences.setStringList(key, value.cast<String>());
    }
  }
}
