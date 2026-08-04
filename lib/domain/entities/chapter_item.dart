// ============================================================
// ChapterItem - Freezed entity (FIXED: was inside media_subtitle.dart)
// ============================================================

import 'package:freezed_annotation/freezed_annotation.dart';

part 'chapter_item.freezed.dart';

@freezed
class ChapterItem with _$ChapterItem {
  const factory ChapterItem({
    required String title,
    required Duration start,
    String? thumbnailUrl,
  }) = _ChapterItem;
}
