// ============================================================
// ChannelInfo - Freezed entity
// ============================================================

import 'package:freezed_annotation/freezed_annotation.dart';

part 'channel_info.freezed.dart';

@freezed
class ChannelInfo with _$ChannelInfo {
  const factory ChannelInfo({
    required String channelId,
    required String title,
    String? description,
    String? avatarUrl,
    String? bannerUrl,
    int? subscriberCount,
    int? videoCount,
    DateTime? joinedAt,
    @Default(false) bool isVerified,
  }) = _ChannelInfo;
}
