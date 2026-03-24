import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/calendar_event.dart';

// ── Date helpers ──────────────────────────────────────────────────────────────

String toDateStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool isToday(DateTime d) => isSameDay(d, DateTime.now());

/// Gera as semanas do mês (seg→dom, incluindo dias fora do mês).
List<List<DateTime>> getMonthWeeks(int year, int month) {
  final first = DateTime(year, month, 1);
  final last  = DateTime(year, month + 1, 0);

  // Weekday: 1=Mon…7=Sun — alinha na segunda
  final offset = first.weekday - 1;
  final start  = first.subtract(Duration(days: offset));

  final weeks = <List<DateTime>>[];
  var cur = start;
  while (cur.isBefore(last) || cur.isAtSameMomentAs(last) || weeks.isEmpty) {
    final week = <DateTime>[];
    for (var i = 0; i < 7; i++) {
      week.add(cur);
      cur = cur.add(const Duration(days: 1));
    }
    weeks.add(week);
    if (cur.isAfter(last) && weeks.length >= 4) break;
  }
  return weeks;
}

/// Retorna os 7 dias da semana (seg→dom) em que `cursor` está.
List<DateTime> getWeekDays(DateTime cursor) {
  final offset = cursor.weekday - 1;
  final monday = cursor.subtract(Duration(days: offset));
  return List.generate(7, (i) => monday.add(Duration(days: i)));
}

// ── Event style ───────────────────────────────────────────────────────────────

({Color bg, Color fg, Color border}) eventColors(CalendarEvent ev) {
  switch (ev.type) {
    case 'birthday':
      return (bg: const Color(0xFFFCE7F3), fg: const Color(0xFF9D174D), border: const Color(0xFFF9A8D4));
    case 'match':
      return ev.isPast
          ? (bg: AppColors.slate100, fg: AppColors.slate500, border: AppColors.slate300)
          : (bg: const Color(0xFFDCFCE7), fg: const Color(0xFF166534), border: const Color(0xFF86EFAC));
    case 'holiday':
      return (bg: AppColors.amber50, fg: const Color(0xFF92400E), border: AppColors.amber200);
    case 'event':
      return (bg: AppColors.violet50, fg: AppColors.violet700, border: AppColors.violet200);
    case 'manual':
      if (ev.categoryColor != null) {
        final hex  = ev.categoryColor!.replaceAll('#', '');
        try {
          final base = Color(int.parse('0xFF$hex'));
          return (
            bg:     Color.fromARGB(30,  base.red, base.green, base.blue),
            fg:     base,
            border: Color.fromARGB(80,  base.red, base.green, base.blue),
          );
        } catch (_) {}
      }
      return (bg: AppColors.slate100, fg: AppColors.slate700, border: AppColors.slate200);
    default:
      return (bg: AppColors.slate100, fg: AppColors.slate700, border: AppColors.slate200);
  }
}

String eventIcon(CalendarEvent ev) {
  switch (ev.type) {
    case 'birthday': return '🎂';
    case 'match':    return ev.isPast ? '✅' : '⚽';
    case 'holiday':  return '🎉';
    case 'event':    return ev.icon ?? '🍖';
    default:         return ev.icon ?? ev.categoryIcon ?? '📅';
  }
}

Color? dotColor(CalendarEvent ev) {
  final c = eventColors(ev);
  return c.fg.withOpacity(.8);
}

// ── EventPill ─────────────────────────────────────────────────────────────────

class EventPill extends StatelessWidget {
  final CalendarEvent ev;
  final VoidCallback  onTap;
  final bool          compact;

  const EventPill({
    super.key,
    required this.ev,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final c    = eventColors(ev);
    final icon = eventIcon(ev);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color:        c.bg,
          borderRadius: BorderRadius.circular(4),
          border:       Border.all(color: c.border, width: .8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 9)),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                compact ? ev.title
                    : '${!ev.timeTBD && ev.time != null ? "${ev.time} " : ""}${ev.title}',
                style: TextStyle(
                  fontSize:   10,
                  fontWeight: FontWeight.w600,
                  color:      c.fg,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
