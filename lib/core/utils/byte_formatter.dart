// ============================================================
// ByteFormatter — human sizes for downloads
// ============================================================
// Units are the same in every locale the app ships (Arabic uses the
// Latin abbreviations too), so this stays out of the .arb files. Only
// the digits are localized, by [NumberFormat] at the call site if the
// caller wants that — the values here are small and mostly one decimal.
// ============================================================

/// "1.4 GB", "812 MB", "64 KB", "0 B".
String formatBytes(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
  return '$bytes B';
}

/// Same as [formatBytes] but for a rate; the "/s" is added by the caller
/// through the `transferRate` string so the slash side stays correct in
/// a right-to-left layout.
String formatRate(double bytesPerSecond) =>
    formatBytes(bytesPerSecond.round());
