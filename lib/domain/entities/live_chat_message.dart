class LiveChatMessage {
  const LiveChatMessage({
    required this.id,
    required this.author,
    required this.message,
    this.authorAvatarUrl,
  });

  final String id;
  final String author;
  final String message;
  final String? authorAvatarUrl;
}
