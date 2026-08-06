// ============================================================
// Connectivity awareness — offline banner + reconnect retry
// ============================================================
// The shared piece every screen can adopt: wrap a Scaffold body in
// [OfflineAwareBody] and it gains a persistent banner while the device
// has no network, plus a single [OfflineAwareBody.onReconnected] callback
// the moment connectivity comes back so the screen can refetch.
// ============================================================

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';

/// The platform connectivity plugin. Overridable in tests.
final connectivityProvider = Provider<Connectivity>((ref) => Connectivity());

/// `true` while the device reports at least one usable network.
///
/// Deliberately not auto-disposed: the answer is app-wide, and keeping one
/// subscription alive means a screen that mounts while offline sees the
/// current state immediately instead of a loading frame.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = ref.watch(connectivityProvider);
  try {
    yield _isOnline(await connectivity.checkConnectivity());
  } catch (_) {
    // Plugin unavailable (tests, unsupported platform) — assume online
    // rather than blocking the UI behind a banner that never clears.
    yield true;
    return;
  }
  yield* connectivity.onConnectivityChanged.map(_isOnline);
});

bool _isOnline(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);

/// Wraps a screen body with an offline banner and a reconnect hook.
class OfflineAwareBody extends ConsumerStatefulWidget {
  const OfflineAwareBody({
    required this.child,
    this.onReconnected,
    super.key,
  });

  /// The screen's normal body.
  final Widget child;

  /// Called once each time the device goes from offline to online.
  final VoidCallback? onReconnected;

  @override
  ConsumerState<OfflineAwareBody> createState() => _OfflineAwareBodyState();
}

class _OfflineAwareBodyState extends ConsumerState<OfflineAwareBody> {
  Timer? _backOnlineTimer;
  bool _showBackOnline = false;

  @override
  void dispose() {
    _backOnlineTimer?.cancel();
    super.dispose();
  }

  void _handleReconnect() {
    widget.onReconnected?.call();
    setState(() => _showBackOnline = true);
    _backOnlineTimer?.cancel();
    _backOnlineTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showBackOnline = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<bool>>(isOnlineProvider, (previous, next) {
      // `previous` has no value on the very first emission, so a screen
      // that opens while online never fires a spurious reconnect.
      if (previous?.valueOrNull == false && (next.valueOrNull ?? false)) {
        _handleReconnect();
      }
    });

    final online = ref.watch(isOnlineProvider).valueOrNull ?? true;

    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: !online
              ? const _ConnectivityBanner(online: false)
              : _showBackOnline
                  ? const _ConnectivityBanner(online: true)
                  : const SizedBox(width: double.infinity),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}

class _ConnectivityBanner extends StatelessWidget {
  const _ConnectivityBanner({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final background =
        online ? scheme.secondaryContainer : scheme.errorContainer;
    final foreground =
        online ? scheme.onSecondaryContainer : scheme.onErrorContainer;

    return Material(
      color: background,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                size: 20,
                color: foreground,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: online
                    ? Text(
                        l10n.backOnline,
                        style: TextStyle(
                          color: foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.offlineTitle,
                            style: TextStyle(
                              color: foreground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            l10n.offlineSubtitle,
                            style: TextStyle(
                              color: foreground,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
