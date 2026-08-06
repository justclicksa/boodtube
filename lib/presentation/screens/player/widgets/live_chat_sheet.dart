import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../providers/content_providers.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/error_view.dart';

Future<void> showLiveChatSheet(BuildContext context, String videoId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.72,
    ),
    builder: (_) => _LiveChatSheet(videoId: videoId),
  );
}

class _LiveChatSheet extends ConsumerWidget {
  const _LiveChatSheet({required this.videoId});

  final String videoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final chat = ref.watch(liveChatProvider(videoId));
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.liveChat,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(l10n.liveChatReadOnly,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: chat.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(liveChatProvider(videoId)),
              ),
              data: (messages) => messages.isEmpty
                  ? Center(child: Text(l10n.liveChatWaiting))
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[messages.length - index - 1];
                        return ListTile(
                          minVerticalPadding: AppSpacing.sm,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundImage: message.authorAvatarUrl == null
                                ? null
                                : CachedNetworkImageProvider(
                                    message.authorAvatarUrl!,
                                  ),
                            child: message.authorAvatarUrl == null
                                ? Text(
                                    message.author.isEmpty
                                        ? '?'
                                        : message.author.characters.first,
                                  )
                                : null,
                          ),
                          title: Text(
                            message.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(message.message),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
