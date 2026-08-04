// ============================================================
// Account - Freezed entity
// ============================================================

import 'package:freezed_annotation/freezed_annotation.dart';

part 'account.freezed.dart';

@freezed
class Account with _$Account {
  const factory Account({
    required String channelId,
    required String channelTitle,
    String? email,
    String? avatarUrl,
    String? accessToken,
    String? refreshToken,
    DateTime? tokenExpiresAt,
  }) = _Account;

  const Account._();

  bool get isSignedIn => channelId.isNotEmpty;
  bool get tokenValid =>
      accessToken != null &&
      tokenExpiresAt != null &&
      tokenExpiresAt!.isAfter(DateTime.now());
}
