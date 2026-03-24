import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/calendar_event.dart';
import 'calendar_utils.dart';

class MonthView extends StatelessWidget {
  final DateTime              cursor;
  final List<CalendarEvent>   events;
  final void Function(DateTime day, List<CalendarEvent> dayEvents) onDayTap;

  static const _headers = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

  const MonthView({
    super.key,
    required this.cursor,
    required this.events,
    required this.onDayTap,
  });

  List<CalendarEvent> _eventsForDay(DateTime day) {
    final ds = toDateStr(day);
    return events.where((e) => e.date == ds).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final weeks  = getMonthWeeks(cursor.year, cursor.month);

    return Column(
      children: [
        // ── Cabeçalho dias da semana ──────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppColors.slate700 : AppColors.slate200,
              ),
            ),
          ),
          child: Row(
            children: _headers.map((h) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  h,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize:   11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.slate400 : AppColors.slate600,
                  ),
                ),
              ),
            )).toList(),
          ),
        ),

        // ── Grid de semanas ───────────────────────────────────────────────
        Expanded(
          child: Column(
            children: weeks.map((week) => Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: week.map((day) {
                  final inMonth  = day.month == cursor.month;
                  final dayEvs   = _eventsForDay(day);
                  final today    = isToday(day);

                  return Expanded(
                    child: _DayCell(
                      day:      day,
                      inMonth:  inMonth,
                      today:    today,
                      dayEvs:   dayEvs,
                      isDark:   isDark,
                      onTap:    () => onDayTap(day, dayEvs),
                    ),
                  );
                }).toList(),
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }
}

// ── DayCell ───────────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  final DateTime            day;
  final bool                inMonth;
  final bool                today;
  final List<CalendarEvent> dayEvs;
  final bool                isDark;
  final VoidCallback        onTap;

  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.today,
    required this.dayEvs,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? AppColors.slate800 : AppColors.slate100;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: inMonth
              ? (isDark ? Colors.transparent : Colors.transparent)
              : (isDark ? AppColors.slate900.withOpacity(.4) : AppColors.slate50.withOpacity(.5)),
          border: Border(
            right:  BorderSide(color: borderColor),
            bottom: BorderSide(color: borderColor),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Número do dia
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: 22, height: 22,
                  decoration: today
                      ? BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? Colors.white : AppColors.slate900,
                        )
                      : null,
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize:   11,
                        fontWeight: FontWeight.w600,
                        color: today
                            ? (isDark ? AppColors.slate900 : Colors.white)
                            : inMonth
                                ? (isDark ? Colors.white : AppColors.slate800)
                                : (isDark ? AppColors.slate600 : AppColors.slate300),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 2),

              // Evento 1 (pill)
              if (dayEvs.isNotEmpty)
                EventPill(ev: dayEvs[0], onTap: onTap, compact: true),

              // Evento 2 (pill, se couber)
              if (dayEvs.length > 1) ...[
                const SizedBox(height: 1),
                EventPill(ev: dayEvs[1], onTap: onTap, compact: true),
              ],

              // "+N mais"
              if (dayEvs.length > 2)
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text(
                    '+${dayEvs.length - 2}',
                    style: TextStyle(
                      fontSize: 9,
                      color: isDark ? AppColors.slate500 : AppColors.slate400,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
