// ============================================================
// DurationFormatter - Utility for formatting Duration
// ============================================================

class DurationFormatter {
  /// Format as HH:MM:SS or MM:SS
  static String format(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Format as "1h 23m" or "45m" or "30s"
  static String formatCompact(Duration d) {
    if (d.inHours > 0) {
      final minutes = d.inMinutes.remainder(60);
      return minutes == 0 ? '${d.inHours}h' : '${d.inHours}h ${minutes}m';
    }
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return '${d.inSeconds}s';
  }
}
