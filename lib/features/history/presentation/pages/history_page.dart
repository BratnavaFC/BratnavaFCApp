import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../domain/entities/history_match.dart';
import '../providers/history_provider.dart';

// ── Page ──────────────────────────────────────────────────────────────────────

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  static const _pageSize = 20;
  int _page = 1;
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _changePage(int p) {
    setState(() => _page = p);
    // Scroll to top
    _scrollCtrl.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final account     = ref.watch(accountStoreProvider).activeAccount;
    final activePlayer = ref.watch(activePlayerProvider);
    final groupId    = account?.activeGroupId ?? activePlayer?.groupId;
    final isDark     = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () async {
        if (groupId != null) {
          ref.invalidate(historyProvider(groupId));
          setState(() => _page = 1);
        }
      },
      child: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          // ── Header ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _Header(
              groupId: groupId,
              isDark:  isDark,
              onRefresh: groupId == null
                  ? null
                  : () => ref.invalidate(historyProvider(groupId)),
            ),
          ),

          if (groupId == null) ...[
            SliverFillRemaining(
              child: _NoGroup(isDark: isDark),
            ),
          ] else ...[
            SliverToBoxAdapter(
              child: _HistoryList(
                groupId:  groupId,
                page:     _page,
                pageSize: _pageSize,
                isDark:   isDark,
                onPageChanged: _changePage,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ],
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  final String?      groupId;
  final bool         isDark;
  final VoidCallback? onRefresh;

  const _Header({required this.groupId, required this.isDark, this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final histAsync = groupId != null
        ? ref.watch(historyProvider(groupId!))
        : const AsyncValue<List<HistoryMatch>>.data([]);

    final isLoading = histAsync.isLoading;
    final total     = histAsync.valueOrNull?.length ?? 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: [
            Color(0xFF0f172a),
            Color(0xFF1e293b),
            Color(0xFF0f172a),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon box
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color:        Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withAlpha(50)),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: Colors.white,
              size:  26,
            ),
          ),
          const SizedBox(width: 16),
          // Title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Histórico',
                  style: TextStyle(
                    fontSize:   22,
                    fontWeight: FontWeight.w900,
                    color:      Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                if (isLoading)
                  Row(
                    children: [
                      SizedBox(
                        width: 10, height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.white.withAlpha(128),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Carregando...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withAlpha(128),
                        ),
                      ),
                    ],
                  )
                else if (groupId == null)
                  Text(
                    'Selecione um grupo',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withAlpha(128),
                    ),
                  )
                else
                  Text(
                    '$total partida${total != 1 ? 's' : ''} '
                    'registrada${total != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withAlpha(128),
                    ),
                  ),
              ],
            ),
          ),
          // Refresh button
          if (onRefresh != null)
            GestureDetector(
              onTap: isLoading ? null : onRefresh,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color:        Colors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withAlpha(50)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      size:  14,
                      color: Colors.white.withAlpha(204),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Atualizar',
                      style: TextStyle(
                        fontSize:   12,
                        fontWeight: FontWeight.w500,
                        color:      Colors.white.withAlpha(204),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── No group ──────────────────────────────────────────────────────────────────

class _NoGroup extends StatelessWidget {
  final bool isDark;
  const _NoGroup({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.group_outlined,
            size:  40,
            color: isDark ? AppColors.slate600 : AppColors.slate300,
          ),
          const SizedBox(height: 12),
          Text(
            'Selecione um grupo no Dashboard.',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.slate500 : AppColors.slate400,
            ),
          ),
        ],
      ),
    );
  }
}

// ── List ──────────────────────────────────────────────────────────────────────

class _HistoryList extends ConsumerWidget {
  final String groupId;
  final int    page;
  final int    pageSize;
  final bool   isDark;
  final void   Function(int) onPageChanged;

