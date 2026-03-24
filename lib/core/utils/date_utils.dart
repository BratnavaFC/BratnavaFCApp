/// Utilities for parsing API dates safely.
///
/// The backend stores dates as local Brazil wall-clock time but marks them
/// with 'Z'. Stripping the timezone marker and parsing as-is preserves the
/// intended time regardless of the device's local timezone.
class AppDateUtils {
  AppDateUtils._();

  static DateTime? parse(String? s) {
    if (s == null || s.isEmpty) return null;
    return _parseDate(s);
  }

  /// Returns a non-nullable DateTime, falling back to [DateTime.now()].
  static DateTime parseOrNow(String? s) => parse(s) ?? DateTime.now();
}

/// Strips timezone suffix, parses as wall-clock time, then subtracts 3 hours
/// to compensate for the backend always returning times 3 hours ahead (UTC vs UTC-3).
DateTime _parseDate(String? s) {
  if (s == null || s.isEmpty) return DateTime.now();
  final bare = s.replaceFirst(RegExp(r'Z$|[+-]\d{2}:\d{2}$'), '');
  final dt = DateTime.tryParse(bare) ?? DateTime.now();
  return dt.subtract(const Duration(hours: 3));
}
