// ============================================================
// DeArrowData - Freezed entity (FIXED: was inside media_subtitle.dart)
// ============================================================

import 'package:freezed_annotation/freezed_annotation.dart';

part 'dearrow_data.freezed.dart';

enum DeArrowLockReason {
  original, // original
  lock, // locked by uploader
  vote, // community voted to lock
}

@freezed
class DeArrowData with _$DeArrowData {
  const factory DeArrowData({
    String? title, // alt title
    String? thumbnailUrl, // alt thumbnail
    DeArrowLockReason? titleLockReason,
    DeArrowLockReason? thumbnailLockReason,
  }) = _DeArrowData;
}
