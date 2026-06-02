// Offset fixo de Brasília (UTC-3). Independe do fuso configurado no dispositivo,
// o que evita o problema de emuladores/dispositivos em UTC exibirem +3h.
const _kBrtOffset = Duration(hours: 3);

/// Converte string ISO-8601 UTC → horário de Brasília (UTC-3).
/// Retorna um DateTime "naive" (sem fuso) com os valores de hora/minuto já
/// corretos para o Brasil, funcionando independente do fuso do dispositivo.
DateTime _toBrt(DateTime utc) {
  final brt = utc.toUtc().subtract(_kBrtOffset);
  // DateTime sem flag isUtc → d.hour já devolve a hora brasileira em qualquer dispositivo
  return DateTime(brt.year, brt.month, brt.day, brt.hour, brt.minute, brt.second, brt.millisecond);
}

DateTime _utcParse(String? raw) {
  if (raw == null || raw.isEmpty) return DateTime.now();
  // Garante sufixo UTC para parsing correto
  final s = (raw.endsWith('Z') || raw.contains('+') ||
             RegExp(r'-\d{2}:\d{2}$').hasMatch(raw)) ? raw : '${raw}Z';
  final utc = DateTime.tryParse(s);
  return utc != null ? _toBrt(utc) : DateTime.now();
}

DateTime? _utcParseOrNull(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final s = (raw.endsWith('Z') || raw.contains('+') ||
             RegExp(r'-\d{2}:\d{2}$').hasMatch(raw)) ? raw : '${raw}Z';
  final utc = DateTime.tryParse(s);
  return utc != null ? _toBrt(utc) : null;
}

// ── Top-level helpers (usados nos modelos mais recentes) ──────────────────────

/// Parseia data da API garantindo interpretação UTC. Nunca retorna null.
DateTime parseApiDate(String? raw, {DateTime? fallback}) =>
    raw == null || raw.isEmpty
        ? (fallback ?? DateTime.now())
        : _utcParseOrNull(raw) ?? fallback ?? DateTime.now();

/// Parseia data da API. Retorna null se a string for inválida.
DateTime? parseApiDateOrNull(String? raw) => _utcParseOrNull(raw);

// ── AppDateUtils — classe compatível com código legado ────────────────────────

/// Classe utilitária de datas. Todos os métodos garantem parsing UTC correto,
/// substituindo o hack anterior de `subtract(3h)`.
class AppDateUtils {
  const AppDateUtils._();

  /// Parseia string ISO-8601. Nunca retorna null.
  static DateTime parseOrNow(String? raw) => _utcParse(raw);

  /// Parseia string ISO-8601. Retorna null se inválida.
  static DateTime? parse(String? raw) => _utcParseOrNull(raw);
}
