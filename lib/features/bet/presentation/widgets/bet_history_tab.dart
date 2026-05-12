import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/bet_models.dart';
import '../providers/bet_provider.dart';

class BetHistoryTab extends ConsumerStatefulWidget {
  final String groupId;
  const BetHistoryTab({super.key, required this.groupId});

  @override
  ConsumerState<BetHistoryTab> createState() => _BetHistoryTabState();
}

class _BetHistoryTabState extends ConsumerState<BetHistoryTab>
    with AutomaticKeepAliveClientMixin {
  List<MatchBetHistoryDto>? _history;
  bool   _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final ds = ref.read(betDsProvider);
      final h  = await ds.fetchHistory(widget.groupId);
      if (!mounted) return;
      setState(() { _history = h; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }
    if (_history == null || _history!.isEmpty) {
      return _EmptyHistoryState(isDark: isDark);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: _history!.length,
        itemBuilder: (_, i) => _MatchHistoryCard(
          match: _history![i],
          isDark: isDark,
        ),
      ),
    );
  }
}

// ── Match history card ────────────────────────────────────────────────────────

class _MatchHistoryCard extends StatefulWidget {
  final MatchBetHistoryDto match;
  final bool isDark;
  const _MatchHistoryCard({required this.match, required this.isDark});

  @override
  State<_MatchHistoryCard> createState() => _MatchHistoryCardState();
}

class _MatchHistoryCardState extends State<_MatchHistoryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final m     = widget.match;
    final isDark = widget.isDark;
    final bg    = isDark ? AppColors.slate800 : Colors.white;
    final border = isDark ? AppColors.slate700 : AppColors.slate200;
    final date  = _formatDate(m.playedAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: border),
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color:        isDark ? AppColors.slate700 : AppColors.slate100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.sports_soccer,
                      size: 20,
                      color: isDark ? AppColors.slate300 : AppColors.slate500),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(date,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: isDark ? Colors.white : AppColors.slate900)),
                      const SizedBox(height: 2),
                      Text(
                        '${m.teamAGoals} × ${m.teamBGoals}  ·  ${m.userBets.length} aposta${m.userBets.length != 1 ? "s" : ""}',
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.slate400 : AppColors.slate500),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: isDark ? AppColors.slate400 : AppColors.slate500,
                ),
              ]),
            ),
          ),

          // ── User bets ───────────────────────────────────────────────────
          if (_expanded)
            Divider(height: 1, color: border),
          if (_expanded)
            Column(
              children: m.userBets.map((ub) => _UserBetRow(
                userBet: ub,
                isDark:  isDark,
                border:  border,
              )).toList(),
            ),
        ],
      ),
    );
  }
}

// ── User bet row ──────────────────────────────────────────────────────────────

class _UserBetRow extends StatefulWidget {
  final UserBetInHistoryDto userBet;
  final bool isDark;
  final Color border;
  const _UserBetRow({required this.userBet, required this.isDark, required this.border});

  @override
  State<_UserBetRow> createState() => _UserBetRowState();
}

class _UserBetRowState extends State<_UserBetRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ub    = widget.userBet;
    final isDark = widget.isDark;
    final total  = ub.totalForMatch;
    final color  = fichasColor(total);

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: isDark ? AppColors.slate700 : AppColors.slate100,
                child: Text(
                  ub.userName.isNotEmpty ? ub.userName[0].toUpperCase() : '?',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.slate300 : AppColors.slate600),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(ub.userName,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.slate800)),
              ),
              Text(
                '${total >= 0 ? "+" : ""}$total BC',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color),
              ),
              const SizedBox(width: 6),
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: isDark ? AppColors.slate500 : AppColors.slate400,
              ),
            ]),
          ),
        ),

        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Column(
              children: [
                // Selections
                ...ub.selections.map((s) => _SelectionResultRow(
                      sel:    s,
                      isDark: isDark,
                    )),
                const SizedBox(height: 6),
                // Base reward
                Row(children: [
                  Icon(Icons.emoji_events_outlined,
                      size: 14,
                      color: isDark ? AppColors.slate500 : AppColors.slate400),
                  const SizedBox(width: 4),
                  Text('Bônus de participação',
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.slate400 : AppColors.slate500)),
                  const Spacer(),
                  Text('+${ub.baseReward} BC',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.slate300 : AppColors.slate600)),
                ]),
              ],
            ),
          ),

        Divider(height: 1, color: widget.border),
      ],
    );
  }
}

// ── Selection result row ──────────────────────────────────────────────────────

class _SelectionResultRow extends StatelessWidget {
  final BetSelectionDto sel;
  final bool isDark;
  const _SelectionResultRow({required this.sel, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final label    = kCategoryLabels[sel.category] ?? sel.category;
    final predicted = formatSelectionValue(sel.category, sel.predictedValue);
    final actual    = sel.actualValue != null
        ? formatSelectionValue(sel.category, sel.actualValue)
        : null;

    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    if (sel.isCorrect == true) {
      statusColor = const Color(0xFF34D399);
      statusIcon  = Icons.check_circle_outline;
      statusLabel = '+${sel.fichasEarned ?? 0}';
    } else if (sel.isPartialCredit == true) {
      statusColor = const Color(0xFFFBBF24);
      statusIcon  = Icons.remove_circle_outline;
      statusLabel = 'Reemb.';
    } else if (sel.isCorrect == false) {
      statusColor = const Color(0xFFF87171);
      statusIcon  = Icons.cancel_outlined;
      statusLabel = '−${sel.fichasWagered}';
    } else {
      // pending
      statusColor = isDark ? AppColors.slate500 : AppColors.slate400;
      statusIcon  = Icons.hourglass_empty;
      statusLabel = '${sel.fichasWagered}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(statusIcon, size: 16, color: statusColor),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.slate400 : AppColors.slate500)),
              Text(predicted,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.slate800)),
              if (actual != null)
                Text('Real: $actual',
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.slate500 : AppColors.slate400)),
            ],
          ),
        ),
        Text(statusLabel,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: statusColor)),
      ]),
    );
  }
}

// ── Empty / error states ──────────────────────────────────────────────────────

class _EmptyHistoryState extends StatelessWidget {
  final bool isDark;
  const _EmptyHistoryState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history,
              size: 44,
              color: isDark ? AppColors.slate700 : AppColors.slate200),
          const SizedBox(height: 12),
          Text('Nenhum histórico de apostas.',
              style: TextStyle(
                  color: isDark ? AppColors.slate500 : AppColors.slate400)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44, color: Color(0xFFF87171)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFF87171))),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Date helper ───────────────────────────────────────────────────────────────

String _formatDate(String iso) {
  try {
    final dt = AppDateUtils.parseOrNow(iso);
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  } catch (_) {
    return iso;
  }
}
