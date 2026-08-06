import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/entities.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/media_item.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/player_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../../theme/app_theme.dart';

Future<void> showCastDeviceSheet(
  BuildContext context,
  MediaItem? item,
) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (_) => _CastDeviceSheet(item: item),
  );
}

class _CastDeviceSheet extends ConsumerStatefulWidget {
  const _CastDeviceSheet({required this.item});

  final MediaItem? item;

  @override
  ConsumerState<_CastDeviceSheet> createState() => _CastDeviceSheetState();
}

class _CastDeviceSheetState extends ConsumerState<_CastDeviceSheet> {
  StreamSubscription<List<GoogleCastDevice>>? _subscription;
  List<GoogleCastDevice> _devices = const [];
  bool _scanning = true;
  String? _connectingId;

  @override
  void initState() {
    super.initState();
    final service = ref.read(castServiceProvider);
    _subscription = service.devices.listen((devices) {
      if (mounted) setState(() => _devices = devices);
    });
    unawaited(service.startDiscovery());
    Future<void>.delayed(const Duration(seconds: 8), () {
      if (mounted) setState(() => _scanning = false);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    unawaited(ref.read(castServiceProvider).stopDiscovery());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.cast),
            title: Text(l10n.castToTv),
            trailing: IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
          const Divider(),
          if (_devices.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                children: [
                  if (_scanning) const CircularProgressIndicator(),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    _scanning ? l10n.castScanning : l10n.castNoDevices,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            for (final device in _devices)
              ListTile(
                minTileHeight: AppSpacing.minTapTarget,
                leading: const Icon(Icons.tv),
                title: Text(device.friendlyName),
                subtitle: device.modelName?.isEmpty ?? true
                    ? null
                    : Text(device.modelName!),
                trailing: _connectingId == device.deviceID
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                enabled: _connectingId == null,
                onTap: () => _cast(device),
              ),
        ],
      ),
    );
  }

  Future<void> _cast(GoogleCastDevice device) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _connectingId = device.deviceID);
    try {
      final item = widget.item;
      if (item == null) {
        await ref.read(castServiceProvider).connect(device);
      } else {
        final player = ref.read(playerControllerProvider);
        await ref.read(castServiceProvider).cast(
              device,
              item,
              position: player.position,
            );
        await ref.read(playerControllerProvider.notifier).player.pause();
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _connectingId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.castFailed)),
      );
    }
  }
}
