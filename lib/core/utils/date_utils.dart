/// Utilities for parsing API dates safely.
///
/// .NET returns UTC dates without the trailing 'Z', which causes Dart
/// to treat them as local time (incorrect). We append 'Z' when no
/// timezone info is present.
class AppDateUtils {
  AppDateUtils._();

  static DateTime? parse(String? s) {
    if (s == null || s.isEmpty) return null;
    final hasTimezone = s.contains('Z') ||
        s.contains('+') ||
        RegExp(r'-\d{2}:\d{2}$').hasMatch(s);
    final normalized = hasTimezone ? s : '${s}Z';
    return DateTime.tryParse(normalized)?.toLocal();
  }

  /// Returns a non-nullable DateTime, falling back to [DateTime.now()].
  static DateTime parseOrNow(String? s) => parse(s) ?? DateTime.now();
}