  const _HistoryList({
    required this.groupId,
    required this.page,
    required this.pageSize,
    required this.isDark,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(historyProvider(groupId));

    return async.when(
      loading: () => _Skeletons(isDark: isDark),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            'Erro: $e',
            style: TextStyle(
              color: isDark ? AppColors.slate400 : AppColors.slate500,
            ),
          ),
        ),
      ),
      data: (all) {
        // Sort newest first
        final sorted = [...all]..sort((a, b) {
            final da = a.playedAt?.millisecondsSinceEpoch ?? 0;
            final db = b.playedAt?.millisecondsSinceEpoch ?? 0;
            return db.compareTo(da);
          });

        if (sorted.isEmpty) return _EmptyState(isDark: isDark);

        final totalPages = (sorted.length / pageSize).ceil().clamp(1, 9999);
        final safeP      = page.clamp(1, totalPages);
        final start      = (safeP - 1) * pageSize;
        final paged      = sorted.skip(start).take(pageSize).toList();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              ...paged.map((m) => _MatchCard(
                match:  m,
                isDark: isDark,
                onTap:  () => context.go('/app/history/${m.groupId}/${m.id}'),
              )),
              const SizedBox(height: 12),
              if (sorted.length > pageSize)
                _Pagination(
                  page:       safeP,
                  totalPages: totalPages,
                  total:      sorted.length,
                  isDark:     isDark,
                  onPage:     onPageChanged,
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Match card ────────────────────────────────────────────────────────────────

class _MatchCard extends StatelessWidget {
  final HistoryMatch match;
  final bool         isDark;
  final VoidCallback onTap;

  const _MatchCard({
    required this.match,
    required this.isDark,
    required this.onTap,
  });

  Color? _parseHex(String? hex) {
    if (hex == null) return null;
    try {
      final h = hex.replaceAll('#', '');
      if (h.length == 3) {
        final r = h[0] + h[0];
        final g = h[1] + h[1];
        final b = h[2] + h[2];
        return Color(int.parse('FF$r$g$b', radix: 16));
      }
      if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final aColor  = _parseHex(match.teamAColorHex);
    final bColor  = _parseHex(match.teamBColorHex);
    final hasScore = match.hasScore;
    final dates   = _formatDate(match.playedAt);

    // Accent strip color
    Color? accentA, accentB;
    if (hasScore) {
      final a = match.teamAGoals!;
      final b = match.teamBGoals!;
      if (a > b) {
        accentA = aColor;
        accentB = aColor;
      } else if (b > a) {
        accentA = bColor;
        accentB = bColor;
      } else {
        accentA = aColor;
        accentB = bColor;
      }
    } else {
      accentA = aColor ?? AppColors.slate400;
      accentB = aColor ?? AppColors.slate400;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color:        isDark ? AppColors.slate900 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.slate700 : AppColors.slate200,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left accent strip
                _AccentStrip(colorA: accentA, colorB: accentB),

                // Date box
                if (dates != null)
                  _DateBox(dates: dates, isDark: isDark),

                // Body
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Full date
                        Text(
                          dates?.full ?? match.id,
                          style: TextStyle(
                            fontSize:   13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppColors.slate900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        // Meta row
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            // Team dots
                            if (aColor != null || bColor != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _TeamDot(color: aColor),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 3),
                                    child: Text(
                                      'vs',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.slate400,
                                      ),
                                    ),
                                  ),
                                  _TeamDot(color: bColor),
                                ],
                              ),
                            // Status badge
                            if (match.statusName != null &&
                                match.statusName!.isNotEmpty)
                              _StatusBadge(
                                status: match.statusName!,
                                isDark: isDark,
                              ),
                            // Place
                            if (match.placeName != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size:  10,
                                    color: isDark
                                        ? AppColors.slate500
                                        : AppColors.slate400,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    match.placeName!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppColors.slate500
                                          : AppColors.slate400,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Score pill or chevron
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 10),
                  child: Center(
                    child: hasScore
                        ? _ScorePill(
                            a: match.teamAGoals!,
                            b: match.teamBGoals!,
                          )
                        : Icon(
                            Icons.chevron_right_rounded,
                            size:  18,
                            color: isDark
                                ? AppColors.slate600
                                : AppColors.slate300,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Accent strip ──────────────────────────────────────────────────────────────

class _AccentStrip extends StatelessWidget {
  final Color? colorA;
  final Color? colorB;

  const _AccentStrip({this.colorA, this.colorB});

  @override
  Widget build(BuildContext context) {
    if (colorA == colorB || colorB == null) {
      return Container(
        width: 4,
        color: colorA ?? AppColors.slate400,
      );
    }
    return Container(
      width: 4,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
          stops: const [0.5, 0.5],
          colors: [colorA ?? AppColors.slate400, colorB!],
        ),
      ),
    );
  }
}

// ── Date box ──────────────────────────────────────────────────────────────────

class _DateBox extends StatelessWidget {
  final _DateParts dates;
  final bool isDark;

  const _DateBox({required this.dates, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   58,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800.withAlpha(120) : AppColors.slate50,
        border: Border(
          right: BorderSide(
            color: isDark ? AppColors.slate800 : AppColors.slate100,
          ),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            dates.month.toUpperCase(),
            style: TextStyle(
              fontSize:      9,
              fontWeight:    FontWeight.w700,
              letterSpacing: 1.2,
              color: isDark ? AppColors.slate500 : AppColors.slate400,
            ),
          ),
          Text(
            dates.day,
            style: TextStyle(
              fontSize:   22,
              fontWeight: FontWeight.w900,
              height:     1,
              color: isDark ? AppColors.slate100 : AppColors.slate800,
            ),
          ),
          Text(
            dates.time,
            style: TextStyle(
              fontSize: 9,
              color: isDark ? AppColors.slate500 : AppColors.slate400,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Score pill ────────────────────────────────────────────────────────────────

class _ScorePill extends StatelessWidget {
  final int a, b;
  const _ScorePill({required this.a, required this.b});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color:        isDark ? Colors.white : AppColors.slate900,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$a',
            style: TextStyle(
              fontSize:   15,
              fontWeight: FontWeight.w900,
              color: isDark ? AppColors.slate900 : Colors.white,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Text(
              '×',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.slate500 : AppColors.slate400,
              ),
            ),
          ),
          Text(
            '$b',
            style: TextStyle(
              fontSize:   15,
              fontWeight: FontWeight.w900,
              color: isDark ? AppColors.slate900 : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Team dot ──────────────────────────────────────────────────────────────────

class _TeamDot extends StatelessWidget {
  final Color? color;
  const _TeamDot({this.color});

  @override
  Widget build(BuildContext context) {
    if (color == null) return const SizedBox.shrink();
    final isWhite = color == const Color(0xFFFFFFFF);
    return Container(
      width:  13,
      height: 13,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: isWhite ? AppColors.slate300 : Colors.white.withAlpha(100),
          width: 1,
        ),
        boxShadow: isWhite
            ? [BoxShadow(color: AppColors.slate300.withAlpha(100), blurRadius: 2)]
            : null,
      ),
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  final bool   isDark;

  const _StatusBadge({required this.status, required this.isDark});

  static const _meta = {
    'final':      (Color(0xFFecfdf5), Color(0xFF059669)),
    'finalizado': (Color(0xFFecfdf5), Color(0xFF059669)),
    'done':       (Color(0xFFecfdf5), Color(0xFF059669)),
    'pós-jogo':   (Color(0xFFfff7ed), Color(0xFFea580c)),
    'postgame':   (Color(0xFFfff7ed), Color(0xFFea580c)),
    'playing':    (Color(0xFFeff6ff), Color(0xFF2563eb)),
    'started':    (Color(0xFFeff6ff), Color(0xFF2563eb)),
    'live':       (Color(0xFFeff6ff), Color(0xFF2563eb)),
    'teams':      (Color(0xFFf5f3ff), Color(0xFF7c3aed)),
    'matchmaking':(Color(0xFFf5f3ff), Color(0xFF7c3aed)),
    'accept':     (Color(0xFFfffbeb), Color(0xFFd97706)),
    'aceitação':  (Color(0xFFfffbeb), Color(0xFFd97706)),
  };

  @override
  Widget build(BuildContext context) {
    final key = status.toLowerCase().trim();
    (Color, Color)? found;
    if (_meta.containsKey(key)) {
      found = _meta[key];
    } else {
      for (final e in _meta.entries) {
        if (key.contains(e.key)) { found = e.value; break; }
      }
    }
    final bg = found?.$1 ?? (isDark ? AppColors.slate800 : AppColors.slate50);
    final fg = found?.$2 ?? (isDark ? AppColors.slate400 : AppColors.slate600);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: fg.withAlpha(80)),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize:   10,
          fontWeight: FontWeight.w600,
          color:      fg,
        ),
      ),
    );
  }
}

// ── Pagination ────────────────────────────────────────────────────────────────

class _Pagination extends StatelessWidget {
  final int  page;
  final int  totalPages;
  final int  total;
  final bool isDark;
  final void Function(int) onPage;

  const _Pagination({
    required this.page,
    required this.totalPages,
    required this.total,
    required this.isDark,
    required this.onPage,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Prev
        _PagButton(
          label:   'Anterior',
          icon:    Icons.chevron_left_rounded,
          leading: true,
          enabled: page > 1,
          isDark:  isDark,
          onTap:   () => onPage(page - 1),
        ),
        // Page info
        Expanded(
          child: Text(
            'Página $page de $totalPages',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.slate400 : AppColors.slate500,
            ),
          ),
        ),
        // Next
        _PagButton(
          label:   'Próxima',
          icon:    Icons.chevron_right_rounded,
          leading: false,
          enabled: page < totalPages,
          isDark:  isDark,
          onTap:   () => onPage(page + 1),
        ),
      ],
    );
  }
}

class _PagButton extends StatelessWidget {
  final String     label;
  final IconData   icon;
  final bool       leading;
  final bool       enabled;
  final bool       isDark;
  final VoidCallback onTap;

  const _PagButton({
    required this.label,
    required this.icon,
    required this.leading,
    required this.enabled,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color:        isDark ? AppColors.slate900 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.slate700 : AppColors.slate200,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading) Icon(icon, size: 14),
              if (leading) const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize:   13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (!leading) const SizedBox(width: 4),
              if (!leading) Icon(icon, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Skeletons ─────────────────────────────────────────────────────────────────

class _Skeletons extends StatelessWidget {
  final bool isDark;
  const _Skeletons({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: List.generate(
          6,
          (i) => Container(
            height:       68,
            margin:       const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color:        isDark ? AppColors.slate800 : AppColors.slate100,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isDark;
  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 48),
        decoration: BoxDecoration(
          color:        isDark ? AppColors.slate900 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:     isDark ? AppColors.slate700 : AppColors.slate200,
            style:     BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size:  36,
              color: isDark ? AppColors.slate600 : AppColors.slate300,
            ),
            const SizedBox(height: 12),
            Text(
              'Nenhuma partida encontrada',
              style: TextStyle(
                fontSize:   14,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.slate400 : AppColors.slate500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'O histórico aparecerá após a primeira partida finalizada.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.slate500 : AppColors.slate400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Date helpers ──────────────────────────────────────────────────────────────

class _DateParts {
  final String day, month, time, full, short;
  const _DateParts({
    required this.day,
    required this.month,
    required this.time,
    required this.full,
    required this.short,
  });
}

_DateParts? _formatDate(DateTime? d) {
  if (d == null) return null;
  return _DateParts(
    day:   DateFormat('dd',             'pt_BR').format(d),
    month: DateFormat('MMM',            'pt_BR').format(d).replaceAll('.', ''),
    time:  DateFormat('HH:mm',          'pt_BR').format(d),
    full:  DateFormat("EEE, dd 'de' MMM 'de' yyyy • HH:mm", 'pt_BR').format(d),
    short: DateFormat("dd 'de' MMM",    'pt_BR').format(d),
  );
}
