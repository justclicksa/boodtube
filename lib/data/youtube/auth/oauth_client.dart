// ============================================================
// OAuth device flow — the "enter this code on youtube.com/tv" login
// ============================================================
// Same approach SmartTube uses: the app shows a short code, the user
// types it on another device, and we poll until Google hands over a
// token. No password ever touches this app.
//
// NOTE: the account is stored locally and only used to sign requests.
// Signing in with an unofficial client carries a real risk to the
// Google account — the UI states this before starting.
// ============================================================

import 'package:dio/dio.dart';

class DeviceCode {
  const DeviceCode({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUrl,
    required this.expiresIn,
    required this.interval,
  });

  final String deviceCode;
  final String userCode;
  final String verificationUrl;
  final Duration expiresIn;
  final Duration interval;
}

class OAuthTokens {
  const OAuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Raised while polling when the user has not finished yet.
class AuthorizationPending implements Exception {}

/// Raised when the user denied access or the code expired.
class AuthorizationFailed implements Exception {
  const AuthorizationFailed(this.reason);
  final String reason;
  @override
  String toString() => 'AuthorizationFailed: $reason';
}

class OAuthClient {
  OAuthClient(this._dio);

  final Dio _dio;

  // Public client identifiers used by YouTube's own TV application.
  // They are not secrets — they identify the *app kind*, and the device
  // flow requires the user to approve on google.com regardless.
  static const _clientId =
      '861556708454-d6dlm3lh05idd8npek18k6be8ba3oc68.apps.googleusercontent.com';
  static const _clientSecret = 'SboVhoG9s0rNafixCSGGKXAT';
  static const _scope = 'http://gdata.youtube.com https://www.googleapis.com/'
      'auth/youtube-paid-content';

  /// Step 1 — ask Google for a code the user can type elsewhere.
  Future<DeviceCode> requestDeviceCode() async {
    final response = await _dio.post<Map<String, dynamic>>(
      'https://oauth2.googleapis.com/device/code',
      data: {'client_id': _clientId, 'scope': _scope},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    final data = response.data!;
    return DeviceCode(
      deviceCode: data['device_code'] as String,
      userCode: data['user_code'] as String,
      verificationUrl:
          (data['verification_url'] ?? data['verification_uri']) as String,
      expiresIn: Duration(seconds: (data['expires_in'] as num).toInt()),
      interval: Duration(seconds: (data['interval'] as num?)?.toInt() ?? 5),
    );
  }

  /// Step 2 — poll until the user approves. Throws [AuthorizationPending]
  /// while waiting so the caller can keep polling on its own schedule.
  Future<OAuthTokens> pollForTokens(String deviceCode) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        'https://oauth2.googleapis.com/token',
        data: {
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'device_code': deviceCode,
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      return _tokensFrom(response.data!);
    } on DioException catch (e) {
      final error = e.response?.data is Map
          ? (e.response!.data as Map)['error'] as String?
          : null;
      switch (error) {
        case 'authorization_pending':
        case 'slow_down':
          throw AuthorizationPending();
        case 'access_denied':
          throw const AuthorizationFailed('You denied the request');
        case 'expired_token':
          throw const AuthorizationFailed('The code expired, try again');
        default:
          throw AuthorizationFailed(error ?? e.message ?? 'Unknown error');
      }
    }
  }

  /// Exchanges a refresh token for a fresh access token.
  Future<OAuthTokens> refresh(String refreshToken) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'https://oauth2.googleapis.com/token',
      data: {
        'client_id': _clientId,
        'client_secret': _clientSecret,
        'refresh_token': refreshToken,
        'grant_type': 'refresh_token',
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    return _tokensFrom(response.data!, fallbackRefresh: refreshToken);
  }

  OAuthTokens _tokensFrom(
    Map<String, dynamic> data, {
    String? fallbackRefresh,
  }) {
    return OAuthTokens(
      accessToken: data['access_token'] as String,
      refreshToken: (data['refresh_token'] as String?) ?? fallbackRefresh ?? '',
      expiresAt: DateTime.now().add(
        Duration(seconds: (data['expires_in'] as num?)?.toInt() ?? 3600),
      ),
    );
  }
}
