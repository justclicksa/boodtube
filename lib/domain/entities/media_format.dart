// ============================================================
// MediaFormat - Pure Dart Entity
// ============================================================
// تمثيل تنسيق فيديو واحد (جودة + معدل بت + نوع كوديك).
// ============================================================

import 'package:freezed_annotation/freezed_annotation.dart';

part 'media_format.freezed.dart';

/// Quality tier (للـ UI).
/// Display strings live in presentation/l10n/enum_labels.dart so they can
/// be translated; nothing here knows about the UI language.
enum MediaFormatQuality {
  lowest,
  low,
  medium,
  high,
  highest,
  best, // "best available"
}

@freezed
class MediaFormat with _$MediaFormat {
  const factory MediaFormat({
    required String formatId,
    required String url,

    // Quality
    String? qualityLabel, // e.g., "1080p", "720p60"
    int? width,
    int? height,
    double? fps,

    // Codec
    required String mimeType,
    required String codec,

    // Bitrate
    required int bitrate,

    // Audio
    @Default(false) bool isAudioOnly,
    String? audioCodec,
    int? audioBitrate,
  }) = _MediaFormat;

  const MediaFormat._();

  /// Parse height from qualityLabel (e.g., "1080p60" -> 1080)
  int? get parsedHeight {
    if (qualityLabel == null) return height;
    final match = RegExp(r'(\d+)p').firstMatch(qualityLabel!);
    return match?.group(1) != null ? int.parse(match!.group(1)!) : height;
  }

  /// Is this progressive (audio + video in one)?
  bool get isProgressive => !isAudioOnly && audioCodec != null;

  /// Human readable quality (e.g., "1080p60 • VP9")
  String get displayLabel {
    final parts = <String>[];
    if (qualityLabel != null) parts.add(qualityLabel!);
    if (codec.isNotEmpty) parts.add(codec.toUpperCase());
    return parts.join(' • ');
  }
}
