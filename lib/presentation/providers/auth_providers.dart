// ============================================================
// Sign-in state (OAuth device flow)
// ============================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/youtube/auth/oauth_client.dart';
import '../../data/youtube/authenticated_client.dart';
import 'repository_providers.dart';
import 'settings_providers.dart';

export '../../data/youtube/auth/oauth_client.dart' show DeviceCode;

final _secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
});

final oauthClientProvider = Provider<OAuthClient>((ref) {
  return OAuthClient(ref.watch(dioProvider));
});

/// Where the sign-in flow currently is.
sealed class AuthState {
  const AuthState();
}

class SignedOut extends AuthState {
  const SignedOut({this.error});
  final String? error;
}

class AwaitingCode extends AuthState {
  const AwaitingCode(this.code);
  final DeviceCode code;
}

class SignedIn extends AuthState {
  const SignedIn({required this.expiresAt});
  final DateTime expiresAt;
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._client, this._storage) : super(const SignedOut()) {
    unawaited(_restore());
  }

  final OAuthClient _client;
  final FlutterSecureStorage _storage;
  Timer? _pollTimer;

  static const _refreshKey = 'yt_refresh_token';

  /// Kept in memory only — it is short-lived and re-derivable from the
  /// refresh token, so it never touches disk.
  OAuthTokens? _tokens;

  /// A valid access token, refreshing first when the current one has
  /// expired. Null when signed out.
  Future<String?> accessToken() async {
    final current = _tokens;
    if (current != null && !current.isExpired) return current.accessToken;

    final refresh = current?.refreshToken ?? await _storage.read(key: _refreshKey);
    if (refresh == null || refresh.isEmpty) return null;
    try {
      final tokens = await _client.refresh(refresh);
      _tokens = tokens;
      state = SignedIn(expiresAt: tokens.expiresAt);
      return tokens.accessToken;
    } catch (_) {
      return null;
    }
  }

  Future<void> _restore() async {
    final refresh = await _storage.read(key: _refreshKey);
    if (refresh == null || refresh.isEmpty) return;
    try {
      final tokens = await _client.refresh(refresh);
      _tokens = tokens;
      state = SignedIn(expiresAt: tokens.expiresAt);
    } catch (_) {
      // Token revoked or offline — stay signed out, keep the token so a
      // later attempt can still succeed.
    }
  }

  /// Starts the flow: shows a code and polls until Google approves it.
  Future<void> startSignIn() async {
    _pollTimer?.cancel();
    try {
      final code = await _client.requestDeviceCode();
      state = AwaitingCode(code);

      final deadline = DateTime.now().add(code.expiresIn);
      _pollTimer = Timer.periodic(code.interval, (timer) async {
        if (DateTime.now().isAfter(deadline)) {
          timer.cancel();
          state = const SignedOut(error: 'The code expired, try again');
          return;
        }
        try {
          final tokens = await _client.pollForTokens(code.deviceCode);
          timer.cancel();
          _tokens = tokens;
          await _storage.write(
            key: _refreshKey,
            value: tokens.refreshToken,
          );
          state = SignedIn(expiresAt: tokens.expiresAt);
        } on AuthorizationPending {
          // keep waiting
        } on AuthorizationFailed catch (e) {
          timer.cancel();
          state = SignedOut(error: e.reason);
        }
      });
    } catch (e) {
      state = SignedOut(error: e.toString());
    }
  }

  Future<void> signOut() async {
    _pollTimer?.cancel();
    await _storage.delete(key: _refreshKey);
    state = const SignedOut();
  }

  void cancel() {
    _pollTimer?.cancel();
    state = const SignedOut();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    ref.watch(oauthClientProvider),
    ref.watch(_secureStorageProvider),
  );
});

/// Signed-in YouTube requests (real subscriptions, likes, subscribe).
///
/// Watches the language: YouTube personalises the home feed by locale,
/// so a client pinned to en/US returns a feed that looks nothing like
/// the official app does for an Arabic-speaking account.
final authenticatedClientProvider =
    Provider<AuthenticatedInnerTubeClient>((ref) {
  return AuthenticatedInnerTubeClient(
    ref.watch(dioProvider),
    () => ref.read(authControllerProvider.notifier).accessToken(),
    locale: ref.watch(settingsControllerProvider).language,
  );
});

/// True while a usable session exists.
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(authControllerProvider) is SignedIn;
});
